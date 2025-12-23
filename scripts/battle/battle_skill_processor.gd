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
const SkillDisplayConfig = preload("res://scripts/battle_screen/skill_display_config.gd")
# SkillPermanentBuff, SkillBattleStartConditions はグローバルクラスとして利用可能
var _skill_magic_gain = preload("res://scripts/battle/skills/skill_magic_gain.gd")

var board_system_ref = null
var game_flow_manager_ref = null
var card_system_ref = null
var battle_screen_manager = null
var battle_preparation_ref = null

func setup_systems(board_system, game_flow_manager = null, card_system = null, p_battle_screen_manager = null, battle_preparation = null):
	board_system_ref = board_system
	game_flow_manager_ref = game_flow_manager
	card_system_ref = card_system
	battle_screen_manager = p_battle_screen_manager
	battle_preparation_ref = battle_preparation

## バトル前スキル適用（async対応・スキル毎にアニメーション）
## 戻り値: { transform_result: Dictionary }
func apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> Dictionary:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	var attacker_used_item = participants.get("attacker_used_item", false)
	var defender_used_item = participants.get("defender_used_item", false)
	var battle_tile_index = tile_info.get("index", -1)
	
	var result = {"transform_result": {}}
	
	# 🚫 【最優先】能力無効化チェック: ウォーロックディスク or skill_nullify呪いがある場合
	var SkillSpecialCreatureScript = load("res://scripts/battle/skills/skill_special_creature.gd")
	var has_nullify = _has_warlock_disk(attacker) or _has_warlock_disk(defender) or _has_skill_nullify_curse(attacker) or _has_skill_nullify_curse(defender)
	
	if has_nullify:
		print("【能力無効化発動】全スキル・変身・応援をスキップして基礎ステータスでバトル")
		SkillSpecialCreatureScript.apply_nullify_enemy_abilities(attacker, defender)
		SkillSpecialCreatureScript.apply_nullify_enemy_abilities(defender, attacker)
		
		# 🎬 能力無効化スキル表示（どちらが持っているか判定）
		if battle_screen_manager:
			var skill_name = SkillDisplayConfig.get_skill_name("nullify_abilities")
			if _has_warlock_disk(attacker) or _has_skill_nullify_curse(attacker):
				await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
			elif _has_warlock_disk(defender) or _has_skill_nullify_curse(defender):
				await battle_screen_manager.show_skill_activation("defender", skill_name, {})
		
		# 能力無効化でもアイテム効果は適用（アイテム破壊スキルも無効化されるため）
		if battle_preparation_ref:
			battle_preparation_ref.apply_remaining_item_effects(attacker, defender, battle_tile_index)
		return result
	
	# ============================================================
	# 【Phase 0-T】変身スキル適用（戦闘開始時・アイテム適用前）
	# ============================================================
	# 変身後に土地ボーナスを再計算するため、アイテム適用前に処理
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
	# 【Phase 0-0】アイテム破壊・盗み（スキル計算前に実行）
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
	
	# アイテム使用フラグを更新（破壊された場合はfalseに）
	attacker_used_item = not attacker.creature_data.get("items", []).is_empty()
	defender_used_item = not defender.creature_data.get("items", []).is_empty()
	
	# アイテム効果適用（破壊されなかったアイテムのみ）
	var attacker_before_item = _snapshot_stats(attacker)
	var defender_before_item = _snapshot_stats(defender)
	
	if battle_preparation_ref:
		battle_preparation_ref.apply_remaining_item_effects(attacker, defender, battle_tile_index)
	
	# アイテム効果でステータスが変わった場合、アイテム名を表示してバトル画面を更新
	await _show_item_effect_if_any(attacker, attacker_before_item, "attacker")
	await _show_item_effect_if_any(defender, defender_before_item, "defender")
	
	# 合体が発生した場合、合体スキル名を表示
	await _show_merge_if_any(attacker, "attacker")
	await _show_merge_if_any(defender, "defender")
	
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
		print("【巻物攻撃】防御側の土地ボーナス ", defender.land_bonus_hp, " を無効化")
		defender_before = _snapshot_stats(defender)
		defender.land_bonus_hp = 0
		# 敵対象スキル: attackerがスキル所持者、defenderが効果対象
		var scroll_name = SkillDisplayConfig.get_skill_name("scroll_attack")
		await _show_skill_change_if_any(defender, defender_before, scroll_name, attacker)
	
	# 💰 魔力獲得スキル適用（バトル開始時）
	await apply_magic_gain_on_battle_start(attacker, defender)
	
	return result


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
	
	# 8. 巻物使用時のAP固定（固有名を維持）
	if participant.is_using_scroll:
		before = _snapshot_stats(participant)
		_apply_scroll_ap_fix(participant, context)
		await _show_skill_change_if_any(participant, before, scroll_attack_name)


