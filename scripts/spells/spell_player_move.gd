extends Node
class_name SpellPlayerMove

# プレイヤー移動スペルシステム
# ワープ・移動制御系のスペル効果を管理
# ドキュメント: docs/design/spells/プレイヤー移動.md

# 参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var game_flow_manager: GameFlowManager
var spell_curse: SpellCurse
var tile_neighbor_system: TileNeighborSystem

# 初期化
func setup(board: BoardSystem3D, player: PlayerSystem, flow: GameFlowManager, curse: SpellCurse):
	board_system = board
	player_system = player
	game_flow_manager = flow
	spell_curse = curse
	
	if board_system:
		tile_neighbor_system = board_system.tile_neighbor_system
	
	print("[SpellPlayerMove] 初期化完了")

# ========================================
# ワープ系
# ========================================

## 最寄り空地にワープ（エスケープ 2014）
## @return Dictionary: {success: bool, from: int, to: int, message: String}
func warp_to_nearest_vacant(player_id: int) -> Dictionary:
	# MovementControllerから正確な位置を取得
	var current_tile = _get_player_current_tile(player_id)
	
	# 空地判定: クリーチャーがいない通常土地（現在地は除外）
	var is_vacant = func(tile_index: int) -> bool:
		if tile_index == current_tile:
			return false  # 現在地は除外
		var tile = board_system.tile_nodes.get(tile_index)
		if not tile:
			return false
		# 特殊タイル（配置不可）は除外
		if TileHelper.is_special_tile(tile):
			return false
		# クリーチャーがいる土地は除外
		var creature_data = BaseTile.creature_manager.get_data_ref(tile_index)
		if creature_data and not creature_data.is_empty():
			return false
		return true
	
	var nearest = find_nearest_tile(current_tile, is_vacant)
	
	if nearest < 0:
		return {
			"success": false,
			"from": current_tile,
			"to": -1,
			"message": "空地が見つかりません"
		}
	
	# プレイヤーをワープ
	_warp_player(player_id, nearest)
	
	return {
		"success": true,
		"from": current_tile,
		"to": nearest,
		"message": "タイル%dにワープしました" % nearest
	}

## 最寄りゲートにワープ（フォームポータル 2079）
## 現在地がゲートの場合は移動なしでゲート効果のみ発動
## @return Dictionary: {success: bool, from: int, to: int, gate_key: String, message: String}
func warp_to_nearest_gate(player_id: int) -> Dictionary:
	# MovementControllerから正確な位置を取得
	var current_tile = _get_player_current_tile(player_id)
	
	# 現在地がゲートかチェック
	var current_tile_node = board_system.tile_nodes.get(current_tile)
	if current_tile_node and current_tile_node.tile_type == "checkpoint":
		# 現在地がゲートなので移動なし、ゲート効果のみ発動
		var current_gate_key = _get_gate_key(current_tile)
		_trigger_gate_effect(player_id, current_tile, current_gate_key)
		
		return {
			"success": true,
			"from": current_tile,
			"to": current_tile,
			"gate_key": current_gate_key,
			"message": "現在地のゲート(%s)で効果発動" % current_gate_key
		}
	
	# ゲート判定（現在地以外を探す）
	var is_gate = func(tile_index: int) -> bool:
		var tile = board_system.tile_nodes.get(tile_index)
		if not tile:
			return false
		return tile.tile_type == "checkpoint"
	
	var nearest = find_nearest_tile(current_tile, is_gate)
	
	if nearest < 0:
		return {
			"success": false,
			"from": current_tile,
			"to": -1,
			"gate_key": "",
			"message": "ゲートが見つかりません"
		}
	
	# プレイヤーをワープ
	_warp_player(player_id, nearest)
	
	# ゲート効果を発動（通過扱い + ダウン解除）
	var gate_key = _get_gate_key(nearest)
	_trigger_gate_effect(player_id, nearest, gate_key)
	
	return {
		"success": true,
		"from": current_tile,
		"to": nearest,
		"gate_key": gate_key,
		"message": "ゲート(%s)にワープしました" % gate_key
	}

