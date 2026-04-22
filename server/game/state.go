package game

import (
	"math/rand/v2"
)

type Phase string

const (
	PhaseSpell      Phase = "spell"
	PhaseDice       Phase = "dice"
	PhaseMove       Phase = "move"
	PhaseTileAction Phase = "tile_action"
	PhaseBattle     Phase = "battle"
	PhaseEndTurn    Phase = "end_turn"
)

type GameState struct {
	Players         []*PlayerState `json:"players"`
	CurrentTurn     int            `json:"current_turn"`
	ActivePlayer    int            `json:"active_player"`
	Phase           Phase          `json:"phase"`
	Board           []*TileState   `json:"board"`
	TargetTEP       int            `json:"target_tep"`
	MaxTurns        int            `json:"max_turns"`
	TotalTurns      int            `json:"total_turns"`
	DiceResult      int            `json:"dice_result"`
	Seed            int64          `json:"seed"`
	rng             *rand.Rand
	Finished        bool           `json:"finished"`
	StateVersion    int64          `json:"state_version"`
	PendingBattle   *BattleContext `json:"pending_battle,omitempty"`
	BattleItemsReady [2]bool       `json:"-"`
}

type PlayerState struct {
	UserID       string `json:"user_id"`
	InternalID   int64  `json:"internal_id"`
	SlotIndex    int    `json:"slot_index"`
	EP           int    `json:"ep"`
	Hand         []int  `json:"hand"`
	Deck         []int  `json:"deck"`
	Discard      []int  `json:"discard"`
	Position     int    `json:"position"`
	LapCount     int    `json:"lap_count"`
	TEP          int    `json:"tep"`
	Alive        bool   `json:"alive"`
	FinalRank    int    `json:"final_rank"`
	Disconnected bool   `json:"disconnected"`
}

type TileState struct {
	Index      int    `json:"index"`
	OwnerIndex int    `json:"owner_index"`
	CreatureID int    `json:"creature_id"`
	CreatureHP int    `json:"creature_hp"`
	Level      int    `json:"level"`
	IsDown     bool   `json:"is_down"`
	Element    string `json:"element"`
}

type InitConfig struct {
	Players      []PlayerInit
	MapTiles     []TileInit
	TargetTEP    int
	MaxTurns     int
	InitialEP    int
	InitialCards int
}

type PlayerInit struct {
	UserID     string
	InternalID int64
	SlotIndex  int
	DeckCards  []int
}

type TileInit struct {
	Element string
}

func NewGameState(cfg InitConfig) *GameState {
	seed := rand.Int64()
	rng := rand.New(rand.NewPCG(uint64(seed), 0))

	gs := &GameState{
		CurrentTurn:  1,
		ActivePlayer: 0,
		Phase:        PhaseSpell,
		TargetTEP:    cfg.TargetTEP,
		MaxTurns:     cfg.MaxTurns,
		Seed:         seed,
		rng:          rng,
	}

	for _, pi := range cfg.Players {
		deck := make([]int, len(pi.DeckCards))
		copy(deck, pi.DeckCards)
		rng.Shuffle(len(deck), func(i, j int) { deck[i], deck[j] = deck[j], deck[i] })

		hand := make([]int, 0, cfg.InitialCards)
		drawCount := min(cfg.InitialCards, len(deck))
		if drawCount > 0 {
			hand = append(hand, deck[:drawCount]...)
			deck = deck[drawCount:]
		}

		gs.Players = append(gs.Players, &PlayerState{
			UserID:     pi.UserID,
			InternalID: pi.InternalID,
			SlotIndex:  pi.SlotIndex,
			EP:         cfg.InitialEP,
			Hand:       hand,
			Deck:       deck,
			Discard:    []int{},
			Position:   0,
			LapCount:   0,
			TEP:        0,
			Alive:      true,
		})
	}

	for i, ti := range cfg.MapTiles {
		gs.Board = append(gs.Board, &TileState{
			Index:      i,
			OwnerIndex: -1,
			CreatureID: 0,
			CreatureHP: 0,
			Level:      1,
			IsDown:     false,
			Element:    ti.Element,
		})
	}

	return gs
}

func (gs *GameState) ActivePlayerState() *PlayerState {
	if gs.ActivePlayer < 0 || gs.ActivePlayer >= len(gs.Players) {
		return nil
	}
	return gs.Players[gs.ActivePlayer]
}

