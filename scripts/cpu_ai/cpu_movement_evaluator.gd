# cpu_movement_evaluator.gd
# CPU移動判断システム
# - 経路シミュレーション（足止め・分岐考慮）
# - 進行方向の決定
# - 分岐タイルでの選択
# - ホーリーワード（固定ダイス）スペルの使用判断

extends RefCounted
class_name CPUMovementEvaluator

# =============================================================================
# スコア定数
# =============================================================================

# 停止位置スコア
const SCORE_STOP_ENEMY_CANT_WIN_MULTIPLIER = -1    # 敵領地（倒せない）: -通行料 × 1
const SCORE_STOP_ENEMY_CAN_WIN_MULTIPLIER = 2      # 敵領地（倒せる）: +通行料 × 2
const SCORE_STOP_EMPTY_ELEMENT_MATCH = 300         # 空き地（属性一致・召喚可能）
const SCORE_STOP_EMPTY_ELEMENT_MISMATCH = 100      # 空き地（属性不一致・召喚可能）
const SCORE_STOP_EMPTY_NO_SUMMON = 0               # 空き地（召喚不可）
const SCORE_STOP_OWN_LAND = 0                      # 自分の領地
const SCORE_STOP_SPECIAL_TILE = 50                 # 特殊タイル（城、魔法石等）
const SCORE_STOP_CHECKPOINT_LAP = 1500             # チェックポイント停止で1周達成
const SCORE_PATH_CHECKPOINT_PASS = 1500           # 経路上でチェックポイント通過（シグナル取得）

# 経路スコア
const SCORE_PATH_DIVISOR = 10                      # 経路スコアの除数（1/10にする）

# 方向ボーナス
const SCORE_DIRECTION_UNVISITED_GATE = 1200        # 未訪問ゲート方向ボーナス

# 足止めペナルティ
const SCORE_FORCED_STOP_PENALTY = -500             # 足止めペナルティ基礎値（倒せない場合のみ）

# 経路評価の最大距離
const PATH_EVALUATION_DISTANCE = 10

# =============================================================================
# システム参照
# =============================================================================

var board_system = null
var player_system: PlayerSystem = null
var lap_system = null
var movement_controller = null
var card_system = null
var battle_simulator = null
var spell_movement: SpellMovement = null

## システム参照を設定
func setup_systems(p_board_system, p_player_system: PlayerSystem, p_lap_system = null, 
		p_movement_controller = null, p_card_system = null, p_battle_simulator = null,
		p_spell_movement: SpellMovement = null):
	board_system = p_board_system
	player_system = p_player_system
	lap_system = p_lap_system
	movement_controller = p_movement_controller
	card_system = p_card_system
	battle_simulator = p_battle_simulator
	spell_movement = p_spell_movement

# =============================================================================
# メイン機能: 経路評価
# =============================================================================

## 経路を評価（総合スコアを計算）
## start_tile: 開始タイル
## total_steps: 総移動歩数（サイコロの目）
## player_id: CPUプレイヤーID
## came_from: 来た方向のタイル（-1なら現在のcame_fromを使用）
## 返り値: { score: int, stop_tile: int, path: Array, details: Dictionary }
func evaluate_path(start_tile: int, total_steps: int, player_id: int, came_from: int = -1) -> Dictionary:
	# 経路をシミュレート
	var sim_result = simulate_path(start_tile, total_steps, player_id, came_from)
	
	var stop_tile = sim_result.stop_tile
	var path = sim_result.path
	var forced_stop = sim_result.forced_stop
	var forced_stop_at = sim_result.forced_stop_at
	
	# 手札情報を取得
	var summonable_elements = _get_summonable_elements(player_id)
	
	# 停止位置スコアを計算
	var stop_score = _evaluate_stop_tile(stop_tile, player_id, summonable_elements, forced_stop)
	
	# 経路スコアを計算（チェックポイント通過ボーナスを分離）
	var path_result = _evaluate_path_score_with_checkpoint(path, player_id, summonable_elements)
	var path_score = path_result.path_score
	var checkpoint_bonus = path_result.checkpoint_bonus
	
	# 方向ボーナスを計算（came_fromを渡して正しい方向を判定）
	var actual_came_from = came_from if came_from >= 0 else _get_player_came_from(player_id)
	var direction_bonus = _calculate_direction_bonus(start_tile, player_id, actual_came_from)
	
	# 総合スコア = 停止位置スコア + (経路スコア / 10) + チェックポイント通過ボーナス + 方向ボーナス
	var total_score = stop_score + (path_score / SCORE_PATH_DIVISOR) + checkpoint_bonus + direction_bonus
	
	print("[CPU経路評価] 開始:%d 歩数:%d 停止:%d スコア:%d (停止:%d 経路:%d/10 CP通過:%d 方向:%d)" % [
		start_tile, total_steps, stop_tile, total_score, stop_score, path_score, checkpoint_bonus, direction_bonus
	])
	
	return {
		"score": total_score,
		"stop_tile": stop_tile,
		"path": path,
		"details": {
			"stop_score": stop_score,
			"path_score": path_score,
			"checkpoint_bonus": checkpoint_bonus,
			"direction_bonus": direction_bonus,
			"forced_stop": forced_stop,
			"forced_stop_at": forced_stop_at
		}
	}

