## CPU防御側判断AI
## 防御時のアイテム/援護/合体の判断を行う
class_name CPUDefenseAI
extends RefCounted

# 定数・共通クラスをpreload
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")
const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")

# 共有コンテキスト
var _context: CPUAIContextScript = null

# システム参照のgetter（contextから取得）
var card_system: CardSystem:
	get: return _context.card_system if _context else null
var player_system: PlayerSystem:
	get: return _context.player_system if _context else null
var game_flow_manager:
	get: return _context.game_flow_manager if _context else null
var board_system:
	get: return _context.board_system if _context else null
var tile_action_processor:
	get: return _context.tile_action_processor if _context else null
var battle_simulator: BattleSimulatorScript:
	get: return _context.get_battle_simulator() if _context else null
var cpu_hand_utils: CPUHandUtils:
	get: return _context.get_hand_utils() if _context else null

var merge_evaluator: CPUMergeEvaluator


## 共有コンテキストでセットアップ
func setup_with_context(context: CPUAIContextScript) -> void:
	_context = context


func set_merge_evaluator(evaluator: CPUMergeEvaluator) -> void:
	merge_evaluator = evaluator

## 防御アクションを決定
## @param context: {
##   player_id: int,
##   defender_creature: Dictionary,
##   attacker_creature: Dictionary,
##   tile_info: Dictionary,
##   attacker_player_id: int
## }
## @return: { action: "item"|"support"|"merge"|"pass", item: Dictionary, creature: Dictionary, merge_data: Dictionary }
func decide_defense_action(defense_context: Dictionary) -> Dictionary:
	var result = { "action": "pass" }
	
	var player_id = defense_context.get("player_id", 0)
	var defender = defense_context.get("defender_creature", {})
	var attacker = defense_context.get("attacker_creature", {})
	var tile_info = defense_context.get("tile_info", {})
	var attacker_player_id = defense_context.get("attacker_player_id", -1)
	var tile_level = tile_info.get("level", 1)
	
	print("[CPUDefenseAI] 判断開始: %s vs %s (Lv%d)" % [
		defender.get("name", "?"),
		attacker.get("name", "?"),
		tile_level
	])
	
	# 1. 無効化スキルで勝てるか判定
	if _should_skip_due_to_nullify(defender, attacker, tile_info, attacker_player_id):
		print("[CPUDefenseAI] 無効化スキルで勝てる → パス")
		return result
	
	# 2. 合体判断（最優先）
	var merge_result = _evaluate_merge_option(player_id, defender, attacker, tile_info, attacker_player_id)
	if merge_result.can_merge and merge_result.wins:
		print("[CPUDefenseAI] 合体で勝利可能 → %s" % merge_result.result_name)
		result.action = "merge"
		result.merge_data = merge_result
		return result
	
	# 3. 敵がアイテム破壊・盗みを持っているか
	var enemy_destroy_types = _get_attacker_item_destroy_types(attacker)
	var enemy_has_steal = _attacker_has_item_steal(attacker)
	var should_avoid_items = not enemy_destroy_types.is_empty() or enemy_has_steal
	
	if should_avoid_items:
		print("[CPUDefenseAI] 敵がアイテム破壊/盗み持ち → アイテム使用不可")
	
	# 4. 即死脅威判定
	var instant_death_check = _check_instant_death_threat(attacker, defender)
	if not should_avoid_items and instant_death_check.is_applicable:
		var probability = instant_death_check.probability
		print("[CPUDefenseAI] 敵が即死スキル持ち（%d%%）" % probability)
		
		if probability >= 100 or tile_level >= 2:
			var nullify_item = _find_nullify_item_for_defense(player_id, defender)
			if not nullify_item.is_empty():
				print("[CPUDefenseAI] 無効化アイテム使用: %s" % nullify_item.get("name", "?"))
				result.action = "item"
				result.item = nullify_item
				return result
			
			if probability >= 100:
				print("[CPUDefenseAI] 100%%即死 & 無効化アイテムなし → パス")
				return result
	
	# 5. ワーストケースシミュレーション
	var worst_result = _simulate_worst_case(defender, attacker, tile_info, attacker_player_id, {})
	var worst_outcome = worst_result.get("result", -1)
	
	print("[CPUDefenseAI] ワーストケース: %s" % _result_to_string(worst_outcome))
	
	# ワーストケースでも勝てる/生き残れる → パス
	if worst_outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN or \
	   worst_outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		print("[CPUDefenseAI] ワーストケースでも安全 → パス")
		return result
	
	# 6. 勝てるアイテム・援護を探す
	var armor_count = _count_armor_in_hand(player_id)
	
	var item_results = {"normal": [], "reserve": []}
	if not should_avoid_items:
		item_results = _find_winning_items(player_id, defender, attacker, tile_info, attacker_player_id, worst_outcome)
	
	var assist_results = _find_winning_assists(player_id, defender, attacker, tile_info, attacker_player_id, worst_outcome)
	
	var winning_items = item_results.normal
	var reserve_items = item_results.reserve
	var winning_assists = assist_results.normal
	var reserve_assists = assist_results.reserve
	
	print("[CPUDefenseAI] 通常アイテム:%d 温存アイテム:%d 通常援護:%d 温存援護:%d 防具:%d" % [
		winning_items.size(), reserve_items.size(),
		winning_assists.size(), reserve_assists.size(),
		armor_count
	])
	
	# 7. 優先順位で選択（防具2枚以下 or アイテム使用不可 → 援護優先）
	if should_avoid_items or armor_count <= 2:
		if not winning_assists.is_empty():
			var best = _select_best_by_cost(winning_assists)
			print("[CPUDefenseAI] 援護選択: %s" % best.data.get("name", "?"))
			result.action = "support"
			result.creature = best.data
			result.index = best.index
			return result
		if not should_avoid_items and not winning_items.is_empty():
			var best = _select_best_defense_item(winning_items)
			print("[CPUDefenseAI] アイテム選択: %s" % best.data.get("name", "?"))
			result.action = "item"
			result.item = best.data
			return result
	else:
		if not winning_items.is_empty():
			var best = _select_best_defense_item(winning_items)
			print("[CPUDefenseAI] アイテム選択: %s" % best.data.get("name", "?"))
			result.action = "item"
			result.item = best.data
			return result
		if not winning_assists.is_empty():
			var best = _select_best_by_cost(winning_assists)
			print("[CPUDefenseAI] 援護選択: %s" % best.data.get("name", "?"))
			result.action = "support"
			result.creature = best.data
			result.index = best.index
			return result
	
	# 8. 温存対象（Lv2以上のみ）
	if tile_level >= 2:
		if should_avoid_items or armor_count <= 2:
			if not reserve_assists.is_empty():
				var best = _select_best_by_cost(reserve_assists)
				print("[CPUDefenseAI] 温存援護使用(Lv%d): %s" % [tile_level, best.data.get("name", "?")])
				result.action = "support"
				result.creature = best.data
				result.index = best.index
				return result
			if not should_avoid_items and not reserve_items.is_empty():
				var best = _select_best_defense_item(reserve_items)
				print("[CPUDefenseAI] 温存アイテム使用(Lv%d): %s" % [tile_level, best.data.get("name", "?")])
				result.action = "item"
				result.item = best.data
				return result
		else:
			if not reserve_items.is_empty():
				var best = _select_best_defense_item(reserve_items)
				print("[CPUDefenseAI] 温存アイテム使用(Lv%d): %s" % [tile_level, best.data.get("name", "?")])
				result.action = "item"
				result.item = best.data
				return result
			if not reserve_assists.is_empty():
				var best = _select_best_by_cost(reserve_assists)
				print("[CPUDefenseAI] 温存援護使用(Lv%d): %s" % [tile_level, best.data.get("name", "?")])
				result.action = "support"
				result.creature = best.data
				result.index = best.index
				return result
	
	print("[CPUDefenseAI] 有効な手段なし → パス")
	return result

