extends Control

# ネット対戦ロビー画面
# ランクマッチ / フレンドマッチ をタブで切り替え

# ===== UI要素 =====
var _main_vbox: VBoxContainer
var _tab_container: TabContainer
var _rank_tab: Control
var _friend_tab: Control
var _room_id_input: LineEdit
var _player_count_option: OptionButton

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
	# TODO: NetworkService.start_matchmaking() を呼ぶ
	print("ランクマッチ マッチング開始（未実装）")


func _on_create_room_pressed():
	var player_counts: Array[int] = [2, 3, 4]
	var max_players = player_counts[_player_count_option.get_selected_id()]

	# ルームID生成（4桁数字）
	var room_id = _generate_room_id()

	# TODO: NetworkService.create_room(max_players, room_id) を呼ぶ
	# TODO: サーバー側で重複チェック、重複時は再生成
	print("ルーム作成: ID=%s, 最大%d人" % [room_id, max_players])

	# ホストとして準備画面へ遷移
	GameData.set_meta("net_battle_mode", {
		"is_host": true,
		"max_players": max_players,
		"room_id": room_id
	})
	get_tree().call_deferred("change_scene_to_file", "res://scenes/NetBattleSetup.tscn")


func _on_join_room_pressed():
	var room_id = _room_id_input.text.strip_edges()
	if room_id.is_empty():
		_show_error_dialog("ルームIDを入力してください")
		return

	# TODO: NetworkService.join_room(room_id) を呼ぶ
	# TODO: サーバーでルーム存在チェック、存在しない場合はエラー表示
	print("ルーム参加: %s" % room_id)

	# ゲストとして準備画面へ遷移
	GameData.set_meta("net_battle_mode", {
		"is_host": false,
		"max_players": 4,
		"room_id": room_id
	})
	get_tree().call_deferred("change_scene_to_file", "res://scenes/NetBattleSetup.tscn")


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
