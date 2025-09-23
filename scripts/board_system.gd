extends Node
class_name BoardSystem

# ボードマップとタイル管理システム - 台座追加版

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# ボード設定
var board_tiles = []  # マスの配列（TextureRect）
var board_bases = []  # 台座の配列（TextureRect）
var tile_data = []    # マスのデータ配列
var total_tiles = GameConstants.TOTAL_TILES  # マスの総数

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
			"element": "水",  # 全て水属性に固定
			"index": i,
			"is_special": false,  # 特殊マスフラグ
			"special_type": 0     # 特殊マスタイプ
		})

# ボードマップを生成（菱形配置）
func create_board(parent_node: Node):
	var center = Vector2(400, 300)  # マップ中心
	var tile_spacing = 80  # タイル間隔
	
	print("\n=== タイル作成開始 ===")
	print("タイル間隔: ", tile_spacing)
	print("中心位置: ", center)
	
	# 菱形配置の定義（20マス）
	var diamond_layout = [
		#1段目
		[Vector2(0, -0.65)],
		#2段目
		[Vector2(-0.4, -0.49), Vector2(0.4, -0.49)],
		# 3段目
		[Vector2(-0.8, -0.32), Vector2(0.8, -0.32)],
		# 4段目
		[Vector2(-1.2, -0.16),Vector2(1.2, -0.16)],
		# 5段目
		[Vector2(-1.6, 0), Vector2(1.6, 0)],
		# 6段目
		[Vector2(-1.2, 0.16),  Vector2(1.2, 0.16)],
		# 7段目
		[Vector2(-0.8, 0.32), Vector2(0.8, 0.32)],
		#8段目
		[Vector2(-0.4, 0.49), Vector2(0.4, 0.49)],
		#9段目
		[Vector2(0, 0.65)]
	]
	
	# 全ての位置を一つの配列にまとめる
	var all_positions = []
	for row in diamond_layout:
		for offset in row:
			all_positions.append(center + offset * tile_spacing)
	
	# タイルと台座を作成
	for i in range(min(total_tiles, all_positions.size())):
		var pos = all_positions[i]
		
		# ============ 台座を作成 ============
		var base = TextureRect.new()
		base.name = "Base_" + str(i)
		
		# 台座サイズ（タイルと同じサイズ）
		var base_size = Vector2(64, 32)  # タイルと同じサイズ
		base.custom_minimum_size = base_size
		base.size = base_size
		
		# 位置設定（タイルより10px下に配置）
		base.position = pos - base_size / 2 + Vector2(0, 10)  # 10px下にオフセット
		
		# Y軸下方向が手前になるようにz_index設定（台座用）
		# タイルより小さい値にして、タイルの下に表示
		base.z_index = int(pos.y / 10) - 1
		
		# 台座のテクスチャ設定（base1.pngを使用）
		base.texture = load("res://assets/images/tiles/base1.png")
		base.stretch_mode = TextureRect.STRETCH_SCALE  # タイルと同じstretch_mode
		base.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		
		parent_node.add_child(base)
		board_bases.append(base)
		
		# ============ タイルを作成 ============
		var tile = TextureRect.new()
		tile.name = "Tile_" + str(i)
		
		# アイソメトリック比率（2:1）でサイズ設定
		var tile_size = Vector2(64, 32)
		tile.custom_minimum_size = tile_size
		tile.size = tile_size
		
		print("\nタイル ", i, " 作成:")
		print("  設定サイズ: ", tile_size)
		print("  位置: ", pos)
		
		# 位置設定（タイルの中心を基準に）
		tile.position = pos - tile_size / 2
		
		# Y軸下方向が手前になるようにz_index設定（タイル用）
		# 台座より大きい値にして、台座の上に表示
		tile.z_index = int(pos.y / 10)
		
		# テクスチャ設定
		tile.texture = load("res://assets/images/tiles/fire_tile3.png")
		
		# stretch_mode設定
		tile.stretch_mode = TextureRect.STRETCH_SCALE  # 強制的に指定サイズに拡大縮小
		tile.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		
		print("  stretch_mode: ", tile.stretch_mode)
		print("  expand_mode: ", tile.expand_mode)
		print("  z_index (台座): ", int(pos.y / 10) - 1)
		print("  z_index (タイル): ", int(pos.y / 10))
		
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
		
		# 実際のサイズを次のフレームで確認
		if i == 0:  # 最初のタイルだけ詳細確認
			await get_tree().process_frame
			print("  [確認] 実際のサイズ: ", tile.size)
			print("  [確認] スケール: ", tile.scale)
			print("  [確認] 親ノードスケール: ", parent_node.scale)
	
	print("\n=== タイル作成完了 ===\n")

