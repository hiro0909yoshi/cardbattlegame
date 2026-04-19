extends Node

## NetworkBridge: WebSocket受信を3Dゲームシステムに反映するブリッジ
## 原則: 状態はサーバー側、クライアントは表示のみ（受信→表示→送信）

const TAG: String = "NetBridge"

var _system_manager: GameSystemManager = null
var _ws_client: Node = null
var _player_slot: int = 0
var _current_game_state: Dictionary = {}

var _board_system: Node = null
var _player_system: Node = null
var _card_system: Node = null
var _game_flow_manager: Node = null
var _ui_manager: Node = null

var _action_overlay: CanvasLayer = null
var _action_buttons: Array[Button] = []


func _ready() -> void:
	pass


func setup(system_manager: GameSystemManager) -> void:
	_system_manager = system_manager

	_ws_client = GameData.get_meta("online_ws") if GameData.has_meta("online_ws") else null
	_player_slot = GameData.get_meta("online_player_slot") if GameData.has_meta("online_player_slot") else 0
	_current_game_state = GameData.get_meta("online_game_state") if GameData.has_meta("online_game_state") else {}

	_board_system = _system_manager.board_system_3d
	_player_system = _system_manager.player_system
	_card_system = _system_manager.card_system
	_game_flow_manager = _system_manager.game_flow_manager
	_ui_manager = _system_manager.ui_manager

	if _ws_client and _ws_client.get_parent() == null:
		add_child(_ws_client)

	if _ws_client:
		if not _ws_client.is_connected("message_received", Callable(self, "_on_ws_message")):
			_ws_client.connect("message_received", Callable(self, "_on_ws_message"))
		if not _ws_client.is_connected("disconnected", Callable(self, "_on_ws_disconnected")):
			_ws_client.connect("disconnected", Callable(self, "_on_ws_disconnected"))

	_create_action_overlay()

	# ネット対戦: 自分以外の手札はサーバーから来ない → ローカル乱数手札をクリア
	_clear_opponent_hands()

	if _current_game_state.size() > 0:
		_apply_game_state(_current_game_state)


func _on_ws_message(msg_type: String, data: Variant) -> void:
	var data_dict: Dictionary = data if data is Dictionary else {}
	match msg_type:
		"game_state":
			_apply_game_state(data_dict)
		"turn_start":
			_handle_turn_start(data_dict)
		"your_hand":
			_handle_your_hand(data_dict)
		"dice_result":
			_handle_dice_result(data_dict)
		"action_result":
			_handle_action_result(data_dict)
		"battle_start":
			_handle_battle_start(data_dict)
		"battle_result":
			_handle_battle_result(data_dict)
		"game_over":
			_handle_game_over(data_dict)
		_:
			GameLogger.info(TAG, "Unknown WS msg type: %s" % msg_type)


func _on_ws_disconnected() -> void:
	GameLogger.warn(TAG, "WebSocket connection closed")


# ============================================================================
# Message Handlers (受信→表示のみ。状態書き換えは行わない)
# ============================================================================

func _apply_game_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_current_game_state = state
	# TODO: 表示更新（player info/board）はUI側のシグナル経由で実装


func _handle_turn_start(data: Dictionary) -> void:
	if not data.has("active_player"):
		return
	var active_player_slot: int = int(data.get("active_player", -1))
	GameLogger.info(TAG, "Turn started: Player %d" % active_player_slot)

	if data.has("hand"):
		_current_game_state["hand"] = data.get("hand", [])

	if active_player_slot == _player_slot:
		_show_action_buttons(data)
	else:
		_hide_action_buttons()


func _handle_your_hand(data: Dictionary) -> void:
	# サーバーは "hand" キー（[]int カードID）を送る
	var raw_hand: Variant = data.get("hand", data.get("cards", []))
	if not raw_hand is Array:
		return
	_current_game_state["hand"] = raw_hand
	_apply_hand_to_card_system(raw_hand)
	GameLogger.info(TAG, "Your hand updated (%d cards)" % raw_hand.size())


func _apply_hand_to_card_system(card_ids: Array) -> void:
	if not _system_manager or not _system_manager.card_system:
		return
	var card_system: Node = _system_manager.card_system
	if not card_system.player_hands.has(_player_slot):
		card_system.player_hands[_player_slot] = {"data": []}

	var hand_data: Array[Dictionary] = []
	for cid in card_ids:
		var card: Dictionary = CardLoader.get_card_by_id(int(cid))
		if not card.is_empty():
			hand_data.append(card)

	card_system.player_hands[_player_slot]["data"] = hand_data

	if _ui_manager and _ui_manager.has_method("update_hand_display"):
		_ui_manager.update_hand_display(_player_slot)


