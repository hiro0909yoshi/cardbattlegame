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
## @param silent 出力を抑制するか（シミュレーション時 true）
static func apply(participant, silent: bool = false) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])

	if "2回攻撃" in keywords:
		participant.attack_count = 2
		if not silent:
			print("【2回攻撃】", participant.creature_data.get("name", "?"), " 攻撃回数: 2回")

## スキル付与（アイテム使用時）
##
## @param participant バトル参加者
## @param silent 出力を抑制するか（シミュレーション時 true）
static func grant_skill(participant, silent: bool = false) -> void:
	participant.attack_count = 2
	if not silent:
		print("【2回攻撃付与】", participant.creature_data.get("name", "?"), " アイテムによる2回攻撃")
