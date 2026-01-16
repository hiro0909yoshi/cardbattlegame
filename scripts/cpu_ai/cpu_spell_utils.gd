## CPUスペルAI用ユーティリティ
## 距離計算、利益計算、コンテキスト構築、チェックポイント関連
class_name CPUSpellUtils
extends RefCounted

const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")

## 共有コンテキスト
var _context: CPUAIContextScript = null

## システム参照
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var lap_system: Node = null

## 共有コンテキストを設定
func set_context(ctx: CPUAIContextScript) -> void:
	_context = ctx
	if ctx:
		board_system = _context.board_system
		player_system = _context.player_system
		card_system = _context.card_system
		lap_system = _context.lap_system

# =============================================================================
# コンテキスト構築
# =============================================================================

## コンテキスト作成
func build_context(player_id: int) -> Dictionary:
	var context = {
		"player_id": player_id,
		"magic": player_system.get_magic(player_id) if player_system else 0,
		"hand_count": 0,
		"lap_count": 0,
		"rank": 1,
		"destroyed_count": 0
	}
	
	if card_system:
		var hand = card_system.get_all_cards_for_player(player_id)
		context.hand_count = hand.size()
	
	# 周回数はlap_systemから取得
	if lap_system:
		context.lap_count = lap_system.get_lap_count(player_id)
	
	# 破壊カウントはlap_systemから取得（グローバル）
	if lap_system:
		context.destroyed_count = lap_system.get_destroy_count()
	
	if player_system:
		context.rank = get_player_rank(player_id)
	
	return context

# =============================================================================
# スペル情報取得
# =============================================================================

## スペルコスト取得
func get_spell_cost(spell: Dictionary) -> int:
	var cost_data = spell.get("cost", {})
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	elif typeof(cost_data) == TYPE_INT or typeof(cost_data) == TYPE_FLOAT:
		return int(cost_data)
	return 0

## ダメージ値を取得
func get_damage_value(spell: Dictionary) -> int:
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "damage":
			return effect.get("value", 0)
	
	return 0

# =============================================================================
# 利益計算
# =============================================================================

## 利益計算
func calculate_profit(formula: String, context: Dictionary) -> int:
	if formula.is_empty():
		return 0
	
	# 簡易的な計算
	match formula:
		"destroyed_count * 20":
			return context.get("destroyed_count", 0) * 20
		"destroyed_count * 30":
			return context.get("destroyed_count", 0) * 30
		"rank * 50":
			return context.get("rank", 1) * 50
		"lap_count * 50":
			return context.get("lap_count", 0) * 50
		"lap_diff * 100":
			return calculate_lap_diff(context) * 100
		_:
			# enemy_magic * 0.3 などの計算
			if "enemy_magic" in formula:
				var enemy_magic = get_max_enemy_magic(context)
				if "0.3" in formula:
					return int(enemy_magic * 0.3)
				if "0.1" in formula:
					return int(enemy_magic * 0.1)
			if "enemy_land_count" in formula:
				var count = get_enemy_land_count(context)
				return count * 30
	
	return 0

## 周回差計算
func calculate_lap_diff(context: Dictionary) -> int:
	if not player_system or not lap_system:
		return 0
	
	var player_id = context.player_id
	var my_lap = lap_system.get_lap_count(player_id)
	var max_enemy_lap = 0
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			var enemy_lap = lap_system.get_lap_count(i)
			max_enemy_lap = max(max_enemy_lap, enemy_lap)
	
	var diff = max_enemy_lap - my_lap
	return diff

## 最大敵魔力取得
func get_max_enemy_magic(context: Dictionary) -> int:
	if not player_system:
		return 0
	
	var player_id = context.player_id
	var max_magic = 0
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			var magic = player_system.get_magic(i)
			max_magic = max(max_magic, magic)
	
	return max_magic

## 敵土地数取得
func get_enemy_land_count(context: Dictionary) -> int:
	if not board_system:
		return 0
	
	var player_id = context.player_id
	var count = 0
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id and owner_id != -1:
			count += 1
	
	return count

