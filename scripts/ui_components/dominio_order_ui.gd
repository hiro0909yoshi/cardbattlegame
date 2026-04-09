# DominioOrderUI - ドミニオコマンドUI管理
# UIManagerから分離されたドミニオコマンド関連のUI処理
class_name DominioOrderUI
extends Node

const GC = preload("res://scripts/game_constants.gd")

# シグナル
signal level_up_selected(target_level: int, cost: int)

# UI要素
# 注: dominio_order_buttonはGlobalActionButtonsに移行済み
var action_menu_panel: Panel = null  # 互換性のため残す（非表示判定用）
var action_menu_ui: Control = null  # ActionMenuUI
var level_selection_panel: Panel = null
var terrain_selection_panel: Panel = null  # 地形選択パネル
var action_menu_buttons = {}  # "level_up", "move", "swap", "terrain" - 互換性のため残す
var level_selection_buttons = {}  # レベル選択ボタン
var terrain_selection_buttons = {}  # 地形選択ボタン（fire, water, earth, wind）
var current_level_label: Label = null
var current_terrain_label: Label = null  # 現在の属性表示
var terrain_cost_label: Label = null  # 地形変化コスト表示
var selected_tile_for_action: int = -1

# 現在の堅守状態（ActionMenuUI用）
var current_is_defensive: bool = false

# システム参照
var player_system_ref = null
var board_system_ref = null
var ui_manager_ref = null  # UIManagerへの参照
var dominio_command_handler: DominioCommandHandler = null  # DominioCommandHandler直接参照（チェーンアクセス解消）

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
	# NOTE: dominio_command_handler は GameSystemManager から直接注入される（Phase 10-C）

## ドミニオコマンドボタン表示（後方互換 - GlobalActionButtonsに移行済み、空実装）
func show_dominio_order_button():
	pass

## ドミニオコマンドボタン非表示（後方互換 - GlobalActionButtonsに移行済み、空実装）
func hide_dominio_order_button():
	pass

## キャンセルボタン表示（後方互換 - 新方式ではDominioCommandHandlerで設定）
func show_cancel_button():
	# ナビゲーションはDominioCommandHandlerで設定済み
	pass

## キャンセルボタン非表示（後方互換）
func hide_cancel_button():
	# ナビゲーションはDominioCommandHandlerで設定済み
	pass

## アクションメニュー表示
func show_action_menu(tile_index: int):
	selected_tile_for_action = tile_index
	
	# 堅守チェック
	current_is_defensive = false
	if board_system_ref and board_system_ref.tile_nodes.has(tile_index):
		var tile = board_system_ref.tile_nodes[tile_index]
		var creature = tile.creature_data if tile else {}
		
		# クリーチャーがいる場合、情報パネルを表示（ナビに触らない表示のみ）
		if not creature.is_empty() and ui_manager_ref:
			ui_manager_ref.show_card_info_only(creature, tile_index)
		
		# 堅守チェック
		var creature_type = creature.get("creature_type", "normal")
		current_is_defensive = (creature_type == "defensive")
	
	# ActionMenuUIを作成または取得
	_ensure_action_menu_ui()
	
	# メニュー項目を作成
	var menu_items = _create_action_menu_items()
	
	# メニュー表示
	if action_menu_ui:
		action_menu_ui.set_position_left(false)  # 右側（上下ボタンの左）に配置
		action_menu_ui.show_menu(menu_items, "アクション選択")
	
	# フェーズコメント表示
	if ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.show_action_prompt("アクションを選択してください")
	
	# 互換性のためaction_menu_panelのvisibleも設定
	if action_menu_panel:
		action_menu_panel.visible = false  # 旧パネルは使わない


