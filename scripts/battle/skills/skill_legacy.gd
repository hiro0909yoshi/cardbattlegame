## 形見スキル - 死亡時に特殊効果を発動する
##
## 【主な機能】
## - 形見[EP]: 死亡時にEPを獲得
## - 形見[カード]: 死亡時にカードをドロー
## - 形見[周回数×EP]: 死亡時に周回数に応じたEPを獲得
##
## 【該当クリーチャー】
## - フェイト (ID: 136): 形見[カード1枚] (legacy_card)
## - コーンフォーク (ID: 315): 破壊時、形見[200EP] (legacy_magic)
## - クリーピングコイン (ID: 410): 破壊時、形見[100EP] (legacy_magic)
## - マミー (ID: 239): 形見[周回数×40EP] (legacy_magic)

class_name SkillLegacy


## 死亡時形見効果をまとめて適用（JSONベース統一）
##
## @param defeated 撃破されたクリーチャー
## @param spell_draw SpellDrawインスタンス
## @param spell_magic SpellMagicインスタンス
## @param lap_system LapSystemインスタンス（周回数取得用、オプション）
static func apply_on_death(defeated, spell_draw, spell_magic, lap_system = null) -> Dictionary:
	var result = {
		"legacy_ep_activated": false,
		"legacy_ep_amount": 0,
		"legacy_card_activated": false,
		"legacy_card_count": 0
	}

	var ability_parsed = defeated.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])

	for effect in effects:
		if effect.get("trigger", "") != "on_death":
			continue

		var effect_type = effect.get("effect_type", "")

		match effect_type:
			"legacy_ep", "legacy_magic":
				# 形見[EP] - マミー、コーンフォーク、クリーピングコイン等
				if spell_magic:
					var amount = _calculate_legacy_amount(effect, defeated, lap_system)
					if amount > 0:
						spell_magic.add_magic(defeated.player_id, amount)
						print("【形見発動】%s → プレイヤー%dが%d蓄魔" % [
							defeated.creature_data.get("name", "?"),
							defeated.player_id + 1,
							amount
						])
						result["legacy_ep_activated"] = true
						result["legacy_ep_amount"] = amount

			"legacy_card":
				# 形見[カード] - フェイト等
				if spell_draw:
					var card_count = effect.get("card_count", 1)
					print("【形見発動】%s → プレイヤー%dがカード%d枚ドロー" % [
						defeated.creature_data.get("name", "?"),
						defeated.player_id + 1,
						card_count
					])
					var drawn_cards = spell_draw.draw_cards(defeated.player_id, card_count)
					if drawn_cards.size() > 0:
						print("  引いたカード: ", drawn_cards.map(func(c): return c.get("name", "?")))
						result["legacy_card_activated"] = true
						result["legacy_card_count"] = drawn_cards.size()

	return result


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
		var multiplier = 40  # デフォルト
		var regex = RegEx.new()
		regex.compile("lap_count\\s*\\*\\s*(\\d+)")
		var match_result = regex.search(formula)
		if match_result:
			multiplier = int(match_result.get_string(1))
		return lap_count * multiplier

	return effect.get("amount", 0)


## プレイヤーの周回数を取得
static func _get_lap_count(player_id: int, lap_system) -> int:
	if not lap_system:
		return 1
	return lap_system.get_lap_count(player_id)
