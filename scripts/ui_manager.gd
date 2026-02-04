extends Node
class_name UIManager

# UI要素の統括管理システム（3D対応版）

signal pass_button_pressed()
signal card_selected(card_index: int)
signal level_up_selected(target_level: int, cost: int)
signal dominio_order_button_pressed()  # Phase 1-A: ドミニオコマンドボタン

# UIコンポーネント（分割されたサブシステム）
var dominio_order_ui: DominioOrderUI = null
var hand_display: HandDisplay = null
var phase_display: PhaseDisplay = null
var global_action_buttons: GlobalActionButtons = null

# UIコンポーネント（動的ロード用）
var player_info_panel = null
var player_status_dialog = null
var card_selection_ui = null
var level_up_ui = null
var debug_panel = null
var creature_info_panel_ui: CreatureInfoPanelUI = null
var spell_info_panel_ui: SpellInfoPanelUI = null
var item_info_panel_ui: ItemInfoPanelUI = null
var global_comment_ui: GlobalCommentUI = null
var tap_target_manager: TapTargetManager = null

# 基本UI要素
# フェーズ表示（PhaseDisplayに移行済み）
var phase_label: Label:
	get: return phase_display.phase_label if phase_display else null

# Phase 1-A: ドミニオコマンドUI（DominioOrderUIに委譲）
# 以下の変数は削除予定（DominioOrderUIに移行済み）

# システム参照（型指定なし - 3D対応のため）
var card_system_ref = null
var player_system_ref = null
var board_system_ref = null  # BoardSystem3Dも格納可能
var game_flow_manager_ref = null  # GameFlowManagerの参照

# デバッグモード
var debug_mode = false

# UIレイヤー参照
var ui_layer: CanvasLayer = null

# スペルフェーズ用のフィルター設定
var card_selection_filter: String = ""  # "spell"の時はスペルカードのみ選択可能、"item"の時はアイテムのみ、"item_or_assist"の時はアイテム+援護対象クリーチャー
var assist_target_elements: Array = []  # 援護対象の属性リスト

# ゲームメニュー関連
var game_menu_button: GameMenuButton = null
var game_menu: GameMenu = null
var surrender_dialog: SurrenderDialog = null
var blocked_item_types: Array = []  # ブロックするアイテムタイプ（例: ["防具"]）
var excluded_card_index: int = -1  # 犠牲選択時に除外するカードインデックス（召喚するカード自身）
var excluded_card_id: String = ""  # 犠牲選択時に除外するカードID（召喚するカード自身）

# 手札UI管理（HandDisplayに移行済み）
# 以下の変数は削除予定

