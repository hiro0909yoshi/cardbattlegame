# チェックポイント距離計算システム
# マップロード時に各タイルから各チェックポイントへの最短距離を計算
# ワープも考慮したBFS（幅優先探索）で計算

extends RefCounted
class_name CheckpointDistanceCalculator

# 計算結果: { checkpoint_id: { tile_index: distance, ... }, ... }
# 例: { "N": { 0: 5, 1: 4, 2: 3, ... }, "S": { 0: 12, 1: 13, ... } }
var distances: Dictionary = {}

# チェックポイント情報: { checkpoint_id: tile_index, ... }
var checkpoints: Dictionary = {}

# システム参照
var tile_nodes: Dictionary = {}
var warp_pairs: Dictionary = {}

## 初期化
func setup(p_tile_nodes: Dictionary, p_warp_pairs: Dictionary = {}):
	tile_nodes = p_tile_nodes
	warp_pairs = p_warp_pairs
	print("[CheckpointDistance] setup: tiles=%d, warps=%d" % [tile_nodes.size(), warp_pairs.size()])


## 全チェックポイントへの距離を計算
func calculate_all_distances():
	distances.clear()
	checkpoints.clear()
	
	# 1. チェックポイントを検出
	_find_all_checkpoints()
	print("[CheckpointDistance] チェックポイント検出: %d個" % checkpoints.size())
	for cp_id in checkpoints:
		print("[CheckpointDistance]   %s: タイル%d" % [cp_id, checkpoints[cp_id]])
	
	if checkpoints.is_empty():
		print("[CheckpointDistance] 警告: チェックポイントが見つかりません")
		return
	
	# 2. 各チェックポイントからBFSで距離計算
	for cp_id in checkpoints:
		var cp_tile = checkpoints[cp_id]
		distances[cp_id] = _bfs_from_checkpoint(cp_tile)
		print("[CheckpointDistance] %s: 計算完了（%d タイル）" % [cp_id, distances[cp_id].size()])


## 特定タイルから特定チェックポイントへの距離を取得
func get_distance(tile_index: int, checkpoint_id: String) -> int:
	if not distances.has(checkpoint_id):
		return 9999
	if not distances[checkpoint_id].has(tile_index):
		return 9999
	return distances[checkpoint_id][tile_index]


## 特定タイルから最も近い未訪問チェックポイントを取得
## visited_checkpoints: 訪問済みチェックポイントIDの配列 ["N", "S"] など
## 戻り値: { "checkpoint_id": String, "distance": int }
func get_nearest_unvisited_checkpoint(tile_index: int, visited_checkpoints: Array) -> Dictionary:
	var best_cp = ""
	var best_distance = 9999
	
	for cp_id in checkpoints:
		if cp_id in visited_checkpoints:
			continue  # 訪問済みはスキップ
		
		var dist = get_distance(tile_index, cp_id)
		if dist < best_distance:
			best_distance = dist
			best_cp = cp_id
	
	return { "checkpoint_id": best_cp, "distance": best_distance }


## 全チェックポイントIDを取得
func get_all_checkpoint_ids() -> Array:
	return checkpoints.keys()


## チェックポイントのタイルインデックスを取得
func get_checkpoint_tile(checkpoint_id: String) -> int:
	return checkpoints.get(checkpoint_id, -1)


# =============================================================================
# 内部メソッド
# =============================================================================

## マップからチェックポイントを検出
func _find_all_checkpoints():
	for tile_index in tile_nodes:
		var tile = tile_nodes[tile_index]
		if not tile:
			continue
		
		var tile_type = tile.tile_type if "tile_type" in tile else ""
		if tile_type in ["checkpoint", "gate"]:
			# チェックポイントIDを決定
			var cp_id = _get_checkpoint_id(tile, tile_index)
			checkpoints[cp_id] = tile_index


## チェックポイントIDを取得（タイルの属性から）
func _get_checkpoint_id(tile, _tile_index: int) -> String:
	var number = 0
	
	# checkpoint_type があればそれを使用
	if "checkpoint_type" in tile and tile.checkpoint_type != null:
		var cp_type = tile.checkpoint_type
		# 文字列で有効な値があればそれを返す
		if typeof(cp_type) == TYPE_STRING and cp_type != "":
			return cp_type
		# 整数なら番号として扱う
		elif typeof(cp_type) == TYPE_INT:
			number = cp_type
	
	# gate_number または checkpoint_number から推測
	if number == 0:
		if "gate_number" in tile and tile.gate_number != null:
			number = int(tile.gate_number)
		elif "checkpoint_number" in tile and tile.checkpoint_number != null:
			number = int(tile.checkpoint_number)
	
	# 番号からIDを生成（0=N, 1=S, 2=E, 3=W, ...）
	match number:
		0: return "N"
		1: return "S"
		2: return "E"
		3: return "W"
		_: return "CP%d" % number


## チェックポイントからBFSで全タイルへの距離を計算
func _bfs_from_checkpoint(start_tile: int) -> Dictionary:
	var result: Dictionary = {}
	var queue: Array = []
	var visited: Dictionary = {}
	
	# 開始タイル
	queue.append({ "tile": start_tile, "distance": 0 })
	visited[start_tile] = true
	result[start_tile] = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_tile = current.tile
		var current_distance = current.distance
		
		# 隣接タイルを取得（ワープ情報付き）
		var neighbors = _get_neighbors_with_cost(current_tile)
		
		for neighbor_info in neighbors:
			var neighbor = neighbor_info.tile
			var cost = neighbor_info.cost
			
			if visited.has(neighbor):
				continue
			
			visited[neighbor] = true
			var new_distance = current_distance + cost
			result[neighbor] = new_distance
			queue.append({ "tile": neighbor, "distance": new_distance })
	
	return result


