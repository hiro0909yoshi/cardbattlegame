extends Node
class_name ConditionChecker

# 条件判定を専門に扱うクラス
# 複雑な条件の組み合わせや、強化などの条件付きキーワードを評価

# 強化の条件パターン
enum PowerStrikeCondition {
	MHP_BELOW,           # MHP40以下など
	MHP_ABOVE,           # MHP40以上など
	ON_ELEMENT,          # 特定属性の土地
	HAS_ALL_ELEMENTS,    # 火水地風全て
	ENEMY_ELEMENT,       # 敵と同/異属性
	WITH_ITEM,           # アイテム使用時
	WITHOUT_ENEMY_ITEM,  # 敵アイテム不使用時
	ADJACENT_ALLY_LAND,  # 隣が自ドミニオ
	WITH_WEAPON,         # 武器使用時
	LEVEL_CAP            # レベル使用時
}

# 戦闘コンテキストから強化条件をチェック
func check_power_strike(creature_data: Dictionary, battle_context: Dictionary) -> bool:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	# 強化キーワードを探す
	for effect in effects:
		if effect.get("effect_type") == "power_strike":
			return _evaluate_power_strike_conditions(effect, battle_context)
	
	# キーワードリストからも確認
	var keywords = ability_parsed.get("keywords", [])
	if "強化" in keywords:
		var keyword_conditions = ability_parsed.get("keyword_conditions", {})
		var keyword_cond_data = keyword_conditions.get("強化", {})
		return evaluate_single_condition(keyword_cond_data, battle_context)
	
	return false

# 強化条件の評価
func _evaluate_power_strike_conditions(effect: Dictionary, context: Dictionary) -> bool:
	var effect_conditions = effect.get("conditions", [])
	
	# 条件が空の場合は無条件発動
	if effect_conditions.is_empty():
		return true
	
	# 全条件がtrueである必要がある（AND条件）
	for condition in effect_conditions:
		if not evaluate_single_condition(condition, context):
			return false
	
	return true

# 単一条件の評価
func evaluate_single_condition(condition: Dictionary, context: Dictionary) -> bool:
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
		
		# 使用者（自分）の属性チェック
		"user_element":
			var my_element = context.get("creature_element", "")
			var allowed_elements = condition.get("elements", [])
			return my_element in allowed_elements
		
		# 敵が特定の属性を持っているか（グラディエーター等の条件）
		"enemy_is_element":
			var enemy_element = context.get("enemy_element", "")
			var target_elements = condition.get("elements", [])
			# 文字列単体の場合は配列に変換
			if typeof(target_elements) == TYPE_STRING:
				target_elements = [target_elements]
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
		
		"item_equipped":
			var required_type = condition.get("item_type", "")
			var equipped_item = context.get("equipped_item", {})
			if equipped_item.is_empty():
				return false
			return equipped_item.get("item_type", "") == required_type
		
		"enemy_no_item":
			var enemy_item = context.get("enemy_item", null)
			return enemy_item == null
		
		"with_weapon":
			var equipped_item = context.get("equipped_item", {})
			return equipped_item.get("item_type", "") == "武器"
		
		# 土地条件
		"adjacent_ally_land":
			# TileNeighborSystemを使用した動的判定
			var battle_tile = context.get("battle_tile_index", -1)
			var player_id = context.get("player_id", -1)
			var board_system = context.get("board_system", null)
			
			print("【条件チェック】adjacent_ally_land:")
			print("  battle_tile=", battle_tile, " player_id=", player_id)
			print("  board_system=", board_system != null)
			
			if battle_tile == -1 or player_id == -1 or not board_system:
				# フォールバック: 従来の静的な値
				print("  → フォールバック: ", context.get("adjacent_is_ally_land", false))
				return context.get("adjacent_is_ally_land", false)
			
			# TileNeighborSystemで動的チェック
			if "tile_neighbor_system" in board_system and board_system.tile_neighbor_system:
				var result = board_system.has_adjacent_ally_land(
					battle_tile, player_id, board_system
				)
				print("  → TileNeighborSystem判定: ", result)
				return result
			
			print("  → TileNeighborSystemなし")
			return context.get("adjacent_is_ally_land", false)
		
		# レベル額条件
		"level_cap_item":
			var equipped_item = context.get("equipped_item", {})
			var item_rarity = equipped_item.get("rarity", "N")
			return item_rarity == "レベル額"
		
		# 土地レベル条件
		"land_level_check":
			var tile_level = context.get("tile_level", 1)
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 1)
			match operator:
				">=": return tile_level >= value
				">": return tile_level > value
				"<=": return tile_level <= value
				"<": return tile_level < value
				"==": return tile_level == value
				_: return false
		
		# AP条件（即死判定用）
		"ap_above":
			var enemy_ap = context.get("enemy_ap", 0)
			return enemy_ap >= cond_value
		
		"ap_below":
			var enemy_ap = context.get("enemy_ap", 100)
			return enemy_ap <= cond_value
		
		# 敵のAP判定（強化用）
		"enemy_ap_check":
			var enemy_ap = context.get("enemy_ap", 0)
			var operator = condition.get("operator", "<=")
			var value = condition.get("value", 0)
			match operator:
				"<=": return enemy_ap <= value
				">=": return enemy_ap >= value
				"<": return enemy_ap < value
				">": return enemy_ap > value
				"==": return enemy_ap == value
				_: return false
		
		# 敵の最大HP判定（強化用）
		"enemy_max_hp_check":
			var enemy_mhp = context.get("enemy_mhp", 0)
			var operator = condition.get("operator", "<=")
			var value = condition.get("value", 0)
			match operator:
				"<=": return enemy_mhp <= value
				">=": return enemy_mhp >= value
				"<": return enemy_mhp < value
				">": return enemy_mhp > value
				"==": return enemy_mhp == value
				_: return false
		
		# 堅守判定
		"is_defender_type":
			var enemy_abilities = context.get("enemy_abilities", [])
			return "堅守" in enemy_abilities
		
		# マーク判定（刻印システムで実装）
		"has_mark":
			# 敵クリーチャーが刻印を持っているかチェック
			var enemy_creature_data = context.get("enemy_creature_data", {})
			if enemy_creature_data.is_empty():
				return false
			return enemy_creature_data.has("curse")
		
		# レア度判定（ブラックソード等）
		"user_rarity":
			var creature_rarity = context.get("creature_rarity", "")
			var target_rarities = condition.get("rarities", [])
			return creature_rarity in target_rarities
		
		# 同名クリーチャー数判定（シャドウブレイズ等）
		"same_creature_count_check":
			var enemy_name = context.get("enemy_name", "")
			var board_system = context.get("board_system", null)
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 2)
			
			if enemy_name == "" or not board_system:
				return false
			
			var count = board_system.count_all_creatures_by_name(enemy_name)
			
			match operator:
				"<=": return count <= value
				">=": return count >= value
				"<": return count < value
				">": return count > value
				"==": return count == value
				_: return false
		
		# === 密命用条件タイプ ===
		
		# 手札に全属性カードを持っているか（アセンブルカード用）
		"has_all_element_cards":
			var hand_cards = context.get("hand_cards", [])
			var required_elements = ["fire", "water", "earth", "wind"]
			var found_elements = []
			
			for card in hand_cards:
				var element = card.get("element", "")
				if element in required_elements and not element in found_elements:
					found_elements.append(element)
			
			return found_elements.size() >= 4
		
		# 特定レベルの土地を指定数以上持っているか（フラットランド用）
		"level_land_count":
			var player_id = context.get("player_id", -1)
			var board_system = context.get("board_system", null)
			var required_level = condition.get("level", 2)
			var required_count = condition.get("count", 5)
			
			if player_id == -1 or not board_system:
				return false
			
			var count = 0
			for i in board_system.tile_nodes.keys():
				var tile = board_system.get_tile_data(i)
				if tile and tile.tile_owner == player_id and tile.level == required_level:
					count += 1
			
			return count >= required_count
		
		# 属性不一致の土地を指定数以上持っているか（ホームグラウンド用）
		"mismatched_element_lands":
			var player_id = context.get("player_id", -1)
			var board_system = context.get("board_system", null)
			var creature_manager = context.get("creature_manager", null)
			var required_count = condition.get("count", 4)
			
			if player_id == -1 or not board_system or not creature_manager:
				return false
			
			var mismatched_count = 0
			for i in board_system.tile_nodes.keys():
				var tile = board_system.get_tile_data(i)
				if tile and tile.tile_owner == player_id:
					if creature_manager.has_creature(i):
						var creature_data = creature_manager.get_data(i)
						var creature_element = creature_data.get("element", "")
						var land_element = tile.tile_type
						
						# 属性が異なる、または無属性の場合も不一致とする
						if creature_element != land_element or creature_element == "neutral":
							mismatched_count += 1
			
			return mismatched_count >= required_count
			
		_:
			push_warning("未実装の条件タイプ: " + cond_type)
			return false

