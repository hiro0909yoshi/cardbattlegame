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

## UIサービス（Phase 8-F: 内部委譲レイヤー）
var _message_service: MessageService = null
var _navigation_service: NavigationService = null
var _card_selection_service: CardSelectionService = null
var _info_panel_service: InfoPanelService = null
var _player_info_service = null

## UIサービス公開アクセサ（Phase 8-G+ 外部ファイル直接参照移行用）
var message_service: MessageService:
	get: return _message_service
var navigation_service: NavigationService:
	get: return _navigation_service
var card_selection_service: CardSelectionService:
	get: return _card_selection_service
var info_panel_service: InfoPanelService:
	get: return _info_panel_service
var player_info_service:
	get: return _player_info_service

# 基本UI要素
# フェーズ表示（PhaseDisplayに移行済み）
var phase_label: Label:
	get: return phase_display.phase_label if phase_display else null

# Phase 1-A: ドミニオコマンドUI（DominioOrderUIに委譲）
# 以下の変数は削除予定（DominioOrderUIに移行済み）

# システム参照（型指定なし - 3D対応のため）
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var board_system_ref: BoardSystem3D = null  # BoardSystem3Dも格納可能
var game_flow_manager_ref: GameFlowManager = null  # GameFlowManagerの参照

# === Callable 注入変数（Phase 10-C: 双方向参照削減） ===
var _is_input_locked_cb: Callable = Callable()
var _has_owned_lands_cb: Callable = Callable()
var _update_tile_display_cb: Callable = Callable()

# === UIEventHub 参照（Phase 11-A） ===
var _ui_event_hub: UIEventHub = null

# デバッグモード
# NOTE: debug_modeはDebugSettings.ui_debug_modeに移行済み

# UIレイヤー参照
var ui_layer: CanvasLayer = null

# スペルフェーズ用のフィルター設定（Phase 8-M: CardSelectionServiceに委譲）
var card_selection_filter: String:
	get: return _card_selection_service.card_selection_filter if _card_selection_service else ""
	set(value):
		if _card_selection_service:
			_card_selection_service.card_selection_filter = value

var assist_target_elements: Array:
	get: return _card_selection_service.assist_target_elements if _card_selection_service else []
	set(value):
		if _card_selection_service:
			_card_selection_service.assist_target_elements = value

# ゲームメニュー関連
# サブシステム
var win_screen_handler: UIWinScreen = null
var tap_handler: UITapHandler = null
var game_menu_handler: UIGameMenuHandler = null

var blocked_item_types: Array:
	get: return _card_selection_service.blocked_item_types if _card_selection_service else []
	set(value):
		if _card_selection_service:
			_card_selection_service.blocked_item_types = value

var excluded_card_index: int:
	get: return _card_selection_service.excluded_card_index if _card_selection_service else -1
	set(value):
		if _card_selection_service:
			_card_selection_service.excluded_card_index = value

var excluded_card_id: String:
	get: return _card_selection_service.excluded_card_id if _card_selection_service else ""
	set(value):
		if _card_selection_service:
			_card_selection_service.excluded_card_id = value

# 手札UI管理（HandDisplayに移行済み）
# 以下の変数は削除予定

