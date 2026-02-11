extends RefCounted
class_name UIGameMenuHandler

# ゲームメニュー管理
# UIManagerから委譲される

var ui_manager: UIManager = null

var game_menu_button: GameMenuButton = null
var game_menu: GameMenu = null
var surrender_dialog: SurrenderDialog = null


func _init(p_ui_manager: UIManager) -> void:
	ui_manager = p_ui_manager


## ゲームメニューをセットアップ
func setup_game_menu():
	if not ui_manager.ui_layer:
		print("[UIGameMenu] ui_layerがないためゲームメニュー初期化スキップ")
		return

	# メニューボタン
	game_menu_button = GameMenuButton.new()
	game_menu_button.name = "GameMenuButton"
	game_menu_button.menu_pressed.connect(_on_game_menu_button_pressed)
	ui_manager.ui_layer.add_child(game_menu_button)

	# メニュー
	game_menu = GameMenu.new()
	game_menu.name = "GameMenu"
	game_menu.settings_selected.connect(_on_settings_selected)
	game_menu.help_selected.connect(_on_help_selected)
	game_menu.surrender_selected.connect(_on_surrender_selected)
	ui_manager.ui_layer.add_child(game_menu)

	# 降参確認ダイアログ
	surrender_dialog = SurrenderDialog.new()
	surrender_dialog.name = "SurrenderDialog"
	surrender_dialog.surrendered.connect(_on_surrender_confirmed)
	ui_manager.ui_layer.add_child(surrender_dialog)

	print("[UIGameMenu] ゲームメニュー初期化完了")


## メニューボタン押下
func _on_game_menu_button_pressed():
	if game_menu:
		game_menu.show_menu()


## 設定選択
func _on_settings_selected():
	print("[UIGameMenu] 設定選択（未実装）")


## ヘルプ選択
func _on_help_selected():
	print("[UIGameMenu] ヘルプ選択（未実装）")


## 降参選択
func _on_surrender_selected():
	if surrender_dialog:
		surrender_dialog.show_dialog()


## 降参確認
func _on_surrender_confirmed():
	print("[UIGameMenu] 降参確認")
	if ui_manager.game_flow_manager_ref:
		ui_manager.game_flow_manager_ref.on_player_defeated("surrender")
