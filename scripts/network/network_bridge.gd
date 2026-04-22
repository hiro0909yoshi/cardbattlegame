extends Node

## NetworkBridge: WebSocket ↔ GameFlowManager の橋渡し
## 原則: ゲームロジックはクライアント（GFM + 既存システム）が計算、サーバーは検証+リレー
## 受信 → GFM.on_server_*() → 既存UI（turn_started / phase_changed 等のシグナル経由）
## 送信 → GFM.net_action_requested シグナル → _send(msg_type, data)

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


func _ready() -> void:
	pass


func setup(system_manager: GameSystemManager) -> void:
	_system_manager = system_manager

	_ws_client = GameData.get_meta("online_ws") if GameData.has_meta("online_ws") else null
	_player_slot = GameData.get_meta("online_player_slot") if GameData.has_meta("online_player_slot") else 0
	_current_game_state = GameData.get_meta("online_game_state") if GameData.has_meta("online_game_state") else {}
	GameLogger.info(TAG, "setup: slot=%d" % _player_slot)

	_board_system = _system_manager.board_system_3d
	_player_system = _system_manager.player_system
	_card_system = _system_manager.card_system
	_game_flow_manager = _system_manager.game_flow_manager
	_ui_manager = _system_manager.ui_manager

	# GFM をネット対戦モードに設定（自律動作を抑制）
	if _game_flow_manager and _game_flow_manager.has_method("set_is_net_battle"):
		_game_flow_manager.set_is_net_battle(true, _player_slot)
		# GFMからの送信リクエストを受けてサーバーに転送
		if _game_flow_manager.has_signal("net_action_requested"):
			if not _game_flow_manager.net_action_requested.is_connected(_on_net_action_requested):
				_game_flow_manager.net_action_requested.connect(_on_net_action_requested)

	if _ws_client and _ws_client.get_parent() == null:
		add_child(_ws_client)

	if _ws_client:
		if not _ws_client.is_connected("message_received", Callable(self, "_on_ws_message")):
			_ws_client.connect("message_received", Callable(self, "_on_ws_message"))
		if not _ws_client.is_connected("disconnected", Callable(self, "_on_ws_disconnected")):
			_ws_client.connect("disconnected", Callable(self, "_on_ws_disconnected"))

	# ネット対戦: ローカルで生成された初期手札をクリア（サーバーの game_state / turn_start で上書きされる）
	_clear_all_local_hands()

	if _current_game_state.size() > 0:
		_apply_game_state(_current_game_state)
		# 初期 turn_start 相当を GFM に発火（NetSetup 画面で受信した turn_start は破棄されているため）
		_emit_initial_turn_start_from_state(_current_game_state)


## meta game_state から初期ターン情報を抽出して GFM に通知
## NetSetup 画面で受信した turn_start は破棄されているため、game_state から再構築
func _emit_initial_turn_start_from_state(data: Dictionary) -> void:
	if not _game_flow_manager or not _game_flow_manager.has_method("on_server_turn_started"):
		return
	var state: Dictionary = data
	if data.has("state") and data["state"] is Dictionary:
		state = data["state"]

	var active_player: int = int(state.get("active_player", 0))
	var turn_data: Dictionary = {
		"active_player": active_player,
		"phase": String(state.get("phase", "spell")),
		"turn": int(state.get("current_turn", 1)),
	}

	# active_player の手札を抽出
	var players: Variant = state.get("players", [])
	if players is Array and active_player < players.size():
		var p: Variant = players[active_player]
		if p is Dictionary:
			turn_data["hand"] = p.get("hand", [])

	GameLogger.info(TAG, "初期turn_start発火: active=%d phase=%s" % [active_player, turn_data["phase"]])
	_game_flow_manager.on_server_turn_started(turn_data)