# =============================================================================
# 経路シミュレーション
# =============================================================================

## 経路をシミュレート（足止め・分岐考慮）
## 返り値: { path: Array, stop_tile: int, forced_stop: bool, forced_stop_at: int }
func simulate_path(start_tile: int, steps: int, player_id: int, came_from: int = -1) -> Dictionary:
	var result = {
		"path": [],
		"stop_tile": start_tile,
		"forced_stop": false,
		"forced_stop_at": -1
	}
	
	if steps <= 0:
		return result
	
	if came_from < 0:
		came_from = _get_player_came_from(player_id)
	
	var current_tile = start_tile
	var prev_tile = came_from
	var remaining_steps = steps
	
	# 進行方向を計算（came_fromとstart_tileの差から推測）
	# 周回マップ対応：隣接タイルへの移動方向を判定
	var direction = 1  # デフォルトは正方向
	if came_from >= 0:
		var diff = start_tile - came_from
		# 通常は差の符号で方向を決定
		# ただし周回マップで端をまたぐ場合（例: 0→33 or 33→0）は逆
		if abs(diff) > 1:
			# 端をまたいでいる（例: 0と33の差は33）
			direction = -1 if diff > 0 else 1
		else:
			direction = 1 if diff > 0 else -1
	
	while remaining_steps > 0:
		# 進行方向を現在位置と前の位置から再計算
		if prev_tile >= 0:
			var diff = current_tile - prev_tile
			if abs(diff) > 1:
				# 端をまたいでいる
				direction = -1 if diff > 0 else 1
			else:
				direction = 1 if diff > 0 else -1
		
		# 次のタイルを取得
		var next_tile = _get_next_tile_simulated(current_tile, prev_tile, player_id, remaining_steps, direction)
		
		if next_tile < 0 or next_tile == current_tile:
			break
		
		# 経路に追加
		result.path.append(next_tile)
		
		# 足止め判定（自分の領地以外）
		var tile_info = _get_tile_info(next_tile)
		var tile_owner = tile_info.get("owner", -1)
		
		if tile_owner != player_id:
			var forced_stop_result = _check_forced_stop(next_tile, player_id)
			if forced_stop_result.stopped:
				result.stop_tile = next_tile
				result.forced_stop = true
				result.forced_stop_at = next_tile
				return result
		
		# 次へ進む
		prev_tile = current_tile
		current_tile = next_tile
		remaining_steps -= 1
	
	result.stop_tile = current_tile
	return result

## 次のタイルを取得（シミュレーション用、分岐は最良選択肢を仮定）
## direction: 進行方向（connectionsがない場合に使用）
func _get_next_tile_simulated(current_tile: int, came_from: int, player_id: int, remaining_steps: int, direction: int = 0) -> int:
	if not movement_controller or not movement_controller.tile_nodes:
		return current_tile + (direction if direction != 0 else 1)
	
	var tile_nodes = movement_controller.tile_nodes
	if not tile_nodes.has(current_tile):
		return current_tile + (direction if direction != 0 else 1)
	
	var tile = tile_nodes[current_tile]
	
	# connectionsがなければ単純にindex+direction（実際の移動処理と同じ）
	if not tile.connections or tile.connections.is_empty():
		return current_tile + direction
	
	# BranchTileの場合
	if tile is BranchTile:
		var result = tile.get_next_tile_for_direction(came_from)
		if result.tile >= 0:
			return result.tile
		elif not result.choices.is_empty():
			# 複数選択肢がある場合、最良の選択肢を選ぶ
			return _select_best_branch_choice(result.choices, player_id, remaining_steps - 1, current_tile)
	
	# 通常タイル（connectionsあり）
	var choices = []
	for conn in tile.connections:
		if conn != came_from:
			choices.append(conn)
	
	if choices.is_empty():
		return came_from if came_from >= 0 else current_tile + direction
	if choices.size() == 1:
		return choices[0]
	
	# 複数選択肢がある場合、最良の選択肢を選ぶ
	return _select_best_branch_choice(choices, player_id, remaining_steps - 1, current_tile)

