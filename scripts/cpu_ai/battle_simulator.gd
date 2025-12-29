## バトルシミュレーター
##
## CPUがバトルの勝敗を予測するためのシミュレーションクラス
## 既存のバトル処理ロジック（BattleSkillProcessor, BattlePreparation）を
## 直接呼び出し、実際にバトルを実行せずに最終的なAP/HPと勝敗を計算する
##
## @version 2.0
## @date 2025年1月

class_name BattleSimulator

const BattleParticipantScript = preload("res://scripts/battle/battle_participant.gd")
const BattlePreparationScript = preload("res://scripts/battle/battle_preparation.gd")
const BattleSkillProcessorScript = preload("res://scripts/battle/battle_skill_processor.gd")
const BattleSpecialEffectsScript = preload("res://scripts/battle/battle_special_effects.gd")

# バトル結果の定数
enum BattleResult {
	ATTACKER_WIN,      # 侵略成功（防御側のみ死亡）
	DEFENDER_WIN,      # 防御成功（攻撃側のみ死亡）
	ATTACKER_SURVIVED, # 両方生存（侵略失敗）
	BOTH_DEFEATED      # 相打ち（両方死亡）
}

# システム参照
var board_system_ref = null
var card_system_ref = null
var player_system_ref = null
var game_flow_manager_ref = null

# 処理用インスタンス
var battle_preparation: BattlePreparationScript = null
var skill_processor: BattleSkillProcessorScript = null
var special_effects: BattleSpecialEffectsScript = null

# ログ出力フラグ
var enable_log: bool = true

func _init():
	battle_preparation = BattlePreparationScript.new()
	skill_processor = BattleSkillProcessorScript.new()
	special_effects = BattleSpecialEffectsScript.new()

## システム参照を設定
func setup_systems(board_system, card_system, player_system, game_flow_manager = null) -> void:
	board_system_ref = board_system
	card_system_ref = card_system
	player_system_ref = player_system
	game_flow_manager_ref = game_flow_manager
	
	# BattlePreparationのセットアップ
	battle_preparation.setup_systems(board_system, card_system, null)
	
	# BattleSkillProcessorのセットアップ
	skill_processor.setup_systems(board_system, game_flow_manager, card_system, null, battle_preparation)

