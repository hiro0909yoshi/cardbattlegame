extends Control

const GC = preload("res://scripts/game_constants.gd")
const _GachaSystem = preload("res://scripts/gacha_system.gd")

@onready var left_panel = $MarginContainer/HBoxContainer/LeftPanel
@onready var left_vbox = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer
@onready var right_panel = $MarginContainer/HBoxContainer/RightPanel
@onready var scroll_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer/GridContainer

# モード管理
var is_battle_mode: bool = false  # バトル用かデッキ編集用か

# カード一覧用
var _current_category: String = ""
var _current_page: int = 0
var _cards_per_page: int = 40
var _filtered_cards: Array[Dictionary] = []
var _thumbnail_width: int = 161
var _thumbnail_height: int = 235

func _ready():
	# GameDataから起動モードを取得（メタデータを使用）
	if GameData.has_meta("is_selecting_for_battle"):
		is_battle_mode = GameData.get_meta("is_selecting_for_battle")
	else:
		is_battle_mode = false
	
	# バトルモードなら最初からブック選択表示
	if is_battle_mode:
		scroll_container.visible = true
	else:
		scroll_container.visible = false
	
	# 左側ボタン接続・スタイル設定
	var btn_names = ["DeckEditButton", "CardListButton", "ResetCardsButton", "BackButton"]
	for btn_name in btn_names:
		_apply_left_button_style(left_vbox.get_node(btn_name))

	left_vbox.get_node("DeckEditButton").pressed.connect(_on_deck_edit_pressed)
	left_vbox.get_node("CardListButton").pressed.connect(_on_card_list_pressed)
	left_vbox.get_node("ResetCardsButton").pressed.connect(_on_reset_cards_pressed)
	left_vbox.get_node("BackButton").pressed.connect(_on_back_pressed)
	
	# 星の背景を初期表示
	_setup_category_background(Color(0.4, 0.4, 0.5))

	# バトルモードならブック選択を表示
	if is_battle_mode:
		_show_book_selection()

func _on_deck_edit_pressed():
	# 右側パネルを表示
	scroll_container.visible = true
	# ブック選択画面を表示
	_show_book_selection()

## ブック選択画面を表示（ダイヤルボックス形式）
func _show_book_selection():
	# GridContainerをクリア
	for child in grid_container.get_children():
		child.queue_free()

	# 1列の縦スクロールリストに変更
	grid_container.columns = 1
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 15)
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ブックボタンを再作成
	var book_count = max(6, GameData.player_data.decks.size())
	for i in range(book_count):
		var book_button = Button.new()
		book_button.name = "book" + str(i + 1)
		book_button.custom_minimum_size = Vector2(0, 150)
		book_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# デッキ名を取得
		var deck_name = "ブック" + str(i + 1)
		if i < GameData.player_data.decks.size():
			deck_name = GameData.player_data.decks[i].get("name", deck_name)
			var card_count = GameData.player_data.decks[i].get("cards", {}).size()
			book_button.text = deck_name + "\n(" + str(card_count) + "種類)"
		else:
			book_button.text = deck_name

		book_button.add_theme_font_size_override("font_size", 32)
		book_button.pressed.connect(_on_book_selected.bind(i))

		# スタイル
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		style.border_color = Color(0.4, 0.4, 0.5, 0.6)
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		book_button.add_theme_stylebox_override("normal", style)

		var hover = style.duplicate()
		hover.bg_color = Color(0.25, 0.25, 0.35, 0.95)
		book_button.add_theme_stylebox_override("hover", hover)

		grid_container.add_child(book_button)


## スワイプ用変数
var _swipe_start_y: float = 0.0
var _is_swiping: bool = false