# =============================================================================
# プレイヤー情報
# =============================================================================

## プレイヤー順位取得
func get_player_rank(player_id: int) -> int:
	if not player_system:
		return 1
	
	var my_total = player_system.calculate_total_assets(player_id)
	var rank = 1
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			var other_total = player_system.calculate_total_assets(i)
			if other_total > my_total:
				rank += 1
	
	return rank

## プレイヤーの現在位置を取得
func get_player_current_tile(player_id: int) -> int:
	if board_system and "movement_controller" in board_system and board_system.movement_controller:
		return board_system.movement_controller.get_player_tile(player_id)
	if player_system:
		return player_system.get_player_position(player_id)
	return 0

## 敵プレイヤー一覧を取得
func get_enemy_players(context: Dictionary) -> Array:
	var results = []
	if not player_system:
		return results
	
	var player_id = context.player_id
	var player_count = player_system.players.size()
	
	for i in range(player_count):
		if i != player_id:
			results.append({"type": "player", "player_id": i})
	
	return results

# =============================================================================
# 距離計算
# =============================================================================

## タイル間の距離を計算（BFS・両方向）
func calculate_tile_distance(from_tile: int, to_tile: int) -> int:
	if from_tile == to_tile:
		return 0
	
	if not board_system or not "tile_neighbor_system" in board_system:
		# フォールバック: 単純な差分
		return abs(to_tile - from_tile)
	
	var neighbor_system = board_system.tile_neighbor_system
	if not neighbor_system:
		return abs(to_tile - from_tile)
	
	# BFS
	var visited = {}
	var queue = [[from_tile, 0]]
	visited[from_tile] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var tile = current[0]
		var dist = current[1]
		
		if dist > 20:  # 上限
			break
		
		var neighbors = neighbor_system.get_sequential_neighbors(tile) if neighbor_system.has_method("get_sequential_neighbors") else []
		
		for neighbor in neighbors:
			if neighbor == to_tile:
				return dist + 1
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
	
	return abs(to_tile - from_tile)  # フォールバック

## プレイヤーの進行方向での距離を計算（リミッション用）
## 注: from_tile == to_tileの場合も1周分の距離を返す（現在位置のチェックポイント用）
func calculate_forward_distance(from_tile: int, to_tile: int, player_id: int) -> int:
	if not board_system or not "tile_neighbor_system" in board_system:
		return abs(to_tile - from_tile)
	
	var neighbor_system = board_system.tile_neighbor_system
	if not neighbor_system:
		return abs(to_tile - from_tile)
	
	# プレイヤーの進行方向を取得
	var direction = 1
	if player_system and player_id < player_system.players.size():
		direction = player_system.players[player_id].current_direction
	
	# 進行方向のみで探索
	var current = from_tile
	var came_from = -1
	var dist = 0
	var max_steps = 100  # 無限ループ防止
	
	while dist < max_steps:
		# 次のタイルを取得（進行方向のみ）
		var next_tile = _get_next_tile_in_direction(current, came_from, direction)
		if next_tile < 0:
			break
		
		dist += 1
		
		if next_tile == to_tile:
			return dist
		
		came_from = current
		current = next_tile
	
	return 9999  # 到達不可

## 進行方向で次のタイルを取得
func _get_next_tile_in_direction(current_tile: int, came_from: int, direction: int) -> int:
	if not board_system:
		return current_tile + direction
	
	# tile_neighbor_systemを使用
	if "tile_neighbor_system" in board_system and board_system.tile_neighbor_system:
		var neighbor_system = board_system.tile_neighbor_system
		if neighbor_system.has_method("get_sequential_neighbors"):
			var neighbors = neighbor_system.get_sequential_neighbors(current_tile)
			var choices = []
			for n in neighbors:
				if n != came_from:
					choices.append(n)
			
			if choices.is_empty():
				return came_from if came_from >= 0 else current_tile + direction
			if choices.size() == 1:
				return choices[0]
			
			# 複数選択肢がある場合、方向に基づいて選択
			choices.sort()
			if direction > 0:
				return choices[-1]
			else:
				return choices[0]
	
	# フォールバック: 単純に+direction
	return current_tile + direction

