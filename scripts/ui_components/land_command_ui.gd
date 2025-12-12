# LandCommandUI - 領地コマンドUI管理
# UIManagerから分離された領地コマンド関連のUI処理
class_name LandCommandUI
extends Node

# シグナル
signal land_command_button_pressed()
signal level_up_selected(target_level: int, cost: int)

# UI要素
var land_command_button: Button = null
var action_menu_panel: Panel = null
var level_selection_panel: Panel = null
var action_menu_buttons = {}  # "level_up", "move", "swap", "terrain"
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
	var button_width = 420  # 1.4倍
	var button_height = 98  # 1.4倍
	var player_panel_bottom = 210  # 1.4倍
	
	land_command_button = Button.new()
	land_command_button.name = "LandCommandButton"
	land_command_button.text = "領地コマンド"
	land_command_button.custom_minimum_size = Vector2(button_width, button_height)
	land_command_button.position = Vector2(28, viewport_size.y - player_panel_bottom - button_height - 28)
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
	
	# フォント設定 ※1.4倍
	var font_size = 34
	land_command_button.add_theme_font_size_override("font_size", font_size)
	
	# シグナル接続
	land_command_button.pressed.connect(_on_land_command_button_pressed)
	
	# 親に追加
	parent.add_child(land_command_button)
	
	# 初期状態は非表示
	land_command_button.visible = false

## 領地コマンドボタン表示
func show_land_command_button():
	if land_command_button:
		land_command_button.visible = true

## 領地コマンドボタン非表示
func hide_land_command_button():
	if land_command_button:
		land_command_button.visible = false

## キャンセルボタン表示（グローバルボタンに登録）
func show_cancel_button():
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_cancel_land_command_button_pressed, "閉じる")

## キャンセルボタン非表示（グローバルボタンをクリア）
func hide_cancel_button():
	if ui_manager_ref:
		ui_manager_ref.clear_back_action()

## 土地選択モード表示
func show_land_selection_mode(_owned_lands: Array):
	# 実装は既存のUIManager参照
	# TODO: owned_landsを使った表示実装
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
	
	# クリーチャー情報パネルを表示
	if board_system_ref and board_system_ref.tile_nodes.has(tile_index):
		var tile = board_system_ref.tile_nodes[tile_index]
		var creature = tile.creature_data if tile else {}
		
		# クリーチャーがいる場合、情報パネルを表示
		if not creature.is_empty() and ui_manager_ref and ui_manager_ref.creature_info_panel_ui:
			ui_manager_ref.creature_info_panel_ui.show_view_mode(creature, tile_index)
		
		# 防御型チェック: 移動ボタンを無効化
		var creature_type = creature.get("creature_type", "normal")
		
		if action_menu_buttons.has("move"):
			if creature_type == "defensive":
				action_menu_buttons["move"].disabled = true
				action_menu_buttons["move"].text = "🚶 [M] 移動 (防御型)"
			else:
				action_menu_buttons["move"].disabled = false
				action_menu_buttons["move"].text = "🚶 [M] 移動"
	
	# グローバルボタンに「戻る」を登録（show_view_modeの後に登録して上書き）
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_cancel_land_command_button_pressed, "戻る")
	

## アクションメニュー非表示
## clear_buttons: グローバルボタンをクリアするかどうか（デフォルト: true）
func hide_action_menu(clear_buttons: bool = true):
	if action_menu_panel:
		action_menu_panel.visible = false
		selected_tile_for_action = -1
	
	# クリーチャー情報パネルも閉じる（グローバルボタンのクリアは呼び出し側で制御）
	if ui_manager_ref and ui_manager_ref.creature_info_panel_ui:
		ui_manager_ref.creature_info_panel_ui.hide_panel(clear_buttons)

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
	
	# 各レベルボタンの有効/無効を設定
	for level in [2, 3, 4, 5]:
		if level <= current_level:
			# 現在以下のレベルは無効
			if level_selection_buttons.has(level):
				level_selection_buttons[level].disabled = true
		else:
			# レベルアップコストを動的に計算
			var cost = _calculate_level_up_cost(current_level, level)
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
	
	# グローバルボタンに「戻る」を登録
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_level_cancel_pressed, "戻る")
	
	# 最初の有効なレベルをハイライト
	var first_available_level = current_level + 1
	if first_available_level <= 5:
		highlight_level_button(first_available_level)

func _calculate_level_up_cost(_from_level: int, to_level: int) -> int:
	# TileDataManagerから動的に計算
	if board_system_ref and board_system_ref.tile_data_manager and selected_tile_for_action >= 0:
		var cost = board_system_ref.tile_data_manager.calculate_level_up_cost(selected_tile_for_action, to_level)
		return cost
	
	# フォールバック：TileDataManagerが使えない場合は0を返す
	return 0

