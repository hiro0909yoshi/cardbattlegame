class_name SpellLand
extends RefCounted

## SpellLand - 土地操作スペル効果
##
## 土地の属性変更、レベル操作、クリーチャー破壊などを担当

# システム参照
var board_system_ref: BoardSystem3D
var creature_manager_ref: CreatureManager
var player_system_ref: PlayerSystem

## 初期化
func setup(board_system: BoardSystem3D, creature_manager: CreatureManager, player_system: PlayerSystem) -> void:
	board_system_ref = board_system
	creature_manager_ref = creature_manager
	player_system_ref = player_system
	
	if not board_system_ref:
		push_error("SpellLand: BoardSystem3Dが設定されていません")
	if not creature_manager_ref:
		push_error("SpellLand: CreatureManagerが設定されていません")
	if not player_system_ref:
		push_error("SpellLand: PlayerSystemが設定されていません")

## 土地の属性を変更
func change_element(tile_index: int, new_element: String) -> bool:
	# デバッグ出力
	print("[SpellLand.change_element] 開始 - tile_index=%d, new_element=%s" % [tile_index, new_element])
	print("[SpellLand.change_element] board_system_ref = ", board_system_ref)
	
	if not board_system_ref:
		push_error("SpellLand.change_element: BoardSystem3Dが未設定")
		return false
	
	if not _validate_tile_index(tile_index):
		return false
	
	if not _validate_element(new_element):
		push_error("SpellLand: 無効な属性 '%s'" % new_element)
		return false
	
	# 現在の属性を取得
	var tile_info = board_system_ref.get_tile_info(tile_index)
	var old_element = tile_info.get("type", "unknown")
	
	# BoardSystem3Dのchange_tile_terrainメソッドを使用
	var success = board_system_ref.change_tile_terrain(tile_index, new_element)
	
	if success:
		print("[土地属性変更] タイル%d: %s → %s" % [tile_index, old_element, new_element])
	else:
		print("[土地属性変更失敗] タイル%d" % tile_index)
	
	return success

## 土地のレベルを変更（増減）
func change_level(tile_index: int, delta: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	# BoardSystem3DのtilesはNodeの配列なので、tile_nodesを使う
	if not board_system_ref.tile_nodes.has(tile_index):
		push_error("SpellLand: タイル%dが見つかりません" % tile_index)
		return false
	
	var tile = board_system_ref.tile_nodes[tile_index]
	var old_level = tile.level
	var new_level = clamp(old_level + delta, 1, 5)
	
	if new_level == old_level:
		return false
	
	tile.level = new_level
	
	# 表示を更新
	if board_system_ref.tile_data_manager:
		board_system_ref.tile_data_manager.update_all_displays()
	
	print("[土地レベル変更] タイル%d: Lv%d → Lv%d" % [tile_index, old_level, new_level])
	return true

## 土地のレベルを固定値に設定
func set_level(tile_index: int, level: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	level = clamp(level, 1, 5)
	var tile = board_system_ref.tile_nodes[tile_index]
	var old_level = tile.land_level
	
	if level == old_level:
		return false
	
	tile.land_level = level
	board_system_ref._update_tile_visual(tile_index)
	
	print("[土地レベル設定] タイル%d: Lv%d → Lv%d" % [tile_index, old_level, level])
	return true

## クリーチャーを破壊
func destroy_creature(tile_index: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	if not creature_manager_ref.has_creature(tile_index):
		print("[クリーチャー破壊] タイル%d: クリーチャーが存在しません" % tile_index)
		return false
	
	var creature_data = creature_manager_ref.get_data_ref(tile_index)
	var creature_name = creature_data.get("name", "不明")
	
	creature_manager_ref.set_data(tile_index, {})
	board_system_ref.remove_creature(tile_index)
	
	print("[クリーチャー破壊] タイル%d: %sを破壊" % [tile_index, creature_name])
	return true

## 土地を放棄（所有権を失う）
func abandon_land(tile_index: int, return_rate: float = 0.7) -> int:
	if not _validate_tile_index(tile_index):
		return 0
	
	var tile = board_system_ref.tile_nodes[tile_index]
	var player_id = tile.tile_owner
	
	if player_id < 0:
		push_error("SpellLand: タイル%dは誰も所有していません" % tile_index)
		return 0
	
	var base_value = 100
	var land_value = int(tile.land_level * base_value * return_rate)
	
	if creature_manager_ref.has_creature(tile_index):
		destroy_creature(tile_index)
	
	tile.tile_owner = -1
	board_system_ref._update_tile_visual(tile_index)
	
	var player = player_system_ref.players[player_id]
	var element = tile.element
	if player.lands_owned.has(element):
		player.lands_owned[element] = max(0, player.lands_owned[element] - 1)
	
	player_system_ref.add_magic(player_id, land_value)
	
	print("[土地放棄] タイル%d: P%d Lv%d %s G%d獲得" % [tile_index, player_id, tile.land_level, element, land_value])
	return land_value

## 条件付き属性変更
func change_element_with_condition(tile_index: int, condition: Dictionary, new_element: String) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	var tile = board_system_ref.tile_nodes[tile_index]
	
	if condition.has("max_level"):
		if tile.land_level > condition["max_level"]:
			return false
	
	if condition.has("required_elements"):
		if tile.element not in condition["required_elements"]:
			return false
	
	return change_element(tile_index, new_element)

## プレイヤーの最多属性を取得
func get_player_dominant_element(player_id: int) -> String:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return "earth"
	
	var player = player_system_ref.players[player_id]
	var lands_owned = player.lands_owned
	var max_count = 0
	var dominant_element = "earth"
	
	for element in lands_owned.keys():
		var count = lands_owned[element]
		if count > max_count:
			max_count = count
			dominant_element = element
	
	return dominant_element

## 条件付きレベル変更（複数タイル）
func change_level_multiple_with_condition(player_id: int, condition: Dictionary, delta: int) -> int:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return 0
	
	var changed_count = 0
	
	for tile_index in range(20):
		var tile = board_system_ref.tile_nodes[tile_index]
		
		if tile.tile_owner != player_id:
			continue
		
		if condition.has("required_level"):
			if tile.land_level != condition["required_level"]:
				continue
		
		if condition.has("required_elements"):
			if tile.element not in condition["required_elements"]:
				continue
		
		if change_level(tile_index, delta):
			changed_count += 1
	
	return changed_count

## 最高レベル領地を検索
func find_highest_level_land(player_id: int) -> int:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return -1
	
	var highest_level = 0
	var highest_tile = -1
	
	for tile_index in range(20):
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.tile_owner == player_id:
			if tile.land_level > highest_level:
				highest_level = tile.land_level
				highest_tile = tile_index
	
	return highest_tile

## 最低レベル領地を検索
func find_lowest_level_land(player_id: int) -> int:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return -1
	
	var lowest_level = 999
	var lowest_tile = -1
	
	for tile_index in range(20):
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.tile_owner == player_id:
			if tile.land_level < lowest_level:
				lowest_level = tile.land_level
				lowest_tile = tile_index
	
	return lowest_tile

## 検証：タイルインデックス
func _validate_tile_index(tile_index: int) -> bool:
	if tile_index < 0 or tile_index >= 20:
		push_error("SpellLand: 無効なタイルインデックス %d" % tile_index)
		return false
	return true

## 検証：属性
func _validate_element(element: String) -> bool:
	var valid_elements = ["fire", "water", "earth", "wind", "neutral"]
	return element in valid_elements
