extends ColorRect

var is_dragging = false
var card_data = {}

func _ready():
	print("カード準備完了！")
	load_card_data(3)

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
	print("=== RARITY DEBUG ===")
	print("Card data rarity: ", card_data.get("rarity", "NOT FOUND"))
	
	var border = get_node_or_null("RarityBorder")
	if border:
		var style = StyleBoxFlat.new()
		
		# 中央を透明に、枠だけ表示
		style.bg_color = Color(0, 0, 0, 0)  # 透明
		style.draw_center = false  # 中央を描画しない
		
		# 枠の設定
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		
		# レアリティで枠色を変更
		match card_data.get("rarity", "common"):
			"legendary":
				style.border_color = Color(1.0, 0.8, 0.0, 1)  # 金
			"rare":
				style.border_color = Color(0.1, 0.1, 0.1, 1)  # 黒
			"uncommon":
				style.border_color = Color(0.5, 0.5, 0.5, 1)  # グレー
			_:
				style.border_color = Color(1.0, 1.0, 1.0, 1)  # 白
		
		border.add_theme_stylebox_override("panel", style)
		print("Border style applied: ", card_data.get("rarity", "common"))
		
		
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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_global_mouse_position()
			var card_rect = Rect2(global_position, size)
			
			if card_rect.has_point(mouse_pos):
				print("カードクリック！")
				is_dragging = event.pressed
				# ドラッグ中は最前面に
				if event.pressed:
					z_index = 10
				else:
					z_index = 0
	
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - size / 2
