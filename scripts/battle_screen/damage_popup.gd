class_name DamagePopup
extends Control

## ダメージポップアップ表示

const COLOR_DAMAGE = Color("#FF5252")   # ダメージ: 赤
const COLOR_HEAL = Color("#69F0AE")     # 回復: 緑
const COLOR_BUFF = Color("#40C4FF")     # バフ: 水色

var _label: Label
var _value: int = 0
var _popup_type: String = "damage"  # "damage", "heal", "buff"


func _ready() -> void:
	_setup_label()


func _setup_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	
	# フォント設定
	_label.add_theme_font_size_override("font_size", 32)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)


## ダメージポップアップを表示
func show_damage(value: int) -> void:
	_value = value
	_popup_type = "damage"
	_label.text = str(value)
	_label.add_theme_color_override("font_color", COLOR_DAMAGE)
	_animate()


## 回復ポップアップを表示
func show_heal(value: int) -> void:
	_value = value
	_popup_type = "heal"
	_label.text = "+" + str(value)
	_label.add_theme_color_override("font_color", COLOR_HEAL)
	_animate()


## バフポップアップを表示
func show_buff(text: String) -> void:
	_popup_type = "buff"
	_label.text = text
	_label.add_theme_color_override("font_color", COLOR_BUFF)
	_animate()


## アニメーション実行
func _animate() -> void:
	if not is_inside_tree():
		queue_free()
		return
	# 初期状態
	modulate.a = 1.0
	scale = Vector2.ONE
	var start_pos = position
	
	# Tweenアニメーション
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 上に浮かぶ
	tween.tween_property(self, "position:y", start_pos.y - 50, 0.8).set_ease(Tween.EASE_OUT)
	
	# スケールで強調
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.2)
	
	# フェードアウト
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.3)
	
	# 完了後に削除
	tween.chain().tween_callback(queue_free)
