## CPU AI用 ターゲット解決クラス
## スペルのtarget_conditionに基づいてターゲット候補を取得
class_name CPUTargetResolver
extends RefCounted

## 呪い判別クラス
const CurseEvaluator = preload("res://scripts/cpu_ai/cpu_curse_evaluator.gd")

## 参照
var board_analyzer: CPUBoardAnalyzer = null
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var game_flow_manager: Node = null

## 初期化
func initialize(analyzer: CPUBoardAnalyzer, b_system: Node, p_system: Node, c_system: Node, gf_manager: Node = null) -> void:
	board_analyzer = analyzer
	board_system = b_system
	player_system = p_system
	card_system = c_system
	game_flow_manager = gf_manager

# =============================================================================
# メインターゲット条件チェック
# =============================================================================

## ターゲット条件をチェックし、有効なターゲットを返す
func check_target_condition(target_condition: String, context: Dictionary) -> Array:
	var results = _check_target_condition_internal(target_condition, context)
	
	# 全ての結果に防魔フィルタを適用
	results = _apply_protection_filter(results, context)
	
	return results

## 防魔・HP効果無効フィルタを適用（ターゲット共通）
func _apply_protection_filter(targets: Array, context: Dictionary) -> Array:
	var filtered = []
	var world_curse = {}
	if game_flow_manager and "game_stats" in game_flow_manager:
		world_curse = game_flow_manager.game_stats.get("world_curse", {})
	var protection_context = {"world_curse": world_curse}
	
	# スペルがHP効果を持つか確認
	var spell = context.get("spell", {})
	var effect_parsed = spell.get("effect_parsed", {})
	var affects_hp = effect_parsed.get("affects_hp", false)
	
	for target in targets:
		var target_type = target.get("type", "")
		var should_skip = false
		
		if target_type == "creature" or target.has("creature"):
			var creature = target.get("creature", {})
			if not creature.is_empty():
				# 防魔チェック
				if SpellProtection.is_creature_protected(creature, protection_context):
					should_skip = true
				# HP効果無効チェック
				elif affects_hp and SpellHpImmune.has_hp_effect_immune(creature):
					should_skip = true
		elif target_type == "player":
			var player_id = target.get("player_id", -1)
			if player_id >= 0 and player_system and player_id < player_system.players.size():
				if SpellProtection.is_player_protected(player_system.players[player_id], protection_context):
					should_skip = true
		
		if not should_skip:
			filtered.append(target)
	
	return filtered

## 内部ターゲット条件チェック
func _check_target_condition_internal(target_condition: String, context: Dictionary) -> Array:
	match target_condition:
		# クリーチャー属性
		"fire_wind_creature":
			return _get_creatures_by_elements(["fire", "wind"], "enemy", context)
		"water_earth_creature":
			return _get_creatures_by_elements(["water", "earth"], "enemy", context)
		"fire_earth_creature":
			return _get_creatures_by_elements(["fire", "earth"], "enemy", context)
		"water_wind_creature":
			return _get_creatures_by_elements(["water", "wind"], "enemy", context)
		"fire_water_creature":
			return _get_creatures_by_elements(["fire", "water"], "enemy", context)
		"earth_wind_creature":
			return _get_creatures_by_elements(["earth", "wind"], "enemy", context)
		"neutral_creature":
			return _get_creatures_by_elements(["neutral"], "enemy", context)
		
		# 所有者フィルター
		"enemy_creature":
			return _get_creatures_by_owner("enemy", context)
		"own_creature":
			return _get_creatures_by_owner("own", context)
		
		# 状態フィルター
		"element_mismatch_creatures", "element_mismatch_creature":
			return _get_element_mismatch_creatures(context)
		"element_mismatch_enemy":
			return _get_element_mismatch_enemy_creatures(context)
		"cursed_creatures":
			return _get_cursed_creatures(context)
		"cursed_enemy_creature":
			return _get_cursed_enemy_creatures(context)
		"hp_reduced":
			return _get_hp_reduced_creatures(context)
		"hp_reduced_enemy":
			return _get_hp_reduced_enemy_creatures(context)
		"low_mhp_creatures":
			return _get_low_mhp_creatures(context)
		"low_mhp_enemy_creatures":
			return _get_low_mhp_enemy_creatures(context)
		"downed_high_mhp":
			return _get_downed_high_mhp_creatures(context)
		"duplicate_creatures_exist":
			return _get_duplicate_creatures(context)
		"duplicate_enemy_creatures":
			return _get_duplicate_enemy_creatures(context)
		
		# 特殊条件
		"can_kill_target":
			return _get_killable_targets(context)
		"can_kill_with_40_damage":
			return _get_killable_targets_with_damage(context, 40)
		"most_common_element":
			return _get_most_common_element_creatures(context)
		"has_summon_condition":
			return _get_creatures_with_summon_condition(context)
		"no_curse_no_mystic":
			return _get_creatures_without_curse_or_mystic(context)
		"has_mystic_arts":
			return _get_creatures_with_mystic_arts(context)
		"high_value_or_mystic_enemy":
			return _get_high_value_or_mystic_enemy(context)
		
		# プレイヤー条件
		"enemy_has_2_items", "has_2_items":
			return _get_enemies_with_items(2, context)
		"enemy_has_high_toll":
			return _get_enemies_with_high_toll(context)
		"enemy_has_more_magic":
			return _get_enemies_with_more_magic(context)
		"enemy_player":
			return _get_enemy_players(context)
		"enemy_player_with_creatures":
			return _get_enemy_players_with_creatures(context)
		"self_has_creatures":
			return _check_self_has_creatures(context)
		"self_player", "self_target":
			return _get_self_player(context)
		
		# 敵手札条件（enemy_hand用）
		"has_item_or_spell":
			return _get_enemies_with_item_or_spell(context)
		"has_spell":
			return _get_enemies_with_spell(context)
		"has_duplicate_cards":
			return _get_enemies_with_duplicate_cards(context)
		"has_expensive_cards":
			return _get_enemies_with_expensive_cards(context)
		
		# 土地条件
		"has_empty_land":
			return _get_empty_lands(context)
		"enemy_has_land_bonus":
			return _get_enemies_with_land_bonus(context)
		"own_no_land_bonus":
			return _get_own_without_land_bonus(context)
		
		_:
			push_warning("CPUTargetResolver: Unknown target_condition: " + target_condition)
			return []

