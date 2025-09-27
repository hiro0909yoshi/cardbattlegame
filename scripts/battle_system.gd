extends Node
class_name BattleSystem

# バトル管理システム - GameConstants対応版

signal battle_started(attacker: Dictionary, defender: Dictionary)
signal battle_ended(winner: String, result: Dictionary)
signal battle_animation_finished()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

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
func execute_invasion_battle(attacker_player_id: int, attacker_hand_index: int, tile_info: Dictionary, card_system: CardSystem, board_system) -> Dictionary:
	# 攻撃側のクリーチャーを手札から取得
	var attacker_data = card_system.get_card_data_for_player(attacker_player_id, attacker_hand_index)
	if attacker_data.is_empty():
		return {"success": false, "reason": "invalid_card"}
	
	# 防御側のクリーチャーを取得
	var defender_data = tile_info.get("creature", {})
	if defender_data.is_empty():
		return {"success": false, "reason": "no_defender"}
	
	print("\n========== バトル開始 ==========")
	print("攻撃側: ", attacker_data.get("name", "不明"), " [", attacker_data.get("element", "?"), "]")
	print("防御側: ", defender_data.get("name", "不明"), " [", defender_data.get("element", "?"), "]")
	
	# 防御側の土地所有者IDを取得
	var defender_player_id = tile_info.get("owner", -1)
	
	# ボーナスを個別に計算（ST用とHP用を分離）
	var attacker_bonuses = calculate_creature_bonuses(attacker_data, defender_data, tile_info, true, attacker_player_id, board_system)
	var defender_bonuses = calculate_creature_bonuses(defender_data, attacker_data, tile_info, false, defender_player_id, board_system)
	
	# 最終的な能力値（STとHPに別々のボーナスを適用）
	var final_attacker_st = attacker_data.get("damage", 0) + attacker_bonuses.st_bonus
	var final_attacker_hp = attacker_data.get("block", 0) + attacker_bonuses.hp_bonus
	var final_defender_st = defender_data.get("damage", 0) + defender_bonuses.st_bonus
	var final_defender_hp = defender_data.get("block", 0) + defender_bonuses.hp_bonus
	
	print("攻撃側: ST=", attacker_data.get("damage", 0), "+", attacker_bonuses.st_bonus, "=", final_attacker_st, 
		  " HP=", attacker_data.get("block", 0), "+", attacker_bonuses.hp_bonus, "=", final_attacker_hp)
	print("防御側: ST=", defender_data.get("damage", 0), "+", defender_bonuses.st_bonus, "=", final_defender_st,
		  " HP=", defender_data.get("block", 0), "+", defender_bonuses.hp_bonus, "=", final_defender_hp)
	
	# 先制攻撃を考慮したバトル判定
	var result = determine_battle_result_with_priority(
		final_attacker_st, 
		final_attacker_hp,
		final_defender_st,
		final_defender_hp
	)
	
	# 結果処理
	var battle_outcome = {
		"success": true,
		"winner": result.winner,
		"attacker_st": final_attacker_st,
		"defender_hp": final_defender_hp,
		"damage": abs(final_attacker_st - final_defender_hp),
		"land_captured": false,
		"creature_destroyed": false,
		"battle_type": result.get("battle_type", "normal")
	}
	
	var tile_index = tile_info.get("index", 0)
	
	if result.winner == "attacker":
		print(">>> 攻撃側の勝利！土地を獲得！")
		battle_outcome.land_captured = true
		battle_outcome.creature_destroyed = true
		# 土地の所有者を変更
		board_system.set_tile_owner(tile_index, attacker_player_id)
		# 防御側クリーチャーを削除して攻撃側を配置（生存している場合）
		if result.get("attacker_survives", true):
			board_system.place_creature(tile_index, attacker_data)
		else:
			board_system.place_creature(tile_index, {})  # 攻撃側も死亡
			
	elif result.winner == "defender":
		print(">>> 防御側の勝利！土地を守った！")
		# 攻撃側クリーチャーは消滅（手札から使用済み）
		# 防御側はそのまま残る
		
	else:  # 引き分け
		if result.get("battle_type", "") == "mutual_destruction":
			# 相討ち型：両者倒れるが土地は獲得
			print(">>> 相討ち！攻撃側が土地を獲得！")
			battle_outcome.land_captured = true
			battle_outcome.creature_destroyed = true
			battle_outcome.winner = "draw_capture"
			board_system.set_tile_owner(tile_index, attacker_player_id)
			board_system.place_creature(tile_index, {})  # 両者消滅
		else:
			# 膠着型：決着つかず
			print(">>> 膠着状態！土地は取れず...")
			battle_outcome.winner = "draw_stalemate"
			# 防御側クリーチャーはそのまま残る
	
	print("================================\n")
	
	emit_signal("battle_ended", result.winner, battle_outcome)
	return battle_outcome

