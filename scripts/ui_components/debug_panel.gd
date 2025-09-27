extends Node
class_name DebugPanel

# デバッグパネル管理クラス
# CPU手札表示、ボード情報表示など

signal debug_mode_changed(enabled: bool)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# UI要素
var debug_panel: Panel = null
var debug_label: RichTextLabel = null
var parent_node: Node

# 状態
var is_visible = false
var current_display_mode = "cpu_hand"  # "cpu_hand", "board_info", "stats"

# システム参照
var card_system_ref: CardSystem = null
var board_system_ref= null
var player_system_ref: PlayerSystem = null

func _ready():
	pass

# 初期化
func initialize(parent: Node, card_system: CardSystem, board_system, player_system: PlayerSystem):
	parent_node = parent
	card_system_ref = card_system
	board_system_ref = board_system
	player_system_ref = player_system
	
	create_debug_panel()

# デバッグパネルを作成
func create_debug_panel():
	# 背景パネル
	debug_panel = Panel.new()
	debug_panel.position = Vector2(650, 200)
	debug_panel.size = Vector2(200, 300)
	debug_panel.visible = false
	
	# パネルスタイル設定
	apply_panel_style()
	
	parent_node.add_child(debug_panel)
	
	# ラベル作成
	create_debug_label()

# パネルスタイルを適用
func apply_panel_style():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.5, 0.5, 0.5, 1)
	debug_panel.add_theme_stylebox_override("panel", panel_style)

# デバッグラベルを作成
func create_debug_label():
	debug_label = RichTextLabel.new()
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(180, 280)
	debug_label.bbcode_enabled = true
	debug_label.add_theme_font_size_override("normal_font_size", 12)
	debug_panel.add_child(debug_label)

# デバッグモードの切り替え
func toggle_visibility():
	is_visible = !is_visible
	debug_panel.visible = is_visible
	
	if is_visible:
		refresh_display()
	
	emit_signal("debug_mode_changed", is_visible)

# 表示モードを設定
func set_display_mode(mode: String):
	current_display_mode = mode
	if is_visible:
		refresh_display()

# 表示を更新
func refresh_display():
	if not is_visible or not debug_label:
		return
	
	match current_display_mode:
		"cpu_hand":
			display_cpu_hand()
		"board_info":
			display_board_info()
		"stats":
			display_game_stats()
		_:
			debug_label.text = "[b]デバッグモード[/b]\n\n表示モード: " + current_display_mode

# CPU手札を表示
func display_cpu_hand(player_id: int = 1):
	if not card_system_ref:
		debug_label.text = "[color=red]CardSystem not found[/color]"
		return
	
	var hand_data = card_system_ref.get_all_cards_for_player(player_id)
	var text = build_cpu_hand_text(player_id, hand_data)
	debug_label.text = text

# CPU手札テキストを構築
func build_cpu_hand_text(player_id: int, hand_data: Array) -> String:
	var text = "[b]━━━ プレイヤー" + str(player_id + 1) + "手札 (" + str(hand_data.size()) + "枚) ━━━[/b]\n\n"
	
	if hand_data.is_empty():
		text += "[color=gray]手札なし[/color]"
	else:
		for i in range(hand_data.size()):
			text += format_card_info(i, hand_data[i])
	
	return text

# カード情報をフォーマット
func format_card_info(index: int, card: Dictionary) -> String:
	var cost = card.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	var text = str(index + 1) + ". " + card.get("name", "不明")
	text += " [color=yellow](コスト:" + str(cost) + "G)[/color]\n"
	text += "   ST:" + str(card.get("damage", 0))
	text += " HP:" + str(card.get("block", 0))
	text += " [" + card.get("element", "?") + "]\n\n"
	return text

# ボード情報を表示
func display_board_info():
	if not board_system_ref:
		debug_label.text = "[color=red]BoardSystem not found[/color]"
		return
	
	var text = "[b]━━━ ボード情報 ━━━[/b]\n\n"
	var owned_tiles = count_owned_tiles()
	
	text += "プレイヤー1: " + str(owned_tiles[0]) + "個\n"
	text += "プレイヤー2: " + str(owned_tiles[1]) + "個\n"
	text += "空き地: " + str(owned_tiles[-1]) + "個\n\n"
	
	text += "[b]属性連鎖:[/b]\n"
	text += get_chain_summary()
	
	debug_label.text = text

# 所有タイル数をカウント
func count_owned_tiles() -> Dictionary:
	var counts = {-1: 0, 0: 0, 1: 0}
	
	if board_system_ref:
		for i in range(board_system_ref.total_tiles):
			if counts.has(board_system_ref.tile_owners[i]):
				counts[board_system_ref.tile_owners[i]] += 1
	
	return counts

# 属性連鎖サマリーを取得
func get_chain_summary() -> String:
	if not board_system_ref:
		return "データなし"
	
	var text = ""
	for player_id in range(2):
		text += "P" + str(player_id + 1) + ": "
		var chains = get_player_chains(player_id)
		if chains.is_empty():
			text += "なし"
		else:
			for element in chains:
				text += element + "×" + str(chains[element]) + " "
		text += "\n"
	
	return text

# プレイヤーの属性連鎖を取得
func get_player_chains(player_id: int) -> Dictionary:
	var chains = {}
	
	if board_system_ref:
		for i in range(board_system_ref.total_tiles):
			if board_system_ref.tile_owners[i] == player_id:
				var element = board_system_ref.tile_data[i].get("element", "")
				if element != "":
					if chains.has(element):
						chains[element] += 1
					else:
						chains[element] = 1
	
	return chains

# ゲーム統計を表示
func display_game_stats():
	if not player_system_ref:
		debug_label.text = "[color=red]PlayerSystem not found[/color]"
		return
	
	var text = "[b]━━━ ゲーム統計 ━━━[/b]\n\n"
	
	for i in range(player_system_ref.players.size()):
		var player = player_system_ref.players[i]
		text += "[b]" + player.name + "[/b]\n"
		text += "魔力: " + str(player.magic_power) + "G\n"
		text += "位置: マス" + str(player.current_tile) + "\n\n"
	
	debug_label.text = text

# 特定プレイヤーのCPU手札を更新
func update_cpu_hand(player_id: int):
	if is_visible and current_display_mode == "cpu_hand":
		display_cpu_hand(player_id)

# 可視性を取得
func is_debug_visible() -> bool:
	return is_visible

# クリーンアップ
func cleanup():
	if debug_panel and is_instance_valid(debug_panel):
		debug_panel.queue_free()
	debug_panel = null
	debug_label = null
