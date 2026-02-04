extends Node
class_name TileDataManager

# タイルデータ管理クラス
# タイル情報の取得・更新・計算処理を担当

# 定数をpreload

# タイルノード管理
var tile_nodes = {}  # tile_index -> BaseTile

# サブシステム参照
var tile_info_display: TileInfoDisplay = null
var game_flow_manager = null  # 世界呪い判定用

func _ready():
	pass

# タイルノードを設定
func set_tile_nodes(nodes: Dictionary):
	tile_nodes = nodes

# タイル情報表示システムを設定
func set_display_system(display: TileInfoDisplay):
	tile_info_display = display

# GameFlowManager参照を設定（世界呪い判定用）
func set_game_flow_manager(gfm):
	game_flow_manager = gfm

# === タイル情報取得 ===

# タイル情報を取得
func get_tile_info(tile_index: int) -> Dictionary:
	if not tile_nodes.has(tile_index):
		return {}
	
	var tile = tile_nodes[tile_index]
	return {
		"index": tile_index,
		"element": tile.tile_type if TileHelper.has_land_effect_type(tile.tile_type) else "",
		"owner": tile.owner_id,
		"level": tile.level,
		"creature": tile.creature_data,
		"has_creature": not tile.creature_data.is_empty(),
		"is_special": is_special_tile_type(tile.tile_type),
		"connections": tile.connections if "connections" in tile else []
	}

# 特殊タイルかチェック（TileHelperに委譲）
func is_special_tile_type(tile_type: String) -> bool:
	return TileHelper.is_special_type(tile_type)

# タイルが存在するかチェック
func has_tile(tile_index: int) -> bool:
	return tile_nodes.has(tile_index)

# === タイル更新 ===

# タイル所有者を設定
func set_tile_owner(tile_index: int, owner_id: int):
	if not tile_nodes.has(tile_index):
		return
	
	var tile = tile_nodes[tile_index]
	var old_owner = tile.owner_id
	var element = tile.tile_type
	
	tile.set_tile_owner(owner_id)
	_update_display(tile_index)
	
	# 連鎖が変わるので関連タイルの表示を更新
	if old_owner != -1 and TileHelper.is_element_type(element):
		_update_chain_displays(old_owner, element)
	if owner_id != -1 and TileHelper.is_element_type(element):
		_update_chain_displays(owner_id, element)

# クリーチャーを配置
func place_creature(tile_index: int, creature_data: Dictionary):
	if not tile_nodes.has(tile_index):
		return
	
	var tile = tile_nodes[tile_index]
	var old_owner = tile.owner_id
	var element = tile.tile_type
	
	tile.place_creature(creature_data)
	_update_display(tile_index)
	
	# 所有権が変わった場合、連鎖タイルの表示を更新
	var new_owner = tile.owner_id
	if old_owner != new_owner and TileHelper.is_element_type(element):
		if old_owner != -1:
			_update_chain_displays(old_owner, element)
		if new_owner != -1:
			_update_chain_displays(new_owner, element)

# クリーチャーを除去
func remove_creature(tile_index: int):
	if not tile_nodes.has(tile_index):
		return
	
	var tile = tile_nodes[tile_index]
	var old_owner = tile.owner_id
	var element = tile.tile_type
	
	tile.remove_creature()
	_update_display(tile_index)
	
	# 所有権が変わった場合、連鎖タイルの表示を更新
	var new_owner = tile.owner_id
	if old_owner != new_owner and old_owner != -1 and TileHelper.is_element_type(element):
		_update_chain_displays(old_owner, element)

# 同じ所有者・同じ属性の全タイルの表示を更新（連鎖ボーナス変動時）
func _update_chain_displays(owner_id: int, element: String):
	for idx in tile_nodes:
		var tile = tile_nodes[idx]
		if tile.owner_id == owner_id and tile.tile_type == element:
			_update_display(idx)

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

# 土地価値を計算
# 土地価値 = 基本価値 × 属性係数 × レベル倍率(価値用) × 連鎖倍率(価値用)
func calculate_land_value(tile_index: int) -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	var tile = tile_nodes[tile_index]
	if tile.owner_id == -1:
		return 0
	
	var base = GameConstants.BASE_LAND_VALUE
	
	# 属性係数を取得
	var element_mult = GameConstants.LAND_VALUE_ELEMENT_MULTIPLIER.get(tile.tile_type, 1.0)
	
	# レベル倍率（価値用）を取得
	var level_mult = GameConstants.LAND_VALUE_LEVEL_MULTIPLIER.get(tile.level, 1)
	
	# 連鎖倍率（価値用）を計算
	var chain_count = get_element_chain_count(tile_index, tile.owner_id)
	var chain_mult = GameConstants.LAND_VALUE_CHAIN_MULTIPLIER.get(min(chain_count, 5), 1.0)
	
	# 計算実行
	var raw_value = base * element_mult * level_mult * chain_mult
	
	# 10の位で切り捨て
	return GameConstants.floor_toll(raw_value)