## 巻物使用時のAP固定処理
func _apply_scroll_ap_fix(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
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


## アイテム効果の変化をバトル画面に表示（アイテム使用時のみ）
func _show_item_effect_if_any(participant: BattleParticipant, before: Dictionary, side: String) -> void:
	if not battle_screen_manager:
		return
	
	# アイテムがない場合は表示しない（破壊された場合など）
	var items = participant.creature_data.get("items", [])
	print("[アイテム表示チェック] ", side, " items=", items)
	if items.is_empty():
		print("  → アイテムなし、スキップ")
		return
	
	var hp_changed = participant.current_hp != before.get("current_hp", 0)
	var ap_changed = participant.current_ap != before.get("current_ap", 0)
	var item_hp_changed = participant.item_bonus_hp != before.get("item_bonus_hp", 0)
	
	print("  hp_changed=", hp_changed, " ap_changed=", ap_changed, " item_hp_changed=", item_hp_changed)
	print("  before: hp=", before.get("current_hp", 0), " ap=", before.get("current_ap", 0), " item_hp=", before.get("item_bonus_hp", 0))
	print("  after: hp=", participant.current_hp, " ap=", participant.current_ap, " item_hp=", participant.item_bonus_hp)
	
	if not hp_changed and not ap_changed and not item_hp_changed:
		print("  → 変化なし、スキップ")
		return
	
	# アイテム名を取得（援護クリーチャーの場合は「援護[クリーチャー名]」）
	var item = items[0]
	var display_name: String
	var item_type = item.get("type", "")
	if item_type == "creature":
		# 援護クリーチャー
		var creature_name = item.get("name", "?")
		var skill_name = SkillDisplayConfig.get_skill_name("assist")
		display_name = "%s[%s]" % [skill_name, creature_name]
	else:
		display_name = item.get("name", "アイテム")
	
	var hp_data = _create_hp_data(participant)
	
	# アイテム名表示 + HP/AP更新
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
	
	# 8. アイテム巻物が使用中の場合、AP を最終固定
	if participant.is_using_scroll:
		var ability_parsed = participant.creature_data.get("ability_parsed", {})
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
func apply_land_count_effects(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	# プレイヤーの土地情報を取得
	var player_lands = context.get("player_lands", {})
	
	for effect in effects:
		if effect.get("effect_type") == "land_count_multiplier":
			# 対象属性の土地数を合計
			var target_elements = effect.get("elements", [])
			var total_count = 0
			
			for element in target_elements:
				total_count += player_lands.get(element, 0)
			
						# multiplierを適用
			var multiplier = effect.get("multiplier", 1)
			var bonus = total_count * multiplier
			
			# operation（加算 or 代入）
			var operation = effect.get("operation", "add")
			
			# statに応じてボーナスを適用
			var stat = effect.get("stat", "ap")
			
			if stat == "ap" or stat == "both":
				var old_ap = participant.current_ap
				if operation == "set":
					participant.current_ap = bonus
				else:
					participant.current_ap += bonus
				print("【土地数比例】", participant.creature_data.get("name", "?"))
				print("  対象属性:", target_elements, " 合計土地数:", total_count)
				print("  AP: ", old_ap, " → ", participant.current_ap, " (", operation, " ", bonus, ")")
			
			if stat == "hp" or stat == "both":
				var old_hp = participant.current_hp
				if operation == "set":
					# setの場合は一度リセットしてから設定
					var base_mhp = participant.get_max_hp()
					participant.current_hp = base_mhp
					participant.temporary_bonus_hp = bonus - base_mhp
				else:
					participant.temporary_bonus_hp += bonus
				print("【土地数比例】", participant.creature_data.get("name", "?"))
				print("  対象属性:", target_elements, " 合計土地数:", total_count)
				print("  HP: ", old_hp, " → ", participant.current_hp, " (", operation, " ", bonus, ")")


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
func apply_turn_number_bonus(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "turn_number_bonus":
			# GameFlowManagerから現在のターン数を取得
			var game_flow_manager = context.get("game_flow_manager")
			if not game_flow_manager:
				print("【ターン数ボーナス】GameFlowManagerが見つかりません")
				print("  context keys: ", context.keys())
				print("  board_system_ref: ", board_system_ref)
				if board_system_ref:
					print("  board_system_ref.game_flow_manager: ", board_system_ref.game_flow_manager)
				return
			
			var current_turn = game_flow_manager.current_turn_number
			var ap_mode = effect.get("ap_mode", "add")
			var hp_mode = effect.get("hp_mode", "add")
			
			# AP処理
			var old_ap = participant.current_ap
			if ap_mode == "subtract":
				# STから現ターン数を引く
				participant.current_ap = max(0, participant.current_ap - current_turn)
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " ST減算: ", old_ap, " → ", participant.current_ap, " (-", current_turn, ")")
			elif ap_mode == "add":
				participant.current_ap += current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " ST+", current_turn, " (ターン", current_turn, ")")
			elif ap_mode == "override":
				# STを現ターン数で上書き
				participant.current_ap = current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " ST上書き: ", old_ap, " → ", current_turn, " (ターン", current_turn, ")")
			
			# HP処理
			if hp_mode == "add":
				# temporary_bonus_hpに現ターン数を加算
				participant.temporary_bonus_hp += current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP+", current_turn, " (ターン", current_turn, ")")
			elif hp_mode == "subtract":
				# temporary_bonus_hpから現ターン数を引く
				participant.temporary_bonus_hp -= current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP-", current_turn, " (ターン", current_turn, ")")
			
			return

