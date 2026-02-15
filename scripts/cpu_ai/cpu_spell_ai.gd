## CPU スペルカード使用判断
## 手札のスペルを評価し、使用すべきか判断する
class_name CPUSpellAI
extends RefCounted

## 参照
var condition_checker: CPUSpellConditionChecker = null
var target_selector: CPUSpellTargetSelector = null
var spell_utils: CPUSpellUtils = null
var sacrifice_selector: CPUSacrificeSelector = null
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var creature_manager: Node = null
var lap_system: Node = null
var cpu_movement_evaluator: CPUMovementEvaluator = null

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

## 内部コンポーネントを初期化
func _init() -> void:
	condition_checker = CPUSpellConditionChecker.new()
	target_selector = CPUSpellTargetSelector.new()
	spell_utils = CPUSpellUtils.new()
	sacrifice_selector = CPUSacrificeSelector.new()

## 手札ユーティリティを設定
func set_hand_utils(utils: CPUHandUtils) -> void:
	hand_utils = utils
	if condition_checker:
		condition_checker.set_hand_utils(utils)

## SpellSynthesisを設定（犠牲カード選択用）
func set_spell_synthesis(spell_synth: SpellSynthesis) -> void:
	if sacrifice_selector:
		sacrifice_selector.spell_synthesis = spell_synth

## CPUBattleAIを設定（共通バトル評価用）
func set_battle_ai(ai: CPUBattleAI) -> void:
	if condition_checker:
		condition_checker.set_battle_ai(ai)

## 共有コンテキストで初期化
func initialize(context) -> void:
	# contextからシステム参照を取得
	if context:
		board_system = context.board_system
		player_system = context.player_system
		card_system = context.card_system
		creature_manager = context.creature_manager
		lap_system = context.lap_system
	
	if condition_checker:
		condition_checker.initialize(context)
	if target_selector:
		target_selector.initialize(context)
	if spell_utils:
		spell_utils.set_context(context)
	if sacrifice_selector and context:
		sacrifice_selector.initialize(context.card_system, context.board_system)

## CPUMovementEvaluatorを設定（ホーリーワード判断用）
func set_movement_evaluator(evaluator: CPUMovementEvaluator) -> void:
	cpu_movement_evaluator = evaluator

## game_statsを設定（GFM経由を廃止） - 内部コンポーネントにも伝播
func set_game_stats(p_game_stats) -> void:
	if target_selector:
		target_selector.set_game_stats(p_game_stats)
	if condition_checker:
		condition_checker.set_game_stats(p_game_stats)

## スペル使用判断のメインエントリ
## 戻り値: {use: bool, spell: Dictionary, target: Dictionary, sacrifice_card: Dictionary, should_synthesize: bool}
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
		# should_useがtrueかつスコアが0以上の場合のみ使用候補に追加
		if evaluation.should_use and evaluation.score >= 0:
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
	var best_spell = best.spell
	
	# カード犠牲処理
	var sacrifice_card = {}
	var should_synthesize = false
	
	if _requires_card_sacrifice(best_spell):
		# 合成判断（targetがnullの場合は空のDictionaryを渡す）
		var target_for_synth = best.target if best.target != null else {}
		should_synthesize = _should_synthesize_spell(best_spell, target_for_synth, context)
		
		# 犠牲カード選択
		if sacrifice_selector:
			sacrifice_card = sacrifice_selector.select_sacrifice_card(best_spell, player_id, should_synthesize)
		
		# 犠牲カードがない場合は使用しない
		if sacrifice_card.is_empty():
			print("[CPUSpellAI] 犠牲カードがないため %s を使用しない" % best_spell.get("name", "?"))
			return {"use": false}
	
	return {
		"use": true,
		"spell": best_spell,
		"target": best.target,
		"score": best.score,
		"sacrifice_card": sacrifice_card,
		"should_synthesize": should_synthesize
	}

