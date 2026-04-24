package game

import (
	"context"
	"encoding/json"
	"log/slog"
	"time"
)

type BroadcastFunc func(msg []byte)
type SendToFunc func(slotIndex int, msg []byte)
type GameOverFunc func(totalTurns int, results []map[string]any)

// command is a unit of work sent to the Session goroutine.
type command struct {
	kind      cmdKind
	slot      int
	msgType   string
	data      json.RawMessage
}

type cmdKind int

const (
	cmdAction     cmdKind = iota
	cmdTimeout
	cmdDisconnect
	cmdReconnect
	cmdDefeat
	cmdStop
)

// Session owns the GameState exclusively. All access goes through the
// single run() goroutine via the commands channel — no mutex needed.
type Session struct {
	state     *GameState
	RoomID    string
	MatchType string
	broadcast BroadcastFunc
	sendTo    SendToFunc
	onGameOver GameOverFunc
	ctx       context.Context
	cancel    context.CancelFunc
	commands  chan command
	turnTimer *time.Timer
}

const turnTimeout = 60 * time.Second

func NewSession(roomID, matchType string, cfg InitConfig, broadcast BroadcastFunc, sendTo SendToFunc, onGameOver GameOverFunc) *Session {
	ctx, cancel := context.WithCancel(context.Background())
	return &Session{
		state:      NewGameState(cfg),
		RoomID:     roomID,
		MatchType:  matchType,
		broadcast:  broadcast,
		sendTo:     sendTo,
		onGameOver: onGameOver,
		ctx:        ctx,
		cancel:     cancel,
		commands:   make(chan command, 64),
	}
}

// Start launches the Session goroutine and sends the initial state.
func (s *Session) Start() {
	go s.run()

	// クライアントの start_turn() と対称に、ゲーム開始時にも active player に 1 枚ドロー
	// （EndTurn 時は次プレイヤーにドローする実装と合わせる）
	s.state.DrawCard(s.state.ActivePlayer)

	s.broadcast(newMsg("game_state", map[string]any{
		"state": s.state,
	}))
	s.broadcastTurnStart()
	s.resetTurnTimer()
}

// Stop shuts down the Session goroutine.
func (s *Session) Stop() {
	s.cancel()
}

// Public API — all non-blocking sends into the command channel.

func (s *Session) HandleAction(slotIndex int, msgType string, data json.RawMessage) {
	select {
	case s.commands <- command{kind: cmdAction, slot: slotIndex, msgType: msgType, data: data}:
	case <-s.ctx.Done():
	}
}

func (s *Session) HandleDisconnect(slotIndex int) {
	select {
	case s.commands <- command{kind: cmdDisconnect, slot: slotIndex}:
	case <-s.ctx.Done():
	}
}

func (s *Session) HandleReconnect(slotIndex int) {
	select {
	case s.commands <- command{kind: cmdReconnect, slot: slotIndex}:
	case <-s.ctx.Done():
	}
}

func (s *Session) HandleDefeat(slotIndex int) {
	select {
	case s.commands <- command{kind: cmdDefeat, slot: slotIndex}:
	case <-s.ctx.Done():
	}
}

// run is the single goroutine that owns state. No other goroutine touches it.
func (s *Session) run() {
	defer s.stopTurnTimer()

	for {
		select {
		case <-s.ctx.Done():
			return
		case cmd := <-s.commands:
			switch cmd.kind {
			case cmdAction:
				s.processAction(cmd.slot, cmd.msgType, cmd.data)
			case cmdTimeout:
				s.processTurnTimeout()
			case cmdDisconnect:
				s.processDisconnect(cmd.slot)
			case cmdReconnect:
				s.processReconnect(cmd.slot)
			case cmdDefeat:
				s.processDefeat(cmd.slot)
			case cmdStop:
				s.cancel()
				return
			}
		}
	}
}

