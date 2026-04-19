extends Control

# オンライン対戦ゲーム画面
# サーバーのgame_stateを受信して表示する最小実装
# Phase 3-1: 受信→表示

var _ws: WsClient
var _player_slot: int = -1
var _game_state: Dictionary = {}
var _current_phase: String = ""
var _active_player: int = -1
var _hand: Array = []
var _is_my_turn: bool = false

# UI
var _status_label: Label
var _board_label: Label
var _hand_label: Label
var _phase_label: Label
var _action_vbox: VBoxContainer
var _log_label: RichTextLabel


func _ready() -> void:
	# ロビーから引き継いだWebSocketとゲーム状態を取得
	if GameData.has_meta("online_ws"):
		_ws = GameData.get_meta("online_ws")
		GameData.remove_meta("online_ws")
		add_child(_ws)
		_ws.message_received.connect(_on_ws_message)
		_ws.disconnected.connect(_on_ws_disconnected)

	if GameData.has_meta("online_player_slot"):
		_player_slot = GameData.get_meta("online_player_slot")
		GameData.remove_meta("online_player_slot")

	if GameData.has_meta("online_game_state"):
		var initial_state: Variant = GameData.get_meta("online_game_state")
		GameData.remove_meta("online_game_state")
		if initial_state is Dictionary:
			_apply_game_state(initial_state)

	_build_ui()
	_update_display()


func _exit_tree() -> void:
	if _ws:
		_ws.disconnect_from_server()


# ===== WebSocketメッセージ処理 =====

func _on_ws_message(msg_type: String, data: Variant) -> void:
	_add_log("← %s" % msg_type)

	match msg_type:
		"game_state":
			_apply_game_state(data)
			_update_display()
		"turn_start":
			_on_turn_start(data)
		"your_hand":
			if data is Dictionary:
				_hand = data.get("hand", [])
				_update_hand_display()
		"dice_result":
			if data is Dictionary:
				_add_log("ダイス: %d" % int(data.get("result", 0)))
		"action_result":
			_on_action_result(data)
		"battle_start":
			_add_log("バトル開始！")
		"battle_result":
			_add_log("バトル終了")
			_on_action_result(data)
		"game_over":
			_on_game_over(data)
		"error":
			var err: String = data.message if data is Dictionary else str(data)
			_add_log("[ERROR] %s" % err)


func _on_ws_disconnected() -> void:
	_add_log("サーバーから切断されました")
	_set_status("切断")


# ===== ゲーム状態 =====

func _apply_game_state(data: Variant) -> void:
	if not data is Dictionary:
		return
	var state: Variant = data.get("state", data)
	if state is Dictionary:
		_game_state = state
		_active_player = int(state.get("active_player", -1))
		_current_phase = state.get("phase", "")


func _on_turn_start(data: Variant) -> void:
	if not data is Dictionary:
		return
	_active_player = int(data.get("active_player", -1))
	_is_my_turn = (_active_player == _player_slot)
	if data.has("hand"):
		_hand = data.get("hand", [])

	_current_phase = "spell"
	_add_log("--- ターン開始 (P%d)%s ---" % [_active_player, " [自分]" if _is_my_turn else ""])
	_update_display()
	_update_action_buttons()


func _on_action_result(data: Variant) -> void:
	if not data is Dictionary:
		return
	var action_data: Variant = data.get("data", data)
	if action_data is Dictionary:
		var phase: String = action_data.get("phase", "")
		if not phase.is_empty():
			_current_phase = phase
	_update_display()
	_update_action_buttons()


func _on_game_over(data: Variant) -> void:
	if not data is Dictionary:
		return
	var winner: int = int(data.get("winner", -1))
	var msg: String = "ゲーム終了！ 勝者: Player %d" % winner
	if winner == _player_slot:
		msg = "ゲーム終了！ あなたの勝ちです！"
	_add_log(msg)
	_set_status(msg)

	# 5秒後にロビーに戻る
	await get_tree().create_timer(5.0).timeout
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")


# ===== 操作送信 (Phase 3-3) =====

func _send_spell_pass() -> void:
	if _ws:
		_ws.send_msg("spell_pass", null)
		_add_log("→ spell_pass")


func _send_dice_roll() -> void:
	if _ws:
		_ws.send_msg("dice_roll", null)
		_add_log("→ dice_roll")


func _send_move_complete() -> void:
	if _ws:
		_ws.send_msg("move_complete", {"direction": -1})
		_add_log("→ move_complete")


func _send_pass() -> void:
	if _ws:
		_ws.send_msg("pass", null)
		_add_log("→ pass")


func _send_end_turn() -> void:
	if _ws:
		_ws.send_msg("end_turn", null)
		_add_log("→ end_turn")


func _send_summon(card_id: int) -> void:
	if _ws:
		_ws.send_msg("summon", {"card_id": card_id})
		_add_log("→ summon (card %d)" % card_id)


# ===== UI更新 =====

func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _add_log(text: String) -> void:
	print("[OnlineGame] %s" % text)
	if _log_label:
		_log_label.append_text(text + "\n")
		# 自動スクロール
		_log_label.scroll_to_line(_log_label.get_line_count() - 1)