func _clear_all_local_hands() -> void:
	if not _system_manager or not _system_manager.card_system:
		return
	var card_system: Node = _system_manager.card_system
	for pid in card_system.player_hands.keys():
		card_system.player_hands[pid] = {"data": []}
	if _ui_manager and _ui_manager.has_method("update_hand_display"):
		_ui_manager.update_hand_display(0)
	GameLogger.info(TAG, "Cleared all local hands (waiting for server turn_start)")


# ============================================================================
# 送信側: GFM から net_action_requested を受けてサーバー送信
# ============================================================================

func _on_net_action_requested(msg_type: String, data: Variant) -> void:
	_send(msg_type, data)


func _send(msg_type: String, data: Variant) -> void:
	if not _ws_client:
		GameLogger.warn(TAG, "WebSocket client not available")
		return
	GameLogger.info(TAG, "Send: %s" % msg_type)
	_ws_client.send_msg(msg_type, data)


# ============================================================================
# 受信側: WSメッセージを GFM に渡す
# ============================================================================

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
		"action_broadcast":
			_handle_action_broadcast(data_dict)
		"battle_start":
			_handle_battle_start(data_dict)
		"battle_result":
			_handle_battle_result(data_dict)
		"game_over":
			_handle_game_over(data_dict)
		"action_error":
			var err_code: String = String(data_dict.get("code", "unknown"))
			var err_msg: String = String(data_dict.get("message", ""))
			GameLogger.warn(TAG, "action_error from server: [%s] %s" % [err_code, err_msg])
		_:
			GameLogger.info(TAG, "Unknown WS msg type: %s" % msg_type)


func _on_ws_disconnected() -> void:
	GameLogger.warn(TAG, "WebSocket connection closed")


# ============================================================================
# Message Handlers
# ============================================================================

## game_state: ゲーム開始時・再接続時の初期状態スナップショット
## サーバー構造: { "state": { "active_player": N, "players": [ { "hand": [...] } ], ... } }
func _apply_game_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	_current_game_state = data

	var state: Dictionary = data
	if data.has("state") and data["state"] is Dictionary:
		state = data["state"]

	var players: Variant = state.get("players", [])
	if players is Array:
		# 全プレイヤーの手札を CardSystem に反映（表示切替は後段）
		for i in range(players.size()):
			var p: Variant = players[i]
			if p is Dictionary:
				var raw_hand: Variant = p.get("hand", [])
				if raw_hand is Array:
					_write_hand_to_card_system(raw_hand, i)

	# active_player の手札を画面に表示
	var active_player_slot: int = int(state.get("active_player", -1))
	if active_player_slot >= 0 and _ui_manager and _ui_manager.has_method("update_hand_display"):
		_ui_manager.update_hand_display(active_player_slot)
		GameLogger.info(TAG, "Applied hands, display=slot %d" % active_player_slot)


## turn_start: 新ターン開始通知
func _handle_turn_start(data: Dictionary) -> void:
	if not data.has("active_player"):
		return
	var active_player_slot: int = int(data.get("active_player", -1))
	GameLogger.info(TAG, "turn_start: P%d phase=%s" % [active_player_slot, String(data.get("phase", ""))])

	# 手札をローカルに反映（ターン保持者分）
	# 変更なしの場合は UI 再描画をスキップ（card_index リセット防止）
	if data.has("hand") and active_player_slot >= 0:
		var raw_hand: Variant = data.get("hand", [])
		if raw_hand is Array:
			if _is_hand_unchanged(raw_hand, active_player_slot):
				GameLogger.info(TAG, "turn_start hand: 変更なし、UI再描画スキップ (%d cards)" % raw_hand.size())
			else:
				_apply_hand_to_card_system(raw_hand, active_player_slot)

	# GFM にターン開始を通知（既存シグナル経由でUIが動く）
	if _game_flow_manager and _game_flow_manager.has_method("on_server_turn_started"):
		_game_flow_manager.on_server_turn_started(data)


