extends Control

# ネット対戦準備画面（フレンドマッチ）
# ソロバトル準備画面と同様のUI構成
# ホスト: マップ・ルール設定 + 対戦開始ボタン
# ゲスト: 読み取り専用 + 準備完了ボタン

# ===== UI要素 =====
var _main_vbox: VBoxContainer
var _book_buttons: Array[Button] = []
var _map_buttons: Array[Button] = []
var _rule_preset_option: OptionButton
var _initial_ep_spin: SpinBox
var _target_tep_spin: SpinBox
var _max_turns_spin: SpinBox
var _action_button: Button  # ホスト=対戦開始 / ゲスト=準備完了
var _map_preview: TextureRect
var _player_slots: Array[Dictionary] = []  # [{name_label, ready_label}, ...]
var _player_preview_viewports: Array[SubViewport] = []  # 各プレイヤーのSubViewport
var _player_preview_char_nodes: Array[Node] = []  # 各キャラノード（差し替え用）

# ===== データ =====
var _selected_deck_index: int = 0
var _selected_map_id: String = ""
var _selected_rule_preset: String = "standard"
var _maps: Array[Dictionary] = []
var _map_preview_cache: Dictionary = {}
var _is_host: bool = true  # ホストかゲストか
var _max_players: int = 4  # 最大プレイヤー数
var _local_ready: bool = false

# プレイヤーデータ（ネットワーク接続時に更新される）
var _players: Array[Dictionary] = []  # [{id, name, is_ready}, ...]

# ===== 色定義 =====
const PANEL_COLOR = Color(0.18, 0.18, 0.22, 0.55)
const HIGHLIGHT_COLOR = Color(0.3, 0.5, 0.8, 0.8)
const READY_COLOR = Color(0.3, 0.8, 0.3, 1.0)
const NOT_READY_COLOR = Color(0.5, 0.5, 0.5, 1.0)
const WAITING_COLOR = Color(0.4, 0.4, 0.4, 0.6)

# ===== パス定義 =====
const MAPS_PATH = "res://data/master/maps/"


func _ready():
	modulate = Color.WHITE

	var viewport_size = get_viewport().get_visible_rect().size

	# 背景: CastleEnvironmentを3Dレンダリング
	_build_castle_background(viewport_size)

	# メタデータからモード判定
	if GameData.has_meta("net_battle_mode"):
		var mode_data = GameData.get_meta("net_battle_mode")
		_is_host = mode_data.get("is_host", true)
		_max_players = mode_data.get("max_players", 4)

	# ルート VBox レイアウト
	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.position = Vector2.ZERO
	_main_vbox.size = viewport_size
	_main_vbox.add_theme_constant_override("separation", 0)
	add_child(_main_vbox)

	# データ読み込み
	_load_maps()

	# ダミープレイヤーを設定（ネットワーク未接続時のテスト用）
	_setup_dummy_players()

	# UI構築
	_build_top_bar()
	_build_content_area()

	print("ネット対戦準備画面を初期化しました（ホスト=%s, 最大%d人）" % [str(_is_host), _max_players])


func _build_top_bar():
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	top_hbox.custom_minimum_size = Vector2(0, 100)
	_main_vbox.add_child(top_hbox)

	# 退出ボタン
	var back_button = Button.new()
	back_button.text = "← 退出"
	back_button.custom_minimum_size = Vector2(180, 80)
	back_button.add_theme_font_size_override("font_size", 42)
	back_button.pressed.connect(_on_back_pressed)
	top_hbox.add_child(back_button)

	# タイトル
	var title_label = Label.new()
	title_label.text = "対戦準備（フレンドマッチ）"
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hbox.add_child(title_label)

	# 右スペーサー
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	top_hbox.add_child(spacer)


func _build_content_area():
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	_main_vbox.add_child(content_margin)

	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 20)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content_hbox)

	# 左パネル：ブック選択 + プレイヤーリスト
	var left_vbox = _build_left_panel()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.4
	content_hbox.add_child(left_vbox)

	# 右パネル：マップ選択 + ルール設定
	var right_vbox = _build_right_panel()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.6
	content_hbox.add_child(right_vbox)

	# 下部：対戦開始 / 準備完了ボタン
	_build_bottom_area()


