extends Control

# 魔法石ショップUI
# 4属性の石を表示し、購入・売却を選択

signal shop_closed(transaction_done: bool)

var player_id: int = 0
var player_magic: int = 0
var player_stones: Dictionary = {}
var stone_values: Dictionary = {}
var stone_system = null
var player_system_ref = null
var transaction_done: bool = false

# 閲覧モード（全プレイヤー所持状況表示）
var is_info_mode: bool = false
var all_players_stones: Array = []  # [{name, stones}, ...]

# UI要素
var panel: Panel
var title_label: Label
var magic_label: Label
var stones_container: HBoxContainer
var close_button: Button
var stone_panels: Dictionary = {}  # element -> panel

# 属性情報
const ELEMENTS = ["fire", "water", "earth", "wind"]
const ELEMENT_NAMES = {
	"fire": "火の石",
	"water": "水の石",
	"earth": "土の石",
	"wind": "風の石"
}
const GC = preload("res://scripts/game_constants.gd")

func _ready():
	setup_ui()

func setup_ui():
	if panel != null:
		return
	
	visible = false
	
	# メインパネル
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(1195, 675)
	add_child(panel)

	# パネルスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	style.border_color = Color(0.3, 0.6, 0.8)
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", style)

	# マージン
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# ヘッダー（タイトル + 所持EP）
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 60)
	vbox.add_child(header)

	title_label = Label.new()
	title_label.text = "魔法石ショップ"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	header.add_child(title_label)

	magic_label = Label.new()
	magic_label.text = "所持EP: 0"
	magic_label.add_theme_font_size_override("font_size", 30)
	magic_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	header.add_child(magic_label)
	
	# 石表示エリア
	stones_container = HBoxContainer.new()
	stones_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stones_container.add_theme_constant_override("separation", 20)
	vbox.add_child(stones_container)
	
	# 4属性のパネルを作成
	for element in ELEMENTS:
		var stone_panel = _create_stone_panel(element)
		stones_container.add_child(stone_panel)
		stone_panels[element] = stone_panel
	
	# 閉じるボタン
	close_button = Button.new()
	close_button.text = "閉じる"
	close_button.custom_minimum_size = Vector2(260, 58)
	close_button.add_theme_font_size_override("font_size", 27)
	close_button.pressed.connect(_on_close_pressed)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.3, 0.4)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	close_button.add_theme_stylebox_override("normal", btn_style)
	
	var close_spacer = Control.new()
	close_spacer.custom_minimum_size = Vector2(0, 25)
	vbox.add_child(close_spacer)

	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_child(close_button)
	vbox.add_child(button_container)

