# MovementHelper - クリーチャー移動の共通処理
class_name MovementHelper

const TileHelper = preload("res://scripts/tile_helper.gd")

## 移動可能な土地のインデックス配列を返す
## 発動タイミングに関わらず、移動タイプに応じた候補を返す
static func get_move_destinations(
	board_system: Node,
	creature_data: Dictionary,
	from_tile_index: int,
	move_type_override: String = ""  # スペルなどで強制的に移動タイプを指定
) -> Array:
	
	# 移動不可呪いチェック
	if has_move_disable_curse(creature_data):
		print("[MovementHelper] 移動不可呪いにより移動できません")
		return []
	
	# 移動タイプの判定（オーバーライドがあればそれを優先）
	var move_type = move_type_override
	if move_type.is_empty():
		move_type = _detect_move_type(creature_data)
	
	
	match move_type:
		"vacant_move":
			# 空地移動スキル持ちでも通常の隣接移動もできる
			var elements = _get_vacant_move_elements(creature_data)
			var vacant_destinations = _get_vacant_tiles_by_elements(board_system, elements)
			
			# 隣接タイルも追加（通常移動）
			var adjacent_destinations = []
			if board_system.tile_neighbor_system:
				adjacent_destinations = board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
			
			# 重複を避けて結合
			var all_destinations = vacant_destinations.duplicate()
			for tile in adjacent_destinations:
				if not tile in all_destinations:
					all_destinations.append(tile)
			
			# フィルタリング適用
			var current_player_id = board_system.current_player_index
			all_destinations = _filter_invalid_destinations(board_system, all_destinations, current_player_id)
			
			return all_destinations
		"enemy_move":
			# 敵地移動スキル持ちでも通常の隣接移動もできる
			var enemy_destinations = []
			var condition = _get_enemy_move_condition(creature_data)
			enemy_destinations = _get_enemy_tiles_by_condition(board_system, condition, from_tile_index, creature_data)
			
			# 隣接タイルも追加（通常移動）
			var adjacent_destinations = []
			if board_system.tile_neighbor_system:
				adjacent_destinations = board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
			
			# 重複を避けて結合
			var all_destinations = enemy_destinations.duplicate()
			for tile in adjacent_destinations:
				if not tile in all_destinations:
					all_destinations.append(tile)
			
			# フィルタリング適用
			var current_player_id = board_system.current_player_index
			all_destinations = _filter_invalid_destinations(board_system, all_destinations, current_player_id)
			
			return all_destinations
		"adjacent":
			# TileNeighborSystemを使用
			if board_system.tile_neighbor_system:
				var adjacent_tiles = board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
				# フィルタリング適用
				var current_player_id = board_system.current_player_index
				adjacent_tiles = _filter_invalid_destinations(board_system, adjacent_tiles, current_player_id)
				return adjacent_tiles
			return []
		"random_vacant":  # 戦闘後のアージェントキー用
			return _get_all_vacant_tiles(board_system)
		"one_tile":  # 1マス移動（クリーピングフレイム秘術、スペル用）
			return _get_tiles_within_steps(board_system, from_tile_index, 1)
		"two_tiles":  # 2マス移動（チャリオット、スレイプニール秘術用）
			return _get_tiles_within_steps(board_system, from_tile_index, 2)
		"adjacent_enemy":  # 隣接する敵領地のみ（アウトレイジ用）
			return _get_adjacent_enemy_tiles(board_system, from_tile_index)
		"remote_move":  # 遠隔移動呪い（全空き地 + 隣接タイル）
			var all_vacant = _get_all_vacant_tiles(board_system)
			# 隣接タイルも追加（通常移動）
			var adjacent_destinations = []
			if board_system.tile_neighbor_system:
				adjacent_destinations = board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
			# 重複を避けて結合
			for tile in adjacent_destinations:
				if not tile in all_vacant:
					all_vacant.append(tile)
			# フィルタリング適用
			var current_player_id = board_system.current_player_index
			all_vacant = _filter_invalid_destinations(board_system, all_vacant, current_player_id)
			return all_vacant
		_:
			return []


## 指定マス数以内の移動先を取得（BFS探索）
static func _get_tiles_within_steps(board_system: Node, from_tile_index: int, max_steps: int) -> Array:
	var destinations: Array = []
	
	if not board_system or not board_system.tile_neighbor_system:
		return destinations
	
	# BFSで指定マス数以内のタイルを探索
	var visited: Dictionary = {from_tile_index: 0}
	var queue: Array = [from_tile_index]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_distance = visited[current]
		
		if current_distance >= max_steps:
			continue
		
		var neighbors = board_system.tile_neighbor_system.get_spatial_neighbors(current)
		for neighbor in neighbors:
			if visited.has(neighbor):
				continue
			
			var tile = board_system.tile_nodes.get(neighbor)
			if not tile:
				continue
			
			# 配置不可タイルは移動不可（クリーチャー移動）
			if not TileHelper.is_placeable_tile(tile):
				continue
			
			visited[neighbor] = current_distance + 1
			queue.append(neighbor)
	
	# 移動元を除外して結果を返す
	for tile_index in visited.keys():
		if tile_index != from_tile_index:
			destinations.append(tile_index)
	
	return destinations


