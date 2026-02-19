extends Node
class_name CardSelectionService

## シグナル
signal card_selected(card_index: int)
signal pass_button_pressed()

## コンポーネント参照
var _card_selection_ui = null  # CardSelectionUI（循環参照回避のため型なし）
var _hand_display: HandDisplay = null

## システム参照（HandDisplay 更新用）
var _card_system_ref: CardSystem = null
var _player_system_ref: PlayerSystem = null

## フィルター状態
var card_selection_filter: String = ""
var assist_target_elements: Array = []
var blocked_item_types: Array = []
var excluded_card_index: int = -1
var excluded_card_id: String = ""


## 初期化
func setup(card_selection_ui, hand_display: HandDisplay, card_system: CardSystem = null, player_system: PlayerSystem = null) -> void:
	_card_selection_ui = card_selection_ui
	_hand_display = hand_display
	_card_system_ref = card_system
	_player_system_ref = player_system

	# CardSelectionUI の card_selected を直接リレー（Phase 8-M）
	if _card_selection_ui and _card_selection_ui.has_signal("card_selected"):
		if not _card_selection_ui.card_selected.is_connected(_relay_card_selected):
			_card_selection_ui.card_selected.connect(_relay_card_selected)


## ============================================================================
## CardSelectionUI 委譲メソッド
## ============================================================================

## カード選択UIを表示
func show_card_selection_ui(current_player) -> void:
	if _card_selection_ui and _card_selection_ui.has_method("show_selection"):
		_card_selection_ui.show_selection(current_player, "summon")


## モード指定でカード選択UIを表示
func show_card_selection_ui_mode(current_player, mode: String) -> void:
	if _card_selection_ui and _card_selection_ui.has_method("show_selection"):
		_card_selection_ui.show_selection(current_player, mode)


## カード選択UIを非表示
func hide_card_selection_ui() -> void:
	if _card_selection_ui and _card_selection_ui.has_method("hide_selection"):
		_card_selection_ui.hide_selection()


## ============================================================================
## フィルター管理
## ============================================================================

## フィルターをクリア
func clear_card_selection_filter() -> void:
	card_selection_filter = ""


## ============================================================================
## HandDisplay 委譲メソッド
## ============================================================================

## 手札コンテナを初期化
func initialize_hand_container(container_layer: Node) -> void:
	if _hand_display:
		_hand_display.initialize(container_layer, _card_system_ref, _player_system_ref)


## CardSystemのシグナルに接続
func connect_card_system_signals() -> void:
	if _hand_display:
		_hand_display.connect_card_system_signals()


## 手札表示を更新
func update_hand_display(player_id: int) -> void:
	if _hand_display:
		_hand_display.update_hand_display(player_id)


## 手札カードノードを取得
func get_player_card_nodes(player_id: int) -> Array:
	if _hand_display:
		return _hand_display.get_player_card_nodes(player_id)
	return []


## ============================================================================
## card_selected リレー（CardSelectionUI → CardSelectionService、Phase 8-M）
## ============================================================================

## CardSelectionUI.card_selected からのリレー
## ビジネスロジック層（GameFlowManager）は CardSelectionService.card_selected を subscribe する
func _relay_card_selected(card_index: int) -> void:
	card_selected.emit(card_index)
