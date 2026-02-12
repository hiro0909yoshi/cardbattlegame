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
var spell_phase_handler_ref = null  # SpellPhaseHandler参照（チェーンアクセス解消用）
var dominio_command_handler_ref = null  # DominioCommandHandler参照（チェーンアクセス解消用）

# デバッグモード
# NOTE: debug_modeはDebugSettings.ui_debug_modeに移行済み

# UIレイヤー参照
var ui_layer: CanvasLayer = null

# スペルフェーズ用のフィルター設定
var card_selection_filter: String = ""  # "spell"の時はスペルカードのみ選択可能、"item"の時はアイテムのみ、"item_or_assist"の時はアイテム+援護対象クリーチャー
var assist_target_elements: Array = []  # 援護対象の属性リスト

# ゲームメニュー関連
# サブシステム
var win_screen_handler: UIWinScreen = null
var tap_handler: UITapHandler = null
var game_menu_handler: UIGameMenuHandler = null
var blocked_item_types: Array = []  # ブロックするアイテムタイプ（例: ["防具"]）
var excluded_card_index: int = -1  # 犠牲選択時に除外するカードインデックス（召喚するカード自身）
var excluded_card_id: String = ""  # 犠牲選択時に除外するカードID（召喚するカード自身）

# 手札UI管理（HandDisplayに移行済み）
# 以下の変数は削除予定

func _ready():
	# サブシステム初期化
	win_screen_handler = UIWinScreen.new(self)
	tap_handler = UITapHandler.new(self)
	game_menu_handler = UIGameMenuHandler.new(self)

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
		# GameFlowManager参照を設定（シグナル表示用）
		if game_flow_manager_ref:
			var lap_sys = game_flow_manager_ref.lap_system if game_flow_manager_ref.get("lap_system") else null
			player_info_panel.set_game_flow_manager(game_flow_manager_ref, lap_sys)
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
	tap_target_manager.target_selected.connect(tap_handler.on_tap_target_selected)
	tap_target_manager.selection_cancelled.connect(tap_handler.on_tap_target_cancelled)
	
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
	game_menu_handler.setup_game_menu()

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
func on_card_button_pressed(card_index: int):
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
			DebugSettings.ui_debug_mode = debug_panel.is_debug_visible()

func update_cpu_hand_display(player_id: int):
	if debug_panel and debug_panel.has_method("update_cpu_hand"):
		debug_panel.update_cpu_hand(player_id)

# === 基本UI操作 ===
func update_ui(_current_player, current_phase):
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
	DebugSettings.ui_debug_mode = enabled

func _on_dominio_order_button_pressed():
	emit_signal("dominio_order_button_pressed")

func _on_creature_info_panel_confirmed(card_data: Dictionary):
	# カードインデックスを取得してcard_selectedシグナルを発火
	var card_index = card_data.get("hand_index", -1)
	if card_index >= 0:
		emit_signal("card_selected", card_index)

func _on_creature_info_panel_cancelled():
	emit_signal("pass_button_pressed")

func on_cancel_dominio_order_button_pressed():
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
	
	# 新しいナビゲーション設定時は前の保存状態を無効化
	_nav_state_saved = false
	
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

# インフォパネル閲覧モード中のナビゲーション保存/復元
var _saved_nav_confirm: Callable = Callable()
var _saved_nav_back: Callable = Callable()
var _saved_nav_up: Callable = Callable()
var _saved_nav_down: Callable = Callable()
var _saved_nav_special_cb: Callable = Callable()
var _saved_nav_special_text: String = ""
var _saved_nav_phase_comment: String = ""
var _nav_state_saved: bool = false

