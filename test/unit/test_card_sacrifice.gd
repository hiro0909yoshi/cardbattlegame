extends GutTest

## カード犠牲システムのテスト
## CardSacrificeHelper, SummonConditionChecker, CreatureSynthesis,
## SpellSynthesis, CPUSacrificeSelector の選択ロジックと消費処理を検証


# ============================================
# テスト用データ
# ============================================

func _make_creature_card(id: int, name: String, element: String = "fire") -> Dictionary:
	return {
		"id": id, "name": name, "type": "creature",
		"element": element, "ap": 30, "hp": 40,
		"base_ap": 30, "base_hp": 40,
	}


func _make_spell_card(id: int, name: String, spell_type: String = "単体対象") -> Dictionary:
	return {
		"id": id, "name": name, "type": "spell",
		"spell_type": spell_type,
	}


func _make_item_card(id: int, name: String) -> Dictionary:
	return {"id": id, "name": name, "type": "item"}


func _make_sacrifice_creature(id: int, name: String, element: String,
		synthesis: Dictionary, cost_sacrifice: int = 1) -> Dictionary:
	return {
		"id": id, "name": name, "type": "creature",
		"element": element, "ap": 30, "hp": 40,
		"base_ap": 30, "base_hp": 40,
		"cost": {"ep": 60, "cards_sacrifice": cost_sacrifice},
		"cost_cards_sacrifice": cost_sacrifice,
		"synthesis": synthesis,
	}


func _make_sacrifice_spell(id: int, name: String,
		synthesis: Dictionary, cost_sacrifice: int = 1) -> Dictionary:
	return {
		"id": id, "name": name, "type": "spell",
		"cost": {"ep": 100, "cards_sacrifice": cost_sacrifice},
		"cost_cards_sacrifice": cost_sacrifice,
		"effect_parsed": {"effects": [{"effect_type": "damage", "value": 50}]},
		"synthesis": synthesis,
	}


# ============================================
# SummonConditionChecker テスト
# ============================================

func test_requires_sacrifice_with_cost_cards_sacrifice():
	var card = {"cost_cards_sacrifice": 1}
	assert_true(SummonConditionChecker.requires_card_sacrifice(card))


func test_requires_sacrifice_with_nested_cost():
	var card = {"cost": {"ep": 60, "cards_sacrifice": 1}}
	assert_true(SummonConditionChecker.requires_card_sacrifice(card))


func test_requires_sacrifice_zero():
	var card = {"cost_cards_sacrifice": 0}
	assert_false(SummonConditionChecker.requires_card_sacrifice(card))


func test_requires_sacrifice_no_cost():
	var card = {"cost": {"ep": 30}}
	assert_false(SummonConditionChecker.requires_card_sacrifice(card))


func test_requires_sacrifice_cost_is_int():
	var card = {"cost": 30}
	assert_false(SummonConditionChecker.requires_card_sacrifice(card))


func test_requires_sacrifice_empty_card():
	assert_false(SummonConditionChecker.requires_card_sacrifice({}))


# ============================================
# CardSacrificeHelper テスト
# ============================================

var _card_system: CardSystem
var _helper: CardSacrificeHelper


func before_each():
	_card_system = CardSystem.new()
	add_child(_card_system)
	# player_hands を手動セットアップ
	_card_system.player_hands[0] = {"data": []}
	_card_system.player_hands[1] = {"data": []}
	_card_system.player_discards[0] = []
	_card_system.player_discards[1] = []
	_helper = CardSacrificeHelper.new(_card_system, null)


func after_each():
	_card_system.free()


## consume_card: 正常消費 → 手札から消え、捨て札に追加される
func test_consume_card_removes_from_hand():
	var card_a = _make_creature_card(100, "テストA")
	var card_b = _make_creature_card(200, "テストB")
	_card_system.player_hands[0]["data"] = [card_a, card_b]

	var result = _helper.consume_card(0, card_a)

	assert_true(result, "consume_card は true を返すべき")
	assert_eq(_card_system.get_all_cards_for_player(0).size(), 1, "手札は1枚に減るべき")
	assert_eq(_card_system.get_all_cards_for_player(0)[0].get("id"), 200, "残るのはカードB")


