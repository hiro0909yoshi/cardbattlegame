## CPU スペルカード使用判断
## 手札のスペルを評価し、使用すべきか判断する
class_name CPUSpellAI
extends RefCounted

## 参照
var condition_checker: CPUSpellConditionChecker = null
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var creature_manager: Node = null
var lap_system: Node = null

## 優先度の数値変換
const PRIORITY_VALUES = {
	"highest": 4.0,
	"high": 3.0,
	"medium_high": 2.5,
	"medium": 2.0,
	"low": 1.0,
	"very_low": 0.5
}

## 初期化
func initialize(b_system: Node, p_system: Node, c_system: Node, cr_manager: Node, l_system: Node = null, gf_manager: Node = null) -> void:
	board_system = b_system
	player_system = p_system
	card_system = c_system
	creature_manager = cr_manager
	lap_system = l_system
	
	# 条件チェッカー初期化
	condition_checker = CPUSpellConditionChecker.new()
	condition_checker.initialize(b_system, p_system, c_system, cr_manager, l_system, gf_manager)

## スペル使用判断のメインエントリ
## 戻り値: {use: bool, spell: Dictionary, target: Dictionary} または null
func decide_spell(player_id: int) -> Dictionary:
	if not card_system or not player_system:
		return {"use": false}
	
	# 使用可能なスペルを取得
	var usable_spells = _get_usable_spells(player_id)
	if usable_spells.is_empty():
		return {"use": false}
	
	# コンテキスト作成
	var context = _build_context(player_id)
	
	# 各スペルを評価
	var evaluated_spells = []
	for spell in usable_spells:
		var evaluation = _evaluate_spell(spell, context)
		if evaluation.should_use:
			evaluated_spells.append({
				"spell": spell,
				"score": evaluation.score,
				"target": evaluation.target
			})
	
	if evaluated_spells.is_empty():
		return {"use": false}
	
	# スコアでソートして最高のものを選択
	evaluated_spells.sort_custom(func(a, b): return a.score > b.score)
	
	var best = evaluated_spells[0]
	return {
		"use": true,
		"spell": best.spell,
		"target": best.target,
		"score": best.score
	}

## 使用可能なスペルを取得
func _get_usable_spells(player_id: int) -> Array:
	var hand = card_system.get_all_cards_for_player(player_id)
	var magic = player_system.get_magic(player_id)
	var spells = []
	
	for card in hand:
		if card.get("type") != "spell":
			continue
		
		# コストチェック
		var cost = _get_spell_cost(card)
		if cost > magic:
			continue
		
		# cpu_ruleがskipのものは除外
		var cpu_rule = card.get("cpu_rule", {})
		if cpu_rule.get("pattern") == "skip":
			continue
		
		spells.append(card)
	
	return spells

## スペルを評価
func _evaluate_spell(spell: Dictionary, context: Dictionary) -> Dictionary:
	var cpu_rule = spell.get("cpu_rule", {})
	var pattern = cpu_rule.get("pattern", "")
	var priority = cpu_rule.get("priority", "low")
	var base_score = PRIORITY_VALUES.get(priority, 1.0)
	
	var result = {
		"should_use": false,
		"score": 0.0,
		"target": null
	}
	
	match pattern:
		"immediate":
			result = _evaluate_immediate(spell, context, base_score)
		
		"has_target":
			result = _evaluate_has_target(spell, context, base_score)
		
		"condition":
			result = _evaluate_condition(spell, context, base_score)
		
		"enemy_hand":
			result = _evaluate_enemy_hand(spell, context, base_score)
		
		"profit_calc":
			result = _evaluate_profit_calc(spell, context, base_score)
		
		"strategic":
			result = _evaluate_strategic(spell, context, base_score)
		
		_:
			# 不明なパターンは使用しない
			pass
	
	return result