## レベル選択非表示
func hide_level_selection():
	if level_selection_panel:
		level_selection_panel.visible = false

## レベルボタンのハイライト（上下キー選択用）
func highlight_level_button(selected_level: int):
	for level in level_selection_buttons.keys():
		var button = level_selection_buttons[level]
		if not button:
			continue
		
		if level == selected_level and not button.disabled:
			# 選択中のボタンをハイライト（枠線を強調）
			var style = button.get_theme_stylebox("normal").duplicate() if button.get_theme_stylebox("normal") else StyleBoxFlat.new()
			if style is StyleBoxFlat:
				style.border_color = Color(1, 1, 0, 1)  # 黄色の枠
				style.border_width_top = 4
				style.border_width_bottom = 4
				style.border_width_left = 4
				style.border_width_right = 4
				button.add_theme_stylebox_override("normal", style)
		else:
			# 非選択ボタンは通常スタイル
			_reset_level_button_style(button, level)

## レベルボタンのスタイルをリセット
func _reset_level_button_style(button: Button, _level: int):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.5, 0.9)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(1, 1, 1, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", style)

## シグナルハンドラ
func _on_land_command_button_pressed():
	land_command_button_pressed.emit()

func _on_cancel_land_command_button_pressed():
	print("[LandCommandUI] キャンセルボタン押下")
	# UIManagerのキャンセル処理を呼び出す
	if ui_manager_ref and ui_manager_ref.has_method("_on_cancel_land_command_button_pressed"):
		ui_manager_ref._on_cancel_land_command_button_pressed()

## クリーチャー情報パネルを閉じる（表示中の場合）
func _close_creature_info_panel_if_open():
	if ui_manager_ref and ui_manager_ref.creature_info_panel_ui:
		if ui_manager_ref.creature_info_panel_ui.is_visible_panel:
			ui_manager_ref.creature_info_panel_ui.hide_panel()

func _on_action_level_up_pressed():
	_close_creature_info_panel_if_open()
	# LandCommandHandlerに通知（キーボード入力をエミュレート）
	var event = InputEventKey.new()
	event.keycode = KEY_L
	event.pressed = true
	Input.parse_input_event(event)

func _on_action_move_pressed():
	_close_creature_info_panel_if_open()
	var event = InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	Input.parse_input_event(event)

func _on_action_swap_pressed():
	_close_creature_info_panel_if_open()
	var event = InputEventKey.new()
	event.keycode = KEY_S
	event.pressed = true
	Input.parse_input_event(event)

func _on_action_terrain_change_pressed():
	_close_creature_info_panel_if_open()
	print("[LandCommandUI] 地形変化ボタン押下")
	hide_action_menu(false)  # グローバルボタンはクリアしない（地形選択で再設定される）
	var event = InputEventKey.new()
	event.keycode = KEY_T
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
	# land_command_handlerのcancel()を呼ぶ（状態管理を統一）
	if ui_manager_ref and ui_manager_ref.game_flow_manager_ref and ui_manager_ref.game_flow_manager_ref.land_command_handler:
		ui_manager_ref.game_flow_manager_ref.land_command_handler.cancel()
	else:
		# フォールバック
		hide_level_selection()
		if selected_tile_for_action >= 0:
			show_action_menu(selected_tile_for_action)

## アクションメニューパネル作成
func create_action_menu_panel(parent: Node):
	if action_menu_panel:
		return
		
	action_menu_panel = Panel.new()
	action_menu_panel.name = "ActionMenuPanel"
	
	# 右側に配置（大きめパネル）
	var viewport_size = parent.get_viewport().get_visible_rect().size
	var panel_width = 630  # 1.4倍
	var panel_height = 840  # 1.4倍
	
	var panel_x = viewport_size.x - panel_width - 42  # 1.4倍
	var panel_y = (viewport_size.y - panel_height) / 2 - 280  # 1.4倍
	
	action_menu_panel.position = Vector2(panel_x, panel_y)
	action_menu_panel.size = Vector2(panel_width, panel_height)
	action_menu_panel.z_index = 1000  # creature_info_panelより上に表示
	action_menu_panel.visible = false
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.5, 0.5, 0.5, 1)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	action_menu_panel.add_theme_stylebox_override("panel", panel_style)
	
	parent.add_child(action_menu_panel)
	
	# ボタンを作成（大きめサイズ、タイトル削除で上から配置）※1.4倍
	var button_y = 42
	var button_spacing = 56
	var button_height = 140
	var button_width = 574
	
	# レベルアップボタン
	var level_up_btn = _create_large_menu_button("📈 [L] レベルアップ", Vector2(28, button_y), Vector2(button_width, button_height), Color(0.2, 0.6, 0.8))
	level_up_btn.pressed.connect(_on_action_level_up_pressed)
	action_menu_panel.add_child(level_up_btn)
	action_menu_buttons["level_up"] = level_up_btn
	button_y += button_height + button_spacing
	
	# 移動ボタン
	var move_btn = _create_large_menu_button("🚶 [M] 移動", Vector2(28, button_y), Vector2(button_width, button_height), Color(0.6, 0.4, 0.8))
	move_btn.pressed.connect(_on_action_move_pressed)
	action_menu_panel.add_child(move_btn)
	action_menu_buttons["move"] = move_btn
	button_y += button_height + button_spacing
	
	# 交換ボタン
	var swap_btn = _create_large_menu_button("🔄 [S] 交換", Vector2(28, button_y), Vector2(button_width, button_height), Color(0.8, 0.6, 0.2))
	swap_btn.pressed.connect(_on_action_swap_pressed)
	action_menu_panel.add_child(swap_btn)
	action_menu_buttons["swap"] = swap_btn
	button_y += button_height + button_spacing
	
	# 地形変化ボタン
	var terrain_btn = _create_large_menu_button("🌍 [T] 地形変化", Vector2(28, button_y), Vector2(button_width, button_height), Color(0.4, 0.8, 0.4))
	terrain_btn.pressed.connect(_on_action_terrain_change_pressed)
	action_menu_panel.add_child(terrain_btn)
	action_menu_buttons["terrain"] = terrain_btn
	# 戻るボタンはグローバルアクションボタンに移行済み