## 現在のナビゲーション状態を保存（閲覧モード用）
## 既に保存済みの場合は上書きしない（連続閲覧対応）
func save_navigation_state():
	if _nav_state_saved:
		return
	_saved_nav_confirm = _compat_confirm_cb
	_saved_nav_back = _compat_back_cb
	_saved_nav_up = _compat_up_cb
	_saved_nav_down = _compat_down_cb
	# special_button状態を保存
	if global_action_buttons:
		_saved_nav_special_cb = global_action_buttons._special_callback
		_saved_nav_special_text = global_action_buttons._special_text
	# フェーズコメントを保存
	if phase_display and phase_display.has_method("get_current_action_prompt"):
		_saved_nav_phase_comment = phase_display.get_current_action_prompt()
	else:
		_saved_nav_phase_comment = ""
	_nav_state_saved = true
	# 特殊ボタンをクリア（インフォパネル表示中は不要。復元時に再設定される）
	clear_special_button()

## 保存したナビゲーション状態を復元
func restore_navigation_state():
	if not _nav_state_saved:
		return
	_compat_confirm_cb = _saved_nav_confirm
	_compat_back_cb = _saved_nav_back
	_compat_up_cb = _saved_nav_up
	_compat_down_cb = _saved_nav_down
	_nav_state_saved = false
	_update_compat_buttons()
	# special_button状態を復元
	if global_action_buttons:
		if _saved_nav_special_cb.is_valid():
			global_action_buttons.setup_special(_saved_nav_special_text, _saved_nav_special_cb)
		else:
			global_action_buttons.clear_special()
	# フェーズコメントを復元
	if _saved_nav_phase_comment != "" and phase_display:
		phase_display.show_action_prompt(_saved_nav_phase_comment)
	# 入力ロックを解除（×ボタン押下時にlock_inputされるため）
	if game_flow_manager_ref:
		game_flow_manager_ref.unlock_input()

## ナビゲーション保存状態をクリア（フェーズ切り替え時等）
func clear_navigation_saved_state():
	_nav_state_saved = false

## 現在アクティブなフェーズのナビゲーション・フェーズコメントを復元
## 閲覧モードから戻る時に使用（save/restoreではなくフェーズに直接依頼）
func _restore_current_phase():
	# 1. ドミニオコマンドがアクティブ → ドミニオに委譲
	if dominio_command_handler_ref:
		var dominio = dominio_command_handler_ref
		if dominio.current_state != dominio.State.CLOSED:
			if dominio.current_state == dominio.State.SELECTING_ACTION:
				if dominio_order_ui and dominio_order_ui.action_menu_ui:
					dominio_order_ui.action_menu_ui.restore_navigation()
				else:
					dominio.restore_navigation()
			else:
				dominio.restore_navigation()
			hide_dominio_order_button()
			dominio.restore_phase_comment()
			_nav_state_saved = false
			return
	
	# 2. スペルフェーズがアクティブ（target選択/確認含む） → spell_phase_handlerに委譲
	if spell_phase_handler_ref and spell_phase_handler_ref.is_spell_phase_active():
		spell_phase_handler_ref.restore_navigation()
		_nav_state_saved = false
		return
	
	# 3. カード選択UIがアクティブ（召喚/バトル/アイテム等） → card_selection_uiに委譲
	if card_selection_ui and card_selection_ui.is_active:
		card_selection_ui.restore_navigation()
		_nav_state_saved = false
		return
	
	# 4. 方向選択・分岐選択がアクティブ → セレクターに委譲
	if board_system_ref and board_system_ref.movement_controller:
		var mc = board_system_ref.movement_controller
		if mc.direction_selector and mc.direction_selector.is_active:
			mc.direction_selector.restore_navigation()
			_nav_state_saved = false
			return
		if mc.branch_selector and mc.branch_selector.is_active:
			mc.branch_selector.restore_navigation()
			_nav_state_saved = false
			return
	
	# 5. どのフェーズでもない → save/restore フォールバック
	restore_navigation_state()

## [後方互換] スペルフェーズ中のインフォパネル閉じ後にボタンを復元
func restore_spell_phase_buttons():
	restore_navigation_state()

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
	hide_all_info_panels(true)
	clear_navigation_saved_state()

