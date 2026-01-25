# チュートリアル用穴あきオーバーレイ
# 指定した箇所以外を暗くして、特定のUI要素をハイライトする
extends Control

class_name TutorialOverlay

# 穴の情報
var holes: Array = []  # [{position: Vector2, size: Vector2, shape: "circle"|"rect"}]



# 発光アニメーション用
var glow_time: float = 0.0
var glow_color: Color = Color(1.0, 0.9, 0.3, 1.0)  # 黄色っぽい光



# グローバルボタン参照
var global_action_buttons = null

# 許可されたボタン
var allowed_buttons: Array = []

func _ready():
	# ポーズ中でも動作するように設定
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 全画面設定
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# クリックは通す（発光表示のみ）
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	visible = false
	
	# アニメーション用にprocess有効化
	set_process(true)

func _process(delta: float):
	if visible and holes.size() > 0:
		glow_time += delta * 3.0  # 速度調整
		queue_redraw()

func _setup_shader():
	# シェーダーは使わない（発光エフェクトのみ_drawで描画）
	pass

## オーバーレイを非表示
func hide_overlay():
	visible = false
	holes.clear()
	allowed_buttons = []
	# ボタンを通常状態に戻す
	_restore_button_states()

## 全ボタンを無効化（発光なし）
func disable_all_buttons():
	holes.clear()
	allowed_buttons = []
	_update_button_states()
	visible = false

## 円形の穴を追加（グローバルボタン用）
func add_circle_hole(center: Vector2, radius: float):
	holes.append({
		"position": center - Vector2(radius, radius),
		"size": Vector2(radius * 2, radius * 2),
		"shape": "circle"
	})

## 矩形の穴を追加（カード用）
func add_rect_hole(pos: Vector2, rect_size: Vector2):
	holes.append({
		"position": pos,
		"size": rect_size,
		"shape": "rect"
	})

## 穴をクリア
func clear_holes():
	holes.clear()

## グローバルボタンをハイライト（発光のみ）
func highlight_button(button_name: String, _with_overlay: bool = false):
	clear_holes()
	allowed_buttons = [button_name]
	
	var button_info = _get_button_info(button_name)
	if button_info.is_empty():
		return
	
	add_circle_hole(button_info.center, button_info.radius)
	_update_button_states()
	visible = true

## 複数のグローバルボタンをハイライト（発光のみ）
func highlight_buttons(button_names: Array, _with_overlay: bool = false):
	clear_holes()
	allowed_buttons = button_names.duplicate()
	
	for btn_name in button_names:
		var button_info = _get_button_info(btn_name)
		if not button_info.is_empty():
			add_circle_hole(button_info.center, button_info.radius)
	
	# グローバルボタンの有効/無効を設定
	_update_button_states()
	
	visible = true

## カードをハイライト
func highlight_card(card_node: Control, _with_overlay: bool = false):
	clear_holes()
	allowed_buttons = []
	
	if card_node:
		var rect = card_node.get_global_rect()
		add_rect_hole(rect.position, rect.size)
	
	_update_button_states()
	visible = true

## 手札の全カードをハイライト
func highlight_hand_cards(card_nodes: Array, _with_overlay: bool = false):
	clear_holes()
	allowed_buttons = []  # ボタンは全て無効
	
	for card_node in card_nodes:
		if card_node and is_instance_valid(card_node):
			var rect = card_node.get_global_rect()
			add_rect_hole(rect.position, rect.size)
	
	# グローバルボタンを全て無効化
	_update_button_states()
	
	visible = true

## グローバルボタンの位置情報を取得
func _get_button_info(button_name: String) -> Dictionary:
	var viewport = get_viewport()
	if not viewport:
		return {}
	
	var viewport_size = viewport.get_visible_rect().size
	
	# GlobalActionButtonsの定数
	const BUTTON_SIZE = 280
	const BUTTON_SPACING = 42
	const MARGIN_RIGHT = 70
	const MARGIN_BOTTOM = 70
	const MARGIN_LEFT = 70
	
	var radius = BUTTON_SIZE / 2.0
	var base_x = viewport_size.x - MARGIN_RIGHT - BUTTON_SIZE + radius
	var back_y = viewport_size.y - MARGIN_BOTTOM - BUTTON_SIZE + radius
	var confirm_y = back_y - BUTTON_SIZE - BUTTON_SPACING
	var down_y = confirm_y - BUTTON_SIZE - BUTTON_SPACING
	var up_y = down_y - BUTTON_SIZE - BUTTON_SPACING
	
	match button_name:
		"confirm", "ok", "決定":
			return {"center": Vector2(base_x, confirm_y), "radius": radius}
		"back", "cancel", "戻る":
			return {"center": Vector2(base_x, back_y), "radius": radius}
		"up", "上":
			return {"center": Vector2(base_x, up_y), "radius": radius}
		"down", "下":
			return {"center": Vector2(base_x, down_y), "radius": radius}
		"special", "特殊":
			var special_x = MARGIN_LEFT + radius
			return {"center": Vector2(special_x, back_y), "radius": radius}
		_:
			return {}

