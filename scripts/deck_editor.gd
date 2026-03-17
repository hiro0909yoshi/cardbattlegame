extends Control

var _current_deck = {}  # 現在編集中のデッキ
var _current_filter = "all"  # フィルター状態
var _card_dialog = null
var _selected_card_id = 0
var _count_buttons: Array[Button] = []  # 枚数選択ボタンの配列

# 正確なノードパス
@onready var button_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/Control/HBoxContainer
@onready var scroll_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer/GridContainer
@onready var info_panel_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/InfoPanelContainer
@onready var right_vbox = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer
@onready var card_type_count = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardTypeCount
@onready var card_count_label = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardCountLabel
@onready var save_button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/SaveButton

var _reset_button: Button = null

# インフォパネル
var _creature_info_panel_scene = preload("res://scenes/ui/creature_info_panel.tscn")
var _item_info_panel_scene = preload("res://scenes/ui/item_info_panel.tscn")
var _spell_info_panel_scene = preload("res://scenes/ui/spell_info_panel.tscn")
var _current_info_panel: Control = null

func _ready():
	# フィルターボタン接続（8個）
	var buttons = button_container.get_children()
	if buttons.size() >= 8:
		buttons[0].pressed.connect(_on_filter_pressed.bind("deck"))     # DeckButton
		buttons[1].pressed.connect(_on_filter_pressed.bind("無"))       # NeutralButton
		buttons[2].pressed.connect(_on_filter_pressed.bind("火"))       # FireButton
		buttons[3].pressed.connect(_on_filter_pressed.bind("水"))       # WaterButton
		buttons[4].pressed.connect(_on_filter_pressed.bind("地"))       # EarthButton
		buttons[5].pressed.connect(_on_filter_pressed.bind("風"))       # WindButton
		buttons[6].pressed.connect(_on_filter_pressed.bind("item"))     # ItemButton
		buttons[7].pressed.connect(_on_filter_pressed.bind("spell"))    # SpellButton
	
	# BackButtonがある場合（8番目のボタンが戻るボタンの場合）
	if buttons.size() > 8:
		buttons[8].pressed.connect(_on_back_pressed)
	
	# 右側ボタン接続
	save_button.pressed.connect(_on_save_pressed)
	
	# リセットボタンを動的に作成
	_create_reset_button()
	
	# 🔧 デバッグ: データリセットボタン（テスト用）
	_create_debug_reset_button()
	
	# もし戻るボタンが別の場所にあれば
	if has_node("BackButton"):
		$BackButton.pressed.connect(_on_back_pressed)
	
	# 選択したブックを読み込み
	load_deck()
	
	# タイトル設定（もしタイトルラベルがあれば）
	if has_node("TitleLabel"):
		var deck_name = GameData.player_data.decks[GameData.selected_deck_index]["name"]
		$TitleLabel.text = "デッキ編集 - " + deck_name
	
	# ダイアログ作成
	_create_card_dialog()
	
	# 宇宙風背景を設定
	_setup_space_background(Color(0.4, 0.4, 0.5))

	# カード一覧を表示（最初はデッキ内のカードのみ）
	display_cards("deck")

func load_deck():
	# GameDataから現在のブックを読み込み
	_current_deck = GameData.get_current_deck()["cards"].duplicate()
	update_card_count()

func _create_card_dialog():
	_card_dialog = Popup.new()
	_card_dialog.size = Vector2(1183, 500)
	_card_dialog.transparent_bg = true

	# Popupのパネル背景を透明に
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0, 0, 0, 0)
	popup_style.set_border_width_all(0)
	_card_dialog.add_theme_stylebox_override("panel", popup_style)

	# シンプルなVBox
	var vbox = VBoxContainer.new()
	vbox.name = "DialogVBox"
	vbox.position = Vector2(30, 30)
	vbox.size = Vector2(1123, 440)
	vbox.add_theme_constant_override("separation", 30)
	_card_dialog.add_child(vbox)
	
	# 所持枚数/デッキ内枚数ラベル
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.add_theme_font_size_override("font_size", 70)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)
	
	# 枚数選択ボタン（横並び）
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	
	_count_buttons.clear()
	for i in range(5):
		var btn = Button.new()
		btn.text = str(i) + "枚"
		btn.custom_minimum_size = Vector2(180, 100)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 50)
		btn.pressed.connect(_on_count_selected.bind(i))
		hbox.add_child(btn)
		_count_buttons.append(btn)
	
	vbox.add_child(hbox)
	
	# スペーサー
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# 閉じるボタン
	var close_btn = Button.new()
	close_btn.text = "閉じる"
	close_btn.custom_minimum_size = Vector2(375, 125)
	close_btn.add_theme_font_size_override("font_size", 55)
	close_btn.pressed.connect(_on_dialog_closed)
	vbox.add_child(close_btn)
	
	# ダイアログが非表示になったときの処理
	_card_dialog.popup_hide.connect(_on_dialog_closed)
	
	add_child(_card_dialog)