# =============================================================================
# クリーチャー属性フィルター
# =============================================================================

## 属性でクリーチャーをフィルタ
func _get_creatures_by_elements(elements: Array, owner_filter: String, context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		var creature_element = creature.get("element", "")
		if creature_element not in elements:
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_filter == "enemy" and owner_id == player_id:
			continue
		if owner_filter == "own" and owner_id != player_id:
			continue
		
		results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 所有者でクリーチャーをフィルタ
func _get_creatures_by_owner(owner_filter: String, context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_filter == "enemy" and (owner_id == player_id or owner_id == -1):
			continue
		if owner_filter == "own" and owner_id != player_id:
			continue
		
		results.append({"type": "creature", "tile_index": tile.get("index", -1), "creature": creature})
	
	return results

# =============================================================================
# 状態フィルター
# =============================================================================

## 属性不一致のクリーチャーを取得
func _get_element_mismatch_creatures(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		
		if tile_element != creature_element and tile_element != "neutral" and creature_element != "neutral":
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 属性不一致の敵クリーチャーを取得
func _get_element_mismatch_enemy_creatures(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		
		if tile_element != creature_element and tile_element != "neutral" and creature_element != "neutral":
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 呪い付きクリーチャーを取得
func _get_cursed_creatures(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and board_analyzer.has_curse(creature):
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 呪い付き敵クリーチャーを取得
func _get_cursed_enemy_creatures(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and board_analyzer.has_curse(creature):
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## HP減少中のクリーチャーを取得
func _get_hp_reduced_creatures(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		var current_hp = creature.get("current_hp", 0)
		var max_hp = creature.get("max_hp", 0)
		if current_hp < max_hp:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## HP減少中の敵クリーチャーを取得
func _get_hp_reduced_enemy_creatures(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var current_hp = creature.get("current_hp", creature.get("hp", 0))
		var max_hp = creature.get("max_hp", creature.get("hp", 0))
		if current_hp < max_hp:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## MHP30以下のクリーチャーを取得
func _get_low_mhp_creatures(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		var max_hp = creature.get("max_hp", 0)
		if max_hp <= 30:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## MHP30以下の敵クリーチャーを取得
func _get_low_mhp_enemy_creatures(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var max_hp = creature.get("max_hp", creature.get("hp", 0))
		if max_hp <= 30:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## ダウン中かつMHP50以上のクリーチャーを取得
func _get_downed_high_mhp_creatures(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		var is_down = creature.get("is_down", false)
		var max_hp = creature.get("max_hp", 0)
		if is_down and max_hp >= 50:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

# =============================================================================
# 重複クリーチャー
# =============================================================================

## 重複クリーチャーを取得（全体）
func _get_duplicate_creatures(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var creature_counts = {}
	var creature_tiles = {}
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and not creature.is_empty():
			var creature_id = creature.get("id", 0)
			creature_counts[creature_id] = creature_counts.get(creature_id, 0) + 1
			if not creature_tiles.has(creature_id):
				creature_tiles[creature_id] = []
			creature_tiles[creature_id].append({"tile_index": tile.get("index", -1), "creature": creature})
	
	for creature_id in creature_counts:
		if creature_counts[creature_id] >= 2:
			results.append_array(creature_tiles[creature_id])
	
	return results

## 重複している敵クリーチャーを取得
func _get_duplicate_enemy_creatures(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var creature_counts = {}
	var creature_tiles = {}
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and not creature.is_empty():
			var creature_id = creature.get("id", 0)
			creature_counts[creature_id] = creature_counts.get(creature_id, 0) + 1
			if not creature_tiles.has(creature_id):
				creature_tiles[creature_id] = []
			creature_tiles[creature_id].append({"tile_index": tile.get("index", -1), "creature": creature})
	
	for creature_id in creature_counts:
		if creature_counts[creature_id] >= 2:
			results.append_array(creature_tiles[creature_id])
	
	return results

# =============================================================================
# 特殊条件
# =============================================================================

## 倒せるターゲットを取得（倒せるターゲット優先、なければ敵クリーチャー全体）
func _get_killable_targets(context: Dictionary) -> Array:
	var damage = context.get("damage_value", 0)
	var player_id = context.get("player_id", 0)
	var killable = []
	var all_enemies = []
	
	if not board_system:
		return []
	
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		
		# 敵クリーチャーのみ対象
		if owner_id == player_id or owner_id == -1:
			continue
		
		var current_hp = creature.get("current_hp", creature.get("hp", 0))
		var target_data = {"type": "creature", "tile_index": tile.get("index", -1), "creature": creature}
		
		all_enemies.append(target_data)
		
		if current_hp > 0 and current_hp <= damage:
			killable.append(target_data)
	
	# 倒せるターゲットがいればそれを優先、なければ敵クリーチャー全体
	if not killable.is_empty():
		return killable
	return all_enemies


## 指定ダメージで倒せるターゲットを取得（シャイニングガイザー等）
## 倒せるターゲット優先、なければ敵クリーチャー全体
func _get_killable_targets_with_damage(context: Dictionary, damage: int) -> Array:
	var player_id = context.get("player_id", 0)
	var killable = []
	var all_enemies = []
	
	if not board_system:
		return []
	
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		
		# 敵クリーチャーのみ対象
		if owner_id == player_id or owner_id == -1:
			continue
		
		var current_hp = creature.get("current_hp", creature.get("hp", 0))
		var target_data = {"type": "creature", "tile_index": tile.get("index", -1), "creature": creature}
		
		all_enemies.append(target_data)
		
		if current_hp > 0 and current_hp <= damage:
			killable.append(target_data)
	
	# 倒せるターゲットがいればそれを優先、なければ敵クリーチャー全体
	if not killable.is_empty():
		return killable
	return all_enemies


## 最多属性のクリーチャーを取得
func _get_most_common_element_creatures(context: Dictionary) -> Array:
	if not board_system:
		return []
	
	# 属性ごとのカウント
	var element_counts = {}
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature:
			var element = creature.get("element", "")
			element_counts[element] = element_counts.get(element, 0) + 1
	
	# 最多属性を特定
	var max_element = ""
	var max_count = 0
	for element in element_counts:
		if element_counts[element] > max_count:
			max_count = element_counts[element]
			max_element = element
	
	# 該当クリーチャーを返す
	return _get_creatures_by_elements([max_element], "any", context)

## 召喚条件持ちクリーチャーを取得
func _get_creatures_with_summon_condition(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id:
			continue  # 敵のみ
		
		if creature.get("summon_condition"):
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 呪いもアルカナアーツも持たないクリーチャーを取得
func _get_creatures_without_curse_or_mystic(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		if not board_analyzer.has_curse(creature) and not creature.get("mystic_arts"):
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## アルカナアーツ持ちクリーチャーを取得
func _get_creatures_with_mystic_arts(_context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		if creature.get("mystic_arts"):
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 高価値またはアルカナアーツ持ちの敵クリーチャーを取得
func _get_high_value_or_mystic_enemy(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system:
		return results
	
	var CardRateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
	const HIGH_RATE_THRESHOLD = 50  # 高レートの閾値
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		# アルカナアーツ持ちチェック
		var has_mystic = creature.get("mystic_arts") != null
		if not has_mystic:
			var ability_parsed = creature.get("ability_parsed", {})
			if ability_parsed:
				var mystic_arts = ability_parsed.get("mystic_arts", [])
				has_mystic = not mystic_arts.is_empty()
				if not has_mystic:
					var keywords = ability_parsed.get("keywords", [])
					has_mystic = "アルカナアーツ" in keywords
		
		# レートチェック
		var rate = CardRateEvaluator.get_rate(creature)
		var is_high_value = rate >= HIGH_RATE_THRESHOLD
		
		if has_mystic or is_high_value:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

# =============================================================================
# プレイヤー条件
# =============================================================================

## アイテムを指定数以上持つ敵を取得
func _get_enemies_with_items(min_count: int, context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not card_system or not player_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i == player_id:
			continue
		
		var hand = card_system.get_all_cards_for_player(i)
		var item_count = 0
		for card in hand:
			if card.get("type") == "item":
				item_count += 1
		
		if item_count >= min_count:
			results.append({"type": "player", "player_id": i})
	
	return results

## 高通行料の土地を持つ敵を取得
func _get_enemies_with_high_toll(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not board_system or not player_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i == player_id:
			continue
		
		# 敵のレベル3以上の土地をチェック
		var enemy_lands = board_analyzer.get_enemy_lands_by_level(player_id, 3)
		if enemy_lands.size() > 0:
			results.append({"type": "player", "player_id": i})
	
	return results

## 自分よりEPが多い敵を取得
func _get_enemies_with_more_magic(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system:
		return results
	
	var my_magic = player_system.get_magic(player_id)
	var player_count = player_system.players.size()
	
	for i in range(player_count):
		if i == player_id:
			continue
		
		var other_magic = player_system.get_magic(i)
		if other_magic > my_magic:
			results.append({"type": "player", "player_id": i, "magic": other_magic})
	
	return results

## 敵プレイヤーリストを取得
func _get_enemy_players(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			results.append({"type": "player", "player_id": i})
	
	return results

## クリーチャーを持つ敵プレイヤーを取得
func _get_enemy_players_with_creatures(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system or not board_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			# このプレイヤーがクリーチャーを持っているかチェック
			if _player_has_creatures(i):
				results.append({"type": "player", "player_id": i})
	
	return results

## プレイヤーがクリーチャーを持っているかチェック
func _player_has_creatures(player_id: int) -> bool:
	if not board_system:
		return false
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id:
			var creature = tile.get("creature", tile.get("placed_creature", {}))
			if not creature.is_empty():
				return true
	return false

## 自分がクリーチャーを持っている場合にtrue
func _check_self_has_creatures(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	if _player_has_creatures(player_id):
		return [{"type": "self", "player_id": player_id}]
	return []

## 自分自身を取得
func _get_self_player(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	return [{"type": "player", "player_id": player_id}]

## アイテムまたはスペルを持つ敵プレイヤーを取得（シャッター、メタモルフォシス用）
func _get_enemies_with_item_or_spell(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system or not card_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i == player_id:
			continue
		
		var hand = card_system.get_all_cards_for_player(i)
		var has_target_card = false
		for card in hand:
			var card_type = card.get("type", "")
			if card_type == "item" or card_type == "spell":
				has_target_card = true
				break
		
		if has_target_card:
			results.append({"type": "player", "player_id": i, "hand_size": hand.size()})
	
	return results

## スペルを持つ敵プレイヤーを取得（セフト用）
func _get_enemies_with_spell(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system or not card_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i == player_id:
			continue
		
		var hand = card_system.get_all_cards_for_player(i)
		var has_spell = false
		for card in hand:
			if card.get("type", "") == "spell":
				has_spell = true
				break
		
		if has_spell:
			results.append({"type": "player", "player_id": i, "hand_size": hand.size()})
	
	return results

## 手札に重複カードがある敵プレイヤーを取得（エロージョン用）
func _get_enemies_with_duplicate_cards(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system or not card_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i == player_id:
			continue
		
		var hand = card_system.get_all_cards_for_player(i)
		var card_ids = {}
		var has_duplicate = false
		for card in hand:
			var card_id = card.get("id", 0)
			if card_ids.has(card_id):
				has_duplicate = true
				break
			card_ids[card_id] = true
		
		if has_duplicate:
			results.append({"type": "player", "player_id": i, "hand_size": hand.size()})
	
	return results

## 手札にEP100以上のカードがある敵プレイヤーを取得（レイオブロウ用）
func _get_enemies_with_expensive_cards(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system or not card_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i == player_id:
			continue
		
		var hand = card_system.get_all_cards_for_player(i)
		var has_expensive = false
		for card in hand:
			var cost = card.get("cost", {})
			var ep = cost.get("ep", 0) if cost is Dictionary else 0
			if ep >= 100:
				has_expensive = true
				break
		
		if has_expensive:
			results.append({"type": "player", "player_id": i, "hand_size": hand.size()})
	
	return results

## 手札を持つ敵プレイヤーを取得（enemy_hand用簡易版）
func _get_enemies_with_cards(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var results = []
	
	if not player_system or not card_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i == player_id:
			continue
		
		var hand = card_system.get_all_cards_for_player(i)
		if hand.size() > 0:
			results.append({"type": "player", "player_id": i, "hand_size": hand.size()})
	
	return results

# =============================================================================
# 土地条件
# =============================================================================

## 空き地を取得
func _get_empty_lands(_context: Dictionary) -> Array:
	return board_analyzer.get_empty_lands()

## 地形ボーナスを持つ敵クリーチャーを取得
func _get_enemies_with_land_bonus(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	return board_analyzer.get_enemies_with_land_bonus(player_id)

## 地形ボーナスを持たない自クリーチャーを取得
func _get_own_without_land_bonus(context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	return board_analyzer.get_own_without_land_bonus(player_id)

# =============================================================================
# 呪いスペル用フィルタリング
# =============================================================================

## 呪いスペルのターゲット候補をフィルタリング
## curse_is_beneficial: 付与する呪いが有利(true)か不利(false)か
## targets: ターゲット候補のリスト
## context: コンテキスト（player_idを含む）
## 戻り値: フィルタリング後のターゲットリスト
func filter_curse_spell_targets(curse_is_beneficial: bool, targets: Array, context: Dictionary) -> Array:
	var player_id = context.get("player_id", 0)
	var filtered = []
	
	for target in targets:
		var creature = target.get("creature", {})
		if creature.is_empty():
			filtered.append(target)  # クリーチャー以外はそのまま
			continue
		
		var tile_index = target.get("tile_index", -1)
		var owner_id = _get_tile_owner(tile_index)
		
		if curse_is_beneficial:
			# 有利な呪いを付ける場合
			if CpuCurseEvaluator.is_valid_beneficial_curse_target(player_id, owner_id, creature):
				filtered.append(target)
		else:
			# 不利な呪いを付ける場合
			if CpuCurseEvaluator.is_valid_harmful_curse_target(player_id, owner_id, creature):
				filtered.append(target)
	
	return filtered


## タイルの所有者IDを取得
func _get_tile_owner(tile_index: int) -> int:
	if not board_system or tile_index < 0:
		return -1
	
	var tile = board_system.get_tile_data(tile_index)
	if tile:
		return tile.get("owner", tile.get("owner_id", -1))
	return -1


## スペルが呪いスペルかどうか判定し、有利/不利を返す
## 戻り値: {"is_curse": bool, "is_beneficial": bool}
func analyze_curse_spell(spell_data: Dictionary) -> Dictionary:
	var result = {"is_curse": false, "is_beneficial": false}
	
	var effect_parsed = spell_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var curse_type = effect.get("curse_type", "")
		
		# 呪い関連のeffect_typeをチェック
		if effect_type in ["creature_curse", "player_curse", "apply_curse", 
						   "skill_nullify", "battle_disable", "plague_curse",
						   "toll_multiplier", "peace", "forced_stop",
						   "magic_barrier", "destroy_after_battle", "grant_mystic_arts"]:
			result.is_curse = true
			
			# curse_typeから有利/不利を判定
			if curse_type != "":
				if curse_type in CpuCurseEvaluator.BENEFICIAL_CREATURE_CURSES:
					result.is_beneficial = true
				elif curse_type in CpuCurseEvaluator.HARMFUL_CREATURE_CURSES:
					result.is_beneficial = false
			else:
				# effect_typeから推測
				if effect_type in ["grant_mystic_arts", "toll_multiplier", "forced_stop", "magic_barrier"]:
					result.is_beneficial = true
				elif effect_type in ["skill_nullify", "battle_disable", "plague_curse", 
									 "peace", "destroy_after_battle"]:
					result.is_beneficial = false
			
			break
	
	return result
