package game

import (
	"fmt"

	"arcana-conquest-server/masterdata"
)

type ActionError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *ActionError) Error() string { return e.Message }

func errNotYourTurn() *ActionError {
	return &ActionError{Code: "not_your_turn", Message: "not your turn"}
}
func errWrongPhase(expected, actual Phase) *ActionError {
	return &ActionError{Code: "wrong_phase", Message: fmt.Sprintf("expected %s, got %s", expected, actual)}
}
func errCardNotInHand() *ActionError {
	return &ActionError{Code: "card_not_in_hand", Message: "card not in hand"}
}
func errInvalidTile() *ActionError {
	return &ActionError{Code: "invalid_tile", Message: "invalid tile"}
}
func errTileOccupied() *ActionError {
	return &ActionError{Code: "tile_occupied", Message: "tile already occupied"}
}
func errNotEnoughEP(need, have int) *ActionError {
	return &ActionError{Code: "not_enough_ep", Message: fmt.Sprintf("need %d EP, have %d", need, have)}
}

func (gs *GameState) ValidateActivePlayer(slotIndex int) *ActionError {
	if gs.ActivePlayer != slotIndex {
		return errNotYourTurn()
	}
	return nil
}

func (gs *GameState) ValidatePhase(expected Phase) *ActionError {
	if gs.Phase != expected {
		return errWrongPhase(expected, gs.Phase)
	}
	return nil
}

// SpellCast processes a spell cast action
func (gs *GameState) SpellCast(slotIndex, cardID, targetPlayer, targetTile int) *ActionError {
	if err := gs.ValidateActivePlayer(slotIndex); err != nil {
		return err
	}
	if err := gs.ValidatePhase(PhaseSpell); err != nil {
		return err
	}
	if !gs.hasCard(slotIndex, cardID) {
		return errCardNotInHand()
	}
	card := masterdata.GetCard(cardID)
	if card == nil || card.Type != "spell" {
		return &ActionError{Code: "invalid_card", Message: "not a spell card"}
	}

	gs.RemoveFromHand(slotIndex, cardID)
	// スペル効果の具体的な処理はカードデータに依存するため、
	// 将来的にカードマスタデータを読み込んで処理する
	gs.TransitionTo(PhaseDice)
	return nil
}

// SpellPass skips the spell phase
func (gs *GameState) SpellPass(slotIndex int) *ActionError {
	if err := gs.ValidateActivePlayer(slotIndex); err != nil {
		return err
	}
	if err := gs.ValidatePhase(PhaseSpell); err != nil {
		return err
	}
	gs.TransitionTo(PhaseDice)
	return nil
}

// DiceRoll performs dice roll (server-authoritative)
func (gs *GameState) DiceRoll(slotIndex int) (int, *ActionError) {
	if err := gs.ValidateActivePlayer(slotIndex); err != nil {
		return 0, err
	}
	if err := gs.ValidatePhase(PhaseDice); err != nil {
		return 0, err
	}
	result := gs.RollDice()
	gs.TransitionTo(PhaseMove)
	return result, nil
}

// MoveComplete processes movement direction choice
func (gs *GameState) MoveComplete(slotIndex, direction int) *ActionError {
	if err := gs.ValidateActivePlayer(slotIndex); err != nil {
		return err
	}
	if err := gs.ValidatePhase(PhaseMove); err != nil {
		return err
	}

	p := gs.ActivePlayerState()
	if p == nil {
		return errInvalidTile()
	}
	tileCount := len(gs.Board)
	if tileCount == 0 {
		return errInvalidTile()
	}

	newPos := (p.Position + gs.DiceResult) % tileCount
	if direction >= 0 && direction < tileCount {
		newPos = direction
	}
	p.Position = newPos

	if p.Position == 0 && gs.DiceResult > 0 {
		p.LapCount++
	}

	gs.TransitionAfterLanding(slotIndex)
	return nil
}

