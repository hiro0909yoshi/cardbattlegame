## 吸魔スキル - 敵からEPを奪う
##
## 【主な機能】
## - ダメージベース吸魔: 与えたダメージに応じてEPを奪う
## - アイテム不使用時吸魔: アイテムを使用していない時にEPを奪う
##
## 【該当クリーチャー】
## - バンディット (ID: 433): 加勢；吸魔[敵に与えたダメージ×2EP]
## - アマゾン (ID: 107): アイテム不使用時、吸魔[周回数×30EP]
##
## @version 1.0
## @date 2025-11-03

class_name SkillMagicSteal

## ダメージベース吸魔スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return ダメージベース吸魔スキルを持っているか
static func has_damage_based_steal(creature_data: Dictionary) -> bool:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type", "") == "magic_steal_on_damage":
			return true
	
	return false

## アイテム不使用時吸魔スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return アイテム不使用時吸魔スキルを持っているか
static func has_no_item_steal(creature_data: Dictionary) -> bool:
	var ability = creature_data.get("ability", "")
	return "アイテム不使用時・吸魔" in ability

## ダメージベース吸魔を適用
##
## @param attacker 攻撃側参加者
## @param defender 防御側参加者
## @param damage 与えたダメージ
## @param spell_magic SpellMagicインスタンス
static func apply_damage_based_steal(attacker, defender, damage: int, spell_magic) -> int:
	if not spell_magic:
		print("[吸魔] spell_magic is null")
		return 0
	
	if damage <= 0:
		print("[吸魔] damage <= 0: ", damage)
		return 0
	
	var has_skill = has_damage_based_steal(attacker.creature_data)
	print("[吸魔] チェック: ", attacker.creature_data.get("name", "?"), " has_skill=", has_skill)
	
	if has_skill:
		# ability_parsedから倍率を取得
		var multiplier = 2  # デフォルト
		var ability_parsed = attacker.creature_data.get("ability_parsed", {})
		var effects = ability_parsed.get("effects", [])
		for effect in effects:
			if effect.get("effect_type", "") == "magic_steal_on_damage":
				multiplier = effect.get("multiplier", 2)
				break
		var amount = damage * multiplier
		
		var actual_stolen = spell_magic.steal_magic(defender.player_id, attacker.player_id, amount)
		
		print("【吸魔】", attacker.creature_data.get("name", "?"), 
			  " → ", actual_stolen, "吸魔（ダメージ", damage, "×", multiplier, "）")
		return actual_stolen
	
	return 0

## アイテム不使用時吸魔を適用（バトル開始時チェック）
##
## @param participant バトル参加者
## @param has_item アイテムを使用しているか
## @param turn_count 周回数
## @param spell_magic SpellMagicインスタンス
## @param enemy_participant 敵参加者
static func apply_no_item_steal(participant, has_item: bool, turn_count: int, spell_magic, enemy_participant) -> int:
	if not spell_magic:
		return 0
	
	# アイテムを使用している場合は発動しない
	if has_item:
		return 0
	
	if has_no_item_steal(participant.creature_data):
		var multiplier = _extract_turn_multiplier(participant.creature_data.get("ability_detail", ""), 30)
		var amount = turn_count * multiplier
		
		var actual_stolen = spell_magic.steal_magic(enemy_participant.player_id, participant.player_id, amount)
		
		print("【アイテム不使用時吸魔】", participant.creature_data.get("name", "?"), 
			  " → ", actual_stolen, "吸魔（周回数", turn_count, "×", multiplier, "）")
		return actual_stolen
	
	return 0

## ability_detailから倍率を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_multiplier デフォルト倍率
## @return 倍率
static func _extract_multiplier(ability_detail: String, default_multiplier: int) -> int:
	# "敵に与えたダメージ×2EP" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("×G(\\d+)")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_multiplier


## ability_detailから周回数倍率を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_multiplier デフォルト倍率
## @return 倍率
static func _extract_turn_multiplier(ability_detail: String, default_multiplier: int) -> int:
	# "周回数×30EP" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("周回数×G(\\d+)")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_multiplier