func _ready():
	# サブシステム初期化
	win_screen_handler = UIWinScreen.new(self)
	tap_handler = UITapHandler.new(self)
	game_menu_handler = UIGameMenuHandler.new(self)

	# UIサービス初期化（Phase 8-F）
	_message_service = MessageService.new()
	_message_service.name = "MessageService"
	add_child(_message_service)

	_navigation_service = NavigationService.new()
	_navigation_service.name = "NavigationService"
	add_child(_navigation_service)

	_card_selection_service = CardSelectionService.new()
	_card_selection_service.name = "CardSelectionService"
	add_child(_card_selection_service)

	_info_panel_service = InfoPanelService.new()
	_info_panel_service.name = "InfoPanelService"
	add_child(_info_panel_service)

	_player_info_service = PlayerInfoService.new()
	_player_info_service.name = "PlayerInfoService"
	add_child(_player_info_service)

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
		if not card_selection_ui.card_selected.is_connected(_on_card_ui_selected):
			card_selection_ui.card_selected.connect(_on_card_ui_selected)
		if not card_selection_ui.selection_cancelled.is_connected(_on_selection_cancelled):
			card_selection_ui.selection_cancelled.connect(_on_selection_cancelled)

	# レベルアップUI
	if level_up_ui:
		if not level_up_ui.level_selected.is_connected(_on_level_ui_selected):
			level_up_ui.level_selected.connect(_on_level_ui_selected)
		if not level_up_ui.selection_cancelled.is_connected(_on_level_up_cancelled):
			level_up_ui.selection_cancelled.connect(_on_level_up_cancelled)

	# デバッグパネル
	if debug_panel:
		if not debug_panel.debug_mode_changed.is_connected(_on_debug_mode_changed):
			debug_panel.debug_mode_changed.connect(_on_debug_mode_changed)

	# PlayerInfoPanel
	if player_info_panel:
		if not player_info_panel.player_panel_clicked.is_connected(_on_player_panel_clicked):
			player_info_panel.player_panel_clicked.connect(_on_player_panel_clicked)

	# CreatureInfoPanelUI
	if creature_info_panel_ui:
		if not creature_info_panel_ui.selection_confirmed.is_connected(_on_creature_info_panel_confirmed):
			creature_info_panel_ui.selection_confirmed.connect(_on_creature_info_panel_confirmed)
		# selection_cancelledはcard_selection_ui側で処理（選択UIに戻る）

	# CardSelectionService を CardSelectionUI と HandDisplay に注入（Phase 8-M）
	if card_selection_ui and _card_selection_service:
		card_selection_ui.set_card_selection_service(_card_selection_service)
	if hand_display and _card_selection_service:
		hand_display._card_selection_service = _card_selection_service

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

	# UIサービスセットアップ（Phase 8-F）
	if _message_service:
		_message_service.setup(global_comment_ui, phase_display)
	if _navigation_service:
		var unlock_cb = Callable()
		if game_flow_manager_ref:
			unlock_cb = game_flow_manager_ref.unlock_input
		_navigation_service.setup(global_action_buttons, unlock_cb)
	if _card_selection_service:
		_card_selection_service.setup(card_selection_ui, hand_display, card_system_ref, player_system_ref)
	if _info_panel_service:
		_info_panel_service.setup(creature_info_panel_ui, spell_info_panel_ui, item_info_panel_ui)
	if _player_info_service:
		_player_info_service.setup(player_info_panel)

	# Phase 10-B: hand_display にカードコールバックと参照を設定
	if hand_display:
		hand_display.set_card_callbacks(on_card_button_pressed, _on_card_info_from_hand)
		hand_display._card_selection_ui_ref = card_selection_ui
		hand_display._game_flow_manager_ref = game_flow_manager_ref

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

# === カード選択UI関連 ===
func show_card_selection_ui(current_player):
	if _card_selection_service:
		_card_selection_service.show_card_selection_ui(current_player)

# モード指定でカード選択UIを表示
func show_card_selection_ui_mode(current_player, mode: String):
	if _card_selection_service:
		_card_selection_service.show_card_selection_ui_mode(current_player, mode)

func hide_card_selection_ui():
	if _card_selection_service:
		_card_selection_service.hide_card_selection_ui()

# カードボタンが押された（card.gdから呼ばれる）
func on_card_button_pressed(card_index: int):
	# 入力ロックチェック（Callable注入: Phase 10-C）
	if _is_input_locked_cb.is_valid() and _is_input_locked_cb.call():
		return

	# 通知ポップアップがクリック待ち中なら無視
	if is_notification_popup_active():
		return

	# EventHub経由で発火（ルーティングはGSMが担当）
	if _ui_event_hub:
		_ui_event_hub.hand_card_tapped.emit(card_index)

