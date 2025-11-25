extends Node
class_name PlayerInfoPanel

# プレイヤー情報パネル管理クラス（3D対応版）
# 各プレイヤーの魔力、総魔力情報を簡潔に表示

# シグナル
signal player_panel_clicked(player_id: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# パネル要素
var panels = []           # Panel配列
var info_labels = []      # RichTextLabel配列
var parent_node: Node     # 親ノード参照

# システム参照（型指定なし - 3D対応）
var player_system_ref = null
var board_system_ref = null

# 設定
var panel_count = 2       # 表示するパネル数
var current_turn_player = -1  # 現在のターンプレイヤー

# パネルサイズ（固定値）
var panel_width = 160
var panel_height = 105
var panel_spacing = 10
var start_x = 20
var start_y = 20

func _ready():
	pass

# 初期化（親ノードとシステム参照を設定）
func initialize(parent: Node, player_system: PlayerSystem, board_system, count: int = 2):
	parent_node = parent
	player_system_ref = player_system
	board_system_ref = board_system
	panel_count = count
	
	create_panels()
	update_all_panels()

# パネルを作成
func create_panels():
	for i in range(panel_count):
		var panel = create_single_panel(i)
		parent_node.add_child(panel)
		panels.append(panel)
		

# 単一パネルを作成
func create_single_panel(player_id: int) -> Panel:
	var info_panel = Panel.new()
	
	# 縦積み配置（左上から順に）
	var panel_x = start_x
	var panel_y = start_y + (panel_height + panel_spacing) * player_id
	
	info_panel.position = Vector2(panel_x, panel_y)
	info_panel.size = Vector2(panel_width, panel_height)
	info_panel.visible = true
	
	# パネルスタイル設定
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	
	# プレイヤーカラーで枠線（GameConstants.PLAYER_COLORS を使用）
	if player_id < GameConstants.PLAYER_COLORS.size():
		panel_style.border_color = GameConstants.PLAYER_COLORS[player_id]
	else:
		panel_style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	
	info_panel.add_theme_stylebox_override("panel", panel_style)
	
	# パネルのマウスフィルター設定（クリック検出を有効にする）
	info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 情報ラベル作成
	var info_label = RichTextLabel.new()
	info_label.position = Vector2(8, 8)
	info_label.size = Vector2(panel_width - 16, panel_height - 16)
	info_label.bbcode_enabled = true
	
	# マウスイベントを親に渡す（パネルクリックを優先）
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# スクロールとクリップの設定
	info_label.scroll_active = false
	info_label.fit_content = false
	info_label.clip_contents = true
	
	# フォントサイズを固定値に（魔力・総魔力表示用に大きめに）
	info_label.add_theme_font_size_override("normal_font_size", 20)
	info_label.visible = true
	info_panel.add_child(info_label)
	info_labels.append(info_label)
	
	# クリック検出を接続
	info_panel.gui_input.connect(_on_panel_clicked.bind(player_id))
	
	return info_panel

# 全パネルを更新
func update_all_panels():
	if not player_system_ref or not board_system_ref:
		return
	
	for i in range(info_labels.size()):
		update_single_panel(i)

# 単一パネルを更新
func update_single_panel(player_id: int):
	if not player_system_ref:
		return
		
	if player_id >= player_system_ref.players.size():
		return
	
	if player_id >= info_labels.size():
		return
	
	var player = player_system_ref.players[player_id]
	var text = build_player_info_text(player, player_id)
	info_labels[player_id].text = text

# プレイヤー情報テキストを構築（簡潔版）
func build_player_info_text(player, player_id: int) -> String:
	var text = ""
	
	# 現在のターンならハイライト
	if player_id == current_turn_player:
		text += "[color=yellow]● [/color]"
	
	text += "[b]" + player.name + "[/b]\n"
	text += "魔力: " + str(player.magic_power) + "G\n"
	text += "総魔力: " + str(calculate_total_assets(player_id)) + "G"
	
	return text

# 土地数を取得（3D対応版）
func get_land_count(player_id: int) -> int:
	if not board_system_ref:
		return 0
	
	# 共通メソッドを使用
	if board_system_ref.has_method("get_owner_land_count"):
		return board_system_ref.get_owner_land_count(player_id)
	
	return 0

# 総資産を計算（魔力＋土地価値）- 新方式
func calculate_total_assets(player_id: int) -> int:
	if not player_system_ref or not board_system_ref:
		return 0
	
	var assets = player_system_ref.players[player_id].magic_power
	
	# 3D版
	if board_system_ref != null and "tile_nodes" in board_system_ref:
		for i in board_system_ref.tile_nodes:
			var tile = board_system_ref.tile_nodes[i]
			if tile.owner_id == player_id:
				# 土地の価値を加算（LEVEL_VALUESから取得）
				var level_value = GameConstants.LEVEL_VALUES.get(tile.level, 0)
				assets += level_value
	
	
	return assets

# 属性連鎖情報を取得
func get_chain_info(player_id: int) -> String:
	if not board_system_ref:
		return "なし"
	
	var element_counts = {}
	
	# タイル情報を取得
	if board_system_ref.has_method("get_tile_data_array"):
		# get_tile_data_array()を使用（推奨）
		var tile_data = board_system_ref.get_tile_data_array()
		for tile_info in tile_data:
			if tile_info["owner"] == player_id:
				var element = tile_info["element"]
				if element != "" and element in ["火", "水", "風", "土"]:
					if element_counts.has(element):
						element_counts[element] += 1
					else:
						element_counts[element] = 1
	elif "tile_nodes" in board_system_ref:
		# tile_nodesへの直接アクセス（フォールバック）
		for i in board_system_ref.tile_nodes:
			var tile = board_system_ref.tile_nodes[i]
			if tile.owner_id == player_id:
				var element = tile.tile_type
				if element != "" and element in ["火", "水", "風", "土"]:
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

# パネルがクリックされたときのハンドラ
func _on_panel_clicked(event: InputEvent, player_id: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("player_panel_clicked", player_id)

# 現在のターンプレイヤーを設定
func set_current_turn(player_id: int):
	current_turn_player = player_id
	update_all_panels()

# 特定プレイヤーの情報のみ更新
func update_player(player_id: int):
	if player_id >= 0 and player_id < info_labels.size():
		update_single_panel(player_id)

# パネルの表示/非表示
func set_visible(visible: bool):
	for panel in panels:
		panel.visible = visible

# パネルの位置を調整
func set_panel_position(player_id: int, position: Vector2):
	if player_id >= 0 and player_id < panels.size():
		panels[player_id].position = position

# 属性を英語から日本語にマッピング
var ELEMENT_MAP = {
	"fire": "火",
	"water": "水",
	"wind": "風",
	"earth": "土",
	"neutral": "無",
	"checkpoint": "無"
}

# 土地情報を属性ごとに取得（ステータスダイアログ用）
func get_lands_by_element(player_id: int) -> Dictionary:
	var element_counts = {"火": 0, "水": 0, "風": 0, "土": 0, "無": 0}
	
	if not board_system_ref:
		return element_counts
	
	# tile_nodes を優先的に使用（クリーチャー情報も必要なため）
	if "tile_nodes" in board_system_ref:
		for i in board_system_ref.tile_nodes:
			var tile = board_system_ref.tile_nodes[i]
			if tile.owner_id == player_id:
				var english_element = tile.tile_type
				var jp_element = ELEMENT_MAP.get(english_element, "無")
				print("[PlayerInfoPanel] 土地: tile ", i, " type=", english_element, " -> ", jp_element)
				if jp_element in element_counts:
					element_counts[jp_element] += 1
	
	print("[PlayerInfoPanel] 土地カウント結果: ", element_counts)
	return element_counts

# 保有クリーチャー情報を取得（ステータスダイアログ用）
func get_creatures_on_lands(player_id: int) -> Array:
	var creatures = []
	
	if not board_system_ref:
		return creatures
	
	# tile_nodes から直接クリーチャーを取得（get_tile_data_array には creature がないため）
	if "tile_nodes" in board_system_ref:
		for i in board_system_ref.tile_nodes:
			var tile = board_system_ref.tile_nodes[i]
			if tile.owner_id == player_id:
				if tile.creature_data and not tile.creature_data.is_empty():
					creatures.append(tile.creature_data)
	return creatures

# クリーンアップ
func cleanup():
	for panel in panels:
		if panel and is_instance_valid(panel):
			panel.queue_free()
	panels.clear()
	info_labels.clear()
