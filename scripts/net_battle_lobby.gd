extends Control

# ネット対戦ロビー画面
# ランクマッチ / フレンドマッチ をタブで切り替え

# ===== ネットワーク =====
var _api: ApiClient
var _ws: WsClient
var _access_token: String = ""
var _room_id: String = ""
var _is_host: bool = false

# ===== UI要素 =====
var _main_vbox: VBoxContainer
var _tab_container: TabContainer
var _rank_tab: Control
var _friend_tab: Control
var _room_id_input: LineEdit
var _player_count_option: OptionButton

# ===== 定数 =====
# サーバー接続先は NetConfig (autoload) から取得

# ===== データ =====
var _creature_images: Array[String] = []

# ===== 色定義 =====
const PANEL_COLOR = Color(0.12, 0.12, 0.16, 0.75)
const TAB_ACTIVE_COLOR = Color(0.3, 0.5, 0.8, 1.0)
const TAB_INACTIVE_COLOR = Color(0.25, 0.25, 0.30, 1.0)

# ===== パス定義 =====
const CREATURES_IMAGE_PATH = "res://assets/images/creatures/"


func _ready():
	modulate = Color.WHITE

	var viewport_size = get_viewport().get_visible_rect().size

	# 背景: クリーチャーカード画像タイリング
	_load_creature_images()
	_build_card_background(viewport_size)

	# ルート VBox レイアウト
	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.position = Vector2.ZERO
	_main_vbox.size = viewport_size
	_main_vbox.add_theme_constant_override("separation", 0)
	add_child(_main_vbox)

	# UI構築
	_build_top_bar()
	_build_tab_area()

	# ネットワーク初期化
	_api = ApiClient.new()
	add_child(_api)
	_api.registered.connect(_on_registered)
	_api.login_success.connect(_on_login_success)
	_api.login_failed.connect(_on_login_failed)
	_api.deck_saved.connect(_on_deck_saved)

	_ws = WsClient.new()
	add_child(_ws)
	_ws.connected.connect(_on_ws_connected)
	_ws.disconnected.connect(_on_ws_disconnected)
	_ws.message_received.connect(_on_ws_message)

	_api.guest_register(GameData.player_data.user_id, GameData.player_data.profile.name)
	print("ネット対戦ロビーを初期化しました")


