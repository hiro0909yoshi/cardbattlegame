## 巻物攻撃スキル (Scroll Attack Skill)
##
## 巻物アイテムを使用している場合に発動する特殊攻撃スキル
##
## 【主な機能】
## - バフ未使用時のみ発動（base_up_ap以外のバフがある場合は通常攻撃）
## - APの固定値設定 or 基本ST使用
## - 防御側の土地ボーナスHP無効化
## - 巻物強打との併用（APを1.5倍）
##
## 【発動条件】
## - 巻物アイテムを装備している
## - base_up_ap以外のバフが適用されていない
##
## 【効果】
## - AP固定値設定（scroll_type: "fixed_ap"）
## - AP基本AP使用（scroll_type: "base_ap"）
## - 土地数比例（scroll_type: "land_count"）
## - 防御側の土地ボーナスHP無効化
## - 巻物強打: 上記AP × 1.5
##
## 【実装済みクリーチャー例】
## - Phantom (ID: 315) - 巻物攻撃（基本ST）
## - Valkyrie (ID: 318) - 巻物攻撃（基本ST）
## - Armed Paladin (ID: 338) - 巻物攻撃（固定30）
## - ウィッチ - 巻物強打（基本ST×1.5）
## - 他多数
##
## @version 1.1
## @date 2025-01-25

class_name SkillScrollAttack

const ParticipantClass = preload("res://scripts/battle/battle_participant.gd")

## 巻物攻撃スキルを適用
##
## バフ未使用時のみ巻物攻撃が発動する
## 巻物攻撃フラグを立て、APを設定する
## 巻物強打の場合はAPを1.5倍にする
##
## @param participant: バトル参加者
## @param context: 戦闘コンテキスト
## @return bool: 巻物攻撃が発動したかどうか
static func apply(participant: BattleParticipant, context: Dictionary) -> bool:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 巻物攻撃 or 巻物強打を持つか
	if not ("巻物攻撃" in keywords or "巻物強打" in keywords):
		return false
	
	# バフチェック: base_up_ap以外のバフが入っていたら発動しない
	var base_ap = participant.creature_data.get("ap", 0)
	var expected_ap = base_ap + participant.base_up_ap
	
	if participant.current_ap != expected_ap:
		# base_up_ap以外のバフが入っている → 巻物攻撃不可
		print("【巻物攻撃不可】", participant.creature_data.get("name", "?"), 
			  " バフ検出（AP:", participant.current_ap, "≠", expected_ap, "）通常攻撃に変更")
		return false
	
	# 巻物攻撃フラグを立てる
	participant.is_using_scroll = true
	
	# AP設定を取得（巻物強打優先）
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var scroll_config = {}
	var is_power_strike = "巻物強打" in keywords
	
	# 巻物攻撃の設定を優先（巻物強打でもscroll_type等は巻物攻撃から取得する場合がある）
	if "巻物攻撃" in keywords:
		scroll_config = keyword_conditions.get("巻物攻撃", {})
	if is_power_strike and keyword_conditions.has("巻物強打"):
		# 巻物強打の設定があればマージ（巻物強打の設定を優先）
		var power_strike_config = keyword_conditions.get("巻物強打", {})
		for key in power_strike_config:
			scroll_config[key] = power_strike_config[key]
	
	# scroll_typeに基づいてAPを設定
	var scroll_type = scroll_config.get("scroll_type", "base_ap")
	var calculated_ap = base_ap  # デフォルトは基本AP
	
	match scroll_type:
		"fixed_ap":
			# 固定値
			calculated_ap = scroll_config.get("value", base_ap)
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP固定:", calculated_ap)
		"base_ap":
			# 基本APのまま
			calculated_ap = base_ap
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP=基本AP:", calculated_ap)
		"land_count":
			# 土地数比例
			var elements = scroll_config.get("elements", [])
			var multiplier = scroll_config.get("multiplier", 1)
			var player_lands = context.get("player_lands", {})
			
			var total_count = 0
			for element in elements:
				total_count += player_lands.get(element, 0)
			
			calculated_ap = total_count * multiplier
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), 
				  " AP=", elements, "土地数", total_count, "×", multiplier, "=", calculated_ap)
		_:
			# デフォルトは基本ST
			calculated_ap = base_ap
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP=基本AP:", calculated_ap)
	
	# 巻物強打の場合、APを1.5倍にする
	if is_power_strike:
		var original_ap = calculated_ap
		calculated_ap = int(calculated_ap * 1.5)
		print("【巻物強打発動】", participant.creature_data.get("name", "?"), 
			  " AP:", original_ap, " → ", calculated_ap, "（×1.5）")
	
	participant.current_ap = calculated_ap
	return true

## 巻物攻撃スキルを持つかチェック
##
## クリーチャーが巻物攻撃または巻物強打スキルを持っているか判定する
##
## @param creature_data: クリーチャーデータ
## @return bool: 巻物攻撃/巻物強打スキルを持つ場合はtrue
static func has_skill(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "巻物攻撃" in keywords or "巻物強打" in keywords

## 巻物強打スキルを持つかチェック
##
## クリーチャーが巻物強打スキルを持っているか判定する
##
## @param creature_data: クリーチャーデータ
## @return bool: 巻物強打スキルを持つ場合はtrue
static func has_power_strike(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "巻物強打" in keywords
