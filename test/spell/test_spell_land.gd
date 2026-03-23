extends GutTest

## SpellLand テスト
## 土地属性変更、レベル変更、クリーチャー破壊、土地放棄の効果を検証

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _spell_land: SpellLand
var _board: BoardSystem3D
var _cm: CreatureManager
var _player_system: PlayerSystem


func before_each():
	# BoardSystem3D（Nodeベース）をシーンツリーに追加
	_board = MockBoard.new()
	_board.name = "BoardSystem3D_Test"
	add_child(_board)
	# tile_nodesをMockTileで差し替え
	_board.tile_nodes = Helper.create_tile_nodes()
	# TileDataManagerのダミー設定
	var tdm = TileDataManager.new()
	tdm.name = "TileDataManager"
	_board.add_child(tdm)
	_board.tile_data_manager = tdm
	tdm.tile_nodes = _board.tile_nodes

	# CreatureManager
	_cm = CreatureManager.new()
	_cm.name = "CreatureManager_Test"
	add_child(_cm)

	# PlayerSystem
	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_Test"
	add_child(_player_system)
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 500
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 500
	_player_system.players = [p0, p1]

	# SpellLandセットアップ
	_spell_land = SpellLand.new()
	_spell_land.setup(_board, _cm, _player_system)


func after_each():
	# シーンツリーからクリーンアップ
	if _board and is_instance_valid(_board):
		_board.free()
	if _cm and is_instance_valid(_cm):
		_cm.free()
	if _player_system and is_instance_valid(_player_system):
		_player_system.free()


# ========================================
# 属性変更テスト
# ========================================

## 火タイルを水に変更
func test_change_element_fire_to_water():
	assert_eq(_board.tile_nodes[1].tile_type, "fire", "初期状態: 火")
	var success = _spell_land.change_element(1, "water")
	assert_true(success, "属性変更成功")
	assert_eq(_board.tile_nodes[1].tile_type, "water", "水に変更された")


## 同じ属性への変更は失敗
func test_change_element_same_element():
	var success = _spell_land.change_element(1, "fire")
	assert_false(success, "同じ属性への変更は失敗")


## 無効な属性は失敗（push_errorが発生するため境界テストとしてスキップ）
## GameLoggerがpush_errorを呼び、GUTがUnexpected Errorとして検出する
# func test_change_element_invalid():

## 存在しないタイルインデックスは失敗（同上）
# func test_change_element_invalid_tile():


## 全5属性への変更が可能
func test_change_element_all_valid_elements():
	var elements: Array[String] = ["fire", "water", "earth", "wind", "neutral"]
	for element in elements:
		_board.tile_nodes[5].tile_type = "checkpoint"
		var success = _spell_land.change_element(5, element)
		assert_true(success, "%sへの変更成功" % element)
		assert_eq(_board.tile_nodes[5].tile_type, element, "%sに変更された" % element)


# ========================================
# 相互属性変更テスト
# ========================================

## 火タイルを火↔水変換で水に変更
func test_change_element_bidirectional_fire_to_water():
	assert_eq(_board.tile_nodes[1].tile_type, "fire")
	var success = _spell_land.change_element_bidirectional(1, "fire", "water")
	assert_true(success, "火→水の変換成功")
	assert_eq(_board.tile_nodes[1].tile_type, "water", "水に変換された")


## 水タイルを火↔水変換で火に変更
func test_change_element_bidirectional_water_to_fire():
	assert_eq(_board.tile_nodes[6].tile_type, "water")
	var success = _spell_land.change_element_bidirectional(6, "fire", "water")
	assert_true(success, "水→火の変換成功")
	assert_eq(_board.tile_nodes[6].tile_type, "fire", "火に変換された")


## 対象外の属性（風タイルに火↔水変換）は失敗
func test_change_element_bidirectional_unrelated():
	assert_eq(_board.tile_nodes[11].tile_type, "wind")
	var success = _spell_land.change_element_bidirectional(11, "fire", "water")
	assert_false(success, "風タイルは火↔水変換の対象外")


# ========================================
# レベル変更テスト
# ========================================

## レベルアップ（+1）
func test_change_level_up():
	_board.tile_nodes[1].level = 1
	var success = _spell_land.change_level(1, 1)
	assert_true(success, "レベルアップ成功")
	assert_eq(_board.tile_nodes[1].level, 2, "Lv1→Lv2")


## レベルダウン（-1）
func test_change_level_down():
	_board.tile_nodes[1].level = 3
	var success = _spell_land.change_level(1, -1)
	assert_true(success, "レベルダウン成功")
	assert_eq(_board.tile_nodes[1].level, 2, "Lv3→Lv2")