# 複数条件の組み合わせ評価（OR条件）
func check_any_condition(conditions: Array, context: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if evaluate_single_condition(condition, context):
			return true
	
	return false

# 複数条件の組み合わせ評価（AND条件）
func check_all_conditions(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		if not evaluate_single_condition(condition, context):
			return false
	
	return true

# 密命条件のチェック（スペル用）
func check_secret_mission(spell_card: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell_card.get("effect_parsed", {})
	var keywords = effect_parsed.get("keywords", [])
	
	# 密命キーワードが存在しない場合は無条件成功
	if not "密命" in keywords:
		return {"success": true, "is_mission": false}
	
	# 密命の条件を取得
	var keyword_conditions = effect_parsed.get("keyword_conditions", {})
	var mission_data = keyword_conditions.get("密命", {})
	
	# 成功条件をチェック
	var success_conditions = mission_data.get("success_conditions", [])
	
	# 条件が空の場合は無条件成功
	if success_conditions.is_empty():
		return {"success": true, "is_mission": true}
	
	# 全条件を満たすかチェック
	var all_met = check_all_conditions(success_conditions, context)
	
	return {
		"success": all_met,
		"is_mission": true,
		"failure_effect": mission_data.get("failure_effect", "return_to_deck")
	}

# 即死条件のチェック
func check_instant_death(creature_data: Dictionary, battle_context: Dictionary) -> Dictionary:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "instant_death":
			var effect_conditions = effect.get("conditions", [])
			if check_all_conditions(effect_conditions, battle_context):
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
						var effect_conditions = effect.get("conditions", [])
						if check_all_conditions(effect_conditions, attack_context):
							return true
				"scroll":
					if attack_type == "scroll":
						return true
				"ap_below":
					var threshold = effect.get("value", 30)
					var attacker_ap = attack_context.get("attacker_ap", 0)
					if attacker_ap <= threshold:
						return true
				"element":
					var nullify_elements = effect.get("elements", [])
					var attack_element = attack_context.get("attacker_element", "")
					if attack_element in nullify_elements:
						return true
	
	return false

# 共鳴条件のチェック（ステータスボーナス）
func check_affinity(creature_data: Dictionary, game_context: Dictionary) -> Dictionary:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	var bonuses = {"ap": 0, "hp": 0}
	
	for effect in effects:
		if effect.get("effect_type") == "affinity":
			var element = effect.get("element", "")
			var player_lands = game_context.get("player_lands", {})
			
			if player_lands.get(element, 0) > 0:
				bonuses.ap += effect.get("ap_bonus", 0)
				bonuses.hp += effect.get("hp_bonus", 0)
	
	return bonuses

# コンテキストビルダー（戦闘用）
static func build_battle_context(attacker_data: Dictionary, defender_data: Dictionary, 
								  battle_field: Dictionary, game_state: Dictionary) -> Dictionary:
	return {
		# クリーチャー情報
		"creature_mhp": attacker_data.get("mhp", 0),
		"creature_element": attacker_data.get("element", ""),
		"creature_rarity": attacker_data.get("rarity", ""),
		"enemy_element": defender_data.get("element", ""),
		"enemy_name": game_state.get("enemy_name", defender_data.get("name", "")),
		"enemy_ap": defender_data.get("ap", 0),
		"enemy_mhp": game_state.get("enemy_mhp_override", defender_data.get("mhp", 0)),
		"enemy_creature_data": defender_data,  # 敵クリーチャーの完全なデータ（刻印判定用）
		
		# アイテム情報
		"equipped_item": attacker_data.get("equipped_item", {}),
		"enemy_item": defender_data.get("equipped_item", null),
		
		# 土地情報
		"battle_land_element": battle_field.get("element", ""),
		"tile_level": battle_field.get("level", 1),
		"adjacent_is_ally_land": battle_field.get("adjacent_ally", false),
		"player_lands": game_state.get("player_lands", {}),
		
		# 隣接判定用の追加情報
		"battle_tile_index": game_state.get("battle_tile_index", -1),
		"player_id": game_state.get("player_id", -1),
		"board_system": game_state.get("board_system", null),
		"game_flow_manager": game_state.get("game_flow_manager", null),
		
		# 能力情報
		"enemy_abilities": defender_data.get("abilities", []),
		
		# 攻撃タイプ
		"is_attacker": game_state.get("is_attacker", true),
		"is_placed_on_tile": game_state.get("is_placed_on_tile", false),  # Phase 3-B用
		"attack_type": "normal",  # or "scroll", "ability"
		
		# スクイドマントルチェック用
		"opponent": game_state.get("opponent", null),
		"is_defender": game_state.get("is_defender", false)
	}
