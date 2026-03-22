class_name DiceRollerUI
extends Node

## ゲームの3Dシーンに直接サイコロを配置して転がす演出
## カメラに追従し、移動中もサイコロが画面に残る

signal roll_completed

var _dice_container: Node3D
var _total_label: Label
var _canvas_layer: CanvasLayer


func show_roll_in_scene(scene_root: Node, player_pos: Vector3, dice_values: Array, total: int, duration: float = 1.5) -> void:
	# カメラを取得してサイコロをカメラの子にする（完全同期・ガクガク防止）
	var camera := scene_root.get_viewport().get_camera_3d()

	# サイコロ用コンテナ
	_dice_container = Node3D.new()
	_dice_container.scale = Vector3(3.0, 3.0, 3.0)

	if camera:
		# カメラの子にして、カメラローカル座標で配置
		camera.add_child(_dice_container)
		# ワールド座標での目標位置を計算
		var world_target := Vector3(player_pos.x, player_pos.y + 3.0, player_pos.z + 7.0)
		# カメラローカル座標に変換
		_dice_container.global_position = world_target
	else:
		# カメラがない場合はフォールバック
		_dice_container.position = Vector3(player_pos.x, player_pos.y + 3.0, player_pos.z + 7.0)
		scene_root.add_child(_dice_container)

	# サイコロ生成・配置（大きめ間隔）
	var dice_count := dice_values.size()
	var spacing := 1.5
	var start_x := -(dice_count - 1) * spacing / 2.0

	# ダイスの種類: [ダイス1, ダイス2] または [ダイス1, ダイス2, ダイス3]
	var dice_types: Array[int] = [1, 2, 3]
	for i in range(dice_count):
		var die := Dice3D.new()
		die.position = Vector3(start_x + i * spacing, 0, 0)
		_dice_container.add_child(die)
		die.setup(dice_types[i])
		die.roll_to(dice_values[i], i * 0.15)

	# 合計値ラベル（2D UIとして最前面に表示）
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	scene_root.add_child(_canvas_layer)

	_total_label = Label.new()
	_total_label.text = str(total)
	_total_label.add_theme_font_size_override("font_size", 200)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_total_label.size = Vector2(400, 250)
	_total_label.position = Vector2(
		scene_root.get_viewport().get_visible_rect().size.x / 2.0 - 200,
		scene_root.get_viewport().get_visible_rect().size.y / 2.0 - 125
	)
	_total_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_total_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_total_label.add_theme_constant_override("shadow_offset_x", 5)
	_total_label.add_theme_constant_override("shadow_offset_y", 5)
	_total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_total_label.visible = false
	_canvas_layer.add_child(_total_label)

	# 転がりアニメーション完了後に合計表示
	await scene_root.get_tree().create_timer(1.3).timeout
	if is_instance_valid(_total_label):
		_total_label.visible = true

	# 表示時間待ち
	var remaining := maxf(duration - 1.3, 0.5)
	await scene_root.get_tree().create_timer(remaining).timeout

	roll_completed.emit()

	# クリーンアップ
	await scene_root.get_tree().create_timer(0.3).timeout
	if is_instance_valid(_dice_container):
		_dice_container.queue_free()
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	queue_free()