# 通行料を計算
# 通行料 = 土地価値 × レベル倍率(通行料用)
func calculate_toll(tile_index: int, _map_id: String = "") -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	var tile = tile_nodes[tile_index]
	if tile.owner_id == -1:
		return 0
	
	# 土地価値を取得
	var land_value = calculate_land_value(tile_index)
	
	# 通行料用レベル倍率を取得
	var toll_level_mult = GameConstants.TOLL_LEVEL_MULTIPLIER.get(tile.level, 0.2)
	
	# 計算実行
	var raw_toll = land_value * toll_level_mult
	
	# 10の位で切り捨て
	var final_toll = GameConstants.floor_toll(raw_toll)
	
	# ========================================
	# ドミニオ呪い判定（toll_multiplier, peace）
	# ========================================
	
	# クリーチャーの呪いをチェック
	# GameSystemManager経由で spell_curse_toll にアクセス
	if get_tree() and get_tree().root:
		var game_system_manager = get_tree().root.get_node_or_null("GameSystemManager")
		if game_system_manager and game_system_manager.board_system_3d and game_system_manager.board_system_3d.spell_curse_toll:
			final_toll = game_system_manager.board_system_3d.spell_curse_toll.get_land_toll_modifier(tile_index, final_toll)
	
	return final_toll

# レベルアップコストを計算（動的計算版）
# 現在レベルから目標レベルへの差額コストを返す
func calculate_level_up_cost(tile_index: int, target_level: int, _from_level: String = "") -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	if target_level < 2 or target_level > GameConstants.MAX_LEVEL:
		return 0
	
	var tile = tile_nodes[tile_index]
	var current_level = tile.level if tile.level else 1
	
	# 目標レベルへの累計コスト
	var target_cost = _calculate_cumulative_level_cost(tile, target_level)
	
	# 現在レベルへの累計コスト
	var current_cost = _calculate_cumulative_level_cost(tile, current_level)
	
	# 差額を返す
	return target_cost - current_cost


# レベルへの累計コストを計算（従来のLEVEL_VALUESを使用）
func _calculate_cumulative_level_cost(_tile, level: int) -> int:
	return GameConstants.LEVEL_VALUES.get(level, 0)

# === 連鎖計算 ===

# 連鎖倍率を計算（土地価値用）
func calculate_chain_bonus(tile_index: int, owner_id: int) -> float:
	if not tile_nodes.has(tile_index):
		return 1.0
	
	var target_element = tile_nodes[tile_index].tile_type
	
	# 属性タイルでない場合は連鎖なし
	if target_element == "" or not TileHelper.is_element_type(target_element):
		return 1.0
	
	var chain_count = get_element_chain_count(tile_index, owner_id)
	
	# 新しい連鎖倍率を返す
	return GameConstants.LAND_VALUE_CHAIN_MULTIPLIER.get(min(chain_count, 5), 1.0)

# 属性連鎖数を取得
func get_element_chain_count(tile_index: int, owner_id: int) -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	var target_element = tile_nodes[tile_index].tile_type
	var chain_count = 0
	
	# game_statsを取得（世界呪い判定用）
	var game_stats = {}
	if game_flow_manager:
		game_stats = game_flow_manager.game_stats
	
	# 同じ所有者・同じ連鎖グループのタイルを数える
	for i in tile_nodes:
		var tile = tile_nodes[i]
		if tile.owner_id == owner_id:
			# ジョイントワールド対応: 同属性または連鎖ペアならカウント
			if SpellWorldCurse.is_same_chain_group(tile.tile_type, target_element, game_stats):
				chain_count += 1
	
	return min(chain_count, 5)  # 最大5個まで

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
		"fire": 0,
		"water": 0,
		"wind": 0,
		"earth": 0,
		"other": 0
	}
	
	for i in tile_nodes:
		var tile = tile_nodes[i]
		if tile.owner_id == owner_id:
			if TileHelper.is_element_type(tile.tile_type):
				counts[tile.tile_type] += 1
			else:
				counts["other"] += 1
	
	return counts

# 所有者の総土地価値を計算（土地価値ベース、連鎖ボーナス含む）
func calculate_total_land_value(owner_id: int) -> int:
	var total_value = 0
	
	for i in tile_nodes:
		var tile = tile_nodes[i]
		if tile.owner_id == owner_id:
			# 土地の価値 = 土地価値（連鎖ボーナス含む）
			total_value += calculate_land_value(i)
	
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

# タイルデータ配列を取得（UIコンポーネント用）
func get_tile_data_array() -> Array:
	var data = []
	
	# 全タイルのデータを配列化
	for tile_index in tile_nodes:
		var tile = tile_nodes[tile_index]
		data.append({
			"element": tile.tile_type,
			"owner": tile.owner_id,
			"level": tile.level,
			"index": tile_index
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