## 分岐で最良の選択肢を選ぶ（再帰的に評価）
func _select_best_branch_choice(choices: Array, player_id: int, remaining_steps: int, came_from: int) -> int:
	if choices.is_empty():
		return -1
	
	if choices.size() == 1:
		return choices[0]
	
	var best_choice = choices[0]
	var best_score = -999999
	
	for choice in choices:
		# 残り歩数で停止する位置を評価
		var eval_result = evaluate_path(choice, remaining_steps, player_id, came_from)
		var score = eval_result.score
		
		if score > best_score:
			best_score = score
			best_choice = choice
	
	return best_choice

# =============================================================================
# 停止位置評価
# =============================================================================

## 停止位置のスコアを計算
func _evaluate_stop_tile(tile_index: int, player_id: int, summonable_elements: Array, is_forced_stop: bool) -> int:
	var tile_info = _get_tile_info(tile_index)
	var owner_id = tile_info.get("owner", -1)
	var tile_element = tile_info.get("element", "")
	var is_special = tile_info.get("is_special", false)
	
	# 特殊タイル
	if is_special:
		# チェックポイント/ゲートの場合、停止で1周達成できるかチェック
		var tile_type = tile_info.get("tile_type", "")
		if tile_type in ["checkpoint", "gate"]:
			if _is_gate_unvisited(tile_info, player_id):
				# 未訪問のゲートに停止 = 1周達成
				return SCORE_STOP_CHECKPOINT_LAP
		return SCORE_STOP_SPECIAL_TILE
	
	# 自分の領地
	if owner_id == player_id:
		return SCORE_STOP_OWN_LAND
	
	# 敵の領地
	if owner_id >= 0 and owner_id != player_id:
		var toll = _calculate_toll(tile_index)
		var can_win = _can_invade_and_win(tile_index, player_id)
		
		if can_win:
			# 倒せる → 侵略ボーナス
			return toll * SCORE_STOP_ENEMY_CAN_WIN_MULTIPLIER
		else:
			# 倒せない → 通行料ペナルティ
			var score = toll * SCORE_STOP_ENEMY_CANT_WIN_MULTIPLIER
			# 足止めの場合は追加ペナルティ
			if is_forced_stop:
				score += SCORE_FORCED_STOP_PENALTY
			return score
	
	# 空き地
	if owner_id == -1:
		# 召喚可能かチェック
		if tile_element in summonable_elements:
			return SCORE_STOP_EMPTY_ELEMENT_MATCH
		elif not summonable_elements.is_empty():
			# 属性不一致だが召喚可能なクリーチャーはある
			return SCORE_STOP_EMPTY_ELEMENT_MISMATCH
		else:
			return SCORE_STOP_EMPTY_NO_SUMMON
	
	return 0

# =============================================================================
# 経路スコア評価
# =============================================================================

## 経路全体のスコアを計算（10マス先まで）
## 経路スコアとチェックポイント通過ボーナスを計算
## 戻り値: { path_score: int, checkpoint_bonus: int }
func _evaluate_path_score_with_checkpoint(path: Array, player_id: int, summonable_elements: Array) -> Dictionary:
	var score = 0
	var checkpoint_bonus = 0
	
	for tile_index in path:
		var tile_info = _get_tile_info(tile_index)
		var owner_id = tile_info.get("owner", -1)
		var tile_element = tile_info.get("element", "")
		var tile_type = tile_info.get("tile_type", "")
		
		# チェックポイント通過でシグナル取得できる場合、大きなボーナス（除算されない）
		if tile_type in ["gate", "checkpoint"]:
			if _is_gate_unvisited(tile_info, player_id):
				checkpoint_bonus += SCORE_PATH_CHECKPOINT_PASS
				print("[CPU経路スコア] チェックポイント通過ボーナス: tile=%d, +%d" % [tile_index, SCORE_PATH_CHECKPOINT_PASS])
		
		# 自分の領地はスキップ
		if owner_id == player_id:
			continue
		
		# 敵の領地
		if owner_id >= 0:
			var toll = _calculate_toll(tile_index)
			score -= toll
		# 空き地
		elif owner_id == -1:
			if tile_element in summonable_elements:
				score += SCORE_STOP_EMPTY_ELEMENT_MATCH
			elif not summonable_elements.is_empty():
				score += SCORE_STOP_EMPTY_ELEMENT_MISMATCH
	
	return { "path_score": score, "checkpoint_bonus": checkpoint_bonus }

