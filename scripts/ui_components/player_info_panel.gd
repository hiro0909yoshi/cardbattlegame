extends Node
class_name PlayerInfoPanel

# プレイヤー情報パネル管理クラス（3D対応版）
# 各プレイヤーのEP、TEP情報を簡潔に表示

# シグナル
signal player_panel_clicked(player_id: int)

# 定数をpreload

# パネル要素
var panels = []           # Panel配列
var info_labels = []      # RichTextLabel配列
var parent_node: Node     # 親ノード参照

# システム参照（型指定なし - 3D対応）
var player_system_ref = null
var board_system_ref = null
var game_flow_manager_ref = null  # 世界呪い取得用

# 世界呪い表示用
var world_curse_label: RichTextLabel = null

# 設定
var panel_count = 2       # 表示するパネル数
var current_turn_player = -1  # 現在のターンプレイヤー

# パネルサイズ（固定値）※1.4倍
var panel_width = 260
var panel_height = 190
var panel_spacing = 14
var start_x = 28
var start_y = 28

func _ready():
	pass

# 初期化（親ノードとシステム参照を設定）
func initialize(parent: Node, player_system: PlayerSystem, board_system, count: int = 2):
	parent_node = parent
	player_system_ref = player_system
	board_system_ref = board_system
	panel_count = count
	
	create_panels()
	create_world_curse_label()
	update_all_panels()
	
	# EP変更シグナルを接続（即座更新用）
	if player_system_ref:
		player_system_ref.magic_changed.connect(_on_magic_changed)

# GameFlowManager参照を設定（世界呪い表示用、ターン開始シグナル接続用）
func set_game_flow_manager(gfm):
	game_flow_manager_ref = gfm
	
	# ターン開始シグナルを接続（ターン開始時に即座に順番アイコンを更新）
	if game_flow_manager_ref:
		game_flow_manager_ref.turn_started.connect(_on_turn_started)
	
	# シグナル取得時にパネルを即座更新
	if game_flow_manager_ref and game_flow_manager_ref.lap_system:
		game_flow_manager_ref.lap_system.checkpoint_signal_obtained.connect(_on_signal_obtained)

# パネルを作成
func create_panels():
	for i in range(panel_count):
		var panel = create_single_panel(i)
		parent_node.add_child(panel)
		panels.append(panel)

# 世界呪いラベルを作成
func create_world_curse_label():
	world_curse_label = RichTextLabel.new()
	
	# プレイヤーパネルの下に配置
	var label_y = start_y + (panel_height + panel_spacing) * panel_count
	world_curse_label.position = Vector2(start_x, label_y)
	world_curse_label.size = Vector2(panel_width, 42)
	world_curse_label.bbcode_enabled = true
	world_curse_label.scroll_active = false
	world_curse_label.fit_content = false
	world_curse_label.add_theme_font_size_override("normal_font_size", 22)
	world_curse_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_curse_label.visible = false  # 初期は非表示
	
	parent_node.add_child(world_curse_label)
		

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
	info_label.position = Vector2(11, 11)
	info_label.size = Vector2(panel_width - 22, panel_height - 22)
	info_label.bbcode_enabled = true
	
	# マウスイベントを親に渡す（パネルクリックを優先）
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# スクロールとクリップの設定
	info_label.scroll_active = false
	info_label.fit_content = false
	info_label.clip_contents = true
	
	# フォントサイズを固定値に（EP・TEP表示用に大きめに）※1.4倍
	info_label.add_theme_font_size_override("normal_font_size", 28)
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
	
	# 世界呪いラベルを更新
	update_world_curse_label()