## カードの情報表示リクエスト処理（card.gd の card_info_requested Signal から）
func _on_card_info_from_hand(card_data: Dictionary) -> void:
	# プレイヤーステータスダイアログが開いていたら閉じる
	if player_status_dialog and player_status_dialog.is_dialog_visible():
		player_status_dialog.hide_dialog()
	# 閲覧モードで表示
	show_card_info(card_data, -1, false)
	# 召喚/バトルフェーズ中はドミニオボタンを再表示（アイテムフェーズでは不要）
	if card_selection_ui and card_selection_ui.is_active:
		if card_selection_ui.selection_mode in ["summon", "battle"]:
			show_dominio_order_button()

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

# === 基本UI操作 ===
func update_ui(_current_player, current_phase):
	# プレイヤー情報パネルを更新
	if _player_info_service:
		_player_info_service.update_panels()
	
	# フェーズ表示を更新
	update_phase_display(current_phase)

# フェーズ表示を更新
func update_phase_display(phase):
	if _message_service:
		_message_service.update_phase_display(phase)

# ダイス結果を表示
func show_dice_result(value: int, _parent: Node = null):
	if _message_service:
		_message_service.show_dice_result(value)

## 通知ポップアップがアクティブ（クリック待ち中）かどうか
func is_notification_popup_active() -> bool:
	if _message_service:
		return _message_service.is_notification_popup_active()
	return false

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
	# EventHub経由で発火（GSMがDCHに接続）
	if _ui_event_hub:
		_ui_event_hub.dominio_cancel_requested.emit()

# === グローバルアクションボタン管理 ===

## ナビゲーションボタンを設定（推奨）
## 有効なCallableを渡したボタンのみ表示される
func enable_navigation(confirm_cb: Callable = Callable(), back_cb: Callable = Callable(), up_cb: Callable = Callable(), down_cb: Callable = Callable()):
	if _navigation_service:
		_navigation_service.enable_navigation(confirm_cb, back_cb, up_cb, down_cb)

## ナビゲーションボタンを全てクリア
func disable_navigation():
	if _navigation_service:
		_navigation_service.disable_navigation()


## ナビゲーション状態が保存されているか（info_panelから参照）
func is_nav_state_saved() -> bool:
	if _navigation_service:
		return _navigation_service.is_nav_state_saved()
	return false

## 現在のナビゲーション状態を保存（閲覧モード用）
## 既に保存済みの場合は上書きしない（連続閲覧対応）
func save_navigation_state():
	if not _navigation_service or _navigation_service.is_nav_state_saved():
		return
	# phase_commentを取得してNavigationServiceに設定
	var phase_comment = ""
	if phase_display and phase_display.has_method("get_current_action_prompt"):
		phase_comment = phase_display.get_current_action_prompt()
	_navigation_service.set_saved_phase_comment(phase_comment)
	_navigation_service.save_navigation_state()

## 保存したナビゲーション状態を復元
func restore_navigation_state():
	if not _navigation_service or not _navigation_service.is_nav_state_saved():
		return
	var phase_comment = _navigation_service.get_saved_phase_comment()
	_navigation_service.restore_navigation_state()
	# phase_commentを復元
	if phase_comment != "" and phase_display:
		phase_display.show_action_prompt(phase_comment)

## ナビゲーション保存状態をクリア（フェーズ切り替え時等）
func clear_navigation_saved_state():
	if _navigation_service:
		_navigation_service.clear_navigation_saved_state()

## 現在アクティブなフェーズのナビゲーション・フェーズコメントを復元
## 閲覧モードから戻る時に使用
## Primary: 保存されたナビ状態があれば復元
## Fallback: 保存がない場合、card_selection_ui にフェーズ固有の復元を依頼
func restore_current_phase():
	if _navigation_service and _navigation_service.is_nav_state_saved():
		restore_navigation_state()
		return
	# Fallback: save が無効化されている場合、フェーズ固有の復元
	if card_selection_ui and card_selection_ui.is_active:
		card_selection_ui.restore_navigation()

