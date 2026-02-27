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
const SkillReflectScript = preload("res://scripts/battle/skills/skill_reflect.gd")

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

# ログレベル（0=silent, 1=summary, 2=full）
var log_level: int = 1

func _init():
	battle_preparation = BattlePreparationScript.new()
	battle_preparation.silent = true
	skill_processor = BattleSkillProcessorScript.new()
	skill_processor.silent = true
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

	# ログレベルに応じてsilentモード切替
	battle_preparation.set_silent(log_level < 2)
	skill_processor.silent = (log_level < 2)

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
	var nullify_reduction_rate = nullify_result.get("reduction_rate", 0.0)
	
	# 完全無効化（reduction_rate == 0.0）の場合のみ早期リターン
	if is_nullified and nullify_reduction_rate == 0.0:
		_log("")
		_log("▼▼▼ 無効化判定 ▼▼▼")
		_log("  → 【無効化】攻撃が無効化される！休戦")

		# 無効化成功でも、防御側が攻撃側を倒すので死亡時効果を考慮
		var defender_final_hp_nullify = _calculate_total_hp(defender)
		var _defender_final_ap_nullify = defender.current_ap  # 将来の拡張用
		var attacker_data_for_death = attacker.creature_data

		# 攻撃側の死亡時ダメージを確認
		var death_damage = _get_attacker_death_damage(attacker_data_for_death)
		var final_result = BattleResult.DEFENDER_WIN
		var final_defender_survives = true

		if death_damage > 0:
			# 防御側が攻撃側を倒した後の残りHPを計算
			# 無効化成功時、攻撃側の攻撃は無効なので防御側はダメージを受けない
			# 防御側が攻撃 → 攻撃側死亡 → 死亡時効果発動
			var remaining_hp = defender_final_hp_nullify - death_damage

			_log("--- 死亡時効果判定（無効化後） ---")
			_log("攻撃側死亡時ダメージ: %d" % death_damage)
			_log("防御側HP: %d" % defender_final_hp_nullify)

			if remaining_hp <= 0:
				_log("  → 死亡時効果で防御側も撃破！相打ちに変更")
				final_result = BattleResult.BOTH_DEFEATED
				final_defender_survives = false
			else:
				_log("  → 防御側生存（残りHP: %d）" % remaining_hp)

		_log("")

		# レベル1: 無効化サマリー
		if log_level >= 1:
			var atk_name_n = attacker_data.get("name", "?")
			var def_name_n = defender_data.get("name", "?")
			var atk_base_n = "%s(%d/%d)" % [atk_name_n, attacker_data.get("ap", 0), attacker_data.get("hp", 0)]
			var def_base_n = "%s(%d/%d)" % [def_name_n, defender_data.get("ap", 0), defender_data.get("hp", 0)]

			if not attacker_item.is_empty():
				atk_base_n = "[%s] %s" % [attacker_item.get("name", "?"), atk_base_n]
			if not defender_item.is_empty():
				def_base_n = "[%s] %s" % [defender_item.get("name", "?"), def_base_n]

			print("[BattleSim] %s vs %s" % [atk_base_n, def_base_n])
			print("  → 無効化")

		return {
			"result": final_result,
			"attacker_ap": attacker.current_ap,
			"attacker_hp": _calculate_total_hp(attacker),
			"defender_ap": defender.current_ap,
			"defender_hp": _calculate_total_hp(defender),
			"attack_order": "N/A",
			"attacker_survives": false,
			"defender_survives": final_defender_survives,
			"is_nullified": true
		}
	
	# 5. 最終ステータス取得
	var attacker_final_ap = attacker.current_ap
	var attacker_final_hp = _calculate_total_hp(attacker)
	var defender_final_ap = defender.current_ap
	var defender_final_hp = _calculate_total_hp(defender)

	# 5.5. 消沈チェック: 攻撃不可 → AP=0として計算
	if SpellCurseBattle.has_battle_disable(attacker.creature_data):
		_log("【消沈】攻撃側は攻撃不可 → AP=0")
		attacker_final_ap = 0
	if SpellCurseBattle.has_battle_disable(defender.creature_data):
		_log("【消沈】防御側は攻撃不可 → AP=0")
		defender_final_ap = 0
	
	# 攻撃回数取得
	var attacker_attack_count = attacker.attack_count
	var defender_attack_count = defender.attack_count
	
	_log("=== 最終ステータス ===")
	_log("攻撃側: AP=%d, HP=%d, 攻撃回数=%d" % [attacker_final_ap, attacker_final_hp, attacker_attack_count])
	_log("防御側: AP=%d, HP=%d, 攻撃回数=%d" % [defender_final_ap, defender_final_hp, defender_attack_count])
	
	# 6. 攻撃順序判定
	var attack_order = _determine_attack_order(attacker, defender)
	_log("攻撃順序: %s" % attack_order)
	
	# 7. 反射情報取得（相手が術攻撃の場合、通常攻撃用の反射は効かない）
	var attacker_has_scroll = _has_scroll_attack(attacker.creature_data)
	var defender_has_scroll = _has_scroll_attack(defender.creature_data)
	var attacker_reflect = _get_reflect_info(attacker, defender_has_scroll)  # 防御側が術攻撃なら攻撃側の反射は効かない
	var defender_reflect = _get_reflect_info(defender, attacker_has_scroll)  # 攻撃側が術攻撃なら防御側の反射は効かない
	
	if defender_reflect.has_reflect:
		_log("防御側反射: %.0f%%反射, %.0f%%軽減" % [defender_reflect.reflect_ratio * 100, (1.0 - defender_reflect.self_damage_ratio) * 100])
	if attacker_reflect.has_reflect:
		_log("攻撃側反射: %.0f%%反射, %.0f%%軽減" % [attacker_reflect.reflect_ratio * 100, (1.0 - attacker_reflect.self_damage_ratio) * 100])
	
	# 8. ダメージ軽減判定（無効化[1/2]など）
	var defender_damage_reduction = 1.0  # 1.0 = 軽減なし
	if is_nullified and nullify_reduction_rate > 0.0:
		defender_damage_reduction = nullify_reduction_rate  # 例: 0.5 = 50%軽減
		_log("防御側ダメージ軽減: %.0f%%" % [(1.0 - defender_damage_reduction) * 100])
	
	# 9. 勝敗判定（2回攻撃・反射・軽減を考慮）
	var result = _calculate_battle_result(
		attacker_final_ap, attacker_final_hp, attacker_attack_count,
		defender_final_ap, defender_final_hp, defender_attack_count,
		attack_order,
		attacker_reflect, defender_reflect,
		defender_damage_reduction
	)
	
	# 10. 攻撃側クリーチャーの死亡時効果を考慮
	var death_effect_result = _apply_attacker_death_effects(
		result, attacker.creature_data, defender_final_hp,
		attacker_final_ap, attacker_attack_count, defender_reflect
	)
	result = death_effect_result["result"]
	var _adjusted_defender_hp = death_effect_result["defender_hp"]  # 現在未使用

	# 11. 戦闘後刻印効果（崩壊・衰弱）
	result = _apply_post_battle_curse_effects(result, attacker, defender)

	_log("")
	_log(_get_result_header(result))
	_log("  → %s" % _result_to_string(result))
	_log("")

	# レベル1: 3行サマリー
	if log_level >= 1:
		var order_str = "先攻" if attack_order == "attacker_first" else "後攻"
		var result_str = _result_to_short_string(result)

		# Line 1: アイテム + 基礎ステータス
		var atk_name = attacker_data.get("name", "?")
		var def_name = defender_data.get("name", "?")
		var atk_base = "%s(%d/%d)" % [atk_name, attacker_data.get("ap", 0), attacker_data.get("hp", 0)]
		var def_base = "%s(%d/%d)" % [def_name, defender_data.get("ap", 0), defender_data.get("hp", 0)]

		if not attacker_item.is_empty():
			atk_base = "[%s] %s" % [attacker_item.get("name", "?"), atk_base]
		if not defender_item.is_empty():
			def_base = "[%s] %s" % [defender_item.get("name", "?"), def_base]

		print("[BattleSim] %s vs %s" % [atk_base, def_base])

		# Line 2: スキル・刻印（効果がある場合のみ）
		var atk_effects = _get_effects_summary(attacker)
		var def_effects = _get_effects_summary(defender)
		if atk_effects != "なし" or def_effects != "なし":
			print("  攻: %s | 防: %s" % [atk_effects, def_effects])

		# Line 3: 最終ステータス + 結果
		print("  → %s(AP%d/HP%d) vs %s(AP%d/HP%d) [%s] → %s" % [
			atk_name, attacker_final_ap, attacker_final_hp,
			def_name, defender_final_ap, defender_final_hp,
			order_str, result_str
		])

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
	
	# 刻印等のtemporary_effectsを反映
	battle_preparation.apply_effect_arrays(attacker, attacker_creature_data)
	
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
	
	# 刻印等のtemporary_effectsを反映
	battle_preparation.apply_effect_arrays(defender, defender_creature_data)
	
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

