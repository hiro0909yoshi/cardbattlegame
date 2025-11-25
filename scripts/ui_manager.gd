extends Node
class_name UIManager

# UI要素の統括管理システム（3D対応版）

signal dice_button_pressed()
signal pass_button_pressed()
signal card_selected(card_index: int)
signal level_up_selected(target_level: int, cost: int)
signal land_command_button_pressed()  # Phase 1-A: 領地コマンドボタン

# UIコンポーネント（分割されたサブシステム）
var land_command_ui: LandCommandUI = null
var hand_display: HandDisplay = null
var phase_display: PhaseDisplay = null

# UIコンポーネント（動的ロード用）
var player_info_panel = null
var player_status_dialog = null
var card_selection_ui = null
var level_up_ui = null
var debug_panel = null

# 基本UI要素
# フェーズ表示とサイコロUI（PhaseDisplayに移行済み）
var dice_button: Button:
	get: return phase_display.dice_button if phase_display else null
var phase_label: Label:
	get: return phase_display.phase_label if phase_display else null

# Phase 1-A: 領地コマンドUI（LandCommandUIに委譲）
# 以下の変数は削除予定（LandCommandUIに移行済み）

# システム参照（型指定なし - 3D対応のため）
var card_system_ref = null
var player_system_ref = null
var board_system_ref = null  # BoardSystem3Dも格納可能
var game_flow_manager_ref = null  # GameFlowManagerの参照

# デバッグモード
var debug_mode = false

# スペルフェーズ用のフィルター設定
var card_selection_filter: String = ""  # "spell"の時はスペルカードのみ選択可能、"item"の時はアイテムのみ、"item_or_assist"の時はアイテム+援護対象クリーチャー
var assist_target_elements: Array = []  # 援護対象の属性リスト

# 手札UI管理（HandDisplayに移行済み）
# 以下の変数は削除予定

func _ready():
	# UIコンポーネントを動的にロードして作成
	var PlayerInfoPanelClass = load("res://scripts/ui_components/player_info_panel.gd")
	var CardSelectionUIClass = load("res://scripts/ui_components/card_selection_ui.gd")
	var LevelUpUIClass = load("res://scripts/ui_components/level_up_ui.gd")
	var DebugPanelClass = load("res://scripts/ui_components/debug_panel.gd")
	var LandCommandUIClass = load("res://scripts/ui_components/land_command_ui.gd")
	var HandDisplayClass = load("res://scripts/ui_components/hand_display.gd")
	var PhaseDisplayClass = load("res://scripts/ui_components/phase_display.gd")
	
	if PlayerInfoPanelClass:
		player_info_panel = PlayerInfoPanelClass.new()
		add_child(player_info_panel)
	
	if CardSelectionUIClass:
		card_selection_ui = CardSelectionUIClass.new()
		add_child(card_selection_ui)
	
	if LevelUpUIClass:
		level_up_ui = LevelUpUIClass.new()
		add_child(level_up_ui)
	
	if DebugPanelClass:
		debug_panel = DebugPanelClass.new()
		add_child(debug_panel)
	
	# LandCommandUI初期化
	if LandCommandUIClass:
		land_command_ui = LandCommandUIClass.new()
		land_command_ui.name = "LandCommandUI"
		add_child(land_command_ui)
		# シグナル接続
		land_command_ui.land_command_button_pressed.connect(_on_land_command_button_pressed)
		land_command_ui.level_up_selected.connect(_on_level_ui_selected)
	
	# HandDisplay初期化
	if HandDisplayClass:
		hand_display = HandDisplayClass.new()
		hand_display.name = "HandDisplay"
		add_child(hand_display)
	
	# PhaseDisplay初期化
	if PhaseDisplayClass:
		phase_display = PhaseDisplayClass.new()
		phase_display.name = "PhaseDisplay"
		add_child(phase_display)
	
	# PlayerStatusDialog初期化
	var PlayerStatusDialogClass = load("res://scripts/ui_components/player_status_dialog.gd")
	if PlayerStatusDialogClass:
		player_status_dialog = PlayerStatusDialogClass.new()
		player_status_dialog.name = "PlayerStatusDialog"
		add_child(player_status_dialog)
	
	# シグナル接続
	connect_ui_signals()