## 3Dオブジェクトをスクリーン座標に変換してハイライト
func highlight_3d_object(object_3d: Node3D, camera: Camera3D, rect_size: Vector2 = Vector2(200, 100)):
	if not object_3d or not camera:
		return
	
	clear_holes()
	allowed_buttons = []
	
	# 3D位置をスクリーン座標に変換
	var screen_pos = camera.unproject_position(object_3d.global_position)
	
	# 矩形の中心をスクリーン座標に合わせる
	var rect_pos = screen_pos - rect_size / 2
	add_rect_hole(rect_pos, rect_size)
	
	_update_button_states()
	visible = true

func _draw():
	# 発光エフェクトのみ描画
	var glow_alpha = (sin(glow_time) + 1.0) / 2.0 * 0.6 + 0.4  # 0.4〜1.0で脈動
	var glow_scale = 1.0 + (sin(glow_time) + 1.0) / 2.0 * 0.2  # 1.0〜1.2で拡縮
	
	for hole in holes:
		var center = hole.position + hole.size / 2
		
		if hole.shape == "circle":
			var radius = hole.size.x / 2
			# 外側の光（複数リングで発光感を出す）
			for i in range(5):
				var ring_radius = radius * glow_scale + 8 + i * 10
				var ring_alpha = glow_alpha * (1.0 - i * 0.18)
				var ring_color = Color(glow_color.r, glow_color.g, glow_color.b, ring_alpha * 0.9)
				draw_arc(center, ring_radius, 0, TAU, 64, ring_color, 6.0 - i * 0.8)
		else:
			# 矩形の場合
			var rect = Rect2(hole.position, hole.size)
			var expanded = rect.grow(10 * glow_scale)
			for i in range(5):
				var ring_rect = expanded.grow(i * 8)
				var ring_alpha = glow_alpha * (1.0 - i * 0.18)
				var ring_color = Color(glow_color.r, glow_color.g, glow_color.b, ring_alpha * 0.9)
				draw_rect(ring_rect, ring_color, false, 5.0 - i * 0.8)



## グローバルボタン参照を設定
func set_global_action_buttons(buttons):
	global_action_buttons = buttons

## 許可されたボタン以外を無効化（visibleも制御）
func _update_button_states():
	if not global_action_buttons:
		return
	
	# 全ボタンを一時的に無効化、許可されたもののみ有効
	var buttons_map = {
		"up": global_action_buttons.up_button,
		"down": global_action_buttons.down_button,
		"confirm": global_action_buttons.confirm_button,
		"ok": global_action_buttons.confirm_button,
		"back": global_action_buttons.back_button,
		"cancel": global_action_buttons.back_button,
		"special": global_action_buttons.special_button
	}
	
	# 全ボタンを無効化＆非表示
	for button in [global_action_buttons.up_button, global_action_buttons.down_button,
				   global_action_buttons.confirm_button, global_action_buttons.back_button,
				   global_action_buttons.special_button]:
		if button:
			button.disabled = true
			if allowed_buttons.is_empty():
				# 全ボタン無効時は非表示にする
				button.visible = false
	
	# 許可されたボタンのみ有効化＆表示
	for btn_name in allowed_buttons:
		if buttons_map.has(btn_name) and buttons_map[btn_name]:
			buttons_map[btn_name].disabled = false
			buttons_map[btn_name].visible = true

## ボタン状態を元に戻す
func _restore_button_states():
	if not global_action_buttons:
		return
	
	# GlobalActionButtonsの通常の更新を呼び出す
	if global_action_buttons.has_method("_update_button_states"):
		global_action_buttons._update_button_states()
