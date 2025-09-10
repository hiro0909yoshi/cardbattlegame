extends Node
class_name UIManager

# UI要素の作成・管理・更新システム - プレイヤー情報パネル追加版

signal dice_button_pressed()
signal pass_button_pressed()
signal card_selected(card_index: int)
signal level_up_selected(target_level: int, cost: int)

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

# プレイヤー情報パネル
var player_info_panels = []
var player_info_labels = []

# カード選択UI用
var card_selection_buttons = []
var card_selection_active = false

# レベルアップUI用
var level_up_panel: Panel = null
var level_up_active = false

# システム参照（デバッグ表示用）
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var board_system_ref: BoardSystem = null

func _ready():
	pass

# UIを作成
func create_ui(parent: Node):
	# システム参照を取得
	if parent.has_node("CardSystem"):
		card_system_ref = parent.get_node("CardSystem")
	if parent.has_node("PlayerSystem"):
		player_system_ref = parent.get_node("PlayerSystem")
	if parent.has_node("BoardSystem"):
		board_system_ref = parent.get_node("BoardSystem")
	
	# フェーズ表示
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	phase_label.position = Vector2(350, 50)
	phase_label.add_theme_font_size_override("font_size", 24)
	parent.add_child(phase_label)
	
	# ターン表示（非表示）
	turn_label = Label.new()
	turn_label.position = Vector2(50, 30)
	turn_label.add_theme_font_size_override("font_size", 16)
	turn_label.visible = false
	parent.add_child(turn_label)
	
	# 魔力表示（非表示）
	magic_label = Label.new()
	magic_label.position = Vector2(50, 60)
	magic_label.add_theme_font_size_override("font_size", 16)
	magic_label.visible = false
	parent.add_child(magic_label)
	
	# サイコロボタン
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	dice_button.position = Vector2(350, 250)
	dice_button.size = Vector2(120, 40)
	dice_button.pressed.connect(_on_dice_button_pressed)
	dice_button.disabled = true
	parent.add_child(dice_button)
	
	# プレイヤー情報パネルを作成
	create_player_info_panels(parent)
	
	# デバッグ表示パネルを作成
	create_debug_panel(parent)

# プレイヤー情報パネルを作成
func create_player_info_panels(parent: Node):
	for i in range(2):  # 2プレイヤー分
		# パネル作成
		var info_panel = Panel.new()
		if i == 0:
			info_panel.position = Vector2(20, 50)  # プレイヤー1は左側
		else:
			info_panel.position = Vector2(600, 50)  # プレイヤー2は右側
		info_panel.size = Vector2(180, 120)
		
		# パネルスタイル設定
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		
		# プレイヤーカラーで枠線
		if i == 0:
			panel_style.border_color = Color(1, 1, 0, 0.8)  # 黄色
		else:
			panel_style.border_color = Color(0, 0.5, 1, 0.8)  # 青
		
		info_panel.add_theme_stylebox_override("panel", panel_style)
		parent.add_child(info_panel)
		player_info_panels.append(info_panel)
		
		# 情報ラベル
		var info_label = RichTextLabel.new()
		info_label.position = Vector2(10, 10)
		info_label.size = Vector2(160, 100)
		info_label.bbcode_enabled = true
		info_label.add_theme_font_size_override("normal_font_size", 12)
		info_panel.add_child(info_label)
		player_info_labels.append(info_label)
	
	# 初期情報を表示
	update_player_info_panels()

# プレイヤー情報パネルを更新
func update_player_info_panels():
	if not player_system_ref or not board_system_ref:
		return
	
	for i in range(player_info_labels.size()):
		if i >= player_system_ref.players.size():
			continue
		
		var player = player_system_ref.players[i]
		var text = "[b]" + player.name + "[/b]\n"
		text += "━━━━━━━━━━━━\n"
		text += "魔力: " + str(player.magic_power) + "/" + str(player.target_magic) + "G\n"
		
		# 土地数を計算
		var land_count = board_system_ref.get_owner_land_count(i)
		text += "土地数: " + str(land_count) + "個\n"
		
		# 総資産を計算（魔力＋土地価値）
		var total_assets = calculate_total_assets(i)
		text += "総資産: " + str(total_assets) + "G\n"
		
		# 属性連鎖を計算
		var chain_info = get_chain_info(i)
		text += "連鎖: " + chain_info
		
		# 現在のプレイヤーの場合はハイライト
		if player_system_ref.current_player_index == i:
			text = "[color=yellow]● 現在のターン[/color]\n" + text
		
		player_info_labels[i].text = text

# 総資産を計算
func calculate_total_assets(player_id: int) -> int:
	var assets = player_system_ref.players[player_id].magic_power
	
	# 土地価値を加算（簡易計算：レベル×100）
	for i in range(board_system_ref.total_tiles):
		if board_system_ref.tile_owners[i] == player_id:
			assets += board_system_ref.tile_levels[i] * 100
	
	return assets

# 属性連鎖情報を取得
func get_chain_info(player_id: int) -> String:
	var element_counts = {}
	
	# 各属性の土地数をカウント
	for i in range(board_system_ref.total_tiles):
		if board_system_ref.tile_owners[i] == player_id:
			var element = board_system_ref.tile_data[i].get("element", "")
			if element != "":
				if element_counts.has(element):
					element_counts[element] += 1
				else:
					element_counts[element] = 1
	
	# 文字列に変換
	var chain_text = ""
	for element in element_counts:
		if chain_text != "":
			chain_text += ", "
		chain_text += element + "×" + str(element_counts[element])
	
	if chain_text == "":
		chain_text = "なし"
	
	return chain_text

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