func _build_top_bar():
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	top_hbox.custom_minimum_size = Vector2(0, 120)
	_main_vbox.add_child(top_hbox)

	# 戻るボタン
	var back_button = Button.new()
	back_button.text = "← 戻る"
	back_button.custom_minimum_size = Vector2(260, 100)
	back_button.add_theme_font_size_override("font_size", 54)
	back_button.pressed.connect(_on_back_pressed)
	top_hbox.add_child(back_button)

	# サーバー設定ボタン
	var config_button = Button.new()
	config_button.text = "⚙"
	config_button.custom_minimum_size = Vector2(120, 100)
	config_button.add_theme_font_size_override("font_size", 54)
	config_button.pressed.connect(_on_server_config_pressed)
	top_hbox.add_child(config_button)

	# タイトル
	var title_label = Label.new()
	title_label.text = "ネット対戦"
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hbox.add_child(title_label)

	# 右側：タブ切替ボタン
	var tab_hbox = HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 12)
	top_hbox.add_child(tab_hbox)

	var rank_tab_btn = Button.new()
	rank_tab_btn.text = "ランクマッチ"
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
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 40)
	content_margin.add_theme_constant_override("margin_right", 40)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	_main_vbox.add_child(content_margin)

	# タブコンテンツ
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.tabs_visible = false  # タブヘッダーはトップバーのボタンで制御
	content_margin.add_child(_tab_container)

	# ランクマッチタブ
	_rank_tab = _build_rank_tab()
	_tab_container.add_child(_rank_tab)

	# フレンドマッチタブ
	_friend_tab = _build_friend_tab()
	_tab_container.add_child(_friend_tab)

	# デフォルトはフレンドマッチ
	_tab_container.current_tab = 1


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

	# ランク情報
	var rank_info_hbox = HBoxContainer.new()
	rank_info_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(rank_info_hbox)

	var rank_label = Label.new()
	rank_label.text = "現在のランク: シルバー I"
	rank_label.add_theme_font_size_override("font_size", 66)
	rank_label.add_theme_color_override("font_color", Color.WHITE)
	rank_info_hbox.add_child(rank_label)

	var rate_label = Label.new()
	rate_label.text = "レート: 10.0"
	rate_label.add_theme_font_size_override("font_size", 66)
	rate_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	rank_info_hbox.add_child(rate_label)

	# 対戦人数選択
	var player_count_hbox = HBoxContainer.new()
	player_count_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(player_count_hbox)

	var pc_label = Label.new()
	pc_label.text = "対戦人数:"
	pc_label.add_theme_font_size_override("font_size", 66)
	pc_label.add_theme_color_override("font_color", Color.WHITE)
	player_count_hbox.add_child(pc_label)

	var rank_player_option = OptionButton.new()
	rank_player_option.custom_minimum_size = Vector2(240, 80)
	rank_player_option.add_theme_font_size_override("font_size", 66)
	rank_player_option.get_popup().add_theme_font_size_override("font_size", 66)
	rank_player_option.add_item("2人", 0)
	rank_player_option.add_item("4人", 1)
	rank_player_option.select(0)
	player_count_hbox.add_child(rank_player_option)

	# ルール表示
	var rule_label = Label.new()
	rule_label.text = "ルール: スタンダード（固定）"
	rule_label.add_theme_font_size_override("font_size", 60)
	rule_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(rule_label)

	# スペーサー
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# マッチング開始ボタン
	var match_hbox = HBoxContainer.new()
	match_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(match_hbox)

	var match_button = Button.new()
	match_button.text = "【 マッチング開始 】"
	match_button.custom_minimum_size = Vector2(560, 120)
	match_button.add_theme_font_size_override("font_size", 66)
	match_button.add_theme_color_override("font_color", Color.YELLOW)
	match_button.pressed.connect(_on_rank_match_pressed)
	match_hbox.add_child(match_button)

	# 未実装注記
	var note_label = Label.new()
	note_label.text = "※ バックエンド未接続のためマッチングは動作しません"
	note_label.add_theme_font_size_override("font_size", 40)
	note_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note_label)

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

	# ===== ルーム作成セクション =====
	var create_label = Label.new()
	create_label.text = "■ ルーム作成"
	create_label.add_theme_font_size_override("font_size", 66)
	create_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(create_label)

	var create_hbox = HBoxContainer.new()
	create_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(create_hbox)

	# 対戦人数
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
	_player_count_option.select(2)  # デフォルト4人
	create_hbox.add_child(_player_count_option)

	# ルーム作成ボタン
	var create_button = Button.new()
	create_button.text = "ルーム作成"
	create_button.custom_minimum_size = Vector2(380, 100)
	create_button.add_theme_font_size_override("font_size", 60)
	create_button.add_theme_color_override("font_color", Color.YELLOW)
	create_button.pressed.connect(_on_create_room_pressed)
	create_hbox.add_child(create_button)

	# セパレーター
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator)

	# ===== ルーム参加セクション =====
	var join_label = Label.new()
	join_label.text = "■ ルーム参加"
	join_label.add_theme_font_size_override("font_size", 66)
	join_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(join_label)

	var join_hbox = HBoxContainer.new()
	join_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(join_hbox)

	var id_label = Label.new()
	id_label.text = "ルームID:"
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

	# スペーサー
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	return panel


# ===== コールバック =====

func _on_tab_selected(index: int):
	_tab_container.current_tab = index


func _on_back_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")


func _on_rank_match_pressed():
	print("ランクマッチ マッチング開始（未実装）")


func _on_create_room_pressed():
	if not _ws or not _ws.is_connected_to_server():
		_show_error_dialog("サーバーに接続されていません")
		return

	var player_counts: Array[int] = [2, 3, 4]
	var max_players = player_counts[_player_count_option.get_selected_id()]

	_is_host = true
	_ws.send_msg("create_room", {
		"match_type": "friend",
		"max_players": max_players,
		"initial_magic": 1000,
		"target_magic": 8000,
		"initial_cards": GameConstants.INITIAL_HAND_SIZE,
	})
	print("ルーム作成送信: 最大%d人" % max_players)


