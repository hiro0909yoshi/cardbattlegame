# SpellCreatureMove - クリーチャー移動・交換スペル/秘術
class_name SpellCreatureMove

# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var spell_phase_handler_ref: Object
var game_flow_manager_ref: Object

# ============ バトル保留用変数 ============

var pending_battle_result: Dictionary = {}
var pending_battle_caster_player_id: int = -1
var pending_battle_tile_info: Dictionary = {}
var pending_attacker_item: Dictionary = {}
var pending_defender_item: Dictionary = {}
var is_waiting_for_defender_item: bool = false

# バトル完了待機用シグナル
signal spell_move_battle_completed


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


## 敵領地への侵略が可能かチェック（peace呪い + プレイヤー侵略不可呪い + マーシフルワールド + クリーチャー移動侵略無効）
func _can_invade_tile(tile_index: int, player_id: int) -> bool:
	var spell_curse_toll = _get_spell_curse_toll()
	if not spell_curse_toll:
		return true
	
	# peace呪いチェック（領地側の防御）
	if spell_curse_toll.has_peace_curse(tile_index):
		return false
	
	# クリーチャー移動侵略無効チェック（グルイースラッグ、ランドアーチン等）
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if tile and not tile.creature_data.is_empty():
		if spell_curse_toll.is_creature_invasion_immune(tile.creature_data):
			return false
	
	# プレイヤー侵略不可呪いチェック（バンフィズム）
	if spell_curse_toll.is_player_invasion_disabled(player_id):
		return false
	
	# マーシフルワールド（下位侵略不可）チェック - SpellWorldCurseに委譲
	if tile and tile.owner_id >= 0 and tile.owner_id != player_id:
		if game_flow_manager_ref and game_flow_manager_ref.spell_world_curse:
			if game_flow_manager_ref.spell_world_curse.check_invasion_blocked(player_id, tile.owner_id, false):
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
## アイテムフェーズを経由してからバトルを実行
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
	
	# バトル情報を保存
	pending_battle_result = result
	pending_battle_caster_player_id = caster_player_id
	pending_battle_tile_info = tile_info
	pending_attacker_item = {}
	pending_defender_item = {}
	is_waiting_for_defender_item = false
	
	# 移動中フラグを設定（応援スキル計算から除外するため）
	attacker_creature["is_moving"] = true
	
	# アイテムフェーズを開始（攻撃側）
	if game_flow_manager_ref and game_flow_manager_ref.item_phase_handler:
		# アイテムフェーズ完了シグナルに接続
		var item_handler = game_flow_manager_ref.item_phase_handler
		if not item_handler.item_phase_completed.is_connected(_on_spell_move_item_phase_completed):
			item_handler.item_phase_completed.connect(_on_spell_move_item_phase_completed, CONNECT_ONE_SHOT)
		
		# 攻撃側フェーズ開始（防御側情報を渡して事前選択）
		item_handler.start_item_phase(caster_player_id, attacker_creature, tile_info)
		
		# バトル完了シグナルを待機
		await spell_move_battle_completed
	else:
		# ItemPhaseHandlerがない場合は直接バトル
		await _execute_spell_move_battle()


