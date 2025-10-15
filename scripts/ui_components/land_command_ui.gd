# LandCommandUI - 領地コマンドUI管理
# UIManagerから分離された領地コマンド関連のUI処理
class_name LandCommandUI
extends Node

# シグナル
signal land_command_button_pressed()
signal level_up_selected(target_level: int, cost: int)

# UI要素
var land_command_button: Button = null
var cancel_button: Button = null
var action_menu_panel: Panel = null
var level_selection_panel: Panel = null
var action_menu_buttons = {}  # "level_up", "move", "swap", "cancel"
var level_selection_buttons = {}  # レベル選択ボタン
var current_level_label: Label = null
var selected_tile_for_action: int = -1

# システム参照
var player_system_ref = null
var board_system_ref = null
var ui_manager_ref = null  # UIManagerへの参照

# 親UIレイヤー
var ui_layer: Node = null

func _ready():
	pass

## 初期化
func initialize(ui_parent: Node, player_sys, board_sys, ui_manager = null):
	ui_layer = ui_parent
	player_system_ref = player_sys
	board_system_ref = board_sys
	ui_manager_ref = ui_manager

## 領地コマンドボタン作成
func create_land_command_button(parent: Node):
	if land_command_button:
		return
	
	var viewport_size = parent.get_viewport().get_visible_rect().size
	var button_width = 300
	var button_height = 70
	var player_panel_bottom = 150
	
	land_command_button = Button.new()
	land_command_button.name = "LandCommandButton"
	land_command_button.text = "領地コマンド"
	land_command_button.custom_minimum_size = Vector2(button_width, button_height)
	land_command_button.position = Vector2(20, viewport_size.y - player_panel_bottom - button_height - 20)
	land_command_button.z_index = 100
	
	# スタイル設定
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.6, 0.3, 1.0)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(1, 1, 1, 1)
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	land_command_button.add_theme_stylebox_override("normal", button_style)
	
	# ホバー時
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.8, 0.4, 1.0)
	land_command_button.add_theme_stylebox_override("hover", hover_style)
	
	# 押下時
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.45, 0.2, 1.0)
	land_command_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# 無効時
	var disabled_style = button_style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	land_command_button.add_theme_stylebox_override("disabled", disabled_style)
	
	# フォント設定
	var font_size = 24
	land_command_button.add_theme_font_size_override("font_size", font_size)
	
	# シグナル接続
	land_command_button.pressed.connect(_on_land_command_button_pressed)
	
	# 親に追加
	parent.add_child(land_command_button)
	
	# 初期状態は非表示
	land_command_button.visible = false

## キャンセルボタン作成
func create_cancel_land_command_button(parent: Node):
	if cancel_button:
		return
	
	var viewport_size = parent.get_viewport().get_visible_rect().size
	
	# 領地コマンドボタンと同じ配置計算
	var button_width = 300
	var button_height = 70
	var player_panel_bottom = 150
	var button_x = 20
	
	# 領地コマンドボタンのY座標
	var land_command_y = viewport_size.y - player_panel_bottom - button_height - 20
	
	# キャンセルボタンは領地コマンドボタンの下（より画面下端に近い位置）
	var button_y = land_command_y + button_height + 10  # 領地コマンドの下、10pxマージン
	
	cancel_button = Button.new()
	cancel_button.name = "CancelLandCommandButton"
	cancel_button.text = "✕ 閉じる"
	cancel_button.custom_minimum_size = Vector2(button_width, button_height)
	cancel_button.position = Vector2(button_x, button_y)
	cancel_button.z_index = 100
	
	# スタイル設定
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.6, 0.2, 0.2, 1.0)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(1, 1, 1, 1)
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	cancel_button.add_theme_stylebox_override("normal", button_style)
	
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.9, 0.3, 0.3, 1.0)
	cancel_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.7, 0.1, 0.1, 1.0)
	cancel_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# フォントサイズ（ボタン高さに応じて調整）
	var font_size = int(button_height * 0.25)
	cancel_button.add_theme_font_size_override("font_size", font_size)
	
	cancel_button.pressed.connect(_on_cancel_land_command_button_pressed)
	
	parent.add_child(cancel_button)
	cancel_button.visible = false

## 領地コマンドボタン表示
func show_land_command_button():
	if land_command_button:
		land_command_button.visible = true

## 領地コマンドボタン非表示
func hide_land_command_button():
	if land_command_button:
		land_command_button.visible = false

## キャンセルボタン表示
func show_cancel_button():
	if cancel_button:
		cancel_button.visible = true

## キャンセルボタン非表示
func hide_cancel_button():
	if cancel_button:
		cancel_button.visible = false

## 土地選択モード表示
func show_land_selection_mode(owned_lands: Array):
	# 実装は既存のUIManager参照
	pass

## アクション選択UI表示
func show_action_selection_ui(tile_index: int):
	show_action_menu(tile_index)

