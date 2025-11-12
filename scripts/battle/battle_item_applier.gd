extends Node
class_name BattleItemApplier

# 定数をpreload
const FirstStrikeSkill = preload("res://scripts/battle/skills/skill_first_strike.gd")
const DoubleAttackSkill = preload("res://scripts/battle/skills/skill_double_attack.gd")
const SkillAssistScript = preload("res://scripts/battle/skills/skill_assist.gd")

# システム参照
var board_system_ref = null
var card_system_ref: CardSystem = null
var spell_magic_ref = null

func setup_systems(board_system, card_system: CardSystem, spell_magic = null):
	board_system_ref = board_system
	card_system_ref = card_system
	spell_magic_ref = spell_magic

## アイテムまたは援護クリーチャーの効果を適用
func apply_item_effects(participant: BattleParticipant, item_data: Dictionary, enemy_participant: BattleParticipant, battle_tile_index: int = -1) -> void:
	var item_type = item_data.get("type", "")
	print("[アイテム効果適用] ", item_data.get("name", "???"), " (type: ", item_type, ")")
	
	# contextを構築（既存システムと同じ形式）
	var context = {
		"player_id": participant.player_id,
		"creature_element": participant.creature_data.get("element", ""),
		"creature_rarity": participant.creature_data.get("rarity", ""),
		"enemy_element": enemy_participant.creature_data.get("element", "") if enemy_participant else "",
		"battle_tile_index": battle_tile_index
	}
	
	# 援護クリーチャーの場合はSkillAssistで処理
	if item_type == "creature":
		SkillAssistScript.apply_assist_effect(participant, item_data)
		# 援護クリーチャーのスキルは継承されないのでここで終了
		return
	
	# 以下はアイテムカードの処理
	# effect_parsedから効果を取得（アイテムはeffect_parsedを使用）
	var effect_parsed = item_data.get("effect_parsed", {})
	if effect_parsed.is_empty():
		print("  警告: effect_parsedが定義されていません")
		return
	
	# stat_bonusを先に適用（ST+20、HP+20など）
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	if not stat_bonus.is_empty():
		_apply_stat_bonus(participant, stat_bonus)
	
	var effects = effect_parsed.get("effects", [])
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		_apply_item_effect(participant, enemy_participant, effect, context)

## stat_bonusを適用
func _apply_stat_bonus(participant: BattleParticipant, stat_bonus: Dictionary) -> void:
	var st = stat_bonus.get("st", 0)
	var hp = stat_bonus.get("hp", 0)
	var force_st = stat_bonus.get("force_st", false)
	
	# force_st: STを絶対値で設定（例: スフィアシールドのST=0）
	if force_st:
		participant.current_ap = st
		print("  ST=", st, "（絶対値設定）")
	elif st > 0:
		participant.current_ap += st
		print("  ST+", st, " → ", participant.current_ap)
	
	if hp > 0:
		participant.item_bonus_hp += hp
		participant.update_current_hp()
		print("  HP+", hp, " → ", participant.current_hp)

