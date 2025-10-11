extends Node
class_name CardSelectionUI

# カード選択UI管理クラス
# 召喚・バトル時のカード選択インターフェース

signal card_selected(card_index: int)
signal selection_cancelled()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# UI要素
var selection_buttons = []     # 追加ボタン配列
var pass_button: Button = null # パスボタン
var parent_node: Node          # 親ノード参照
var phase_label_ref: Label     # フェーズラベル参照

# 状態
var is_active = false          # 選択UI表示中か
var selection_mode = ""        # "summon" or "battle"

# システム参照
var card_system_ref: CardSystem = null
var ui_manager_ref = null  # UIManager参照を追加
var game_flow_manager_ref = null  # GameFlowManager参照

func _ready():
	pass

# 初期化
func initialize(parent: Node, card_system: CardSystem, phase_label: Label, ui_manager = null):
	parent_node = parent
	card_system_ref = card_system
	phase_label_ref = phase_label
	ui_manager_ref = ui_manager

# カード選択UIを表示
func show_selection(current_player, mode: String = "summon"):
	if not card_system_ref:
		print("Error: CardSystem reference not set")
		return
	
	# 既存のボタンをクリア
	cleanup_buttons()
	
	# プレイヤーの手札を取得
	var hand_data = card_system_ref.get_all_cards_for_player(current_player.id)
	if hand_data.is_empty():
		emit_signal("selection_cancelled")
		return
	
	is_active = true
	selection_mode = mode
	
	# フェーズラベルを更新
	update_phase_label(current_player, mode)
	
	# デバッグモード（全員手動）またはプレイヤー1の場合、カード選択可能
	var allow_manual = (current_player.id == 0) or (game_flow_manager_ref and game_flow_manager_ref.debug_manual_control_all)
	if allow_manual:
		enable_card_selection(hand_data, current_player.magic_power, current_player.id)
		create_pass_button(hand_data.size())

# フェーズラベルを更新
func update_phase_label(current_player, mode: String):
	if not phase_label_ref:
		return
	
	match mode:
		"summon":
			phase_label_ref.text = "召喚するクリーチャーを選択 (魔力: " + str(current_player.magic_power) + "G)"
		"battle":
			phase_label_ref.text = "バトルするクリーチャーを選択（またはパスで通行料）"
		"invasion":
			phase_label_ref.text = "無防備な土地！侵略するクリーチャーを選択（またはパスで通行料）"
		"discard":
			var hand_size = card_system_ref.get_hand_size_for_player(current_player.id)
			var cards_to_discard = hand_size - 6
			phase_label_ref.text = "手札を6枚まで減らしてください（" + str(cards_to_discard) + "枚捨てる）"
		_:
			phase_label_ref.text = "カードを選択してください"

# カード選択を有効化
func enable_card_selection(hand_data: Array, available_magic: int, player_id: int = 0):
	if not ui_manager_ref:
		return
	
	# UIManagerから手札ノードを取得（指定されたプレイヤーの手札）
	var hand_nodes = ui_manager_ref.player_card_nodes.get(player_id, [])
	for i in range(hand_nodes.size()):
		var card_node = hand_nodes[i]
		if card_node and is_instance_valid(card_node):
			# カードを選択可能にする
			if card_node.has_method("set_selectable"):
				card_node.set_selectable(true, i)
			# 捨て札モードでは全て選択可能、それ以外はコストチェック
			if selection_mode == "discard":
				add_card_highlight(card_node, hand_data[i], 999999)  # 全て選択可能
			else:
				add_card_highlight(card_node, hand_data[i], available_magic)

# カードにハイライトを追加
func add_card_highlight(card_node: Node, card_data: Dictionary, available_magic: int):
	# ハイライト枠を追加
	var highlight = ColorRect.new()
	highlight.name = "SelectionHighlight"
	highlight.size = card_node.size + Vector2(4, 4)
	highlight.position = Vector2(-2, -2)
	highlight.z_index = -1
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# コストチェック
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	if cost > available_magic:
		# 魔力不足の場合
		card_node.modulate = Color(0.5, 0.5, 0.5)
		highlight.color = Color(0.5, 0.5, 0.5, 0.3)
	else:
		# 選択可能
		highlight.color = Color(1, 1, 0, 0.3)
	
	card_node.add_child(highlight)

# パスボタンを作成
func create_pass_button(hand_count: int):
	# 捨て札モードではパスボタンを作らない
	if selection_mode == "discard":
		return
	
	pass_button = Button.new()
	
	# ボタンテキスト設定
	match selection_mode:
		"summon":
			pass_button.text = "召喚しない"
		"battle":
			pass_button.text = "バトルしない"
		"invasion":
			pass_button.text = "侵略しない"
		_:
			pass_button.text = "パス"
	
	# 位置設定（手札の右側）
	# CardUIHelperを使用してレイアウト計算
	var viewport_size = get_viewport().get_visible_rect().size
	var layout = CardUIHelper.calculate_card_layout(viewport_size, hand_count)
	
	# 最後のカードの右側に配置（間隔を空けて）
	var last_card_x = layout.start_x + hand_count * layout.card_width + (hand_count - 1) * layout.spacing + layout.spacing
	pass_button.position = Vector2(last_card_x, layout.card_y)
	pass_button.size = Vector2(layout.card_width, layout.card_height)
	pass_button.pressed.connect(_on_pass_button_pressed)
	
	# ボタンスタイル設定
	apply_button_style(pass_button)
	
	parent_node.add_child(pass_button)
	selection_buttons.append(pass_button)

# ボタンスタイルを適用
func apply_button_style(button: Button):
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.8, 0.8, 0.8)
	button.add_theme_stylebox_override("normal", button_style)

# 選択UIを非表示
func hide_selection():
	is_active = false
	selection_mode = ""
	
	# カード選択モードを解除
	if card_system_ref:
		disable_card_selection()
	
	# ボタンをクリア
	cleanup_buttons()
	
	# フェーズラベルを元に戻す
	if phase_label_ref:
		phase_label_ref.text = "アクション選択"

# カード選択を無効化
func disable_card_selection():
	if not ui_manager_ref:
		return
	
	# UIManagerから手札ノードを取得
	var hand_nodes = ui_manager_ref.player_card_nodes.get(0, [])
	for card_node in hand_nodes:
		if card_node and is_instance_valid(card_node):
			# カードを選択不可にする
			if card_node.has_method("set_selectable"):
				card_node.set_selectable(false)
			remove_card_highlight(card_node)

# カードのハイライトを削除
func remove_card_highlight(card_node: Node):
	# ハイライトを削除
	if card_node.has_node("SelectionHighlight"):
		card_node.get_node("SelectionHighlight").queue_free()
	# 明度を元に戻す
	card_node.modulate = Color(1, 1, 1)

# ボタンをクリーンアップ
func cleanup_buttons():
	for button in selection_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	selection_buttons.clear()
	pass_button = null

# カードが選択された（外部から呼ばれる）
func on_card_selected(card_index: int):
	if is_active:
		hide_selection()
		emit_signal("card_selected", card_index)

# パスボタンが押された
func _on_pass_button_pressed():
	if is_active:
		hide_selection()
		emit_signal("selection_cancelled")

# 選択中かチェック
func is_selection_active() -> bool:
	return is_active

# 現在の選択モードを取得
func get_selection_mode() -> String:
	return selection_mode
