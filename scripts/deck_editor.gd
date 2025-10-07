extends Control

var current_deck = {}  # 現在編集中のデッキ
var current_filter = "all"  # フィルター状態
var card_dialog = null
var selected_card_id = 0

func _ready():
	# ボタン接続
	$BackButton.pressed.connect(_on_back_pressed)
	$SaveButton.pressed.connect(_on_save_pressed)
	
	# フィルターボタン接続
	$DeckButton.pressed.connect(_on_filter_pressed.bind("deck"))
	$NeutralButton.pressed.connect(_on_filter_pressed.bind("無"))
	$FireButton.pressed.connect(_on_filter_pressed.bind("火"))
	$WaterButton.pressed.connect(_on_filter_pressed.bind("水"))
	$EarthButton.pressed.connect(_on_filter_pressed.bind("地"))
	$WindButton.pressed.connect(_on_filter_pressed.bind("風"))
	$ItemButton.pressed.connect(_on_filter_pressed.bind("item"))
	$SpellButton.pressed.connect(_on_filter_pressed.bind("spell"))
	
	# 選択したブックを読み込み
	load_deck()
	
	# タイトルを更新
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
	
	for i in range(5):
		var btn = Button.new()
		btn.text = str(i) + "枚"
		btn.custom_minimum_size = Vector2(80, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_count_selected.bind(i))
		hbox.add_child(btn)
	
	vbox.add_child(hbox)
	
	add_child(card_dialog)

func _on_filter_pressed(filter_type: String):
	current_filter = filter_type
	display_cards(filter_type)
	print("フィルター: ", filter_type)

func display_cards(filter: String):
	clear_card_list()
	
	var cards_to_show = []
	
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
			if card.type == "spell" and GameData.player_data.collection.has(card.id):
				cards_to_show.append(card)
	elif filter == "item":
		# アイテムカード
		for card in CardLoader.all_cards:
			if card.type == "item" and GameData.player_data.collection.has(card.id):
				cards_to_show.append(card)
	elif filter == "all":
		# 全ての所持カード
		for card in CardLoader.all_cards:
			if GameData.player_data.collection.has(card.id):
				cards_to_show.append(card)
	else:
		# 属性フィルター（火・水・地・風・無）
		for card in CardLoader.all_cards:
			if card.has("element") and card.element == filter and GameData.player_data.collection.has(card.id):
				cards_to_show.append(card)
	
	# カードボタンを生成
	for card in cards_to_show:
		create_card_button(card)

func clear_card_list():
	var grid = $DeckScrollContainer/GridContainer
	for child in grid.get_children():
		child.queue_free()

func create_card_button(card_data: Dictionary):
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 140)
	
	# 所持枚数を取得
	var owned_count = GameData.player_data.collection.get(card_data.id, 0)
	var deck_count = current_deck.get(card_data.id, 0)
	
	# ボタンテキスト
	var card_name = card_data.get("name", "???")
	var card_type = card_data.get("type", "")
	var element = card_data.get("element", "")
	
	button.text = card_name + "\n"
	if not element.is_empty():
		button.text += "[" + element + "] "
	button.text += str(owned_count) + "枚"
	if deck_count > 0:
		button.text += " (デッキ:" + str(deck_count) + ")"
	
	# ボタン押下時の処理
	button.pressed.connect(_on_card_button_pressed.bind(card_data.id))
	
	$DeckScrollContainer/GridContainer.add_child(button)

func _on_card_button_pressed(card_id: int):
	selected_card_id = card_id
	var card = CardLoader.get_card_by_id(card_id)
	
	var owned = GameData.player_data.collection.get(card_id, 0)
	var in_deck = current_deck.get(card_id, 0)
	
	var title_label = card_dialog.get_node("DialogVBox/TitleLabel")
	var info_label = card_dialog.get_node("DialogVBox/InfoLabel")
	
	title_label.text = card.get("name", "???")
	info_label.text = "所持: " + str(owned) + "枚 / デッキ内: " + str(in_deck) + "枚\n\nデッキに入れる枚数を選択してください"
	
	card_dialog.popup_centered()
	
func _on_count_selected(count: int):
	var owned = GameData.player_data.collection.get(selected_card_id, 0)
	var max_count = min(4, owned)
	
	if count > max_count:
		print("所持数を超えています")
		return
	
	# 現在のデッキ枚数を計算（選択中のカードを除く）
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
		print("カードを削除しました")
	else:
		current_deck[selected_card_id] = count
		print("カードを", count, "枚に設定しました")
	
	update_card_count()
	display_cards(current_filter)
	card_dialog.hide()

func update_card_count():
	var total = 0
	for count in current_deck.values():
		total += count
	
	$CardCountLabel.text = "現在: " + str(total) + "/50"
	
	# 50枚の時だけ保存ボタン有効化
	$SaveButton.disabled = (total != 50)

func _on_save_pressed():
	# GameDataに保存
	GameData.save_deck(GameData.selected_deck_index, current_deck)
	print("保存完了")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/DeckSelect.tscn")
