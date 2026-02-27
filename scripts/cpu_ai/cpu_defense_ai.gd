## CPU防御側判断AI
## 防御時のアイテム/加勢/合体の判断を行う
class_name CPUDefenseAI
extends RefCounted

# 定数・共通クラスをpreload
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")
const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")
const CPUBattlePolicyScript = preload("res://scripts/cpu_ai/cpu_battle_policy.gd")

# 共有コンテキスト
var _context: CPUAIContextScript = null

# バトルポリシー（性格）への参照
var battle_policy: CPUBattlePolicyScript = null

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
func setup_with_context(ctx: CPUAIContextScript) -> void:
	_context = ctx

## バトルポリシーを設定
func set_battle_policy(policy: CPUBattlePolicyScript) -> void:
	battle_policy = policy

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
	var tile_index = tile_info.get("index", -1)
	
	print("[CPUDefenseAI] 判断開始: %s vs %s (Lv%d)" % [
		defender.get("name", "?"),
		attacker.get("name", "?"),
		tile_level
	])

	# ポリシー判定：アイテムを使用するかどうか
	var use_items = true  # デフォルトはアイテム使用
	print("[CPUDefenseAI] battle_policy: %s" % (battle_policy != null))
	if battle_policy:
		# 通行料を取得
		var toll = _calculate_toll(tile_index)
		# 防御アイテム数を取得
		var defense_item_count = _count_defense_items_in_hand(player_id)
		
		var policy_context = {
			"defender": defender,
			"tile_info": tile_info,
			"toll": toll,
			"defense_item_count": defense_item_count
		}
		
		var defense_action = battle_policy.decide_defense_action(policy_context)
		
		if defense_action == CPUBattlePolicyScript.DefenseAction.NO_ITEM:
			use_items = false
			print("[CPUDefenseAI] ポリシー判断: アイテム使用しない")
		else:
			print("[CPUDefenseAI] ポリシー判断: アイテム使用可能")
	
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
	var should_avoid_items = enemy_has_steal

	# nullify_item_manipulation チェック - 防御側がnullify持ちなら敵の破壊/盗みは無効
	if cpu_hand_utils and cpu_hand_utils.has_nullify_item_manipulation(defender):
		enemy_destroy_types = []
		enemy_has_steal = false
		should_avoid_items = false
		print("[CPUDefenseAI] 防御側がアイテム破壊/盗み無効スキル持ち → 敵の破壊/盗みを無視")

	if enemy_has_steal:
		print("[CPUDefenseAI] 敵がアイテム盗み持ち → 全アイテム使用不可")
	elif not enemy_destroy_types.is_empty():
		print("[CPUDefenseAI] 敵がアイテム破壊持ち → 対象タイプのみ回避: %s" % str(enemy_destroy_types))
	
	# 4. 即死脅威判定（ポリシーでアイテム使用が許可されている場合のみ）
	var instant_death_check = _check_instant_death_threat(attacker, defender)
	if use_items and not enemy_has_steal and instant_death_check.is_applicable:
		var probability = instant_death_check.probability
		print("[CPUDefenseAI] 敵が即死スキル持ち（%d%%）" % probability)
		
		# 即死確率とタイルレベルに応じて無効化アイテムを検討
		# - 100%即死: 常に使う
		# - 高確率（50%以上）かつLv2以上: 使う
		var should_use_nullify = (
			probability >= 100 or
			(probability >= 50 and tile_level >= 2)
		)
		
		if should_use_nullify:
			var nullify_item = _find_nullify_item_for_defense(player_id, defender, enemy_destroy_types)
			if not nullify_item.is_empty():
				print("[CPUDefenseAI] 無効化アイテム使用: %s（即死%d%% Lv%d）" % [nullify_item.get("name", "?"), probability, tile_level])
				result.action = "item"
				result.item = nullify_item
				return result
			else:
				print("[CPUDefenseAI] 無効化アイテムなし（即死%d%%）" % probability)
			
			if probability >= 100:
				print("[CPUDefenseAI] 100%%即死 & 無効化アイテムなし → パス")
				return result
	
	# 5. ワーストケースシミュレーション
	var worst_result = _simulate_worst_case(defender, attacker, tile_info, attacker_player_id, {})
	var worst_outcome = worst_result.get("result", -1)
	
	print("[CPUDefenseAI] ワーストケース: %s" % _result_to_string(worst_outcome))
	
	# ワーストケースでも勝てる/生き残れる → パス
	# ただし即死スキル持ちの場合は油断しない（即死で負ける可能性がある）
	if worst_outcome == BattleSimulatorScript.BattleResult.DEFENDER_WIN or \
	   worst_outcome == BattleSimulatorScript.BattleResult.ATTACKER_SURVIVED:
		if instant_death_check.is_applicable and instant_death_check.probability >= 50:
			print("[CPUDefenseAI] ワーストケースは安全だが即死リスクあり（%d%%）→ 継続判断" % instant_death_check.probability)
		else:
			print("[CPUDefenseAI] ワーストケースでも安全 → パス")
			return result
	
	# 6. 勝てるアイテム・加勢を探す
	var armor_count = _count_armor_in_hand(player_id)
	
	var item_results = {"normal": [], "reserve": []}
	# ポリシーでアイテム使用が許可されており、敵のアイテム破壊/盗みがない場合のみ検索
	if use_items and not enemy_has_steal:
		item_results = _find_winning_items(player_id, defender, attacker, tile_info, attacker_player_id, worst_outcome, enemy_destroy_types)
	
	var assist_results = _find_winning_assists(player_id, defender, attacker, tile_info, attacker_player_id, worst_outcome)
	
	var winning_items = item_results.normal
	var reserve_items = item_results.reserve
	var winning_assists = assist_results.normal
	var reserve_assists = assist_results.reserve
	
	print("[CPUDefenseAI] 通常アイテム:%d 温存アイテム:%d 通常加勢:%d 温存加勢:%d 防具:%d" % [
		winning_items.size(), reserve_items.size(),
		winning_assists.size(), reserve_assists.size(),
		armor_count
	])
	
	# 7. 優先順位で選択（防具2枚以下 or アイテム使用不可 → 加勢優先）
	if should_avoid_items or armor_count <= 2:
		if not winning_assists.is_empty():
			var best = _select_best_by_cost(winning_assists)
			print("[CPUDefenseAI] 加勢選択: %s" % best.data.get("name", "?"))
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
			print("[CPUDefenseAI] 加勢選択: %s" % best.data.get("name", "?"))
			result.action = "support"
			result.creature = best.data
			result.index = best.index
			return result
	
	# 8. 温存対象（Lv2以上のみ）
	if tile_level >= 2:
		if should_avoid_items or armor_count <= 2:
			if not reserve_assists.is_empty():
				var best = _select_best_by_cost(reserve_assists)
				print("[CPUDefenseAI] 温存加勢使用(Lv%d): %s" % [tile_level, best.data.get("name", "?")])
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
				print("[CPUDefenseAI] 温存加勢使用(Lv%d): %s" % [tile_level, best.data.get("name", "?")])
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
	return cpu_hand_utils.attacker_has_item_destroy(attacker)