# ========================================
# 破壊数カウント効果
# ========================================

# 破壊数カウント効果を適用（ソウルコレクター用）
func apply_destroy_count_effects(participant: BattleParticipant):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_count_multiplier":
			var stat = effect.get("stat", "ap")
			var multiplier = effect.get("multiplier", 5)
			
			# LapSystemから破壊数取得
			var destroy_count = 0
			if game_flow_manager_ref and game_flow_manager_ref.lap_system:
				destroy_count = game_flow_manager_ref.lap_system.get_destroy_count()
			
			var bonus_value = destroy_count * multiplier
			
			if stat == "ap":
				participant.temporary_bonus_ap += bonus_value
				participant.current_ap += bonus_value
				print("【破壊数効果】", participant.creature_data.get("name", "?"), 
					  " ST+", bonus_value, " (破壊数:", destroy_count, " × ", multiplier, ")")
			elif stat == "hp":
				participant.temporary_bonus_hp += bonus_value
				print("【破壊数効果】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus_value, " (破壊数:", destroy_count, " × ", multiplier, ")")

## Phase 3-C効果を適用（ローンビースト、ジェネラルカン）
func apply_phase_3c_effects(participant: BattleParticipant, context: Dictionary):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 1. 基礎APをHPに加算（ローンビースト）
		if effect_type == "base_ap_to_hp":
			var base_ap = participant.creature_data.get("ap", 0)
			var base_up_ap = participant.creature_data.get("base_up_ap", 0)
			var total_base_ap = base_ap + base_up_ap
			
			participant.temporary_bonus_hp += total_base_ap
			print("【基礎AP→HP】", participant.creature_data.get("name", "?"), 
				  " HP+", total_base_ap, " (基礎AP: ", base_ap, "+", base_up_ap, ")")
		
		# 2. 条件付き配置数カウント（ジェネラルカン）
		elif effect_type == "conditional_land_count":
			var creature_condition = effect.get("creature_condition", {})
			var stat = effect.get("stat", "ap")
			var multiplier = effect.get("multiplier", 5)
			
			# プレイヤーの全タイルを取得
			var player_id = context.get("player_id", 0)
			if not board_system_ref:
				continue
			
			var player_tiles = board_system_ref.get_player_tiles(player_id)
			var qualified_count = 0
			
			# 各タイルのクリーチャーが条件を満たすかチェック
			for tile in player_tiles:
				if not tile.creature_data:
					continue
				
				# 条件チェック
				var condition_type = creature_condition.get("condition_type", "")
				if condition_type == "mhp_above":
					var threshold = creature_condition.get("value", 50)
					# BattleParticipantのget_max_hp()を使用してMHP取得
					var creature_mhp = tile.creature_data.get("hp", 0) + tile.creature_data.get("base_up_hp", 0)
					if creature_mhp >= threshold:
						qualified_count += 1
			
			var bonus = qualified_count * multiplier
			
			if stat == "ap":
				participant.temporary_bonus_ap += bonus
				participant.current_ap += bonus
				print("【条件付き配置数】", participant.creature_data.get("name", "?"), 
					  " ST+", bonus, " (MHP50以上: ", qualified_count, " × ", multiplier, ")")
			elif stat == "hp":
				participant.temporary_bonus_hp += bonus
				print("【条件付き配置数】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus, " (MHP50以上: ", qualified_count, " × ", multiplier, ")")

## Phase 3-B効果を適用（中程度の条件効果）
func apply_phase_3b_effects(participant: BattleParticipant, context: Dictionary):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 1. 防御時固定ST（ガーゴイル） - 既存の条件チェック不要（is_attackerで直接判定）
		if effect_type == "defender_fixed_ap":
			var is_attacker = context.get("is_attacker", true)
			if not is_attacker:  # 防御側のみ
				var fixed_ap = effect.get("value", 50)
				participant.current_ap = fixed_ap
				print("【防御時固定ST】", participant.creature_data.get("name", "?"), 
					  " ST=", fixed_ap)
		
		# 2. 戦闘地レベル効果（ネッシー） - 既存のon_element_land条件を使用
		elif effect_type == "battle_land_level_bonus":
			var condition_data = effect.get("condition", {})
			var required_element = condition_data.get("battle_land_element", "water")
			
			# 既存のConditionCheckerを使用して属性チェック
			var checker = ConditionChecker.new()
			var element_condition = {
				"condition_type": "on_element_land",
				"element": required_element
			}
			var is_on_element = checker._evaluate_single_condition(element_condition, context)
			
			if is_on_element:
				var tile_level = context.get("tile_level", 1)
				var multiplier = effect.get("multiplier", 10)
				var bonus = tile_level * multiplier
				
				var stat = effect.get("stat", "hp")
				if stat == "hp":
					participant.temporary_bonus_hp += bonus
					print("【戦闘地レベル効果】", participant.creature_data.get("name", "?"), 
						  " HP+", bonus, " (レベル:", tile_level, " × ", multiplier, ")")
		
		# 3. 自領地数閾値効果（バーンタイタン）
		elif effect_type == "owned_land_threshold":
			var threshold = effect.get("threshold", 5)
			var operation = effect.get("operation", "gte")  # gte, lt, etc
			
			# BoardSystemから自領地数を取得
			var player_id = context.get("player_id", 0)
			var owned_land_count = 0
			if board_system_ref:
				owned_land_count = board_system_ref.get_player_owned_land_count(player_id)
			
			var condition_met = false
			if operation == "gte":
				condition_met = owned_land_count >= threshold
			
			if condition_met:
				var stat_changes = effect.get("stat_changes", {})
				var ap_change = stat_changes.get("ap", 0)
				var hp_change = stat_changes.get("hp", 0)
				
				if ap_change != 0:
					participant.temporary_bonus_ap += ap_change
					participant.current_ap += ap_change
					print("【自領地数閾値】", participant.creature_data.get("name", "?"), 
						  " ST", ("+" if ap_change >= 0 else ""), ap_change, 
						  " (自領地:", owned_land_count, ")")
				
				if hp_change != 0:
					participant.temporary_bonus_hp += hp_change
					print("【自領地数閾値】", participant.creature_data.get("name", "?"), 
						  " HP", ("+" if hp_change >= 0 else ""), hp_change, 
						  " (自領地:", owned_land_count, ")")
		
		# 4. 特定クリーチャーカウント（ハイプワーカー）
		elif effect_type == "specific_creature_count":
			var target_name = effect.get("target_name", "")
			var multiplier = effect.get("multiplier", 10)
			var include_self = effect.get("include_self", true)
			
			# BoardSystemから特定クリーチャーをカウント
			var player_id = context.get("player_id", 0)
			var creature_count = 0
			if board_system_ref:
				creature_count = board_system_ref.count_creatures_by_name(player_id, target_name)
			
			# 侵略側（配置されていない）の場合、自分を除外
			var is_placed = context.get("is_placed_on_tile", false)
			if include_self and is_placed:
				# 自分も含める（既にカウント済み）
				pass
			elif not is_placed and creature_count > 0:
				# 侵略側は自分を除外
				creature_count -= 1
			
			var bonus = creature_count * multiplier
			
			var stat_changes = effect.get("stat_changes", {})
			var affects_ap = stat_changes.get("ap", true)
			var affects_hp = stat_changes.get("hp", true)
			
			if affects_ap:
				participant.temporary_bonus_ap += bonus
				participant.current_ap += bonus
			
			if affects_hp:
				participant.temporary_bonus_hp += bonus
			
			print("【特定クリーチャーカウント】", participant.creature_data.get("name", "?"), 
				  " ST&HP+", bonus, " (", target_name, ":", creature_count, " × ", multiplier, ")")
		
		# 4.5. 種族配置数でステータス決定（レッドキャップ）
		elif effect_type == "race_creature_stat_replace":
			var target_race = effect.get("target_race", "")
			var multiplier = effect.get("multiplier", 20)
			
			# BoardSystemから特定種族をカウント（配置済みのみ）
			var player_id = context.get("player_id", 0)
			var race_count = 0
			if board_system_ref:
				race_count = board_system_ref.count_creatures_by_race(player_id, target_race)
			
			# 侵略側（配置されていない）は自分を含めない
			# count_creatures_by_raceは配置済みのみカウントするので追加処理不要
			
			var stat_value = int(race_count * multiplier)
			
			# ステータスを置き換え（基本値を上書き）
			participant.creature_data["ap"] = stat_value
			participant.creature_data["hp"] = stat_value
			participant.current_ap = stat_value
			participant.current_hp = stat_value
			# max_hpはget_max_hp()で計算されるため、creature_data["hp"]を設定すればOK
			
			print("【種族配置数ステータス】", participant.creature_data.get("name", "?"),
				  " AP&HP=", stat_value, " (", target_race, ":", race_count, " × ", multiplier, ")")
		
		# 5. 他属性カウント（リビングクローブ）- SkillItemCreatureで処理済みのためスキップ
		elif effect_type == "other_element_count":
			pass  # apply_skills()の先頭でSkillItemCreature.apply_as_creature()により処理済み
		
		# 6. 隣接自領地条件（タイガーヴェタ） - 既存の条件チェック機能を使用
		elif effect_type == "adjacent_owned_land":
			# 既存のConditionCheckerを使用
			var checker = ConditionChecker.new()
			var condition = {"condition_type": "adjacent_ally_land"}
			var has_adjacent_ally = checker._evaluate_single_condition(condition, context)
			
			if has_adjacent_ally:
				var stat_changes = effect.get("stat_changes", {})
				var ap_change = stat_changes.get("ap", 0)
				var hp_change = stat_changes.get("hp", 0)
				
				if ap_change != 0:
					participant.temporary_bonus_ap += ap_change
					participant.current_ap += ap_change
					print("【隣接自領地】", participant.creature_data.get("name", "?"), 
						  " ST+", ap_change)
				
				if hp_change != 0:
					participant.temporary_bonus_hp += hp_change
					print("【隣接自領地】", participant.creature_data.get("name", "?"), 
						  " HP+", hp_change)

## ランダムステータス効果を適用（スペクター用）
## バトル準備時に呼び出され、STとHPをランダムな値に設定する
func apply_random_stat_effects(participant: BattleParticipant) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "random_stat":
			var stat = effect.get("stat", "both")
			var min_value = effect.get("min", 10)
			var max_value = effect.get("max", 70)
			
			randomize()
			
			# STをランダムに設定
			if stat == "ap" or stat == "both":
				var random_ap = randi() % (max_value - min_value + 1) + min_value
				var base_ap = participant.creature_data.get("ap", 0)
				var base_up_ap = participant.creature_data.get("base_up_ap", 0)
				participant.temporary_bonus_ap = random_ap - (base_ap + base_up_ap)
				participant.update_current_ap()
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " ST=", participant.current_ap, " (", min_value, "~", max_value, ")")
			
			# HPをランダムに設定
			if stat == "hp" or stat == "both":
				var random_hp = randi() % (max_value - min_value + 1) + min_value
				# temporary_bonus_hpを使ってHPを設定
				var base_mhp = participant.get_max_hp()
				participant.temporary_bonus_hp = random_hp - base_mhp
				# update_current_hp() は呼ばない（current_hp が状態値になったため）
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " HP=", participant.current_hp, " (", min_value, "~", max_value, ")")
			
			return