## consume_card: 捨て札プールに追加される（修正後のバグ検証）
func test_consume_card_adds_to_discard():
	var card = _make_creature_card(100, "犠牲カード")
	_card_system.player_hands[0]["data"] = [card]

	_helper.consume_card(0, card)

	assert_eq(_card_system.player_discards[0].size(), 1, "捨て札に1枚追加されるべき")


## consume_card: 消費対象でないカードが手札に残ることを確認
func test_consume_card_preserves_other_cards():
	var card_a = _make_creature_card(100, "残るカードA")
	var card_b = _make_creature_card(200, "犠牲カード")
	var card_c = _make_item_card(300, "残るカードC")
	_card_system.player_hands[0]["data"] = [card_a, card_b, card_c]

	_helper.consume_card(0, card_b)

	var hand = _card_system.get_all_cards_for_player(0)
	assert_eq(hand.size(), 2, "2枚残るべき")
	assert_eq(hand[0].get("id"), 100, "カードAが残る")
	assert_eq(hand[1].get("id"), 300, "カードCが残る")


## consume_card: 同IDが2枚ある場合、最初の1枚だけ消費
func test_consume_card_duplicate_ids():
	var card1 = _make_creature_card(100, "同名A")
	var card2 = _make_creature_card(100, "同名B")
	_card_system.player_hands[0]["data"] = [card1, card2]

	_helper.consume_card(0, card1)

	assert_eq(_card_system.get_all_cards_for_player(0).size(), 1, "1枚だけ消費されるべき")


## consume_card: 連続消費が正しく動作する
func test_consume_card_sequential():
	var card_a = _make_creature_card(100, "カードA")
	var card_b = _make_creature_card(200, "カードB")
	var card_c = _make_creature_card(300, "カードC")
	_card_system.player_hands[0]["data"] = [card_a, card_b, card_c]

	_helper.consume_card(0, card_a)
	assert_eq(_card_system.get_all_cards_for_player(0).size(), 2)

	_helper.consume_card(0, card_c)
	assert_eq(_card_system.get_all_cards_for_player(0).size(), 1)
	assert_eq(_card_system.get_all_cards_for_player(0)[0].get("id"), 200, "カードBだけ残る")


## has_valid_cards: フィルタなし
func test_has_valid_cards_no_filter():
	_card_system.player_hands[0]["data"] = [_make_creature_card(1, "C1")]
	assert_true(_helper.has_valid_cards(0))


## has_valid_cards: 空手札
func test_has_valid_cards_empty_hand():
	assert_false(_helper.has_valid_cards(0))


## has_valid_cards: フィルタあり（一致）
func test_has_valid_cards_filter_match():
	_card_system.player_hands[0]["data"] = [_make_spell_card(1, "S1")]
	assert_true(_helper.has_valid_cards(0, "spell"))


## has_valid_cards: フィルタあり（不一致）
func test_has_valid_cards_filter_no_match():
	_card_system.player_hands[0]["data"] = [_make_creature_card(1, "C1")]
	assert_false(_helper.has_valid_cards(0, "spell"))


## get_valid_cards: フィルタで正しく絞り込み
func test_get_valid_cards_filter():
	_card_system.player_hands[0]["data"] = [
		_make_creature_card(1, "C1"),
		_make_spell_card(2, "S1"),
		_make_item_card(3, "I1"),
		_make_spell_card(4, "S2"),
	]
	var spells = _helper.get_valid_cards(0, "spell")
	assert_eq(spells.size(), 2, "スペルは2枚")


## get_valid_cards: フィルタなしは全カード
func test_get_valid_cards_no_filter():
	_card_system.player_hands[0]["data"] = [
		_make_creature_card(1, "C1"),
		_make_spell_card(2, "S1"),
	]
	var all_cards = _helper.get_valid_cards(0)
	assert_eq(all_cards.size(), 2)


# ============================================
# CreatureSynthesis テスト
# ============================================

var _creature_synth: CreatureSynthesis


## 属性条件（element）: 一致する属性で合成成立
func test_creature_synth_element_match():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var sacrifice = _make_creature_card(500, "地クリーチャー", "earth")

	assert_true(_creature_synth.check_condition(creature, sacrifice))


## 属性条件: 不一致の属性では合成不成立
func test_creature_synth_element_mismatch():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var sacrifice = _make_creature_card(500, "火クリーチャー", "fire")

	assert_false(_creature_synth.check_condition(creature, sacrifice))


