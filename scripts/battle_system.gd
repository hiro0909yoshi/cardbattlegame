extends Node
class_name BattleSystem

# バトル管理システム - 2D/3D統合版

signal battle_started(attacker: Dictionary, defender: Dictionary)
signal battle_ended(winner: String, result: Dictionary)
signal battle_animation_finished()
signal invasion_completed(success: bool, tile_index: int)

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

# システム参照（3D対応）
var board_system_ref = null  # BoardSystem2D or BoardSystem3D
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null

func _ready():
	pass

# システム参照を設定（3D対応）
func setup_systems(board_system, card_system: CardSystem, player_system: PlayerSystem):
	board_system_ref = board_system
	card_system_ref = card_system
	player_system_ref = player_system

# === 3D版統合処理 ===

# バトル実行（3D版メイン処理）
func execute_3d_battle(attacker_index: int, card_index: int, tile_info: Dictionary) -> void:
	if not validate_systems():
		print("Error: システム参照が設定されていません")
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# カードインデックスが-1の場合は通行料支払い
	if card_index < 0:
		pay_toll_3d(attacker_index, tile_info)
		return
	
	var card_data = card_system_ref.get_card_data_for_player(attacker_index, card_index)
	if card_data.is_empty():
		pay_toll_3d(attacker_index, tile_info)
		return
	
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system_ref.get_current_player()
	
	if current_player.magic_power < cost:
		pay_toll_3d(attacker_index, tile_info)
		return
	
	# カード使用
	card_system_ref.use_card_for_player(attacker_index, card_index)
	player_system_ref.add_magic(attacker_index, -cost)
	
	# 防御クリーチャーがいない場合（侵略）
	if tile_info.get("creature", {}).is_empty():
		execute_invasion_3d(attacker_index, card_data, tile_info)
		return
	
	# スキルシステムを使った戦闘処理
	var effect_combat = load("res://scripts/skills/effect_combat.gd").new()
	var condition_checker = load("res://scripts/skills/condition_checker.gd").new()
	
	# プレイヤーの土地所有状況を取得
	var player_lands = {"火": 0, "水": 0, "地": 0, "風": 0}
	if board_system_ref and board_system_ref.has_method("get_player_lands_by_element"):
		player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
	else:
		# デバッグ用：全属性を持っていることにする
		print("【デバッグ】土地データ取得不可、テスト用に全属性保有とする")
		player_lands = {"火": 1, "水": 1, "地": 1, "風": 1}
	
	print("  プレイヤー土地: ", player_lands)
	
	# 戦闘コンテキストの構築
	var defender_creature = tile_info.get("creature", {})
	var battle_context = ConditionChecker.build_battle_context(
		card_data, 
		defender_creature,
		tile_info,
		{"player_lands": player_lands}
	)
	
	# 強打などの効果を適用
	var modified_attacker = effect_combat.apply_power_strike(card_data, battle_context)
	
	# 強打が適用されたか確認
	if modified_attacker.get("power_strike_applied", false):
		print("【強打発動！】AP: ", card_data.get("ap", 0), " → ", modified_attacker.get("ap", 0))
	
	# 修正後のステータスを使用
	var attacker_st = modified_attacker.get("ap", 0)
	var defender_hp = defender_creature.get("hp", 0)
	
	print("========== バトル開始 ==========")
	print("攻撃側: ", card_data.get("name", "不明"), " [", card_data.get("element", "?"), "]")
	print("  基本AP: ", card_data.get("ap", 0), " HP: ", card_data.get("hp", 0))
	print("  ability_parsed: ", card_data.get("ability_parsed", {}))
	print("防御側: ", tile_info.get("creature", {}).get("name", "不明"), " [", tile_info.get("creature", {}).get("element", "?"), "]")
	print("攻撃側AP: ", attacker_st, " vs 防御側HP: ", defender_hp)
	
	if attacker_st >= defender_hp:
		print(">>> 攻撃側の勝利！土地を獲得！")
		# 土地を奪取
		board_system_ref.set_tile_owner(tile_info["index"], attacker_index)
		board_system_ref.place_creature(tile_info["index"], card_data)
		
		# 表示更新
		if board_system_ref.has_method("update_all_tile_displays"):
			board_system_ref.update_all_tile_displays()
	else:
		print(">>> 防御側の勝利！土地を守った！")
	
	print("================================")
	
	# バトル終了シグナルを発行
	emit_signal("invasion_completed", attacker_st >= defender_hp, tile_info["index"])

# 侵略処理（防御クリーチャーなし）
func execute_invasion_3d(attacker_index: int, card_data: Dictionary, tile_info: Dictionary):
	print("侵略成功！土地を奪取")
	
	# 土地を奪取
	board_system_ref.set_tile_owner(tile_info["index"], attacker_index)
	board_system_ref.place_creature(tile_info["index"], card_data)
	
	# UI更新
	if board_system_ref.has_method("update_all_tile_displays"):
		board_system_ref.update_all_tile_displays()
	
	emit_signal("invasion_completed", true, tile_info["index"])

