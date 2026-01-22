extends Control

# ボタンへのパス（新しい構造に対応）
@onready var grid = $MarginContainer/HBoxContainer/RightPanel/CenterContainer/GridContainer

# ユーザー情報表示用
@onready var player_name_label = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/UserInfoPanel/VBox/NameHBox/PlayerNameLabel
@onready var gold_label = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/UserInfoPanel/VBox/GoldHBox/GoldLabel
@onready var character_rect = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/CharacterContainer/CharacterRect

# デバッグ用（後で削除）
@onready var reset_gold_button = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/UserInfoPanel/VBox/NameHBox/ResetGoldButton

func _ready():
	# 各ボタンの接続（実際のボタン名で）
	grid.get_node("QuestButton").pressed.connect(_on_quest_pressed)
	grid.get_node("SoloBattleButton").pressed.connect(_on_solo_battle_pressed)
	grid.get_node("NetBattleButton").pressed.connect(_on_net_battle_pressed)
	grid.get_node("DeckButton").pressed.connect(_on_album_pressed)  # DeckButtonをアルバムに
	grid.get_node("SettingsButton").pressed.connect(_on_settings_pressed)
	grid.get_node("ShopButton").pressed.connect(_on_shop_pressed)
	
	# ユーザー情報を表示
	_update_user_info()
	
	# デバッグ用：ゴールドリセットボタン（後で削除）
	if reset_gold_button:
		reset_gold_button.pressed.connect(_on_reset_gold)

func _update_user_info():
	if player_name_label:
		player_name_label.text = GameData.player_data.profile.name
	if gold_label:
		gold_label.text = str(GameData.player_data.profile.gold) + " G"
	if character_rect:
		var texture = load("res://assets/images/characters/marion.png")
		if texture:
			character_rect.texture = texture

# デバッグ用：ゴールドを100000にリセット（後で削除）
func _on_reset_gold():
	GameData.player_data.profile.gold = 100000
	GameData.save_to_file()
	_update_user_info()
	print("[DEBUG] ゴールドを100000にリセットしました")

# ========== デッキ検証 ==========
## 全デッキに所持していないカードが含まれていないかチェック
func _check_deck_validity() -> Dictionary:
	var invalid_cards = []
	
	for deck_index in range(GameData.player_data.decks.size()):
		var deck = GameData.player_data.decks[deck_index]
		var cards = deck.get("cards", {})
		
		for card_id in cards.keys():
			var owned = UserCardDB.get_card_count(card_id)
			if owned <= 0:
				var card_info = CardLoader.get_card_by_id(card_id)
				var card_name = card_info.get("name", "ID:%d" % card_id) if card_info else "ID:%d" % card_id
				invalid_cards.append({
					"deck_index": deck_index,
					"deck_name": deck.get("name", "ブック%d" % (deck_index + 1)),
					"card_id": card_id,
					"card_name": card_name
				})
	
	return {
		"valid": invalid_cards.is_empty(),
		"invalid_cards": invalid_cards
	}

## 無効なデッキの場合に警告ダイアログを表示
func _show_invalid_deck_warning(invalid_cards: Array):
	var dialog = AcceptDialog.new()
	dialog.title = "デッキエラー"
	dialog.ok_button_text = "OK"
	
	# カスタムLabelでフォントサイズを大きくする
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 36)
	
	var message = "所持していないカードがデッキに含まれています。\nアルバムでデッキを修正してください。\n\n"
	for info in invalid_cards:
		message += "・%s: %s\n" % [info.deck_name, info.card_name]
	
	label.text = message
	dialog.add_child(label)
	
	# OKボタンのサイズを大きくする（横3倍、縦1.5倍）
	var ok_button = dialog.get_ok_button()
	ok_button.custom_minimum_size = Vector2(240, 60)
	ok_button.add_theme_font_size_override("font_size", 32)
	
	add_child(dialog)
	dialog.popup_centered()

# ========== ボタン処理 ==========
func _on_quest_pressed():
	# デッキ検証
	var check = _check_deck_validity()
	if not check.valid:
		_show_invalid_deck_warning(check.invalid_cards)
		return
	
	print("クエスト選択 → ステージ選択画面へ")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/QuestSelect.tscn")

func _on_solo_battle_pressed():
	# デッキ検証
	var check = _check_deck_validity()
	if not check.valid:
		_show_invalid_deck_warning(check.invalid_cards)
		return
	
	print("一人対戦選択 → ブック選択へ")
	# バトル用フラグを設定（メタデータを使用）
	GameData.set_meta("is_selecting_for_battle", true)
	# Album.tscnに遷移（バトルモードで起動）
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Album.tscn")

func _on_net_battle_pressed():
	# デッキ検証
	var check = _check_deck_validity()
	if not check.valid:
		_show_invalid_deck_warning(check.invalid_cards)
		return
	
	print("NET対戦選択")
	# get_tree().change_scene_to_file("res://scenes/NetBattle.tscn")

func _on_album_pressed():
	print("アルバム選択")
	# 通常モードでAlbum.tscnを開く（フラグなし）
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Album.tscn")

func _on_settings_pressed():
	print("設定選択")
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_shop_pressed():
	print("ショップ選択")
	get_tree().change_scene_to_file("res://scenes/Shop.tscn")