## バトルをシミュレーション
##
## @param attacker_data: 攻撃側クリーチャーデータ
## @param defender_data: 防御側クリーチャーデータ
## @param tile_info: タイル情報（element, level, owner, index等）
## @param attacker_player_id: 攻撃側プレイヤーID
## @param attacker_item: 攻撃側アイテム（任意）
## @param defender_item: 防御側アイテム（任意）
## @return Dictionary: シミュレーション結果
func simulate_battle(
	attacker_data: Dictionary,
	defender_data: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	attacker_item: Dictionary = {},
	defender_item: Dictionary = {}
) -> Dictionary:
	
	_log("=== シミュレーション開始 ===")
	_log("攻撃側: %s (基礎AP:%d, 基礎HP:%d)" % [
		attacker_data.get("name", "?"),
		attacker_data.get("ap", 0),
		attacker_data.get("hp", 0)
	])
	_log("防御側: %s (基礎AP:%d, 基礎HP:%d)" % [
		defender_data.get("name", "?"),
		defender_data.get("ap", 0),
		defender_data.get("hp", 0)
	])
	
	# 1. BattleParticipant作成
	var participants = _create_participants(
		attacker_data, defender_data, tile_info,
		attacker_player_id, attacker_item, defender_item
	)
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# 2. アイテム効果適用（BattlePreparationを使用）
	var battle_tile_index = tile_info.get("index", tile_info.get("tile_index", -1))
	if not attacker_item.is_empty() or not defender_item.is_empty():
		_log("--- アイテム効果適用 ---")
		battle_preparation.apply_remaining_item_effects(attacker, defender, battle_tile_index)
	
	# 3. スキル適用（BattleSkillProcessorを使用）
	_log("--- スキル適用 ---")
	var sim_tile_info = tile_info.duplicate()
	sim_tile_info["index"] = battle_tile_index
	skill_processor.apply_skills_for_simulation(participants, sim_tile_info, attacker_player_id)
	
	# 4. 無効化判定（防御側クリーチャーのスキルによる無効化）
	var nullify_context = {
		"tile_level": tile_info.get("level", 1),
		"tile_element": tile_info.get("element", ""),
		"battle_tile_index": battle_tile_index
	}
	var nullify_result = special_effects.check_nullify(attacker, defender, nullify_context)
	var is_nullified = nullify_result.get("is_nullified", false)
	
	if is_nullified:
		_log("")
		_log("▼▼▼ 無効化判定 ▼▼▼")
		_log("  → 【無効化】攻撃が無効化される！侵略不可")
		_log("")
		return {
			"result": BattleResult.DEFENDER_WIN,
			"attacker_ap": attacker.current_ap,
			"attacker_hp": _calculate_total_hp(attacker),
			"defender_ap": defender.current_ap,
			"defender_hp": _calculate_total_hp(defender),
			"attack_order": "N/A",
			"attacker_survives": false,
			"defender_survives": true,
			"is_nullified": true
		}
	
	# 5. 最終ステータス取得
	var attacker_final_ap = attacker.current_ap
	var attacker_final_hp = _calculate_total_hp(attacker)
	var defender_final_ap = defender.current_ap
	var defender_final_hp = _calculate_total_hp(defender)
	
	# 攻撃回数取得
	var attacker_attack_count = attacker.attack_count
	var defender_attack_count = defender.attack_count
	
	_log("=== 最終ステータス ===")
	_log("攻撃側: AP=%d, HP=%d, 攻撃回数=%d" % [attacker_final_ap, attacker_final_hp, attacker_attack_count])
	_log("防御側: AP=%d, HP=%d, 攻撃回数=%d" % [defender_final_ap, defender_final_hp, defender_attack_count])
	
	# 6. 攻撃順序判定
	var attack_order = _determine_attack_order(attacker, defender)
	_log("攻撃順序: %s" % attack_order)
	
	# 7. 勝敗判定（2回攻撃を考慮）
	var result = _calculate_battle_result(
		attacker_final_ap, attacker_final_hp, attacker_attack_count,
		defender_final_ap, defender_final_hp, defender_attack_count,
		attack_order
	)
	
	_log("")
	_log(_get_result_header(result))
	_log("  → %s" % _result_to_string(result))
	_log("")
	
	return {
		"result": result,
		"attacker_ap": attacker_final_ap,
		"attacker_hp": attacker_final_hp,
		"defender_ap": defender_final_ap,
		"defender_hp": defender_final_hp,
		"attack_order": attack_order,
		"attacker_survives": result == BattleResult.ATTACKER_WIN or result == BattleResult.ATTACKER_SURVIVED,
		"defender_survives": result == BattleResult.DEFENDER_WIN or result == BattleResult.ATTACKER_SURVIVED,
		"is_nullified": false
	}

## BattleParticipant作成
func _create_participants(
	attacker_data: Dictionary,
	defender_data: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	attacker_item: Dictionary,
	defender_item: Dictionary
) -> Dictionary:
	
	_log("--- 基礎ステータス ---")
	
	# 攻撃側（土地ボーナスなし）
	var attacker_base_hp = attacker_data.get("hp", 0)
	var attacker_base_up_hp = attacker_data.get("base_up_hp", 0)
	var attacker_base_ap = attacker_data.get("ap", 0)
	var attacker_base_up_ap = attacker_data.get("base_up_ap", 0)
	
	# クリーチャーデータにアイテムを設定
	var attacker_creature_data = attacker_data.duplicate(true)
	if not attacker_item.is_empty():
		attacker_creature_data["items"] = [attacker_item]
	
	var attacker = BattleParticipantScript.new(
		attacker_creature_data,
		attacker_base_hp,
		0,  # 攻撃側は土地ボーナスなし
		attacker_base_ap,
		true,
		attacker_player_id
	)
	attacker.base_up_hp = attacker_base_up_hp
	attacker.base_up_ap = attacker_base_up_ap
	attacker.current_hp = attacker_data.get("current_hp", attacker_base_hp + attacker_base_up_hp)
	
	if attacker_base_up_hp > 0 or attacker_base_up_ap > 0:
		_log("攻撃側: base_up_hp=%d, base_up_ap=%d" % [attacker_base_up_hp, attacker_base_up_ap])
	
	# 防御側（土地ボーナスあり）
	var defender_base_hp = defender_data.get("hp", 0)
	var defender_base_up_hp = defender_data.get("base_up_hp", 0)
	var defender_base_ap = defender_data.get("ap", 0)
	var defender_base_up_ap = defender_data.get("base_up_ap", 0)
	var defender_owner = tile_info.get("owner", -1)
	
	# 土地ボーナス計算
	var land_bonus = _calculate_land_bonus(defender_data, tile_info)
	
	# クリーチャーデータにアイテムを設定
	var defender_creature_data = defender_data.duplicate(true)
	if not defender_item.is_empty():
		defender_creature_data["items"] = [defender_item]
	
	var defender = BattleParticipantScript.new(
		defender_creature_data,
		defender_base_hp,
		land_bonus,
		defender_base_ap,
		false,
		defender_owner
	)
	defender.base_up_hp = defender_base_up_hp
	defender.base_up_ap = defender_base_up_ap
	defender.current_hp = defender_data.get("current_hp", defender_base_hp + defender_base_up_hp)
	
	if defender_base_up_hp > 0 or defender_base_up_ap > 0:
		_log("防御側: base_up_hp=%d, base_up_ap=%d" % [defender_base_up_hp, defender_base_up_ap])
	
	return {
		"attacker": attacker,
		"defender": defender
	}