func _clear_opponent_hands() -> void:
	if not _system_manager or not _system_manager.card_system:
		return
	var card_system: Node = _system_manager.card_system
	for pid in card_system.player_hands.keys():
		if int(pid) != _player_slot:
			card_system.player_hands[pid] = {"data": []}
	GameLogger.info(TAG, "Cleared opponent hands (my_slot=%d)" % _player_slot)


func _handle_dice_result(data: Dictionary) -> void:
	var dice_value: int = int(data.get("dice_value", data.get("result", 0)))
	GameLogger.info(TAG, "Dice result: %d" % dice_value)


func _handle_action_result(_data: Dictionary) -> void:
	# 状態は次の game_state で同期されるためログのみ
	GameLogger.info(TAG, "Action result received")


func _handle_battle_start(_data: Dictionary) -> void:
	GameLogger.info(TAG, "Battle started")


func _handle_battle_result(_data: Dictionary) -> void:
	GameLogger.info(TAG, "Battle result received")


func _handle_game_over(data: Dictionary) -> void:
	if not data.has("winner"):
		return
	var winner: int = int(data.get("winner", -1))
	GameLogger.info(TAG, "Game over! Winner: Player %d" % winner)

	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# ============================================================================
# Action UI and Sending
# ============================================================================

func _create_action_overlay() -> void:
	_action_overlay = CanvasLayer.new()
	_action_overlay.layer = 100
	add_child(_action_overlay)

	var button_container: VBoxContainer = VBoxContainer.new()
	button_container.anchor_left = 0.5
	button_container.anchor_top = 1.0
	button_container.anchor_right = 0.5
	button_container.anchor_bottom = 1.0
	button_container.offset_top = -100
	button_container.offset_left = -150
	button_container.custom_minimum_size = Vector2(300, 80)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_overlay.add_child(button_container)

	_action_buttons.clear()
	_hide_action_buttons()


func _show_action_buttons(turn_data: Dictionary) -> void:
	if not _action_overlay:
		return

	var phase: String = String(turn_data.get("phase", ""))

	for btn in _action_buttons:
		btn.queue_free()
	_action_buttons.clear()

	var button_container: Node = _action_overlay.get_child(0) if _action_overlay.get_child_count() > 0 else null
	if not button_container:
		return

	match phase:
		"spell":
			_create_button("スペルパス", Callable(self, "_on_spell_pass"), button_container)
		"dice":
			_create_button("ダイスロール", Callable(self, "_on_dice_roll"), button_container)
		"move":
			_create_button("移動確定", Callable(self, "_on_move_complete"), button_container)
		"tile_action":
			var hand: Array = _current_game_state.get("hand", [])
			for i in range(hand.size()):
				var card_id: int = int(hand[i])
				_create_button("召喚 #%d" % card_id, Callable(self, "_on_summon").bind(card_id), button_container)
			_create_button("パス", Callable(self, "_on_tile_action_pass"), button_container)
		"end_turn":
			_create_button("ターン終了", Callable(self, "_on_end_turn"), button_container)

	_action_overlay.visible = true


func _hide_action_buttons() -> void:
	if _action_overlay:
		_action_overlay.visible = false

	for btn in _action_buttons:
		btn.queue_free()
	_action_buttons.clear()


func _create_button(label: String, callback: Callable, container: Node) -> void:
	var btn: Button = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(280, 40)
	btn.connect("pressed", callback)
	container.add_child(btn)
	_action_buttons.append(btn)


# ============================================================================
# Action Senders（メッセージタイプ直送、サーバー仕様に合わせる）
# ============================================================================

func _on_spell_pass() -> void:
	_send("spell_pass", null)
	_hide_action_buttons()


func _on_dice_roll() -> void:
	_send("dice_roll", null)
	_hide_action_buttons()


func _on_move_complete() -> void:
	_send("move_complete", {"direction": -1})
	_hide_action_buttons()


func _on_summon(card_id: int) -> void:
	_send("summon", {"card_id": card_id})
	_hide_action_buttons()


func _on_tile_action_pass() -> void:
	_send("pass", null)
	_hide_action_buttons()


func _on_end_turn() -> void:
	_send("end_turn", null)
	_hide_action_buttons()


func _send(msg_type: String, data: Variant) -> void:
	if not _ws_client:
		GameLogger.warn(TAG, "WebSocket client not available")
		return
	GameLogger.info(TAG, "Send: %s" % msg_type)
	_ws_client.send_msg(msg_type, data)