func register_confirm_action(callback: Callable, _text: String = ""):
	if _navigation_service:
		_navigation_service.register_confirm_action(callback, _text)

func register_back_action(callback: Callable, _text: String = ""):
	if _navigation_service:
		_navigation_service.register_back_action(callback, _text)

func register_arrow_actions(up_callback: Callable, down_callback: Callable):
	if _navigation_service:
		_navigation_service.register_arrow_actions(up_callback, down_callback)

func clear_confirm_action():
	if _navigation_service:
		_navigation_service.clear_confirm_action()

func clear_back_action():
	if _navigation_service:
		_navigation_service.clear_back_action()

func clear_arrow_actions():
	if _navigation_service:
		_navigation_service.clear_arrow_actions()

func clear_global_actions():
	if _navigation_service:
		_navigation_service.clear_global_actions()

# === 特殊ボタン（左下）API ===

## 特殊ボタンを設定（アルカナアーツ/ドミニオコマンド等）
func set_special_button(text: String, callback: Callable):
	if _navigation_service:
		_navigation_service.set_special_button(text, callback)

## 特殊ボタンをクリア
func clear_special_button():
	if _navigation_service:
		_navigation_service.clear_special_button()

func register_global_actions(confirm_callback: Callable, back_callback: Callable, _confirm_text: String = "", _back_text: String = ""):
	if _navigation_service:
		_navigation_service.register_global_actions(confirm_callback, back_callback, _confirm_text, _back_text)

# === 手札UI管理 ===

# 手札コンテナを初期化
func initialize_hand_container(container_layer: Node):
	if _card_selection_service:
		_card_selection_service.initialize_hand_container(container_layer)

# CardSystemのシグナルに接続
func connect_card_system_signals():
	if _card_selection_service:
		_card_selection_service.connect_card_system_signals()

# カード関連のシグナルハンドラ（HandDisplayに移行済み）

# 手札表示を更新
func update_hand_display(player_id: int):
	if _card_selection_service:
		_card_selection_service.update_hand_display(player_id)

# create_card_node は HandDisplayに移行済みのため削除

# rearrange_hand は HandDisplayに移行済みのため削除

## 敵カード選択モードの有効/無効切り替え
func set_enemy_card_selection_active(active: bool):
	if hand_display:
		hand_display.is_enemy_card_selection_active = active

## カード選択UIを有効化（手札データ指定）
func enable_card_selection(hand_data: Array, available_magic: int, player_id: int = 0):
	if card_selection_ui:
		card_selection_ui.enable_card_selection(hand_data, available_magic, player_id)

# ============ player_info_panel 委譲メソッド ============

## 現在のターンプレイヤーを設定
func set_current_turn(player_id: int):
	if player_info_panel and player_info_panel.has_method("set_current_turn"):
		player_info_panel.set_current_turn(player_id)

## プレイヤーランキングを取得
func get_player_ranking(player_id: int) -> int:
	if player_info_panel and player_info_panel.has_method("get_player_ranking"):
		return player_info_panel.get_player_ranking(player_id)
	return 0

# ============ phase_display 委譲メソッド ============

## フェーズラベルのテキストを設定
func set_phase_text(text: String):
	if _message_service:
		_message_service.set_phase_text(text)

## フェーズラベルのテキストを取得
func get_phase_text() -> String:
	if _message_service:
		return _message_service.get_phase_text()
	return ""

## ダイス結果を大きく表示
func show_big_dice_result(value: int, duration: float = 1.5):
	if _message_service:
		_message_service.show_big_dice_result(value, duration)

## ダイス結果（2個）を表示
func show_dice_result_double(dice1: int, dice2: int, total: int):
	if _message_service:
		_message_service.show_dice_result_double(dice1, dice2, total)

