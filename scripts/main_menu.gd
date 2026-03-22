extends Control

# 上部バー
@onready var _top_bar: PanelContainer = $MainVBox/TopBar
@onready var _stamina_label: Label = $MainVBox/TopBar/TopBarMargin/TopBarHBox/LeftIcons/StaminaLabel
@onready var _gold_label: Label = $MainVBox/TopBar/TopBarMargin/TopBarHBox/LeftIcons/GoldLabel
@onready var _stone_icon: Label = $MainVBox/TopBar/TopBarMargin/TopBarHBox/LeftIcons/StoneIcon
@onready var _stone_label: Label = $MainVBox/TopBar/TopBarMargin/TopBarHBox/LeftIcons/StoneLabel
@onready var _stamina_plus_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/LeftIcons/StaminaPlusButton
@onready var _gold_plus_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/LeftIcons/GoldPlusButton
@onready var _stone_plus_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/LeftIcons/StonePlusButton
@onready var _daily_quest_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/RightIcons/DailyQuestButton
@onready var _announcement_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/RightIcons/AnnouncementButton
@onready var _mail_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/RightIcons/MailButton
@onready var _settings_icon_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/RightIcons/SettingsButton

# 左パネル（タップでステータス画面へ）
@onready var _left_panel: Control = $MainVBox/ContentArea/LeftPanel
@onready var _player_name_label: Label = $MainVBox/ContentArea/LeftPanel/VBoxContainer/UserInfoPanel/VBox/NameHBox/PlayerNameLabel
@onready var _character_rect: TextureRect = $MainVBox/ContentArea/LeftPanel/VBoxContainer/CharacterContainer/CharacterRect

# 右パネル（メインボタン）
@onready var _right_vbox: VBoxContainer = $MainVBox/ContentArea/RightPanel/RightVBox

# デバッグ用（後で削除）
@onready var _reset_gold_button: Button = $MainVBox/ContentArea/LeftPanel/VBoxContainer/UserInfoPanel/VBox/NameHBox/ResetGoldButton
@onready var _reset_stamina_button: Button = $MainVBox/ContentArea/LeftPanel/VBoxContainer/UserInfoPanel/VBox/NameHBox/ResetStaminaButton
@onready var _reset_stone_button: Button = $MainVBox/ContentArea/LeftPanel/VBoxContainer/UserInfoPanel/VBox/NameHBox/ResetStoneButton


func _ready():
	# 上部バーの背景色を設定（黒とグレーの中間）
	_setup_top_bar_style()

	# メインボタンの接続
	_right_vbox.get_node("BattleContainer/TopRow/QuestButton").pressed.connect(_on_quest_pressed)
	_right_vbox.get_node("BattleContainer/TopRow/TournamentButton").pressed.connect(_on_tournament_pressed)
	_right_vbox.get_node("BattleContainer/BottomBattleRow/NetBattleButton").pressed.connect(_on_net_battle_pressed)
	_right_vbox.get_node("BattleContainer/BottomBattleRow/SoloBattleButton").pressed.connect(_on_solo_battle_pressed)
	_right_vbox.get_node("MenuContainer/BottomRow/DeckButton").pressed.connect(_on_album_pressed)
	_right_vbox.get_node("MenuContainer/BottomRow/StorageButton").pressed.connect(_on_storage_pressed)
	_right_vbox.get_node("MenuContainer/BottomRow/FacilityButton").pressed.connect(_on_facility_pressed)
	_right_vbox.get_node("MenuContainer/BottomRow/ShopButton").pressed.connect(_on_shop_pressed)

	# 上部バー右アイコンの接続
	_daily_quest_button.pressed.connect(_on_daily_quest_pressed)
	_announcement_button.pressed.connect(_on_announcement_pressed)
	_mail_button.pressed.connect(_on_mail_pressed)
	_settings_icon_button.pressed.connect(_on_settings_pressed)
	_stamina_plus_button.pressed.connect(_on_stamina_plus_pressed)
	_gold_plus_button.pressed.connect(_on_gold_plus_pressed)
	_stone_plus_button.pressed.connect(_on_stone_plus_pressed)

	# 左パネルのクリック検出
	_left_panel.gui_input.connect(_on_left_panel_input)

	# ユーザー情報を表示
	_update_user_info()

	# スタミナ表示の定期更新（1秒ごと）
	var timer = Timer.new()
	timer.name = "StaminaTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_stamina_display)
	add_child(timer)

	# ログインボーナスチェック
	_check_login_bonus()

	# デバッグ用：リセットボタン（後で削除）
	if _reset_gold_button:
		_reset_gold_button.pressed.connect(_on_reset_gold)
	if _reset_stamina_button:
		_reset_stamina_button.pressed.connect(_on_reset_stamina)
	if _reset_stone_button:
		_reset_stone_button.visible = DebugSettings.show_premium_stone
		_reset_stone_button.pressed.connect(_on_reset_stone)


