extends CanvasLayer
class_name GachaAnimation

signal animation_finished

const _CARD_BACK_TEX: Texture2D = preload("res://assets/images/tiles/card_back_color.png")
const _CARD_SCENE: PackedScene = preload("res://scenes/Card.tscn")

const _CARD_NATIVE: Vector2 = Vector2(220, 293)
const _CARD_GAP: float = 28.0
const _CARD_MAX: Vector2 = Vector2(320, 427)
const _CARD_MIN: Vector2 = Vector2(160, 213)
const _ZOOM_SCALE: float = 1.5
const _EDGE_MARGIN: float = 16.0

var _card_size: Vector2 = Vector2(160, 213)
var _zoomed_card: Control = null

const _RARITY_ORDER: Dictionary = {"R": 0, "S": 1, "N": 2, "C": 3}

const _RARITY_COLORS: Dictionary = {
	"R": Color(1.0, 0.85, 0.2, 1.0),
	"S": Color(0.7, 0.4, 1.0, 1.0),
	"N": Color(0.4, 0.7, 1.0, 1.0),
	"C": Color(0.75, 0.75, 0.75, 1.0),
}

@onready var _root: Control = $Root
@onready var _cards_layer: Control = $Root/CardsLayer
@onready var _fx_layer: Control = $Root/FxLayer
@onready var _hint_label: Label = $Root/HintLabel

var _cards_data: Array = []
var _card_nodes: Array = []
var _is_running: bool = false
var _skip_requested: bool = false
var _last_tap_frame: int = -1
var _info_panel_node: Control = null
var _info_visible: bool = false

const _CREATURE_INFO_SCENE: PackedScene = preload("res://scenes/ui/creature_info_panel.tscn")
const _SPELL_INFO_SCENE: PackedScene = preload("res://scenes/ui/spell_info_panel.tscn")
const _ITEM_INFO_SCENE: PackedScene = preload("res://scenes/ui/item_info_panel.tscn")


func play(cards: Array) -> void:
	_cards_data = _sort_by_rarity(cards)
	_is_running = true
	await _run_sequence()
	_is_running = false
	animation_finished.emit()


func _sort_by_rarity(cards: Array) -> Array:
	var sorted: Array = cards.duplicate()
	sorted.sort_custom(func(a, b):
		var ra: int = _RARITY_ORDER.get(String(a.get("rarity", "N")), 4)
		var rb: int = _RARITY_ORDER.get(String(b.get("rarity", "N")), 4)
		return ra < rb
	)
	return sorted


func _run_sequence() -> void:
	_hint_label.modulate.a = 0.0
	set_process_input(true)
	_compute_card_size()
	await _fade_bg_in()
	await _show_pack_opening()
	await _spread_cards()
	await _flip_cards_sequentially()
	await _wait_for_dismiss()


func _compute_card_size() -> void:
	var n: int = max(1, _cards_data.size())
	var rows: int = 1 if n <= 5 else 2
	var per_row: int = int(ceil(float(n) / rows))
	var available_w: float = _root.size.x - 40.0 - (per_row - 1) * _CARD_GAP
	var w: float = clamp(available_w / per_row, _CARD_MIN.x, _CARD_MAX.x)
	var h: float = w * (_CARD_NATIVE.y / _CARD_NATIVE.x)
	var max_h: float = (_root.size.y * 0.8 - (rows - 1) * _CARD_GAP) / rows
	if h > max_h:
		h = max_h
		w = h * (_CARD_NATIVE.x / _CARD_NATIVE.y)
	_card_size = Vector2(w, h)


func _fade_bg_in() -> void:
	var bg: ColorRect = $Root/BgDim
	bg.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 0.25)
	await tw.finished