## 全てのインフォパネルを閉じてナビゲーションをクリア（saved stateは保持）
## show_card_info内でのパネル切り替え時に使用
func _hide_all_info_panels_raw():
	# saved stateを一時退避（disable_navigation→clear_allで消費されないように）
	var was_saved = _nav_state_saved
	var saved_confirm = _saved_nav_confirm
	var saved_back = _saved_nav_back
	var saved_up = _saved_nav_up
	var saved_down = _saved_nav_down
	var saved_special_cb = _saved_nav_special_cb
	var saved_special_text = _saved_nav_special_text
	var saved_phase_comment = _saved_nav_phase_comment
	
	# パネルを閉じる（clear_buttons=false: hide_panel内でのボタン操作を防ぐ）
	if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
		creature_info_panel_ui.hide_panel(false)
	if spell_info_panel_ui and spell_info_panel_ui.is_panel_visible():
		spell_info_panel_ui.hide_panel(false)
	if item_info_panel_ui and item_info_panel_ui.is_panel_visible():
		item_info_panel_ui.hide_panel(false)
	
	# ナビゲーションを全クリア（前のパネルの確認ボタン等を確実に消す）
	disable_navigation()
	# special_buttonも明示的にクリア（閲覧モード中は不要）
	if global_action_buttons:
		global_action_buttons.clear_special()
	
	# saved stateを復元（disable/clearで消費された分を戻す）
	_nav_state_saved = was_saved
	_saved_nav_confirm = saved_confirm
	_saved_nav_back = saved_back
	_saved_nav_up = saved_up
	_saved_nav_down = saved_down
	_saved_nav_special_cb = saved_special_cb
	_saved_nav_special_text = saved_special_text
	_saved_nav_phase_comment = saved_phase_comment

## 全てのインフォパネルを閉じる（clear_buttons指定可能）
func hide_all_info_panels(clear_buttons: bool = true):
	if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
		creature_info_panel_ui.hide_panel(clear_buttons)
	if spell_info_panel_ui and spell_info_panel_ui.is_panel_visible():
		spell_info_panel_ui.hide_panel(clear_buttons)
	if item_info_panel_ui and item_info_panel_ui.is_panel_visible():
		item_info_panel_ui.hide_panel(clear_buttons)

## いずれかのインフォパネルが表示中か
func is_any_info_panel_visible() -> bool:
	if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
		return true
	if spell_info_panel_ui and spell_info_panel_ui.is_panel_visible():
		return true
	if item_info_panel_ui and item_info_panel_ui.is_panel_visible():
		return true
	return false

## カード情報パネルを表示（ナビゲーションに触らない）
## ドミニオの土地プレビュー等、表示の一部として使用する場合用
func show_card_info_only(card_data: Dictionary, tile_index: int = -1):
	var card_type = card_data.get("type", "")
	# 既存パネルを閉じる（ナビゲーションに触らない）
	if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
		creature_info_panel_ui.hide_panel(false)
	if spell_info_panel_ui and spell_info_panel_ui.is_panel_visible():
		spell_info_panel_ui.hide_panel(false)
	if item_info_panel_ui and item_info_panel_ui.is_panel_visible():
		item_info_panel_ui.hide_panel(false)
	# パネル表示（setup_buttons=false、×ボタンも設定しない）
	match card_type:
		"creature":
			if creature_info_panel_ui:
				creature_info_panel_ui.show_view_mode(card_data, tile_index, false)
		"spell":
			if spell_info_panel_ui:
				spell_info_panel_ui.show_view_mode(card_data, false)
		"item":
			if item_info_panel_ui:
				item_info_panel_ui.show_view_mode(card_data, false)

