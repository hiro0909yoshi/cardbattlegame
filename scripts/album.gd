extends Control

@onready var left_vbox = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer
@onready var right_panel = $MarginContainer/HBoxContainer/RightPanel
@onready var scroll_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer/GridContainer

# モード管理
var is_battle_mode = false  # バトル用かデッキ編集用か

func _ready():
	# GameDataから起動モードを取得（メタデータを使用）
	if GameData.has_meta("is_selecting_for_battle"):
		is_battle_mode = GameData.get_meta("is_selecting_for_battle")
	else:
		is_battle_mode = false
	
	# バトルモードなら最初からブック選択表示
	if is_battle_mode:
		scroll_container.visible = true
		print("バトル用ブック選択モード")
	else:
		scroll_container.visible = false
		print("通常アルバムモード")
	
	# 左側ボタン接続
	left_vbox.get_node("DeckEditButton").pressed.connect(_on_deck_edit_pressed)
	left_vbox.get_node("CardListButton").pressed.connect(_on_card_list_pressed)
	left_vbox.get_node("ResetCardsButton").pressed.connect(_on_reset_cards_pressed)
	left_vbox.get_node("BackButton").pressed.connect(_on_back_pressed)
	
	# バトルモードならブック選択を表示
	if is_battle_mode:
		_show_book_selection()

func _on_deck_edit_pressed():
	print("ブック選択画面表示")
	# 右側パネルを表示
	scroll_container.visible = true
	# ブック選択画面を表示
	_show_book_selection()

## ブック選択画面を表示
func _show_book_selection():
	# GridContainerをクリア
	for child in grid_container.get_children():
		child.queue_free()
	
	# ブックボタンを再作成（6個）
	for i in range(6):
		var book_button = Button.new()
		book_button.name = "book" + str(i + 1)
		book_button.custom_minimum_size = Vector2(1000, 400)
		
		# デッキ名を取得
		var deck_name = "ブック" + str(i + 1)
		if i < GameData.player_data.decks.size():
			deck_name = GameData.player_data.decks[i].get("name", deck_name)
			var card_count = GameData.player_data.decks[i].get("cards", {}).size()
			book_button.text = deck_name + "\n(" + str(card_count) + "種類)"
		else:
			book_button.text = deck_name
		
		book_button.add_theme_font_size_override("font_size", 48)
		book_button.pressed.connect(_on_book_selected.bind(i))
		grid_container.add_child(book_button)

func _on_book_selected(book_index: int):
	print("ブック", book_index + 1, "選択")
	# 選択したブックを保存
	GameData.selected_deck_index = book_index
	
	# モードに応じて遷移先を変える
	if is_battle_mode:
		# バトルモードの場合はフラグを消してバトル画面へ
		GameData.remove_meta("is_selecting_for_battle")
		print("→ バトル開始")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")
	else:
		# 通常モードの場合はデッキ編集画面へ
		print("→ デッキ編集")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/DeckEditor.tscn")

func _on_card_list_pressed():
	print("カード所持率表示")
	scroll_container.visible = true
	_show_collection_stats()

func _on_reset_cards_pressed():
	print("[DEBUG] カードリセット実行")
	UserCardDB.reset_database()
	UserCardDB.flush()
	# 表示更新
	_show_collection_stats()
	print("[DEBUG] 全カードを0枚にリセットしました")

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
	
	# 統計データを収集
	var stats = _calculate_collection_stats()
	
	# 表示用パネルを作成
	var categories = ["fire", "water", "earth", "wind", "neutral", "item", "spell"]
	var category_names = {
		"fire": "🔥 火",
		"water": "💧 水", 
		"earth": "🪨 地",
		"wind": "🌪️ 風",
		"neutral": "⚪ 無",
		"item": "📦 アイテム",
		"spell": "📜 スペル"
	}
	
	# 戻るボタンを追加
	var back_btn = Button.new()
	back_btn.text = "← 戻る"
	back_btn.custom_minimum_size = Vector2(200, 80)
	back_btn.add_theme_font_size_override("font_size", 32)
	back_btn.pressed.connect(_show_collection_stats)
	back_btn.visible = false
	back_btn.name = "CategoryBackButton"
	grid_container.add_child(back_btn)
	
	for category in categories:
		if not stats.has(category):
			continue
		
		var panel = _create_stats_panel(category_names[category], stats[category], category)
		grid_container.add_child(panel)