// Summon places a creature on the current tile
func (gs *GameState) Summon(slotIndex, cardID int) *ActionError {
	if err := gs.ValidateActivePlayer(slotIndex); err != nil {
		return err
	}
	if err := gs.ValidatePhase(PhaseTileAction); err != nil {
		return err
	}
	if !gs.hasCard(slotIndex, cardID) {
		return errCardNotInHand()
	}

	p := gs.ActivePlayerState()
	if p == nil {
		return errInvalidTile()
	}
	if p.Position < 0 || p.Position >= len(gs.Board) {
		return errInvalidTile()
	}
	tile := gs.Board[p.Position]
	if tile.OwnerIndex >= 0 {
		return errTileOccupied()
	}

	card := masterdata.GetCard(cardID)
	if card == nil || card.Type != "creature" {
		return &ActionError{Code: "invalid_card", Message: "not a creature card"}
	}

	gs.RemoveFromHand(slotIndex, cardID)
	tile.OwnerIndex = slotIndex
	tile.CreatureID = cardID
	tile.CreatureHP = card.HP
	tile.Level = 1
	tile.IsDown = !masterdata.HasKeyword(cardID, "奮闘")

	gs.TransitionTo(PhaseEndTurn)
	return nil
}

// DominioAction processes level up / move creature / swap commands
func (gs *GameState) DominioAction(slotIndex int, command string, sourceTile, targetTile int) *ActionError {
	if err := gs.ValidateActivePlayer(slotIndex); err != nil {
		return err
	}
	if err := gs.ValidatePhase(PhaseTileAction); err != nil {
		return err
	}

	switch command {
	case "level_up":
		return gs.levelUp(slotIndex, sourceTile)
	case "move_creature":
		return gs.moveCreature(slotIndex, sourceTile, targetTile)
	case "swap":
		return gs.swapCreature(slotIndex, sourceTile, targetTile)
	default:
		return &ActionError{Code: "invalid_command", Message: "unknown dominio command"}
	}
}

func (gs *GameState) levelUp(slotIndex, tileIdx int) *ActionError {
	if tileIdx < 0 || tileIdx >= len(gs.Board) {
		return errInvalidTile()
	}
	tile := gs.Board[tileIdx]
	if tile.OwnerIndex != slotIndex {
		return errInvalidTile()
	}
	if tile.IsDown {
		return &ActionError{Code: "tile_down", Message: "tile is down"}
	}

	cost := tile.Level * 100
	p := gs.Players[slotIndex]
	if p.EP < cost {
		return errNotEnoughEP(cost, p.EP)
	}

	p.EP -= cost
	tile.Level++
	tile.IsDown = true
	gs.TransitionTo(PhaseEndTurn)
	return nil
}

func (gs *GameState) moveCreature(slotIndex, src, dst int) *ActionError {
	if src < 0 || src >= len(gs.Board) || dst < 0 || dst >= len(gs.Board) {
		return errInvalidTile()
	}
	srcTile := gs.Board[src]
	dstTile := gs.Board[dst]

	if srcTile.OwnerIndex != slotIndex {
		return errInvalidTile()
	}
	if dstTile.OwnerIndex >= 0 {
		return errTileOccupied()
	}
	if srcTile.IsDown {
		return &ActionError{Code: "tile_down", Message: "source tile is down"}
	}

	dstTile.OwnerIndex = slotIndex
	dstTile.CreatureID = srcTile.CreatureID
	dstTile.CreatureHP = srcTile.CreatureHP
	dstTile.Level = srcTile.Level
	dstTile.IsDown = true

	srcTile.OwnerIndex = -1
	srcTile.CreatureID = 0
	srcTile.CreatureHP = 0
	srcTile.Level = 1
	srcTile.IsDown = false

	gs.TransitionTo(PhaseEndTurn)
	return nil
}

func (gs *GameState) swapCreature(slotIndex, src, dst int) *ActionError {
	if src < 0 || src >= len(gs.Board) || dst < 0 || dst >= len(gs.Board) {
		return errInvalidTile()
	}
	srcTile := gs.Board[src]
	dstTile := gs.Board[dst]

	if srcTile.OwnerIndex != slotIndex || dstTile.OwnerIndex != slotIndex {
		return errInvalidTile()
	}
	if srcTile.IsDown || dstTile.IsDown {
		return &ActionError{Code: "tile_down", Message: "cannot swap down tiles"}
	}

	srcTile.CreatureID, dstTile.CreatureID = dstTile.CreatureID, srcTile.CreatureID
	srcTile.CreatureHP, dstTile.CreatureHP = dstTile.CreatureHP, srcTile.CreatureHP
	srcTile.IsDown = true
	dstTile.IsDown = true

	gs.TransitionTo(PhaseEndTurn)
	return nil
}

