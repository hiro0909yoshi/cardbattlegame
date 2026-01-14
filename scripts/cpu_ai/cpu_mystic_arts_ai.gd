## CPU ミスティックアーツ使用判断
## 配置クリーチャーの秘術を評価し、使用すべきか判断する
class_name CPUMysticArtsAI
extends RefCounted

## 参照
var condition_checker: CPUSpellConditionChecker = null
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var creature_manager: Node = null
var lap_system: Node = null
var target_resolver: CPUTargetResolver = null
var game_flow_manager: Node = null

## ミスティックアーツデータキャッシュ
var mystic_arts_data: Dictionary = {}

## 優先度の数値変換
const PRIORITY_VALUES = {
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
	game_flow_manager = gf_manager
	
	# 条件チェッカー初期化
	condition_checker = CPUSpellConditionChecker.new()
	condition_checker.initialize(b_system, p_system, c_system, cr_manager)
	
	# CPUTargetResolverの初期化
	target_resolver = CPUTargetResolver.new()
	var board_analyzer = CPUBoardAnalyzer.new()
	board_analyzer.initialize(b_system, p_system, c_system, cr_manager)
	target_resolver.initialize(board_analyzer, b_system, p_system, c_system, game_flow_manager)
	
	# ミスティックアーツデータをロード
	_load_mystic_arts_data()

## 手札ユーティリティを設定
func set_hand_utils(utils: CPUHandUtils) -> void:
	if condition_checker:
		condition_checker.set_hand_utils(utils)

## CPUBattleAIを設定（共通バトル評価用）
func set_battle_ai(ai: CPUBattleAI) -> void:
	if condition_checker:
		condition_checker.set_battle_ai(ai)

## ミスティックアーツデータをロード
func _load_mystic_arts_data() -> void:
	var file = FileAccess.open("res://data/spell_mystic.json", FileAccess.READ)
	if not file:
		push_warning("CPUMysticArtsAI: Failed to load spell_mystic.json")
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_warning("CPUMysticArtsAI: Failed to parse spell_mystic.json")
		return
	
	var data = json.get_data()
	if data and data.has("cards"):
		for card in data.cards:
			var id = card.get("id", 0)
			mystic_arts_data[id] = card

## ミスティックアーツ使用判断のメインエントリ
## 戻り値: {use: bool, creature_tile: int, mystic: Dictionary, target: Dictionary}
func decide_mystic_arts(player_id: int) -> Dictionary:
	if not board_system or not player_system:
		return {"use": false}
	
	# 使用可能なミスティックアーツを取得
	var usable_mystics = _get_usable_mystic_arts(player_id)
	if usable_mystics.is_empty():
		return {"use": false}
	
	# コンテキスト作成
	var context = _build_context(player_id)
	
	# 各ミスティックアーツを評価
	var evaluated_mystics = []
	for mystic_info in usable_mystics:
		var evaluation = _evaluate_mystic_art(mystic_info, context)
		# should_useがtrueかつスコアが0以上の場合のみ使用候補に追加
		if evaluation.should_use and evaluation.score >= 0:
			evaluated_mystics.append({
				"creature_tile": mystic_info.tile_index,
				"mystic": mystic_info.mystic,
				"mystic_data": mystic_info.mystic_data,
				"score": evaluation.score,
				"target": evaluation.target
			})
	
	if evaluated_mystics.is_empty():
		return {"use": false}
	
	# スコアでソートして最高のものを選択
	evaluated_mystics.sort_custom(func(a, b): return a.score > b.score)
	
	var best = evaluated_mystics[0]
	return {
		"use": true,
		"creature_tile": best.creature_tile,
		"mystic": best.mystic,
		"mystic_data": best.mystic_data,
		"target": best.target,
		"score": best.score
	}

## 使用可能なミスティックアーツを取得
func _get_usable_mystic_arts(player_id: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var magic = player_system.get_magic(player_id) if player_system else 0
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		# 自分のクリーチャーのみ
		if tile.get("owner", tile.get("owner_id", -1)) != player_id:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature:
			continue
		
		# ダウン中は使用不可（タイルノードで確認）
		var tile_index = tile.get("index", -1)
		var is_down = _check_tile_is_down(tile_index)
		if is_down:
			continue
		
		# 秘術を取得
		var ability = creature.get("ability_parsed", {})
		
		# mystic_art（単数）またはmystic_arts（複数）に対応
		var mystic_arts = []
		if ability.has("mystic_art"):
			mystic_arts = [ability.get("mystic_art")]
		elif ability.has("mystic_arts"):
			mystic_arts = ability.get("mystic_arts", [])
		
		for mystic in mystic_arts:
			var spell_id = mystic.get("spell_id", 0)
			var cost = mystic.get("cost", 0)
			
			# コストチェック
			if cost > magic:
				continue
			
			# spell_idからデータを取得
			var mystic_data = mystic_arts_data.get(spell_id, {})
			
			# cpu_ruleがskipのものは除外
			var cpu_rule = mystic_data.get("cpu_rule", {})
			if cpu_rule.get("pattern") == "skip":
				continue
			
			results.append({
				"tile_index": tile.get("index", -1),
				"creature": creature,
				"mystic": mystic,
				"mystic_data": mystic_data,
				"cost": cost
			})
	
	return results

## ミスティックアーツを評価
func _evaluate_mystic_art(mystic_info: Dictionary, context: Dictionary) -> Dictionary:
	var mystic_data = mystic_info.mystic_data
	var cpu_rule = mystic_data.get("cpu_rule", {})
	var pattern = cpu_rule.get("pattern", "")
	var priority = cpu_rule.get("priority", "low")
	var base_score = PRIORITY_VALUES.get(priority, 1.0)
	
	# 術者情報をコンテキストに追加
	context["caster_tile"] = mystic_info.tile_index
	context["caster"] = mystic_info.creature
	
	var result = {
		"should_use": false,
		"score": 0.0,
		"target": null
	}
	
	match pattern:
		"immediate":
			result = _evaluate_immediate(mystic_data, context, base_score)
		
		"has_target":
			result = _evaluate_has_target(mystic_data, context, base_score)
		
		"condition":
			result = _evaluate_condition(mystic_data, context, base_score)
		
		"profit_calc":
			result = _evaluate_profit_calc(mystic_info, context, base_score)
		
		"strategic":
			result = _evaluate_strategic(mystic_data, context, base_score)
		
		_:
			pass
	
	return result

## パターン: immediate
func _evaluate_immediate(_mystic_data: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	return {
		"should_use": true,
		"score": base_score,
		"target": {"type": "self", "player_id": context.player_id}
	}

## パターン: has_target
func _evaluate_has_target(mystic_data: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = mystic_data.get("cpu_rule", {})
	var target_condition = cpu_rule.get("target_condition", "")
	
	var targets = []
	
	# ダメージ値をcontextに追加
	var damage_value = _get_damage_value(mystic_data)
	if damage_value > 0:
		context["damage_value"] = damage_value
	
	if target_condition:
		targets = condition_checker.check_target_condition(target_condition, context)
	else:
		targets = _get_default_targets(mystic_data, context)
	
	if targets.is_empty():
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 最適なターゲットを選択（スコア付き）
	var selection = _select_best_target_with_score(targets, mystic_data, context)
	var best_target = selection.target
	var target_score = selection.score
	
	# ダメージ系でターゲットを倒せる場合、優先度を上げる
	var adjusted_score = base_score
	if damage_value > 0 and target_score >= 3.0:
		adjusted_score = base_score * 1.5
	
	return {
		"should_use": true,
		"score": adjusted_score,
		"target": best_target
	}

## パターン: condition
func _evaluate_condition(mystic_data: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var cpu_rule = mystic_data.get("cpu_rule", {})
	var condition = cpu_rule.get("condition", "")
	
	if not condition:
		return {"should_use": false, "score": 0.0, "target": null}
	
	if not condition_checker.check_condition(condition, context):
		return {"should_use": false, "score": 0.0, "target": null}
	
	# ターゲット取得（スコア付き）
	var result = _get_condition_target_with_score(mystic_data, context)
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

## パターン: profit_calc
func _evaluate_profit_calc(mystic_info: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	var mystic_data = mystic_info.mystic_data
	var cpu_rule = mystic_data.get("cpu_rule", {})
	var profit_formula = cpu_rule.get("profit_formula", "")
	var cost = mystic_info.cost
	
	# 術者の情報を追加
	var caster = mystic_info.creature
	context["caster_mhp"] = caster.get("max_hp", 0)
	
	var profit = _calculate_profit(profit_formula, context)
	
	if profit <= cost:
		return {"should_use": false, "score": 0.0, "target": null}
	
	var profit_ratio = float(profit) / float(cost) if cost > 0 else 1.0
	var adjusted_score = base_score * min(profit_ratio, 2.0)
	
	var target = _get_profit_target(mystic_data, context)
	
	return {
		"should_use": true,
		"score": adjusted_score,
		"target": target
	}

## パターン: strategic
func _evaluate_strategic(mystic_data: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	if randf() < 0.3:
		var target = _get_strategic_target(mystic_data, context)
		return {
			"should_use": true,
			"score": base_score * 0.5,
			"target": target
		}
	
	return {"should_use": false, "score": 0.0, "target": null}

# =============================================================================
# ヘルパー関数
# =============================================================================

## コンテキスト作成
func _build_context(player_id: int) -> Dictionary:
	var context = {
		"player_id": player_id,
		"magic": player_system.get_magic(player_id) if player_system else 0,
		"destroyed_count": 0
	}
	
	# 破壊カウントはlap_systemから取得（グローバル）
	if lap_system:
		context.destroyed_count = lap_system.get_destroy_count()
	
	return context

## ダメージ値取得
func _get_damage_value(mystic_data: Dictionary) -> int:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "damage":
			return effect.get("value", 0)
	
	return 0

## デフォルトターゲット取得（TargetSelectionHelper共通ロジック使用）
func _get_default_targets(mystic_data: Dictionary, context: Dictionary) -> Array:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var target_info = effect_parsed.get("target_info", {}).duplicate()
	
	# selfターゲットは特別処理
	if target_type == "self":
		return [{"type": "self", "tile_index": context.get("caster_tile", -1)}]
	
	# systemsを構築
	var systems = {
		"board_system": board_system,
		"player_system": player_system,
		"current_player_id": context.get("player_id", 0),
		"game_flow_manager": game_flow_manager
	}
	
	# TargetSelectionHelperの共通ロジックを使用
	var targets = TargetSelectionHelper.get_valid_targets_core(systems, target_type, target_info)
	
	# 移動系呪いの場合、防御型クリーチャーを除外
	if _is_movement_curse(mystic_data):
		targets = targets.filter(func(t): return not _is_defensive_creature(t.get("creature", {})))
	
	# 呪い秘術の場合、追加のフィルタリングを適用
	if target_type == "creature" and target_resolver:
		var curse_info = target_resolver.analyze_curse_spell(mystic_data)
		if curse_info.is_curse:
			targets = target_resolver.filter_curse_spell_targets(
				curse_info.is_beneficial,
				targets,
				context
			)
	
	return targets

## 最適なターゲット選択（スコア付き）
func _select_best_target_with_score(targets: Array, mystic_data: Dictionary, context: Dictionary) -> Dictionary:
	if targets.is_empty():
		return {"target": {}, "score": 0.0}
	
	var player_id = context.get("player_id", 0)
	var damage_value = context.get("damage_value", 0)
	var is_damage_spell = damage_value > 0
	
	# 呪い秘術かどうか判定
	var curse_info = _analyze_curse_mystic(mystic_data)
	
	var best_target = targets[0]
	var best_score = -999.0
	
	for target in targets:
		var score = _calculate_target_score(target, player_id, damage_value, is_damage_spell, curse_info)
		if score > best_score:
			best_score = score
			best_target = target
	
	return {"target": best_target, "score": best_score}

## ターゲットスコアを計算
func _calculate_target_score(target: Dictionary, player_id: int, damage_value: int, is_damage_spell: bool, curse_info: Dictionary = {}) -> float:
	var score = 0.0
	
	var tile_index = target.get("tile_index", -1)
	var creature = target.get("creature", {})
	var tile_data = {}
	
	if tile_index >= 0 and board_system:
		tile_data = board_system.get_tile_data(tile_index)
		if tile_data and creature.is_empty():
			creature = tile_data.get("creature", tile_data.get("placed_creature", {}))
	
	if creature.is_empty():
		return score
	
	# 敵クリーチャーかどうか
	var owner_id = -1
	if tile_data:
		owner_id = tile_data.get("owner", tile_data.get("owner_id", -1))
	var is_enemy = owner_id != player_id and owner_id >= 0
	
	if is_enemy:
		score += 1.0
	
	# ダメージスペルの場合
	if is_damage_spell:
		var current_hp = creature.get("current_hp", creature.get("hp", 0))
		
		# 倒せる場合は最優先
		if current_hp > 0 and current_hp <= damage_value:
			score += 200.0
		elif current_hp > 0:
			var damage_ratio = float(damage_value) / float(current_hp)
			score += min(damage_ratio, 1.0)
	
	# 呪い秘術の場合、既存の呪い状態でスコア調整
	if curse_info.get("is_curse", false):
		score += _calculate_curse_overwrite_score(creature, player_id, owner_id, curse_info.get("is_beneficial", false))
	
	# 土地レベル（属性一致の場合のみスコア加算）
	if tile_data and not creature.is_empty():
		var level = tile_data.get("level", 1)
		var tile_element = tile_data.get("element", "")
		var creature_element = creature.get("element", "")
		if tile_element == creature_element or tile_element == "neutral" or creature_element == "neutral":
			score += 30 * level
	
	# クリーチャーのレート
	var creature_rate = 0.0
	if not creature.is_empty():
		var CardRateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
		creature_rate = CardRateEvaluator.get_rate(creature)
		score += creature_rate
	
	# デバッグ: 最終スコア
	var creature_name = creature.get("name", "?")
	var debug_level = tile_data.get("level", 1) if tile_data else 1
	print("[MysticAI] 最終スコア: %s = %.1f (level=%d, rate=%.1f)" % [creature_name, score, debug_level, creature_rate])
	
	return score


## 呪い秘術かどうか判定
func _analyze_curse_mystic(mystic_data: Dictionary) -> Dictionary:
	var result = {"is_curse": false, "is_beneficial": false}
	
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var curse_type = effect.get("curse_type", "")
		
		if effect_type == "creature_curse" or effect_type == "player_curse" or curse_type != "":
			result.is_curse = true
			
			if curse_type in CpuCurseEvaluator.BENEFICIAL_CREATURE_CURSES:
				result.is_beneficial = true
			elif curse_type in CpuCurseEvaluator.HARMFUL_CREATURE_CURSES:
				result.is_beneficial = false
			
			break
	
	return result


## 呪い上書きスコアを計算
func _calculate_curse_overwrite_score(creature: Dictionary, player_id: int, owner_id: int, _spell_is_beneficial: bool) -> float:
	var curse_benefit = CpuCurseEvaluator.get_creature_curse_benefit(creature)
	
	var is_own = (owner_id == player_id)
	var score = 0.0
	
	if curse_benefit != 0:
		if is_own:
			if curse_benefit > 0:
				score = -300.0  # 自分の有利な呪いを消したくない
			else:
				score = 150.0   # 不利な呪いを消したい
		else:
			if curse_benefit > 0:
				score = 150.0   # 敵の有利な呪いを消したい
			else:
				score = -300.0  # 敵の不利な呪いを残したい
	
	# デバッグログ
	var creature_name = creature.get("name", "?")
	print("[MysticAI] 呪いスコア: %s, benefit=%d, is_own=%s, score=%.1f" % [creature_name, curse_benefit, str(is_own), score])
	
	return score

## 旧互換
func _select_best_target(targets: Array, mystic_data: Dictionary, context: Dictionary) -> Dictionary:
	var result = _select_best_target_with_score(targets, mystic_data, context)
	return result.target

## 条件に基づくターゲット取得（スコア付き）
func _get_condition_target_with_score(mystic_data: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var cpu_rule = mystic_data.get("cpu_rule", {})
	var condition = cpu_rule.get("condition", "")
	
	# element_mismatch + creature の場合、スコア計算を使用
	if condition == "element_mismatch" and target_type == "creature":
		var mismatched = condition_checker.check_target_condition("element_mismatch_creatures", context)
		# 自クリーチャーのみフィルタ（防御型・防魔を除外）
		var own_mismatched = []
		for target in mismatched:
			var tile_index = target.get("tile_index", -1)
			if tile_index >= 0 and board_system:
				var tile = board_system.get_tile_data(tile_index)
				if tile and tile.get("owner", tile.get("owner_id", -1)) == context.player_id:
					var creature = target.get("creature", {})
					# 防御型クリーチャーは移動できないので除外
					if _is_defensive_creature(creature):
						continue
					# 防魔チェック
					if SpellProtection.is_creature_protected(creature, _build_world_curse_context()):
						continue
					own_mismatched.append(target)
		
		if own_mismatched.is_empty():
			return {"target": {}, "score": 0.0}
		
		# スコア計算を使用して最適なターゲットを選択
		return _select_best_target_with_score(own_mismatched, mystic_data, context)
	
	# その他の条件は従来通り（スコア0で返す）
	var target = _get_condition_target(mystic_data, context)
	return {"target": target, "score": 0.0}

## 条件に基づくターゲット取得（旧互換）
func _get_condition_target(mystic_data: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var cpu_rule = mystic_data.get("cpu_rule", {})
	var condition = cpu_rule.get("condition", "")
	
	match target_type:
		"self", "none":
			return {"type": "self", "tile_index": context.get("caster_tile", -1)}
		"creature":
			# 属性不一致の場合、属性不一致の自クリーチャーをターゲット（スコア計算使用）
			if condition == "element_mismatch":
				var mismatched = condition_checker.check_target_condition("element_mismatch_creatures", context)
				# 自クリーチャーのみフィルタ（防御型を除外）
				var own_mismatched = []
				for target in mismatched:
					var tile_index = target.get("tile_index", -1)
					if tile_index >= 0 and board_system:
						var tile = board_system.get_tile_data(tile_index)
						if tile and tile.get("owner", tile.get("owner_id", -1)) == context.player_id:
							var creature = target.get("creature", {})
							# 防御型クリーチャーは移動できないので除外
							if not _is_defensive_creature(creature):
								own_mismatched.append(target)
				if not own_mismatched.is_empty():
					# スコア計算を使用して最適なターゲットを選択
					var selection = _select_best_target_with_score(own_mismatched, mystic_data, context)
					return selection.target
				return {}
			# デフォルト
			var targets = _get_default_targets(mystic_data, context)
			if not targets.is_empty():
				return targets[0]
	
	return {"type": "self", "player_id": context.player_id}

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

## 利益計算
func _calculate_profit(formula: String, context: Dictionary) -> int:
	if formula.is_empty():
		return 0
	
	match formula:
		"destroyed_count * 30":
			return context.get("destroyed_count", 0) * 30
		"caster_mhp * 2":
			return context.get("caster_mhp", 0) * 2
		"200 - caster_value":
			# 黄金献身: 200G獲得 - 術者の価値
			return 200  # TODO: 術者価値の計算
		_:
			if "enemy_magic" in formula:
				var enemy_magic = _get_max_enemy_magic(context)
				if "0.1" in formula:
					return int(enemy_magic * 0.1)
			if "enemy_spell_count" in formula:
				var count = _get_enemy_spell_count(context)
				return count * 40
	
	return 0

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

## 敵スペル数取得
func _get_enemy_spell_count(context: Dictionary) -> int:
	if not card_system or not player_system:
		return 0
	
	var player_id = context.player_id
	var total = 0
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			var hand = card_system.get_all_cards_for_player(i)
			for card in hand:
				if card.get("type") == "spell":
					total += 1
	
	return total

## profit_calc用ターゲット取得
func _get_profit_target(mystic_data: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	
	if target_type == "player":
		var enemies = _get_enemy_players(context)
		if not enemies.is_empty():
			return enemies[0]
	
	return {"type": "self", "player_id": context.player_id}

## strategic用ターゲット取得
func _get_strategic_target(mystic_data: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var target_filter = effect_parsed.get("target_filter", "any")
	
	match target_type:
		"player":
			if target_filter == "enemy":
				var enemies = _get_enemy_players(context)
				if not enemies.is_empty():
					return enemies[randi() % enemies.size()]
			return {"type": "self", "player_id": context.player_id}
		"self", "none":
			return {"type": "self", "tile_index": context.get("caster_tile", -1)}
	
	return {"type": "self", "player_id": context.player_id}


## 移動系呪いかどうかをチェック（遠隔移動等）
func _is_movement_curse(mystic_data: Dictionary) -> bool:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		var curse_type = effect.get("curse_type", "")
		if curse_type in ["remote_move", "move_disable"]:
			return true
	
	return false

## 防御型クリーチャーかどうかをチェック（移動不可）
func _is_defensive_creature(creature_data: Dictionary) -> bool:
	# creature_typeで判定
	if creature_data.get("creature_type", "") == "defensive":
		return true
	
	# ability_parsed.keywordsで判定
	var ability_parsed = creature_data.get("ability_parsed", {})
	if ability_parsed:
		var keywords = ability_parsed.get("keywords", [])
		if "防御型" in keywords:
			return true
	
	return false

## 防魔・HP効果無効のクリーチャーをフィルタリング
## 防魔・HP効果無効のクリーチャーをフィルタリング（共通ロジック使用）
func _filter_spell_immune_targets(targets: Array, mystic_data: Dictionary) -> Array:
	var effect_parsed = mystic_data.get("effect_parsed", {})
	
	# 世界呪いコンテキスト構築
	var context = _build_world_curse_context()
	
	var filtered = []
	for target in targets:
		var creature = target.get("creature", {})
		if creature.is_empty():
			filtered.append(target)
			continue
		
		# 防魔チェック（SpellProtection使用）
		if SpellProtection.is_creature_protected(creature, context):
			continue
		
		# HP効果無効チェック（SpellHpImmune使用）
		if SpellHpImmune.should_skip_hp_effect(creature, effect_parsed):
			continue
		
		filtered.append(target)
	
	return filtered

## 世界呪いコンテキストを構築
func _build_world_curse_context() -> Dictionary:
	var context = {}
	if game_flow_manager and "game_stats" in game_flow_manager:
		context["world_curse"] = game_flow_manager.game_stats.get("world_curse", {})
	return context

## タイルがダウン状態かチェック
func _check_tile_is_down(tile_index: int) -> bool:
	if tile_index < 0:
		return false
	if not board_system:
		return false
	if not "tile_nodes" in board_system:
		return false
	if not board_system.tile_nodes.has(tile_index):
		return false
	var tile_node = board_system.tile_nodes[tile_index]
	if tile_node == null:
		return false
	if not tile_node.has_method("is_down"):
		return false
	return tile_node.is_down()
