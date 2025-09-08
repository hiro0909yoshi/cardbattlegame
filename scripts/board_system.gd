extends Node
class_name BoardSystem

# ボードマップとタイル管理システム

# ボード設定
var board_tiles = []  # マスの配列（ColorRect）
var tile_data = []    # マスのデータ配列
var total_tiles = 20  # マスの総数

# タイルの種類
enum TileType {
	NORMAL,      # 通常土地
	START,       # スタート地点
	CHECKPOINT,  # チェックポイント
	SPECIAL      # 特殊マス
}

# タイル情報
var tile_owners = []  # 各マスの所有者（-1=未所有、0=プレイヤー1、1=プレイヤー2）
var tile_levels = []  # 各マスのレベル
var tile_creatures = []  # 各マスのクリーチャー情報

func _ready():
	print("BoardSystem: 初期化")
	initialize_tile_data()

# タイルデータの初期化
func initialize_tile_data():
	for i in range(total_tiles):
		tile_owners.append(-1)  # 全て未所有
		tile_levels.append(1)   # レベル1
		tile_creatures.append({})  # クリーチャーなし
		
		# タイルタイプを設定
		var type = TileType.NORMAL
		if i == 0:
			type = TileType.START
		elif i % 5 == 0:
			type = TileType.CHECKPOINT
		
		tile_data.append({
			"type": type,
			"element": get_random_element() if type == TileType.NORMAL else "",
			"index": i
		})

# ボードマップを生成（UIノードに追加）
func create_board(parent_node: Node):
	var center = Vector2(400, 400)  # ボードの中心
	var radius = 150  # 円の半径
	
	for i in range(total_tiles):
		# 円形にマスを配置
		var angle = (2 * PI * i) / total_tiles - PI/2
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		
		# マスを表す四角形を作成
		var tile = ColorRect.new()
		tile.size = Vector2(30, 30)
		tile.position = pos - tile.size / 2  # 中心に配置
		
		# マスの色を設定
		if tile_data[i].type == TileType.START:
			tile.color = Color(1.0, 0.9, 0.3)  # スタート地点は金色
		elif tile_data[i].type == TileType.CHECKPOINT:
			tile.color = Color(0.3, 0.8, 0.3)  # チェックポイントは緑
		else:
			# 通常マスは属性色
			tile.color = get_element_color(tile_data[i].element)
		
		parent_node.add_child(tile)
		board_tiles.append(tile)
	
	print("BoardSystem: ボードマップ生成完了 (", total_tiles, "マス)")

# ランダムな属性を取得
func get_random_element() -> String:
	var elements = ["火", "水", "風", "土"]
	return elements[randi() % elements.size()]

# 属性に応じた色を取得
func get_element_color(element: String) -> Color:
	match element:
		"火": return Color(1.0, 0.4, 0.4)
		"水": return Color(0.4, 0.6, 1.0)
		"風": return Color(0.4, 1.0, 0.6)
		"土": return Color(0.8, 0.6, 0.3)
		_: return Color(0.7, 0.7, 0.7)

# タイルの位置を取得
func get_tile_position(tile_index: int) -> Vector2:
	if tile_index >= 0 and tile_index < board_tiles.size():
		var tile = board_tiles[tile_index]
		return tile.position + tile.size / 2
	return Vector2.ZERO

# タイルの所有者を設定
func set_tile_owner(tile_index: int, owner_id: int):
	if tile_index >= 0 and tile_index < total_tiles:
		tile_owners[tile_index] = owner_id
		update_tile_visual(tile_index)

# タイルにクリーチャーを配置
func place_creature(tile_index: int, creature_data: Dictionary):
	if tile_index >= 0 and tile_index < total_tiles:
		tile_creatures[tile_index] = creature_data
		# TODO: クリーチャーの見た目を追加

# タイルの見た目を更新
func update_tile_visual(tile_index: int):
	var tile = board_tiles[tile_index]
	var tile_owner = tile_owners[tile_index]  # owner → tile_owner に変更
	
	# 既存の枠を削除
	for child in tile.get_children():
		child.queue_free()
	
	if tile_owner >= 0:
		# 所有者の枠を追加
		var border = ColorRect.new()
		border.size = tile.size + Vector2(4, 4)
		border.position = Vector2(-2, -2)
		border.color = get_player_color(tile_owner)
		border.z_index = -1
		tile.add_child(border)

# プレイヤーの色を取得
func get_player_color(player_id: int) -> Color:
	var colors = [
		Color(1, 1, 0, 0.8),    # プレイヤー1: 黄色
		Color(0, 0.5, 1, 0.8),  # プレイヤー2: 青
		Color(1, 0, 0, 0.8),    # プレイヤー3: 赤
		Color(0, 1, 0, 0.8)     # プレイヤー4: 緑
	]
	return colors[player_id % colors.size()]

# タイル情報を取得
func get_tile_info(tile_index: int) -> Dictionary:
	if tile_index >= 0 and tile_index < total_tiles:
		return {
			"index": tile_index,
			"type": tile_data[tile_index].type,
			"element": tile_data[tile_index].element,
			"owner": tile_owners[tile_index],
			"level": tile_levels[tile_index],
			"creature": tile_creatures[tile_index]
		}
	return {}

# 通行料を計算
func calculate_toll(tile_index: int) -> int:
	if tile_index < 0 or tile_index >= total_tiles:
		return 0
	
	if tile_owners[tile_index] == -1:
		return 0
	
	var base_toll = 50 * tile_levels[tile_index]
	# TODO: クリーチャーのSTによる計算
	return base_toll