## ダイアログが閉じられたとき（インフォパネルも閉じる）
func _on_dialog_closed():
	_card_dialog.hide()
	_close_info_panel()

## インフォパネルを閉じる
func _close_info_panel():
	if _current_info_panel and is_instance_valid(_current_info_panel):
		_current_info_panel.queue_free()
		_current_info_panel = null

func _on_filter_pressed(filter_type: String):
	_current_filter = filter_type
	# フィルターに応じた属性色で背景更新
	_setup_space_background(_get_filter_color(filter_type))
	display_cards(filter_type)

func display_cards(filter: String):
	clear_card_list()
	
	var cards_to_show: Array[Dictionary] = []
	
	# 属性フィルターのマッピング（日本語 → 英語）
	var element_map = {
		"無": "neutral",
		"火": "fire",
		"水": "water",
		"地": "earth",
		"風": "wind"
	}
	
	# フィルターに応じてカードを取得
	if filter == "deck":
		# デッキに入っているカードだけ
		for card_id in _current_deck.keys():
			var card = CardLoader.get_card_by_id(card_id)
			if not card.is_empty():
				cards_to_show.append(card)
	elif filter == "spell":
		# スペルカード
		for card in CardLoader.all_cards:
			if card.type == "spell" and GameData.get_card_count(card.id) > 0:
				cards_to_show.append(card)
	elif filter == "item":
		# アイテムカード
		for card in CardLoader.all_cards:
			if card.type == "item" and GameData.get_card_count(card.id) > 0:
				cards_to_show.append(card)
	else:
		# 属性フィルター（火・水・地・風・無）
		var target_element = element_map.get(filter, filter)  # マッピング適用
		
		for card in CardLoader.all_cards:
			# この属性のカードか？
			if card.has("element") and card.element == target_element:
				# プレイヤーが所持しているか？（1枚以上）
				if GameData.get_card_count(card.id) > 0:
					cards_to_show.append(card)
	

	
	# カードボタンを生成
	for card in cards_to_show:
		create_card_button(card)

func clear_card_list():
	for child in grid_container.get_children():
		child.queue_free()

func create_card_button(card_data: Dictionary):
	# 所持枚数を取得（DB連携）
	var owned_count = GameData.get_card_count(card_data.id)
	var deck_count = _current_deck.get(card_data.id, 0)
	var rarity = card_data.get("rarity", "N")
	var card_type = card_data.get("type", "")

	# ボタン（テキストは空、子要素で構成）
	var button = Button.new()
	button.custom_minimum_size = Vector2(420, 700)
	button.set_meta("card_id", card_data.id)
	button.clip_contents = true

	# VBoxContainer で画像+テキストを縦並び
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)

	# カード画像
	var image_rect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(300, 300)
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var image_path = _get_card_image_path(card_data)
	if ResourceLoader.exists(image_path):
		image_rect.texture = load(image_path)
	vbox.add_child(image_rect)

	# テキスト情報
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var card_name = card_data.get("name", "???")
	var dev_name = card_data.get("dev_name", "")
	var element = card_data.get("element", "")

	var text = card_name
	if not dev_name.is_empty():
		text += "\n" + dev_name
	text += "\n[" + rarity + "]"
	if not element.is_empty():
		text += " " + element
	text += "\n所持: " + str(owned_count) + "枚"
	if deck_count > 0:
		text += "\nデッキ: " + str(deck_count) + "枚"
	if card_type == "creature":
		var ap = card_data.get("ap", 0)
		var hp = card_data.get("hp", 0)
		text += "\nAP:%d / HP:%d" % [ap, hp]

	label.text = text
	vbox.add_child(label)

	button.add_child(vbox)

	# レアリティでテキスト色（画像には影響させない）
	match rarity:
		"R":
			label.modulate = Color(1.0, 0.9, 0.7)
		"S":
			label.modulate = Color(0.9, 0.85, 1.0)
		"N":
			label.modulate = Color(0.85, 0.9, 1.0)
		"C":
			label.modulate = Color(0.9, 0.9, 0.9)

	button.pressed.connect(_on_card_button_pressed.bind(card_data.id))
	grid_container.add_child(button)


