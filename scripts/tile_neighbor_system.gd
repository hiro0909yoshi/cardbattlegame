class_name TileNeighborSystem
extends Node

# タイル隣接判定システム
# 物理的な座標ベースでタイルの隣接関係を管理

# タイル情報の参照
var tile_nodes = {}

# 設定
const TILE_SIZE = 4.0
const NEIGHBOR_THRESHOLD = 4.5  # タイルサイズより少し大きめ

# キャッシュ
var spatial_neighbors_cache = {}

func _ready():
	pass

# 初期化（BoardSystem3Dから呼ばれる）
func setup(tiles: Dictionary):
	tile_nodes = tiles
	_build_spatial_neighbors_cache()

# 隣接情報を構築
func _build_spatial_neighbors_cache():
	spatial_neighbors_cache.clear()
	
	for tile_index in tile_nodes.keys():
		spatial_neighbors_cache[tile_index] = _calculate_spatial_neighbors(tile_index)


# 物理的隣接を計算（XZ平面での距離）
func _calculate_spatial_neighbors(tile_index: int) -> Array:
	if not tile_nodes.has(tile_index):
		return []
	
	var neighbors = []
	var my_pos = tile_nodes[tile_index].global_position
	
	for other_index in tile_nodes.keys():
		if other_index == tile_index:
			continue
		
		var other_pos = tile_nodes[other_index].global_position
		
		# XZ平面での距離（Y軸無視）
		var dx = abs(my_pos.x - other_pos.x)
		var dz = abs(my_pos.z - other_pos.z)
		var distance_xz = sqrt(dx * dx + dz * dz)
		
		if distance_xz < NEIGHBOR_THRESHOLD:
			neighbors.append(other_index)
	
	return neighbors

# 物理的に隣接するタイルを取得
func get_spatial_neighbors(tile_index: int) -> Array:
	return spatial_neighbors_cache.get(tile_index, [])

# すごろく的隣接（前後1マス）
func get_sequential_neighbors(tile_index: int) -> Array:
	var total = tile_nodes.size()
	if total == 0:
		return []
	
	var prev = (tile_index - 1 + total) % total
	var next = (tile_index + 1) % total
	return [prev, next]

# 隣接に指定プレイヤーの領地があるかチェック
func has_adjacent_ally_land(tile_index: int, player_id: int, board_system) -> bool:
	var neighbors = get_spatial_neighbors(tile_index)
	
	for neighbor_index in neighbors:
		var tile_info = board_system.get_tile_info(neighbor_index)
		var tile_owner = tile_info.get("owner", -1)
		
		if tile_owner == player_id:
			return true
	
	return false

# デバッグ: 隣接情報を出力
func debug_print_neighbors():
	print("\n=== タイル隣接情報 ===")
	var sorted_indices = tile_nodes.keys()
	sorted_indices.sort()
	
	for tile_index in sorted_indices:
		var neighbors = get_spatial_neighbors(tile_index)
		print("タイル%2d の隣接: %s" % [tile_index, neighbors])