## アイテム条件: アイテムカードで合成成立
func test_creature_synth_item_match():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(25, "ナイトエラント", "fire", {
		"type": "item",
		"effect_type": "transform", "transform_to": 26
	})
	var sacrifice = _make_item_card(1000, "テストアイテム")

	assert_true(_creature_synth.check_condition(creature, sacrifice))


## アイテム条件: クリーチャーカードでは不成立
func test_creature_synth_item_mismatch():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(25, "ナイトエラント", "fire", {
		"type": "item",
		"effect_type": "transform", "transform_to": 26
	})
	var sacrifice = _make_creature_card(500, "テストクリーチャー")

	assert_false(_creature_synth.check_condition(creature, sacrifice))


## クリーチャー条件: クリーチャーカードで合成成立
func test_creature_synth_creature_match():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(112, "イド", "water", {
		"type": "creature",
		"effect_type": "transform", "transform_to": "sacrifice"
	})
	var sacrifice = _make_creature_card(500, "犠牲クリーチャー", "water")

	assert_true(_creature_synth.check_condition(creature, sacrifice))


## スペル条件: スペルカードで合成成立
func test_creature_synth_spell_match():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(320, "スカラベンドラ", "wind", {
		"type": "spell",
		"effect_type": "transform", "transform_to": 321
	})
	var sacrifice = _make_spell_card(2000, "テストスペル")

	assert_true(_creature_synth.check_condition(creature, sacrifice))


## 刻印スペル条件: 単体特殊能力付与で合成成立
func test_creature_synth_curse_spell_match():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(248, "ワーベア", "earth", {
		"type": "curse_spell",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var sacrifice = _make_spell_card(2050, "刻印スペル", "単体特殊能力付与")

	assert_true(_creature_synth.check_condition(creature, sacrifice))


## 刻印スペル条件: 通常スペルでは不成立
func test_creature_synth_curse_spell_mismatch():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(248, "ワーベア", "earth", {
		"type": "curse_spell",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var sacrifice = _make_spell_card(2000, "通常スペル", "単体対象")

	assert_false(_creature_synth.check_condition(creature, sacrifice))


## synthesis定義なしでは合成不成立
func test_creature_synth_no_synthesis():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_creature_card(999, "合成なし")
	var sacrifice = _make_creature_card(500, "テスト")

	assert_false(_creature_synth.check_condition(creature, sacrifice))


## 犠牲カードが空では合成不成立
func test_creature_synth_empty_sacrifice():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})

	assert_false(_creature_synth.check_condition(creature, {}))


## apply_synthesis: ステータス上昇の適用
func test_creature_synth_apply_stat_boost():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var sacrifice = _make_creature_card(500, "地クリーチャー", "earth")

	var result = _creature_synth.apply_synthesis(creature, sacrifice, true)

	assert_eq(int(result.get("base_ap", 0)), 50, "AP 30+20=50")
	assert_eq(int(result.get("base_hp", 0)), 60, "HP 40+20=60")
	assert_true(result.get("is_synthesized", false), "合成済みフラグ")
	assert_eq(result.get("synthesis_type"), "stat_boost")
	assert_eq(int(result.get("original_card_id", -1)), 22, "元カードID保持")


## apply_synthesis: is_synthesized=false なら変化なし
func test_creature_synth_apply_not_synthesized():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(22, "テスト", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})

	var result = _creature_synth.apply_synthesis(creature, {}, false)

	assert_false(result.has("is_synthesized"), "合成済みフラグなし")
	assert_eq(int(result.get("base_ap", 0)), 30, "APは変化なし")


## apply_synthesis: 変身（犠牲クリーチャーに変身）
func test_creature_synth_apply_transform_sacrifice():
	_creature_synth = CreatureSynthesis.new()
	var creature = _make_sacrifice_creature(112, "イド", "water", {
		"type": "creature",
		"effect_type": "transform", "transform_to": "sacrifice"
	})
	var sacrifice = _make_creature_card(500, "強いクリーチャー", "water")
	sacrifice["ap"] = 60
	sacrifice["hp"] = 80

	var result = _creature_synth.apply_synthesis(creature, sacrifice, true)

	assert_eq(result.get("name"), "強いクリーチャー", "犠牲カード名に変身")
	assert_eq(int(result.get("ap", 0)), 60, "犠牲カードのAP")
	assert_true(result.get("is_synthesized", false))
	assert_eq(result.get("synthesis_type"), "transform")
	assert_eq(result.get("transformed_from"), "イド")


# ============================================
# SpellSynthesis テスト
# ============================================

var _spell_synth: SpellSynthesis


## requires_sacrifice: 正規化済みフィールド
func test_spell_synth_requires_sacrifice():
	_spell_synth = SpellSynthesis.new()
	var spell = {"cost_cards_sacrifice": 1}
	assert_true(_spell_synth.requires_sacrifice(spell))


## requires_sacrifice: ネストされたcost
func test_spell_synth_requires_sacrifice_nested():
	_spell_synth = SpellSynthesis.new()
	var spell = {"cost": {"ep": 100, "cards_sacrifice": 1}}
	assert_true(_spell_synth.requires_sacrifice(spell))


## requires_sacrifice: 犠牲不要
func test_spell_synth_no_sacrifice():
	_spell_synth = SpellSynthesis.new()
	var spell = {"cost": {"ep": 50}}
	assert_false(_spell_synth.requires_sacrifice(spell))


## 同名カード条件: 同IDで合成成立
func test_spell_synth_same_card_match():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2003, "アステロイド", {
		"type": "same_card",
		"effect_override": {"effect_type": "set_level", "value": 1}
	})
	var sacrifice = _make_spell_card(2003, "アステロイド")

	assert_true(_spell_synth.check_condition(spell, sacrifice))