## your_hand: 自分がターン保持者の時に個別送信される手札
func _handle_your_hand(data: Dictionary) -> void:
	var raw_hand: Variant = data.get("hand", data.get("cards", []))
	if not raw_hand is Array:
		return
	# 現在のCardSystemの手札と比較し、変わっていなければUI再描画をスキップ
	# （カード選択中に手札UIをリセットすると is_selectable が失われ、召喚できなくなる）
	if _is_hand_unchanged(raw_hand, _player_slot):
		GameLogger.info(TAG, "your_hand: 変更なし、UI再描画スキップ (%d cards)" % raw_hand.size())
		return
	_apply_hand_to_card_system(raw_hand, _player_slot)
	GameLogger.info(TAG, "your_hand updated (%d cards)" % raw_hand.size())


## 現在の手札と比較して同じならtrue
func _is_hand_unchanged(new_card_ids: Array, player_id: int) -> bool:
	if not _system_manager or not _system_manager.card_system:
		return false
	var card_system: Node = _system_manager.card_system
	if not card_system.player_hands.has(player_id):
		return false
	var current_data: Array = card_system.player_hands[player_id].get("data", [])
	if current_data.size() != new_card_ids.size():
		return false
	for i in range(current_data.size()):
		var cur_id: int = int(current_data[i].get("id", -1))
		var new_id: int = int(new_card_ids[i])
		if cur_id != new_id:
			return false
	return true


func _apply_hand_to_card_system(card_ids: Array, player_id: int) -> void:
	_write_hand_to_card_system(card_ids, player_id)
	if _ui_manager and _ui_manager.has_method("update_hand_display"):
		_ui_manager.update_hand_display(player_id)


## 表示更新なしで CardSystem に書き込む
func _write_hand_to_card_system(card_ids: Array, player_id: int) -> void:
	if not _system_manager or not _system_manager.card_system:
		return
	var card_system: Node = _system_manager.card_system
	if not card_system.player_hands.has(player_id):
		card_system.player_hands[player_id] = {"data": []}

	var hand_data: Array[Dictionary] = []
	for cid in card_ids:
		var card: Dictionary = CardLoader.get_card_by_id(int(cid))
		if not card.is_empty():
			hand_data.append(card)

	card_system.player_hands[player_id]["data"] = hand_data


## dice_result: サーバー生成のダイス値
func _handle_dice_result(data: Dictionary) -> void:
	var dice_value: int = int(data.get("dice_value", data.get("value", data.get("result", 0))))
	GameLogger.info(TAG, "dice_result: %d" % dice_value)
	if _game_flow_manager and _game_flow_manager.has_method("on_server_dice_result"):
		_game_flow_manager.on_server_dice_result(data)


## action_result: 全員に配信されるアクション結果（他プレイヤー・自分共通）
## サーバーペイロード: {"player": int, "action_type": string, "data": {...}, "turn_number": int, "state_version": int}
func _handle_action_result(data: Dictionary) -> void:
	var action_type: String = String(data.get("action_type", ""))
	var player: int = int(data.get("player", -1))
	GameLogger.info(TAG, "action_result: player=%d action=%s" % [player, action_type])
	if _game_flow_manager and _game_flow_manager.has_method("on_server_action_broadcast"):
		_game_flow_manager.on_server_action_broadcast(data)


## action_broadcast: 旧名称互換（現サーバーは action_result で送信）
func _handle_action_broadcast(data: Dictionary) -> void:
	if _game_flow_manager and _game_flow_manager.has_method("on_server_action_broadcast"):
		_game_flow_manager.on_server_action_broadcast(data)


func _handle_battle_start(_data: Dictionary) -> void:
	GameLogger.info(TAG, "battle_start received")


func _handle_battle_result(_data: Dictionary) -> void:
	GameLogger.info(TAG, "battle_result received")


func _handle_game_over(data: Dictionary) -> void:
	var winner: int = int(data.get("winner", -1))
	GameLogger.info(TAG, "game_over: winner=%d" % winner)
	if _game_flow_manager and _game_flow_manager.has_method("on_server_game_over"):
		_game_flow_manager.on_server_game_over(data)
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