## カードの画像パスを取得
func _get_card_image_path(card_data: Dictionary) -> String:
	var card_id = card_data.get("id", 0)
	var card_type = card_data.get("type", "")
	var element = card_data.get("element", "")

	match card_type:
		"creature":
			return "res://assets/images/creatures/%s/%d.png" % [element, card_id]
		"spell":
			return "res://assets/images/spells/%d.png" % card_id
		"item":
			return "res://assets/images/items/%d.png" % card_id
	return ""

func _on_card_button_pressed(card_id: int):
	_selected_card_id = card_id
	var card = CardLoader.get_card_by_id(card_id)
	var card_type = card.get("type", "")
	
	# カードタイプに応じたインフォパネルを表示
	_show_info_panel(card, card_type)

## カードタイプに応じたインフォパネルを表示
func _show_info_panel(card: Dictionary, card_type: String):
	# 既存のインフォパネルを削除
	if _current_info_panel and is_instance_valid(_current_info_panel):
		_current_info_panel.queue_free()
		_current_info_panel = null
	
	# インフォパネルの紙部分を右側パネルに表示
	_show_info_in_right_panel(card, card_type)
	
	# 枚数選択ダイアログを表示
	_show_count_dialog()

## InfoPanelContainerにインフォパネルを表示
func _show_info_in_right_panel(card: Dictionary, card_type: String):
	# 既存のプレビューを削除
	if _current_info_panel and is_instance_valid(_current_info_panel):
		_current_info_panel.queue_free()
		_current_info_panel = null
	
	# タイプに応じたパネルをインスタンス化
	match card_type:
		"creature":
			_current_info_panel = _creature_info_panel_scene.instantiate()
		"item":
			_current_info_panel = _item_info_panel_scene.instantiate()
		"spell":
			_current_info_panel = _spell_info_panel_scene.instantiate()
	
	if not _current_info_panel:
		return
	
	# InfoPanelContainerに追加
	info_panel_container.add_child(_current_info_panel)

	# マウスイベントを透過させてスクロールを妨げない
	_set_mouse_filter_ignore(_current_info_panel)
	
	# アンカーをリセット（左上基準に）
	_current_info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_current_info_panel.anchor_left = 0
	_current_info_panel.anchor_top = 0
	_current_info_panel.anchor_right = 0
	_current_info_panel.anchor_bottom = 0
	
	# データを読み込む
	match card_type:
		"creature":
			_current_info_panel.show_view_mode(card, -1, false)
		"item":
			_current_info_panel.show_item_info(card)
		"spell":
			_current_info_panel.show_spell_info(card)
	
	await get_tree().process_frame
	
	if not info_panel_container or not is_instance_valid(info_panel_container):
		return

	# スケール調整
	var scale_factor = 0.95
	_current_info_panel.scale = Vector2(scale_factor, scale_factor)

	# 位置を調整
	_current_info_panel.position = Vector2(0, 0)

	# 中のMainContainerの位置を調整
	var main_container = _current_info_panel.get_node_or_null("MainContainer")
	if main_container:
		main_container.position.x -= 225
		main_container.position.y -= 290

## 枚数選択ダイアログを表示
func _show_count_dialog():
	var owned = GameData.get_card_count(_selected_card_id)
	var in_deck = _current_deck.get(_selected_card_id, 0)
	
	# 情報ラベルを更新
	var info_label = _card_dialog.get_node_or_null("DialogVBox/InfoLabel")
	if info_label:
		info_label.text = "所持: %d枚 / デッキ内: %d枚" % [owned, in_deck]
	
	# ボタンの有効/無効を設定
	var max_count = min(4, owned)
	for i in range(_count_buttons.size()):
		if i > max_count:
			_count_buttons[i].disabled = true
			_count_buttons[i].modulate = Color(0.5, 0.5, 0.5)
		else:
			_count_buttons[i].disabled = false
			_count_buttons[i].modulate = Color(1, 1, 1)
	
	# インフォパネルの下に配置
	await get_tree().process_frame
	var info_rect = info_panel_container.get_global_rect()
	_card_dialog.position = Vector2(info_rect.position.x, info_rect.end.y + 10)
	_card_dialog.popup()