## 領地コマンドUI非表示
func hide_land_command_ui():
	hide_action_menu()
	hide_level_selection()
	hide_cancel_button()
	hide_land_command_button()

## アクションメニュー表示
func show_action_menu(tile_index: int):
	if not action_menu_panel:
		return
	
	selected_tile_for_action = tile_index
	action_menu_panel.visible = true
	
	# 土地番号を表示
	var tile_label = action_menu_panel.get_node_or_null("TileLabel")
	if tile_label:
		tile_label.text = "土地: #%d" % tile_index
	

## アクションメニュー非表示
func hide_action_menu():
	if action_menu_panel:
		action_menu_panel.visible = false
		selected_tile_for_action = -1

## レベル選択表示
func show_level_selection(tile_index: int, current_level: int, player_magic: int):
	if not level_selection_panel:
		return
	
	# 重要: tile_indexを保持
	selected_tile_for_action = tile_index
	
	# アクションメニューを隠す
	if action_menu_panel:
		action_menu_panel.visible = false
	
	# 現在レベルを表示
	if current_level_label:
		current_level_label.text = "現在: Lv.%d" % current_level
	
	# レベルコスト計算
	var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}
	
	# 各レベルボタンの有効/無効を設定
	for level in [2, 3, 4, 5]:
		if level <= current_level:
			# 現在以下のレベルは無効
			if level_selection_buttons.has(level):
				level_selection_buttons[level].disabled = true
		else:
			# レベルアップコストを計算
			var cost = level_costs[level] - level_costs[current_level]
			if player_magic >= cost:
				# 魔力が足りる
				if level_selection_buttons.has(level):
					level_selection_buttons[level].disabled = false
					level_selection_buttons[level].text = "Lv.%d → %dG" % [level, cost]
			else:
				# 魔力不足
				if level_selection_buttons.has(level):
					level_selection_buttons[level].disabled = true
					level_selection_buttons[level].text = "Lv.%d → %dG (不足)" % [level, cost]
	
	level_selection_panel.visible = true

func _calculate_level_up_cost(from_level: int, to_level: int) -> int:
	var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}
	return level_costs.get(to_level, 0) - level_costs.get(from_level, 0)

## レベル選択非表示
func hide_level_selection():
	if level_selection_panel:
		level_selection_panel.visible = false

## シグナルハンドラ
func _on_land_command_button_pressed():
	land_command_button_pressed.emit()

func _on_cancel_land_command_button_pressed():
	print("[LandCommandUI] キャンセルボタン押下")
	# UIManagerのキャンセル処理を呼び出す
	if ui_manager_ref and ui_manager_ref.has_method("_on_cancel_land_command_button_pressed"):
		ui_manager_ref._on_cancel_land_command_button_pressed()

func _on_action_level_up_pressed():
	# LandCommandHandlerに通知（キーボード入力をエミュレート）
	var event = InputEventKey.new()
	event.keycode = KEY_L
	event.pressed = true
	Input.parse_input_event(event)

func _on_action_move_pressed():
	var event = InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	Input.parse_input_event(event)

func _on_action_swap_pressed():
	var event = InputEventKey.new()
	event.keycode = KEY_S
	event.pressed = true
	Input.parse_input_event(event)

func _on_action_cancel_pressed():
	print("[LandCommandUI] アクションキャンセルボタン押下")
	hide_action_menu()
	var event = InputEventKey.new()
	event.keycode = KEY_C
	event.pressed = true
	Input.parse_input_event(event)

func _on_level_selected(level: int):
	var current_player = player_system_ref.get_current_player() if player_system_ref else null
	if not current_player:
		return
	
	var board_system = board_system_ref
	if not board_system or not board_system.tile_nodes.has(selected_tile_for_action):
		return
	
	var tile = board_system.tile_nodes[selected_tile_for_action]
	var cost = _calculate_level_up_cost(tile.level, level)
	
	level_up_selected.emit(level, cost)
	hide_level_selection()

func _on_level_cancel_pressed():
	print("[LandCommandUI] レベル選択キャンセル")
	hide_level_selection()
	# アクションメニューに戻る
	if selected_tile_for_action >= 0:
		show_action_menu(selected_tile_for_action)

