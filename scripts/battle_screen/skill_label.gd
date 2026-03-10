class_name SkillLabel
extends Control

## スキル名表示コンポーネント（カードから飛び出すズームエフェクト）

const TEXT_COLOR = Color.WHITE
const DISPLAY_DURATION = 0.8  # 表示時間

var _label: Label

## 基準位置を保持（アニメーションで移動するためリセット用）
var _base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_setup_ui()
	visible = false


func _setup_ui() -> void:
	# メインテキスト
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(_label)


## スキル名をカードから飛び出すズームエフェクトで表示
func show_skill(skill_name: String, duration: float = DISPLAY_DURATION) -> void:
	if not is_inside_tree():
		return

	_label.text = skill_name

	# テキストサイズに合わせてラベルサイズ調整
	var text_width = _label.get_theme_font("font").get_string_size(
		skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36
	).x
	var label_width = text_width + 40
	var label_height = 60.0
	_label.position = Vector2(-label_width / 2, -label_height / 2)
	_label.size = Vector2(label_width, label_height)

	# 初期状態
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.3, 0.3)

	var tween = create_tween()
	tween.set_parallel(true)

	# バウンス拡大（0.3 → 3.5 → 3.0 のオーバーシュート）
	tween.tween_property(self, "scale", Vector2(3.5, 3.5), 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector2(3.0, 3.0), 0.1) \
		.set_ease(Tween.EASE_IN_OUT)

	# フェードイン
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

	# 維持後にフェードアウト
	tween.chain().tween_interval(duration)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(_on_animation_finished)


## アニメーション終了時にリセット
func _on_animation_finished() -> void:
	visible = false
	position = _base_position
	scale = Vector2.ONE


## 即座に非表示
func hide_skill() -> void:
	visible = false
	modulate.a = 0.0


func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos
