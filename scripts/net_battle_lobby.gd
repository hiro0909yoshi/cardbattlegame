extends Control

# ネット対戦ロビー画面
# サーバー認証 → WebSocket接続 → ルーム作成/参加 → ゲーム開始

# ===== ネットワーク =====
var _api: ApiClient
var _ws: WsClient
var _access_token: String = ""
var _refresh_token: String = ""
var _room_id: String = ""
var _is_host: bool = false
var _player_slot: int = -1

# ===== UI要素 =====
var _main_vbox: VBoxContainer
var _tab_container: TabContainer
var _rank_tab: Control
var _friend_tab: Control
var _room_id_input: LineEdit
var _player_count_option: OptionButton
var _status_label: Label
var _room_info_panel: VBoxContainer
var _room_players_label: Label
var _ready_button: Button
var _start_button: Button
var _is_ready: bool = false

# ===== データ =====
var _creature_images: Array[String] = []

# ===== 定数 =====
const PANEL_COLOR = Color(0.12, 0.12, 0.16, 0.75)
const SERVER_HOST: String = "localhost"
const SERVER_PORT: int = 8080
const CREATURES_IMAGE_PATH = "res://assets/images/creatures/"


func _ready():
	modulate = Color.WHITE
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	_load_creature_images()
	_build_card_background(viewport_size)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.position = Vector2.ZERO
	_main_vbox.size = viewport_size
	_main_vbox.add_theme_constant_override("separation", 0)
	add_child(_main_vbox)

	_build_top_bar()
	_build_tab_area()

	# ネットワーク初期化
	_api = ApiClient.new()
	add_child(_api)
	_api.registered.connect(_on_registered)
	_api.login_success.connect(_on_login_success)
	_api.login_failed.connect(_on_login_failed)

	_ws = WsClient.new()
	add_child(_ws)
	_ws.connected.connect(_on_ws_connected)
	_ws.disconnected.connect(_on_ws_disconnected)
	_ws.message_received.connect(_on_ws_message)

	# 自動認証開始
	_set_status("サーバーに接続中...")
	var user_id: String = GameData.player_data.user_id
	var display_name: String = GameData.player_data.profile.name
	_api.guest_register(user_id, display_name)


func _exit_tree() -> void:
	if _ws and _ws.is_connected_to_server():
		_ws.disconnect_from_server()


# ===== 認証コールバック =====

func _on_registered(_user_id: String, access_token: String, refresh_token: String) -> void:
	_access_token = access_token
	_refresh_token = refresh_token
	_set_status("認証完了、WebSocket接続中...")
	_ws.connect_to_server(SERVER_HOST, SERVER_PORT, _access_token)


func _on_login_success(access_token: String, refresh_token: String) -> void:
	_access_token = access_token
	_refresh_token = refresh_token
	_set_status("ログイン完了、WebSocket接続中...")
	_ws.connect_to_server(SERVER_HOST, SERVER_PORT, _access_token)


func _on_login_failed(error: String) -> void:
	if "Register" in error:
		_set_status("既存アカウントでログイン中...")
		_api.guest_login(GameData.player_data.user_id)
	else:
		_set_status("接続失敗: " + error)


# ===== WebSocket コールバック =====

func _on_ws_connected() -> void:
	_set_status("サーバー接続完了！")


func _on_ws_disconnected() -> void:
	_set_status("サーバーから切断されました")
	_room_id = ""
	_hide_room_info()


func _on_ws_message(msg_type: String, data: Variant) -> void:
	print("[NetLobby] ← %s" % msg_type)

	match msg_type:
		"room_created":
			_room_id = data.room_id if data is Dictionary else ""
			_is_host = true
			_set_status("ルーム作成: %s" % _room_id)
			_show_room_info()
		"room_state":
			_update_room_state(data)
		"game_state":
			_on_game_start(data)
		"error":
			var err_msg: String = data.message if data is Dictionary else str(data)
			_set_status("エラー: " + err_msg)


# ===== ルーム状態管理 =====

