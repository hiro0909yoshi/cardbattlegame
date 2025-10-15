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

# UIコンポーネント（動的ロード用）
var player_info_panel = null
var card_selection_ui = null
var level_up_ui = null
var debug_panel = null

# 基本UI要素
var dice_button: Button
var phase_label: Label
var current_dice_label: Label = null

# Phase 1-A: 領地コマンドUI（LandCommandUIに委譲）
# 以下の変数は削除予定（LandCommandUIに移行済み）

# システム参照（型指定なし - 3D対応のため）
var card_system_ref = null
var player_system_ref = null
var board_system_ref = null  # BoardSystem3Dも格納可能
var game_flow_manager_ref = null  # GameFlowManagerの参照

# デバッグモード
var debug_mode = false

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
		print("PlayerInfoPanel初期化開始")
		# 3D版の場合、board_systemは渡さずに初期化
		player_info_panel.initialize(ui_layer, player_system_ref, null)
		# 3D版のboard_systemを手動で設定（プロパティとして直接設定）
		player_info_panel.set("board_system_ref", board_system_ref)
		print("PlayerInfoPanel初期化完了")
		# 初期化後にパネルの状態を確認
		if player_info_panel.has_method("update_all_panels"):
			print("update_all_panels呼び出し")
			player_info_panel.update_all_panels()
			
	if card_selection_ui and card_selection_ui.has_method("initialize"):
		card_selection_ui.initialize(ui_layer, card_system_ref, phase_label, self)
		# GameFlowManager参照を設定
		card_selection_ui.game_flow_manager_ref = game_flow_manager_ref
		
	if level_up_ui and level_up_ui.has_method("initialize"):
		level_up_ui.initialize(ui_layer, null, phase_label)  # board_systemはnullで初期化
		level_up_ui.set("board_system_ref", board_system_ref)  # set()で設定
		
	if debug_panel and debug_panel.has_method("initialize"):
		debug_panel.initialize(ui_layer, card_system_ref, null, player_system_ref)  # board_systemはnullで初期化
		debug_panel.set("board_system_ref", board_system_ref)  # set()で設定

# 基本UI要素を作成（サイコロボタン位置修正）
func create_basic_ui(parent: Node):
	# フェーズ表示（画面中央上部、サイコロボタンの上）
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	
	var viewport_size_phase = get_viewport().get_visible_rect().size
	var player_panel_bottom_phase = 20 + 240 + 20  # パネルY + パネル高さ(240) + マージン
	
	# サイコロボタンの少し上に配置
	phase_label.position = Vector2(viewport_size_phase.x / 2 - 150, player_panel_bottom_phase)
	phase_label.add_theme_font_size_override("font_size", 24)
	parent.add_child(phase_label)
	
	# サイコロボタン（プレイヤー情報パネルの下、画面中央）
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	
	var viewport_size = get_viewport().get_visible_rect().size
	var button_width = 200
	var button_height = 60
	var player_panel_bottom = 20 + 240 + 70  # パネルY + パネル高さ(240) + マージン(70)
	
	dice_button.position = Vector2((viewport_size.x - button_width) / 2, player_panel_bottom)
	dice_button.size = Vector2(button_width, button_height)
	dice_button.disabled = true
	dice_button.pressed.connect(_on_dice_button_pressed)
	
	# サイコロボタンのスタイルを設定
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.5, 0.8, 0.9)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(1, 1, 1, 1)
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	dice_button.add_theme_stylebox_override("normal", button_style)
	
	# ホバー時のスタイル
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.6, 0.9, 1.0)
	dice_button.add_theme_stylebox_override("hover", hover_style)
	
	# 押下時のスタイル
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.4, 0.7, 1.0)
	dice_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# 無効時のスタイル
	var disabled_style = button_style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	dice_button.add_theme_stylebox_override("disabled", disabled_style)
	
	# フォントサイズを大きく
	dice_button.add_theme_font_size_override("font_size", 18)
	
	parent.add_child(dice_button)
	
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

# フェーズ表示を更新
func update_phase_display(phase):
	if not phase_label:
		return
		
	match phase:
		0: # SETUP
			phase_label.text = "準備中..."
		1: # DICE_ROLL
			phase_label.text = "サイコロを振ってください"
		2: # MOVING
			phase_label.text = "移動中..."
		3: # TILE_ACTION
			phase_label.text = "アクション選択"
		4: # BATTLE
			phase_label.text = "バトル！"
		5: # END_TURN
			phase_label.text = "ターン終了"

# ダイス結果を表示（位置調整）
func show_dice_result(value: int, parent: Node):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# 新しいダイスラベルを作成（サイコロボタンの近くに表示）
	current_dice_label = Label.new()
	current_dice_label.text = "🎲 " + str(value)
	current_dice_label.add_theme_font_size_override("font_size", 48)
	current_dice_label.position = Vector2(530, 90)  # サイコロボタンの右横
	current_dice_label.add_theme_color_override("font_color", Color(1, 1, 0))
	current_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	
	# UILayerがある場合はそこに追加
	if parent.has_node("UILayer"):
		parent.get_node("UILayer").add_child(current_dice_label)
	else:
		parent.add_child(current_dice_label)
	
	# 2秒後に自動的に消す
	await get_tree().create_timer(2.0).timeout
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
		current_dice_label = null

# サイコロボタンの有効/無効
func set_dice_button_enabled(enabled: bool):
	if not dice_button:
		return
		
	dice_button.disabled = not enabled
	
	# 有効時は目立たせる
	if enabled:
		dice_button.modulate = Color(1, 1, 1, 1)
	else:
		dice_button.modulate = Color(0.7, 0.7, 0.7, 0.8)

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
	print("[UIManager] 領地コマンドボタンがクリックされました！")
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

# 土地選択モードを表示
func show_land_selection_mode(owned_lands: Array):
	print("[UIManager] 土地選択モード表示: ", owned_lands)
	if phase_label:
		var land_list = ""
		for i in range(owned_lands.size()):
			land_list += str(i + 1) + ":" + str(owned_lands[i]) + " "
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
	print("[UIManager] 領地コマンドUI非表示")
	# Phase 1-A: 新UIパネルを非表示
	hide_action_menu()
	hide_level_selection()
	
	if phase_label:
		phase_label.text = "召喚フェーズ"
	
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
