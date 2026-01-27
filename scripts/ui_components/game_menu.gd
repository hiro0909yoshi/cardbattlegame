class_name GameMenu
extends Control

## ゲームメニュー
## 画面中央に表示される

signal settings_selected
signal help_selected
signal surrender_selected
signal menu_closed

var bg: ColorRect
var panel: Panel
var button_container: VBoxContainer
var is_open: bool = false

const PANEL_WIDTH = 1200
const PANEL_HEIGHT = 1100


func _ready():
	_build_ui()
	hide_menu()
	get_tree().root.size_changed.connect(_update_position)


func _build_ui():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 背景（半透明黒、クリックで閉じる用）
	bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	
	# パネル
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	# ボタンコンテナ
	button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 60)
	button_container.position = Vector2(80, 80)
	panel.add_child(button_container)
	
	# メニュー項目
	_add_menu_button("ゲーム設定", _on_settings_pressed)
	_add_menu_button("ヘルプ", _on_help_pressed)
	_add_separator()
	_add_menu_button("降参", _on_surrender_pressed, Color(0.9, 0.3, 0.3))
	
	_update_position()


func _add_menu_button(text: String, callback: Callable, color: Color = Color.WHITE):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(1040, 240)
	button.add_theme_font_size_override("font_size", 96)
	button.add_theme_color_override("font_color", color)
	button.pressed.connect(callback)
	button_container.add_child(button)


func _add_separator():
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(1040, 40)
	button_container.add_child(sep)


func _update_position():
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_size = viewport.get_visible_rect().size
	
	# 背景を画面全体に
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	
	# パネルを画面中央より少し上に
	panel.position = Vector2(
		(viewport_size.x - PANEL_WIDTH) / 2,
		(viewport_size.y - PANEL_HEIGHT) / 2 - 200
	)


func show_menu():
	print("[GameMenu] show_menu 呼び出し")
	_update_position()
	visible = true
	is_open = true
	
	# アニメーション
	panel.modulate.a = 0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = Vector2(PANEL_WIDTH / 2.0, PANEL_HEIGHT / 2.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15)
	
	print("[GameMenu] メニュー表示完了")


func hide_menu():
	visible = false
	is_open = false
	menu_closed.emit()


func _on_bg_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		hide_menu()


func _on_settings_pressed():
	hide_menu()
	settings_selected.emit()


func _on_help_pressed():
	hide_menu()
	help_selected.emit()


func _on_surrender_pressed():
	hide_menu()
	surrender_selected.emit()
