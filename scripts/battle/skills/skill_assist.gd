class_name SkillAssist

## 援護スキル - クリーチャーをアイテムとして使用
##
## 【主な機能】
## - 手札のクリーチャーカードをアイテムフェーズで使用
## - AP/HPをバトル参加クリーチャーに加算
## - スキルは継承されない
## - 対象属性制限あり
##
## 【発動条件】
## - バトル参加クリーチャーが「援護」キーワードを持つ
## - 対象クリーチャーの属性が援護対象に含まれる
## - 使用クリーチャーのコスト分の魔力を消費
##
## 【効果】
## - 援護クリーチャーのAPを加算
## - 援護クリーチャーのHPを加算
## - 使用したクリーチャーは捨て札へ
##
## 【特殊処理】
## - ブラッドプリン (ID: 137): 援護クリーチャーのMHPを永続吸収
##
## 【実装済みクリーチャー】
## - 全18体（全属性対応5体、特定属性13体）
##
## @version 1.0
## @date 2025-11-03

## 援護効果を適用
##
## 援護クリーチャーのAP/HPをバトル参加クリーチャーに加算
## ブラッドプリンの場合は特殊処理（MHP永続吸収）
##
## @param participant バトル参加者
## @param assist_creature_data 援護クリーチャーのデータ
static func apply_assist_effect(participant: BattleParticipant, assist_creature_data: Dictionary) -> void:
	var creature_ap = assist_creature_data.get("ap", 0)
	var creature_hp = assist_creature_data.get("hp", 0)
	
	# AP加算
	if creature_ap > 0:
		participant.current_ap += creature_ap
		print("  [援護] AP+", creature_ap, " → ", participant.current_ap)
	
	# HP加算
	if creature_hp > 0:
		participant.item_bonus_hp += creature_hp
		participant.update_current_hp()
		print("  [援護] HP+", creature_hp, " → ", participant.current_hp)
	
	# 【ブラッドプリン専用処理】援護クリーチャーのMHPを永続吸収
	if participant.creature_data.get("id") == 137:
		_apply_blood_purin_effect(participant, assist_creature_data)

## ブラッドプリン特殊効果: 援護クリーチャーのMHPを永続吸収
##
## ブラッドプリン (ID: 137) が援護クリーチャーを使用した場合、
## そのクリーチャーのMHPを永続的に吸収（上限100まで）
##
## @param participant バトル参加者（ブラッドプリン）
## @param assist_creature_data 援護クリーチャーのデータ
static func _apply_blood_purin_effect(participant: BattleParticipant, assist_creature_data: Dictionary) -> void:
	# 援護クリーチャーのMHPを取得（hp + base_up_hp）
	var assist_base_hp = assist_creature_data.get("hp", 0)
	var assist_base_up_hp = assist_creature_data.get("base_up_hp", 0)
	var assist_mhp = assist_base_hp + assist_base_up_hp
	
	# ブラッドプリンの現在MHPを取得
	var current_mhp = participant.get_max_hp()
	
	# MHP上限100チェック
	var max_increase = 100 - current_mhp
	var actual_increase = min(assist_mhp, max_increase)
	
	if actual_increase > 0:
		# 永続的にMHPを上昇（creature_dataのみ更新、戦闘中は適用しない）
		var blood_purin_base_up_hp = participant.creature_data.get("base_up_hp", 0)
		participant.creature_data["base_up_hp"] = blood_purin_base_up_hp + actual_increase
		
		print("【ブラッドプリン効果】援護クリーチャー", assist_creature_data.get("name", "?"), "のMHP", assist_mhp, "を吸収")
		print("  MHP: ", current_mhp, " → ", current_mhp + actual_increase, " (+", actual_increase, ")")
	elif max_increase == 0:
		print("【ブラッドプリン効果】MHP上限100に到達済み - 吸収なし")
	else:
		print("【ブラッドプリン効果】吸収量", assist_mhp, "だが上限まで", max_increase, "のみ吸収")

## 援護スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 援護スキルを持っているか
static func has_assist_skill(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "援護" in keywords

## 援護対象として使用できるかチェック
##
## バトル参加クリーチャーの援護スキル条件に基づき、
## 指定されたクリーチャーが援護対象として使用可能かを判定
##
## @param battle_creature_data バトル参加クリーチャーのデータ
## @param assist_candidate_data 援護候補クリーチャーのデータ
## @return 援護対象として使用可能か
static func can_be_used_as_assist(battle_creature_data: Dictionary, assist_candidate_data: Dictionary) -> bool:
	# バトル参加クリーチャーが援護スキルを持っているかチェック
	if not has_assist_skill(battle_creature_data):
		return false
	
	# 援護スキルの条件を取得
	var ability_parsed = battle_creature_data.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var assist_condition = keyword_conditions.get("援護", {})
	
	# 対象属性を取得
	var target_elements = assist_condition.get("target_elements", [])
	
	# target_elementsが空または"all"を含む場合は全属性対応
	if target_elements.is_empty() or "all" in target_elements:
		return true
	
	# 候補クリーチャーの属性を取得
	var candidate_element = assist_candidate_data.get("element", "")
	
	# 候補クリーチャーの属性が対象に含まれているかチェック
	return candidate_element in target_elements
