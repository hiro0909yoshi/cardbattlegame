extends Node
class_name BattleItemApplier

# 定数をpreload
const FirstStrikeSkill = preload("res://scripts/battle/skills/skill_first_strike.gd")
const DoubleAttackSkill = preload("res://scripts/battle/skills/skill_double_attack.gd")
const SkillAssistScript = preload("res://scripts/battle/skills/skill_assist.gd")
const BattleSkillGranterScript = preload("res://scripts/battle/battle_skill_granter.gd")

# システム参照
var board_system_ref = null
var card_system_ref: CardSystem = null
var spell_magic_ref = null

# ログ出力フラグ
var silent: bool = false

func setup_systems(board_system, card_system: CardSystem, spell_magic = null):
	board_system_ref = board_system
	card_system_ref = card_system
	spell_magic_ref = spell_magic

## ログ出力ヘルパー
func _log(message: String) -> void:
	if not silent:
		print(message)

## アイテムまたは援護クリーチャーの効果を適用
## アイテムまたは援護クリーチャーの効果を適用
## @param stat_bonus_only trueの場合、ステータスボーナスのみ適用（スキル効果はスキップ）
## @param skip_stat_bonus trueの場合、ステータスボーナスをスキップ（スキル効果のみ適用）
func apply_item_effects(participant: BattleParticipant, item_data: Dictionary, enemy_participant: BattleParticipant, battle_tile_index: int = -1, stat_bonus_only: bool = false, skip_stat_bonus: bool = false) -> void:
	var item_type = item_data.get("type", "")
	var mode_str = ""
	if stat_bonus_only:
		mode_str = "（ステータスのみ）"
	elif skip_stat_bonus:
		mode_str = "（スキルのみ）"
	_log("[アイテム効果適用%s] %s (type: %s)" % [mode_str, item_data.get("name", "???"), item_type])
	
	# contextを構築（既存システムと同じ形式）
	var context = {
		"player_id": participant.player_id,
		"creature_element": participant.creature_data.get("element", ""),
		"creature_rarity": participant.creature_data.get("rarity", ""),
		"enemy_element": enemy_participant.creature_data.get("element", "") if enemy_participant else "",
		"battle_tile_index": battle_tile_index
	}
	
	# クリーチャーの場合
	if item_type == "creature":
		# stat_bonus_onlyの場合はクリーチャー効果をスキップ
		if stat_bonus_only:
			return
		# アイテムクリーチャー判定
		if SkillItemCreature.is_item_creature(item_data):
			# アイテムクリーチャーとして処理
			SkillItemCreature.apply_as_item(participant, item_data, board_system_ref)
			return
		else:
			# 援護クリーチャーとして処理
			SkillAssistScript.apply_assist_effect(participant, item_data)
			return
	
	# 以下はアイテムカードの処理
	# effect_parsedから効果を取得（アイテムはeffect_parsedを使用）
	var effect_parsed = item_data.get("effect_parsed", {})
	if effect_parsed.is_empty():
		_log("  警告: effect_parsedが定義されていません")
		return
	
	# stat_bonusを適用（skip_stat_bonusがfalseの場合のみ）
	if not skip_stat_bonus:
		var stat_bonus = effect_parsed.get("stat_bonus", {})
		if not stat_bonus.is_empty():
			_apply_stat_bonus(participant, stat_bonus)
	
	# stat_bonus_onlyがtrueならスキル効果をスキップ
	if stat_bonus_only:
		return
	
	var effects = effect_parsed.get("effects", [])
	for effect in effects:
		var _effect_type = effect.get("effect_type", "")
		_apply_item_effect(participant, enemy_participant, effect, context)

