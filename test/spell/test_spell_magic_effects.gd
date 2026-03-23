extends GutTest

## SpellMagic EP/Magic操作系テスト
## 各EP操作メソッドのコアロジック検証 + JSON定義確認

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _spell_magic: SpellMagic
var _player_system: PlayerSystem


func before_each():
	_player_system = PlayerSystem.new()
	# 2人プレイヤーセットアップ
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 1000
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 500
	_player_system.players = [p0, p1]

	_spell_magic = SpellMagic.new()
	_spell_magic.setup(_player_system)


func after_each():
	if is_instance_valid(_spell_magic):
		_spell_magic.free()


## JSON定義からeffect_typeを取得
func _get_effect_type(spell_id: int) -> String:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		var et = e.get("effect_type", "")
		if et.begins_with("drain_magic") or et.begins_with("gain_magic") or et == "balance_all_magic" or et == "mhp_to_magic":
			return et
	return ""


# ========================================
# 基本EP操作
# ========================================

## add_magic: EP増加
func test_add_magic():
	_spell_magic.add_magic(0, 200)
	assert_eq(_player_system.players[0].magic_power, 1200, "EP: 1000+200=1200")


## reduce_magic: EP減少
func test_reduce_magic():
	_spell_magic.reduce_magic(0, 300)
	assert_eq(_player_system.players[0].magic_power, 700, "EP: 1000-300=700")


## steal_magic: 吸魔
func test_steal_magic():
	var actual = _spell_magic.steal_magic(1, 0, 200)
	assert_eq(actual, 200, "奪取量: 200")
	assert_eq(_player_system.players[0].magic_power, 1200, "P0: 1000+200=1200")
	assert_eq(_player_system.players[1].magic_power, 300, "P1: 500-200=300")


## steal_magic: 所持EP以上は奪えない
func test_steal_magic_capped():
	var actual = _spell_magic.steal_magic(1, 0, 9999)
	assert_eq(actual, 500, "奪取量: P1の全EP=500")
	assert_eq(_player_system.players[1].magic_power, 0, "P1: 0EP")
	assert_eq(_player_system.players[0].magic_power, 1500, "P0: 1000+500=1500")


# ========================================
# JSON定義確認
# ========================================

## リーチ(2063): drain_magic
func test_reach_json():
	assert_eq(_get_effect_type(2063), "drain_magic", "リーチ: drain_magic")

## ドレイン(2082): drain_magic_conditional
func test_drain_json():
	assert_eq(_get_effect_type(2082), "drain_magic_conditional", "ドレイン: drain_magic_conditional")

## オーバーテイク(2044): drain_magic_by_lap_diff
func test_overtake_json():
	assert_eq(_get_effect_type(2044), "drain_magic_by_lap_diff", "オーバーテイク: drain_magic_by_lap_diff")

## ハーベスト(2119): drain_magic_by_land_count
func test_harvest_json():
	assert_eq(_get_effect_type(2119), "drain_magic_by_land_count", "ハーベスト: drain_magic_by_land_count")

## ラッキー(2020): gain_magic_by_rank
func test_lucky_json():
	assert_eq(_get_effect_type(2020), "gain_magic_by_rank", "ラッキー: gain_magic_by_rank")

## サイクル(2109): gain_magic_by_lap
func test_cycle_json():
	assert_eq(_get_effect_type(2109), "gain_magic_by_lap", "サイクル: gain_magic_by_lap")

## キルボーナス(2007): gain_magic_from_destroyed_count
func test_kill_bonus_json():
	assert_eq(_get_effect_type(2007), "gain_magic_from_destroyed_count", "キルボーナス: gain_magic_from_destroyed_count")

## インサイト(2025): gain_magic_from_spell_cost
func test_insight_json():
	assert_eq(_get_effect_type(2025), "gain_magic_from_spell_cost", "インサイト: gain_magic_from_spell_cost")

