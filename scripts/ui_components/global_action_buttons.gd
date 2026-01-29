# 右下に縦並びで配置（▲▼✓×）、左下に特殊ボタン
# ボタンは常に表示、機能がない時はグレーアウト
extends Control

class_name GlobalActionButtons

signal special_button_pressed()  # スペシャルボタン押下シグナル

# UI要素
var up_button: Button
var down_button: Button
var confirm_button: Button
var back_button: Button
var special_button: Button  # 左下の特殊ボタン（アルカナアーツ/ドミニオコマンド等）

# コールバック
var _confirm_callback: Callable = Callable()
var _back_callback: Callable = Callable()
var _up_callback: Callable = Callable()
var _down_callback: Callable = Callable()
var _special_callback: Callable = Callable()

# 特殊ボタンのテキスト
var _special_text: String = ""

# GameFlowManager参照（入力ロック用）
var game_flow_manager_ref = null

# 説明モード中フラグ（trueの場合、入力ロックを無視）
var explanation_mode_active: bool = false

# 定数
const BUTTON_SIZE = 280
const BUTTON_SPACING = 42
const MARGIN_RIGHT = 70
const MARGIN_BOTTOM = 70
const MARGIN_LEFT = 70


func _ready():
	_setup_ui()
	_update_button_states()


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
	
	# 特殊ボタン（左下、テキストは動的）
	special_button = _create_special_button("", Color(0.4, 0.2, 0.6))  # 紫色、専用スタイル
	special_button.pressed.connect(_on_special_pressed)
	add_child(special_button)
	
	_update_positions()
	get_tree().root.size_changed.connect(_update_positions)


func _create_button(text: String, color: Color, font_size: int) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.visible = true  # 常に表示
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	var corner_radius := int(BUTTON_SIZE / 2.0)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
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


## 特殊ボタン（アルカナアーツ用）専用作成 - 大きなフォントとスタイリッシュなデザイン
func _create_special_button(text: String, _color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.visible = true
	
	# グラデーション風の背景スタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.15, 0.7)  # 鮮やかな紫
	var corner_radius := int(BUTTON_SIZE / 2.0)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.border_width_top = 5
	style.border_width_bottom = 5
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_color = Color(1, 0.85, 0.4, 0.9)  # ゴールドの縁取り
	style.shadow_color = Color(0.2, 0.0, 0.3, 0.6)
	style.shadow_size = 8
	style.shadow_offset = Vector2(4, 4)
	button.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.6, 0.2, 0.8)  # 明るい紫
	hover_style.border_color = Color(1, 0.95, 0.6, 1)  # 明るいゴールド
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(0.35, 0.1, 0.5)  # 暗い紫
	pressed_style.shadow_size = 2
	pressed_style.shadow_offset = Vector2(1, 1)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled_style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	disabled_style.shadow_size = 0
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	# 大きなフォントサイズ
	button.add_theme_font_size_override("font_size", 120)
	button.add_theme_color_override("font_color", Color(1, 0.95, 0.7))  # クリーム色
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	button.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.15))
	button.add_theme_constant_override("outline_size", 4)  # 文字のアウトライン
	
	return button


func _update_positions():
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_size = viewport.get_visible_rect().size
	
	# 右下のボタン群
	var base_x = viewport_size.x - MARGIN_RIGHT - BUTTON_SIZE
	var back_y = viewport_size.y - MARGIN_BOTTOM - BUTTON_SIZE
	
	var confirm_y = back_y - BUTTON_SIZE - BUTTON_SPACING
	var down_y = confirm_y - BUTTON_SIZE - BUTTON_SPACING
	var up_y = down_y - BUTTON_SIZE - BUTTON_SPACING
	
	up_button.position = Vector2(base_x, up_y)
	down_button.position = Vector2(base_x, down_y)
	confirm_button.position = Vector2(base_x, confirm_y)
	back_button.position = Vector2(base_x, back_y)
	
	# 左下の特殊ボタン（×ボタンと同じ高さ）
	special_button.position = Vector2(MARGIN_LEFT, back_y)


## ボタンの有効/無効状態を更新（常に表示、機能がない時はグレーアウト）
func _update_button_states():
	up_button.disabled = not _up_callback.is_valid()
	down_button.disabled = not _down_callback.is_valid()
	confirm_button.disabled = not _confirm_callback.is_valid()
	back_button.disabled = not _back_callback.is_valid()
	special_button.disabled = not _special_callback.is_valid()
	special_button.text = _special_text if _special_callback.is_valid() else ""


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _confirm_callback.is_valid():
				_on_confirm_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
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


func _is_input_locked() -> bool:
	# 説明モード中はロックを無視
	if explanation_mode_active:
		return false
	if game_flow_manager_ref and game_flow_manager_ref.has_method("is_input_locked"):
		return game_flow_manager_ref.is_input_locked()
	return false


func _on_confirm_pressed():
	if _is_input_locked():
		return
	# 入力をロック（連打防止）
	if game_flow_manager_ref and game_flow_manager_ref.has_method("lock_input"):
		game_flow_manager_ref.lock_input()
	if _confirm_callback.is_valid():
		_confirm_callback.call()


func _on_back_pressed():
	if _is_input_locked():
		return
	# 入力をロック（連打防止）
	if game_flow_manager_ref and game_flow_manager_ref.has_method("lock_input"):
		game_flow_manager_ref.lock_input()
	if _back_callback.is_valid():
		_back_callback.call()


func _on_up_pressed():
	if _is_input_locked():
		return
	if _up_callback.is_valid():
		_up_callback.call()


func _on_down_pressed():
	if _is_input_locked():
		return
	if _down_callback.is_valid():
		_down_callback.call()


func _on_special_pressed():
	if _is_input_locked():
		return
	# 入力をロック（連打防止）
	if game_flow_manager_ref and game_flow_manager_ref.has_method("lock_input"):
		game_flow_manager_ref.lock_input()
	# シグナル発火（チュートリアル用）
	special_button_pressed.emit()
	if _special_callback.is_valid():
		_special_callback.call()


# === 公開メソッド ===

## ナビゲーションボタンを一括設定
## 有効なCallableを渡したボタンのみ有効になる
func setup(confirm_cb: Callable = Callable(), back_cb: Callable = Callable(), up_cb: Callable = Callable(), down_cb: Callable = Callable()):
	_confirm_callback = confirm_cb
	_back_callback = back_cb
	_up_callback = up_cb
	_down_callback = down_cb
	_update_button_states()


## 特殊ボタンを設定（テキストとコールバック）
func setup_special(text: String, callback: Callable):
	_special_text = text
	_special_callback = callback
	_update_button_states()


## 特殊ボタンをクリア
func clear_special():
	_special_text = ""
	_special_callback = Callable()
	_update_button_states()


## 全ボタンをクリア（全てグレーアウト）
func clear_all():
	_confirm_callback = Callable()
	_back_callback = Callable()
	_up_callback = Callable()
	_down_callback = Callable()
	_special_callback = Callable()
	_special_text = ""
	_update_button_states()
