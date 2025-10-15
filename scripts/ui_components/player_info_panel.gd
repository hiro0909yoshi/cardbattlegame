extends Node
class_name PlayerInfoPanel

# プレイヤー情報パネル管理クラス（3D対応版）
# 各プレイヤーの魔力、土地数、総資産、連鎖情報を表示

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
	
	# 画面サイズに応じた配置（横4分割）
	var viewport_size = get_viewport().get_visible_rect().size
	var area_width = viewport_size.x / 4
	var margin = 50
	var panel_width = area_width - margin
	var panel_height = 240
	
	# プレイヤーIDに応じた位置（0-3で左から順番）
	var panel_x = (area_width * player_id) + int(margin / 2.0)
	var panel_y = 20  # 上部に配置
	
	info_panel.position = Vector2(panel_x, panel_y)
	info_panel.size = Vector2(panel_width, panel_height)
	info_panel.visible = true  # 明示的に表示
	
	# パネルスタイル設定
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	
	# プレイヤーカラーで枠線
	if player_id < GameConstants.PLAYER_COLORS.size():
		# 黄色系の色調整（プレイヤー1用）
		if player_id == 0:
			panel_style.border_color = Color(1, 1, 0, 0.8)
		else:
			panel_style.border_color = Color(0, 0.5, 1, 0.8)
	
	info_panel.add_theme_stylebox_override("panel", panel_style)
	
	# 情報ラベル作成（パネルサイズに応じて調整）
	var info_label = RichTextLabel.new()
	info_label.position = Vector2(10, 10)
	info_label.size = Vector2(panel_width - 20, panel_height - 20)
	info_label.bbcode_enabled = true
	
	# スクロールとクリップの設定
	info_label.scroll_active = false  # スクロール無効
	info_label.fit_content = false    # 内容に合わせて拡大しない
	info_label.clip_contents = true   # はみ出た部分をクリップ
	
	# フォントサイズ（少し小さめに調整）
	var font_size = int(panel_width / 25)  # パネル幅の4%程度
	if font_size < 11:
		font_size = 11  # 最小フォントサイズ
	info_label.add_theme_font_size_override("normal_font_size", font_size)
	info_label.visible = true  # 明示的に表示
	info_panel.add_child(info_label)
	info_labels.append(info_label)
	
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

# プレイヤー情報テキストを構築（簡素化版）
func build_player_info_text(player, player_id: int) -> String:
	var text = ""
	
	# 現在のターンならハイライト
	if player_id == current_turn_player:
		text += "[color=yellow]● [/color]"
	
	text += "[b]" + player.name + "[/b]
"
	
	
	# 魔力
	text += "魔力: " + str(player.magic_power) + "G
"
	
	# 土地数
	var land_count = get_land_count(player_id)
	text += "土地: " + str(land_count) + "個
"
	
	# 総資産
	var total_assets = calculate_total_assets(player_id)
	text += "総資産: " + str(total_assets) + "G
"
	
	# 属性連鎖
	var chain_info = get_chain_info(player_id)
	if chain_info != "なし":
		text += "連鎖: " + chain_info
	
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

# クリーンアップ
func cleanup():
	for panel in panels:
		if panel and is_instance_valid(panel):
			panel.queue_free()
	panels.clear()
	info_labels.clear()
