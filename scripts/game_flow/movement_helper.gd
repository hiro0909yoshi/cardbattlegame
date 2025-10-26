# MovementHelper - クリーチャー移動の共通処理
class_name MovementHelper

## 移動可能な土地のインデックス配列を返す
## 発動タイミングに関わらず、移動タイプに応じた候補を返す
static func get_move_destinations(
	board_system: Node,
	creature_data: Dictionary,
	from_tile_index: int,
	move_type_override: String = ""  # スペルなどで強制的に移動タイプを指定
) -> Array:
	
	# 移動タイプの判定（オーバーライドがあればそれを優先）
	var move_type = move_type_override
	if move_type.is_empty():
		move_type = _detect_move_type(creature_data)
	
	print("[MovementHelper] 移動タイプ: %s (from_tile: %d)" % [move_type, from_tile_index])
	
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
			
			print("[MovementHelper] 空地移動+通常移動: 空地=%d個, 隣接=%d個, 合計=%d個" % [vacant_destinations.size(), adjacent_destinations.size(), all_destinations.size()])
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
			
			print("[MovementHelper] 敵地移動+通常移動: 敵地=%d個, 隣接=%d個, 合計=%d個" % [enemy_destinations.size(), adjacent_destinations.size(), all_destinations.size()])
			return all_destinations
		"adjacent":
			# TileNeighborSystemを使用
			if board_system.tile_neighbor_system:
				return board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
			return []
		"random_vacant":  # 戦闘後のアージェントキー用
			return _get_all_vacant_tiles(board_system)
		_:
			return []

## クリーチャーの移動タイプを判定
static func _detect_move_type(creature_data: Dictionary) -> String:
	if not creature_data:
		print("[MovementHelper] _detect_move_type: creature_data is empty")
		return "adjacent"
	
	print("[MovementHelper] _detect_move_type: creature_name=%s, id=%s" % [creature_data.get("name", "?"), creature_data.get("id", "?")])
	
	var parsed = creature_data.get("ability_parsed", {})
	var keywords = parsed.get("keywords", [])
	var conditions = parsed.get("keyword_conditions", {})
	
	print("[MovementHelper] _detect_move_type: keywords=%s, conditions=%s" % [keywords, conditions.keys()])
	
	# 空地移動チェック
	if "空地移動" in keywords and conditions.has("空地移動"):
		return "vacant_move"
	
	# 敵地移動チェック
	if "敵領地移動" in keywords and conditions.has("敵領地移動"):
		return "enemy_move"
	
	# デフォルトは隣接移動
	return "adjacent"

## 空地移動で移動可能な属性を取得
static func _get_vacant_move_elements(creature_data: Dictionary) -> Array:
	var parsed = creature_data.get("ability_parsed", {})
	var conditions = parsed.get("keyword_conditions", {})
	var vacant_move = conditions.get("空地移動", {})
	var elements = vacant_move.get("target_elements", [])
	
	print("[MovementHelper] 空地移動対象属性: %s" % [elements])
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
	
	print("[MovementHelper] 移動可能な空き地: %d個" % [vacant_tiles.size()])
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
	creature_data: Dictionary = {}
) -> Array:
	var enemy_tiles = []
	
	if not board_system:
		return enemy_tiles
	
	# 現在のプレイヤーIDを取得
	var current_player_id = board_system.current_player_index
	var from_tile = board_system.tile_nodes[from_tile_index]
	
	# 移動元タイルの属性を取得
	var from_tile_element = from_tile.tile_type
	
	print("[MovementHelper] 敵地移動: from_tile=%d, tile_element=%s, player=%d" % [from_tile_index, from_tile_element, current_player_id])
	print("[MovementHelper] 条件: %s" % [condition])
	
	# 全タイルをループ
	var all_tiles = board_system.tile_nodes.keys()
	
	for i in all_tiles:
		var tile = board_system.tile_nodes[i]
		if not tile:
			continue
		
		# 敵地チェック（他プレイヤーの土地）
		if tile.owner_id == -1 or tile.owner_id == current_player_id:
			continue
		
		print("[MovementHelper] 候補タイル %d: owner=%d, element=%s" % [i, tile.owner_id, tile.tile_type])
		
		# 条件チェック（属性が異なる）- サンダースポーン用
		if condition.has("different_element") and condition.get("different_element"):
			var tile_element = tile.tile_type
			print("[MovementHelper]   -> different_element check: from_tile=%s, enemy_tile=%s" % [from_tile_element, tile_element])
			if tile_element == from_tile_element:
				print("[MovementHelper]   -> SKIP: 同じ属性")
				continue
		
		print("[MovementHelper]   -> OK: 移動可能")
		enemy_tiles.append(i)
	
	print("[MovementHelper] 移動可能な敵地: %d個" % [enemy_tiles.size()])
	return enemy_tiles

## すべての空き地を取得（アージェントキー用）
static func _get_all_vacant_tiles(board_system: Node) -> Array:
	# "全"属性として処理
	return _get_vacant_tiles_by_elements(board_system, ["全"])

## クリーチャーの移動を実行する共通処理
## 発動タイミングに関わらず同じ処理
static func execute_creature_move(
	board_system: Node,
	from_tile: int,
	to_tile: int,
	creature_data: Dictionary = {}
) -> void:
	
	if not board_system:
		print("[MovementHelper] エラー: board_systemが無効")
		return
	
	var from_tile_node = board_system.tile_nodes[from_tile]
	var to_tile_node = board_system.tile_nodes[to_tile]
	
	# creature_dataが空の場合は移動元から取得
	if creature_data.is_empty():
		creature_data = from_tile_node.creature_data
	
	print("[MovementHelper] 移動実行: %d -> %d" % [from_tile, to_tile])
	
	# 移動元をクリア
	from_tile_node.creature_data = {}
	if from_tile_node.has_method("update_display"):
		from_tile_node.update_display()
	
	# 移動先に配置
	to_tile_node.creature_data = creature_data
	to_tile_node.owner_id = from_tile_node.owner_id
	
	# ダウン状態設定（不屈チェック）
	if to_tile_node.has_method("set_down_state"):
		if not SkillSystem.has_unyielding(creature_data):
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
	
	print("[MovementHelper] 移動完了")
