extends Control
class_name GameMenuButton

const GC = preload("res://scripts/game_constants.gd")


## ゲームメニューボタン（右上に配置）
## 押すとゲームメニューを表示する

signal menu_pressed

var button: Button

const BUTTON_SIZE = 180
const MARGIN_RIGHT = 30
const MARGIN_TOP = 30


func _ready():
	_build_ui()
	_update_position()
	get_tree().root.size_changed.connect(_update_position)


func _build_ui():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ボタン
	button = Button.new()
	button.text = "≡"
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.add_theme_font_size_override("font_size", GC.FONT_SIZE_MENU_BUTTON)
	button.modulate.a = 0.7
	button.pressed.connect(_on_button_pressed)
	add_child(button)


func _update_position():
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_size = viewport.get_visible_rect().size
	
	# 右上に配置
	var x = viewport_size.x - MARGIN_RIGHT - BUTTON_SIZE
	var y = MARGIN_TOP
	button.position = Vector2(x, y)


func _on_button_pressed():
	print("[GameMenuButton] ボタン押下")
	menu_pressed.emit()


## ボタンの有効/無効を切り替え
func set_enabled(enabled: bool):
	button.disabled = not enabled
