##
## 先制・後手スキル - 攻撃順序を制御する
##
## 【主な機能】
## - 先制: 先攻権を獲得
## - 後手: 相手に先攻を譲る
##
## 【発動条件】
## - "先制"または"後手"キーワードを保持
##
## 【効果】
## - 先制: has_first_strike = true
## - 後手: has_last_strike = true
##
## @version 1.0
## @date 2025-10-31

class_name SkillFirstStrike

## 先制スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 先制スキルを持っているか
static func has_first_strike(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "先制" in keywords

## 後手スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 後手スキルを持っているか
static func has_last_strike(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "後手" in keywords

## 先制・後手スキルを適用
##
## @param participant バトル参加者
static func apply(participant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "先制" in keywords:
		participant.has_first_strike = true
		print("【先制】", participant.creature_data.get("name", "?"), " 先制攻撃権獲得")
	
	if "後手" in keywords:
		participant.has_last_strike = true
		print("【後手】", participant.creature_data.get("name", "?"), " 後手攻撃")

## スキル付与（アイテム使用時）
##
## @param participant バトル参加者
## @param skill_name スキル名（"先制"または"後手"）
static func grant_skill(participant, skill_name: String) -> void:
	match skill_name:
		"先制":
			participant.has_first_strike = true
			print("【先制付与】", participant.creature_data.get("name", "?"), " アイテムによる先制")
		"後手":
			participant.has_last_strike = true
			print("【後手付与】", participant.creature_data.get("name", "?"), " アイテムによる後手")
