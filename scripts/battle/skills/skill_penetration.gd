##
## 貫通スキル - 土地ボーナスを無視して攻撃する
##
## 【主な機能】
## - 侵略側のみ有効（防御側の貫通は無視される）
## - 防御側の土地ボーナスHPを無効化
##
## 【発動条件】
## - 侵略側であること
## - 貫通キーワードを持っていること
##
## 【効果】
## - 防御側の土地ボーナスHPを0として扱う
## - 基本HPと感応ボーナスのみに対してダメージを与える
##
## 【実装済みクリーチャー例】
## - Gargoyle (ID: 303)
## - Evil Blast (ID: 325)
## - 他多数
##
## @version 1.0
## @date 2025-10-31

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

## 侵略側が貫通を持っているかチェック
##
## @param attacker 攻撃側の参加者
## @return 侵略側が貫通を持っているか
static func is_active(attacker) -> bool:
	if not attacker.is_attacker:
		return false
	
	return has_penetration(attacker.creature_data)

## 貫通スキルを適用（土地ボーナスHPを無効化）
##
## 侵略側が貫通を持っている場合、防御側の土地ボーナスHPを0にする
##
## @param attacker 攻撃側の参加者
## @param defender 防御側の参加者
static func apply_penetration(attacker, defender) -> void:
	if not is_active(attacker):
		return
	
	if defender.land_bonus_hp > 0:
		print("  【貫通】防御側の土地ボーナスHP ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		defender.update_current_hp()