## 💰 バトル開始時の魔力獲得スキルを適用
func apply_magic_gain_on_battle_start(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	"""
	バトル開始時に発動する魔力獲得スキルをまとめて適用
	- 侵略時魔力獲得（攻撃側のみ）
	- 無条件魔力獲得（両側）
	"""
	# spell_magic_refを直接使う（BattleParticipantから取得）
	var spell_magic = attacker.spell_magic_ref
	if not spell_magic:
		return
	
	# 魔力獲得スキルを適用
	var activated = _skill_magic_gain.apply_on_battle_start(attacker, defender, spell_magic)
	
	# 発動したスキルをバトル画面に表示
	for participant in activated:
		if battle_screen_manager:
			var side = "attacker" if participant.is_attacker else "defender"
			var skill_name = SkillDisplayConfig.get_skill_name("magic_gain")
			await battle_screen_manager.show_skill_activation(side, skill_name, {})

## 戦闘地条件効果を適用（アンフィビアン、カクタスウォール用）
func apply_battle_condition_effects(participant: BattleParticipant, context: Dictionary):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 戦闘地の属性条件
		if effect_type == "battle_land_element_bonus":
			var condition = effect.get("condition", {})
			var allowed_elements = condition.get("battle_land_elements", [])
			
			# 戦闘地の属性を取得
			var battle_land_element = context.get("battle_land_element", "")
			
			if battle_land_element in allowed_elements:
				var stat = effect.get("stat", "ap")
				var value = effect.get("value", 0)
				
				if stat == "ap":
					participant.temporary_bonus_ap += value
					participant.current_ap += value
					print("【戦闘地条件】", participant.creature_data.get("name", "?"), 
						  " 戦闘地:", battle_land_element, " → ST+", value)
				elif stat == "hp":
					participant.temporary_bonus_hp += value
					# update_current_hp() は呼ばない（current_hp が状態値になったため）
					print("【戦闘地条件】", participant.creature_data.get("name", "?"), 
						  " 戦闘地:", battle_land_element, " → HP+", value)
		
		# 敵の属性条件
		elif effect_type == "enemy_element_bonus":
			var condition = effect.get("condition", {})
			var allowed_elements = condition.get("enemy_elements", [])
			
			# 敵の属性を取得
			var enemy_element = context.get("enemy_element", "")
			
			if enemy_element in allowed_elements:
				var stat = effect.get("stat", "ap")
				var value = effect.get("value", 0)
				
				if stat == "ap":
					participant.temporary_bonus_ap += value
					participant.current_ap += value
					print("【敵属性条件】", participant.creature_data.get("name", "?"), 
						  " 敵:", enemy_element, " → ST+", value)
				elif stat == "hp":
					participant.temporary_bonus_hp += value
					# update_current_hp() は呼ばない（current_hp が状態値になったため）
					print("【敵属性条件】", participant.creature_data.get("name", "?"), 
						  " 敵:", enemy_element, " → HP+", value)

## 常時補正効果を適用（アイスウォール、トルネード用）
func apply_constant_stat_bonus(participant: BattleParticipant):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "constant_stat_bonus":
			var stat = effect.get("stat", "ap")
			var value = effect.get("value", 0)
			
			if stat == "ap":
				participant.temporary_bonus_ap += value
				participant.current_ap += value
				print("【常時補正】", participant.creature_data.get("name", "?"), 
					  " ST", ("+" if value >= 0 else ""), value)
			elif stat == "hp":
				participant.temporary_bonus_hp += value
				# update_current_hp() は呼ばない（current_hp が状態値になったため）
				print("【常時補正】", participant.creature_data.get("name", "?"), 
					  " HP", ("+" if value >= 0 else ""), value)

## 手札数効果を適用（リリス用）
func apply_hand_count_effects(participant: BattleParticipant, player_id: int, card_system):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "hand_count_multiplier":
			var stat = effect.get("stat", "hp")
			var multiplier = effect.get("multiplier", 10)
			
			# CardSystemから手札数取得
			var hand_count = 0
			if card_system:
				hand_count = card_system.get_hand_size_for_player(player_id)
			
			var bonus_value = hand_count * multiplier
			
			if stat == "ap":
				participant.temporary_bonus_ap += bonus_value
				participant.current_ap += bonus_value
				print("【手札数効果】", participant.creature_data.get("name", "?"), 
					  " ST+", bonus_value, " (手札数:", hand_count, " × ", multiplier, ")")
			elif stat == "hp":
				participant.temporary_bonus_hp += bonus_value
				# update_current_hp() は呼ばない（current_hp が状態値になったため）
				print("【手札数効果】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus_value, " (手札数:", hand_count, " × ", multiplier, ")")

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
