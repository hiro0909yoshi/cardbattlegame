class_name SpellLand
extends RefCounted

## SpellLand - 土地操作スペル効果
##
## 土地の属性変更、レベル操作、クリーチャー破壊などを担当
## 
## 使用例:
##   spell_land.change_element(5, "fire")  # タイル5を火属性に変更
##   spell_land.change_level(10, -1)       # タイル10のレベルを1下げる
##   spell_land.destroy_creature(3)        # タイル3のクリーチャーを破壊

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
## 
## @param tile_index: タイルのインデックス（0-19）
## @param new_element: 新しい属性（"fire", "water", "earth", "air"）
## @return 成功した場合true
func change_element(tile_index: int, new_element: String) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	if not _validate_element(new_element):
		push_error("SpellLand: 無効な属性 '%s'" % new_element)
		return false
	
	var tile = board_system_ref.tiles[tile_index]
	var old_element = tile.element
	
	# 属性変更
	tile.element = new_element
	
	# ビジュアル更新
	board_system_ref._update_tile_visual(tile_index)
	
	print("[土地属性変更] タイル%d: %s → %s" % [tile_index, old_element, new_element])
	return true

## 土地のレベルを変更（増減）
## 
## @param tile_index: タイルのインデックス
## @param delta: レベル変化量（+1, -1等）
## @return 成功した場合true
func change_level(tile_index: int, delta: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	var tile = board_system_ref.tiles[tile_index]
	var old_level = tile.land_level
	var new_level = clamp(old_level + delta, 1, 5)  # レベルは1-5の範囲
	
	if new_level == old_level:
		print("[土地レベル変更] タイル%d: レベル変更なし（上限/下限）" % tile_index)
		return false
	
	# レベル変更
	tile.land_level = new_level
	
	# ビジュアル更新
	board_system_ref._update_tile_visual(tile_index)
	
	print("[土地レベル変更] タイル%d: Lv%d → Lv%d" % [tile_index, old_level, new_level])
	return true

## 土地のレベルを固定値に設定
## 
## @param tile_index: タイルのインデックス
## @param level: 設定するレベル（1-5）
## @return 成功した場合true
func set_level(tile_index: int, level: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	level = clamp(level, 1, 5)
	
	var tile = board_system_ref.tiles[tile_index]
	var old_level = tile.land_level
	
	if level == old_level:
		return false
	
	# レベル設定
	tile.land_level = level
	
	# ビジュアル更新
	board_system_ref._update_tile_visual(tile_index)
	
	print("[土地レベル設定] タイル%d: Lv%d → Lv%d" % [tile_index, old_level, level])
	return true

## クリーチャーを破壊
## 
## @param tile_index: タイルのインデックス
## @return 成功した場合true
func destroy_creature(tile_index: int) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	if not creature_manager_ref.has_creature(tile_index):
		print("[クリーチャー破壊] タイル%d: クリーチャーが存在しません" % tile_index)
		return false
	
	var creature_data = creature_manager_ref.get_data_ref(tile_index)
	var creature_name = creature_data.get("name", "不明")
	
	# クリーチャーを削除
	creature_manager_ref.set_data(tile_index, {})
	
	# ビジュアル更新
	board_system_ref.remove_creature(tile_index)
	
	print("[クリーチャー破壊] タイル%d: %sを破壊" % [tile_index, creature_name])
	return true

## 土地を放棄（所有権を失う）
## 
## @param tile_index: タイルのインデックス
## @param player_id: 放棄するプレイヤーID
## @return 放棄した土地の価値（魔力換算）
func abandon_land(tile_index: int, player_id: int) -> int:
	if not _validate_tile_index(tile_index):
		return 0
	
	var tile = board_system_ref.tiles[tile_index]
	
	# 所有者確認
	if tile.tile_owner != player_id:
		push_error("SpellLand: プレイヤー%dはタイル%dを所有していません" % [player_id, tile_index])
		return 0
	
	# 土地の価値を計算（レベル × 基本価格）
	var base_value = 100  # 基本価格
	var land_value = tile.land_level * base_value
	
	# クリーチャーも破壊
	if creature_manager_ref.has_creature(tile_index):
		destroy_creature(tile_index)
	
	# 所有権を失う
	tile.tile_owner = -1
	
	# ビジュアル更新
	board_system_ref._update_tile_visual(tile_index)
	
	# プレイヤーの土地数を更新
	var player = player_system_ref.players[player_id]
	var element = tile.element
	if player.lands_owned.has(element):
		player.lands_owned[element] = max(0, player.lands_owned[element] - 1)
	
	print("[土地放棄] タイル%d: プレイヤー%d Lv%d %s 価値=%d" % [
		tile_index, player_id, tile.land_level, element, land_value
	])
	
	return land_value

## 条件付き属性変更
## 
## @param tile_index: タイルのインデックス
## @param condition: 条件（Dictionary）
## @param new_element: 新しい属性
## @return 成功した場合true
func change_element_with_condition(tile_index: int, condition: Dictionary, new_element: String) -> bool:
	if not _validate_tile_index(tile_index):
		return false
	
	var tile = board_system_ref.tiles[tile_index]
	
	# 条件チェック：レベル制限
	if condition.has("max_level"):
		if tile.land_level > condition["max_level"]:
			print("[条件付き属性変更] タイル%d: レベル条件不一致（Lv%d > Lv%d）" % [
				tile_index, tile.land_level, condition["max_level"]
			])
			return false
	
	# 条件チェック：属性制限
	if condition.has("required_elements"):
		var required = condition["required_elements"]
		if tile.element not in required:
			print("[条件付き属性変更] タイル%d: 属性条件不一致（%s not in %s）" % [
				tile_index, tile.element, required
			])
			return false
	
	# 条件を満たした場合、属性変更
	return change_element(tile_index, new_element)

## プレイヤーの最多属性を取得
## 
## @param player_id: プレイヤーID
## @return 最も多く所有している属性
func get_player_dominant_element(player_id: int) -> String:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return "earth"  # デフォルト
	
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
## 
## @param player_id: プレイヤーID
## @param condition: 条件（Dictionary）
## @param delta: レベル変化量
## @return 変更されたタイル数
func change_level_multiple_with_condition(player_id: int, condition: Dictionary, delta: int) -> int:
	if player_id < 0 or player_id >= player_system_ref.players.size():
		return 0
	
	var changed_count = 0
	
	# 条件に合うタイルを検索
	for tile_index in range(20):
		var tile = board_system_ref.tiles[tile_index]
		
		# 所有者チェック
		if tile.tile_owner != player_id:
			continue
		
		# レベル条件チェック
		if condition.has("required_level"):
			if tile.land_level != condition["required_level"]:
				continue
		
		# 属性条件チェック
		if condition.has("required_elements"):
			if tile.element not in condition["required_elements"]:
				continue
		
		# 条件を満たした場合、レベル変更
		if change_level(tile_index, delta):
			changed_count += 1
	
	return changed_count

## タイルインデックスの検証
func _validate_tile_index(tile_index: int) -> bool:
	if tile_index < 0 or tile_index >= 20:
		push_error("SpellLand: 無効なタイルインデックス %d" % tile_index)
		return false
	return true

## 属性の検証
func _validate_element(element: String) -> bool:
	var valid_elements = ["fire", "water", "earth", "air"]
	return element in valid_elements