## stat_bonusを適用
func _apply_stat_bonus(participant: BattleParticipant, stat_bonus: Dictionary) -> void:
	var ap = stat_bonus.get("ap", 0)
	var hp = stat_bonus.get("hp", 0)
	var force_ap = stat_bonus.get("force_ap", false)
	
	# force_ap: APを絶対値で設定（例: スフィアシールドのAP=0）
	if force_ap:
		participant.current_ap = ap
		_log("  AP=%d（絶対値設定）" % ap)
		# force_apの場合はupdate_current_ap()を呼ばない（絶対値を保持する）
	elif ap > 0:
		participant.item_bonus_ap += ap
		_log("  AP+%d → %d" % [ap, participant.item_bonus_ap])
	elif ap < 0:
		participant.item_bonus_ap += ap
		_log("  AP%d → %d" % [ap, participant.item_bonus_ap])

	if hp > 0:
		participant.item_bonus_hp += hp
		_log("  HP+%d → item_bonus_hp:%d" % [hp, participant.item_bonus_hp])
	elif hp < 0:
		participant.item_bonus_hp += hp
		_log("  HP%d → item_bonus_hp:%d" % [hp, participant.item_bonus_hp])
	
	# AP計算を更新（force_apでない場合のみ）
	if not force_ap:
		participant.update_current_ap()