## 各効果タイプを適用
func _apply_item_effect(participant: BattleParticipant, enemy_participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var effect_type: String = effect.get("effect_type", "")
	var value: int = effect.get("value", 0)
	
	match effect_type:
		"buff_ap":
			participant.current_ap += value
			print("  AP+", value, " → ", participant.current_ap)
		
		"buff_hp":
			participant.item_bonus_hp += value
			participant.update_current_hp()
			print("  HP+", value, " → ", participant.current_hp)
		
		"debuff_ap":
			participant.current_ap -= value
			print("  AP-", value, " → ", participant.current_ap)
		
		"debuff_hp":
			participant.item_bonus_hp -= value
			participant.update_current_hp()
			print("  HP-", value, " → ", participant.current_hp)
		
		"element_count_bonus":
			_apply_element_count_bonus(participant, effect, context)
		
		"same_element_as_enemy_count":
			_apply_same_element_bonus(participant, effect, context)
		
		"hand_count_multiplier":
			_apply_hand_count_bonus(participant, effect, context)
		
		"owned_land_count_bonus":
			_apply_owned_land_count_bonus(participant, effect, context)
		
		"grant_skill":
			_apply_grant_skill(participant, effect, context)
		
		"st_drain":
			_apply_st_drain(participant, enemy_participant, effect)
		
		"grant_first_strike":
			FirstStrikeSkill.grant_skill(participant, "先制")
		
		"grant_last_strike":
			FirstStrikeSkill.grant_skill(participant, "後手")
		
		"grant_double_attack":
			DoubleAttackSkill.grant_skill(participant)
		
		"reflect_damage", "nullify_reflect":
			# 反射系のスキルはバトル中にBattleSkillProcessorで処理
			pass
		
		"revive":
			_apply_revive_skill(participant)
		
		"random_stat_bonus":
			_apply_random_stat_bonus(participant, effect)
		
		"element_mismatch_bonus":
			_apply_element_mismatch_bonus(participant, effect, context)
		
		"fixed_stat":
			_apply_fixed_stat(participant, effect)
		
		"nullify_item_manipulation":
			_apply_nullify_item_manipulation(participant, effect)
		
		"nullify_attacker_special_attacks":
			participant.has_squid_mantle = true
			print("  スクイドマントル効果付与（敵の特殊攻撃無効化）")
		
		"change_element":
			_apply_change_element(participant, effect)
		
		"destroy_item":
			_apply_destroy_item(participant, effect)
		
		"transform":
			_apply_transform(participant, effect)
		
		"instant_death":
			# バトル中に処理
			pass
		
		"scroll_attack":
			_apply_scroll_attack(participant, effect)
		
		"level_up_on_win", "revenge_mhp_damage", "legacy_magic", "magic_from_damage", "magic_on_enemy_survive":
			# バトル後や戦闘中に処理
			pass
		
		"chain_count_st_bonus":
			_apply_chain_count_bonus(participant, effect, context)
		
		"nullify_all_enemy_abilities":
			# 後でprepare_participants()で処理
			pass
		
		_:
			print("  未実装の効果タイプ: ", effect_type)

## 属性別配置数ボーナス
func _apply_element_count_bonus(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var elements = effect.get("elements", [])
	var multiplier = effect.get("multiplier", 1)
	var stat = effect.get("stat", "ap")
	var player_id = context.get("player_id", 0)
	
	var total_count = 0
	for element in elements:
		if board_system_ref:
			total_count += board_system_ref.count_creatures_by_element(player_id, element)
	
	var bonus = total_count * multiplier
	
	if stat == "ap":
		participant.current_ap += bonus
		print("  [属性配置数]", elements, ":", total_count, " × ", multiplier, " = AP+", bonus)
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		participant.update_current_hp()
		print("  [属性配置数]", elements, ":", total_count, " × ", multiplier, " = HP+", bonus)

## 敵と同属性の配置数ボーナス
func _apply_same_element_bonus(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var multiplier = effect.get("multiplier", 1)
	var stat = effect.get("stat", "ap")
	var player_id = context.get("player_id", 0)
	var enemy_element = context.get("enemy_element", "")
	
	var count = 0
	if enemy_element != "" and board_system_ref:
		count = board_system_ref.count_creatures_by_element(player_id, enemy_element)
	
	var bonus = count * multiplier
	
	if stat == "ap":
		participant.current_ap += bonus
		print("  [敵同属性配置数] 敵=", enemy_element, ":", count, " × ", multiplier, " = AP+", bonus)
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		participant.update_current_hp()
		print("  [敵同属性配置数] 敵=", enemy_element, ":", count, " × ", multiplier, " = HP+", bonus)

## 手札数ボーナス
func _apply_hand_count_bonus(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var multiplier = effect.get("multiplier", 1)
	var stat = effect.get("stat", "ap")
	var player_id = context.get("player_id", 0)
	
	var hand_count = 0
	if card_system_ref:
		hand_count = card_system_ref.get_hand_size_for_player(player_id)
	
	var bonus = hand_count * multiplier
	
	if stat == "ap":
		participant.current_ap += bonus
		print("  [手札数ボーナス] 手札:", hand_count, "枚 × ", multiplier, " = ST+", bonus)
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		participant.update_current_hp()
		print("  [手札数ボーナス] 手札:", hand_count, "枚 × ", multiplier, " = HP+", bonus)

## 自領地数ボーナス
func _apply_owned_land_count_bonus(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var elements = effect.get("elements", [])
	var multiplier = effect.get("multiplier", 1)
	var stat = effect.get("stat", "hp")
	var player_id = context.get("player_id", 0)
	
	var total_land_count = 0
	if board_system_ref:
		var player_lands = board_system_ref.get_player_lands_by_element(player_id)
		for element in elements:
			total_land_count += player_lands.get(element, 0)
	
	var bonus = total_land_count * multiplier
	
	if stat == "ap":
		participant.current_ap += bonus
		print("  [自領地数ボーナス] ", elements, ":", total_land_count, "枚 × ", multiplier, " = ST+", bonus)
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		participant.update_current_hp()
		print("  [自領地数ボーナス] ", elements, ":", total_land_count, "枚 × ", multiplier, " = HP+", bonus)

## STドレイン
func _apply_st_drain(participant: BattleParticipant, enemy_participant: BattleParticipant, effect: Dictionary) -> void:
	var target = effect.get("target", "enemy")
	if target == "enemy" and enemy_participant:
		var drained_st = enemy_participant.current_ap
		if drained_st > 0:
			participant.current_ap += drained_st
			enemy_participant.current_ap = 0
			enemy_participant.creature_data["ap"] = 0
			print("  [STドレイン] ", participant.creature_data.get("name", "?"), " が ", enemy_participant.creature_data.get("name", "?"), " のST", drained_st, "を吸収")
			print("    → 自ST:", participant.current_ap, " / 敵ST:", enemy_participant.current_ap)

## 死者復活スキル付与
func _apply_revive_skill(participant: BattleParticipant) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("keywords"):
		participant.creature_data["ability_parsed"]["keywords"] = []
	
	if not "死者復活" in participant.creature_data["ability_parsed"]["keywords"]:
		participant.creature_data["ability_parsed"]["keywords"].append("死者復活")
		print("  スキル付与: 死者復活")

## ランダムステータスボーナス
func _apply_random_stat_bonus(participant: BattleParticipant, effect: Dictionary) -> void:
	var st_range = effect.get("st_range", {})
	var hp_range = effect.get("hp_range", {})
	
	var st_bonus = 0
	var hp_bonus = 0
	
	if not st_range.is_empty():
		var st_min = st_range.get("min", 0)
		var st_max = st_range.get("max", 0)
		st_bonus = randi() % int(st_max - st_min + 1) + st_min
		participant.current_ap += st_bonus
	
	if not hp_range.is_empty():
		var hp_min = hp_range.get("min", 0)
		var hp_max = hp_range.get("max", 0)
		hp_bonus = randi() % int(hp_max - hp_min + 1) + hp_min
		participant.item_bonus_hp += hp_bonus
		participant.update_current_hp()
	
	print("  [ランダムボーナス] ST+", st_bonus, ", HP+", hp_bonus)

## 属性不一致ボーナス
func _apply_element_mismatch_bonus(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var user_element = participant.creature_data.get("element", "")
	var enemy_element = context.get("enemy_element", "")
	
	if user_element != enemy_element:
		var stat_bonus_data = effect.get("stat_bonus", {})
		var st = stat_bonus_data.get("st", 0)
		var hp = stat_bonus_data.get("hp", 0)
		
		if st > 0:
			participant.current_ap += st
		if hp > 0:
			participant.item_bonus_hp += hp
			participant.update_current_hp()
		
		print("  [属性不一致] ", user_element, " ≠ ", enemy_element, " → ST+", st, ", HP+", hp)
	else:
		print("  [属性不一致] ", user_element, " = ", enemy_element, " → ボーナスなし")

## 固定値設定
func _apply_fixed_stat(participant: BattleParticipant, effect: Dictionary) -> void:
	var stat = effect.get("stat", "")
	var fixed_value = int(effect.get("value", 0))
	var operation = effect.get("operation", "set")
	
	if operation == "set":
		if stat == "st":
			participant.creature_data["ap"] = fixed_value
			participant.current_ap = fixed_value
			print("  [固定値] ST=", fixed_value)
		elif stat == "hp":
			participant.creature_data["mhp"] = fixed_value
			participant.creature_data["hp"] = fixed_value
			participant.base_hp = fixed_value
			participant.base_up_hp = 0
			participant.update_current_hp()
			print("  [固定値] HP=", fixed_value)

## アイテム破壊・盗み無効
func _apply_nullify_item_manipulation(participant: BattleParticipant, effect: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("effects"):
		participant.creature_data["ability_parsed"]["effects"] = []
	
	var already_has = false
	for existing_effect in participant.creature_data["ability_parsed"]["effects"]:
		if existing_effect.get("effect_type") == "nullify_item_manipulation":
			already_has = true
			break
	
	if not already_has:
		participant.creature_data["ability_parsed"]["effects"].append(effect)
		print("  アイテム破壊・盗み無効を付与")

## 属性変更
func _apply_change_element(participant: BattleParticipant, effect: Dictionary) -> void:
	var target_element = effect.get("target_element", "neutral")
	var old_element = participant.creature_data.get("element", "")
	participant.creature_data["element"] = target_element
	print("  属性変更: ", old_element, " → ", target_element)

## アイテム破壊
func _apply_destroy_item(participant: BattleParticipant, effect: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("effects"):
		participant.creature_data["ability_parsed"]["effects"] = []
	
	var already_has = false
	for existing_effect in participant.creature_data["ability_parsed"]["effects"]:
		if existing_effect.get("effect_type") == "destroy_item":
			already_has = true
			break
	
	if not already_has:
		participant.creature_data["ability_parsed"]["effects"].append(effect)
		var target_types = effect.get("target_types", [])
		print("  アイテム破壊を付与: ", target_types)

## 変身効果付与
func _apply_transform(participant: BattleParticipant, effect: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("effects"):
		participant.creature_data["ability_parsed"]["effects"] = []
	
	var already_has = false
	for existing_effect in participant.creature_data["ability_parsed"]["effects"]:
		if existing_effect.get("effect_type") == "transform" and existing_effect.get("trigger") == effect.get("trigger"):
			already_has = true
			break
	
	if not already_has:
		participant.creature_data["ability_parsed"]["effects"].append(effect)
		print("  変身効果を付与: ", effect.get("transform_type", ""))

## 巻物攻撃設定
func _apply_scroll_attack(participant: BattleParticipant, effect: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("keywords"):
		participant.creature_data["ability_parsed"]["keywords"] = []
	if not participant.creature_data["ability_parsed"].has("keyword_conditions"):
		participant.creature_data["ability_parsed"]["keyword_conditions"] = {}
	
	if not "巻物攻撃" in participant.creature_data["ability_parsed"]["keywords"]:
		participant.creature_data["ability_parsed"]["keywords"].append("巻物攻撃")
	
	var scroll_type = effect.get("scroll_type", "base_st")
	var scroll_config = {"scroll_type": scroll_type}
	
	match scroll_type:
		"fixed_st":
			scroll_config["value"] = effect.get("value", 0)
			print("  巻物攻撃を付与: ST固定", scroll_config["value"])
		"base_st":
			print("  巻物攻撃を付与: ST=基本ST")
		"land_count":
			scroll_config["elements"] = effect.get("elements", [])
			scroll_config["multiplier"] = effect.get("multiplier", 1)
			print("  巻物攻撃を付与: ST=土地数×", scroll_config["multiplier"], " (", scroll_config["elements"], ")")
	
	participant.creature_data["ability_parsed"]["keyword_conditions"]["巻物攻撃"] = scroll_config

## 連鎖数STボーナス
func _apply_chain_count_bonus(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var multiplier = effect.get("multiplier", 20)
	var tile_index = context.get("battle_tile_index", -1)
	var player_id = context.get("player_id", 0)
	
	var chain_count = 0
	if tile_index >= 0 and board_system_ref:
		var tile_data_manager = board_system_ref.tile_data_manager
		if tile_data_manager:
			chain_count = tile_data_manager.get_element_chain_count(tile_index, player_id)
	
	var bonus = chain_count * multiplier
	participant.current_ap += bonus
	print("  [連鎖数STボーナス] 連鎖:", chain_count, " × ", multiplier, " = ST+", bonus)

## スキル付与処理
func _apply_grant_skill(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var skill_name = effect.get("skill", "")
	
	# 条件チェック
	var skill_conditions = effect.get("skill_conditions", [])
	var condition = effect.get("condition", {})
	
	var conditions_to_check = []
	if not skill_conditions.is_empty():
		conditions_to_check = skill_conditions
	elif not condition.is_empty():
		conditions_to_check = [condition]
	
	var skip_condition_check = (skill_name == "巻物強打")
	
	var all_conditions_met = true
	if not skip_condition_check:
		for cond in conditions_to_check:
			if not _check_skill_grant_condition(participant, cond, context):
				all_conditions_met = false
				break
	
	if all_conditions_met:
		_grant_skill_to_participant(participant, skill_name, effect)

## スキル付与条件をチェック
func _check_skill_grant_condition(_participant: BattleParticipant, condition: Dictionary, context: Dictionary) -> bool:
	var checker = ConditionChecker.new()
	return checker._evaluate_single_condition(condition, context)

## パーティシパントにスキルを付与
func _grant_skill_to_participant(participant: BattleParticipant, skill_name: String, _skill_data: Dictionary) -> void:
	match skill_name:
		"先制":
			FirstStrikeSkill.grant_skill(participant, "先制")
		
		"後手":
			FirstStrikeSkill.grant_skill(participant, "後手")
		
		"2回攻撃":
			DoubleAttackSkill.grant_skill(participant)
		
		_:
			pass
