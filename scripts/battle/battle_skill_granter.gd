extends Node
class_name BattleSkillGranter

# 定数をpreload
const FirstStrikeSkill = preload("res://scripts/battle/skills/skill_first_strike.gd")
const DoubleAttackSkill = preload("res://scripts/battle/skills/skill_double_attack.gd")

## スキル付与条件をチェック（既存ConditionCheckerを使用）
func check_skill_grant_condition(_participant: BattleParticipant, condition: Dictionary, context: Dictionary) -> bool:
	# 既存のConditionCheckerを使用
	var checker = ConditionChecker.new()
	return checker._evaluate_single_condition(condition, context)

## パーティシパントにスキルを付与
func grant_skill_to_participant(participant: BattleParticipant, skill_name: String, _skill_data: Dictionary) -> void:
	match skill_name:
		"先制":
			FirstStrikeSkill.grant_skill(participant, "先制")
		
		"後手":
			FirstStrikeSkill.grant_skill(participant, "後手")
		
		"2回攻撃":
			DoubleAttackSkill.grant_skill(participant)
		
		"巻物強打":
			_grant_scroll_power_strike(participant, _skill_data)
		
		"強打":
			_grant_power_strike(participant, _skill_data)
		
		"無効化":
			_grant_nullify(participant, _skill_data)
		
		"貫通":
			_grant_penetration(participant)
		
		"即死":
			_grant_instant_death(participant, _skill_data)
		
		_:
			print("  未実装のスキル: ", skill_name)

## 巻物強打スキル付与
func _grant_scroll_power_strike(participant: BattleParticipant, skill_data: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	
	var ability_parsed = participant.creature_data["ability_parsed"]
	
	if not ability_parsed.has("keywords"):
		ability_parsed["keywords"] = []
	
	if not "巻物強打" in ability_parsed["keywords"]:
		ability_parsed["keywords"].append("巻物強打")
	
	if not ability_parsed.has("effects"):
		ability_parsed["effects"] = []
	
	var skill_conditions = skill_data.get("skill_conditions", [])
	var scroll_power_strike_effect = {
		"effect_type": "scroll_power_strike",
		"multiplier": 1.5,
		"conditions": skill_conditions
	}
	
	ability_parsed["effects"].append(scroll_power_strike_effect)
	print("  巻物強打スキル付与（条件数: ", skill_conditions.size(), "）")

## 強打スキル付与
func _grant_power_strike(participant: BattleParticipant, skill_data: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	
	var ability_parsed = participant.creature_data["ability_parsed"]
	
	if not ability_parsed.has("keywords"):
		ability_parsed["keywords"] = []
	
	if not "強打" in ability_parsed["keywords"]:
		ability_parsed["keywords"].append("強打")
	
	if not ability_parsed.has("effects"):
		ability_parsed["effects"] = []
	
	var skill_conditions = skill_data.get("skill_conditions", [])
	var power_strike_effect = {
		"effect_type": "power_strike",
		"multiplier": 1.5,
		"conditions": skill_conditions
	}
	
	ability_parsed["effects"].append(power_strike_effect)
	print("  強打スキル付与（条件数: ", skill_conditions.size(), "）")

## 無効化スキル付与
func _grant_nullify(participant: BattleParticipant, skill_data: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	
	var ability_parsed = participant.creature_data["ability_parsed"]
	if not ability_parsed.has("keywords"):
		ability_parsed["keywords"] = []
	
	if not "無効化" in ability_parsed["keywords"]:
		ability_parsed["keywords"].append("無効化")
	
	if not ability_parsed.has("keyword_conditions"):
		ability_parsed["keyword_conditions"] = {}
	
	if not ability_parsed["keyword_conditions"].has("無効化"):
		ability_parsed["keyword_conditions"]["無効化"] = []
	
	var skill_params = skill_data.get("skill_params", {})
	var nullify_type = skill_params.get("nullify_type", "normal_attack")
	var reduction_rate = skill_params.get("reduction_rate", 0.0)
	
	var nullify_data = {
		"nullify_type": nullify_type,
		"reduction_rate": reduction_rate,
		"conditions": []
	}
	
	if nullify_type in ["st_below", "st_above", "mhp_below", "mhp_above"]:
		nullify_data["value"] = skill_params.get("value", 0)
	elif nullify_type == "element":
		nullify_data["elements"] = skill_params.get("elements", [])
	
	ability_parsed["keyword_conditions"]["無効化"].append(nullify_data)
	print("  無効化スキル付与: ", nullify_type)

## 貫通スキル付与
func _grant_penetration(participant: BattleParticipant) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	
	var ability_parsed = participant.creature_data["ability_parsed"]
	if not ability_parsed.has("keywords"):
		ability_parsed["keywords"] = []
	
	if not "貫通" in ability_parsed["keywords"]:
		ability_parsed["keywords"].append("貫通")
	
	print("  貫通スキル付与")

## 即死スキル付与
func _grant_instant_death(participant: BattleParticipant, skill_data: Dictionary) -> void:
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	
	var ability_parsed = participant.creature_data["ability_parsed"]
	if not ability_parsed.has("keywords"):
		ability_parsed["keywords"] = []
	
	if not "即死" in ability_parsed["keywords"]:
		ability_parsed["keywords"].append("即死")
	
	if not ability_parsed.has("keyword_conditions"):
		ability_parsed["keyword_conditions"] = {}
	
	var skill_params = skill_data.get("skill_params", {})
	var probability = skill_params.get("probability", 100)
	var target_elements = skill_params.get("target_elements", [])
	var target_type = skill_params.get("target_type", "")
	
	var instant_death_data = {
		"probability": probability
	}
	
	if not target_elements.is_empty():
		instant_death_data["condition_type"] = "enemy_element"
		instant_death_data["elements"] = target_elements
	elif not target_type.is_empty():
		instant_death_data["condition_type"] = "enemy_type"
		instant_death_data["type"] = target_type
	
	ability_parsed["keyword_conditions"]["即死"] = instant_death_data
	print("  即死スキル付与: 確率=", probability, "% 条件=", instant_death_data.get("condition_type", "無条件"))
