extends Node
class_name MovementController3D

# 3D移動制御システム
# プレイヤーの3D移動、カメラ追従、ワープ処理を管理

signal movement_started(player_id: int)
signal movement_step_completed(player_id: int, tile_index: int)
signal movement_completed(player_id: int, final_tile: int)
signal warp_executed(player_id: int, from_tile: int, to_tile: int)
signal start_passed(player_id: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# 移動設定
const MOVE_DURATION = 0.5  # 1マスの移動時間
const MOVE_HEIGHT = 1.0    # 駒の高さオフセット
const CAMERA_OFFSET = Vector3(19, 19, 19)  # カメラオフセット

# 参照
var tile_nodes = {}        # tile_index -> BaseTile
var player_nodes = []      # プレイヤー駒ノード配列
var player_tiles = []      # 各プレイヤーの現在位置
var camera = null          # Camera3D参照

# 状態
var is_moving = false
var current_moving_player = -1

# システム参照
var player_system: PlayerSystem = null
var special_tile_system: SpecialTileSystem = null

func _ready():
	pass

# 初期化
func initialize(tiles: Dictionary, players: Array, cam: Camera3D = null):
	tile_nodes = tiles
	player_nodes = players
	camera = cam
	
	# 初期位置配列を作成
	player_tiles.clear()
	for i in range(player_nodes.size()):
		player_tiles.append(0)

# システム参照を設定
func setup_systems(p_system: PlayerSystem, st_system: SpecialTileSystem = null):
	player_system = p_system
	special_tile_system = st_system

# プレイヤーの現在位置を取得
func get_player_tile(player_id: int) -> int:
	if player_id >= 0 and player_id < player_tiles.size():
		return player_tiles[player_id]
	return -1

# プレイヤーの位置を設定
func set_player_tile(player_id: int, tile_index: int):
	if player_id >= 0 and player_id < player_tiles.size():
		player_tiles[player_id] = tile_index

# === メイン移動処理 ===

# プレイヤーを移動（外部から呼ばれるメイン関数）
func move_player(player_id: int, steps: int) -> void:
	if is_moving or player_id >= player_nodes.size():
		print("移動不可: is_moving=", is_moving, ", player_id=", player_id)
		return
	
	is_moving = true
	current_moving_player = player_id
	emit_signal("movement_started", player_id)
	
	# 移動経路を作成
	var path = calculate_path(player_id, steps)
	
	# 経路に沿って移動
	await move_along_path(player_id, path)
	
	# 最終位置を更新
	var final_tile = path[path.size() - 1] if path.size() > 0 else player_tiles[player_id]
	player_tiles[player_id] = final_tile
	
	is_moving = false
	current_moving_player = -1
	
	emit_signal("movement_completed", player_id, final_tile)

# 移動経路を計算
func calculate_path(player_id: int, steps: int) -> Array:
	var path = []
	var current_tile = player_tiles[player_id]
	
	for i in range(steps):
		# 次のタイルを計算（20マスの円形ボード想定）
		current_tile = (current_tile + 1) % 20
		path.append(current_tile)
	
	return path

# 経路に沿って移動
func move_along_path(player_id: int, path: Array) -> void:
	var previous_tile = player_tiles[player_id]
	var i = 0
	
	while i < path.size():
		var tile_index = path[i]
		
		if not tile_nodes.has(tile_index):
			print("Warning: タイル", tile_index, "が見つかりません")
			i += 1
			continue
		
		# スタート通過チェック
		if tile_index == 0 and previous_tile > tile_index:
			handle_start_pass(player_id)
		
		# チェックポイント通過チェック
		check_and_handle_checkpoint(player_id, tile_index, previous_tile)
		
		# タイルへ移動
		await move_to_tile(player_id, tile_index)
		
		# 位置を更新
		player_tiles[player_id] = tile_index
		
		# 通過型ワープチェック（ビジュアルエフェクトのみ）
		var warp_result = await check_and_handle_warp(player_id, tile_index)
		if warp_result.warped:
			# ワープ発生：経路を修正する
			var warped_tile = warp_result.new_tile
			player_tiles[player_id] = warped_tile
			
			# 経路の残りを再計算（ワープ先から続ける）
			var new_path = [warped_tile]  # ワープ先
			var current = warped_tile
			for j in range(i + 1, path.size()):
				current = (current + 1) % 20
				new_path.append(current)
			
			# 経路を置き換え
			for j in range(new_path.size()):
				if i + j + 1 < path.size():
					path[i + j + 1] = new_path[j]
				else:
					path.append(new_path[j])
			
			tile_index = warped_tile
		
		emit_signal("movement_step_completed", player_id, tile_index)
		previous_tile = tile_index
		i += 1

# 単一タイルへの移動
func move_to_tile(player_id: int, tile_index: int) -> void:
	if not tile_nodes.has(tile_index):
		return
	
	var player_node = player_nodes[player_id]
	var target_pos = tile_nodes[tile_index].global_position
	target_pos.y += MOVE_HEIGHT
	
	# Tweenで滑らかな移動
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# プレイヤー駒を移動
	tween.tween_property(player_node, "global_position", target_pos, MOVE_DURATION)
	
	# カメラを追従（現在のプレイヤーのみ）
	if camera and player_system and player_id == player_system.current_player_index:
		var cam_target = target_pos + CAMERA_OFFSET
		tween.tween_property(camera, "global_position", cam_target, MOVE_DURATION)
	
	await tween.finished

# === ワープ処理 ===

# ワープをチェックして処理
func check_and_handle_warp(player_id: int, tile_index: int) -> Dictionary:
	if not special_tile_system:
		return {"warped": false}
	
	# 通過型ワープかチェック
	if special_tile_system.is_warp_gate(tile_index):
		var warp_pair = special_tile_system.get_warp_pair(tile_index)
		if warp_pair != -1 and warp_pair != tile_index:
			await execute_warp(player_id, tile_index, warp_pair)
			return {"warped": true, "new_tile": warp_pair}
	
	return {"warped": false}

# ワープを実行（3D版）
func warp_player_3d(player_id: int, to_tile: int) -> void:
	if player_id >= player_nodes.size() or not tile_nodes.has(to_tile):
		return
	
	var from_tile = player_tiles[player_id]
	await execute_warp(player_id, from_tile, to_tile)
	player_tiles[player_id] = to_tile

# ワープアニメーション実行
func execute_warp(player_id: int, from_tile: int, to_tile: int) -> void:
	print("ワープ！マス", from_tile, " → マス", to_tile)
	
	var player_node = player_nodes[player_id]
	
	# ワープエフェクト（簡易版：縮小して消える→移動→拡大して現れる）
	# 注意: Vector3.ZEROだとTransform3D.invert()でエラーが出るため極小値を使用
	const WARP_MIN_SCALE = Vector3(0.001, 0.001, 0.001)
	var tween = get_tree().create_tween()
	
	# 縮小して消える（ほぼゼロまで）
	tween.tween_property(player_node, "scale", WARP_MIN_SCALE, 0.2)
	
	# 瞬間移動
	await tween.finished
	if tile_nodes.has(to_tile):
		var target_pos = tile_nodes[to_tile].global_position
		target_pos.y += MOVE_HEIGHT
		player_node.global_position = target_pos
		
		# カメラも瞬間移動
		if camera and player_system and player_id == player_system.current_player_index:
			var cam_target = target_pos + CAMERA_OFFSET
			camera.global_position = cam_target
	
	# 拡大して現れる
	var tween2 = get_tree().create_tween()
	tween2.tween_property(player_node, "scale", Vector3.ONE, 0.2)
	await tween2.finished
	
	emit_signal("warp_executed", player_id, from_tile, to_tile)

# === 特殊処理 ===

# スタート地点通過処理
func handle_start_pass(player_id: int):
	print("スタート地点通過！")
	if player_system:
		player_system.add_magic(player_id, GameConstants.PASS_BONUS)
	
	# Phase 1-A: プレイヤーの全土地のダウン状態をクリア
	clear_all_down_states_for_player(player_id)
	
	# 全クリーチャーのHP回復+10
	heal_all_creatures_for_player(player_id, 10)
	
	emit_signal("start_passed", player_id)

# チェックポイント通過処理
func check_and_handle_checkpoint(player_id: int, tile_index: int, previous_tile: int):
	if not tile_nodes.has(tile_index):
		return
	
	var tile = tile_nodes[tile_index]
	
	# CheckpointTileかチェック
	if tile.has_signal("checkpoint_passed"):
		# タイル0は2回目以降のみ通過扱い（previous_tile > tile_indexで判定）
		if tile_index == 0 and previous_tile <= tile_index:
			return
		
		# CheckpointTileのon_player_passedを呼ぶ
		if tile.has_method("on_player_passed"):
			tile.on_player_passed(player_id)

# 特定タイルへ直接配置（初期配置用）
func place_player_at_tile(player_id: int, tile_index: int) -> void:
	if player_id >= player_nodes.size() or not tile_nodes.has(tile_index):
		return
	
	var player_node = player_nodes[player_id]
	var target_pos = tile_nodes[tile_index].global_position
	target_pos.y += MOVE_HEIGHT
	
	# オフセットを追加（プレイヤーごとに少しずらす）
	target_pos.x += player_id * 0.5
	
	player_node.global_position = target_pos
	player_tiles[player_id] = tile_index

# 全クリーチャーのHP回復
func heal_all_creatures_for_player(player_id: int, heal_amount: int):
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.creature_data:
			var creature = tile.creature_data
			var max_hp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
			var current_hp = creature.get("current_hp", max_hp)
			
			# HP回復（MHPを超えない）
			var new_hp = min(current_hp + heal_amount, max_hp)
			creature["current_hp"] = new_hp
			
			print("[MovementController] HP回復: タイル", tile_index, " ", creature.get("name", ""), 
				  " (", current_hp, " → ", new_hp, " / ", max_hp, ")")

# Phase 1-A: プレイヤーの全土地のダウン状態をクリア
func clear_all_down_states_for_player(player_id: int):
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.has_method("is_down") and tile.is_down():
			tile.clear_down_state()
			print("[MovementController] ダウン状態クリア: タイル", tile_index, "（プレイヤー", player_id + 1, "）")

# カメラをプレイヤーにフォーカス
func focus_camera_on_player(player_id: int, smooth: bool = true) -> void:
	if not camera or player_id >= player_nodes.size():
		print("Warning: カメラなし or 無効なplayer_id:", player_id)
		return
	
	var player_node = player_nodes[player_id]
	if not player_node:
		print("Warning: プレイヤーノードが見つかりません:", player_id)
		return
		
	var target_pos = player_node.global_position + CAMERA_OFFSET
	
	print("カメラ移動: プレイヤー", player_id + 1, "の位置へ (", player_node.global_position, ")")
	
	if smooth:
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "global_position", target_pos, 0.8)
		await tween.finished
	else:
		camera.global_position = target_pos

# === ユーティリティ ===

# 移動中かチェック
func is_player_moving() -> bool:
	return is_moving

# 移動中のプレイヤーIDを取得
func get_moving_player() -> int:
	return current_moving_player