## パターン: immediate（即座使用）
func _evaluate_immediate(_spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	# 即座使用系は常に使用可能
	return {
		"should_use": true,
		"score": base_score,
		"target": {"type": "self", "player_id": context.player_id}
	}

## パターン: has_target（ターゲット存在）
func _evaluate_has_target(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = spell.get("cpu_rule", {})
	var target_condition = cpu_rule.get("target_condition", "")
	
	var targets = []
	
	# ダメージ値をcontextに追加
	var damage_value = _get_damage_value(spell)
	if damage_value > 0:
		context["damage_value"] = damage_value
	
	if target_condition:
		targets = condition_checker.check_target_condition(target_condition, context)
	else:
		targets = _get_default_targets(spell, context)
	
	if targets.is_empty():
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 最適なターゲットを選択（スコア付き）
	var selection = _select_best_target_with_score(targets, spell, context)
	var best_target = selection.target
	var target_score = selection.score
	
	# 倒せるターゲットがいる場合はスコアを1.5倍
	var adjusted_score = base_score
	if damage_value > 0 and target_score >= 3.0:
		adjusted_score = base_score * 1.5
	
	return {
		"should_use": true,
		"score": adjusted_score,
		"target": best_target
	}

## パターン: condition（条件判定）
func _evaluate_condition(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = spell.get("cpu_rule", {})
	var condition = cpu_rule.get("condition", "")
	
	if not condition:
		return {"should_use": false, "score": 0.0, "target": null}
	
	# スペル情報をcontextに追加（move_invasion_win等で使用）
	var extended_context = context.duplicate()
	extended_context["spell"] = spell
	
	# 条件チェック
	if not condition_checker.check_condition(condition, extended_context):
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 条件を満たした場合、ターゲットを取得
	var target = _get_condition_target(spell, extended_context)
	
	# 適切なターゲットがない場合は使用しない
	if target.is_empty():
		return {"should_use": false, "score": 0.0, "target": null}
	
	return {
		"should_use": true,
		"score": base_score,
		"target": target
	}

## パターン: enemy_hand（敵手札参照）
func _evaluate_enemy_hand(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = spell.get("cpu_rule", {})
	var target_condition = cpu_rule.get("target_condition", "")
	
	# 敵手札をチェック
	var targets = []
	if target_condition:
		targets = condition_checker.check_target_condition(target_condition, context)
	else:
		# デフォルト: 敵プレイヤーを対象
		targets = _get_enemy_players(context)
	
	if targets.is_empty():
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 最適なターゲットを選択
	var best_target = targets[0]
	
	return {
		"should_use": true,
		"score": base_score,
		"target": best_target
	}

## パターン: profit_calc（損益計算）
func _evaluate_profit_calc(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = spell.get("cpu_rule", {})
	var profit_formula = cpu_rule.get("profit_formula", "")
	var profit_condition = cpu_rule.get("profit_condition", "")
	var cost = _get_spell_cost(spell)
	
	var target = null
	
	# profit_conditionがある場合は条件チェック
	if not profit_condition.is_empty():
		var condition_met = _check_profit_condition(profit_condition, context, cost)
		if not condition_met:
			return {"should_use": false, "score": 0.0, "target": null}
		
		target = _get_profit_target(spell, context)
		return {
			"should_use": true,
			"score": base_score,
			"target": target
		}
	
	# 従来のprofit_formula形式
	var profit = _calculate_profit(profit_formula, context)
	
	# コストより利益が大きければ使用
	if profit <= cost:
		return {"should_use": false, "score": 0.0, "target": null}
	
	# スコアを利益率で調整
	var profit_ratio = float(profit) / float(cost) if cost > 0 else 1.0
	var adjusted_score = base_score * min(profit_ratio, 2.0)
	
	target = _get_profit_target(spell, context)
	
	return {
		"should_use": true,
		"score": adjusted_score,
		"target": target
	}

## profit_condition のチェック
func _check_profit_condition(condition: String, context: Dictionary, cost: int) -> bool:
	match condition:
		"destroyed_count_gte_4":
			return context.get("destroyed_count", 0) >= 4
		"enemy_lands_gte_3":
			return _get_enemy_land_count(context) >= 3
		"enemy_magic_gte_300":
			return _get_max_enemy_magic(context) >= 300
		"enemy_magic_higher":
			var my_magic = context.get("magic", 0)
			return _get_max_enemy_magic(context) > my_magic
		"land_value_high":
			var highest_value = _get_highest_own_land_value(context)
			return highest_value * 0.7 > cost
		"lap_behind_enemy":
			return _calculate_lap_diff(context) > 0
		_:
			push_warning("Unknown profit_condition: " + condition)
			return false

## 最高価値の自領地を取得
func _get_highest_own_land_value(context: Dictionary) -> int:
	if not board_system:
		return 0
	
	var player_id = context.get("player_id", 0)
	var highest = 0
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		if tile.get("owner", tile.get("owner_id", -1)) == player_id:
			var level = tile.get("level", 1)
			var base_value = tile.get("base_value", 100)
			var value = base_value * level
			highest = max(highest, value)
	
	return highest

## パターン: strategic（戦略的判断）
func _evaluate_strategic(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = spell.get("cpu_rule", {})
	var strategy = cpu_rule.get("strategy", "")
	
	var should_use = false
	var score_multiplier = 0.5
	
	var target = null
	
	match strategy:
		"after_lap_complete":
			should_use = _check_after_lap_complete(context)
			score_multiplier = 0.8
			# スペルのターゲットタイプに応じてターゲットを設定
			var effect_parsed = spell.get("effect_parsed", {})
			var target_type = effect_parsed.get("target_type", "")
			if target_type == "land":
				# 土地選択スペル（マジカルリープ等）: 最寄りチェックポイントに近い土地を選ぶ
				target = _get_best_warp_target_for_checkpoint(spell, context)
			else:
				# 自動ワープスペル（エスケープ等）: 自分をターゲット
				target = {"type": "player", "player_id": context.player_id}
		"dice_manipulation":
			should_use = _check_dice_manipulation_useful(context)
			score_multiplier = 0.6
			# 敵をターゲット（自分の高レベル土地を踏ませたい）
			var enemies = _get_enemy_players(context)
			if not enemies.is_empty():
				target = enemies[randi() % enemies.size()]
		"near_enemy_high_toll":
			should_use = _check_near_enemy_high_toll(context)
			score_multiplier = 0.7
			target = _get_strategic_target(spell, context)
		_:
			should_use = randf() < 0.3
			score_multiplier = 0.5
			target = _get_strategic_target(spell, context)
	
	if should_use and target != null:
		return {
			"should_use": true,
			"score": base_score * score_multiplier,
			"target": target
		}
	
	return {"should_use": false, "score": 0.0, "target": null}

## チェックポイントシグナルが0個かチェック（周回完了直後）
func _check_after_lap_complete(context: Dictionary) -> bool:
	if not lap_system:
		return false
	
	var player_id = context.get("player_id", 0)
	var visited_count = lap_system.get_visited_checkpoint_count(player_id)
	return visited_count == 0

## ダイス操作が有用かチェック
func _check_dice_manipulation_useful(context: Dictionary) -> bool:
	# 自分のレベル2以上の土地があれば、敵に踏ませたいので有用
	var own_high_lands = _get_own_high_level_lands(context)
	return own_high_lands.size() > 0

## 自分の高レベル土地を取得（レベル2以上）
func _get_own_high_level_lands(context: Dictionary) -> Array:
	var results = []
	if not board_system:
		return results
	
	var player_id = context.get("player_id", 0)
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id:
			continue
		
		var level = tile.get("level", 1)
		if level >= 2:
			results.append(tile)
	
	return results

## 敵の高額通行料土地の近くにいるかチェック
func _check_near_enemy_high_toll(context: Dictionary) -> bool:
	if not player_system or not board_system:
		return false
	
	var player_id = context.get("player_id", 0)
	var player_pos = player_system.get_player_position(player_id)
	
	# 前方8マス以内に敵の高レベル土地があるか
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var level = tile.get("level", 1)
		if level >= 3:
			var tile_index = tile.get("index", -1)
			var distance = abs(tile_index - player_pos)
			if distance <= 8 and distance > 0:
				return true
	
	return false

## 敵の高レベル土地を取得
func _get_enemy_high_level_lands(context: Dictionary) -> Array:
	var results = []
	if not board_system:
		return results
	
	var player_id = context.get("player_id", 0)
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var level = tile.get("level", 1)
		if level >= 3:
			results.append(tile)
	
	return results

## 最寄りチェックポイントに近い土地をワープターゲットとして取得（マジカルリープ用）
func _get_best_warp_target_for_checkpoint(spell: Dictionary, context: Dictionary) -> Dictionary:
	if not board_system or not lap_system:
		return {}
	
	var player_id = context.get("player_id", 0)
	var current_tile = _get_player_current_tile(player_id)
	
	# スペルの距離制限を取得
	var effect_parsed = spell.get("effect_parsed", {})
	var target_info = effect_parsed.get("target_info", {})
	var distance_min = target_info.get("distance_min", 1)
	var distance_max = target_info.get("distance_max", 4)
	
	# 未訪問チェックポイントタイルを取得
	var checkpoint_tiles = _get_unvisited_checkpoint_tiles(player_id)
	if checkpoint_tiles.is_empty():
		# 全て訪問済みなら最寄りチェックポイントを使用
		checkpoint_tiles = _get_all_checkpoint_tiles()
	
	if checkpoint_tiles.is_empty():
		return {}
	
	# 距離制限内の土地を取得
	var candidate_tiles = _get_tiles_in_range(current_tile, distance_min, distance_max)
	if candidate_tiles.is_empty():
		return {}
	
	# 最寄りチェックポイントに最も近い土地を選ぶ
	var best_tile = -1
	var best_distance = 999999
	
	for tile_index in candidate_tiles:
		for cp_tile in checkpoint_tiles:
			var dist = _calculate_tile_distance(tile_index, cp_tile)
			if dist < best_distance:
				best_distance = dist
				best_tile = tile_index
	
	if best_tile >= 0:
		return {"type": "land", "tile_index": best_tile}
	
	return {}

## 未訪問チェックポイントタイルを取得
func _get_unvisited_checkpoint_tiles(player_id: int) -> Array:
	var results = []
	if not board_system or not lap_system:
		return results
	
	# lap_systemから未訪問チェックポイントを取得
	var required_checkpoints = lap_system.required_checkpoints
	var player_state = lap_system.player_lap_state.get(player_id, {})
	
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			# このチェックポイントは未訪問
			var tile_index = _get_checkpoint_tile_index(checkpoint)
			if tile_index >= 0:
				results.append(tile_index)
	
	return results

## 全チェックポイントタイルを取得
func _get_all_checkpoint_tiles() -> Array:
	var results = []
	if not board_system:
		return results
	
	var tiles = board_system.tile_nodes if board_system.has_method("get") else {}
	if board_system.has("tile_nodes"):
		tiles = board_system.tile_nodes
	
	for tile_index in tiles.keys():
		var tile = tiles[tile_index]
		if tile and tile.tile_type == "checkpoint":
			results.append(tile_index)
	
	return results

## チェックポイント種別からタイルインデックスを取得
func _get_checkpoint_tile_index(checkpoint_type: String) -> int:
	if not board_system:
		return -1
	
	var tiles = board_system.tile_nodes if "tile_nodes" in board_system else {}
	
	for tile_index in tiles.keys():
		var tile = tiles[tile_index]
		if tile and tile.tile_type == "checkpoint":
			var type_str = _get_checkpoint_type_string(tile)
			if type_str == checkpoint_type:
				return tile_index
	
	return -1

## チェックポイントタイルからタイプ文字列を取得（N, S, E, W対応）
func _get_checkpoint_type_string(tile) -> String:
	if not tile:
		return ""
	var cp_type = tile.checkpoint_type if "checkpoint_type" in tile else 0
	match cp_type:
		0: return "N"
		1: return "S"
		2: return "E"
		3: return "W"
		_: return ""

## 進行方向から最も遠い未訪問ゲートを取得（リミッション用）
func _get_farthest_unvisited_gate(context: Dictionary) -> Dictionary:
	if not board_system or not lap_system:
		return {}
	
	var player_id = context.get("player_id", 0)
	var current_tile = _get_player_current_tile(player_id)
	var player_state = lap_system.player_lap_state.get(player_id, {})
	var required_checkpoints = lap_system.required_checkpoints
	
	# 未訪問で1周完了を引き起こさないゲートを収集
	var selectable_gates = []
	var unvisited_count = 0
	
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			unvisited_count += 1
	
	# 未訪問が2つ以上ある場合のみ選択可能
	if unvisited_count < 2:
		return {}
	
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			var tile_index = _get_checkpoint_tile_index(checkpoint)
			if tile_index >= 0:
				# 進行方向での距離を計算
				var distance = _calculate_forward_distance(current_tile, tile_index, player_id)
				selectable_gates.append({
					"checkpoint": checkpoint,
					"tile_index": tile_index,
					"distance": distance
				})
	
	if selectable_gates.is_empty():
		return {}
	
	# 距離でソート（遠い順）
	selectable_gates.sort_custom(func(a, b): return a.distance > b.distance)
	
	var farthest = selectable_gates[0]
	
	return {
		"type": "gate",
		"tile_index": farthest.tile_index,
		"gate_key": farthest.checkpoint
	}

## 距離制限内の土地を取得
func _get_tiles_in_range(from_tile: int, min_dist: int, max_dist: int) -> Array:
	var results = []
	if not board_system:
		return results
	
	var tiles = board_system.tile_nodes if "tile_nodes" in board_system else {}
	
	for tile_index in tiles.keys():
		if tile_index == from_tile:
			continue
		
		var dist = _calculate_tile_distance(from_tile, tile_index)
		if dist >= min_dist and dist <= max_dist:
			results.append(tile_index)
	
	return results

## タイル間の距離を計算（BFS・両方向）
func _calculate_tile_distance(from_tile: int, to_tile: int) -> int:
	if from_tile == to_tile:
		return 0
	
	if not board_system or not "tile_neighbor_system" in board_system:
		# フォールバック: 単純な差分
		return abs(to_tile - from_tile)
	
	var neighbor_system = board_system.tile_neighbor_system
	if not neighbor_system:
		return abs(to_tile - from_tile)
	
	# BFS
	var visited = {}
	var queue = [[from_tile, 0]]
	visited[from_tile] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var tile = current[0]
		var dist = current[1]
		
		if dist > 20:  # 上限
			break
		
		var neighbors = neighbor_system.get_sequential_neighbors(tile) if neighbor_system.has_method("get_sequential_neighbors") else []
		
		for neighbor in neighbors:
			if neighbor == to_tile:
				return dist + 1
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
	
	return abs(to_tile - from_tile)  # フォールバック

## プレイヤーの進行方向での距離を計算（リミッション用）
## 注: from_tile == to_tileの場合も1周分の距離を返す（現在位置のチェックポイント用）
func _calculate_forward_distance(from_tile: int, to_tile: int, player_id: int) -> int:
	if not board_system or not "tile_neighbor_system" in board_system:
		return abs(to_tile - from_tile)
	
	var neighbor_system = board_system.tile_neighbor_system
	if not neighbor_system:
		return abs(to_tile - from_tile)
	
	# プレイヤーの進行方向を取得
	var direction = 1
	if player_system and player_id < player_system.players.size():
		direction = player_system.players[player_id].current_direction
	
	# 進行方向のみで探索
	var current = from_tile
	var came_from = -1
	var dist = 0
	var max_steps = 100  # 無限ループ防止
	
	while dist < max_steps:
		# 次のタイルを取得（進行方向のみ）
		var next_tile = _get_next_tile_in_direction(current, came_from, direction)
		if next_tile < 0:
			break
		
		dist += 1
		
		if next_tile == to_tile:
			return dist
		
		came_from = current
		current = next_tile
	
	return 9999  # 到達不可

## 進行方向で次のタイルを取得
func _get_next_tile_in_direction(current_tile: int, came_from: int, direction: int) -> int:
	if not board_system:
		return current_tile + direction
	
	# tile_neighbor_systemを使用
	if "tile_neighbor_system" in board_system and board_system.tile_neighbor_system:
		var neighbor_system = board_system.tile_neighbor_system
		if neighbor_system.has_method("get_sequential_neighbors"):
			var neighbors = neighbor_system.get_sequential_neighbors(current_tile)
			var choices = []
			for n in neighbors:
				if n != came_from:
					choices.append(n)
			
			if choices.is_empty():
				return came_from if came_from >= 0 else current_tile + direction
			if choices.size() == 1:
				return choices[0]
			
			# 複数選択肢がある場合、方向に基づいて選択
			choices.sort()
			if direction > 0:
				return choices[-1]
			else:
				return choices[0]
	
	# フォールバック: 単純に+direction
	return current_tile + direction

## プレイヤーの現在位置を取得
func _get_player_current_tile(player_id: int) -> int:
	if board_system and "movement_controller" in board_system and board_system.movement_controller:
		return board_system.movement_controller.get_player_tile(player_id)
	if player_system:
		return player_system.get_player_position(player_id)
	return 0

# =============================================================================
# ヘルパー関数
# =============================================================================

## コンテキスト作成
func _build_context(player_id: int) -> Dictionary:
	var context = {
		"player_id": player_id,
		"magic": player_system.get_magic(player_id) if player_system else 0,
		"hand_count": 0,
		"lap_count": 0,
		"rank": 1,
		"destroyed_count": 0
	}
	
	if card_system:
		var hand = card_system.get_all_cards_for_player(player_id)
		context.hand_count = hand.size()
	
	# 周回数はlap_systemから取得
	if lap_system:
		context.lap_count = lap_system.get_lap_count(player_id)
	
	# 破壊カウントはlap_systemから取得（グローバル）
	if lap_system:
		context.destroyed_count = lap_system.get_destroy_count()
	
	if player_system:
		context.rank = _get_player_rank(player_id)
	
	return context

## スペルコスト取得
func _get_spell_cost(spell: Dictionary) -> int:
	var cost_data = spell.get("cost", {})
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	elif typeof(cost_data) == TYPE_INT or typeof(cost_data) == TYPE_FLOAT:
		return int(cost_data)
	return 0

## ダメージ値を取得
func _get_damage_value(spell: Dictionary) -> int:
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "damage":
			return effect.get("value", 0)
	
	return 0

## デフォルトターゲット取得
func _get_default_targets(spell: Dictionary, context: Dictionary) -> Array:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var target_info = effect_parsed.get("target_info", {})
	var owner_filter = target_info.get("owner_filter", "any")
	
	match target_type:
		"creature":
			return condition_checker.check_target_condition(owner_filter + "_creature", context)
		"player":
			if owner_filter == "enemy":
				return _get_enemy_players(context)
			else:
				return [{"type": "player", "player_id": context.player_id}]
		"land", "own_land":
			return _get_land_targets(owner_filter, context)
		_:
			return []

## 最適なターゲット選択（スコア付き）
func _select_best_target_with_score(targets: Array, _spell: Dictionary, context: Dictionary) -> Dictionary:
	if targets.is_empty():
		return {"target": {}, "score": 0.0}
	
	var player_id = context.get("player_id", 0)
	var damage_value = context.get("damage_value", 0)
	var is_damage_spell = damage_value > 0
	
	var best_target = targets[0]
	var best_score = -999.0
	
	for target in targets:
		var score = _calculate_target_score(target, player_id, damage_value, is_damage_spell)
		if score > best_score:
			best_score = score
			best_target = target
	
	return {"target": best_target, "score": best_score}

## ターゲットスコアを計算
func _calculate_target_score(target: Dictionary, player_id: int, damage_value: int, is_damage_spell: bool) -> float:
	var score = 0.0
	
	var tile_index = target.get("tile_index", -1)
	var creature = target.get("creature", {})
	var tile_data = {}
	
	# タイル情報を取得
	if tile_index >= 0 and board_system:
		tile_data = board_system.get_tile_data(tile_index)
		if tile_data and creature.is_empty():
			creature = tile_data.get("creature", tile_data.get("placed_creature", {}))
	
	if creature.is_empty():
		return score
	
	# 敵クリーチャーかどうか
	var owner_id = -1
	if tile_data:
		owner_id = tile_data.get("owner_id", -1)
	var is_enemy = owner_id != player_id and owner_id >= 0
	
	if is_enemy:
		score += 1.0
	
	# ダメージスペルの場合
	if is_damage_spell:
		var current_hp = creature.get("current_hp", creature.get("hp", 0))
		
		# 倒せる場合は最優先
		if current_hp > 0 and current_hp <= damage_value:
			score += 3.0
		# ダメージ効率（HPに対するダメージ割合）
		elif current_hp > 0:
			var damage_ratio = float(damage_value) / float(current_hp)
			score += min(damage_ratio, 1.0)  # 最大+1.0
	
	# 土地レベル
	if tile_data:
		var level = tile_data.get("level", 1)
		score += level * 0.5
	
	return score

## 旧互換（他の箇所で使用されている場合）
func _select_best_target(targets: Array, spell: Dictionary, context: Dictionary) -> Dictionary:
	var result = _select_best_target_with_score(targets, spell, context)
	return result.target

## 条件に基づくターゲット取得
func _get_condition_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var cpu_rule = spell.get("cpu_rule", {})
	var condition = cpu_rule.get("condition", "")
	
	match target_type:
		"self", "none":
			return {"type": "self", "player_id": context.player_id}
		"unvisited_gate":
			# リミッション用：進行方向から遠い未訪問ゲートを選ぶ
			var farthest_gate = _get_farthest_unvisited_gate(context)
			if not farthest_gate.is_empty():
				return farthest_gate
			return {}
		"own_land":
			# 属性変更スペルの場合、属性一致を改善できる土地を選ぶ
			if condition == "element_mismatch":
				var best_land = _get_best_element_shift_target(spell, context)
				if not best_land.is_empty():
					return best_land
				# 適切なターゲットがない場合は空を返す（使用しない）
				return {}
			# デフォルト: 最初の自領地
			var lands = _get_land_targets("own", context)
			if not lands.is_empty():
				return lands[0]
		"land":
			# 条件に応じたターゲット取得
			match condition:
				"enemy_high_level":
					# 敵の高レベル土地（レベル3以上で最もレベルが高いもの）
					var enemy_lands = _get_enemy_lands_by_level_sorted(context.player_id, 3)
					if not enemy_lands.is_empty():
						return {"type": "land", "tile_index": enemy_lands[0].get("index", -1)}
				"enemy_level_4":
					# 敵のレベル4土地
					var enemy_lands = _get_enemy_lands_by_level_sorted(context.player_id, 4)
					if not enemy_lands.is_empty():
						return {"type": "land", "tile_index": enemy_lands[0].get("index", -1)}
				_:
					# デフォルト: 敵の土地から選択
					var lands = _get_land_targets("enemy", context)
					if not lands.is_empty():
						return lands[0]
		"creature":
			# 移動侵略スペルの場合、勝てる自クリーチャーを選ぶ
			if condition == "move_invasion_win":
				var best_target = _get_best_move_invasion_target(context)
				if not best_target.is_empty():
					return best_target
				return {}
			# エクスチェンジの場合、属性不一致のクリーチャーを優先
			if condition == "can_upgrade_creature":
				var best_target = _get_best_exchange_target(context)
				if not best_target.is_empty():
					return best_target
			var targets = _get_default_targets(spell, context)
			if not targets.is_empty():
				return targets[0]
	
	return {}

## エクスチェンジ用：交換対象の自クリーチャーを選ぶ
## 属性不一致で、手札のクリーチャーで改善できるものを優先
func _get_best_exchange_target(context: Dictionary) -> Dictionary:
	var player_id = context.get("player_id", 0)
	
	if not board_system or not card_system:
		return {}
	
	# 手札のクリーチャーを取得
	var hand = card_system.get_all_cards_for_player(player_id)
	var hand_creatures = []
	for card in hand:
		if card.get("type") == "creature":
			hand_creatures.append(card)
	
	if hand_creatures.is_empty():
		return {}
	
	# 手札クリーチャーの属性セットを作成
	var hand_elements = {}
	for hc in hand_creatures:
		hand_elements[hc.get("element", "")] = true
	
	# 自クリーチャーを取得
	var tiles = board_system.get_all_tiles()
	var candidates = []
	
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id:
			continue
		
		var creature = tile.get("creature", {})
		if creature.is_empty():
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		var is_mismatched = tile_element != creature_element and tile_element != "neutral" and creature_element != "neutral"
		
		# 手札に該当タイルと一致する属性のクリーチャーがいるか
		var can_improve = hand_elements.has(tile_element)
		
		candidates.append({
			"type": "creature",
			"tile_index": tile.get("index", -1),
			"creature": creature,
			"is_mismatched": is_mismatched,
			"can_improve": can_improve
		})
	
	if candidates.is_empty():
		return {}
	
	# ソート：改善可能 & 属性不一致を優先
	candidates.sort_custom(func(a, b):
		# 改善可能かつ属性不一致が最優先
		var a_priority = 0
		var b_priority = 0
		if a.can_improve and a.is_mismatched:
			a_priority = 2
		elif a.is_mismatched:
			a_priority = 1
		if b.can_improve and b.is_mismatched:
			b_priority = 2
		elif b.is_mismatched:
			b_priority = 1
		return a_priority > b_priority
	)
	
	return candidates[0]

## 移動侵略スペル用：勝てる自クリーチャーをターゲットとして返す
## アウトレイジ、チャリオット等で使用
## contextにspell情報がある場合、スペルの移動距離を考慮
func _get_best_move_invasion_target(context: Dictionary) -> Dictionary:
	var player_id = context.get("player_id", 0)
	
	if not board_system or not condition_checker or not condition_checker._battle_simulator:
		return {}
	
	# スペル情報から移動距離を取得
	var spell = context.get("spell", {})
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	var steps = 1  # デフォルト: 隣接（アウトレイジ）
	var exact_steps = false
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		if effect_type == "move_steps":
			steps = effect.get("steps", 2)
			exact_steps = effect.get("exact_steps", false)
			break
		elif effect_type == "move_to_adjacent_enemy":
			steps = 1
			exact_steps = false
			break
	
	# 自クリーチャーを取得（盤面上）
	var own_creatures = condition_checker._get_own_creatures_on_board(player_id)
	if own_creatures.is_empty():
		return {}
	
	# 勝てる組み合わせを収集
	var winning_combos = []
	var battle_simulator = condition_checker._battle_simulator
	
	for own_tile in own_creatures:
		var attacker = own_tile.get("creature", {})
		if attacker.is_empty():
			continue
		
		var from_tile = own_tile.get("tile_index", -1)
		if from_tile < 0:
			continue
		
		# 移動可能な敵領地を取得
		var reachable_enemies = condition_checker._get_reachable_enemy_tiles(from_tile, player_id, steps, exact_steps)
		
		for enemy_tile in reachable_enemies:
			var defender = enemy_tile.get("creature", {})
			if defender.is_empty():
				continue
			
			# シミュレーション
			var sim_tile_info = {
				"element": enemy_tile.get("element", ""),
				"level": enemy_tile.get("level", 1),
				"owner": enemy_tile.get("owner", -1),
				"tile_index": enemy_tile.get("tile_index", -1)
			}
			
			var sim_result = battle_simulator.simulate_battle(
				attacker,
				defender,
				sim_tile_info,
				player_id,
				{},
				{}
			)
			
			var result = sim_result.get("result", -1)
			if result == condition_checker.BattleSimulatorScript.BattleResult.ATTACKER_WIN:
				# オーバーキル計算（低いほど効率的）
				var overkill = sim_result.get("attacker_ap", 0) - sim_result.get("defender_hp", 0)
				winning_combos.append({
					"own_tile_index": own_tile.get("tile_index", -1),
					"enemy_tile_index": enemy_tile.get("tile_index", -1),
					"attacker": attacker,
					"defender": defender,
					"enemy_level": enemy_tile.get("level", 1),
					"overkill": max(0, overkill)
				})
	
	if winning_combos.is_empty():
		return {}
	
	# 優先順位：敵土地レベルが高い > オーバーキルが低い
	winning_combos.sort_custom(func(a, b):
		if a.enemy_level != b.enemy_level:
			return a.enemy_level > b.enemy_level
		return a.overkill < b.overkill
	)
	
	var best = winning_combos[0]
	
	return {
		"type": "creature",
		"tile_index": best.own_tile_index,
		"creature": best.attacker,
		"enemy_tile_index": best.enemy_tile_index  # CPUが選んだ移動先
	}

## 指定レベル以上の敵土地をレベル降順でソートして取得
func _get_enemy_lands_by_level_sorted(player_id: int, min_level: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var level = tile.get("level", 1)
		if level >= min_level:
			results.append(tile)
	
	# レベル降順でソート（最もレベルが高いものを優先）
	results.sort_custom(func(a, b): return a.get("level", 1) > b.get("level", 1))
	
	return results

## 属性変更スペルの最適ターゲットを取得
## 変更先属性とクリーチャーの属性が一致し、現在土地属性が不一致の土地を選ぶ
func _get_best_element_shift_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	# 変更先属性を取得
	var target_element = ""
	for effect in effects:
		if effect.get("effect_type") == "change_element":
			target_element = effect.get("element", "")
			break
	
	if target_element.is_empty():
		return {}
	
	if not board_system:
		return {}
	
	var player_id = context.get("player_id", 0)
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		
		# クリーチャーの属性が変更先属性と一致し、土地属性が不一致の場合
		if creature_element == target_element and tile_element != target_element:
			return {"type": "land", "tile_index": tile.get("index", -1)}
	
	# 見つからなければ空を返す（使用しない方がいい）
	return {}

## 敵プレイヤー取得
func _get_enemy_players(context: Dictionary) -> Array:
	var player_id = context.player_id
	var results = []
	
	if not player_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			results.append({"type": "player", "player_id": i})
	
	return results

## 土地ターゲット取得
func _get_land_targets(owner_filter: String, context: Dictionary) -> Array:
	var player_id = context.player_id
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		
		match owner_filter:
			"own":
				if owner_id != player_id:
					continue
			"enemy":
				if owner_id == player_id or owner_id == -1:
					continue
			"any":
				pass
		
		results.append({"type": "land", "tile_index": tile.get("index", -1)})
	
	return results

## 利益計算
func _calculate_profit(formula: String, context: Dictionary) -> int:
	if formula.is_empty():
		return 0
	
	# 簡易的な計算
	match formula:
		"destroyed_count * 20":
			return context.get("destroyed_count", 0) * 20
		"destroyed_count * 30":
			return context.get("destroyed_count", 0) * 30
		"rank * 50":
			return context.get("rank", 1) * 50
		"lap_count * 50":
			return context.get("lap_count", 0) * 50
		"lap_diff * 100":
			return _calculate_lap_diff(context) * 100
		_:
			# enemy_magic * 0.3 などの計算
			if "enemy_magic" in formula:
				var enemy_magic = _get_max_enemy_magic(context)
				if "0.3" in formula:
					return int(enemy_magic * 0.3)
				if "0.1" in formula:
					return int(enemy_magic * 0.1)
			if "enemy_land_count" in formula:
				var count = _get_enemy_land_count(context)
				return count * 30
	
	return 0

## 周回差計算
func _calculate_lap_diff(context: Dictionary) -> int:
	if not player_system or not lap_system:
		return 0
	
	var player_id = context.player_id
	var my_lap = lap_system.get_lap_count(player_id)
	var max_enemy_lap = 0
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			var enemy_lap = lap_system.get_lap_count(i)
			max_enemy_lap = max(max_enemy_lap, enemy_lap)
	
	var diff = max_enemy_lap - my_lap
	print("[lap_diff] player_id=%d, my_lap=%d, max_enemy_lap=%d, diff=%d" % [player_id, my_lap, max_enemy_lap, diff])
	return diff

## 最大敵魔力取得
func _get_max_enemy_magic(context: Dictionary) -> int:
	if not player_system:
		return 0
	
	var player_id = context.player_id
	var max_magic = 0
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			var magic = player_system.get_magic(i)
			max_magic = max(max_magic, magic)
	
	return max_magic

## 敵土地数取得
func _get_enemy_land_count(context: Dictionary) -> int:
	if not board_system:
		return 0
	
	var player_id = context.player_id
	var count = 0
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id and owner_id != -1:
			count += 1
	
	return count

## profit_calc用ターゲット取得
func _get_profit_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	
	if target_type == "player":
		var enemies = _get_enemy_players(context)
		if not enemies.is_empty():
			return enemies[0]
	
	return {"type": "self", "player_id": context.player_id}

## strategic用ターゲット取得
func _get_strategic_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var target_filter = effect_parsed.get("target_filter", "any")
	
	match target_type:
		"player":
			if target_filter == "enemy":
				var enemies = _get_enemy_players(context)
				if not enemies.is_empty():
					return enemies[randi() % enemies.size()]
			elif target_filter == "self":
				return {"type": "self", "player_id": context.player_id}
			else:
				# any: ランダム
				if randf() < 0.5:
					return {"type": "self", "player_id": context.player_id}
				else:
					var enemies = _get_enemy_players(context)
					if not enemies.is_empty():
						return enemies[randi() % enemies.size()]
		"world", "none", "self":
			return {"type": "self", "player_id": context.player_id}
	
	return {"type": "self", "player_id": context.player_id}

## プレイヤー順位取得
func _get_player_rank(player_id: int) -> int:
	if not player_system:
		return 1
	
	var my_total = player_system.calculate_total_assets(player_id)
	var rank = 1
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			var other_total = player_system.calculate_total_assets(i)
			if other_total > my_total:
				rank += 1
	
	return rank