func _on_join_room_pressed():
	if not _ws or not _ws.is_connected_to_server():
		_show_error_dialog("サーバーに接続されていません")
		return

	var room_id = _room_id_input.text.strip_edges()
	if room_id.is_empty():
		_show_error_dialog("ルームIDを入力してください")
		return

	_room_id = room_id
	_is_host = false
	_ws.send_msg("join_room", {
		"room_id": room_id,
		"deck_id": "0",
	})
	print("ルーム参加送信: %s" % room_id)


# ===== 背景 =====

## クリーチャー画像パスを収集
func _load_creature_images():
	_creature_images.clear()
	var elements: Array[String] = ["fire", "water", "earth", "wind", "neutral"]
	for element in elements:
		var dir_path = CREATURES_IMAGE_PATH + element + "/"
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".png"):
					_creature_images.append(dir_path + file_name)
				file_name = dir.get_next()
	print("背景用クリーチャー画像: %d枚" % _creature_images.size())


## クリーチャーカード画像をグリッド状に並べた背景を生成
func _build_card_background(viewport_size: Vector2) -> void:
	if _creature_images.is_empty():
		# フォールバック: 単色背景
		var bg = ColorRect.new()
		bg.color = Color(0.08, 0.08, 0.12, 1.0)
		bg.position = Vector2.ZERO
		bg.size = viewport_size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		return

	# 画像をシャッフルして55枚に制限
	var shuffled: Array[String] = _creature_images.duplicate()
	shuffled.shuffle()
	if shuffled.size() > 55:
		shuffled.resize(55)

	# カードサイズ（元画像200x200、大きめに表示）
	var card_width := 360
	var card_height := 360
	var cols = int(ceil(viewport_size.x / card_width)) + 1
	var rows = int(ceil(viewport_size.y / card_height)) + 1

	# 背景コンテナ
	var bg_container = Control.new()
	bg_container.position = Vector2.ZERO
	bg_container.size = viewport_size
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_container)

	# 暗い背景ベース
	var bg_base = ColorRect.new()
	bg_base.color = Color(0.05, 0.05, 0.08, 1.0)
	bg_base.position = Vector2.ZERO
	bg_base.size = viewport_size
	bg_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(bg_base)

	# カード画像を並べる
	var img_index := 0
	for row in range(rows):
		for col in range(cols):
			if shuffled.is_empty():
				break

			var texture = load(shuffled[img_index % shuffled.size()])
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

	# 暗いオーバーレイ（UIの視認性確保）
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.05, 0.15)
	overlay.position = Vector2.ZERO
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(overlay)


# ===== ヘルパー =====

## 4桁数字のルームIDを生成
func _generate_room_id() -> String:
	return "%04d" % randi_range(0, 9999)


func _show_error_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "エラー"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _on_server_config_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "サーバー接続設定"
	dialog.ok_button_text = "保存"
	dialog.add_cancel_button("キャンセル")
	var reset_btn: Button = dialog.add_button("初期値", true, "reset")

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	dialog.add_child(vbox)

	var host_label := Label.new()
	host_label.text = "ホスト (IPアドレス)"
	host_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(host_label)

	var host_input := LineEdit.new()
	host_input.text = NetConfig.server_host
	host_input.placeholder_text = "例: 192.168.3.10"
	host_input.custom_minimum_size = Vector2(600, 80)
	host_input.add_theme_font_size_override("font_size", 40)
	vbox.add_child(host_input)

	var port_label := Label.new()
	port_label.text = "ポート"
	port_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(port_label)

	var port_input := LineEdit.new()
	port_input.text = str(NetConfig.server_port)
	port_input.placeholder_text = "例: 8080"
	port_input.custom_minimum_size = Vector2(300, 80)
	port_input.add_theme_font_size_override("font_size", 40)
	vbox.add_child(port_input)

	var hint := Label.new()
	hint.text = "初期値: %s:%d\n保存後、アプリを再起動すると新しい設定で接続します。" % [NetConfig.DEFAULT_HOST, NetConfig.DEFAULT_PORT]
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint)

	add_child(dialog)

	dialog.confirmed.connect(func():
		var new_host: String = host_input.text.strip_edges()
		var new_port: int = int(port_input.text.strip_edges())
		if new_host == "" or new_port <= 0:
			_show_error_dialog("ホスト/ポートの値が不正です")
			return
		NetConfig.set_server(new_host, new_port)
		_show_error_dialog("保存しました。アプリを再起動してください。")
	)

	dialog.custom_action.connect(func(action: StringName):
		if action == &"reset":
			host_input.text = NetConfig.DEFAULT_HOST
			port_input.text = str(NetConfig.DEFAULT_PORT)
	)

	dialog.popup_centered(Vector2(800, 700))