## 同名カード条件: 異なるIDでは不成立
func test_spell_synth_same_card_mismatch():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2003, "アステロイド", {
		"type": "same_card",
		"effect_override": {"effect_type": "set_level", "value": 1}
	})
	var sacrifice = _make_spell_card(2004, "別のスペル")

	assert_false(_spell_synth.check_condition(spell, sacrifice))


## 任意スペル条件: スペルカードで合成成立
func test_spell_synth_any_spell_match():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2107, "マスグロース", {
		"type": "any_spell",
	})
	var sacrifice = _make_spell_card(2000, "何かのスペル")

	assert_true(_spell_synth.check_condition(spell, sacrifice))


## 任意スペル条件: クリーチャーでは不成立
func test_spell_synth_any_spell_mismatch():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2107, "マスグロース", {
		"type": "any_spell",
	})
	var sacrifice = _make_creature_card(500, "テストクリーチャー")

	assert_false(_spell_synth.check_condition(spell, sacrifice))


## クリーチャー条件: クリーチャーで合成成立
func test_spell_synth_creature_match():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2058, "デビリティ", {
		"type": "creature",
	})
	var sacrifice = _make_creature_card(500, "テスト")

	assert_true(_spell_synth.check_condition(spell, sacrifice))


## アイテム条件: アイテムで合成成立
func test_spell_synth_item_match():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2055, "ディスエレメント", {
		"type": "item",
	})
	var sacrifice = _make_item_card(1000, "テストアイテム")

	assert_true(_spell_synth.check_condition(spell, sacrifice))


## 単体対象スペル条件: 一致
func test_spell_synth_single_target_match():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2033, "シャイニングガイザー", {
		"type": "single_target_spell",
	})
	var sacrifice = _make_spell_card(2000, "単体スペル", "単体対象")

	assert_true(_spell_synth.check_condition(spell, sacrifice))


## 単体対象スペル条件: 複数対象では不成立
func test_spell_synth_single_target_mismatch():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2033, "シャイニングガイザー", {
		"type": "single_target_spell",
	})
	var sacrifice = _make_spell_card(2000, "複数スペル", "複数対象")

	assert_false(_spell_synth.check_condition(spell, sacrifice))


## synthesis定義なしでは不成立
func test_spell_synth_no_synthesis():
	_spell_synth = SpellSynthesis.new()
	var spell = {"id": 9999, "name": "通常スペル", "type": "spell"}
	var sacrifice = _make_spell_card(2000, "テスト")

	assert_false(_spell_synth.check_condition(spell, sacrifice))


