extends Node
class_name BattleSpecialEffects

# バトル特殊効果処理
# 即死、無効化、再生などの特殊スキル処理を担当

var board_system_ref = null

func setup_systems(board_system):
	board_system_ref = board_system

## 無効化判定を行う
func check_nullify(attacker: BattleParticipant, defender: BattleParticipant, context: Dictionary) -> Dictionary:
	"""
	無効化判定を行う
	
	Returns:
		{
			"is_nullified": bool,  # 無効化されたか
			"reduction_rate": float  # 軽減率（0.0=完全無効化、0.5=50%軽減、1.0=無効化なし）
		}
	"""
	var ability_parsed = defender.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "無効化" in keywords:
		return {"is_nullified": false, "reduction_rate": 1.0}
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var nullify_condition = keyword_conditions.get("無効化", {})
	
	if nullify_condition.is_empty():
		return {"is_nullified": false, "reduction_rate": 1.0}
	
	# 条件付き無効化の場合、先に条件をチェック
	var conditions = nullify_condition.get("conditions", [])
	if conditions.size() > 0:
		print("  【無効化条件チェック】条件数: ", conditions.size())
		var condition_checker = load("res://scripts/skills/condition_checker.gd").new()
		for condition in conditions:
			var condition_type = condition.get("condition_type", "")
			print("    条件タイプ: ", condition_type)
			if condition_type == "land_level_check":
				print("    土地レベル: ", context.get("tile_level", 1), 
					  " ", condition.get("operator", ">="), " ", condition.get("value", 1))
			if not condition_checker._evaluate_single_condition(condition, context):
				print("    → 条件不成立、無効化発動せず")
				return {"is_nullified": false, "reduction_rate": 1.0}
		print("    → 全条件成立")
	
	# 無効化タイプ別の判定
	var nullify_type = nullify_condition.get("nullify_type", "")
	var is_nullified = false
	
	match nullify_type:
		"element":
			is_nullified = _check_nullify_element(nullify_condition, attacker)
		"mhp_above":
			is_nullified = _check_nullify_mhp_above(nullify_condition, attacker)
		"mhp_below":
			is_nullified = _check_nullify_mhp_below(nullify_condition, attacker)
		"st_below":
			is_nullified = _check_nullify_st_below(nullify_condition, attacker)
		"st_above":
			is_nullified = _check_nullify_st_above(nullify_condition, attacker)
		"all_attacks":
			is_nullified = true  # 無条件で適用
		"has_ability":
			is_nullified = _check_nullify_has_ability(nullify_condition, attacker)
		"scroll_attack":
			is_nullified = attacker.is_using_scroll
		"normal_attack":
			is_nullified = not attacker.is_using_scroll
		_:
			print("【無効化】未知のタイプ: ", nullify_type)
			return {"is_nullified": false, "reduction_rate": 1.0}
	
	if is_nullified:
		var reduction_rate = nullify_condition.get("reduction_rate", 0.0)
		return {"is_nullified": true, "reduction_rate": reduction_rate}
	
	return {"is_nullified": false, "reduction_rate": 1.0}

