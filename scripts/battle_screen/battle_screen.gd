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
	_vs_label.add_theme_font_size_override("font_size", 100)
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
	_attacker_display.original_position = _attacker_display.position
	
	# 防御側（右）- カードの左端が中央から少し右
	var defender_x = center_x + card_spacing
	_defender_display.position = Vector2(defender_x, center_y)
	_defender_display.original_position = _defender_display.position
	
	# VS（中央）
	_vs_label.position = Vector2(center_x - 30, center_y + card_height / 2 - 50)
	
	# HPバー固定位置（画面下部、片側300px = 合計600px離す）
	var hp_bar_width = 1040  # HP_BAR_WIDTH
	var hp_bar_y = viewport_size.y - 360  # 画面下から360px
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


## 攻撃演出（光収束 → 攻撃モーション → 光の玉発射）
func show_attack(attacker_side: String, damage: int):
	var attacker = _attacker_display if attacker_side == "attacker" else _defender_display
	var defender = _defender_display if attacker_side == "attacker" else _attacker_display

	var scaled_size = BattleCreatureDisplay.CARD_DISPLAY_SIZE * BattleCreatureDisplay.CARD_SCALE
	var attacker_center = attacker.position + scaled_size / 2
	var defender_center = defender.position + scaled_size / 2

	# Phase 1: エネルギー収束（0.5s）- 光の粒子が集まり、中央の玉が大きくなる
	var orb = _create_energy_orb(attacker_center)
	_spawn_gathering_particles(attacker_center, 0.5)
	await _animate_orb_charge(orb, 0.5)

	# Phase 2: 攻撃モーション（0.2s）
	await attacker.play_attack_animation()

	# Phase 3: 光の玉が敵に飛ぶ（0.3s）
	await _animate_orb_travel(orb, attacker_center, defender_center, 0.3)

	# 着弾：ダメージ演出（ポップアップはbattle_execution側で表示）
	orb.queue_free()
	defender.play_damage_animation()

	await get_tree().create_timer(0.15).timeout


## 反射攻撃演出（防御側→攻撃側に光玉を跳ね返す）
func show_reflect_attack(defender_side: String):
	var defender = _attacker_display if defender_side == "attacker" else _defender_display
	var attacker = _defender_display if defender_side == "attacker" else _attacker_display

	var scaled_size = BattleCreatureDisplay.CARD_DISPLAY_SIZE * BattleCreatureDisplay.CARD_SCALE
	var defender_center = defender.position + scaled_size / 2
	var attacker_center = attacker.position + scaled_size / 2

	# 反射の光玉を生成（赤系）
	var orb = _create_reflect_orb(defender_center)

	# 反射チャージ（短め、0.3s）
	await _animate_reflect_charge(orb, defender_center, 0.3)

	# 反射玉が攻撃側に飛ぶ
	await _animate_orb_travel(orb, defender_center, attacker_center, 0.25)

	# 着弾
	orb.queue_free()
	attacker.play_damage_animation()
	await get_tree().create_timer(0.15).timeout


## 反射用の光玉を作成（赤系グラデーション）
func _create_reflect_orb(center: Vector2) -> Control:
	var orb = ReflectOrb.new()
	orb.size = Vector2(16, 16)
	orb.position = center - Vector2(8, 8)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_layer.add_child(orb)
	return orb


## 反射チャージアニメーション（短め、バリアが光って跳ね返す感じ）
func _animate_reflect_charge(orb: Control, center: Vector2, duration: float) -> void:
	# バリアフラッシュ（円形の光が一瞬広がる）
	var flash = Panel.new()
	var flash_style = StyleBoxFlat.new()
	flash_style.bg_color = Color(1.0, 0.3, 0.2, 0.4)
	flash_style.corner_radius_top_left = 200
	flash_style.corner_radius_top_right = 200
	flash_style.corner_radius_bottom_left = 200
	flash_style.corner_radius_bottom_right = 200
	flash.add_theme_stylebox_override("panel", flash_style)
	flash.size = Vector2(50, 50)
	flash.position = center - Vector2(25, 25)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_layer.add_child(flash)

	var flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "size", Vector2(400, 400), duration * 0.6)
	flash_tween.tween_property(flash, "position", center - Vector2(200, 200), duration * 0.6)
	flash_tween.tween_property(flash, "modulate:a", 0.0, duration * 0.6)
	flash_tween.chain().tween_callback(flash.queue_free)

	# 玉の拡大
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var base_t = t / duration
		var current_size = Vector2(16, 16).lerp(Vector2(200, 200), base_t)
		orb.size = current_size
		orb.position = center - current_size / 2
		orb.queue_redraw()
	, 0.0, duration, duration)
	await tween.finished


## エネルギーの玉を作成（_draw()ベースのなめらかグラデーション）
func _create_energy_orb(center: Vector2) -> Control:
	var orb = EnergyOrb.new()
	orb.size = Vector2(16, 16)
	orb.position = center - Vector2(8, 8)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_layer.add_child(orb)
	return orb


