extends Control

# カード譲渡タイルUI
# 3種類（クリーチャー/アイテム/スペル）から選択

signal type_selected(card_type: String)
signal cancelled()

var card_system = null
var player_id: int = 0

# UI要素
var panel: Panel
var title_label: Label
var types_container: HBoxContainer
var cancel_button: Button
var type_panels: Array = []  # 3つのタイプパネル

# タイプ情報
var type_info = [
	{"type": "creature", "name": "クリーチャー", "color": Color(1.0, 0.7, 0.7)},
	{"type": "item", "name": "アイテム", "color": Color(0.7, 1.0, 0.7)},
	{"type": "spell", "name": "スペル", "color": Color(0.7, 0.7, 1.0)}
]

func _ready():
	_setup_ui()

func _setup_ui():
	# 既に初期化済みならスキップ
	if panel != null:
		return
	
	visible = false
	
	# メインパネル（magic_tile_uiと同じサイズ）
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(1800, 1050)
	add_child(panel)
	
	# パネルスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.1, 0.95)
	style.border_color = Color(0.4, 0.6, 0.4)
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
	title_label.text = "カードの種類を選択"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	vbox.add_child(title_label)
	
	# タイプ表示エリア
	types_container = HBoxContainer.new()
	types_container.alignment = BoxContainer.ALIGNMENT_CENTER
	types_container.add_theme_constant_override("separation", 80)
	vbox.add_child(types_container)
	
	# 3つのタイプパネルを作成
	for i in range(3):
		var type_panel = _create_type_panel(i)
		types_container.add_child(type_panel)
		type_panels.append(type_panel)
	
	# キャンセルボタン
	cancel_button = Button.new()
	cancel_button.text = "キャンセル"
	cancel_button.custom_minimum_size = Vector2(450, 110)
	cancel_button.add_theme_font_size_override("font_size", 42)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_child(cancel_button)
	vbox.add_child(button_container)

func _create_type_panel(index: int) -> Panel:
	var type_panel = Panel.new()
	type_panel.custom_minimum_size = Vector2(500, 680)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.2, 0.15, 1.0)
	panel_style.border_color = Color(0.4, 0.5, 0.4)
	panel_style.border_width_top = 4
	panel_style.border_width_bottom = 4
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	type_panel.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	type_panel.add_child(margin)
	margin.add_child(vbox)
	
	# タイプ名
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 64)
	vbox.add_child(name_label)
	
	# 説明
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 40)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
	# スペーサー
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 選択ボタン
	var select_button = Button.new()
	select_button.name = "SelectButton"
	select_button.text = "選択"
	select_button.custom_minimum_size = Vector2(350, 100)
	select_button.add_theme_font_size_override("font_size", 42)
	select_button.pressed.connect(_on_type_selected.bind(index))
	vbox.add_child(select_button)
	
	return type_panel

func setup(p_card_system, p_player_id: int):
	card_system = p_card_system
	player_id = p_player_id

func show_selection():
	# 各タイプの表示を更新
	for i in range(3):
		var info = type_info[i]
		var type_panel = type_panels[i]
		var margin = type_panel.get_child(0)
		var vbox = margin.get_child(0)
		
		var name_label = vbox.get_node("NameLabel")
		var desc_label = vbox.get_node("DescLabel")
		var select_button = vbox.get_node("SelectButton")
		
		# タイプ名と色
		name_label.text = info["name"]
		name_label.add_theme_color_override("font_color", info["color"])
		
		# 説明文
		match info["type"]:
			"creature":
				desc_label.text = "山札からクリーチャーカードを1枚引く"
			"item":
				desc_label.text = "山札からアイテムカードを1枚引く"
			"spell":
				desc_label.text = "山札からスペルカードを1枚引く"
		
		# 利用可能かチェック
		var has_type = true
		if card_system and card_system.has_method("has_deck_card_type"):
			has_type = card_system.has_deck_card_type(player_id, info["type"])
		
		select_button.disabled = not has_type
		if not has_type:
			select_button.text = "なし"
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			select_button.text = "選択"
	
	# 中央に配置
	_center_panel()
	visible = true

func _center_panel():
	var viewport_size = get_viewport_rect().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2 - 150  # 150ピクセル上に
	)

func hide_selection():
	visible = false

func _on_type_selected(index: int):
	var card_type = type_info[index]["type"]
	hide_selection()
	emit_signal("type_selected", card_type)

func _on_cancel_pressed():
	hide_selection()
	emit_signal("cancelled")
