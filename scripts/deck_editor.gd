extends Control

var current_deck = {}  # 現在編集中のデッキ
var current_filter = "all"  # フィルター状態
var card_dialog = null
var selected_card_id = 0
var count_buttons = []  # 枚数選択ボタンの配列

# 正確なノードパス
@onready var button_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/Control/HBoxContainer
@onready var scroll_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/DeckScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/DeckScrollContainer/GridContainer
@onready var right_vbox = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer
@onready var card_count_label = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardCountLabel
@onready var save_button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/SaveButton

# リセットボタン（コードで生成）
var reset_button: Button = null

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
	
	# カード一覧を表示
	display_cards("all")

func load_deck():
	# GameDataから現在のブックを読み込み
	current_deck = GameData.get_current_deck()["cards"].duplicate()
	update_card_count()

func create_card_dialog():
	card_dialog = Popup.new()
	card_dialog.size = Vector2(600, 300)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(560, 260)
	vbox.name = "DialogVBox"
	card_dialog.add_child(vbox)
	
	# タイトルラベル
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)
	
	# 情報ラベル
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(info_label)
	
	# スペーサー
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# 枚数選択ボタン（横並び）
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	
	count_buttons.clear()
	for i in range(5):
		var btn = Button.new()
		btn.text = str(i) + "枚"
		btn.custom_minimum_size = Vector2(80, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_count_selected.bind(i))
		hbox.add_child(btn)
		count_buttons.append(btn)
	
	vbox.add_child(hbox)
	
	add_child(card_dialog)

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
	elif filter == "all":
		# 全ての所持カード
		for card in CardLoader.all_cards:
			if GameData.get_card_count(card.id) > 0:
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
	var button = Button.new()
	button.custom_minimum_size = Vector2(300, 500)
	
	# カードIDをメタデータとして保存
	button.set_meta("card_id", card_data.id)
	
	# 所持枚数を取得
	var owned_count = GameData.player_data.collection.get(card_data.id, 0)
	var deck_count = current_deck.get(card_data.id, 0)
	
	# ボタンテキスト
	var card_name = card_data.get("name", "???")
	var element = card_data.get("element", "")
	
	button.text = card_name + "\n"
	if not element.is_empty():
		button.text += "[" + element + "] "
	button.text += str(owned_count) + "枚"
	if deck_count > 0:
		button.text += " (デッキ:" + str(deck_count) + ")"
	
	# ボタン押下時の処理
	button.pressed.connect(_on_card_button_pressed.bind(card_data.id))
	
	grid_container.add_child(button)

func _on_card_button_pressed(card_id: int):
	selected_card_id = card_id
	var card = CardLoader.get_card_by_id(card_id)
	
	var owned = GameData.player_data.collection.get(card_id, 0)
	var in_deck = current_deck.get(card_id, 0)
	
	var title_label = card_dialog.get_node("DialogVBox/TitleLabel")
	var info_label = card_dialog.get_node("DialogVBox/InfoLabel")
	
	title_label.text = card.get("name", "???")
	info_label.text = "所持: " + str(owned) + "枚 / デッキ内: " + str(in_deck) + "枚\n\nデッキに入れる枚数を選択してください"
	
	# ボタンの有効/無効を設定
	var max_count = min(4, owned)
	for i in range(count_buttons.size()):
		if i > max_count:
			count_buttons[i].disabled = true
			count_buttons[i].modulate = Color(0.5, 0.5, 0.5)
		else:
			count_buttons[i].disabled = false
			count_buttons[i].modulate = Color(1, 1, 1)
	
	card_dialog.popup_centered()

func _on_count_selected(count: int):
	var owned = GameData.player_data.collection.get(selected_card_id, 0)
	var max_count = min(4, owned)
	
	if count > max_count:
		print("所持数を超えています")
		return
	
	# 現在のデッキ枚数を計算
	var current_total = 0
	for card_id in current_deck.keys():
		if card_id != selected_card_id:
			current_total += current_deck[card_id]
	
	# 新しい枚数を追加した時の合計
	if current_total + count > 50:
		print("デッキが50枚を超えます！")
		return
	
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
	var owned_count = GameData.player_data.collection.get(card_id, 0)
	var deck_count = current_deck.get(card_id, 0)
	
	# 既存のボタンを探して更新
	for button in grid_container.get_children():
		if button.has_meta("card_id") and button.get_meta("card_id") == card_id:
			var card_name = card.get("name", "???")
			var element = card.get("element", "")
			
			button.text = card_name + "\n"
			if not element.is_empty():
				button.text += "[" + element + "] "
			button.text += str(owned_count) + "枚"
			if deck_count > 0:
				button.text += " (デッキ:" + str(deck_count) + ")"
			break

func update_card_count():
	var total = 0
	for count in current_deck.values():
		total += count
	
	card_count_label.text = "現在: " + str(total) + "/50"
	
	# 保存ボタンは常に有効（何枚でも保存可能）
	save_button.disabled = false

func _on_save_pressed():
	GameData.save_deck(GameData.selected_deck_index, current_deck)
	print("デッキ保存完了")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Album.tscn")

## 🔧 デバッグ用：全データをリセット（開発用）
func create_debug_reset_button():
	var debug_button = Button.new()
	debug_button.text = "🔧 全データリセット"
	debug_button.custom_minimum_size = Vector2(200, 60)
	debug_button.add_theme_font_size_override("font_size", 16)
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
	reset_button.custom_minimum_size = Vector2(200, 60)
	reset_button.add_theme_font_size_override("font_size", 20)
	
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
