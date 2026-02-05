class_name MapPreviewDialog
extends Window

## マッププレビューダイアログ
## 左: マップリスト、右: タイル配置の2Dプレビュー

const MAP_DIR = "res://data/master/maps/"

# タイルタイプ別の色定義
const TILE_COLORS = {
	"Fire": Color(1.0, 0.4, 0.4),
	"Water": Color(0.4, 0.6, 1.0),
	"Earth": Color(0.8, 0.6, 0.3),
	"Wind": Color(0.4, 1.0, 0.6),
	"Neutral": Color(0.6, 0.6, 0.6),
	"Checkpoint": Color(1.0, 0.9, 0.3),
	"Warp": Color(1.0, 0.5, 0.0),
	"WarpStop": Color(0.8, 0.3, 0.8),
	"CardBuy": Color(0.3, 0.8, 0.8),
	"CardGive": Color(0.3, 0.8, 0.8),
	"Magic": Color(0.9, 0.3, 0.9),
	"MagicStone": Color(0.7, 0.5, 0.9),
	"Branch": Color(1.0, 0.7, 0.3),
	"Base": Color(0.5, 0.9, 0.5),
	"Blank": Color(0.4, 0.4, 0.4),
}

# タイルタイプの日本語名
const TILE_TYPE_NAMES = {
	"Fire": "火", "Water": "水", "Earth": "土", "Wind": "風",
	"Neutral": "無", "Checkpoint": "CP", "Warp": "WP",
	"WarpStop": "WS", "CardBuy": "購", "CardGive": "配",
	"Magic": "魔", "MagicStone": "石", "Branch": "分", "Base": "拠",
	"Blank": "空",
}

var map_list: Array = []
var map_item_list: ItemList
var preview_container: Control
var info_label: Label
var legend_container: HBoxContainer

func _init():
	title = "マッププレビュー"
	size = Vector2i(1800, 1100)
	unresizable = false
	close_requested.connect(_on_close)

func _ready():
	_build_ui()
	_load_map_list()

# ============================================
# UI構築
# ============================================

func _build_ui():
	var margin = MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	# === 左パネル: マップリスト ===
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.size_flags_horizontal = Control.SIZE_FILL
	hbox.add_child(left_panel)

	var list_title = Label.new()
	list_title.text = "マップ一覧"
	list_title.add_theme_font_size_override("font_size", 28)
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(list_title)

	map_item_list = ItemList.new()
	map_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_item_list.add_theme_font_size_override("font_size", 24)
	map_item_list.item_selected.connect(_on_map_selected)
	left_panel.add_child(map_item_list)

	# === 右パネル: プレビュー ===
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 2.5
	right_panel.add_theme_constant_override("separation", 10)
	hbox.add_child(right_panel)

	# マップ情報
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.text = "マップを選択してください"
	right_panel.add_child(info_label)

	# プレビュー領域
	var preview_panel = PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	style.set_corner_radius_all(8)
	preview_panel.add_theme_stylebox_override("panel", style)
	right_panel.add_child(preview_panel)

	preview_container = Control.new()
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview_container)

	# 凡例
	legend_container = HBoxContainer.new()
	legend_container.add_theme_constant_override("separation", 15)
	right_panel.add_child(legend_container)
	_build_legend()

func _build_legend():
	var legend_types = ["Fire", "Water", "Earth", "Wind", "Neutral", "Checkpoint", "Branch", "Warp", "Magic"]
	for tile_type in legend_types:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		legend_container.add_child(hbox)

		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = TILE_COLORS.get(tile_type, Color.WHITE)
		hbox.add_child(color_rect)

		var lbl = Label.new()
		lbl.text = TILE_TYPE_NAMES.get(tile_type, tile_type)
		lbl.add_theme_font_size_override("font_size", 18)
		hbox.add_child(lbl)

# ============================================
# マップデータ読み込み
# ============================================

