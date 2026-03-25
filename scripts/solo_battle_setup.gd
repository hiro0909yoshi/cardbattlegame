extends Control

# ソロバトル準備画面
# ビューポート相対位置でUIを動的生成

# ===== UI要素 =====
var _main_vbox: VBoxContainer
var _book_buttons: Array[Button] = []
var _map_buttons: Array[Button] = []
var _cpu_character_options: Array[OptionButton] = []
var _cpu_star_buttons: Array[Array] = []  # [[Button, Button, Button], ...]  各CPU×3つの星ボタン
var _cpu_selected_level: Array[int] = [1, 1, 1]  # 各CPUの選択レベル
var _rule_preset_option: OptionButton
var _initial_ep_player_spin: SpinBox
var _initial_ep_cpu_spin: SpinBox
var _target_tep_spin: SpinBox
var _max_turns_spin: SpinBox
var _battle_start_button: Button
var _map_preview: TextureRect
var _cpu_preview_containers: Array[SubViewportContainer] = []  # CPUキャラプレビュー×3
var _cpu_preview_viewports: Array[SubViewport] = []  # 各SubViewport
var _cpu_preview_char_nodes: Array[Node] = []  # 各キャラノード（差し替え用）

# ===== データ =====
var _selected_deck_index: int = 0
var _selected_map_id: String = ""
var _selected_rule_preset: String = "standard"
var _characters: Dictionary = {}  # キャラクターデータ
var _maps: Array[Dictionary] = []  # マップリスト
var _enemies: Array[Dictionary] = []  # 選択中のCPU敵
var _map_preview_cache: Dictionary = {}  # マップID → ImageTexture キャッシュ

# ===== 色定義 =====
const PANEL_COLOR = Color(0.18, 0.18, 0.22, 0.55)
const HIGHLIGHT_COLOR = Color(0.3, 0.5, 0.8, 0.8)

# ===== パス定義 =====
const MAPS_PATH = "res://data/master/maps/"
const CHARACTERS_PATH = "res://data/master/characters/characters.json"


func _ready():
	# 画面背景
	modulate = Color.WHITE

	var viewport_size = get_viewport().get_visible_rect().size

	# 背景: CastleEnvironmentを3Dレンダリング
	_build_castle_background(viewport_size)

	# ルート VBox レイアウト
	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.position = Vector2.ZERO
	_main_vbox.size = viewport_size
	_main_vbox.add_theme_constant_override("separation", 0)
	add_child(_main_vbox)

	# データ読み込み
	_load_characters()
	_load_maps()

	# UI構築
	_build_top_bar()
	_build_content_area()

	print("ソロバトル準備画面を初期化しました")