func _ready():
	# UIコンポーネントを動的にロードして作成
	var PlayerInfoPanelClass = load("res://scripts/ui_components/player_info_panel.gd")
	var CardSelectionUIClass = load("res://scripts/ui_components/card_selection_ui.gd")
	var LevelUpUIClass = load("res://scripts/ui_components/level_up_ui.gd")
	var DebugPanelClass = load("res://scripts/ui_components/debug_panel.gd")
	var DominioOrderUIClass = load("res://scripts/ui_components/dominio_order_ui.gd")
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
	
	# CreatureInfoPanelUI初期化（シーンからインスタンス化）
	var creature_info_scene = preload("res://scenes/ui/creature_info_panel.tscn")
	creature_info_panel_ui = creature_info_scene.instantiate()
	creature_info_panel_ui.set_ui_manager(self)
	add_child(creature_info_panel_ui)
	
	# SpellInfoPanelUI初期化（シーンからインスタンス化）
	var spell_info_scene = preload("res://scenes/ui/spell_info_panel.tscn")
	spell_info_panel_ui = spell_info_scene.instantiate()
	spell_info_panel_ui.set_ui_manager(self)
	add_child(spell_info_panel_ui)
	
	# ItemInfoPanelUI初期化（シーンからインスタンス化）
	var item_info_scene = preload("res://scenes/ui/item_info_panel.tscn")
	item_info_panel_ui = item_info_scene.instantiate()
	item_info_panel_ui.set_ui_manager(self)
	add_child(item_info_panel_ui)
	
	# GlobalActionButtons初期化
	global_action_buttons = GlobalActionButtons.new()
	global_action_buttons.name = "GlobalActionButtons"
	add_child(global_action_buttons)
	
	# GlobalCommentUI初期化
	global_comment_ui = GlobalCommentUI.new()
	global_comment_ui.name = "GlobalCommentUI"
	add_child(global_comment_ui)
	
	# DominioOrderUI初期化
	if DominioOrderUIClass:
		dominio_order_ui = DominioOrderUIClass.new()
		dominio_order_ui.name = "DominioOrderUI"
		dominio_order_ui.ui_manager_ref = self  # グローバルボタン用に参照設定
		add_child(dominio_order_ui)
		# シグナル接続（dominio_order_button_pressedは特殊ボタンに移行済み）
		dominio_order_ui.level_up_selected.connect(_on_level_ui_selected)
	
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
	
	# PlayerStatusDialog初期化（シーンからインスタンス化）
	var player_status_scene = preload("res://scenes/ui/player_status_dialog.tscn")
	if player_status_scene:
		player_status_dialog = player_status_scene.instantiate()
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
	
	# PlayerInfoPanel
	if player_info_panel:
		player_info_panel.player_panel_clicked.connect(_on_player_panel_clicked)
	
	# CreatureInfoPanelUI
	if creature_info_panel_ui:
		creature_info_panel_ui.selection_confirmed.connect(_on_creature_info_panel_confirmed)
		# selection_cancelledはcard_selection_ui側で処理（選択UIに戻る）
	
	# GlobalActionButtonsはシグナルなし（直接コールバック呼び出し）

