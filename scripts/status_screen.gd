extends Control

# 左パネル
@onready var _character_preview: SubViewportContainer = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/CharacterPreview
@onready var _player_name_label: Label = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/PlayerNameLabel
@onready var _level_label: Label = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/LevelLabel
@onready var _title_label: Label = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/TitleLabel
@onready var _character_change_button: Button = $MainVBox/ContentArea/LeftPanel/LeftMargin/LeftVBox/CharacterChangeButton

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
	_character_change_button.pressed.connect(_on_character_change_pressed)
	_account_button.pressed.connect(_on_account_pressed)


func _update_display():
	var profile = GameData.player_data.profile
	var stats = GameData.player_data.stats
	var login = GameData.player_data.login_bonus

	# 左パネル
	_player_name_label.text = profile.name
	_level_label.text = "Lv. %d  (EXP: %d)" % [profile.level, profile.exp]
	_title_label.text = "はじまりの一歩"

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
		var is_unlocked = GameData.is_character_unlocked(char_id)
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
			btn.text = "%s\n🔒" % char_data.name
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


func _on_account_pressed():
	print("アカウント連携（未実装）")