# UIコンポーネントのシグナルを接続
func connect_ui_signals():
	# カード選択UI
	if card_selection_ui:
		card_selection_ui.card_selected.connect(_on_card_ui_selected)
		card_selection_ui.selection_cancelled.connect(_on_selection_cancelled)
	
	# レベルアップUI
	if level_up_ui:
		level_up_ui.level_selected.connect(_on_level_ui_selected)
		level_up_ui.selection_cancelled.connect(_on_level_up_cancelled)
	
	# デバッグパネル
	if debug_panel:
		debug_panel.debug_mode_changed.connect(_on_debug_mode_changed)
	
	# PhaseDisplay
	if phase_display:
		phase_display.dice_button_pressed.connect(_on_dice_button_pressed)
	
	# PlayerInfoPanel
	if player_info_panel:
		player_info_panel.player_panel_clicked.connect(_on_player_panel_clicked)

# UIを作成
func create_ui(parent: Node):
	# システム参照を取得（既に設定されている場合はスキップ）
	if not card_system_ref and parent.has_node("CardSystem"):
		card_system_ref = parent.get_node("CardSystem")
	if not player_system_ref and parent.has_node("PlayerSystem"):
		player_system_ref = parent.get_node("PlayerSystem")
	# board_system_ref は BoardSystem3D から設定される
	
	# UIレイヤー（CanvasLayer）を作成
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	parent.add_child(ui_layer)
	
	# 基本UI要素を作成（UIレイヤーの子として）
	create_basic_ui(ui_layer)
	
	# 各コンポーネントを初期化（3D版対応）
	if player_info_panel and player_info_panel.has_method("initialize"):
		# 3D版の場合、board_systemは渡さずに初期化
		player_info_panel.initialize(ui_layer, player_system_ref, null)
		# 3D版のboard_systemを手動で設定（プロパティとして直接設定）
		player_info_panel.set("board_system_ref", board_system_ref)
		# 初期化後にパネルの状態を確認
		if player_info_panel.has_method("update_all_panels"):
			player_info_panel.update_all_panels()
			
	if card_selection_ui and card_selection_ui.has_method("initialize"):
		card_selection_ui.initialize(ui_layer, card_system_ref, phase_label, self)
		# GameFlowManager参照を設定
		card_selection_ui.game_flow_manager_ref = game_flow_manager_ref
		
	if level_up_ui and level_up_ui.has_method("initialize"):
		level_up_ui.initialize(ui_layer, null, phase_label)  # board_systemはnullで初期化
		level_up_ui.set("board_system_ref", board_system_ref)  # set()で設定
		
	if debug_panel and debug_panel.has_method("initialize"):
		debug_panel.initialize(ui_layer, card_system_ref, null, player_system_ref, game_flow_manager_ref)  # board_systemはnullで初期化
		debug_panel.set("board_system_ref", board_system_ref)  # set()で設定で設定
	
	if player_status_dialog and player_status_dialog.has_method("initialize"):
		player_status_dialog.initialize(ui_layer, player_system_ref, board_system_ref, player_info_panel)

# 基本UI要素を作成（PhaseDisplayに委譲）
func create_basic_ui(parent: Node):
	# PhaseDisplayを初期化
	if phase_display:
		phase_display.initialize(parent)
	
	# Phase 1-A: 領地コマンドUI初期化（LandCommandUIに委譲）
	if land_command_ui:
		land_command_ui.initialize(parent, player_system_ref, board_system_ref, self)
		land_command_ui.create_land_command_button(parent)
		land_command_ui.create_cancel_land_command_button(parent)
		land_command_ui.create_action_menu_panel(parent)
		land_command_ui.create_level_selection_panel(parent)

# === プレイヤー情報パネル関連 ===
func update_player_info_panels():
	if player_info_panel and player_info_panel.has_method("update_all_panels"):
		player_info_panel.update_all_panels()

# === カード選択UI関連 ===
func show_card_selection_ui(current_player):
	if card_selection_ui and card_selection_ui.has_method("show_selection"):
		card_selection_ui.show_selection(current_player, "summon")

