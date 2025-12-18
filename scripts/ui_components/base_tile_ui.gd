extends Control

# ベースタイルUI
# 手札からクリーチャーを選択して遠隔配置

signal creature_selected(creature_data: Dictionary, hand_index: int)
signal cancelled()

var player_id: int = 0
var player_magic: int = 0
var displayed_creatures: Array = []  # 表示中のクリーチャー（{data, hand_index, can_summon, reason}）

# UI要素
var panel: Panel
var title_label: Label
var creatures_container: HBoxContainer
var scroll_container: ScrollContainer
var cancel_button: Button
var creature_panels: Array = []

# システム参照
var _player_system = null
var _board_system = null

func _ready():
	_setup_ui()

func _setup_ui():
	# 既に初期化済みならスキップ
	if panel != null:
		return
	
	visible = false
	
	# メインパネル
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(1800, 1050)
	add_child(panel)
	
	# パネルスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	style.border_color = Color(0.5, 0.5, 0.6)
	style.border_width_top = 6
	style.border_width_bottom = 6
	style.border_width_left = 6
	style.border_width_right = 6
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", style)
	
	# VBoxContainer
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 30)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	panel.add_child(margin)
	margin.add_child(vbox)
	
	# タイトル
	title_label = Label.new()
	title_label.text = "クリーチャーを配置（空き地を選択して配置）"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	vbox.add_child(title_label)
	
	# スクロールコンテナ（クリーチャーが多い場合用）
	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.custom_minimum_size = Vector2(0, 700)
	vbox.add_child(scroll_container)
	
	# クリーチャー表示エリア
	creatures_container = HBoxContainer.new()
	creatures_container.alignment = BoxContainer.ALIGNMENT_CENTER
	creatures_container.add_theme_constant_override("separation", 40)
	scroll_container.add_child(creatures_container)
	
	# 配置しないボタン
	cancel_button = Button.new()
	cancel_button.text = "配置しない"
	cancel_button.custom_minimum_size = Vector2(400, 100)
	cancel_button.add_theme_font_size_override("font_size", 36)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_child(cancel_button)
	vbox.add_child(button_container)

func _create_creature_panel(index: int) -> Panel:
	var creature_panel = Panel.new()
	creature_panel.custom_minimum_size = Vector2(420, 600)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.18, 0.28, 1.0)
	panel_style.border_color = Color(0.5, 0.45, 0.6)
	panel_style.border_width_top = 4
	panel_style.border_width_bottom = 4
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	creature_panel.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	var margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_top", 25)
	margin_container.add_theme_constant_override("margin_bottom", 25)
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	creature_panel.add_child(margin_container)
	margin_container.add_child(vbox)
	
	# 属性
	var element_label = Label.new()
	element_label.name = "ElementLabel"
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	element_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(element_label)
	
	# クリーチャー名
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)
	
	# ステータス（ST/HP）
	var stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 32)
	stats_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	vbox.add_child(stats_label)
	
	# スペーサー
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# コスト表示
	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 36)
	cost_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(cost_label)
	
	# 配置条件表示（lands_required）
	var condition_label = Label.new()
	condition_label.name = "ConditionLabel"
	condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	condition_label.add_theme_font_size_override("font_size", 24)
	condition_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(condition_label)
	
	# 配置不可理由表示
	var reason_label = Label.new()
	reason_label.name = "ReasonLabel"
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 22)
	reason_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(reason_label)
	
	# 配置ボタン
	var place_button = Button.new()
	place_button.name = "PlaceButton"
	place_button.text = "配置"
	place_button.custom_minimum_size = Vector2(280, 80)
	place_button.add_theme_font_size_override("font_size", 32)
	place_button.pressed.connect(_on_place_pressed.bind(index))
	vbox.add_child(place_button)
	
	return creature_panel

func setup(p_player_id: int, p_player_magic: int, p_player_system, p_board_system):
	player_id = p_player_id
	player_magic = p_player_magic
	_player_system = p_player_system
	_board_system = p_board_system