## コネクト(2131): gain_magic_from_land_chain
func test_connect_json():
	assert_eq(_get_effect_type(2131), "gain_magic_from_land_chain", "コネクト: gain_magic_from_land_chain")

## バランス(2130): balance_all_magic
func test_balance_json():
	assert_eq(_get_effect_type(2130), "balance_all_magic", "バランス: balance_all_magic")


# ========================================
# drain_magic_from_effect（固定値/割合吸魔）
# ========================================

## 固定値吸魔: 200EP奪取
func test_drain_magic_fixed():
	var effect: Dictionary = {"value": 200, "value_type": "fixed"}
	var actual = _spell_magic.drain_magic_from_effect(effect, 1, 0)
	assert_eq(actual, 200, "固定値: 200EP奪取")
	assert_eq(_player_system.players[0].magic_power, 1200, "P0: +200")
	assert_eq(_player_system.players[1].magic_power, 300, "P1: -200")


## 割合吸魔: 50%
func test_drain_magic_percentage():
	var effect: Dictionary = {"value": 50, "value_type": "percentage"}
	var actual = _spell_magic.drain_magic_from_effect(effect, 1, 0)
	assert_eq(actual, 250, "割合: 500*50%=250EP奪取")
	assert_eq(_player_system.players[1].magic_power, 250, "P1: 500-250=250")


## 固定値が所持EP超過: 全額奪取
func test_drain_magic_fixed_capped():
	var effect: Dictionary = {"value": 9999, "value_type": "fixed"}
	var actual = _spell_magic.drain_magic_from_effect(effect, 1, 0)
	assert_eq(actual, 500, "全額奪取: 500EP")


# ========================================
# drain_magic_conditional（条件付き吸魔）
# ========================================

## 条件成立: 対象が術者よりEP多い → 30%奪取
func test_drain_conditional_success():
	# P0=1000, P1=500 → P0から奪う（P0の方が多い）
	var effect: Dictionary = {"condition": "target_has_more_magic", "percentage": 30}
	var result = _spell_magic.drain_magic_conditional(effect, 0, 1)
	assert_true(result.get("success", false), "条件成立: P0(1000)>P1(500)")
	assert_eq(result.get("amount", 0), 300, "1000*30%=300EP奪取")


## 条件不成立: 対象のEPが術者以下
func test_drain_conditional_fail():
	# P1=500, P0=1000 → P1から奪う（P1の方が少ない）
	var effect: Dictionary = {"condition": "target_has_more_magic", "percentage": 30}
	var result = _spell_magic.drain_magic_conditional(effect, 1, 0)
	assert_false(result.get("success", true), "条件不成立: P1(500)<=P0(1000)")
	assert_eq(result.get("reason", ""), "condition_not_met", "理由: 条件不成立")


# ========================================
# gain_magic_by_rank（ランク別EP獲得）
# ========================================

## 1位 × 50EP = 50EP
func test_gain_magic_by_rank_1st():
	var effect: Dictionary = {"effect_type": "gain_magic_by_rank", "multiplier": 50}
	var result = await _spell_magic.apply_effect(effect, 0, {"rank": 1})
	assert_eq(result.get("amount", 0), 50, "1位: 1*50=50EP")
	assert_eq(_player_system.players[0].magic_power, 1050, "P0: 1000+50=1050")


## 3位 × 50EP = 150EP
func test_gain_magic_by_rank_3rd():
	var effect: Dictionary = {"effect_type": "gain_magic_by_rank", "multiplier": 50}
	var result = await _spell_magic.apply_effect(effect, 0, {"rank": 3})
	assert_eq(result.get("amount", 0), 150, "3位: 3*50=150EP")


# ========================================
# balance_all_magic（全員EP平均化）
# ========================================

