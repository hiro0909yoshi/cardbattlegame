## 感応スキル (Resonance/Affinity Skill)
##
## 特定属性の土地を所有している場合、APやHPにボーナスを得るパッシブスキル
##
## 【主な機能】
## - 属性別の土地所有チェック
## - 1つでも対象属性の土地を所有していれば発動
## - AP/HPボーナスの付与
## - 巻物攻撃との併用可否の制御
##
## 【発動条件】
## - 対象属性の土地を1つ以上所有
##
## 【効果】
## - AP上昇（例：+30）
## - HP上昇（例：+20）
## - または両方
##
## 【実装済みクリーチャー例】
## - Phoenix (ID: 302) - 火土地所有でST+30
## - Kraken (ID: 342) - 水土地所有でST+30
## - 他、多数のクリーチャーが感応スキルを持つ
##
## @version 1.0
## @date 2025-10-31

class_name SkillResonance

const ParticipantClass = preload("res://scripts/battle/battle_participant.gd")

## 感応スキルを適用
##
## プレイヤーが対象属性の土地を所有している場合、
## バトル参加者のAPとHPにボーナスを付与する
##
## @param participant: バトル参加者
## @param context: 戦闘コンテキスト（player_lands等を含む）
## @return bool: 感応が発動したかどうか
static func apply(participant: BattleParticipant, context: Dictionary) -> bool:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 感応スキルがない場合
	if not "感応" in keywords:
		return false
	
	# 感応条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var resonance_condition = keyword_conditions.get("感応", {})
	
	if resonance_condition.is_empty():
		return false
	
	# 必要な属性を取得
	var required_element = resonance_condition.get("element", "")
	
	# プレイヤーの土地情報を取得
	var player_lands = context.get("player_lands", {})
	var owned_count = player_lands.get(required_element, 0)
	
	# 感応発動判定：指定属性の土地を1つでも所有していれば発動
	if owned_count > 0:
		var stat_bonus = resonance_condition.get("stat_bonus", {})
		var ap_bonus = stat_bonus.get("ap", 0)
		var hp_bonus = stat_bonus.get("hp", 0)
		
		if ap_bonus > 0 or hp_bonus > 0:
			print("【感応発動】", participant.creature_data.get("name", "?"))
			print("  必要属性:", required_element, " 所持数:", owned_count)
			
			# APボーナス適用
			if ap_bonus > 0:
				var old_ap = participant.current_ap
				participant.current_ap += ap_bonus
				print("  AP: ", old_ap, " → ", participant.current_ap, " (+", ap_bonus, ")")
			
			# HPボーナス適用（resonance_bonus_hpに追加）
			if hp_bonus > 0:
				var old_hp = participant.current_hp
				participant.resonance_bonus_hp += hp_bonus
				print("  HP: ", old_hp, " → ", participant.current_hp, " (+", hp_bonus, ")")
			
			return true
	
	return false

## 感応スキルを持つかチェック（オプション）
##
## クリーチャーが感応スキルを持っているか判定する
##
## @param creature_data: クリーチャーデータ
## @return bool: 感応スキルを持つ場合はtrue
static func has_skill(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "感応" in keywords