# モード指定でカード選択UIを表示
func show_card_selection_ui_mode(current_player, mode: String):
	if card_selection_ui and card_selection_ui.has_method("show_selection"):
		card_selection_ui.show_selection(current_player, mode)

func hide_card_selection_ui():
	if card_selection_ui and card_selection_ui.has_method("hide_selection"):
		card_selection_ui.hide_selection()

# カードボタンが押された（card.gdから呼ばれる）
func _on_card_button_pressed(card_index: int):
	if card_selection_ui and card_selection_ui.has_method("on_card_selected"):
		card_selection_ui.on_card_selected(card_index)

# === レベルアップUI関連 ===
func show_level_up_ui(tile_info: Dictionary, current_magic: int):
	if level_up_ui and level_up_ui.has_method("show_level_up_selection"):
		level_up_ui.show_level_up_selection(tile_info, current_magic)

func hide_level_up_ui():
	if level_up_ui and level_up_ui.has_method("hide_selection"):
		level_up_ui.hide_selection()

# === デバッグパネル関連 ===
func toggle_debug_mode():
	if debug_panel and debug_panel.has_method("toggle_visibility"):
		debug_panel.toggle_visibility()
		if debug_panel.has_method("is_debug_visible"):
			debug_mode = debug_panel.is_debug_visible()

func update_cpu_hand_display(player_id: int):
	if debug_panel and debug_panel.has_method("update_cpu_hand"):
		debug_panel.update_cpu_hand(player_id)

# === 基本UI操作 ===
func update_ui(current_player, current_phase):
	# プレイヤー情報パネルを更新
	update_player_info_panels()
	
	# 現在のターンプレイヤーを設定
	if current_player and player_info_panel and player_info_panel.has_method("set_current_turn"):
		player_info_panel.set_current_turn(current_player.id)
	
	# フェーズ表示を更新
	update_phase_display(current_phase)

# フェーズ表示を更新（PhaseDisplayに委譲）
func update_phase_display(phase):
	if phase_display:
		phase_display.update_phase_display(phase)

# ダイス結果を表示（PhaseDisplayに委譲）
func show_dice_result(value: int, _parent: Node = null):
	if phase_display:
		phase_display.show_dice_result(value)

# サイコロボタンの有効/無効（PhaseDisplayに委譲）
func set_dice_button_enabled(enabled: bool):
	if phase_display:
		phase_display.set_dice_button_enabled(enabled)

# === イベントハンドラ ===
func _on_dice_button_pressed():
	emit_signal("dice_button_pressed")

func _on_pass_button_pressed():
	emit_signal("pass_button_pressed")

func _on_card_ui_selected(card_index: int):
	emit_signal("card_selected", card_index)

func _on_selection_cancelled():
	emit_signal("pass_button_pressed")

func _on_level_ui_selected(target_level: int, cost: int):
	emit_signal("level_up_selected", target_level, cost)

func _on_level_up_cancelled():
	emit_signal("level_up_selected", 0, 0)

func _on_debug_mode_changed(enabled: bool):
	debug_mode = enabled

func _on_land_command_button_pressed():
	emit_signal("land_command_button_pressed")

func _on_cancel_land_command_button_pressed():
	print("[UIManager] キャンセルボタンがクリックされました！")
	# GameFlowManagerのland_command_handlerに通知
	if game_flow_manager_ref and game_flow_manager_ref.land_command_handler:
		game_flow_manager_ref.land_command_handler.cancel()

# === 手札UI管理 ===

# 手札コンテナを初期化（HandDisplayに委譲）
func initialize_hand_container(ui_layer: Node):
	if hand_display:
		hand_display.initialize(ui_layer, card_system_ref, player_system_ref)

# CardSystemのシグナルに接続（HandDisplayに委譲）
func connect_card_system_signals():
	if hand_display:
		hand_display.connect_card_system_signals()

# カード関連のシグナルハンドラ（HandDisplayに移行済み）

# 手札表示を更新（HandDisplayに委譲）
func update_hand_display(player_id: int):
	if hand_display:
		hand_display.update_hand_display(player_id)

