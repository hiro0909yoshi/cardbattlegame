extends Node
class_name TileDataManager

# タイルデータ管理クラス
# タイル情報の取得・更新・計算処理を担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# タイルノード管理
var tile_nodes = {}  # tile_index -> BaseTile

# サブシステム参照
var tile_info_display: TileInfoDisplay = null

func _ready():
	pass

# タイルノードを設定
func set_tile_nodes(nodes: Dictionary):
	tile_nodes = nodes

# タイル情報表示システムを設定
func set_display_system(display: TileInfoDisplay):
	tile_info_display = display

# === タイル情報取得 ===

# タイル情報を取得
func get_tile_info(tile_index: int) -> Dictionary:
	if not tile_nodes.has(tile_index):
		return {}
	
	var tile = tile_nodes[tile_index]
	return {
		"index": tile_index,
		"type": get_tile_type(tile.tile_type),
		"element": tile.tile_type if tile.tile_type in ["火", "水", "風", "土"] else "",
		"owner": tile.owner_id,
		"level": tile.level,
		"creature": tile.creature_data,
		"is_special": is_special_tile_type(tile.tile_type)
	}

# タイルタイプを数値に変換
func get_tile_type(tile_type_str: String) -> int:
	match tile_type_str:
		"start": return 1
		"checkpoint": return 2
		"warp", "card", "neutral": return 3
		_: return 0

# 特殊タイルかチェック
func is_special_tile_type(tile_type: String) -> bool:
	return tile_type in ["warp", "card", "checkpoint", "neutral", "start"]

# タイルが存在するかチェック
func has_tile(tile_index: int) -> bool:
	return tile_nodes.has(tile_index)

# === タイル更新 ===

# タイル所有者を設定
func set_tile_owner(tile_index: int, owner_id: int):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].set_tile_owner(owner_id)
		_update_display(tile_index)

# クリーチャーを配置
func place_creature(tile_index: int, creature_data: Dictionary):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].place_creature(creature_data)
		_update_display(tile_index)

# クリーチャーを除去
func remove_creature(tile_index: int):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].remove_creature()
		_update_display(tile_index)

# タイルレベルをアップグレード
func upgrade_tile_level(tile_index: int) -> bool:
	if tile_nodes.has(tile_index):
		var success = tile_nodes[tile_index].level_up()
		if success:
			_update_display(tile_index)
		return success
	return false

# タイルレベルを直接設定
func set_tile_level(tile_index: int, level: int):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].set_level(level)
		_update_display(tile_index)

# === コスト計算 ===

# レベルアップコストを計算
func get_upgrade_cost(tile_index: int) -> int:
	if not tile_nodes.has(tile_index):
		return 0
		
	var current_level = tile_nodes[tile_index].level
	var next_level = current_level + 1
	
	if next_level <= GameConstants.MAX_LEVEL:
		var current_value = GameConstants.LEVEL_VALUES.get(current_level, 0)
		var next_value = GameConstants.LEVEL_VALUES.get(next_level, 0)
		return next_value - current_value
	
	return 0

# 通行料を計算
func calculate_toll(tile_index: int) -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	var tile = tile_nodes[tile_index]
	if tile.owner_id == -1:
		return 0
	
	var base_toll = GameConstants.BASE_TOLL
	var level_multiplier = tile.level
	var chain_bonus = calculate_chain_bonus(tile_index, tile.owner_id)
	
	return int(base_toll * level_multiplier * chain_bonus)

# === 連鎖計算 ===

# 連鎖ボーナスを計算
func calculate_chain_bonus(tile_index: int, owner_id: int) -> float:
	if not tile_nodes.has(tile_index):
		return 1.0
	
	var target_element = tile_nodes[tile_index].tile_type
	
	# 属性タイルでない場合は連鎖なし
	if target_element == "" or not target_element in ["火", "水", "風", "土"]:
		return 1.0
	
	var same_element_count = get_element_chain_count(tile_index, owner_id)
	
	# 連鎖数に応じたボーナス
	if same_element_count >= 4:
		return GameConstants.CHAIN_BONUS_4
	elif same_element_count == 3:
		return GameConstants.CHAIN_BONUS_3
	elif same_element_count == 2:
		return GameConstants.CHAIN_BONUS_2
	
	return 1.0

# 属性連鎖数を取得
func get_element_chain_count(tile_index: int, owner_id: int) -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	var target_element = tile_nodes[tile_index].tile_type
	var chain_count = 0
	
	# 同じ所有者・同じ属性のタイルを数える
	for i in tile_nodes:
		var tile = tile_nodes[i]
		if tile.owner_id == owner_id and tile.tile_type == target_element:
			chain_count += 1
	
	return min(chain_count, 4)  # 最大4個まで

# === 統計情報 ===

# 所有者の土地数を取得
func get_owner_land_count(owner_id: int) -> int:
	var count = 0
	for i in tile_nodes:
		if tile_nodes[i].owner_id == owner_id:
			count += 1
	return count

# 所有者の属性別土地数を取得
func get_owner_element_counts(owner_id: int) -> Dictionary:
	var counts = {
		"火": 0,
		"水": 0,
		"風": 0,
		"土": 0,
		"その他": 0
	}
	
	for i in tile_nodes:
		var tile = tile_nodes[i]
		if tile.owner_id == owner_id:
			if tile.tile_type in ["火", "水", "風", "土"]:
				counts[tile.tile_type] += 1
			else:
				counts["その他"] += 1
	
	return counts

# 所有者の総資産を計算
func calculate_total_land_value(owner_id: int) -> int:
	var total_value = 0
	
	for i in tile_nodes:
		var tile = tile_nodes[i]
		if tile.owner_id == owner_id:
			var level_value = GameConstants.LEVEL_VALUES.get(tile.level, 0)
			total_value += level_value
	
	return total_value

# === 表示更新 ===

# 全タイルの表示を更新
func update_all_displays():
	if not tile_info_display:
		return
	
	for index in tile_nodes:
		var tile_info = get_tile_info(index)
		tile_info_display.update_display(index, tile_info)

# 個別タイルの表示を更新
func _update_display(tile_index: int):
	if tile_info_display:
		tile_info_display.update_display(tile_index, get_tile_info(tile_index))

# === 2D互換用（将来削除予定） ===

# タイルデータ配列を取得（PlayerInfoPanel用）
func get_tile_data_array() -> Array:
	var data = []
	
	# 20タイル固定（2D版互換のため）
	for i in range(20):
		if tile_nodes.has(i):
			var tile = tile_nodes[i]
			data.append({
				"element": tile.tile_type,
				"type": get_tile_type(tile.tile_type),
				"owner": tile.owner_id,
				"level": tile.level
			})
		else:
			# デフォルト値
			data.append({
				"element": "",
				"type": 0,
				"owner": -1,
				"level": 1
			})
	
	return data

# === デバッグ ===

# タイル情報を出力
func debug_print_tile(tile_index: int):
	if tile_nodes.has(tile_index):
		var tile = tile_nodes[tile_index]
		print("タイル", tile_index, ":")
		print("  タイプ: ", tile.tile_type)
		print("  所有者: ", tile.owner_id)
		print("  レベル: ", tile.level)
		print("  クリーチャー: ", tile.creature_data.get("name", "なし"))
	else:
		print("タイル", tile_index, "は存在しません")

# 全タイル情報を出力
func debug_print_all_tiles():
	print("=== 全タイル情報 ===")
	for i in tile_nodes:
		debug_print_tile(i)
	print("===================")