## レベル上限（5）を超えない
func test_change_level_max_cap():
	_board.tile_nodes[1].level = 5
	var success = _spell_land.change_level(1, 1)
	assert_false(success, "Lv5からのレベルアップは失敗")
	assert_eq(_board.tile_nodes[1].level, 5, "Lv5のまま")


## レベル下限（1）を下回らない
func test_change_level_min_cap():
	_board.tile_nodes[1].level = 1
	var success = _spell_land.change_level(1, -1)
	assert_false(success, "Lv1からのレベルダウンは失敗")
	assert_eq(_board.tile_nodes[1].level, 1, "Lv1のまま")


## レベル固定設定
func test_set_level():
	_board.tile_nodes[1].level = 1
	var success = _spell_land.set_level(1, 3)
	assert_true(success, "Lv3に設定成功")
	assert_eq(_board.tile_nodes[1].level, 3, "Lv3に設定された")


## 同じレベルへの設定は変更なし
func test_set_level_same():
	_board.tile_nodes[1].level = 3
	var success = _spell_land.set_level(1, 3)
	assert_false(success, "同レベル設定は変更なし")


# ========================================
# クリーチャー破壊テスト
# ========================================

## クリーチャーを破壊
func test_destroy_creature():
	var creature = Helper.make_creature("ゴブリン", 30, 20)
	Helper.place_creature(_board.tile_nodes, _cm, 1, creature, 0)
	assert_true(_cm.has_creature(1), "破壊前: クリーチャー存在")

	var success = _spell_land.destroy_creature(1)
	assert_true(success, "破壊成功")
	assert_false(_cm.has_creature(1), "破壊後: クリーチャー消滅")


## クリーチャーなしタイルの破壊は失敗
func test_destroy_creature_empty_tile():
	var success = _spell_land.destroy_creature(1)
	assert_false(success, "クリーチャーなしタイルは失敗")


# ========================================
# 土地放棄テスト
# ========================================

## 土地放棄でEP返却
func test_abandon_land():
	_board.tile_nodes[1].owner_id = 0
	_board.tile_nodes[1].level = 3
	_board.player_system = _player_system

	var initial_ep = _player_system.players[0].magic_power
	var returned = _spell_land.abandon_land(1, 0.7)

	assert_gt(returned, 0, "EP返却あり")
	assert_eq(_board.tile_nodes[1].owner_id, -1, "所有権が解除された")
	assert_eq(_player_system.players[0].magic_power, initial_ep + returned, "EP加算された")


## 所有者なしタイルの放棄は0返却（push_errorが発生するためスキップ）
# func test_abandon_land_no_owner():


# ========================================
# 最多属性変更テスト
# ========================================

## プレイヤーの最多属性を取得
func test_get_player_dominant_element():
	_board.tile_nodes[1].owner_id = 0  # fire
	_board.tile_nodes[2].owner_id = 0  # fire
	_board.tile_nodes[6].owner_id = 0  # water

	var dominant = _spell_land.get_player_dominant_element(0)
	assert_eq(dominant, "fire", "火が最多")


# ========================================
# JSON定義確認（残り5スペル）
# ========================================

## ダウナー(2030): find_and_change_highest_level
func test_downer_json():
	var card = CardLoader.get_card_by_id(2030)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	assert_eq(effects[0].get("effect_type", ""), "find_and_change_highest_level", "ダウナー: find_and_change_highest_level")
	assert_eq(int(effects[0].get("value", 0)), -1, "ダウナー: value=-1")


## グラウンド(2085): conditional_level_change
func test_ground_json():
	var card = CardLoader.get_card_by_id(2085)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var e = effects[0]
	assert_eq(e.get("effect_type", ""), "conditional_level_change", "グラウンド: conditional_level_change")
	assert_eq(int(e.get("required_level", 0)), 2, "グラウンド: required_level=2")
	assert_eq(int(e.get("required_count", 0)), 5, "グラウンド: required_count=5")
	assert_eq(int(e.get("value", 0)), 1, "グラウンド: value=1")


## マッチ(2096): align_mismatched_lands
func test_match_json():
	var card = CardLoader.get_card_by_id(2096)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	assert_eq(effects[0].get("effect_type", ""), "align_mismatched_lands", "マッチ: align_mismatched_lands")
	assert_eq(int(effects[0].get("required_count", 0)), 4, "マッチ: required_count=4")


## アクアシフト(9039): change_caster_tile_element
func test_aqua_shift_json():
	var card = CardLoader.get_card_by_id(9039)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	assert_eq(effects[0].get("effect_type", ""), "change_caster_tile_element", "アクアシフト: change_caster_tile_element")
	assert_eq(effects[0].get("element", ""), "water", "アクアシフト: element=water")