func _load_map_list():
	map_list.clear()
	map_item_list.clear()

	var dir = DirAccess.open(MAP_DIR)
	if not dir:
		print("[MapPreview] マップディレクトリが開けません: %s" % MAP_DIR)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var map_data = _load_map_json(MAP_DIR + file_name)
			if map_data and map_data.has("tiles"):
				map_list.append(map_data)
		file_name = dir.get_next()
	dir.list_dir_end()

	# 名前でソート
	map_list.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))

	for map_data in map_list:
		var display_name = "%s (%dマス)" % [map_data.get("name", "不明"), map_data.get("tile_count", 0)]
		map_item_list.add_item(display_name)

func _load_map_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		print("[MapPreview] JSONパースエラー: %s" % path)
		return {}
	return json.data if json.data is Dictionary else {}

# ============================================
# マップ選択 → プレビュー描画
# ============================================

func _on_map_selected(index: int):
	if index < 0 or index >= map_list.size():
		return
	var map_data = map_list[index]
	_update_info(map_data)
	_draw_preview(map_data)

func _update_info(map_data: Dictionary):
	var name_text = map_data.get("name", "不明")
	var desc_text = map_data.get("description", "")
	var tile_count = map_data.get("tile_count", 0)
	var checkpoint_preset = map_data.get("checkpoint_preset", "standard")

	var info = "%s  |  %dマス  |  CP: %s" % [name_text, tile_count, checkpoint_preset]
	if desc_text != "":
		info += "\n%s" % desc_text
	info_label.text = info

func _draw_preview(map_data: Dictionary):
	# 既存の描画をクリア
	for child in preview_container.get_children():
		child.queue_free()

	var tiles = map_data.get("tiles", [])
	if tiles.is_empty():
		return

	# 座標の範囲を計算（JSON座標は4単位刻み）
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF
	for tile in tiles:
		var tx = float(tile.get("x", 0))
		var tz = float(tile.get("z", 0))
		min_x = min(min_x, tx)
		max_x = max(max_x, tx)
		min_z = min(min_z, tz)
		max_z = max(max_z, tz)

	# グリッド単位に変換（4で割る）
	var grid_step = 4.0
	var grid_cols = int((max_x - min_x) / grid_step) + 1
	var grid_rows = int((max_z - min_z) / grid_step) + 1

	# 1フレーム待ってコンテナサイズを確定させる
	await get_tree().process_frame

	var container_size = preview_container.size
	if container_size.x <= 0 or container_size.y <= 0:
		container_size = Vector2(900, 700)

	# タイルサイズ計算（領域に収まるように）
	var padding = 30.0
	var available_w = container_size.x - padding * 2
	var available_h = container_size.y - padding * 2

	# グリッド間の隙間を考慮（タイルサイズ + gap）
	var gap = 3.0
	var size_by_w = (available_w - gap * (grid_cols - 1)) / grid_cols
	var size_by_h = (available_h - gap * (grid_rows - 1)) / grid_rows
	var tile_size = min(size_by_w, size_by_h)
	tile_size = clamp(tile_size, 16.0, 64.0)

	# 全体の描画サイズ
	var total_w = grid_cols * tile_size + (grid_cols - 1) * gap
	var total_h = grid_rows * tile_size + (grid_rows - 1) * gap

	# 中央揃えオフセット
	var offset_x = (container_size.x - total_w) / 2.0
	var offset_z = (container_size.y - total_h) / 2.0

	# connections情報を取得
	var connections = map_data.get("connections", {})

	# タイル間の接続線を描画
	_draw_connections(tiles, connections, min_x, min_z, grid_step, tile_size, gap, offset_x, offset_z)

	# タイルを描画
	for tile in tiles:
		var tx = float(tile.get("x", 0))
		var tz = float(tile.get("z", 0))
		var tile_type = tile.get("type", "Neutral")
		var tile_index = tile.get("index", -1)

		var col = (tx - min_x) / grid_step
		var row = (tz - min_z) / grid_step
		var px = col * (tile_size + gap) + offset_x
		var pz = row * (tile_size + gap) + offset_z

		_create_tile_node(px, pz, tile_size, tile_type, tile_index, tile)

