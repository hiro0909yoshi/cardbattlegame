# SpellCreatureMove - クリーチャー移動・交換スペル/秘術
class_name SpellCreatureMove

# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var spell_phase_handler_ref: Object
var game_flow_manager_ref: Object


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, spell_phase_handler: Object = null) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	spell_phase_handler_ref = spell_phase_handler
	# game_flow_managerはspell_phase_handler経由で取得
	if spell_phase_handler and spell_phase_handler.game_flow_manager:
		game_flow_manager_ref = spell_phase_handler.game_flow_manager


# ============ メイン効果適用 ============

## 移動不可呪いをチェック
func _has_move_disable_curse(tile_index: int) -> bool:
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if not tile or tile.creature_data.is_empty():
		return false
	var creature_data = tile.creature_data
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "move_disable"


## SpellCurseToll参照を取得
func _get_spell_curse_toll():
	if board_system_ref and board_system_ref.has_meta("spell_curse_toll"):
		return board_system_ref.get_meta("spell_curse_toll")
	return null


## 敵領地への侵略が可能かチェック（peace呪い + プレイヤー侵略不可呪い）
func _can_invade_tile(tile_index: int, player_id: int) -> bool:
	var spell_curse_toll = _get_spell_curse_toll()
	if not spell_curse_toll:
		return true
	
	# peace呪いチェック（領地側の防御）
	if spell_curse_toll.has_peace_curse(tile_index):
		return false
	
	# プレイヤー侵略不可呪いチェック（バンフィズム）
	if spell_curse_toll.is_player_invasion_disabled(player_id):
		return false
	
	return true