## apply_overrides: effect_override でエフェクトが書き換わる
func test_spell_synth_apply_effect_override():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2003, "アステロイド", {
		"type": "same_card",
		"effect_override": {"effect_type": "set_level", "value": 1}
	})

	var result = _spell_synth.apply_overrides(spell, true)

	assert_eq(result["effects"][0]["effect_type"], "set_level")
	assert_eq(int(result["effects"][0]["value"]), 1)


## apply_overrides: is_synthesized=false なら元のeffect_parsedを返す
func test_spell_synth_apply_not_synthesized():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2003, "アステロイド", {
		"type": "same_card",
		"effect_override": {"effect_type": "set_level", "value": 1}
	})

	var result = _spell_synth.apply_overrides(spell, false)

	assert_eq(result["effects"][0]["effect_type"], "damage", "元のeffectが維持される")
	assert_eq(int(result["effects"][0]["value"]), 50)


## apply_overrides: value_override のみ
func test_spell_synth_apply_value_override():
	_spell_synth = SpellSynthesis.new()
	var spell = _make_sacrifice_spell(2017, "エロージョン", {
		"type": "any_spell",
		"value_override": 100
	})

	var result = _spell_synth.apply_overrides(spell, true)

	assert_eq(int(result["effects"][0]["value"]), 100, "valueが上書きされる")
	assert_eq(result["effects"][0]["effect_type"], "damage", "effect_typeは維持")


# ============================================
# CPUSacrificeSelector テスト
# ============================================

var _cpu_selector: CPUSacrificeSelector


## スペル犠牲: 合成条件に合うカードを優先選択
func test_cpu_select_spell_synthesis_priority():
	_cpu_selector = CPUSacrificeSelector.new()
	_spell_synth = SpellSynthesis.new()
	_cpu_selector.initialize(_card_system, null, _spell_synth)

	var spell = _make_sacrifice_spell(2003, "アステロイド", {
		"type": "same_card",
	})
	# 手札: アステロイド(同名=合成可), クリーチャー(高レート)
	var same_spell = _make_spell_card(2003, "アステロイド")
	same_spell["rate"] = 80
	var creature = _make_creature_card(500, "高レートクリーチャー")
	creature["rate"] = 30
	_card_system.player_hands[0]["data"] = [spell, same_spell, creature]

	var selected = _cpu_selector.select_sacrifice_card(spell, 0, true)

	assert_eq(selected.get("id"), 2003, "同名カード（合成条件一致）が選択されるべき")


## スペル犠牲: 合成不要ならレート最低を選択
func test_cpu_select_spell_lowest_rate():
	_cpu_selector = CPUSacrificeSelector.new()
	_cpu_selector.initialize(_card_system)

	var spell = _make_sacrifice_spell(2003, "テスト", {"type": "same_card"})
	var card_low = _make_creature_card(100, "低レート")
	card_low["rate"] = 10
	var card_high = _make_creature_card(200, "高レート")
	card_high["rate"] = 90
	_card_system.player_hands[0]["data"] = [spell, card_low, card_high]

	var selected = _cpu_selector.select_sacrifice_card(spell, 0, false)

	assert_eq(selected.get("id"), 100, "レート最低が選択されるべき")


## スペル犠牲: 手札が使用スペルだけ（犠牲なし）
func test_cpu_select_spell_only_self():
	_cpu_selector = CPUSacrificeSelector.new()
	_cpu_selector.initialize(_card_system)

	var spell = _make_sacrifice_spell(2003, "テスト", {"type": "same_card"})
	_card_system.player_hands[0]["data"] = [spell]

	var selected = _cpu_selector.select_sacrifice_card(spell, 0, false)

	assert_true(selected.is_empty(), "自分自身は除外されるので空")


## クリーチャー犠牲: 合成条件一致のカードを優先
func test_cpu_select_creature_synthesis_priority():
	_cpu_selector = CPUSacrificeSelector.new()
	_creature_synth = CreatureSynthesis.new()
	_cpu_selector.initialize(_card_system, null, null, _creature_synth)

	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var earth_card = _make_creature_card(500, "地クリーチャー", "earth")
	earth_card["rate"] = 50
	var fire_card = _make_creature_card(600, "火クリーチャー", "fire")
	fire_card["rate"] = 10  # レートは低いが合成条件に合わない
	_card_system.player_hands[0]["data"] = [creature, earth_card, fire_card]

	var result = _cpu_selector.select_sacrifice_for_creature(creature, 0)

	assert_eq(result.get("card", {}).get("id"), 500, "地属性カードが合成条件一致で選択されるべき")
	assert_true(result.get("should_synthesize", false), "合成フラグが立つべき")