# UIを作成
func create_ui(parent: Node):
	# システム参照を取得（既に設定されている場合はスキップ）
	if not card_system_ref and parent.has_node("CardSystem"):
		card_system_ref = parent.get_node("CardSystem")
	if not player_system_ref and parent.has_node("PlayerSystem"):
		player_system_ref = parent.get_node("PlayerSystem")
	# board_system_ref は BoardSystem3D から設定される
	
	# UIレイヤー（CanvasLayer）を作成
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	parent.add_child(ui_layer)
	
	# 基本UI要素を作成（UIレイヤーの子として）
	create_basic_ui(ui_layer)
	
	# 各コンポーネントを初期化（3D版対応）
	if player_info_panel and player_info_panel.has_method("initialize"):
		# プレイヤー数を取得
		var player_count = player_system_ref.players.size() if player_system_ref else 2
		# 3D版の場合、board_systemは渡さずに初期化
		player_info_panel.initialize(ui_layer, player_system_ref, null, player_count)
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
		level_up_ui.initialize(ui_layer, null, phase_label, self)  # board_systemはnullで初期化
		level_up_ui.set("board_system_ref", board_system_ref)  # set()で設定
		
	if debug_panel and debug_panel.has_method("initialize"):
		debug_panel.initialize(ui_layer, card_system_ref, null, player_system_ref, game_flow_manager_ref)  # board_systemはnullで初期化
		debug_panel.set("board_system_ref", board_system_ref)  # set()で設定で設定
	
	if player_status_dialog and player_status_dialog.has_method("initialize"):
		player_status_dialog.initialize(ui_layer, player_system_ref, board_system_ref, player_info_panel, game_flow_manager_ref, card_system_ref)
	
	# インフォパネル用の専用レイヤーを作成（バトル画面より前面に表示）
	var info_panel_layer = CanvasLayer.new()
	info_panel_layer.name = "InfoPanelLayer"
	info_panel_layer.layer = 85  # バトル準備画面(80)より上、バトル画面(90)より下
	parent.add_child(info_panel_layer)
	
	# CreatureInfoPanelUI初期化
	if creature_info_panel_ui:
		creature_info_panel_ui.set_card_system(card_system_ref)
		# インフォパネルレイヤーに移動
		if creature_info_panel_ui.get_parent():
			creature_info_panel_ui.get_parent().remove_child(creature_info_panel_ui)
		info_panel_layer.add_child(creature_info_panel_ui)
	
	# SpellInfoPanelUIもインフォパネルレイヤーに移動
	if spell_info_panel_ui:
		if spell_info_panel_ui.get_parent():
			spell_info_panel_ui.get_parent().remove_child(spell_info_panel_ui)
		info_panel_layer.add_child(spell_info_panel_ui)
	
	# ItemInfoPanelUIもインフォパネルレイヤーに移動
	if item_info_panel_ui:
		if item_info_panel_ui.get_parent():
			item_info_panel_ui.get_parent().remove_child(item_info_panel_ui)
		info_panel_layer.add_child(item_info_panel_ui)
	
	# TapTargetManager初期化
	tap_target_manager = TapTargetManager.new()
	tap_target_manager.name = "TapTargetManager"
	add_child(tap_target_manager)
	tap_target_manager.setup(board_system_ref, player_system_ref)
	tap_target_manager.target_selected.connect(_on_tap_target_selected)
	tap_target_manager.selection_cancelled.connect(_on_tap_target_cancelled)
	
	# GlobalActionButtonsをUIレイヤーに移動（最前面に表示するため、最後に追加）
	if global_action_buttons:
		if global_action_buttons.get_parent():
			global_action_buttons.get_parent().remove_child(global_action_buttons)
		ui_layer.add_child(global_action_buttons)
		# GameFlowManager参照を設定（入力ロック用）
		global_action_buttons.game_flow_manager_ref = game_flow_manager_ref
	
	# GlobalCommentUI用の専用レイヤーを作成（最前面に表示）
	if global_comment_ui:
		var notification_layer = CanvasLayer.new()
		notification_layer.name = "NotificationLayer"
		notification_layer.layer = 100  # 他のUIより高いレイヤー
		parent.add_child(notification_layer)
		
		if global_comment_ui.get_parent():
			global_comment_ui.get_parent().remove_child(global_comment_ui)
		notification_layer.add_child(global_comment_ui)
		
		# GameFlowManager参照を設定（CPU自動進行用）
		global_comment_ui.game_flow_manager_ref = game_flow_manager_ref
	
	# ゲームメニュー初期化
	_setup_game_menu()

# 基本UI要素を作成（PhaseDisplayに委譲）
func create_basic_ui(parent: Node):
	# PhaseDisplayを初期化
	if phase_display:
		phase_display.initialize(parent)
	
	# Phase 1-A: ドミニオコマンドUI初期化（DominioOrderUIに委譲）
	# 注: ドミニオコマンドボタンはグローバル特殊ボタンに移行済み
	if dominio_order_ui:
		dominio_order_ui.initialize(parent, player_system_ref, board_system_ref, self)
		dominio_order_ui.create_action_menu_panel(parent)
		dominio_order_ui.create_level_selection_panel(parent)

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
	# 入力ロックチェック
	if game_flow_manager_ref and game_flow_manager_ref.is_input_locked():
		return
	
	# 通知ポップアップがクリック待ち中なら無視
	if is_notification_popup_active():
		return
	
	# 犠牲選択中はcard_selection_uiで処理（card_selection_handlerをバイパス）
	if card_selection_ui and card_selection_ui.selection_mode == "sacrifice":
		card_selection_ui.on_card_selected(card_index)
		return
	
	# カード選択ハンドラーが選択中の場合はGameFlowManager経由で処理
	if game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
		var handler = game_flow_manager_ref.spell_phase_handler.card_selection_handler
		if handler and handler.is_selecting():
			game_flow_manager_ref.on_card_selected(card_index)
			return
	
	if card_selection_ui and card_selection_ui.has_method("on_card_selected"):
		card_selection_ui.on_card_selected(card_index)