## 指定タイルにワープ（マジカルリープ 2104）
## @return Dictionary: {success: bool, from: int, to: int, message: String}
func warp_to_target(player_id: int, target_tile: int) -> Dictionary:
	# MovementControllerから正確な位置を取得
	var current_tile = _get_player_current_tile(player_id)
	
	# 距離チェック（1～4マス）
	var distance = calculate_tile_distance(current_tile, target_tile)
	if distance < 1 or distance > 4:
		return {
			"success": false,
			"from": current_tile,
			"to": target_tile,
			"message": "距離が範囲外です（%dマス）" % distance
		}
	
	# プレイヤーをワープ
	_warp_player(player_id, target_tile)
	
	return {
		"success": true,
		"from": current_tile,
		"to": target_tile,
		"message": "タイル%dにワープしました" % target_tile
	}

## 範囲内のタイルを取得（マジカルリープ用ターゲット選択）
func get_tiles_in_range(from_tile: int, min_dist: int, max_dist: int) -> Array:
	var result = []
	var total_tiles = board_system.tile_nodes.size()
	
	for tile_index in range(total_tiles):
		if tile_index == from_tile:
			continue
		
		var dist = calculate_tile_distance(from_tile, tile_index)
		if dist >= min_dist and dist <= max_dist:
			result.append(tile_index)
	
	return result

# ========================================
# 移動制御系
# ========================================

## 歩行逆転呪いを全セプターに付与（カオスパニック 2019）
func apply_movement_reverse_curse(duration: int = 1) -> void:
	for player_id in range(player_system.players.size()):
		spell_curse.curse_player(player_id, "movement_reverse", duration, {
			"name": "歩行逆転"
		})
	print("[SpellPlayerMove] 歩行逆転を全プレイヤーに付与 (duration=%d)" % duration)

## ゲート通過効果を発動（リミッション 2123）
## 注意: リミッションは「通過したことにする」だけで、停止はしないのでダウン解除は発生しない
## @return Dictionary: {success: bool, gate_key: String, lap_completed: bool, message: String}
func trigger_gate_pass(player_id: int, gate_key: String) -> Dictionary:
	if not game_flow_manager.player_lap_state.has(player_id):
		return {
			"success": false,
			"gate_key": gate_key,
			"lap_completed": false,
			"message": "プレイヤー状態が見つかりません"
		}
	
	# ゲートフラグを更新
	game_flow_manager.player_lap_state[player_id][gate_key] = true
	print("[SpellPlayerMove] ゲート通過: プレイヤー%d → %s" % [player_id, gate_key])
	
	# 周回完了チェック
	var lap_state = game_flow_manager.player_lap_state[player_id]
	var lap_completed = false
	if lap_state.get("N", false) and lap_state.get("S", false):
		# 周回完了処理を呼び出し（魔力ボーナス付与）
		game_flow_manager._complete_lap(player_id)
		lap_completed = true
	
	return {
		"success": true,
		"gate_key": gate_key,
		"lap_completed": lap_completed,
		"message": "%sを通過しました" % gate_key
	}

## 方向選択権を付与（クロックアウル秘術 9021）
func grant_direction_choice(player_id: int, _duration: int = 1) -> void:
	if player_id < 0 or player_id >= player_system.players.size():
		return
	
	var player = player_system.players[player_id]
	
	# MovementControllerがチェックするフラグを設定
	player.buffs["direction_choice_pending"] = true
	
	var player_name = "プレイヤー%d" % (player_id + 1)
	print("[SpellPlayerMove] 方向選択権付与: %s" % player_name)