## クリーチャー犠牲: 合成条件に合うカードがなければ合成せずレート最低
func test_cpu_select_creature_no_match_fallback():
	_cpu_selector = CPUSacrificeSelector.new()
	_creature_synth = CreatureSynthesis.new()
	_cpu_selector.initialize(_card_system, null, null, _creature_synth)

	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var fire_card = _make_creature_card(500, "火カード", "fire")
	fire_card["rate"] = 50
	var water_card = _make_creature_card(600, "水カード", "water")
	water_card["rate"] = 10
	_card_system.player_hands[0]["data"] = [creature, fire_card, water_card]

	var result = _cpu_selector.select_sacrifice_for_creature(creature, 0)

	assert_eq(result.get("card", {}).get("id"), 600, "レート最低が選択されるべき")
	assert_false(result.get("should_synthesize", true), "合成しないフラグ")


## クリーチャー犠牲: synthesis定義なしでもレート最低を選択
func test_cpu_select_creature_no_synthesis():
	_cpu_selector = CPUSacrificeSelector.new()
	_cpu_selector.initialize(_card_system)

	var creature = _make_creature_card(999, "合成なし")
	creature["cost"] = {"ep": 30, "cards_sacrifice": 1}
	creature["cost_cards_sacrifice"] = 1
	var low_card = _make_item_card(100, "低レート")
	low_card["rate"] = 5
	var high_card = _make_spell_card(200, "高レート")
	high_card["rate"] = 80
	_card_system.player_hands[0]["data"] = [creature, low_card, high_card]

	var result = _cpu_selector.select_sacrifice_for_creature(creature, 0)

	assert_eq(result.get("card", {}).get("id"), 100, "レート最低が選択されるべき")
	assert_false(result.get("should_synthesize", true))


## _get_hand_excluding_card: 使用カード自身は除外される
func test_cpu_hand_excluding_self():
	_cpu_selector = CPUSacrificeSelector.new()
	_cpu_selector.initialize(_card_system)

	var spell = _make_spell_card(2003, "アステロイド")
	var other = _make_creature_card(500, "テスト")
	_card_system.player_hands[0]["data"] = [spell, other]

	# has_valid_sacrifice_for_spell で間接テスト
	assert_true(_cpu_selector.has_valid_sacrifice_for_spell(spell, 0, false))


## has_valid_sacrifice_for_spell: 合成用で条件一致カードがある
func test_cpu_has_valid_sacrifice_spell_synthesis():
	_cpu_selector = CPUSacrificeSelector.new()
	_spell_synth = SpellSynthesis.new()
	_cpu_selector.initialize(_card_system, null, _spell_synth)

	var spell = _make_sacrifice_spell(2003, "アステロイド", {"type": "same_card"})
	var same = _make_spell_card(2003, "アステロイド")
	_card_system.player_hands[0]["data"] = [spell, same]

	assert_true(_cpu_selector.has_valid_sacrifice_for_spell(spell, 0, true))


## has_valid_sacrifice_for_spell: 合成用だが条件一致カードなし
func test_cpu_has_no_valid_sacrifice_spell_synthesis():
	_cpu_selector = CPUSacrificeSelector.new()
	_spell_synth = SpellSynthesis.new()
	_cpu_selector.initialize(_card_system, null, _spell_synth)

	var spell = _make_sacrifice_spell(2003, "アステロイド", {"type": "same_card"})
	var other = _make_creature_card(500, "テスト")
	_card_system.player_hands[0]["data"] = [spell, other]

	assert_false(_cpu_selector.has_valid_sacrifice_for_spell(spell, 0, true))


## has_valid_sacrifice_for_creature: 合成用で条件一致カードがある
func test_cpu_has_valid_sacrifice_creature_synthesis():
	_cpu_selector = CPUSacrificeSelector.new()
	_creature_synth = CreatureSynthesis.new()
	_cpu_selector.initialize(_card_system, null, null, _creature_synth)

	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var earth = _make_creature_card(500, "地", "earth")
	_card_system.player_hands[0]["data"] = [creature, earth]

	assert_true(_cpu_selector.has_valid_sacrifice_for_creature(creature, 0, true))