## ダイス結果（3個/フライ）を表示
func show_dice_result_triple(dice1: int, dice2: int, dice3: int, total: int):
	if _message_service:
		_message_service.show_dice_result_triple(dice1, dice2, dice3, total)

## ダイス結果（範囲刻印）を表示
func show_dice_result_range(curse_name: String, value: int):
	if _message_service:
		_message_service.show_dice_result_range(curse_name, value)

## トースト表示（短時間の通知メッセージ）
func show_toast(message: String, duration: float = 2.0):
	if _message_service:
		_message_service.show_toast(message, duration)

## アクション指示表示
func show_action_prompt(message: String, position: String = "center"):
	if _message_service:
		_message_service.show_action_prompt(message, position)

## アクション指示を非表示
func hide_action_prompt():
	if _message_service:
		_message_service.hide_action_prompt()

# ============ global_comment_ui 委譲メソッド ============

## グローバルコメント表示（クリック待ち）
func show_comment_and_wait(message: String, player_id: int = -1, force_click_wait: bool = false) -> void:
	if _message_service:
		await _message_service.show_comment_and_wait(message, player_id, force_click_wait)

## グローバルコメント表示（選択肢付き）
func show_choice_and_wait(message: String, player_id: int = -1, yes_text: String = "はい", no_text: String = "いいえ") -> bool:
	if _message_service:
		return await _message_service.show_choice_and_wait(message, player_id, yes_text, no_text)
	return false

## グローバルコメント表示（メッセージのみ、クリック待ちなし）
func show_comment_message(message: String) -> void:
	if _message_service:
		_message_service.show_comment_message(message)

## グローバルコメント非表示
func hide_comment_message() -> void:
	if _message_service:
		_message_service.hide_comment_message()

## 全てのインフォパネルを閉じる（フェーズ変更時に呼び出す）
func close_all_info_panels():
	if _info_panel_service:
		_info_panel_service.hide_all_info_panels(true)
	clear_navigation_saved_state()

## 全てのインフォパネルを閉じてナビゲーションをクリア（saved stateは保持）
## show_card_info内でのパネル切り替え時に使用
func _hide_all_info_panels_raw():
	# パネルを閉じる（clear_buttons=false: hide_panel内でのボタン操作を防ぐ）
	if _info_panel_service:
		_info_panel_service.hide_all_info_panels(false)
	# インフォパネルのロックを解除してからナビをクリア
	if _navigation_service:
		_navigation_service.unlock_info_panel_back()
	disable_navigation()
	clear_special_button()

## 全てのインフォパネルを閉じる（clear_buttons指定可能）
func hide_all_info_panels(clear_buttons: bool = true):
	if _navigation_service:
		_navigation_service.unlock_info_panel_back()
	if _info_panel_service:
		_info_panel_service.hide_all_info_panels(clear_buttons)

## いずれかのインフォパネルが表示中か
func is_any_info_panel_visible() -> bool:
	if _info_panel_service:
		return _info_panel_service.is_any_info_panel_visible()
	return false

## カード情報パネルを表示（ナビゲーションに触らない）
## ドミニオの土地プレビュー等、表示の一部として使用する場合用
func show_card_info_only(card_data: Dictionary, tile_index: int = -1):
	if _info_panel_service:
		_info_panel_service.show_card_info_only(card_data, tile_index)

