extends Node
class_name ConditionChecker

# 条件判定を専門に扱うクラス
# 複雑な条件の組み合わせや、強打などの条件付きキーワードを評価

# 強打の条件パターン
enum PowerStrikeCondition {
	MHP_BELOW,           # MHP40以下など
	MHP_ABOVE,           # MHP40以上など
	ON_ELEMENT,          # 特定属性の土地
	HAS_ALL_ELEMENTS,    # 火水地風全て
	ENEMY_ELEMENT,       # 敵と同/異属性
	WITH_ITEM,           # アイテム使用時
	WITHOUT_ENEMY_ITEM,  # 敵アイテム不使用時
	ADJACENT_ALLY_LAND,  # 隣が自領地
	WITH_WEAPON,         # 武器使用時
	LEVEL_CAP            # レベル額使用時
}

# 戦闘コンテキストから強打条件をチェック
func check_power_strike(creature_data: Dictionary, battle_context: Dictionary) -> bool:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	# 強打キーワードを探す
	for effect in effects:
		if effect.get("effect_type") == "power_strike":
			return _evaluate_power_strike_conditions(effect, battle_context)
	
	# キーワードリストからも確認
	var keywords = ability_parsed.get("keywords", [])
	if "強打" in keywords:
		var keyword_conditions = ability_parsed.get("keyword_conditions", {})
		var conditions = keyword_conditions.get("強打", {})
		return _evaluate_single_condition(conditions, battle_context)
	
	return false

# 強打条件の評価
func _evaluate_power_strike_conditions(effect: Dictionary, context: Dictionary) -> bool:
	var conditions = effect.get("conditions", [])
	
	# 全条件がtrueである必要がある（AND条件）
	for condition in conditions:
		if not _evaluate_single_condition(condition, context):
			return false
	
	return true

# 単一条件の評価
func _evaluate_single_condition(condition: Dictionary, context: Dictionary) -> bool:
	var cond_type = condition.get("condition_type", "")
	var cond_value = condition.get("value", 0)
	
	match cond_type:
		# MHP条件
		"mhp_below":
			var target_mhp = context.get("creature_mhp", 100)
			return target_mhp <= cond_value
		
		"mhp_above":
			var target_mhp = context.get("creature_mhp", 0)
			return target_mhp >= cond_value
		
		# 属性土地条件
		"on_element_land":
			var element = condition.get("element", "")
			var land_element = context.get("battle_land_element", "")
			return land_element == element
		
		# 全属性条件（火水地風）
		"has_all_elements":
			var player_lands = context.get("player_lands", {})
			return player_lands.get("火", 0) > 0 and \
				   player_lands.get("水", 0) > 0 and \
				   player_lands.get("地", 0) > 0 and \
				   player_lands.get("風", 0) > 0
		
		# 敵が特定の属性を持っているか（グラディエーター等の条件）
		"enemy_is_element":
			var enemy_element = context.get("enemy_element", "")
			var target_elements = condition.get("elements", [])
			return enemy_element in target_elements
		
		# 敵との属性関係
		"enemy_same_element":
			var my_element = context.get("creature_element", "")
			var enemy_element = context.get("enemy_element", "")
			return my_element == enemy_element
		
		"enemy_different_element":
			var my_element = context.get("creature_element", "")
			var enemy_element = context.get("enemy_element", "")
			return my_element != enemy_element
		
		# アイテム条件
		"with_item_type":
			var item_type = condition.get("item_type", "")
			var equipped_item = context.get("equipped_item", {})
			return equipped_item.get("item_type", "") == item_type
		
		"enemy_no_item":
			var enemy_item = context.get("enemy_item", null)
			return enemy_item == null
		
		"with_weapon":
			var equipped_item = context.get("equipped_item", {})
			return equipped_item.get("item_type", "") == "武器"
		
		# 土地条件
		"adjacent_ally_land":
			return context.get("adjacent_is_ally_land", false)
		
		# レベル額条件
		"level_cap_item":
			var equipped_item = context.get("equipped_item", {})
			var item_rarity = equipped_item.get("rarity", "N")
			return item_rarity == "レベル額"
		
		# ST条件（即死判定用）
		"st_above":
			var enemy_st = context.get("enemy_st", 0)
			return enemy_st >= cond_value
		
		"st_below":
			var enemy_st = context.get("enemy_st", 100)
			return enemy_st <= cond_value
		
		# 防御型判定
		"is_defender_type":
			var enemy_abilities = context.get("enemy_abilities", [])
			return "防御型" in enemy_abilities
			
		_:
			push_warning("未実装の条件タイプ: " + cond_type)
			return false