## クリーチャーが術攻撃を持っているかチェック
func _has_scroll_attack(creature_data: Dictionary) -> bool:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 「術攻撃」キーワードをチェック
	for keyword in keywords:
		if "術攻撃" in str(keyword):
			return true
	
	# effectsもチェック
	var effects = ability_parsed.get("effects", [])
	for effect in effects:
		if effect.get("effect_type") == "scroll_attack":
			return true
	
	return false

## 勝敗判定（2回攻撃を考慮）
## 反射情報を取得
## opponent_has_scroll: 相手が術攻撃を持っているか（術攻撃には反射が効かない）
func _get_reflect_info(participant, opponent_has_scroll: bool = false) -> Dictionary:
	var result = {
		"has_reflect": false,
		"reflect_ratio": 0.0,
		"self_damage_ratio": 1.0  # デフォルトは100%ダメージを受ける
	}
	
	# 相手が術攻撃の場合、通常攻撃用の反射は効かない
	var required_attack_type = "scroll" if opponent_has_scroll else "normal"
	
	# クリーチャー自身のスキルをチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "reflect_damage":
			var attack_types = effect.get("attack_types", [])
			if required_attack_type in attack_types:
				result.has_reflect = true
				result.reflect_ratio = effect.get("reflect_ratio", 0.5)
				result.self_damage_ratio = effect.get("self_damage_ratio", 0.5)
				return result
	
	# アイテムをチェック
	var items = participant.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var item_effects = effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "reflect_damage":
				var attack_types = effect.get("attack_types", [])
				if required_attack_type in attack_types:
					result.has_reflect = true
					result.reflect_ratio = effect.get("reflect_ratio", 0.5)
					result.self_damage_ratio = effect.get("self_damage_ratio", 0.5)
					return result
	
	return result