## 方向ボーナスを計算
## came_from: 来た方向（分岐元）- 反対方向との比較に使用
func _calculate_direction_bonus(start_tile: int, player_id: int, came_from: int) -> int:
	# この方向の未訪問ゲートまでの距離を取得
	var this_distance = _get_distance_to_unvisited_gate(start_tile, player_id, came_from)
	
	print("[CPU方向ボーナス] start=%d, came_from=%d, this_distance=%d" % [start_tile, came_from, this_distance])
	
	# ゲートが見つからなければボーナスなし
	if this_distance < 0:
		print("[CPU方向ボーナス] → ゲート見つからず、ボーナス0")
		return 0
	
	# 未訪問ゲートがこの方向にあれば、距離に応じたボーナスを付与
	# 距離が近いほど高いボーナス（最大1200、距離10以上で0に近づく）
	var distance_bonus = max(0, SCORE_DIRECTION_UNVISITED_GATE - (this_distance * 100))
	print("[CPU方向ボーナス] → 距離%dでボーナス%d" % [this_distance, distance_bonus])
	return distance_bonus

# =============================================================================
# 進行方向決定
# =============================================================================

## CPUの進行方向を決定（+1/-1の選択）
## available_directions: 選択可能な方向 [1, -1] など
## 返り値: 選択した方向
func decide_direction(player_id: int, available_directions: Array) -> int:
	if available_directions.is_empty():
		return 1
	
	if available_directions.size() == 1:
		return available_directions[0]
	
	var current_tile = _get_player_current_tile(player_id)
	var came_from = _get_player_came_from(player_id)
	var best_direction = available_directions[0]
	var best_score = -999999
	
	for direction in available_directions:
		# 10マス先までの平均スコアを計算
		var total_score = 0
		for dice in range(1, 7):  # 1〜6
			var start_tile = current_tile + direction
			var eval_result = evaluate_path(start_tile, dice, player_id, current_tile)
			total_score += eval_result.score
		
		var avg_score = total_score / 6.0
		print("[CPU方向評価] 方向 %d: 平均スコア %.1f" % [direction, avg_score])
		
		if avg_score > best_score:
			best_score = avg_score
			best_direction = direction
	
	print("[CPU方向選択] 選択した方向: %d (スコア: %.1f)" % [best_direction, best_score])
	return best_direction

# =============================================================================
# 分岐タイルでの選択
# =============================================================================

## 分岐タイルでの選択（残り歩数を考慮）
## available_tiles: 選択可能なタイルインデックス配列
## remaining_steps: 残り歩数
## 返り値: 選択したタイルインデックス
func decide_branch_choice(player_id: int, available_tiles: Array, remaining_steps: int) -> int:
	if available_tiles.is_empty():
		return -1
	
	if available_tiles.size() == 1:
		return available_tiles[0]
	
	var current_tile = _get_player_current_tile(player_id)
	var best_tile = available_tiles[0]
	var best_score = -999999
	
	print("[CPU分岐選択開始] player=%d, current_tile=%d, available=%s, remaining_steps=%d" % [
		player_id, current_tile, available_tiles, remaining_steps
	])
	
	for tile_index in available_tiles:
		# 残り歩数での停止位置を評価
		# tile_indexが次の1歩目なので、remaining_steps - 1 で評価
		var eval_result = evaluate_path(tile_index, remaining_steps - 1, player_id, current_tile)
		var score = eval_result.score
		
		print("[CPU分岐評価] タイル%d → 停止%d: スコア%d" % [tile_index, eval_result.stop_tile, score])
		
		if score > best_score:
			best_score = score
			best_tile = tile_index
	
	print("[CPU分岐選択] 選択したタイル: %d (スコア: %d)" % [best_tile, best_score])
	return best_tile

