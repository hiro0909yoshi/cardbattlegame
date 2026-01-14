# チェックポイント距離計算システム
# マップロード時に各タイルから各チェックポイントへの最短距離を計算
# ワープも考慮したBFS（幅優先探索）で計算

extends RefCounted
class_name CheckpointDistanceCalculator

# 計算結果: { checkpoint_id: { tile_index: distance, ... }, ... }
# 例: { "N": { 0: 5, 1: 4, 2: 3, ... }, "S": { 0: 12, 1: 13, ... } }
var distances: Dictionary = {}

# 方向別距離: { branch_tile: { next_tile: { checkpoint_id: distance, ... }, ... }, ... }
# 例: { 2: { 3: { "N": 10, "W": 3 }, 24: { "N": 3, "W": 5 } }, ... }
var directional_distances: Dictionary = {}

# 分岐タイル一覧（connectionsが2つ以上のタイル）
var branch_tiles: Array = []

# チェックポイント情報: { checkpoint_id: tile_index, ... }
var checkpoints: Dictionary = {}

# システム参照
var tile_nodes: Dictionary = {}
var warp_pairs: Dictionary = {}

## 初期化
func setup(p_tile_nodes: Dictionary, p_warp_pairs: Dictionary = {}):
	tile_nodes = p_tile_nodes
	warp_pairs = p_warp_pairs


## 全チェックポイントへの距離を計算
func calculate_all_distances():
	distances.clear()
	checkpoints.clear()
	directional_distances.clear()
	branch_tiles.clear()
	
	# 1. チェックポイントを検出
	_find_all_checkpoints()
	
	if checkpoints.is_empty():
		return
	
	# 2. 分岐タイルを検出
	_find_branch_tiles()
	
	# 3. 各チェックポイントからBFSで距離計算
	for cp_id in checkpoints:
		var cp_tile = checkpoints[cp_id]
		distances[cp_id] = _bfs_from_checkpoint(cp_tile)
	
	# 4. 方向別距離を計算
	_calculate_directional_distances()


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


## 分岐タイルから特定方向に進んだ場合の、最も近い未訪問チェックポイントを取得
## branch_tile: 分岐タイルのインデックス
## next_tile: 進む方向の次のタイル
## visited_checkpoints: 訪問済みチェックポイントIDの配列
## 戻り値: { "checkpoint_id": String, "distance": int }
func get_directional_nearest_checkpoint(branch_tile: int, next_tile: int, visited_checkpoints: Array) -> Dictionary:
	var best_cp = ""
	var best_distance = 9999
	
	# 方向別距離データがあれば使用
	if directional_distances.has(branch_tile) and directional_distances[branch_tile].has(next_tile):
		var dir_dist = directional_distances[branch_tile][next_tile]
		for cp_id in dir_dist:
			if cp_id in visited_checkpoints:
				continue
			var dist = dir_dist[cp_id]
			if dist < best_distance:
				best_distance = dist
				best_cp = cp_id
	else:
		# フォールバック: 次のタイルからの通常距離を使用
		return get_nearest_unvisited_checkpoint(next_tile, visited_checkpoints)
	
	return { "checkpoint_id": best_cp, "distance": best_distance }


## 分岐タイルから特定方向に進んだ場合の、特定チェックポイントへの距離を取得
func get_directional_distance(branch_tile: int, next_tile: int, checkpoint_id: String) -> int:
	if directional_distances.has(branch_tile) and directional_distances[branch_tile].has(next_tile):
		if directional_distances[branch_tile][next_tile].has(checkpoint_id):
			return directional_distances[branch_tile][next_tile][checkpoint_id]
	# フォールバック
	return get_distance(next_tile, checkpoint_id)


## タイルが分岐タイルかどうか
func is_branch_tile(tile_index: int) -> bool:
	return tile_index in branch_tiles