## 効果を適用（effect_typeに応じて分岐）
func apply_effect(effect: Dictionary, target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	
	var result: Dictionary
	match effect_type:
		"move_to_adjacent_enemy":
			result = await _apply_move_to_adjacent_enemy(target_data, caster_player_id)
		"move_steps":
			var steps = effect.get("steps", 2)
			var exact_steps = effect.get("exact_steps", false)
			result = await _apply_move_steps(target_data, steps, exact_steps, caster_player_id)
		"move_self":
			var steps = effect.get("steps", 1)
			var exclude_enemy_creatures = effect.get("exclude_enemy_creatures", false)
			result = await _apply_move_self(target_data, steps, exclude_enemy_creatures)
		"destroy_and_move":
			result = _apply_destroy_and_move(target_data)
		_:
			push_error("[SpellCreatureMove] 未対応のeffect_type: %s" % effect_type)
			return {"success": false, "reason": "unknown_effect_type"}
	
	# 戦闘トリガーがある場合は戦闘を実行
	if result.get("trigger_battle", false):
		await _trigger_battle(result, caster_player_id)
	
	return result


## 戦闘を実行（敵領地への移動時）
func _trigger_battle(result: Dictionary, caster_player_id: int) -> void:
	var from_tile = result.get("from_tile", -1)
	var to_tile = result.get("to_tile", -1)
	
	if from_tile < 0 or to_tile < 0:
		return
	
	if not game_flow_manager_ref or not game_flow_manager_ref.battle_system:
		push_error("[SpellCreatureMove] battle_systemが見つかりません")
		return
	
	var attacker_creature = result.get("creature_data", {})
	var tile_info = board_system_ref.get_tile_info(to_tile) if board_system_ref else {}
	
	await game_flow_manager_ref.battle_system.execute_3d_battle_with_data(
		caster_player_id,
		attacker_creature,
		tile_info,
		{},  # attacker_item
		{},  # defender_item
		from_tile
	)


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
			# 侵略可能かチェック（peace呪い + バンフィズム）
			if not _can_invade_tile(tile_index, current_player_id):
				continue
			destinations.append(tile_index)
	
	return destinations


## 指定マス数以内の移動先を取得（共通処理）
func _get_tiles_within_steps(from_tile_index: int, max_steps: int) -> Array:
	var destinations: Array = []
	
	if not board_system_ref or not board_system_ref.tile_neighbor_system:
		return destinations
	
	var current_player_id = board_system_ref.current_player_index
	
	# BFSで指定マス数以内のタイルを探索
	# チェックポイント・ワープは通過可能だが止まれない
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
			
			# 通過は可能（距離をカウント）
			visited[neighbor] = current_distance + 1
			queue.append(neighbor)
	
	# 移動元を除外し、止まれないマスも除外して結果を返す
	for tile_index in visited.keys():
		if tile_index == from_tile_index:
			continue
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if tile and tile.tile_type in ["checkpoint", "warp"]:
			continue  # 止まれないマスは除外
		# 敵領地の場合は侵略可能かチェック（peace呪い + バンフィズム）
		if tile.owner_id != -1 and tile.owner_id != current_player_id:
			if not _can_invade_tile(tile_index, current_player_id):
				continue
		destinations.append(tile_index)
	
	return destinations


## ちょうど指定マス数先の移動先を取得（チャリオット用）
func _get_tiles_at_exact_steps(from_tile_index: int, exact_steps: int) -> Array:
	var destinations: Array = []
	
	if not board_system_ref or not board_system_ref.tile_neighbor_system:
		return destinations
	
	var current_player_id = board_system_ref.current_player_index
	
	# BFSで探索し、距離を記録
	var visited: Dictionary = {from_tile_index: 0}
	var queue: Array = [from_tile_index]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_distance = visited[current]
		
		if current_distance >= exact_steps:
			continue
		
		var neighbors = board_system_ref.tile_neighbor_system.get_spatial_neighbors(current)
		for neighbor in neighbors:
			if visited.has(neighbor):
				continue
			
			var tile = board_system_ref.tile_nodes.get(neighbor)
			if not tile:
				continue
			
			# 通過は可能（距離をカウント）
			visited[neighbor] = current_distance + 1
			queue.append(neighbor)
	
	# ちょうどexact_stepsマス先のタイルのみを返す
	# ただし、チェックポイント・ワープには止まれない
	for tile_index in visited.keys():
		if visited[tile_index] == exact_steps:
			var tile = board_system_ref.tile_nodes.get(tile_index)
			if tile and tile.tile_type in ["checkpoint", "warp"]:
				continue  # 止まれないマスは除外
			# 敵領地の場合は侵略可能かチェック（peace呪い + バンフィズム）
			if tile.owner_id != -1 and tile.owner_id != current_player_id:
				if not _can_invade_tile(tile_index, current_player_id):
					continue
			destinations.append(tile_index)
	
	return destinations


# ============ 移動効果実装 ============

## 隣接敵領地への移動（アウトレイジ）
func _apply_move_to_adjacent_enemy(target_data: Dictionary, _caster_player_id: int) -> Dictionary:
	var from_tile_index = target_data.get("tile_index", -1)
	if from_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	# 移動不可呪いチェック
	if _has_move_disable_curse(from_tile_index):
		return {"success": false, "reason": "move_disabled"}
	
	# 移動先候補を取得
	var destinations = get_adjacent_enemy_destinations(from_tile_index)
	if destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination", "return_to_deck": true}
	
	# 移動先選択（常にUI表示）
	var to_tile_index = await _select_move_destination(destinations, "移動先の敵領地を選択")
	if to_tile_index == -1:
		return {"success": false, "reason": "cancelled"}
	
	# 移動前にクリーチャーデータを取得（移動はバトル後に行う）
	var from_tile = board_system_ref.tile_nodes.get(from_tile_index)
	var creature_data = from_tile.creature_data.duplicate() if from_tile else {}
	
	# 注意: 移動はここでは実行しない（バトルシステムが処理する）
	# バトルシステムにfrom_tile_indexを渡し、勝敗に応じて移動を処理させる
	
	# 戦闘発生（敵領地への移動）
	return {
		"success": true,
		"from_tile": from_tile_index,
		"to_tile": to_tile_index,
		"trigger_battle": true,
		"creature_data": creature_data
	}


## 指定マス数移動（チャリオット、スレイプニール秘術）
func _apply_move_steps(target_data: Dictionary, steps: int, exact_steps: bool, _caster_player_id: int) -> Dictionary:
	var from_tile_index = target_data.get("tile_index", -1)
	if from_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	# 移動不可呪いチェック
	if _has_move_disable_curse(from_tile_index):
		return {"success": false, "reason": "move_disabled"}
	
	# 移動先候補を取得
	var destinations: Array = []
	if exact_steps:
		# ちょうどNマス先のみ（チャリオット用）
		destinations = _get_tiles_at_exact_steps(from_tile_index, steps)
	else:
		# Nマス以内（スレイプニール用）
		destinations = _get_tiles_within_steps(from_tile_index, steps)
	
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
	
	# 移動先が敵領地かチェック（敵クリーチャーがいる場合のみ戦闘）
	var to_tile = board_system_ref.tile_nodes.get(to_tile_index)
	var trigger_battle = false
	if to_tile and to_tile.owner_id != -1 and to_tile.owner_id != current_player_id:
		# 敵領地で、かつクリーチャーがいる場合は戦闘
		if not to_tile.creature_data.is_empty():
			trigger_battle = true
	
	# 移動前にクリーチャーデータを取得
	var from_tile = board_system_ref.tile_nodes.get(from_tile_index)
	var creature_data = from_tile.creature_data.duplicate() if from_tile else {}
	
	# 戦闘が発生する場合は移動を実行しない（バトルシステムに任せる）
	if not trigger_battle:
		_execute_move(from_tile_index, to_tile_index)
	
	return {
		"success": true,
		"from_tile": from_tile_index,
		"to_tile": to_tile_index,
		"trigger_battle": trigger_battle,
		"creature_data": creature_data
	}


## 自己移動（クリーピングフレイム秘術）
## exclude_enemy_creatures: 敵クリーチャーがいるタイルを除外（防御型用）
func _apply_move_self(target_data: Dictionary, steps: int, exclude_enemy_creatures: bool = false) -> Dictionary:
	# target_dataには秘術発動者の情報が入っている
	var from_tile_index = target_data.get("tile_index", -1)
	if from_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	# 移動不可呪いチェック
	if _has_move_disable_curse(from_tile_index):
		return {"success": false, "reason": "move_disabled"}
	
	# 移動先候補を取得
	var destinations = _get_tiles_within_steps(from_tile_index, steps)
	if destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination"}
	
	# 自クリーチャーがいる土地を除外
	var current_player_id = board_system_ref.current_player_index
	var valid_destinations: Array = []
	for tile_index in destinations:
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if not tile:
			continue
		# 自クリーチャーがいる土地は除外
		if tile.owner_id == current_player_id and not tile.creature_data.is_empty():
			continue
		# 防御型: 敵クリーチャーがいる土地も除外（戦闘不可のため）
		if exclude_enemy_creatures:
			if tile.owner_id != -1 and tile.owner_id != current_player_id and not tile.creature_data.is_empty():
				continue
		valid_destinations.append(tile_index)
	
	if valid_destinations.is_empty():
		return {"success": false, "reason": "no_valid_destination"}
	
	# 移動先選択
	var to_tile_index = await _select_move_destination(valid_destinations, "移動先を選択")
	if to_tile_index == -1:
		return {"success": false, "reason": "cancelled"}
	
	# 移動先が敵領地かチェック（敵クリーチャーがいる場合のみ戦闘）
	var to_tile = board_system_ref.tile_nodes.get(to_tile_index)
	var trigger_battle = false
	if to_tile and to_tile.owner_id != -1 and to_tile.owner_id != current_player_id:
		# 敵領地で、かつクリーチャーがいる場合は戦闘
		if not to_tile.creature_data.is_empty():
			trigger_battle = true
	
	# 移動前にクリーチャーデータを取得
	var from_tile = board_system_ref.tile_nodes.get(from_tile_index)
	var creature_data = from_tile.creature_data.duplicate() if from_tile else {}
	
	# 戦闘が発生する場合は移動を実行しない（バトルシステムに任せる）
	# ただし、exclude_enemy_creaturesの場合は戦闘が発生しないはず
	if not trigger_battle:
		_execute_move(from_tile_index, to_tile_index)
	
	return {
		"success": true,
		"from_tile": from_tile_index,
		"to_tile": to_tile_index,
		"trigger_battle": trigger_battle,
		"creature_data": creature_data
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


# ============ 移動実行 ============

## 移動実行（MovementHelperを使用）
func _execute_move(from_tile: int, to_tile: int) -> void:
	if not board_system_ref:
		return
	
	var from_tile_node = board_system_ref.tile_nodes.get(from_tile)
	var to_tile_node = board_system_ref.tile_nodes.get(to_tile)
	if not from_tile_node or not to_tile_node:
		return
	
	# クリーチャーデータを取得
	var creature_data = from_tile_node.creature_data.duplicate()
	var owner_id = from_tile_node.owner_id
	
	# 移動による呪い消滅
	if creature_data.has("curse"):
		var curse_name = creature_data["curse"].get("name", "不明")
		creature_data.erase("curse")
		print("[SpellCreatureMove] 呪い消滅（移動）: ", curse_name)
	
	# 移動元のクリーチャーを削除
	board_system_ref.remove_creature(from_tile)
	
	# 移動先にクリーチャーを配置
	board_system_ref.set_tile_owner(to_tile, owner_id)
	board_system_ref.place_creature(to_tile, creature_data)
	
	# ダウン状態設定（不屈チェック）
	if to_tile_node.has_method("set_down_state"):
		if not PlayerBuffSystem.has_unyielding(creature_data):
			to_tile_node.set_down_state(true)
	
	print("[SpellCreatureMove] タイル%d → タイル%d に移動" % [from_tile, to_tile])



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