## アクションメニュー用の項目を作成
func _create_action_menu_items() -> Array:
	var items: Array = []
	
	# レベルアップ
	items.append({
		"text": "レベルアップ",
		"color": Color(0.2, 0.6, 0.8),
		"icon": "",
		"disabled": false,
		"action": "level_up"
	})
	
	# 移動（堅守は無効）
	items.append({
		"text": "移動" + (" (堅守)" if current_is_defensive else ""),
		"color": Color(0.6, 0.4, 0.8),
		"icon": "",
		"disabled": current_is_defensive,
		"action": "move"
	})
	
	# 交換
	items.append({
		"text": "交換",
		"color": Color(0.8, 0.6, 0.2),
		"icon": "",
		"disabled": false,
		"action": "swap"
	})
	
	# 地形変化
	items.append({
		"text": "地形変化",
		"color": Color(0.3, 0.7, 0.4),
		"icon": "",
		"disabled": false,
		"action": "terrain"
	})
	
	return items


## ActionMenuUIの作成/取得
func _ensure_action_menu_ui():
	if action_menu_ui:
		return
	
	var ActionMenuUIClass = load("res://scripts/ui_components/action_menu_ui.gd")
	if not ActionMenuUIClass:
		return
	
	action_menu_ui = ActionMenuUIClass.new()
	action_menu_ui.name = "LandActionMenu"
	action_menu_ui.set_ui_manager(ui_manager_ref)
	action_menu_ui.set_menu_size(420, 580, 95, 34, 28)  # 大きめサイズ、間隔広め
	
	# 選択シグナルを接続
	action_menu_ui.item_selected.connect(_on_action_menu_item_selected)
	
	# 親ノードに追加（ui_layerを優先）
	var parent_node = ui_layer if ui_layer else ui_manager_ref
	if parent_node:
		parent_node.add_child(action_menu_ui)


## アクションメニュー項目選択時
func _on_action_menu_item_selected(index: int):
	if index < 0:
		# キャンセル
		_on_cancel_dominio_order_button_pressed()
		return
	
	var items = _create_action_menu_items()
	if index >= items.size():
		return
	
	var action = items[index].get("action", "")
	
	# チュートリアルのアクション制限チェック
	if not _check_tutorial_action_allowed(action):
		print("[DominioOrderUI] チュートリアル制限: %s は選択不可" % action)
		# 入力ロックを解除
		if ui_manager_ref and ui_manager_ref.game_flow_manager_ref:
			ui_manager_ref.game_flow_manager_ref.unlock_input()
		# アクションメニューを再表示
		if selected_tile_for_action >= 0:
			show_action_menu(selected_tile_for_action)
		return
	
	# クリーチャー情報パネルを閉じる
	_close_creature_info_panel_if_open()
	
	match action:
		"level_up":
			_on_action_level_up_pressed()
		"move":
			_on_action_move_pressed()
		"swap":
			_on_action_swap_pressed()
		"terrain":
			_on_action_terrain_change_pressed()


## アクションメニュー非表示
## clear_buttons: グローバルボタンをクリアするかどうか（デフォルト: true）
func hide_action_menu(clear_buttons: bool = true):
	if action_menu_ui:
		action_menu_ui.hide_menu()
	
	if action_menu_panel:
		action_menu_panel.visible = false
	
	selected_tile_for_action = -1
	
	# クリーチャー情報パネルも閉じる（グローバルボタンのクリアは呼び出し側で制御）
	if ui_manager_ref:
		ui_manager_ref.hide_all_info_panels(clear_buttons)

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
				# EPが足りる
				if level_selection_buttons.has(level):
					level_selection_buttons[level].disabled = false
					level_selection_buttons[level].text = "Lv.%d → %dEP" % [level, cost]
			else:
				# EP不足
				if level_selection_buttons.has(level):
					level_selection_buttons[level].disabled = true
					level_selection_buttons[level].text = "Lv.%d → %dEP (不足)" % [level, cost]
	
	level_selection_panel.visible = true
	
	# ナビゲーションボタンはLandActionHelperで設定済み
	
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
				style.border_width_top = 6
				style.border_width_bottom = 6
				style.border_width_left = 6
				style.border_width_right = 6
				button.add_theme_stylebox_override("normal", style)
		else:
			# 非選択ボタンは通常スタイル
			_reset_level_button_style(button, level)

## レベルボタンのスタイルをリセット
func _reset_level_button_style(button: Button, _level: int):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.7)
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_color = Color(1, 1, 1, 0.3)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	button.add_theme_stylebox_override("normal", style)

