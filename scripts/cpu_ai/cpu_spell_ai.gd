## CPU スペルカード使用判断
## 手札のスペルを評価し、使用すべきか判断する
class_name CPUSpellAI
extends RefCounted

## 参照
var condition_checker: CPUSpellConditionChecker = null
var target_selector: CPUSpellTargetSelector = null
var spell_utils: CPUSpellUtils = null
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

## 手札ユーティリティ（ワーストケースシミュレーション用）
var hand_utils: CPUHandUtils = null

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
	
	# ターゲット選択クラス初期化
	target_selector = CPUSpellTargetSelector.new()
	target_selector.initialize(b_system, p_system, c_system, condition_checker, l_system)
	
	# ユーティリティクラス初期化
	spell_utils = CPUSpellUtils.new()
	spell_utils.initialize(b_system, p_system, c_system, l_system)

## 手札ユーティリティを設定
func set_hand_utils(utils: CPUHandUtils) -> void:
	hand_utils = utils
	if condition_checker:
		condition_checker.set_hand_utils(utils)

## CPUBattleAIを設定（共通バトル評価用）
func set_battle_ai(ai: CPUBattleAI) -> void:
	if condition_checker:
		condition_checker.set_battle_ai(ai)

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
	var context = spell_utils.build_context(player_id)
	
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
		var cost = spell_utils.get_spell_cost(card)
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
	var damage_value = spell_utils.get_damage_value(spell)
	if damage_value > 0:
		context["damage_value"] = damage_value
	
	if target_condition:
		targets = condition_checker.check_target_condition(target_condition, context)
	else:
		targets = target_selector.get_default_targets(spell, context)
	
	if targets.is_empty():
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 最適なターゲットを選択（スコア付き）
	var selection = target_selector.select_best_target_with_score(targets, spell, context)
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
	var target = target_selector.get_condition_target(spell, extended_context)
	
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
		targets = target_selector.get_enemy_players(context)
	
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
	var cost = spell_utils.get_spell_cost(spell)
	
	var target = null
	
	# profit_conditionがある場合は条件チェック
	if not profit_condition.is_empty():
		var condition_met = _check_profit_condition(profit_condition, context, cost)
		if not condition_met:
			return {"should_use": false, "score": 0.0, "target": null}
		
		target = target_selector.get_profit_target(spell, context)
		return {
			"should_use": true,
			"score": base_score,
			"target": target
		}
	
	# 従来のprofit_formula形式
	var profit = spell_utils.calculate_profit(profit_formula, context)
	
	# コストより利益が大きければ使用
	if profit <= cost:
		return {"should_use": false, "score": 0.0, "target": null}
	
	# スコアを利益率で調整
	var profit_ratio = float(profit) / float(cost) if cost > 0 else 1.0
	var adjusted_score = base_score * min(profit_ratio, 2.0)
	
	target = target_selector.get_profit_target(spell, context)
	
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
			return spell_utils.get_enemy_land_count(context) >= 3
		"enemy_magic_gte_300":
			return spell_utils.get_max_enemy_magic(context) >= 300
		"enemy_magic_higher":
			var my_magic = context.get("magic", 0)
			return spell_utils.get_max_enemy_magic(context) > my_magic
		"land_value_high":
			var highest_value = _get_highest_own_land_value(context)
			return highest_value * 0.7 > cost
		"lap_behind_enemy":
			return spell_utils.calculate_lap_diff(context) > 0
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
			var enemies = target_selector.get_enemy_players(context)
			if not enemies.is_empty():
				target = enemies[randi() % enemies.size()]
		"near_enemy_high_toll":
			should_use = _check_near_enemy_high_toll(context)
			score_multiplier = 0.7
			target = target_selector.get_strategic_target(spell, context)
		_:
			should_use = randf() < 0.3
			score_multiplier = 0.5
			target = target_selector.get_strategic_target(spell, context)
	
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
	var current_tile = spell_utils.get_player_current_tile(player_id)
	
	# スペルの距離制限を取得
	var effect_parsed = spell.get("effect_parsed", {})
	var target_info = effect_parsed.get("target_info", {})
	var distance_min = target_info.get("distance_min", 1)
	var distance_max = target_info.get("distance_max", 4)
	
	# 未訪問チェックポイントタイルを取得
	var checkpoint_tiles = spell_utils.get_unvisited_checkpoint_tiles(player_id)
	if checkpoint_tiles.is_empty():
		# 全て訪問済みなら最寄りチェックポイントを使用
		checkpoint_tiles = spell_utils.get_all_checkpoint_tiles()
	
	if checkpoint_tiles.is_empty():
		return {}
	
	# 距離制限内の土地を取得
	var candidate_tiles = spell_utils.get_tiles_in_range(current_tile, distance_min, distance_max)
	if candidate_tiles.is_empty():
		return {}
	
	# 最寄りチェックポイントに最も近い土地を選ぶ
	var best_tile = -1
	var best_distance = 999999
	
	for tile_index in candidate_tiles:
		for cp_tile in checkpoint_tiles:
			var dist = spell_utils.calculate_tile_distance(tile_index, cp_tile)
			if dist < best_distance:
				best_distance = dist
				best_tile = tile_index
	
	if best_tile >= 0:
		return {"type": "land", "tile_index": best_tile}
	
	return {}
