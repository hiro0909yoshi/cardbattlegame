# TargetSelectionUI - スペル等の対象選択UI
extends Control
class_name TargetSelectionUI

## シグナル
signal target_selected(target_data: Dictionary)
signal selection_cancelled()

## UI要素
var panel: Panel = null
var target_list_label: Label = null
var instruction_label: Label = null

## 状態
var is_selecting: bool = false
var target_type: String = ""  # "creature", "player", "land"
var target_list: Array = []
var current_index: int = 0

## システム参照
var board_system = null
var player_system = null

func _ready():
	# 初期状態では非表示
	visible = false

## 初期化
func initialize(board_sys, player_sys):
	board_system = board_sys
	player_system = player_sys

## 対象選択を開始
func show_target_selection(type: String, targets: Array):
	if targets.is_empty():
		print("[TargetSelectionUI] 対象が空です")
		selection_cancelled.emit()
		return
	
	target_type = type
	target_list = targets
	current_index = 0
	is_selecting = true
	
	# UIを作成
	_create_ui()
	
	# 選択リストを更新
	_update_selection()
	
	visible = true
	print("[TargetSelectionUI] 対象選択開始: ", type, " (", targets.size(), "個)")

## UIを作成
func _create_ui():
	# 既存のUIをクリア
	for child in get_children():
		child.queue_free()
	
	# パネル作成
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(viewport_size.x - 400) / 2,
		(viewport_size.y - 300) / 2
	)
	
	add_child(panel)
	
	# VBoxContainer
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# タイトル
	var title_label = Label.new()
	match target_type:
		"creature":
			title_label.text = "対象のクリーチャーを選択"
		"player":
			title_label.text = "対象のプレイヤーを選択"
		"land":
			title_label.text = "対象の土地を選択"
		_:
			title_label.text = "対象を選択"
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)
	
	# 対象リスト
	target_list_label = Label.new()
	target_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	target_list_label.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(target_list_label)
	
	# 操作説明
	instruction_label = Label.new()
	instruction_label.text = "↑↓: 選択移動  Enter: 決定  Esc: キャンセル"
	instruction_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(instruction_label)

## 選択リストを更新
func _update_selection():
	if target_list.is_empty():
		return
	
	var text = ""
	
	for i in range(target_list.size()):
		var target = target_list[i]
		var prefix = "  "
		if i == current_index:
			prefix = "→ "
		
		var line = prefix
		
		match target_type:
			"creature":
				var creature_name = target.get("creature", {}).get("name", "???")
				var tile_index = target.get("tile_index", -1)
				line += "タイル %d: %s" % [tile_index, creature_name]
			
			"player":
				var player_id = target.get("player_id", -1)
				var player = target.get("player", {})
				var player_name = player.get("name", "")
				if player_name == "":
					player_name = "プレイヤー%d" % (player_id + 1)
				line += player_name
			
			"land":
				var tile_index = target.get("tile_index", -1)
				var element = target.get("element", "中立")
				var level = target.get("level", 1)
				line += "タイル %d: %s Lv%d" % [
					tile_index,
					element,
					level
				]
		
		text += line + "\n"
	
	if target_list_label:
		target_list_label.text = text
	
	# カメラを対象にフォーカス
	_focus_camera_on_current_target()

## カメラを現在の対象にフォーカス
func _focus_camera_on_current_target():
	if not board_system or target_list.is_empty():
		return
	
	var target = target_list[current_index]
	
	match target_type:
		"creature", "land":
			var tile_index = target.get("tile_index", -1)
			if tile_index >= 0 and board_system.tile_nodes.has(tile_index):
				var tile = board_system.tile_nodes[tile_index]
				if board_system.camera:
					var tile_pos = tile.global_position
					var camera_offset = Vector3(12, 15, 12)
					board_system.camera.position = tile_pos + camera_offset
					board_system.camera.look_at(tile_pos, Vector3.UP)
		
		"player":
			var player_id = target.get("player_id", -1)
			if player_id >= 0 and board_system.movement_controller:
				var player_tile = board_system.movement_controller.get_player_tile(player_id)
				if board_system.tile_nodes.has(player_tile):
					var tile = board_system.tile_nodes[player_tile]
					if board_system.camera:
						var tile_pos = tile.global_position
						var camera_offset = Vector3(12, 15, 12)
						board_system.camera.position = tile_pos + camera_offset
						board_system.camera.look_at(tile_pos, Vector3.UP)

## 入力処理
func _input(event):
	if not is_selecting:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_move_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_move_selection(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_confirm_selection()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_cancel_selection()
				get_viewport().set_input_as_handled()

## 選択を移動
func _move_selection(direction: int):
	if target_list.is_empty():
		return
	
	current_index = (current_index + direction) % target_list.size()
	if current_index < 0:
		current_index = target_list.size() - 1
	
	_update_selection()

## 選択を確定
func _confirm_selection():
	if target_list.is_empty():
		return
	
	var selected_target = target_list[current_index]
	print("[TargetSelectionUI] 対象選択確定: ", selected_target)
	
	hide_selection()
	target_selected.emit(selected_target)

## 選択をキャンセル
func _cancel_selection():
	print("[TargetSelectionUI] 対象選択キャンセル")
	hide_selection()
	selection_cancelled.emit()

## 選択UIを非表示
func hide_selection():
	is_selecting = false
	visible = false
	
	# UIをクリア
	for child in get_children():
		child.queue_free()