## 土地ボーナス計算
func _calculate_land_bonus(creature_data: Dictionary, tile_info: Dictionary) -> int:
	var creature_element = creature_data.get("element", "")
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	if creature_element == tile_element and creature_element != "":
		var bonus = tile_level * 10
		_log("防御側: 土地ボーナス +%d (属性一致 Lv%d)" % [bonus, tile_level])
		return bonus
	
	return 0

## 合計HP計算
func _calculate_total_hp(participant) -> int:
	return participant.current_hp + participant.land_bonus_hp + participant.resonance_bonus_hp + \
		   participant.temporary_bonus_hp + participant.item_bonus_hp + participant.spell_bonus_hp

## 攻撃順序決定
func _determine_attack_order(attacker, defender) -> String:
	# アイテム先制が最優先
	if attacker.has_item_first_strike:
		return "attacker_first"
	if defender.has_item_first_strike:
		return "defender_first"
	
	# クリーチャー先制
	if attacker.has_first_strike and not defender.has_first_strike:
		return "attacker_first"
	if defender.has_first_strike and not attacker.has_first_strike:
		return "defender_first"
	
	# 後手チェック
	if attacker.has_last_strike and not defender.has_last_strike:
		return "defender_first"
	if defender.has_last_strike and not attacker.has_last_strike:
		return "attacker_first"
	
	# デフォルト：攻撃側が先攻
	return "attacker_first"

## 勝敗判定（2回攻撃を考慮）
func _calculate_battle_result(
	attacker_ap: int,
	attacker_hp: int,
	attacker_attack_count: int,
	defender_ap: int,
	defender_hp: int,
	defender_attack_count: int,
	attack_order: String
) -> int:
	
	var attacker_current_hp = attacker_hp
	var defender_current_hp = defender_hp
	
	# 総ダメージ計算（2回攻撃を考慮）
	var attacker_total_damage = attacker_ap * attacker_attack_count
	var defender_total_damage = defender_ap * defender_attack_count
	
	if attack_order == "attacker_first":
		# 攻撃側が先攻
		defender_current_hp -= attacker_total_damage
		if defender_current_hp > 0:
			# 防御側が生き残ったら反撃
			attacker_current_hp -= defender_total_damage
	else:
		# 防御側が先攻
		attacker_current_hp -= defender_total_damage
		if attacker_current_hp > 0:
			# 攻撃側が生き残ったら攻撃
			defender_current_hp -= attacker_total_damage
	
	var attacker_dies = attacker_current_hp <= 0
	var defender_dies = defender_current_hp <= 0
	
	# 結果判定
	if attacker_dies and defender_dies:
		return BattleResult.BOTH_DEFEATED
	elif defender_dies:
		return BattleResult.ATTACKER_WIN
	elif attacker_dies:
		return BattleResult.DEFENDER_WIN
	else:
		return BattleResult.ATTACKER_SURVIVED

## 結果を文字列に変換
func _get_result_header(result: int) -> String:
	match result:
		BattleResult.ATTACKER_WIN:
			return "★★★ 勝敗判定 ★★★"
		_:
			return "▼▼▼ 勝敗判定 ▼▼▼"

func _result_to_string(result: int) -> String:
	match result:
		BattleResult.ATTACKER_WIN:
			return "【勝利】侵略成功！攻撃側の勝ち"
		BattleResult.DEFENDER_WIN:
			return "【敗北】防御成功…攻撃側の負け"
		BattleResult.ATTACKER_SURVIVED:
			return "【引分】両方生存（侵略失敗）"
		BattleResult.BOTH_DEFEATED:
			return "【相打】両方撃破"
		_:
			return "【不明】"

## ログ出力
func _log(message: String) -> void:
	if enable_log:
		print("[BattleSimulator] " + message)