func show_selection(creatures_with_status: Array):
	"""クリーチャー選択画面を表示
	
	Args:
		creatures_with_status: [{data, hand_index, can_summon, reason}, ...]
	"""
	displayed_creatures = creatures_with_status
	
	# 既存のパネルをクリア
	for child in creatures_container.get_children():
		child.queue_free()
	creature_panels.clear()
	
	# クリーチャーがいない場合
	if creatures_with_status.is_empty():
		title_label.text = "配置できるクリーチャーがありません"
		_center_panel()
		visible = true
		return
	
	# 各クリーチャーのパネルを作成
	for i in range(creatures_with_status.size()):
		var creature_info = creatures_with_status[i]
		var creature_panel = _create_creature_panel(i)
		creatures_container.add_child(creature_panel)
		creature_panels.append(creature_panel)
		_update_creature_panel(creature_panel, creature_info)
	
	# 中央に配置
	_center_panel()
	visible = true

func _update_creature_panel(creature_panel: Panel, creature_info: Dictionary):
	var margin_container = creature_panel.get_child(0)
	var vbox = margin_container.get_child(0)
	
	var element_label = vbox.get_node("ElementLabel")
	var name_label = vbox.get_node("NameLabel")
	var stats_label = vbox.get_node("StatsLabel")
	var cost_label = vbox.get_node("CostLabel")
	var condition_label = vbox.get_node("ConditionLabel")
	var reason_label = vbox.get_node("ReasonLabel")
	var place_button = vbox.get_node("PlaceButton")
	
	var creature_data = creature_info.get("data", {})
	var can_summon = creature_info.get("can_summon", false)
	var reason = creature_info.get("reason", "")
	
	# 属性
	var element = creature_data.get("element", "neutral")
	element_label.text = "【%s】" % _get_element_name(element)
	element_label.add_theme_color_override("font_color", _get_element_color(element))
	
	# 名前
	name_label.text = creature_data.get("name", "???")
	
	# ステータス
	var st = creature_data.get("ST", creature_data.get("st", 0))
	var hp = creature_data.get("HP", creature_data.get("hp", 0))
	stats_label.text = "ST:%d / HP:%d" % [st, hp]
	
	# コスト
	var cost = _get_creature_cost(creature_data)
	cost_label.text = "コスト: %dG" % cost
	
	# 配置条件
	var lands_required = _get_lands_required(creature_data)
	if not lands_required.is_empty():
		var condition_texts = []
		for land in lands_required:
			condition_texts.append(_get_element_name(land))
		condition_label.text = "必要土地: " + ", ".join(condition_texts)
	else:
		condition_label.text = ""
	
	# 配置不可理由
	if not can_summon and not reason.is_empty():
		reason_label.text = reason
		reason_label.visible = true
	else:
		reason_label.visible = false
	
	# ボタン状態
	place_button.disabled = not can_summon
	if not can_summon:
		place_button.text = "配置不可"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		place_button.text = "配置"
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		cost_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))

func _get_creature_cost(creature_data: Dictionary) -> int:
	var cost_data = creature_data.get("cost", {})
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	return int(cost_data)

func _get_lands_required(creature_data: Dictionary) -> Array:
	# cost_lands_required（フラット化済み）
	if creature_data.has("cost_lands_required"):
		var lands = creature_data.get("cost_lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
	# cost.lands_required
	var cost = creature_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		var lands = cost.get("lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
	return []

func _get_element_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		"neutral": return "無"
		_: return element

func _get_element_color(element: String) -> Color:
	match element:
		"fire": return Color(1.0, 0.5, 0.3)
		"water": return Color(0.3, 0.6, 1.0)
		"earth": return Color(0.8, 0.6, 0.3)
		"wind": return Color(0.3, 1.0, 0.5)
		"neutral": return Color(0.7, 0.7, 0.7)
		_: return Color(1.0, 1.0, 1.0)

func _center_panel():
	var viewport_size = get_viewport_rect().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2 - 150
	)

func hide_selection():
	visible = false

func _on_place_pressed(index: int):
	if index < displayed_creatures.size():
		var creature_info = displayed_creatures[index]
		if creature_info.get("can_summon", false):
			hide_selection()
			emit_signal("creature_selected", creature_info.get("data", {}), creature_info.get("hand_index", -1))

func _on_cancel_pressed():
	hide_selection()
	emit_signal("cancelled")