## チュートリアルのアクション制限をチェック
func _check_tutorial_action_allowed(action: String) -> bool:
	var tutorial_manager = _get_tutorial_manager()
	if not tutorial_manager or not tutorial_manager.is_active:
		return true  # チュートリアル非アクティブ = 制限なし
	return tutorial_manager.is_action_allowed(action)

## チュートリアルのレベル制限をチェック
func _check_tutorial_level_allowed(level: int) -> bool:
	var tutorial_manager = _get_tutorial_manager()
	if not tutorial_manager or not tutorial_manager.is_active:
		return true  # チュートリアル非アクティブ = 制限なし
	return tutorial_manager.is_level_allowed(level)

## TutorialManagerを取得
func _get_tutorial_manager():
	if not ui_manager_ref:
		return null
	var system_manager = ui_manager_ref.get_parent()
	var game_3d = system_manager.get_parent() if system_manager else null
	if not game_3d or not "tutorial_manager" in game_3d:
		return null
	return game_3d.tutorial_manager

## シグナルハンドラ
func _on_cancel_dominio_order_button_pressed():
	print("[DominioOrderUI] キャンセルボタン押下")
	# UIManagerのキャンセル処理を呼び出す
	if ui_manager_ref and ui_manager_ref.has_method("on_cancel_dominio_order_button_pressed"):
		ui_manager_ref.on_cancel_dominio_order_button_pressed()

## クリーチャー情報パネルを閉じる（表示中の場合）
func _close_creature_info_panel_if_open():
	if ui_manager_ref:
		ui_manager_ref.hide_all_info_panels()
		# フェーズコメントもクリア（アクション選択中のコメントを消す）
		if ui_manager_ref.phase_display:
			ui_manager_ref.phase_display.hide_action_prompt()

func _on_action_level_up_pressed():
	_close_creature_info_panel_if_open()
	# DominioCommandHandlerに通知（キーボード入力をエミュレート）
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
	print("[DominioOrderUI] 地形変化ボタン押下")
	hide_action_menu(false)  # グローバルボタンはクリアしない（地形選択で再設定される）
	var event = InputEventKey.new()
	event.keycode = KEY_T
	event.pressed = true
	Input.parse_input_event(event)

func on_level_selected(level: int):
	# チュートリアルのレベル制限チェック
	if not _check_tutorial_level_allowed(level):
		print("[DominioOrderUI] チュートリアル制限: レベル%d は選択不可" % level)
		# 入力ロックを解除
		if ui_manager_ref and ui_manager_ref.game_flow_manager_ref:
			ui_manager_ref.game_flow_manager_ref.unlock_input()
		return
	
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
	print("[DominioOrderUI] レベル選択キャンセル")
	# dominio_command_handlerのcancel()を呼ぶ（状態管理を統一）
	if dominio_command_handler:
		dominio_command_handler.cancel()
	else:
		# フォールバック
		hide_level_selection()
		if selected_tile_for_action >= 0:
			show_action_menu(selected_tile_for_action)

## アクションメニューパネル作成（ActionMenuUIに移行済み、互換性のため残す）
func create_action_menu_panel(_parent: Node):
	# ActionMenuUIを使用するため、旧パネルは作成しない
	pass

