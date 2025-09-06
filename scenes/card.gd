extends ColorRect

var is_dragging = false
var card_data = {}
var mouse_over = false

func _ready():
	print("カード準備完了！")
	# マウスイベントを接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	load_card_data(3)

func _on_mouse_entered():
	mouse_over = true
	if not is_dragging:
		z_index = 5  # ホバー時に少し前面に

func _on_mouse_exited():
	mouse_over = false
	if not is_dragging:
		z_index = 0  # 元に戻す

func load_card_data(card_id):
	var file = FileAccess.open("res://data/Cards.json", FileAccess.READ)
	if file == null:
		print("JSONファイルが開けません")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("JSONパースエラー")
		return
	
	var data = json.data
	for card in data.cards:
		if card.id == card_id:
			card_data = card
			update_label()
			set_element_color()
			set_rarity_border()
			break

func set_element_color():
	match card_data.element:
		"火": color = Color(1.0, 0.4, 0.4)
		"水": color = Color(0.4, 0.6, 1.0)
		"風": color = Color(0.4, 1.0, 0.6)
		"土": color = Color(0.8, 0.6, 0.3)

func set_rarity_border():
	var border = get_node_or_null("RarityBorder")
	if border:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.draw_center = false
		
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		
		match card_data.get("rarity", "common"):
			"legendary":
				style.border_color = Color(1.0, 0.8, 0.0, 1)
			"rare":
				style.border_color = Color(0.1, 0.1, 0.1, 1)
			"uncommon":
				style.border_color = Color(0.5, 0.5, 0.5, 1)
			_:
				style.border_color = Color(1.0, 1.0, 1.0, 1)
		
		border.add_theme_stylebox_override("panel", style)

func update_label():
	var name_label = get_node_or_null("NameLabel")
	if name_label:
		name_label.text = card_data.name
		name_label.add_theme_color_override("font_color", Color.BLACK)
	
	var cost_label = get_node_or_null("CostLabel")
	if cost_label:
		cost_label.text = str(card_data.cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	var stats_label = get_node_or_null("StatsLabel")
	if stats_label:
		stats_label.text = "攻:" + str(card_data.damage) + " 防:" + str(card_data.block)
		stats_label.add_theme_color_override("font_color", Color.BLACK)
	
	var desc_label = get_node_or_null("DescriptionLabel")
	if desc_label:
		if card_data.type == "攻撃":
			desc_label.text = "敵に" + str(card_data.damage) + "ダメージを与える"
		elif card_data.type == "防御":
			desc_label.text = str(card_data.block) + "の防御を得る"
		elif card_data.type == "特殊":
			desc_label.text = card_data.element + "属性の特殊効果"
		else:
			desc_label.text = card_data.element + "属性"
		
		desc_label.add_theme_color_override("font_color", Color.BLACK)

func _input(event):
	# ドラッグ中の移動処理
	if is_dragging and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - size / 2
		return
	
	# マウスボタンを離した時の処理（どこでも反応）
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				is_dragging = false
				z_index = 0
				print("カードドロップ: ", card_data.name)
				return
	
	# クリック処理（マウスオーバー時のみ）
	if mouse_over and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("カードクリック！", card_data.name)
			is_dragging = true
			z_index = 10
			get_viewport().set_input_as_handled()
