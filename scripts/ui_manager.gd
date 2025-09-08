extends Node
class_name UIManager

# UI要素の作成・管理・更新システム - 整理版

signal dice_button_pressed()
signal pass_button_pressed()
signal card_selected(card_index: int)

# UI要素
var dice_button: Button
var turn_label: Label
var magic_label: Label
var phase_label: Label

# ダイス表示用
var current_dice_label: Label = null

# デバッグ表示用
var debug_mode = false
var cpu_hand_panel: Panel
var cpu_hand_label: RichTextLabel

# カード選択UI用
var card_selection_buttons = []
var card_selection_active = false

# システム参照（デバッグ表示用）
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null

func _ready():
	pass

# UIを作成
func create_ui(parent: Node):
	# システム参照を取得
	if parent.has_node("CardSystem"):
		card_system_ref = parent.get_node("CardSystem")
	if parent.has_node("PlayerSystem"):
		player_system_ref = parent.get_node("PlayerSystem")
	
	# フェーズ表示
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	phase_label.position = Vector2(350, 50)
	phase_label.add_theme_font_size_override("font_size", 24)
	parent.add_child(phase_label)
	
	# ターン表示
	turn_label = Label.new()
	turn_label.position = Vector2(50, 30)
	turn_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(turn_label)
	
	# 魔力表示
	magic_label = Label.new()
	magic_label.position = Vector2(50, 60)
	magic_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(magic_label)
	
	# サイコロボタン
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	dice_button.position = Vector2(350, 250)
	dice_button.size = Vector2(120, 40)
	dice_button.pressed.connect(_on_dice_button_pressed)
	dice_button.disabled = true
	parent.add_child(dice_button)
	
	# デバッグ表示パネルを作成
	create_debug_panel(parent)

# デバッグパネルを作成
func create_debug_panel(parent: Node):
	# 背景パネル
	cpu_hand_panel = Panel.new()
	cpu_hand_panel.position = Vector2(650, 200)
	cpu_hand_panel.size = Vector2(200, 300)
	cpu_hand_panel.visible = false
	
	# パネルスタイル設定
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.5, 0.5, 0.5, 1)
	cpu_hand_panel.add_theme_stylebox_override("panel", panel_style)
	
	parent.add_child(cpu_hand_panel)
	
	# ラベル
	cpu_hand_label = RichTextLabel.new()
	cpu_hand_label.position = Vector2(10, 10)
	cpu_hand_label.size = Vector2(180, 280)
	cpu_hand_label.bbcode_enabled = true
	cpu_hand_label.add_theme_font_size_override("normal_font_size", 12)
	cpu_hand_panel.add_child(cpu_hand_label)

# カード選択UIを表示
func show_card_selection_ui(current_player):
	if not card_system_ref:
		return
	
	# 既存のボタンをクリア
	for button in card_selection_buttons:
		button.queue_free()
	card_selection_buttons.clear()
	
	# プレイヤーの手札を取得
	var hand_data = card_system_ref.get_all_cards_for_player(current_player.id)
	if hand_data.is_empty():
		return
	
	card_selection_active = true
	
	# 説明テキストを表示
	phase_label.text = "召喚するクリーチャーを選択 (魔力: " + str(current_player.magic_power) + "G)"
	
	# カードを選択可能にする
	card_system_ref.set_cards_selectable(true)
	
	# 手札のカードノードにハイライトを追加
	var hand_nodes = card_system_ref.player_hands[0]["nodes"]
	for i in range(hand_nodes.size()):
		var card_node = hand_nodes[i]
		if card_node and is_instance_valid(card_node):
			# カードにハイライト枠を追加
			var highlight = ColorRect.new()
			highlight.name = "SelectionHighlight"
			highlight.size = card_node.size + Vector2(4, 4)
			highlight.position = Vector2(-2, -2)
			highlight.color = Color(1, 1, 0, 0.3)  # 半透明の黄色
			highlight.z_index = -1
			highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_node.add_child(highlight)
			
			# コストチェック
			var cost = hand_data[i].get("cost", 1) * 10
			if cost > current_player.magic_power:
				# 魔力不足の場合は暗くする
				card_node.modulate = Color(0.5, 0.5, 0.5)
				highlight.color = Color(0.5, 0.5, 0.5, 0.3)
	
	# 「召喚しない」ボタンを手札の右側に配置
	var pass_button_new = Button.new()
	pass_button_new.text = "召喚しない"
	var last_card_x = 100 + hand_data.size() * 120
	pass_button_new.position = Vector2(last_card_x, 620)
	pass_button_new.size = Vector2(100, 80)
	pass_button_new.pressed.connect(_on_pass_button_pressed)
	
	# ボタンスタイル設定
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.8, 0.8, 0.8)
	pass_button_new.add_theme_stylebox_override("normal", button_style)
	
	get_parent().add_child(pass_button_new)
	card_selection_buttons.append(pass_button_new)

