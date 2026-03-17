extends Control

var _current_deck: Dictionary = {}  # 現在編集中のデッキ
var _current_filter: String = "all"  # フィルター状態
var _card_dialog: VBoxContainer = null
var _selected_card_id: int = 0
var _count_buttons: Array[Button] = []  # 枚数選択ボタンの配列

@onready var _button_container: HBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/Control/HBoxContainer
@onready var _scroll_container: ScrollContainer = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer
@onready var _grid_container: GridContainer = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer/GridContainer
@onready var _info_panel_container: Control = $MarginContainer/HBoxContainer/LeftPanel/InfoPanelContainer
@onready var _right_vbox: VBoxContainer = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer
@onready var _card_type_count: RichTextLabel = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardTypeCount
@onready var _card_count_label: Label = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardCountLabel
@onready var _save_button: Button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/SaveButton

var _reset_button: Button = null

# インフォパネル
var _creature_info_panel_scene: PackedScene = preload("res://scenes/ui/creature_info_panel.tscn")
var _item_info_panel_scene: PackedScene = preload("res://scenes/ui/item_info_panel.tscn")
var _spell_info_panel_scene: PackedScene = preload("res://scenes/ui/spell_info_panel.tscn")
var _current_info_panel: Control = null

func _ready():
	# フィルターボタン接続（8個）
	var buttons = _button_container.get_children()
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
	_save_button.pressed.connect(_on_save_pressed)
	
	# リセットボタンを動的に作成
	_create_reset_button()
	
	# 🔧 デバッグ: データリセットボタン（テスト用）
	_create_debug_reset_button()
	
	# もし戻るボタンが別の場所にあれば
	if has_node("BackButton"):
		$BackButton.pressed.connect(_on_back_pressed)
	
	# 選択したブックを読み込み
	_load_deck()
	
	# タイトル設定（もしタイトルラベルがあれば）
	if has_node("TitleLabel"):
		var deck_name = GameData.player_data.decks[GameData.selected_deck_index]["name"]
		$TitleLabel.text = "デッキ編集 - " + deck_name
	
	# ダイアログ作成
	_create_card_dialog()
	
	# InfoPanelContainerのマウスイベントを透過
	_info_panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 宇宙風背景を設定
	_setup_space_background(Color(0.4, 0.4, 0.5))

	# カード一覧を表示（最初はデッキ内のカードのみ）
	_display_cards("deck")

func _load_deck():
	# GameDataから現在のブックを読み込み
	_current_deck = GameData.get_current_deck()["cards"].duplicate()
	_update_card_count()

func _create_card_dialog():
	# _info_panel_container 内に直接配置（Popup不使用でスクロールをブロックしない）
	_card_dialog = VBoxContainer.new()
	_card_dialog.name = "CardDialog"
	_card_dialog.add_theme_constant_override("separation", 25)
	_card_dialog.visible = false

	# 所持枚数/デッキ内枚数ラベル
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.add_theme_font_size_override("font_size", 60)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_dialog.add_child(info_label)

	# 枚数選択ボタン（横並び）
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)

	_count_buttons.clear()
	for i in range(5):
		var btn = Button.new()
		btn.text = str(i) + "枚"
		btn.custom_minimum_size = Vector2(140, 120)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 40)
		btn.pressed.connect(_on_count_selected.bind(i))
		hbox.add_child(btn)
		_count_buttons.append(btn)

	_card_dialog.add_child(hbox)

	# 閉じるボタン
	var close_btn = Button.new()
	close_btn.text = "閉じる"
	close_btn.custom_minimum_size = Vector2(300, 120)
	close_btn.add_theme_font_size_override("font_size", 45)
	close_btn.pressed.connect(_on_dialog_closed)
	_card_dialog.add_child(close_btn)

	# InfoPanelContainerの下部に配置
	_info_panel_container.add_child(_card_dialog)

## ダイアログが閉じられたとき（インフォパネルも閉じる）
func _on_dialog_closed():
	_card_dialog.visible = false
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
	_display_cards(filter_type)

func _display_cards(filter: String):
	_clear_card_list()
	
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
		_create_card_button(card)

