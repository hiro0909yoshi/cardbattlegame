extends Node
class_name BoardSystem

# ボードマップとタイル管理システム - 特殊マス対応版

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

# レベルアップ設定
const MAX_LEVEL = 5
const LEVEL_COLORS = [
	Color(0.7, 0.7, 0.7),  # レベル1: 灰色
	Color(0.4, 0.8, 0.4),  # レベル2: 緑
	Color(0.4, 0.6, 1.0),  # レベル3: 青
	Color(0.8, 0.4, 0.8),  # レベル4: 紫
	Color(1.0, 0.8, 0.0)   # レベル5: 金
]

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
		elif i % 5 == 0 and i != 0:  # 0番マスは除外
			type = TileType.CHECKPOINT
		
		tile_data.append({
			"type": type,
			"element": get_random_element() if type == TileType.NORMAL else "",
			"index": i,
			"is_special": false,  # 特殊マスフラグ
			"special_type": 0     # 特殊マスタイプ
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
		
		# マスの色を設定（特殊マスは後で上書きされる）
		if tile_data[i].type == TileType.START:
			tile.color = Color(1.0, 0.9, 0.3)  # スタート地点は金色
		elif tile_data[i].type == TileType.CHECKPOINT:
			tile.color = Color(0.3, 0.8, 0.3)  # チェックポイントは緑
		else:
			# 通常マスは属性色
			tile.color = get_element_color(tile_data[i].element)
		
		# レベル表示用ラベルを追加
		var level_label = Label.new()
		level_label.name = "LevelLabel"
		level_label.text = ""
		level_label.position = Vector2(5, 5)
		level_label.add_theme_font_size_override("font_size", 10)
		level_label.add_theme_color_override("font_color", Color.WHITE)
		level_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		level_label.z_index = 1
		tile.add_child(level_label)
		
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
		print("クリーチャー配置: ", creature_data.get("name", "不明"), " (マス", tile_index, ")")

# タイルのレベルアップ
func upgrade_tile_level(tile_index: int) -> bool:
	if tile_index < 0 or tile_index >= total_tiles:
		return false
	
	if tile_levels[tile_index] >= MAX_LEVEL:
		print("この土地は最大レベルです")
		return false
	
	tile_levels[tile_index] += 1
	update_tile_visual(tile_index)
	
	print("土地レベルアップ！ マス", tile_index, " → レベル", tile_levels[tile_index])
	return true

# レベルアップコストを取得（原作仕様）
func get_upgrade_cost(tile_index: int) -> int:
	if tile_index < 0 or tile_index >= total_tiles:
		return 0
	
	var current_level = tile_levels[tile_index]
	if current_level >= MAX_LEVEL:
		return 0
	
	# 原作仕様：現在レベル×100
	return current_level * 100

# タイルの見た目を更新
func update_tile_visual(tile_index: int):
	if tile_index < 0 or tile_index >= board_tiles.size():
		return
		
	var tile = board_tiles[tile_index]
	var owner = tile_owners[tile_index]
	var level = tile_levels[tile_index]
	
	# 既存の枠を削除
	for child in tile.get_children():
		if child.name == "OwnerBorder":
			child.queue_free()
	
	# 所有者の枠を追加
	if owner >= 0:
		var border = ColorRect.new()
		border.name = "OwnerBorder"
		border.size = tile.size + Vector2(4, 4)
		border.position = Vector2(-2, -2)
		border.color = get_player_color(owner)
		border.z_index = -1
		tile.add_child(border)
		
		# レベルに応じて枠を太くする
		if level > 1:
			var level_border = ColorRect.new()
			level_border.name = "LevelBorder"
			var border_size = 2 + (level - 1) * 2
			level_border.size = tile.size + Vector2(border_size * 2, border_size * 2)
			level_border.position = Vector2(-border_size, -border_size)
			level_border.color = LEVEL_COLORS[min(level - 1, LEVEL_COLORS.size() - 1)]
			level_border.color.a = 0.5
			level_border.z_index = -2
			tile.add_child(level_border)
	
	# レベル表示を更新
	var level_label = tile.get_node_or_null("LevelLabel")
	if level_label:
		if owner >= 0 and level > 1:
			level_label.text = "Lv" + str(level)
		else:
			level_label.text = ""

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
			"creature": tile_creatures[tile_index],
			"is_special": tile_data[tile_index].get("is_special", false),
			"special_type": tile_data[tile_index].get("special_type", 0)
		}
	return {}

# 特殊マスとして設定（SpecialTileSystemから呼ばれる）
func mark_as_special_tile(tile_index: int, special_type: int):
	if tile_index >= 0 and tile_index < total_tiles:
		tile_data[tile_index]["is_special"] = true
		tile_data[tile_index]["special_type"] = special_type
		
		# チェックポイントは保持する（通過型ワープと共存）
		if tile_data[tile_index]["type"] != TileType.CHECKPOINT and tile_data[tile_index]["type"] != TileType.START:
			# 無属性マス以外は特殊マスタイプに変更
			if special_type != 3:  # NEUTRAL以外
				tile_data[tile_index]["type"] = TileType.SPECIAL
				tile_data[tile_index]["element"] = ""  # 特殊マスは属性なし
			else:
				# 無属性マスは通常土地として扱うが属性なし
				tile_data[tile_index]["type"] = TileType.NORMAL
				tile_data[tile_index]["element"] = ""
		
		# 特殊マスの色を更新
		if tile_index < board_tiles.size():
			var tile = board_tiles[tile_index]
			# SpecialTileSystemから色を取得
			var special_system = get_tree().get_root().get_node_or_null("Game/SpecialTileSystem")
			if special_system:
				tile.color = special_system.get_special_tile_color(special_type)
			
			# 特殊マスマークを追加
			var mark_label = Label.new()
			mark_label.name = "SpecialMark"
			mark_label.position = Vector2(10, 10)
			mark_label.add_theme_font_size_override("font_size", 14)
			mark_label.add_theme_color_override("font_color", Color.WHITE)
			mark_label.z_index = 2
			
			# 特殊マスタイプによってマークを設定
			match special_type:
				1:  # WARP_GATE
					mark_label.text = "→"
				2:  # WARP_POINT
					mark_label.text = "◆"
				3:  # NEUTRAL
					mark_label.text = "N"
				4:  # CARD
					mark_label.text = "C"
				_:
					mark_label.text = "?"
			
			tile.add_child(mark_label)

# 通行料を計算（修正版：クリーチャーSTを使わない）
func calculate_toll(tile_index: int) -> int:
	if tile_index < 0 or tile_index >= total_tiles:
		return 0
	
	if tile_owners[tile_index] == -1:
		return 0
	
	var owner = tile_owners[tile_index]
	var level = tile_levels[tile_index]
	
	# 基礎通行料は100G固定
	var base_toll = 100
	
	# 土地レベル倍率
	var level_multiplier = level
	
	# 土地連鎖ボーナスを計算
	var chain_bonus = calculate_chain_bonus(tile_index, owner)
	
	# 最終通行料 = 基礎通行料 × 土地レベル × 連鎖ボーナス
	var total_toll = int(base_toll * level_multiplier * chain_bonus)
	
	print("通行料計算: 基礎", base_toll, " × Lv", level, " × 連鎖", chain_bonus, "倍 = ", total_toll, "G")
	
	return total_toll

# 土地連鎖ボーナスを計算（属性ベース）
func calculate_chain_bonus(tile_index: int, owner: int) -> float:
	# 対象タイルの属性を取得
	var target_element = tile_data[tile_index].get("element", "")
	if target_element == "":
		return 1.0  # 特殊マスや無属性マスは連鎖ボーナスなし
	
	# SpecialTileSystemの参照を取得
	var special_system = get_tree().get_root().get_node_or_null("Game/SpecialTileSystem")
	
	# 同じ所有者かつ同じ属性の土地を全マップから数える
	var same_element_count = 0
	for i in range(total_tiles):
		if tile_owners[i] == owner:
			# 無属性マスチェック
			if special_system and special_system.is_neutral_tile(i):
				continue  # 無属性マスは連鎖に含めない
				
			var tile_element = tile_data[i].get("element", "")
			if tile_element == target_element:
				same_element_count += 1
	
	# 連鎖ボーナス計算（修正版）
	# 1個:1.0倍、2個:1.5倍、3個:2.5倍、4個以上:4.0倍（上限）
	var bonus = 1.0
	if same_element_count >= 4:
		bonus = 4.0  # 4個以上は4倍固定（5個でも6個でも4倍）
	elif same_element_count == 3:
		bonus = 2.5
	elif same_element_count == 2:
		bonus = 1.5
	
	if same_element_count > 1:
		print("属性連鎖ボーナス: ", target_element, "属性×", same_element_count, "個 → ", bonus, "倍")
	
	return bonus

# 属性連鎖数を取得（バトルシステム用）
func get_element_chain_count(tile_index: int, owner: int) -> int:
	# 対象タイルの属性を取得
	var target_element = tile_data[tile_index].get("element", "")
	if target_element == "":
		return 0  # 特殊マスや無属性マスは連鎖なし
	
	# SpecialTileSystemの参照を取得
	var special_system = get_tree().get_root().get_node_or_null("Game/SpecialTileSystem")
	
	# 同じ所有者かつ同じ属性の土地を全マップから数える
	var same_element_count = 0
	for i in range(total_tiles):
		if tile_owners[i] == owner:
			# 無属性マスチェック
			if special_system and special_system.is_neutral_tile(i):
				continue  # 無属性マスは連鎖に含めない
			
			var tile_element = tile_data[i].get("element", "")
			if tile_element == target_element:
				same_element_count += 1
	
	# 最大4個として返す（5個以上でも4として扱う）
	return min(same_element_count, 4)

# 同じ所有者の土地数を取得（全体）
func get_owner_land_count(owner: int) -> int:
	var count = 0
	for i in range(total_tiles):
		if tile_owners[i] == owner:
			count += 1
	return count

# レベルアップ可能かチェック
func can_upgrade(tile_index: int, player_id: int) -> bool:
	if tile_index < 0 or tile_index >= total_tiles:
		return false
	
	# 所有者チェック
	if tile_owners[tile_index] != player_id:
		return false
	
	# レベル上限チェック
	if tile_levels[tile_index] >= MAX_LEVEL:
		return false
	
	# タイプチェック（通常土地のみレベルアップ可能）
	if tile_data[tile_index].type != TileType.NORMAL:
		return false
	
	return true

# デバッグ用：全タイル情報を表示
func debug_print_all_tiles():
	print("\n=== タイル情報 ===")
	for i in range(total_tiles):
		var info = get_tile_info(i)
		if info.owner >= 0:
			print("マス", i, ": ", 
				"所有者P", info.owner + 1, 
				" Lv", info.level,
				" ", info.element if info.element != "" else "特殊",
				" クリーチャー:", "あり" if not info.creature.is_empty() else "なし")
