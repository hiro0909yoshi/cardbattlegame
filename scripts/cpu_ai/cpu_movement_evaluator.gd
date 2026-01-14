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
const SCORE_STOP_EMPTY_ELEMENT_MATCH = 50          # 空き地（属性一致・召喚可能）
const SCORE_STOP_EMPTY_ELEMENT_MISMATCH = 20       # 空き地（属性不一致・召喚可能）
const SCORE_STOP_EMPTY_NO_SUMMON = 0               # 空き地（召喚不可）
const SCORE_STOP_OWN_LAND = 0                      # 自分の領地
const SCORE_STOP_SPECIAL_TILE = 50                 # 特殊タイル（城、魔法石等）
const SCORE_STOP_CHECKPOINT_LAP = 1500             # チェックポイント停止で1周達成（未使用）
const SCORE_PATH_CHECKPOINT_PASS = 0              # 経路上でチェックポイント通過（削除）

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

# チェックポイント距離計算システム
var checkpoint_calculator: CheckpointDistanceCalculator = null

# 現在の分岐タイル（方向ボーナス計算時にCPを除外するため）
var _current_branch_tile: int = -1



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


## チェックポイント距離が計算済みか
var _checkpoint_distances_calculated: bool = false

## チェックポイント距離が未計算なら計算（遅延初期化）
func _ensure_checkpoint_distances_calculated():
	if _checkpoint_distances_calculated:
		return
	calculate_checkpoint_distances()

