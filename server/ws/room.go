package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/rand/v2"
	"sync"
	"time"

	"arcana-conquest-server/game"
)

type RoomStatus string

const (
	RoomWaiting  RoomStatus = "waiting"
	RoomReady    RoomStatus = "ready"
	RoomPlaying  RoomStatus = "playing"
	RoomFinished RoomStatus = "finished"
)

type RoomConfig struct {
	MatchType    string `json:"match_type"`
	MaxPlayers   int    `json:"max_players"`
	MapID        string `json:"map_id"`
	RulePreset   string `json:"rule_preset"`
	InitialMagic int    `json:"initial_magic"`
	TargetMagic  int    `json:"target_magic"`
	MaxTurns     int    `json:"max_turns"`
}

type PlayerSlot struct {
	Client       *Client    `json:"-"`
	UserID       int64      `json:"user_id"`
	UserUUID     string     `json:"user_uuid"`
	DisplayName  string     `json:"display_name"`
	SlotIndex    int        `json:"slot_index"`
	DeckID       string     `json:"deck_id"`
	IsReady      bool       `json:"is_ready"`
	Connected    bool       `json:"connected"`
	DisconnectAt *time.Time `json:"-"`
}

// Room manages connections only. Game logic lives in game.Session.
type Room struct {
	mu       sync.RWMutex
	ID       string        `json:"room_id"`
	HostID   int64         `json:"host_id"`
	Config   RoomConfig    `json:"config"`
	Status   RoomStatus    `json:"status"`
	Players  []*PlayerSlot `json:"players"`
	hub      *Hub
	Session  *game.Session `json:"-"`

	disconnectTimers map[int64]*time.Timer
}

func NewRoom(hub *Hub, hostClient *Client, cfg RoomConfig) *Room {
	roomID := hub.uniqueRoomID()
	r := &Room{
		ID:               roomID,
		HostID:           hostClient.UserID,
		Config:           cfg,
		Status:           RoomWaiting,
		hub:              hub,
		Players:          make([]*PlayerSlot, 0, cfg.MaxPlayers),
		disconnectTimers: make(map[int64]*time.Timer),
	}
	r.addPlayer(hostClient, "")
	return r
}

func (r *Room) addPlayer(c *Client, deckID string) int {
	slot := len(r.Players)
	r.Players = append(r.Players, &PlayerSlot{
		Client:      c,
		UserID:      c.UserID,
		UserUUID:    c.UserUUID,
		DisplayName: c.DisplayName,
		SlotIndex:   slot,
		DeckID:      deckID,
		IsReady:     false,
		Connected:   true,
	})
	c.Room = r
	return slot
}

func (r *Room) Join(c *Client, deckID string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.Status != RoomWaiting {
		return false
	}
	if len(r.Players) >= r.Config.MaxPlayers {
		return false
	}
	for _, p := range r.Players {
		if p.UserID == c.UserID {
			return false
		}
	}

	slot := r.addPlayer(c, deckID)
	slog.Info("player joined room", "room", r.ID, "user", c.UserID, "slot", slot)
	r.broadcastRoomState()
	return true
}

func (r *Room) Leave(c *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()

	idx := r.findPlayerIndex(c.UserID)
	if idx < 0 {
		return
	}

	c.Room = nil
	r.Players = append(r.Players[:idx], r.Players[idx+1:]...)
	for i := idx; i < len(r.Players); i++ {
		r.Players[i].SlotIndex = i
	}

	slog.Info("player left room", "room", r.ID, "user", c.UserID)

	if len(r.Players) == 0 {
		r.Status = RoomFinished
		for _, timer := range r.disconnectTimers {
			timer.Stop()
		}
		if r.Session != nil {
			r.Session.Stop()
		}
		r.hub.RemoveRoom(r.ID)
		return
	}

	if c.UserID == r.HostID && len(r.Players) > 0 {
		r.HostID = r.Players[0].UserID
	}

	r.broadcastRoomState()
}

func (r *Room) SetReady(c *Client, ready bool) {
	r.mu.Lock()
	defer r.mu.Unlock()

	p := r.findPlayer(c.UserID)
	if p == nil {
		return
	}
	p.IsReady = ready

	if r.allReady() && len(r.Players) >= 2 {
		r.Status = RoomReady
	} else {
		r.Status = RoomWaiting
	}
	r.broadcastRoomState()
}

