extends Control

var current_deck = {}  # 現在編集中のデッキ
var current_filter = "all"  # フィルター状態
var card_dialog = null
var selected_card_id = 0
var count_buttons = []  # 枚数選択ボタンの配列

# 正確なノードパス
@onready var button_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/Control/HBoxContainer
@onready var scroll_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer/GridContainer
@onready var info_panel_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/InfoPanelContainer
@onready var right_vbox = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer
@onready var card_type_count = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardTypeCount
@onready var card_count_label = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardCountLabel
@onready var save_button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/SaveButton

# リセットボタン（コードで生成）
var reset_button: Button = null

# インフォパネル
var CreatureInfoPanelScene = preload("res://scenes/ui/creature_info_panel.tscn")
var ItemInfoPanelScene = preload("res://scenes/ui/item_info_panel.tscn")
var SpellInfoPanelScene = preload("res://scenes/ui/spell_info_panel.tscn")
var current_info_panel: Control = null

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
	create_reset_button()
	
	# 🔧 デバッグ: データリセットボタン（テスト用）
	create_debug_reset_button()
	
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
	create_card_dialog()
	
	# カード一覧を表示（最初はデッキ内のカードのみ）
	display_cards("deck")

func load_deck():
	# GameDataから現在のブックを読み込み
	current_deck = GameData.get_current_deck()["cards"].duplicate()
	update_card_count()

func create_card_dialog():
	card_dialog = Popup.new()
	card_dialog.size = Vector2(1183, 500)
	
	# シンプルなVBox
	var vbox = VBoxContainer.new()
	vbox.name = "DialogVBox"
	vbox.position = Vector2(30, 30)
	vbox.size = Vector2(1123, 440)
	vbox.add_theme_constant_override("separation", 30)
	card_dialog.add_child(vbox)
	
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
	
	count_buttons.clear()
	for i in range(5):
		var btn = Button.new()
		btn.text = str(i) + "枚"
		btn.custom_minimum_size = Vector2(180, 100)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 50)
		btn.pressed.connect(_on_count_selected.bind(i))
		hbox.add_child(btn)
		count_buttons.append(btn)
	
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
	card_dialog.popup_hide.connect(_on_dialog_closed)
	
	add_child(card_dialog)

## ダイアログが閉じられたとき（インフォパネルも閉じる）
func _on_dialog_closed():
	card_dialog.hide()
	_close_info_panel()

## インフォパネルを閉じる
func _close_info_panel():
	if current_info_panel and is_instance_valid(current_info_panel):
		current_info_panel.queue_free()
		current_info_panel = null

func _on_filter_pressed(filter_type: String):
	current_filter = filter_type
	display_cards(filter_type)

func display_cards(filter: String):
	clear_card_list()
	
	var cards_to_show = []
	
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
		for card_id in current_deck.keys():
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
	var deck_count = current_deck.get(card_data.id, 0)
	var rarity = card_data.get("rarity", "N")
	
	# ボタン（元のサイズに戻す）
	var button = Button.new()
	button.custom_minimum_size = Vector2(420, 700)
	button.set_meta("card_id", card_data.id)
	
	# テキスト表示
	var card_name = card_data.get("name", "???")
	var dev_name = card_data.get("dev_name", "")
	var element = card_data.get("element", "")
	var card_type = card_data.get("type", "")

	button.text = card_name
	if not dev_name.is_empty():
		button.text += "\n" + dev_name
	button.text += "\n[" + rarity + "]"
	if not element.is_empty():
		button.text += " " + element
	button.text += "\n所持: " + str(owned_count) + "枚"
	if deck_count > 0:
		button.text += "\nデッキ: " + str(deck_count) + "枚"
	
	# クリーチャーならAP/HP表示
	if card_type == "creature":
		var ap = card_data.get("ap", 0)
		var hp = card_data.get("hp", 0)
		button.text += "\nAP:%d / HP:%d" % [ap, hp]
	
	button.add_theme_font_size_override("font_size", 32)
	
	# レアリティで背景色
	match rarity:
		"R":
			button.modulate = Color(1.0, 0.9, 0.7)
		"S":
			button.modulate = Color(0.9, 0.85, 1.0)
		"N":
			button.modulate = Color(0.85, 0.9, 1.0)
		"C":
			button.modulate = Color(0.9, 0.9, 0.9)
	
	button.pressed.connect(_on_card_button_pressed.bind(card_data.id))
	grid_container.add_child(button)