## アクションメニューパネル作成
func create_action_menu_panel(parent: Node):
	if action_menu_panel:
		return
		
	action_menu_panel = Panel.new()
	action_menu_panel.name = "ActionMenuPanel"
	
	# 右側に配置
	var viewport_size = parent.get_viewport().get_visible_rect().size
	var panel_width = 200
	var panel_height = 320
	
	var panel_x = viewport_size.x - panel_width - 20
	var panel_y = (viewport_size.y - panel_height) / 2
	
	action_menu_panel.position = Vector2(panel_x, panel_y)
	action_menu_panel.size = Vector2(panel_width, panel_height)
	action_menu_panel.z_index = 100
	action_menu_panel.visible = false
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.5, 0.5, 0.5, 1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	action_menu_panel.add_theme_stylebox_override("panel", panel_style)
	
	parent.add_child(action_menu_panel)
	
	# タイトルラベル
	var title_label = Label.new()
	title_label.text = "アクション選択"
	title_label.position = Vector2(10, 10)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	action_menu_panel.add_child(title_label)
	
	# 選択中の土地番号表示
	var tile_label = Label.new()
	tile_label.name = "TileLabel"
	tile_label.text = "土地: -"
	tile_label.position = Vector2(10, 40)
	tile_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	action_menu_panel.add_child(tile_label)
	
	# ボタンを作成
	var button_y = 80
	var button_spacing = 10
	var button_height = 50
	
	# レベルアップボタン
	var level_up_btn = _create_menu_button("📈 [L] レベルアップ", Vector2(10, button_y), Color(0.2, 0.6, 0.8))
	level_up_btn.pressed.connect(_on_action_level_up_pressed)
	action_menu_panel.add_child(level_up_btn)
	action_menu_buttons["level_up"] = level_up_btn
	button_y += button_height + button_spacing
	
	# 移動ボタン
	var move_btn = _create_menu_button("🚶 [M] 移動", Vector2(10, button_y), Color(0.6, 0.4, 0.8))
	move_btn.pressed.connect(_on_action_move_pressed)
	action_menu_panel.add_child(move_btn)
	action_menu_buttons["move"] = move_btn
	button_y += button_height + button_spacing
	
	# 交換ボタン
	var swap_btn = _create_menu_button("🔄 [S] 交換", Vector2(10, button_y), Color(0.8, 0.6, 0.2))
	swap_btn.pressed.connect(_on_action_swap_pressed)
	action_menu_panel.add_child(swap_btn)
	action_menu_buttons["swap"] = swap_btn
	button_y += button_height + button_spacing
	
	# 戻るボタン
	var cancel_btn = _create_menu_button("↩️ [C] 戻る", Vector2(10, button_y), Color(0.5, 0.5, 0.5))
	cancel_btn.pressed.connect(_on_action_cancel_pressed)
	action_menu_panel.add_child(cancel_btn)
	action_menu_buttons["cancel"] = cancel_btn

## レベル選択パネル作成
func create_level_selection_panel(parent: Node):
	if level_selection_panel:
		return
		
	level_selection_panel = Panel.new()
	level_selection_panel.name = "LevelSelectionPanel"
	
	# アクションメニューと同じ位置
	var viewport_size = parent.get_viewport().get_visible_rect().size
	var panel_width = 250
	var panel_height = 400
	
	var panel_x = viewport_size.x - panel_width - 20
	var panel_y = (viewport_size.y - panel_height) / 2
	
	level_selection_panel.position = Vector2(panel_x, panel_y)
	level_selection_panel.size = Vector2(panel_width, panel_height)
	level_selection_panel.z_index = 101
	level_selection_panel.visible = false
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.15, 0.9)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.2, 0.6, 0.8, 1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	level_selection_panel.add_theme_stylebox_override("panel", panel_style)
	
	parent.add_child(level_selection_panel)
	
	# タイトル
	var title = Label.new()
	title.text = "レベルアップ"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	level_selection_panel.add_child(title)
	
	# 現在レベル表示
	current_level_label = Label.new()
	current_level_label.name = "CurrentLevelLabel"
	current_level_label.text = "現在: Lv.1"
	current_level_label.position = Vector2(10, 45)
	current_level_label.add_theme_font_size_override("font_size", 18)
	current_level_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	level_selection_panel.add_child(current_level_label)
	
	# レベル選択ボタン（2-5）
	var button_y = 85
	var button_spacing = 10
	
	var level_costs = {2: 80, 3: 240, 4: 620, 5: 1200}
	
	for level in [2, 3, 4, 5]:
		var btn = _create_level_button(level, level_costs[level], Vector2(10, button_y))
		btn.pressed.connect(_on_level_selected.bind(level))
		level_selection_panel.add_child(btn)
		level_selection_buttons[level] = btn
		button_y += 65 + button_spacing
	
	# 戻るボタン
	var cancel_btn = _create_menu_button("↩️ [C] 戻る", Vector2(10, button_y), Color(0.5, 0.5, 0.5))
	cancel_btn.pressed.connect(_on_level_cancel_pressed)
	level_selection_panel.add_child(cancel_btn)

## メニューボタン作成ヘルパー
func _create_menu_button(text: String, pos: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(180, 50)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.add_theme_font_size_override("font_size", 16)
	
	return btn

## レベルボタン作成ヘルパー
func _create_level_button(level: int, cost: int, pos: Vector2) -> Button:
	var btn = Button.new()
	btn.text = "Lv.%d → %dG" % [level, cost]
	btn.position = pos
	btn.size = Vector2(230, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.7)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.3, 0.6, 0.8)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.4, 0.6)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	btn.add_theme_font_size_override("font_size", 18)
	
	return btn