// Pass skips the current phase action
func (gs *GameState) Pass(slotIndex int) *ActionError {
	if err := gs.ValidateActivePlayer(slotIndex); err != nil {
		return err
	}
	switch gs.Phase {
	case PhaseSpell:
		gs.TransitionTo(PhaseDice)
	case PhaseTileAction:
		gs.TransitionTo(PhaseEndTurn)
	default:
		return errWrongPhase(PhaseSpell, gs.Phase)
	}
	return nil
}

// EndTurn advances to the next player's turn
func (gs *GameState) EndTurn(slotIndex int) (winner int, finished bool, err *ActionError) {
	if e := gs.ValidateActivePlayer(slotIndex); e != nil {
		return -1, false, e
	}
	if e := gs.ValidatePhase(PhaseEndTurn); e != nil {
		return -1, false, e
	}

	// ダウン状態の解除
	for _, tile := range gs.Board {
		if tile.OwnerIndex == slotIndex {
			tile.IsDown = false
		}
	}

	// 勝利条件チェック
	if w := gs.CheckWinCondition(); w >= 0 {
		gs.Finished = true
		gs.assignRanks(w)
		return w, true, nil
	}

	// 最大ターンチェック
	gs.TotalTurns++
	if gs.CheckMaxTurns() {
		gs.Finished = true
		gs.assignRanksByTEP()
		for _, p := range gs.Players {
			if p.FinalRank == 1 {
				return p.SlotIndex, true, nil
			}
		}
		return -1, true, nil
	}

	// 次プレイヤー
	next := gs.NextAlivePlayer()
	if next < 0 {
		gs.Finished = true
		return -1, true, nil
	}

	if next <= gs.ActivePlayer {
		gs.CurrentTurn++
	}
	gs.ActivePlayer = next
	gs.TransitionTo(PhaseSpell)

	// ドロー
	gs.DrawCard(next)

	return -1, false, nil
}

func (gs *GameState) assignRanks(winnerIdx int) {
	gs.Players[winnerIdx].FinalRank = 1
	type tepEntry struct {
		idx int
		tep int
	}
	var others []tepEntry
	for i := range gs.Players {
		if i != winnerIdx {
			others = append(others, tepEntry{i, gs.CalculateTEP(i)})
		}
	}
	// TEP降順ソート
	for i := 0; i < len(others); i++ {
		for j := i + 1; j < len(others); j++ {
			if others[j].tep > others[i].tep {
				others[i], others[j] = others[j], others[i]
			}
		}
	}
	for rank, e := range others {
		gs.Players[e.idx].FinalRank = rank + 2
	}
}

func (gs *GameState) assignRanksByTEP() {
	type tepEntry struct {
		idx   int
		tep   int
		ep    int
		tiles int
	}
	var entries []tepEntry
	for i, p := range gs.Players {
		tileCount := 0
		for _, t := range gs.Board {
			if t.OwnerIndex == i {
				tileCount++
			}
		}
		entries = append(entries, tepEntry{i, gs.CalculateTEP(i), p.EP, tileCount})
	}
	// Tie-break: TEP → EP → 所持タイル数
	for i := 0; i < len(entries); i++ {
		for j := i + 1; j < len(entries); j++ {
			swap := false
			if entries[j].tep > entries[i].tep {
				swap = true
			} else if entries[j].tep == entries[i].tep {
				if entries[j].ep > entries[i].ep {
					swap = true
				} else if entries[j].ep == entries[i].ep && entries[j].tiles > entries[i].tiles {
					swap = true
				}
			}
			if swap {
				entries[i], entries[j] = entries[j], entries[i]
			}
		}
	}
	for rank, e := range entries {
		gs.Players[e.idx].FinalRank = rank + 1
	}
}

func (gs *GameState) hasCard(slotIndex, cardID int) bool {
	p := gs.Players[slotIndex]
	for _, c := range p.Hand {
		if c == cardID {
			return true
		}
	}
	return false
}
