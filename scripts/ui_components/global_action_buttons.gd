# グローバル決定/戻るボタン
# 右下に縦並びで配置、Enter/Escapeキーと連動
# 上下ボタンは選択場面でのみ表示
extends Control

class_name GlobalActionButtons

signal confirm_pressed
signal back_pressed
signal up_pressed
signal down_pressed

# UI要素
var up_button: Button
var down_button: Button
var confirm_button: Button
var back_button: Button

# 状態
var confirm_enabled: bool = false
var back_enabled: bool = false
var up_enabled: bool = false
var down_enabled: bool = false
var confirm_text: String = "決定"
var back_text: String = "戻る"

# 定数（固定サイズ）※1.4倍
const BUTTON_SIZE = 280  # 丸ボタンの直径（全ボタン共通）
const BUTTON_SPACING = 42  # ボタン間の間隔
const MARGIN_RIGHT = 70  # 右端からの距離
const MARGIN_BOTTOM = 70  # 下端からの距離


func _ready():
	_setup_ui()
	_update_button_states()


func _setup_ui():
	# 自身の設定
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000  # 常に最前面に表示
	
	# 上ボタン（一番上）
	up_button = _create_arrow_button("▲", Color(0.3, 0.4, 0.6))
	up_button.pressed.connect(_on_up_pressed)
	add_child(up_button)
	
	# 下ボタン
	down_button = _create_arrow_button("▼", Color(0.3, 0.4, 0.6))
	down_button.pressed.connect(_on_down_pressed)
	add_child(down_button)
	
	# 決定ボタン
	confirm_button = _create_circle_button("決定", Color(0.2, 0.6, 0.3))
	confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(confirm_button)
	
	# 戻るボタン（一番下）
	back_button = _create_circle_button("戻る", Color(0.5, 0.3, 0.3))
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)
	
	# 位置更新
	_update_positions()
	
	# 画面サイズ変更に対応
	get_tree().root.size_changed.connect(_update_positions)


func _create_circle_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE  # エンターキーでの誤発火を防止
	
	# 丸いスタイル
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
	
	# ホバースタイル
	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	button.add_theme_stylebox_override("hover", hover_style)
	
	# 押下スタイル
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# 無効スタイル
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled_style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	# フォント設定
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	
	return button


func _create_arrow_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	
	# 丸いスタイル（決定/戻ると同じサイズ）
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
	
	# ホバースタイル
	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	button.add_theme_stylebox_override("hover", hover_style)
	
	# 押下スタイル
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# 無効スタイル
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled_style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	# フォント設定（大きな三角形）
	button.add_theme_font_size_override("font_size", 100)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	
	# 初期状態は非表示
	button.visible = false
	
	return button


func _update_positions():
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_size = viewport.get_visible_rect().size
	
	# 右下基準位置（戻るボタンの位置から逆算）
	var base_x = viewport_size.x - MARGIN_RIGHT - BUTTON_SIZE
	var back_y = viewport_size.y - MARGIN_BOTTOM - BUTTON_SIZE
	
	# ボタン配置を計算
	var positions = _calculate_button_positions(base_x, back_y)
	
	up_button.position = positions.up
	down_button.position = positions.down
	confirm_button.position = positions.confirm
	back_button.position = positions.back


func _calculate_button_positions(base_x: float, back_y: float) -> Dictionary:
	# 下から上に配置：戻る → 決定 → ↓ → ↑（全て同じサイズ）
	var confirm_y = back_y - BUTTON_SIZE - BUTTON_SPACING
	var down_y = confirm_y - BUTTON_SIZE - BUTTON_SPACING
	var up_y = down_y - BUTTON_SIZE - BUTTON_SPACING
	
	return {
		"up": Vector2(base_x, up_y),
		"down": Vector2(base_x, down_y),
		"confirm": Vector2(base_x, confirm_y),
		"back": Vector2(base_x, back_y)
	}


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if confirm_enabled:
				_on_confirm_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if back_enabled:
				_on_back_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			if up_enabled:
				_on_up_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			if down_enabled:
				_on_down_pressed()
				get_viewport().set_input_as_handled()


func _on_confirm_pressed():
	if confirm_enabled:
		confirm_pressed.emit()


func _on_back_pressed():
	if back_enabled:
		back_pressed.emit()


func _on_up_pressed():
	if up_enabled:
		up_pressed.emit()


func _on_down_pressed():
	if down_enabled:
		down_pressed.emit()


# === 公開メソッド ===

## 決定ボタンの状態を設定
func set_confirm_state(enabled: bool, text: String = "決定"):
	confirm_enabled = enabled
	confirm_text = text
	_update_button_states()


## 戻るボタンの状態を設定
func set_back_state(enabled: bool, text: String = "戻る"):
	back_enabled = enabled
	back_text = text
	_update_button_states()


## 両方のボタンを一度に設定
func set_states(confirm_enabled_: bool, back_enabled_: bool, confirm_text_: String = "決定", back_text_: String = "戻る"):
	confirm_enabled = confirm_enabled_
	back_enabled = back_enabled_
	confirm_text = confirm_text_
	back_text = back_text_
	_update_button_states()


## 上下ボタンを有効化（選択場面で使用）
func enable_arrows():
	up_enabled = true
	down_enabled = true
	_update_button_states()


## 上下ボタンを無効化
func disable_arrows():
	up_enabled = false
	down_enabled = false
	_update_button_states()


## 両方のボタンを無効化
func disable_all():
	confirm_enabled = false
	back_enabled = false
	up_enabled = false
	down_enabled = false
	_update_button_states()


## ボタンの表示/非表示
func set_visible_buttons(is_visible: bool):
	confirm_button.visible = is_visible
	back_button.visible = is_visible


func _update_button_states():
	if confirm_button:
		confirm_button.disabled = not confirm_enabled
		confirm_button.text = confirm_text
	if back_button:
		back_button.disabled = not back_enabled
		back_button.text = back_text
	if up_button:
		up_button.visible = up_enabled
		up_button.disabled = not up_enabled
	if down_button:
		down_button.visible = down_enabled
		down_button.disabled = not down_enabled
