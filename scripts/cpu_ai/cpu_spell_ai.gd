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

## 優先度の数値変換
const PRIORITY_VALUES = {
	"high": 3.0,
	"medium_high": 2.5,
	"medium": 2.0,
	"low": 1.0,
	"very_low": 0.5
}

## 初期化
func initialize(b_system: Node, p_system: Node, c_system: Node, cr_manager: Node) -> void:
	board_system = b_system
	player_system = p_system
	card_system = c_system
	creature_manager = cr_manager
	
	# 条件チェッカー初期化
	condition_checker = CPUSpellConditionChecker.new()
	condition_checker.initialize(b_system, p_system, c_system, cr_manager)

## スペル使用判断のメインエントリ
## 戻り値: {use: bool, spell: Dictionary, target: Dictionary} または null
func decide_spell(player_id: int) -> Dictionary:
	print("[CPU Spell AI] decide_spell開始: Player%d" % (player_id + 1))
	
	if not card_system or not player_system:
		print("[CPU Spell AI] エラー: card_system または player_system が未設定")
		return {"use": false}
	
	# 使用可能なスペルを取得
	var usable_spells = _get_usable_spells(player_id)
	print("[CPU Spell AI] 使用可能スペル: %d枚" % usable_spells.size())
	for s in usable_spells:
		print("  - %s (pattern: %s)" % [s.get("name", "?"), s.get("cpu_rule", {}).get("pattern", "none")])
	
	if usable_spells.is_empty():
		print("[CPU Spell AI] 使用可能なスペルなし")
		return {"use": false}
	
	# コンテキスト作成
	var context = _build_context(player_id)
	
	# 各スペルを評価
	var evaluated_spells = []
	for spell in usable_spells:
		var evaluation = _evaluate_spell(spell, context)
		print("[CPU Spell AI] 評価: %s → should_use=%s, score=%.1f" % [spell.get("name", "?"), evaluation.should_use, evaluation.score])
		if evaluation.should_use:
			evaluated_spells.append({
				"spell": spell,
				"score": evaluation.score,
				"target": evaluation.target
			})
	
	print("[CPU Spell AI] 使用候補: %d件" % evaluated_spells.size())
	for e in evaluated_spells:
		print("  - %s (score: %.1f)" % [e.spell.get("name", "?"), e.score])
	
	if evaluated_spells.is_empty():
		print("[CPU Spell AI] 使用すべきスペルなし")
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
func _evaluate_immediate(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
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
	var effect_parsed = spell.get("effect_parsed", {})
	
	print("[has_target] スペル: %s" % spell.get("name", "?"))
	print("[has_target] target_condition: '%s'" % target_condition)
	print("[has_target] effect_parsed: %s" % effect_parsed)
	
	var targets = []
	
	# ダメージ値をcontextに追加
	var damage_value = _get_damage_value(spell)
	if damage_value > 0:
		context["damage_value"] = damage_value
	print("[has_target] damage_value: %d" % damage_value)
	
	if target_condition:
		print("[has_target] condition_checker.check_target_condition呼び出し")
		targets = condition_checker.check_target_condition(target_condition, context)
	else:
		print("[has_target] _get_default_targets呼び出し")
		targets = _get_default_targets(spell, context)
	
	print("[has_target] targets数: %d" % targets.size())
	
	if targets.is_empty():
		print("[has_target] ターゲットなし → 使用しない")
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 最適なターゲットを選択（スコア付き）
	var selection = _select_best_target_with_score(targets, spell, context)
	var best_target = selection.target
	var target_score = selection.score
	
	# ダメージ系スペルでターゲットを倒せる場合、優先度を上げる
	var adjusted_score = base_score
	if damage_value > 0 and target_score >= 3.0:
		# 倒せるターゲットがいる場合はスコアを1.5倍
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
	
	# 条件チェック
	if not condition_checker.check_condition(condition, context):
		return {"should_use": false, "score": 0.0, "target": null}
	
	# 条件を満たした場合、ターゲットを取得
	var target = _get_condition_target(spell, context)
	
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
	var cost = _get_spell_cost(spell)
	
	# 利益を計算
	var profit = _calculate_profit(profit_formula, context)
	
	# コストより利益が大きければ使用
	if profit <= cost:
		return {"should_use": false, "score": 0.0, "target": null}
	
	# スコアを利益率で調整
	var profit_ratio = float(profit) / float(cost) if cost > 0 else 1.0
	var adjusted_score = base_score * min(profit_ratio, 2.0)
	
	var target = _get_profit_target(spell, context)
	
	return {
		"should_use": true,
		"score": adjusted_score,
		"target": target
	}

## パターン: strategic（戦略的判断）
func _evaluate_strategic(spell: Dictionary, context: Dictionary, base_score: float) -> Dictionary:
	# TODO: 複雑な戦略的判断
	# 現時点では低確率で使用
	if randf() < 0.3:
		var target = _get_strategic_target(spell, context)
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
		"hand_count": 0,
		"lap_count": 0,
		"rank": 1,
		"destroyed_count": 0
	}
	
	if card_system:
		var hand = card_system.get_all_cards_for_player(player_id)
		context.hand_count = hand.size()
	
	if player_system:
		if player_id >= 0 and player_id < player_system.players.size():
			var player = player_system.players[player_id]
			if player:
				context.lap_count = player.lap_count if "lap_count" in player else 0
				context.destroyed_count = player.destroyed_count if "destroyed_count" in player else 0
		context.rank = _get_player_rank(player_id)
	
	return context

## スペルコスト取得
func _get_spell_cost(spell: Dictionary) -> int:
	var cost_data = spell.get("cost", {})
	return cost_data.get("mp", 0)

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
func _select_best_target_with_score(targets: Array, spell: Dictionary, context: Dictionary) -> Dictionary:
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
	
	match target_type:
		"self", "none":
			return {"type": "self", "player_id": context.player_id}
		"own_land":
			var lands = _get_land_targets("own", context)
			if not lands.is_empty():
				return lands[0]
		"creature":
			var targets = _get_default_targets(spell, context)
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
	if not player_system:
		return 0
	
	var player_id = context.player_id
	var my_lap = context.get("lap_count", 0)
	var max_enemy_lap = 0
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id and i < player_system.players.size():
			var player = player_system.players[i]
			if player:
				max_enemy_lap = max(max_enemy_lap, player.lap_count if "lap_count" in player else 0)
	
	return max_enemy_lap - my_lap

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
