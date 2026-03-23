extends GutTest

## クリーチャー手札戻し系テスト
## SpellCreatureReturn + JSON定義確認
## MockBoard + CardSystem使用

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _board: BoardSystem3D
var _card_system: CardSystem
var _player_system: PlayerSystem
var _spell_return: SpellCreatureReturn


func before_each():
	_board = MockBoard.new()
	_board.name = "MockBoard_CreatureReturn"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()

	_card_system = CardSystem.new()
	_card_system.name = "CardSystem_CreatureReturn"
	add_child(_card_system)
	for pid in range(2):
		_card_system.player_decks[pid] = []
		_card_system.player_discards[pid] = []
		_card_system.player_hands[pid] = {"data": []}

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_CreatureReturn"
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

	_spell_return = SpellCreatureReturn.new(_board, _player_system, _card_system)


func after_each():
	if _board and is_instance_valid(_board):
		_board.free()
	if _card_system and is_instance_valid(_card_system):
		_card_system.free()
	if _player_system and is_instance_valid(_player_system):
		_player_system.free()


## クリーチャー配置
func _place_creature(tile_index: int, owner_id: int = 0, creature_name: String = "テストクリーチャー",
		hp: int = 40, ap: int = 30, element: String = "fire") -> void:
	var creature = Helper.make_creature(creature_name, hp, ap, element)
	creature["id"] = 1  # デフォルトID
	var tile = _board.tile_nodes[tile_index]
	tile.creature_data = creature.duplicate(true)
	tile.owner_id = owner_id


## JSON定義からeffect_typesを取得
func _get_effect_types(spell_id: int) -> Array[String]:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	return types


# ========================================
# JSON定義確認
# ========================================

## パージ(2012): return_to_hand
func test_purge_json():
	var types = _get_effect_types(2012)
	assert_true(types.has("return_to_hand"), "パージ: return_to_hand持ち")
	var card = CardLoader.get_card_by_id(2012)
	var target_info = card.get("effect_parsed", {}).get("target_info", {})
	assert_true(target_info.get("has_curse", false), "パージ: has_curse条件")


## エクストラクト(2076): return_to_hand + lowest_mhp
func test_extract_json():
	var types = _get_effect_types(2076)
	assert_true(types.has("return_to_hand"), "エクストラクト: return_to_hand持ち")
	var card = CardLoader.get_card_by_id(2076)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "return_to_hand":
			assert_eq(e.get("select_by", ""), "lowest_mhp", "エクストラクト: select_by=lowest_mhp")


## ネゲート(2097): return_to_hand
func test_negate_json():
	var types = _get_effect_types(2097)
	assert_true(types.has("return_to_hand"), "ネゲート: return_to_hand持ち")
	var card = CardLoader.get_card_by_id(2097)
	var target_info = card.get("effect_parsed", {}).get("target_info", {})
	assert_true(target_info.get("element_mismatch", false), "ネゲート: element_mismatch条件")


# ========================================
# apply_effect: 直接指定で手札に戻す
# ========================================

## クリーチャーを手札に戻す（基本）
func test_return_to_hand_basic():
	_place_creature(3, 0)
	assert_false(_board.tile_nodes[3].creature_data.is_empty(), "前提: クリーチャーあり")
	assert_eq(_card_system.player_hands[0]["data"].size(), 0, "前提: P0手札0枚")

	var effect = {"effect_type": "return_to_hand"}
	var target_data = {"tile_index": 3}
	var result = _spell_return.apply_effect(effect, target_data, 1)

	assert_true(result.get("success", false), "手札戻し成功")
	assert_true(_board.tile_nodes[3].creature_data.is_empty(), "タイルからクリーチャー除去")
	assert_eq(_board.tile_nodes[3].owner_id, -1, "所有権解除")
	assert_eq(_card_system.player_hands[0]["data"].size(), 1, "P0手札1枚に増加")


## 無効なtile_index → 失敗
func test_return_to_hand_invalid_tile():
	var effect = {"effect_type": "return_to_hand"}
	var target_data = {"tile_index": -1}
	var result = _spell_return.apply_effect(effect, target_data, 0)
	assert_false(result.get("success", true), "無効タイル: 失敗")


## クリーチャーなしのタイル → 失敗
func test_return_to_hand_empty_tile():
	var effect = {"effect_type": "return_to_hand"}
	var target_data = {"tile_index": 3}
	var result = _spell_return.apply_effect(effect, target_data, 0)
	assert_false(result.get("success", true), "空タイル: 失敗")