func _update_room_state(data: Variant) -> void:
	if not data is Dictionary:
		return

	var players: Array = data.get("players", [])
	var text: String = "ルーム: %s (%d人参加中)\n" % [_room_id, players.size()]
	for i in range(players.size()):
		var p: Dictionary = players[i] if players[i] is Dictionary else {}
		var name_str: String = p.get("display_name", "Player %d" % i)
		var ready_str: String = " [準備完了]" if p.get("ready", false) else ""
		text += "  %d. %s%s\n" % [i + 1, name_str, ready_str]

	if _room_players_label:
		_room_players_label.text = text

	_show_room_info()


func _on_game_start(data: Variant) -> void:
	GameData.set_meta("online_game_state", data)
	GameData.set_meta("online_ws", _ws)
	GameData.set_meta("online_access_token", _access_token)
	GameData.set_meta("online_player_slot", _player_slot)
	GameData.current_game_mode = "net_battle"

	remove_child(_ws)

	get_tree().call_deferred("change_scene_to_file", "res://scenes/OnlineGame.tscn")


# ===== UIボタン処理 =====

func _on_create_room_pressed():
	if not _ws or not _ws.is_connected_to_server():
		_set_status("サーバーに接続されていません")
		return

	var player_counts: Array[int] = [2, 3, 4]
	var max_players: int = player_counts[_player_count_option.get_selected_id()]

	_ws.send_msg("create_room", {
		"match_type": "friend",
		"max_players": max_players,
		"initial_magic": 1000,
		"target_magic": 8000,
	})
	_set_status("ル��ム作成中...")


func _on_join_room_pressed():
	if not _ws or not _ws.is_connected_to_server():
		_set_status("サーバーに接続されていません")
		return

	var room_id: String = _room_id_input.text.strip_edges()
	if room_id.is_empty():
		_set_status("ルームIDを入力してく��さい")
		return

	_room_id = room_id
	_is_host = false
	_ws.send_msg("join_room", {
		"room_id": room_id,
		"deck_id": "0",
	})
	_set_status("ルーム参加��...")


func _on_ready_pressed():
	if not _ws or not _ws.is_connected_to_server():
		return
	_is_ready = not _is_ready
	_ws.send_msg("set_ready", {"ready": _is_ready})
	if _ready_button:
		_ready_button.text = "準備取消" if _is_ready else "準備完了"


func _on_start_game_pressed():
	if not _ws or not _ws.is_connected_to_server():
		return
	if not _is_host:
		return
	_ws.send_msg("start_game", null)
	_set_status("ゲーム開始中...")


func _on_tab_selected(index: int):
	_tab_container.current_tab = index


func _on_back_pressed():
	if _ws and _ws.is_connected_to_server():
		_ws.disconnect_from_server()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")


func _on_rank_match_pressed():
	_set_status("ラ��クマッチは準備中です")


# ===== ステータス表示 =====

func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
	print("[NetLobby] %s" % text)


func _show_room_info() -> void:
	if _room_info_panel:
		_room_info_panel.visible = true


func _hide_room_info() -> void:
	if _room_info_panel:
		_room_info_panel.visible = false


# ===== UI構築 =====

func _build_top_bar():
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	top_hbox.custom_minimum_size = Vector2(0, 120)
	_main_vbox.add_child(top_hbox)

	var back_button = Button.new()
	back_button.text = "← 戻る"
	back_button.custom_minimum_size = Vector2(260, 100)
	back_button.add_theme_font_size_override("font_size", 54)
	back_button.pressed.connect(_on_back_pressed)
	top_hbox.add_child(back_button)

	var title_label = Label.new()
	title_label.text = "ネット対戦"
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hbox.add_child(title_label)

	var tab_hbox = HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 12)
	top_hbox.add_child(tab_hbox)

	var rank_tab_btn = Button.new()
	rank_tab_btn.text = "ランクマッ��"
	rank_tab_btn.custom_minimum_size = Vector2(420, 100)
	rank_tab_btn.add_theme_font_size_override("font_size", 60)
	rank_tab_btn.pressed.connect(_on_tab_selected.bind(0))
	tab_hbox.add_child(rank_tab_btn)

	var friend_tab_btn = Button.new()
	friend_tab_btn.text = "フレンドマッチ"
	friend_tab_btn.custom_minimum_size = Vector2(480, 100)
	friend_tab_btn.add_theme_font_size_override("font_size", 60)
	friend_tab_btn.pressed.connect(_on_tab_selected.bind(1))
	tab_hbox.add_child(friend_tab_btn)