func _show_pack_opening() -> void:
	var center: Vector2 = _root.size * 0.5
	var pack_size: Vector2 = Vector2(280, 380)
	var pack_pos: Vector2 = center - pack_size * 0.5

	# カード裏面を先に中央へ配置（パックの裏に隠れる）
	for i in range(_cards_data.size()):
		var card_ctrl: Control = _create_card_control(_cards_data[i])
		card_ctrl.position = center - _card_size * 0.5
		card_ctrl.scale = Vector2.ONE
		card_ctrl.modulate.a = 1.0
		_cards_layer.add_child(card_ctrl)
		_card_nodes.append(card_ctrl)

	# パック本体（PanelContainer）— カードの上に表示
	var pack: PanelContainer = PanelContainer.new()
	pack.custom_minimum_size = pack_size
	pack.size = pack_size
	pack.pivot_offset = pack_size * 0.5
	pack.position = pack_pos
	pack.scale = Vector2(0.0, 0.0)
	pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack.z_index = 10

	var pack_style: StyleBoxFlat = StyleBoxFlat.new()
	pack_style.bg_color = Color(0.15, 0.08, 0.25, 1.0)
	pack_style.border_color = Color(0.6, 0.4, 0.9, 0.9)
	pack_style.set_border_width_all(4)
	pack_style.set_corner_radius_all(16)
	pack_style.shadow_color = Color(0.4, 0.2, 0.8, 0.4)
	pack_style.shadow_size = 12
	pack.add_theme_stylebox_override("panel", pack_style)

	# パック内ラベル
	var pack_label: Label = Label.new()
	pack_label.text = "CARD\nPACK"
	pack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pack_label.add_theme_font_size_override("font_size", 42)
	pack_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0, 0.8))
	pack_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.3))
	pack_label.add_theme_constant_override("outline_size", 4)
	pack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack.add_child(pack_label)

	_fx_layer.add_child(pack)

	# パック登場（拡大）
	var tw_appear: Tween = create_tween()
	tw_appear.tween_property(pack, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_appear.finished
	await get_tree().create_timer(0.3).timeout

	# パック振動
	var orig_pos: Vector2 = pack.position
	var tw_shake: Tween = create_tween()
	for k in range(6):
		var intensity: float = 3.0 + k * 2.0
		tw_shake.tween_property(pack, "position", orig_pos + Vector2(intensity, 0), 0.04)
		tw_shake.tween_property(pack, "position", orig_pos + Vector2(-intensity, 0), 0.04)
	tw_shake.tween_property(pack, "position", orig_pos, 0.02)
	await tw_shake.finished

	# パック発光
	pack_style.shadow_color = Color(1.0, 0.9, 0.4, 0.8)
	pack_style.shadow_size = 30
	pack_style.border_color = Color(1.0, 0.9, 0.5, 1.0)
	await get_tree().create_timer(0.15).timeout

	# 左右に縦割り（上から裂けるように開く）
	var half_w: float = pack_size.x * 0.5

	var pack_left: PanelContainer = PanelContainer.new()
	pack_left.custom_minimum_size = Vector2(half_w, pack_size.y)
	pack_left.size = Vector2(half_w, pack_size.y)
	pack_left.pivot_offset = Vector2(half_w, pack_size.y)  # 右下（下中央）が回転軸
	pack_left.position = pack_pos
	pack_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_left.z_index = 10
	var left_style: StyleBoxFlat = pack_style.duplicate()
	left_style.corner_radius_top_right = 0
	left_style.corner_radius_bottom_right = 0
	pack_left.add_theme_stylebox_override("panel", left_style)
	pack_left.clip_contents = true
	_fx_layer.add_child(pack_left)

	var pack_right: PanelContainer = PanelContainer.new()
	pack_right.custom_minimum_size = Vector2(half_w, pack_size.y)
	pack_right.size = Vector2(half_w, pack_size.y)
	pack_right.pivot_offset = Vector2(0, pack_size.y)  # 左下（下中央）が回転軸
	pack_right.position = pack_pos + Vector2(half_w, 0)
	pack_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_right.z_index = 10
	var right_style: StyleBoxFlat = pack_style.duplicate()
	right_style.corner_radius_top_left = 0
	right_style.corner_radius_bottom_left = 0
	pack_right.add_theme_stylebox_override("panel", right_style)
	pack_right.clip_contents = true
	_fx_layer.add_child(pack_right)

	# 元パックを非表示
	pack.visible = false

	# フラッシュ
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = _root.size
	flash.position = Vector2.ZERO
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 11
	_fx_layer.add_child(flash)

	# 破裂アニメーション — 上から裂けて左右に開く
	var tw_burst: Tween = create_tween().set_parallel(true)
	# 左半分: 左上を軸に外側へ回転して飛ぶ
	tw_burst.tween_property(pack_left, "rotation", -0.8, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_burst.tween_property(pack_left, "position:x", pack_left.position.x - 300, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_burst.tween_property(pack_left, "modulate:a", 0.0, 0.45)
	# 右半分: 右上を軸に外側へ回転して飛ぶ
	tw_burst.tween_property(pack_right, "rotation", 0.8, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_burst.tween_property(pack_right, "position:x", pack_right.position.x + 300, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw_burst.tween_property(pack_right, "modulate:a", 0.0, 0.45)
	# フラッシュ
	tw_burst.tween_property(flash, "color:a", 0.9, 0.1)
	tw_burst.chain().tween_property(flash, "color:a", 0.0, 0.3)
	await tw_burst.finished

	# クリーンアップ
	pack.queue_free()
	pack_left.queue_free()
	pack_right.queue_free()
	flash.queue_free()


func _spawn_card_backs() -> void:
	var viewport_size: Vector2 = _root.size
	var center: Vector2 = viewport_size * 0.5
	for i in range(_cards_data.size()):
		var card_ctrl: Control = _create_card_control(_cards_data[i])
		card_ctrl.position = center - _card_size * 0.5
		card_ctrl.scale = Vector2(0.2, 0.2)
		card_ctrl.modulate.a = 0.0
		_cards_layer.add_child(card_ctrl)
		_card_nodes.append(card_ctrl)

	# パック破裂風: 中央でまとめて拡大＋光る
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = _root.size
	flash.position = Vector2.ZERO
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(flash)

	var tw: Tween = create_tween().set_parallel(true)
	for c in _card_nodes:
		tw.tween_property(c, "modulate:a", 1.0, 0.25)
		tw.tween_property(c, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "color:a", 0.8, 0.15)
	tw.chain().tween_property(flash, "color:a", 0.0, 0.25)
	await tw.finished
	flash.queue_free()


func _spread_cards() -> void:
	var n: int = _card_nodes.size()
	if n == 0:
		return
	var rows: int = 1 if n <= 5 else 2
	var per_row: int = int(ceil(float(n) / rows))
	var total_height: float = rows * _card_size.y + (rows - 1) * _CARD_GAP
	var y_start: float = (_root.size.y - total_height) * 0.5

	var tw: Tween = create_tween().set_parallel(true)
	for i in range(n):
		var row: int = i / per_row
		var col: int = i % per_row
		var count_in_row: int = per_row if row < rows - 1 else (n - row * per_row)
		var row_width: float = count_in_row * _card_size.x + (count_in_row - 1) * _CARD_GAP
		var row_start_x: float = (_root.size.x - row_width) * 0.5
		var target: Vector2 = Vector2(
			row_start_x + col * (_card_size.x + _CARD_GAP),
			y_start + row * (_card_size.y + _CARD_GAP)
		)
		_card_nodes[i].set_meta("home_pos", target)
		tw.tween_property(_card_nodes[i], "position", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(0.2).timeout


func _flip_cards_sequentially() -> void:
	for i in range(_card_nodes.size()):
		if _skip_requested:
			_reveal_all_immediately()
			return
		await _flip_card(_card_nodes[i], _cards_data[i])
		await get_tree().create_timer(0.08).timeout


func _flip_card(card_ctrl: Control, card_data: Dictionary) -> void:
	var back: TextureRect = card_ctrl.get_node("Back")
	var front: Control = card_ctrl.get_node("Front")
	front.visible = false

	var tw: Tween = create_tween()
	tw.tween_property(card_ctrl, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished

	back.visible = false
	front.visible = true

	var tw2: Tween = create_tween()
	tw2.tween_property(card_ctrl, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished

	var badge: Node = card_ctrl.get_node_or_null("NewBadge")
	if badge:
		badge.visible = true
		badge.modulate.a = 0.0
		var tw_badge: Tween = create_tween()
		tw_badge.tween_property(badge, "modulate:a", 1.0, 0.2)
		# NEWカードは発光エフェクト追加
		_add_new_glow(card_ctrl)

	var rarity: String = String(card_data.get("rarity", "N"))
	if rarity == "R" or rarity == "S":
		_play_rarity_effect(card_ctrl, rarity)


func _play_rarity_effect(card_ctrl: Control, rarity: String) -> void:
	var color: Color = _RARITY_COLORS.get(rarity, Color.WHITE)

	var flash: ColorRect = ColorRect.new()
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.size = _root.size
	flash.position = Vector2.ZERO
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(flash)

	var peak: float = 0.5 if rarity == "R" else 0.25
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", peak, 0.08)
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)

	var pulse: Tween = create_tween()
	pulse.tween_property(card_ctrl, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(card_ctrl, "scale", Vector2(1.0, 1.0), 0.18)


func _reveal_all_immediately() -> void:
	for i in range(_card_nodes.size()):
		var c: Control = _card_nodes[i]
		var back: TextureRect = c.get_node("Back")
		var front: Control = c.get_node("Front")
		back.visible = false
		front.visible = true
		c.scale = Vector2.ONE
		var badge: Node = c.get_node_or_null("NewBadge")
		if badge:
			badge.visible = true
			badge.modulate.a = 1.0
			_add_new_glow(c)


func _wait_for_dismiss() -> void:
	_hint_label.text = "タップで閉じる"
	var tw: Tween = create_tween()
	tw.tween_property(_hint_label, "modulate:a", 1.0, 0.3)
	_skip_requested = false
	while not _skip_requested:
		await get_tree().process_frame


func _input(event: InputEvent) -> void:
	if not _is_running:
		return
	var is_tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not is_tap:
		return
	# モバイルではtouch+エミュレートmouseで同フレーム2回発火するのを防止
	var frame: int = Engine.get_process_frames()
	if frame == _last_tap_frame:
		get_viewport().set_input_as_handled()
		return
	_last_tap_frame = frame
	# カードタップ判定（完了後のみ）: ズームトグル
	if _hint_label.modulate.a >= 0.9:
		var tap_pos: Vector2 = _get_event_position(event)
		var tapped_card: Control = _find_card_at(tap_pos)
		if tapped_card:
			_toggle_zoom(tapped_card)
			get_viewport().set_input_as_handled()
			return
		# ズーム中ならズーム解除
		if _zoomed_card and is_instance_valid(_zoomed_card):
			_reset_zoom(_zoomed_card)
			_hide_info_panel()
			_zoomed_card = null
			get_viewport().set_input_as_handled()
			return
		# それ以外は閉じる
		_skip_requested = true
		get_viewport().set_input_as_handled()
		return
	# フリップ中は即時全公開
	_skip_requested = true
	get_viewport().set_input_as_handled()


func _get_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return event.position
	if event is InputEventScreenTouch:
		return event.position
	return Vector2.ZERO


func _find_card_at(pos: Vector2) -> Control:
	# 後ろから判定（上に描画されているものを優先）
	for i in range(_card_nodes.size() - 1, -1, -1):
		var c: Control = _card_nodes[i]
		if not is_instance_valid(c):
			continue
		var rect: Rect2 = Rect2(c.position, c.size * c.scale)
		# ピボットを考慮して中心基準で広げる
		var center: Vector2 = c.position + c.size * 0.5
		var half: Vector2 = c.size * c.scale * 0.5
		rect = Rect2(center - half, half * 2.0)
		if rect.has_point(pos):
			return c
	return null


func _create_card_control(card: Dictionary) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = _card_size
	ctrl.size = _card_size
	ctrl.pivot_offset = _card_size * 0.5
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.set_meta("card_data", card)

	var back: TextureRect = TextureRect.new()
	back.name = "Back"
	back.texture = _CARD_BACK_TEX
	back.size = _card_size
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(back)

	var front: Control = _build_front(card)
	front.name = "Front"
	front.size = _card_size
	front.visible = false
	ctrl.add_child(front)

	if card.get("_is_new", false):
		var new_badge: Label = Label.new()
		new_badge.name = "NewBadge"
		new_badge.text = "NEW"
		new_badge.size = Vector2(_card_size.x, 32)
		new_badge.position = Vector2(0, -34)
		new_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		new_badge.add_theme_font_size_override("font_size", 26)
		new_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
		new_badge.add_theme_color_override("font_outline_color", Color(0.4, 0.1, 0.1))
		new_badge.add_theme_constant_override("outline_size", 6)
		new_badge.visible = false
		new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(new_badge)

	return ctrl


func _toggle_zoom(card_ctrl: Control) -> void:
	if _zoomed_card == card_ctrl:
		_reset_zoom(card_ctrl)
		_hide_info_panel()
		_zoomed_card = null
		return
	if _zoomed_card and is_instance_valid(_zoomed_card):
		_reset_zoom(_zoomed_card)
		_hide_info_panel()
	_zoomed_card = card_ctrl
	card_ctrl.z_index = 100
	# カードを右側に配置、インフォパネルを左側に表示
	var right_x: float = _root.size.x * 0.55
	var center_y: float = (_root.size.y - _card_size.y * _ZOOM_SCALE) * 0.5
	var target_pos: Vector2 = Vector2(right_x, center_y)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(card_ctrl, "scale", Vector2(_ZOOM_SCALE, _ZOOM_SCALE), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_ctrl, "position", target_pos, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# インフォパネル表示
	var card_data: Dictionary = card_ctrl.get_meta("card_data", {})
	_show_info_panel(card_data)


func _clamp_zoom_position(card_ctrl: Control) -> Vector2:
	var home: Vector2 = card_ctrl.get_meta("home_pos", card_ctrl.position)
	var center: Vector2 = home + _card_size * 0.5
	var half: Vector2 = _card_size * _ZOOM_SCALE * 0.5
	var min_c: Vector2 = half + Vector2(_EDGE_MARGIN, _EDGE_MARGIN)
	var max_c: Vector2 = _root.size - half - Vector2(_EDGE_MARGIN, _EDGE_MARGIN)
	center.x = clamp(center.x, min_c.x, max_c.x)
	center.y = clamp(center.y, min_c.y, max_c.y)
	return center - _card_size * 0.5


func _reset_zoom(card_ctrl: Control) -> void:
	card_ctrl.z_index = 0
	var home: Vector2 = card_ctrl.get_meta("home_pos", card_ctrl.position)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(card_ctrl, "scale", Vector2.ONE, 0.14)
	tw.tween_property(card_ctrl, "position", home, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_front(card: Dictionary) -> Control:
	var container: Control = Control.new()
	container.size = _card_size
	container.clip_contents = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_instance: Control = _CARD_SCENE.instantiate()
	card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_filter_recursive(card_instance, Control.MOUSE_FILTER_IGNORE)

	var card_id: int = int(card.get("id", 0))
	if card_instance.has_method("load_card_data") and card_id > 0:
		card_instance.load_card_data(card_id)

	# レアリティに応じて角装飾の色を変更
	var rarity: String = String(card.get("rarity", "N"))
	_apply_rarity_ornament_color(card_instance, rarity)

	var sx: float = _card_size.x / _CARD_NATIVE.x
	var sy: float = _card_size.y / _CARD_NATIVE.y
	card_instance.scale = Vector2(sx, sy)
	card_instance.position = Vector2.ZERO
	card_instance.set_process(false)
	card_instance.set_process_input(false)

	container.add_child(card_instance)
	return container


func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


## レアリティに応じて角装飾（CornerTopLeft/CornerTopRight/TopAccent）の色を変更
func _apply_rarity_ornament_color(card_instance: Control, rarity: String) -> void:
	var edge_color: Color
	var border_color: Color
	match rarity:
		"R":
			edge_color = Color(0.72, 0.53, 0.04, 1.0)  # 金色
			border_color = Color(0.9, 0.72, 0.15, 1.0)
		"S":
			edge_color = Color(0.55, 0.55, 0.6, 1.0)  # 銀色
			border_color = Color(0.85, 0.85, 0.9, 1.0)
		"N":
			edge_color = Color(0.25, 0.45, 0.8, 1.0)  # 青色
			border_color = Color(0.45, 0.65, 1.0, 1.0)
		_:  # C
			edge_color = Color(0.1, 0.1, 0.1, 1.0)  # 黒色
			border_color = Color(0.3, 0.3, 0.3, 1.0)

	# R/Sはグラデーション（端→白→端）、N/Cは単色
	var use_gradient: bool = rarity == "R" or rarity == "S"

	for node_name in ["CornerTopLeft", "CornerTopRight", "TopAccent"]:
		var ornament: Panel = card_instance.get_node_or_null(node_name)
		if not ornament:
			continue
		if use_gradient:
			var gradient: Gradient = Gradient.new()
			gradient.set_color(0, edge_color)
			gradient.add_point(0.25, edge_color)
			gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 0.6))
			gradient.add_point(0.75, edge_color)
			gradient.set_color(4, edge_color)
			var grad_tex: GradientTexture2D = GradientTexture2D.new()
			grad_tex.gradient = gradient
			grad_tex.width = 16
			grad_tex.height = 16
			grad_tex.fill = GradientTexture2D.FILL_LINEAR
			grad_tex.fill_from = Vector2(0.0, 0.0)
			grad_tex.fill_to = Vector2(1.0, 1.0)
			var style: StyleBoxTexture = StyleBoxTexture.new()
			style.texture = grad_tex
			ornament.add_theme_stylebox_override("panel", style)
		else:
			var style: StyleBoxFlat = ornament.get_theme_stylebox("panel").duplicate()
			style.bg_color = edge_color
			style.border_color = border_color
			ornament.add_theme_stylebox_override("panel", style)


## インフォパネルを表示（既存シーン利用）
func _show_info_panel(card_data: Dictionary) -> void:
	_hide_info_panel()
	if card_data.is_empty():
		return

	var card_type: String = String(card_data.get("type", "creature"))

	match card_type:
		"spell":
			_info_panel_node = _SPELL_INFO_SCENE.instantiate()
			_fx_layer.add_child(_info_panel_node)
			_info_panel_node.show_spell_info(card_data, -1, "", "spell")
		"item":
			_info_panel_node = _ITEM_INFO_SCENE.instantiate()
			_fx_layer.add_child(_info_panel_node)
			_info_panel_node.show_item_info(card_data, -1, "", "item")
		_:  # creature
			_info_panel_node = _CREATURE_INFO_SCENE.instantiate()
			_fx_layer.add_child(_info_panel_node)
			_info_panel_node.show_view_mode(card_data, -1, false)

	_info_visible = true

	# カードより前面に表示
	_info_panel_node.z_index = 200

	# フェードイン
	_info_panel_node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_info_panel_node, "modulate:a", 1.0, 0.15)


## インフォパネルを非表示
func _hide_info_panel() -> void:
	if _info_panel_node and is_instance_valid(_info_panel_node):
		_info_panel_node.queue_free()
		_info_panel_node = null
	_info_visible = false


## NEWカードに発光エフェクトを追加（フリップ後に呼ばれる）
func _add_new_glow(card_ctrl: Control) -> void:
	var glow: ColorRect = ColorRect.new()
	glow.name = "NewGlow"
	glow.size = card_ctrl.size + Vector2(8, 8)
	glow.position = Vector2(-4, -4)
	glow.color = Color(1.0, 0.95, 0.3, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = -1
	card_ctrl.add_child(glow)

	# 脈動アニメーション（ループ）
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(glow, "color:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "color:a", 0.1, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
