extends Control

# カード購入タイルUI
# スペル・アイテムから3枚表示し、1枚選択購入

signal card_purchased(card_data: Dictionary)
signal cancelled()

var player_id: int = 0
var player_magic: int = 0
var displayed_cards: Array = []  # 表示中の3枚

# UI要素
var panel: Panel
var title_label: Label
var cards_container: HBoxContainer
var cancel_button: Button
var card_panels: Array = []  # 3つのカードパネル

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
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	style.border_color = Color(0.6, 0.5, 0.2)
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
	title_label.text = "カードを購入（価格: コストの50%）"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(title_label)
	
	# カード表示エリア
	cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 80)
	vbox.add_child(cards_container)
	
	# 3つのカードパネルを作成
	for i in range(3):
		var card_panel = _create_card_panel(i)
		cards_container.add_child(card_panel)
		card_panels.append(card_panel)
	
	# 買わないボタン
	cancel_button = Button.new()
	cancel_button.text = "買わない"
	cancel_button.custom_minimum_size = Vector2(400, 100)
	cancel_button.add_theme_font_size_override("font_size", 36)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_child(cancel_button)
	vbox.add_child(button_container)

func _create_card_panel(index: int) -> Panel:
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(500, 680)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	card_style.border_color = Color(0.4, 0.4, 0.5)
	card_style.border_width_top = 4
	card_style.border_width_bottom = 4
	card_style.border_width_left = 4
	card_style.border_width_right = 4
	card_style.corner_radius_top_left = 16
	card_style.corner_radius_top_right = 16
	card_style.corner_radius_bottom_left = 16
	card_style.corner_radius_bottom_right = 16
	card_panel.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	card_panel.add_child(margin)
	margin.add_child(vbox)
	
	# カードタイプ
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(type_label)
	
	# カード名
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)
	
	# 名前と効果説明の間のスペーサー
	var name_effect_spacer = Control.new()
	name_effect_spacer.custom_minimum_size = Vector2(0, 20)
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
	
	# 購入価格表示
	var price_label = Label.new()
	price_label.name = "PriceLabel"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 48)
	price_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(price_label)
	
	# 購入ボタン
	var buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "購入"
	buy_button.custom_minimum_size = Vector2(300, 90)
	buy_button.add_theme_font_size_override("font_size", 36)
	buy_button.pressed.connect(_on_buy_pressed.bind(index))
	vbox.add_child(buy_button)
	
	return card_panel

func setup(p_player_id: int, p_player_magic: int):
	player_id = p_player_id
	player_magic = p_player_magic

func show_selection(cards: Array):
	displayed_cards = cards
	
	# 3枚のカードを表示
	for i in range(3):
		var card_panel = card_panels[i]
		
		if i < cards.size():
			var card_data = cards[i]
			_update_card_panel(card_panel, card_data, true)
		else:
			_update_card_panel(card_panel, {}, false)
	
	# 中央に配置
	_center_panel()
	visible = true

func _update_card_panel(card_panel: Panel, card_data: Dictionary, show: bool):
	var margin = card_panel.get_child(0)
	var vbox = margin.get_child(0)
	
	var type_label = vbox.get_node("TypeLabel")
	var name_label = vbox.get_node("NameLabel")
	var effect_label = vbox.get_node("EffectLabel")
	var price_label = vbox.get_node("PriceLabel")
	var buy_button = vbox.get_node("BuyButton")
	
	if not show or card_data.is_empty():
		card_panel.visible = false
		return
	
	card_panel.visible = true
	
	# カードタイプ
	var card_type = card_data.get("type", "")
	match card_type:
		"spell":
			type_label.text = "【スペル】"
			type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		"item":
			type_label.text = "【アイテム】"
			type_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		_:
			type_label.text = "【" + card_type + "】"
	
	# カード名
	name_label.text = card_data.get("name", "???")
	
	# 効果説明
	var effect_text = card_data.get("effect", "")
	if effect_text.length() > 100:
		effect_text = effect_text.substr(0, 97) + "..."
	effect_label.text = effect_text
	
	# 購入価格（コストの50%、切り上げ）
	var cost_data = card_data.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)
	else:
		cost = int(cost_data)
	var price = int(ceil(cost / 2.0))
	price_label.text = "購入: " + str(price) + "EP"
	
	# 購入可能かチェック
	var can_buy = player_magic >= price
	buy_button.disabled = not can_buy
	if not can_buy:
		buy_button.text = "EP不足"
		price_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		buy_button.text = "購入"
		price_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))

func _center_panel():
	var viewport_size = get_viewport_rect().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2 - 150  # 150ピクセル上に
	)

func hide_selection():
	visible = false

func _on_buy_pressed(index: int):
	if index < displayed_cards.size():
		var card_data = displayed_cards[index]
		hide_selection()
		emit_signal("card_purchased", card_data)

func _on_cancel_pressed():
	hide_selection()
	emit_signal("cancelled")
