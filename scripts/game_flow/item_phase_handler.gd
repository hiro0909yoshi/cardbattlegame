# ItemPhaseHandler - アイテム/巻物選択フェーズの処理を担当
extends Node
class_name ItemPhaseHandler

## シグナル
signal item_phase_started()
signal item_phase_completed()
signal item_passed()  # アイテム未使用
signal item_used(item_card: Dictionary)

## 状態
enum State {
	INACTIVE,
	WAITING_FOR_SELECTION,  # アイテム選択待ち
	ITEM_APPLIED            # アイテム適用済み
}

var current_state: State = State.INACTIVE
var current_player_id: int = -1
var selected_item_card: Dictionary = {}
var item_used_this_battle: bool = false  # 1バトル1回制限

## 参照
var ui_manager = null
var game_flow_manager = null
var card_system = null
var player_system = null
var battle_system = null

func _ready():
	pass

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	battle_system = b_system if b_system else (flow_mgr.battle_system if flow_mgr else null)

## アイテムフェーズ開始
func start_item_phase(player_id: int):
	if current_state != State.INACTIVE:
		print("[ItemPhaseHandler] 既にアクティブです")
		return
	
	current_state = State.WAITING_FOR_SELECTION
	current_player_id = player_id
	item_used_this_battle = false
	selected_item_card = {}
	
	item_phase_started.emit()
	
	print("[ItemPhaseHandler] アイテムフェーズ開始: プレイヤー ", player_id + 1)
	
	# CPUの場合は簡易AI（現在は実装しない）
	if is_cpu_player(player_id):
		print("[ItemPhaseHandler] CPU: アイテムをパス")
		pass_item()
		return
	
	# 人間プレイヤーの場合はUI表示
	_show_item_selection_ui()

## アイテム選択UIを表示
func _show_item_selection_ui():
	if not ui_manager or not card_system or not player_system:
		print("[ItemPhaseHandler] 必要なシステムが初期化されていません")
		complete_item_phase()
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		print("[ItemPhaseHandler] プレイヤー情報が取得できません")
		complete_item_phase()
		return
	
	# 手札を取得
	var hand_data = card_system.get_all_cards_for_player(current_player.id)
	
	# アイテムカードのみフィルター
	var item_cards = []
	for card in hand_data:
		if card.get("type", "") == "item":
			item_cards.append(card)
	
	if item_cards.is_empty():
		print("[ItemPhaseHandler] 手札にアイテムカードがありません")
		complete_item_phase()
		return
	
	# アイテムカードのフィルター設定
	if ui_manager:
		ui_manager.card_selection_filter = "item"
		# 手札表示を更新してアイテムカード以外をグレーアウト
		if ui_manager.hand_display:
			ui_manager.hand_display.update_hand_display(current_player.id)
	
	# CardSelectionUIを使用してアイテム選択
	if ui_manager.card_selection_ui and ui_manager.card_selection_ui.has_method("show_selection"):
		ui_manager.card_selection_ui.show_selection(current_player, "item")

## アイテムを使用
func use_item(item_card: Dictionary):
	if current_state != State.WAITING_FOR_SELECTION:
		print("[ItemPhaseHandler] アイテム使用できる状態ではありません")
		return
	
	if item_used_this_battle:
		print("[ItemPhaseHandler] このバトル既にアイテムを使用しています")
		return
	
	# コストチェック
	if not _can_afford_item(item_card):
		print("[ItemPhaseHandler] 魔力が不足しています")
		return
	
	selected_item_card = item_card
	item_used_this_battle = true
	current_state = State.ITEM_APPLIED
	
	# コストを支払う
	var cost_data = item_card.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = cost_data
	
	if player_system:
		player_system.add_magic(current_player_id, -cost * 10)  # mp * 10G
		print("[ItemPhaseHandler] 魔力消費: %dG" % (cost * 10))
	
	# アイテムをカード使用（捨て札に）
	if card_system:
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == item_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	
	# アイテム使用シグナル
	item_used.emit(item_card)
	
	print("[ItemPhaseHandler] アイテム使用: %s" % item_card.get("name", "???"))
	
	# フェーズ完了
	complete_item_phase()

## アイテムをパス（使用しない）
func pass_item():
	if current_state != State.WAITING_FOR_SELECTION:
		return
	
	print("[ItemPhaseHandler] アイテムをパス")
	item_passed.emit()
	complete_item_phase()

## アイテムフェーズ完了
func complete_item_phase():
	if current_state == State.INACTIVE:
		return
	
	current_state = State.INACTIVE
	
	# フィルターをクリア
	if ui_manager:
		ui_manager.card_selection_filter = ""
		# 手札表示を更新してグレーアウトを解除
		if ui_manager.hand_display and player_system:
			var current_player = player_system.get_current_player()
			if current_player:
				ui_manager.hand_display.update_hand_display(current_player.id)
	
	item_phase_completed.emit()
	
	print("[ItemPhaseHandler] アイテムフェーズ完了")

## アイテムが使用可能か（コスト的に）
func _can_afford_item(item_card: Dictionary) -> bool:
	if not player_system:
		return false
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return false
	
	var cost_data = item_card.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = cost_data
	
	return current_player.magic_power >= cost * 10

## 選択されたアイテムを取得
func get_selected_item() -> Dictionary:
	return selected_item_card

## アイテムが使用されたか
func was_item_used() -> bool:
	return item_used_this_battle

## CPUプレイヤーかどうか
func is_cpu_player(player_id: int) -> bool:
	if not game_flow_manager:
		return false
	
	var cpu_settings = game_flow_manager.player_is_cpu
	var debug_mode = game_flow_manager.debug_manual_control_all
	
	if debug_mode:
		return false  # デバッグモードでは全員手動
	
	return player_id < cpu_settings.size() and cpu_settings[player_id]

## アクティブか
func is_item_phase_active() -> bool:
	return current_state != State.INACTIVE