## 相手のクリーチャーを戻す → 相手の手札に戻る
func test_return_to_hand_opponent():
	_place_creature(7, 1)  # P1のクリーチャー
	assert_eq(_card_system.player_hands[1]["data"].size(), 0, "前提: P1手札0枚")

	var effect = {"effect_type": "return_to_hand"}
	var target_data = {"tile_index": 7}
	var result = _spell_return.apply_effect(effect, target_data, 0)

	assert_true(result.get("success", false), "手札戻し成功")
	assert_eq(result.get("returned_to_player", -1), 1, "P1に返却")
	assert_eq(_card_system.player_hands[1]["data"].size(), 1, "P1手札1枚に増加")


## レベルは維持される
func test_return_to_hand_keeps_level():
	_place_creature(3, 0)
	_board.tile_nodes[3].level = 3

	var effect = {"effect_type": "return_to_hand"}
	var target_data = {"tile_index": 3}
	_spell_return.apply_effect(effect, target_data, 1)

	assert_eq(_board.tile_nodes[3].level, 3, "レベル維持")
	assert_true(_board.tile_nodes[3].creature_data.is_empty(), "クリーチャー除去")


# ========================================
# lowest_mhp: 最低MHP選択
# ========================================

## 最低MHPクリーチャーが選択される
func test_return_lowest_mhp():
	# P1に3体配置（HP異なる）
	_place_creature(1, 1, "弱いクリーチャー", 20, 30)
	_place_creature(2, 1, "普通クリーチャー", 40, 30)
	_place_creature(3, 1, "強いクリーチャー", 60, 30)

	var effect = {"effect_type": "return_to_hand", "select_by": "lowest_mhp"}
	var target_data = {"player_id": 1}
	var result = _spell_return.apply_effect(effect, target_data, 0)

	assert_true(result.get("success", false), "最低MHP戻し成功")
	assert_eq(result.get("creature_name", ""), "弱いクリーチャー", "HP20が選択")
	# タイル1のクリーチャーが消えている
	assert_true(_board.tile_nodes[1].creature_data.is_empty(), "タイル1から除去")
	# 他の2体は残っている
	assert_false(_board.tile_nodes[2].creature_data.is_empty(), "タイル2は残存")
	assert_false(_board.tile_nodes[3].creature_data.is_empty(), "タイル3は残存")


## クリーチャーなし → 失敗
func test_return_lowest_mhp_no_creature():
	var effect = {"effect_type": "return_to_hand", "select_by": "lowest_mhp"}
	var target_data = {"player_id": 1}
	var result = _spell_return.apply_effect(effect, target_data, 0)
	assert_false(result.get("success", true), "クリーチャーなし: 失敗")


# ========================================
# is_valid_exile_target: パージ条件判定
# ========================================

## 刻印付き+召喚条件なし → 有効
func test_exile_target_valid():
	_place_creature(3, 0)
	_board.tile_nodes[3].creature_data["curse"] = {"name": "テスト刻印", "value": 10}
	var result = _spell_return.is_valid_exile_target(3)
	assert_true(result, "刻印付き: 有効ターゲット")


## 刻印なし → 無効
func test_exile_target_no_curse():
	_place_creature(3, 0)
	var result = _spell_return.is_valid_exile_target(3)
	assert_false(result, "刻印なし: 無効ターゲット")


## 空タイル → 無効
func test_exile_target_empty():
	var result = _spell_return.is_valid_exile_target(3)
	assert_false(result, "空タイル: 無効ターゲット")


# ========================================
# is_valid_holy_banish_target: ネゲート条件判定
# ========================================

## 属性不一致 → 有効（fireクリーチャーをwaterタイルに）
func test_holy_banish_valid():
	_place_creature(6, 0, "火クリーチャー", 40, 30, "fire")  # タイル6はwaterタイプ
	var result = _spell_return.is_valid_holy_banish_target(6)
	assert_true(result, "属性不一致: 有効ターゲット")


## 属性一致 → 無効（fireクリーチャーをfireタイルに）
func test_holy_banish_same_element():
	_place_creature(1, 0, "火クリーチャー", 40, 30, "fire")  # タイル1はfireタイプ
	var result = _spell_return.is_valid_holy_banish_target(1)
	assert_false(result, "属性一致: 無効ターゲット")


## 空タイル → 無効
func test_holy_banish_empty():
	var result = _spell_return.is_valid_holy_banish_target(3)
	assert_false(result, "空タイル: 無効ターゲット")