## カードシーンをプリロード
var CardScene = preload("res://scenes/Card.tscn")

func _on_card_button_pressed(card_id: int):
	selected_card_id = card_id
	var card = CardLoader.get_card_by_id(card_id)
	var card_type = card.get("type", "")
	
	# カードタイプに応じたインフォパネルを表示
	_show_info_panel(card, card_type)

## カードタイプに応じたインフォパネルを表示
func _show_info_panel(card: Dictionary, card_type: String):
	# 既存のインフォパネルを削除
	if current_info_panel and is_instance_valid(current_info_panel):
		current_info_panel.queue_free()
		current_info_panel = null
	
	# インフォパネルの紙部分を右側パネルに表示
	_show_info_in_right_panel(card, card_type)
	
	# 枚数選択ダイアログを表示
	_show_count_dialog()

## InfoPanelContainerにインフォパネルを表示
func _show_info_in_right_panel(card: Dictionary, card_type: String):
	# 既存のプレビューを削除
	if current_info_panel and is_instance_valid(current_info_panel):
		current_info_panel.queue_free()
		current_info_panel = null
	
	# タイプに応じたパネルをインスタンス化
	match card_type:
		"creature":
			current_info_panel = CreatureInfoPanelScene.instantiate()
		"item":
			current_info_panel = ItemInfoPanelScene.instantiate()
		"spell":
			current_info_panel = SpellInfoPanelScene.instantiate()
	
	if not current_info_panel:
		return
	
	# InfoPanelContainerに追加
	info_panel_container.add_child(current_info_panel)
	
	# アンカーをリセット（左上基準に）
	current_info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	current_info_panel.anchor_left = 0
	current_info_panel.anchor_top = 0
	current_info_panel.anchor_right = 0
	current_info_panel.anchor_bottom = 0
	
	# データを読み込む
	match card_type:
		"creature":
			current_info_panel.show_view_mode(card, -1, false)
		"item":
			current_info_panel.show_item_info(card)
		"spell":
			current_info_panel.show_spell_info(card)
	
	await get_tree().process_frame
	
	# デバッグ出力
	var container_size = info_panel_container.size
	var panel_size = current_info_panel.size
	print("Container size: ", container_size)
	print("Panel size: ", panel_size)
	
	# スケール調整
	var scale_factor = 0.95
	current_info_panel.scale = Vector2(scale_factor, scale_factor)
	
	# 位置を調整
	current_info_panel.position = Vector2(0, 0)
	
	# 中のMainContainerの位置を調整（左に265、上に210）
	var main_container = current_info_panel.get_node_or_null("MainContainer")
	if main_container:
		main_container.position.x -= 265
		main_container.position.y -= 210
	
	print("Applied scale: ", current_info_panel.scale)
	print("Panel position: ", current_info_panel.position)

## インフォパネルが閉じられたとき
func _on_info_panel_closed():
	if current_info_panel and is_instance_valid(current_info_panel):
		current_info_panel.queue_free()
		current_info_panel = null