## 2人で平均化: (1000+500)/2 = 750
func test_balance_all_magic():
	var result = _spell_magic.balance_all_magic()
	assert_true(result.get("success", false), "成功")
	assert_eq(result.get("average", 0), 750, "平均: 750EP")
	assert_eq(_player_system.players[0].magic_power, 750, "P0: 750EP")
	assert_eq(_player_system.players[1].magic_power, 750, "P1: 750EP")


## 3人で平均化（端数切り捨て）
func test_balance_all_magic_3players():
	var p2 = PlayerSystem.PlayerData.new()
	p2.id = 2
	p2.name = "プレイヤー3"
	p2.magic_power = 200
	_player_system.players.append(p2)
	# (1000+500+200)/3 = 566.67 → 566
	var result = _spell_magic.balance_all_magic()
	assert_eq(result.get("average", 0), 566, "平均: 566EP（端数切捨）")
	assert_eq(_player_system.players[0].magic_power, 566, "P0: 566EP")
	assert_eq(_player_system.players[1].magic_power, 566, "P1: 566EP")
	assert_eq(_player_system.players[2].magic_power, 566, "P2: 566EP")


# ========================================
# drain_magic_by_land_count（土地数×吸魔）
# ========================================

## 敵ドミニオ3つ × 30EP = 90EP吸魔
func test_drain_by_land_count():
	# tile_nodesのみ持つモックボード（get_owner_land_countを持たない→tile_nodesイテレーション経路を使用）
	var mock_board = _MockBoard.new()
	mock_board.tile_nodes = SpellTestHelper.create_tile_nodes()
	# P1の土地を3つ設定
	mock_board.tile_nodes[1].owner_id = 1
	mock_board.tile_nodes[2].owner_id = 1
	mock_board.tile_nodes[3].owner_id = 1
	_spell_magic.board_system_ref = mock_board

	var effect: Dictionary = {"multiplier": 30}
	var result = _spell_magic.drain_magic_by_land_count(effect, 1, 0)
	assert_eq(result.get("land_count", 0), 3, "土地数: 3")
	assert_eq(result.get("amount", 0), 90, "3*30=90EP奪取")
	assert_eq(_player_system.players[0].magic_power, 1090, "P0: 1000+90=1090")
	assert_eq(_player_system.players[1].magic_power, 410, "P1: 500-90=410")


## 敵ドミニオ0 → 奪取なし
func test_drain_by_land_count_zero():
	var mock_board = _MockBoard.new()
	mock_board.tile_nodes = SpellTestHelper.create_tile_nodes()
	_spell_magic.board_system_ref = mock_board

	var effect: Dictionary = {"multiplier": 30}
	var result = _spell_magic.drain_magic_by_land_count(effect, 1, 0)
	assert_eq(result.get("land_count", 0), 0, "土地数: 0")
	assert_eq(result.get("amount", 0), 0, "奪取なし")


# ========================================
# gain_magic_from_land_chain（連続ドミニオ）
# ========================================

## 連続ドミニオ4つで条件達成 → 500EP
func test_land_chain_success():
	var mock_board = _MockBoard.new()
	mock_board.tile_nodes = SpellTestHelper.create_tile_nodes()
	# タイル1-4を連続でP0の土地に
	for i in range(1, 5):
		mock_board.tile_nodes[i].owner_id = 0
	_spell_magic.board_system_ref = mock_board

	var effect: Dictionary = {"required_chain": 4, "amount": 500}
	var result = _spell_magic.gain_magic_from_land_chain(0, effect, {})
	assert_true(result.get("condition_met", false), "条件達成: 連続4ドミニオ")
	assert_eq(result.get("amount", 0), 500, "500EP獲得")
	assert_eq(_player_system.players[0].magic_power, 1500, "P0: 1000+500=1500")