func _build_tab_area():
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 48)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.custom_minimum_size = Vector2(0, 60)
	_main_vbox.add_child(_status_label)

	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 40)
	content_margin.add_theme_constant_override("margin_right", 40)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	_main_vbox.add_child(content_margin)

	var split = HBoxContainer.new()
	split.add_theme_constant_override("separation", 20)
	content_margin.add_child(split)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.tabs_visible = false
	split.add_child(_tab_container)

	_rank_tab = _build_rank_tab()
	_tab_container.add_child(_rank_tab)

	_friend_tab = _build_friend_tab()
	_tab_container.add_child(_friend_tab)

	_tab_container.current_tab = 1

	# ルーム情報パネル（右側）
	_room_info_panel = VBoxContainer.new()
	_room_info_panel.custom_minimum_size = Vector2(600, 0)
	_room_info_panel.visible = false
	split.add_child(_room_info_panel)

	var room_panel_bg = PanelContainer.new()
	room_panel_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var room_style = StyleBoxFlat.new()
	room_style.bg_color = PANEL_COLOR
	room_style.content_margin_left = 30
	room_style.content_margin_right = 30
	room_style.content_margin_top = 30
	room_style.content_margin_bottom = 30
	room_panel_bg.add_theme_stylebox_override("panel", room_style)
	_room_info_panel.add_child(room_panel_bg)

	var room_vbox = VBoxContainer.new()
	room_vbox.add_theme_constant_override("separation", 20)
	room_panel_bg.add_child(room_vbox)

	_room_players_label = Label.new()
	_room_players_label.text = ""
	_room_players_label.add_theme_font_size_override("font_size", 48)
	_room_players_label.add_theme_color_override("font_color", Color.WHITE)
	_room_players_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_vbox.add_child(_room_players_label)

	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 20)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	room_vbox.add_child(button_hbox)

	_ready_button = Button.new()
	_ready_button.text = "準備完了"
	_ready_button.custom_minimum_size = Vector2(300, 100)
	_ready_button.add_theme_font_size_override("font_size", 54)
	_ready_button.pressed.connect(_on_ready_pressed)
	button_hbox.add_child(_ready_button)

	_start_button = Button.new()
	_start_button.text = "ゲーム開始"
	_start_button.custom_minimum_size = Vector2(300, 100)
	_start_button.add_theme_font_size_override("font_size", 54)
	_start_button.add_theme_color_override("font_color", Color.YELLOW)
	_start_button.pressed.connect(_on_start_game_pressed)
	button_hbox.add_child(_start_button)


func _build_rank_tab() -> Control:
	var panel = PanelContainer.new()
	panel.name = "RankMatch"
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)

	var rank_label = Label.new()
	rank_label.text = "ランクマッチは準備中です"
	rank_label.add_theme_font_size_override("font_size", 66)
	rank_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(rank_label)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var match_button = Button.new()
	match_button.text = "【 マッチング開始 】"
	match_button.custom_minimum_size = Vector2(560, 120)
	match_button.add_theme_font_size_override("font_size", 66)
	match_button.add_theme_color_override("font_color", Color.YELLOW)
	match_button.pressed.connect(_on_rank_match_pressed)
	vbox.add_child(match_button)

	return panel