## 枚数選択ダイアログを表示
func _show_count_dialog():
	var owned = GameData.get_card_count(selected_card_id)
	var in_deck = current_deck.get(selected_card_id, 0)
	
	# 情報ラベルを更新
	var info_label = card_dialog.get_node_or_null("DialogVBox/InfoLabel")
	if info_label:
		info_label.text = "所持: %d枚 / デッキ内: %d枚" % [owned, in_deck]
	
	# ボタンの有効/無効を設定
	var max_count = min(4, owned)
	for i in range(count_buttons.size()):
		if i > max_count:
			count_buttons[i].disabled = true
			count_buttons[i].modulate = Color(0.5, 0.5, 0.5)
		else:
			count_buttons[i].disabled = false
			count_buttons[i].modulate = Color(1, 1, 1)
	
	# インフォパネルの下に配置
	await get_tree().process_frame
	var info_rect = info_panel_container.get_global_rect()
	card_dialog.position = Vector2(info_rect.position.x, info_rect.end.y + 10)
	card_dialog.popup()

func _on_count_selected(count: int):
	var owned = GameData.get_card_count(selected_card_id)
	var max_count = min(4, owned)
	
	if count > max_count:
		print("所持数を超えています")
		return
	
	# 現在のデッキ枚数を計算
	var current_total = 0
	for card_id in current_deck.keys():
		if card_id != selected_card_id:
			current_total += current_deck[card_id]
	
	# 50枚超えても追加可能（ただし保存不可）
	
	# デッキに設定
	if count == 0:
		current_deck.erase(selected_card_id)
	else:
		current_deck[selected_card_id] = count
	
	update_card_count()
	
	# 該当カードのボタンだけ更新
	if current_filter == "deck":
		display_cards(current_filter)
	else:
		update_single_card_button(selected_card_id)
	
	card_dialog.hide()

func update_single_card_button(card_id: int):
	var card = CardLoader.get_card_by_id(card_id)
	var owned_count = GameData.get_card_count(card_id)
	var deck_count = current_deck.get(card_id, 0)
	
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
	
	for card_id in current_deck.keys():
		var count = current_deck[card_id]
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
	GameData.save_deck(GameData.selected_deck_index, current_deck)
	print("デッキ保存完了")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Album.tscn")

## 🔧 デバッグ用：全データをリセット（開発用）
func create_debug_reset_button():
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
	print("🔧 [デバッグ] 全データリセット実行")
	GameData.reset_save()
	print("✅ リセット完了 - ゲームを再起動してください")
	
	# 確認ダイアログ
	var info = AcceptDialog.new()
	info.dialog_text = "✅ セーブデータをリセットしました。

ゲームを再起動してください。"
	info.title = "完了"
	add_child(info)
	info.popup_centered()

## リセットボタンを作成（保存ボタンの下に配置）
func create_reset_button():
	reset_button = Button.new()
	reset_button.text = "リセット"
	reset_button.custom_minimum_size = Vector2(280, 200)
	reset_button.add_theme_font_size_override("font_size", 36)
	
	# 警告色（赤っぽく）
	reset_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	# 保存ボタンと同じ親に追加
	right_vbox.add_child(reset_button)
	
	# ボタン押下時の処理を接続
	reset_button.pressed.connect(_on_reset_pressed)

## リセットボタン押下時の処理
func _on_reset_pressed():
	# 確認ダイアログを表示
	var confirm_dialog = ConfirmationDialog.new()
	
	# 現在編集中のブック名を取得
	var current_deck_name = GameData.player_data.decks[GameData.selected_deck_index]["name"]
	
	confirm_dialog.dialog_text = "「" + current_deck_name + "」を空デッキ（0枚）にリセットしますか？\n\n現在の内容は失われます。\n他のブックは影響を受けません。"
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
	print("【ブックリセット】ブック", GameData.selected_deck_index, "をリセットします")
	
	# 空デッキ（0枚）
	var empty_deck = {}
	
	# 現在のデッキを上書き
	current_deck = empty_deck.duplicate()
	
	# GameDataにも保存
	GameData.save_deck(GameData.selected_deck_index, current_deck)
	
	print("【ブックリセット】完了 - 空デッキ（0枚）")
	
	# 表示を更新
	update_card_count()
	display_cards(current_filter)