## 使用可能なスペルを取得
func _get_usable_spells(player_id: int) -> Array:
	var hand = card_system.get_all_cards_for_player(player_id)
	var magic = player_system.get_magic(player_id)
	var spells = []

	# プレイヤー呪いをチェック - スペル不可状態
	var player = player_system.players[player_id] if player_id < player_system.players.size() else null
	if player and SpellProtection.is_player_spell_disabled(player, {}):
		# スペル不可状態 → 使用可能なスペルなし
		print("[CPUSpellAI] プレイヤー%dはスペル不可の呪いがかかっています" % player_id)
		return []

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
func _evaluate_immediate(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var target_filter = effect_parsed.get("target_filter", "")
	
	# target_type が player かつ target_filter が enemy の場合、敵プレイヤーをターゲットにする
	if target_type == "player" and target_filter == "enemy":
		if player_system:
			var enemies = []
			var my_id = context.player_id
			for i in range(player_system.players.size()):
				if i != my_id:
					enemies.append(i)
			if not enemies.is_empty():
				var target_id = enemies[randi() % enemies.size()]
				return {
					"should_use": true,
					"score": base_score,
					"target": {"type": "player", "player_id": target_id}
				}
		# 敵プレイヤーが見つからない場合は使用しない
		return {"should_use": false, "score": 0.0, "target": null}
	
	# それ以外は従来通り自分をターゲット
	return {
		"should_use": true,
		"score": base_score,
		"target": {"type": "self", "player_id": context.player_id}
	}

## パターン: has_target（ターゲット存在）
func _evaluate_has_target(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = spell.get("cpu_rule", {})
	var target_condition = cpu_rule.get("target_condition", "")
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	
	var targets = []
	
	# ダメージ値をcontextに追加
	var damage_value = spell_utils.get_damage_value(spell)
	if damage_value > 0:
		context["damage_value"] = damage_value
	
	# スペル情報をcontextに追加（HP効果無効フィルタ用）
	context["spell"] = spell
	
	if target_condition:
		targets = condition_checker.check_target_condition(target_condition, context)
	else:
		targets = target_selector.get_default_targets(spell, context)
	
	if targets.is_empty():
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 全体効果スペル（all_creatures, all_lands等）の場合、ターゲット選択不要
	if target_type in ["all_creatures", "all_lands", "none", "self", "world"]:
		return {
			"should_use": true,
			"score": base_score,
			"target": null
		}
	
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
	var condition_met = condition_checker.check_condition(condition, extended_context)
	print("[CPUスペルAI] condition=%s, 結果=%s, スペル=%s" % [condition, condition_met, spell.get("name", "")])
	if not condition_met:
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 条件を満たした場合、ターゲットを取得（スコア付き）
	var result = target_selector.get_condition_target_with_score(spell, extended_context)
	var target = result.target
	var target_score = result.score
	
	# 適切なターゲットがない場合は使用しない
	if target.is_empty():
		return {"should_use": false, "score": 0.0, "target": null}
	
	# ターゲットスコアが負の場合は使用しない（有利な呪いを上書きしたくない等）
	if target_score < 0:
		return {"should_use": false, "score": target_score, "target": null}
	
	return {
		"should_use": true,
		"score": base_score + target_score,
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

## 最高価値の自ドミニオを取得
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
			# ホーリーワード系スペルの判断（CPUMovementEvaluator経由）
			var holy_word_result = _evaluate_holy_word_spell(spell, context)
			should_use = holy_word_result.should_use
			if should_use:
				target = holy_word_result.target
				score_multiplier = 0.9  # 効果的な使用なので高スコア
				print("[CPUスペルAI] ホーリーワード使用: %s" % holy_word_result.reason)
			else:
				score_multiplier = 0.0
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

## ホーリーワード系スペルの使用判断
## 返り値: { should_use: bool, target: Dictionary, reason: String }
func _evaluate_holy_word_spell(spell: Dictionary, context: Dictionary) -> Dictionary:
	var result = { "should_use": false, "target": null, "reason": "" }
	
	# CPUMovementEvaluatorがなければ使用しない
	if not cpu_movement_evaluator:
		return result
	
	var player_id = context.get("player_id", 0)
	
	# スペルからダイス固定値を取得
	var dice_value = _get_dice_value_from_spell(spell)
	if dice_value <= 0:
		return result
	
	var cost_data = spell.get("cost", {})
	var spell_cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		spell_cost = cost_data.get("ep", 0)
	elif typeof(cost_data) == TYPE_INT:
		spell_cost = cost_data
	
	# 各敵プレイヤーについて評価
	var best_toll = 0
	var best_target_id = -1
	var best_tile_index = -1
	
	for enemy_id in range(player_system.players.size()):
		if enemy_id == player_id:
			continue
		
		# 敵の現在位置と進行方向を取得
		var enemy_tile = cpu_movement_evaluator.get_player_current_tile(enemy_id)
		var enemy_direction = cpu_movement_evaluator.get_player_direction(enemy_id)
		
		# 敵がdice_value歩進んだ先の停止位置を計算
		var sim_result = cpu_movement_evaluator.simulate_path(
			enemy_tile + enemy_direction,  # 1歩目から開始
			dice_value - 1,  # 残り歩数
			enemy_id,
			enemy_tile  # came_from
		)
		
		# dice_value == 1 の場合は特別処理
		var stop_tile: int
		if dice_value == 1:
			stop_tile = enemy_tile + enemy_direction
		else:
			stop_tile = sim_result.stop_tile
		
		# 停止位置の情報を取得
		var tile_info = cpu_movement_evaluator.get_tile_info(stop_tile)
		var owner = tile_info.get("owner", -1)
		var level = tile_info.get("level", 1)
		
		# 自分のLv3以上のドミニオかチェック
		if owner != player_id:
			continue
		if level < 3:
			continue
		
		# 敵が侵略して勝てるかチェック
		if cpu_movement_evaluator.can_invade_and_win(stop_tile, enemy_id):
			continue  # 敵が勝てるなら使用しない
		
		# 通行料を計算
		var toll = cpu_movement_evaluator.calculate_toll(stop_tile)
		
		if toll > best_toll:
			best_toll = toll
			best_target_id = enemy_id
			best_tile_index = stop_tile
	
	# 最良の組み合わせがあれば使用（攻撃的使用）
	if best_target_id >= 0 and best_toll > 0:
		result.should_use = true
		result.target = { "type": "player", "player_id": best_target_id }
		result.reason = "攻撃: 敵P%dをLv%d土地(タイル%d)に止まらせる（通行料: %dEP）" % [
			best_target_id + 1,
			cpu_movement_evaluator.get_tile_info(best_tile_index).get("level", 1),
			best_tile_index,
			best_toll
		]
		return result
	
	# 攻撃的使用ができない場合、防御的使用を検討
	var defensive_result = _evaluate_holy_word_defensive(dice_value, player_id, spell_cost)
	if defensive_result.should_use:
		result.should_use = true
		result.target = { "type": "player", "player_id": player_id }
		result.reason = defensive_result.reason
	
	return result

## ホーリーワード防御的使用の判断
## 自分が敵の高額ドミニオを回避できるか判断
func _evaluate_holy_word_defensive(dice_value: int, player_id: int, _spell_cost: int) -> Dictionary:
	var result = { "should_use": false, "reason": "" }
	
	if not cpu_movement_evaluator:
		return result
	
	var my_tile = cpu_movement_evaluator.get_player_current_tile(player_id)
	var my_direction = cpu_movement_evaluator.get_player_direction(player_id)
	
	# 経路上の危険な位置（敵Lv3以上ドミニオ）をリストアップ
	# 距離とタイルインデックスのペアで記録
	var danger_positions = _find_danger_positions_on_path(my_tile, my_direction, player_id)
	
	if danger_positions.is_empty():
		return result
	
	# このホーリーワードで止まる位置を計算
	var sim_result = cpu_movement_evaluator.simulate_path(
		my_tile + my_direction,
		dice_value - 1,
		player_id,
		my_tile
	)
	
	var stop_tile: int
	if dice_value == 1:
		stop_tile = my_tile + my_direction
	else:
		stop_tile = sim_result.stop_tile
	
	# ホーリーワードでの停止位置までの距離を計算
	var stop_distance = dice_value
	
	# 判定：
	# 1. 停止位置がいずれかの危険な位置に一致 → ダメ
	# 2. 最も近い危険な位置を超えていない → ダメ（危険回避になっていない）
	# 3. 危険な位置を超えつつ、どの危険な位置にも止まらない → OK
	
	var min_danger_distance = 999
	for danger in danger_positions:
		var danger_distance = danger.distance
		var danger_tile = danger.tile
		
		if danger_distance < min_danger_distance:
			min_danger_distance = danger_distance
		
		# 停止位置が危険な位置に一致
		if stop_tile == danger_tile:
			return result
	
	# 最も近い危険を超えているかチェック
	if stop_distance <= min_danger_distance:
		return result
	
	# OK: 危険を超えつつ、どの危険にも止まらない
	var max_avoided_toll = 0
	for danger in danger_positions:
		if danger.distance < stop_distance:
			max_avoided_toll = max(max_avoided_toll, danger.toll)
	
	result.should_use = true
	result.reason = "防御: 敵の高額ドミニオを回避（回避通行料: %dEP）" % max_avoided_toll
	
	return result

## 経路上の危険な位置（敵Lv3以上ドミニオ）をリストアップ
## 返り値: Array[{ distance: int, tile: int, toll: int }]
func _find_danger_positions_on_path(start_tile: int, direction: int, player_id: int) -> Array:
	var dangers = []
	
	if not cpu_movement_evaluator:
		return dangers
	
	# 8マス先までチェック（ホーリーワード8が最大）
	for distance in range(1, 9):
		# start_tileからdistance歩進んだ位置を計算
		var sim_result = cpu_movement_evaluator.simulate_path(
			start_tile + direction,
			distance - 1,
			player_id,
			start_tile
		)
		
		var check_tile: int
		if distance == 1:
			check_tile = start_tile + direction
		else:
			check_tile = sim_result.stop_tile
		
		# タイル情報を取得
		var tile_info = cpu_movement_evaluator.get_tile_info(check_tile)
		var owner = tile_info.get("owner", -1)
		var level = tile_info.get("level", 1)
		
		# 敵のLv3以上のドミニオかチェック
		if owner >= 0 and owner != player_id and level >= 3:
			var toll = cpu_movement_evaluator.calculate_toll(check_tile)
			dangers.append({
				"distance": distance,
				"tile": check_tile,
				"toll": toll
			})
	
	return dangers

## スペルからダイス固定値を取得
func _get_dice_value_from_spell(spell: Dictionary) -> int:
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "dice_fixed":
			return effect.get("value", 0)
	
	return 0

## 自分の高レベル土地を取得（レベル3以上）
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
		if level >= 3:
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


# =============================================================================
# カード犠牲・合成判断
# =============================================================================

## カード犠牲が必要か判定
func _requires_card_sacrifice(spell_data: Dictionary) -> bool:
	# 正規化されたフィールドをチェック
	if spell_data.get("cost_cards_sacrifice", 0) > 0:
		return true
	# 正規化されていない場合、元のcostフィールドもチェック
	var cost = spell_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		return cost.get("cards_sacrifice", 0) > 0
	return false


## 合成すべきか判断（スペル使用時）
## 戻り値: true=合成する, false=合成しない
func _should_synthesize_spell(spell: Dictionary, target: Dictionary, context: Dictionary) -> bool:
	var spell_id = spell.get("id", 0)
	var synthesis = spell.get("synthesis", {})
	
	if synthesis.is_empty():
		return false  # 合成効果なし
	
	# スペルごとの合成判断
	match spell_id:
		2033:  # シャイニングガイザー
			return _should_synthesize_shining_geyser(target, context)
		2058:  # デビリティ
			return _should_synthesize_debility(context)
		2107:  # マスグロース
			return _should_synthesize_mass_growth(context)
		_:
			# その他の合成スペルは合成しない（カード犠牲のみ）
			return false


## シャイニングガイザーの合成判断
## HP31-40の敵がいる場合のみ合成
func _should_synthesize_shining_geyser(target: Dictionary, _context: Dictionary) -> bool:
	if target.is_empty():
		return false
	
	var creature = target.get("creature", {})
	if creature.is_empty():
		return false
	
	var current_hp = creature.get("current_hp", creature.get("hp", 0))
	
	# HP31-40なら合成必須（30ダメージでは倒せないが40なら倒せる）
	return current_hp > 30 and current_hp <= 40


## デビリティの合成判断
## 可能な限り合成（任意スペルが手札にあれば）
func _should_synthesize_debility(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	
	if not sacrifice_selector:
		return false
	
	# 手札に任意スペルがあるかチェック
	var hand = card_system.get_all_cards_for_player(player_id)
	for card in hand:
		if card.get("type") == "spell":
			return true  # スペルがあれば合成する
	
	return false


## マスグロースの合成判断
## 敵クリーチャーがいる場合のみ合成（自クリーチャーのみに効果を限定）
func _should_synthesize_mass_growth(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	
	if not board_system:
		return false
	
	# 敵クリーチャーがいるかチェック
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if creature.is_empty():
			continue
		
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id and owner_id != -1:
			return true  # 敵クリーチャーがいれば合成する
	
	return false

# =============================================================================
# 魔法タイル用評価（外部呼び出し用）
# =============================================================================

## 魔法タイル用スペル評価
## 魔法タイルで提示されたスペルを使用すべきか判断する
## 通常のスペルフェーズとは異なり、手札からではなくランダムで提示されたスペルを評価
func evaluate_spell_for_magic_tile(spell: Dictionary, player_id: int) -> Dictionary:
	var result = {
		"should_use": false,
		"score": 0.0,
		"target": null
	}
	
	# コンテキスト構築
	var context = _build_context(player_id)
	if context.is_empty():
		return result
	
	# スペル評価（既存の_evaluate_spellを使用）
	var eval_result = _evaluate_spell(spell, context)
	
	# 魔法タイルでは閾値を下げる（無料ではないが、提示されたスペルを活用したい）
	# 通常フェーズでは使わないような低スコアのスペルも、魔法タイルなら使う価値がある
	var magic_tile_threshold = 1.0  # 低めの閾値
	
	if eval_result.get("should_use", false) and eval_result.get("score", 0) >= magic_tile_threshold:
		result.should_use = true
		result.score = eval_result.get("score", 0)
		result.target = eval_result.get("target")
	
	return result

## コンテキスト構築（内部用）
func _build_context(player_id: int) -> Dictionary:
	if not player_system or not board_system:
		return {}
	
	if player_id >= player_system.players.size():
		return {}
	
	var player = player_system.players[player_id]
	var current_tile = player.current_tile
	var tile_info = {}
	if board_system.has_method("get_tile_info"):
		tile_info = board_system.get_tile_info(current_tile)
	
	return {
		"player_id": player_id,
		"magic": player.magic_power,
		"current_tile": current_tile,
		"tile_info": tile_info,
		"player": player
	}