func (s *Session) processAction(slotIndex int, msgType string, data json.RawMessage) {
	if s.state.Finished {
		return
	}

	slog.Debug("action received",
		"slot", slotIndex,
		"type", msgType,
		"phase", s.state.Phase,
		"turn", s.state.CurrentTurn,
	)

	var actionErr *ActionError

	switch msgType {
	case "spell_cast":
		var req struct {
			CardID       int `json:"card_id"`
			TargetPlayer int `json:"target_player"`
			TargetTile   int `json:"target_tile"`
		}
		if err := json.Unmarshal(data, &req); err != nil {
			s.sendTo(slotIndex, newMsg("action_error", &ActionError{Code: "bad_request", Message: "invalid JSON"}))
			return
		}
		actionErr = s.state.SpellCast(slotIndex, req.CardID, req.TargetPlayer, req.TargetTile)
		if actionErr == nil {
			s.broadcastAction(slotIndex, "spell_cast", map[string]any{
				"card_id":       req.CardID,
				"target_player": req.TargetPlayer,
				"target_tile":   req.TargetTile,
			})
		}

	case "spell_pass":
		actionErr = s.state.SpellPass(slotIndex)
		if actionErr == nil {
			s.broadcastAction(slotIndex, "spell_pass", nil)
			// 薄型リレー方式: 自動ダイスロールを廃止。
			// PhaseDice 遷移後、クライアントから dice_roll メッセージを待つ。
			// フェーズ変更を通知するため turn_start を再送信
			s.broadcastTurnStart()
		}

	case "dice_roll":
		// 薄型リレー方式: クライアントからの明示的な dice_roll 要求でダイスを振る
		result, err := s.state.DiceRoll(slotIndex)
		actionErr = err
		if actionErr == nil {
			s.broadcast(newMsg("dice_result", map[string]any{
				"player": slotIndex,
				"result": result,
			}))
		}

	case "move_complete":
		var req struct {
			Direction int `json:"direction"`
		}
		if err := json.Unmarshal(data, &req); err != nil {
			s.sendTo(slotIndex, newMsg("action_error", &ActionError{Code: "bad_request", Message: "invalid JSON"}))
			return
		}
		actionErr = s.state.MoveComplete(slotIndex, req.Direction)
		if actionErr == nil {
			if p := s.state.ActivePlayerState(); p != nil {
				s.broadcastAction(slotIndex, "move_complete", map[string]any{
					"position": p.Position,
					"phase":    s.state.Phase,
				})
			}
			// 薄型リレー: フェーズ遷移をクライアントに通知
			s.broadcastTurnStart()
			// 旧: PhaseBattle でサーバーが ResolveBattle を実行していた処理は削除済み。
		}

	case "summon":
		var req struct {
			CardID int `json:"card_id"`
		}
		if err := json.Unmarshal(data, &req); err != nil {
			s.sendTo(slotIndex, newMsg("action_error", &ActionError{Code: "bad_request", Message: "invalid JSON"}))
			return
		}
		actionErr = s.state.Summon(slotIndex, req.CardID)
		if actionErr == nil {
			if p := s.state.ActivePlayerState(); p != nil && p.Position >= 0 && p.Position < len(s.state.Board) {
				tile := s.state.Board[p.Position]
				s.broadcastAction(slotIndex, "summon", map[string]any{
					"card_id":  req.CardID,
					"tile":     p.Position,
					"creature": tile,
				})
			}
			// 薄型リレー: phase 遷移通知（PhaseEndTurn へ）
			s.broadcastTurnStart()
		}

	case "dominio_action":
		var req struct {
			Command     string `json:"command"`
			SourceTile  int    `json:"source_tile"`
			TargetTile  int    `json:"target_tile"`
			TargetLevel int    `json:"target_level"`
			Cost        int    `json:"cost"`
			NewElement  string `json:"new_element"`
			CardID      int    `json:"card_id"`
		}
		if err := json.Unmarshal(data, &req); err != nil {
			s.sendTo(slotIndex, newMsg("action_error", &ActionError{Code: "bad_request", Message: "invalid JSON"}))
			return
		}
		actionErr = s.state.DominioAction(slotIndex, req.Command, req.SourceTile, req.TargetTile)
		if actionErr == nil {
			// クライアント計算結果（target_level/cost/new_element/card_id 等）をそのまま他プレイヤーに配信
			s.broadcastAction(slotIndex, "dominio_action", map[string]any{
				"command":      req.Command,
				"source_tile":  req.SourceTile,
				"target_tile":  req.TargetTile,
				"target_level": req.TargetLevel,
				"cost":         req.Cost,
				"new_element":  req.NewElement,
				"card_id":      req.CardID,
			})
			// 薄型リレー: phase 遷移通知
			s.broadcastTurnStart()
		}

	case "pass":
		actionErr = s.state.Pass(slotIndex)
		if actionErr == nil {
			s.broadcastAction(slotIndex, "pass", nil)
			// 薄型リレー: フェーズ遷移通知
			s.broadcastTurnStart()
		}

	case "battle_item":
		// 旧: サーバー側でバトルアイテム選択を処理していた。薄型リレー方式では
		// クライアントがバトル計算全体を担当するため、このアクションは廃止。
		// Phase 2 でクライアントから battle_result_report を受ける形に置き換え。
		s.sendTo(slotIndex, newMsg("action_error", &ActionError{Code: "deprecated", Message: "battle_item is deprecated in thin-relay mode"}))
		return

	case "end_turn":
		winner, finished, err := s.state.EndTurn(slotIndex)
		actionErr = err
		if actionErr == nil {
			if finished {
				s.handleGameOver(winner)
				return
			}
			s.broadcastTurnStart()
			s.resetTurnTimer()
			return
		}

	case "card_selected":
		var req struct {
			CardID int `json:"card_id"`
		}
		if err := json.Unmarshal(data, &req); err != nil {
			s.sendTo(slotIndex, newMsg("action_error", &ActionError{Code: "bad_request", Message: "invalid JSON"}))
			return
		}
		s.broadcastAction(slotIndex, "card_selected", map[string]any{
			"card_id": req.CardID,
		})
		return

	case "lap_complete":
		// 薄型リレー: クライアントが周回完了を検知した通知を他プレイヤーに配信
		// ダウン解除・HP回復は各クライアントが自前で処理する
		var req struct {
			PlayerID int `json:"player_id"`
		}
		if err := json.Unmarshal(data, &req); err != nil {
			s.sendTo(slotIndex, newMsg("action_error", &ActionError{Code: "bad_request", Message: "invalid JSON"}))
			return
		}
		s.broadcastAction(slotIndex, "lap_complete", map[string]any{
			"player_id": req.PlayerID,
		})
		return

	default:
		slog.Warn("unknown game action", "type", msgType, "player", slotIndex)
		return
	}

	if actionErr != nil {
		s.sendTo(slotIndex, newMsg("action_error", actionErr))
		slog.Info("action rejected", "room", s.RoomID, "player", slotIndex, "type", msgType, "err", actionErr.Message)
	}
}

