# 右下に縦並びで配置、Enter/Escapeキーと連動
# ボタンはアイコン固定（✓、✕、▲、▼）、コールバックのみ設定
extends Control

class_name GlobalActionButtons

# UI要素
var up_button: Button
var down_button: Button
var confirm_button: Button
var back_button: Button

# コールバック
var _confirm_callback: Callable = Callable()
var _back_callback: Callable = Callable()
var _up_callback: Callable = Callable()
var _down_callback: Callable = Callable()

# 定数
const BUTTON_SIZE = 280
const BUTTON_SPACING = 42
const MARGIN_RIGHT = 70
const MARGIN_BOTTOM = 70


func _ready():
	_setup_ui()
	_update_visibility()


func _setup_ui():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	
	# 上ボタン（▲）
	up_button = _create_button("▲", Color(0.3, 0.4, 0.6), 100)
	up_button.pressed.connect(_on_up_pressed)
	add_child(up_button)
	
	# 下ボタン（▼）
	down_button = _create_button("▼", Color(0.3, 0.4, 0.6), 100)
	down_button.pressed.connect(_on_down_pressed)
	add_child(down_button)
	
	# 決定ボタン（✓）
	confirm_button = _create_button("✓", Color(0.2, 0.6, 0.3), 120)
	confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(confirm_button)
	
	# 戻るボタン（✕）
	back_button = _create_button("✕", Color(0.6, 0.3, 0.3), 100)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)
	
	_update_positions()
	get_tree().root.size_changed.connect(_update_positions)


func _create_button(text: String, color: Color, font_size: int) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = BUTTON_SIZE / 2
	style.corner_radius_top_right = BUTTON_SIZE / 2
	style.corner_radius_bottom_left = BUTTON_SIZE / 2
	style.corner_radius_bottom_right = BUTTON_SIZE / 2
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(1, 1, 1, 0.5)
	button.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled_style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	
	return button


func _update_positions():
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_size = viewport.get_visible_rect().size
	
	var base_x = viewport_size.x - MARGIN_RIGHT - BUTTON_SIZE
	var back_y = viewport_size.y - MARGIN_BOTTOM - BUTTON_SIZE
	
	var confirm_y = back_y - BUTTON_SIZE - BUTTON_SPACING
	var down_y = confirm_y - BUTTON_SIZE - BUTTON_SPACING
	var up_y = down_y - BUTTON_SIZE - BUTTON_SPACING
	
	up_button.position = Vector2(base_x, up_y)
	down_button.position = Vector2(base_x, down_y)
	confirm_button.position = Vector2(base_x, confirm_y)
	back_button.position = Vector2(base_x, back_y)


func _update_visibility():
	up_button.visible = _up_callback.is_valid()
	down_button.visible = _down_callback.is_valid()
	confirm_button.visible = _confirm_callback.is_valid()
	back_button.visible = _back_callback.is_valid()


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _confirm_callback.is_valid():
				print("[GlobalActionButtons] ENTER pressed, calling confirm")
				_on_confirm_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			print("[GlobalActionButtons] ESC pressed, back_callback.is_valid=%s" % _back_callback.is_valid())
			if _back_callback.is_valid():
				_on_back_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			if _up_callback.is_valid():
				_on_up_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			if _down_callback.is_valid():
				_on_down_pressed()
				get_viewport().set_input_as_handled()


func _on_confirm_pressed():
	if _confirm_callback.is_valid():
		_confirm_callback.call()


func _on_back_pressed():
	if _back_callback.is_valid():
		_back_callback.call()


func _on_up_pressed():
	if _up_callback.is_valid():
		_up_callback.call()


func _on_down_pressed():
	if _down_callback.is_valid():
		_down_callback.call()


# === 公開メソッド ===

## ナビゲーションボタンを一括設定
## 有効なCallableを渡したボタンのみ表示される
func setup(confirm_cb: Callable = Callable(), back_cb: Callable = Callable(), up_cb: Callable = Callable(), down_cb: Callable = Callable()):
	print("[GlobalActionButtons] setup: confirm=%s, back=%s, up=%s, down=%s" % [confirm_cb.is_valid(), back_cb.is_valid(), up_cb.is_valid(), down_cb.is_valid()])
	_confirm_callback = confirm_cb
	_back_callback = back_cb
	_up_callback = up_cb
	_down_callback = down_cb
	_update_visibility()
	print("[GlobalActionButtons] after _update_visibility: back_button.visible=%s" % back_button.visible)


## 全ボタンをクリア
func clear_all():
	print("[GlobalActionButtons] clear_all() called")
	_confirm_callback = Callable()
	_back_callback = Callable()
	_up_callback = Callable()
	_down_callback = Callable()
	_update_visibility()
