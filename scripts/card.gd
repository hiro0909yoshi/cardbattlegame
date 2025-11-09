extends Control
# カード表示・操作・選択スクリプト - CardFrame.tscn対応版
# 更新日: 2025-11-07

var is_dragging = false
var card_data = {}
var mouse_over = false
var card_index = -1
var is_selectable = false
var is_selected = false
var original_position: Vector2
var original_size: Vector2

# CardFrame.tscnのサイズ定義
const CARDFRAME_WIDTH = 220.0   # CardFrame.tscnの設計サイズ
const CARDFRAME_HEIGHT = 293.0
const GAME_CARD_WIDTH = 290.0   # ゲーム内表示サイズ
const GAME_CARD_HEIGHT = 390.0

func _ready():
	# 元のサイズを記録
	original_size = size
	
	# マウスイベントを接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# マウスフィルターを設定（重要！）
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# サイズ変更時に子要素を調整
	resized.connect(_on_resized)
	_adjust_children_size()

# サイズ変更時の処理
func _on_resized():
	_adjust_children_size()

# 子要素のサイズを親に合わせて調整（CardFrame.tscn対応）
# 注：スケールはhand_display.gdで設定されるため、ここでは何もしない
func _adjust_children_size():
	# フォントサイズはシーンファイルのデフォルト値を使用
	# 必要に応じて将来的に調整可能
	pass

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
			set_element_color()
			load_creature_image(card_id)
			_adjust_children_size()
		return
	
	print("[Card] ERROR: CardLoaderが見つかりません")

# クリーチャーの動的データを読み込む（バトル中の変更を反映）
func load_dynamic_creature_data(data: Dictionary):
	if data.is_empty():
		return
	
	# 渡されたデータをそのまま使用（バトル中の変更が含まれる）
	card_data = data.duplicate()
	
	# 表示を更新
	update_dynamic_stats()
	set_element_color()
	_adjust_children_size()