func (s *Session) processTurnTimeout() {
	if s.state.Finished {
		return
	}

	active := s.state.ActivePlayer
	slog.Info("turn timeout", "room", s.RoomID, "player", active)

	s.broadcast(newMsg("turn_timeout", map[string]any{
		"player":      active,
		"action_type": "turn_timeout",
		"turn_number": s.state.CurrentTurn,
	}))

	switch s.state.Phase {
	case PhaseSpell:
		s.state.TransitionTo(PhaseDice)
		s.state.RollDice()
		s.broadcast(newMsg("dice_result", map[string]any{
			"player": active,
			"result": s.state.DiceResult,
		}))
		if p := s.state.ActivePlayerState(); p != nil && len(s.state.Board) > 0 {
			p.Position = (p.Position + s.state.DiceResult) % len(s.state.Board)
			s.state.StateVersion++
		}
		s.state.TransitionTo(PhaseEndTurn)
	case PhaseDice:
		s.state.RollDice()
		if p := s.state.ActivePlayerState(); p != nil && len(s.state.Board) > 0 {
			p.Position = (p.Position + s.state.DiceResult) % len(s.state.Board)
			s.state.StateVersion++
		}
		s.state.TransitionTo(PhaseEndTurn)
	case PhaseMove, PhaseTileAction, PhaseBattle:
		s.state.TransitionTo(PhaseEndTurn)
	case PhaseEndTurn:
	}

	winner, finished, _ := s.state.EndTurn(active)
	if finished {
		s.handleGameOver(winner)
		return
	}

	s.broadcastTurnStart()
	s.resetTurnTimer()
}

func (s *Session) processDisconnect(slotIndex int) {
	if slotIndex >= 0 && slotIndex < len(s.state.Players) {
		s.state.Players[slotIndex].Disconnected = true
		s.state.StateVersion++
	}
}

func (s *Session) processReconnect(slotIndex int) {
	if slotIndex < 0 || slotIndex >= len(s.state.Players) {
		return
	}
	s.state.Players[slotIndex].Disconnected = false
	s.state.StateVersion++
	s.sendTo(slotIndex, newMsg("game_state", map[string]any{
		"state": s.state,
	}))
	if slotIndex == s.state.ActivePlayer {
		s.sendTo(slotIndex, newMsg("your_hand", map[string]any{
			"hand": s.state.Players[slotIndex].Hand,
		}))
	}
}