func _calculate_battle_result(
	attacker_ap: int,
	attacker_hp: int,
	attacker_attack_count: int,
	defender_ap: int,
	defender_hp: int,
	defender_attack_count: int,
	attack_order: String,
	attacker_reflect: Dictionary = {},
	defender_reflect: Dictionary = {},
	defender_damage_reduction: float = 1.0  # 防御側が受けるダメージの軽減率（1.0=軽減なし、0.5=50%軽減）
) -> int:
	
	var attacker_current_hp = attacker_hp
	var defender_current_hp = defender_hp
	
	# 総ダメージ計算（2回攻撃を考慮）
	# 防御側のダメージ軽減を適用（無効化[1/2]など）
	var attacker_total_damage = int(attacker_ap * attacker_attack_count * defender_damage_reduction)
	var defender_total_damage = defender_ap * defender_attack_count
	
	# 反射計算用
	var attacker_has_reflect = attacker_reflect.get("has_reflect", false)
	var attacker_reflect_ratio = attacker_reflect.get("reflect_ratio", 0.0)
	var attacker_self_damage_ratio = attacker_reflect.get("self_damage_ratio", 1.0)
	
	var defender_has_reflect = defender_reflect.get("has_reflect", false)
	var defender_reflect_ratio = defender_reflect.get("reflect_ratio", 0.0)
	var defender_self_damage_ratio = defender_reflect.get("self_damage_ratio", 1.0)
	
	if attack_order == "attacker_first":
		# 攻撃側が先攻
		if defender_has_reflect:
			# 防御側が反射を持っている
			var reflect_damage = int(attacker_total_damage * defender_reflect_ratio)
			var actual_damage = int(attacker_total_damage * defender_self_damage_ratio)
			defender_current_hp -= actual_damage
			attacker_current_hp -= reflect_damage
		else:
			defender_current_hp -= attacker_total_damage
		
		if defender_current_hp > 0 and attacker_current_hp > 0:
			# 防御側が生き残ったら反撃
			if attacker_has_reflect:
				var reflect_damage = int(defender_total_damage * attacker_reflect_ratio)
				var actual_damage = int(defender_total_damage * attacker_self_damage_ratio)
				attacker_current_hp -= actual_damage
				defender_current_hp -= reflect_damage
			else:
				attacker_current_hp -= defender_total_damage
	else:
		# 防御側が先攻
		if attacker_has_reflect:
			# 攻撃側が反射を持っている
			var reflect_damage = int(defender_total_damage * attacker_reflect_ratio)
			var actual_damage = int(defender_total_damage * attacker_self_damage_ratio)
			attacker_current_hp -= actual_damage
			defender_current_hp -= reflect_damage
		else:
			attacker_current_hp -= defender_total_damage
		
		if attacker_current_hp > 0 and defender_current_hp > 0:
			# 攻撃側が生き残ったら攻撃
			if defender_has_reflect:
				var reflect_damage = int(attacker_total_damage * defender_reflect_ratio)
				var actual_damage = int(attacker_total_damage * defender_self_damage_ratio)
				defender_current_hp -= actual_damage
				attacker_current_hp -= reflect_damage
			else:
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