# =============================================================================
# ホーリーワード判断
# =============================================================================

## ホーリーワード系スペルの使用判断
## spell: ホーリーワードスペル
## context: { player_id, ... }
## 返り値: { "should_use": bool, "target": Dictionary, "reason": String }
func evaluate_holy_word(spell: Dictionary, context: Dictionary) -> Dictionary:
	var player_id = context.get("player_id", 0)
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	# ダイス固定値を取得
	var dice_value = 0
	for effect in effects:
		if effect.get("effect_type") == "dice_fixed":
			dice_value = effect.get("value", 0)
			break
	
	if dice_value == 0:
		return { "should_use": false }
	
	var spell_cost = spell.get("cost", {}).get("mp", 0)
	
	# 攻撃的使用を評価
	var offensive_result = _evaluate_holy_word_offensive(dice_value, player_id, spell_cost)
	
	# 防御的使用を評価
	var defensive_result = _evaluate_holy_word_defensive(dice_value, player_id, spell_cost)
	
	# 攻撃と防御を比較
	if offensive_result.should_use and offensive_result.expected_toll >= spell_cost:
		return {
			"should_use": true,
			"target": { "type": "player", "player_id": offensive_result.target_player_id },
			"reason": "攻撃: 敵を自分の土地に止まらせる（通行料: %dG）" % offensive_result.expected_toll
		}
	
	if defensive_result.should_use and defensive_result.avoided_toll >= spell_cost:
		return {
			"should_use": true,
			"target": { "type": "player", "player_id": player_id },
			"reason": "防御: 敵の土地を回避（回避通行料: %dG）" % defensive_result.avoided_toll
		}
	
	return { "should_use": false }

## 攻撃的使用を評価
func _evaluate_holy_word_offensive(dice_value: int, player_id: int, spell_cost: int) -> Dictionary:
	var result = {
		"should_use": false,
		"target_player_id": -1,
		"expected_toll": 0
	}
	
	if not player_system:
		return result
	
	var best_toll = 0
	var best_target = -1
	
	for enemy_id in range(player_system.players.size()):
		if enemy_id == player_id:
			continue
		
		var enemy_tile = _get_player_current_tile(enemy_id)
		var enemy_direction = _get_player_direction(enemy_id)
		
		# 敵がdice_value歩進んだ先を計算
		var sim_result = simulate_path(enemy_tile, dice_value * enemy_direction, enemy_id)
		var stop_tile = sim_result.stop_tile
		
		var tile_info = _get_tile_info(stop_tile)
		var owner = tile_info.get("owner", -1)
		
		# 自分の土地かチェック
		if owner == player_id:
			var toll = _calculate_toll(stop_tile)
			
			# 侵略リスクをチェック
			if not _can_enemy_invade(stop_tile, enemy_id):
				if toll > best_toll:
					best_toll = toll
					best_target = enemy_id
	
	if best_target >= 0 and best_toll > spell_cost:
		result.should_use = true
		result.target_player_id = best_target
		result.expected_toll = best_toll
	
	return result

## 防御的使用を評価
func _evaluate_holy_word_defensive(dice_value: int, player_id: int, spell_cost: int) -> Dictionary:
	var result = {
		"should_use": false,
		"avoided_toll": 0
	}
	
	var current_tile = _get_player_current_tile(player_id)
	var my_direction = _get_player_direction(player_id)
	
	# dice_valueで止まる位置を計算
	var target_sim = simulate_path(current_tile, dice_value * my_direction, player_id)
	var target_tile = target_sim.stop_tile
	var target_info = _get_tile_info(target_tile)
	var target_owner = target_info.get("owner", -1)
	
	# このダイス目で敵の土地に止まるか？
	if target_owner >= 0 and target_owner != player_id:
		if not _can_invade_and_win(target_tile, player_id):
			# 倒せない敵の土地 → このダイス目は使いたくない
			return result
	
	# 他のダイス目で危険な場所があるか確認
	var max_danger_toll = 0
	for check_dice in [1, 2, 3, 4, 5, 6, 8]:
		if check_dice == dice_value:
			continue
		
		var check_sim = simulate_path(current_tile, check_dice * my_direction, player_id)
		var check_tile = check_sim.stop_tile
		var check_info = _get_tile_info(check_tile)
		var check_owner = check_info.get("owner", -1)
		
		if check_owner >= 0 and check_owner != player_id:
			if not _can_invade_and_win(check_tile, player_id):
				var toll = _calculate_toll(check_tile)
				if toll > max_danger_toll:
					max_danger_toll = toll
	
	if max_danger_toll > spell_cost:
		result.should_use = true
		result.avoided_toll = max_danger_toll
	
	return result