func _clear_card_list():
	for child in _grid_container.get_children():
		child.queue_free()

func _create_card_button(card_data: Dictionary):
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
	_grid_container.add_child(button)


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
	_info_panel_container.add_child(_current_info_panel)

	# マウスイベントを透過させてスクロールを妨げない
	_set_mouse_filter_ignore(_current_info_panel)
	
	# アンカーをリセットし、サイズをコンテナに制限（入力イベントがはみ出さないように）
	_current_info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_current_info_panel.anchor_left = 0
	_current_info_panel.anchor_top = 0
	_current_info_panel.anchor_right = 0
	_current_info_panel.anchor_bottom = 0
	_current_info_panel.size = _info_panel_container.size
	_current_info_panel.clip_contents = true
	
	# データを読み込む
	match card_type:
		"creature":
			_current_info_panel.show_view_mode(card, -1, false)
		"item":
			_current_info_panel.show_item_info(card)
		"spell":
			_current_info_panel.show_spell_info(card)
	
	await get_tree().process_frame
	
	if not _info_panel_container or not is_instance_valid(_info_panel_container):
		return

	# データ読み込み後に再度マウスフィルター設定（動的追加ノード対応）
	_set_mouse_filter_ignore(_current_info_panel)

	# コンテナ基準で配置
	_current_info_panel.position = Vector2(0, 0)
	_current_info_panel.scale = Vector2(1.0, 1.0)
	var main_container = _current_info_panel.get_node_or_null("MainContainer")
	if main_container:
		main_container.position = Vector2(-120, -140)

## 枚数選択ダイアログを表示
func _show_count_dialog():
	var owned = GameData.get_card_count(_selected_card_id)
	var in_deck = _current_deck.get(_selected_card_id, 0)
	
	# 情報ラベルを更新
	var info_label = _card_dialog.get_node_or_null("InfoLabel")
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
	
	# インフォパネルの下に配置（コンテナ下部）
	var container_h = _info_panel_container.size.y
	_card_dialog.position = Vector2(0, container_h - _card_dialog.size.y - 10)
	_card_dialog.size.x = _info_panel_container.size.x
	_card_dialog.visible = true
	# 最前面に表示
	_info_panel_container.move_child(_card_dialog, -1)

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
	
	_update_card_count()
	
	# 該当カードのボタンだけ更新
	if _current_filter == "deck":
		_display_cards(_current_filter)
	else:
		_update_single_card_button(_selected_card_id)
	
	_card_dialog.visible = false

func _update_single_card_button(card_id: int):
	var card = CardLoader.get_card_by_id(card_id)
	var owned_count = GameData.get_card_count(card_id)
	var deck_count = _current_deck.get(card_id, 0)
	
	# 既存のボタンを探して更新
	for button in _grid_container.get_children():
		if button.has_meta("card_id") and button.get_meta("card_id") == card_id:
			# VBox内のLabelを探して更新（button.textではなく子Labelを更新）
			var vbox = button.get_child(0) if button.get_child_count() > 0 else null
			if not vbox:
				break
			var label: Label = null
			for child in vbox.get_children():
				if child is Label:
					label = child
					break
			if not label:
				break

			var card_name = card.get("name", "???")
			var dev_name = card.get("dev_name", "")
			var element = card.get("element", "")
			var card_type = card.get("type", "")
			var rarity = card.get("rarity", "N")

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
				var ap = card.get("ap", 0)
				var hp = card.get("hp", 0)
				text += "\nAP:%d / HP:%d" % [ap, hp]

			label.text = text
			break

func _update_card_count():
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
	_card_type_count.text = type_text
	
	_card_count_label.text = "現在: " + str(total) + "/50"
	
	# 50枚以下なら保存可能
	if total <= 50:
		_save_button.disabled = false
		_save_button.modulate = Color(1, 1, 1)
	else:
		_save_button.disabled = true
		_save_button.modulate = Color(0.5, 0.5, 0.5)

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
	
	_right_vbox.add_child(debug_button)
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
	_right_vbox.add_child(_reset_button)
	
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
	_update_card_count()
	_display_cards(_current_filter)

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