## 通知ポップアップがアクティブ（クリック待ち中）かどうか
func is_notification_popup_active() -> bool:
	if global_comment_ui and global_comment_ui.waiting_for_click:
		return true
	return false

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

# === イベントハンドラ ===
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

func _on_dominio_order_button_pressed():
	emit_signal("dominio_order_button_pressed")

func _on_creature_info_panel_confirmed(card_data: Dictionary):
	# カードインデックスを取得してcard_selectedシグナルを発火
	var card_index = card_data.get("hand_index", -1)
	if card_index >= 0:
		emit_signal("card_selected", card_index)

func _on_creature_info_panel_cancelled():
	emit_signal("pass_button_pressed")

func _on_cancel_dominio_order_button_pressed():
	print("[UIManager] キャンセルボタンがクリックされました！")
	# GameFlowManagerのdominio_command_handlerに通知
	if game_flow_manager_ref and game_flow_manager_ref.dominio_command_handler:
		game_flow_manager_ref.dominio_command_handler.cancel()

# === グローバルアクションボタン管理 ===

## ナビゲーションボタンを設定（推奨）
## 有効なCallableを渡したボタンのみ表示される
func enable_navigation(confirm_cb: Callable = Callable(), back_cb: Callable = Callable(), up_cb: Callable = Callable(), down_cb: Callable = Callable()):
	# 入力待ち状態になったのでロック解除
	if game_flow_manager_ref:
		game_flow_manager_ref.unlock_input()
	
	# 後方互換変数も同期（register_xxx系との競合防止）
	_compat_confirm_cb = confirm_cb
	_compat_back_cb = back_cb
	_compat_up_cb = up_cb
	_compat_down_cb = down_cb
	if global_action_buttons:
		global_action_buttons.setup(confirm_cb, back_cb, up_cb, down_cb)
	else:
		print("[UIManager] ERROR: global_action_buttons is null!")

## ナビゲーションボタンを全てクリア
func disable_navigation():
	# 後方互換変数もクリア
	_compat_confirm_cb = Callable()
	_compat_back_cb = Callable()
	_compat_up_cb = Callable()
	_compat_down_cb = Callable()
	if global_action_buttons:
		global_action_buttons.clear_all()

# === 後方互換API（他コンポーネント用） ===
# 注: 新規実装ではenable_navigation()を使用してください

var _compat_confirm_cb: Callable = Callable()
var _compat_back_cb: Callable = Callable()
var _compat_up_cb: Callable = Callable()
var _compat_down_cb: Callable = Callable()

func _update_compat_buttons():
	if global_action_buttons:
		global_action_buttons.setup(_compat_confirm_cb, _compat_back_cb, _compat_up_cb, _compat_down_cb)

func register_confirm_action(callback: Callable, _text: String = ""):
	# 入力待ち状態になったのでロック解除
	if game_flow_manager_ref:
		game_flow_manager_ref.unlock_input()
	_compat_confirm_cb = callback
	_update_compat_buttons()

func register_back_action(callback: Callable, _text: String = ""):
	# 入力待ち状態になったのでロック解除
	if game_flow_manager_ref:
		game_flow_manager_ref.unlock_input()
	_compat_back_cb = callback
	_update_compat_buttons()

func register_arrow_actions(up_callback: Callable, down_callback: Callable):
	# 入力待ち状態になったのでロック解除
	if game_flow_manager_ref:
		game_flow_manager_ref.unlock_input()
	_compat_up_cb = up_callback
	_compat_down_cb = down_callback
	_update_compat_buttons()

func clear_confirm_action():
	_compat_confirm_cb = Callable()
	_update_compat_buttons()

func clear_back_action():
	_compat_back_cb = Callable()
	_update_compat_buttons()

func clear_arrow_actions():
	_compat_up_cb = Callable()
	_compat_down_cb = Callable()
	_update_compat_buttons()