func _on_count_selected(count: int):
	var owned = GameData.get_card_count(_selected_card_id)
	var max_count = min(4, owned)
	
	if count > max_count:
		push_warning("所持数を超えています")
		return
	
	# デッキに設定
	if count == 0:
		_current_deck.erase(_selected_card_id)
	else:
		_current_deck[_selected_card_id] = count
	
	update_card_count()
	
	# 該当カードのボタンだけ更新
	if _current_filter == "deck":
		display_cards(_current_filter)
	else:
		update_single_card_button(_selected_card_id)
	
	_card_dialog.hide()

func update_single_card_button(card_id: int):
	var card = CardLoader.get_card_by_id(card_id)
	var owned_count = GameData.get_card_count(card_id)
	var deck_count = _current_deck.get(card_id, 0)
	
	# 既存のボタンを探して更新
	for button in grid_container.get_children():
		if button.has_meta("card_id") and button.get_meta("card_id") == card_id:
			var card_name = card.get("name", "???")
			var dev_name = card.get("dev_name", "")
			var element = card.get("element", "")

			button.text = card_name
			if not dev_name.is_empty():
				button.text += "\n" + dev_name
			button.text += "\n"
			if not element.is_empty():
				button.text += "[" + element + "] "
			button.text += str(owned_count) + "枚"
			if deck_count > 0:
				button.text += " (デッキ:" + str(deck_count) + ")"
			break

func update_card_count():
	var total = 0
	var fire_count = 0
	var water_count = 0
	var earth_count = 0
	var wind_count = 0
	var neutral_count = 0
	var item_count = 0
	var spell_count = 0
	
	for card_id in _current_deck.keys():
		var count = _current_deck[card_id]
		total += count
		var card = CardLoader.get_card_by_id(card_id)
		if card.is_empty():
			continue
		if card.type == "item":
			item_count += count
		elif card.type == "spell":
			spell_count += count
		else:
			match card.get("element", ""):
				"fire": fire_count += count
				"water": water_count += count
				"earth": earth_count += count
				"wind": wind_count += count
				_: neutral_count += count
	
	# 種別カウント表示
	var type_text = "[font_size=48]"
	type_text += "[color=#ff4545]●[/color] %d\n" % fire_count
	type_text += "[color=#4587ff]●[/color] %d\n" % water_count
	type_text += "[color=#87cc45]●[/color] %d\n" % earth_count
	type_text += "[color=#ffcc45]●[/color] %d\n" % wind_count
	type_text += "[color=#aaaaaa]●[/color] %d\n" % neutral_count
	type_text += "[color=#aaaaaa]▲[/color] %d\n" % item_count
	type_text += "[color=#aaaaaa]◆[/color] %d" % spell_count
	type_text += "[/font_size]"
	card_type_count.text = type_text
	
	card_count_label.text = "現在: " + str(total) + "/50"
	
	# 50枚以下なら保存可能
	if total <= 50:
		save_button.disabled = false
		save_button.modulate = Color(1, 1, 1)
	else:
		save_button.disabled = true
		save_button.modulate = Color(0.5, 0.5, 0.5)

func _on_save_pressed():
	GameData.save_deck(GameData.selected_deck_index, _current_deck)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Album.tscn")

## 🔧 デバッグ用：全データをリセット（開発用）
func _create_debug_reset_button():
	var debug_button = Button.new()
	debug_button.text = "🔧 全データリセット"
	debug_button.custom_minimum_size = Vector2(280, 200)
	debug_button.add_theme_font_size_override("font_size", 28)
	debug_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # オレンジ色
	
	right_vbox.add_child(debug_button)
	debug_button.pressed.connect(_on_debug_reset_pressed)

func _on_debug_reset_pressed():
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "⚠️ 警告 ⚠️

全てのセーブデータをリセットして、
全カードを再登録しますか？