## 大きめメニューボタン作成ヘルパー
func _create_large_menu_button(text: String, pos: Vector2, btn_size: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = btn_size
	btn.add_theme_font_size_override("font_size", 23)
	
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
	
	# 画面中央に配置 ※1.5倍サイズ
	var viewport_size = parent.get_viewport().get_visible_rect().size
	var panel_width = 490
	var panel_height = 782

	# 中央配置
	var panel_x = (viewport_size.x - panel_width) / 2
	var panel_y = (viewport_size.y - panel_height) / 2 - 100
	
	level_selection_panel.position = Vector2(panel_x, panel_y)
	level_selection_panel.size = Vector2(panel_width, panel_height)
	level_selection_panel.z_index = 1001
	level_selection_panel.visible = false
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.15, 0.9)
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.border_width_top = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.2, 0.6, 0.8, 1)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	level_selection_panel.add_theme_stylebox_override("panel", panel_style)
	
	parent.add_child(level_selection_panel)
	
	# タイトル
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "レベルアップ"
	title_label.position = Vector2(22, 19)
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	level_selection_panel.add_child(title_label)
	
	# 現在レベル表示
	current_level_label = Label.new()
	current_level_label.name = "CurrentLevelLabel"
	current_level_label.text = "現在: Lv.1"
	current_level_label.position = Vector2(22, 85)
	current_level_label.add_theme_font_size_override("font_size", 33)
	current_level_label.add_theme_color_override("font_color", Color(1, 1, 1))
	level_selection_panel.add_child(current_level_label)
	
	# レベル選択ボタン（2-5）
	var button_y = 151
	var button_spacing = 23
	var button_height = 132
	var button_width = 446
	
	for level in [2, 3, 4, 5]:
		var btn = _create_large_level_button(level, 0, Vector2(22, button_y), Vector2(button_width, button_height))
		btn.pressed.connect(on_level_selected.bind(level))
		level_selection_panel.add_child(btn)
		level_selection_buttons[level] = btn
		button_y += button_height + button_spacing
	
	# 地形選択パネルも作成
	_create_terrain_selection_panel(parent)

## 地形選択パネル作成
func _create_terrain_selection_panel(parent: Node):
	if terrain_selection_panel:
		return
	
	terrain_selection_panel = Panel.new()
	terrain_selection_panel.name = "TerrainSelectionPanel"
	
	# 画面中央に配置 ※1.5倍サイズ
	var viewport_size = parent.get_viewport().get_visible_rect().size
	var panel_width = 490
	var panel_height = 662

	var panel_x = (viewport_size.x - panel_width) / 2
	var panel_y = (viewport_size.y - panel_height) / 2 - 150
	
	terrain_selection_panel.position = Vector2(panel_x, panel_y)
	terrain_selection_panel.size = Vector2(panel_width, panel_height)
	terrain_selection_panel.z_index = 1001
	terrain_selection_panel.visible = false
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.15, 0.9)
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.border_width_top = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.8, 0.4, 0.2, 1)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	terrain_selection_panel.add_theme_stylebox_override("panel", panel_style)
	
	parent.add_child(terrain_selection_panel)
	
	# タイトル
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "地形変化"
	title_label.position = Vector2(22, 19)
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	terrain_selection_panel.add_child(title_label)
	
	# 現在の属性表示
	current_terrain_label = Label.new()
	current_terrain_label.name = "CurrentTerrainLabel"
	current_terrain_label.text = "現在: 火属性"
	current_terrain_label.position = Vector2(22, 85)
	current_terrain_label.add_theme_font_size_override("font_size", 33)
	current_terrain_label.add_theme_color_override("font_color", Color(1, 1, 1))
	terrain_selection_panel.add_child(current_terrain_label)
	
	# コスト表示
	terrain_cost_label = Label.new()
	terrain_cost_label.name = "TerrainCostLabel"
	terrain_cost_label.text = "コスト: 400EP"
	terrain_cost_label.position = Vector2(272, 85)
	terrain_cost_label.add_theme_font_size_override("font_size", 33)
	terrain_cost_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	terrain_selection_panel.add_child(terrain_cost_label)
	
	# 属性選択ボタン（火、水、土、風）
	var elements = [
		{"key": "fire", "name": "火属性", "color": GC.ELEMENT_COLORS["fire"]},
		{"key": "water", "name": "水属性", "color": GC.ELEMENT_COLORS["water"]},
		{"key": "earth", "name": "土属性", "color": GC.ELEMENT_COLORS["earth"]},
		{"key": "wind", "name": "風属性", "color": GC.ELEMENT_COLORS["wind"]}
	]
	
	var button_y = 151
	var button_spacing = 23
	var button_height = 104
	var button_width = 446

	for element in elements:
		var btn = _create_terrain_button(element["name"], element["color"], Vector2(22, button_y), Vector2(button_width, button_height))
		btn.pressed.connect(_on_terrain_selected.bind(element["key"]))
		terrain_selection_panel.add_child(btn)
		terrain_selection_buttons[element["key"]] = btn
		button_y += button_height + button_spacing