func (r *Room) SetDeck(c *Client, deckID string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	p := r.findPlayer(c.UserID)
	if p == nil {
		return
	}
	p.DeckID = deckID
	r.broadcastRoomState()
}

// StartGame creates a Session and delegates all game logic to it.
// Room does NOT touch GameState after this point.
func (r *Room) StartGame() bool {
	r.mu.Lock()

	if r.Status != RoomReady {
		r.mu.Unlock()
		return false
	}
	r.Status = RoomPlaying

	tileCount := 20
	elements := []string{"fire", "water", "earth", "wind", "neutral"}
	tiles := make([]game.TileInit, tileCount)
	for i := range tiles {
		tiles[i] = game.TileInit{Element: elements[i%len(elements)]}
	}

	var players []game.PlayerInit
	for _, p := range r.Players {
		var deckCards []int
		if r.hub.loadDeck != nil {
			cards, err := r.hub.loadDeck(context.Background(), p.UserID, p.DeckID)
			if err != nil {
				slog.Warn("failed to load deck", "user", p.UserID, "deck", p.DeckID, "err", err)
			} else {
				deckCards = cards
			}
		}
		if deckCards == nil {
			deckCards = []int{}
		}

		players = append(players, game.PlayerInit{
			UserID:     p.UserUUID,
			InternalID: p.UserID,
			SlotIndex:  p.SlotIndex,
			DeckCards:  deckCards,
		})
	}

	cfg := game.InitConfig{
		Players:      players,
		MapTiles:     tiles,
		TargetTEP:    r.Config.TargetMagic,
		MaxTurns:     r.Config.MaxTurns,
		InitialEP:    r.Config.InitialMagic,
		InitialCards: 4,
	}

	broadcastFn := func(msg []byte) {
		r.mu.RLock()
		defer r.mu.RUnlock()
		for _, p := range r.Players {
			if p.Client != nil {
				p.Client.Send(msg)
			}
		}
	}
	sendToFn := func(slotIndex int, msg []byte) {
		r.mu.RLock()
		defer r.mu.RUnlock()
		if slotIndex >= 0 && slotIndex < len(r.Players) && r.Players[slotIndex].Client != nil {
			r.Players[slotIndex].Client.Send(msg)
		}
	}
	onGameOver := func(totalTurns int, results []map[string]any) {
		r.mu.Lock()
		r.Status = RoomFinished
		r.mu.Unlock()

		if r.hub.onMatchResult != nil {
			r.hub.onMatchResult(r.ID, r.Config.MatchType, r.Config.MapID, r.Config.RulePreset, r.Config.InitialMagic, r.Config.TargetMagic, r.Config.MaxTurns, totalTurns, results)
		}
	}

	r.Session = game.NewSession(r.ID, r.Config.MatchType, cfg, broadcastFn, sendToFn, onGameOver)

	// Unlock BEFORE Start() — Start() broadcasts game_state which needs RLock
	r.mu.Unlock()
	r.Session.Start()
	return true
}

// HandleDisconnect delegates disconnect to Session if game is in progress
func (r *Room) HandleDisconnect(c *Client) {
	r.mu.Lock()

	p := r.findPlayer(c.UserID)
	if p == nil {
		r.mu.Unlock()
		return
	}
	p.Connected = false
	p.Client = nil
	now := time.Now()
	p.DisconnectAt = &now

	slog.Info("player disconnected", "room", r.ID, "user", c.UserID, "status", r.Status)

	if r.Status != RoomPlaying {
		r.mu.Unlock()
		r.Leave(c)
		return
	}

	// Notify Session
	slotIndex := p.SlotIndex
	if r.Session != nil {
		r.Session.HandleDisconnect(slotIndex)
	}

	gracePeriod := 30 * time.Second
	if r.Config.MatchType == "friend" {
		gracePeriod = 60 * time.Second
	}

	timer := time.AfterFunc(gracePeriod, func() {
		r.handleDisconnectTimeout(c.UserID)
	})
	r.disconnectTimers[c.UserID] = timer

	r.broadcastFromLocked(NewMessage("player_disconnected", map[string]any{
		"user_id":       c.UserID,
		"grace_seconds": int(gracePeriod.Seconds()),
	}))

	r.mu.Unlock()
}

