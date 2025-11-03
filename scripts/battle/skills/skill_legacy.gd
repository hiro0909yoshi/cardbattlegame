## 遺産スキル - 死亡時に特殊効果を発動する
##
## 【主な機能】
## - 遺産[魔力]: 死亡時に魔力を獲得
## - 遺産[カード]: 死亡時にカードをドロー
## - 道産: 死亡時に魔力を獲得（破壊時専用）
##
## 【該当クリーチャー】
## - フェイト (ID: 136): 遺産[カード1枚]
## - コーンフォーク (ID: 315): 破壊時、道産[G200]
## - クリーピングコイン (ID: 410): 破壊時、道産[G100]
##
## @version 1.0
## @date 2025-11-03

class_name SkillLegacy

## 遺産[カード]スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 遺産[カード]スキルを持っているか
static func has_card_legacy(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "遺産[カード" in ability_detail

## 道産スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 道産スキルを持っているか
static func has_magic_legacy(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "道産[G" in ability_detail or "破壊時魔力道産" in ability_detail

## 遺産[カード]を適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_draw SpellDrawインスタンス
static func apply_card_legacy(defeated, spell_draw) -> void:
	print("[DEBUG] apply_card_legacy 呼び出し")
	print("[DEBUG] spell_draw: ", spell_draw != null)
	
	if not spell_draw:
		print("[DEBUG] spell_drawがnull")
		return
	
	var has_legacy = has_card_legacy(defeated.creature_data)
	print("[DEBUG] has_card_legacy: ", has_legacy)
	
	if has_legacy:
		var card_count = _extract_card_count(defeated.creature_data.get("ability_detail", ""), 1)
		
		print("【遺産発動】", defeated.creature_data.get("name", "?"), 
			  " → プレイヤー", defeated.player_id + 1, "がカード", card_count, "枚ドロー")
		
		# カードドロー.mdの方法: draw_cards()を使用
		var drawn_cards = spell_draw.draw_cards(defeated.player_id, card_count)
		
		if drawn_cards.size() > 0:
			print("  引いたカード: ", drawn_cards.map(func(c): return c.get("name", "?")))

## 道産[魔力]を適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_magic SpellMagicインスタンス
static func apply_magic_legacy(defeated, spell_magic) -> void:
	if not spell_magic:
		return
	
	if has_magic_legacy(defeated.creature_data):
		var amount = _extract_magic_amount(defeated.creature_data.get("ability_detail", ""), 100)
		
		print("【道産発動】", defeated.creature_data.get("name", "?"), 
			  " → プレイヤー", defeated.player_id + 1, "が", amount, "G獲得")
		
		spell_magic.add_magic(defeated.player_id, amount)

## 死亡時遺産効果をまとめて適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_draw SpellDrawインスタンス
## @param spell_magic SpellMagicインスタンス
static func apply_on_death(defeated, spell_draw, spell_magic) -> void:
	print("[DEBUG] SkillLegacy.apply_on_death 呼び出し")
	print("[DEBUG] defeated: ", defeated.creature_data.get("name", "?"))
	print("[DEBUG] ability_detail: ", defeated.creature_data.get("ability_detail", ""))
	
	# 遺産[カード]
	apply_card_legacy(defeated, spell_draw)
	
	# 道産[魔力]
	apply_magic_legacy(defeated, spell_magic)

## ability_detailからカード枚数を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_count デフォルト枚数
## @return カード枚数
static func _extract_card_count(ability_detail: String, default_count: int) -> int:
	# "遺産[カード1枚]" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("遺産\\[カード(\\d+)枚\\]")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_count

## ability_detailから魔力獲得量を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_amount デフォルト値
## @return 魔力獲得量
static func _extract_magic_amount(ability_detail: String, default_amount: int) -> int:
	# "道産[G200]" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("道産\\[G(\\d+)\\]")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_amount
