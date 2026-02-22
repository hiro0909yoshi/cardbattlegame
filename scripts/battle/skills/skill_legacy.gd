## 形見スキル - 死亡時に特殊効果を発動する
##
## 【主な機能】
## - 形見[EP]: 死亡時にEPを獲得
## - 形見[カード]: 死亡時にカードをドロー
## - 形見[周回数×EP]: 死亡時に周回数に応じたEPを獲得
##
## 【該当クリーチャー】
## - フェイト (ID: 136): 形見[カード1枚]（テキスト解析）
## - コーンフォーク (ID: 315): 破壊時、形見[200EP]（テキスト解析）
## - クリーピングコイン (ID: 410): 破壊時、形見[100EP]（テキスト解析）
## - マミー (ID: 239): 形見[周回数×40EP]（JSON形式）
##
## @version 1.2
## @date 2026-01-26

class_name SkillLegacy

## 形見[カード]スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 形見[カード]スキルを持っているか
static func has_card_legacy(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "形見[カード" in ability_detail

## 形見スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 形見スキルを持っているか
static func has_magic_legacy(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "形見[EP" in ability_detail or "破壊時EP形見" in ability_detail

## 形見[カード]を適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_draw SpellDrawインスタンス
static func apply_card_legacy(defeated, spell_draw) -> bool:
	if not spell_draw:
		return false
	
	var has_legacy = has_card_legacy(defeated.creature_data)
	
	if has_legacy:
		var card_count = _extract_card_count(defeated.creature_data.get("ability_detail", ""), 1)
		
		print("【形見発動】", defeated.creature_data.get("name", "?"), 
			  " → プレイヤー", defeated.player_id + 1, "がカード", card_count, "枚ドロー")
		
		# カードドロー.mdの方法: draw_cards()を使用
		var drawn_cards = spell_draw.draw_cards(defeated.player_id, card_count)
		
		if drawn_cards.size() > 0:
			print("  引いたカード: ", drawn_cards.map(func(c): return c.get("name", "?")))
			return true
	
	return false

## 形見[EP]を適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_magic SpellMagicインスタンス
static func apply_magic_legacy(defeated, spell_magic) -> bool:
	if not spell_magic:
		return false
	
	if has_magic_legacy(defeated.creature_data):
		var amount = _extract_magic_amount(defeated.creature_data.get("ability_detail", ""), 100)
		
		print("【形見発動】", defeated.creature_data.get("name", "?"), 
			  " → プレイヤー", defeated.player_id + 1, "が", amount, "蓄魔")
		
		spell_magic.add_magic(defeated.player_id, amount)
		return true
	
	return false

## 死亡時形見効果をまとめて適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_draw SpellDrawインスタンス
## @param spell_magic SpellMagicインスタンス
## @param lap_system LapSystemインスタンス（周回数取得用、オプション）
static func apply_on_death(defeated, spell_draw, spell_magic, lap_system = null) -> Dictionary:
	var result = {"legacy_ep_activated": false, "legacy_card_activated": false}

	# JSON形式の形見効果（マミー等）
	if apply_legacy_from_json(defeated, spell_magic, lap_system):
		result["legacy_ep_activated"] = true
	
	# テキスト形式の形見[カード]
	if apply_card_legacy(defeated, spell_draw):
		result["legacy_card_activated"] = true
	
	# テキスト形式の形見[EP]
	if apply_magic_legacy(defeated, spell_magic):
		result["legacy_ep_activated"] = true
	
	return result


## JSON形式の形見効果を適用（マミー等）
##
## @param defeated 撃破されたクリーチャー
## @param spell_magic SpellMagicインスタンス
## @param lap_system LapSystemインスタンス
static func apply_legacy_from_json(defeated, spell_magic, lap_system) -> bool:
	if not spell_magic:
		return false

	var ability_parsed = defeated.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])

	for effect in effects:
		var trigger = effect.get("trigger", "")
		if trigger != "on_death":
			continue

		var effect_type = effect.get("effect_type", "")

		match effect_type:
			"legacy_ep":
				# 形見[EP] - マミー等
				var amount = _calculate_legacy_amount(effect, defeated, lap_system)
				if amount > 0:
					spell_magic.add_magic(defeated.player_id, amount)
					print("【形見発動】%s → プレイヤー%dが%d蓄魔" % [
						defeated.creature_data.get("name", "?"),
						defeated.player_id + 1,
						amount
					])
					return true
	
	return false


## 形見金額を計算
##
## @param effect 効果データ
## @param defeated 撃破されたクリーチャー
## @param lap_system LapSystemインスタンス
## @return 獲得金額
static func _calculate_legacy_amount(effect: Dictionary, defeated, lap_system) -> int:
	var formula = effect.get("amount_formula", "")

	if formula.is_empty():
		return effect.get("amount", 0)

	# "lap_count * 40" のような形式を解析
	if "lap_count" in formula:
		var lap_count = _get_lap_count(defeated.player_id, lap_system)
		# 式を評価（lap_count * N の形式）
		var multiplier = 40  # デフォルト
		var regex = RegEx.new()
		regex.compile("lap_count\\s*\\*\\s*(\\d+)")
		var match_result = regex.search(formula)
		if match_result:
			multiplier = int(match_result.get_string(1))
		return lap_count * multiplier
	
	return effect.get("amount", 0)


## プレイヤーの周回数を取得
##
## @param player_id プレイヤーID
## @param lap_system LapSystemインスタンス
## @return 周回数
static func _get_lap_count(player_id: int, lap_system) -> int:
	if not lap_system:
		return 1
	return lap_system.get_lap_count(player_id)

## ability_detailからカード枚数を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_count デフォルト枚数
## @return カード枚数
static func _extract_card_count(ability_detail: String, default_count: int) -> int:
	# "形見[カード1枚]" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("形見\\[カード(\\d+)枚\\]")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_count

## ability_detailから蓄魔量を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_amount デフォルト値
## @return 蓄魔量
static func _extract_magic_amount(ability_detail: String, default_amount: int) -> int:
	# "形見[EP200]" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("形見\\[G(\\d+)\\]")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_amount