## 選択可能なゲートを取得（リミッション用）
## 未通過かつ1周完了を引き起こさないゲートのみ返す
func get_selectable_gates(player_id: int) -> Array:
	if not game_flow_manager.player_lap_state.has(player_id):
		return []
	
	var lap_state = game_flow_manager.player_lap_state[player_id]
	var selectable = []
	
	# 未通過ゲートを列挙
	var unvisited = []
	for gate_key in ["N", "S"]:  # 現在は2ゲート固定
		if lap_state.has(gate_key) and not lap_state[gate_key]:
			unvisited.append(gate_key)
	
	# 1周完了を引き起こすゲートを除外
	for gate_key in unvisited:
		if not _would_complete_lap(player_id, gate_key):
			selectable.append(gate_key)
	
	return selectable

## 選択可能なゲートのタイル情報を取得（ターゲット選択UI用）
func get_selectable_gate_tiles(player_id: int) -> Array:
	var selectable_gates = get_selectable_gates(player_id)
	var result = []
	
	for gate_key in selectable_gates:
		var tile_index = _get_tile_index_for_gate(gate_key)
		if tile_index >= 0:
			result.append({
				"type": "gate",
				"tile_index": tile_index,
				"gate_key": gate_key
			})
	
	return result

# ========================================
# 移動方向判定（MovementController統合用）
# ========================================

## 利用可能な移動方向を取得
## @return Array: [1] = 順方向のみ、[-1] = 逆方向のみ、[1, -1] = 両方選択可
func get_available_directions(player_id: int) -> Array:
	var player = player_system.players[player_id]
	
	# 方向選択権があれば両方向を返す
	if player.buffs.has("direction_choice"):
		return [1, -1]  # 順方向、逆方向
	
	# 歩行逆転呪いチェック
	var curse = spell_curse.get_player_curse(player_id)
	if curse.get("curse_type") == "movement_reverse":
		return [-1]
	
	return [1]  # 通常は順方向のみ

## 方向選択権を消費
func consume_direction_choice(player_id: int) -> void:
	var player = player_system.players[player_id]
	if player.buffs.has("direction_choice"):
		player.buffs.erase("direction_choice")
		print("[SpellPlayerMove] 方向選択権消費: プレイヤー%d" % player_id)

## 最終的な移動方向を取得（歩行逆転＋方向選択の組み合わせ）
func get_final_direction(player_id: int, chosen_direction: int) -> int:
	var base_direction = 1
	
	# 歩行逆転呪いチェック
	var curse = spell_curse.get_player_curse(player_id)
	if curse.get("curse_type") == "movement_reverse":
		base_direction = -1
	
	# 方向選択権で選んだ方向を適用
	return base_direction * chosen_direction

# ========================================
# 距離計算ユーティリティ
# ========================================

## BFSでタイル間距離を計算（すごろく経路）
func calculate_tile_distance(from_tile: int, to_tile: int) -> int:
	if from_tile == to_tile:
		return 0
	
	if not tile_neighbor_system:
		push_error("[SpellPlayerMove] tile_neighbor_systemが未設定")
		return -1
	
	var visited = {}
	var queue = [[from_tile, 0]]  # [tile_index, distance]
	visited[from_tile] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var tile = current[0]
		var dist = current[1]
		
		# 隣接タイル（すごろき的な前後）を取得
		var neighbors = tile_neighbor_system.get_sequential_neighbors(tile)
		
		for neighbor in neighbors:
			if neighbor == to_tile:
				return dist + 1
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
	
	return -1  # 到達不可

## 条件に合致する最寄りタイルを検索（BFS）
func find_nearest_tile(from_tile: int, condition: Callable) -> int:
	if not tile_neighbor_system:
		push_error("[SpellPlayerMove] tile_neighbor_systemが未設定")
		return -1
	
	var visited = {}
	var queue = [from_tile]
	visited[from_tile] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		# 隣接タイルを取得
		var neighbors = tile_neighbor_system.get_sequential_neighbors(current)
		
		for neighbor in neighbors:
			if not visited.has(neighbor):
				visited[neighbor] = true
				
				# 条件チェック
				if condition.call(neighbor):
					return neighbor
				
				queue.append(neighbor)
	
	return -1  # 見つからない

