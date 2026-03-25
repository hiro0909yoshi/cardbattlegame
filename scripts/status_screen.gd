extends Control

# 左パネル
@onready var _character_preview: SubViewportContainer = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/CharacterPreview
@onready var _player_name_label: Label = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/PlayerNameLabel
@onready var _level_label: Label = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/LevelLabel
@onready var _title_label: Label = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/TitleLabel
@onready var _title_change_button: Button = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/TitleChangeButton
@onready var _character_change_button: Button = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/CharacterChangeButton
@onready var _name_change_button: Button = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/NameChangeButton

# 右パネル - 基本情報
@onready var _gold_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/ProfileSection/GoldRow/GoldValue
@onready var _stone_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/ProfileSection/StoneRow/StoneValue
@onready var _stamina_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/ProfileSection/StaminaRow/StaminaValue

# 右パネル - 戦績
@onready var _battle_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/StatsSection/BattleRow/BattleValue
@onready var _win_loss_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/StatsSection/WinLossRow/WinLossValue
@onready var _win_rate_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/StatsSection/WinRateRow/WinRateValue
@onready var _story_clear_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/StatsSection/StoryClearRow/StoryClearValue

# 右パネル - 所持情報
@onready var _card_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/CollectionSection/CardRow/CardValue
@onready var _deck_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/CollectionSection/DeckRow/DeckValue
@onready var _map_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/CollectionSection/MapRow/MapValue

# 右パネル - ログイン
@onready var _streak_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/LoginSection/StreakRow/StreakValue
@onready var _total_login_value: Label = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/LoginSection/TotalLoginRow/TotalLoginValue

# 右パネル - 設定ボタン
@onready var _account_button: Button = $MainVBox/ContentArea/RightPanel/RightMargin/MenuVBox/SettingsSection/AccountButton

# トップバー
@onready var _back_button: Button = $MainVBox/TopBar/TopBarMargin/TopBarHBox/BackButton


func _ready():
	_setup_top_bar_style()
	_setup_left_panel_style()
	_update_display()
	_connect_buttons()


func _connect_buttons():
	_back_button.pressed.connect(_on_back_pressed)
	_title_change_button.pressed.connect(_on_title_change_pressed)
	_character_change_button.pressed.connect(_on_character_change_pressed)
	_name_change_button.pressed.connect(_on_name_change_pressed)
	_account_button.pressed.connect(_on_account_pressed)
	_update_name_change_button()


func _update_display():
	var profile = GameData.player_data.profile
	var stats = GameData.player_data.stats
	var login = GameData.player_data.login_bonus

	# 左パネル
	_player_name_label.text = profile.name
	_level_label.text = "Lv. %d  (EXP: %d)" % [profile.level, profile.exp]
	_title_label.text = GameData.get_equipped_title()

	if _character_preview:
		_character_preview.set_selected_character()

	# 基本情報
	_gold_value.text = "%d" % int(profile.gold)
	_stone_value.text = "%d" % int(GameData.get_stone())
	_stamina_value.text = "%d / %d" % [GameData.get_stamina(), GameData.get_stamina_max()]

	# 戦績
	_battle_value.text = "%d" % int(stats.total_battles)
	_win_loss_value.text = "%d / %d" % [int(stats.wins), int(stats.losses)]
	var win_rate = 0.0
	if int(stats.total_battles) > 0:
		win_rate = float(stats.wins) / float(stats.total_battles) * 100.0
	_win_rate_value.text = "%.1f%%" % win_rate
	_story_clear_value.text = "%d" % int(stats.story_cleared)

	# 所持情報
	var owned_cards = UserCardDB.get_all_obtained_cards()
	_card_value.text = "%d 種" % owned_cards.size()
	var deck_count = GameData.player_data.decks.size()
	var max_decks = GameData.player_data.get("max_decks", 6)
	_deck_value.text = "%d / %d" % [deck_count, max_decks]

	# マップ
	var unlocked_maps = UnlockManager.get_unlocked_by_prefix("map.")
	_map_value.text = "%d 種" % unlocked_maps.size()

	# ログイン
	_streak_value.text = "%d 日" % login.login_streak
	_total_login_value.text = "%d 日" % login.total_login_days

	# 課金石の表示制御
	var stone_row = _stone_value.get_parent()
	if stone_row:
		stone_row.visible = DebugSettings.show_premium_stone


func _setup_top_bar_style():
	var top_bar: PanelContainer = $MainVBox/TopBar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	top_bar.add_theme_stylebox_override("panel", style)


func _setup_left_panel_style():
	var left_panel: PanelContainer = $MainVBox/ContentArea/LeftPanel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 1.0)
	left_panel.add_theme_stylebox_override("panel", style)


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_title_change_pressed():
	var dialog = AcceptDialog.new()
	dialog.title = "称号変更"
	dialog.ok_button_text = "閉じる"

	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(400, 80)
	ok_btn.add_theme_font_size_override("font_size", 36)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var current_title = GameData.get_equipped_title()
	var available_titles = GameData.get_available_titles()

	for title_data in available_titles:
		var is_equipped = title_data.name == current_title
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 28)

		if is_equipped:
			btn.text = "%s\n[装備中]" % title_data.name
			btn.disabled = true
		else:
			btn.text = "%s\n%s" % [title_data.name, title_data.description]
			btn.pressed.connect(_on_title_selected.bind(title_data.name, dialog))

		vbox.add_child(btn)

	# 未解放の称号も表示（ロック状態）
	for title_data in GameData.TITLES:
		if not GameData._is_title_unlocked(title_data):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(0, 80)
			btn.add_theme_font_size_override("font_size", 28)
			btn.text = "🔒 ???\n%s" % title_data.description
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
			vbox.add_child(btn)

	scroll.add_child(vbox)
	dialog.add_child(scroll)
	add_child(dialog)
	dialog.popup_centered()


func _on_title_selected(title_name: String, dialog: AcceptDialog):
	if GameData.equip_title(title_name):
		_update_display()
		if dialog and is_instance_valid(dialog):
			dialog.queue_free()
		print("[StatusScreen] 称号変更: %s" % title_name)


func _on_character_change_pressed():
	var dialog = AcceptDialog.new()
	dialog.title = "キャラクター変更"
	dialog.ok_button_text = "閉じる"
	dialog.exclusive = true

	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(400, 100)
	ok_btn.add_theme_font_size_override("font_size", 48)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 500)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)

	var current_id = GameData.player_data.character.selected_id

	for char_id in GameData.PLAYABLE_CHARACTERS:
		var char_data = GameData.PLAYABLE_CHARACTERS[char_id]
		var is_unlocked = UnlockManager.is_unlocked("character." + char_id)
		var is_selected = char_id == current_id

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(240, 100)
		btn.add_theme_font_size_override("font_size", 32)

		if is_selected:
			btn.text = "%s\n[装備中]" % char_data.name
			btn.disabled = true
		elif is_unlocked:
			btn.text = char_data.name
			btn.pressed.connect(_on_character_selected.bind(char_id, dialog))
		else:
			var condition = UnlockManager.get_condition_for_key("character." + char_id)
			var lock_text = condition.get("lock_description", "???") if condition else "???"
			btn.text = "%s\n🔒 %s" % [char_data.name, lock_text]
			btn.disabled = true

		grid.add_child(btn)

	scroll.add_child(grid)
	dialog.add_child(scroll)
	add_child(dialog)
	dialog.popup_centered()


func _on_character_selected(char_id: String, dialog: AcceptDialog):
	if GameData.select_character(char_id):
		_update_display()
		if dialog and is_instance_valid(dialog):
			dialog.queue_free()
		print("[StatusScreen] キャラクター変更: %s" % char_id)


## 将来追加予定:
## - 称号変更ボタン（TitleChangeButton）
## - ブック選択ボタン（DeckSelectButton）


func _update_name_change_button():
	var ticket_count = GameData.player_data.inventory.get("name_change_ticket", 0)
	if ticket_count > 0:
		_name_change_button.text = "名前変更（残り%d回）" % ticket_count
		_name_change_button.disabled = false
	else:
		_name_change_button.text = "名前変更（チケットなし）"
		_name_change_button.disabled = true


func _on_name_change_pressed():
	var ticket_count = GameData.player_data.inventory.get("name_change_ticket", 0)
	if ticket_count <= 0:
		return

	var dialog = AcceptDialog.new()
	dialog.title = "名前変更"
	dialog.ok_button_text = "変更する"

	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(300, 80)
	ok_btn.add_theme_font_size_override("font_size", 36)
	ok_btn.disabled = true

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	var info_label = Label.new()
	info_label.text = "新しいプレイヤー名を入力してください\n（名前変更チケットを1枚消費します）"
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	var line_edit = LineEdit.new()
	line_edit.custom_minimum_size = Vector2(500, 60)
	line_edit.add_theme_font_size_override("font_size", 36)
	line_edit.placeholder_text = GameData.player_data.profile.name
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.max_length = 20
	line_edit.text_changed.connect(func(text: String):
		var trimmed = text.strip_edges()
		ok_btn.disabled = trimmed.is_empty() or trimmed == GameData.player_data.profile.name
	)
	vbox.add_child(line_edit)

	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		var new_name = line_edit.text.strip_edges()
		if new_name.is_empty() or new_name == GameData.player_data.profile.name:
			return
		GameData.player_data.profile.name = new_name
		GameData.player_data.inventory["name_change_ticket"] = ticket_count - 1
		GameData.save_to_file()
		_update_display()
		_update_name_change_button()
		print("[StatusScreen] 名前変更: %s" % new_name)
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 300))


func _on_account_pressed():
	print("アカウント連携（未実装）")
