class_name BattleScreen
extends CanvasLayer

## バトル画面メインコントローラー

signal battle_intro_completed
@warning_ignore("unused_signal")
signal phase_completed(phase_name: String)  # 将来使用予定
signal battle_ended(result: int)

const SCREEN_LAYER = 90

# 子ノード
var _background: ColorRect
var _attacker_display: BattleCreatureDisplay
var _defender_display: BattleCreatureDisplay
var _vs_label: Label
var _effect_layer: Control

# データ
var _attacker_data: Dictionary = {}
var _defender_data: Dictionary = {}


func _ready() -> void:
	layer = SCREEN_LAYER
	_setup_ui()


func _setup_ui() -> void:
	# 背景
	_background = ColorRect.new()
	_background.color = Color(0.1, 0.1, 0.15, 0.95)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	
	# メインコンテナ
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	
	# 攻撃側（左）
	_attacker_display = BattleCreatureDisplay.new()
	container.add_child(_attacker_display)
	
	# 防御側（右）
	_defender_display = BattleCreatureDisplay.new()
	container.add_child(_defender_display)
	
	# VSラベル（中央）
	_vs_label = Label.new()
	_vs_label.text = "VS"
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vs_label.add_theme_font_size_override("font_size", 48)
	_vs_label.add_theme_color_override("font_color", Color.WHITE)
	_vs_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_vs_label.add_theme_constant_override("outline_size", 4)
	_vs_label.modulate.a = 0.0
	container.add_child(_vs_label)
	
	# エフェクトレイヤー
	_effect_layer = Control.new()
	_effect_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effect_layer)
	
	# 初期配置
	_layout_ui()


func _layout_ui() -> void:
	var viewport_size = Vector2(1920, 1080)  # デフォルト解像度
	if get_viewport():
		viewport_size = get_viewport().get_visible_rect().size
	
	var center_y = viewport_size.y / 2 - 150
	
	# 攻撃側（左）
	_attacker_display.position = Vector2(viewport_size.x * 0.2, center_y)
	_attacker_display._original_position = _attacker_display.position
	
	# 防御側（右）
	_defender_display.position = Vector2(viewport_size.x * 0.65, center_y)
	_defender_display._original_position = _defender_display.position
	
	# VS（中央）
	_vs_label.position = Vector2(viewport_size.x / 2 - 30, center_y + 100)


## バトルを初期化
func initialize(attacker_data: Dictionary, defender_data: Dictionary) -> void:
	_attacker_data = attacker_data
	_defender_data = defender_data
	
	_attacker_display.setup(attacker_data, true)
	_defender_display.setup(defender_data, false)


## イントロ演出を再生
func play_intro():
	# カードをスライドイン（順次実行）
	await _attacker_display.slide_in(true)
	await _defender_display.slide_in(false)
	
	# VS表示
	await _show_vs_label()
	
	battle_intro_completed.emit()


func _show_vs_label():
	_vs_label.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_vs_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(_vs_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.chain().tween_property(_vs_label, "scale", Vector2.ONE, 0.1)
	await tween.finished


## スキル発動演出
func show_skill_activation(side: String, skill_name: String):
	var display = _attacker_display if side == "attacker" else _defender_display
	display.show_skill(skill_name)
	await get_tree().create_timer(0.8).timeout


## HP変更演出
func show_hp_change(side: String, new_data: Dictionary):
	var display = _attacker_display if side == "attacker" else _defender_display
	await display.update_hp(new_data)


## AP変更演出
func show_ap_change(side: String, new_ap: int) -> void:
	var display = _attacker_display if side == "attacker" else _defender_display
	display.update_ap(new_ap)


## 攻撃演出
func show_attack(attacker_side: String, damage: int):
	var attacker = _attacker_display if attacker_side == "attacker" else _defender_display
	var defender = _defender_display if attacker_side == "attacker" else _attacker_display
	
	# 攻撃モーション
	await attacker.play_attack_animation()
	
	# 被ダメージ演出
	defender.play_damage_animation()
	defender.show_damage_popup(damage)
	
	await get_tree().create_timer(0.3).timeout


## 結果演出
func show_result(result: int):
	# result: BattleSystem.ATTACKER_WIN, DEFENDER_WIN, etc.
	match result:
		0:  # ATTACKER_WIN
			await _defender_display.play_defeat_animation()
		1:  # DEFENDER_WIN
			await _attacker_display.play_defeat_animation()
		2:  # BOTH_DEFEATED
			# 順次実行（GDScriptでは並列awaitは難しい）
			await _attacker_display.play_defeat_animation()
			await _defender_display.play_defeat_animation()
		3:  # ATTACKER_SURVIVED
			# 特に演出なし、またはテキスト表示
			pass
	
	await get_tree().create_timer(0.5).timeout
	battle_ended.emit(result)


## バトル画面を閉じる
func close():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()


## ダメージポップアップを表示
func show_damage_popup(side: String, amount: int) -> void:
	var display = _attacker_display if side == "attacker" else _defender_display
	display.show_damage_popup(amount)


## 回復ポップアップを表示
func show_heal_popup(side: String, amount: int) -> void:
	var display = _attacker_display if side == "attacker" else _defender_display
	display.show_heal_popup(amount)


## バフポップアップを表示
func show_buff_popup(side: String, text: String) -> void:
	var display = _attacker_display if side == "attacker" else _defender_display
	display.show_buff_popup(text)
