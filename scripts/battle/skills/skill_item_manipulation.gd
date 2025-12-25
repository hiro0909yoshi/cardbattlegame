class_name SkillItemManipulation

## アイテム操作スキル処理モジュール
##
## アイテム破壊とアイテム盗みのスキル判定と処理を行う
##
## 使用方法:
## ```gdscript
## SkillItemManipulation.apply(first_attacker, second_attacker)
## ```

## アイテム操作スキルを適用（先制順序で処理）
##
## @param first: 先に行動する側
## @param second: 後に行動する側
## @return 発動したスキルの配列 [{"actor": participant, "skill_type": "destroy_item"/"steal_item"}, ...]
static func apply(first, second) -> Array:
	var results = []
	
	# 先に行動する側の処理
	var first_result = _process_item_manipulation(first, second)
	if first_result:
		results.append(first_result)
	
	# 後に行動する側の処理（アイテムがまだ残っていれば）
	var second_result = _process_item_manipulation(second, first)
	if second_result:
		results.append(second_result)
	
	return results

## 単一参加者のアイテム破壊・盗み処理
## @return 発動したスキルの情報 {"actor": participant, "skill_type": "destroy_item"/"steal_item"} or null
static func _process_item_manipulation(actor, target):
	# 対象がアイテム破壊・盗み無効を持つかチェック
	if _has_nullify_item_manipulation(target):
		return null
	
	# アイテム破壊スキルをチェック
	var destroy_effect = _get_destroy_item_effect(actor)
	if destroy_effect:
		var success = _execute_destroy_item(actor, target, destroy_effect)
		if success:
			return {"actor": actor, "skill_type": "destroy_item"}
		return null
	
	# アイテム盗みスキルをチェック
	var steal_effect = _get_steal_item_effect(actor)
	if steal_effect:
		var success = _execute_steal_item(actor, target, steal_effect)
		if success:
			return {"actor": actor, "skill_type": "steal_item"}
	
	return null

## アイテム破壊・盗み無効を持つかチェック
static func _has_nullify_item_manipulation(participant) -> bool:
	var participant_name = participant.creature_data.get("name", "?")
	
	# クリーチャー能力をチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "nullify_item_manipulation":
			print("  【アイテム操作無効】", participant_name, " がアイテム破壊・盗みを無効化（クリーチャー能力）")
			return true
	
	# アイテム効果をチェック（エンジェルケープ等）
	var items = participant.creature_data.get("items", [])
	for item in items:
		var item_effect_parsed = item.get("effect_parsed", {})
		var item_effects = item_effect_parsed.get("effects", [])
		for item_effect in item_effects:
			if item_effect.get("effect_type") == "nullify_item_manipulation":
				print("  【アイテム操作無効】", participant_name, " がアイテム破壊・盗みを無効化（", item.get("name", "?"), "）")
				return true
	
	return false

## アイテム破壊スキルを取得
static func _get_destroy_item_effect(participant):
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				return effect
	
	return null

## アイテム盗みスキルを取得
static func _get_steal_item_effect(participant):
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "steal_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				# 条件チェック: 自分がアイテム未使用
				var conditions = effect.get("conditions", [])
				for condition in conditions:
					if condition.get("condition_type") == "self_no_item":
						if _has_any_item(participant):
							return null  # 自分がアイテムを持っている場合は盗めない
				return effect
	
	return null

## アイテムを持っているかチェック
static func _has_any_item(participant) -> bool:
	if not participant or not participant.creature_data:
		return false
	
	var items = participant.creature_data.get("items", [])
	return items.size() > 0

## アイテム破壊を実行
## @return 成功したらtrue
static func _execute_destroy_item(actor, target, effect: Dictionary) -> bool:
	var target_items = target.creature_data.get("items", [])
	if target_items.is_empty():
		return false
	
	# 対象のアイテムタイプをチェック
	var target_item = target_items[0]
	var item_type = target_item.get("item_type", "")
	var target_types = effect.get("target_types", [])
	
	# タイプが一致するかチェック
	# 「道具」は武器・防具・アクセサリを含む
	var type_matches = false
	if item_type in target_types:
		type_matches = true
	elif "道具" in target_types and item_type in ["武器", "防具", "アクセサリ"]:
		type_matches = true
	
	if not type_matches:
		return false
	
	# アイテム名を取得（先に宣言）
	var actor_name = actor.creature_data.get("name", "?")
	var target_name = target.creature_data.get("name", "?")
	var item_name = target_item.get("name", "???")
	
	# レア度チェック（グレムリンアイ等）
	var rarity_exclude = effect.get("rarity_exclude", [])
	if not rarity_exclude.is_empty():
		var item_rarity = target_item.get("rarity", "N")
		if item_rarity in rarity_exclude:
			print("  【レア度除外】", item_name, " (レア度: ", item_rarity, ") は破壊対象外")
			return false
	
	print("【アイテム破壊】", actor_name, " が ", target_name, " の ", item_name, " を破壊")
	
	# アイテムを削除（効果はまだ適用されていないので、削除するだけでOK）
	target.creature_data["items"] = []
	return true

## アイテム盗みを実行
## @return 成功したらtrue
static func _execute_steal_item(actor, target, _effect: Dictionary) -> bool:
	var target_items = target.creature_data.get("items", [])
	if target_items.is_empty():
		return false
	
	var actor_name = actor.creature_data.get("name", "?")
	var target_name = target.creature_data.get("name", "?")
	var stolen_item = target_items[0]
	var item_name = stolen_item.get("name", "???")
	
	print("【アイテム盗み】", actor_name, " が ", target_name, " の ", item_name, " を奪った")
	
	# 対象からアイテムを削除（効果はまだ適用されていない）
	target.creature_data["items"] = []
	
	# 自分にアイテムを追加（効果の適用はapply_remaining_item_effectsで行う）
	if not actor.creature_data.has("items"):
		actor.creature_data["items"] = []
	actor.creature_data["items"].append(stolen_item)
	return true

## アイテム効果を削除（ステータスを元に戻す）
static func _remove_item_effects(participant, item: Dictionary) -> void:
	var effect_parsed = item.get("effect_parsed", {})
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	
	var ap = stat_bonus.get("ap", 0)
	var hp = stat_bonus.get("hp", 0)
	
	if ap > 0:
		participant.current_ap -= ap
		print("    - AP-", ap, " → ", participant.current_ap)
	
	if hp > 0:
		participant.item_bonus_hp -= hp
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
		print("    - HP-", hp, " → ", participant.current_hp)

## 盗んだアイテムの効果を適用
static func _apply_stolen_item_effects(participant, item: Dictionary) -> void:
	var effect_parsed = item.get("effect_parsed", {})
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	
	var ap = stat_bonus.get("ap", 0)
	var hp = stat_bonus.get("hp", 0)
	
	if ap > 0:
		participant.current_ap += ap
		print("    + AP+", ap, " → ", participant.current_ap)
	
	if hp > 0:
		participant.item_bonus_hp += hp
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
		print("    + HP+", hp, " → ", participant.current_hp)