var _navigating_to_setup: bool = false


func _navigate_to_setup(is_host: bool, initial_state: Variant = null) -> void:
	_navigating_to_setup = true
	remove_child(_ws)
	GameData.set_meta("online_ws", _ws)
	GameData.set_meta("net_battle_mode", {
		"is_host": is_host,
		"room_id": _room_id,
		"max_players": 4,
	})
	if initial_state is Dictionary:
		GameData.set_meta("online_room_state", initial_state)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/NetBattleSetup.tscn")


func _exit_tree() -> void:
	if _navigating_to_setup:
		return
	if _ws and _ws.is_connected_to_server():
		_ws.disconnect_from_server()


# ===== ネットワークコールバック =====

func _on_registered(_user_id: String, access_token: String, _refresh_token: String) -> void:
	print("[NetLobby] 登録成功、WS接続開始")
	_access_token = access_token
	_upload_current_deck()
	_ws.connect_to_server(NetConfig.server_host, NetConfig.server_port, _access_token)


func _on_login_success(access_token: String, _refresh_token: String) -> void:
	print("[NetLobby] ログイン成功、WS接続開始")
	_access_token = access_token
	_upload_current_deck()
	_ws.connect_to_server(NetConfig.server_host, NetConfig.server_port, _access_token)


## 現在のデッキをサーバーに保存（ゲーム開始前に必須）
## GameData.get_current_deck() の {card_id: count} を配列 [id, id, ...] に変換して送信
func _upload_current_deck() -> void:
	var deck: Dictionary = GameData.get_current_deck()
	var cards_dict: Dictionary = deck.get("cards", {})
	var deck_name: String = String(deck.get("name", "Deck"))
	var cards_array: Array = []
	for card_id_key in cards_dict.keys():
		var count: int = int(cards_dict[card_id_key])
		var card_id: int = int(card_id_key)
		for i in range(count):
			cards_array.append(card_id)
	if cards_array.is_empty():
		print("[NetLobby] デッキが空のためサーバー保存をスキップ")
		return
	print("[NetLobby] デッキをサーバーに保存: slot=%d, %d枚" % [GameData.selected_deck_index, cards_array.size()])
	_api.save_deck(_access_token, GameData.selected_deck_index, deck_name, cards_array)


func _on_deck_saved(success: bool, error: String) -> void:
	if success:
		print("[NetLobby] デッキ保存成功")
	else:
		print("[NetLobby] デッキ保存失敗: %s" % error)


func _on_login_failed(error: String) -> void:
	print("[NetLobby] 認証失敗: %s" % error)
	if "Register" in error:
		_api.guest_login(GameData.player_data.user_id)
	else:
		_show_error_dialog("サーバー接続失敗: " + error)


func _on_ws_connected() -> void:
	print("[NetLobby] サーバー接続完了")


func _on_ws_disconnected() -> void:
	print("[NetLobby] サーバー切断")


func _on_ws_message(msg_type: String, data: Variant) -> void:
	print("[NetLobby] ← %s" % msg_type)
	match msg_type:
		"room_created":
			if data is Dictionary:
				_room_id = data.get("room_id", "")
			_is_host = true
			print("[NetLobby] ルーム作成完了: %s" % _room_id)
			_navigate_to_setup(true, data)
		"room_state":
			if data is Dictionary and not _room_id.is_empty():
				print("[NetLobby] room_state受信 → セットアップ画面へ")
				_navigate_to_setup(false, data)
		"game_state":
			print("[NetLobby] game_state受信（ロビーでは無視）")
		"error":
			var err_msg: String = data.message if data is Dictionary else str(data)
			_show_error_dialog("エラー: " + err_msg)
