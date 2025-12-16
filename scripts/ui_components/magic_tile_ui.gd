extends Control

# 魔法タイルUI
# 全スペルから3枚表示し、1枚選択使用

signal spell_selected(spell_data: Dictionary)
signal cancelled()

var player_id: int = 0
var player_magic: int = 0
var displayed_spells: Array = []  # 表示中の3枚

# UI要素
var panel: Panel
var title_label: Label
var spells_container: HBoxContainer
var cancel_button: Button
var spell_panels: Array = []  # 3つのスペルパネル

func _ready():
	_setup_ui()

func _setup_ui():
	# 既に初期化済みならスキップ
	if panel != null:
		return
	
	visible = false
	
	# メインパネル（3倍サイズ）
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(2200, 1240)
	add_child(panel)
	
	# パネルスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.25, 0.95)
	style.border_color = Color(0.6, 0.4, 0.8)
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
	title_label.text = "魔法を使う（コストを支払い使用）"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	vbox.add_child(title_label)
	
	# スペル表示エリア
	spells_container = HBoxContainer.new()
	spells_container.alignment = BoxContainer.ALIGNMENT_CENTER
	spells_container.add_theme_constant_override("separation", 80)
	vbox.add_child(spells_container)
	
	# 3つのスペルパネルを作成
	for i in range(3):
		var spell_panel = _create_spell_panel(i)
		spells_container.add_child(spell_panel)
		spell_panels.append(spell_panel)
	
	# 使わないボタン
	cancel_button = Button.new()
	cancel_button.text = "使わない"
	cancel_button.custom_minimum_size = Vector2(600, 150)
	cancel_button.add_theme_font_size_override("font_size", 48)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_child(cancel_button)
	vbox.add_child(button_container)

func _create_spell_panel(index: int) -> Panel:
	var spell_panel = Panel.new()
	spell_panel.custom_minimum_size = Vector2(600, 880)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.15, 0.3, 1.0)
	panel_style.border_color = Color(0.5, 0.4, 0.6)
	panel_style.border_width_top = 4
	panel_style.border_width_bottom = 4
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	spell_panel.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	spell_panel.add_child(margin)
	margin.add_child(vbox)
	
	# スペルタイプ
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 32)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
	vbox.add_child(type_label)
	
	# スペル名
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)
	
	# スペル名と効果説明の間のスペーサー
	var name_effect_spacer = Control.new()
	name_effect_spacer.custom_minimum_size = Vector2(0, 30)  # ここで隙間を調整
	vbox.add_child(name_effect_spacer)
	
	# 効果説明
	var effect_label = Label.new()
	effect_label.name = "EffectLabel"
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.add_theme_font_size_override("font_size", 40)
	effect_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	effect_label.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(effect_label)
	
	# スペーサー
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# コスト表示
	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 48)
	cost_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(cost_label)
	
	# 使用ボタン
	var use_button = Button.new()
	use_button.name = "UseButton"
	use_button.text = "使用"
	use_button.custom_minimum_size = Vector2(300, 90)
	use_button.add_theme_font_size_override("font_size", 36)
	use_button.pressed.connect(_on_use_pressed.bind(index))
	vbox.add_child(use_button)
	
	return spell_panel

func setup(p_player_id: int, p_player_magic: int):
	player_id = p_player_id
	player_magic = p_player_magic

func show_selection(spells: Array):
	displayed_spells = spells
	
	# 3枚のスペルを表示
	for i in range(3):
		var spell_panel = spell_panels[i]
		
		if i < spells.size():
			var spell_data = spells[i]
			_update_spell_panel(spell_panel, spell_data, true)
		else:
			_update_spell_panel(spell_panel, {}, false)
	
	# 中央に配置
	_center_panel()
	visible = true

func _update_spell_panel(spell_panel: Panel, spell_data: Dictionary, show: bool):
	var margin = spell_panel.get_child(0)
	var vbox = margin.get_child(0)
	
	var type_label = vbox.get_node("TypeLabel")
	var name_label = vbox.get_node("NameLabel")
	var effect_label = vbox.get_node("EffectLabel")
	var cost_label = vbox.get_node("CostLabel")
	var use_button = vbox.get_node("UseButton")
	
	if not show or spell_data.is_empty():
		spell_panel.visible = false
		return
	
	spell_panel.visible = true
	
	# スペルタイプ
	var spell_type = spell_data.get("spell_type", "")
	type_label.text = "【%s】" % spell_type if spell_type else "【スペル】"
	
	# スペル名
	name_label.text = spell_data.get("name", "???")
	
	# 効果説明
	var effect_text = spell_data.get("effect", "")
	if effect_text.length() > 100:
		effect_text = effect_text.substr(0, 97) + "..."
	effect_label.text = effect_text
	
	# コスト
	var cost_data = spell_data.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = int(cost_data)
	cost_label.text = "コスト: " + str(cost) + "G"
	
	# 使用可能かチェック
	var can_use = player_magic >= cost
	use_button.disabled = not can_use
	if not can_use:
		use_button.text = "魔力不足"
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		use_button.text = "使用"
		cost_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))

func _center_panel():
	var viewport_size = get_viewport_rect().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2 - 200  
	)

func hide_selection():
	visible = false

func _on_use_pressed(index: int):
	if index < displayed_spells.size():
		var spell_data = displayed_spells[index]
		hide_selection()
		emit_signal("spell_selected", spell_data)

func _on_cancel_pressed():
	hide_selection()
	emit_signal("cancelled")
