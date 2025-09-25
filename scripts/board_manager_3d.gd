extends Node3D
class_name BoardManager3D

# タイル管理
var tile_nodes = {}
var player_node = null
var current_tile = 0

# 移動制御
var is_moving = false
var move_speed = 2.0  # 移動速度（調整可能）

# デバッグ機能
var debug_mode = false
var fixed_dice_value = 0

# カメラ参照
var camera = null

func _ready():
	collect_tiles()
	setup_connections()
	find_player()
	setup_camera()
	
	print("=== BoardManager初期化 ===")
	print("タイル総数: ", tile_nodes.size())
	print("\n【操作方法】")
	print("スペース: サイコロを振る")
	print("1-6キー: サイコロ固定")
	print("0キー: 固定解除")

# カメラを設定
func setup_camera():
	camera = get_node_or_null("Camera3D")
	if camera and player_node:
		var offset = Vector3(0, 10, 10)
		camera.global_position = player_node.global_position + offset
		camera.look_at(player_node.global_position, Vector3.UP)

# 全タイルを収集
func collect_tiles():
	for child in get_children():
		if child is BaseTile:
			tile_nodes[child.tile_index] = child

# タイル間の接続設定
func setup_connections():
	for i in range(20):
		if tile_nodes.has(i):
			var next_index = (i + 1) % 20
			tile_nodes[i].connections["next"] = next_index

# プレイヤーを探す
func find_player():
	for child in get_children():
		if child.name == "Player":
			player_node = child
			if tile_nodes.has(0):
				var start_pos = tile_nodes[0].global_position
				start_pos.y += 1.0
				player_node.global_position = start_pos

# タイル位置を取得
func get_tile_position(index: int) -> Vector3:
	if tile_nodes.has(index):
		var pos = tile_nodes[index].global_position
		pos.y += 1.0
		return pos
	return Vector3.ZERO

# サイコロを振って滑らかに移動
func roll_dice_and_move():
	if is_moving:
		return
		
	is_moving = true
	
	var dice_value
	if debug_mode and fixed_dice_value > 0:
		dice_value = fixed_dice_value
		print("\n🎲 サイコロ: ", dice_value, " (固定)")
	else:
		dice_value = randi_range(1, 6)
		print("\n🎲 サイコロ: ", dice_value)
	
	# 経路を作成
	var path = []
	var temp_tile = current_tile
	for i in range(dice_value):
		temp_tile = (temp_tile + 1) % 20
		path.append(temp_tile)
	
	# 滑らかに移動
	await move_along_path(path)
	
	print("移動完了: タイル", current_tile, "に到着")
	
	if tile_nodes.has(current_tile):
		var tile = tile_nodes[current_tile]
		print("タイル種類: ", tile.tile_type)
	
	is_moving = false

# 経路に沿って滑らかに移動
func move_along_path(path: Array):
	for tile_index in path:
		current_tile = tile_index
		var target_pos = get_tile_position(tile_index)
		
		print("  → タイル", tile_index)
		
		# プレイヤーとカメラを同時に移動
		var tween = get_tree().create_tween()
		tween.set_parallel(true)  # 並列実行
		
		# プレイヤー移動
		tween.tween_property(player_node, "global_position", target_pos, 0.5)
		
		# カメラ移動（プレイヤーを追従）
		if camera:
			var cam_offset = Vector3(0, 10, 10)
			var cam_target = target_pos + cam_offset
			tween.tween_property(camera, "global_position", cam_target, 0.5)
			
		await tween.finished
		
		# カメラの向きを調整
		if camera:
			camera.look_at(player_node.global_position, Vector3.UP)

# デバッグ：サイコロ値を固定
func set_fixed_dice(value: int):
	if value >= 1 and value <= 6:
		debug_mode = true
		fixed_dice_value = value
		print("【デバッグ】サイコロ固定: ", value)
	elif value == 0:
		debug_mode = false
		fixed_dice_value = 0
		print("【デバッグ】サイコロ固定解除")

# 入力処理
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				roll_dice_and_move()
			KEY_1:
				set_fixed_dice(1)
			KEY_2:
				set_fixed_dice(2)
			KEY_3:
				set_fixed_dice(3)
			KEY_4:
				set_fixed_dice(4)
			KEY_5:
				set_fixed_dice(5)
			KEY_6:
				set_fixed_dice(6)
			KEY_0:
				set_fixed_dice(0)
			KEY_ENTER:
				# デバッグ用1マス移動
				if not is_moving:
					is_moving = true
					var path = [(current_tile + 1) % 20]
					await move_along_path(path)
					is_moving = false
