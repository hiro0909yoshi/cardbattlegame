extends GutTest

## SpellDice サイコロ操作テスト
## ダイス刻印の付与 + get_modified_dice_value による出目変更 + JSON定義確認

var _spell_dice: SpellDice
var _spell_curse: SpellCurse
var _player_system: PlayerSystem


func before_each():
	_player_system = PlayerSystem.new()
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 1000
	_player_system.players = [p0]

	_spell_curse = SpellCurse.new()
	_spell_curse.player_system = _player_system

	_spell_dice = SpellDice.new()
	_spell_dice.setup(_player_system, _spell_curse)


func after_each():
	if _spell_dice and is_instance_valid(_spell_dice):
		_spell_dice.queue_free()
	if _spell_curse and is_instance_valid(_spell_curse):
		_spell_curse.queue_free()


## JSON定義からeffect_typeを取得
func _get_dice_effect_type(spell_id: int) -> String:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		var et = e.get("effect_type", "")
		if et.begins_with("dice_"):
			return et
	return ""


## JSON定義からdice固定値を取得
func _get_dice_fixed_value(spell_id: int) -> int:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type") == "dice_fixed":
			return e.get("value", 0)
	return 0


## JSON定義からdice範囲を取得
func _get_dice_range(spell_id: int) -> Dictionary:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		var et = e.get("effect_type", "")
		if et == "dice_range" or et == "dice_range_magic":
			return {"min": e.get("min", 0), "max": e.get("max", 0)}
	return {}


# ========================================
# JSON定義確認
# ========================================

## フェイト1(2098): dice_fixed, value=1
func test_fate1_json():
	assert_eq(_get_dice_effect_type(2098), "dice_fixed", "フェイト1: dice_fixed")
	assert_eq(_get_dice_fixed_value(2098), 1, "フェイト1: value=1")

## フェイト3(2099): dice_fixed, value=3
func test_fate3_json():
	assert_eq(_get_dice_effect_type(2099), "dice_fixed", "フェイト3: dice_fixed")
	assert_eq(_get_dice_fixed_value(2099), 3, "フェイト3: value=3")

## フェイト6(2100): dice_fixed, value=6
func test_fate6_json():
	assert_eq(_get_dice_effect_type(2100), "dice_fixed", "フェイト6: dice_fixed")
	assert_eq(_get_dice_fixed_value(2100), 6, "フェイト6: value=6")

## フェイト8(2101): dice_fixed, value=8
func test_fate8_json():
	assert_eq(_get_dice_effect_type(2101), "dice_fixed", "フェイト8: dice_fixed")
	assert_eq(_get_dice_fixed_value(2101), 8, "フェイト8: value=8")

## 翼神刻印(9016): dice_fixed
func test_wing_god_json():
	assert_eq(_get_dice_effect_type(9016), "dice_fixed", "翼神刻印: dice_fixed")

## 快足刻印(9017): dice_fixed
func test_swift_json():
	assert_eq(_get_dice_effect_type(9017), "dice_fixed", "快足刻印: dice_fixed")

## ダッシュ(2091): dice_range
func test_dash_json():
	assert_eq(_get_dice_effect_type(2091), "dice_range", "ダッシュ: dice_range")

## 泥沼刻印(9029): dice_range
func test_swamp_json():
	assert_eq(_get_dice_effect_type(9029), "dice_range", "泥沼刻印: dice_range")

## マルチ(2080): dice_multi
func test_multi_json():
	assert_eq(_get_dice_effect_type(2080), "dice_multi", "マルチ: dice_multi")

## ジャーニー(2051): dice_range_magic
func test_journey_json():
	assert_eq(_get_dice_effect_type(2051), "dice_range_magic", "ジャーニー: dice_range_magic")


# ========================================
# dice_fixed: ダイス固定
# ========================================

## ダイス固定6: 出目が常に6
func test_dice_fixed_6():
	_spell_dice.apply_dice_fixed_effect(
		{"value": 6, "duration": 1, "name": "フェイト6"},
		{}, 0
	)
	var result = _spell_dice.get_modified_dice_value(0, 3)
	assert_eq(result, 6, "固定6: 出目=6")


