extends Node
class_name BattleSkillProcessor

# バトルスキル処理
# 感応、強打、2回攻撃、巻物攻撃などのスキル適用を担当

# スキルモジュール
const SupportSkill = preload("res://scripts/battle/skills/skill_support.gd")
const ResonanceSkill = preload("res://scripts/battle/skills/skill_resonance.gd")
const ScrollAttackSkill = preload("res://scripts/battle/skills/skill_scroll_attack.gd")
const ReflectSkill = preload("res://scripts/battle/skills/skill_reflect.gd")
const ItemManipulationSkill = preload("res://scripts/battle/skills/skill_item_manipulation.gd")
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")
const PenetrationSkill = preload("res://scripts/battle/skills/skill_penetration.gd")
const PowerStrikeSkill = preload("res://scripts/battle/skills/skill_power_strike.gd")
const DoubleAttackSkill = preload("res://scripts/battle/skills/skill_double_attack.gd")
const FirstStrikeSkill = preload("res://scripts/battle/skills/skill_first_strike.gd")
const SpecialCreatureSkill = preload("res://scripts/battle/skills/skill_special_creature.gd")
# SkillStatModifiers はグローバルクラスとして利用可能
const BattleCurseApplierScript = preload("res://scripts/battle/battle_curse_applier.gd")
# SkillDisplayConfig, SkillPermanentBuff, SkillBattleStartConditions はグローバルクラスとして利用可能
var _skill_magic_gain = preload("res://scripts/battle/skills/skill_magic_gain.gd")

var board_system_ref = null
var game_flow_manager_ref = null
var card_system_ref = null
var battle_screen_manager = null
var battle_preparation_ref = null

# === 直接参照（GFM経由を廃止） ===
var lap_system = null  # LapSystem: 周回管理（破壊数効果用）

func setup_systems(board_system, game_flow_manager = null, card_system = null, p_battle_screen_manager = null, battle_preparation = null):
	board_system_ref = board_system
	game_flow_manager_ref = game_flow_manager
	card_system_ref = card_system
	battle_screen_manager = p_battle_screen_manager
	battle_preparation_ref = battle_preparation

	# lap_systemの直接参照を設定
	if game_flow_manager_ref and game_flow_manager_ref.lap_system:
		lap_system = game_flow_manager_ref.lap_system

