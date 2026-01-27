class_name SurrenderDialog
extends Control

## 降参確認ダイアログ

signal surrendered
signal cancelled

var bg: ColorRect
var panel: Panel
var is_open: bool = false

const PANEL_WIDTH = 900
const PANEL_HEIGHT = 500


func _ready():
	_build_ui()
	hide_dialog()
	get_tree().root.size_changed.connect(_update_position)


func _build_ui():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 背景（半透明黒）
	bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	
	# ダイアログパネル
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.98)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	# 内部コンテナ
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 50)
	inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.position = Vector2(60, 60)
	panel.add_child(inner_vbox)
	
	# タイトル
	var title = Label.new()
	title.text = "本当に降参しますか？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.custom_minimum_size = Vector2(780, 0)
	inner_vbox.add_child(title)
	
	# 説明
	var desc = Label.new()
	desc.text = "報酬は獲得できません。"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 48)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc.custom_minimum_size = Vector2(780, 0)
	inner_vbox.add_child(desc)
	
	# ボタンコンテナ
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 80)
	inner_vbox.add_child(button_container)
	
	# キャンセルボタン
	var cancel_btn = Button.new()
	cancel_btn.text = "キャンセル"
	cancel_btn.custom_minimum_size = Vector2(320, 120)
	cancel_btn.add_theme_font_size_override("font_size", 48)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_btn)
	
	# 降参ボタン
	var surrender_btn = Button.new()
	surrender_btn.text = "降参する"
	surrender_btn.custom_minimum_size = Vector2(320, 120)
	surrender_btn.add_theme_font_size_override("font_size", 48)
	surrender_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	surrender_btn.pressed.connect(_on_surrender_pressed)
	button_container.add_child(surrender_btn)
	
	_update_position()


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
		(viewport_size.y - PANEL_HEIGHT) / 2 - 100
	)


func show_dialog():
	print("[SurrenderDialog] show_dialog 呼び出し")
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


func hide_dialog():
	visible = false
	is_open = false


func _on_bg_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_cancel_pressed()


func _on_cancel_pressed():
	hide_dialog()
	cancelled.emit()


func _on_surrender_pressed():
	hide_dialog()
	surrendered.emit()