## ダイス固定1: 出目が常に1
func test_dice_fixed_1():
	_spell_dice.apply_dice_fixed_effect(
		{"value": 1, "duration": 1, "name": "フェイト1"},
		{}, 0
	)
	var result = _spell_dice.get_modified_dice_value(0, 5)
	assert_eq(result, 1, "固定1: 出目=1")


## ダイス固定8: 出目が常に8
func test_dice_fixed_8():
	_spell_dice.apply_dice_fixed_effect(
		{"value": 8, "duration": 1, "name": "フェイト8"},
		{}, 0
	)
	var result = _spell_dice.get_modified_dice_value(0, 4)
	assert_eq(result, 8, "固定8: 出目=8")


## 刻印なし: 元の出目がそのまま
func test_no_curse_original_value():
	var result = _spell_dice.get_modified_dice_value(0, 4)
	assert_eq(result, 4, "刻印なし: 元の出目4")


# ========================================
# dice_range: ダイス範囲指定
# ========================================

## 範囲6-8: 出目が6-8の範囲内
func test_dice_range_6_8():
	_spell_dice.apply_dice_range_effect(
		{"min": 6, "max": 8, "duration": 1, "name": "ダッシュ"},
		{}, 0
	)
	# 10回試行して全て範囲内か確認
	for i in range(10):
		var result = _spell_dice.get_modified_dice_value(0, 3)
		assert_true(result >= 6 and result <= 8, "範囲6-8: 出目%d" % result)


## 範囲1-2: 出目が1-2の範囲内（泥沼）
func test_dice_range_1_2():
	_spell_dice.apply_dice_range_effect(
		{"min": 1, "max": 2, "duration": 1, "name": "泥沼"},
		{}, 0
	)
	for i in range(10):
		var result = _spell_dice.get_modified_dice_value(0, 5)
		assert_true(result >= 1 and result <= 2, "範囲1-2: 出目%d" % result)


## has_dice_range_curse: 範囲刻印判定
func test_has_dice_range_curse():
	assert_false(_spell_dice.has_dice_range_curse(0), "刻印なし: false")
	_spell_dice.apply_dice_range_effect(
		{"min": 6, "max": 8, "duration": 1}, {}, 0
	)
	assert_true(_spell_dice.has_dice_range_curse(0), "範囲刻印あり: true")


## get_dice_range_info: 範囲情報取得
func test_get_dice_range_info():
	_spell_dice.apply_dice_range_effect(
		{"min": 6, "max": 8, "duration": 1, "name": "ダッシュ"}, {}, 0
	)
	var info = _spell_dice.get_dice_range_info(0)
	assert_eq(info.get("min", 0), 6, "min=6")
	assert_eq(info.get("max", 0), 8, "max=8")


# ========================================
# dice_multi: 複数ダイス
# ========================================

## 複数ダイス: needs_multi_roll判定
func test_dice_multi_needs_multi_roll():
	assert_false(_spell_dice.needs_multi_roll(0), "刻印なし: false")
	_spell_dice.apply_dice_multi_effect(
		{"count": 2, "duration": 1, "name": "マルチ"}, {}, 0
	)
	assert_true(_spell_dice.needs_multi_roll(0), "マルチ刻印: true")


## 複数ダイス: ロール回数取得
func test_dice_multi_roll_count():
	_spell_dice.apply_dice_multi_effect(
		{"count": 2, "duration": 1, "name": "マルチ"}, {}, 0
	)
	assert_eq(_spell_dice.get_multi_roll_count(0), 2, "ロール回数: 2")


## 複数ダイス: 3つなら3rdダイスも必要
func test_dice_multi_needs_third():
	_spell_dice.apply_dice_multi_effect(
		{"count": 3, "duration": 1, "name": "マルチ3"}, {}, 0
	)
	assert_true(_spell_dice.needs_third_dice(0), "3ダイス: 3rd必要")