func _build_left_panel() -> Control:
	var left_panel = PanelContainer.new()
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	left_panel.add_theme_stylebox_override("panel", style)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 16)
	left_panel.add_child(left_vbox)

	# ===== ブック選択 =====
	var book_label = Label.new()
	book_label.text = "■ ブック選択"
	book_label.add_theme_font_size_override("font_size", 48)
	book_label.add_theme_color_override("font_color", Color.WHITE)
	left_vbox.add_child(book_label)

	# ブック選択エリア（左: ボタン一覧、右: プレビュー）
	var book_area_hbox = HBoxContainer.new()
	book_area_hbox.add_theme_constant_override("separation", 16)
	book_area_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(book_area_hbox)

	# 左側: ブックボタン一覧
	var book_scroll = ScrollContainer.new()
	book_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_area_hbox.add_child(book_scroll)

	var book_grid = GridContainer.new()
	book_grid.columns = 2
	book_grid.add_theme_constant_override("h_separation", 60)
	book_grid.add_theme_constant_override("v_separation", 30)
	book_scroll.add_child(book_grid)

	# デッキボタンを生成
	for i in range(GameData.player_data.decks.size()):
		var book_button = Button.new()
		var deck = GameData.player_data.decks[i]
		var deck_name = deck.get("name", "ブック%d" % (i + 1))
		var card_count = deck.get("cards", {}).size()
		book_button.text = "%s\n(%d枚)" % [deck_name, card_count]
		book_button.custom_minimum_size = Vector2(390, 176)
		book_button.add_theme_font_size_override("font_size", 36)
		book_button.pressed.connect(_on_deck_selected.bind(i))
		book_grid.add_child(book_button)
		_book_buttons.append(book_button)

	# 右側: ブックプレビュー（将来実装用のプレースホルダー）
	var book_preview_panel = PanelContainer.new()
	book_preview_panel.custom_minimum_size = Vector2(400, 0)
	book_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var book_preview_style = StyleBoxFlat.new()
	book_preview_style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
	book_preview_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	book_preview_style.set_border_width_all(1)
	book_preview_panel.add_theme_stylebox_override("panel", book_preview_style)
	book_area_hbox.add_child(book_preview_panel)

	# 最初のデッキを選択状態に
	_selected_deck_index = GameData.selected_deck_index
	_update_book_highlight()

	# ===== プレイヤーリスト =====
	left_vbox.add_child(VSeparator.new())

	var player_label = Label.new()
	player_label.text = "■ プレイヤー"
	player_label.add_theme_font_size_override("font_size", 48)
	player_label.add_theme_color_override("font_color", Color.WHITE)
	player_label.custom_minimum_size = Vector2(0, 70)
	left_vbox.add_child(player_label)

	# プレイヤースロット（各行: 名前 + 準備完了マーク + キャラプレビュー）
	var player_list_vbox = VBoxContainer.new()
	player_list_vbox.add_theme_constant_override("separation", 12)
	player_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(player_list_vbox)

	for slot_index in range(_max_players):
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 12)
		slot_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		player_list_vbox.add_child(slot_hbox)

		# 左側: プレイヤー情報（番号 + 名前 + 準備完了）
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot_hbox.add_child(info_vbox)

		# プレイヤー番号 + 名前（1行目）
		var name_hbox = HBoxContainer.new()
		name_hbox.add_theme_constant_override("separation", 8)
		info_vbox.add_child(name_hbox)

		var num_label = Label.new()
		num_label.text = "P%d:" % (slot_index + 1)
		num_label.add_theme_font_size_override("font_size", 48)
		num_label.add_theme_color_override("font_color", Color.WHITE)
		name_hbox.add_child(num_label)

		var name_label = Label.new()
		name_label.add_theme_font_size_override("font_size", 48)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_hbox.add_child(name_label)

		# 準備完了マーク
		var ready_label = Label.new()
		ready_label.add_theme_font_size_override("font_size", 48)
		ready_label.custom_minimum_size = Vector2(100, 0)
		ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_hbox.add_child(ready_label)

		_player_slots.append({
			"name_label": name_label,
			"ready_label": ready_label
		})

		# 右側: キャラプレビュー（SubViewportContainer）
		var svc = SubViewportContainer.new()
		svc.custom_minimum_size = Vector2(200, 150)
		svc.stretch = true
		svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_hbox.add_child(svc)

		var sv = SubViewport.new()
		sv.size = Vector2i(200, 150)
		sv.transparent_bg = false
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.own_world_3d = true

		# 背景 + ライト
		var world_env = WorldEnvironment.new()
		var env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.1, 0.1, 0.12, 1.0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		env.ambient_light_energy = 0.8
		world_env.environment = env
		sv.add_child(world_env)

		var light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, 30, 0)
		light.light_energy = 1.2
		sv.add_child(light)

		# カメラ
		var camera = Camera3D.new()
		camera.position = Vector3(0, 1.2, 11.0)
		camera.rotation_degrees = Vector3(2, 0, 0)
		camera.fov = 28
		camera.current = true
		sv.add_child(camera)

		# 未参加スロットは描画不要
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED

		svc.add_child(sv)

		_player_preview_viewports.append(sv)
		_player_preview_char_nodes.append(null)

	# 自分のキャラプレビューを表示（P1 = 現在はNecromancer固定）
	_update_player_preview(0, "res://scenes/Characters/Necromancer.tscn")

	_update_player_display()

	return left_panel


