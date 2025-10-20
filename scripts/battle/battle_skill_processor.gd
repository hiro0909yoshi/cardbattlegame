extends Node
class_name BattleSkillProcessor

# バトルスキル処理
# 感応、強打、2回攻撃、巻物攻撃などのスキル適用を担当

var board_system_ref = null

func setup_systems(board_system):
	board_system_ref = board_system

## バトル前スキル適用
func apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> void:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# プレイヤー土地情報取得
	var player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
	
	# 侵略側のスキル適用
	var attacker_context = ConditionChecker.build_battle_context(
		attacker.creature_data,
		defender.creature_data,
		tile_info,
		{
			"player_lands": player_lands,
			"battle_tile_index": tile_info.get("index", -1),
			"player_id": attacker_index,
			"board_system": board_system_ref
		}
	)
	apply_skills(attacker, attacker_context)
	
	# 防御側のスキル適用
	var defender_lands = board_system_ref.get_player_lands_by_element(defender.player_id) if defender.player_id >= 0 else {}
	var defender_context = ConditionChecker.build_battle_context(
		defender.creature_data,
		attacker.creature_data,
		tile_info,
		{
			"player_lands": defender_lands,
			"battle_tile_index": tile_info.get("index", -1),
			"player_id": defender.player_id,
			"board_system": board_system_ref
		}
	)
	apply_skills(defender, defender_context)
	
	# 巻物攻撃による土地ボーナスHP無効化
	if attacker.is_using_scroll and defender.land_bonus_hp > 0:
		print("【巻物攻撃】防御側の土地ボーナス ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		defender.update_current_hp()

## スキル適用
func apply_skills(participant: BattleParticipant, context: Dictionary) -> void:
	var effect_combat = load("res://scripts/skills/effect_combat.gd").new()
	
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	var has_scroll_power_strike = "巻物強打" in keywords
	
	# 1. 巻物攻撃判定（最優先）
	check_scroll_attack(participant, context)
	
	# 2. 感応スキルを適用
	# 巻物強打の場合は感応を適用、通常の巻物攻撃の場合はスキップ
	if not participant.is_using_scroll or has_scroll_power_strike:
		apply_resonance_skill(participant, context)
	
	# 3. 強打スキルを適用（巻物強打を含む）
	apply_power_strike_skills(participant, context, effect_combat)
	
	# 2回攻撃スキルを判定
	check_double_attack(participant)

## 2回攻撃スキル判定
func check_double_attack(participant: BattleParticipant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "2回攻撃" in keywords:
		participant.attack_count = 2
		print("【2回攻撃】", participant.creature_data.get("name", "?"), " 攻撃回数: 2回")

## 巻物攻撃判定
func check_scroll_attack(participant: BattleParticipant, _context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 巻物攻撃 or 巻物強打を持つか
	if not ("巻物攻撃" in keywords or "巻物強打" in keywords):
		return
	
	# 巻物攻撃フラグを立てる
	participant.is_using_scroll = true
	
	# AP設定を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var scroll_config = {}
	
	# 巻物攻撃の設定を優先
	if "巻物攻撃" in keywords:
		scroll_config = keyword_conditions.get("巻物攻撃", {})
	elif "巻物強打" in keywords:
		scroll_config = keyword_conditions.get("巻物強打", {})
	
	# scroll_typeに基づいてAPを設定
	var scroll_type = scroll_config.get("scroll_type", "base_st")
	var base_ap = participant.creature_data.get("ap", 0)
	
	match scroll_type:
		"fixed_st":
			# 固定値
			var value = scroll_config.get("value", base_ap)
			participant.current_ap = value
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP固定:", value)
		"base_st":
			# 基本STのまま
			participant.current_ap = base_ap
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP=基本ST:", base_ap)
		_:
			# デフォルトは基本ST
			participant.current_ap = base_ap
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP=基本ST:", base_ap)

## 強打スキル適用（巻物強打を含む）
func apply_power_strike_skills(participant: BattleParticipant, context: Dictionary, effect_combat) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 巻物強打判定（最優先）
	if "巻物強打" in keywords and participant.is_using_scroll:
		# 巻物強打は無条件でAP×1.5
		var original_ap = participant.current_ap
		participant.current_ap = int(participant.current_ap * 1.5)
		print("【巻物強打】", participant.creature_data.get("name", "?"), 
			  " AP: ", original_ap, " → ", participant.current_ap, " (×1.5)")
		return
	
	# 通常の強打判定
	if "強打" in keywords:
		var modified_creature_data = participant.creature_data.duplicate()
		modified_creature_data["ap"] = participant.current_ap  # 現在のAPを設定
		var modified = effect_combat.apply_power_strike(modified_creature_data, context)
		participant.current_ap = modified.get("ap", participant.current_ap)
		
		if modified.get("power_strike_applied", false):
			print("【強打発動】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap)

## 感応スキルを適用
func apply_resonance_skill(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 感応スキルがない場合
	if not "感応" in keywords:
		return
	
	# 感応条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var resonance_condition = keyword_conditions.get("感応", {})
	
	if resonance_condition.is_empty():
		return
	
	# 必要な属性を取得
	var required_element = resonance_condition.get("element", "")
	
	# プレイヤーの土地情報を取得
	var player_lands = context.get("player_lands", {})
	var owned_count = player_lands.get(required_element, 0)
	
	# 感応発動判定：指定属性の土地を1つでも所有していれば発動
	if owned_count > 0:
		var stat_bonus = resonance_condition.get("stat_bonus", {})
		var ap_bonus = stat_bonus.get("ap", 0)
		var hp_bonus = stat_bonus.get("hp", 0)
		
		if ap_bonus > 0 or hp_bonus > 0:
			print("【感応発動】", participant.creature_data.get("name", "?"))
			print("  必要属性:", required_element, " 所持数:", owned_count)
			
			# APボーナス適用
			if ap_bonus > 0:
				var old_ap = participant.current_ap
				participant.current_ap += ap_bonus
				print("  AP: ", old_ap, " → ", participant.current_ap, " (+", ap_bonus, ")")
			
			# HPボーナス適用（resonance_bonus_hpに追加）
			if hp_bonus > 0:
				var old_hp = participant.current_hp
				participant.resonance_bonus_hp += hp_bonus
				participant.update_current_hp()
				print("  HP: ", old_hp, " → ", participant.current_hp, " (+", hp_bonus, ")")