## 連続ドミニオ3つで条件未達成
func test_land_chain_fail():
	var mock_board = _MockBoard.new()
	mock_board.tile_nodes = SpellTestHelper.create_tile_nodes()
	# タイル1-3のみ
	for i in range(1, 4):
		mock_board.tile_nodes[i].owner_id = 0
	_spell_magic.board_system_ref = mock_board

	var effect: Dictionary = {"required_chain": 4, "amount": 500}
	var result = _spell_magic.gain_magic_from_land_chain(0, effect, {})
	assert_false(result.get("condition_met", true), "条件未達成: 連続3ドミニオ")
	assert_eq(result.get("amount", 0), 0, "EP獲得なし")
	assert_eq(_player_system.players[0].magic_power, 1000, "P0: 変化なし")


# ========================================
# JSON定義: 魔女の奪取/生命変換
# ========================================

## 魔女の奪取(9036): drain_magic_by_spell_count
func test_witch_drain_json():
	assert_eq(_get_effect_type(9036), "drain_magic_by_spell_count", "魔女の奪取: drain_magic_by_spell_count")


## 生命変換(9034): mhp_to_magic
func test_life_convert_json():
	assert_eq(_get_effect_type(9034), "mhp_to_magic", "生命変換: mhp_to_magic")


## 生命変換(9034): multiplier=2, stat_penalty確認
func test_life_convert_params():
	var card = CardLoader.get_card_by_id(9034)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "mhp_to_magic":
			assert_eq(int(e.get("multiplier", 0)), 2, "multiplier=2")
			var penalty = e.get("stat_penalty", {})
			assert_eq(int(penalty.get("ap", 0)), -10, "AP-10")
			assert_eq(int(penalty.get("max_hp", 0)), -10, "MHP-10")


# ========================================
# drain_magic_by_spell_count（スペル数吸魔）
# ========================================

## スペル3枚 × 40EP = 120EP奪取
func test_drain_by_spell_count():
	var card_system = CardSystem.new()
	card_system.name = "CardSystem_DrainTest"
	add_child(card_system)
	for pid in range(2):
		card_system.player_decks[pid] = []
		card_system.player_discards[pid] = []
		card_system.player_hands[pid] = {"data": []}
	# P1の手札にスペル3枚追加
	for spell_id in [2016, 2023, 2031]:
		var card_data = CardLoader.get_card_by_id(spell_id).duplicate(true)
		card_system.player_hands[1]["data"].append(card_data)

	var effect: Dictionary = {"multiplier": 40}
	var result = _spell_magic.drain_magic_by_spell_count(effect, 1, 0, card_system)
	assert_true(result.get("success", false), "吸魔成功")
	assert_eq(result.get("spell_count", 0), 3, "スペル3枚")
	assert_eq(result.get("amount", 0), 120, "3*40=120EP奪取")
	assert_eq(_player_system.players[0].magic_power, 1120, "P0: 1000+120=1120")
	assert_eq(_player_system.players[1].magic_power, 380, "P1: 500-120=380")
	if is_instance_valid(card_system):
		card_system.free()


## スペルなし → 失敗
func test_drain_by_spell_count_no_spells():
	var card_system = CardSystem.new()
	card_system.name = "CardSystem_DrainTest2"
	add_child(card_system)
	for pid in range(2):
		card_system.player_decks[pid] = []
		card_system.player_discards[pid] = []
		card_system.player_hands[pid] = {"data": []}
	# P1にクリーチャーカードのみ
	var card_data = CardLoader.get_card_by_id(1).duplicate(true)
	card_system.player_hands[1]["data"].append(card_data)

	var effect: Dictionary = {"multiplier": 40}
	var result = _spell_magic.drain_magic_by_spell_count(effect, 1, 0, card_system)
	assert_false(result.get("success", true), "スペルなし: 失敗")
	assert_eq(result.get("spell_count", -1), 0, "スペル0枚")
	if is_instance_valid(card_system):
		card_system.free()


