class_name BattleScreen
extends CanvasLayer

## バトル画面メインコントローラー

signal battle_intro_completed
@warning_ignore("unused_signal")
signal phase_completed(phase_name: String)  # 将来使用予定
signal battle_ended(result: int)
signal click_received  # クリック待ち用

const SCREEN_LAYER = 90

# 子ノード
var _background: ColorRect
var _attacker_display: BattleCreatureDisplay
var _defender_display: BattleCreatureDisplay
var _attacker_hp_bar: HpApBar  # 固定位置のHPバー
var _defender_hp_bar: HpApBar  # 固定位置のHPバー
var _vs_label: Label
var _effect_layer: Control
var _click_area: Control  # クリック受付用

# データ
var _attacker_data: Dictionary = {}
var _defender_data: Dictionary = {}

# クリック待ち状態
var _waiting_for_click: bool = false


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
	
	# 固定位置のHPバー（攻撃側）
	_attacker_hp_bar = HpApBar.new()
	container.add_child(_attacker_hp_bar)
	
	# 固定位置のHPバー（防御側）
	_defender_hp_bar = HpApBar.new()
	container.add_child(_defender_hp_bar)
	
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
	
	# クリック受付エリア（最前面）
	_click_area = Control.new()
	_click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_area.gui_input.connect(_on_click_area_input)
	add_child(_click_area)
	_click_area.visible = false
	
	# 初期配置
	_layout_ui()


## クリック入力処理
func _on_click_area_input(event: InputEvent) -> void:
	if _waiting_for_click and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_waiting_for_click = false
			_click_area.visible = false
			click_received.emit()


## クリック待ち
func wait_for_click():
	_waiting_for_click = true
	_click_area.visible = true
	await click_received


func _layout_ui() -> void:
	var viewport_size = Vector2(1920, 1080)  # デフォルト解像度
	if get_viewport():
		viewport_size = get_viewport().get_visible_rect().size
	
	# カードサイズ（3.9倍スケール）
	var card_width = 220 * 3.9
	var card_height = 293 * 3.9
	
	var center_y = viewport_size.y / 2 - 150 - 500 - 50  # 550ピクセル上に（さらに50px上）
	
	# 画面中央を基準に左右均等配置
	var center_x = viewport_size.x / 2
	var card_spacing = 300  # カード間のスペース（片側300px = 合計600px）
	
	# 攻撃側（左）- カードの右端が中央から少し左
	var attacker_x = center_x - card_spacing - card_width
	_attacker_display.position = Vector2(attacker_x, center_y)
	_attacker_display._original_position = _attacker_display.position
	
	# 防御側（右）- カードの左端が中央から少し右
	var defender_x = center_x + card_spacing
	_defender_display.position = Vector2(defender_x, center_y)
	_defender_display._original_position = _defender_display.position
	
	# VS（中央）
	_vs_label.position = Vector2(center_x - 30, center_y + card_height / 2 - 50)
	
	# HPバー固定位置（画面下部、片側300px = 合計600px離す）
	var hp_bar_width = 1040  # HP_BAR_WIDTH
	var hp_bar_y = viewport_size.y - 280  # 画面下から280px
	var hp_bar_spacing = 300  # HPバーの中央からの距離
	
	# 攻撃側HPバー - 中央から左に300px
	var attacker_hp_x = center_x - hp_bar_spacing - hp_bar_width
	_attacker_hp_bar.position = Vector2(attacker_hp_x, hp_bar_y)
	
	# 防御側HPバー - 中央から右に300px
	var defender_hp_x = center_x + hp_bar_spacing
	_defender_hp_bar.position = Vector2(defender_hp_x, hp_bar_y)


## バトルを初期化
func initialize(attacker_data: Dictionary, defender_data: Dictionary) -> void:
	_attacker_data = attacker_data
	_defender_data = defender_data
	
	# カード表示（HPバーなし）
	_attacker_display.setup(attacker_data, true, false)
	_defender_display.setup(defender_data, false, false)
	
	# 固定位置のHPバーを初期化
	_init_hp_bar(_attacker_hp_bar, attacker_data)
	_init_hp_bar(_defender_hp_bar, defender_data)