# 基本ラベル更新（静的データ）
func update_label():
	# コスト
	var cost_label = get_node_or_null("CostBadge/CostCircle/CostLabel")
	if cost_label:
		var cost = card_data.get("cost", 1)
		if typeof(cost) == TYPE_DICTIONARY and cost.has("mp"):
			cost = cost.mp
		cost_label.text = str(cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 名前
	var name_label = get_node_or_null("NameBanner/NameLabel")
	if name_label:
		name_label.text = card_data.get("name", "???")
		name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 攻撃力（AP）
	var left_stat_label = get_node_or_null("LeftStatBadge/LeftStatCircle/LeftStatLabel")
	if left_stat_label:
		var ap = card_data.get("ap", 0)
		left_stat_label.text = str(ap)
		left_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 最大HP
	var right_stat_label = get_node_or_null("RightStatBadge/RightStatCircle/RightStatLabel")
	if right_stat_label:
		var hp = card_data.get("hp", 0)
		right_stat_label.text = str(hp)
		right_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 現在HP（初期状態では最大HPと同じ）
	var current_hp_label = get_node_or_null("CurrentHPBadge/CurrentHPCircle/CurrentHPLabel")
	if current_hp_label:
		var hp = card_data.get("hp", 0)
		current_hp_label.text = str(hp)
		current_hp_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 説明文
	var desc_label = get_node_or_null("DescriptionBox/DescriptionLabel")
	if desc_label:
		var ability_text = card_data.get("ability", "")
		var element = card_data.get("element", "")
		
		if ability_text.is_empty():
			ability_text = element + "属性"
		
		desc_label.text = ability_text
		desc_label.add_theme_color_override("font_color", Color(0.25, 0.2, 0.15))

# 動的ステータスを更新（MHP/ST増加を反映）
func update_dynamic_stats():
	# コスト
	var cost_label = get_node_or_null("CostBadge/CostCircle/CostLabel")
	if cost_label:
		var cost = card_data.get("cost", 1)
		if typeof(cost) == TYPE_DICTIONARY and cost.has("mp"):
			cost = cost.mp
		cost_label.text = str(cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 名前
	var name_label = get_node_or_null("NameBanner/NameLabel")
	if name_label:
		name_label.text = card_data.get("name", "???")
		name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 攻撃力（AP）- 基礎値 + 増加分
	var left_stat_label = get_node_or_null("LeftStatBadge/LeftStatCircle/LeftStatLabel")
	if left_stat_label:
		var base_ap = card_data.get("ap", 0)
		var base_up_ap = card_data.get("base_up_ap", 0)
		var total_ap = base_ap + base_up_ap
		left_stat_label.text = str(total_ap)
		
		# 変化がある場合は色を変える
		if base_up_ap > 0:
			left_stat_label.add_theme_color_override("font_color", Color.GREEN)
		elif base_up_ap < 0:
			left_stat_label.add_theme_color_override("font_color", Color.RED)
		else:
			left_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 最大HP - 基礎値 + 増加分
	var right_stat_label = get_node_or_null("RightStatBadge/RightStatCircle/RightStatLabel")
	if right_stat_label:
		var base_hp = card_data.get("hp", 0)
		var base_up_hp = card_data.get("base_up_hp", 0)
		var total_hp = base_hp + base_up_hp
		right_stat_label.text = str(total_hp)
		
		# 変化がある場合は色を変える
		if base_up_hp > 0:
			right_stat_label.add_theme_color_override("font_color", Color.GREEN)
		elif base_up_hp < 0:
			right_stat_label.add_theme_color_override("font_color", Color.RED)
		else:
			right_stat_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 現在HP（バトル中の動的データ）
	var current_hp_label = get_node_or_null("CurrentHPBadge/CurrentHPCircle/CurrentHPLabel")
	if current_hp_label:
		var current_hp = card_data.get("current_hp", card_data.get("hp", 0))
		current_hp_label.text = str(current_hp)
		
		# HPが減っている場合は色を変える
		var max_hp = card_data.get("hp", 0) + card_data.get("base_up_hp", 0)
		if current_hp < max_hp:
			current_hp_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			current_hp_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 説明文
	var desc_label = get_node_or_null("DescriptionBox/DescriptionLabel")
	if desc_label:
		var ability_text = card_data.get("ability", "")
		var element = card_data.get("element", "")
		
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
			ability_text += "\n[永続: " + str(permanent_effects.size()) + "個]"
		
		# 一時効果を表示
		var temporary_effects = card_data.get("temporary_effects", [])
		if temporary_effects.size() > 0:
			ability_text += "\n[一時: " + str(temporary_effects.size()) + "個]"
		
		if ability_text.is_empty():
			ability_text = element + "属性"
		
		desc_label.text = ability_text
		desc_label.add_theme_color_override("font_color", Color(0.25, 0.2, 0.15))

# 属性色を設定（OuterFrameの背景色とシェーダーを変更）
func set_element_color():
	var outer_frame = get_node_or_null("OuterFrame")
	if not outer_frame:
		return
	
	var element = card_data.get("element", "")
	var card_type = card_data.get("type", "")
	
	# アイテム、スペル、無属性クリーチャーは全てグレー
	var is_gray = (card_type == "item" or card_type == "spell" or element == "neutral" or element == "")
	
	# StyleBoxFlatの背景色を変更
	var style = outer_frame.get_theme_stylebox("panel")
	if style and style is StyleBoxFlat:
		if is_gray:
			style.bg_color = Color(0.4, 0.4, 0.4)  # グレー
		else:
			match element:
				"fire":
					style.bg_color = Color(0.8, 0.1, 0.1)  # 赤
				"water":
					style.bg_color = Color(0.1, 0.3, 0.8)  # 青
				"wind":
					style.bg_color = Color(0.1, 0.7, 0.3)  # 緑
				"earth":
					style.bg_color = Color(0.6, 0.4, 0.1)  # 茶色
				_:
					style.bg_color = Color(0.4, 0.4, 0.4)  # グレー（フォールバック）
	
	# シェーダーマテリアルの色を変更
	# 重要：マテリアルを複製して個別に設定（共有を避ける）
	var shader_mat = outer_frame.material as ShaderMaterial
	if shader_mat and shader_mat.shader:
		# マテリアルを複製（このカード専用にする）
		if not outer_frame.material.resource_local_to_scene:
			shader_mat = shader_mat.duplicate()
			outer_frame.material = shader_mat
		if is_gray:
			# グレー系の迷彩パターン（アイテム・スペル・無属性）
			shader_mat.set_shader_parameter("color_dark", Color(0.3, 0.3, 0.3, 1))
			shader_mat.set_shader_parameter("color_mid", Color(0.5, 0.5, 0.5, 1))
			shader_mat.set_shader_parameter("color_light", Color(0.7, 0.7, 0.7, 1))
		else:
			match element:
				"fire":
					# 赤系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.6, 0.05, 0.05, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.8, 0.1, 0.1, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.95, 0.2, 0.2, 1))
				"water":
					# 青系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.05, 0.2, 0.6, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.1, 0.4, 0.8, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.2, 0.6, 0.95, 1))
				"wind":
					# 緑系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.05, 0.5, 0.1, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.1, 0.7, 0.2, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.2, 0.9, 0.3, 1))
				"earth":
					# 茶色系の迷彩パターン
					shader_mat.set_shader_parameter("color_dark", Color(0.5, 0.3, 0.05, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.7, 0.45, 0.1, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.9, 0.6, 0.2, 1))
				_:
					# フォールバック：グレー
					shader_mat.set_shader_parameter("color_dark", Color(0.3, 0.3, 0.3, 1))
					shader_mat.set_shader_parameter("color_mid", Color(0.5, 0.5, 0.5, 1))
					shader_mat.set_shader_parameter("color_light", Color(0.7, 0.7, 0.7, 1))

# クリーチャー画像を読み込む
func load_creature_image(card_id: int):
	var card_art = get_node_or_null("CardArtContainer/CardArt")
	if not card_art:
		return
	
	# 画像パスを構築（IDベース）
	var image_path = "res://assets/images/creatures/" + str(card_id) + ".png"
	
	# 画像ファイルが存在するか確認
	if FileAccess.file_exists(image_path):
		var texture = load(image_path)
		if texture:
			card_art.texture = texture
	else:
		# 画像がない場合はデフォルト表示（属性に応じた色）
		var placeholder = Image.create(199, 185, false, Image.FORMAT_RGBA8)
		
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
		card_art.texture = ImageTexture.create_from_image(placeholder)

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