## 地形選択ボタン作成
func _create_terrain_button(text: String, color: Color, pos: Vector2, btn_size: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = btn_size
	btn.add_theme_font_size_override("font_size", 35)
	btn.focus_mode = Control.FOCUS_NONE

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(1, 1, 1, 0.3)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
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

## 地形選択パネル表示
func show_terrain_selection(tile_index: int, current_element: String, cost: int, player_magic: int):
	if not terrain_selection_panel:
		return
	
	selected_tile_for_action = tile_index
	
	# アクションメニューを隠す
	if action_menu_panel:
		action_menu_panel.visible = false
	
	# 属性名を日本語に変換
	var element_names = {
		"fire": "火属性",
		"water": "水属性",
		"earth": "土属性",
		"wind": "風属性",
		"neutral": "無属性"
	}
	
	# 現在の属性を表示
	if current_terrain_label:
		current_terrain_label.text = "現在: %s" % element_names.get(current_element, "無属性")
	
	# コストを表示
	if terrain_cost_label:
		terrain_cost_label.text = "コスト: %dEP" % cost
		if player_magic < cost:
			terrain_cost_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		else:
			terrain_cost_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	
	# 各ボタンの有効/無効を設定
	for key in terrain_selection_buttons.keys():
		var btn = terrain_selection_buttons[key]
		if key == current_element:
			# 現在の属性は選択不可
			btn.disabled = true
		elif player_magic < cost:
			# EP不足
			btn.disabled = true
		else:
			btn.disabled = false
	
	terrain_selection_panel.visible = true
	
	# ナビゲーションボタンはLandActionHelperで設定済み

## 地形選択パネル非表示
func hide_terrain_selection():
	if terrain_selection_panel:
		terrain_selection_panel.visible = false

## 地形ボタンのハイライト（上下キー選択用）
func highlight_terrain_button(selected_element: String):
	for key in terrain_selection_buttons.keys():
		var button = terrain_selection_buttons[key]
		if not button:
			continue
		
		if key == selected_element and not button.disabled:
			# 選択中のボタンをハイライト
			var style = StyleBoxFlat.new()
			style.bg_color = GC.ELEMENT_COLORS.get(key, Color(0.5, 0.5, 0.5))
			style.border_color = Color(1, 1, 0, 1)  # 黄色の枠
			style.border_width_top = 6
			style.border_width_bottom = 6
			style.border_width_left = 6
			style.border_width_right = 6
			style.corner_radius_top_left = 15
			style.corner_radius_top_right = 15
			style.corner_radius_bottom_left = 15
			style.corner_radius_bottom_right = 15
			button.add_theme_stylebox_override("normal", style)
		else:
			# 非選択ボタンは通常スタイルに戻す
			_reset_terrain_button_style(button, key)

## 地形ボタンのスタイルをリセット
func _reset_terrain_button_style(button: Button, element: String):
	var base_colors = GC.ELEMENT_COLORS
	var style = StyleBoxFlat.new()
	style.bg_color = base_colors.get(element, Color(0.5, 0.5, 0.5))
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_color = Color(1, 1, 1, 0.3)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	button.add_theme_stylebox_override("normal", style)

## 地形選択ハンドラ
func _on_terrain_selected(element: String):
	# DominioCommandHandlerに通知
	if dominio_command_handler:
		dominio_command_handler.current_terrain_index = dominio_command_handler.terrain_options.find(element)
		LandActionHelper.execute_terrain_change_with_element(dominio_command_handler, element)

## 地形選択キャンセル
func _on_terrain_cancel_pressed():
	if dominio_command_handler:
		dominio_command_handler.cancel()

## 大きめレベルボタン作成ヘルパー
func _create_large_level_button(level: int, cost: int, pos: Vector2, btn_size: Vector2) -> Button:
	var btn = Button.new()
	btn.text = "Lv.%d → %dEP" % [level, cost]
	btn.position = pos
	btn.size = btn_size
	btn.add_theme_font_size_override("font_size", 35)
	btn.focus_mode = Control.FOCUS_NONE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.7)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(1, 1, 1, 0.3)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
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
	btn.size = Vector2(130, 36)
	
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
	
	btn.add_theme_font_size_override("font_size", 12)
	
	return btn
