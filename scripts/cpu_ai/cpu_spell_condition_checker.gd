## CPU スペル/ミスティックアーツ 条件チェッカー
## 各条件の判定ロジックを集約
class_name CPUSpellConditionChecker
extends RefCounted

## 参照
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var creature_manager: Node = null

## 初期化
func initialize(b_system: Node, p_system: Node, c_system: Node, cr_manager: Node) -> void:
	board_system = b_system
	player_system = p_system
	card_system = c_system
	creature_manager = cr_manager

# =============================================================================
# メイン条件チェック（condition フィールド用）
# =============================================================================

## 条件をチェック
func check_condition(condition: String, context: Dictionary) -> bool:
	match condition:
		# 属性関連
		"element_mismatch":
			return _check_element_mismatch(context)
		
		# 敵土地関連
		"enemy_high_level":
			return _check_enemy_high_level(context)
		"enemy_level_4":
			return _check_enemy_level_4(context)
		
		# 移動・侵略関連
		"move_invasion_win":
			return _check_move_invasion_win(context)
		
		# 自クリーチャー状態
		"has_downed_creature":
			return _check_has_downed_creature(context)
		"self_creature_damaged":
			return _check_self_creature_damaged(context)
		"has_cursed_creature":
			return _check_has_cursed_creature(context)
		
		# 盤面状態
		"duplicate_creatures":
			return _check_duplicate_creatures(context)
		"has_vacant_land":
			return _check_has_vacant_land(context)
		"has_empty_land":
			return _check_has_empty_land(context)
		
		# 手札関連
		"has_all_elements_in_hand":
			return _check_has_all_elements_in_hand(context)
		"low_hand_quality":
			return _check_low_hand_quality(context)
		"has_curse_cards_in_hand":
			return _check_has_curse_cards_in_hand(context)
		"has_expensive_cards":
			return _check_has_expensive_cards(context)
		
		# 土地条件
		"has_4_mismatched_lands":
			return _check_has_4_mismatched_lands(context)
		"has_5_level2_lands":
			return _check_has_5_level2_lands(context)
		"has_4_consecutive_lands":
			return _check_has_4_consecutive_lands(context)
		
		# 呪い関連
		"has_any_curse":
			return _check_has_any_curse(context)
		"has_bad_world_curse":
			return _check_has_bad_world_curse(context)
		"has_player_curse":
			return _check_has_player_curse(context)
		
		# その他
		"has_5_low_mhp_creatures":
			return _check_has_5_low_mhp_creatures(context)
		"has_priority_swap_target":
			return _check_has_priority_swap_target(context)
		"deck_nearly_empty":
			return _check_deck_nearly_empty(context)
		"has_unvisited_gate":
			return _check_has_unvisited_gate(context)
		"self_lowest_magic":
			return _check_self_lowest_magic(context)
		"transform_beneficial":
			return _check_transform_beneficial(context)
		
		_:
			push_warning("CPUSpellConditionChecker: Unknown condition: " + condition)
			return false

# =============================================================================
# ターゲット条件チェック（target_condition フィールド用）
# =============================================================================

## ターゲット条件をチェックし、有効なターゲットを返す
func check_target_condition(target_condition: String, context: Dictionary) -> Array:
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
		"element_mismatch_creatures":
			return _get_element_mismatch_creatures(context)
		"element_mismatch_creature":
			return _get_element_mismatch_creatures(context)
		"cursed_creatures":
			return _get_cursed_creatures(context)
		"hp_reduced":
			return _get_hp_reduced_creatures(context)
		"low_mhp_creatures":
			return _get_low_mhp_creatures(context)
		"downed_high_mhp":
			return _get_downed_high_mhp_creatures(context)
		
		# 特殊条件
		"can_kill_target":
			return _get_killable_targets(context)
		"most_common_element":
			return _get_most_common_element_creatures(context)
		"has_summon_condition":
			return _get_creatures_with_summon_condition(context)
		"no_curse_no_mystic":
			return _get_creatures_without_curse_or_mystic(context)
		"has_mystic_arts":
			return _get_creatures_with_mystic_arts(context)
		
		# プレイヤー条件
		"enemy_has_2_items":
			return _get_enemies_with_items(2, context)
		"enemy_has_high_toll":
			return _get_enemies_with_high_toll(context)
		"enemy_has_more_magic":
			return _get_enemies_with_more_magic(context)
		
		# 土地条件
		"enemy_has_land_bonus":
			return _get_enemies_with_land_bonus(context)
		"own_no_land_bonus":
			return _get_own_without_land_bonus(context)
		
		_:
			push_warning("CPUSpellConditionChecker: Unknown target_condition: " + target_condition)
			return []