## カード種別に応じたインフォパネルを表示（閲覧モード）
## ナビゲーション状態を自動保存し、パネルを閉じた時に復元する
func show_card_info(card_data: Dictionary, tile_index: int = -1, setup_buttons: bool = true):
	var card_type = card_data.get("type", "")
	
	# ナビゲーション状態を保存（連続閲覧時は最初の1回のみ）
	save_navigation_state()
	
	# 他のパネルを閉じる（ボタンはクリアしない：show_card_info内での切り替えなのでrestoreを走らせない）
	_hide_all_info_panels_raw()
	
	# 閲覧モードで表示
	var panel = null
	match card_type:
		"creature":
			if creature_info_panel_ui:
				creature_info_panel_ui.show_view_mode(card_data, tile_index, setup_buttons)
				panel = creature_info_panel_ui
		"spell":
			if spell_info_panel_ui:
				spell_info_panel_ui.show_view_mode(card_data, setup_buttons)
				panel = spell_info_panel_ui
		"item":
			if item_info_panel_ui:
				item_info_panel_ui.show_view_mode(card_data, setup_buttons)
				panel = item_info_panel_ui
	
	# パネルが表示されたら、閲覧モードの×ボタン（閉じる）のみ設定
	# _hide_all_info_panels_rawでdisable_navigation→_compat_*が全クリア済みなので
	# 閲覧中は×ボタンだけ有効にする（✓▲▼は不要）
	# 復元はフェーズ別restore_navigation()が担当する
	if panel and not setup_buttons:
		register_back_action(func():
			_hide_all_info_panels_raw()
			_restore_current_phase()
			# カードのホバー状態を解除
			var card_script = load("res://scripts/card.gd")
			if card_script.currently_selected_card:
				card_script.currently_selected_card.deselect_card()
		, "閉じる")
		
		# 閲覧モード中のフェーズコメント表示
		var card_name = card_data.get("name", "")
		if phase_display and card_name != "":
			phase_display.show_action_prompt("%s の情報を閲覧中" % card_name)

## カード種別に応じたインフォパネルを表示（選択モード）
func show_card_selection(card_data: Dictionary, hand_index: int = -1,
		confirmation_text: String = "", restriction_reason: String = "",
		selection_mode: String = ""):
	var card_type = card_data.get("type", "")
	# 他のパネルを閉じる
	hide_all_info_panels(false)
	match card_type:
		"creature":
			if creature_info_panel_ui:
				creature_info_panel_ui.show_selection_mode(card_data, confirmation_text, restriction_reason)
		"spell":
			if spell_info_panel_ui:
				spell_info_panel_ui.show_spell_info(card_data, hand_index, restriction_reason, selection_mode, confirmation_text)
		"item":
			if item_info_panel_ui:
				item_info_panel_ui.show_item_info(card_data, hand_index, restriction_reason, selection_mode, confirmation_text)

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
## 操作可能な所有地（非ダウン）がない場合は表示しない
func show_dominio_order_button():
	if board_system_ref and board_system_ref.has_method("has_owned_lands"):
		var player_id = board_system_ref.current_player_index
		if not board_system_ref.has_owned_lands(player_id):
			return
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
	# 他のインフォパネルが開いていたら閉じる
	if creature_info_panel_ui and creature_info_panel_ui.is_panel_visible():
		creature_info_panel_ui.hide_panel()
	if spell_info_panel_ui and spell_info_panel_ui.is_panel_visible():
		spell_info_panel_ui.hide_panel()
	if item_info_panel_ui and item_info_panel_ui.is_panel_visible():
		item_info_panel_ui.hide_panel()
	
	if player_status_dialog and player_status_dialog.has_method("show_for_player"):
		player_status_dialog.show_for_player(player_id)

# === 勝敗演出（UIWinScreenに委譲） ===

func show_win_screen(player_id: int):
	win_screen_handler.show_win_screen(player_id)

func show_win_screen_async(player_id: int):
	await win_screen_handler.show_win_screen_async(player_id)

func show_lose_screen_async(player_id: int):
	await win_screen_handler.show_lose_screen_async(player_id)


# === カメラタップ（UITapHandlerに委譲） ===

func connect_camera_signals():
	tap_handler.connect_camera_signals()
	# TapTargetManagerのシグナルも接続
	if tap_target_manager:
		if not tap_target_manager.target_selected.is_connected(tap_handler.on_tap_target_selected):
			tap_target_manager.target_selected.connect(tap_handler.on_tap_target_selected)
		if not tap_target_manager.selection_cancelled.is_connected(tap_handler.on_tap_target_cancelled):
			tap_target_manager.selection_cancelled.connect(tap_handler.on_tap_target_cancelled)


# === ゲームメニュー（UIGameMenuHandlerに委譲） ===
# game_menu_button, game_menu, surrender_dialog は game_menu_handler 内で管理