## ログインボーナスをチェックして表示
func _check_login_bonus():
	var rewards = GameData.check_login_bonus()
	if rewards.is_empty():
		return

	# 報酬があれば表示を更新してダイアログ表示
	_update_user_info()

	var dialog = AcceptDialog.new()
	dialog.title = "ログインボーナス"
	dialog.ok_button_text = "OK"
	dialog.exclusive = true

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	for reward in rewards:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 52)

		var text = reward.get("label", "ボーナス") + "\n"
		var gold = int(reward.get("gold", 0))
		var stone = int(reward.get("stone", 0))
		if gold > 0:
			text += "  💰 %d ゴールド" % gold
		if stone > 0 and DebugSettings.show_premium_stone:
			if gold > 0:
				text += "\n"
			text += "  💎 %d 課金石" % stone

		label.text = text
		vbox.add_child(label)

		# キャンペーンとデイリーの間にセパレーター
		if reward != rewards.back():
			var sep = HSeparator.new()
			vbox.add_child(sep)

	dialog.add_child(vbox)

	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(500, 120)
	ok_btn.add_theme_font_size_override("font_size", 56)

	add_child(dialog)
	dialog.popup_centered()


## 上部バーのスタイル設定
func _setup_top_bar_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)  # 黒とグレーの中間、少し透過
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	_top_bar.add_theme_stylebox_override("panel", style)


func _update_user_info():
	# 左パネル
	if _player_name_label:
		_player_name_label.text = GameData.player_data.profile.name
	if _character_rect:
		var texture = load("res://assets/images/characters/marion.png")
		if texture:
			_character_rect.texture = texture

	# 上部バー
	if _gold_label:
		_gold_label.text = str(GameData.player_data.profile.gold)
	if _stone_icon:
		_stone_icon.visible = DebugSettings.show_premium_stone
	if _stone_label:
		_stone_label.visible = DebugSettings.show_premium_stone
		_stone_label.text = str(GameData.get_stone())
	if _stone_plus_button:
		_stone_plus_button.visible = DebugSettings.show_premium_stone
	_update_stamina_display()


## スタミナ表示を更新
func _update_stamina_display():
	if not _stamina_label:
		return
	var current = GameData.get_stamina()
	var max_val = GameData.get_stamina_max()
	_stamina_label.text = "%d/%d" % [current, max_val]

# デバッグ用：ゴールドを100000にリセット（後で削除）
func _on_reset_gold():
	GameData.player_data.profile.gold = 100000
	GameData.save_to_file()
	_update_user_info()
	print("[DEBUG] ゴールドを100000にリセットしました")


# デバッグ用：スタミナを50にリセット（後で削除）
func _on_reset_stamina():
	GameData.player_data.stamina.current = 50
	GameData.player_data.stamina.updated_at = GameClock.get_now()
	GameData.save_to_file()
	_update_stamina_display()
	print("[DEBUG] スタミナを50にリセットしました")


# デバッグ用：課金石を100000にリセット（後で削除）
func _on_reset_stone():
	GameData.player_data.profile.stone = 100000
	GameData.save_to_file()
	_update_user_info()
	print("[DEBUG] 課金石を100000にリセットしました")