## 攻撃側クリーチャーの死亡時効果を考慮
## サルファバルーン等の「死亡時敵にダメージ」を考慮して結果を調整
func _apply_attacker_death_effects(
	current_result: int,
	attacker_data: Dictionary,
	defender_hp: int,
	attacker_ap: int,
	attacker_attack_count: int,
	defender_reflect: Dictionary
) -> Dictionary:
	var result = current_result
	var adjusted_defender_hp = defender_hp
	
	# 攻撃側が死亡しない場合は効果なし
	if result != BattleResult.DEFENDER_WIN and result != BattleResult.BOTH_DEFEATED:
		return {"result": result, "defender_hp": adjusted_defender_hp}
	
	# 攻撃側クリーチャーの死亡時効果を確認
	var death_damage = _get_attacker_death_damage(attacker_data)
	if death_damage <= 0:
		return {"result": result, "defender_hp": adjusted_defender_hp}
	
	# 防御側の残りHPを計算（反射を考慮した実際のダメージ後）
	var defender_has_reflect = defender_reflect.get("has_reflect", false)
	var defender_self_damage_ratio = defender_reflect.get("self_damage_ratio", 1.0)
	
	var actual_attacker_damage = attacker_ap * attacker_attack_count
	if defender_has_reflect:
		actual_attacker_damage = int(actual_attacker_damage * defender_self_damage_ratio)
	
	# 防御側の残りHP（元HPから攻撃ダメージを引いた値）
	# DEFENDER_WIN の場合、防御側は生き残っているので、残りHPを推測
	var estimated_remaining_hp = defender_hp - actual_attacker_damage
	if estimated_remaining_hp < 1:
		estimated_remaining_hp = 1  # 勝った場合は最低1は残っている
	
	_log("--- 死亡時効果判定 ---")
	_log("攻撃側死亡時ダメージ: %d" % death_damage)
	_log("防御側推定残りHP: %d" % estimated_remaining_hp)
	
	# 死亡時ダメージを適用
	adjusted_defender_hp = estimated_remaining_hp - death_damage
	
	if adjusted_defender_hp <= 0:
		_log("  → 死亡時効果で防御側も撃破！相打ちに変更")
		result = BattleResult.BOTH_DEFEATED
	else:
		_log("  → 防御側生存（残りHP: %d）" % adjusted_defender_hp)
	
	return {"result": result, "defender_hp": adjusted_defender_hp}

## 攻撃側クリーチャーの死亡時ダメージを取得
func _get_attacker_death_damage(attacker_data: Dictionary) -> int:
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var trigger = effect.get("trigger", "")
		if trigger == "on_death":
			var effect_type = effect.get("effect_type", "")
			if effect_type == "damage_enemy":
				return effect.get("damage", 0)
	
	return 0

