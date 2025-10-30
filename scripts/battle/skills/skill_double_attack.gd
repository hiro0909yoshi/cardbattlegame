##
## 2回攻撃スキル - 1回のバトルで2回攻撃する
##
## 【主な機能】
## - 攻撃回数を2回に設定
##
## 【発動条件】
## - "2回攻撃"キーワードを保持
##
## 【効果】
## - attack_count = 2
##
## @version 1.0
## @date 2025-10-31

class_name SkillDoubleAttack

## 2回攻撃スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 2回攻撃スキルを持っているか
static func has_skill(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "2回攻撃" in keywords

## 2回攻撃スキルを適用
##
## @param participant バトル参加者
static func apply(participant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "2回攻撃" in keywords:
		participant.attack_count = 2
		print("【2回攻撃】", participant.creature_data.get("name", "?"), " 攻撃回数: 2回")