func _build_top_bar():
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	top_hbox.custom_minimum_size = Vector2(0, 100)
	_main_vbox.add_child(top_hbox)

	# 戻るボタン
	var back_button = Button.new()
	back_button.text = "← 戻る"
	back_button.custom_minimum_size = Vector2(180, 80)
	back_button.add_theme_font_size_override("font_size", 42)
	back_button.pressed.connect(_on_back_pressed)
	top_hbox.add_child(back_button)

	# タイトル
	var title_label = Label.new()
	title_label.text = "ソロバトル準備"
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

	# 左パネル：ブック選択 + CPU選択
	var left_vbox = _build_left_panel()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.4
	content_hbox.add_child(left_vbox)

	# 右パネル：マップ選択 + ルール設定
	var right_vbox = _build_right_panel()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.6
	content_hbox.add_child(right_vbox)

	# 下部：対戦開始ボタン
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

	# ===== CPU選択 =====
	left_vbox.add_child(VSeparator.new())

	var cpu_label = Label.new()
	cpu_label.text = "■ CPU対戦相手"
	cpu_label.add_theme_font_size_override("font_size", 48)
	cpu_label.add_theme_color_override("font_color", Color.WHITE)
	cpu_label.custom_minimum_size = Vector2(0, 70)
	left_vbox.add_child(cpu_label)

	# CPU選択エリア（左: 選択UI、右: プレビュー3つ）— 下詰め
	var cpu_area_hbox = HBoxContainer.new()
	cpu_area_hbox.add_theme_constant_override("separation", 16)
	cpu_area_hbox.size_flags_vertical = Control.SIZE_SHRINK_END
	left_vbox.add_child(cpu_area_hbox)

	# 左側: CPU選択UI（プレビューと高さを揃えて均等配置）
	var cpu_select_vbox = VBoxContainer.new()
	cpu_select_vbox.add_theme_constant_override("separation", 150)
	cpu_select_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cpu_select_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cpu_select_vbox.size_flags_stretch_ratio = 0.55
	cpu_select_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cpu_area_hbox.add_child(cpu_select_vbox)

	# CPU スロット (最大3)
	for cpu_index in range(3):
		var cpu_slot_vbox = VBoxContainer.new()
		cpu_slot_vbox.add_theme_constant_override("separation", 4)
		cpu_select_vbox.add_child(cpu_slot_vbox)

		# CPU タイトル + キャラ選択（1行目）
		var char_hbox = HBoxContainer.new()
		char_hbox.add_theme_constant_override("separation", 8)
		cpu_slot_vbox.add_child(char_hbox)

		var cpu_title = Label.new()
		cpu_title.text = "CPU%d:" % (cpu_index + 1)
		cpu_title.add_theme_font_size_override("font_size", 63)
		cpu_title.add_theme_color_override("font_color", Color.WHITE)
		char_hbox.add_child(cpu_title)

		var char_option = OptionButton.new()
		char_option.custom_minimum_size = Vector2(375, 0)
		char_option.add_theme_font_size_override("font_size", 63)
		char_option.get_popup().add_theme_font_size_override("font_size", 63)
		char_hbox.add_child(char_option)
		_cpu_character_options.append(char_option)

		# 星ボタン（レベル選択）
		var star_buttons: Array[Button] = []
		for star_i in range(3):
			var star_btn = Button.new()
			star_btn.text = "☆"
			star_btn.add_theme_font_size_override("font_size", 63)
			star_btn.custom_minimum_size = Vector2(75, 0)
			star_btn.flat = true
			star_btn.pressed.connect(_on_star_pressed.bind(cpu_index, star_i + 1))
			char_hbox.add_child(star_btn)
			star_buttons.append(star_btn)
		_cpu_star_buttons.append(star_buttons)

		# CPU1は必須、CPU2/3は「なし」を含む
		if cpu_index == 0:
			_populate_character_option(char_option, false)
		else:
			_populate_character_option(char_option, true)

		char_option.item_selected.connect(_on_cpu_character_changed_from_signal.bind(cpu_index))

		# デフォルト選択（プレビューはSubViewport作成後に実行）
		if cpu_index == 0:
			if char_option.item_count > 0:
				char_option.select(0)
		else:
			char_option.select(0)

	# 右側: キャラプレビュー3つ（縦並び・SubViewportContainerでライブレンダリング）
	var preview_vbox = VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 20)
	cpu_area_hbox.add_child(preview_vbox)

	for i in range(3):
		var svc = SubViewportContainer.new()
		svc.custom_minimum_size = Vector2(320, 230)
		svc.stretch = true
		svc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		preview_vbox.add_child(svc)

		var sv = SubViewport.new()
		sv.size = Vector2i(320, 230)
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
		camera.position = Vector3(0, 2.0, 11.0)
		camera.rotation_degrees = Vector3(-5, 0, 0)
		camera.fov = 28
		camera.current = true
		sv.add_child(camera)

		# キャラ未選択時は描画不要
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED

		svc.add_child(sv)

		_cpu_preview_containers.append(svc)
		_cpu_preview_viewports.append(sv)
		_cpu_preview_char_nodes.append(null)

	# CPU1のデフォルト選択をプレビュー含めて実行
	_on_cpu_character_changed(0)

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

	var map_scroll = ScrollContainer.new()
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_list_vbox.add_child(map_scroll)

	var map_vbox = VBoxContainer.new()
	map_vbox.add_theme_constant_override("separation", 28)
	map_scroll.add_child(map_vbox)

	for map_data in _maps:
		var map_id = map_data.id
		var unlock_key = "map." + map_id.trim_prefix("map_")
		if not UnlockManager.is_unlocked(unlock_key):
			continue

		var map_button = Button.new()
		map_button.custom_minimum_size = Vector2(0, 75)
		map_button.add_theme_font_size_override("font_size", 42)
		map_button.text = "%s (%dマス)" % [map_data.name, map_data.tile_count]
		map_button.pressed.connect(_on_map_selected.bind(map_id))

		map_vbox.add_child(map_button)
		_map_buttons.append(map_button)

	# 右側：マッププレビュー（上20px・左20pxオフセット）
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

	# デフォルトマップ選択（解放済みの最初のマップ）
	for map_data in _maps:
		var unlock_key = "map." + map_data.id.trim_prefix("map_")
		if UnlockManager.is_unlocked(unlock_key):
			_selected_map_id = map_data.id
			break
	if _selected_map_id != "":
		_update_map_highlight()
		_show_map_preview(_selected_map_id)

	# ===== 下段：ルール設定（左右2列） =====
	var rule_label = Label.new()
	rule_label.text = "■ ルール設定"
	rule_label.add_theme_font_size_override("font_size", 60)
	rule_label.add_theme_color_override("font_color", Color.WHITE)
	right_vbox.add_child(rule_label)

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

	# --- 右列：目標TEP + 初期EP(自分) + 初期EP(CPU) ---
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

	# 初期EP(自分)
	var ep_player_label = Label.new()
	ep_player_label.text = "初期EP(自分):"
	ep_player_label.add_theme_font_size_override("font_size", 54)
	rule_right_grid.add_child(ep_player_label)

	_initial_ep_player_spin = SpinBox.new()
	_initial_ep_player_spin.min_value = 100
	_initial_ep_player_spin.max_value = 10000
	_initial_ep_player_spin.step = 100
	_initial_ep_player_spin.value = GameConstants.get_initial_magic("standard")
	var ep_player_row = _create_spin_with_arrows(_initial_ep_player_spin, 320)
	ep_player_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_right_grid.add_child(ep_player_row)

	# 初期EP(CPU)
	var ep_cpu_label = Label.new()
	ep_cpu_label.text = "初期EP(CPU):"
	ep_cpu_label.add_theme_font_size_override("font_size", 54)
	rule_right_grid.add_child(ep_cpu_label)

	_initial_ep_cpu_spin = SpinBox.new()
	_initial_ep_cpu_spin.min_value = 100
	_initial_ep_cpu_spin.max_value = 10000
	_initial_ep_cpu_spin.step = 100
	_initial_ep_cpu_spin.value = GameConstants.get_initial_magic("standard")
	var ep_cpu_row = _create_spin_with_arrows(_initial_ep_cpu_spin, 320)
	ep_cpu_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_right_grid.add_child(ep_cpu_row)

	return right_panel