# =============================================================================
# ヘルパー関数
# =============================================================================

## タイル情報を取得
func _get_tile_info(tile_index: int) -> Dictionary:
	if board_system and board_system.has_method("get_tile_info"):
		var info = board_system.get_tile_info(tile_index)
		if not info.is_empty():
			info["tile_index"] = tile_index
			# tile_typeがない場合、タイルノードから取得
			if not info.has("tile_type") and movement_controller:
				var tile_node = movement_controller.tile_nodes.get(tile_index)
				if tile_node:
					info["tile_type"] = tile_node.tile_type
			return info
	return {}

## 通行料を計算
func _calculate_toll(tile_index: int) -> int:
	if board_system and board_system.has_method("calculate_toll"):
		return board_system.calculate_toll(tile_index)
	return 0

## 足止め判定
func _check_forced_stop(tile_index: int, player_id: int) -> Dictionary:
	if spell_movement and movement_controller:
		return spell_movement.check_forced_stop_with_tiles(tile_index, player_id, movement_controller.tile_nodes)
	return {"stopped": false}

## 侵略して勝てるか判定
func _can_invade_and_win(tile_index: int, attacker_id: int) -> bool:
	if not battle_simulator or not card_system:
		return false
	
	var tile_info = _get_tile_info(tile_index)
	var defender = tile_info.get("creature", {})
	if defender.is_empty():
		return true  # クリーチャーがいなければ勝ち
	
	# 攻撃側の手札からクリーチャーを取得
	var hand = card_system.get_all_cards_for_player(attacker_id)
	
	for card in hand:
		if card.get("type") != "creature":
			continue
		if card.get("hidden", false):
			continue
		
		var sim_result = battle_simulator.simulate_battle(
			card, defender, tile_info, attacker_id, {}, {}
		)
		
		if sim_result.get("result", -1) == 0:  # ATTACKER_WIN
			return true
	
	return false

## 敵が侵略して勝てるか判定
func _can_enemy_invade(tile_index: int, enemy_id: int) -> bool:
	return _can_invade_and_win(tile_index, enemy_id)

## 召喚可能なクリーチャーの属性リストを取得
func _get_summonable_elements(player_id: int) -> Array:
	var elements = []
	if not card_system:
		return elements
	
	var hand = card_system.get_all_cards_for_player(player_id)
	for card in hand:
		if card.get("type") == "creature":
			var element = card.get("element", "")
			if element != "" and element not in elements:
				elements.append(element)
	
	return elements

## プレイヤーの現在タイルを取得
func _get_player_current_tile(player_id: int) -> int:
	if movement_controller and player_id >= 0 and player_id < movement_controller.player_tiles.size():
		return movement_controller.player_tiles[player_id]
	return 0

## プレイヤーのcame_fromを取得
func _get_player_came_from(player_id: int) -> int:
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		return player_system.players[player_id].came_from
	return -1

## プレイヤーの進行方向を取得
func _get_player_direction(player_id: int) -> int:
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		return player_system.players[player_id].current_direction
	return 1