## 属性無効化判定
func _check_nullify_element(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var attacker_element = attacker.creature_data.get("element", "")
	
	# 単一属性
	if condition.has("element"):
		var target_element = condition.get("element")
		return attacker_element == target_element
	
	# 複数属性
	if condition.has("elements"):
		var elements = condition.get("elements", [])
		return attacker_element in elements
	
	return false

## MHP以上無効化判定
func _check_nullify_mhp_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# BattleParticipantのget_max_hp()を使用
	return attacker.get_max_hp() >= threshold

## MHP以下無効化判定
func _check_nullify_mhp_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# BattleParticipantのget_max_hp()を使用
	return attacker.get_max_hp() <= threshold

## ST以下無効化判定
func _check_nullify_st_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# 基礎ST = base_ap + base_up_ap
	var base_ap = attacker.creature_data.get("ap", 0)
	var base_up_ap = attacker.creature_data.get("base_up_ap", 0)
	var attacker_base_st = base_ap + base_up_ap
	return attacker_base_st <= threshold

## ST以上無効化判定
func _check_nullify_st_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# 基礎ST = base_ap + base_up_ap
	var base_ap = attacker.creature_data.get("ap", 0)
	var base_up_ap = attacker.creature_data.get("base_up_ap", 0)
	var attacker_base_st = base_ap + base_up_ap
	return attacker_base_st >= threshold

## 能力持ち無効化判定
func _check_nullify_has_ability(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var ability = condition.get("ability", "")
	var attacker_keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
	return ability in attacker_keywords

## 即死判定を行う
func check_instant_death(attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	# 即死スキルを持つかチェック
	var ability_parsed = attacker.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "即死" in keywords:
		return false
	
	print("【即死判定開始】", attacker.creature_data.get("name", "?"), " → ", defender.creature_data.get("name", "?"))
	
	# 即死条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	if instant_death_condition.is_empty():
		return false
	
	# 条件チェック
	if not _check_instant_death_condition(instant_death_condition, attacker, defender):
		return false
	
	# 確率判定
	var probability = instant_death_condition.get("probability", 0)
	var random_value = randf() * 100.0
	
	if random_value <= probability:
		print("【即死発動】", attacker.creature_data.get("name", "?"), " → ", defender.creature_data.get("name", "?"), " (", probability, "% 判定成功)")
		defender.instant_death_flag = true
		defender.base_hp = 0
		defender.update_current_hp()
		return true
	else:
		print("【即死失敗】確率:", probability, "% 判定値:", int(random_value), "%")
		return false

## 即死条件をチェック
func _check_instant_death_condition(condition: Dictionary, attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"none":
			# 無条件
			return true
		
		"enemy_is_element":
			# 敵が特定属性
			var required_elements = condition.get("elements", "")
			var defender_element = defender.creature_data.get("element", "")
			
			# 「全」属性は全てに有効
			if required_elements == "全":
				return true
			
			if defender_element == required_elements:
				print("【即死条件】敵が", required_elements, "属性 → 条件満たす")
				return true
			else:
				print("【即死条件】敵が", defender_element, "属性（要求:", required_elements, "）→ 条件不成立")
				return false
		
		"defender_st_check":
			# 防御側のSTが一定以上（基本STで判定）
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			var defender_base_st = defender.creature_data.get("ap", 0)  # 基本STで判定
			
			var meets_condition = false
			match operator:
				">=": meets_condition = defender_base_st >= value
				">": meets_condition = defender_base_st > value
				"==": meets_condition = defender_base_st == value
			
			if meets_condition:
				print("【即死条件】防御側ST ", defender_base_st, " ", operator, " ", value, " → 条件満たす")
				return true
			else:
				print("【即死条件】防御側ST ", defender_base_st, " ", operator, " ", value, " → 条件不成立")
				return false
		
		"defender_role":
			# 使用者が防御側の場合のみ発動（キロネックス用）
			if not attacker.is_attacker:
				print("【即死条件】使用者が防御側 → 条件満たす")
				return true
			else:
				print("【即死条件】使用者が侵略側 → 条件不成立")
				return false
		
		"後手":
			# 後手条件（先制の逆）
			# この条件は先制判定で既に処理されているため、ここでは常にtrueを返す
			return true
		
		_:
			print("【即死条件】未知の条件タイプ:", condition_type)
			return false

## 再生スキル処理
func apply_regeneration(participant: BattleParticipant) -> void:
	# 生き残っていない場合は発動しない
	if not participant.is_alive():
		return
	
	# 再生キーワードチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "再生" in keywords:
		# 基本HPの最大値を取得（初期値）
		var max_base_hp = participant.creature_data.get("hp", 0)
		# 永続HP上昇の最大値を取得
		var max_base_up_hp = participant.creature_data.get("base_up_hp", 0)
		
		var healed = 0
		
		# base_hpを回復
		if participant.base_hp < max_base_hp:
			healed += max_base_hp - participant.base_hp
			participant.base_hp = max_base_hp
		
		# base_up_hpを回復
		if participant.base_up_hp < max_base_up_hp:
			healed += max_base_up_hp - participant.base_up_hp
			participant.base_up_hp = max_base_up_hp
		
		if healed > 0:
			participant.update_current_hp()
			print("【再生発動】", participant.creature_data.get("name", "?"), 
				  " HP回復: +", healed, " → ", participant.current_hp)

## 防御側クリーチャーのHPを更新
func update_defender_hp(tile_info: Dictionary, defender: BattleParticipant) -> void:
	var tile_index = tile_info["index"]
	var creature_data = tile_info.get("creature", {}).duplicate()
	
	# 元のHPは触らない（不変）
	# creature_data["hp"] = そのまま
	
	# 現在HPを保存（base_hp + base_up_hpの現在値）
	creature_data["current_hp"] = defender.base_hp + defender.base_up_hp
	
	# タイルのクリーチャーデータを更新
	board_system_ref.tile_data_manager.tile_nodes[tile_index].creature_data = creature_data