# カテゴリ名マップ（クラス変数として保持）
var _category_names = {
	"fire": "🔥 火",
	"water": "💧 水", 
	"earth": "🪨 地",
	"wind": "🌪️ 風",
	"neutral": "⚪ 無",
	"item": "📦 アイテム",
	"spell": "📜 スペル"
}

## カテゴリ別の統計パネルを作成（ボタンとして）
func _create_stats_panel(title: String, data: Dictionary, category: String) -> Control:
	var button = Button.new()
	button.custom_minimum_size = Vector2(900, 400)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# ボタンテキストを構築
	var text = title + "\n"
	
	var total_owned = data.get("total_owned", 0)
	var total_cards = data.get("total_cards", 0)
	var total_percent = 0.0 if total_cards == 0 else (float(total_owned) / total_cards * 100.0)
	text += "合計: %d / %d (%.1f%%)\n" % [total_owned, total_cards, total_percent]
	
	# レアリティ別（C < N < S < R）
	var rarities = ["C", "N", "S", "R"]
	for rarity in rarities:
		var rarity_data = data.get(rarity, {"owned": 0, "total": 0})
		var owned = rarity_data.get("owned", 0)
		var total = rarity_data.get("total", 0)
		var percent = 0.0 if total == 0 else (float(owned) / total * 100.0)
		text += "  [%s] %d / %d (%.1f%%)\n" % [rarity, owned, total, percent]
	
	button.text = text
	button.add_theme_font_size_override("font_size", 36)
	
	# クリックでカード一覧を表示
	button.pressed.connect(_show_category_cards.bind(category))
	
	return button

## カテゴリ別のカード一覧を表示
func _show_category_cards(category: String):
	print("カテゴリ表示: ", category)
	
	# GridContainerをクリア
	for child in grid_container.get_children():
		child.queue_free()
	
	# 戻るボタン
	var back_btn = Button.new()
	back_btn.text = "← 戻る"
	back_btn.custom_minimum_size = Vector2(200, 80)
	back_btn.add_theme_font_size_override("font_size", 32)
	back_btn.pressed.connect(_show_collection_stats)
	grid_container.add_child(back_btn)
	
	# タイトル
	var title_label = Label.new()
	title_label.text = _category_names.get(category, category) + " のカード一覧"
	title_label.add_theme_font_size_override("font_size", 48)
	grid_container.add_child(title_label)
	
	# カードを取得
	var cards_to_show = []
	for card in CardLoader.all_cards:
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
			cards_to_show.append(card)
	
	# カードボタンを作成
	for card in cards_to_show:
		var card_btn = _create_card_button(card)
		grid_container.add_child(card_btn)

## カードボタンを作成
func _create_card_button(card: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(280, 120)
	
	var card_id = card.get("id", 0)
	var card_name = card.get("name", "???")
	var rarity = card.get("rarity", "N")
	var owned = UserCardDB.get_card_count(card_id)
	
	button.text = "%s\n[%s] %d枚" % [card_name, rarity, owned]
	button.add_theme_font_size_override("font_size", 24)
	
	# 所持していない場合は暗くする
	if owned <= 0:
		button.modulate = Color(0.5, 0.5, 0.5)
	else:
		# レアリティで色分け
		match rarity:
			"R":
				button.modulate = Color(1.0, 0.9, 0.7)
			"S":
				button.modulate = Color(0.9, 0.8, 1.0)
			"N":
				button.modulate = Color(0.8, 0.9, 1.0)
	
	return button

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
	
	# 全カードをチェック
	for card in CardLoader.all_cards:
		var card_type = card.get("type", "")
		var element = card.get("element", "")
		var rarity = card.get("rarity", "N")
		var card_id = card.get("id", 0)
		
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
