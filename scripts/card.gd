extends ColorRect
# カード表示・操作・選択スクリプト - クリーンアップ版

var is_dragging = false
var card_data = {}
var mouse_over = false
var card_index = -1  # 手札内のインデックス
var is_selectable = false  # 選択可能かどうか
var is_selected = false  # 選択中かどうか
var original_position: Vector2  # 元の位置
var original_size: Vector2  # 元のサイズ

# カード選択シグナル
signal card_clicked(index: int)

func _ready():
	# マウスイベントを接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# 元のサイズを記録
	original_size = size
	
	# マウスフィルターを設定（重要！）
	mouse_filter = Control.MOUSE_FILTER_STOP

func _on_mouse_entered():
	mouse_over = true
	if not is_dragging and not is_selectable:
		z_index = 5  # ホバー時に少し前面に

func _on_mouse_exited():
	mouse_over = false
	if not is_dragging and not is_selectable:
		z_index = 0  # 元に戻す

func load_card_data(card_id):
	var file = FileAccess.open("res://data/Cards.json", FileAccess.READ)
	if file == null:
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
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
		"火": 
			color = Color(1.0, 0.4, 0.4)
		"水": 
			color = Color(0.4, 0.6, 1.0)
		"風": 
			color = Color(0.4, 1.0, 0.6)
		"土": 
			color = Color(0.8, 0.6, 0.3)

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

# カードを選択可能にする
func set_selectable(selectable: bool, index: int = -1):
	is_selectable = selectable
	card_index = index
	
	# 全ての子要素のマウスフィルターを設定
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not selectable:
		# 選択モード解除時は元に戻す
		if is_selected:
			deselect_card()

# カードを選択状態にする（1段階目）
func select_card():
	if is_selected:
		return
	
	is_selected = true
	original_position = position
	
	# カードを大きく表示
	z_index = 100
	
	# アニメーション（安全に実行）
	if get_tree():
		var tween = get_tree().create_tween()
		if tween:
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.set_ease(Tween.EASE_OUT)
			
			# 上に移動して1.4倍に拡大
			tween.parallel().tween_property(self, "position", 
				Vector2(position.x - 20, position.y - 60), 0.3)
			tween.parallel().tween_property(self, "scale", 
				Vector2(1.4, 1.4), 0.3)

# カードの選択を解除
func deselect_card():
	if not is_selected:
		return
	
	is_selected = false
	z_index = 0
	
	# 元の位置とサイズに戻す
	position = original_position
	scale = Vector2(1.0, 1.0)
	
	# 色を元に戻す
	modulate = Color(1.0, 1.0, 1.0)

# カードが決定された時の処理（2段階目）
func on_card_confirmed():
	if is_selectable and is_selected and card_index >= 0:
		# UIManagerに通知 - 複数のパスを試す
		var ui_manager = null
		# 再帰的に探す
		if not ui_manager:
			ui_manager = find_ui_manager_recursive(get_tree().get_root())
		
		if ui_manager and ui_manager.has_method("_on_card_button_pressed"):
			ui_manager._on_card_button_pressed(card_index)
		else:
			print("WARNING: UIManagerが見つかりません")

# UIManagerを再帰的に探す
func find_ui_manager_recursive(node: Node) -> Node:
	if node.name == "UIManager":
		return node
	for child in node.get_children():
		var result = find_ui_manager_recursive(child)
		if result:
			return result
	return null
	
# 通常の入力処理とカード選択処理
func _input(event):
	# カード選択モード時のクリック処理
	if is_selectable and mouse_over and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not is_selected:
				# 1回目のクリック：選択（プレビュー）
				# 他のカードの選択を解除（親ノードの全子要素をチェック）
				var parent = get_parent()
				if parent:
					for sibling in parent.get_children():
						if sibling != self and sibling.has_method("deselect_card"):
							sibling.deselect_card()
				
				select_card()
			else:
				# 2回目のクリック：決定
				on_card_confirmed()
			
			get_viewport().set_input_as_handled()
			return
	
	# 選択モード中はドラッグ無効
	if is_selectable:
		return
	
	# ドラッグ中の移動処理
	if is_dragging and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - size / 2
		return
	
	# マウスボタンを離した時の処理
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				is_dragging = false
				z_index = 0
				return
	
	# ドラッグ開始処理
	if not is_selectable and mouse_over and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_dragging = true
			z_index = 10
			get_viewport().set_input_as_handled()
