## CPU AI用 盤面分析クラス
## 盤面上のクリーチャー・土地情報を取得するヘルパー関数を提供
class_name CPUBoardAnalyzer
extends RefCounted

## システム参照
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var creature_manager: Node = null
var lap_system: Node = null
var game_flow_manager: Node = null

## 初期化
func initialize(b_system: Node, p_system: Node, c_system: Node, cr_manager: Node, l_system: Node = null, gf_manager: Node = null) -> void:
	board_system = b_system
	player_system = p_system
	card_system = c_system
	creature_manager = cr_manager
	lap_system = l_system
	game_flow_manager = gf_manager

# =============================================================================
# 自クリーチャー取得
# =============================================================================

## 自分のクリーチャーを取得
func get_own_creatures(player_id: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and tile.get("owner", tile.get("owner_id", -1)) == player_id:
			results.append(creature)
	
	return results

## 自クリーチャーがいるタイル情報を取得
func get_own_creatures_on_board(player_id: int) -> Array:
	var results = []
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature.is_empty():
			continue
		
		results.append({
			"tile_index": tile.get("index", -1),
			"creature": creature,
			"element": tile.get("element", ""),
			"level": tile.get("level", 1)
		})
	
	return results

# =============================================================================
# 敵クリーチャー取得
# =============================================================================

## 敵クリーチャーのいるタイルを取得
func get_enemy_creature_tiles(player_id: int) -> Array:
	var results = []
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature.is_empty():
			continue
		
		results.append({
			"tile_index": tile.get("index", -1),
			"creature": creature,
			"element": tile.get("element", ""),
			"level": tile.get("level", 1),
			"owner": owner_id
		})
	
	return results

# =============================================================================
# 土地取得
# =============================================================================

## 属性不一致の自ドミニオを取得
func get_mismatched_own_lands(player_id: int) -> Array:
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
func get_enemy_lands_by_level(player_id: int, min_level: int) -> Array:
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

## 指定レベルの自ドミニオを取得
func get_own_lands_by_level(player_id: int, target_level: int) -> Array:
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

## 空き地（クリーチャーのいない土地）を取得
func get_empty_lands() -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature and not creature.is_empty():
			continue
		
		# 属性がある土地のみ（特殊タイルは除外）
		# tile_typeが空の場合はelementで判定
		var element = tile.get("element", "")
		var tile_type = tile.get("tile_type", "")
		var is_land = false
		
		if tile_type != "":
			is_land = TileHelper.has_land_effect_type(tile_type)
		else:
			# elementで判定：属性タイル(fire/water/earth/wind)またはneutral
			is_land = element in ["fire", "water", "earth", "wind", "neutral"]
		
		if not is_land:
			continue
		
		results.append({
			"tile_index": tile.get("index", -1),
			"element": element,
			"level": tile.get("level", 1)
		})
	
	return results

## 地形ボーナスを持つ敵クリーチャーを取得
func get_enemies_with_land_bonus(player_id: int) -> Array:
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
func get_own_without_land_bonus(player_id: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
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
# クリーチャー状態チェック
# =============================================================================

## クリーチャーが呪いを持っているか
func has_curse(creature: Dictionary) -> bool:
	var ability = creature.get("ability_parsed", {})
	if ability.get("curses", []).size() > 0:
		return true
	return false

## ダウン中の自クリーチャーがいるか
func has_downed_creature(player_id: int) -> bool:
	if not board_system:
		return false
	
	var tiles = board_system.get_all_tiles()
	for tile_info in tiles:
		var owner_id = tile_info.get("owner", -1)
		if owner_id != player_id:
			continue
		
		var creature = tile_info.get("creature", {})
		if creature.is_empty():
			continue
		
		# タイルノードから直接down状態を確認
		var tile_index = tile_info.get("index", -1)
		if tile_index >= 0 and board_system.tile_nodes.has(tile_index):
			var tile = board_system.tile_nodes[tile_index]
			if tile.has_method("is_down") and tile.is_down():
				return true
	return false

## 自クリーチャーがダメージを受けているか
func has_damaged_creature(player_id: int) -> bool:
	var creatures = get_own_creatures(player_id)
	for creature_data in creatures:
		var current_hp = creature_data.get("current_hp", 0)
		var max_hp = creature_data.get("max_hp", 0)
		if current_hp < max_hp:
			return true
	return false

## 呪い付きクリーチャーがいるか（自分の）
func has_cursed_creature(player_id: int) -> bool:
	var creatures = get_own_creatures(player_id)
	for creature_data in creatures:
		if has_curse(creature_data):
			return true
	return false

# =============================================================================
# プレイヤー・位置関連
# =============================================================================

## プレイヤーの現在位置を取得
func get_player_current_tile(player_id: int) -> int:
	if board_system and "movement_controller" in board_system and board_system.movement_controller:
		return board_system.movement_controller.get_player_tile(player_id)
	if player_system and player_system.has_method("get_player_position"):
		return player_system.get_player_position(player_id)
	return 0

## タイル間の距離を計算（簡易版・BFS）
func calculate_tile_distance(from_tile: int, to_tile: int) -> int:
	if from_tile == to_tile:
		return 0
	
	if not board_system or not "tile_neighbor_system" in board_system:
		return abs(to_tile - from_tile)
	
	var neighbor_system = board_system.tile_neighbor_system
	if not neighbor_system or not neighbor_system.has_method("get_sequential_neighbors"):
		return abs(to_tile - from_tile)
	
	# BFS
	var visited = {}
	var queue = [[from_tile, 0]]
	visited[from_tile] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var tile = current[0]
		var dist = current[1]
		
		if dist > 30:
			break
		
		var neighbors = neighbor_system.get_sequential_neighbors(tile)
		for neighbor in neighbors:
			if neighbor == to_tile:
				return dist + 1
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
	
	return abs(to_tile - from_tile)

## 最寄りチェックポイントを探す
func find_nearest_checkpoint(from_tile: int) -> Dictionary:
	if not board_system or not "tile_nodes" in board_system:
		return {"tile_index": -1, "checkpoint_type": ""}
	
	var tiles = board_system.tile_nodes
	var nearest_tile = -1
	var nearest_distance = 999999
	var nearest_type = ""
	
	for tile_index in tiles.keys():
		var tile = tiles[tile_index]
		if tile and tile.tile_type == "checkpoint":
			var dist = calculate_tile_distance(from_tile, tile_index)
			if dist < nearest_distance:
				nearest_distance = dist
				nearest_tile = tile_index
				nearest_type = tile.get_checkpoint_type_string() if tile.has_method("get_checkpoint_type_string") else "N"
	
	return {"tile_index": nearest_tile, "checkpoint_type": nearest_type}

# =============================================================================
# 到達可能タイル探索
# =============================================================================

## 指定歩数で到達可能な敵タイルを取得
func get_reachable_enemy_tiles(from_tile: int, player_id: int, steps: int, exact_steps: bool) -> Array:
	var results = []
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var tile_index = tile.get("index", -1)
		if tile_index < 0:
			continue
		
		# 敵の土地かチェック
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		# クリーチャーがいるかチェック
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature.is_empty():
			continue
		
		# 距離計算
		var distance = calculate_tile_distance(from_tile, tile_index)
		
		# 到達可能かチェック
		var reachable = false
		if exact_steps:
			reachable = (distance == steps)
		else:
			reachable = (distance <= steps)
		
		if reachable:
			results.append({
				"tile_index": tile_index,
				"creature": creature,
				"element": tile.get("element", ""),
				"level": tile.get("level", 1),
				"distance": distance
			})
	
	return results
