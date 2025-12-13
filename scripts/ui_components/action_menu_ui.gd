class_name ActionMenuUI
extends Control

## 汎用アクションメニューUI
## 領地コマンド、秘術選択などで共通使用

# シグナル
signal item_selected(index: int)
signal selection_cancelled
signal selection_changed(index: int, data: Variant)  # 選択変更時（カメラフォーカス等に使用）

# UI要素
var panel: Panel = null
var buttons: Array = []
var current_index: int = 0

# 設定
var items: Array = []  # {text, color, icon, disabled, data}
var ui_manager_ref = null

# 表示設定
var panel_width: int = 450
var panel_height: int = 600
var button_height: int = 100
var button_spacing: int = 20
var font_size: int = 36
var position_left: bool = true  # true=左側, false=右側


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process_unhandled_key_input(true)
	visible = false


func _unhandled_key_input(event):
	if not visible or items.is_empty():
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_select_previous()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_select_next()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_confirm_selection()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_C:
				_cancel_selection()
				get_viewport().set_input_as_handled()


## メニューを表示
## items_data: [{text, color, icon, disabled, data}, ...]
func show_menu(items_data: Array, title: String = ""):
	items = items_data
	current_index = 0
	
	# 最初の有効な項目を選択
	for i in range(items.size()):
		if not items[i].get("disabled", false):
			current_index = i
			break
	
	_create_panel()
	_create_buttons(title)
	_update_highlight()
	
	visible = true
	
	# グローバルナビゲーション有効化（上下/決定/戻る）
	if ui_manager_ref:
		ui_manager_ref.enable_navigation(
			func(): _confirm_selection(),  # 決定
			func(): _cancel_selection(),   # 戻る
			func(): _select_previous(),    # 上
			func(): _select_next()         # 下
		)


## メニューを非表示
func hide_menu():
	visible = false
	if panel:
		panel.queue_free()
		panel = null
	buttons.clear()
	items.clear()
	
	# グローバルナビゲーション無効化
	if ui_manager_ref:
		ui_manager_ref.disable_navigation()


## UIManager参照を設定
func set_ui_manager(manager) -> void:
	ui_manager_ref = manager


## 左側/右側配置を設定
func set_position_left(left: bool):
	position_left = left


## サイズを設定
func set_menu_size(width: int, height: int, btn_height: int = 100, fnt_size: int = 36, btn_spacing: int = 20):
	panel_width = width
	panel_height = height
	button_height = btn_height
	font_size = fnt_size
	button_spacing = btn_spacing


func _create_panel():
	if panel:
		panel.queue_free()
	
	panel = Panel.new()
	panel.name = "ActionMenuPanel"
	
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 30
	var nav_button_width = 200  # グローバルナビゲーションボタンの幅
	
	var panel_x: float
	if position_left:
		panel_x = margin
	else:
		# 上下ボタンの左側に配置
		panel_x = viewport_size.x - panel_width - margin - nav_button_width - 300
	
	var panel_y = (viewport_size.y - panel_height) / 2 - 150
	
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_width, panel_height)
	panel.z_index = 1000
	
	# パネルスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.5, 0.5, 0.5, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	
	add_child(panel)


func _create_buttons(title: String):
	buttons.clear()
	
	var button_y = 20
	var button_width = panel_width - 40
	
	# タイトルラベル（オプション）
	if not title.is_empty():
		var title_label = Label.new()
		title_label.text = title
		title_label.position = Vector2(20, button_y)
		title_label.size = Vector2(button_width, 40)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", font_size)
		title_label.add_theme_color_override("font_color", Color(1, 1, 1))
		panel.add_child(title_label)
		button_y += 50
	
	for i in range(items.size()):
		var item = items[i]
		var btn = _create_button(item, Vector2(20, button_y), Vector2(button_width, button_height), i)
		panel.add_child(btn)
		buttons.append(btn)
		button_y += button_height + button_spacing


func _create_button(item: Dictionary, pos: Vector2, size: Vector2, index: int) -> Button:
	var btn = Button.new()
	
	var icon_text = item.get("icon", "")
	var text = item.get("text", "項目")
	btn.text = icon_text + " " + text if not icon_text.is_empty() else text
	
	btn.position = pos
	btn.size = size
	btn.disabled = item.get("disabled", false)
	btn.add_theme_font_size_override("font_size", font_size)
	
	# ボタンスタイル
	var color = item.get("color", Color(0.3, 0.3, 0.3))
	var style = StyleBoxFlat.new()
	style.bg_color = color if not btn.disabled else Color(0.2, 0.2, 0.2, 0.5)
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_color = Color(1, 1, 1, 0.3)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("normal", style)
	
	# 無効時スタイル
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.15, 0.7)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	# クリックイベント
	btn.pressed.connect(func(): _on_button_pressed(index))
	
	return btn


func _update_highlight():
	for i in range(buttons.size()):
		var btn = buttons[i]
		var item = items[i]
		var is_selected = (i == current_index)
		var is_disabled = item.get("disabled", false)
		
		var color = item.get("color", Color(0.3, 0.3, 0.3))
		var style = StyleBoxFlat.new()
		style.bg_color = color if not is_disabled else Color(0.2, 0.2, 0.2, 0.5)
		style.corner_radius_top_left = 15
		style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 15
		style.corner_radius_bottom_right = 15
		
		if is_selected and not is_disabled:
			# 選択中：黄色の太い枠
			style.border_width_top = 6
			style.border_width_bottom = 6
			style.border_width_left = 6
			style.border_width_right = 6
			style.border_color = Color(1, 1, 0, 1)
		else:
			# 非選択：通常の枠
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_color = Color(1, 1, 1, 0.3)
		
		btn.add_theme_stylebox_override("normal", style)


func _select_previous():
	if items.is_empty():
		return
	
	var start = current_index
	current_index = (current_index - 1 + items.size()) % items.size()
	
	# 有効な項目を探す（ループ）
	while items[current_index].get("disabled", false) and current_index != start:
		current_index = (current_index - 1 + items.size()) % items.size()
	
	_update_highlight()
	_emit_selection_changed()


func _select_next():
	if items.is_empty():
		return
	
	var start = current_index
	current_index = (current_index + 1) % items.size()
	
	# 有効な項目を探す（ループ）
	while items[current_index].get("disabled", false) and current_index != start:
		current_index = (current_index + 1) % items.size()
	
	_update_highlight()
	_emit_selection_changed()


func _emit_selection_changed():
	if items.is_empty() or current_index < 0 or current_index >= items.size():
		return
	var data = items[current_index].get("data", null)
	selection_changed.emit(current_index, data)


func _confirm_selection():
	if items.is_empty():
		return
	
	if items[current_index].get("disabled", false):
		return
	
	var selected_index = current_index
	hide_menu()
	item_selected.emit(selected_index)


func _cancel_selection():
	hide_menu()
	selection_cancelled.emit()
	item_selected.emit(-1)


func _on_button_pressed(index: int):
	if index < 0 or index >= items.size():
		return
	
	if items[index].get("disabled", false):
		return
	
	current_index = index
	_confirm_selection()
