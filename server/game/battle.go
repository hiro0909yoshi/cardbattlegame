package game

import "arcana-conquest-server/masterdata"

type BattleResult struct {
	AttackerSlot int  `json:"attacker_slot"`
	DefenderSlot int  `json:"defender_slot"`
	AttackerHP   int  `json:"attacker_hp"`
	DefenderHP   int  `json:"defender_hp"`
	AttackerWon  bool `json:"attacker_won"`
	AttackerDead bool `json:"attacker_dead"`
	DefenderDead bool `json:"defender_dead"`
	DamageDealt  int  `json:"damage_dealt"`
	DamageTaken  int  `json:"damage_taken"`
}

type BattleContext struct {
	AttackerSlot    int
	DefenderSlot    int
	TileIndex       int
	AttackerItemID  int
	DefenderItemID  int
}

func (gs *GameState) ResolveBattle(ctx BattleContext) *BattleResult {
	if ctx.TileIndex < 0 || ctx.TileIndex >= len(gs.Board) {
		return nil
	}
	if ctx.AttackerSlot < 0 || ctx.AttackerSlot >= len(gs.Players) ||
		ctx.DefenderSlot < 0 || ctx.DefenderSlot >= len(gs.Players) {
		return nil
	}
	tile := gs.Board[ctx.TileIndex]

	// 攻撃者（侵入者）のクリーチャーは手札から使ったカード
	// ここでは現在位置のタイルに攻撃者がいる想定
	attackerCard := gs.getAttackerCard(ctx.AttackerSlot)
	defenderCard := masterdata.GetCard(tile.CreatureID)

	if attackerCard == nil || defenderCard == nil {
		return nil
	}

	// 基本ステータス
	atkAP := attackerCard.AP
	atkHP := attackerCard.HP
	defAP := defenderCard.AP
	defHP := tile.CreatureHP

	// 地形ボーナス（防御側）
	landBonus := tile.Level * 10
	defHP += landBonus

	// アイテムボーナス
	if ctx.AttackerItemID > 0 {
		bonus := masterdata.GetItemStatBonus(ctx.AttackerItemID)
		atkAP += bonus.AP
		atkHP += bonus.HP
	}
	if ctx.DefenderItemID > 0 {
		bonus := masterdata.GetItemStatBonus(ctx.DefenderItemID)
		defAP += bonus.AP
		defHP += bonus.HP
	}

	// ダメージ計算: 同時攻撃
	defHP -= atkAP
	atkHP -= defAP

	if defHP < 0 {
		defHP = 0
	}
	if atkHP < 0 {
		atkHP = 0
	}

	result := &BattleResult{
		AttackerSlot: ctx.AttackerSlot,
		DefenderSlot: ctx.DefenderSlot,
		AttackerHP:   atkHP,
		DefenderHP:   defHP,
		DamageDealt:  atkAP,
		DamageTaken:  defAP,
	}

	// 勝敗判定
	if defHP <= 0 && atkHP > 0 {
		// 攻撃側勝利 → タイル奪取
		result.AttackerWon = true
		result.DefenderDead = true
		tile.OwnerIndex = ctx.AttackerSlot
		tile.CreatureID = attackerCard.ID
		tile.CreatureHP = atkHP
		tile.Level = 1
		tile.IsDown = true
	} else if atkHP <= 0 {
		// 防���側勝利（相討ちも防御側有利）
		result.AttackerDead = true
		tile.CreatureHP = defHP
	} else {
		// 両者生存 → 防御側残留、攻撃���は通過
		tile.CreatureHP = defHP
	}

	// 通行料（防御側勝利時）
	if !result.AttackerWon && !result.DefenderDead {
		toll := tile.Level * 100
		attacker := gs.Players[ctx.AttackerSlot]
		defender := gs.Players[ctx.DefenderSlot]
		if attacker.EP < toll {
			toll = attacker.EP
		}
		attacker.EP -= toll
		defender.EP += toll
	}

	gs.StateVersion++
	return result
}

func (gs *GameState) getAttackerCard(slotIndex int) *masterdata.Card {
	if slotIndex < 0 || slotIndex >= len(gs.Players) {
		return nil
	}
	p := gs.Players[slotIndex]
	for _, cardID := range p.Hand {
		if masterdata.IsCreature(cardID) {
			return masterdata.GetCard(cardID)
		}
	}
	return nil
}
