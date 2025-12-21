class_name SkillLabel
extends Control

## スキル名表示コンポーネント

const BACKGROUND_COLOR = Color(0.1, 0.08, 0.06, 0.85)  # 半透明の茶色
const TEXT_COLOR = Color.WHITE
const DISPLAY_DURATION = 1.5  # 表示時間

var _background: ColorRect
var _label: Label


func _ready() -> void:
	_setup_ui()
	visible = false


func _setup_ui() -> void:
	# 背景
	_background = ColorRect.new()
	_background.color = BACKGROUND_COLOR
	_background.custom_minimum_size = Vector2(300, 60)
	add_child(_background)
	
	# ラベル
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	
	# サイズ調整
	custom_minimum_size = Vector2(300, 60)


## スキル名を表示
func show_skill(skill_name: String, duration: float = DISPLAY_DURATION) -> void:
	_label.text = skill_name
	
	# サイズ調整
	var text_width = _label.get_theme_font("font").get_string_size(skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var min_width = max(text_width + 60, 300)
	_background.custom_minimum_size.x = min_width
	custom_minimum_size.x = min_width
	
	# ラベル位置調整
	_label.position = Vector2(0, 0)
	_label.size = _background.custom_minimum_size
	
	# アニメーション
	visible = true
	modulate.a = 0.0
	
	var tween = create_tween()
	# フェードイン
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	# 維持
	tween.tween_interval(duration)
	# フェードアウト
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false)


## 即座に非表示
func hide_skill() -> void:
	visible = false
	modulate.a = 0.0
