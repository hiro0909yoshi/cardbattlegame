class_name TransitionLayer
extends CanvasLayer

## 画面遷移用レイヤー

signal fade_out_completed
signal fade_in_completed

const FADE_DURATION = 0.25

var _color_rect: ColorRect
var _battle_label: Label


func _ready() -> void:
	layer = 100  # 最前面
	_setup_ui()


func _setup_ui() -> void:
	# フェード用の黒い背景
	_color_rect = ColorRect.new()
	_color_rect.color = Color.BLACK
	_color_rect.color.a = 0.0
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)
	
	# "BATTLE!" テキスト
	_battle_label = Label.new()
	_battle_label.text = "BATTLE!"
	_battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_battle_label.set_anchors_preset(Control.PRESET_CENTER)
	_battle_label.add_theme_font_size_override("font_size", 64)
	_battle_label.add_theme_color_override("font_color", Color.WHITE)
	_battle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_battle_label.add_theme_constant_override("outline_size", 6)
	_battle_label.modulate.a = 0.0
	_battle_label.pivot_offset = _battle_label.size / 2
	add_child(_battle_label)


## フェードアウト（画面を暗くする）
func fade_out(show_battle_text: bool = true):
	if not is_inside_tree():
		fade_out_completed.emit()
		return
	var tween = create_tween()
	
	# 画面を暗くする
	tween.tween_property(_color_rect, "color:a", 1.0, FADE_DURATION)
	
	# BATTLE!テキスト表示
	if show_battle_text:
		tween.tween_callback(func(): _show_battle_text())
		tween.tween_interval(0.4)
	
	await tween.finished
	fade_out_completed.emit()


## フェードイン（画面を明るくする）
func fade_in():
	if not is_inside_tree():
		fade_in_completed.emit()
		return
	# BATTLE!テキストを非表示
	_battle_label.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, FADE_DURATION)
	
	await tween.finished
	fade_in_completed.emit()


## BATTLE!テキストを表示
func _show_battle_text() -> void:
	if not is_inside_tree():
		return
	_battle_label.modulate.a = 0.0
	_battle_label.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_battle_label, "modulate:a", 1.0, 0.15)
	tween.tween_property(_battle_label, "scale", Vector2(1.2, 1.2), 0.15)
	tween.chain().tween_property(_battle_label, "scale", Vector2.ONE, 0.1)


## クイックフェード（テキストなし）
func quick_fade_out():
	if not is_inside_tree():
		return
	var tween = create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, 0.15)
	await tween.finished


func quick_fade_in():
	if not is_inside_tree():
		return
	_battle_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, 0.15)
	await tween.finished
