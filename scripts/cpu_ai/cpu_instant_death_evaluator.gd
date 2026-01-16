# CPU即死スキル評価システム
# 即死スキルを持つクリーチャーの使用判断を担当
#
# 機能:
# - 無効化+即死クリーチャーの優先使用判断
# - 勝てない場合の即死スキルギャンブル判断
# - 即死条件のチェック
#
# 使用例:
#   var evaluator = CPUInstantDeathEvaluator.new()
#   evaluator.setup(hand_utils)
#   var result = evaluator.check_instant_death_gamble(player, creatures, defender)
extends RefCounted
class_name CPUInstantDeathEvaluator

# 手札ユーティリティ参照
var _hand_utils: CPUHandUtils = null


## セットアップ
func setup(hand_utils: CPUHandUtils) -> void:
	_hand_utils = hand_utils


## 無効化+即死クリーチャーを優先使用するかチェック
## 敵が無効化アイテムを持っている場合に呼び出される
func check_nullify_instant_death_priority(current_player, creatures: Array, defender: Dictionary) -> Dictionary:
	var result = {
		"can_use": false,
		"creature_index": -1,
		"creature": {},
		"probability": 0
	}
	
	if not _hand_utils:
		return result
	
	var best_candidate = null
	var best_probability = 0
	
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		
		# コストチェック
		if not _hand_utils.can_afford_card(current_player, creature_index):
			continue
		
		# 無効化スキルを持っているかチェック
		if not has_nullify_skill(creature):
			continue
		
		# 即死スキルを持っているかチェック
		var instant_death_info = get_instant_death_info(creature)
		if instant_death_info.is_empty():
			continue
		
		# 即死条件を満たすかチェック
		if not check_instant_death_condition(instant_death_info, defender):
			continue
		
		var probability = instant_death_info.get("probability", 0)
		print("  [無効化+即死候補] %s: 確率 %d%%" % [creature.get("name", "?"), probability])
		
		# 最も確率が高いクリーチャーを選択
		if probability > best_probability:
			best_probability = probability
			best_candidate = {
				"creature_index": creature_index,
				"creature": creature,
				"probability": probability
			}
	
	if best_candidate:
		result.can_use = true
		result.creature_index = best_candidate.creature_index
		result.creature = best_candidate.creature
		result.probability = best_candidate.probability
	
	return result


## 即死スキルで賭けるかチェック
## 勝てる組み合わせがない場合に、即死スキル持ちで条件を満たすクリーチャーを探す
func check_instant_death_gamble(current_player, creatures: Array, defender: Dictionary) -> Dictionary:
	var result = {
		"can_gamble": false,
		"creature_index": -1,
		"creature": {},
		"probability": 0
	}
	
	if not _hand_utils:
		return result
	
	var best_candidate = null
	var best_probability = 0
	
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		
		# コストチェック
		if not _hand_utils.can_afford_card(current_player, creature_index):
			continue
		
		# 即死スキルをチェック
		var instant_death_info = get_instant_death_info(creature)
		if instant_death_info.is_empty():
			continue
		
		# 即死条件を満たすかチェック
		if not check_instant_death_condition(instant_death_info, defender):
			continue
		
		var probability = instant_death_info.get("probability", 0)
		print("  [即死候補] %s: 確率 %d%%" % [creature.get("name", "?"), probability])
		
		# 最も確率が高いクリーチャーを選択
		if probability > best_probability:
			best_probability = probability
			best_candidate = {
				"creature_index": creature_index,
				"creature": creature,
				"probability": probability
			}
	
	if best_candidate:
		result.can_gamble = true
		result.creature_index = best_candidate.creature_index
		result.creature = best_candidate.creature
		result.probability = best_candidate.probability
	
	return result


## クリーチャーが無効化スキルを持っているかチェック
func has_nullify_skill(creature: Dictionary) -> bool:
	var ability_parsed = creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "無効化" in keywords


## クリーチャーの即死スキル情報を取得
func get_instant_death_info(creature: Dictionary) -> Dictionary:
	var ability_parsed = creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "即死" in keywords:
		return {}
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	if instant_death_condition.is_empty():
		return {}
	
	return instant_death_condition


## 即死条件をCPU側でチェック（攻撃時）
func check_instant_death_condition(condition: Dictionary, defender: Dictionary) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"none", "":
			# 無条件
			return true
		
		"enemy_is_element", "enemy_element":
			# 敵が特定属性
			var defender_element = defender.get("element", "")
			
			# 単一属性
			if condition.has("element"):
				var required_element = condition.get("element", "")
				if required_element == "全":
					return true
				return defender_element == required_element
			
			# 複数属性
			var required_elements = condition.get("elements", [])
			if typeof(required_elements) == TYPE_STRING:
				if required_elements == "全":
					return true
				required_elements = [required_elements]
			
			return defender_element in required_elements
		
		"defender_ap_check":
			# 防御側のAPが一定以上
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			var defender_base_ap = defender.get("ap", 0)
			
			match operator:
				">=": return defender_base_ap >= value
				">": return defender_base_ap > value
				"==": return defender_base_ap == value
				_: return false
		
		"defender_role":
			# 使用者が防御側の時のみ発動（キロネックス）
			# CPUが攻撃側なので、この条件は満たせない
			return false
		
		"後手":
			# 後手条件は先制判定で処理されるため、ここでは常にtrue
			return true
		
		_:
			print("[CPU AI] 未知の即死条件タイプ: ", condition_type)
			return false