## バトル前スキル適用（async対応・スキル毎にアニメーション）
## 戻り値: { transform_result: Dictionary }
func apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> Dictionary:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	var attacker_used_item = participants.get("attacker_used_item", false)
	var defender_used_item = participants.get("defender_used_item", false)
	var battle_tile_index = tile_info.get("index", -1)
	
	var result = {"transform_result": {}}
	var SkillSpecialCreatureScript = load("res://scripts/battle/skills/skill_special_creature.gd")
	
	# ============================================================
	# 【Phase 0-C】呪い適用（バトル画面セットアップ後・エフェクト表示可能）
	# ============================================================
	await _apply_curse_effects(attacker, defender, battle_tile_index)
	
	# ============================================================
	# 【Phase 0-N】能力無効化チェック（呪い適用後）
	# ============================================================
	var has_nullify = _has_warlock_disk(attacker) or _has_warlock_disk(defender) \
		or _has_skill_nullify_curse(attacker) or _has_skill_nullify_curse(defender) \
		or _has_nullify_creature_ability(attacker) or _has_nullify_creature_ability(defender)
	
	if has_nullify:
		print("【能力無効化発動】以降のスキル・変身・応援をスキップして基礎ステータスでバトル")
		SkillSpecialCreatureScript.apply_nullify_enemy_abilities(attacker, defender)
		SkillSpecialCreatureScript.apply_nullify_enemy_abilities(defender, attacker)
		
		# 🎬 能力無効化スキル表示（どちらが持っているか判定）
		# ウォーロックディスクの場合は「アイテム名 を使用」、それ以外は「戦闘中能力無効」
		if battle_screen_manager:
			if _has_warlock_disk(attacker):
				var attacker_item_name = _get_warlock_disk_name(attacker)
				await battle_screen_manager.show_skill_activation("attacker", "%s を使用" % attacker_item_name, {})
			elif _has_warlock_disk(defender):
				var defender_item_name = _get_warlock_disk_name(defender)
				await battle_screen_manager.show_skill_activation("defender", "%s を使用" % defender_item_name, {})
			else:
				# クリーチャー能力 or skill_nullify呪い → 「戦闘中能力無効」
				var skill_name = SkillDisplayConfig.get_skill_name("nullify_abilities")
				if _has_skill_nullify_curse(attacker) or _has_nullify_creature_ability(attacker):
					await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
				elif _has_skill_nullify_curse(defender) or _has_nullify_creature_ability(defender):
					await battle_screen_manager.show_skill_activation("defender", skill_name, {})
		
		# 能力無効化でもアイテムステータスは適用
		var attacker_nullify_before = _snapshot_stats(attacker)
		var defender_nullify_before = _snapshot_stats(defender)
		
		if battle_preparation_ref:
			battle_preparation_ref.apply_remaining_item_effects(attacker, defender, battle_tile_index, true)  # stat_bonus_only=true
		
		# アイテム効果でステータスが変わった場合、アイテム名を表示
		await _show_item_effect_if_any(attacker, attacker_nullify_before, "attacker")
		await _show_item_effect_if_any(defender, defender_nullify_before, "defender")
		
		return result
	
	# ============================================================
	# 【Phase 0-D】アイテム破壊・盗み（能力無効化後に実行）
	# ============================================================
	# 素の先制（クリーチャー能力のみ）で順序決定
	var attacker_has_raw_first_strike = _has_raw_first_strike(attacker)
	var defender_has_raw_first_strike = _has_raw_first_strike(defender)
	
	var first: BattleParticipant
	var second: BattleParticipant
	
	# 先制判定: 両方先制 or 両方なし → 攻撃側優先
	if attacker_has_raw_first_strike == defender_has_raw_first_strike:
		first = attacker
		second = defender
	elif attacker_has_raw_first_strike:
		first = attacker
		second = defender
	else:
		first = defender
		second = attacker
	
	# アイテム破壊・盗み実行
	await apply_item_manipulation(first, second)
	
	# アイテム使用フラグを再更新（破壊された場合はfalseに）
	attacker_used_item = not attacker.creature_data.get("items", []).is_empty()
	defender_used_item = not defender.creature_data.get("items", []).is_empty()
	
	# ============================================================
	# 【Phase 0-T】変身スキル適用（アイテム破壊・盗み後）
	# ============================================================
	# 変身後に土地ボーナスを再計算するため
	# skill_transform.gd内で土地ボーナス再計算も行う
	result["transform_result"] = TransformSkill.process_transform_effects(
		attacker, defender, CardLoader, "on_battle_start", board_system_ref, battle_tile_index
	)
	
	# 🎬 変身スキル表示
	var transform_result = result["transform_result"]
	if transform_result.get("attacker_transformed", false) and battle_screen_manager:
		var skill_name = SkillDisplayConfig.get_skill_name("transform")
		await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
		# 🎬 カード表示を更新
		var display_data = _create_display_data(attacker)
		await battle_screen_manager.update_creature("attacker", display_data)
	if transform_result.get("defender_transformed", false) and battle_screen_manager:
		var skill_name = SkillDisplayConfig.get_skill_name("transform")
		await battle_screen_manager.show_skill_activation("defender", skill_name, {})
		# 🎬 カード表示を更新
		var display_data = _create_display_data(defender)
		await battle_screen_manager.update_creature("defender", display_data)
	
	# ============================================================
	# 【Phase 0-S】アイテム効果適用（変身後・破壊後に残ったアイテム）
	# ============================================================
	# 残っているアイテムのステータス＋スキル効果を適用
	var attacker_before_item = _snapshot_stats(attacker)
	var defender_before_item = _snapshot_stats(defender)
	
	if battle_preparation_ref:
		battle_preparation_ref.apply_remaining_item_effects(attacker, defender, battle_tile_index)  # 通常適用（ステータス＋スキル両方）
	
	# アイテム効果でステータスが変わった場合、アイテム名を表示
	await _show_item_effect_if_any(attacker, attacker_before_item, "attacker")
	await _show_item_effect_if_any(defender, defender_before_item, "defender")
	
	# 合体が発生した場合、合体スキル名を表示
	await _show_merge_if_any(attacker, "attacker")
	await _show_merge_if_any(defender, "defender")
	
	# ============================================================
	# 【Phase 0-T2】アイテムによる変身スキル適用（ドラゴンオーブ等）
	# ============================================================
	# アイテム効果適用で追加された変身効果を処理
	var item_transform_result = TransformSkill.process_transform_effects(
		attacker, defender, CardLoader, "on_battle_start", board_system_ref, battle_tile_index
	)
	
	# 🎬 アイテム変身スキル表示
	if item_transform_result.get("attacker_transformed", false) and battle_screen_manager:
		var skill_name = SkillDisplayConfig.get_skill_name("transform")
		await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
		var display_data = _create_display_data(attacker)
		await battle_screen_manager.update_creature("attacker", display_data)
		# 変身結果をマージ
		result["transform_result"]["attacker_transformed"] = true
		if item_transform_result.has("attacker_original") and not item_transform_result["attacker_original"].is_empty():
			result["transform_result"]["attacker_original"] = item_transform_result["attacker_original"]
	if item_transform_result.get("defender_transformed", false) and battle_screen_manager:
		var skill_name = SkillDisplayConfig.get_skill_name("transform")
		await battle_screen_manager.show_skill_activation("defender", skill_name, {})
		var display_data = _create_display_data(defender)
		await battle_screen_manager.update_creature("defender", display_data)
		# 変身結果をマージ
		result["transform_result"]["defender_transformed"] = true
		if item_transform_result.has("defender_original") and not item_transform_result["defender_original"].is_empty():
			result["transform_result"]["defender_original"] = item_transform_result["defender_original"]
	
	# ============================================================
	# 【Phase 0-A】クリック後に適用する効果
	# ============================================================
	var attacker_before: Dictionary
	var defender_before: Dictionary
	var stat_change_name = SkillDisplayConfig.get_skill_name("stat_change")
	
	# ブルガサリ: アイテム使用時AP+20（アイテムが破壊されていなければ発動）
	attacker_before = _snapshot_stats(attacker)
	defender_before = _snapshot_stats(defender)
	SkillPermanentBuff.apply_bulgasari_battle_bonus(attacker, attacker_used_item, defender_used_item)
	SkillPermanentBuff.apply_bulgasari_battle_bonus(defender, defender_used_item, attacker_used_item)
	await _show_skill_change_if_any(attacker, attacker_before, stat_change_name)
	await _show_skill_change_if_any(defender, defender_before, stat_change_name)
	
	# APドレインは攻撃成功時効果のためbattle_execution.gdで処理
	
	# ランダムステータス（スペクター用）- 固有名を維持
	attacker_before = _snapshot_stats(attacker)
	defender_before = _snapshot_stats(defender)
	SkillSpecialCreatureScript.apply_random_stat_effects(attacker)
	SkillSpecialCreatureScript.apply_random_stat_effects(defender)
	var random_stat_name = SkillDisplayConfig.get_skill_name("random_stat")
	await _show_skill_change_if_any(attacker, attacker_before, random_stat_name)
	await _show_skill_change_if_any(defender, defender_before, random_stat_name)
	
	# 戦闘開始時条件（スラッジタイタン、ギガンテリウム等）
	attacker_before = _snapshot_stats(attacker)
	defender_before = _snapshot_stats(defender)
	_apply_battle_start_conditions(attacker, defender)
	await _show_skill_change_if_any(attacker, attacker_before, stat_change_name)
	await _show_skill_change_if_any(defender, defender_before, stat_change_name)
	
	# プレイヤー土地情報取得
	var player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
	
	# 【Phase 1】応援スキル適用（盤面全体を対象にバフ）- 固有名を維持
	attacker_before = _snapshot_stats(attacker)
	defender_before = _snapshot_stats(defender)
	SupportSkill.apply_to_all(participants, battle_tile_index, board_system_ref)
	var support_name = SkillDisplayConfig.get_skill_name("support")
	await _show_skill_change_if_any(attacker, attacker_before, support_name)
	await _show_skill_change_if_any(defender, defender_before, support_name)
	
	# コンテキスト構築
	var attacker_context = ConditionChecker.build_battle_context(
		attacker.creature_data, defender.creature_data, tile_info,
		{
			"player_lands": player_lands,
			"battle_tile_index": battle_tile_index,
			"player_id": attacker_index,
			"board_system": board_system_ref,
			"game_flow_manager": game_flow_manager_ref,
			"is_placed_on_tile": false,
			"enemy_mhp_override": defender.get_max_hp(),
			"enemy_name": defender.creature_data.get("name", ""),
			"opponent": defender,
			"is_attacker": true
		}
	)
	
	var defender_lands = board_system_ref.get_player_lands_by_element(defender.player_id) if defender.player_id >= 0 else {}
	var defender_context = ConditionChecker.build_battle_context(
		defender.creature_data, attacker.creature_data, tile_info,
		{
			"player_lands": defender_lands,
			"battle_tile_index": battle_tile_index,
			"player_id": defender.player_id,
			"board_system": board_system_ref,
			"game_flow_manager": game_flow_manager_ref,
			"is_attacker": false,
			"is_placed_on_tile": true,
			"enemy_mhp_override": attacker.get_max_hp(),
			"enemy_name": attacker.creature_data.get("name", ""),
			"opponent": attacker,
			"is_defender": true
		}
	)
	
	# 【Phase 2】各スキルを順番に適用（アニメーション付き）
	await _apply_skills_with_animation(attacker, attacker_context)
	await _apply_skills_with_animation(defender, defender_context)
	
	# 【Phase 3】貫通・巻物攻撃による土地ボーナス無効化
	if not defender.has_squid_mantle:
		defender_before = _snapshot_stats(defender)
		PenetrationSkill.apply_penetration(attacker, defender)
		# 敵対象スキル: attackerがスキル所持者、defenderが効果対象
		var penetration_name = SkillDisplayConfig.get_skill_name("penetration")
		await _show_skill_change_if_any(defender, defender_before, penetration_name, attacker)
	else:
		print("【スクイドマントル】貫通を無効化")
	
	if attacker.is_using_scroll and defender.land_bonus_hp > 0:
		# 巻物強打か巻物攻撃かを判定
		var attacker_ability = attacker.creature_data.get("ability_parsed", {})
		var attacker_keywords = attacker_ability.get("keywords", [])
		var is_scroll_power_strike = "巻物強打" in attacker_keywords
		var scroll_skill_key = "scroll_power_strike" if is_scroll_power_strike else "scroll_attack"
		var scroll_skill_name = "巻物強打" if is_scroll_power_strike else "巻物攻撃"
		print("【%s】防御側の土地ボーナス %d を無効化" % [scroll_skill_name, defender.land_bonus_hp])
		defender_before = _snapshot_stats(defender)
		defender.land_bonus_hp = 0
		# 敵対象スキル: attackerがスキル所持者、defenderが効果対象
		var scroll_name = SkillDisplayConfig.get_skill_name(scroll_skill_key)
		await _show_skill_change_if_any(defender, defender_before, scroll_name, attacker)
	
	# 💰 EP獲得スキル適用（バトル開始時）
	await apply_magic_gain_on_battle_start(attacker, defender)
	
	return result