# クリーチャーのボーナスを計算（属性連鎖HPボーナス対応）
func calculate_creature_bonuses(creature: Dictionary, opponent: Dictionary, tile_info: Dictionary, is_attacker: bool, player_id: int, board_system, silent: bool = false) -> Dictionary:
	var bonuses = {
		"st_bonus": 0,
		"hp_bonus": 0
	}
	
	# 1. 地形効果（HPボーナス - 属性連鎖対応）
	var tile_element = tile_info.get("element", "")
	var tile_index = tile_info.get("index", 0)
	
	if creature.get("element", "") == tile_element and tile_element != "":
		# 属性連鎖数を取得（board_systemの新しい関数を使用）
		var chain_count = 1  # デフォルト値
		if board_system and board_system.has_method("get_element_chain_count"):
			chain_count = board_system.get_element_chain_count(tile_index, player_id)
		
		# 連鎖数に応じたHPボーナス（GameConstantsから取得）
		var hp_bonus_value = 0
		if chain_count >= 4:
			hp_bonus_value = GameConstants.TERRAIN_BONUS_4
		elif chain_count == 3:
			hp_bonus_value = GameConstants.TERRAIN_BONUS_3
		elif chain_count == 2:
			hp_bonus_value = GameConstants.TERRAIN_BONUS_2
		elif chain_count == 1:
			hp_bonus_value = GameConstants.TERRAIN_BONUS_1
		
		bonuses.hp_bonus += hp_bonus_value
		
		# サイレントモードでなければログ出力
		if not silent:
			var role = "攻撃側" if is_attacker else "防御側"
			print("  ", role, ": 地形ボーナス HP+", hp_bonus_value, " (", tile_element, "属性×", chain_count, "個)")
	
	# 2. 属性相性（STにのみ適用）
	var advantage = calculate_element_advantage(
		creature.get("element", ""), 
		opponent.get("element", "")
	)
	if advantage > 0:
		bonuses.st_bonus += advantage
		# サイレントモードでなければログ出力
		if not silent:
			var role = "攻撃側" if is_attacker else "防御側"
			print("  ", role, ": 属性相性ボーナス ST+", advantage, " (", 
				  creature.get("element", ""), "→", opponent.get("element", ""), ")")
	
	return bonuses

# 属性相性を計算
func calculate_element_advantage(attacker_element: String, defender_element: String) -> int:
	if not element_advantages.has(attacker_element):
		return 0
	
	# 有利属性ならGameConstantsから値を取得
	if element_advantages[attacker_element] == defender_element:
		return GameConstants.ELEMENT_ADVANTAGE
	
	return 0

# 先制攻撃を考慮したバトル結果を判定
func determine_battle_result_with_priority(attacker_st: int, attacker_hp: int, defender_st: int, defender_hp: int) -> Dictionary:
	var result = {
		"winner": "",
		"result_type": BattleResult.DRAW,
		"attacker_survives": false,
		"defender_survives": false,
		"battle_type": "normal"
	}
	
	# 1. 攻撃側の先制攻撃
	print("  [先制攻撃] 攻撃側ST(", attacker_st, ") vs 防御側HP(", defender_hp, ")")
	if attacker_st >= defender_hp:
		# 防御側が倒れる
		print("  → 防御側クリーチャー撃破！")
		result.defender_survives = false
		result.attacker_survives = true
		result.winner = "attacker"
		result.result_type = BattleResult.ATTACKER_WIN
		result.battle_type = "normal"
		return result
	else:
		print("  → 防御側生存（残HP: ", defender_hp - attacker_st, "）")
		result.defender_survives = true
	
	# 2. 防御側の反撃（生き残った場合のみ）
	print("  [反撃] 防御側ST(", defender_st, ") vs 攻撃側HP(", attacker_hp, ")")
	if defender_st >= attacker_hp:
		# 攻撃側が倒れる
		print("  → 攻撃側クリーチャー撃破！")
		result.attacker_survives = false
		result.winner = "defender"
		result.result_type = BattleResult.DEFENDER_WIN
		result.battle_type = "normal"
	else:
		print("  → 攻撃側生存（残HP: ", attacker_hp - defender_st, "）")
		result.attacker_survives = true
		
		# 両者生存 = 膠着状態
		if attacker_st == 0 and defender_st == 0:
			result.winner = "draw"
			result.result_type = BattleResult.DRAW
			result.battle_type = "stalemate"
			print("  → 膠着状態（両者攻撃力なし）")
		else:
			# 通常は起こらないが、両者生存で決着つかず
			result.winner = "draw"
			result.result_type = BattleResult.DRAW
			result.battle_type = "stalemate"
			print("  → 決着つかず")
	
	return result

# バトル予測（UI表示用）
func predict_battle_outcome(attacker: Dictionary, defender: Dictionary, tile: Dictionary) -> Dictionary:
	# 仮のプレイヤーIDを使用（実際のバトル時には正しいIDが渡される）
	var attacker_player_id = 0
	var defender_player_id = tile.get("owner", -1)
	
	# BoardSystemへの参照を取得
	var board_system = get_tree().get_root().get_node_or_null("Game/BoardSystem")
	
	# ボーナスを個別に計算
	var attacker_bonuses = calculate_creature_bonuses(attacker, defender, tile, true, attacker_player_id, board_system, true)
	var defender_bonuses = calculate_creature_bonuses(defender, attacker, tile, false, defender_player_id, board_system, true)
	
	var prediction = {
		"attacker_st": attacker.get("damage", 0) + attacker_bonuses.st_bonus,
		"attacker_hp": attacker.get("block", 0) + attacker_bonuses.hp_bonus,
		"defender_st": defender.get("damage", 0) + defender_bonuses.st_bonus,
		"defender_hp": defender.get("block", 0) + defender_bonuses.hp_bonus,
		"attacker_st_bonus": attacker_bonuses.st_bonus,
		"attacker_hp_bonus": attacker_bonuses.hp_bonus,
		"defender_st_bonus": defender_bonuses.st_bonus,
		"defender_hp_bonus": defender_bonuses.hp_bonus,
		"likely_winner": ""
	}
	
	# 先制攻撃を考慮した予測
	if prediction.attacker_st >= prediction.defender_hp:
		prediction.likely_winner = "attacker"
	elif prediction.defender_st >= prediction.attacker_hp:
		prediction.likely_winner = "defender"
	else:
		prediction.likely_winner = "draw"
	
	return prediction
