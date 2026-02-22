##
## 刺突スキル - 土地ボーナスを無視して攻撃する
##
## 【主な機能】
## - 侵略側のみ有効（防御側の刺突は無視される）
## - 防御側の土地ボーナスHPを無効化
## - 条件付き刺突に対応（敵属性、ST比較など）
##
## 【発動条件】
## - 侵略側であること
## - 刺突キーワードを持っていること
## - 条件がある場合は条件を満たすこと
##
## 【条件タイプ】
## - enemy_is_element: 敵が特定属性の場合
## - attacker_ap_check: 攻撃側APが条件を満たす場合
## - defender_ap_check: 防御側APが条件を満たす場合
##
## 【効果】
## - 防御側の土地ボーナスHPを0として扱う
## - 基本HPと共鳴ボーナスのみに対してダメージを与える
##
## 【実装済みクリーチャー例】
## - Gargoyle (ID: 303) - 無条件刺突
## - Evil Blast (ID: 325) - 無条件刺突
## - ファイアービーク (ID: 38) - 刺突[水風]
## - ピュトン (ID: 36) - 刺突[敵AP≧40]
##
## @version 2.0
## @date 2025-11-03

class_name SkillPenetration

## 刺突スキルのチェック
##
## 防御側が刺突を持っていても効果がないことを通知
##
## @param attacker 攻撃側の参加者
## @return 刺突が有効かどうか
static func check_and_notify(attacker) -> bool:
	# 防御側の刺突スキルは効果なし
	if not attacker.is_attacker:
		var keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
		if "刺突" in keywords:
			print("  【刺突】防御側のため効果なし")
			return false
	
	return true

## 刺突スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 刺突スキルを持っているか
static func has_penetration(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "刺突" in keywords

## 侵略側が刺突を持っているかチェック（条件なし）
##
## @param attacker 攻撃側の参加者
## @return 侵略側が刺突キーワードを持っているか
static func is_active(attacker) -> bool:
	if not attacker.is_attacker:
		return false
	
	return has_penetration(attacker.creature_data)

## 刺突の条件をチェック（準備フェーズ用）
##
## 攻撃側が刺突を持ち、条件を満たす場合にtrueを返す
## 条件付き刺突に対応：
## - enemy_is_element: 敵が特定属性の場合
## - attacker_ap_check: 攻撃側APが条件を満たす場合
## - defender_ap_check: 防御側APが条件を満たす場合
##
## @param attacker_data 攻撃側のクリーチャーデータ
## @param defender_data 防御側のクリーチャーデータ
## @return 刺突が発動するかどうか
static func check_penetration_condition(attacker_data: Dictionary, defender_data: Dictionary) -> bool:
	# 攻撃側のability_parsedから刺突スキルを取得
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 刺突スキルがない場合
	if not "刺突" in keywords:
		return false
	
	# 刺突スキルの条件をチェック
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var penetrate_condition = keyword_conditions.get("刺突", {})
	
	# 条件がない場合は無条件発動
	if penetrate_condition.is_empty():
		print("【刺突】無条件発動")
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
					print("【刺突】条件満たす: 敵が", defender_element, "属性（", required_elements, "のいずれか）")
					return true
				else:
					print("【刺突】条件不成立: 敵が", defender_element, "属性（要求:", required_elements, "）")
					return false
			# elementsが文字列の場合（後方互換）
			else:
				if defender_element == required_elements:
					print("【刺突】条件満たす: 敵が", required_elements, "属性")
					return true
				else:
					print("【刺突】条件不成立: 敵が", defender_element, "属性（要求:", required_elements, "）")
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
				print("【刺突】条件満たす: ST ", attacker_ap, " ", operator, " ", value)
				return true
			else:
				print("【刺突】条件不成立: ST ", attacker_ap, " ", operator, " ", value)
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
				print("【刺突】条件満たす: 敵AP ", defender_ap, " ", operator_d, " ", value_d)
				return true
			else:
				print("【刺突】条件不成立: 敵AP ", defender_ap, " ", operator_d, " ", value_d)
				return false
		
		_:
			# 未知の条件タイプ
			print("【刺突】未知の条件タイプ:", condition_type)
			return false

## 刺突スキルを適用（土地ボーナスHPを無効化）
##
## 侵略側が刺突を持ち、条件を満たす場合、防御側の土地ボーナスHPを0にする
##
## @param attacker 攻撃側の参加者
## @param defender 防御側の参加者
static func apply_penetration(attacker, defender) -> void:
	if not attacker.is_attacker:
		return
	
	# 条件付き刺突チェック
	if not check_penetration_condition(attacker.creature_data, defender.creature_data):
		return
	
	if defender.land_bonus_hp > 0:
		print("  【刺突】防御側の土地ボーナスHP ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