## パーティシパントのスキル・刻印情報を収集（レベル1用）
func _get_effects_summary(participant) -> String:
	var parts: Array[String] = []

	# ability_parsed の keywords からスキル名を収集
	var ability = participant.creature_data.get("ability_parsed", {})
	var keywords = ability.get("keywords", [])
	for kw in keywords:
		parts.append(str(kw))

	# BattleParticipant のフラグからアイテム付与スキルを収集
	if participant.has_item_first_strike:
		if "先制" not in parts:
			parts.append("先制(アイテム)")
	if participant.attack_count > 1 and "2回攻撃" not in parts:
		parts.append("2回攻撃")
	if participant.has_squid_mantle:
		parts.append("特殊攻撃無効")

	# temporary_effects から刻印効果を収集
	var temp_effects = participant.creature_data.get("temporary_effects", [])
	for eff in temp_effects:
		var eff_name = eff.get("name", "")
		if eff_name == "":
			# nameがなければeffect_typeを使う
			eff_name = eff.get("effect_type", "効果")
		parts.append("呪:" + str(eff_name))

	# curse（プレイヤー刻印由来の効果）もチェック
	var curse_effects = participant.creature_data.get("curse_effects", [])
	for eff in curse_effects:
		var eff_name = eff.get("name", eff.get("effect_type", "刻印"))
		parts.append("呪:" + str(eff_name))

	if parts.is_empty():
		return "なし"
	return ", ".join(parts)

## 戦闘後刻印効果（崩壊・衰弱）を適用して結果を再判定
func _apply_post_battle_curse_effects(current_result: int, attacker, defender) -> int:
	var result = current_result
	var attacker_survives = (result == BattleResult.ATTACKER_WIN or result == BattleResult.ATTACKER_SURVIVED)
	var defender_survives = (result == BattleResult.DEFENDER_WIN or result == BattleResult.ATTACKER_SURVIVED)

	# 崩壊: 生存していても戦闘後に破壊
	if attacker_survives and SpellCurseBattle.has_destroy_after_battle(attacker.creature_data):
		_log("【崩壊】攻撃側は戦闘後に破壊")
		attacker_survives = false
	if defender_survives and SpellCurseBattle.has_destroy_after_battle(defender.creature_data):
		_log("【崩壊】防御側は戦闘後に破壊")
		defender_survives = false

	# 衰弱: 生存者にMHP/2ダメージ
	if attacker_survives and _has_plague_curse(attacker.creature_data):
		var max_hp = attacker.base_hp + attacker.base_up_hp
		var plague_damage = int(max_hp / 2)
		var remaining_hp = _calculate_total_hp(attacker) - plague_damage
		_log("【衰弱】攻撃側にMHP/2=%dダメージ → 残HP=%d" % [plague_damage, remaining_hp])
		if remaining_hp <= 0:
			attacker_survives = false
	if defender_survives and _has_plague_curse(defender.creature_data):
		var max_hp = defender.base_hp + defender.base_up_hp + defender.land_bonus_hp
		var plague_damage = int(max_hp / 2)
		var remaining_hp = _calculate_total_hp(defender) - plague_damage
		_log("【衰弱】防御側にMHP/2=%dダメージ → 残HP=%d" % [plague_damage, remaining_hp])
		if remaining_hp <= 0:
			defender_survives = false

	# 結果を再判定
	if attacker_survives and defender_survives:
		return result  # 変化なし
	elif attacker_survives and not defender_survives:
		return BattleResult.ATTACKER_WIN
	elif not attacker_survives and defender_survives:
		return BattleResult.DEFENDER_WIN
	elif not attacker_survives and not defender_survives:
		return BattleResult.BOTH_DEFEATED

	return result


## 衰弱刻印を持っているかチェック
func _has_plague_curse(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "plague"


## ログ出力（レベル2以上で詳細ログを出力）
func _log(message: String) -> void:
	if log_level >= 2:
		print("[BattleSimulator] " + message)

## 結果を短い文字列に変換（レベル1用）
func _result_to_short_string(result: int) -> String:
	match result:
		BattleResult.ATTACKER_WIN:
			return "勝利"
		BattleResult.DEFENDER_WIN:
			return "敗北"
		BattleResult.ATTACKER_SURVIVED:
			return "引分"
		BattleResult.BOTH_DEFEATED:
			return "相打"
		_:
			return "不明"