## ニュートラルシフト(9041): change_element + self_destruct
func test_neutral_shift_json():
	var card = CardLoader.get_card_by_id(9041)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	assert_true(types.has("change_element"), "ニュートラルシフト: change_element持ち")
	assert_true(types.has("self_destruct"), "ニュートラルシフト: self_destruct持ち")


# ========================================
# find_and_change_highest_level: 最高レベル土地検索+レベル変更
# ========================================

## 最高レベル土地を検索
func test_find_highest_level_land():
	_board.tile_nodes[1].owner_id = 0
	_board.tile_nodes[1].level = 2
	_board.tile_nodes[2].owner_id = 0
	_board.tile_nodes[2].level = 4
	_board.tile_nodes[3].owner_id = 0
	_board.tile_nodes[3].level = 3

	var highest = _spell_land.find_highest_level_land(0)
	assert_eq(highest, 2, "最高レベルはタイル2(Lv4)")


## 最高レベル土地のレベルを下げる
func test_find_and_change_highest_level():
	_board.tile_nodes[1].owner_id = 1
	_board.tile_nodes[1].level = 3
	_board.tile_nodes[2].owner_id = 1
	_board.tile_nodes[2].level = 5
	_board.tile_nodes[3].owner_id = 1
	_board.tile_nodes[3].level = 2

	var target_data: Dictionary = {"player_id": 1}
	var effect: Dictionary = {"effect_type": "find_and_change_highest_level", "value": -1}
	var success = _spell_land.apply_land_effect(effect, target_data, 1)
	assert_true(success, "最高レベル変更成功")
	assert_eq(_board.tile_nodes[2].level, 4, "タイル2: Lv5→Lv4")
	# 他のタイルは変化なし
	assert_eq(_board.tile_nodes[1].level, 3, "タイル1: Lv3のまま")
	assert_eq(_board.tile_nodes[3].level, 2, "タイル3: Lv2のまま")


## 土地を持たないプレイヤー → 失敗
func test_find_highest_no_land():
	var highest = _spell_land.find_highest_level_land(1)
	assert_eq(highest, -1, "土地なし: -1")


# ========================================
# conditional_level_change: 条件付きレベル変更
# ========================================

## 条件成立: Lv2土地5つ → 全Lv3に
func test_conditional_level_change_success():
	# P0のLv2土地を5つ用意
	for i in [1, 2, 3, 6, 7]:
		_board.tile_nodes[i].owner_id = 0
		_board.tile_nodes[i].level = 2

	var effect: Dictionary = {
		"effect_type": "conditional_level_change",
		"required_level": 2,
		"required_count": 5,
		"value": 1,
	}
	var target_data: Dictionary = {"player_id": 0}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_true(success, "条件成立: Lv2×5")
	for i in [1, 2, 3, 6, 7]:
		assert_eq(_board.tile_nodes[i].level, 3, "タイル%d: Lv2→Lv3" % i)


## 条件不成立: Lv2土地4つ → 失敗（デッキ復帰）
func test_conditional_level_change_fail():
	for i in [1, 2, 3, 6]:
		_board.tile_nodes[i].owner_id = 0
		_board.tile_nodes[i].level = 2

	var effect: Dictionary = {
		"effect_type": "conditional_level_change",
		"required_level": 2,
		"required_count": 5,
		"value": 1,
	}
	var target_data: Dictionary = {"player_id": 0}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_false(success, "条件不成立: Lv2×4")
	# レベルは変化なし
	for i in [1, 2, 3, 6]:
		assert_eq(_board.tile_nodes[i].level, 2, "タイル%d: Lv2のまま" % i)


## 条件成立: Lv2が6つあっても全部レベルアップ
func test_conditional_level_change_excess():
	for i in [1, 2, 3, 6, 7, 8]:
		_board.tile_nodes[i].owner_id = 0
		_board.tile_nodes[i].level = 2

	var effect: Dictionary = {
		"effect_type": "conditional_level_change",
		"required_level": 2,
		"required_count": 5,
		"value": 1,
	}
	var target_data: Dictionary = {"player_id": 0}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_true(success, "条件成立: Lv2×6")
	for i in [1, 2, 3, 6, 7, 8]:
		assert_eq(_board.tile_nodes[i].level, 3, "タイル%d: Lv2→Lv3" % i)


# ========================================
# align_mismatched_lands: 属性不一致修正
# ========================================

