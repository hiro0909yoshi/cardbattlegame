extends Node
class_name LevelUpUI

# 土地レベルアップUI管理クラス
# 複数レベル選択、コスト計算、連鎖ボーナス表示

signal level_selected(target_level: int, cost: int)
signal selection_cancelled()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# UI要素
var level_up_panel: Panel = null
var level_buttons = []
var parent_node: Node
var phase_label_ref: Label

# 状態
var is_active = false
var current_tile_info = {}

# システム参照
var board_system_ref = null
var ui_manager_ref = null

func _ready():
	pass

# 初期化
func initialize(parent: Node, board_system, phase_label: Label, ui_manager = null):
	parent_node = parent
	board_system_ref = board_system
	phase_label_ref = phase_label
	ui_manager_ref = ui_manager

# レベルアップUIを表示
func show_level_up_selection(tile_info: Dictionary, current_magic: int):
	# 既存のパネルを削除
	hide_selection()
	
	is_active = true
	current_tile_info = tile_info
	
	var current_level = tile_info.get("level", 1)
	var tile_index = tile_info.get("index", 0)
	
	# パネル作成
	level_up_panel = create_panel()
	parent_node.add_child(level_up_panel)
	
	# UI要素を追加
	add_title_label()
	add_current_level_label(current_level)
	add_magic_label(current_magic)
	add_chain_bonus_label(tile_index, tile_info)
	add_level_buttons(current_level, current_magic, tile_index, tile_info)
	add_cancel_button()
	
	# アクション指示パネルで表示
	if ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.show_action_prompt("土地レベルアップ選択")

# パネルを作成
func create_panel() -> Panel:
	var panel = Panel.new()
	panel.position = Vector2(200, 280)
	panel.size = Vector2(500, 380)
	panel.z_index = 50
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.8, 0.8)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	return panel

# タイトルラベルを追加
func add_title_label():
	var title_label = Label.new()
	title_label.text = "土地レベルアップ"
	title_label.position = Vector2(20, 20)
	title_label.add_theme_font_size_override("font_size", 22)
	level_up_panel.add_child(title_label)

# 現在のレベル表示を追加
func add_current_level_label(current_level: int):
	var label = Label.new()
	label.text = "現在のレベル: " + str(current_level) + " → ?"
	label.position = Vector2(20, 60)
	label.add_theme_font_size_override("font_size", 16)
	level_up_panel.add_child(label)

# 保有EP表示を追加
func add_magic_label(current_magic: int):
	var label = Label.new()
	label.text = "保有EP: " + str(current_magic) + "EP"
	label.position = Vector2(300, 60)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	level_up_panel.add_child(label)

# 連鎖ボーナス表示を追加
func add_chain_bonus_label(tile_index: int, tile_info: Dictionary):
	if not board_system_ref:
		return
	
	var tile_owner = tile_info.get("owner", -1)
	var chain_bonus = board_system_ref.calculate_chain_bonus(tile_index, tile_owner)
	
	if chain_bonus > 1.0:
		var label = Label.new()
		label.text = "連鎖ボーナス: ×" + str(chain_bonus)
		label.position = Vector2(20, 85)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		level_up_panel.add_child(label)

# レベル選択ボタンを追加
func add_level_buttons(current_level: int, current_magic: int, tile_index: int, tile_info: Dictionary):
	var button_y = 110
	var chain_bonus = 1.0
	
	if board_system_ref:
		chain_bonus = board_system_ref.calculate_chain_bonus(tile_index, tile_info.get("owner", -1))
	
	for target_level in range(current_level + 1, GameConstants.MAX_LEVEL + 1):
		var button = create_level_button(
			current_level, 
			target_level, 
			current_magic, 
			chain_bonus, 
			button_y
		)
		level_up_panel.add_child(button)
		level_buttons.append(button)
		button_y += 55

# 個別のレベルボタンを作成
func create_level_button(current_level: int, target_level: int, current_magic: int, chain_bonus: float, y_position: int) -> Button:
	# 累計コストを計算（新方式）
	var total_cost = calculate_total_cost(current_level, target_level)
	
	# 通行料の予想額を計算
	var expected_toll = calculate_expected_toll(target_level, chain_bonus)
	
	# ボタン作成
	var button = Button.new()
	button.position = Vector2(20, y_position)
	button.size = Vector2(460, 45)
	
	# ボタンテキスト
	var button_text = build_button_text(target_level, total_cost, expected_toll, chain_bonus)
	button.text = button_text
	
	# ボタンスタイル
	apply_level_button_style(button, current_magic >= total_cost)
	
	# 購入可能な場合のみコネクト
	if current_magic >= total_cost:
		button.pressed.connect(_on_level_selected.bind(target_level, total_cost))
	else:
		button.disabled = true
		button.modulate = Color(0.7, 0.7, 0.7)
	
	return button

# 累計コストを計算（新方式：差額計算）
func calculate_total_cost(current_level: int, target_level: int) -> int:
	var current_value = GameConstants.LEVEL_VALUES.get(current_level, 0)
	var target_value = GameConstants.LEVEL_VALUES.get(target_level, 0)
	return target_value - current_value

# 予想通行料を計算
func calculate_expected_toll(level: int, chain_bonus: float) -> int:
	# レベルに応じた基本通行料
	var base_toll = GameConstants.BASE_TOLL
	return int(base_toll * level * chain_bonus)

# ボタンテキストを構築
func build_button_text(target_level: int, cost: int, toll: int, chain_bonus: float) -> String:
	var text = "レベル" + str(target_level) + "にする"
	text += " (コスト: " + str(cost) + "EP)"
	text += " → 通行料: " + str(toll) + "EP"
	if chain_bonus > 1.0:
		text += " (連鎖込)"
	return text

# レベルボタンのスタイルを適用
func apply_level_button_style(button: Button, can_afford: bool):
	var btn_style = StyleBoxFlat.new()
	
	if can_afford:
		# 購入可能
		btn_style.bg_color = Color(0.2, 0.4, 0.2, 0.9)
		btn_style.border_color = Color(0.3, 1.0, 0.3)
	else:
		# EP不足
		btn_style.bg_color = Color(0.3, 0.2, 0.2, 0.9)
		btn_style.border_color = Color(0.5, 0.3, 0.3)
	
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", btn_style)

# キャンセルボタンを追加（グローバルボタンに移行）
func add_cancel_button():
	# グローバルボタンに登録
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_cancel_pressed, "しない")

# レベルアップUIを非表示
func hide_selection():
	if level_up_panel and is_instance_valid(level_up_panel):
		level_up_panel.queue_free()
		level_up_panel = null
	
	# グローバルボタンをクリア
	if ui_manager_ref:
		ui_manager_ref.clear_back_action()
	
	level_buttons.clear()
	is_active = false
	current_tile_info = {}
	
	# アクション指示パネルを閉じる
	if ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.hide_action_prompt()

# レベルが選択された
func _on_level_selected(target_level: int, cost: int):
	if is_active:
		hide_selection()
		emit_signal("level_selected", target_level, cost)

# キャンセルされた
func _on_cancel_pressed():
	if is_active:
		hide_selection()
		emit_signal("selection_cancelled")

# 選択中かチェック
func is_selection_active() -> bool:
	return is_active
