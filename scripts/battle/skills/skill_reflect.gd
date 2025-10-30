class_name SkillReflect

## 反射スキル処理モジュール
##
## 攻撃を受けた時にダメージを反射するスキルの判定と処理を行う
##
## 使用方法:
## ```gdscript
## var result = SkillReflect.check_damage(attacker, defender, damage, "normal")
## if result["has_reflect"]:
##     attacker.take_damage(result["reflect_damage"])
##     defender.take_damage(result["self_damage"])
## ```

## 反射スキルのチェックと反射ダメージの計算
##
## @param attacker_p: 攻撃側参加者
## @param defender_p: 防御側参加者  
## @param original_damage: 元のダメージ量
## @param attack_type: 攻撃タイプ ("normal" or "scroll")
## @return Dictionary {
##     "has_reflect": bool,  # 反射スキルがあるか
##     "reflect_damage": int,  # 反射するダメージ量
##     "self_damage": int  # 防御側が受けるダメージ量
## }
static func check_damage(attacker_p, defender_p, original_damage: int, attack_type: String) -> Dictionary:
	var result = {
		"has_reflect": false,
		"reflect_damage": 0,
		"self_damage": original_damage
	}
	
	# 1. 攻撃側が「反射無効」を持っているかチェック
	if _has_nullify_reflect(attacker_p):
		print("  【反射無効】攻撃側が反射無効を持つため、反射スキルは発動しない")
		return result
	
	# 2. 防御側の反射スキルを取得
	var reflect_effect = _get_reflect_effect(defender_p, attack_type)
	if reflect_effect == null:
		return result
	
	# 3. 条件チェック（条件付き反射の場合）
	var conditions = reflect_effect.get("conditions", [])
	if conditions.size() > 0:
		var context = _build_reflect_context(attacker_p, defender_p)
		if not _check_reflect_conditions(conditions, context):
			print("  【反射】条件不成立のため反射スキップ")
			return result
	
	# 4. 反射ダメージ計算
	var reflect_ratio = reflect_effect.get("reflect_ratio", 0.5)
	var self_damage_ratio = reflect_effect.get("self_damage_ratio", 0.5)
	
	result["has_reflect"] = true
	result["reflect_damage"] = int(original_damage * reflect_ratio)
	result["self_damage"] = int(original_damage * self_damage_ratio)
	
	var defender_name = defender_p.creature_data.get("name", "?")
	var attacker_name = attacker_p.creature_data.get("name", "?")
	
	if reflect_ratio >= 1.0:
		print("  【反射100%】", defender_name, " が攻撃を完全に反射")
	else:
		print("  【反射", int(reflect_ratio * 100), "%】", defender_name, " がダメージを反射")
	
	print("    - ", defender_name, " が受けるダメージ: ", result["self_damage"])
	print("    - ", attacker_name, " に返すダメージ: ", result["reflect_damage"])
	
	return result

## 攻撃側が「反射無効」を持っているかチェック
static func _has_nullify_reflect(attacker_p) -> bool:
	var ability_parsed = attacker_p.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "nullify_reflect":
			return true
	
	# アイテムもチェック
	var items = attacker_p.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var item_effects = effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "nullify_reflect":
				return true
	
	return false

## 防御側の反射スキルを取得
##
## @param defender_p: 防御側参加者
## @param attack_type: 攻撃タイプ ("normal" or "scroll")
## @return Dictionary or null
static func _get_reflect_effect(defender_p, attack_type: String):
	# クリーチャー自身のスキルをチェック
	var ability_parsed = defender_p.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "reflect_damage":
			var attack_types = effect.get("attack_types", [])
			if attack_type in attack_types:
				return effect
	
	# アイテムをチェック
	var items = defender_p.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var item_effects = effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "reflect_damage":
				var attack_types = effect.get("attack_types", [])
				if attack_type in attack_types:
					return effect
	
	return null

## 反射条件チェック用のコンテキスト構築
static func _build_reflect_context(attacker_p, defender_p) -> Dictionary:
	return {
		"attacker": attacker_p,
		"defender": defender_p,
		"attacker_has_item": _has_any_item(attacker_p)
	}

## クリーチャーがアイテムを持っているかチェック
static func _has_any_item(participant) -> bool:
	var items = participant.creature_data.get("items", [])
	return items.size() > 0

## 反射条件チェック
static func _check_reflect_conditions(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		var condition_type = condition.get("condition_type", "")
		
		if condition_type == "enemy_no_item":
			# 敵アイテム未使用時
			if context.get("attacker_has_item", false):
				return false
		# 他の条件タイプを追加可能
	
	return true