# create_card_node は HandDisplayに移行済みのため削除

# rearrange_hand は HandDisplayに移行済みのため削除

# デバッグ入力を処理
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			toggle_debug_mode()

# ============================================
# Phase 1-A: 領地コマンドUI
# ============================================

# land_command_button と cancel_land_command_button は
# LandCommandUIに移行済みのため削除

# 領地コマンドボタンを作成（create_basic_ui内から呼ばれる想定）
# create_land_command_button と create_cancel_land_command_button は
# LandCommandUIに移行済みのため削除

# 領地コマンドボタンの表示/非表示（LandCommandUIに委譲）
func show_land_command_button():
	if land_command_ui:
		land_command_ui.show_land_command_button()

func hide_land_command_button():
	if land_command_ui:
		land_command_ui.hide_land_command_button()

# create_action_menu_panel は LandCommandUIに移行済みのため削除

# _create_menu_button は LandCommandUIに移行済みのため削除

# create_level_selection_panel と _create_level_button は LandCommandUIに移行済みのため削除

# キャンセルボタンの表示/非表示
func show_cancel_button():
	if land_command_ui:
		land_command_ui.show_cancel_button()

func hide_cancel_button():
	if land_command_ui:
		land_command_ui.hide_cancel_button()

# スペルカードフィルターを設定（スペルフェーズ用）
func set_card_selection_filter(filter_type: String):
	card_selection_filter = filter_type
	# 既に表示されている手札を更新
	if hand_display:
		var current_player = player_system_ref.get_current_player() if player_system_ref else null
		if current_player:
			hand_display.update_hand_display(current_player.id)

# フィルターをクリア
func clear_card_selection_filter():
	card_selection_filter = ""

# 土地選択モードを表示
func show_land_selection_mode(_owned_lands: Array):
	if phase_label:
		var land_list = ""
		for i in range(_owned_lands.size()):
			land_list += str(i + 1) + ":" + str(_owned_lands[i]) + " "
		phase_label.text = "土地を選択（数字キー） " + land_list
	
	# キャンセルボタンを表示
	show_cancel_button()

# アクション選択UIを表示
func show_action_selection_ui(tile_index: int):
	print("[UIManager] アクション選択UI表示: tile ", tile_index)
	# Phase 1-A: 新しいUIパネルを使用
	show_action_menu(tile_index)

# 領地コマンドUIを非表示
func hide_land_command_ui():
	# Phase 1-A: 新UIパネルを非表示
	hide_action_menu()
	hide_level_selection()
	
	# CardSelectionUIも非表示にする
	if card_selection_ui and card_selection_ui.has_method("hide_selection"):
		card_selection_ui.hide_selection()
	
	# キャンセルボタンを非表示
	hide_cancel_button()

# ==== Phase 1-A: アクションメニュー表示/非表示（LandCommandUIに委譲） ====

func show_action_menu(tile_index: int):
	if land_command_ui:
		land_command_ui.show_action_menu(tile_index)

func hide_action_menu():
	if land_command_ui:
		land_command_ui.hide_action_menu()

# ==== Phase 1-A: レベル選択パネル表示/非表示（LandCommandUIに委譲） ====

func show_level_selection(tile_index: int, current_level: int, player_magic: int):
	if land_command_ui:
		land_command_ui.show_level_selection(tile_index, current_level, player_magic)

func hide_level_selection():
	if land_command_ui:
		land_command_ui.hide_level_selection()

# ==== Phase 1-A: イベントハンドラ ====

# イベントハンドラはLandCommandUIに移行済み

# === 手札UI関連（HandDisplayへのアクセサ） ===
func get_player_card_nodes(player_id: int) -> Array:
	if hand_display:
		return hand_display.get_player_card_nodes(player_id)
	return []

# === プレイヤーパネル関連 ===

# プレイヤー情報パネルがクリックされたときのハンドラ
func _on_player_panel_clicked(player_id: int):
	if player_status_dialog and player_status_dialog.has_method("show_for_player"):
		player_status_dialog.show_for_player(player_id)
