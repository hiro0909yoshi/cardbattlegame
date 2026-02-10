## 遺産スキル - 死亡時に特殊効果を発動する
##
## 【主な機能】
## - 遺産[EP]: 死亡時にEPを獲得
## - 遺産[カード]: 死亡時にカードをドロー
## - 遺産[周回数×EP]: 死亡時に周回数に応じたEPを獲得
##
## 【該当クリーチャー】
## - フェイト (ID: 136): 遺産[カード1枚]（テキスト解析）
## - コーンフォーク (ID: 315): 破壊時、遺産[200EP]（テキスト解析）
## - クリーピングコイン (ID: 410): 破壊時、遺産[100EP]（テキスト解析）
## - マミー (ID: 239): 遺産[周回数×40EP]（JSON形式）
##
## @version 1.2
## @date 2026-01-26

class_name SkillLegacy

## 遺産[カード]スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 遺産[カード]スキルを持っているか
static func has_card_legacy(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "遺産[カード" in ability_detail

## 遺産スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 遺産スキルを持っているか
static func has_magic_legacy(creature_data: Dictionary) -> bool:
	var ability_detail = creature_data.get("ability_detail", "")
	return "遺産[EP" in ability_detail or "破壊時EP遺産" in ability_detail

## 遺産[カード]を適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_draw SpellDrawインスタンス
static func apply_card_legacy(defeated, spell_draw) -> bool:
	if not spell_draw:
		return false
	
	var has_legacy = has_card_legacy(defeated.creature_data)
	
	if has_legacy:
		var card_count = _extract_card_count(defeated.creature_data.get("ability_detail", ""), 1)
		
		print("【遺産発動】", defeated.creature_data.get("name", "?"), 
			  " → プレイヤー", defeated.player_id + 1, "がカード", card_count, "枚ドロー")
		
		# カードドロー.mdの方法: draw_cards()を使用
		var drawn_cards = spell_draw.draw_cards(defeated.player_id, card_count)
		
		if drawn_cards.size() > 0:
			print("  引いたカード: ", drawn_cards.map(func(c): return c.get("name", "?")))
			return true
	
	return false

## 遺産[EP]を適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_magic SpellMagicインスタンス
static func apply_magic_legacy(defeated, spell_magic) -> bool:
	if not spell_magic:
		return false
	
	if has_magic_legacy(defeated.creature_data):
		var amount = _extract_magic_amount(defeated.creature_data.get("ability_detail", ""), 100)
		
		print("【遺産発動】", defeated.creature_data.get("name", "?"), 
			  " → プレイヤー", defeated.player_id + 1, "が", amount, "EP獲得")
		
		spell_magic.add_magic(defeated.player_id, amount)
		return true
	
	return false

## 死亡時遺産効果をまとめて適用
##
## @param defeated 撃破されたクリーチャー
## @param spell_draw SpellDrawインスタンス
## @param spell_magic SpellMagicインスタンス
## @param game_flow_manager GameFlowManagerインスタンス（周回数取得用、オプション）
static func apply_on_death(defeated, spell_draw, spell_magic, game_flow_manager = null) -> Dictionary:
	var result = {"legacy_ep_activated": false, "legacy_card_activated": false}
	
	# JSON形式の遺産効果（マミー等）
	if apply_legacy_from_json(defeated, spell_magic, game_flow_manager):
		result["legacy_ep_activated"] = true
	
	# テキスト形式の遺産[カード]
	if apply_card_legacy(defeated, spell_draw):
		result["legacy_card_activated"] = true
	
	# テキスト形式の遺産[EP]
	if apply_magic_legacy(defeated, spell_magic):
		result["legacy_ep_activated"] = true
	
	return result


## JSON形式の遺産効果を適用（マミー等）
##
## @param defeated 撃破されたクリーチャー
## @param spell_magic SpellMagicインスタンス
## @param game_flow_manager GameFlowManagerインスタンス
static func apply_legacy_from_json(defeated, spell_magic, game_flow_manager) -> bool:
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
				# 遺産[EP] - マミー等
				var amount = _calculate_legacy_amount(effect, defeated, game_flow_manager)
				if amount > 0:
					spell_magic.add_magic(defeated.player_id, amount)
					print("【遺産発動】%s → プレイヤー%dが%dEP獲得" % [
						defeated.creature_data.get("name", "?"),
						defeated.player_id + 1,
						amount
					])
					return true
	
	return false


## 遺産金額を計算
##
## @param effect 効果データ
## @param defeated 撃破されたクリーチャー
## @param game_flow_manager GameFlowManagerインスタンス
## @return 獲得金額
static func _calculate_legacy_amount(effect: Dictionary, defeated, game_flow_manager) -> int:
	var formula = effect.get("amount_formula", "")
	
	if formula.is_empty():
		return effect.get("amount", 0)
	
	# "lap_count * 40" のような形式を解析
	if "lap_count" in formula:
		var lap_count = _get_lap_count(defeated.player_id, game_flow_manager)
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
## @param game_flow_manager GameFlowManagerインスタンス
## @return 周回数
static func _get_lap_count(player_id: int, game_flow_manager) -> int:
	if not game_flow_manager or not game_flow_manager.lap_system:
		return 1
	return game_flow_manager.lap_system.get_lap_count(player_id)

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

## ability_detailからEP獲得量を抽出
##
## @param ability_detail 能力詳細文字列
## @param default_amount デフォルト値
## @return EP獲得量
static func _extract_magic_amount(ability_detail: String, default_amount: int) -> int:
	# "遺産[EP200]" のような形式から数値を抽出
	var regex = RegEx.new()
	regex.compile("遺産\\[G(\\d+)\\]")
	var result = regex.search(ability_detail)
	
	if result:
		return int(result.get_string(1))
	
	return default_amount