## ツインスパイク用：変身後のスキル再計算
## 変身したクリーチャーのスキルを再適用する
func recalculate_skills_after_transform(participant: BattleParticipant, context: Dictionary) -> void:
	print("[スキル再計算] ", participant.creature_data.get("name", "?"), " のスキルを再適用")
	
	# スキルによるボーナスをリセット（変身後の素のステータスから再計算）
	participant.resonance_bonus_hp = 0
	participant.temporary_bonus_hp = 0
	# 注: spell_bonus_hp, item_bonus_hp, land_bonus_hpは変身処理で適切に設定済み
	
	# 全スキルを再適用
	await _apply_skills_with_animation(participant, context)
	
	print("[スキル再計算完了] AP:", participant.current_ap, " HP:", participant.current_hp)


## スキルを順番に適用（アニメーション付き）
func _apply_skills_with_animation(participant: BattleParticipant, context: Dictionary) -> void:
	@warning_ignore("unused_variable")
	var _SkillSpecialCreatureScript = load("res://scripts/battle/skills/skill_special_creature.gd")
	var before: Dictionary
	
	# 共通の表示名
	var stat_change_name = SkillDisplayConfig.get_skill_name("stat_change")
	var resonance_name = SkillDisplayConfig.get_skill_name("resonance")
	var scroll_attack_name = SkillDisplayConfig.get_skill_name("scroll_attack")
	var power_strike_name = SkillDisplayConfig.get_skill_name("power_strike")
	
	# 0. アイテムクリーチャーのクリーチャー時効果
	if SkillItemCreature.is_item_creature(participant.creature_data):
		before = _snapshot_stats(participant)
		SkillItemCreature.apply_as_creature(participant, board_system_ref)
		await _show_skill_change_if_any(participant, before, stat_change_name)
	elif participant.creature_data.get("has_living_clove_effect", false):
		before = _snapshot_stats(participant)
		SkillItemCreature.apply_living_clove_stat(participant, board_system_ref)
		await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 0.1. オーガロード
	var creature_id = participant.creature_data.get("id", -1)
	if creature_id == 407:
		before = _snapshot_stats(participant)
		var ogre_player_id = context.get("player_id", 0)
		SpecialCreatureSkill.apply_ogre_lord_bonus(participant, ogre_player_id, board_system_ref)
		await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 0.5. ターン数ボーナス
	before = _snapshot_stats(participant)
	apply_turn_number_bonus(participant, context)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 1. 感応スキル（固有名を維持）
	before = _snapshot_stats(participant)
	ResonanceSkill.apply(participant, context)
	await _show_skill_change_if_any(participant, before, resonance_name)
	
	# 3. 土地数比例効果
	before = _snapshot_stats(participant)
	apply_land_count_effects(participant, context)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 3.5. 破壊数効果
	before = _snapshot_stats(participant)
	apply_destroy_count_effects(participant)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 3.6. 手札数効果
	before = _snapshot_stats(participant)
	var player_id = context.get("player_id", 0)
	apply_hand_count_effects(participant, player_id, card_system_ref)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 3.7. 常時補正効果
	before = _snapshot_stats(participant)
	apply_constant_stat_bonus(participant)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 3.8. 戦闘地条件効果
	before = _snapshot_stats(participant)
	apply_battle_condition_effects(participant, context)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 3.9. Phase 3-B 効果
	before = _snapshot_stats(participant)
	apply_phase_3b_effects(participant, context)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 3.10. Phase 3-C 効果
	before = _snapshot_stats(participant)
	apply_phase_3c_effects(participant, context)
	await _show_skill_change_if_any(participant, before, stat_change_name)
	
	# 4. 先制・後手スキル（HP/AP変化なし、表示のみ）
	var strike_skills = FirstStrikeSkill.apply(participant)
	for skill_type in strike_skills:
		await _show_skill_no_stat_change(participant, skill_type)
	
	# 5. 強打スキル（固有名を維持）
	before = _snapshot_stats(participant)
	apply_power_strike_skills(participant, context)
	await _show_skill_change_if_any(participant, before, power_strike_name)
	
	# 6. 巻物攻撃判定
	ScrollAttackSkill.apply(participant, context)
	
	# 7. 2回攻撃スキル
	check_double_attack(participant, context)
	
	# 8. 巻物使用時のAP固定（巻物攻撃 or 巻物強打を区別して表示）
	if participant.is_using_scroll:
		before = _snapshot_stats(participant)
		_apply_scroll_ap_fix(participant, context)
		# 巻物強打を持っているか判定
		var ability_parsed_scroll = participant.creature_data.get("ability_parsed", {})
		var keywords_scroll = ability_parsed_scroll.get("keywords", [])
		var scroll_display_name: String
		if "巻物強打" in keywords_scroll:
			scroll_display_name = SkillDisplayConfig.get_skill_name("scroll_power_strike")
		else:
			scroll_display_name = scroll_attack_name
		await _show_skill_change_if_any(participant, before, scroll_display_name)