#region 無効化判定

func _should_skip_due_to_nullify(defender: Dictionary, attacker: Dictionary, tile_info: Dictionary, attacker_player_id: int) -> bool:
	if not battle_simulator:
		return false
	
	# 無効化スキルチェック
	var ability_parsed = defender.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	var has_nullify = false
	for effect in effects:
		if effect.get("effect_type") == "nullify":
			has_nullify = true
			break
	
	if not has_nullify:
		return false
	
	# シミュレーションで確認
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", -1),
		"tile_index": tile_info.get("index", -1)
	}
	
	var sim_result = battle_simulator.simulate_battle(
		attacker, defender, sim_tile_info, attacker_player_id, {}, {}
	)
	
	if sim_result.get("is_nullified", false):
		var outcome = sim_result.get("result", -1)
		if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			return true
	
	return false

#endregion

#region 合体判定

func _evaluate_merge_option(player_id: int, defender: Dictionary, attacker: Dictionary, tile_info: Dictionary, attacker_player_id: int) -> Dictionary:
	var result = {
		"can_merge": false,
		"wins": false,
		"partner_index": -1,
		"partner_data": {},
		"result_id": -1,
		"result_name": "",
		"cost": 0
	}
	
	if not SkillMerge.has_merge_skill(defender):
		return result
	
	if not card_system:
		return result
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var partner_index = SkillMerge.find_merge_partner_in_hand(defender, hand)
	if partner_index == -1:
		return result
	
	var current_player = player_system.players[player_id] if player_system else null
	if not current_player:
		return result
	
	var partner_data = hand[partner_index]
	var cost = SkillMerge.get_merge_cost(hand, partner_index)
	
	if cost > current_player.magic_power:
		return result
	
	var result_id = SkillMerge.get_merge_result_id(defender)
	var result_creature = {}
	if card_system:
		result_creature = card_system.get_card_by_id(result_id)
	
	if result_creature.is_empty():
		return result
	
	result.can_merge = true
	result.partner_index = partner_index
	result.partner_data = partner_data
	result.result_id = result_id
	result.result_name = result_creature.get("name", "?")
	result.cost = cost
	
	# 合体後シミュレーション
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": player_id,
		"tile_index": tile_info.get("index", -1)
	}
	
	var sim_result = battle_simulator.simulate_battle(
		attacker, result_creature, sim_tile_info, attacker_player_id, {}, {}
	)
	
	var outcome = sim_result.get("result", -1)
	if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN or \
	   outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		result.wins = true
	
	return result