func (gs *GameState) NextAlivePlayer() int {
	count := len(gs.Players)
	for i := 1; i <= count; i++ {
		idx := (gs.ActivePlayer + i) % count
		if gs.Players[idx].Alive && !gs.Players[idx].Disconnected {
			return idx
		}
	}
	return -1
}

func (gs *GameState) DrawCard(playerIdx int) int {
	p := gs.Players[playerIdx]
	if len(p.Deck) == 0 {
		if len(p.Discard) == 0 {
			return -1
		}
		p.Deck = append(p.Deck, p.Discard...)
		p.Discard = p.Discard[:0]
		gs.rng.Shuffle(len(p.Deck), func(i, j int) { p.Deck[i], p.Deck[j] = p.Deck[j], p.Deck[i] })
	}
	card := p.Deck[0]
	p.Deck = p.Deck[1:]
	p.Hand = append(p.Hand, card)
	gs.StateVersion++
	return card
}

func (gs *GameState) RollDice() int {
	result := gs.rng.IntN(6) + 1
	gs.DiceResult = result
	gs.StateVersion++
	return result
}

func (gs *GameState) RemoveFromHand(playerIdx, cardID int) bool {
	p := gs.Players[playerIdx]
	for i, c := range p.Hand {
		if c == cardID {
			p.Hand = append(p.Hand[:i], p.Hand[i+1:]...)
			p.Discard = append(p.Discard, cardID)
			gs.StateVersion++
			return true
		}
	}
	return false
}

func (gs *GameState) CalculateTEP(playerIdx int) int {
	p := gs.Players[playerIdx]
	tep := p.EP
	for _, tile := range gs.Board {
		if tile.OwnerIndex == playerIdx {
			tep += tile.Level * 100
		}
	}
	p.TEP = tep
	return tep
}

func (gs *GameState) CheckWinCondition() int {
	for i, p := range gs.Players {
		if p.Alive && gs.CalculateTEP(i) >= gs.TargetTEP {
			return i
		}
	}
	return -1
}

func (gs *GameState) CheckMaxTurns() bool {
	return gs.MaxTurns > 0 && gs.TotalTurns >= gs.MaxTurns
}

// TransitionTo is the single point for all phase transitions.
func (gs *GameState) TransitionTo(next Phase) {
	gs.Phase = next
	gs.StateVersion++
}

func (gs *GameState) TransitionAfterLanding(slotIndex int) {
	// 薄型リレー方式（2026-04-20 移行中）: バトル計算はクライアント側で行う。
	// 敵タイル着地時もサーバーは PhaseTileAction に遷移し、クライアントからの
	// バトル結果報告（battle_result_report）を待つ設計。
	// 現在はクライアント側報告が未実装のため、着地後は常に TileAction に進む。
	gs.TransitionTo(PhaseTileAction)
}

func (gs *GameState) StartBattle(attackerSlot int) {
	p := gs.Players[attackerSlot]
	if p == nil {
		return
	}
	tile := gs.Board[p.Position]
	gs.PendingBattle = &BattleContext{
		AttackerSlot: attackerSlot,
		DefenderSlot: tile.OwnerIndex,
		TileIndex:    p.Position,
	}
	gs.BattleItemsReady = [2]bool{false, false}
}

func (gs *GameState) BattleItemSelect(slotIndex, itemID int) *ActionError {
	if gs.Phase != PhaseBattle {
		return errWrongPhase(PhaseBattle, gs.Phase)
	}
	if gs.PendingBattle == nil {
		return &ActionError{Code: "no_battle", Message: "no pending battle"}
	}

	if slotIndex == gs.PendingBattle.AttackerSlot {
		gs.PendingBattle.AttackerItemID = itemID
		gs.BattleItemsReady[0] = true
	} else if slotIndex == gs.PendingBattle.DefenderSlot {
		gs.PendingBattle.DefenderItemID = itemID
		gs.BattleItemsReady[1] = true
	} else {
		return &ActionError{Code: "not_in_battle", Message: "not a battle participant"}
	}
	return nil
}

func (gs *GameState) BattleBothReady() bool {
	return gs.BattleItemsReady[0] && gs.BattleItemsReady[1]
}