この操作は取り消せません！"
	confirm.title = "全データリセット"
	confirm.ok_button_text = "リセットする"
	confirm.cancel_button_text = "キャンセル"
	confirm.size = Vector2(500, 250)
	
	confirm.confirmed.connect(_on_debug_reset_confirmed)
	add_child(confirm)
	confirm.popup_centered()

func _on_debug_reset_confirmed():
	GameData.reset_save()
	
	# 確認ダイアログ
	var info = AcceptDialog.new()
	info.dialog_text = "✅ セーブデータをリセットしました。

ゲームを再起動してください。"
	info.title = "完了"
	add_child(info)
	info.popup_centered()

## リセットボタンを作成（保存ボタンの下に配置）
func _create_reset_button():
	_reset_button = Button.new()
	_reset_button.text = "リセット"
	_reset_button.custom_minimum_size = Vector2(280, 200)
	_reset_button.add_theme_font_size_override("font_size", 36)
	
	# 警告色（赤っぽく）
	_reset_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	# 保存ボタンと同じ親に追加
	right_vbox.add_child(_reset_button)
	
	# ボタン押下時の処理を接続
	_reset_button.pressed.connect(_on_reset_pressed)

## リセットボタン押下時の処理
func _on_reset_pressed():
	# 確認ダイアログを表示
	var confirm_dialog = ConfirmationDialog.new()
	
	# 現在編集中のブック名を取得
	var deck_name = GameData.player_data.decks[GameData.selected_deck_index]["name"]

	confirm_dialog.dialog_text = "「" + deck_name + "」を空デッキ（0枚）にリセットしますか？\n\n現在の内容は失われます。\n他のブックは影響を受けません。"
	confirm_dialog.title = "ブックリセット確認"
	confirm_dialog.ok_button_text = "リセットする"
	confirm_dialog.cancel_button_text = "キャンセル"
	
	# ダイアログサイズ調整
	confirm_dialog.size = Vector2(500, 200)
	
	# OKボタン押下時の処理
	confirm_dialog.confirmed.connect(_on_reset_confirmed)
	
	# ダイアログを追加して表示
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

## リセット確認後の実際の処理
func _on_reset_confirmed():
	# 空デッキ（0枚）
	var empty_deck = {}
	
	# 現在のデッキを上書き
	_current_deck = empty_deck.duplicate()
	
	# GameDataにも保存
	GameData.save_deck(GameData.selected_deck_index, _current_deck)

	# 表示を更新
	update_card_count()
	display_cards(_current_filter)


## フィルターに応じた属性色を返す
func _get_filter_color(filter_type: String) -> Color:
	match filter_type:
		"火":
			return Color(0.9, 0.3, 0.1)
		"水":
			return Color(0.1, 0.4, 0.9)
		"地":
			return Color(0.5, 0.35, 0.1)
		"風":
			return Color(0.1, 0.7, 0.3)
		"無":
			return Color(0.6, 0.6, 0.6)
		"item":
			return Color(0.7, 0.6, 0.2)
		"spell":
			return Color(0.5, 0.2, 0.7)
	# deck / all はニュートラル
	return Color(0.4, 0.4, 0.5)


## 宇宙風背景（暗いグラデーション + 星エフェクト）
func _setup_space_background(element_color: Color):
	# 既存の背景を削除
	var existing = get_node_or_null("SpaceBG")
	if existing:
		existing.queue_free()

	var bg_container = Control.new()
	bg_container.name = "SpaceBG"
	bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# グラデーション背景（属性色 → 暗闇）
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

	# 星を散りばめる（60個）
	var viewport_size = get_viewport().get_visible_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = _current_filter.hash()

	for i in range(60):
		var star = PanelContainer.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var star_size = rng.randf_range(2.0, 6.0)
		star.custom_minimum_size = Vector2(star_size, star_size)
		star.position = Vector2(rng.randf_range(0, viewport_size.x), rng.randf_range(0, viewport_size.y))

		var star_style = StyleBoxFlat.new()
		var brightness = rng.randf_range(0.5, 1.0)
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

		# キラキラアニメーション（40%の星）
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


## 子ノード全体のmouse_filterをIGNOREに設定（スクロール透過用）
func _set_mouse_filter_ignore(node: Control):
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_set_mouse_filter_ignore(child)