func _build_friend_tab() -> Control:
	var panel = PanelContainer.new()
	panel.name = "FriendMatch"
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)

	var create_label = Label.new()
	create_label.text = "■ ルーム作成"
	create_label.add_theme_font_size_override("font_size", 66)
	create_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(create_label)

	var create_hbox = HBoxContainer.new()
	create_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(create_hbox)

	var create_pc_label = Label.new()
	create_pc_label.text = "対戦人数:"
	create_pc_label.add_theme_font_size_override("font_size", 60)
	create_pc_label.add_theme_color_override("font_color", Color.WHITE)
	create_hbox.add_child(create_pc_label)

	_player_count_option = OptionButton.new()
	_player_count_option.custom_minimum_size = Vector2(240, 80)
	_player_count_option.add_theme_font_size_override("font_size", 60)
	_player_count_option.get_popup().add_theme_font_size_override("font_size", 60)
	_player_count_option.add_item("2人", 0)
	_player_count_option.add_item("3人", 1)
	_player_count_option.add_item("4人", 2)
	_player_count_option.select(0)
	create_hbox.add_child(_player_count_option)

	var create_button = Button.new()
	create_button.text = "ルーム作成"
	create_button.custom_minimum_size = Vector2(380, 100)
	create_button.add_theme_font_size_override("font_size", 60)
	create_button.add_theme_color_override("font_color", Color.YELLOW)
	create_button.pressed.connect(_on_create_room_pressed)
	create_hbox.add_child(create_button)

	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator)

	var join_label = Label.new()
	join_label.text = "■ ルーム参加"
	join_label.add_theme_font_size_override("font_size", 66)
	join_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(join_label)

	var join_hbox = HBoxContainer.new()
	join_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(join_hbox)

	var id_label = Label.new()
	id_label.text = "ルー���ID:"
	id_label.add_theme_font_size_override("font_size", 60)
	id_label.add_theme_color_override("font_color", Color.WHITE)
	join_hbox.add_child(id_label)

	_room_id_input = LineEdit.new()
	_room_id_input.custom_minimum_size = Vector2(440, 80)
	_room_id_input.add_theme_font_size_override("font_size", 60)
	_room_id_input.placeholder_text = "IDを入力..."
	join_hbox.add_child(_room_id_input)

	var join_button = Button.new()
	join_button.text = "参加"
	join_button.custom_minimum_size = Vector2(240, 100)
	join_button.add_theme_font_size_override("font_size", 60)
	join_button.pressed.connect(_on_join_room_pressed)
	join_hbox.add_child(join_button)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	return panel


# ===== 背景 =====

func _load_creature_images():
	_creature_images.clear()
	var elements: Array[String] = ["fire", "water", "earth", "wind", "neutral"]
	for element in elements:
		var dir_path: String = CREATURES_IMAGE_PATH + element + "/"
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".png"):
					_creature_images.append(dir_path + file_name)
				file_name = dir.get_next()


func _build_card_background(viewport_size: Vector2) -> void:
	if _creature_images.is_empty():
		var bg = ColorRect.new()
		bg.color = Color(0.08, 0.08, 0.12, 1.0)
		bg.position = Vector2.ZERO
		bg.size = viewport_size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		return

	var shuffled: Array[String] = _creature_images.duplicate()
	shuffled.shuffle()
	if shuffled.size() > 55:
		shuffled.resize(55)

	var card_width := 360
	var card_height := 360
	var cols: int = int(ceil(viewport_size.x / card_width)) + 1
	var rows: int = int(ceil(viewport_size.y / card_height)) + 1

	var bg_container = Control.new()
	bg_container.position = Vector2.ZERO
	bg_container.size = viewport_size
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_container)

	var bg_base = ColorRect.new()
	bg_base.color = Color(0.05, 0.05, 0.08, 1.0)
	bg_base.position = Vector2.ZERO
	bg_base.size = viewport_size
	bg_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(bg_base)

	var img_index := 0
	for row in range(rows):
		for col in range(cols):
			if shuffled.is_empty():
				break
			var texture: Texture2D = load(shuffled[img_index % shuffled.size()])
			if texture:
				var tex_rect = TextureRect.new()
				tex_rect.texture = texture
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				tex_rect.position = Vector2(col * card_width, row * card_height)
				tex_rect.size = Vector2(card_width, card_height)
				tex_rect.modulate = Color(0.75, 0.75, 0.75, 0.8)
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bg_container.add_child(tex_rect)
			img_index += 1

	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.05, 0.15)
	overlay.position = Vector2.ZERO
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(overlay)