# ========================================
# 内部ヘルパー
# ========================================

## プレイヤーの現在位置を取得（MovementController優先）
func _get_player_current_tile(player_id: int) -> int:
	# MovementControllerから正確な位置を取得（優先）
	if board_system and board_system.movement_controller:
		return board_system.movement_controller.get_player_tile(player_id)
	# フォールバック: PlayerSystemから取得
	return player_system.players[player_id].current_tile

## プレイヤーをワープ（内部処理）
func _warp_player(player_id: int, target_tile: int) -> void:
	var from_tile = _get_player_current_tile(player_id)
	
	# PlayerSystemの位置も更新
	player_system.players[player_id].current_tile = target_tile
	
	# 3Dモデルを移動（MovementController3D経由）
	if board_system and board_system.movement_controller:
		board_system.movement_controller.place_player_at_tile(player_id, target_tile)
		# MovementControllerの内部状態も更新
		board_system.movement_controller.player_tiles[player_id] = target_tile
	
	# 次ターンの方向選択権を付与（スペルワープ後）
	player_system.players[player_id].buffs["direction_choice_pending"] = true
	print("[SpellPlayerMove] プレイヤー%d: 次ターン方向選択権付与" % (player_id + 1))
	
	print("[SpellPlayerMove] プレイヤー%d ワープ: %d → %d" % [player_id, from_tile, target_tile])

## ゲート効果を発動（ゲートワープ時）
func _trigger_gate_effect(player_id: int, _tile_index: int, gate_key: String) -> void:
	# 1. ゲート通過扱い（周回フラグ更新）
	if game_flow_manager.player_lap_state.has(player_id):
		game_flow_manager.player_lap_state[player_id][gate_key] = true
		print("[SpellPlayerMove] ゲート通過: %s" % gate_key)
		
		# 周回完了チェック
		var lap_state = game_flow_manager.player_lap_state[player_id]
		if lap_state.get("N", false) and lap_state.get("S", false):
			# 周回完了処理はGameFlowManagerに任せる
			game_flow_manager._on_checkpoint_passed(player_id, gate_key)
	
	# 2. ダウン解除（全クリーチャー）
	_release_all_creature_down()

## 全クリーチャーのダウン状態を解除
func _release_all_creature_down() -> void:
	for tile_index in board_system.tile_nodes.keys():
		var creature = BaseTile.creature_manager.get_data_ref(tile_index)
		if creature and creature.get("is_down", false):
			creature["is_down"] = false
	print("[SpellPlayerMove] 全クリーチャーのダウン状態を解除")

## ゲートキーを取得（タイルインデックスから）
func _get_gate_key(tile_index: int) -> String:
	var tile = board_system.tile_nodes.get(tile_index)
	if tile and tile.tile_type == "checkpoint":
		# checkpoint_type: 0 = N, 1 = S
		return "N" if tile.checkpoint_type == 0 else "S"
	return ""

## ゲートキーからタイルインデックスを取得
func _get_tile_index_for_gate(gate_key: String) -> int:
	for tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[tile_index]
		if tile.tile_type == "checkpoint":
			var type_str = "N" if tile.checkpoint_type == 0 else "S"
			if type_str == gate_key:
				return tile_index
	return -1

## このゲートを通過すると1周完了になるか判定
func _would_complete_lap(player_id: int, gate_key: String) -> bool:
	var lap_state = game_flow_manager.player_lap_state[player_id]
	
	# 仮にこのゲートを通過した場合をシミュレート
	for key in ["N", "S"]:
		if key == gate_key:
			continue  # このゲートは通過済みとして扱う
		if not lap_state.get(key, false):
			return false  # 他に未通過があれば1周にならない
	
	return true  # 全て通過済み = 1周完了
