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

// Summon: 薄型リレー方式ではタイル状態（HP初期値・IsDown・奮闘スキル判定）は
// クライアント計算に委譲し、結果を action_result_report で受信する（Phase 2）。
// サーバー側は所有権・手札所持検証と手札消費のみ行う。
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
	// card type / HP / 奮闘キーワード判定はクライアント計算結果を待つため削除。
	// 手札からの消費のみ行う（カードを使った事実は記録）。
	gs.RemoveFromHand(slotIndex, cardID)
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

// levelUp / moveCreature / swapCreature: 薄型リレー方式ではクライアントが
// コスト計算・タイル状態更新を行い、結果を action_result_report で送信する（Phase 2）。
// 現在は最小限の所有権検証のみ実施し、フェーズ遷移で進行を止めないようにする。
// 実際の EP 消費・タイル状態変更・レベル更新はクライアント報告受信時に反映予定。

// 薄型リレー方式では Board の OwnerIndex / IsDown / Level 等はクライアント側が権威。
// サーバーは状態を更新していないため所有権・ダウン状態の検証はできない。
// タイル範囲のみを検証し、クライアント計算結果を信頼して PhaseEndTurn に遷移する。
func (gs *GameState) levelUp(slotIndex, tileIdx int) *ActionError {
	_ = slotIndex
	if tileIdx < 0 || tileIdx >= len(gs.Board) {
		return errInvalidTile()
	}
	gs.TransitionTo(PhaseEndTurn)
	return nil
}

func (gs *GameState) moveCreature(slotIndex, src, dst int) *ActionError {
	_ = slotIndex
	if src < 0 || src >= len(gs.Board) || dst < 0 || dst >= len(gs.Board) {
		return errInvalidTile()
	}
	gs.TransitionTo(PhaseEndTurn)
	return nil
}

func (gs *GameState) swapCreature(slotIndex, src, dst int) *ActionError {
	_ = slotIndex
	if src < 0 || src >= len(gs.Board) || dst < 0 || dst >= len(gs.Board) {
		return errInvalidTile()
	}
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
	case PhaseEndTurn:
		// 薄型リレー: summon/dominio_action が server 側で既に PhaseEndTurn に
		// 遷移させた後、クライアントから届く pass は no-op として扱う
		// （旧設計では errWrongPhase になっていたが、クライアントの意図は
		//  「タイル着地アクション完了」の通知なので冪等に許可する）
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