## 隣接する敵領地のみ取得（アウトレイジ用）
static func _get_adjacent_enemy_tiles(board_system: Node, from_tile_index: int) -> Array:
	var destinations: Array = []
	
	if not board_system:
		return destinations
	
	# 隣接タイルを取得
	var adjacent_tiles: Array = []
	if board_system.tile_neighbor_system:
		adjacent_tiles = board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
	
	# 敵領地のみフィルタ
	var current_player_id = board_system.current_player_index
	
	for tile_index in adjacent_tiles:
		var tile = board_system.tile_nodes.get(tile_index)
		if not tile:
			continue
		
		# 配置不可タイルは除外（クリーチャー移動）
		if not TileHelper.is_placeable_tile(tile):
			continue
		
		# 敵領地のみ（自領地や空地は除外）
		if tile.owner_id != -1 and tile.owner_id != current_player_id:
			destinations.append(tile_index)
	
	return destinations

## 移動不可呪いを持っているかチェック
static func has_move_disable_curse(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	var curse = creature_data.get("curse", {})
	if curse.is_empty():
		return false
	
	var curse_type = curse.get("curse_type", "")
	return curse_type == "move_disable"


## クリーチャーの移動タイプを判定
static func _detect_move_type(creature_data: Dictionary) -> String:
	if not creature_data:
		return "adjacent"
	
	# 遠隔移動呪いチェック（全空き地に移動可能）
	if has_remote_move_curse(creature_data):
		return "remote_move"
	
	var parsed = creature_data.get("ability_parsed", {})
	var keywords = parsed.get("keywords", [])
	var conditions = parsed.get("keyword_conditions", {})
	
	# 空地移動チェック
	if "空地移動" in keywords and conditions.has("空地移動"):
		return "vacant_move"
	
	# 敵地移動チェック
	if "敵領地移動" in keywords and conditions.has("敵領地移動"):
		return "enemy_move"
	
	# デフォルトは隣接移動
	return "adjacent"


## 遠隔移動呪いを持っているかチェック
static func has_remote_move_curse(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	var curse = creature_data.get("curse", {})
	if curse.is_empty():
		return false
	
	var curse_type = curse.get("curse_type", "")
	return curse_type == "remote_move"

## 空地移動で移動可能な属性を取得
static func _get_vacant_move_elements(creature_data: Dictionary) -> Array:
	var parsed = creature_data.get("ability_parsed", {})
	var conditions = parsed.get("keyword_conditions", {})
	var vacant_move = conditions.get("空地移動", {})
	var elements = vacant_move.get("target_elements", [])
	
	return elements

## 指定属性の空き地を取得
static func _get_vacant_tiles_by_elements(board_system: Node, elements: Array) -> Array:
	var vacant_tiles = []
	
	if not board_system:
		return vacant_tiles
	
	# タイル番号順にソートして処理
	var tile_indices = board_system.tile_nodes.keys()
	tile_indices.sort()
	
	for i in tile_indices:
		var tile = board_system.tile_nodes[i]
		if not tile:
			continue
		
		# 配置不可タイルは空地移動不可
		if not TileHelper.is_placeable_tile(tile):
			continue
		
		# 空き地チェック（所有者がいない）
		if tile.owner_id != -1:
			continue
		
		# クリーチャーがいる場合はスキップ
		if tile.creature_data != null and not tile.creature_data.is_empty():
			continue
		
		# 属性チェック（"全"の場合はすべて許可）
		var tile_element = tile.tile_type
		if "全" in elements or tile_element in elements:
			vacant_tiles.append(i)
	
	return vacant_tiles

## 敵地移動の条件を取得
static func _get_enemy_move_condition(creature_data: Dictionary) -> Dictionary:
	var parsed = creature_data.get("ability_parsed", {})
	var conditions = parsed.get("keyword_conditions", {})
	var enemy_move = conditions.get("敵領地移動", {})
	return enemy_move.get("condition", {})

## 条件に合う敵地を取得
static func _get_enemy_tiles_by_condition(
	board_system: Node,
	condition: Dictionary,
	from_tile_index: int,
	_creature_data: Dictionary = {}
) -> Array:
	var enemy_tiles = []
	
	if not board_system:
		return enemy_tiles
	
	# 現在のプレイヤーIDを取得
	var current_player_id = board_system.current_player_index
	var from_tile = board_system.tile_nodes[from_tile_index]
	
	# 移動元タイルの属性を取得
	var from_tile_element = from_tile.tile_type
	
	
	# 全タイルをループ
	var all_tiles = board_system.tile_nodes.keys()
	
	for i in all_tiles:
		var tile = board_system.tile_nodes[i]
		if not tile:
			continue
		
		# 配置不可タイルは敵地移動不可
		if not TileHelper.is_placeable_tile(tile):
			continue
		
		# 敵地チェック（他プレイヤーの土地）
		if tile.owner_id == -1 or tile.owner_id == current_player_id:
			continue
		
		
		# 条件チェック（属性が異なる）- サンダースポーン用
		if condition.has("different_element") and condition.get("different_element"):
			var tile_element = tile.tile_type
			if tile_element == from_tile_element:
				continue
		
		enemy_tiles.append(i)
	
	return enemy_tiles

## すべての空き地を取得（アージェントキー用）
static func _get_all_vacant_tiles(board_system: Node) -> Array:
	# "全"属性として処理
	return _get_vacant_tiles_by_elements(board_system, ["全"])

## 移動不可能なタイルをフィルタリング
static func _filter_invalid_destinations(board_system: Node, tile_indices: Array, current_player_id: int) -> Array:
	var valid_tiles = []
	
	# SpellCurseToll参照を取得（peace呪いチェック用）
	var spell_curse_toll = null
	if board_system.has_meta("spell_curse_toll"):
		spell_curse_toll = board_system.get_meta("spell_curse_toll")
	
	for tile_index in tile_indices:
		if not board_system.tile_nodes.has(tile_index):
			continue
		
		var tile = board_system.tile_nodes[tile_index]
		
		# 配置不可タイルは移動不可（クリーチャー移動）
		if not TileHelper.is_placeable_tile(tile):
			continue
		
		# 自分のクリーチャーがいる土地はNG
		if tile.owner_id == current_player_id and not tile.creature_data.is_empty():
			continue
		
		# peace呪いチェック（敵領地への移動除外）
		if spell_curse_toll and tile.owner_id != -1 and tile.owner_id != current_player_id:
			if spell_curse_toll.has_peace_curse(tile_index):
				continue  # peace呪いがある敵領地は移動不可
		
		# クリーチャー移動侵略無効チェック（グルイースラッグ、ランドアーチン等）
		if spell_curse_toll and tile.owner_id != -1 and tile.owner_id != current_player_id:
			if not tile.creature_data.is_empty() and spell_curse_toll.is_creature_invasion_immune(tile.creature_data):
				continue  # 移動侵略無効のクリーチャーがいる敵領地は移動不可
		
		# プレイヤー侵略不可呪いチェック（バンフィズム：全敵領地への移動除外）
		if spell_curse_toll and tile.owner_id != -1 and tile.owner_id != current_player_id:
			if spell_curse_toll.is_player_invasion_disabled(current_player_id):
				continue  # 侵略不可呪いで敵領地は移動不可
		
		# マーシフルワールド（下位侵略不可）チェック - SpellWorldCurseに委譲
		if tile.owner_id != -1 and tile.owner_id != current_player_id:
			var gfm = board_system.game_flow_manager if "game_flow_manager" in board_system else null
			if gfm and gfm.spell_world_curse:
				if gfm.spell_world_curse.check_invasion_blocked(current_player_id, tile.owner_id, false):
					continue  # 下位への侵略不可
		
		valid_tiles.append(tile_index)
	
	return valid_tiles

## クリーチャーの移動を実行する共通処理
## 発動タイミングに関わらず同じ処理
static func execute_creature_move(
	board_system: Node,
	from_tile: int,
	to_tile: int,
	creature_data: Dictionary = {}
) -> void:
	
	if not board_system:
		return
	
	var from_tile_node = board_system.tile_nodes[from_tile]
	var to_tile_node = board_system.tile_nodes[to_tile]
	
	# creature_dataが空の場合は移動元から取得（duplicate()でコピー）
	if creature_data.is_empty():
		creature_data = from_tile_node.creature_data.duplicate()
	
	
	# 移動元をクリア（3Dカードも削除される）
	from_tile_node.remove_creature()
	if from_tile_node.has_method("update_display"):
		from_tile_node.update_display()
	
	# 移動による呪い消滅
	if creature_data.has("curse"):
		var curse_name = creature_data["curse"].get("name", "不明")
		creature_data.erase("curse")
		print("[MovementHelper] 呪い消滅（移動）: ", curse_name)
	
	# 移動先に配置（3Dカードも作成される）
	to_tile_node.place_creature(creature_data)
	to_tile_node.owner_id = from_tile_node.owner_id
	
	# ダウン状態設定（不屈チェック）
	if to_tile_node.has_method("set_down_state"):
		if not PlayerBuffSystem.has_unyielding(creature_data):
			to_tile_node.set_down_state(true)
	
	if to_tile_node.has_method("update_display"):
		to_tile_node.update_display()
	
	# 移動元の所有権を解除（クリーチャーがいなくなったため）
	from_tile_node.owner_id = -1
	if from_tile_node.has_method("update_display"):
		from_tile_node.update_display()
	
	# シグナル発信（board_systemがシグナルを持っている場合）
	if board_system.has_signal("creature_moved"):
		board_system.creature_moved.emit(from_tile, to_tile)


