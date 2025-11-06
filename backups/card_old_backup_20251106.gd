extends ColorRect
# カード表示・操作・選択スクリプト - サイズ対応版

var is_dragging = false
var card_data = {}
var mouse_over = false
var card_index = -1
var is_selectable = false
var is_selected = false
var original_position: Vector2
var original_size: Vector2

# TODO: 将来実装予定
# signal card_clicked(index: int)

func _ready():
	# デフォルトのカード背景色を設定（シーンのデザイン用）
	color = Color(0.6, 0.6, 0.6, 1)  # グレー
	
	# マウスイベントを接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# 元のサイズを記録
	original_size = size
	
	# マウスフィルターを設定（重要！）
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# サイズ変更時に子要素を調整
	resized.connect(_on_resized)
	_adjust_children_size()

# サイズ変更時の処理
func _on_resized():
	_adjust_children_size()

# 子要素のサイズを親に合わせて調整（既存ノードのみ）
func _adjust_children_size():
	# Card.tscnの元サイズ（120x160）を基準とした比率
	var original_width = 120.0
	var original_height = 160.0
	var scale_x = size.x / original_width
	var scale_y = size.y / original_height
	
	# 各要素をCard.tscnで設定した位置から比率で拡大
	var name_label = get_node_or_null("NameLabel")
	if name_label:
		name_label.position = Vector2(4, 3) * Vector2(scale_x, scale_y)
		name_label.size = Vector2(112, 8) * Vector2(scale_x, scale_y)
		name_label.add_theme_font_size_override("font_size", max(int(5 * scale_x), 5))
	
	var cost_label = get_node_or_null("CostLabel")
	if cost_label:
		cost_label.position = Vector2(111, 2) * Vector2(scale_x, scale_y)
		cost_label.size = Vector2(8, 11) * Vector2(scale_x, scale_y)
		cost_label.add_theme_font_size_override("font_size", max(int(7 * scale_x), 7))
	
	var card_image = get_node_or_null("CardImage")
	if card_image:
		card_image.position = Vector2(2, 1) * Vector2(scale_x, scale_y)
		card_image.size = Vector2(116, 110) * Vector2(scale_x, scale_y)
	
	var desc_bg = get_node_or_null("DescBG")
	if desc_bg:
		desc_bg.position = Vector2(12, 115) * Vector2(scale_x, scale_y)
		desc_bg.size = Vector2(94, 43) * Vector2(scale_x, scale_y)
	
	var stats_label = get_node_or_null("StatsLabel")
	if stats_label:
		stats_label.position = Vector2(51, 117) * Vector2(scale_x, scale_y)
		stats_label.size = Vector2(54, 8) * Vector2(scale_x, scale_y)
		stats_label.add_theme_font_size_override("font_size", max(int(5 * scale_x), 5))
	
	var desc_label = get_node_or_null("DescriptionLabel")
	if desc_label:
		desc_label.position = Vector2(13, 130) * Vector2(scale_x, scale_y)
		desc_label.size = Vector2(92, 28) * Vector2(scale_x, scale_y)
		desc_label.add_theme_font_size_override("font_size", max(int(5 * scale_x), 5))
	
	var rarity_border = get_node_or_null("RarityBorder")
	if rarity_border:
		rarity_border.position = Vector2.ZERO
		rarity_border.size = Vector2(120, 160) * Vector2(scale_x, scale_y)

func _on_mouse_entered():
	mouse_over = true
	if not is_dragging and not is_selectable:
		z_index = 5

func _on_mouse_exited():
	mouse_over = false
	if not is_dragging and not is_selectable:
		z_index = 0

func load_card_data(card_id):
	# CardLoaderを使用
	if CardLoader:
		card_data = CardLoader.get_card_by_id(card_id)
		if not card_data.is_empty():
			update_label()
			set_element_color()    # 背景を属性色に
			set_rarity_border()    # 枠をレアリティ色に
			load_creature_image(card_id)  # 画像を読み込む
			_adjust_children_size()
		return
	
	# フォールバック：Cards.json（古い実装）
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
			_adjust_children_size()
			break

# クリーチャーの動的データを読み込む（バトル中の変更を反映）
func load_dynamic_creature_data(data: Dictionary):
	if data.is_empty():
		return
	
	# 渡されたデータをそのまま使用（バトル中の変更が含まれる）
	card_data = data.duplicate()
	
	# 表示を更新
	update_dynamic_stats()
	set_element_color()
	set_rarity_border()
	_adjust_children_size()