func _create_stone_panel(element: String) -> Panel:
	var stone_panel = Panel.new()
	stone_panel.custom_minimum_size = Vector2(273, 470)
	stone_panel.name = element + "_panel"

	var color = GC.ELEMENT_COLORS[element]
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.9)
	panel_style.border_color = color
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	stone_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var inner_margin = MarginContainer.new()
	inner_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_margin.add_theme_constant_override("margin_top", 14)
	inner_margin.add_theme_constant_override("margin_bottom", 14)
	inner_margin.add_theme_constant_override("margin_left", 12)
	inner_margin.add_theme_constant_override("margin_right", 12)
	stone_panel.add_child(inner_margin)
	inner_margin.add_child(vbox)

	# 石の名前
	var name_label = Label.new()
	name_label.name = "name_label"
	name_label.text = ELEMENT_NAMES[element]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", color)
	vbox.add_child(name_label)

	# 現在価値
	var value_label = Label.new()
	value_label.name = "value_label"
	value_label.text = "価値: 50EP"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 27)
	value_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(value_label)

	# 所持数
	var owned_label = Label.new()
	owned_label.name = "owned_label"
	owned_label.text = "所持: 0個"
	owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned_label.add_theme_font_size_override("font_size", 25)
	owned_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(owned_label)

	# スペーサー
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# 数量選択
	var qty_container = HBoxContainer.new()
	qty_container.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_container.add_theme_constant_override("separation", 12)
	vbox.add_child(qty_container)

	var minus_btn = Button.new()
	minus_btn.name = "minus_btn"
	minus_btn.text = "－"
	minus_btn.custom_minimum_size = Vector2(65, 60)
	minus_btn.add_theme_font_size_override("font_size", 36)
	minus_btn.pressed.connect(_on_qty_minus.bind(element))
	qty_container.add_child(minus_btn)

	var qty_label = Label.new()
	qty_label.name = "qty_label"
	qty_label.text = "1"
	qty_label.custom_minimum_size = Vector2(60, 60)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 36)
	qty_container.add_child(qty_label)

	var plus_btn = Button.new()
	plus_btn.name = "plus_btn"
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(65, 60)
	plus_btn.add_theme_font_size_override("font_size", 36)
	plus_btn.pressed.connect(_on_qty_plus.bind(element))
	qty_container.add_child(plus_btn)

	# スペーサー（購入ボタン前）
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	# 購入ボタン
	var buy_btn = Button.new()
	buy_btn.name = "buy_btn"
	buy_btn.text = "購入"
	buy_btn.custom_minimum_size = Vector2(195, 56)
	buy_btn.add_theme_font_size_override("font_size", 27)
	buy_btn.pressed.connect(_on_buy_pressed.bind(element))

	var buy_style = StyleBoxFlat.new()
	buy_style.bg_color = Color(0.2, 0.5, 0.3)
	buy_style.corner_radius_top_left = 8
	buy_style.corner_radius_top_right = 8
	buy_style.corner_radius_bottom_left = 8
	buy_style.corner_radius_bottom_right = 8
	buy_btn.add_theme_stylebox_override("normal", buy_style)

	var buy_container = HBoxContainer.new()
	buy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_container.add_child(buy_btn)
	vbox.add_child(buy_container)

	# 合計表示
	var total_label = Label.new()
	total_label.name = "total_label"
	total_label.text = "合計: 50EP"
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 25)
	total_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(total_label)

	# スペーサー（売却ボタン前）
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer3)

	# 売却ボタン
	var sell_btn = Button.new()
	sell_btn.name = "sell_btn"
	sell_btn.text = "売却"
	sell_btn.custom_minimum_size = Vector2(195, 56)
	sell_btn.add_theme_font_size_override("font_size", 27)
	sell_btn.pressed.connect(_on_sell_pressed.bind(element))

	var sell_style = StyleBoxFlat.new()
	sell_style.bg_color = Color(0.5, 0.3, 0.2)
	sell_style.corner_radius_top_left = 8
	sell_style.corner_radius_top_right = 8
	sell_style.corner_radius_bottom_left = 8
	sell_style.corner_radius_bottom_right = 8
	sell_btn.add_theme_stylebox_override("normal", sell_style)

	var sell_container = HBoxContainer.new()
	sell_container.alignment = BoxContainer.ALIGNMENT_CENTER
	sell_container.add_child(sell_btn)
	vbox.add_child(sell_container)

	return stone_panel

## セットアップ
func setup(p_id: int, p_magic: int, p_stones: Dictionary, s_values: Dictionary, s_system, p_system):
	player_id = p_id
	player_magic = p_magic
	player_stones = p_stones.duplicate()
	stone_values = s_values.duplicate()
	stone_system = s_system
	player_system_ref = p_system
	transaction_done = false
	
	_update_display()

## ショップ表示
func show_shop():
	is_info_mode = false
	_apply_mode_visibility()
	_update_display()
	_center_panel()
	visible = true

## 閲覧モード表示（全プレイヤー所持状況）
func show_info_mode(players_data: Array, s_values: Dictionary):
	is_info_mode = true
	all_players_stones = players_data
	stone_values = s_values.duplicate()
	if title_label:
		title_label.text = "魔法石所持状況"
	if magic_label:
		magic_label.visible = false
	_apply_mode_visibility()
	_update_display()
	_center_panel()
	visible = true

## ショップ操作要素の表示/非表示切替
func _apply_mode_visibility():
	var shop_visible: bool = not is_info_mode
	if magic_label:
		magic_label.visible = shop_visible
	for element in ELEMENTS:
		if not stone_panels.has(element):
			continue
		var panel_node = stone_panels[element]
		for ctrl_name in ["minus_btn", "plus_btn", "qty_label", "buy_btn", "sell_btn", "total_label"]:
			var ctrl = _find_child_by_name(panel_node, ctrl_name)
			if ctrl:
				ctrl.visible = shop_visible