# カード選択UIを非表示
func hide_card_selection_ui():
	card_selection_active = false
	
	# カード選択モードを解除
	if card_system_ref:
		card_system_ref.set_cards_selectable(false)
		
		# ハイライトを削除
		var hand_nodes = card_system_ref.player_hands[0]["nodes"]
		for card_node in hand_nodes:
			if card_node and is_instance_valid(card_node):
				# ハイライトを削除
				if card_node.has_node("SelectionHighlight"):
					card_node.get_node("SelectionHighlight").queue_free()
				# 明度を元に戻す
				card_node.modulate = Color(1, 1, 1)
	
	# ボタンをクリア
	for button in card_selection_buttons:
		button.queue_free()
	card_selection_buttons.clear()
	
	# フェーズラベルを元に戻す
	phase_label.text = "アクション選択"

# カードボタンが押された
func _on_card_button_pressed(card_index: int):
	if card_selection_active:
		hide_card_selection_ui()
		emit_signal("card_selected", card_index)

# Dキー入力を処理
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			toggle_debug_mode()

# デバッグモードの切り替え
func toggle_debug_mode():
	debug_mode = !debug_mode
	cpu_hand_panel.visible = debug_mode
	
	if debug_mode and player_system_ref:
		var current_player = player_system_ref.get_current_player()
		if current_player and current_player.id > 0:
			update_cpu_hand_display(current_player.id)
		else:
			# プレイヤー2（CPU）の手札を表示
			update_cpu_hand_display(1)

# CPU手札表示を更新
func update_cpu_hand_display(player_id: int):
	if not debug_mode or not cpu_hand_label or not card_system_ref:
		return
	
	var hand_data = card_system_ref.get_all_cards_for_player(player_id)
	var text = "[b]━━━ プレイヤー" + str(player_id + 1) + "手札 (" + str(hand_data.size()) + "枚) ━━━[/b]\n\n"
	
	if hand_data.is_empty():
		text += "[color=gray]手札なし[/color]"
	else:
		for i in range(hand_data.size()):
			var card = hand_data[i]
			var cost = card.get("cost", 1) * 10
			text += str(i + 1) + ". " + card.get("name", "不明")
			text += " [color=yellow](コスト:" + str(cost) + "G)[/color]\n"
			text += "   ST:" + str(card.get("damage", 0))
			text += " HP:" + str(card.get("block", 0))
			text += " [" + card.get("element", "?") + "]\n\n"
	
	cpu_hand_label.text = text

# UI更新
func update_ui(current_player, current_phase):
	if current_player:
		turn_label.text = current_player.name + "のターン"
		magic_label.text = "魔力: " + str(current_player.magic_power) + " / " + str(current_player.target_magic) + " G"
	
	# フェーズ表示を更新
	update_phase_display(current_phase)

# フェーズ表示を更新
func update_phase_display(phase):
	match phase:
		0: # SETUP
			phase_label.text = "準備中..."
		1: # DICE_ROLL
			phase_label.text = "サイコロを振ってください"
		2: # MOVING
			phase_label.text = "移動中..."
		3: # TILE_ACTION
			phase_label.text = "アクション選択"
		4: # BATTLE
			phase_label.text = "バトル！"
		5: # END_TURN
			phase_label.text = "ターン終了"

# ダイス結果を表示
func show_dice_result(value: int, parent: Node):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# 新しいダイスラベルを作成
	current_dice_label = Label.new()
	current_dice_label.text = "🎲 " + str(value)
	current_dice_label.add_theme_font_size_override("font_size", 48)
	current_dice_label.position = Vector2(350, 300)
	parent.add_child(current_dice_label)

# 魔力不足表示
func show_magic_shortage():
	phase_label.text = "魔力不足 - 召喚不可"

# サイコロボタンの有効/無効
func set_dice_button_enabled(enabled: bool):
	dice_button.disabled = not enabled

# ボタンイベント
func _on_dice_button_pressed():
	emit_signal("dice_button_pressed")

func _on_pass_button_pressed():
	emit_signal("pass_button_pressed")