## カード種別に応じたインフォパネルを表示（閲覧モード）
## ナビゲーション状態を自動保存し、パネルを閉じた時に復元する
func show_card_info(card_data: Dictionary, tile_index: int = -1, setup_buttons: bool = true):
	var card_type = card_data.get("type", "")

	# ナビゲーション状態を保存（連続閲覧時は最初の1回のみ）
	# 選択モードのパネルが表示中（pending_card_index >= 0）の場合は保存しない
	# → スペル/アイテムパネルの「使用しますか？」コールバックを誤保存しないため
	# → ×で閉じた時は fallback (card_selection_ui.restore_navigation) でフェーズ選択に戻る
	if not (card_selection_ui and card_selection_ui.pending_card_index >= 0):
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
	if panel and not setup_buttons:
		register_back_action(func():
			_hide_all_info_panels_raw()
			# 選択モードのパネルが開いていた場合（「使用しますか？」等）、
			# 保存状態をクリアしてフェーズ選択画面に戻す
			# （パネルなしで「使用しますか？」テキストだけ残る半端な状態を防止）
			if card_selection_ui and card_selection_ui.pending_card_index >= 0:
				card_selection_ui.pending_card_index = -1
				clear_navigation_saved_state()
			restore_current_phase()
			# カードのホバー状態を解除
			var card_script = load("res://scripts/card.gd")
			if card_script.currently_selected_card:
				card_script.currently_selected_card.deselect_card()
		, "閉じる")
		# インフォパネル表示中は×ボタンを保護
		if _navigation_service:
			_navigation_service.lock_info_panel_back()

		# 閲覧モード中のフェーズコメント表示
		var card_name = card_data.get("name", "")
		if _message_service and card_name != "":
			_message_service.show_action_prompt("%s の情報を閲覧中" % card_name)

## カード種別に応じたインフォパネルを表示（選択モード）
func show_card_selection(card_data: Dictionary, hand_index: int = -1,
		confirmation_text: String = "", restriction_reason: String = "",
		selection_mode: String = ""):
	if _info_panel_service:
		_info_panel_service.show_card_selection(card_data, hand_index, confirmation_text, restriction_reason, selection_mode)

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
	# Callable注入（Phase 10-C: board_system_refランタイム参照除去）
	if _has_owned_lands_cb.is_valid() and not _has_owned_lands_cb.call():
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

# ==== Phase 1-A: アクションメニュー表示/非表示（DominioOrderUIに委譲） ====

func show_action_menu(tile_index: int):
	if dominio_order_ui:
		dominio_order_ui.show_action_menu(tile_index)

func hide_action_menu():
	if dominio_order_ui:
		dominio_order_ui.hide_action_menu()

## アクションメニュー非表示（グローバルボタンクリア制御付き）
func hide_action_menu_keep_buttons():
	if dominio_order_ui:
		dominio_order_ui.hide_action_menu(false)

## 地形選択パネル表示
func show_terrain_selection(tile_index: int, current_element: String, cost: int, player_magic: int):
	if dominio_order_ui:
		dominio_order_ui.show_terrain_selection(tile_index, current_element, cost, player_magic)

## 地形選択パネル非表示
func hide_terrain_selection():
	if dominio_order_ui:
		dominio_order_ui.hide_terrain_selection()

## 地形ボタンのハイライト（上下キー選択用）
func highlight_terrain_button(selected_element: String):
	if dominio_order_ui:
		dominio_order_ui.highlight_terrain_button(selected_element)

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
	if _card_selection_service:
		return _card_selection_service.get_player_card_nodes(player_id)
	return []

# === プレイヤーパネル関連 ===

# プレイヤー情報パネルがクリックされたときのハンドラ
func _on_player_panel_clicked(player_id: int):
	# 他のインフォパネルが開いていたら閉じる
	if _info_panel_service:
		_info_panel_service.hide_all_info_panels(true)

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

# === Day 3 追加: クリーチャー更新ハンドラー ===

func on_creature_updated(tile_index: int, creature_data: Dictionary):
	# null チェック
	if not board_system_ref:
		push_error("[UIManager] board_system_ref が null")
		return

	# UI の creature 関連要素を自動更新
	if _info_panel_service and not creature_data.is_empty():
		_info_panel_service.update_display(creature_data)

	# 3D表示更新（Callable注入: Phase 10-C）
	if _update_tile_display_cb.is_valid():
		_update_tile_display_cb.call(tile_index)