func clear_global_actions():
	_compat_confirm_cb = Callable()
	_compat_back_cb = Callable()
	_compat_up_cb = Callable()
	_compat_down_cb = Callable()
	if global_action_buttons:
		global_action_buttons.clear_all()

# === 特殊ボタン（左下）API ===

## 特殊ボタンを設定（アルカナアーツ/ドミニオコマンド等）
func set_special_button(text: String, callback: Callable):
	if global_action_buttons:
		global_action_buttons.setup_special(text, callback)

## 特殊ボタンをクリア
func clear_special_button():
	if global_action_buttons:
		global_action_buttons.clear_special()

func register_global_actions(confirm_callback: Callable, back_callback: Callable, _confirm_text: String = "", _back_text: String = ""):
	# 入力待ち状態になったのでロック解除
	if game_flow_manager_ref:
		game_flow_manager_ref.unlock_input()
	_compat_confirm_cb = confirm_callback
	_compat_back_cb = back_callback
	_update_compat_buttons()

# === 手札UI管理 ===

# 手札コンテナを初期化（HandDisplayに委譲）
func initialize_hand_container(container_layer: Node):
	if hand_display:
		hand_display.initialize(container_layer, card_system_ref, player_system_ref)

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

## 全てのインフォパネルを閉じる（フェーズ変更時に呼び出す）
func close_all_info_panels():
	if creature_info_panel_ui and creature_info_panel_ui.visible:
		creature_info_panel_ui.hide_panel()
	if spell_info_panel_ui and spell_info_panel_ui.visible:
		spell_info_panel_ui.hide_panel()
	if item_info_panel_ui and item_info_panel_ui.visible:
		item_info_panel_ui.hide_panel()

# デバッグ入力を処理
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			toggle_debug_mode()

# ============================================
# Phase 1-A: ドミニオコマンドUI
# ============================================

# ドミニオコマンドボタンは特殊ボタン（左下）に移行済み

## ドミニオコマンドボタンを表示（特殊ボタン使用）
func show_dominio_order_button():
	set_special_button("D", func(): _on_dominio_order_button_pressed())

## ドミニオコマンドボタンを非表示（特殊ボタンクリア）
func hide_dominio_order_button():
	clear_special_button()

# ============================================
# アルカナアーツボタン（特殊ボタン使用）
# ============================================

## アルカナアーツボタンを表示
func show_mystic_button(callback: Callable):
	set_special_button("A", callback)

## アルカナアーツボタンを非表示
func hide_mystic_button():
	clear_special_button()

# create_action_menu_panel は DominioOrderUIに移行済みのため削除

# _create_menu_button は DominioOrderUIに移行済みのため削除

# create_level_selection_panel と _create_level_button は DominioOrderUIに移行済みのため削除

# キャンセルボタンの表示/非表示
func show_cancel_button():
	if dominio_order_ui:
		dominio_order_ui.show_cancel_button()

func hide_cancel_button():
	if dominio_order_ui:
		dominio_order_ui.hide_cancel_button()

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
	var land_list = ""
	for i in range(_owned_lands.size()):
		land_list += str(i + 1) + ":" + str(_owned_lands[i]) + " "
	if phase_display:
		phase_display.show_action_prompt("土地を選択（数字キー） " + land_list)
	
	# キャンセルボタンはdominio_command_handler側で登録するためここでは呼ばない
	# show_cancel_button()

# アクション選択UIを表示
func show_action_selection_ui(tile_index: int):
	print("[UIManager] アクション選択UI表示: tile ", tile_index)
	# Phase 1-A: 新しいUIパネルを使用
	show_action_menu(tile_index)

# ドミニオコマンドUIを非表示
func hide_dominio_order_ui():
	# Phase 1-A: 新UIパネルを非表示
	hide_action_menu()
	hide_level_selection()
	
	# CardSelectionUIも非表示にする
	if card_selection_ui and card_selection_ui.has_method("hide_selection"):
		card_selection_ui.hide_selection()
	
	# キャンセルボタンを非表示
	hide_cancel_button()