func _build_right_panel() -> Control:
	var right_panel = PanelContainer.new()
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	right_panel.add_theme_stylebox_override("panel", style)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	# ===== 上段：マップ選択 + プレビュー（横並び） =====
	var map_top_hbox = HBoxContainer.new()
	map_top_hbox.add_theme_constant_override("separation", 16)
	map_top_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_top_hbox.size_flags_stretch_ratio = 1.0
	right_vbox.add_child(map_top_hbox)

	# 左側：マップ選択リスト
	var map_list_vbox = VBoxContainer.new()
	map_list_vbox.add_theme_constant_override("separation", 8)
	map_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_list_vbox.size_flags_stretch_ratio = 0.4
	map_top_hbox.add_child(map_list_vbox)

	var map_label = Label.new()
	map_label.text = "■ マップ選択"
	map_label.add_theme_font_size_override("font_size", 48)
	map_label.add_theme_color_override("font_color", Color.WHITE)
	map_list_vbox.add_child(map_label)

	# ホストのみ注釈
	if not _is_host:
		var host_only_label = Label.new()
		host_only_label.text = "（ホストが選択中）"
		host_only_label.add_theme_font_size_override("font_size", 32)
		host_only_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		map_list_vbox.add_child(host_only_label)

	var map_scroll = ScrollContainer.new()
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_list_vbox.add_child(map_scroll)

	var map_vbox = VBoxContainer.new()
	map_vbox.add_theme_constant_override("separation", 28)
	map_scroll.add_child(map_vbox)

	for map_data in _maps:
		var map_button = Button.new()
		map_button.text = "%s (%dマス)" % [map_data.name, map_data.tile_count]
		map_button.custom_minimum_size = Vector2(0, 75)
		map_button.add_theme_font_size_override("font_size", 42)
		var map_id = map_data.id
		map_button.pressed.connect(_on_map_selected.bind(map_id))
		# ゲストはマップ選択不可
		if not _is_host:
			map_button.disabled = true
		map_vbox.add_child(map_button)
		_map_buttons.append(map_button)

	# 右側：マッププレビュー
	var preview_margin = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_top", -40)
	preview_margin.add_theme_constant_override("margin_right", 20)
	preview_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_margin.size_flags_stretch_ratio = 0.48
	map_top_hbox.add_child(preview_margin)

	_map_preview = TextureRect.new()
	_map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_margin.add_child(_map_preview)

	# デフォルトマップ選択
	if _maps.size() > 0:
		_selected_map_id = _maps[0].id
		_update_map_highlight()
		_show_map_preview(_selected_map_id)

	# ===== 下段：ルール設定（左右2列） =====
	var rule_label = Label.new()
	rule_label.text = "■ ルール設定"
	rule_label.add_theme_font_size_override("font_size", 60)
	rule_label.add_theme_color_override("font_color", Color.WHITE)
	right_vbox.add_child(rule_label)

	# ホストのみ注釈
	if not _is_host:
		var host_rule_label = Label.new()
		host_rule_label.text = "（ホストが設定中）"
		host_rule_label.add_theme_font_size_override("font_size", 32)
		host_rule_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		right_vbox.add_child(host_rule_label)

	var rule_hbox = HBoxContainer.new()
	rule_hbox.add_theme_constant_override("separation", 60)
	right_vbox.add_child(rule_hbox)

	# --- 左列：プリセット + 最大ターン ---
	var rule_left_grid = GridContainer.new()
	rule_left_grid.columns = 2
	rule_left_grid.add_theme_constant_override("h_separation", 20)
	rule_left_grid.add_theme_constant_override("v_separation", 20)
	rule_hbox.add_child(rule_left_grid)

	# プリセット
	var preset_label = Label.new()
	preset_label.text = "プリセット:"
	preset_label.add_theme_font_size_override("font_size", 54)
	rule_left_grid.add_child(preset_label)

	_rule_preset_option = OptionButton.new()
	_rule_preset_option.custom_minimum_size = Vector2(340, 80)
	_rule_preset_option.add_theme_font_size_override("font_size", 54)
	rule_left_grid.add_child(_rule_preset_option)
	_rule_preset_option.get_popup().add_theme_font_size_override("font_size", 63)

	_rule_preset_option.add_item("スタンダード", 0)
	_rule_preset_option.add_item("クイック", 1)
	_rule_preset_option.add_item("殲滅", 2)
	_rule_preset_option.add_item("テリトリー", 3)
	_rule_preset_option.select(0)
	_rule_preset_option.item_selected.connect(_on_rule_preset_changed)
	if not _is_host:
		_rule_preset_option.disabled = true

	# 最大ターン
	var turns_label = Label.new()
	turns_label.text = "最大ターン:"
	turns_label.add_theme_font_size_override("font_size", 54)
	rule_left_grid.add_child(turns_label)

	_max_turns_spin = SpinBox.new()
	_max_turns_spin.min_value = 0
	_max_turns_spin.max_value = 100
	_max_turns_spin.step = 1
	_max_turns_spin.value = 0
	var turns_row = _create_spin_with_arrows(_max_turns_spin, 280, true)
	rule_left_grid.add_child(turns_row)

	# --- 右列：目標TEP + 初期EP ---
	var rule_right_grid = GridContainer.new()
	rule_right_grid.columns = 2
	rule_right_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_right_grid.add_theme_constant_override("h_separation", 28)
	rule_right_grid.add_theme_constant_override("v_separation", 20)
	rule_hbox.add_child(rule_right_grid)

	# 目標TEP
	var tep_label = Label.new()
	tep_label.text = "目標TEP:"
	tep_label.add_theme_font_size_override("font_size", 54)
	rule_right_grid.add_child(tep_label)

	_target_tep_spin = SpinBox.new()
	_target_tep_spin.min_value = 1000
	_target_tep_spin.max_value = 30000
	_target_tep_spin.step = 1000
	_target_tep_spin.value = 8000
	var tep_row = _create_spin_with_arrows(_target_tep_spin, 320)
	tep_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_right_grid.add_child(tep_row)

	# 初期EP（全員共通）
	var ep_label = Label.new()
	ep_label.text = "初期EP:"
	ep_label.add_theme_font_size_override("font_size", 54)
	rule_right_grid.add_child(ep_label)

	_initial_ep_spin = SpinBox.new()
	_initial_ep_spin.min_value = 100
	_initial_ep_spin.max_value = 10000
	_initial_ep_spin.step = 100
	_initial_ep_spin.value = GameConstants.get_initial_magic("standard")
	var ep_row = _create_spin_with_arrows(_initial_ep_spin, 320)
	ep_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_right_grid.add_child(ep_row)

	# ゲストはSpinBox操作不可
	if not _is_host:
		_max_turns_spin.editable = false
		_target_tep_spin.editable = false
		_initial_ep_spin.editable = false

	return right_panel