## 全体入力処理（mouse_filterに依存しないスワイプ対応）
func _input(event: InputEvent):
	if not scroll_container or not scroll_container.visible:
		return

	# マウス操作
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_swipe_start_y = event.position.y
				_is_swiping = true
			else:
				_is_swiping = false
	elif event is InputEventMouseMotion and _is_swiping:
		var delta = event.position.y - _swipe_start_y
		scroll_container.scroll_vertical -= int(delta)
		_swipe_start_y = event.position.y

	# タッチ操作（モバイル）
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start_y = event.position.y
			_is_swiping = true
		else:
			_is_swiping = false
	elif event is InputEventScreenDrag and _is_swiping:
		scroll_container.scroll_vertical -= int(event.relative.y)

func _on_book_selected(book_index: int):
	# 選択したブックを保存
	GameData.selected_deck_index = book_index
	
	# モードに応じて遷移先を変える
	if is_battle_mode:
		# バトルモードの場合はフラグを消してバトル画面へ
		GameData.remove_meta("is_selecting_for_battle")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")
	else:
		# 通常モードの場合はデッキ編集画面へ
		get_tree().call_deferred("change_scene_to_file", "res://scenes/DeckEditor.tscn")

## 左パネルボタンにスタイルを適用
func _apply_left_button_style(btn: Button):
	btn.add_theme_font_size_override("font_size", 28)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	style.border_color = Color(0.4, 0.4, 0.4, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 13
	style.content_margin_right = 13
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.25, 0.25, 0.25, 0.95)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = style.duplicate()
	pressed.bg_color = Color(0.3, 0.3, 0.3, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

func _on_card_list_pressed():
	scroll_container.visible = true
	_show_collection_stats()

func _on_reset_cards_pressed():
	UserCardDB.reset_database()
	UserCardDB.flush()
	GameData.reset_collection_complete()
	_show_collection_stats()

func _on_back_pressed():
	# バトルモードの場合はフラグをクリア
	if is_battle_mode:
		GameData.remove_meta("is_selecting_for_battle")
	
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")

## 所持カードの統計を表示
func _show_collection_stats():
	# GridContainerをクリア
	for child in grid_container.get_children():
		child.queue_free()

	# 星の背景を設定（白ベース）
	_setup_category_background(Color(0.4, 0.4, 0.5))

	# 統計データを収集
	var stats = _calculate_collection_stats()
	
	# 表示用パネルを作成
	var categories = ["fire", "water", "earth", "wind", "neutral", "item", "spell"]

	# GridContainerをコンテナ幅に合わせて配置
	grid_container.columns = 2
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.add_theme_constant_override("h_separation", 30)
	grid_container.add_theme_constant_override("v_separation", 13)

	# 戻るボタンを追加
	var back_btn = Button.new()
	back_btn.text = "← 戻る"
	back_btn.custom_minimum_size = Vector2(134, 54)
	back_btn.add_theme_font_size_override("font_size", 21)
	back_btn.pressed.connect(_show_collection_stats)
	back_btn.visible = false
	back_btn.name = "CategoryBackButton"
	grid_container.add_child(back_btn)
	
	for category in categories:
		if not stats.has(category):
			continue
		
		var panel = _create_stats_panel(_category_names[category], stats[category], category)
		grid_container.add_child(panel)

var _category_names = {
	"fire": "🔥 火",
	"water": "💧 水",
	"earth": "🪨 地",
	"wind": "🌪️ 風",
	"neutral": "⚪ 無",
	"item": "👝 アイテム",
	"spell": "📜 スペル"
}

## カテゴリ別の統計パネルを作成（ボタンとして）
func _create_stats_panel(title: String, data: Dictionary, category: String) -> Control:
	var button = Button.new()
	button.custom_minimum_size = Vector2(660, 240)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# 属性色のグラデーション背景
	var element_color = _get_element_color_for_category(category)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(element_color.r * 0.5, element_color.g * 0.5, element_color.b * 0.5, 0.9)
	style.border_color = Color(element_color.r * 0.8, element_color.g * 0.8, element_color.b * 0.8, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 13
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(element_color.r * 0.15, element_color.g * 0.15, element_color.b * 0.15, 0.5)
	style.shadow_size = 6
	button.add_theme_stylebox_override("normal", style)

	# ホバー時は少し明るく
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(element_color.r * 0.6, element_color.g * 0.6, element_color.b * 0.6, 0.95)
	button.add_theme_stylebox_override("hover", hover_style)

	# 押下時
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(element_color.r * 0.7, element_color.g * 0.7, element_color.b * 0.7, 1.0)
	button.add_theme_stylebox_override("pressed", pressed_style)

	# ボタンテキストを構築（3行: タイトル+合計 / C+N / S+R）
	var total_owned = data.get("total_owned", 0)
	var total_cards = data.get("total_cards", 0)
	var total_percent = 0.0 if total_cards == 0 else (float(total_owned) / total_cards * 100.0)

	var text = "%s　　合計: %d / %d (%.1f%%)\n" % [title, total_owned, total_cards, total_percent]

	var rarity_texts: Array[String] = []
	for rarity in ["C", "N", "S", "R"]:
		var rarity_data = data.get(rarity, {"owned": 0, "total": 0})
		var owned = rarity_data.get("owned", 0)
		var total = rarity_data.get("total", 0)
		var percent = 0.0 if total == 0 else (float(owned) / total * 100.0)
		rarity_texts.append("[%s] %d / %d (%.1f%%)" % [rarity, owned, total, percent])

	text += "%s　　%s\n" % [rarity_texts[0], rarity_texts[1]]
	text += "%s　　%s" % [rarity_texts[2], rarity_texts[3]]

	button.text = text
	button.add_theme_font_size_override("font_size", 30)

	# クリックでカード一覧を表示
	button.pressed.connect(_show_category_cards.bind(category))

	return button

## カテゴリ別のカード一覧を表示
func _show_category_cards(category: String):
	_current_category = category

	# カードをフィルタリング（排出不能カードは除外）
	_filtered_cards.clear()
	for card in CardLoader.all_cards:
		var card_id: int = int(card.get("id", 0))
		if card_id in _GachaSystem.EXCLUDED_CARD_IDS:
			continue
		var card_type = card.get("type", "")
		var element = card.get("element", "")

		var card_category = ""
		if card_type == "creature":
			card_category = element
		elif card_type == "item":
			card_category = "item"
		elif card_type == "spell":
			card_category = "spell"

		if card_category == category:
			_filtered_cards.append(card)

	_current_page = 0
	_render_card_page()


## 現在のページを描画
func _render_card_page():
	# ScrollContainerをAlbumルートに移動してフル幅使用
	if scroll_container.get_parent() != self:
		scroll_container.reparent(self)

	# HBoxContainerを非表示にしてフル画面モードに切替
	$MarginContainer/HBoxContainer.visible = false

	# フル画面サイズで配置（ビューポートサイズから動的計算）
	var vp_size = get_viewport().get_visible_rect().size
	scroll_container.position = Vector2(20, 60)
	scroll_container.size = Vector2(vp_size.x - 40, vp_size.y - 60)
	scroll_container.visible = true

	# 属性色のグラデーション背景を設定
	var element_color = _get_element_color_for_category(_current_category)
	_setup_category_background(element_color)

	# GridContainerをクリア
	for child in grid_container.get_children():
		child.queue_free()

	# グリッドを10列に変更（画像タイル用）
	var h_sep = 20
	grid_container.columns = 10
	grid_container.add_theme_constant_override("h_separation", h_sep)
	grid_container.add_theme_constant_override("v_separation", 12)
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# カードサイズをScrollContainer幅から動的計算（スクロールバー分も考慮）
	var scrollbar_width = 30
	var content_width = scroll_container.size.x - scrollbar_width
	_thumbnail_width = int((content_width - (9 * h_sep)) / 10.0)
	_thumbnail_height = int(_thumbnail_width * 1.33)

	# スクロール位置をリセット
	scroll_container.scroll_vertical = 0

	var total_pages = max(1, int(ceil(float(_filtered_cards.size()) / _cards_per_page)))

	# ヘッダー行（GridContainerの外にHBoxContainerで配置）
	var header = HBoxContainer.new()
	header.name = "CardListHeader"
	header.custom_minimum_size = Vector2(0, 54)
	header.add_theme_constant_override("separation", 13)
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.offset_left = 0
	header.offset_right = 0

	var back_btn = Button.new()
	back_btn.text = "← 戻る"
	back_btn.custom_minimum_size = Vector2(134, 54)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(_on_card_list_back)
	header.add_child(back_btn)

	var left_spacer = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(left_spacer)

	var prev_btn = Button.new()
	prev_btn.text = "◀ 前"
	prev_btn.custom_minimum_size = Vector2(107, 54)
	prev_btn.add_theme_font_size_override("font_size", 24)
	prev_btn.disabled = (_current_page == 0)
	prev_btn.pressed.connect(_on_page_prev)
	header.add_child(prev_btn)

	var title_label = Label.new()
	title_label.text = "%s (%d種)" % [_category_names.get(_current_category, _current_category), _filtered_cards.size()]
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title_label)

	var page_label = Label.new()
	page_label.text = "%d / %d" % [_current_page + 1, total_pages]
	page_label.add_theme_font_size_override("font_size", 28)
	page_label.add_theme_color_override("font_color", Color.WHITE)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(page_label)

	var next_btn = Button.new()
	next_btn.text = "次 ▶"
	next_btn.custom_minimum_size = Vector2(107, 54)
	next_btn.add_theme_font_size_override("font_size", 24)
	next_btn.disabled = (_current_page >= total_pages - 1)
	next_btn.pressed.connect(_on_page_next)
	header.add_child(next_btn)

	var right_spacer = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(right_spacer)

	# 既存ヘッダーを全て削除してから追加
	_remove_all_headers()
	self.add_child(header)

	# ScrollContainerの位置調整（ヘッダー分 + 左右マージン）
	scroll_container.offset_top = 60
	scroll_container.offset_left = 20
	scroll_container.offset_right = -20
	scroll_container.offset_bottom = 0

	# カードサムネイルを表示（現在ページ分）
	var start_index = _current_page * _cards_per_page
	var end_index = min(start_index + _cards_per_page, _filtered_cards.size())

	for i in range(start_index, end_index):
		var card_panel = _create_card_thumbnail(_filtered_cards[i])
		grid_container.add_child(card_panel)


## ページ操作
func _on_page_prev():
	if _current_page > 0:
		_current_page -= 1
		_render_card_page()


func _on_page_next():
	var total_pages = max(1, int(ceil(float(_filtered_cards.size()) / _cards_per_page)))
	if _current_page < total_pages - 1:
		_current_page += 1
		_render_card_page()


## カードサムネイルを作成（画像 + カード名 + 所持数）
func _create_card_thumbnail(card: Dictionary) -> Control:
	var card_id = card.get("id", 0)
	var card_name = card.get("name", "???")
	var rarity = card.get("rarity", "N")
	var card_type = card.get("type", "")
	var element = card.get("element", "")
	var owned = UserCardDB.get_card_count(card_id)

	# 属性色のグラデーション背景付きパネル
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(_thumbnail_width, _thumbnail_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var element_color = _get_element_color(element, card_type)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(element_color.r, element_color.g, element_color.b, 0.35)
	style.border_color = Color(element_color.r, element_color.g, element_color.b, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	# 上部から下部へ暗くなるスカート（疑似グラデーション）
	style.shadow_color = Color(element_color.r * 0.3, element_color.g * 0.3, element_color.b * 0.3, 0.4)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

	# 未所持はパネル自体を暗く
	if owned <= 0:
		panel.modulate = Color(0.4, 0.4, 0.4, 0.8)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# カード画像
	var image_path = _get_card_image_path(card_id, card_type, element)
	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(_thumbnail_width - 12, _thumbnail_width - 12)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if image_path != "" and ResourceLoader.exists(image_path):
		tex_rect.texture = load(image_path)

	vbox.add_child(tex_rect)

	# カード名ラベル
	var name_label = Label.new()
	name_label.text = card_name
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# レアリティで色分け
	if owned <= 0:
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	else:
		match rarity:
			"R":
				name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			"S":
				name_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
			_:
				name_label.add_theme_color_override("font_color", Color.WHITE)

	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# 所持数ラベル
	var count_label = Label.new()
	count_label.text = "[%s] %d枚" % [rarity, owned]
	count_label.add_theme_font_size_override("font_size", 24)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(count_label)

	panel.add_child(vbox)
	return panel


## カテゴリから属性色を取得
func _get_element_color_for_category(category: String) -> Color:
	match category:
		"fire":
			return Color(0.9, 0.3, 0.1)
		"water":
			return Color(0.1, 0.4, 0.9)
		"earth":
			return Color(0.1, 0.55, 0.2)
		"wind":
			return Color(0.8, 0.7, 0.1)
		"neutral":
			return Color(0.6, 0.6, 0.6)
		"item":
			return Color(0.91, 0.51, 0.16)
		"spell":
			return Color(0.5, 0.2, 0.7)
	return Color(0.4, 0.4, 0.4)


## グラデーション背景を設定（暗い宇宙風 + 星 + 属性色のアクセント）
func _setup_category_background(element_color: Color):
	# 既存の背景があれば削除
	_remove_category_background()

	# コンテナ
	var bg_container = Control.new()
	bg_container.name = "CategoryBG"
	bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 暗い背景 + 属性色の薄いグラデーション
	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gradient = Gradient.new()
	gradient.set_color(0, Color(element_color.r * 0.12, element_color.g * 0.12, element_color.b * 0.12, 0.95))
	gradient.set_color(1, Color(0.02, 0.02, 0.05, 0.98))

	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)

	bg.texture = grad_tex
	bg_container.add_child(bg)

	# 星を散りばめる
	var viewport_size = get_viewport().get_visible_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = _current_category.hash()  # カテゴリごとに同じ配置

	for i in range(60):
		var star = PanelContainer.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var star_size = rng.randf_range(2.0, 6.0)
		star.custom_minimum_size = Vector2(star_size, star_size)
		star.position = Vector2(rng.randf_range(0, viewport_size.x), rng.randf_range(0, viewport_size.y))

		var star_style = StyleBoxFlat.new()
		var brightness = rng.randf_range(0.5, 1.0)
		# 一部の星に属性色を混ぜる
		var star_color: Color
		if rng.randf() < 0.3:
			star_color = Color(
				lerpf(1.0, element_color.r, 0.5) * brightness,
				lerpf(1.0, element_color.g, 0.5) * brightness,
				lerpf(1.0, element_color.b, 0.5) * brightness,
				brightness
			)
		else:
			star_color = Color(brightness, brightness, brightness * 1.1, brightness)
		star_style.bg_color = star_color
		star_style.set_corner_radius_all(int(star_size))
		star.add_theme_stylebox_override("panel", star_style)

		bg_container.add_child(star)

		# キラキラアニメーション（一部の星）
		if rng.randf() < 0.4:
			var tween = create_tween()
			tween.set_loops()
			var delay = rng.randf_range(0.0, 3.0)
			var duration = rng.randf_range(1.5, 3.5)
			tween.tween_interval(delay)
			tween.tween_property(star, "modulate:a", rng.randf_range(0.2, 0.5), duration)
			tween.tween_property(star, "modulate:a", 1.0, duration)

	add_child(bg_container)
	move_child(bg_container, 0)


## right_panel内の全ヘッダーを削除
func _remove_all_headers():
	# selfとright_panel両方からヘッダーを削除
	for parent_node in [self, right_panel]:
		var to_remove: Array[Node] = []
		for child in parent_node.get_children():
			if child.name.begins_with("CardListHeader"):
				to_remove.append(child)
		for node in to_remove:
			parent_node.remove_child(node)
			node.queue_free()


## 背景を削除
func _remove_category_background():
	var existing = get_node_or_null("CategoryBG")
	if existing:
		existing.queue_free()


## 属性色を取得
func _get_element_color(element: String, card_type: String) -> Color:
	match element:
		"fire":
			return Color(0.9, 0.3, 0.1)
		"water":
			return Color(0.1, 0.4, 0.9)
		"earth":
			return Color(0.1, 0.55, 0.2)
		"wind":
			return Color(0.8, 0.7, 0.1)
		"neutral":
			return Color(0.6, 0.6, 0.6)
	# アイテム・スペル
	match card_type:
		"item":
			return Color(0.7, 0.6, 0.2)
		"spell":
			return Color(0.5, 0.2, 0.7)
	return Color(0.4, 0.4, 0.4)


## カード画像パスを取得
func _get_card_image_path(card_id: int, card_type: String, element: String) -> String:
	if card_type == "creature":
		return "res://assets/images/creatures/%s/%d.png" % [element, card_id]
	elif card_type == "spell":
		return "res://assets/images/spells/%d.png" % card_id
	elif card_type == "item":
		return "res://assets/images/items/%d.png" % card_id
	return ""


## カード一覧から統計画面に戻る（グリッド設定を復元）
func _on_card_list_back():
	_remove_category_background()
	# ヘッダー全削除
	_remove_all_headers()

	# ScrollContainerをRightPanelに戻す
	if scroll_container.get_parent() != right_panel:
		scroll_container.reparent(right_panel)
	scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_container.offset_top = 40
	scroll_container.offset_left = 40
	scroll_container.offset_right = -40
	scroll_container.offset_bottom = -40

	# HBoxContainerを再表示
	$MarginContainer/HBoxContainer.visible = true
	left_panel.visible = true

	grid_container.size_flags_horizontal = Control.SIZE_FILL
	grid_container.columns = 2
	_show_collection_stats()

## 所持カード統計を計算
func _calculate_collection_stats() -> Dictionary:
	var stats = {}
	
	# カテゴリ初期化
	var categories = ["fire", "water", "earth", "wind", "neutral", "item", "spell"]
	for category in categories:
		stats[category] = {
			"total_owned": 0,
			"total_cards": 0,
			"C": {"owned": 0, "total": 0},
			"N": {"owned": 0, "total": 0},
			"S": {"owned": 0, "total": 0},
			"R": {"owned": 0, "total": 0}
		}
	
	# 全カードをチェック（排出不能カードは除外）
	for card in CardLoader.all_cards:
		var card_id: int = int(card.get("id", 0))
		if card_id in _GachaSystem.EXCLUDED_CARD_IDS:
			continue
		var card_type = card.get("type", "")
		var element = card.get("element", "")
		var rarity = card.get("rarity", "N")
		
		# カテゴリ判定
		var category = ""
		if card_type == "creature":
			category = element
		elif card_type == "item":
			category = "item"
		elif card_type == "spell":
			category = "spell"
		
		if category.is_empty() or not stats.has(category):
			continue
		
		# 総数カウント
		stats[category]["total_cards"] += 1
		stats[category][rarity]["total"] += 1
		
		# 所持チェック（1枚以上持っているか）
		var owned_count = UserCardDB.get_card_count(card_id)
		if owned_count > 0:
			stats[category]["total_owned"] += 1
			stats[category][rarity]["owned"] += 1
	
	return stats
