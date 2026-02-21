# CPUホーリーワード評価システム
# ホーリーワード系スペル（ダイス目固定）の使用判断を担当
#
# 使用例:
#   var evaluator = CPUHolyWordEvaluator.new()
#   evaluator.setup(movement_evaluator)
#   var result = evaluator.evaluate(spell, context)
extends RefCounted
class_name CPUHolyWordEvaluator

# 移動評価システムへの参照（経路シミュレーション等に使用）
var _movement_evaluator: CPUMovementEvaluator = null


## セットアップ
func setup(movement_evaluator: CPUMovementEvaluator) -> void:
	_movement_evaluator = movement_evaluator


## ホーリーワード系スペルの使用判断
## spell: ホーリーワードスペル
## context: { player_id, ... }
## 返り値: { "should_use": bool, "target": Dictionary, "reason": String }
func evaluate(spell: Dictionary, context: Dictionary) -> Dictionary:
	if not _movement_evaluator:
		return { "should_use": false }
	
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
	
	var spell_cost = spell.get("cost", {}).get("ep", 0)
	
	# 攻撃的使用を評価
	var offensive_result = _evaluate_offensive(dice_value, player_id, spell_cost)
	
	# 防御的使用を評価
	var defensive_result = _evaluate_defensive(dice_value, player_id, spell_cost)
	
	# 攻撃と防御を比較
	if offensive_result.should_use and offensive_result.expected_toll >= spell_cost:
		return {
			"should_use": true,
			"target": { "type": "player", "player_id": offensive_result.target_player_id },
			"reason": "攻撃: 敵を自分の土地に止まらせる（通行料: %dEP）" % offensive_result.expected_toll
		}
	
	if defensive_result.should_use and defensive_result.avoided_toll >= spell_cost:
		return {
			"should_use": true,
			"target": { "type": "player", "player_id": player_id },
			"reason": "防御: 敵の土地を回避（回避通行料: %dEP）" % defensive_result.avoided_toll
		}
	
	return { "should_use": false }


## 攻撃的使用を評価（敵を自分の高額土地に止まらせる）
func _evaluate_offensive(dice_value: int, player_id: int, spell_cost: int) -> Dictionary:
	var result = {
		"should_use": false,
		"target_player_id": -1,
		"expected_toll": 0
	}
	
	var player_system = _movement_evaluator.player_system
	if not player_system:
		return result
	
	var best_toll = 0
	var best_target = -1
	
	for enemy_id in range(player_system.players.size()):
		if player_system.is_same_team(player_id, enemy_id):
			continue
		
		var enemy_tile = _movement_evaluator.get_player_current_tile(enemy_id)
		var enemy_direction = _movement_evaluator.get_player_direction(enemy_id)
		
		# 敵がdice_value歩進んだ先を計算
		var sim_result = _movement_evaluator.simulate_path(enemy_tile, dice_value * enemy_direction, enemy_id)
		var stop_tile = sim_result.stop_tile
		
		var tile_info = _movement_evaluator.get_tile_info(stop_tile)
		var owner = tile_info.get("owner", -1)

		# 自分の土地かチェック
		if player_system.is_same_team(player_id, owner):
			var toll = _movement_evaluator.calculate_toll(stop_tile)
			
			# 侵略リスクをチェック
			if not _movement_evaluator.can_enemy_invade(stop_tile, enemy_id):
				if toll > best_toll:
					best_toll = toll
					best_target = enemy_id
	
	if best_target >= 0 and best_toll > spell_cost:
		result.should_use = true
		result.target_player_id = best_target
		result.expected_toll = best_toll
	
	return result


## 防御的使用を評価（自分が危険な土地を回避する）
func _evaluate_defensive(dice_value: int, player_id: int, spell_cost: int) -> Dictionary:
	var result = {
		"should_use": false,
		"avoided_toll": 0
	}

	var player_system = _movement_evaluator.player_system
	if not player_system:
		return result

	var current_tile = _movement_evaluator.get_player_current_tile(player_id)
	var my_direction = _movement_evaluator.get_player_direction(player_id)
	
	# dice_valueで止まる位置を計算
	var target_sim = _movement_evaluator.simulate_path(current_tile, dice_value * my_direction, player_id)
	var target_tile = target_sim.stop_tile
	var target_info = _movement_evaluator.get_tile_info(target_tile)
	var target_owner = target_info.get("owner", -1)
	
	# このダイス目で敵の土地に止まるか？
	if target_owner >= 0 and not player_system.is_same_team(player_id, target_owner):
		if not _movement_evaluator.can_invade_and_win(target_tile, player_id):
			# 倒せない敵の土地 → このダイス目は使いたくない
			return result
	
	# 他のダイス目で危険な場所があるか確認
	var max_danger_toll = 0
	for check_dice in [1, 2, 3, 4, 5, 6, 8]:
		if check_dice == dice_value:
			continue
		
		var check_sim = _movement_evaluator.simulate_path(current_tile, check_dice * my_direction, player_id)
		var check_tile = check_sim.stop_tile
		var check_info = _movement_evaluator.get_tile_info(check_tile)
		var check_owner = check_info.get("owner", -1)

		if check_owner >= 0 and not player_system.is_same_team(player_id, check_owner):
			if not _movement_evaluator.can_invade_and_win(check_tile, player_id):
				var toll = _movement_evaluator.calculate_toll(check_tile)
				if toll > max_danger_toll:
					max_danger_toll = toll
	
	if max_danger_toll > spell_cost:
		result.should_use = true
		result.avoided_toll = max_danger_toll
	
	return result