## 表示更新
func _update_display():
	# EP表示更新
	if magic_label and not is_info_mode:
		magic_label.text = "所持EP: %dEP" % player_magic

	# 各属性パネル更新
	for element in ELEMENTS:
		if not stone_panels.has(element):
			continue

		var panel_node = stone_panels[element]
		var value = stone_values.get(element, 50)
		var owned = player_stones.get(element, 0)

		# 価値
		var value_label = _find_child_by_name(panel_node, "value_label")
		if value_label:
			value_label.text = "価値: %dEP" % value

		# 所持数（モード別表示）
		var owned_label = _find_child_by_name(panel_node, "owned_label")
		if owned_label:
			if is_info_mode:
				var lines: Array[String] = []
				for p_data in all_players_stones:
					var p_name: String = p_data.get("name", "P?")
					var p_stones: Dictionary = p_data.get("stones", {})
					lines.append("%s: %d個" % [p_name, p_stones.get(element, 0)])
				owned_label.text = "\n".join(lines)
			else:
				owned_label.text = "所持: %d個" % owned
		
		# 数量
		var qty_label = _find_child_by_name(panel_node, "qty_label")
		var qty = int(qty_label.text) if qty_label else 1
		
		# 合計
		var total_label = _find_child_by_name(panel_node, "total_label")
		if total_label:
			total_label.text = "合計: %dEP" % (value * qty)
		
		# ボタン有効/無効
		var buy_btn = _find_child_by_name(panel_node, "buy_btn")
		if buy_btn:
			buy_btn.disabled = (player_magic < value * qty)
		
		var sell_btn = _find_child_by_name(panel_node, "sell_btn")
		if sell_btn:
			sell_btn.disabled = (owned < qty)

## 子ノード検索
func _find_child_by_name(parent: Node, child_name: String) -> Node:
	for child in parent.get_children():
		if child.name == child_name:
			return child
		var found = _find_child_by_name(child, child_name)
		if found:
			return found
	return null

## パネル中央配置
func _center_panel():
	if panel:
		var viewport_size = get_viewport().get_visible_rect().size
		panel.position = (viewport_size - panel.size) / 2 - Vector2(0, 110)

## 数量マイナス
func _on_qty_minus(element: String):
	var panel_node = stone_panels.get(element)
	if not panel_node:
		return
	
	var qty_label = _find_child_by_name(panel_node, "qty_label")
	if qty_label:
		var qty = max(1, int(qty_label.text) - 1)
		qty_label.text = str(qty)
		_update_display()

## 数量プラス
func _on_qty_plus(element: String):
	var panel_node = stone_panels.get(element)
	if not panel_node:
		return
	
	var qty_label = _find_child_by_name(panel_node, "qty_label")
	if qty_label:
		var qty = int(qty_label.text) + 1
		qty_label.text = str(qty)
		_update_display()

## 購入
func _on_buy_pressed(element: String):
	if not stone_system:
		return
	
	var panel_node = stone_panels.get(element)
	if not panel_node:
		return
	
	var qty_label = _find_child_by_name(panel_node, "qty_label")
	var qty = int(qty_label.text) if qty_label else 1
	
	var result = stone_system.buy_stone(player_id, element, qty)
	if result.get("success", false):
		transaction_done = true
		print("[MagicStoneUI] 購入成功: %s × %d" % [element, qty])
		# 売買完了でショップを閉じる
		_close_shop()

## 売却
func _on_sell_pressed(element: String):
	if not stone_system:
		return
	
	var panel_node = stone_panels.get(element)
	if not panel_node:
		return
	
	var qty_label = _find_child_by_name(panel_node, "qty_label")
	var qty = int(qty_label.text) if qty_label else 1
	
	var result = stone_system.sell_stone(player_id, element, qty)
	if result.get("success", false):
		transaction_done = true
		print("[MagicStoneUI] 売却成功: %s × %d" % [element, qty])
		# 売買完了でショップを閉じる
		_close_shop()

## ショップを閉じる（売買完了時）
func _close_shop():
	visible = false
	shop_closed.emit(transaction_done)

## 閉じる
func _on_close_pressed():
	visible = false
	shop_closed.emit(transaction_done)
