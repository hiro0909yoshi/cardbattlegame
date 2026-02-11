##
## 強打スキル - 条件を満たすとAPが上昇する
##
## 【主な機能】
## - 通常の強打: 条件付きでAP上昇
## - 巻物強打: 巻物使用時に無条件でAP×1.5
##
## 【発動条件】
## - 通常の強打: ConditionChecker.check_power_strike()で条件判定
## - 巻物強打: 巻物使用 + 巻物強打キーワード保持
##
## 【効果】
## - AP上昇（条件により倍率が変わる）
##
## @version 1.0
## @date 2025-10-31

class_name SkillPowerStrike

## 巻物強打を持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 巻物強打スキルを持っているか
static func has_scroll_power_strike(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "巻物強打" in keywords

## 通常の強打を持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 強打スキルを持っているか
static func has_power_strike(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "強打" in keywords

## 強打スキルを適用（巻物強打を含む）
##
## @param participant バトル参加者
## @param context バトルコンテキスト
## @param effect_combat エフェクトコンバットシステム（非推奨・互換性用）
static func apply(participant, context: Dictionary, effect_combat = null) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 巻物強打判定（最優先）
	if "巻物強打" in keywords and participant.is_using_scroll:
		apply_scroll_power_strike(participant, context)
		return
	
	# 通常の強打判定
	if "強打" in keywords:
		apply_normal_power_strike(participant, context, effect_combat)

## 巻物強打を適用
##
## 無条件でAP×1.5
##
## @param participant バトル参加者
static func apply_scroll_power_strike(participant, context: Dictionary = {}) -> bool:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	# 巻物強打効果を検索
	for effect in effects:
		if effect.get("effect_type") == "scroll_power_strike":
			# 条件チェック
			var conditions = effect.get("conditions", [])
			var all_conditions_met = true
			
			if conditions.size() > 0:
				var checker = load("res://scripts/skills/condition_checker.gd").new()
				for condition in conditions:
					if not checker.evaluate_single_condition(condition, context):
						all_conditions_met = false
						break
			
			# 条件を満たした場合のみAP上昇
			if all_conditions_met:
				var before_ap = participant.current_ap
				var multiplier = effect.get("multiplier", 1.5)
				participant.current_ap = int(participant.current_ap * multiplier)
				print("【巻物強打発動】", participant.creature_data.get("name", "?"), 
					  " AP: ", before_ap, " → ", participant.current_ap, " (×", multiplier, ")")
				return true
			else:
				print("【巻物強打不発】", participant.creature_data.get("name", "?"), " 条件未達 → 通常の巻物攻撃")
				return false
	
	# 巻物強打効果が見つからない場合（無条件の巻物強打）
	var original_ap = participant.current_ap
	participant.current_ap = int(participant.current_ap * 1.5)
	print("【巻物強打発動】", participant.creature_data.get("name", "?"), 
		  " AP: ", original_ap, " → ", participant.current_ap, " (×1.5・無条件)")
	return true

## 通常の強打を適用
##
## 条件付きでAP上昇
##
## @param participant バトル参加者
## @param context バトルコンテキスト
## @param _effect_combat エフェクトコンバットシステム
static func apply_normal_power_strike(participant, context: Dictionary, _effect_combat) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var condition_checker = load("res://scripts/skills/condition_checker.gd").new()
	
	# 強打条件を満たしているか確認
	if condition_checker.check_power_strike(participant.creature_data, context):
		var base_ap = participant.current_ap
		var multiplier = 1.5  # デフォルトは1.5倍
		
		# ability_parsedから倍率を取得（将来的な拡張用）
		var effects = ability_parsed.get("effects", [])
		for effect in effects:
			if effect.get("effect_type") == "power_strike":
				multiplier = effect.get("multiplier", 1.5)
				break
		
		participant.current_ap = int(base_ap * multiplier)
		print("【強打発動】", participant.creature_data.get("name", "?"), " AP: ", base_ap, " → ", participant.current_ap, " (×", multiplier, ")")