# ランダムな属性を取得
func get_random_element() -> String:
	# 現在は全て水属性なので使用しない
	return "水"

# 属性に応じた色を取得
func get_element_color(element: String) -> Color:
	if GameConstants.ELEMENT_COLORS.has(element):
		return GameConstants.ELEMENT_COLORS[element]
	return Color(0.7, 0.7, 0.7)

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

# タイルのレベルアップ
func upgrade_tile_level(tile_index: int) -> bool:
	if tile_index < 0 or tile_index >= total_tiles:
		return false
	
	if tile_levels[tile_index] >= GameConstants.MAX_LEVEL:
		return false
	
	tile_levels[tile_index] += 1
	update_tile_visual(tile_index)
	
	# 台座のビジュアルも更新（オプション）
	update_base_visual(tile_index)
	
	return true

# 台座のビジュアルを更新（レベルに応じて）
func update_base_visual(tile_index: int):
	if tile_index < 0 or tile_index >= board_bases.size():
		return
	
	var base = board_bases[tile_index]
	var level = tile_levels[tile_index]
	var owner = tile_owners[tile_index]
	
	# 所有者がいる場合、台座に薄くプレイヤーカラーを適用
	if owner >= 0 and base is TextureRect:
		# レベルに応じて色の強さを調整
		var intensity = 0.3 + (level - 1) * 0.1
		intensity = min(intensity, 0.8)  # 最大0.8
		
		# プレイヤーカラーを取得して調整
		var player_color = get_player_color(owner)
		base.modulate = Color(
			1.0 - (1.0 - player_color.r) * intensity,
			1.0 - (1.0 - player_color.g) * intensity,
			1.0 - (1.0 - player_color.b) * intensity,
			1.0
		)
	else:
		# 所有者なしの場合はデフォルト（白 = テクスチャの元の色）
		if base is TextureRect:
			base.modulate = Color(1.0, 1.0, 1.0, 1.0)

# レベルアップコストを取得（原作仕様）
func get_upgrade_cost(tile_index: int) -> int:
	if tile_index < 0 or tile_index >= total_tiles:
		return 0
	
	var current_level = tile_levels[tile_index]
	if current_level >= GameConstants.MAX_LEVEL:
		return 0
	
	# 原作仕様：現在レベル×100
	return current_level * GameConstants.LEVEL_UP_COST_RATE

# タイルの見た目を更新
func update_tile_visual(tile_index: int):
	if tile_index < 0 or tile_index >= board_tiles.size():
		return
		
	var tile = board_tiles[tile_index]
	var tile_owner = tile_owners[tile_index]
	var level = tile_levels[tile_index]
	
	# 既存の枠を削除
	for child in tile.get_children():
		if child.name == "OwnerBorder":
			child.queue_free()
	
	# 所有者の枠を追加
	if tile_owner >= 0:
		var border = ColorRect.new()
		border.name = "OwnerBorder"
		border.size = tile.size + Vector2(4, 4)
		border.position = Vector2(-2, -2)
		border.color = get_player_color(tile_owner)
		border.z_index = -1
		tile.add_child(border)
		
		# レベルに応じて枠を太くする
		if level > 1:
			var level_border = ColorRect.new()
			level_border.name = "LevelBorder"
			var border_size = 2 + (level - 1) * 2
			level_border.size = tile.size + Vector2(border_size * 2, border_size * 2)
			level_border.position = Vector2(-border_size, -border_size)
			level_border.color = GameConstants.LEVEL_COLORS[min(level - 1, GameConstants.LEVEL_COLORS.size() - 1)]
			level_border.color.a = 0.5
			level_border.z_index = -2
			tile.add_child(level_border)
	
	# レベル表示を更新
	var level_label = tile.get_node_or_null("LevelLabel")
	if level_label:
		if tile_owner >= 0 and level > 1:
			level_label.text = "Lv" + str(level)
		else:
			level_label.text = ""
	
	# 台座も更新
	update_base_visual(tile_index)

