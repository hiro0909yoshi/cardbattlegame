# グローバル決定/戻るボタン
# 右下に縦並びで配置、Enter/Escapeキーと連動
extends Control

class_name GlobalActionButtons

signal confirm_pressed
signal back_pressed

# UI要素
var confirm_button: Button
var back_button: Button

# 状態
var confirm_enabled: bool = false
var back_enabled: bool = false
var confirm_text: String = "決定"
var back_text: String = "戻る"

# 定数（固定サイズ）
const BUTTON_SIZE = 200  # 丸ボタンの直径
const BUTTON_SPACING = 30  # ボタン間の間隔
const MARGIN_RIGHT = 50  # 右端からの距離
const MARGIN_BOTTOM = 50  # 下端からの距離


func _ready():
	_setup_ui()
	_update_button_states()


func _setup_ui():
	# 自身の設定
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 決定ボタン（上）
	confirm_button = _create_circle_button("決定", Color(0.2, 0.6, 0.3))
	confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(confirm_button)
	
	# 戻るボタン（下）
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
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	
	return button


func _update_positions():
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_size = viewport.get_visible_rect().size
	
	# 右下基準位置
	var base_x = viewport_size.x - MARGIN_RIGHT - BUTTON_SIZE
	var base_y = viewport_size.y - MARGIN_BOTTOM - BUTTON_SIZE * 2 - BUTTON_SPACING
	
	# ボタン配置（将来の左右入替に備えて抽象化）
	var positions = _calculate_button_positions(base_x, base_y)
	
	confirm_button.position = positions.confirm
	back_button.position = positions.back


func _calculate_button_positions(base_x: float, base_y: float) -> Dictionary:
	# 将来の設定で左右入替する場合はここを変更
	# GameSettings.button_layout == "left" の場合は左下に配置など
	
	return {
		"confirm": Vector2(base_x, base_y),  # 上
		"back": Vector2(base_x, base_y + BUTTON_SIZE + BUTTON_SPACING)  # 下
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


func _on_confirm_pressed():
	if confirm_enabled:
		confirm_pressed.emit()


func _on_back_pressed():
	if back_enabled:
		back_pressed.emit()


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


## 両方のボタンを無効化
func disable_all():
	confirm_enabled = false
	back_enabled = false
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