## 各効果タイプを適用
func _apply_item_effect(participant: BattleParticipant, enemy_participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var effect_type: String = effect.get("effect_type", "")
	var value: int = effect.get("value", 0)
	
	match effect_type:
		"buff_ap":
			participant.current_ap += value
			_log("  AP+%d → %d" % [value, participant.current_ap])

		"buff_hp":
			participant.item_bonus_hp += value
			_log("  HP+%d → item_bonus_hp:%d" % [value, participant.item_bonus_hp])

		"debuff_ap":
			participant.current_ap -= value
			_log("  AP-%d → %d" % [value, participant.current_ap])

		"debuff_hp":
			participant.item_bonus_hp -= value
			_log("  HP-%d → item_bonus_hp:%d" % [value, participant.item_bonus_hp])
		
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
		
		"ap_drain":
			# on_attack_success triggerの場合はbattle_execution.gdで処理するためスキップ
			var trigger = effect.get("trigger", "")
			if trigger != "on_attack_success":
				_apply_ap_drain(participant, enemy_participant, effect)
		
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
			_apply_revive_skill(participant, effect)
		
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
			_log("  スクイドマントル効果付与（敵の特殊攻撃無効化）")
		
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
		
		"chain_count_ap_bonus":
			_apply_chain_count_bonus(participant, effect, context)
		
		"nullify_all_enemy_abilities":
			# 後でprepare_participants()で処理
			pass
		
		_:
			_log("  未実装の効果タイプ: %s" % effect_type)

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
		_log("  [属性配置数]%s:%d × %d = AP+%d" % [str(elements), total_count, multiplier, bonus])
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
		_log("  [属性配置数]%s:%d × %d = HP+%d" % [str(elements), total_count, multiplier, bonus])

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
		_log("  [敵同属性配置数] 敵=%s:%d × %d = AP+%d" % [enemy_element, count, multiplier, bonus])
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
		_log("  [敵同属性配置数] 敵=%s:%d × %d = HP+%d" % [enemy_element, count, multiplier, bonus])

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
		_log("  [手札数ボーナス] 手札:%d枚 × %d = AP+%d" % [hand_count, multiplier, bonus])
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
		_log("  [手札数ボーナス] 手札:%d枚 × %d = HP+%d" % [hand_count, multiplier, bonus])

## 自ドミニオ数ボーナス
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
		_log("  [自ドミニオ数ボーナス] %s:%d枚 × %d = AP+%d" % [str(elements), total_land_count, multiplier, bonus])
	elif stat == "hp":
		participant.item_bonus_hp += bonus
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
		_log("  [自ドミニオ数ボーナス] %s:%d枚 × %d = HP+%d" % [str(elements), total_land_count, multiplier, bonus])

## APドレイン（敵のAPを永続的に0にする）
func _apply_ap_drain(participant: BattleParticipant, enemy_participant: BattleParticipant, _effect: Dictionary) -> void:
	if not enemy_participant:
		return
	
	var enemy_name = enemy_participant.creature_data.get("name", "?")
	var original_ap = enemy_participant.current_ap
	
	# 戦闘中のAPを0に
	enemy_participant.current_ap = 0
	
	# 永続的にAPを0にする（base_apを0、base_up_apも0に）
	enemy_participant.creature_data["ap"] = 0
	enemy_participant.creature_data["base_up_ap"] = 0
	enemy_participant.base_up_ap = 0

	_log("  [APドレイン] %s が %s のAPを永続的に0に (元AP: %d)" % [participant.creature_data.get("name", "?"), enemy_name, original_ap])

## 死者復活スキル付与
func _apply_revive_skill(participant: BattleParticipant, item_effect: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("effects"):
		participant.creature_data["ability_parsed"]["effects"] = []
	
	# 既に復活効果があるかチェック
	var has_revive = false
	for effect in participant.creature_data["ability_parsed"]["effects"]:
		if effect.get("effect_type") == "revive" and effect.get("trigger") == "on_death":
			has_revive = true
			break
	
	if not has_revive:
		# アイテムの効果をそのまま追加（creature_idはアイテムで指定されたもの）
		var revive_effect = item_effect.duplicate()
		# triggerが設定されていない場合はon_deathを設定
		if not revive_effect.has("trigger"):
			revive_effect["trigger"] = "on_death"
		participant.creature_data["ability_parsed"]["effects"].append(revive_effect)
		_log("  スキル付与: 死者復活（ID: %sとして復活）" % revive_effect.get("creature_id", "?"))

## ランダムステータスボーナス
func _apply_random_stat_bonus(participant: BattleParticipant, effect: Dictionary) -> void:
	var ap_range = effect.get("ap_range", {})
	var hp_range = effect.get("hp_range", {})
	
	var ap_bonus = 0
	var hp_bonus = 0
	
	if not ap_range.is_empty():
		var ap_min = ap_range.get("min", 0)
		var ap_max = ap_range.get("max", 0)
		ap_bonus = randi() % int(ap_max - ap_min + 1) + ap_min
		participant.current_ap += ap_bonus
	
	if not hp_range.is_empty():
		var hp_min = hp_range.get("min", 0)
		var hp_max = hp_range.get("max", 0)
		hp_bonus = randi() % int(hp_max - hp_min + 1) + hp_min
		participant.item_bonus_hp += hp_bonus
		# update_current_hp() は呼ばない（current_hp が状態値になったため）

	_log("  [ランダムボーナス] AP+%d, HP+%d" % [ap_bonus, hp_bonus])

## 属性不一致ボーナス
func _apply_element_mismatch_bonus(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var user_element = participant.creature_data.get("element", "")
	var enemy_element = context.get("enemy_element", "")
	
	if user_element != enemy_element:
		var stat_bonus_data = effect.get("stat_bonus", {})
		var ap = stat_bonus_data.get("ap", 0)
		var hp = stat_bonus_data.get("hp", 0)
		
		if ap > 0:
			participant.current_ap += ap
		if hp > 0:
			participant.item_bonus_hp += hp
			# update_current_hp() は呼ばない（current_hp が状態値になったため）

		_log("  [属性不一致] %s ≠ %s → AP+%d, HP+%d" % [user_element, enemy_element, ap, hp])
	else:
		_log("  [属性不一致] %s = %s → ボーナスなし" % [user_element, enemy_element])

## 固定値設定
func _apply_fixed_stat(participant: BattleParticipant, effect: Dictionary) -> void:
	var stat = effect.get("stat", "")
	var fixed_value = int(effect.get("value", 0))
	var operation = effect.get("operation", "set")
	
	if operation == "set":
		if stat == "ap":
			participant.current_ap = fixed_value
			_log("  [固定値] AP=%d" % fixed_value)
		elif stat == "hp":
			# HP固定値を適用
			# creature_data["hp"]は元の値を維持（戦闘後の復元用）
			participant.base_hp = fixed_value
			participant.current_hp = fixed_value
			_log("  [固定値] HP=%d" % fixed_value)

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
		_log("  アイテム破壊・盗み無効を付与")

## 属性変更
func _apply_change_element(participant: BattleParticipant, effect: Dictionary) -> void:
	var target_element = effect.get("target_element", "neutral")
	var old_element = participant.creature_data.get("element", "")
	participant.creature_data["element"] = target_element
	_log("  属性変更: %s → %s" % [old_element, target_element])

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
		_log("  アイテム破壊を付与: %s" % str(target_types))

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
		_log("  変身効果を付与: %s" % effect.get("transform_type", ""))

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
	
	var scroll_type = effect.get("scroll_type", "base_ap")
	var scroll_config = {"scroll_type": scroll_type}
	
	# アイテム巻物：AP を動的に計算して直接設定
	var base_ap = participant.creature_data.get("ap", 0)
	
	match scroll_type:
		"fixed_ap":
			var value = effect.get("value", 0)
			scroll_config["value"] = value
			participant.current_ap = value
			_log("  【アイテム巻物】%s AP強制固定: %d" % [participant.creature_data.get("name", "?"), value])
		"base_ap":
			participant.current_ap = base_ap
			_log("  【アイテム巻物】%s AP=基本AP: %d" % [participant.creature_data.get("name", "?"), base_ap])
		"land_count":
			scroll_config["elements"] = effect.get("elements", [])
			scroll_config["multiplier"] = effect.get("multiplier", 1)
			# 土地数を計算してAPを設定
			var elements = scroll_config["elements"]
			var multiplier = scroll_config["multiplier"]
			var total_count = 0
			if board_system_ref:
				for element in elements:
					total_count += board_system_ref.count_creatures_by_element(0, element)
			var calculated_ap = total_count * multiplier
			participant.current_ap = calculated_ap
			_log("  【アイテム巻物】%s AP=%s土地数%d×%d=%d" % [participant.creature_data.get("name", "?"), str(elements), total_count, multiplier, calculated_ap])
		_:
			participant.current_ap = base_ap
			_log("  【アイテム巻物】%s AP=基本AP（デフォルト）: %d" % [participant.creature_data.get("name", "?"), base_ap])
	
	# アイテム巻物フラグを立てる（他のスキルをスキップするため）
	participant.is_using_scroll = true
	
	# keyword_conditions に設定を保存
	participant.creature_data["ability_parsed"]["keyword_conditions"]["巻物攻撃"] = scroll_config

## 連鎖数APボーナス
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
	_log("  [連鎖数APボーナス] 連鎖:%d × %d = AP+%d" % [chain_count, multiplier, bonus])

## スキル付与処理
func _apply_grant_skill(participant: BattleParticipant, effect: Dictionary, context: Dictionary) -> void:
	var skill_name = effect.get("skill", "")
	
	# 付与条件をチェック（付与条件がある場合のみ）
	var condition = effect.get("condition", {})
	
	if not condition.is_empty():
		if not _check_skill_grant_condition(participant, condition, context):
			_log("  [スキル付与] %s - 付与条件を満たさないため付与しません" % skill_name)
			return
	
	# 付与条件が満たされた場合、スキルを付与
	_grant_skill_to_participant(participant, skill_name, effect)

## スキル付与条件をチェック
func _check_skill_grant_condition(_participant: BattleParticipant, condition: Dictionary, context: Dictionary) -> bool:
	var checker = ConditionChecker.new()
	return checker.evaluate_single_condition(condition, context)

## パーティシパントにスキルを付与
func _grant_skill_to_participant(participant: BattleParticipant, skill_name: String, effect_data: Dictionary) -> void:
	match skill_name:
		"先制":
			FirstStrikeSkill.grant_skill(participant, "先制")
		
		"後手":
			FirstStrikeSkill.grant_skill(participant, "後手")
		
		"2回攻撃":
			DoubleAttackSkill.grant_skill(participant)
		
		_:
			# その他のスキルは BattleSkillGranter で処理
			var granter = BattleSkillGranter.new()
			granter.grant_skill_to_participant(participant, skill_name, effect_data)