# 世界呪いラベルを更新
func update_world_curse_label():
	if not world_curse_label:
		return
	
	var world_curse = {}
	if game_flow_manager_ref and "game_stats" in game_flow_manager_ref:
		world_curse = game_flow_manager_ref.game_stats.get("world_curse", {})
	
	if world_curse.is_empty():
		world_curse_label.visible = false
	else:
		var curse_name = world_curse.get("name", "世界呪い")
		var duration = world_curse.get("duration", 0)
		world_curse_label.text = "[color=purple]世界: %s (%dR)[/color]" % [curse_name, duration]
		world_curse_label.visible = true

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
	
	# 順位を取得して表示
	var ranking = get_player_ranking(player_id)
	text += "[b]" + str(ranking) + "[/b] "
	
	# 現在のターンならハイライト
	if player_id == current_turn_player:
		text += "[color=yellow]● [/color]"
	
	text += "[b]" + player.name + "[/b]\n"
	text += "EP: " + str(player.magic_power) + "EP\n"
	text += "TEP: " + str(calculate_total_assets(player_id)) + "EP\n"
	
	# 取得済みシグナル表示
	text += _build_signal_text(player_id)
	
	# プレイヤー呪いがあれば別行で表示
	if player.curse and not player.curse.is_empty():
		var curse_name = player.curse.get("name", "呪い")
		text += "\n[color=red]呪: " + curse_name + "[/color]"
	
	return text

# 取得済みシグナルテキストを構築
func _build_signal_text(player_id: int) -> String:
	if not game_flow_manager_ref or not game_flow_manager_ref.lap_system:
		return ""
	
	var lap_system = game_flow_manager_ref.lap_system
	var required = lap_system.required_checkpoints
	var player_state = lap_system.player_lap_state.get(player_id, {})
	
	var parts = []
	for cp in required:
		if player_state.get(cp, false):
			parts.append("[color=yellow]%s[/color]" % cp)
		else:
			parts.append("[color=gray]%s[/color]" % cp)
	
	return "SG: " + " ".join(parts)

# 土地数を取得（3D対応版）
func get_land_count(player_id: int) -> int:
	if not board_system_ref:
		return 0
	
	# 共通メソッドを使用
	if board_system_ref.has_method("get_owner_land_count"):
		return board_system_ref.get_owner_land_count(player_id)
	
	return 0

# TEPを計算（PlayerSystemに委譲）
func calculate_total_assets(player_id: int) -> int:
	if not player_system_ref:
		return 0
	return player_system_ref.calculate_total_assets(player_id)

# 全プレイヤーの順位を計算（TEP降順、1位=1）
func calculate_all_rankings() -> Array:
	if not player_system_ref:
		return []
	
	# 各プレイヤーのTEPを取得
	var player_assets = []
	for i in range(player_system_ref.players.size()):
		player_assets.append({
			"player_id": i,
			"total": calculate_total_assets(i)
		})
	
	# TEP降順でソート
	player_assets.sort_custom(func(a, b): return a["total"] > b["total"])
	
	# 順位を割り当て（同率は同順位）
	var rankings = []
	rankings.resize(player_system_ref.players.size())
	
	var current_rank = 1
	var prev_total = -1
	for i in range(player_assets.size()):
		var entry = player_assets[i]
		if entry["total"] != prev_total:
			current_rank = i + 1
		rankings[entry["player_id"]] = current_rank
		prev_total = entry["total"]
	
	return rankings

# 特定プレイヤーの順位を取得
func get_player_ranking(player_id: int) -> int:
	var rankings = calculate_all_rankings()
	if player_id >= 0 and player_id < rankings.size():
		return rankings[player_id]
	return 0

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

# EP変更時コールバック（即座更新用）
func _on_magic_changed(player_id: int, _new_value: int):
	update_player(player_id)

# ターン開始時コールバック（順番アイコン即座更新用）
func _on_turn_started(player_id: int):
	set_current_turn(player_id)

# シグナル取得時の即座更新
func _on_signal_obtained(_player_id: int, _checkpoint_type: String):
	update_all_panels()

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
				if jp_element in element_counts:
					element_counts[jp_element] += 1
	
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