# クリーチャーとのバトル処理
func execute_battle_with_creature_3d(attacker_index: int, attacker_data: Dictionary, tile_info: Dictionary):
	var defender_data = tile_info["creature"]
	
	print("\n========== バトル開始 ==========")
	print("攻撃側: ", attacker_data.get("name", "不明"), " [", attacker_data.get("element", "?"), "]")
	print("防御側: ", defender_data.get("name", "不明"), " [", defender_data.get("element", "?"), "]")
	
	# バトル結果を既存のシステムで計算
	var result = execute_invasion_battle(attacker_index, -1, tile_info, card_system_ref, board_system_ref)
	
	# 結果に基づいて処理（既にexecute_invasion_battleで処理済みなので、ここでは通知のみ）
	var success = result.get("land_captured", false)
	emit_signal("invasion_completed", success, tile_info["index"])

# 通行料支払い（3D版）
func pay_toll_3d(payer_index: int, tile_info: Dictionary):
	var toll = board_system_ref.calculate_toll(tile_info["index"])
	var receiver_id = tile_info["owner"]
	
	if receiver_id >= 0 and receiver_id < player_system_ref.players.size():
		player_system_ref.pay_toll(payer_index, receiver_id, toll)
		print("通行料 ", toll, "G を支払いました")
	
	emit_signal("invasion_completed", false, tile_info["index"])

# システム検証
func validate_systems() -> bool:
	return board_system_ref != null and card_system_ref != null and player_system_ref != null

# === 既存の2D版処理（保持） ===

# 侵略バトルを実行（メインバトル処理）
func execute_invasion_battle(attacker_player_id: int, attacker_hand_index: int, tile_info: Dictionary, card_system: CardSystem, board_system) -> Dictionary:
	# 攻撃側のクリーチャーを取得
	var attacker_data: Dictionary
	if attacker_hand_index >= 0:
		# 手札から取得（2D版）
		attacker_data = card_system.get_card_data_for_player(attacker_player_id, attacker_hand_index)
	else:
		# 既に使用済みのカード（3D版での呼び出し）
		# tile_infoから最後に使用されたカード情報を取得する必要があるが、
		# 3D版では既にカードは使用済みなので、別の方法で渡す必要がある
		# ここでは簡易的に空を返す（3D版は別ルートで処理）
		return {"success": false, "reason": "invalid_card"}
	
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
	var final_attacker_st = attacker_data.get("ap", 0) + attacker_bonuses.st_bonus  # damage -> ap
	var final_attacker_hp = attacker_data.get("hp", 0) + attacker_bonuses.hp_bonus  # block -> hp
	var final_defender_st = defender_data.get("ap", 0) + defender_bonuses.st_bonus  # damage -> ap
	var final_defender_hp = defender_data.get("hp", 0) + defender_bonuses.hp_bonus  # block -> hp
	
	print("攻撃側: AP=", attacker_data.get("ap", 0), "+", attacker_bonuses.st_bonus, "=", final_attacker_st, 
		  " HP=", attacker_data.get("hp", 0), "+", attacker_bonuses.hp_bonus, "=", final_attacker_hp)
	print("防御側: AP=", defender_data.get("ap", 0), "+", defender_bonuses.st_bonus, "=", final_defender_st,
		  " HP=", defender_data.get("hp", 0), "+", defender_bonuses.hp_bonus, "=", final_defender_hp)
	
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
		"damage": abs(final_attacker_st - final_defender_hp),  # TODO: これも後でap/hpベースに変更
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
	print("  [先制攻撃] 攻撃側AP(", attacker_st, ") vs 防御側HP(", defender_hp, ")")
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
	var board_system = board_system_ref
	if not board_system:
		board_system = get_tree().get_root().get_node_or_null("Game/BoardSystem")
		if not board_system:
			board_system = get_tree().get_root().get_node_or_null("Game3D/BoardSystem3D")
	
	# ボーナスを個別に計算
	var attacker_bonuses = calculate_creature_bonuses(attacker, defender, tile, true, attacker_player_id, board_system, true)
	var defender_bonuses = calculate_creature_bonuses(defender, attacker, tile, false, defender_player_id, board_system, true)
	
	var prediction = {
		"attacker_st": attacker.get("ap", 0) + attacker_bonuses.st_bonus,  # damage -> ap
		"attacker_hp": attacker.get("hp", 0) + attacker_bonuses.hp_bonus,  # block -> hp
		"defender_st": defender.get("ap", 0) + defender_bonuses.st_bonus,  # damage -> ap
		"defender_hp": defender.get("hp", 0) + defender_bonuses.hp_bonus,  # block -> hp
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

# 簡易バトル判定（3D版用）
func quick_battle_check(attacker_st: int, defender_hp: int) -> bool:
	return attacker_st >= defender_hp
