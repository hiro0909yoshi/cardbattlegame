## 魔力獲得スキル - 様々な条件で魔力を獲得する
##
## 【主な機能】
## - 侵略時魔力獲得: バトル開始時に魔力獲得
## - ダメージ時魔力獲得: ダメージを受けた時に魔力獲得
## - 破壊時魔力獲得: 戦闘で破壊された時に魔力獲得
## - 無条件魔力獲得: 常に魔力獲得（バトル開始時）
##
## 【該当クリーチャー】
## - ピュトン (ID: 36): 侵略時、魔力獲得[G100]
## - トレジャーレイダー (ID: 331): 侵略時、魔力獲得[G100]
## - ゼラチンウォール (ID: 127): 防御型；魔力獲得[受けたダメージ×G5]
## - クリーピングコイン (ID: 410): 魔力獲得[G100]
##
## @version 1.0
## @date 2025-11-03

class_name SkillMagicGain

## 侵略時魔力獲得スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 侵略時魔力獲得スキルを持っているか
static func has_invasion_magic_gain(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "侵略時、魔力獲得" in ability_detail or "侵略時魔力獲得" in ability_detail

## 無条件魔力獲得スキルを持っているかチェック（バトル開始時に発動）
##
## @param creature_data クリーチャーデータ
## @return 無条件魔力獲得スキルを持っているか
static func has_unconditional_magic_gain(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "魔力獲得" in keywords

## ダメージ時魔力獲得スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return ダメージ時魔力獲得スキルを持っているか
static func has_damage_magic_gain(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "魔力獲得[受けたダメージ" in ability_detail

## 破壊時魔力獲得スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 破壊時魔力獲得スキルを持っているか
static func has_destroy_magic_gain(creature_data: Dictionary) -> bool:
	var ability = creature_data.get("ability", "")
	return "破壊時魔力獲得" in ability

## 侵略時魔力獲得を適用（バトル開始時）
##
## @param participant バトル参加者
## @param spell_magic SpellMagicインスタンス
## @return 発動した場合はtrue
static func apply_invasion_magic_gain(participant, spell_magic) -> bool:
	if not spell_magic:
		return false
	
	# 侵略側のみ発動
	if not participant.is_attacker:
		return false
	
	var has_skill = has_invasion_magic_gain(participant.creature_data)
	
	if has_skill:
		var amount = _extract_magic_amount(participant.creature_data.get("ability_detail", ""), 100)
		spell_magic.add_magic(participant.player_id, amount)
		print("【侵略時魔力獲得】", participant.creature_data.get("name", "?"), " → ", amount, "G獲得")
		return true
	
	return false

## 無条件魔力獲得を適用（バトル開始時）
##
## @param participant バトル参加者
## @param spell_magic SpellMagicインスタンス
## @return 発動した場合はtrue
static func apply_unconditional_magic_gain(participant, spell_magic) -> bool:
	if not spell_magic:
		return false
	
	if has_unconditional_magic_gain(participant.creature_data):
		var amount = _extract_magic_amount(participant.creature_data.get("ability_detail", ""), 100)
		spell_magic.add_magic(participant.player_id, amount)
		print("【魔力獲得】", participant.creature_data.get("name", "?"), " → ", amount, "G獲得")
		return true
	
	return false

## ダメージ時魔力獲得を適用
##
## @param participant バトル参加者
## @param damage 受けたダメージ
## @param spell_magic SpellMagicインスタンス
static func apply_damage_magic_gain(participant, damage: int, spell_magic) -> void:
	if not spell_magic:
		return
	
	if damage <= 0:
		return
	
	if has_damage_magic_gain(participant.creature_data):
		var multiplier = _extract_multiplier(participant.creature_data.get("ability_detail", ""), 5)
		var amount = damage * multiplier
		spell_magic.add_magic(participant.player_id, amount)
		print("【ダメージ時魔力獲得】", participant.creature_data.get("name", "?"), 
			  " → ", amount, "G獲得（ダメージ", damage, "×", multiplier, "）")

## バトル開始時の魔力獲得スキルをまとめて適用
##
## @param attacker 攻撃側参加者
## @param defender 防御側参加者
## @param spell_magic SpellMagicインスタンス
## @return 発動した参加者の配列
static func apply_on_battle_start(attacker, defender, spell_magic) -> Array:
	var activated = []
	
	# 侵略時魔力獲得（攻撃側のみ）
	if apply_invasion_magic_gain(attacker, spell_magic):
		activated.append(attacker)
	
	# 無条件魔力獲得（両側）
	if apply_unconditional_magic_gain(attacker, spell_magic):
		if attacker not in activated:
			activated.append(attacker)
	
	if apply_unconditional_magic_gain(defender, spell_magic):
		activated.append(defender)
	
	return activated


## ability_detailから魔力獲得量を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_amount デフォルト値
## @return 魔力獲得量
static func _extract_magic_amount(ability_detail: String, default_amount: int) -> int:
	# "魔力獲得[G100]" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("魔力獲得\\[G(\\d+)\\]")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_amount

## ability_detailから倍率を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_multiplier デフォルト倍率
## @return 倍率
static func _extract_multiplier(ability_detail: String, default_multiplier: int) -> int:
	# "受けたダメージ×G5" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("×G(\\d+)")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_multiplier
