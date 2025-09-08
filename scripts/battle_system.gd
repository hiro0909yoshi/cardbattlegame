extends Node
class_name BattleSystem

# バトル管理システム - 実装版

signal battle_started(attacker: Dictionary, defender: Dictionary)
signal battle_ended(winner: String, result: Dictionary)
signal battle_animation_finished()

# バトル結果
enum BattleResult {
	ATTACKER_WIN,
	DEFENDER_WIN,
	DRAW
}

# 属性相性テーブル（火→風→土→水→火）
var element_advantages = {
	"火": "風",
	"風": "土", 
	"土": "水",
	"水": "火"
}

func _ready():
	pass

# 侵略バトルを実行（メインバトル処理）
func execute_invasion_battle(attacker_player_id: int, attacker_hand_index: int, tile_info: Dictionary, card_system: CardSystem, board_system: BoardSystem) -> Dictionary:
	# 攻撃側のクリーチャーを手札から取得
	var attacker_data = card_system.get_card_data_for_player(attacker_player_id, attacker_hand_index)
	if attacker_data.is_empty():
		return {"success": false, "reason": "invalid_card"}
	
	# 防御側のクリーチャーを取得
	var defender_data = tile_info.creature
	if defender_data.is_empty():
		return {"success": false, "reason": "no_defender"}
	
	print("\n========== バトル開始 ==========")
	print("攻撃側: ", attacker_data.name, " [", attacker_data.element, "]")
	print("防御側: ", defender_data.name, " [", defender_data.element, "]")
	
	# 地形効果と属性相性を計算
	var battle_modifiers = calculate_all_modifiers(attacker_data, defender_data, tile_info)
	
	# 最終的な能力値
	var final_attacker_st = attacker_data.damage + battle_modifiers.attacker_bonus
	var final_defender_hp = defender_data.block + battle_modifiers.defender_bonus
	
	print("攻撃側ST: ", attacker_data.damage, " + ", battle_modifiers.attacker_bonus, " = ", final_attacker_st)
	print("防御側HP: ", defender_data.block, " + ", battle_modifiers.defender_bonus, " = ", final_defender_hp)
	
	# バトル判定
	var result = determine_battle_result(final_attacker_st, final_defender_hp)
	
	# 結果処理
	var battle_outcome = {
		"success": true,
		"winner": result.winner,
		"attacker_st": final_attacker_st,
		"defender_hp": final_defender_hp,
		"damage": abs(final_attacker_st - final_defender_hp),
		"land_captured": false,
		"creature_destroyed": false
	}
	
	if result.winner == "attacker":
		print(">>> 攻撃側の勝利！")
		battle_outcome.land_captured = true
		battle_outcome.creature_destroyed = true
		# 土地の所有者を変更
		board_system.set_tile_owner(tile_info.index, attacker_player_id)
		# 防御側クリーチャーを削除して攻撃側を配置
		board_system.place_creature(tile_info.index, attacker_data)
	elif result.winner == "defender":
		print(">>> 防御側の勝利！")
		# 攻撃側クリーチャーは消滅（手札から使用済み）
	else:
		print(">>> 引き分け！")
		battle_outcome.creature_destroyed = true
		# 両方消滅
		board_system.place_creature(tile_info.index, {})
	
	print("================================\n")
	
	emit_signal("battle_ended", result.winner, battle_outcome)
	return battle_outcome

# すべての修正値を計算
func calculate_all_modifiers(attacker: Dictionary, defender: Dictionary, tile_info: Dictionary) -> Dictionary:
	var modifiers = {
		"attacker_bonus": 0,
		"defender_bonus": 0
	}
	
	# 1. 地形効果（属性一致ボーナス）
	if attacker.element == tile_info.element:
		modifiers.attacker_bonus += 10
		print("  攻撃側: 地形ボーナス +10 (", tile_info.element, "属性)")
	
	if defender.element == tile_info.element:
		modifiers.defender_bonus += 10
		print("  防御側: 地形ボーナス +10 (", tile_info.element, "属性)")
	
	# 2. 属性相性ボーナス
	var attacker_advantage = calculate_element_advantage(attacker.element, defender.element)
	var defender_advantage = calculate_element_advantage(defender.element, attacker.element)
	
	if attacker_advantage > 0:
		modifiers.attacker_bonus += attacker_advantage
		print("  攻撃側: 属性相性ボーナス +", attacker_advantage, " (", attacker.element, "→", defender.element, ")")
	
	if defender_advantage > 0:
		modifiers.defender_bonus += defender_advantage
		print("  防御側: 属性相性ボーナス +", defender_advantage, " (", defender.element, "→", attacker.element, ")")
	
	return modifiers

# 属性相性を計算
func calculate_element_advantage(attacker_element: String, defender_element: String) -> int:
	if not element_advantages.has(attacker_element):
		return 0
	
	# 有利属性なら+20
	if element_advantages[attacker_element] == defender_element:
		return 20
	
	return 0

# バトル結果を判定
func determine_battle_result(attacker_st: int, defender_hp: int) -> Dictionary:
	var result = {
		"winner": "",
		"result_type": BattleResult.DRAW
	}
	
	if attacker_st > defender_hp:
		result.winner = "attacker"
		result.result_type = BattleResult.ATTACKER_WIN
	elif defender_hp > attacker_st:
		result.winner = "defender" 
		result.result_type = BattleResult.DEFENDER_WIN
	else:
		result.winner = "draw"
		result.result_type = BattleResult.DRAW
	
	return result

# バトル予測（UI表示用）
func predict_battle_outcome(attacker: Dictionary, defender: Dictionary, tile: Dictionary) -> Dictionary:
	var modifiers = calculate_all_modifiers(attacker, defender, tile)
	
	var prediction = {
		"attacker_st": attacker.damage + modifiers.attacker_bonus,
		"defender_hp": defender.block + modifiers.defender_bonus,
		"attacker_bonus": modifiers.attacker_bonus,
		"defender_bonus": modifiers.defender_bonus,
		"likely_winner": ""
	}
	
	if prediction.attacker_st > prediction.defender_hp:
		prediction.likely_winner = "attacker"
	elif prediction.defender_hp > prediction.attacker_st:
		prediction.likely_winner = "defender"
	else:
		prediction.likely_winner = "draw"
	
	return prediction

# 通常バトル（手札を使わない戦闘用）
func execute_normal_battle(attacker_data: Dictionary, defender_data: Dictionary, tile_info: Dictionary) -> Dictionary:
	emit_signal("battle_started", attacker_data, defender_data)
	
	print("\n========== バトル開始 ==========")
	print("攻撃側: ", attacker_data.name, " [", attacker_data.element, "]")
	print("防御側: ", defender_data.name, " [", defender_data.element, "]")
	
	# 地形効果と属性相性を計算
	var battle_modifiers = calculate_all_modifiers(attacker_data, defender_data, tile_info)
	
	# 最終的な能力値
	var final_attacker_st = attacker_data.damage + battle_modifiers.attacker_bonus
	var final_defender_hp = defender_data.block + battle_modifiers.defender_bonus
	
	print("最終ST: ", final_attacker_st, " vs 最終HP: ", final_defender_hp)
	
	# バトル判定
	var result = determine_battle_result(final_attacker_st, final_defender_hp)
	
	var battle_outcome = {
		"winner": result.winner,
		"damage": abs(final_attacker_st - final_defender_hp),
		"result_type": result.result_type
	}
	
	print("================================\n")
	
	emit_signal("battle_ended", result.winner, battle_outcome)
	return battle_outcome