## 距離制限内の土地を取得
func get_tiles_in_range(from_tile: int, min_dist: int, max_dist: int) -> Array:
	var results = []
	if not board_system:
		return results
	
	var tiles = board_system.tile_nodes if "tile_nodes" in board_system else {}
	
	for tile_index in tiles.keys():
		if tile_index == from_tile:
			continue
		
		var dist = calculate_tile_distance(from_tile, tile_index)
		if dist >= min_dist and dist <= max_dist:
			results.append(tile_index)
	
	return results

# =============================================================================
# チェックポイント/ゲート関連
# =============================================================================

## 未訪問チェックポイントタイルを取得
func get_unvisited_checkpoint_tiles(player_id: int) -> Array:
	var results = []
	if not board_system or not lap_system:
		return results
	
	# lap_systemから未訪問チェックポイントを取得
	var required_checkpoints = lap_system.required_checkpoints
	var player_state = lap_system.player_lap_state.get(player_id, {})
	
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			# このチェックポイントは未訪問
			var tile_index = get_checkpoint_tile_index(checkpoint)
			if tile_index >= 0:
				results.append(tile_index)
	
	return results

## 全チェックポイントタイルを取得
func get_all_checkpoint_tiles() -> Array:
	var results = []
	if not board_system:
		return results
	
	var tiles = board_system.tile_nodes if board_system.has_method("get") else {}
	if "tile_nodes" in board_system:
		tiles = board_system.tile_nodes
	
	for tile_index in tiles.keys():
		var tile = tiles[tile_index]
		if tile and tile.tile_type == "checkpoint":
			results.append(tile_index)
	
	return results

## チェックポイント種別からタイルインデックスを取得
func get_checkpoint_tile_index(checkpoint_type: String) -> int:
	if not board_system:
		return -1
	
	var tiles = board_system.tile_nodes if "tile_nodes" in board_system else {}
	
	for tile_index in tiles.keys():
		var tile = tiles[tile_index]
		if tile and tile.tile_type == "checkpoint":
			var type_str = get_checkpoint_type_string(tile)
			if type_str == checkpoint_type:
				return tile_index
	
	return -1

## チェックポイントタイルからタイプ文字列を取得（N, S, E, W対応）
func get_checkpoint_type_string(tile) -> String:
	if not tile:
		return ""
	var cp_type = tile.checkpoint_type if "checkpoint_type" in tile else 0
	match cp_type:
		0: return "N"
		1: return "S"
		2: return "E"
		3: return "W"
		_: return ""

## 進行方向から最も遠い未訪問ゲートを取得（リミッション用）
func get_farthest_unvisited_gate(context: Dictionary) -> Dictionary:
	if not board_system or not lap_system:
		return {}
	
	var player_id = context.get("player_id", 0)
	var current_tile = get_player_current_tile(player_id)
	var player_state = lap_system.player_lap_state.get(player_id, {})
	var required_checkpoints = lap_system.required_checkpoints
	
	# 未訪問で1周完了を引き起こさないゲートを収集
	var selectable_gates = []
	var unvisited_count = 0
	
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			unvisited_count += 1
	
	# 未訪問が2つ以上ある場合のみ選択可能
	if unvisited_count < 2:
		return {}
	
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			var tile_index = get_checkpoint_tile_index(checkpoint)
			if tile_index >= 0:
				# 進行方向での距離を計算
				var distance = calculate_forward_distance(current_tile, tile_index, player_id)
				selectable_gates.append({
					"checkpoint": checkpoint,
					"tile_index": tile_index,
					"distance": distance
				})
	
	if selectable_gates.is_empty():
		return {}
	
	# 距離でソート（遠い順）
	selectable_gates.sort_custom(func(a, b): return a.distance > b.distance)
	
	var farthest = selectable_gates[0]
	
	return {
		"type": "gate",
		"tile_index": farthest.tile_index,
		"gate_key": farthest.checkpoint
	}