func _draw_connections(tiles: Array, connections: Dictionary, min_x: float, min_z: float, grid_step: float, tile_size: float, gap: float, offset_x: float, offset_z: float):
	# タイルインデックス → 中心座標のマップを作成
	var tile_positions = {}
	for tile in tiles:
		var idx = tile.get("index", -1)
		var tx = float(tile.get("x", 0))
		var tz = float(tile.get("z", 0))
		var col = (tx - min_x) / grid_step
		var row = (tz - min_z) / grid_step
		var cx = col * (tile_size + gap) + offset_x + tile_size / 2.0
		var cz = row * (tile_size + gap) + offset_z + tile_size / 2.0
		tile_positions[idx] = Vector2(cx, cz)

	# 隣接タイル（index順）を線で結ぶ
	for i in range(tiles.size()):
		var current_idx = tiles[i].get("index", i)
		var next_idx = current_idx + 1
		if i == tiles.size() - 1:
			next_idx = tiles[0].get("index", 0)

		if tile_positions.has(current_idx) and tile_positions.has(next_idx):
			var from_pos = tile_positions[current_idx]
			var to_pos = tile_positions[next_idx]
			var line = Line2D.new()
			line.add_point(from_pos)
			line.add_point(to_pos)
			line.width = 2.0
			line.default_color = Color(0.4, 0.4, 0.5, 0.6)
			preview_container.add_child(line)

	# 特殊接続（connections）を描画
	for from_str in connections:
		var from_idx = int(from_str)
		var to_list = connections[from_str]
		if to_list is Array:
			for to_idx in to_list:
				if tile_positions.has(from_idx) and tile_positions.has(int(to_idx)):
					var from_pos = tile_positions[from_idx]
					var to_pos = tile_positions[int(to_idx)]
					var line = Line2D.new()
					line.add_point(from_pos)
					line.add_point(to_pos)
					line.width = 2.0
					line.default_color = Color(0.6, 0.6, 0.3, 0.4)
					preview_container.add_child(line)

	# 特殊接続（connections）を描画
	for from_str in connections:
		var from_idx = int(from_str)
		var to_list = connections[from_str]
		if to_list is Array:
			for to_idx in to_list:
				if tile_positions.has(from_idx) and tile_positions.has(int(to_idx)):
					var from_pos = tile_positions[from_idx]
					var to_pos = tile_positions[int(to_idx)]
					var line = Line2D.new()
					line.add_point(from_pos)
					line.add_point(to_pos)
					line.width = 2.0
					line.default_color = Color(0.6, 0.6, 0.3, 0.4)
					preview_container.add_child(line)

func _create_tile_node(px: float, pz: float, tile_size: float, tile_type: String, tile_index: int, tile_data: Dictionary):
	var color = TILE_COLORS.get(tile_type, Color(0.5, 0.5, 0.5))

	# タイル背景
	var rect = ColorRect.new()
	rect.position = Vector2(px, pz)
	rect.size = Vector2(tile_size, tile_size)
	rect.color = color
	preview_container.add_child(rect)

	# 枠線（少し暗い色）
	var border = ReferenceRect.new()
	border.position = Vector2(px, pz)
	border.size = Vector2(tile_size, tile_size)
	border.border_color = Color(0.2, 0.2, 0.2, 0.8)
	border.border_width = 1.0
	border.editor_only = false
	preview_container.add_child(border)

	# ラベル（タイプ略称）
	var label_text = TILE_TYPE_NAMES.get(tile_type, "?")
	# チェックポイントは方向も表示
	if tile_type == "Checkpoint":
		var cp_type = tile_data.get("checkpoint_type", "")
		if cp_type != "":
			label_text = cp_type

	var lbl = Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(px, pz)
	lbl.size = Vector2(tile_size, tile_size)
	var font_size = int(tile_size * 0.45)
	font_size = clampi(font_size, 8, 20)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	preview_container.add_child(lbl)

# ============================================
# 閉じる
# ============================================

func _on_close():
	queue_free()