## 巻物使用時のAP固定処理
## 注: 巻物強打の×1.5は SkillScrollAttack.apply() 内で処理済み
func _apply_scroll_ap_fix(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	
	# 巻物強打の場合は SkillScrollAttack.apply() で処理済みなので何もしない
	if "巻物強打" in keywords:
		print("【AP最終確認】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap, "（巻物強打適用済み）")
		return
	
	# 巻物攻撃のみの場合
	var scroll_config = keyword_conditions.get("巻物攻撃", {})
	var scroll_type = scroll_config.get("scroll_type", "base_ap")
	
	match scroll_type:
		"fixed_ap":
			var value = scroll_config.get("value", 0)
			participant.current_ap = value
			print("【AP最終固定】", participant.creature_data.get("name", "?"), " AP:", value)
		"base_ap":
			var base_ap = participant.creature_data.get("ap", 0)
			participant.current_ap = base_ap
			print("【AP最終固定】", participant.creature_data.get("name", "?"), " AP=基本AP:", base_ap)
		"land_count":
			var elements = scroll_config.get("elements", [])
			var multiplier = scroll_config.get("multiplier", 1)
			var total_count = 0
			if board_system_ref:
				var scroll_player_id = context.get("player_id", 0)
				for element in elements:
					total_count += board_system_ref.count_creatures_by_element(scroll_player_id, element)
			var calculated_ap = total_count * multiplier
			participant.current_ap = calculated_ap
			print("【AP最終固定】", participant.creature_data.get("name", "?"), " AP=", elements, "土地数", total_count, "×", multiplier, "=", calculated_ap)


## ステータスのスナップショットを取得
func _snapshot_stats(participant: BattleParticipant) -> Dictionary:
	return {
		"current_hp": participant.current_hp,
		"current_ap": participant.current_ap,
		"resonance_bonus_hp": participant.resonance_bonus_hp,
		"temporary_bonus_hp": participant.temporary_bonus_hp,
		"spell_bonus_hp": participant.spell_bonus_hp,
		"land_bonus_hp": participant.land_bonus_hp,
		"item_bonus_hp": participant.item_bonus_hp
	}


## ステータス変化があったかチェック
func _has_stat_change(participant: BattleParticipant, before: Dictionary) -> bool:
	return (
		participant.current_hp != before["current_hp"] or
		participant.current_ap != before["current_ap"] or
		participant.resonance_bonus_hp != before["resonance_bonus_hp"] or
		participant.temporary_bonus_hp != before["temporary_bonus_hp"] or
		participant.spell_bonus_hp != before["spell_bonus_hp"] or
		participant.land_bonus_hp != before["land_bonus_hp"] or
		participant.item_bonus_hp != before["item_bonus_hp"]
	)


## スキル適用後に変化があればアニメーション表示
## participant: 変化をチェックしてバー更新する対象
## before: スナップショット
## skill_name: スキル名
## skill_owner: スキル名を表示する側（省略時はparticipant自身）
##
## 使い方:
##   自己バフ: _show_skill_change_if_any(attacker, before, "感応")
##   敵対象:   _show_skill_change_if_any(defender, before, "貫通", attacker)
func _show_skill_change_if_any(participant: BattleParticipant, before: Dictionary, skill_name: String, skill_owner: BattleParticipant = null) -> void:
	if not _has_stat_change(participant, before):
		return
	
	var display_owner = skill_owner if skill_owner else participant
	
	# スキル所持者と効果対象が同じ場合
	if display_owner == participant:
		await _show_skill_change(participant, skill_name)
	else:
		# スキル所持者と効果対象が異なる場合
		await _show_skill_change_owner_target(display_owner, participant, skill_name)


## ステータス変化のないスキル表示（先制、後手など）
##
## @param participant スキル所持者
## @param effect_type スキルのeffect_type（SkillDisplayConfigのキー）
func _show_skill_no_stat_change(participant: BattleParticipant, effect_type: String) -> void:
	if not battle_screen_manager:
		return
	
	var side = "attacker" if participant.is_attacker else "defender"
	var skill_name = SkillDisplayConfig.get_skill_name(effect_type)
	
	# スキル名表示のみ（HP/AP更新なし）
	await battle_screen_manager.show_skill_activation(side, skill_name, {})


## BattleParticipantからHP表示用データを作成
func _create_hp_data(participant: BattleParticipant) -> Dictionary:
	return {
		"base_hp": participant.base_hp,
		"base_up_hp": participant.base_up_hp,
		"item_bonus_hp": participant.item_bonus_hp,
		"resonance_bonus_hp": participant.resonance_bonus_hp,
		"temporary_bonus_hp": participant.temporary_bonus_hp,
		"spell_bonus_hp": participant.spell_bonus_hp,
		"land_bonus_hp": participant.land_bonus_hp,
		"current_hp": participant.current_hp,
		"display_max": participant.base_hp + participant.base_up_hp + \
					   participant.item_bonus_hp + participant.resonance_bonus_hp + \
					   participant.temporary_bonus_hp + participant.spell_bonus_hp + \
					   participant.land_bonus_hp
	}


## BattleParticipantから表示用データを作成（変身時のカード更新用）
func _create_display_data(participant: BattleParticipant) -> Dictionary:
	var data = participant.creature_data.duplicate(true)
	data["base_up_hp"] = participant.base_up_hp
	data["item_bonus_hp"] = participant.item_bonus_hp
	data["resonance_bonus_hp"] = participant.resonance_bonus_hp
	data["temporary_bonus_hp"] = participant.temporary_bonus_hp
	data["spell_bonus_hp"] = participant.spell_bonus_hp
	data["land_bonus_hp"] = participant.land_bonus_hp
	data["current_hp"] = participant.current_hp
	data["current_ap"] = participant.current_ap
	return data


## スキル変化をバトル画面に表示
func _show_skill_change(participant: BattleParticipant, skill_name: String) -> void:
	if not battle_screen_manager:
		return
	
	var side = "attacker" if participant.is_attacker else "defender"
	var hp_data = _create_hp_data(participant)
	
	# スキル名表示 + HP/AP更新
	await battle_screen_manager.show_skill_activation(side, skill_name, {
		"hp_data": hp_data,
		"ap": participant.current_ap
	})


## 合体が発生した場合、バトル画面に表示
func _show_merge_if_any(participant: BattleParticipant, side: String) -> void:
	if not battle_screen_manager:
		return
	
	# 合体フラグをチェック
	if not participant.creature_data.get("_was_merged", false):
		return
	
	var merged_name = participant.creature_data.get("_merged_result_name", "?")
	var skill_name = SkillDisplayConfig.get_skill_name("merge")
	var display_name = "%s[%s]" % [skill_name, merged_name]
	
	# 合体スキル名を表示（ステータス更新なし）
	await battle_screen_manager.show_skill_activation(side, display_name, {})
	
	# 表示後にフラグをクリア（再表示防止）
	participant.creature_data.erase("_was_merged")
	participant.creature_data.erase("_merged_result_name")


## アイテム使用をバトル画面に表示（ステータス変化に関係なく常に表示）
## ウォーロックディスク（能力無効化アイテム）は除外（別フェーズで表示済み）
func _show_item_effect_if_any(participant: BattleParticipant, _before: Dictionary, side: String) -> void:
	if not battle_screen_manager:
		return
	
	# アイテムがない場合は表示しない（破壊された場合など）
	var items = participant.creature_data.get("items", [])
	if items.is_empty():
		return
	
	# アイテム名を取得
	var item = items[0]
	var item_type = item.get("type", "")
	
	# ウォーロックディスク（能力無効化アイテム）は除外
	# 能力無効化フェーズで「戦闘中能力無効」として表示済み
	if _is_nullify_abilities_item(item):
		return
	
	var display_name: String
	if item_type == "creature":
		# 援護クリーチャー: 「援護[クリーチャー名]」形式
		var creature_name = item.get("name", "?")
		var skill_name = SkillDisplayConfig.get_skill_name("assist")
		display_name = "%s[%s]" % [skill_name, creature_name]
	else:
		# 通常アイテム: 「アイテム名 を使用」形式
		display_name = "%s を使用" % item.get("name", "アイテム")
	
	var hp_data = _create_hp_data(participant)
	
	# アイテム名表示 + HP/AP更新
	await battle_screen_manager.show_skill_activation(side, display_name, {
		"hp_data": hp_data,
		"ap": participant.current_ap
	})


## アイテムが能力無効化効果（ウォーロックディスク）を持っているかチェック
func _is_nullify_abilities_item(item: Dictionary) -> bool:
	var effect_parsed = item.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	for effect in effects:
		if effect.get("effect_type") == "nullify_all_enemy_abilities":
			return true
	return false


## ウォーロックディスク（能力無効化アイテム）の名前を取得
func _get_warlock_disk_name(participant: BattleParticipant) -> String:
	var items = participant.creature_data.get("items", [])
	for item in items:
		if _is_nullify_abilities_item(item):
			return item.get("name", "ウォーロックディスク")
	return "ウォーロックディスク"


## 呪い効果を適用（バトル画面セットアップ後に呼び出し）
## エフェクト表示付きで呪いを適用する
func _apply_curse_effects(attacker: BattleParticipant, defender: BattleParticipant, battle_tile_index: int) -> void:
	# battle_preparationからcurse_applierを取得
	if not battle_preparation_ref:
		return
	
	var curse_applier = battle_preparation_ref.curse_applier
	if not curse_applier:
		return
	
	# 攻撃側の呪い適用（移動侵略の場合のみ呪いがある可能性）
	var attacker_before = _snapshot_stats(attacker)
	curse_applier.apply_creature_curses(attacker, battle_tile_index)
	await _show_curse_effect_if_changed(attacker, attacker_before, "attacker")
	
	# 防御側の呪い適用
	var defender_before = _snapshot_stats(defender)
	curse_applier.apply_creature_curses(defender, battle_tile_index)
	await _show_curse_effect_if_changed(defender, defender_before, "defender")


## 呪い効果によるステータス変化があった場合にエフェクト表示
func _show_curse_effect_if_changed(participant: BattleParticipant, before: Dictionary, side: String) -> void:
	if not battle_screen_manager:
		return
	
	# 呪い情報を取得
	var curse = participant.creature_data.get("curse", {})
	var curse_type = curse.get("curse_type", "")
	var curse_name = curse.get("name", "")
	var display_name = "呪い[%s]" % curse_name if curse_name else "呪い"
	
	# ステータスが変化していなければ表示しない
	var hp_changed = participant.current_hp != before.get("current_hp", 0) or \
					 participant.temporary_bonus_hp != before.get("temporary_bonus_hp", 0)
	var ap_changed = participant.current_ap != before.get("current_ap", 0)
	
	if not hp_changed and not ap_changed:
		# 無効化系の呪いもチェック
		if curse_type in ["metal_form", "magic_barrier"]:
			await battle_screen_manager.show_skill_activation(side, display_name, {})
		return
	
	var hp_data = _create_hp_data(participant)
	
	# 呪い名表示 + HP/AP更新
	await battle_screen_manager.show_skill_activation(side, display_name, {
		"hp_data": hp_data,
		"ap": participant.current_ap
	})


## 呪いによるステータス変更効果をバトル画面に表示
## 対象: stat_boost, stat_reduce, ap_nullify, random_stat
## 注: この関数は後方互換性のために残しているが、_apply_curse_effectsを使用推奨
func _show_curse_stat_effect_if_any(participant: BattleParticipant, side: String) -> void:
	if not battle_screen_manager:
		return
	
	# 呪いがない場合は表示しない
	var curse = participant.creature_data.get("curse", {})
	if curse.is_empty():
		return
	
	var curse_type = curse.get("curse_type", "")
	var curse_name = curse.get("name", "")
	
	# ステータス変更系の呪いのみ表示（無効化系は効果発揮時に表示）
	var stat_change_curses = ["stat_boost", "stat_reduce", "ap_nullify", "random_stat"]
	if not curse_type in stat_change_curses:
		return
	
	# 「呪い[呪い名]」形式で表示
	var display_name = "呪い[%s]" % curse_name if curse_name else "呪い"
	
	var hp_data = _create_hp_data(participant)
	
	# 呪い名表示 + HP/AP更新
	await battle_screen_manager.show_skill_activation(side, display_name, {
		"hp_data": hp_data,
		"ap": participant.current_ap
	})


## スキル変化をバトル画面に表示（スキル所持者と効果対象が異なる場合）
## skill_owner: スキル名を表示する側
## target: HP/APバーを更新する側
func _show_skill_change_owner_target(skill_owner: BattleParticipant, target: BattleParticipant, skill_name: String) -> void:
	if not battle_screen_manager:
		return
	
	var owner_side = "attacker" if skill_owner.is_attacker else "defender"
	var target_side = "attacker" if target.is_attacker else "defender"
	var target_hp_data = _create_hp_data(target)
	
	# スキル所持者側にスキル名表示
	await battle_screen_manager.show_skill_activation(owner_side, skill_name, {})
	# 効果対象側のHP/APバー更新
	await battle_screen_manager.update_hp(target_side, target_hp_data)
	await battle_screen_manager.update_ap(target_side, target.current_ap)


## スキル適用（従来版・内部用）
func apply_skills(participant: BattleParticipant, context: Dictionary) -> void:
	
	var _has_scroll_power_strike = PowerStrikeSkill.has_scroll_power_strike(participant.creature_data)
	
	# 0. アイテムクリーチャーのクリーチャー時効果を適用
	if SkillItemCreature.is_item_creature(participant.creature_data):
		SkillItemCreature.apply_as_creature(participant, board_system_ref)
	# リビングクローブをアイテムとして使用した場合（フラグで判定）
	elif participant.creature_data.get("has_living_clove_effect", false):
		SkillItemCreature.apply_living_clove_stat(participant, board_system_ref)
	
	# 0.1. オーガロード（ID: 407）: オーガ配置時能力値上昇
	var creature_id = participant.creature_data.get("id", -1)
	if creature_id == 407:
		var ogre_player_id = context.get("player_id", 0)
		SpecialCreatureSkill.apply_ogre_lord_bonus(participant, ogre_player_id, board_system_ref)
	
	# 0.5. ターン数ボーナスを適用（最優先、他のスキルより前）
	apply_turn_number_bonus(participant, context)
	
	# 1. 感応スキルを適用
	ResonanceSkill.apply(participant, context)
	
	# 3. 土地数比例効果を適用（Phase 3追加）
	apply_land_count_effects(participant, context)
	
	# 3.5. 破壊数効果を適用（ソウルコレクター用）
	apply_destroy_count_effects(participant)
	
	# 3.6. 手札数効果を適用（リリス用）
	var player_id = context.get("player_id", 0)
	apply_hand_count_effects(participant, player_id, card_system_ref)
	
	# 3.7. 常時補正効果を適用（アイスウォール、トルネード用）
	apply_constant_stat_bonus(participant)
	
	# 3.8. 戦闘地条件効果を適用（アンフィビアン、カクタスウォール用）
	apply_battle_condition_effects(participant, context)
	
	# 3.9. Phase 3-B 効果（ガーゴイル、ネッシー、バーンタイタン等）
	apply_phase_3b_effects(participant, context)
	
	# 3.10. Phase 3-C 効果（ローンビースト、ジェネラルカン）
	apply_phase_3c_effects(participant, context)
	
	# 4. 先制・後手スキルを適用
	FirstStrikeSkill.apply(participant)
	
	# 5. 強打スキルを適用（巻物強打を含む）
	apply_power_strike_skills(participant, context)
	
	# 6. 巻物攻撃判定
	ScrollAttackSkill.apply(participant, context)
	
	# 7. 2回攻撃スキルを判定
	check_double_attack(participant, context)
	
	# 8. 巻物使用中の場合、AP最終確認
	# 注: 巻物強打の×1.5は SkillScrollAttack.apply() 内で処理済み
	if participant.is_using_scroll:
		var ability_parsed = participant.creature_data.get("ability_parsed", {})
		var keywords = ability_parsed.get("keywords", [])
		
		# 巻物強打の場合は SkillScrollAttack.apply() で処理済み
		if "巻物強打" in keywords:
			print("【AP最終確認】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap, "（巻物強打適用済み）")
		else:
			# 巻物攻撃のみの場合、AP最終固定
			var keyword_conditions = ability_parsed.get("keyword_conditions", {})
			var scroll_config = keyword_conditions.get("巻物攻撃", {})
			var scroll_type = scroll_config.get("scroll_type", "base_ap")
			var board_system = board_system_ref
			
			match scroll_type:
				"fixed_ap":
					var value = scroll_config.get("value", 0)
					participant.current_ap = value
					print("【AP最終固定】", participant.creature_data.get("name", "?"), 
						  " AP:", value)
				"base_ap":
					var base_ap = participant.creature_data.get("ap", 0)
					participant.current_ap = base_ap
					print("【AP最終固定】", participant.creature_data.get("name", "?"), 
						  " AP=基本AP:", base_ap)
				"land_count":
					var elements = scroll_config.get("elements", [])
					var multiplier = scroll_config.get("multiplier", 1)
					var total_count = 0
					if board_system:
						var scroll_player_id = context.get("player_id", 0)
						for element in elements:
							total_count += board_system.count_creatures_by_element(scroll_player_id, element)
					var calculated_ap = total_count * multiplier
					participant.current_ap = calculated_ap
					print("【AP最終固定】", participant.creature_data.get("name", "?"), 
						  " AP=", elements, "土地数", total_count, "×", multiplier, "=", calculated_ap)

## 2回攻撃スキル判定
func check_double_attack(participant: BattleParticipant, context: Dictionary) -> void:
	# スクイドマントルチェック：防御側がスクイドマントルを持つ場合は2回攻撃無効化
	var opponent = context.get("opponent")
	if opponent and opponent.has_squid_mantle and context.get("is_attacker", false):
		print("【スクイドマントル】", participant.creature_data.get("name", "?"), "の2回攻撃を無効化")
		return
	
	DoubleAttackSkill.apply(participant)

## 強打スキル適用（巻物強打を含む）
func apply_power_strike_skills(participant: BattleParticipant, context: Dictionary) -> void:
	# スクイドマントルチェック：防御側がスクイドマントルを持つ場合は強打無効化
	var opponent = context.get("opponent")
	if opponent and opponent.has_squid_mantle and context.get("is_attacker", false):
		print("【スクイドマントル】", participant.creature_data.get("name", "?"), "の強打を無効化")
		return
	
	PowerStrikeSkill.apply(participant, context)
	print("【強打適用後】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap)


## 土地数比例効果を適用（Phase 3追加）
## 委譲先: SkillStatModifiers.apply_land_count_effects
func apply_land_count_effects(participant: BattleParticipant, context: Dictionary) -> void:
	SkillStatModifiers.apply_land_count_effects(participant, context)


## アイテム破壊・盗み処理（戦闘開始前）
func apply_item_manipulation(first: BattleParticipant, second: BattleParticipant) -> void:
	"""
	先制攻撃の順序でアイテム破壊・盗みを処理
	
	@param first: 先に行動する側
	@param second: 後に行動する側
	"""
	var results = ItemManipulationSkill.apply(first, second)
	
	# 発動したスキルをバトル画面に表示
	for result in results:
		var actor = result.get("actor")
		var skill_type = result.get("skill_type", "")
		if actor and skill_type and battle_screen_manager:
			var side = "attacker" if actor.is_attacker else "defender"
			var skill_name = SkillDisplayConfig.get_skill_name(skill_type)
			await battle_screen_manager.show_skill_activation(side, skill_name, {})

## ターン数ボーナスを適用（ラーバキン用）
## ターン数ボーナスを適用（ラーバキン用）
## 委譲先: SkillStatModifiers.apply_turn_number_bonus
func apply_turn_number_bonus(participant: BattleParticipant, context: Dictionary) -> void:
	var game_flow_manager = context.get("game_flow_manager", game_flow_manager_ref)
	SkillStatModifiers.apply_turn_number_bonus(participant, context, game_flow_manager)

# ========================================
# 破壊数カウント効果
# ========================================

## 破壊数カウント効果を適用（ソウルコレクター用）
## 委譲先: SkillStatModifiers.apply_destroy_count_effects
func apply_destroy_count_effects(participant: BattleParticipant):
	SkillStatModifiers.apply_destroy_count_effects(participant, lap_system)

## Phase 3-C効果を適用（ローンビースト、ジェネラルカン）
## Phase 3-C効果を適用（ローンビースト、ジェネラルカン）
## 委譲先: SkillStatModifiers.apply_phase_3c_effects
func apply_phase_3c_effects(participant: BattleParticipant, context: Dictionary):
	SkillStatModifiers.apply_phase_3c_effects(participant, context, board_system_ref)

## Phase 3-B効果を適用（中程度の条件効果）
## 委譲先: SkillStatModifiers.apply_phase_3b_effects
func apply_phase_3b_effects(participant: BattleParticipant, context: Dictionary):
	SkillStatModifiers.apply_phase_3b_effects(participant, context, board_system_ref)

## 💰 バトル開始時のEP獲得スキルを適用
func apply_magic_gain_on_battle_start(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	"""
	バトル開始時に発動するEP獲得スキルをまとめて適用
	- 侵略時EP獲得（攻撃側のみ）
	- 無条件EP獲得（両側）
	"""
	# spell_magic_refを直接使う（BattleParticipantから取得）
	var spell_magic = attacker.spell_magic_ref
	if not spell_magic:
		return
	
	# EP獲得スキルを適用
	var activated = _skill_magic_gain.apply_on_battle_start(attacker, defender, spell_magic)
	
	# 発動したスキルをバトル画面に表示
	for participant in activated:
		if battle_screen_manager:
			var side = "attacker" if participant.is_attacker else "defender"
			var skill_name = SkillDisplayConfig.get_skill_name("magic_gain")
			await battle_screen_manager.show_skill_activation(side, skill_name, {})

## 戦闘地条件効果を適用（アンフィビアン、カクタスウォール用）
## 戦闘地条件効果を適用（アンフィビアン、カクタスウォール用）
## 委譲先: SkillStatModifiers.apply_battle_condition_effects
func apply_battle_condition_effects(participant: BattleParticipant, context: Dictionary):
	SkillStatModifiers.apply_battle_condition_effects(participant, context)

## 常時補正効果を適用（アイスウォール、トルネード用）
## 委譲先: SkillStatModifiers.apply_constant_stat_bonus
func apply_constant_stat_bonus(participant: BattleParticipant):
	SkillStatModifiers.apply_constant_stat_bonus(participant)

## 手札数効果を適用（リリス用）
## 委譲先: SkillStatModifiers.apply_hand_count_effects
func apply_hand_count_effects(participant: BattleParticipant, player_id: int, card_system):
	SkillStatModifiers.apply_hand_count_effects(participant, player_id, card_system)

## ウォーロックディスクチェック
##
## パーティシパントがウォーロックディスクを装備しているかチェック
##
## @param participant チェック対象のパーティシパント
## @return ウォーロックディスクを装備していればtrue
func _has_warlock_disk(participant: BattleParticipant) -> bool:
	var items = participant.creature_data.get("items", [])
	
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type") == "nullify_all_enemy_abilities":
				return true
	
	return false

## skill_nullify 呪いを持っているかチェック
func _has_skill_nullify_curse(participant: BattleParticipant) -> bool:
	return SpellCurseBattle.has_skill_nullify(participant.creature_data)


## クリーチャー能力による能力無効化を持っているかチェック（シーボンズなど）
func _has_nullify_creature_ability(participant: BattleParticipant) -> bool:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	for effect in effects:
		if effect.get("effect_type") == "nullify_all_enemy_abilities":
			return true
	return false


## 戦闘開始時条件チェック（スラッジタイタン、ギガンテリウム等）
func _apply_battle_start_conditions(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	var attacker_context = {"creature_data": attacker.creature_data}
	var defender_context = {"creature_data": defender.creature_data}
	SkillBattleStartConditions.apply(attacker, attacker_context)
	SkillBattleStartConditions.apply(defender, defender_context)


## 素の先制を持っているかチェック（クリーチャー能力のみ、アイテム除く）
## アイテム破壊・盗みの順序決定に使用
func _has_raw_first_strike(participant: BattleParticipant) -> bool:
	var keywords = participant.creature_data.get("keywords", [])
	if "先制" in keywords:
		return true
	
	# ability_parsed内のeffectsもチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "first_strike":
			return true
	
	return false


# ============================================================
# シミュレーション用関数（CPUのBattleSimulatorから呼び出される）
# ============================================================

## シミュレーション用：UI表示なしでスキルを適用
## CPUのBattleSimulatorから呼び出される
## @param participants: {"attacker": BattleParticipant, "defender": BattleParticipant}
## @param tile_info: タイル情報（index, element, level, owner等）
## @param attacker_index: 攻撃側プレイヤーID
func apply_skills_for_simulation(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> void:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	var battle_tile_index = tile_info.get("index", -1)
	
	# プレイヤー土地情報取得
	var attacker_lands = {}
	var defender_lands = {}
	if board_system_ref:
		attacker_lands = board_system_ref.get_player_lands_by_element(attacker_index)
		defender_lands = board_system_ref.get_player_lands_by_element(defender.player_id) if defender.player_id >= 0 else {}
	
	# 応援スキル適用
	SupportSkill.apply_to_all(participants, battle_tile_index, board_system_ref)
	
	# コンテキスト構築（攻撃側）
	var attacker_context = ConditionChecker.build_battle_context(
		attacker.creature_data, defender.creature_data, tile_info,
		{
			"player_lands": attacker_lands,
			"battle_tile_index": battle_tile_index,
			"player_id": attacker_index,
			"board_system": board_system_ref,
			"game_flow_manager": game_flow_manager_ref,
			"is_placed_on_tile": false,
			"enemy_mhp_override": defender.get_max_hp(),
			"enemy_name": defender.creature_data.get("name", ""),
			"opponent": defender,
			"is_attacker": true
		}
	)
	
	# コンテキスト構築（防御側）
	var defender_context = ConditionChecker.build_battle_context(
		defender.creature_data, attacker.creature_data, tile_info,
		{
			"player_lands": defender_lands,
			"battle_tile_index": battle_tile_index,
			"player_id": defender.player_id,
			"board_system": board_system_ref,
			"game_flow_manager": game_flow_manager_ref,
			"is_attacker": false,
			"is_placed_on_tile": true,
			"enemy_mhp_override": attacker.get_max_hp(),
			"enemy_name": attacker.creature_data.get("name", ""),
			"opponent": attacker,
			"is_defender": true
		}
	)
	
	# 各スキル適用（UI表示なし）
	apply_skills(attacker, attacker_context)
	apply_skills(defender, defender_context)
	
	# 貫通判定
	if not defender.has_squid_mantle:
		PenetrationSkill.apply_penetration(attacker, defender)
	
	# 巻物攻撃による土地ボーナス無効化
	if attacker.is_using_scroll and defender.land_bonus_hp > 0:
		defender.land_bonus_hp = 0
