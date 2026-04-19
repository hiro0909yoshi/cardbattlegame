package ws

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"arcana-conquest-server/matchmaking"
)

const maxClients = 2000

type DeckLoader func(ctx context.Context, userID int64, deckID string) ([]int, error)

type MatchResultHandler func(roomID, matchType, mapID, rulePreset string, initialMagic, targetMagic, maxTurns, totalTurns int, results []map[string]any)

type Hub struct {
	mu            sync.RWMutex
	clients       map[int64]*Client // userID -> client
	rooms         map[string]*Room  // roomID -> room
	queue         *matchmaking.Queue
	loadDeck      DeckLoader
	onMatchResult MatchResultHandler
}

func NewHub(loadDeck DeckLoader, onMatchResult MatchResultHandler) *Hub {
	h := &Hub{
		clients:       make(map[int64]*Client),
		rooms:         make(map[string]*Room),
		loadDeck:      loadDeck,
		onMatchResult: onMatchResult,
	}
	h.queue = matchmaking.NewQueue(2, func(entries []matchmaking.QueueEntry) string {
		// マッチ成立 → 自動ルーム作成
		if len(entries) == 0 {
			return ""
		}
		first := h.GetClient(entries[0].UserID)
		if first == nil {
			return ""
		}
		cfg := RoomConfig{
			MatchType:    "ranked",
			MaxPlayers:   len(entries),
			RulePreset:   "standard",
			InitialMagic: 1000,
			TargetMagic:  8000,
		}
		room := NewRoom(h, first, cfg)
		for i := 1; i < len(entries); i++ {
			c := h.GetClient(entries[i].UserID)
			if c != nil {
				room.Join(c, entries[i].DeckID)
			}
		}
		h.mu.Lock()
		h.rooms[room.ID] = room
		h.mu.Unlock()

		room.Broadcast(NewMessage("match_found", map[string]any{
			"room_id": room.ID,
			"players": room.Players,
		}))
		return room.ID
	})
	return h
}

func (h *Hub) Register(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if len(h.clients) >= maxClients {
		c.Send(NewMessage("error", map[string]string{"message": "server full"}))
		c.conn.Close()
		return
	}

	if old, ok := h.clients[c.UserID]; ok {
		old.Send(NewMessage("error", map[string]string{"message": "duplicate connection"}))
		old.conn.Close()
	}
	h.clients[c.UserID] = c
	slog.Info("client registered", "user", c.UserID, "total", len(h.clients))
}

func (h *Hub) Unregister(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if existing, ok := h.clients[c.UserID]; ok && existing == c {
		delete(h.clients, c.UserID)
	}
	slog.Info("client unregistered", "user", c.UserID, "total", len(h.clients))
}

func (h *Hub) GetClient(userID int64) *Client {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.clients[userID]
}

func (h *Hub) RemoveRoom(roomID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.rooms, roomID)
	slog.Info("room removed", "room", roomID, "total", len(h.rooms))
}

func (h *Hub) GetRoom(roomID string) *Room {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.rooms[roomID]
}

func (h *Hub) ListRooms() []map[string]any {
	h.mu.RLock()
	defer h.mu.RUnlock()

	var list []map[string]any
	for _, r := range h.rooms {
		if r.Status == RoomWaiting {
			list = append(list, r.ToListEntry())
		}
	}
	return list
}

func (h *Hub) HandleMessage(c *Client, msg *Message) {
	slog.Debug("hub message", "user", c.UserID, "type", msg.Type)
	switch msg.Type {
	case "create_room":
		h.handleCreateRoom(c, msg.Data)
	case "join_room":
		h.handleJoinRoom(c, msg.Data)
	case "leave_room":
		h.handleLeaveRoom(c)
	case "set_ready":
		h.handleSetReady(c, msg.Data)
	case "set_deck":
		h.handleSetDeck(c, msg.Data)
	case "start_game":
		h.handleStartGame(c)
	case "list_rooms":
		c.Send(NewMessage("room_list", h.ListRooms()))
	case "reconnect":
		h.handleReconnect(c, msg.Data)
	case "start_matchmaking":
		h.handleStartMatchmaking(c, msg.Data)
	case "cancel_matchmaking":
		h.handleCancelMatchmaking(c)
	default:
		if c.Room != nil && c.Room.Status == RoomPlaying {
			c.Room.HandleGameAction(c, msg.Type, msg.Data)
		}
	}
}