func _build_bottom_area():
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.custom_minimum_size = Vector2(0, 100)
	_main_vbox.add_child(bottom_hbox)

	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(450, 100)
	_action_button.add_theme_font_size_override("font_size", 54)

	if _is_host:
		_action_button.text = "【 対戦開始 】"
		# 全員準備完了するまでグレーアウト
		_action_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_action_button.disabled = true
		_action_button.pressed.connect(_on_battle_start_pressed)
	else:
		_action_button.text = "【 準備完了 】"
		_action_button.add_theme_color_override("font_color", Color.WHITE)
		_action_button.pressed.connect(_on_ready_pressed)

	bottom_hbox.add_child(_action_button)


# ===== コールバック =====

func _on_deck_selected(index: int):
	_selected_deck_index = index
	_update_book_highlight()
	print("デッキ %d を選択しました" % (index + 1))


func _update_book_highlight():
	for i in range(_book_buttons.size()):
		var button = _book_buttons[i]
		if i == _selected_deck_index:
			var hl_style = StyleBoxFlat.new()
			hl_style.bg_color = HIGHLIGHT_COLOR
			button.add_theme_stylebox_override("normal", hl_style)
			button.add_theme_stylebox_override("focus", hl_style)
			button.add_theme_stylebox_override("pressed", hl_style)
			button.add_theme_stylebox_override("hover", hl_style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("focus")
			button.remove_theme_stylebox_override("pressed")
			button.remove_theme_stylebox_override("hover")


func _on_map_selected(map_id: String):
	if not _is_host:
		return
	_selected_map_id = map_id
	_update_map_highlight()
	_show_map_preview(map_id)
	print("マップ %s を選択しました" % map_id)
	# TODO: ネットワーク経由でゲストに通知


func _update_map_highlight():
	for i in range(_map_buttons.size()):
		var button = _map_buttons[i]
		if _maps[i].id == _selected_map_id:
			var hl_style = StyleBoxFlat.new()
			hl_style.bg_color = HIGHLIGHT_COLOR
			button.add_theme_stylebox_override("normal", hl_style)
			button.add_theme_stylebox_override("focus", hl_style)
			button.add_theme_stylebox_override("pressed", hl_style)
			button.add_theme_stylebox_override("hover", hl_style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("focus")
			button.remove_theme_stylebox_override("pressed")
			button.remove_theme_stylebox_override("hover")


func _on_rule_preset_changed(_index: int):
	var preset_names: Array[String] = ["standard", "quick", "elimination", "territory"]
	_selected_rule_preset = preset_names[_rule_preset_option.get_selected_id()]

	# プリセットから初期値を設定
	var initial_magic = GameConstants.get_initial_magic(_selected_rule_preset)
	_initial_ep_spin.value = initial_magic

	# プリセットから目標TEPを設定
	var win_conditions = GameConstants.get_win_conditions(_selected_rule_preset)
	var conditions = win_conditions.get("conditions", [])
	for condition in conditions:
		if condition.has("target"):
			_target_tep_spin.value = condition.get("target", 8000)
			break

	# プリセットから最大ターンを設定
	var preset = GameConstants.RULE_PRESETS.get(_selected_rule_preset, {})
	_max_turns_spin.value = preset.get("max_turns", 0)

	# elimination の場合、目標TEPを editable = false
	if _selected_rule_preset == "elimination":
		_target_tep_spin.editable = false
	else:
		_target_tep_spin.editable = true

	# TODO: ネットワーク経由でゲストにルール変更を通知


func _on_ready_pressed():
	_local_ready = not _local_ready

	if _local_ready:
		_action_button.text = "【 準備完了！ 】"
		_action_button.add_theme_color_override("font_color", READY_COLOR)
	else:
		_action_button.text = "【 準備完了 】"
		_action_button.add_theme_color_override("font_color", Color.WHITE)

	# 自分のプレイヤーデータを更新
	for player in _players:
		if player.get("is_local", false):
			player["is_ready"] = _local_ready
			break

	_update_player_display()
	# TODO: ネットワーク経由でホストに準備状態を通知


func _on_battle_start_pressed():
	if not _is_host:
		return

	if not _all_players_ready():
		return

	if not _selected_map_id:
		_show_error_dialog("マップを選択してください")
		return

	# 設定を保存
	var config = {
		"mode": "friend",
		"map_id": _selected_map_id,
		"rule_preset": _selected_rule_preset,
		"initial_magic": int(_initial_ep_spin.value),
		"target_magic": int(_target_tep_spin.value),
		"max_turns": int(_max_turns_spin.value),
		"players": _prepare_players_array()
	}

	GameData.set_meta("net_battle_config", config)
	GameData.selected_deck_index = _selected_deck_index

	print("ネット対戦開始: ", config)

	# TODO: ネットワーク経由で全員にゲーム開始を通知
	# Main.tscn へ遷移
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")


func _on_back_pressed():
	# TODO: ネットワーク切断処理
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")


# ===== プレイヤー表示 =====

## ダミープレイヤーを設定（ネットワーク未接続時のテスト表示用）
func _setup_dummy_players():
	_players.clear()
	# 自分（常にスロット1）
	var player_name = GameData.player_data.profile.name if GameData.player_data and GameData.player_data.profile else "プレイヤー"
	_players.append({
		"id": "local",
		"name": player_name,
		"is_ready": false,
		"is_local": true,
		"model_path": "res://scenes/Characters/Necromancer.tscn"
	})


## プレイヤーリスト表示を更新
func _update_player_display():
	for slot_index in range(_max_players):
		if slot_index >= _player_slots.size():
			break

		var slot = _player_slots[slot_index]
		var name_label: Label = slot["name_label"]
		var ready_label: Label = slot["ready_label"]

		if slot_index < _players.size():
			var player = _players[slot_index]
			var player_name = player.get("name", "???")
			var is_local = player.get("is_local", false)

			if is_local:
				name_label.text = "%s（あなた）" % player_name
			else:
				name_label.text = player_name

			name_label.add_theme_color_override("font_color", Color.WHITE)

			# 準備完了マーク
			if player.get("is_ready", false):
				ready_label.text = "✓"
				ready_label.add_theme_color_override("font_color", READY_COLOR)
			else:
				ready_label.text = "..."
				ready_label.add_theme_color_override("font_color", NOT_READY_COLOR)
		else:
			# 空きスロット
			name_label.text = "（待機中...）"
			name_label.add_theme_color_override("font_color", WAITING_COLOR)
			ready_label.text = ""

	# ホストの対戦開始ボタン状態更新
	_update_action_button_state()


## 全員準備完了かチェック
func _all_players_ready() -> bool:
	if _players.size() < 2:
		return false
	for player in _players:
		if not player.get("is_ready", false):
			return false
	return true


## 対戦開始ボタンの有効/無効を更新
func _update_action_button_state():
	if not _is_host or not _action_button:
		return

	if _all_players_ready():
		_action_button.disabled = false
		_action_button.add_theme_color_override("font_color", Color.YELLOW)
	else:
		_action_button.disabled = true
		_action_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _prepare_players_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in _players:
		result.append({
			"player_id": player.get("id", ""),
			"name": player.get("name", ""),
			"deck_id": "deck_%d" % _selected_deck_index  # TODO: 各プレイヤーの選択デッキ
		})
	return result


# ===== ネットワーク公開メソッド（将来NetworkServiceから呼ばれる） =====

## プレイヤーが参加した時（ネットワーク経由で呼ばれる）
func on_player_joined(player_id: String, player_name: String, model_path: String = "res://scenes/Characters/Necromancer.tscn"):
	var slot_index = _players.size()
	_players.append({
		"id": player_id,
		"name": player_name,
		"is_ready": false,
		"is_local": false,
		"model_path": model_path
	})
	_update_player_display()
	# キャラプレビュー更新
	if slot_index < _max_players:
		_update_player_preview(slot_index, model_path)
	print("プレイヤー参加: %s (%s)" % [player_name, player_id])


## プレイヤーが退出した時
func on_player_left(player_id: String):
	for i in range(_players.size()):
		if _players[i].get("id") == player_id:
			print("プレイヤー退出: %s" % _players[i].get("name", ""))
			_players.remove_at(i)
			break
	# プレビューを全て再構築（スロット番号がずれるため）
	_rebuild_all_player_previews()
	_update_player_display()


## プレイヤーの準備状態が変わった時
func on_player_ready_changed(player_id: String, is_ready: bool):
	for player in _players:
		if player.get("id") == player_id:
			player["is_ready"] = is_ready
			break
	_update_player_display()


## ホストからルール設定を受信した時（ゲスト用）
func on_config_received(config: Dictionary):
	if _is_host:
		return

	var map_id = config.get("map_id", "")
	if map_id:
		_selected_map_id = map_id
		_update_map_highlight()
		_show_map_preview(map_id)

	var preset = config.get("rule_preset", "")
	if preset:
		var preset_index = ["standard", "quick", "elimination", "territory"].find(preset)
		if preset_index >= 0:
			_rule_preset_option.select(preset_index)
			_selected_rule_preset = preset

	if config.has("initial_magic"):
		_initial_ep_spin.value = config.get("initial_magic", 300)
	if config.has("target_magic"):
		_target_tep_spin.value = config.get("target_magic", 8000)
	if config.has("max_turns"):
		_max_turns_spin.value = config.get("max_turns", 0)


# ===== キャラプレビュー =====

## プレイヤーキャラクタープレビューを更新（ライブ3Dレンダリング）
func _update_player_preview(slot_index: int, model_path: String):
	if slot_index >= _player_preview_viewports.size():
		return

	var sv = _player_preview_viewports[slot_index]

	# 既存キャラノードを削除
	if _player_preview_char_nodes[slot_index]:
		_player_preview_char_nodes[slot_index].queue_free()
		_player_preview_char_nodes[slot_index] = null

	if model_path == "" or not ResourceLoader.exists(model_path):
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var char_scene = load(model_path)
	if not char_scene:
		return

	var char_node = char_scene.instantiate()
	char_node.position = Vector3.ZERO
	sv.add_child(char_node)
	_player_preview_char_nodes[slot_index] = char_node

	# IdleModel(テクスチャ付き)を表示、WalkModel(メッシュ)は非表示
	var walk_model = char_node.get_node_or_null("WalkModel")
	var idle_model = char_node.get_node_or_null("IdleModel")
	if idle_model:
		idle_model.visible = true
	if walk_model:
		walk_model.visible = false

	# WalkModelのAnimationPlayerを見つけて、root_nodeをIdleModelに向ける
	if walk_model and idle_model:
		var walk_anim = _find_animation_player(walk_model)
		if walk_anim:
			walk_anim.root_node = walk_anim.get_path_to(idle_model)
			var anims = walk_anim.get_animation_list()
			if anims.size() > 0:
				var anim = walk_anim.get_animation(anims[0])
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				walk_anim.play(anims[0])


## 全プレイヤープレビューを再構築（退出時のスロットずれ対応）
func _rebuild_all_player_previews():
	# 全プレビューをクリア
	for i in range(_max_players):
		if i < _player_preview_char_nodes.size() and _player_preview_char_nodes[i]:
			_player_preview_char_nodes[i].queue_free()
			_player_preview_char_nodes[i] = null
		if i < _player_preview_viewports.size():
			_player_preview_viewports[i].render_target_update_mode = SubViewport.UPDATE_DISABLED

	# 現在のプレイヤーリストから再構築
	for i in range(_players.size()):
		var model_path = _players[i].get("model_path", "res://scenes/Characters/Necromancer.tscn")
		if i < _max_players:
			_update_player_preview(i, model_path)


## ノードツリー内のAnimationPlayerを再帰的に探して返す
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null


# ===== ヘルパーメソッド =====

func _load_maps():
	_maps.clear()

	var dir = DirAccess.open(MAPS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".json"):
				# テスト/チュートリアルマップを除外
				if not ("tutorial" in file_name or "test_" in file_name or "branch_test" in file_name):
					var map_path = MAPS_PATH + file_name
					var map_file = FileAccess.open(map_path, FileAccess.READ)
					if map_file:
						var json_str = map_file.get_as_text()
						map_file.close()

						var json = JSON.new()
						if json.parse(json_str) == OK:
							var map_data = json.data
							if map_data and map_data.has("id") and map_data.has("name"):
								_maps.append({
									"id": map_data.get("id", ""),
									"name": map_data.get("name", ""),
									"tile_count": map_data.get("tile_count", 0)
								})

			file_name = dir.get_next()

		print("ロード完了: %d個のマップ" % _maps.size())
	else:
		print("エラー: maps ディレクトリを開けません")


func _show_error_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "エラー"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


# ===== マッププレビュー =====

func _show_map_preview(map_id: String):
	if not _map_preview:
		return

	# キャッシュ確認
	if _map_preview_cache.has(map_id):
		_map_preview.texture = _map_preview_cache[map_id]
		return

	# マップデータ読み込み
	var path = "res://data/master/maps/%s.json" % map_id
	if not FileAccess.file_exists(path):
		_map_preview.texture = null
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_map_preview.texture = null
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		_map_preview.texture = null
		return

	var map_data = json.get_data()
	var tiles = map_data.get("tiles", [])

	if tiles.is_empty():
		_map_preview.texture = null
		return

	_generate_3d_map_preview(map_id, tiles)


func _generate_3d_map_preview(map_id: String, tiles: Array):
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(900, 700)
	sub_viewport.transparent_bg = false
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	world_env.environment = env
	sub_viewport.add_child(world_env)

	var light = DirectionalLight3D.new()
	light.position = Vector3(10, 20, 10)
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.0
	sub_viewport.add_child(light)

	var min_x = 999999.0
	var max_x = -999999.0
	var min_z = 999999.0
	var max_z = -999999.0

	for tile in tiles:
		var x = float(tile.get("x", 0))
		var z = float(tile.get("z", 0))
		min_x = min(min_x, x)
		max_x = max(max_x, x)
		min_z = min(min_z, z)
		max_z = max(max_z, z)

	var tiles_container = Node3D.new()
	sub_viewport.add_child(tiles_container)

	for tile_data in tiles:
		var tile_type = tile_data.get("type", "Neutral")
		var tile_scene = _get_tile_scene(tile_type)
		if tile_scene:
			var tile_node = tile_scene.instantiate()
			var x = float(tile_data.get("x", 0))
			var z = float(tile_data.get("z", 0))
			tile_node.position = Vector3(x, 0, z)
			tiles_container.add_child(tile_node)

	var camera = Camera3D.new()
	var center_x = (min_x + max_x) / 2.0
	var center_z = (min_z + max_z) / 2.0
	var range_x = max_x - min_x
	var range_z = max_z - min_z
	var map_size = max(range_x, range_z)

	var cam_distance = map_size * 1.0 + 20
	var cam_height = cam_distance * 0.7
	var cam_z_offset = cam_distance * 0.7

	camera.position = Vector3(center_x, cam_height, center_z + cam_z_offset)
	camera.rotation_degrees = Vector3(-45, 0, 0)
	camera.fov = 45
	sub_viewport.add_child(camera)

	add_child(sub_viewport)

	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_texture = sub_viewport.get_texture()
	if viewport_texture:
		var image = viewport_texture.get_image()
		var texture = ImageTexture.create_from_image(image)
		_map_preview_cache[map_id] = texture
		if _map_preview:
			_map_preview.texture = texture

	sub_viewport.queue_free()


func _get_tile_scene(tile_type: String) -> PackedScene:
	var tile_scenes = {
		"Checkpoint": "res://scenes/Tiles/CheckpointTile.tscn",
		"Fire": "res://scenes/Tiles/FireTile.tscn",
		"Water": "res://scenes/Tiles/WaterTile.tscn",
		"Earth": "res://scenes/Tiles/EarthTile.tscn",
		"Wind": "res://scenes/Tiles/WindTile.tscn",
		"Neutral": "res://scenes/Tiles/NeutralTile.tscn",
		"Warp": "res://scenes/Tiles/WarpTile.tscn",
		"WarpStop": "res://scenes/Tiles/WarpStopTile.tscn",
		"CardBuy": "res://scenes/Tiles/CardBuyTile.tscn",
		"CardGive": "res://scenes/Tiles/CardGiveTile.tscn",
		"MagicStone": "res://scenes/Tiles/MagicStoneTile.tscn",
		"Magic": "res://scenes/Tiles/MagicTile.tscn",
		"Base": "res://scenes/Tiles/SpecialBaseTile.tscn",
		"Branch": "res://scenes/Tiles/BranchTile.tscn"
	}

	var path = tile_scenes.get(tile_type, tile_scenes.get("Neutral"))
	if path and ResourceLoader.exists(path):
		return load(path)
	return null


## SpinBoxを非表示にして、▲数値▼の横並びUIを作成
## zero_as_infinity: trueの場合、値0を「∞」と表示
func _create_spin_with_arrows(spin: SpinBox, min_width: float, zero_as_infinity: bool = false) -> HBoxContainer:
	spin.visible = false

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.custom_minimum_size = Vector2(min_width, 80)

	var btn_size := 70

	var _format_value = func(val: float) -> String:
		if zero_as_infinity and int(val) == 0:
			return "∞"
		return str(int(val))

	# ▲ボタン（増加・左）
	var up_btn = Button.new()
	up_btn.text = "▲"
	up_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	up_btn.add_theme_font_size_override("font_size", 40)
	# ゲストは操作不可
	if not _is_host:
		up_btn.disabled = true
	hbox.add_child(up_btn)

	# 数値ラベル
	var value_label = Label.new()
	value_label.text = _format_value.call(spin.value)
	value_label.add_theme_font_size_override("font_size", 72)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(value_label)

	# ▼ボタン（減少・右）
	var down_btn = Button.new()
	down_btn.text = "▼"
	down_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	down_btn.add_theme_font_size_override("font_size", 40)
	if not _is_host:
		down_btn.disabled = true
	hbox.add_child(down_btn)

	hbox.add_child(spin)

	down_btn.pressed.connect(func():
		spin.value = max(spin.value - spin.step, spin.min_value)
		value_label.text = _format_value.call(spin.value)
	)
	up_btn.pressed.connect(func():
		spin.value = min(spin.value + spin.step, spin.max_value)
		value_label.text = _format_value.call(spin.value)
	)
	spin.value_changed.connect(func(val: float):
		value_label.text = _format_value.call(val)
	)

	return hbox


## 背景にCastleEnvironmentを3Dレンダリングして表示
func _build_castle_background(viewport_size: Vector2) -> void:
	var bg_viewport_container = SubViewportContainer.new()
	bg_viewport_container.position = Vector2.ZERO
	bg_viewport_container.size = viewport_size
	bg_viewport_container.stretch = true
	bg_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_viewport_container)

	var bg_viewport = SubViewport.new()
	bg_viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
	bg_viewport.own_world_3d = true
	bg_viewport.transparent_bg = false
	bg_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	bg_viewport_container.add_child(bg_viewport)

	# WorldEnvironment（空と環境光）
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.55, 0.80)
	sky_mat.sky_horizon_color = Color(0.55, 0.68, 0.80)
	sky_mat.ground_bottom_color = Color(0.45, 0.58, 0.72)
	sky_mat.ground_horizon_color = Color(0.55, 0.68, 0.80)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	world_env.environment = env
	bg_viewport.add_child(world_env)

	# ライト
	var dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_energy = 1.5
	dir_light.shadow_enabled = false
	bg_viewport.add_child(dir_light)

	# CastleEnvironment（固定サイズで生成）
	var castle_env = CastleEnvironment.new()
	castle_env.name = "BgCastleEnvironment"
	castle_env.rotation.y = deg_to_rad(45)
	bg_viewport.add_child(castle_env)
	castle_env.setup_with_fixed_size(Vector3(0.0, 0.0, 0.0), 12.0)

	# カメラ（城壁を見下ろすアングル）
	var bg_camera = Camera3D.new()
	bg_camera.position = Vector3(0.0, 18.0, 25.0)
	bg_camera.rotation_degrees = Vector3(-30, 0, 0)
	bg_camera.fov = 50
	bg_camera.current = true
	bg_viewport.add_child(bg_camera)

	# 半透明の暗いオーバーレイ（UIの視認性確保）
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.05, 0.3)
	overlay.position = Vector2.ZERO
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
