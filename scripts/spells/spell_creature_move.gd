# SpellCreatureMove - クリーチャー移動・交換スペル/秘術
class_name SpellCreatureMove

# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var spell_phase_handler_ref: Object


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, spell_phase_handler: Object = null) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	spell_phase_handler_ref = spell_phase_handler


# ============ メイン効果適用 ============

## 効果を適用（effect_typeに応じて分岐）
func apply_effect(effect: Dictionary, target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"move_to_adjacent_enemy":
			return await _apply_move_to_adjacent_enemy(target_data, caster_player_id)
		"move_steps":
			var steps = effect.get("steps", 2)
			return await _apply_move_steps(target_data, steps, caster_player_id)
		"move_self":
			var steps = effect.get("steps", 1)
			return await _apply_move_self(target_data, steps)
		"swap_own_creatures":
			return await _apply_swap_own_creatures(target_data, caster_player_id)
		"destroy_and_move":
			return await _apply_destroy_and_move(target_data)
		_:
			push_error("[SpellCreatureMove] 未対応のeffect_type: %s" % effect_type)
			return {"success": false, "reason": "unknown_effect_type"}


# ============ 移動先取得 ============

## 1マス移動の候補を取得
func get_one_tile_destinations(from_tile_index: int) -> Array:
	return _get_tiles_within_steps(from_tile_index, 1)


## 2マス移動の候補を取得
func get_two_tiles_destinations(from_tile_index: int) -> Array:
	return _get_tiles_within_steps(from_tile_index, 2)


## 隣接する敵領地の候補を取得（アウトレイジ用）
func get_adjacent_enemy_destinations(from_tile_index: int) -> Array:
	var destinations: Array = []
	
	if not board_system_ref:
		return destinations
	
	# 隣接タイルを取得
	var adjacent_tiles: Array = []
	if board_system_ref.tile_neighbor_system:
		adjacent_tiles = board_system_ref.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
	
	# 敵領地のみフィルタ
	var current_player_id = board_system_ref.current_player_index
	
	for tile_index in adjacent_tiles:
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if not tile:
			continue
		
		# 特殊マスは除外
		if tile.tile_type in ["checkpoint", "warp"]:
			continue
		
		# 敵領地のみ（自領地や空地は除外）
		if tile.owner_id != -1 and tile.owner_id != current_player_id:
			destinations.append(tile_index)
	
	return destinations


## 指定マス数以内の移動先を取得（共通処理）
func _get_tiles_within_steps(from_tile_index: int, max_steps: int) -> Array:
	var destinations: Array = []
	
	if not board_system_ref or not board_system_ref.tile_neighbor_system:
		return destinations
	
	# BFSで指定マス数以内のタイルを探索
	var visited: Dictionary = {from_tile_index: 0}
	var queue: Array = [from_tile_index]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_distance = visited[current]
		
		if current_distance >= max_steps:
			continue
		
		var neighbors = board_system_ref.tile_neighbor_system.get_spatial_neighbors(current)
		for neighbor in neighbors:
			if visited.has(neighbor):
				continue
			
			var tile = board_system_ref.tile_nodes.get(neighbor)
			if not tile:
				continue
			
			# 特殊マスは通過不可
			if tile.tile_type in ["checkpoint", "warp"]:
				continue
			
			visited[neighbor] = current_distance + 1
			queue.append(neighbor)
	
	# 移動元を除外して結果を返す
	for tile_index in visited.keys():
		if tile_index != from_tile_index:
			destinations.append(tile_index)
	
	return destinations


# ============ 移動効果実装 ============

## 隣接敵領地への移動（アウトレイジ）
func _apply_move_to_adjacent_enemy(target_data: Dictionary, _caster_player_id: int) -> Dictionary:
	var from_tile_index = target_data.get("tile_index", -1)
	if from_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	# 移動先候補を取得
	var destinations = get_adjacent_enemy_destinations(from_tile_index)
	if destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination", "return_to_deck": true}
	
	# 移動先選択（複数ある場合はUI表示）
	var to_tile_index = -1
	if destinations.size() == 1:
		to_tile_index = destinations[0]
	else:
		to_tile_index = await _select_move_destination(destinations, "移動先の敵領地を選択")
		if to_tile_index == -1:
			return {"success": false, "reason": "cancelled"}
	
	# 移動実行
	_execute_move(from_tile_index, to_tile_index)
	
	# 戦闘発生（敵領地への移動）
	return {
		"success": true,
		"from_tile": from_tile_index,
		"to_tile": to_tile_index,
		"trigger_battle": true
	}


## 指定マス数移動（チャリオット、スレイプニール秘術）
func _apply_move_steps(target_data: Dictionary, steps: int, _caster_player_id: int) -> Dictionary:
	var from_tile_index = target_data.get("tile_index", -1)
	if from_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	# 移動先候補を取得
	var destinations = _get_tiles_within_steps(from_tile_index, steps)
	if destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination", "return_to_deck": true}
	
	# 自クリーチャーがいる土地を除外
	var current_player_id = board_system_ref.current_player_index
	var valid_destinations: Array = []
	for tile_index in destinations:
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if tile and tile.owner_id == current_player_id and not tile.creature_data.is_empty():
			continue  # 自クリーチャーがいる土地は除外
		valid_destinations.append(tile_index)
	
	if valid_destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination", "return_to_deck": true}
	
	# 移動先選択
	var to_tile_index = await _select_move_destination(valid_destinations, "%dマス以内の移動先を選択" % steps)
	if to_tile_index == -1:
		return {"success": false, "reason": "cancelled"}
	
	# 移動先が敵領地かチェック
	var to_tile = board_system_ref.tile_nodes.get(to_tile_index)
	var trigger_battle = false
	if to_tile and to_tile.owner_id != -1 and to_tile.owner_id != current_player_id:
		trigger_battle = true
	
	# 移動実行
	_execute_move(from_tile_index, to_tile_index)
	
	return {
		"success": true,
		"from_tile": from_tile_index,
		"to_tile": to_tile_index,
		"trigger_battle": trigger_battle
	}


## 自己移動（クリーピングフレイム秘術）
func _apply_move_self(target_data: Dictionary, steps: int) -> Dictionary:
	# target_dataには秘術発動者の情報が入っている
	var from_tile_index = target_data.get("tile_index", -1)
	if from_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	# 移動先候補を取得
	var destinations = _get_tiles_within_steps(from_tile_index, steps)
	if destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination"}
	
	# 自クリーチャーがいる土地を除外
	var current_player_id = board_system_ref.current_player_index
	var valid_destinations: Array = []
	for tile_index in destinations:
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if tile and tile.owner_id == current_player_id and not tile.creature_data.is_empty():
			continue
		valid_destinations.append(tile_index)
	
	if valid_destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination"}
	
	# 移動先選択
	var to_tile_index = await _select_move_destination(valid_destinations, "移動先を選択")
	if to_tile_index == -1:
		return {"success": false, "reason": "cancelled"}
	
	# 移動先が敵領地かチェック
	var to_tile = board_system_ref.tile_nodes.get(to_tile_index)
	var trigger_battle = false
	if to_tile and to_tile.owner_id != -1 and to_tile.owner_id != current_player_id:
		trigger_battle = true
	
	# 移動実行
	_execute_move(from_tile_index, to_tile_index)
	
	return {
		"success": true,
		"from_tile": from_tile_index,
		"to_tile": to_tile_index,
		"trigger_battle": trigger_battle
	}


## 破壊して移動（デスリーチ秘術）
func _apply_destroy_and_move(target_data: Dictionary) -> Dictionary:
	var target_tile_index = target_data.get("tile_index", -1)
	var caster_tile_index = target_data.get("caster_tile_index", -1)
	
	if target_tile_index == -1 or caster_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	var target_tile = board_system_ref.tile_nodes.get(target_tile_index)
	if not target_tile or target_tile.creature_data.is_empty():
		return {"success": false, "reason": "no_creature"}
	
	# 条件チェック: HPが減少しダウンしている
	var creature_data = target_tile.creature_data
	var current_hp = creature_data.get("current_hp", creature_data.get("hp", 0))
	var base_hp = creature_data.get("hp", 0)
	var is_down = target_tile.is_down() if target_tile.has_method("is_down") else false
	
	if current_hp >= base_hp or not is_down:
		return {"success": false, "reason": "condition_not_met"}
	
	# 対象クリーチャーを破壊
	var destroyed_name = creature_data.get("name", "クリーチャー")
	board_system_ref.remove_creature(target_tile_index)
	print("[SpellCreatureMove] %s を破壊しました" % destroyed_name)
	
	# 発動者をその場所に移動
	_execute_move(caster_tile_index, target_tile_index)
	
	return {
		"success": true,
		"destroyed_creature": destroyed_name,
		"from_tile": caster_tile_index,
		"to_tile": target_tile_index
	}


# ============ 交換効果実装 ============

## 自クリーチャー2体を交換（リリーフ）
func _apply_swap_own_creatures(target_data: Dictionary, caster_player_id: int) -> Dictionary:
	# target_dataには2体のクリーチャーの情報が入っている
	var tile_index_1 = target_data.get("tile_index_1", -1)
	var tile_index_2 = target_data.get("tile_index_2", -1)
	
	# 2体選択方式の場合
	if tile_index_1 == -1 or tile_index_2 == -1:
		# プレイヤーの自クリーチャー一覧を取得
		var own_creatures = _get_own_creature_tiles(caster_player_id)
		if own_creatures.size() < 2:
			return {"success": false, "reason": "not_enough_creatures", "return_to_deck": true}
		
		# 1体目選択
		tile_index_1 = await _select_creature_tile(own_creatures, "交換する1体目を選択")
		if tile_index_1 == -1:
			return {"success": false, "reason": "cancelled"}
		
		# 2体目選択（1体目を除外）
		var remaining = own_creatures.filter(func(t): return t != tile_index_1)
		tile_index_2 = await _select_creature_tile(remaining, "交換する2体目を選択")
		if tile_index_2 == -1:
			return {"success": false, "reason": "cancelled"}
	
	# 交換実行
	_execute_swap(tile_index_1, tile_index_2)
	
	return {
		"success": true,
		"tile_1": tile_index_1,
		"tile_2": tile_index_2
	}


# ============ 移動・交換実行 ============

## 移動実行（MovementHelperを使用）
func _execute_move(from_tile: int, to_tile: int) -> void:
	MovementHelper.execute_creature_move(board_system_ref, from_tile, to_tile)
	print("[SpellCreatureMove] タイル%d → タイル%d に移動" % [from_tile, to_tile])


## 交換実行
func _execute_swap(tile_index_1: int, tile_index_2: int) -> void:
	var tile_1 = board_system_ref.tile_nodes.get(tile_index_1)
	var tile_2 = board_system_ref.tile_nodes.get(tile_index_2)
	
	if not tile_1 or not tile_2:
		push_error("[SpellCreatureMove] 交換対象のタイルが無効です")
		return
	
	# クリーチャーデータを交換
	var creature_1 = tile_1.creature_data.duplicate() if tile_1.creature_data else {}
	var creature_2 = tile_2.creature_data.duplicate() if tile_2.creature_data else {}
	
	tile_1.creature_data = creature_2
	tile_2.creature_data = creature_1
	
	# owner_idも交換
	var owner_1 = tile_1.owner_id
	var owner_2 = tile_2.owner_id
	tile_1.owner_id = owner_2
	tile_2.owner_id = owner_1
	
	# 表示更新
	if tile_1.has_method("update_display"):
		tile_1.update_display()
	if tile_2.has_method("update_display"):
		tile_2.update_display()
	
	print("[SpellCreatureMove] タイル%d ↔ タイル%d を交換" % [tile_index_1, tile_index_2])


# ============ ユーティリティ ============

## プレイヤーの自クリーチャーがいるタイル一覧を取得
func _get_own_creature_tiles(player_id: int) -> Array:
	var tiles: Array = []
	
	var player_tiles = board_system_ref.get_player_tiles(player_id)
	for tile in player_tiles:
		if tile and not tile.creature_data.is_empty():
			tiles.append(tile.tile_index)
	
	return tiles


## 移動先選択UI（spell_phase_handler経由）
func _select_move_destination(destinations: Array, message: String) -> int:
	if spell_phase_handler_ref and spell_phase_handler_ref.has_method("select_tile_from_list"):
		return await spell_phase_handler_ref.select_tile_from_list(destinations, message)
	
	# フォールバック: 最初の候補を返す
	print("[SpellCreatureMove] UI選択なし、最初の候補を使用: %s" % message)
	return destinations[0] if destinations.size() > 0 else -1


## クリーチャー選択UI
func _select_creature_tile(tile_indices: Array, message: String) -> int:
	if spell_phase_handler_ref and spell_phase_handler_ref.has_method("select_tile_from_list"):
		return await spell_phase_handler_ref.select_tile_from_list(tile_indices, message)
	
	# フォールバック
	print("[SpellCreatureMove] UI選択なし、最初の候補を使用: %s" % message)
	return tile_indices[0] if tile_indices.size() > 0 else -1


# ============ ターゲット取得（スペル/秘術発動判定用） ============

## アウトレイジのターゲット取得（全クリーチャーで隣接敵領地があるもの）
func get_outrage_targets() -> Array:
	var targets: Array = []
	
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if not tile or tile.creature_data.is_empty():
			continue
		
		# 隣接敵領地があるか確認
		var adjacent_enemies = get_adjacent_enemy_destinations(tile_index)
		if adjacent_enemies.size() > 0:
			targets.append(tile_index)
	
	return targets


## チャリオットのターゲット取得（自クリーチャー）
func get_chariot_targets(player_id: int) -> Array:
	return _get_own_creature_tiles(player_id)


## リリーフの発動可能判定（自クリーチャーが2体以上）
func can_cast_relief(player_id: int) -> bool:
	var own_creatures = _get_own_creature_tiles(player_id)
	return own_creatures.size() >= 2