## HPバーを初期化
func _init_hp_bar(hp_bar: HpApBar, data: Dictionary) -> void:
	var hp_data = {
		"base_hp": data.get("hp", 0),
		"base_up_hp": data.get("base_up_hp", 0),
		"item_bonus_hp": data.get("item_bonus_hp", 0),
		"resonance_bonus_hp": data.get("resonance_bonus_hp", 0),
		"temporary_bonus_hp": data.get("temporary_bonus_hp", 0),
		"spell_bonus_hp": data.get("spell_bonus_hp", 0),
		"land_bonus_hp": data.get("land_bonus_hp", 0),
		"current_hp": data.get("current_hp", data.get("hp", 0)),
		"display_max": _calculate_display_max(data)
	}
	hp_bar.set_hp_data(hp_data)
	hp_bar.set_ap(data.get("current_ap", data.get("ap", 0)))


func _calculate_display_max(data: Dictionary) -> int:
	var total = data.get("hp", 0) + \
				data.get("base_up_hp", 0) + \
				data.get("item_bonus_hp", 0) + \
				data.get("resonance_bonus_hp", 0) + \
				data.get("temporary_bonus_hp", 0) + \
				data.get("spell_bonus_hp", 0) + \
				data.get("land_bonus_hp", 0)
	return max(total, 100)


## イントロ演出を再生
func play_intro():
	# カードをスライドイン（順次実行）
	await _attacker_display.slide_in(true)
	await _defender_display.slide_in(false)
	
	# VS表示
	await _show_vs_label()
	
	# クリック待ち
	await wait_for_click()
	
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
	await get_tree().create_timer(1.5).timeout


## HP変更演出（固定位置のHPバーを使用）
func show_hp_change(side: String, new_data: Dictionary):
	var hp_bar = _attacker_hp_bar if side == "attacker" else _defender_hp_bar
	var hp_data = {
		"base_hp": new_data.get("base_hp", 0),
		"base_up_hp": new_data.get("base_up_hp", 0),
		"item_bonus_hp": new_data.get("item_bonus_hp", 0),
		"resonance_bonus_hp": new_data.get("resonance_bonus_hp", 0),
		"temporary_bonus_hp": new_data.get("temporary_bonus_hp", 0),
		"spell_bonus_hp": new_data.get("spell_bonus_hp", 0),
		"land_bonus_hp": new_data.get("land_bonus_hp", 0),
		"current_hp": new_data.get("current_hp", 0),
		"display_max": new_data.get("display_max", 100)
	}
	await hp_bar.animate_hp_change(hp_data)


## AP変更演出（固定位置のHPバーを使用）
func show_ap_change(side: String, new_ap: int):
	var hp_bar = _attacker_hp_bar if side == "attacker" else _defender_hp_bar
	await hp_bar.animate_ap_change(new_ap)


## クリーチャー表示更新（変身時など）
func update_creature_display(side: String, new_data: Dictionary):
	var display = _attacker_display if side == "attacker" else _defender_display
	var hp_bar = _attacker_hp_bar if side == "attacker" else _defender_hp_bar
	
	# カード表示を更新
	display.update_creature(new_data)
	
	# HP/APバーも更新
	var display_max = new_data.get("hp", 0) + \
		new_data.get("base_up_hp", 0) + \
		new_data.get("item_bonus_hp", 0) + \
		new_data.get("resonance_bonus_hp", 0) + \
		new_data.get("temporary_bonus_hp", 0) + \
		new_data.get("spell_bonus_hp", 0) + \
		new_data.get("land_bonus_hp", 0)
	var hp_data = {
		"base_hp": new_data.get("hp", 0),
		"base_up_hp": new_data.get("base_up_hp", 0),
		"item_bonus_hp": new_data.get("item_bonus_hp", 0),
		"resonance_bonus_hp": new_data.get("resonance_bonus_hp", 0),
		"temporary_bonus_hp": new_data.get("temporary_bonus_hp", 0),
		"spell_bonus_hp": new_data.get("spell_bonus_hp", 0),
		"land_bonus_hp": new_data.get("land_bonus_hp", 0),
		"current_hp": new_data.get("current_hp", new_data.get("hp", 0)),
		"display_max": display_max
	}
	print("[update_creature_display] side:", side, " display_max:", display_max, " current_hp:", hp_data["current_hp"])
	hp_bar.set_hp_data(hp_data)
	hp_bar.set_ap(new_data.get("current_ap", new_data.get("ap", 0)))


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