# プレイヤーの色を取得
func get_player_color(player_id: int) -> Color:
	# GameConstantsから色を取得（ただし順番が異なるため調整）
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
				tile.modulate = special_system.get_special_tile_color(special_type)
			
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
	
	var level = tile_levels[tile_index]
	
	# 基礎通行料は定数から取得
	var base_toll = GameConstants.BASE_TOLL
	
	# 土地レベル倍率
	var level_multiplier = level
	
	# 土地連鎖ボーナスを計算
	var chain_bonus = calculate_chain_bonus(tile_index, tile_owners[tile_index])
	
	# 最終通行料 = 基礎通行料 × 土地レベル × 連鎖ボーナス
	var total_toll = int(base_toll * level_multiplier * chain_bonus)
	
	return total_toll

# 土地連鎖ボーナスを計算（属性ベース）
func calculate_chain_bonus(tile_index: int, owner_id: int) -> float:
	# 対象タイルの属性を取得
	var target_element = tile_data[tile_index].get("element", "")
	if target_element == "":
		return 1.0  # 特殊マスや無属性マスは連鎖ボーナスなし
	
	# SpecialTileSystemの参照を取得
	var special_system = get_tree().get_root().get_node_or_null("Game/SpecialTileSystem")
	
	# 同じ所有者かつ同じ属性の土地を全マップから数える
	var same_element_count = 0
	for i in range(total_tiles):
		if tile_owners[i] == owner_id:
			# 無属性マスチェック
			if special_system and special_system.is_neutral_tile(i):
				continue  # 無属性マスは連鎖に含めない
				
			var tile_element = tile_data[i].get("element", "")
			if tile_element == target_element:
				same_element_count += 1
	
	# 連鎖ボーナス計算（GameConstantsから取得）
	var bonus = 1.0
	if same_element_count >= 4:
		bonus = GameConstants.CHAIN_BONUS_4
	elif same_element_count == 3:
		bonus = GameConstants.CHAIN_BONUS_3
	elif same_element_count == 2:
		bonus = GameConstants.CHAIN_BONUS_2
	
	return bonus

# 属性連鎖数を取得（バトルシステム用）
func get_element_chain_count(tile_index: int, owner_id: int) -> int:
	# 対象タイルの属性を取得
	var target_element = tile_data[tile_index].get("element", "")
	if target_element == "":
		return 0  # 特殊マスや無属性マスは連鎖なし
	
	# SpecialTileSystemの参照を取得
	var special_system = get_tree().get_root().get_node_or_null("Game/SpecialTileSystem")
	
	# 同じ所有者かつ同じ属性の土地を全マップから数える
	var same_element_count = 0
	for i in range(total_tiles):
		if tile_owners[i] == owner_id:
			# 無属性マスチェック
			if special_system and special_system.is_neutral_tile(i):
				continue  # 無属性マスは連鎖に含めない
			
			var tile_element = tile_data[i].get("element", "")
			if tile_element == target_element:
				same_element_count += 1
	
	# 最大4個として返す（5個以上でも4として扱う）
	return min(same_element_count, 4)

# 同じ所有者の土地数を取得（全体）
func get_owner_land_count(owner_id: int) -> int:
	var count = 0
	for i in range(total_tiles):
		if tile_owners[i] == owner_id:
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
	if tile_levels[tile_index] >= GameConstants.MAX_LEVEL:
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