## 複数ダイス: 2つなら3rdダイス不要
func test_dice_multi_no_third():
	_spell_dice.apply_dice_multi_effect(
		{"count": 2, "duration": 1, "name": "マルチ2"}, {}, 0
	)
	assert_false(_spell_dice.needs_third_dice(0), "2ダイス: 3rd不要")


## 刻印なし: ロール回数1
func test_no_curse_roll_count():
	assert_eq(_spell_dice.get_multi_roll_count(0), 1, "刻印なし: ロール回数1")


# ========================================
# dice_range_magic: 範囲指定+蓄魔
# ========================================

## 範囲指定+蓄魔: 出目が範囲内
func test_dice_range_magic_range():
	_spell_dice.apply_dice_range_magic_effect(
		{"min": 3, "max": 5, "magic": 100, "duration": 1, "name": "ジャーニー"},
		{}, 0
	)
	for i in range(10):
		var result = _spell_dice.get_modified_dice_value(0, 1)
		assert_true(result >= 3 and result <= 5, "範囲3-5: 出目%d" % result)


## 蓄魔判定: should_grant_magic
func test_dice_range_magic_should_grant():
	assert_false(_spell_dice.should_grant_magic(0), "刻印なし: false")
	_spell_dice.apply_dice_range_magic_effect(
		{"min": 3, "max": 5, "magic": 100, "duration": 1}, {}, 0
	)
	assert_true(_spell_dice.should_grant_magic(0), "ジャーニー刻印: true")


## 蓄魔量取得
func test_dice_range_magic_amount():
	_spell_dice.apply_dice_range_magic_effect(
		{"min": 3, "max": 5, "magic": 100, "duration": 1}, {}, 0
	)
	assert_eq(_spell_dice.get_magic_grant_amount(0), 100, "蓄魔量: 100EP")


## process_magic_grant: EP実際に付与される
func test_dice_range_magic_grant():
	_spell_dice.apply_dice_range_magic_effect(
		{"min": 3, "max": 5, "magic": 100, "duration": 1}, {}, 0
	)
	var result = _spell_dice.process_magic_grant(0)
	assert_true(result.has("message"), "結果メッセージあり")
	assert_eq(_player_system.players[0].magic_power, 1100, "P0: 1000+100=1100EP")


## dice_range通常刻印ではshouldGrantMagicはfalse
func test_dice_range_no_magic_grant():
	_spell_dice.apply_dice_range_effect(
		{"min": 6, "max": 8, "duration": 1}, {}, 0
	)
	assert_false(_spell_dice.should_grant_magic(0), "dice_range: 蓄魔なし")


## has_dice_range_curse: dice_range_magicも範囲刻印として判定
func test_dice_range_magic_is_range_curse():
	_spell_dice.apply_dice_range_magic_effect(
		{"min": 3, "max": 5, "magic": 100, "duration": 1}, {}, 0
	)
	assert_true(_spell_dice.has_dice_range_curse(0), "dice_range_magic: 範囲刻印あり")


# ========================================
# ターゲット指定テスト
# ========================================

## target_type=none: 自分自身に適用
func test_target_none_applies_to_self():
	_spell_dice.apply_dice_fixed_effect(
		{"value": 6, "duration": 1}, {"type": "none"}, 0
	)
	var result = _spell_dice.get_modified_dice_value(0, 3)
	assert_eq(result, 6, "自分自身: 出目=6")


## target_type=player: 指定プレイヤーに適用
func test_target_player_applies_to_target():
	# P1を追加
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 500
	_player_system.players.append(p1)

	_spell_dice.apply_dice_fixed_effect(
		{"value": 1, "duration": 1},
		{"type": "player", "player_id": 1}, 0
	)
	# P0は影響なし、P1に刻印
	var result_p0 = _spell_dice.get_modified_dice_value(0, 5)
	var result_p1 = _spell_dice.get_modified_dice_value(1, 5)
	assert_eq(result_p0, 5, "P0: 影響なし")
	assert_eq(result_p1, 1, "P1: 固定1")
