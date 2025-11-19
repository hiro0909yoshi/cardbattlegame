##
## 貫通スキル - 土地ボーナスを無視して攻撃する
##
## 【主な機能】
## - 侵略側のみ有効（防御側の貫通は無視される）
## - 防御側の土地ボーナスHPを無効化
## - 条件付き貫通に対応（敵属性、ST比較など）
##
## 【発動条件】
## - 侵略側であること
## - 貫通キーワードを持っていること
## - 条件がある場合は条件を満たすこと
##
## 【条件タイプ】
## - enemy_is_element: 敵が特定属性の場合
## - attacker_ap_check: 攻撃側APが条件を満たす場合
## - defender_ap_check: 防御側APが条件を満たす場合
##
## 【効果】
## - 防御側の土地ボーナスHPを0として扱う
## - 基本HPと感応ボーナスのみに対してダメージを与える
##
## 【実装済みクリーチャー例】
## - Gargoyle (ID: 303) - 無条件貫通
## - Evil Blast (ID: 325) - 無条件貫通
## - ファイアービーク (ID: 38) - 貫通[水風]
## - ピュトン (ID: 36) - 貫通[敵AP≧40]
##
## @version 2.0
## @date 2025-11-03

class_name SkillPenetration

## 貫通スキルのチェック
##
## 防御側が貫通を持っていても効果がないことを通知
##
## @param attacker 攻撃側の参加者
## @return 貫通が有効かどうか
static func check_and_notify(attacker) -> bool:
	# 防御側の貫通スキルは効果なし
	if not attacker.is_attacker:
		var keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
		if "貫通" in keywords:
			print("  【貫通】防御側のため効果なし")
			return false
	
	return true

## 貫通スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 貫通スキルを持っているか
static func has_penetration(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "貫通" in keywords

## 侵略側が貫通を持っているかチェック（条件なし）
##
## @param attacker 攻撃側の参加者
## @return 侵略側が貫通キーワードを持っているか
static func is_active(attacker) -> bool:
	if not attacker.is_attacker:
		return false
	
	return has_penetration(attacker.creature_data)

## 貫通の条件をチェック（準備フェーズ用）
##
## 攻撃側が貫通を持ち、条件を満たす場合にtrueを返す
## 条件付き貫通に対応：
## - enemy_is_element: 敵が特定属性の場合
## - attacker_ap_check: 攻撃側APが条件を満たす場合
## - defender_ap_check: 防御側APが条件を満たす場合
##
## @param attacker_data 攻撃側のクリーチャーデータ
## @param defender_data 防御側のクリーチャーデータ
## @return 貫通が発動するかどうか
static func check_penetration_condition(attacker_data: Dictionary, defender_data: Dictionary) -> bool:
	# 攻撃側のability_parsedから貫通スキルを取得
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 貫通スキルがない場合
	if not "貫通" in keywords:
		return false
	
	# 貫通スキルの条件をチェック
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var penetrate_condition = keyword_conditions.get("貫通", {})
	
	# 条件がない場合は無条件発動
	if penetrate_condition.is_empty():
		print("【貫通】無条件発動")
		return true
	
	# 条件チェック
	var condition_type = penetrate_condition.get("condition_type", "")
	
	match condition_type:
		"enemy_is_element":
			# 敵が特定属性の場合
			var required_elements = penetrate_condition.get("elements", [])
			var defender_element = defender_data.get("element", "")
			
			# elementsが配列の場合
			if typeof(required_elements) == TYPE_ARRAY:
				if defender_element in required_elements:
					print("【貫通】条件満たす: 敵が", defender_element, "属性（", required_elements, "のいずれか）")
					return true
				else:
					print("【貫通】条件不成立: 敵が", defender_element, "属性（要求:", required_elements, "）")
					return false
			# elementsが文字列の場合（後方互換）
			else:
				if defender_element == required_elements:
					print("【貫通】条件満たす: 敵が", required_elements, "属性")
					return true
				else:
					print("【貫通】条件不成立: 敵が", defender_element, "属性（要求:", required_elements, "）")
					return false
		
		"attacker_ap_check":
			# 攻撃側のSTが一定以上の場合
			var operator = penetrate_condition.get("operator", ">=")
			var value = penetrate_condition.get("value", 0)
			var attacker_ap = attacker_data.get("ap", 0)
			
			var meets_condition = false
			match operator:
				">=": meets_condition = attacker_ap >= value
				">": meets_condition = attacker_ap > value
				"==": meets_condition = attacker_ap == value
			
			if meets_condition:
				print("【貫通】条件満たす: ST ", attacker_ap, " ", operator, " ", value)
				return true
			else:
				print("【貫通】条件不成立: ST ", attacker_ap, " ", operator, " ", value)
				return false
		
		"defender_ap_check":
			# 防御側のAPが一定以上の場合
			var operator_d = penetrate_condition.get("operator", ">=")
			var value_d = penetrate_condition.get("value", 0)
			var defender_ap = defender_data.get("ap", 0)
			
			var meets_condition_d = false
			match operator_d:
				">=": meets_condition_d = defender_ap >= value_d
				">": meets_condition_d = defender_ap > value_d
				"==": meets_condition_d = defender_ap == value_d
			
			if meets_condition_d:
				print("【貫通】条件満たす: 敵AP ", defender_ap, " ", operator_d, " ", value_d)
				return true
			else:
				print("【貫通】条件不成立: 敵AP ", defender_ap, " ", operator_d, " ", value_d)
				return false
		
		_:
			# 未知の条件タイプ
			print("【貫通】未知の条件タイプ:", condition_type)
			return false

## 貫通スキルを適用（土地ボーナスHPを無効化）
##
## 侵略側が貫通を持ち、条件を満たす場合、防御側の土地ボーナスHPを0にする
##
## @param attacker 攻撃側の参加者
## @param defender 防御側の参加者
static func apply_penetration(attacker, defender) -> void:
	if not attacker.is_attacker:
		return
	
	# 条件付き貫通チェック
	if not check_penetration_condition(attacker.creature_data, defender.creature_data):
		return
	
	if defender.land_bonus_hp > 0:
		print("  【貫通】防御側の土地ボーナスHP ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