// HandleReconnect restores connection and delegates full state sync to Session
func (r *Room) HandleReconnect(c *Client) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.Status == RoomFinished {
		return false
	}

	p := r.findPlayer(c.UserID)
	if p == nil {
		return false
	}

	p.Client = c
	p.Connected = true
	p.DisconnectAt = nil
	c.Room = r

	if timer, ok := r.disconnectTimers[c.UserID]; ok {
		timer.Stop()
		delete(r.disconnectTimers, c.UserID)
	}

	slog.Info("player reconnected", "room", r.ID, "user", c.UserID)

	r.broadcastFromLocked(NewMessage("player_reconnected", map[string]any{
		"user_id": c.UserID,
	}))

	// Session handles full game state sync
	if r.Session != nil {
		r.Session.HandleReconnect(p.SlotIndex)
	}
	return true
}

func (r *Room) handleDisconnectTimeout(userID int64) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.Status == RoomFinished {
		return
	}

	delete(r.disconnectTimers, userID)
	p := r.findPlayer(userID)
	if p == nil || p.Connected {
		return
	}

	slog.Info("disconnect timeout", "room", r.ID, "user", userID)

	if r.Config.MatchType == "ranked" {
		// Delegate defeat to Session
		if r.Session != nil {
			r.Session.HandleDefeat(p.SlotIndex)
		}
		r.broadcastFromLocked(NewMessage("player_defeated", map[string]any{
			"user_id": userID,
			"reason":  "disconnect_timeout",
		}))
	} else {
		r.broadcastFromLocked(NewMessage("player_ai_takeover", map[string]any{
			"user_id": userID,
		}))
	}
}

// HandleGameAction routes game messages to Session
func (r *Room) HandleGameAction(c *Client, msgType string, data json.RawMessage) {
	r.mu.RLock()
	session := r.Session
	slot := r.findPlayerIndex(c.UserID)
	r.mu.RUnlock()

	if session == nil || slot < 0 {
		return
	}
	session.HandleAction(slot, msgType, data)
}

func (r *Room) Broadcast(msg []byte) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, p := range r.Players {
		if p.Client != nil {
			p.Client.Send(msg)
		}
	}
}

func (r *Room) broadcastFromLocked(msg []byte) {
	for _, p := range r.Players {
		if p.Client != nil {
			p.Client.Send(msg)
		}
	}
}

func (r *Room) broadcastRoomState() {
	r.broadcastFromLocked(NewMessage("room_state", r.statePayload()))
}

func (r *Room) statePayload() map[string]any {
	return map[string]any{
		"room_id": r.ID,
		"host_id": r.HostID,
		"status":  r.Status,
		"config":  r.Config,
		"players": r.Players,
	}
}

func (r *Room) findPlayer(userID int64) *PlayerSlot {
	for _, p := range r.Players {
		if p.UserID == userID {
			return p
		}
	}
	return nil
}

func (r *Room) findPlayerIndex(userID int64) int {
	for i, p := range r.Players {
		if p.UserID == userID {
			return i
		}
	}
	return -1
}

func (r *Room) allReady() bool {
	for _, p := range r.Players {
		if !p.IsReady {
			return false
		}
	}
	return true
}

func (r *Room) PlayerCount() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.Players)
}

func (r *Room) ToListEntry() map[string]any {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return map[string]any{
		"room_id":      r.ID,
		"host_id":      r.HostID,
		"match_type":   r.Config.MatchType,
		"map_id":       r.Config.MapID,
		"max_players":  r.Config.MaxPlayers,
		"player_count": len(r.Players),
		"status":       r.Status,
	}
}

func generateRoomID() string {
	return fmt.Sprintf("%04d", rand.IntN(10000))
}

func (p *PlayerSlot) MarshalJSON() ([]byte, error) {
	type Alias struct {
		UserID      int64  `json:"user_id"`
		UserUUID    string `json:"user_uuid"`
		DisplayName string `json:"display_name"`
		SlotIndex   int    `json:"slot_index"`
		DeckID      string `json:"deck_id"`
		IsReady     bool   `json:"is_ready"`
		Connected   bool   `json:"connected"`
	}
	return json.Marshal(&Alias{
		UserID:      p.UserID,
		UserUUID:    p.UserUUID,
		DisplayName: p.DisplayName,
		SlotIndex:   p.SlotIndex,
		DeckID:      p.DeckID,
		IsReady:     p.IsReady,
		Connected:   p.Connected,
	})
}