# ==== Phase 1-A: アクションメニュー表示/非表示（DominioOrderUIに委譲） ====

func show_action_menu(tile_index: int):
	if dominio_order_ui:
		dominio_order_ui.show_action_menu(tile_index)

func hide_action_menu():
	if dominio_order_ui:
		dominio_order_ui.hide_action_menu()

# ==== Phase 1-A: レベル選択パネル表示/非表示（DominioOrderUIに委譲） ====

func show_level_selection(tile_index: int, current_level: int, player_magic: int):
	if dominio_order_ui:
		dominio_order_ui.show_level_selection(tile_index, current_level, player_magic)

func hide_level_selection():
	if dominio_order_ui:
		dominio_order_ui.hide_level_selection()

# ==== Phase 1-A: イベントハンドラ ====

# イベントハンドラはDominioOrderUIに移行済み

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

# ============================================
# 勝利演出
# ============================================

## 勝利画面を表示
func show_win_screen(player_id: int):
	if not ui_layer:
		return
	
	# フェーズラベルを更新
	if phase_label:
		phase_label.text = ""
	
	# 勝利演出パネルを作成
	var win_panel = Panel.new()
	win_panel.name = "WinScreen"
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 半透明の黒背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	win_panel.add_theme_stylebox_override("panel", style)
	
	# VBoxContainerで中央配置
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	win_panel.add_child(vbox)
	
	# 「WIN」ラベル
	var win_label = Label.new()
	win_label.text = "WIN"
	win_label.add_theme_font_size_override("font_size", 200)
	win_label.add_theme_color_override("font_color", Color.GOLD)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(win_label)
	
	# プレイヤー名ラベル
	var player_name = "プレイヤー%d" % (player_id + 1)
	if player_system_ref and player_id < player_system_ref.players.size():
		player_name = player_system_ref.players[player_id].name
	
	var player_label = Label.new()
	player_label.text = player_name + " の勝利！"
	player_label.add_theme_font_size_override("font_size", 48)
	player_label.add_theme_color_override("font_color", Color.WHITE)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(player_label)
	
	# VBoxの位置を中央に
	vbox.position = Vector2(-200, -150)
	vbox.custom_minimum_size = Vector2(400, 300)
	
	ui_layer.add_child(win_panel)
	
	# アニメーション（フェードイン + スケール）
	win_panel.modulate.a = 0
	win_label.scale = Vector2(0.5, 0.5)
	win_label.pivot_offset = win_label.size / 2
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(win_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(win_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	print("[UIManager] 勝利画面表示: プレイヤー", player_id + 1)


## 勝利画面を表示（非同期版 - クリック待ち）
func show_win_screen_async(player_id: int):
	show_win_screen(player_id)
	
	# クリック待ち
	await _wait_for_click()
	
	# 勝利画面を削除
	var win_screen = ui_layer.get_node_or_null("WinScreen")
	if win_screen:
		win_screen.queue_free()


## 敗北画面を表示（非同期版 - クリック待ち）
func show_lose_screen_async(player_id: int):
	if not ui_layer:
		return
	
	# フェーズラベルを更新
	if phase_label:
		phase_label.text = ""
	
	# 敗北演出パネルを作成
	var lose_panel = Panel.new()
	lose_panel.name = "LoseScreen"
	lose_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 半透明の黒背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	lose_panel.add_theme_stylebox_override("panel", style)
	
	# VBoxContainerで中央配置
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lose_panel.add_child(vbox)
	
	# 「LOSE」ラベル
	var lose_label = Label.new()
	lose_label.text = "LOSE..."
	lose_label.add_theme_font_size_override("font_size", 150)
	lose_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lose_label)
	
	# VBoxの位置を中央に
	vbox.position = Vector2(-200, -100)
	vbox.custom_minimum_size = Vector2(400, 200)
	
	ui_layer.add_child(lose_panel)
	
	# アニメーション（フェードイン）
	lose_panel.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(lose_panel, "modulate:a", 1.0, 0.5)
	
	print("[UIManager] 敗北画面表示: プレイヤー", player_id + 1)
	
	# クリック待ち
	await _wait_for_click()
	
	# 敗北画面を削除
	lose_panel.queue_free()


## クリック待ち
func _wait_for_click():
	print("[UIManager] クリック待ち開始")
	# 単純にタイマーで待機
	await get_tree().create_timer(2.0).timeout
	print("[UIManager] クリック待ち完了")


# ============================================
# カメラタップによるクリーチャー情報表示
# ============================================

## CameraControllerのシグナルを接続
func connect_camera_signals():
	print("[UIManager] connect_camera_signals 呼び出し")
	
	if not board_system_ref:
		print("[UIManager] board_system_ref がない")
		return
	
	if not board_system_ref.camera_controller:
		print("[UIManager] camera_controller がない (board_system_ref: %s)" % board_system_ref)
		print("[UIManager] board_system_ref の camera_controller: %s" % board_system_ref.get("camera_controller"))
		return
	
	var cam_ctrl = board_system_ref.camera_controller
	
	# 既に接続されていたらスキップ
	if cam_ctrl.creature_tapped.is_connected(_on_creature_tapped):
		print("[UIManager] シグナル既に接続済み")
		return
	
	cam_ctrl.creature_tapped.connect(_on_creature_tapped)
	cam_ctrl.tile_tapped.connect(_on_tile_tapped)
	cam_ctrl.empty_tapped.connect(_on_empty_tapped)
	print("[UIManager] カメラタップシグナル接続完了")


## クリーチャーがタップされた時のハンドラ
func _on_creature_tapped(tile_index: int, creature_data: Dictionary):
	print("[UIManager] _on_creature_tapped 呼び出し: タイル%d" % tile_index)
	
	if creature_data.is_empty():
		print("[UIManager] creature_data が空")
		return
	
	# TapTargetManagerでターゲット選択中かチェック
	if tap_target_manager and tap_target_manager.is_active:
		if tap_target_manager.handle_creature_tap(tile_index, creature_data):
			# ターゲットとして処理された
			return
	
	# ターゲット選択されなかった場合はインフォパネル表示
	# ターゲット選択中は setup_buttons=false でグローバルボタンを変更しない
	# ドミニオコマンド選択中は専用の処理を行う
	var is_dominio_order_active = game_flow_manager_ref and game_flow_manager_ref.dominio_command_handler and game_flow_manager_ref.dominio_command_handler.current_state != game_flow_manager_ref.dominio_command_handler.State.CLOSED
	var is_tap_target_active = tap_target_manager and tap_target_manager.is_active
	# チュートリアルのExplanationModeがアクティブな時もボタンを変更しない
	var is_tutorial_active = global_action_buttons and global_action_buttons.explanation_mode_active
	var setup_buttons = not is_tap_target_active and not is_dominio_order_active and not is_tutorial_active
	
	if creature_info_panel_ui:
		creature_info_panel_ui.show_view_mode(creature_data, tile_index, setup_buttons)
		print("[UIManager] クリーチャー情報パネル表示: タイル%d - %s (setup_buttons=%s, land_cmd=%s)" % [tile_index, creature_data.get("name", "不明"), setup_buttons, is_dominio_order_active])
		
		# ドミニオコマンド中はパネルを閉じるだけの×ボタンを設定
		if is_dominio_order_active:
			register_back_action(func():
				creature_info_panel_ui.hide_panel(false)
				# ドミニオコマンドのナビゲーションを復元
				game_flow_manager_ref.dominio_command_handler._restore_navigation()
			, "閉じる")
	else:
		print("[UIManager] creature_info_panel_ui がない")


## タイルがタップされた時のハンドラ（クリーチャーがいない場合）
func _on_tile_tapped(tile_index: int, tile_data: Dictionary):
	# TapTargetManagerでターゲット選択中かチェック
	if tap_target_manager and tap_target_manager.is_active:
		if tap_target_manager.handle_tile_tap(tile_index, tile_data):
			# ターゲットとして処理された
			return
		
		# ターゲット選択中だが無効なタイル → インフォパネルだけ閉じる（ボタンはそのまま）
		if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
			creature_info_panel_ui.hide_panel(false)  # clear_buttons=false
		return
	
	# 通常時はインフォパネルを閉じる
	if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
		# チュートリアル中はボタンをクリアしない
		var is_tutorial_active = global_action_buttons and global_action_buttons.explanation_mode_active
		creature_info_panel_ui.hide_panel(not is_tutorial_active)


## 空（タイル外）がタップされた時のハンドラ
func _on_empty_tapped():
	# TapTargetManagerでターゲット選択中かチェック
	if tap_target_manager and tap_target_manager.is_active:
		if tap_target_manager.handle_empty_tap():
			# 選択モード中は何もしない
			return
	
	# 通常時はインフォパネルを閉じる
	if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
		creature_info_panel_ui.hide_panel(false)  # ボタンはクリアしない（チュートリアル等の状態を維持）
		print("[UIManager] 空タップでパネル閉じ")


## TapTargetManagerからターゲットが選択された時
func _on_tap_target_selected(tile_index: int, _creature_data: Dictionary):
	print("[UIManager] タップターゲット選択: タイル%d" % tile_index)
	# ドミニオコマンドハンドラなど、呼び出し元に通知（シグナルを中継）
	# 具体的な処理は各ハンドラが tap_target_manager.target_selected に直接接続


## TapTargetManagerから選択がキャンセルされた時
func _on_tap_target_cancelled():
	print("[UIManager] タップターゲット選択キャンセル")


# ============================================
# ゲームメニュー
# ============================================

## ゲームメニューをセットアップ
func _setup_game_menu():
	if not ui_layer:
		print("[UIManager] ui_layerがないためゲームメニュー初期化スキップ")
		return
	
	# メニューボタン
	game_menu_button = GameMenuButton.new()
	game_menu_button.name = "GameMenuButton"
	game_menu_button.menu_pressed.connect(_on_game_menu_button_pressed)
	ui_layer.add_child(game_menu_button)
	
	# メニュー
	game_menu = GameMenu.new()
	game_menu.name = "GameMenu"
	game_menu.settings_selected.connect(_on_settings_selected)
	game_menu.help_selected.connect(_on_help_selected)
	game_menu.surrender_selected.connect(_on_surrender_selected)
	ui_layer.add_child(game_menu)
	
	# 降参確認ダイアログ
	surrender_dialog = SurrenderDialog.new()
	surrender_dialog.name = "SurrenderDialog"
	surrender_dialog.surrendered.connect(_on_surrender_confirmed)
	ui_layer.add_child(surrender_dialog)
	
	print("[UIManager] ゲームメニュー初期化完了")


## メニューボタン押下
func _on_game_menu_button_pressed():
	print("[UIManager] メニューボタン押下受信")
	if game_menu:
		game_menu.show_menu()
	else:
		print("[UIManager] game_menu が null")


## 設定選択
func _on_settings_selected():
	print("[UIManager] 設定選択（未実装）")
	# TODO: 設定画面を開く


## ヘルプ選択
func _on_help_selected():
	print("[UIManager] ヘルプ選択（未実装）")
	# TODO: ヘルプ画面を開く


## 降参選択
func _on_surrender_selected():
	if surrender_dialog:
		surrender_dialog.show_dialog()


## 降参確認
func _on_surrender_confirmed():
	print("[UIManager] 降参確認")
	if game_flow_manager_ref:
		game_flow_manager_ref.on_player_defeated("surrender")