# 動的ステータスを更新（MHP/ST増加を反映）
func update_dynamic_stats():
	var name_label = get_node_or_null("NameLabel")
	if name_label:
		name_label.text = card_data.get("name", "???")
		name_label.add_theme_color_override("font_color", Color.WHITE)
	
	var cost_label = get_node_or_null("CostLabel")
	if cost_label:
		var cost = card_data.get("cost", 1)
		if typeof(cost) == TYPE_DICTIONARY and cost.has("mp"):
			cost = cost.mp
		cost_label.text = str(cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	var stats_label = get_node_or_null("StatsLabel")
	if stats_label:
		# 基礎値 + 増加分
		var base_ap = card_data.get("ap", 0)
		var base_up_ap = card_data.get("base_up_ap", 0)
		var total_ap = base_ap + base_up_ap
		
		var base_hp = card_data.get("hp", 0)
		var base_up_hp = card_data.get("base_up_hp", 0)
		var total_hp = base_hp + base_up_hp
		
		# 変化がある場合は色を変える
		var ap_text = str(total_ap)
		var hp_text = str(total_hp)
		
		if base_up_ap > 0:
			ap_text = "[color=green]" + ap_text + "[/color]"
		elif base_up_ap < 0:
			ap_text = "[color=red]" + ap_text + "[/color]"
		
		if base_up_hp > 0:
			hp_text = "[color=green]" + hp_text + "[/color]"
		elif base_up_hp < 0:
			hp_text = "[color=red]" + hp_text + "[/color]"
		
		stats_label.text = "攻:" + ap_text + " 防:" + hp_text
		stats_label.add_theme_color_override("font_color", Color.BLACK)
		stats_label.bbcode_enabled = true
	
	var desc_label = get_node_or_null("DescriptionLabel")
	if desc_label:
		var element = card_data.get("element", "")
		var ability_text = card_data.get("ability", "")
		
		# アイテム情報を追加
		var items = card_data.get("items", [])
		if items.size() > 0:
			var item_names = []
			for item in items:
				item_names.append(item.get("name", "???"))
			ability_text += "\n[装備: " + ", ".join(item_names) + "]"
		
		# 永続効果を表示
		var permanent_effects = card_data.get("permanent_effects", [])
		if permanent_effects.size() > 0:
			ability_text += "\n[永続効果: " + str(permanent_effects.size()) + "個]"
		
		# 一時効果を表示
		var temporary_effects = card_data.get("temporary_effects", [])
		if temporary_effects.size() > 0:
			ability_text += "\n[一時効果: " + str(temporary_effects.size()) + "個]"
		
		desc_label.text = ability_text if not ability_text.is_empty() else element + "属性"
		desc_label.add_theme_color_override("font_color", Color.BLACK)

func set_element_color():
	# 属性色をカード背景（グレー部分）に設定
	var element = card_data.get("element", "")
	
	# 属性に応じて背景色を設定
	match element:
		"fire":
			color = Color(0.8, 0.3, 0.2)  # 赤系
		"water":
			color = Color(0.3, 0.5, 0.8)  # 青系
		"wind":
			color = Color(0.3, 0.7, 0.4)  # 緑系
		"earth":
			color = Color(0.7, 0.5, 0.3)  # 茶色系
		_:
			color = Color(0.6, 0.6, 0.6)  # グレー（無属性）

# クリーチャー画像を読み込む
func load_creature_image(card_id: int):
	var card_image = get_node_or_null("CardImage")
	if not card_image:
		return
	
	# 画像パスを構築（IDベース）
	var image_path = "res://assets/images/creatures/" + str(card_id) + ".png"
	
	# 画像ファイルが存在するか確認
	if FileAccess.file_exists(image_path):
		var texture = load(image_path)
		if texture:
			card_image.texture = texture
			# 画像を枠内に収めるための設定（シーンファイルで既に設定済み）
	else:
		# 画像がない場合はデフォルト表示（属性に応じた色）
		var placeholder = Image.create(100, 98, false, Image.FORMAT_RGBA8)
		
		# 属性に応じた色で塗りつぶし
		var element = card_data.get("element", "")
		var fill_color = Color(0.5, 0.5, 0.5)  # デフォルトはグレー
		
		match element:
			"fire":
				fill_color = Color(0.9, 0.4, 0.3)
			"water":
				fill_color = Color(0.4, 0.6, 0.9)
			"wind":
				fill_color = Color(0.4, 0.8, 0.5)
			"earth":
				fill_color = Color(0.8, 0.6, 0.4)
		
		placeholder.fill(fill_color)
		card_image.texture = ImageTexture.create_from_image(placeholder)

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
		name_label.text = card_data.get("name", "???")
		name_label.add_theme_color_override("font_color", Color.WHITE)
	
	var cost_label = get_node_or_null("CostLabel")
	if cost_label:
		var cost = card_data.get("cost", 1)
		# costが辞書の場合は変換
		if typeof(cost) == TYPE_DICTIONARY and cost.has("mp"):
			cost = cost.mp
		cost_label.text = str(cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	var stats_label = get_node_or_null("StatsLabel")
	if stats_label:
		var damage = card_data.get("ap", card_data.get("damage", 0))
		var block = card_data.get("hp", card_data.get("block", 0))
		stats_label.text = "攻:" + str(damage) + " 防:" + str(block)
		stats_label.add_theme_color_override("font_color", Color.BLACK)
	
	var desc_label = get_node_or_null("DescriptionLabel")
	if desc_label:
		var card_type = card_data.get("type", "")
		var damage = card_data.get("ap", card_data.get("damage", 0))
		var block = card_data.get("hp", card_data.get("block", 0))
		var element = card_data.get("element", "")
		
		if card_type == "攻撃":
			desc_label.text = "敵に" + str(damage) + "ダメージを与える"
		elif card_type == "防御":
			desc_label.text = str(block) + "の防御を得る"
		elif card_type == "特殊":
			desc_label.text = element + "属性の特殊効果"
		else:
			desc_label.text = element + "属性"
		
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
	
	# ドラッグ機能は無効化（将来的に必要なら再実装）
	# if not is_selectable and mouse_over and event is InputEventMouseButton:
	#     if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	#         is_dragging = true
	#         z_index = 10
	#         get_viewport().set_input_as_handled()