func (s *Session) processDefeat(slotIndex int) {
	if slotIndex >= 0 && slotIndex < len(s.state.Players) {
		s.state.Players[slotIndex].Alive = false
		s.state.StateVersion++
	}

	alive := 0
	lastAlive := -1
	for i, p := range s.state.Players {
		if p.Alive {
			alive++
			lastAlive = i
		}
	}
	if alive <= 1 && lastAlive >= 0 {
		s.state.Finished = true
		s.state.StateVersion++
		s.state.assignRanks(lastAlive)
		s.handleGameOver(lastAlive)
	}
}

func (s *Session) handleGameOver(winnerIdx int) {
	s.stopTurnTimer()

	results := make([]map[string]any, len(s.state.Players))
	for i, p := range s.state.Players {
		results[i] = map[string]any{
			"user_id":     p.UserID,
			"internal_id": p.InternalID,
			"slot_index":  p.SlotIndex,
			"final_rank":  p.FinalRank,
			"tep":         p.TEP,
		}
	}

	s.broadcast(newMsg("game_over", map[string]any{
		"action_type": "game_over",
		"turn_number": s.state.CurrentTurn,
		"results":     results,
		"total_turns": s.state.TotalTurns,
		"winner":      winnerIdx,
	}))

	slog.Info("game over", "room", s.RoomID, "winner", winnerIdx, "turns", s.state.TotalTurns)

	if s.onGameOver != nil {
		s.onGameOver(s.state.TotalTurns, results)
	}

	s.cancel()
}

func (s *Session) broadcastTurnStart() {
	active := s.state.ActivePlayerState()
	if active == nil {
		slog.Error("broadcastTurnStart: active player is nil", "room", s.RoomID, "active", s.state.ActivePlayer)
		return
	}
	slog.Info("turn start",
		"room", s.RoomID,
		"turn", s.state.CurrentTurn,
		"player", s.state.ActivePlayer,
		"phase", s.state.Phase,
	)
	s.broadcast(newMsg("turn_start", map[string]any{
		"turn":          s.state.CurrentTurn,
		"active_player": s.state.ActivePlayer,
		"phase":         s.state.Phase,
		"player_ep":     active.EP,
		"hand_count":    len(active.Hand),
		"hand":          active.Hand,
		"state_version": s.state.StateVersion,
	}))

	s.sendTo(s.state.ActivePlayer, newMsg("your_hand", map[string]any{
		"hand": active.Hand,
	}))
}

func (s *Session) broadcastAction(slotIndex int, action string, data map[string]any) {
	payload := map[string]any{
		"player":        slotIndex,
		"action_type":   action,
		"turn_number":   s.state.CurrentTurn,
		"state_version": s.state.StateVersion,
	}
	if data != nil {
		payload["data"] = data
	}
	s.broadcast(newMsg("action_result", payload))
}

func (s *Session) resetTurnTimer() {
	s.stopTurnTimer()
	s.turnTimer = time.AfterFunc(turnTimeout, func() {
		select {
		case s.commands <- command{kind: cmdTimeout}:
		case <-s.ctx.Done():
		}
	})
}

func (s *Session) stopTurnTimer() {
	if s.turnTimer != nil {
		s.turnTimer.Stop()
		s.turnTimer = nil
	}
}

// GetState returns a snapshot for read-only external use (e.g. result processing).
// Safe because it's called after game over (goroutine exited).
func (s *Session) GetState() *GameState {
	return s.state
}

func newMsg(msgType string, data any) []byte {
	d, err := json.Marshal(data)
	if err != nil {
		slog.Error("failed to marshal game message data", "type", msgType, "err", err)
		d = []byte("{}")
	}
	m := struct {
		Type      string          `json:"type"`
		Data      json.RawMessage `json:"data"`
		Timestamp int64           `json:"ts"`
	}{Type: msgType, Data: d, Timestamp: time.Now().UnixMilli()}
	b, err := json.Marshal(m)
	if err != nil {
		slog.Error("failed to marshal game message", "type", msgType, "err", err)
		return []byte(`{"type":"error","data":{},"ts":0}`)
	}
	return b
}