func _update_display() -> void:
	# フェーズ表示
	if _phase_label:
		var my_turn_str: String = " [あなたのターン]" if _is_my_turn else " [相手のターン]"
		_phase_label.text = "Phase: %s | Active: P%d%s" % [_current_phase, _active_player, my_turn_str]

	# ボード表示
	if _board_label and _game_state.has("board"):
		var board: Array = _game_state.get("board", [])
		var board_text: String = "ボード (%d タイル):\n" % board.size()
		for i in range(board.size()):
			if not board[i] is Dictionary:
				continue
			var tile: Dictionary = board[i]
			var owner_idx: int = int(tile.get("owner_index", -1))
			if owner_idx >= 0:
				var creature_id: int = int(tile.get("creature_id", 0))
				var level: int = int(tile.get("level", 1))
				var down: String = " [DOWN]" if tile.get("is_down", false) else ""
				board_text += "  [%d] P%d: creature=%d lv=%d%s\n" % [i, owner_idx, creature_id, level, down]
		_board_label.text = board_text

	# プレイヤー情報
	if _status_label and _game_state.has("players"):
		var players: Array = _game_state.get("players", [])
		var player_text: String = ""
		for i in range(players.size()):
			if not players[i] is Dictionary:
				continue
			var p: Dictionary = players[i]
			var me: String = " ★" if i == _player_slot else ""
			player_text += "P%d%s: EP=%d pos=%d\n" % [
				i, me,
				int(p.get("ep", 0)),
				int(p.get("position", 0)),
			]
		_status_label.text = player_text

	_update_hand_display()


func _update_hand_display() -> void:
	if _hand_label:
		var text: String = "手札: "
		for card_id in _hand:
			text += "[%d] " % int(card_id)
		_hand_label.text = text


func _update_action_buttons() -> void:
	if not _action_vbox:
		return

	# 既存ボタンを削除
	for child in _action_vbox.get_children():
		child.queue_free()

	if not _is_my_turn:
		var wait_label: Label = Label.new()
		wait_label.text = "相手のターンです..."
		wait_label.add_theme_font_size_override("font_size", 48)
		_action_vbox.add_child(wait_label)
		return

	match _current_phase:
		"spell":
			_add_action_button("スペルパス", _send_spell_pass)
		"dice":
			_add_action_button("ダイスロール", _send_dice_roll)
		"move":
			_add_action_button("移動確定", _send_move_complete)
		"tile_action":
			# 手札からサモンボタンを生成
			for card_id in _hand:
				var cid: int = int(card_id)
				_add_action_button("サモン: %d" % cid, _send_summon.bind(cid))
			_add_action_button("パス", _send_pass)
		"end_turn":
			_add_action_button("ターン終了", _send_end_turn)


func _add_action_button(text: String, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 80)
	btn.add_theme_font_size_override("font_size", 42)
	btn.pressed.connect(callback)
	_action_vbox.add_child(btn)


# ===== UI構築 =====

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	add_child(main_hbox)

	# 左側: ゲーム情報
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 10)
	main_hbox.add_child(left_vbox)

	# 戻るボタン
	var back_btn: Button = Button.new()
	back_btn.text = "← 退出"
	back_btn.custom_minimum_size = Vector2(200, 60)
	back_btn.add_theme_font_size_override("font_size", 42)
	back_btn.pressed.connect(func(): get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn"))
	left_vbox.add_child(back_btn)

	_phase_label = Label.new()
	_phase_label.text = "Phase: ---"
	_phase_label.add_theme_font_size_override("font_size", 48)
	_phase_label.add_theme_color_override("font_color", Color.YELLOW)
	left_vbox.add_child(_phase_label)

	_status_label = Label.new()
	_status_label.text = "接続中..."
	_status_label.add_theme_font_size_override("font_size", 40)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	left_vbox.add_child(_status_label)

	_hand_label = Label.new()
	_hand_label.text = "手札: ---"
	_hand_label.add_theme_font_size_override("font_size", 40)
	_hand_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	left_vbox.add_child(_hand_label)

	_board_label = Label.new()
	_board_label.text = "ボード: ---"
	_board_label.add_theme_font_size_override("font_size", 36)
	_board_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_board_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_board_label)

	# 右側: アクション + ログ
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(500, 0)
	right_vbox.add_theme_constant_override("separation", 10)
	main_hbox.add_child(right_vbox)

	var action_label: Label = Label.new()
	action_label.text = "アクション"
	action_label.add_theme_font_size_override("font_size", 48)
	action_label.add_theme_color_override("font_color", Color.YELLOW)
	right_vbox.add_child(action_label)

	_action_vbox = VBoxContainer.new()
	_action_vbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(_action_vbox)

	var log_title: Label = Label.new()
	log_title.text = "ログ"
	log_title.add_theme_font_size_override("font_size", 42)
	right_vbox.add_child(log_title)

	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 32)
	right_vbox.add_child(_log_label)

	_add_log("オンラインゲーム画面を初期化")