## チェックポイント距離を計算（マップロード後に呼び出し）
func calculate_checkpoint_distances():
	if not movement_controller or not movement_controller.tile_nodes:
		return
	
	# ワープペアを取得
	var warp_pairs = {}
	if board_system and board_system.special_tile_system:
		warp_pairs = board_system.special_tile_system.warp_pairs
	
	# 計算機を初期化
	checkpoint_calculator = CheckpointDistanceCalculator.new()
	checkpoint_calculator.setup(movement_controller.tile_nodes, warp_pairs)
	checkpoint_calculator.calculate_all_distances()
	
	_checkpoint_distances_calculated = true

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
	
	# 総合スコア = 停止位置スコア + チェックポイント通過ボーナス
	var total_score = stop_score + checkpoint_bonus
	
	return {
		"score": total_score,
		"stop_tile": stop_tile,
		"path": path,
		"details": {
			"stop_score": stop_score,
			"path_score": path_score,
			"checkpoint_bonus": checkpoint_bonus,
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
		
		# ワープ処理（歩数を消費せずにワープ先に移動）
		var tile_type = tile_info.get("tile_type", "")
		if tile_type in ["warp", "warp_stop"]:
			var warp_dest = _get_warp_destination(next_tile)
			if warp_dest >= 0:
				# ワープ先を経路に追加（歩数消費なし）
				result.path.append(warp_dest)
				prev_tile = next_tile
				current_tile = warp_dest
				# remaining_stepsは減らさない（ワープは0歩）
				continue
		
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
		# チェックポイント/ゲートの場合
		# 停止ボーナスは付けない（通過でも取得できるため、方向ボーナスで評価）
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
	var checkpoint_already_counted = false  # 最初のCP通過のみカウント
	
	for tile_index in path:
		var tile_info = _get_tile_info(tile_index)
		var owner_id = tile_info.get("owner", -1)
		var tile_element = tile_info.get("element", "")
		var tile_type = tile_info.get("tile_type", "")
		
		# チェックポイント通過でシグナル取得できる場合、大きなボーナス（除算されない）
		# ただし、最初の1つのみ（ぐるぐる回り防止）
		if tile_type in ["gate", "checkpoint"]:
			if _is_gate_unvisited(tile_info, player_id) and not checkpoint_already_counted:
				checkpoint_bonus += SCORE_PATH_CHECKPOINT_PASS
				checkpoint_already_counted = true
		
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

## 方向ボーナスを計算（事前計算テーブルを使用）
## start_tile: 評価する経路の開始タイル（分岐から1歩進んだ位置）
func _calculate_direction_bonus(start_tile: int, player_id: int, _came_from: int) -> int:
	# チェックポイント距離が未計算なら計算（遅延初期化）
	_ensure_checkpoint_distances_calculated()
	
	# 事前計算システムがなければ旧ロジックにフォールバック
	if not checkpoint_calculator:
		return _calculate_direction_bonus_legacy(start_tile, player_id)
	
	# プレイヤーの訪問済みチェックポイントを取得
	var visited = _get_visited_checkpoints(player_id)
	
	# 今いる分岐タイルがCPなら、そのCPも除外（移動途中で通過したCPを目指さない）
	if _current_branch_tile >= 0:
		var branch_tile_cp = _get_checkpoint_id_at_tile(_current_branch_tile)
		if branch_tile_cp != "" and branch_tile_cp not in visited:
			if typeof(visited) != TYPE_ARRAY or visited.is_read_only():
				visited = visited.duplicate()
			visited.append(branch_tile_cp)
	
	# 方向別距離を使用（分岐タイルからの方向を考慮）
	var result: Dictionary
	if _current_branch_tile >= 0 and checkpoint_calculator.is_branch_tile(_current_branch_tile):
		result = checkpoint_calculator.get_directional_nearest_checkpoint(_current_branch_tile, start_tile, visited)
	else:
		result = checkpoint_calculator.get_nearest_unvisited_checkpoint(start_tile, visited)
	
	var distance = result.distance
	var cp_id = result.checkpoint_id
	
	if cp_id == "" or distance >= 9999:
		return 0
	
	# 距離に応じたボーナス（近いほど高い）
	var distance_bonus = max(0, SCORE_DIRECTION_UNVISITED_GATE - (distance * 60))
	return distance_bonus


## 旧ロジック（フォールバック用）
func _calculate_direction_bonus_legacy(start_tile: int, player_id: int) -> int:
	var came_from = _get_player_came_from(player_id)
	var this_distance = _get_distance_to_unvisited_gate(start_tile, player_id, came_from)
	
	if this_distance < 0:
		return 0
	
	return max(0, SCORE_DIRECTION_UNVISITED_GATE - (this_distance * 100))


## 分岐選択用の方向ボーナス計算
## 分岐タイルから指定方向に進んだ場合の、最短未訪問CPへの距離に基づくボーナス
func _calculate_direction_bonus_for_branch(branch_tile: int, next_tile: int, player_id: int) -> int:
	_ensure_checkpoint_distances_calculated()
	
	if not checkpoint_calculator:
		return 0
	
	if not checkpoint_calculator.is_branch_tile(branch_tile):
		return 0
	
	# プレイヤーの訪問済みチェックポイントを取得
	var visited = _get_visited_checkpoints(player_id)
	
	# 分岐タイルがCPなら除外
	var branch_cp = _get_checkpoint_id_at_tile(branch_tile)
	if branch_cp != "" and branch_cp not in visited:
		if typeof(visited) != TYPE_ARRAY or visited.is_read_only():
			visited = visited.duplicate()
		visited.append(branch_cp)
	
	# この方向での最短CP距離を取得
	var result = checkpoint_calculator.get_directional_nearest_checkpoint(branch_tile, next_tile, visited)
	var distance = result.distance
	var cp_id = result.checkpoint_id
	
	if cp_id == "" or distance >= 9999:
		return 0
	
	# 距離に応じたボーナス（近いほど高い）
	var distance_bonus = max(0, SCORE_DIRECTION_UNVISITED_GATE - (distance * 60))
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
	var _came_from = _get_player_came_from(player_id)  # 将来の拡張用
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
		
		if avg_score > best_score:
			best_score = avg_score
			best_direction = direction
	
	return best_direction

# =============================================================================
# 分岐タイルでの選択
# =============================================================================

## 分岐タイルでの選択（残り歩数を考慮）
## available_tiles: 選択可能なタイルインデックス配列
## remaining_steps: 残り歩数
## branch_tile: 現在いる分岐タイル（-1ならプレイヤー位置から取得）
## 返り値: 選択したタイルインデックス
func decide_branch_choice(player_id: int, available_tiles: Array, remaining_steps: int, branch_tile: int = -1) -> int:
	if available_tiles.is_empty():
		return -1
	
	if available_tiles.size() == 1:
		return available_tiles[0]
	
	var current_tile = branch_tile if branch_tile >= 0 else _get_player_current_tile(player_id)
	_current_branch_tile = current_tile
	
	# 手持ち魔力を取得（最短CP方向のボーナスとして使用）
	var current_magic = _get_player_magic(player_id)
	
	# チェックポイント距離計算を確認
	_ensure_checkpoint_distances_calculated()
	
	# 各方向の経路スコアと最短CP距離を計算
	var tile_scores = {}  # tile_index -> { score, cp_distance, cp_id }
	var visited = _get_visited_checkpoints(player_id)
	
	for tile_index in available_tiles:
		var eval_result = evaluate_path(tile_index, remaining_steps - 1, player_id, current_tile)
		var base_score = eval_result.score
		
		# この方向での最短未訪問CP距離を取得
		var cp_distance = 9999
		var cp_id = ""
		if checkpoint_calculator and checkpoint_calculator.is_branch_tile(current_tile):
			var result = checkpoint_calculator.get_directional_nearest_checkpoint(current_tile, tile_index, visited)
			cp_distance = result.distance
			cp_id = result.checkpoint_id
		
		tile_scores[tile_index] = {
			"base_score": base_score,
			"cp_distance": cp_distance,
			"cp_id": cp_id,
			"stop_tile": eval_result.stop_tile
		}
	
	# 最短CP方向を見つける
	var nearest_cp_tile = -1
	var nearest_cp_distance = 9999
	var _nearest_cp_id = ""
	
	for tile_index in tile_scores:
		var data = tile_scores[tile_index]
		if data.cp_distance < nearest_cp_distance:
			nearest_cp_distance = data.cp_distance
			nearest_cp_tile = tile_index
			_nearest_cp_id = data.cp_id
	
	# 最短CP方向に手持ち魔力をボーナスとして加算
	var final_scores = {}
	for tile_index in tile_scores:
		var data = tile_scores[tile_index]
		var final_score = data.base_score
		if tile_index == nearest_cp_tile:
			final_score += current_magic  # 最短CP方向に魔力ボーナス
		final_scores[tile_index] = final_score
	
	# 選択ロジック
	var selected_tile = available_tiles[0]
	var nearest_score = final_scores.get(nearest_cp_tile, -999999)
	
	# 最短CP方向のスコアがマイナスかどうかで判断
	if nearest_score >= 0:
		# マイナスでなければ最短CP方向を選択
		selected_tile = nearest_cp_tile
	else:
		# 最短CP方向がマイナスの場合
		# 他の方向のスコアを確認
		var other_scores = {}
		for tile_index in final_scores:
			if tile_index != nearest_cp_tile:
				other_scores[tile_index] = final_scores[tile_index]
		
		# 全方向マイナスかチェック
		var all_negative = true
		var best_other_tile = -1
		var best_other_score = -999999
		for tile_index in other_scores:
			if other_scores[tile_index] >= 0:
				all_negative = false
			if other_scores[tile_index] > best_other_score:
				best_other_score = other_scores[tile_index]
				best_other_tile = tile_index
		
		if all_negative:
			# 両方マイナス → マイナス差で判断
			var score_diff = abs(nearest_score - best_other_score)
			if score_diff <= 1000:
				# 差が1000以内なら最短CP方向
				selected_tile = nearest_cp_tile
			else:
				# 差が1000超ならマイナスが小さい方
				if nearest_score > best_other_score:
					selected_tile = nearest_cp_tile
				else:
					selected_tile = best_other_tile
		else:
			# 他にプラスの方向がある → そちらを選択
			selected_tile = best_other_tile
	
	_current_branch_tile = -1
	return selected_tile

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

## プレイヤーの手持ち魔力を取得
func _get_player_magic(player_id: int) -> int:
	if player_system:
		return player_system.get_magic(player_id)
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
	for i in range(PATH_EVALUATION_DISTANCE * 2):  # ワープ考慮で余裕を持たせる
		var tile_info = _get_tile_info(current)
		var tile_type = tile_info.get("tile_type", "")
		
		if tile_type in ["gate", "checkpoint"]:
			if _is_gate_unvisited(tile_info, player_id):
				return distance  # 距離を返す
		
		# ワープタイルの場合、距離を増やさずにジャンプ
		var is_warp = tile_type in ["warp", "warp_stop"]
		
		# 次のタイルへ
		var next = _get_next_tile_simple_with_direction(current, prev, direction)
		if next < 0 or next == current:
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


## プレイヤーの訪問済みチェックポイントIDリストを取得
func _get_visited_checkpoints(player_id: int) -> Array:
	if not lap_system:
		return []
	
	var visited = []
	var player_state = lap_system.player_lap_state.get(player_id, {})
	
	# lap_systemの状態から訪問済みを取得
	# 形式: { "N": true, "S": false, "lap_count": int, ... }
	for cp_id in player_state:
		# lap_count などの非チェックポイントキーをスキップ
		if cp_id == "lap_count":
			continue
		# 値がbool型でtrueの場合のみ訪問済み
		var value = player_state[cp_id]
		if typeof(value) == TYPE_BOOL and value == true:
			visited.append(cp_id)
	
	return visited


## 指定タイルがチェックポイントならそのIDを返す、そうでなければ空文字
func _get_checkpoint_id_at_tile(tile_index: int) -> String:
	if not movement_controller or not movement_controller.tile_nodes:
		return ""
	
	if not movement_controller.tile_nodes.has(tile_index):
		return ""
	
	var tile = movement_controller.tile_nodes[tile_index]
	var tile_type = tile.tile_type if "tile_type" in tile else ""
	
	if tile_type not in ["checkpoint", "gate"]:
		return ""
	
	# checkpoint_typeを取得
	if "checkpoint_type" in tile and tile.checkpoint_type != null:
		var cp_type = tile.checkpoint_type
		if typeof(cp_type) == TYPE_STRING and cp_type != "":
			return cp_type
		elif typeof(cp_type) == TYPE_INT:
			match cp_type:
				0: return "N"
				1: return "S"
				2: return "E"
				3: return "W"
	
	return ""


## プレイヤーが次に取るべきチェックポイントIDを取得
## 周回ゲームではCPは順番に取得する必要があるため、最短距離ではなく順番で決める
func _get_next_required_checkpoint(player_id: int) -> String:
	if not lap_system:
		return ""
	
	var player_state = lap_system.player_lap_state.get(player_id, {})
	var required = lap_system.required_checkpoints  # ["N", "E", "W"] など
	
	# 順番に見て、最初の未訪問CPを返す
	for cp_id in required:
		var is_visited = player_state.get(cp_id, false)
		if not is_visited:
			return cp_id
	
	# 全部訪問済み = 周回完了間近、最初のCPを返す
	if not required.is_empty():
		return required[0]
	
	return ""


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