## タイルの隣接タイル（ワープ含む、コスト付き）を取得
## 戻り値: [{ tile: int, cost: int }, ...]
## 
## 通過型ワープの扱い:
##   タイル28から見ると、隣接の29は通過型ワープなので、
##   29を「スキップ」してワープ先(30)の先のタイル(31)を直接隣接として扱う
##   つまり28→31が1歩
func _get_neighbors_with_cost(tile_index: int) -> Array:
	var neighbors: Array = []
	
	if not tile_nodes.has(tile_index):
		return neighbors
	
	var tile = tile_nodes[tile_index]
	var tile_type = tile.tile_type if "tile_type" in tile else ""
	
	# このタイル自体が通過型ワープかチェック
	var is_warp_tile = warp_pairs.has(tile_index)
	var is_pass_through_warp = is_warp_tile and tile_type == "warp"
	
	# 基本的な隣接を取得
	var basic_neighbors = _get_basic_neighbors(tile_index)
	
	for basic_n in basic_neighbors:
		# 隣接先が通過型ワープかチェック
		var neighbor_is_warp = warp_pairs.has(basic_n)
		var neighbor_tile_type = ""
		if tile_nodes.has(basic_n):
			var n_tile = tile_nodes[basic_n]
			neighbor_tile_type = n_tile.tile_type if "tile_type" in n_tile else ""
		var neighbor_is_pass_through = neighbor_is_warp and neighbor_tile_type == "warp"
		
		if neighbor_is_pass_through:
			# 隣接先が通過型ワープ → ワープ先の先を隣接として追加
			var warp_dest = warp_pairs.get(basic_n, -1)
			if warp_dest >= 0:
				# ワープ先の隣接（元のタイルを除く）を追加
				var warp_dest_neighbors = _get_basic_neighbors(warp_dest)
				for wdn in warp_dest_neighbors:
					if wdn != basic_n:  # ワープ元は除く
						# 重複チェック
						var already = false
						for ex in neighbors:
							if ex.tile == wdn:
								already = true
								break
						if not already:
							neighbors.append({ "tile": wdn, "cost": 1 })
		else:
			# 通常の隣接
			neighbors.append({ "tile": basic_n, "cost": 1 })
	
	# このタイル自体が通過型ワープの場合の追加処理
	if is_pass_through_warp:
		var warp_dest = warp_pairs.get(tile_index, -1)
		if warp_dest >= 0:
			# ワープ先の隣接も自分の隣接として追加（コスト0、同じ場所扱い）
			var dest_neighbors = _get_basic_neighbors(warp_dest)
			for dn in dest_neighbors:
				if dn != tile_index:
					var already = false
					for ex in neighbors:
						if ex.tile == dn:
							already = true
							break
					if not already:
						neighbors.append({ "tile": dn, "cost": 0 })
	
	return neighbors


## 基本的な隣接タイル（ワープ考慮なし）を取得
func _get_basic_neighbors(tile_index: int) -> Array:
	var neighbors: Array = []
	
	if not tile_nodes.has(tile_index):
		# tile_nodesにない場合でも、前後を返す
		if tile_nodes.has(tile_index - 1):
			neighbors.append(tile_index - 1)
		if tile_nodes.has(tile_index + 1):
			neighbors.append(tile_index + 1)
		return neighbors
	
	var tile = tile_nodes[tile_index]
	
	if tile.connections and not tile.connections.is_empty():
		for conn in tile.connections:
			if conn >= 0:
				neighbors.append(conn)
	else:
		# connectionsがない場合、前後のタイルを追加
		# ただしワープ先がある場合はそれも考慮
		if tile_nodes.has(tile_index - 1):
			neighbors.append(tile_index - 1)
		if tile_nodes.has(tile_index + 1):
			neighbors.append(tile_index + 1)
	
	return neighbors


## タイルの隣接タイル（ワープ含む）を取得（後方互換用）
func _get_neighbors(tile_index: int) -> Array:
	var neighbors: Array = []
	
	if not tile_nodes.has(tile_index):
		return neighbors
	
	var tile = tile_nodes[tile_index]
	
	# 1. connections から取得
	if tile.connections and not tile.connections.is_empty():
		for conn in tile.connections:
			if conn >= 0 and not conn in neighbors:
				neighbors.append(conn)
	else:
		# connections がない場合、前後のタイルを追加
		if tile_nodes.has(tile_index - 1):
			neighbors.append(tile_index - 1)
		if tile_nodes.has(tile_index + 1):
			neighbors.append(tile_index + 1)
	
	# 2. ワープ先を追加
	if warp_pairs.has(tile_index):
		var warp_dest = warp_pairs[tile_index]
		if warp_dest >= 0 and not warp_dest in neighbors:
			neighbors.append(warp_dest)
	
	return neighbors


## デバッグ: 距離テーブルを出力
func debug_print_distances():
	print("===== チェックポイント距離テーブル =====")
	for cp_id in distances:
		print("--- %s (タイル%d) ---" % [cp_id, checkpoints.get(cp_id, -1)])
		var dist_list = distances[cp_id]
		var sorted_tiles = dist_list.keys()
		sorted_tiles.sort()
		for tile_index in sorted_tiles:
			print("  タイル%d: %d歩" % [tile_index, dist_list[tile_index]])