func (h *Hub) handleCreateRoom(c *Client, data json.RawMessage) {
	if c.Room != nil {
		c.Send(NewMessage("error", map[string]string{"message": "already in a room"}))
		return
	}

	var cfg RoomConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		c.Send(NewMessage("error", map[string]string{"message": "invalid config"}))
		return
	}
	if cfg.MaxPlayers < 2 {
		cfg.MaxPlayers = 2
	}
	if cfg.MaxPlayers > 4 {
		cfg.MaxPlayers = 4
	}
	if cfg.MatchType == "" {
		cfg.MatchType = "friend"
	}
	if cfg.RulePreset == "" {
		cfg.RulePreset = "standard"
	}
	if cfg.InitialMagic <= 0 {
		cfg.InitialMagic = 1000
	}
	if cfg.InitialMagic > 99999 {
		cfg.InitialMagic = 99999
	}
	if cfg.TargetMagic <= 0 {
		cfg.TargetMagic = 8000
	}
	if cfg.TargetMagic > 999999 {
		cfg.TargetMagic = 999999
	}
	if cfg.TargetMagic <= cfg.InitialMagic {
		cfg.TargetMagic = cfg.InitialMagic * 8
	}
	if cfg.MaxTurns < 0 {
		cfg.MaxTurns = 0
	}
	if cfg.MaxTurns > 999 {
		cfg.MaxTurns = 999
	}

	room := NewRoom(h, c, cfg)
	h.mu.Lock()
	h.rooms[room.ID] = room
	h.mu.Unlock()

	slog.Info("room created", "room", room.ID, "host", c.UserID)
	c.Send(NewMessage("room_created", room.statePayload()))
}

func (h *Hub) handleJoinRoom(c *Client, data json.RawMessage) {
	if c.Room != nil {
		c.Send(NewMessage("error", map[string]string{"message": "already in a room"}))
		return
	}

	var req struct {
		RoomID string `json:"room_id"`
		DeckID string `json:"deck_id"`
	}
	if err := json.Unmarshal(data, &req); err != nil {
		c.Send(NewMessage("error", map[string]string{"message": "invalid request"}))
		return
	}

	room := h.GetRoom(req.RoomID)
	if room == nil {
		c.Send(NewMessage("error", map[string]string{"message": "room not found"}))
		return
	}

	if !room.Join(c, req.DeckID) {
		c.Send(NewMessage("error", map[string]string{"message": "cannot join room"}))
		return
	}
}

func (h *Hub) handleLeaveRoom(c *Client) {
	if c.Room == nil {
		return
	}
	c.Room.Leave(c)
}

func (h *Hub) handleSetReady(c *Client, data json.RawMessage) {
	if c.Room == nil {
		return
	}
	var req struct {
		Ready bool `json:"ready"`
	}
	if err := json.Unmarshal(data, &req); err != nil {
		c.Send(NewMessage("error", map[string]string{"message": "invalid request"}))
		return
	}
	c.Room.SetReady(c, req.Ready)
}

func (h *Hub) handleSetDeck(c *Client, data json.RawMessage) {
	if c.Room == nil {
		return
	}
	var req struct {
		DeckID string `json:"deck_id"`
	}
	if err := json.Unmarshal(data, &req); err != nil {
		c.Send(NewMessage("error", map[string]string{"message": "invalid request"}))
		return
	}
	c.Room.SetDeck(c, req.DeckID)
}

func (h *Hub) handleStartGame(c *Client) {
	if c.Room == nil {
		slog.Debug("start_game: no room", "user", c.UserID)
		return
	}
	if c.Room.HostID != c.UserID {
		slog.Debug("start_game: not host", "user", c.UserID, "host", c.Room.HostID)
		c.Send(NewMessage("error", map[string]string{"message": "only host can start"}))
		return
	}
	slog.Debug("start_game: calling StartGame", "user", c.UserID, "room_status", string(c.Room.Status))
	if !c.Room.StartGame() {
		slog.Debug("start_game: StartGame returned false", "user", c.UserID)
		c.Send(NewMessage("error", map[string]string{"message": "not all players ready"}))
	}
}

func (h *Hub) handleReconnect(c *Client, data json.RawMessage) {
	var req struct {
		RoomID string `json:"room_id"`
	}
	if err := json.Unmarshal(data, &req); err != nil {
		return
	}

	room := h.GetRoom(req.RoomID)
	if room == nil {
		c.Send(NewMessage("error", map[string]string{"message": "room not found"}))
		return
	}

	if !room.HandleReconnect(c) {
		c.Send(NewMessage("error", map[string]string{"message": "reconnect failed"}))
	}
}

func (h *Hub) handleStartMatchmaking(c *Client, data json.RawMessage) {
	if c.Room != nil {
		c.Send(NewMessage("error", map[string]string{"message": "already in a room"}))
		return
	}
	var req struct {
		DeckID      string  `json:"deck_id"`
		DisplayRate float64 `json:"display_rate"`
	}
	if err := json.Unmarshal(data, &req); err != nil {
		c.Send(NewMessage("error", map[string]string{"message": "invalid request"}))
		return
	}

	ok := h.queue.Enqueue(matchmaking.QueueEntry{
		UserID:      c.UserID,
		UserUUID:    c.UserUUID,
		DisplayRate: req.DisplayRate,
		DeckID:      req.DeckID,
		JoinedAt:    time.Now(),
	})
	if !ok {
		c.Send(NewMessage("error", map[string]string{"message": "already in queue"}))
		return
	}
	c.Send(NewMessage("matchmaking_started", map[string]any{
		"queue_size": h.queue.QueueSize(),
	}))
}

func (h *Hub) handleCancelMatchmaking(c *Client) {
	if h.queue.Cancel(c.UserID) {
		c.Send(NewMessage("matchmaking_cancelled", nil))
	}
}

func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) RoomCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.rooms)
}