## 所持EP以上は奪えない
func test_drain_by_spell_count_capped():
	var card_system = CardSystem.new()
	card_system.name = "CardSystem_DrainTest3"
	add_child(card_system)
	for pid in range(2):
		card_system.player_decks[pid] = []
		card_system.player_discards[pid] = []
		card_system.player_hands[pid] = {"data": []}
	# P1にスペル5枚（5*40=200EP > P1所持50EP）
	_player_system.players[1].magic_power = 50
	for spell_id in [2016, 2023, 2031, 2033, 2037]:
		var card_data = CardLoader.get_card_by_id(spell_id).duplicate(true)
		card_system.player_hands[1]["data"].append(card_data)

	var effect: Dictionary = {"multiplier": 40}
	var result = _spell_magic.drain_magic_by_spell_count(effect, 1, 0, card_system)
	assert_eq(result.get("amount", 0), 50, "所持EP上限: 50EP奪取")
	assert_eq(_player_system.players[1].magic_power, 0, "P1: 0EP")
	if is_instance_valid(card_system):
		card_system.free()


# ========================================
# mhp_to_magic（MHP→EP変換）
# ========================================

## MHP40 × 2 = 80EP獲得 + ペナルティ
func test_mhp_to_magic():
	var board = MockBoard.new()
	board.name = "MockBoard_MHP"
	add_child(board)
	board.tile_nodes = Helper.create_tile_nodes()
	var creature = Helper.make_creature("テスト", 40, 30, "fire")
	board.tile_nodes[3].creature_data = creature.duplicate(true)
	board.tile_nodes[3].owner_id = 0
	_spell_magic.board_system_ref = board

	var effect: Dictionary = {"multiplier": 2, "stat_penalty": {"ap": -10, "max_hp": -10}}
	var result = _spell_magic.mhp_to_magic(0, effect, 3)
	assert_true(result.get("success", false), "変換成功")
	assert_eq(result.get("mhp", 0), 40, "MHP=40")
	assert_eq(result.get("amount", 0), 80, "40*2=80EP")
	assert_eq(_player_system.players[0].magic_power, 1080, "P0: 1000+80=1080")
	# ペナルティ確認
	var c = board.tile_nodes[3].creature_data
	assert_eq(c.get("base_up_ap", 0), -10, "AP-10ペナルティ")
	assert_eq(c.get("base_up_hp", 0), -10, "MHP-10ペナルティ")
	if is_instance_valid(board):
		board.free()


## base_up_hp込みのMHP計算
func test_mhp_to_magic_with_base_up():
	var board = MockBoard.new()
	board.name = "MockBoard_MHP2"
	add_child(board)
	board.tile_nodes = Helper.create_tile_nodes()
	var creature = Helper.make_creature("テスト", 40, 30, "fire")
	creature["base_up_hp"] = 10  # MHP = 40+10 = 50
	board.tile_nodes[3].creature_data = creature.duplicate(true)
	board.tile_nodes[3].owner_id = 0
	_spell_magic.board_system_ref = board

	var effect: Dictionary = {"multiplier": 2, "stat_penalty": {"ap": -10, "max_hp": -10}}
	var result = _spell_magic.mhp_to_magic(0, effect, 3)
	assert_eq(result.get("mhp", 0), 50, "MHP=50(40+10)")
	assert_eq(result.get("amount", 0), 100, "50*2=100EP")
	if is_instance_valid(board):
		board.free()


## クリーチャーなし → 失敗
func test_mhp_to_magic_no_creature():
	var board = MockBoard.new()
	board.name = "MockBoard_MHP3"
	add_child(board)
	board.tile_nodes = Helper.create_tile_nodes()
	_spell_magic.board_system_ref = board

	var effect: Dictionary = {"multiplier": 2}
	var result = _spell_magic.mhp_to_magic(0, effect, 3)
	assert_false(result.get("success", true), "クリーチャーなし: 失敗")
	if is_instance_valid(board):
		board.free()


# ========================================
# モック
# ========================================

## tile_nodesのみ持つボードモック（get_owner_land_countを持たない）
class _MockBoard extends RefCounted:
	var tile_nodes: Dictionary = {}