## 未訪問ゲートまでの距離を取得（見つからなければ-1）
func _get_distance_to_unvisited_gate(start_tile: int, player_id: int, came_from: int = -1) -> int:
	if not lap_system:
		return -1
	
	# ワープフラグをリセット（新しい探索開始）
	_warp_used_in_search = false
	
	var current = start_tile
	var prev = came_from if came_from >= 0 else _get_player_came_from(player_id)
	
	# 進行方向を計算
	var direction = 1
	if prev >= 0:
		var diff = current - prev
		if abs(diff) > 1:
			direction = -1 if diff > 0 else 1
		else:
			direction = 1 if diff > 0 else -1
	
	var distance = 0
	print("[CPU方向探索] 開始: start=%d, came_from=%d, direction=%d" % [start_tile, came_from, direction])
	for i in range(PATH_EVALUATION_DISTANCE * 2):  # ワープ考慮で余裕を持たせる
		var tile_info = _get_tile_info(current)
		var tile_type = tile_info.get("tile_type", "")
		print("[CPU方向探索] i=%d current=%d tile_type=%s" % [i, current, tile_type])
		
		if tile_type in ["gate", "checkpoint"]:
			if _is_gate_unvisited(tile_info, player_id):
				print("[CPU方向探索] ★ゲート発見! tile=%d, distance=%d" % [current, distance])
				return distance  # 距離を返す
		
		# ワープタイルの場合、距離を増やさずにジャンプ
		var is_warp = tile_type in ["warp", "warp_stop"]
		
		# 次のタイルへ
		var next = _get_next_tile_simple_with_direction(current, prev, direction)
		print("[CPU方向探索]   → next=%d (prev=%d)" % [next, prev])
		if next < 0 or next == current:
			print("[CPU方向探索]   ループ終了: next=%d, current=%d" % [next, current])
			break
		
		# ワープでない場合のみ距離をカウント
		if not is_warp:
			distance += 1
		
		# 方向を更新（ワープの場合はリセット）
		if is_warp:
			# ワープ後は新しい位置から方向を再計算する必要があるため、
			# ワープ先の次のタイルを見て判断
			prev = -1  # came_fromをリセット
		else:
			var diff = next - current
			if abs(diff) > 1:
				direction = -1 if diff > 0 else 1
			else:
				direction = 1 if diff > 0 else -1
			prev = current
		
		current = next
	
	return -1  # 見つからなかった

## 反対方向の未訪問ゲートまでの距離を取得
func _get_other_direction_gate_distance(branch_tile: int, this_direction_tile: int, player_id: int) -> int:
	if not movement_controller or not movement_controller.tile_nodes:
		return -1
	
	var tile_nodes = movement_controller.tile_nodes
	if not tile_nodes.has(branch_tile):
		return -1
	
	var tile = tile_nodes[branch_tile]
	
	# 分岐タイルの接続先から、this_direction_tile以外の方向を探す
	if tile.connections and not tile.connections.is_empty():
		for conn in tile.connections:
			if conn != this_direction_tile:
				# この方向の距離を計算
				return _get_distance_to_unvisited_gate(conn, player_id, branch_tile)
	
	# connectionsがない場合、反対方向を推測
	var diff = this_direction_tile - branch_tile
	var other_direction_tile: int
	if abs(diff) > 1:
		# 端をまたいでいる
		other_direction_tile = branch_tile + (1 if diff > 0 else -1)
	else:
		other_direction_tile = branch_tile - diff
	
	return _get_distance_to_unvisited_gate(other_direction_tile, player_id, branch_tile)

## ゲートが未訪問か判定
func _is_gate_unvisited(tile_info: Dictionary, player_id: int) -> bool:
	if not lap_system:
		return false
	
	var checkpoint_type = tile_info.get("checkpoint_type", "")
	if checkpoint_type == "":
		var gate_number = tile_info.get("gate_number", tile_info.get("checkpoint_number", 0))
		checkpoint_type = "N" if gate_number == 0 else "S"
	
	var player_state = lap_system.player_lap_state.get(player_id, {})
	return not player_state.get(checkpoint_type, false)

## 次のタイルを取得（簡易版、方向対応）
## ワープ済みフラグ（ループ探索中に一度だけワープする）
var _warp_used_in_search: bool = false

func _get_next_tile_simple_with_direction(current_tile: int, came_from: int, direction: int) -> int:
	if not movement_controller or not movement_controller.tile_nodes:
		return current_tile + direction
	
	var tile_nodes = movement_controller.tile_nodes
	if not tile_nodes.has(current_tile):
		return current_tile + direction
	
	var tile = tile_nodes[current_tile]
	
	# ワープタイルの場合、ワープ先を返す（まだワープしていない場合のみ）
	if tile.tile_type in ["warp", "warp_stop"] and not _warp_used_in_search:
		var warp_dest = _get_warp_destination(current_tile)
		if warp_dest >= 0:
			_warp_used_in_search = true  # ワープ済みにする
			return warp_dest
	
	if tile.connections and not tile.connections.is_empty():
		for conn in tile.connections:
			if conn != came_from:
				return conn
		return came_from
	
	return current_tile + direction


## ワープ先タイルを取得
func _get_warp_destination(tile_index: int) -> int:
	if board_system and board_system.special_tile_system:
		return board_system.special_tile_system.get_warp_pair(tile_index)
	return -1