func _attacker_has_item_steal(attacker: Dictionary) -> bool:
	return cpu_hand_utils.attacker_has_item_steal(attacker)

#endregion

#region 即死脅威判定

func _check_instant_death_threat(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var result = { "is_applicable": false, "probability": 0 }
	
	var ability_parsed = attacker.get("ability_parsed", {})
	
	# 1. keywordsで即死を持っているかチェック
	var keywords = ability_parsed.get("keywords", [])
	if "即死" in keywords:
		var keyword_conditions = ability_parsed.get("keyword_conditions", {})
		var instant_death_condition = keyword_conditions.get("即死", {})
		
		if not instant_death_condition.is_empty():
			# 条件をチェック
			if _check_instant_death_keyword_condition(instant_death_condition, defender):
				result.is_applicable = true
				result.probability = instant_death_condition.get("probability", 100)
				return result
	
	# 2. effectsで即死を持っているかチェック（旧形式との互換）
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


## keyword_conditions形式の即死条件をチェック
func _check_instant_death_keyword_condition(condition: Dictionary, defender: Dictionary) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"none", "":
			return true
		
		"defender_ap_check":
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			var defender_ap = defender.get("ap", 0)
			
			match operator:
				">=": return defender_ap >= value
				">": return defender_ap > value
				"<=": return defender_ap <= value
				"<": return defender_ap < value
				"==": return defender_ap == value
				_: return false
		
		"enemy_is_element", "enemy_element":
			var defender_element = defender.get("element", "")
			if condition.has("element"):
				var required = condition.get("element", "")
				if required == "全":
					return true
				return defender_element == required
			var required_elements = condition.get("elements", [])
			if typeof(required_elements) == TYPE_STRING:
				if required_elements == "全":
					return true
				required_elements = [required_elements]
			return defender_element in required_elements
		
		"defender_role":
			# 攻撃時は発動しない（防御時のみ）
			return false
		
		_:
			return true

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

func _find_nullify_item_for_defense(player_id: int, defender: Dictionary = {}, enemy_destroy_types: Array = []) -> Dictionary:
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

		# 敵のアイテム破壊対象なら破壊対象以外で探す（nullify_item_manipulation持ちアイテムは除外しない）
		if not enemy_destroy_types.is_empty() and cpu_hand_utils and cpu_hand_utils.is_item_destroy_target(card, enemy_destroy_types):
			if not cpu_hand_utils.has_nullify_item_manipulation({}, card):
				continue

		# cannot_use制限チェック（リリース刻印で解除可能）
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

	# nullify_item_manipulation チェック - 防御側がnullify持ちなら敵のアイテム破壊は無効
	var defender_has_nullify = cpu_hand_utils.has_nullify_item_manipulation(defender, defender_item) if cpu_hand_utils else false

	# 各アイテムでシミュレーションしてワーストを探す
	for item in attacker_items:
		# 攻撃側クリーチャーのcannot_use制限をチェック（リリース刻印で解除可能）
		if not disable_cannot_use and not _is_item_restriction_released(attacker_player_id):
			var check_result = ItemUseRestriction.check_can_use(attacker, item)
			if not check_result.can_use:
				continue

		# 攻撃側アイテムが防御側アイテムを破壊するかチェック（nullify持ちなら無視）
		var effective_defender_item = defender_item
		if not defender_has_nullify and not defender_item.is_empty():
			var destroy_effect = cpu_hand_utils.get_item_destroy_effect(item)
			if not destroy_effect.is_empty():
				var target_types = destroy_effect.get("target_types", [])
				var rarity_exclude = destroy_effect.get("rarity_exclude", [])
				if cpu_hand_utils.is_item_destroy_target(defender_item, target_types, rarity_exclude):
					effective_defender_item = {}

		var result = battle_simulator.simulate_battle(
			attacker, defender, sim_tile_info, attacker_player_id, item, effective_defender_item
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

#region アイテム/加勢検索

func _find_winning_items(player_id: int, defender: Dictionary, attacker: Dictionary, tile_info: Dictionary, attacker_player_id: int, current_outcome: int, enemy_destroy_types: Array = []) -> Dictionary:
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

		# 敵のアイテム破壊対象ならスキップ（nullify_item_manipulation持ちアイテムは除外しない）
		if not enemy_destroy_types.is_empty() and cpu_hand_utils and cpu_hand_utils.is_item_destroy_target(card, enemy_destroy_types):
			if not cpu_hand_utils.has_nullify_item_manipulation({}, card):
				print("[CPUDefenseAI] %s は破壊対象のためスキップ" % card.get("name", "?"))
				continue

		# cannot_use制限チェック（リリース刻印で解除可能）
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
	
	# 加勢スキルチェック
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
		
		# 加勢対象属性チェック
		var element = card.get("element", "")
		if not target_elements.is_empty() and not "all" in target_elements:
			if not element in target_elements:
				continue
		
		var cost = _get_creature_cost(card)
		if cost > current_player.magic_power:
			continue
		
		# 加勢を適用した防御側でシミュレーション
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
	return keyword_conditions.has("加勢")

func _get_assist_target_elements(creature: Dictionary) -> Array:
	var ability_parsed = creature.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var assist_info = keyword_conditions.get("加勢", {})
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
		return cost_data.get("ep", 0)
	return cost_data

func _get_creature_cost(creature: Dictionary) -> int:
	var cost_data = creature.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("ep", 0)
	return cost_data

func _select_best_by_cost(entries: Array) -> Dictionary:
	if entries.is_empty():
		return {}
	
	var CardRateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
	
	# レートが低いものを優先（価値の低いカードを加勢に使う）
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



## リリース刻印によるアイテム解放をチェック
func _is_item_restriction_released(player_id: int) -> bool:
	if not player_system or player_id < 0 or player_id >= player_system.players.size():
		return false
	var player = player_system.players[player_id]
	var player_dict = {"curse": player.curse}
	return SpellRestriction.is_item_restriction_released(player_dict)

## 通行料を計算
func _calculate_toll(tile_index: int) -> int:
	if tile_index < 0 or not board_system:
		return 0
	
	# 刻印補正込みの通行料を返す
	if board_system:
		return board_system.calculate_toll_with_curse(tile_index)
	
	return 0

## 防御アイテム（防具・アクセサリ）の数をカウント
func _count_defense_items_in_hand(player_id: int) -> int:
	if not card_system:
		return 0
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var count = 0
	for card in hand:
		if card.get("type", "") == "item":
			var item_type = card.get("item_type", "")
			if item_type in ["防具", "アクセサリ"]:
				count += 1
	return count