## has_valid_sacrifice_for_creature: 合成用だが条件一致なし
func test_cpu_has_no_valid_sacrifice_creature_synthesis():
	_cpu_selector = CPUSacrificeSelector.new()
	_creature_synth = CreatureSynthesis.new()
	_cpu_selector.initialize(_card_system, null, null, _creature_synth)

	var creature = _make_sacrifice_creature(22, "デッドウォーロード", "fire", {
		"type": "element", "condition": "earth",
		"effect_type": "stat_boost", "effect": {"ap": 20, "mhp": 20}
	})
	var fire = _make_creature_card(500, "火", "fire")
	_card_system.player_hands[0]["data"] = [creature, fire]

	assert_false(_cpu_selector.has_valid_sacrifice_for_creature(creature, 0, true))


## イド（犠牲クリーチャーに変身）: 土地属性一致で最高レートを選択
func test_cpu_ido_selects_best_matching_creature():
	_cpu_selector = CPUSacrificeSelector.new()
	_creature_synth = CreatureSynthesis.new()
	_cpu_selector.initialize(_card_system, null, null, _creature_synth)

	var ido = _make_sacrifice_creature(112, "イド", "water", {
		"type": "creature",
		"effect_type": "transform", "transform_to": "sacrifice"
	})
	var water_weak = _make_creature_card(500, "弱い水", "water")
	water_weak["rate"] = 30
	var water_strong = _make_creature_card(600, "強い水", "water")
	water_strong["rate"] = 90
	var fire_card = _make_creature_card(700, "火", "fire")
	fire_card["rate"] = 95
	_card_system.player_hands[0]["data"] = [ido, water_weak, water_strong, fire_card]

	var result = _cpu_selector.select_sacrifice_for_creature(ido, 0, "water")

	assert_eq(result.get("card", {}).get("id"), 600, "水属性の最高レートが選択されるべき")
	assert_true(result.get("should_synthesize", false))


# ============================================
# adjust_index_after_sacrifice テスト
# ============================================

## 犠牲インデックスがカードインデックスより前 → 調整される
func test_adjust_index_sacrifice_before():
	assert_eq(CPUTileActionExecutor.adjust_index_after_sacrifice(5, 3), 4)


## 犠牲インデックスがカードインデックスより後 → 調整されない
func test_adjust_index_sacrifice_after():
	assert_eq(CPUTileActionExecutor.adjust_index_after_sacrifice(2, 5), 2)


## 犠牲インデックスがカードインデックスと同じ → 調整されない
func test_adjust_index_sacrifice_same():
	assert_eq(CPUTileActionExecutor.adjust_index_after_sacrifice(3, 3), 3)


## 犠牲インデックスが-1（犠牲なし） → 調整されない
func test_adjust_index_no_sacrifice():
	assert_eq(CPUTileActionExecutor.adjust_index_after_sacrifice(5, -1), 5)


## 犠牲インデックスが0（先頭カード犠牲） → 全インデックスが調整
func test_adjust_index_sacrifice_first():
	assert_eq(CPUTileActionExecutor.adjust_index_after_sacrifice(1, 0), 0)
	assert_eq(CPUTileActionExecutor.adjust_index_after_sacrifice(6, 0), 5)


## イド: 土地属性一致のクリーチャーがなければ合成せずレート最低
func test_cpu_ido_no_matching_element():
	_cpu_selector = CPUSacrificeSelector.new()
	_creature_synth = CreatureSynthesis.new()
	_cpu_selector.initialize(_card_system, null, null, _creature_synth)

	var ido = _make_sacrifice_creature(112, "イド", "water", {
		"type": "creature",
		"effect_type": "transform", "transform_to": "sacrifice"
	})
	var fire_card = _make_creature_card(500, "火", "fire")
	fire_card["rate"] = 50
	var item = _make_item_card(1000, "アイテム")
	item["rate"] = 10
	_card_system.player_hands[0]["data"] = [ido, fire_card, item]

	var result = _cpu_selector.select_sacrifice_for_creature(ido, 0, "water")

	assert_eq(result.get("card", {}).get("id"), 1000, "レート最低（フォールバック）")
	assert_false(result.get("should_synthesize", true), "合成しない")