#endregion

#region アイテム破壊/盗み判定

func _get_attacker_item_destroy_types(attacker: Dictionary) -> Array:
	var ability_parsed = attacker.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				return effect.get("target_types", [])
	
	return []

func _attacker_has_item_steal(attacker: Dictionary) -> bool:
	var ability_parsed = attacker.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "steal_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				return true
	
	return false

#endregion

#region 即死脅威判定

func _check_instant_death_threat(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var result = { "is_applicable": false, "probability": 0 }
	
	var ability_parsed = attacker.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "instant_death":
			var triggers = effect.get("triggers", [])
			if "on_attack" in triggers or "before_battle" in triggers:
				var probability = effect.get("probability", 100)
				
				# 条件チェック
				var conditions = effect.get("conditions", {})
				if not _check_instant_death_conditions(conditions, defender):
					continue
				
				result.is_applicable = true
				result.probability = probability
				break
	
	return result

func _check_instant_death_conditions(conditions: Dictionary, defender: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	
	# 属性条件
	var element_condition = conditions.get("element", "")
	if not element_condition.is_empty():
		var defender_element = defender.get("element", "")
		if element_condition != defender_element:
			return false
	
	# AP条件
	var ap_condition = conditions.get("ap_less_than", 0)
	if ap_condition > 0:
		var defender_ap = defender.get("ap", 0)
		if defender_ap >= ap_condition:
			return false
	
	return true

func _find_nullify_item_for_defense(player_id: int, defender: Dictionary = {}) -> Dictionary:
	if not card_system:
		return {}
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var current_player = player_system.players[player_id] if player_system else null
	if not current_player:
		return {}
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	
	for card in hand:
		if card.get("type", "") != "item":
			continue
		
		var cost = _get_item_cost(card)
		if cost > current_player.magic_power:
			continue
		
		# cannot_use制限チェック（リリース呪いで解除可能）
		if not disable_cannot_use and not defender.is_empty() and not _is_item_restriction_released(player_id):
			var check_result = ItemUseRestriction.check_can_use(defender, card)
			if not check_result.can_use:
				continue
		
		var effect_parsed = card.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type") == "nullify":
				var nullify_type = effect.get("nullify_type", "")
				if nullify_type == "normal_attack":
					var reduction_rate = effect.get("reduction_rate", 0.0)
					if reduction_rate == 0.0:
						return card
	
	return {}

#endregion

#region ワーストケースシミュレーション

func _simulate_worst_case(defender: Dictionary, attacker: Dictionary, tile_info: Dictionary, attacker_player_id: int, defender_item: Dictionary) -> Dictionary:
	if not battle_simulator:
		return {}
	
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", -1),
		"tile_index": tile_info.get("index", -1)
	}
	
	# まずアイテムなしでシミュレーション
	var worst_result = battle_simulator.simulate_battle(
		attacker, defender, sim_tile_info, attacker_player_id, {}, defender_item
	)
	
	# 攻撃側アイテムを取得
	if not cpu_hand_utils or attacker_player_id < 0:
		return worst_result
	
	var attacker_items = cpu_hand_utils.get_enemy_items(attacker_player_id)
	if attacker_items.is_empty():
		return worst_result
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	
	# 各アイテムでシミュレーションしてワーストを探す
	for item in attacker_items:
		# 攻撃側クリーチャーのcannot_use制限をチェック（リリース呪いで解除可能）
		if not disable_cannot_use and not _is_item_restriction_released(attacker_player_id):
			var check_result = ItemUseRestriction.check_can_use(attacker, item)
			if not check_result.can_use:
				continue
		
		var result = battle_simulator.simulate_battle(
			attacker, defender, sim_tile_info, attacker_player_id, item, defender_item
		)
		if _is_worse_for_defender(result, worst_result):
			worst_result = result
	
	return worst_result

func _is_worse_for_defender(result_a: Dictionary, result_b: Dictionary) -> bool:
	var outcome_a = result_a.get("result", -1)
	var outcome_b = result_b.get("result", -1)
	
	if outcome_b == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
		if outcome_a != BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			return true
	
	if outcome_b == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		if outcome_a == BattleSimulatorScript.BattleResult.ATTACKER_WIN:
			return true
	
	return false

#endregion

#region アイテム/援護検索

func _find_winning_items(player_id: int, defender: Dictionary, attacker: Dictionary, tile_info: Dictionary, attacker_player_id: int, current_outcome: int) -> Dictionary:
	var result = { "normal": [], "reserve": [] }
	
	if not card_system:
		return result
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var current_player = player_system.players[player_id] if player_system else null
	if not current_player:
		return result
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") != "item":
			continue
		
		# 巻物は防御時使用しない
		if card.get("item_type", "") == "巻物":
			continue
		
		# cannot_use制限チェック（リリース呪いで解除可能）
		if not disable_cannot_use and not _is_item_restriction_released(player_id):
			var check_result = ItemUseRestriction.check_can_use(defender, card)
			if not check_result.can_use:
				continue
		
		var cost = _get_item_cost(card)
		if cost > current_player.magic_power:
			continue
		
		var sim_result = _simulate_worst_case(defender, attacker, tile_info, attacker_player_id, card)
		var outcome = sim_result.get("result", -1)
		
		var is_reserve = _is_reserve_item(card)
		var entry = { "index": i, "data": card, "cost": cost }
		
		if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			if is_reserve:
				result.reserve.append(entry)
			else:
				result.normal.append(entry)
		elif outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
			if current_outcome == BattleSimulatorScript.BattleResult.ATTACKER_WIN or \
			   current_outcome == BattleSimulatorScript.BattleResult.BOTH_DEFEATED:
				if is_reserve:
					result.reserve.append(entry)
				else:
					result.normal.append(entry)
	
	return result

func _find_winning_assists(player_id: int, defender: Dictionary, attacker: Dictionary, tile_info: Dictionary, attacker_player_id: int, current_outcome: int) -> Dictionary:
	var result = { "normal": [], "reserve": [] }
	
	# 援護スキルチェック
	if not _has_assist_skill(defender):
		return result
	
	if not card_system:
		return result
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var current_player = player_system.players[player_id] if player_system else null
	if not current_player:
		return result
	
	var target_elements = _get_assist_target_elements(defender)
	
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") != "creature":
			continue
		
		# 援護対象属性チェック
		var element = card.get("element", "")
		if not target_elements.is_empty() and not "all" in target_elements:
			if not element in target_elements:
				continue
		
		var cost = _get_creature_cost(card)
		if cost > current_player.magic_power:
			continue
		
		# 援護を適用した防御側でシミュレーション
		var defender_with_assist = defender.duplicate(true)
		defender_with_assist["ap"] = defender_with_assist.get("ap", 0) + card.get("ap", 0)
		defender_with_assist["hp"] = defender_with_assist.get("hp", 0) + card.get("hp", 0)
		
		var sim_result = _simulate_worst_case(defender_with_assist, attacker, tile_info, attacker_player_id, {})
		var outcome = sim_result.get("result", -1)
		
		var is_reserve = _is_reserve_creature(card)
		var entry = { "index": i, "data": card, "cost": cost }
		
		if outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			if is_reserve:
				result.reserve.append(entry)
			else:
				result.normal.append(entry)
		elif outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
			if current_outcome == BattleSimulatorScript.BattleResult.ATTACKER_WIN or \
			   current_outcome == BattleSimulatorScript.BattleResult.BOTH_DEFEATED:
				if is_reserve:
					result.reserve.append(entry)
				else:
					result.normal.append(entry)
	
	return result

func _has_assist_skill(creature: Dictionary) -> bool:
	var ability_parsed = creature.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	return keyword_conditions.has("援護")

func _get_assist_target_elements(creature: Dictionary) -> Array:
	var ability_parsed = creature.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var assist_info = keyword_conditions.get("援護", {})
	return assist_info.get("target_elements", [])

#endregion

#region 温存対象判定

func _is_reserve_item(item: Dictionary) -> bool:
	var effect_parsed = item.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("trigger") == "on_death":
			var effect_type = effect.get("effect_type", "")
			if effect_type in ["instant_death", "damage_enemy"]:
				return true
	
	return false

func _is_reserve_creature(creature: Dictionary) -> bool:
	var ability_parsed = creature.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("trigger") == "on_death":
			var effect_type = effect.get("effect_type", "")
			if effect_type in ["instant_death", "damage_enemy"]:
				return true
	
	return false

#endregion

#region ユーティリティ

func _count_armor_in_hand(player_id: int) -> int:
	if not card_system:
		return 0
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var count = 0
	for card in hand:
		if card.get("type", "") == "item" and card.get("item_type", "") == "防具":
			count += 1
	return count

func _get_item_cost(item: Dictionary) -> int:
	var cost_data = item.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	return cost_data

func _get_creature_cost(creature: Dictionary) -> int:
	var cost_data = creature.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	return cost_data

func _select_best_by_cost(entries: Array) -> Dictionary:
	if entries.is_empty():
		return {}
	
	var CardRateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
	
	# レートが低いものを優先（価値の低いカードを援護に使う）
	entries.sort_custom(func(a, b):
		var rate_a = CardRateEvaluator.get_rate(a.data)
		var rate_b = CardRateEvaluator.get_rate(b.data)
		return rate_a < rate_b
	)
	
	return entries[0]

func _select_best_defense_item(entries: Array) -> Dictionary:
	if entries.is_empty():
		return {}
	
	entries.sort_custom(func(a, b):
		var priority_a = _get_defense_item_priority(a.data.get("item_type", ""))
		var priority_b = _get_defense_item_priority(b.data.get("item_type", ""))
		
		if priority_a != priority_b:
			return priority_a < priority_b
		
		return a.cost < b.cost
	)
	
	return entries[0]

func _get_defense_item_priority(item_type: String) -> int:
	match item_type:
		"防具": return 0
		"アクセサリ": return 1
		"武器": return 2
		_: return 99

func _result_to_string(result: int) -> String:
	match result:
		BattleSimulatorScript.BattleResult.ATTACKER_WIN:
			return "攻撃側勝利"
		BattleSimulatorScript.BattleResult.DEFENDER_WIN:
			return "防御側勝利"
		BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
			return "両者生存"
		BattleSimulatorScript.BattleResult.BOTH_DEFEATED:
			return "相打ち"
		_:
			return "不明"

#endregion



## リリース呪いによるアイテム制限解除をチェック
func _is_item_restriction_released(player_id: int) -> bool:
	if not player_system or player_id < 0 or player_id >= player_system.players.size():
		return false
	var player = player_system.players[player_id]
	var player_dict = {"curse": player.curse}
	return SpellRestriction.is_item_restriction_released(player_dict)