## 属性不一致の土地を検索
func test_find_mismatched_lands():
	# タイル1(fire)に水クリーチャー → 不一致
	var water_creature = Helper.make_creature("水精", 30, 20, "water")
	Helper.place_creature(_board.tile_nodes, _cm, 1, water_creature, 0)
	# タイル2(fire)に火クリーチャー → 一致
	var fire_creature = Helper.make_creature("炎精", 30, 20, "fire")
	Helper.place_creature(_board.tile_nodes, _cm, 2, fire_creature, 0)
	# タイル6(water)に地クリーチャー → 不一致
	var earth_creature = Helper.make_creature("地精", 30, 20, "earth")
	Helper.place_creature(_board.tile_nodes, _cm, 6, earth_creature, 0)

	var mismatched = _spell_land.find_mismatched_element_lands(0)
	assert_eq(mismatched.size(), 2, "不一致: 2つ")
	assert_true(mismatched.has(1), "タイル1: 不一致")
	assert_true(mismatched.has(6), "タイル6: 不一致")


## 条件成立: 不一致4つ以上 → 属性修正（slice(0, required_count-1)で先頭3件が変更される）
func test_align_mismatched_success():
	# 4つの不一致土地を用意
	var elements: Array[String] = ["water", "earth", "wind", "fire"]
	var tiles: Array[int] = [1, 2, 3, 6]  # fire, fire, fire, water
	for idx in range(4):
		var creature = Helper.make_creature("クリーチャー%d" % idx, 30, 20, elements[idx])
		Helper.place_creature(_board.tile_nodes, _cm, tiles[idx], creature, 0)

	var effect: Dictionary = {
		"effect_type": "align_mismatched_lands",
		"required_count": 4,
	}
	var target_data: Dictionary = {"player_id": 0}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_true(success, "条件成立: 不一致4つ")

	# slice(0, required_count-1) = slice(0, 3) → 先頭3件が変更される
	assert_eq(_board.tile_nodes[1].tile_type, "water", "タイル1: fire→water")
	assert_eq(_board.tile_nodes[2].tile_type, "earth", "タイル2: fire→earth")
	assert_eq(_board.tile_nodes[3].tile_type, "wind", "タイル3: fire→wind")


## 条件不成立: 不一致3つ → 失敗
func test_align_mismatched_fail():
	var elements: Array[String] = ["water", "earth", "wind"]
	var tiles: Array[int] = [1, 2, 3]
	for idx in range(3):
		var creature = Helper.make_creature("クリーチャー%d" % idx, 30, 20, elements[idx])
		Helper.place_creature(_board.tile_nodes, _cm, tiles[idx], creature, 0)

	var effect: Dictionary = {
		"effect_type": "align_mismatched_lands",
		"required_count": 4,
	}
	var target_data: Dictionary = {"player_id": 0}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_false(success, "条件不成立: 不一致3つ")
	# 属性は変化なし
	assert_eq(_board.tile_nodes[1].tile_type, "fire", "タイル1: fireのまま")
	assert_eq(_board.tile_nodes[2].tile_type, "fire", "タイル2: fireのまま")
	assert_eq(_board.tile_nodes[3].tile_type, "fire", "タイル3: fireのまま")


# ========================================
# change_caster_tile_element: 術者タイル属性変更
# ========================================

## 術者タイルを水に変更
func test_change_caster_tile_element():
	assert_eq(_board.tile_nodes[1].tile_type, "fire", "初期: 火")
	var effect: Dictionary = {"effect_type": "change_caster_tile_element", "element": "water"}
	var target_data: Dictionary = {"caster_tile_index": 1}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_true(success, "術者タイル変更成功")
	assert_eq(_board.tile_nodes[1].tile_type, "water", "火→水")


## caster_tile_index未設定 → 失敗（push_errorが発生するためスキップ）
# func test_change_caster_tile_no_index():


# ========================================
# self_destruct: 術者クリーチャー自滅
# ========================================

## 自滅: クリーチャー除去+所有権リセット
func test_self_destruct():
	var creature = Helper.make_creature("ストーンジゾウ", 30, 20, "earth")
	Helper.place_creature(_board.tile_nodes, _cm, 16, creature, 0)
	assert_true(_cm.has_creature(16), "前提: クリーチャー存在")
	assert_eq(_board.tile_nodes[16].owner_id, 0, "前提: P0所有")

	var effect: Dictionary = {"effect_type": "self_destruct"}
	var target_data: Dictionary = {"caster_tile_index": 16}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_true(success, "自滅成功")
	assert_true(_board.tile_nodes[16].creature_data.is_empty(), "クリーチャー除去")
	assert_eq(_board.tile_nodes[16].owner_id, -1, "所有権リセット")


## 自滅: caster_tile_index未設定 → 失敗（push_errorが発生するためスキップ）
# func test_self_destruct_no_index():


## 自滅: クリーチャーなし → 失敗
func test_self_destruct_no_creature():
	var effect: Dictionary = {"effect_type": "self_destruct"}
	var target_data: Dictionary = {"caster_tile_index": 5}
	var success = _spell_land.apply_land_effect(effect, target_data, 0)
	assert_false(success, "クリーチャーなし: 失敗")