# =============================================================================
# 条件チェック実装（condition）
# =============================================================================

## 属性不一致チェック：配置クリーチャーと土地の属性が違う自領地があるか
func _check_element_mismatch(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var mismatched = _get_mismatched_own_lands(player_id)
	return mismatched.size() > 0

## 敵の高レベル土地チェック：レベル3以上
func _check_enemy_high_level(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var enemy_lands = _get_enemy_lands_by_level(player_id, 3)
	return enemy_lands.size() > 0

## 敵のレベル4土地チェック
func _check_enemy_level_4(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var enemy_lands = _get_enemy_lands_by_level(player_id, 4)
	return enemy_lands.size() > 0

## 移動侵略で勝てるかチェック
func _check_move_invasion_win(context: Dictionary) -> bool:
	# TODO: BattleSimulatorと連携して判定
	# 現時点では簡易実装
	return false

## ダウン中の自クリーチャーがいるか
func _check_has_downed_creature(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var creatures = _get_own_creatures(player_id)
	for creature_data in creatures:
		if creature_data.get("is_down", false):
			return true
	return false

## 自クリーチャーがダメージを受けているか
func _check_self_creature_damaged(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var creatures = _get_own_creatures(player_id)
	for creature_data in creatures:
		var current_hp = creature_data.get("current_hp", 0)
		var max_hp = creature_data.get("max_hp", 0)
		if current_hp < max_hp:
			return true
	return false

## 呪い付きクリーチャーがいるか（自分の）
func _check_has_cursed_creature(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var creatures = _get_own_creatures(player_id)
	for creature_data in creatures:
		if _has_curse(creature_data):
			return true
	return false

## 同じクリーチャーが2体以上配置されているか
func _check_duplicate_creatures(context: Dictionary) -> bool:
	if not board_system:
		return false
	
	var creature_counts = {}
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature:
			var creature_id = creature.get("id", 0)
			creature_counts[creature_id] = creature_counts.get(creature_id, 0) + 1
	
	for count in creature_counts.values():
		if count >= 2:
			return true
	return false

## 空地があるか（ボード上）
func _check_has_vacant_land(context: Dictionary) -> bool:
	if not board_system:
		return false
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		if tile.get("tile_type") == "normal" and not tile.get("creature", tile.get("placed_creature", {})):
			return true
	return false

## プレイヤーが空地に止まっているか
func _check_has_empty_land(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not player_system or not board_system:
		return false
	
	var player_pos = player_system.get_player_position(player_id)
	var tile = board_system.get_tile_data(player_pos)
	
	if tile and tile.get("tile_type") == "normal":
		return not tile.get("creature", tile.get("placed_creature", {}))
	return false

## 手札に全属性があるか
func _check_has_all_elements_in_hand(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not card_system:
		return false
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var elements_found = {"fire": false, "water": false, "wind": false, "earth": false}
	
	for card in hand:
		var element = card.get("element", "")
		if element in elements_found:
			elements_found[element] = true
	
	return elements_found["fire"] and elements_found["water"] and elements_found["wind"] and elements_found["earth"]

## 手札の質が低いか
func _check_low_hand_quality(context: Dictionary) -> bool:
	# TODO: 手札の質を評価するロジック
	return false

## 手札に呪いカードがあるか
func _check_has_curse_cards_in_hand(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not card_system:
		return false
	
	var hand = card_system.get_all_cards_for_player(player_id)
	for card in hand:
		if card.get("is_curse", false):
			return true
	return false

## 高コストカードがあるか（G100以上）
func _check_has_expensive_cards(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not card_system:
		return false
	
	var hand = card_system.get_all_cards_for_player(player_id)
	for card in hand:
		var cost = card.get("cost", {}).get("mp", 0)
		if cost >= 100:
			return true
	return false

## 属性不一致の土地が4つあるか
func _check_has_4_mismatched_lands(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var mismatched = _get_mismatched_own_lands(player_id)
	return mismatched.size() >= 4

## レベル2の土地が5つあるか
func _check_has_5_level2_lands(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var level2_lands = _get_own_lands_by_level(player_id, 2)
	return level2_lands.size() >= 5

## 4連続の土地があるか
func _check_has_4_consecutive_lands(context: Dictionary) -> bool:
	# TODO: 連続判定ロジック
	return false

## 何らかの呪いがあるか
func _check_has_any_curse(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	
	# クリーチャー呪いチェック
	if _check_has_cursed_creature(context):
		return true
	
	# プレイヤー呪いチェック
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		var player = player_system.players[player_id]
		if player and player.curses.size() > 0:
			return true
	
	return false

## 不利な世界呪いがあるか
func _check_has_bad_world_curse(context: Dictionary) -> bool:
	# TODO: 世界呪いの有利/不利判定
	return false

## プレイヤー呪いがあるか
func _check_has_player_curse(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not player_system:
		return false
	
	if player_id < 0 or player_id >= player_system.players.size():
		return false
	
	var player = player_system.players[player_id]
	return player and player.curses.size() > 0

## MHP30以下のクリーチャーが5体あるか
func _check_has_5_low_mhp_creatures(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var count = 0
	var creatures = _get_own_creatures(player_id)
	
	for creature_data in creatures:
		var max_hp = creature_data.get("max_hp", 0)
		if max_hp <= 30:
			count += 1
	
	return count >= 5

## 交換優先度の高いクリーチャーがいるか
func _check_has_priority_swap_target(context: Dictionary) -> bool:
	# TODO: 優先度判定ロジック
	return false

## デッキがほぼ空か
func _check_deck_nearly_empty(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not card_system:
		return false
	
	var deck_count = card_system.get_deck_count(player_id)
	return deck_count <= 5

## 未訪問ゲートがあるか
func _check_has_unvisited_gate(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not player_system:
		return false
	
	if player_id < 0 or player_id >= player_system.players.size():
		return false
	
	var player = player_system.players[player_id]
	if not player:
		return false
	
	var visited_gates = player.visited_gates if "visited_gates" in player else []
	var total_gates = 4  # TODO: マップから取得
	return visited_gates.size() < total_gates

## 自分が最下位魔力か
func _check_self_lowest_magic(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not player_system:
		return false
	
	var my_magic = player_system.get_magic(player_id)
	var player_count = player_system.players.size()
	
	for i in range(player_count):
		if i != player_id:
			var other_magic = player_system.get_magic(i)
			if other_magic < my_magic:
				return false
	
	return true

## 変身が有利か
func _check_transform_beneficial(context: Dictionary) -> bool:
	# TODO: 変身先との比較ロジック
	return false

# =============================================================================
# ターゲット条件実装（target_condition）
# =============================================================================

## 指定属性のクリーチャーを取得
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
		if not creature:
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_filter == "enemy" and owner_id == player_id:
			continue
		if owner_filter == "own" and owner_id != player_id:
			continue
		
		results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 属性不一致のクリーチャーを取得
func _get_element_mismatch_creatures(context: Dictionary) -> Array:
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

## 呪い付きクリーチャーを取得
func _get_cursed_creatures(context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and _has_curse(creature):
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## HP減少中のクリーチャーを取得
func _get_hp_reduced_creatures(context: Dictionary) -> Array:
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

## MHP30以下のクリーチャーを取得
func _get_low_mhp_creatures(context: Dictionary) -> Array:
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

## ダウン中かつMHP50以上のクリーチャーを取得
func _get_downed_high_mhp_creatures(context: Dictionary) -> Array:
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

## 倒せるターゲットを取得
func _get_killable_targets(context: Dictionary) -> Array:
	var damage = context.get("damage_value", 0)
	var player_id = context.get("player_id", 0)
	var results = []
	
	print("[_get_killable_targets] damage=%d, player_id=%d" % [damage, player_id])
	
	if not board_system:
		print("[_get_killable_targets] board_systemがない")
		return results
	
	var tiles = board_system.get_all_tiles()
	print("[_get_killable_targets] tiles数: %d" % tiles.size())
	
	for tile in tiles:
		# get_tile_infoは"creature"キーで返す
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		
		# 敵クリーチャーのみ対象
		if owner_id == player_id:
			continue
		
		# HPを取得（current_hpがなければhpを使用）
		var current_hp = creature.get("current_hp", creature.get("hp", 0))
		
		print("[_get_killable_targets] タイル%d: %s (HP=%d, owner=%d)" % [
			tile.get("index", -1), creature.get("name", "?"), current_hp, owner_id
		])
		
		if current_hp > 0 and current_hp <= damage:
			print("[_get_killable_targets] → 倒せる！")
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	print("[_get_killable_targets] 結果: %d体" % results.size())
	return results

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

## 呪いも秘術も持たないクリーチャーを取得
func _get_creatures_without_curse_or_mystic(context: Dictionary) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		if not _has_curse(creature) and not creature.get("mystic_arts"):
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 秘術持ちクリーチャーを取得
func _get_creatures_with_mystic_arts(context: Dictionary) -> Array:
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
			results.append({"player_id": i})
	
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
		var enemy_lands = _get_enemy_lands_by_level(player_id, 3)
		if enemy_lands.size() > 0:
			results.append({"player_id": i})
	
	return results

## 自分より魔力が多い敵を取得
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
			results.append({"player_id": i, "magic": other_magic})
	
	return results

## 地形ボーナスを持つ敵クリーチャーを取得
func _get_enemies_with_land_bonus(context: Dictionary) -> Array:
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
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		if tile_element == creature_element:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

## 地形ボーナスを持たない自クリーチャーを取得
func _get_own_without_land_bonus(context: Dictionary) -> Array:
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
		if owner_id != player_id:
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		if tile_element != creature_element:
			results.append({"tile_index": tile.get("index", -1), "creature": creature})
	
	return results

# =============================================================================
# ヘルパー関数
# =============================================================================

## 自分のクリーチャーを取得
func _get_own_creatures(player_id: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and tile.get("owner", tile.get("owner_id", -1)) == player_id:
			results.append(creature)
	
	return results

## 属性不一致の自領地を取得
func _get_mismatched_own_lands(player_id: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		if tile.get("owner", tile.get("owner_id", -1)) != player_id:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		
		if tile_element != creature_element and tile_element != "neutral" and creature_element != "neutral":
			results.append(tile)
	
	return results

## 指定レベル以上の敵土地を取得
func _get_enemy_lands_by_level(player_id: int, min_level: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var level = tile.get("level", 1)
		if level >= min_level:
			results.append(tile)
	
	return results

## 指定レベルの自領地を取得
func _get_own_lands_by_level(player_id: int, target_level: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		if tile.get("owner", tile.get("owner_id", -1)) != player_id:
			continue
		
		var level = tile.get("level", 1)
		if level == target_level:
			results.append(tile)
	
	return results

## クリーチャーが呪いを持っているか
func _has_curse(creature: Dictionary) -> bool:
	var ability = creature.get("ability_parsed", {})
	if ability.get("curses", []).size() > 0:
		return true
	if creature.get("curse"):
		return true
	return false