# 複数条件の組み合わせ評価（OR条件）
func check_any_condition(conditions: Array, context: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if _evaluate_single_condition(condition, context):
			return true
	
	return false

# 複数条件の組み合わせ評価（AND条件）
func check_all_conditions(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		if not _evaluate_single_condition(condition, context):
			return false
	
	return true

# 即死条件のチェック
func check_instant_death(creature_data: Dictionary, battle_context: Dictionary) -> Dictionary:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "instant_death":
			var conditions = effect.get("conditions", [])
			if check_all_conditions(conditions, battle_context):
				return {
					"can_instant_death": true,
					"probability": effect.get("probability", 60)
				}
	
	return {"can_instant_death": false, "probability": 0}

# 無効化条件のチェック
func check_nullify(creature_data: Dictionary, attack_context: Dictionary) -> bool:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "nullify":
			var nullify_type = effect.get("nullify_type", "")
			var attack_type = attack_context.get("attack_type", "")
			
			match nullify_type:
				"normal_attack":
					if attack_type == "normal":
						var conditions = effect.get("conditions", [])
						if check_all_conditions(conditions, attack_context):
							return true
				"scroll":
					if attack_type == "scroll":
						return true
				"st_below":
					var threshold = effect.get("value", 30)
					var attacker_st = attack_context.get("attacker_st", 0)
					if attacker_st <= threshold:
						return true
				"element":
					var nullify_elements = effect.get("elements", [])
					var attack_element = attack_context.get("attacker_element", "")
					if attack_element in nullify_elements:
						return true
	
	return false

# 感応条件のチェック（ステータスボーナス）
func check_affinity(creature_data: Dictionary, game_context: Dictionary) -> Dictionary:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	var bonuses = {"st": 0, "hp": 0}
	
	for effect in effects:
		if effect.get("effect_type") == "affinity":
			var element = effect.get("element", "")
			var player_lands = game_context.get("player_lands", {})
			
			if player_lands.get(element, 0) > 0:
				bonuses.st += effect.get("st_bonus", 0)
				bonuses.hp += effect.get("hp_bonus", 0)
	
	return bonuses

# コンテキストビルダー（戦闘用）
static func build_battle_context(attacker_data: Dictionary, defender_data: Dictionary, 
								  battle_field: Dictionary, game_state: Dictionary) -> Dictionary:
	return {
		# クリーチャー情報
		"creature_mhp": attacker_data.get("mhp", 0),
		"creature_element": attacker_data.get("element", ""),
		"enemy_element": defender_data.get("element", ""),
		"enemy_st": defender_data.get("st", 0),
		"enemy_mhp": defender_data.get("mhp", 0),
		
		# アイテム情報
		"equipped_item": attacker_data.get("equipped_item", {}),
		"enemy_item": defender_data.get("equipped_item", null),
		
		# 土地情報
		"battle_land_element": battle_field.get("element", ""),
		"adjacent_is_ally_land": battle_field.get("adjacent_ally", false),
		"player_lands": game_state.get("player_lands", {}),
		
		# 能力情報
		"enemy_abilities": defender_data.get("abilities", []),
		
		# 攻撃タイプ
		"is_attacker": true,
		"attack_type": "normal"  # or "scroll", "ability"
	}