## 分岐タイルの方向別距離テーブルを取得
func get_branch_directional_distances(branch_tile: int) -> Dictionary:
	if directional_distances.has(branch_tile):
		return directional_distances[branch_tile]
	return {}


## 全チェックポイントIDを取得
func get_all_checkpoint_ids() -> Array:
	return checkpoints.keys()


## チェックポイントのタイルインデックスを取得
func get_checkpoint_tile(checkpoint_id: String) -> int:
	return checkpoints.get(checkpoint_id, -1)


# =============================================================================
# 内部メソッド
# =============================================================================

## 分岐タイル（connectionsが2つ以上）を検出
func _find_branch_tiles():
	branch_tiles.clear()
	for tile_index in tile_nodes:
		var tile = tile_nodes[tile_index]
		if not tile:
			continue
		if tile.connections and tile.connections.size() >= 2:
			branch_tiles.append(tile_index)


## 方向別距離を計算
## 各分岐タイルから各方向に1歩進んだ後、そこから各CPへの距離を計算
## ただし、分岐タイルを経由しないパス限定で計算
func _calculate_directional_distances():
	directional_distances.clear()
	
	for branch_tile in branch_tiles:
		directional_distances[branch_tile] = {}
		
		var tile = tile_nodes[branch_tile]
		if not tile or not tile.connections:
			continue
		
		# 分岐タイルがCPかどうか確認
		var branch_cp_id = ""
		for cp_id in checkpoints:
			if checkpoints[cp_id] == branch_tile:
				branch_cp_id = cp_id
				break
		
		# 各方向について
		for next_tile in tile.connections:
			if next_tile < 0:
				continue
			
			# この方向に進んだ場合の各CPへの距離を計算
			# BFSで計算するが、分岐タイルを除外して探索
			var dir_distances = _bfs_directional(next_tile, branch_tile)
			
			# 分岐タイル自体がCPの場合、その方向に進むと戻らないと到達できない
			# →その方向からは距離を大きくする（実質的に除外）
			if branch_cp_id != "":
				# 分岐タイル自体のCPへの距離は、この方向からは非常に遠い
				dir_distances[branch_cp_id] = 9999
			
			directional_distances[branch_tile][next_tile] = dir_distances


## 特定方向に進んだ場合のBFS（分岐タイルを除外）
## start_tile: 進む方向の最初のタイル
## excluded_tile: 除外するタイル（元の分岐タイル）
## 戻り値: { checkpoint_id: distance, ... }
func _bfs_directional(start_tile: int, excluded_tile: int) -> Dictionary:
	var result: Dictionary = {}
	var queue: Array = []
	var visited: Dictionary = {}
	
	# 除外タイルを最初から訪問済みとしてマーク
	visited[excluded_tile] = true
	
	# 開始タイル
	queue.append({ "tile": start_tile, "distance": 1 })  # 分岐から1歩進んでいる
	visited[start_tile] = true
	
	# 開始タイルがCPか確認
	for cp_id in checkpoints:
		if checkpoints[cp_id] == start_tile:
			result[cp_id] = 1
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_tile = current.tile
		var current_distance = current.distance
		
		# 隣接タイルを取得
		var neighbors = _get_neighbors_with_cost(current_tile)
		
		for neighbor_info in neighbors:
			var neighbor = neighbor_info.tile
			var cost = neighbor_info.cost
			
			if visited.has(neighbor):
				continue
			
			visited[neighbor] = true
			var new_distance = current_distance + cost
			
			# このタイルがCPか確認
			for cp_id in checkpoints:
				if checkpoints[cp_id] == neighbor:
					if not result.has(cp_id) or new_distance < result[cp_id]:
						result[cp_id] = new_distance
			
			queue.append({ "tile": neighbor, "distance": new_distance })
	
	# 到達できなかったCPは9999を設定
	for cp_id in checkpoints:
		if not result.has(cp_id):
			result[cp_id] = 9999
	
	return result


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