# レベルアップ選択UIを表示（複数レベル選択対応）
func show_level_up_ui(tile_info: Dictionary, current_magic: int):
	if level_up_panel:
		level_up_panel.queue_free()
	
	level_up_active = true
	
	var current_level = tile_info.get("level", 1)
	var max_level = 5
	var tile_index = tile_info.get("index", 0)
	
	# パネル作成
	level_up_panel = Panel.new()
	level_up_panel.position = Vector2(200, 280)
	level_up_panel.size = Vector2(500, 380)
	level_up_panel.z_index = 50
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.8, 0.8)
	level_up_panel.add_theme_stylebox_override("panel", panel_style)
	
	get_parent().add_child(level_up_panel)
	
	# タイトル
	var title_label = Label.new()
	title_label.text = "土地レベルアップ"
	title_label.position = Vector2(20, 20)
	title_label.add_theme_font_size_override("font_size", 22)
	level_up_panel.add_child(title_label)
	
	# 現在のレベル表示
	var current_level_label = Label.new()
	current_level_label.text = "現在のレベル: " + str(current_level) + " → ?"
	current_level_label.position = Vector2(20, 60)
	current_level_label.add_theme_font_size_override("font_size", 16)
	level_up_panel.add_child(current_level_label)
	
	# 保有魔力表示
	var magic_label_local = Label.new()
	magic_label_local.text = "保有魔力: " + str(current_magic) + "G"
	magic_label_local.position = Vector2(300, 60)
	magic_label_local.add_theme_font_size_override("font_size", 16)
	magic_label_local.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	level_up_panel.add_child(magic_label_local)
	
	# 連鎖ボーナス情報を取得
	var chain_bonus = 1.0
	if board_system_ref:
		var owner = tile_info.get("owner", -1)
		chain_bonus = board_system_ref.calculate_chain_bonus(tile_index, owner)
	
	# 連鎖ボーナス表示
	if chain_bonus > 1.0:
		var chain_label = Label.new()
		chain_label.text = "連鎖ボーナス: ×" + str(chain_bonus)
		chain_label.position = Vector2(20, 85)
		chain_label.add_theme_font_size_override("font_size", 14)
		chain_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		level_up_panel.add_child(chain_label)
	
	# レベル選択ボタンを作成
	var button_y = 110
	for target_level in range(current_level + 1, max_level + 1):
		# 累計コストを計算
		var total_cost = 0
		for lv in range(current_level + 1, target_level + 1):
			total_cost += lv * 100
		
		# 通行料の予想額を計算
		var base_toll = 100
		var expected_toll = int(base_toll * target_level * chain_bonus)
		
		# レベルボタン
		var level_button = Button.new()
		level_button.position = Vector2(20, button_y)
		level_button.size = Vector2(460, 45)
		
		# ボタンテキスト
		var button_text = "レベル" + str(target_level) + "にする"
		button_text += " (コスト: " + str(total_cost) + "G)"
		button_text += " → 通行料: " + str(expected_toll) + "G"
		if chain_bonus > 1.0:
			button_text += " (連鎖込)"
		level_button.text = button_text
		
		# ボタンスタイル
		var btn_style = StyleBoxFlat.new()
		if current_magic >= total_cost:
			# 購入可能
			btn_style.bg_color = Color(0.2, 0.4, 0.2, 0.9)
			btn_style.border_color = Color(0.3, 1.0, 0.3)
			level_button.pressed.connect(_on_level_selected.bind(target_level, total_cost))
		else:
			# 魔力不足
			btn_style.bg_color = Color(0.3, 0.2, 0.2, 0.9)
			btn_style.border_color = Color(0.5, 0.3, 0.3)
			level_button.disabled = true
			level_button.modulate = Color(0.7, 0.7, 0.7)
		
		btn_style.border_width_left = 2
		btn_style.border_width_right = 2
		btn_style.border_width_top = 2
		btn_style.border_width_bottom = 2
		level_button.add_theme_stylebox_override("normal", btn_style)
		
		level_up_panel.add_child(level_button)
		button_y += 55
	
	# キャンセルボタン
	var cancel_button = Button.new()
	cancel_button.text = "レベルアップしない"
	cancel_button.position = Vector2(150, 330)
	cancel_button.size = Vector2(200, 35)
	cancel_button.pressed.connect(_on_level_selected.bind(0, 0))
	
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	cancel_style.border_color = Color(0.7, 0.7, 0.7)
	cancel_style.border_width_left = 2
	cancel_style.border_width_right = 2
	cancel_style.border_width_top = 2
	cancel_style.border_width_bottom = 2
	cancel_button.add_theme_stylebox_override("normal", cancel_style)
	
	level_up_panel.add_child(cancel_button)
	
	# フェーズラベル更新
	phase_label.text = "土地レベルアップ選択"

# レベルアップUIを非表示
func hide_level_up_ui():
	if level_up_panel:
		level_up_panel.queue_free()
		level_up_panel = null
	level_up_active = false
	phase_label.text = "アクション選択"

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
			highlight.color = Color(1, 1, 0, 0.3)
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
	
	# ボード情報も表示
	if debug_mode and board_system_ref:
		board_system_ref.debug_print_all_tiles()

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
	# プレイヤー情報パネルを更新
	update_player_info_panels()
	
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

# レベル選択された
func _on_level_selected(target_level: int, cost: int):
	if level_up_active:
		hide_level_up_ui()
		emit_signal("level_up_selected", target_level, cost)

# ボタンイベント
func _on_dice_button_pressed():
	emit_signal("dice_button_pressed")

func _on_pass_button_pressed():
	emit_signal("pass_button_pressed")