## アイテムフェーズ完了時のコールバック
func _on_spell_move_item_phase_completed() -> void:

	if not is_waiting_for_defender_item:
		# 攻撃側のアイテムフェーズ完了 → 防御側のアイテムフェーズ開始
		
		# 攻撃側のアイテムを保存
		if game_flow_manager_ref and game_flow_manager_ref.item_phase_handler:
			pending_attacker_item = game_flow_manager_ref.item_phase_handler.get_selected_item()
		
		# 防御側のアイテムフェーズを開始
		var defender_owner = pending_battle_tile_info.get("owner", -1)
		if defender_owner >= 0:
			is_waiting_for_defender_item = true
			
			# 防御側のアイテムフェーズ開始
			if game_flow_manager_ref and game_flow_manager_ref.item_phase_handler:
				var item_handler = game_flow_manager_ref.item_phase_handler
				# 再度シグナルに接続（ONE_SHOTなので再接続が必要）
				# ONE_SHOTはコールバック完了後に切断されるため、コールバック内では常に再接続が必要
				item_handler.item_phase_completed.connect(_on_spell_move_item_phase_completed, CONNECT_ONE_SHOT)
				

				# 防御側クリーチャーのデータを取得して渡す
				var defender_creature = pending_battle_tile_info.get("creature", {})
				# 攻撃側クリーチャーデータを設定（無効化判定用）
				item_handler.set_opponent_creature(pending_battle_result.get("creature_data", {}))
				# タイル情報を設定（シミュレーション用）
				item_handler.set_defense_tile_info(pending_battle_tile_info)
				item_handler.start_item_phase(defender_owner, defender_creature)
			else:
				# ItemPhaseHandlerがない場合は直接バトル
				_start_battle_deferred()
		else:
			# 防御側がいない場合（ありえないが念のため）
			_start_battle_deferred()
	else:
		# 防御側のアイテムフェーズ完了 → バトル開始
		print("[SpellCreatureMove] 防御側アイテムフェーズ完了、バトル開始")
		
		# 防御側のアイテムを保存
		if game_flow_manager_ref and game_flow_manager_ref.item_phase_handler:
			pending_defender_item = game_flow_manager_ref.item_phase_handler.get_selected_item()
		
		is_waiting_for_defender_item = false
		_start_battle_deferred()


## バトルを遅延実行（シグナルコールバックからawaitできないため）
func _start_battle_deferred() -> void:
	# call_deferredで次フレームに実行
	_execute_spell_move_battle.call_deferred()


## 保留中のスペル移動バトルを実行
func _execute_spell_move_battle() -> void:
	if pending_battle_result.is_empty():
		spell_move_battle_completed.emit()
		return
	
	var from_tile = pending_battle_result.get("from_tile", -1)
	var attacker_creature = pending_battle_result.get("creature_data", {})
	
	print("[SpellCreatureMove] バトル実行: タイル%d → タイル%d" % [from_tile, pending_battle_tile_info.get("index", -1)])
	
	await game_flow_manager_ref.battle_system.execute_3d_battle_with_data(
		pending_battle_caster_player_id,
		attacker_creature,
		pending_battle_tile_info,
		pending_attacker_item,
		pending_defender_item,
		from_tile
	)
	
	# バトル情報をクリア
	pending_battle_result = {}
	pending_battle_caster_player_id = -1
	pending_battle_tile_info = {}
	pending_attacker_item = {}
	pending_defender_item = {}
	is_waiting_for_defender_item = false
	
	# バトル完了シグナルを発火
	spell_move_battle_completed.emit()


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
		
		# 配置不可タイルは除外（クリーチャー移動）
		if not TileHelper.is_placeable_tile(tile):
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
		if tile and not TileHelper.is_placeable_tile(tile):
			continue  # 配置不可タイルは除外（クリーチャー移動）
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
	# ただし、停止不可マスには止まれない
	for tile_index in visited.keys():
		if visited[tile_index] == exact_steps:
			var tile = board_system_ref.tile_nodes.get(tile_index)
			if tile and not TileHelper.is_placeable_tile(tile):
				continue  # 配置不可タイルは除外（クリーチャー移動）
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
	
	# CPUが選んだ移動先があればそれを使用（アウトレイジAI用）
	var to_tile_index = -1
	if target_data.has("enemy_tile_index"):
		var cpu_target = target_data.get("enemy_tile_index", -1)
		if cpu_target >= 0 and cpu_target in destinations:
			to_tile_index = cpu_target
	
	# それ以外は移動先選択UI表示
	if to_tile_index == -1:
		to_tile_index = await _select_move_destination(destinations, "移動先の敵領地を選択")
	
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
	
	# CPUが選んだ移動先があればそれを使用（チャリオットAI用）
	var to_tile_index = -1
	if target_data.has("enemy_tile_index"):
		var cpu_target = target_data.get("enemy_tile_index", -1)
		if cpu_target >= 0 and cpu_target in valid_destinations:
			to_tile_index = cpu_target
	
	# それ以外は移動先選択UI表示
	if to_tile_index == -1:
		to_tile_index = await _select_move_destination(valid_destinations, "%dマス以内の移動先を選択" % steps)
	
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
