## 戦闘開始時条件スキル - 戦闘開始時に条件に応じて効果を発動
##
## 【主な機能】
## - self_destruct: 条件を満たすと自壊
## - hp_penalty: 条件を満たすとHP減少
##
## 【該当クリーチャー】
## - スラッジタイタン (ID: 125): HP減少中なら自壊
## - ギガンテリウム (ID: 206): 呪い付きならHP-20
##
## @version 1.0
## @date 2025-12-06

class_name SkillBattleStartConditions


## 戦闘開始時条件をチェックして適用
##
## @param participant バトル参加者
## @param context バトルコンテキスト（自分のクリーチャーデータを含む）
## @return 結果辞書 { self_destructed: bool, hp_reduced: int }
static func apply(participant, context: Dictionary) -> Dictionary:
	var result = {
		"self_destructed": false,
		"hp_reduced": 0
	}
	
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var condition = effect.get("condition", "")
		
		match effect_type:
			"self_destruct":
				# 自壊条件チェック
				if _check_condition(condition, participant, context):
					print("【戦闘開始時自壊】%s は条件「%s」を満たしたため自壊" % [
						participant.creature_data.get("name", "?"),
						condition
					])
					participant.base_hp = 0
					participant.current_hp = 0
					result["self_destructed"] = true
			
			"hp_penalty":
				# HPペナルティ条件チェック
				if _check_condition(condition, participant, context):
					var amount = effect.get("amount", 0)
					print("【戦闘開始時HPペナルティ】%s は条件「%s」を満たしたためHP-%d" % [
						participant.creature_data.get("name", "?"),
						condition,
						amount
					])
					participant.current_hp = maxi(0, participant.current_hp - amount)
					result["hp_reduced"] = amount
	
	return result


## 条件をチェック
##
## @param condition 条件タイプ
## @param participant バトル参加者
## @param context バトルコンテキスト
## @return 条件を満たすか
static func _check_condition(condition: String, participant, _context: Dictionary) -> bool:
	match condition:
		"hp_damaged":
			# HP減少中（現在HPがMHP未満）
			return participant.is_damaged()
		
		"has_mark":
			# 自分のクリーチャーが呪いを持っているか
			var creature_data = participant.creature_data
			return creature_data.has("curse") and not creature_data.get("curse", {}).is_empty()
		
		_:
			return false