## 収束パーティクルを生成
func _spawn_gathering_particles(center: Vector2, duration: float) -> void:
	var particle_count = 12
	for i in range(particle_count):
		var particle = Panel.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.4, 0.7, 1.0, 0.8)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		particle.add_theme_stylebox_override("panel", style)
		particle.size = Vector2(20, 20)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# ランダムな位置から出発（中心から200〜350px離れた円周上）
		var angle = (TAU / particle_count) * i + randf_range(-0.3, 0.3)
		var dist = randf_range(200, 350)
		var start_pos = center + Vector2(cos(angle), sin(angle)) * dist
		particle.position = start_pos - Vector2(10, 10)

		_effect_layer.add_child(particle)

		# スパイラル軌道で中心に収束
		var delay = randf_range(0.0, duration * 0.3)
		var travel_time = duration - delay
		var start_angle = angle
		var start_dist = dist
		var rotations = 1.0  # 回転数
		var p_center = center
		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_method(func(t: float):
			# t: 0.0 → 1.0
			var current_dist = start_dist * (1.0 - t)
			var current_angle = start_angle + rotations * TAU * t
			var pos = p_center + Vector2(cos(current_angle), sin(current_angle)) * current_dist
			particle.position = pos - Vector2(10, 10)
			# 終盤でフェードアウト
			if t > 0.7:
				particle.modulate.a = 1.0 - (t - 0.7) / 0.3
		, 0.0, 1.0, travel_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(particle.queue_free)


## 玉のチャージアニメーション（小→大 + 脈動 + 周回パーティクル）
func _animate_orb_charge(orb: Control, duration: float) -> void:
	var center = orb.position + orb.size / 2
	var target_size = Vector2(300, 300)

	# メインの拡大アニメーション
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var base_t = t / duration
		# 脈動: 振幅0.25で4回、はっきり膨張・収縮
		var pulse = sin(base_t * TAU * 4.0) * 0.25 * base_t
		var scale_factor = base_t + pulse
		var current_size = Vector2(16, 16).lerp(target_size, clampf(scale_factor, 0.0, 1.3))
		orb.size = current_size
		orb.position = center - current_size / 2
		orb.queue_redraw()
	, 0.0, duration, duration)

	# 周回パーティクル（チャージ後半から出現）
	_spawn_orbiting_particles(center, duration)

	await tween.finished


## 周回パーティクル（玉の周りを回る大きめの光）
func _spawn_orbiting_particles(center: Vector2, duration: float) -> void:
	var orbit_count = 6
	for i in range(orbit_count):
		var p = EnergyOrb.new()
		p.size = Vector2(30, 30)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.0
		_effect_layer.add_child(p)

		var start_angle = (TAU / orbit_count) * i
		var delay = duration * 0.3
		var orbit_time = duration - delay
		var p_center = center

		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_method(func(t: float):
			# 玉の外周を周回（半径180〜220で揺らぐ）
			var orbit_radius = 180.0 + 40.0 * sin(t * TAU * 3.0)
			var angle = start_angle + t * TAU * 3.0
			var pos = p_center + Vector2(cos(angle), sin(angle)) * orbit_radius
			p.position = pos - p.size / 2
			p.modulate.a = minf(t * 3.0, 0.8)
			p.queue_redraw()
		, 0.0, 1.0, orbit_time)
		tween.tween_callback(p.queue_free)


## 光の玉が敵に飛ぶアニメーション（軌跡パーティクル付き）
func _animate_orb_travel(orb: Control, _from: Vector2, to: Vector2, duration: float) -> void:
	var start_pos = orb.position
	var target_pos = to - orb.size / 2

	var tween = create_tween()
	tween.tween_method(func(t: float):
		orb.position = start_pos.lerp(target_pos, t)
		# 軌跡パーティクル
		if randf() < 0.6:
			_spawn_trail_particle(orb.position + orb.size / 2)
	, 0.0, 1.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	await tween.finished


## 軌跡パーティクル（飛行中に残る小さな光）
func _spawn_trail_particle(pos: Vector2) -> void:
	var p = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.7, 1.0, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	p.add_theme_stylebox_override("panel", style)
	p.size = Vector2(14, 14)
	p.position = pos - Vector2(7, 7) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_layer.add_child(p)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(p, "modulate:a", 0.0, 0.3)
	tween.tween_property(p, "scale", Vector2(0.2, 0.2), 0.3)
	tween.chain().tween_callback(p.queue_free)


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


## Object Pool用のリセット処理
func reset() -> void:
	# データをクリア
	_attacker_data = {}
	_defender_data = {}

	# UI状態をリセット
	_waiting_for_click = false
	_click_area.visible = false

	# 表示をリセット
	if _vs_label:
		_vs_label.modulate.a = 0.0
		_vs_label.scale = Vector2.ONE

	# ツイーンをキャンセル（Godot 4 では自動クリーンアップされるため不要）
	# Note: ツイーンは対象ノードに紐づいているため、明示的なキャンセルは不要

	# クリーチャー表示の視覚状態をリセット（敗北アニメーション後の状態が残るため）
	_reset_creature_display(_attacker_display)
	_reset_creature_display(_defender_display)

	# エフェクトレイヤーをクリア
	if _effect_layer:
		for child in _effect_layer.get_children():
			child.queue_free()


## クリーチャー表示の視覚状態をリセット
func _reset_creature_display(display: BattleCreatureDisplay) -> void:
	if not display:
		return
	display.modulate.a = 1.0
	display.rotation = 0.0
	display.position = display.original_position