# ========== デッキ検証 ==========
## 全デッキに所持していないカードが含まれていないかチェック
func _check_deck_validity() -> Dictionary:
	var invalid_cards: Array[Dictionary] = []

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

	var label = Label.new()
	label.add_theme_font_size_override("font_size", 36)

	var message = "所持していないカードがデッキに含まれています。\nアルバムでデッキを修正してください。\n\n"
	for info in invalid_cards:
		message += "・%s: %s\n" % [info.deck_name, info.card_name]

	label.text = message
	dialog.add_child(label)

	var ok_button = dialog.get_ok_button()
	ok_button.custom_minimum_size = Vector2(240, 60)
	ok_button.add_theme_font_size_override("font_size", 32)

	add_child(dialog)
	dialog.popup_centered()


# ========== メインボタン処理 ==========
func _on_quest_pressed():
	var check = _check_deck_validity()
	if not check.valid:
		_show_invalid_deck_warning(check.invalid_cards)
		return
	get_tree().call_deferred("change_scene_to_file", "res://scenes/WorldStageSelect.tscn")


func _on_solo_battle_pressed():
	var check = _check_deck_validity()
	if not check.valid:
		_show_invalid_deck_warning(check.invalid_cards)
		return
	get_tree().call_deferred("change_scene_to_file", "res://scenes/SoloBattleSetup.tscn")


func _on_net_battle_pressed():
	var check = _check_deck_validity()
	if not check.valid:
		_show_invalid_deck_warning(check.invalid_cards)
		return
	get_tree().call_deferred("change_scene_to_file", "res://scenes/NetBattleLobby.tscn")


func _on_tournament_pressed():
	var check = _check_deck_validity()
	if not check.valid:
		_show_invalid_deck_warning(check.invalid_cards)
		return
	print("大会（未実装）")


func _on_storage_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Storage.tscn")


func _on_facility_pressed():
	print("施設（未実装）")


func _on_album_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Album.tscn")


func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")


func _on_shop_pressed():
	get_tree().change_scene_to_file("res://scenes/Shop.tscn")


# ========== 上部バーアイコン処理 ==========
func _on_daily_quest_pressed():
	print("デイリークエスト（未実装）")


func _on_announcement_pressed():
	print("お知らせ（未実装）")


func _on_mail_pressed():
	print("メール（未実装）")


func _on_stamina_plus_pressed():
	var count = GameData.get_inventory_item_count(2)  # スタミナ回復薬（大）
	if count <= 0:
		_show_no_stamina_item_dialog()
	else:
		_show_use_stamina_item_dialog(count)


func _show_no_stamina_item_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "スタミナ回復"
	dialog.ok_button_text = "OK"
	dialog.exclusive = true
	var label = Label.new()
	label.text = "スタミナ回復薬を所持していません"
	label.add_theme_font_size_override("font_size", 72)
	dialog.add_child(label)
	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(500, 120)
	ok_btn.add_theme_font_size_override("font_size", 56)
	add_child(dialog)
	dialog.popup_centered()


func _show_use_stamina_item_dialog(count: int):
	var dialog = ConfirmationDialog.new()
	dialog.title = "スタミナ回復"
	dialog.ok_button_text = "使う"
	dialog.cancel_button_text = "キャンセル"
	dialog.exclusive = true
	var label = Label.new()
	label.text = "スタミナ回復薬（大）を使いますか？\n所持数: %d" % count
	label.add_theme_font_size_override("font_size", 72)
	dialog.add_child(label)
	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(500, 120)
	ok_btn.add_theme_font_size_override("font_size", 56)
	var cancel_btn = dialog.get_cancel_button()
	cancel_btn.custom_minimum_size = Vector2(500, 120)
	cancel_btn.add_theme_font_size_override("font_size", 56)
	dialog.confirmed.connect(_on_stamina_recover_confirmed)
	add_child(dialog)
	dialog.popup_centered()


func _on_stamina_recover_confirmed():
	if GameData.use_inventory_item(2):
		_update_stamina_display()
		_update_user_info()


func _on_gold_plus_pressed():
	print("ゴールド購入（未実装）")


func _on_stone_plus_pressed():
	print("課金石購入（未実装）")


func _on_left_panel_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("ステータス画面へ（未実装）")