func _build_bottom_area():
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.custom_minimum_size = Vector2(0, 100)
	_main_vbox.add_child(bottom_hbox)

	_battle_start_button = Button.new()
	_battle_start_button.text = "【 対戦開始 】"
	_battle_start_button.custom_minimum_size = Vector2(450, 100)
	_battle_start_button.add_theme_font_size_override("font_size", 54)
	_battle_start_button.add_theme_color_override("font_color", Color.YELLOW)
	_battle_start_button.pressed.connect(_on_battle_start_pressed)
	bottom_hbox.add_child(_battle_start_button)


# ===== コールバック =====

func _on_deck_selected(index: int):
	_selected_deck_index = index
	_update_book_highlight()
	print("デッキ %d を選択しました" % (index + 1))


func _update_book_highlight():
	for i in range(_book_buttons.size()):
		var button = _book_buttons[i]
		if i == _selected_deck_index:
			var style = StyleBoxFlat.new()
			style.bg_color = HIGHLIGHT_COLOR
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("focus", style)
			button.add_theme_stylebox_override("pressed", style)
			button.add_theme_stylebox_override("hover", style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("focus")
			button.remove_theme_stylebox_override("pressed")
			button.remove_theme_stylebox_override("hover")


func _on_map_selected(map_id: String):
	_selected_map_id = map_id
	_update_map_highlight()
	_show_map_preview(map_id)
	print("マップ %s を選択しました" % map_id)


func _update_map_highlight():
	for i in range(_map_buttons.size()):
		var button = _map_buttons[i]
		if _maps[i].id == _selected_map_id:
			var style = StyleBoxFlat.new()
			style.bg_color = HIGHLIGHT_COLOR
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("focus", style)
			button.add_theme_stylebox_override("pressed", style)
			button.add_theme_stylebox_override("hover", style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("focus")
			button.remove_theme_stylebox_override("pressed")
			button.remove_theme_stylebox_override("hover")


## deck_id ("cpu_deck_1"等) からCpuDeckDataのデッキ名を取得
func _get_deck_name(deck_id: String) -> String:
	if not deck_id.begins_with("cpu_deck_"):
		return ""
	var index = int(deck_id.substr(9)) - 1
	if index < 0 or index >= CpuDeckData.decks.size():
		return ""
	return CpuDeckData.decks[index].get("name", "")


func _get_selected_char_id(cpu_index: int) -> String:
	var char_option = _cpu_character_options[cpu_index]
	var selected_id = char_option.get_selected_id()
	var id_map = char_option.get_meta("id_map", {})
	return id_map.get(selected_id, "")


## item_selected シグナルから呼ばれるラッパー（selected_index引数を無視）
func _on_cpu_character_changed_from_signal(_selected_index: int, cpu_index: int):
	_on_cpu_character_changed(cpu_index)


func _on_cpu_character_changed(cpu_index: int):
	var char_id = _get_selected_char_id(cpu_index)

	if char_id == "" and cpu_index > 0:
		# 「なし」が選択された場合
		_update_cpu_preview(cpu_index, "")
		_update_star_display(cpu_index, 0, 0)

		# 敵配列から削除
		var enemy_to_remove = _find_enemy_by_cpu_index(cpu_index)
		if enemy_to_remove:
			_enemies.erase(enemy_to_remove)
	else:
		# キャラが選択された
		var model_path = _characters.get(char_id, {}).get("model_path", "")
		_update_cpu_preview(cpu_index, model_path)

		# 星表示を更新（レベル1を選択、最大レベルはdifficulties数）
		var max_level = 0
		if _characters.has(char_id) and _characters[char_id].has("difficulties"):
			max_level = _characters[char_id]["difficulties"].size()

		_cpu_selected_level[cpu_index] = 1
		_update_star_display(cpu_index, 1, max_level)
		_apply_level_selection(cpu_index)


## 星ボタンが押された時
func _on_star_pressed(cpu_index: int, level: int):
	var char_id = _get_selected_char_id(cpu_index)
	if char_id == "":
		return

	var max_level = 0
	if _characters.has(char_id) and _characters[char_id].has("difficulties"):
		max_level = _characters[char_id]["difficulties"].size()

	if level > max_level:
		return

	_cpu_selected_level[cpu_index] = level
	_update_star_display(cpu_index, level, max_level)
	_apply_level_selection(cpu_index)


## 星の表示を更新（★=選択済み、☆=未選択、非表示=最大レベル超え）
func _update_star_display(cpu_index: int, selected_level: int, max_level: int):
	if cpu_index >= _cpu_star_buttons.size():
		return

	var stars = _cpu_star_buttons[cpu_index]
	for i in range(3):
		var star_btn: Button = stars[i]
		if i < max_level:
			star_btn.visible = true
			if i < selected_level:
				star_btn.text = "★"
				star_btn.add_theme_color_override("font_color", Color.YELLOW)
			else:
				star_btn.text = "☆"
				star_btn.remove_theme_color_override("font_color")
		else:
			star_btn.visible = false


## _enemies配列からcpu_indexに一致する敵を検索
func _find_enemy_by_cpu_index(cpu_index: int):
	for enemy in _enemies:
		if enemy.get("cpu_index") == cpu_index:
			return enemy
	return null


## レベル選択を敵配列に反映
func _apply_level_selection(cpu_index: int):
	var char_id = _get_selected_char_id(cpu_index)
	var level = _cpu_selected_level[cpu_index]

	if _characters.has(char_id) and _characters[char_id].has("difficulties"):
		var difficulties = _characters[char_id]["difficulties"]
		var diff_index = level - 1
		if diff_index >= 0 and diff_index < difficulties.size():
			var difficulty = difficulties[diff_index]

			# 敵配列を更新
			var existing_enemy = _find_enemy_by_cpu_index(cpu_index)

			var enemy_config = {
				"cpu_index": cpu_index,
				"character_id": char_id,
				"deck_id": difficulty.get("deck_id", "")
			}

			if existing_enemy:
				existing_enemy.clear()
				existing_enemy.merge(enemy_config)
			else:
				_enemies.append(enemy_config)


func _on_rule_preset_changed(_index: int):
	var preset_names = ["standard", "quick", "elimination", "territory"]
	_selected_rule_preset = preset_names[_rule_preset_option.get_selected_id()]

	# プリセットから初期値を設定
	var initial_magic = GameConstants.get_initial_magic(_selected_rule_preset)
	_initial_ep_player_spin.value = initial_magic
	_initial_ep_cpu_spin.value = initial_magic

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


func _on_battle_start_pressed():
	# 検証
	if not _selected_map_id:
		_show_error_dialog("マップを選択してください")
		return

	if _enemies.is_empty():
		_show_error_dialog("CPU対戦相手を選択してください")
		return

	# 設定を保存
	var config = {
		"map_id": _selected_map_id,
		"rule_preset": _selected_rule_preset,
		"initial_magic_player": int(_initial_ep_player_spin.value),
		"initial_magic_cpu": int(_initial_ep_cpu_spin.value),
		"target_magic": int(_target_tep_spin.value),
		"max_turns": int(_max_turns_spin.value),
		"enemies": _prepare_enemies_array()
	}

	GameData.set_meta("solo_battle_config", config)
	GameData.selected_deck_index = _selected_deck_index

	print("対戦開始: ", config)

	# Main.tscn へ遷移
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")


func _prepare_enemies_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in _enemies:
		result.append({
			"character_id": enemy.get("character_id", ""),
			"deck_id": enemy.get("deck_id", "")
		})
	return result


func _on_back_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")


# ===== ヘルパーメソッド =====

func _load_characters():
	_characters.clear()

	var file = FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_str) == OK:
			var data = json.data
			if data and data.has("characters"):
				var chars = data.get("characters", {})
				for char_id in chars.keys():
					var char_data = chars[char_id]
					# difficulties があるキャラだけ対象
					if char_data.has("difficulties"):
						_characters[char_id] = char_data

				print("ロード完了: %d個のキャラクター" % _characters.size())
			else:
				print("エラー: characters フィールドが見つかりません")
		else:
			print("エラー: JSON パース失敗")
	else:
		print("エラー: characters.json を開けません")


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


func _populate_character_option(option: OptionButton, include_none: bool):
	option.clear()
	var id_map: Dictionary = {}  # item_index → character_id

	if include_none:
		option.add_item("（なし）", 0)
		id_map[0] = ""

	var index = 1 if include_none else 0
	for char_id in _characters.keys():
		if not _characters[char_id].has("name"):
			continue
		# アンロック済みキャラのみ表示
		if not UnlockManager.is_unlocked("character." + char_id):
			continue
		var char_name = _characters[char_id]["name"]
		option.add_item(char_name, index)
		id_map[index] = char_id
		index += 1

	option.set_meta("id_map", id_map)


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
	# SubViewportを作成
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(900, 700)
	sub_viewport.transparent_bg = false
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# 背景色を設定するためのWorldEnvironment
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	world_env.environment = env
	sub_viewport.add_child(world_env)

	# ライトを追加
	var light = DirectionalLight3D.new()
	light.position = Vector3(10, 20, 10)
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.0
	sub_viewport.add_child(light)

	# タイルの座標範囲を計算
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

	# タイルコンテナを作成
	var tiles_container = Node3D.new()
	sub_viewport.add_child(tiles_container)

	# タイルを配置
	for tile_data in tiles:
		var tile_type = tile_data.get("type", "Neutral")
		var tile_scene = _get_tile_scene(tile_type)
		if tile_scene:
			var tile_node = tile_scene.instantiate()
			var x = float(tile_data.get("x", 0))
			var z = float(tile_data.get("z", 0))
			tile_node.position = Vector3(x, 0, z)
			tiles_container.add_child(tile_node)

	# カメラを追加（斜め45度の見下ろしアングル）
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

	# シーンツリーに追加してレンダリング
	add_child(sub_viewport)

	# 2フレーム待ってからテクスチャを取得
	await get_tree().process_frame
	await get_tree().process_frame

	# テクスチャを取得
	var viewport_texture = sub_viewport.get_texture()
	if viewport_texture:
		var image = viewport_texture.get_image()
		var texture = ImageTexture.create_from_image(image)
		_map_preview_cache[map_id] = texture
		if _map_preview:
			_map_preview.texture = texture

	# クリーンアップ
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


## ノードツリー内のAnimationPlayerを再帰的に探して返す
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null


## CPUキャラクタープレビューを更新（ライブ3Dレンダリング）
func _update_cpu_preview(cpu_index: int, model_path: String):
	if cpu_index >= _cpu_preview_viewports.size():
		return

	var sv = _cpu_preview_viewports[cpu_index]

	# 既存キャラノードを削除
	if _cpu_preview_char_nodes[cpu_index]:
		_cpu_preview_char_nodes[cpu_index].queue_free()
		_cpu_preview_char_nodes[cpu_index] = null

	if model_path == "" or not ResourceLoader.exists(model_path):
		sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# キャラクターモデルを配置
	var char_scene = load(model_path)
	if not char_scene:
		return

	var char_node = char_scene.instantiate()
	char_node.position = Vector3.ZERO
	sv.add_child(char_node)
	_cpu_preview_char_nodes[cpu_index] = char_node

	# IdleModel(テクスチャ付き)を表示、WalkModel(メッシュ)は非表示
	var walk_model = char_node.get_node_or_null("WalkModel")
	var idle_model = char_node.get_node_or_null("IdleModel")
	if idle_model:
		idle_model.visible = true
	if walk_model:
		walk_model.visible = false

	# WalkModelのAnimationPlayerを見つけて、root_nodeをIdleModelに向ける
	# → IdleModelのスケルトンにWalkアニメーションが適用される
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


## SpinBoxを非表示にして、▲数値▼の横並びUIを作成
## zero_as_infinity: trueの場合、値0を「∞」と表示
func _create_spin_with_arrows(spin: SpinBox, min_width: float, zero_as_infinity: bool = false) -> HBoxContainer:
	# SpinBox自体は非表示（値管理のみ使用）
	spin.visible = false

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.custom_minimum_size = Vector2(min_width, 80)

	var btn_size := 70

	# 値→表示テキスト変換
	var _format_value = func(val: float) -> String:
		if zero_as_infinity and int(val) == 0:
			return "∞"
		return str(int(val))

	# ▲ボタン（増加・左）
	var up_btn = Button.new()
	up_btn.text = "▲"
	up_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	up_btn.add_theme_font_size_override("font_size", 40)
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
	hbox.add_child(down_btn)

	# SpinBoxを非表示で追加（値の管理用）
	hbox.add_child(spin)

	# ボタン押下でSpinBox値を変更 → ラベル更新
	down_btn.pressed.connect(func():
		spin.value = max(spin.value - spin.step, spin.min_value)
		value_label.text = _format_value.call(spin.value)
	)
	up_btn.pressed.connect(func():
		spin.value = min(spin.value + spin.step, spin.max_value)
		value_label.text = _format_value.call(spin.value)
	)
	# SpinBox値が外部から変更された場合もラベル同期
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