## 大きめメニューボタン作成ヘルパー
func _create_large_menu_button(text: String, pos: Vector2, btn_size: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = btn_size
	btn.add_theme_font_size_override("font_size", 45)  # 1.4倍
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1, 1, 1, 0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	return btn

## レベル選択パネル作成
func create_level_selection_panel(parent: Node):
	if level_selection_panel:
		return
		
	level_selection_panel = Panel.new()
	level_selection_panel.name = "LevelSelectionPanel"
	
	# アクションメニューと同じサイズ・位置 ※1.4倍
	var viewport_size = parent.get_viewport().get_visible_rect().size
	var panel_width = 630
	var panel_height = 840
	
	var panel_x = viewport_size.x - panel_width - 42
	var panel_y = (viewport_size.y - panel_height) / 2 - 280
	
	level_selection_panel.position = Vector2(panel_x, panel_y)
	level_selection_panel.size = Vector2(panel_width, panel_height)
	level_selection_panel.z_index = 1001  # creature_info_panelより上に表示
	level_selection_panel.visible = false
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.15, 0.9)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.2, 0.6, 0.8, 1)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	level_selection_panel.add_theme_stylebox_override("panel", panel_style)
	
	parent.add_child(level_selection_panel)
	
	# 現在レベル表示（タイトルなし、レベル表示のみ）※1.4倍
	current_level_label = Label.new()
	current_level_label.name = "CurrentLevelLabel"
	current_level_label.text = "現在: Lv.1"
	current_level_label.position = Vector2(28, 28)
	current_level_label.add_theme_font_size_override("font_size", 50)  # 1.4倍
	current_level_label.add_theme_color_override("font_color", Color(1, 1, 1))
	level_selection_panel.add_child(current_level_label)
	
	# レベル選択ボタン（2-5）大きめサイズ ※1.4倍
	var button_y = 126
	var button_spacing = 42
	var button_height = 140
	var button_width = 574
	
	# 初期表示用のコスト（後でshow_level_selectionで動的に更新される）
	for level in [2, 3, 4, 5]:
		var btn = _create_large_level_button(level, 0, Vector2(28, button_y), Vector2(button_width, button_height))
		btn.pressed.connect(_on_level_selected.bind(level))
		level_selection_panel.add_child(btn)
		level_selection_buttons[level] = btn
		button_y += button_height + button_spacing
	
	# 戻るボタンはグローバルアクションボタンに移行済み

## 大きめレベルボタン作成ヘルパー
func _create_large_level_button(level: int, cost: int, pos: Vector2, btn_size: Vector2) -> Button:
	var btn = Button.new()
	btn.text = "Lv.%d → %dG" % [level, cost]
	btn.position = pos
	btn.size = btn_size
	btn.add_theme_font_size_override("font_size", 45)  # 1.4倍
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.7)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1, 1, 1, 0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.3, 0.6, 0.8)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.4, 0.6)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	return btn

## メニューボタン作成ヘルパー
func _create_menu_button(text: String, pos: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(252, 70)  # 1.4倍
	
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
	
	btn.add_theme_font_size_override("font_size", 22)  # 1.4倍
	
	return btn
