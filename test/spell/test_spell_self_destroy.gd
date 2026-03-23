extends GutTest

## 自滅効果系テスト
## SpellMagic.apply_self_destroy + JSON定義確認
## MockBoard使用（remove_creature/set_tile_ownerオーバーライド済み）

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _board: BoardSystem3D
var _spell_magic: SpellMagic
var _player_system: PlayerSystem


func before_each():
	_board = MockBoard.new()
	_board.name = "MockBoard_SelfDestroy"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_SelfDestroy"
	add_child(_player_system)
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 500
	_player_system.players = [p0]

	_spell_magic = SpellMagic.new()
	_spell_magic.setup(_player_system, _board)


func after_each():
	if is_instance_valid(_board):
		_board.free()
	if is_instance_valid(_player_system):
		_player_system.free()


## クリーチャー配置
func _place_creature(tile_index: int, hp: int = 40, ap: int = 30) -> void:
	var creature = Helper.make_creature("テストクリーチャー", hp, ap)
	var tile = _board.tile_nodes[tile_index]
	tile.creature_data = creature.duplicate(true)
	tile.owner_id = 0


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

## 黄金献身(9015): gain_magic + self_destroy
func test_golden_dedication_json():
	var types = _get_effect_types(9015)
	assert_true(types.has("self_destroy"), "黄金献身: self_destroy持ち")
	assert_true(types.has("gain_magic"), "黄金献身: gain_magic持ち")


## ケルベロス召喚(9054): place_creature + self_destroy
func test_cerberus_summon_json():
	var types = _get_effect_types(9054)
	assert_true(types.has("self_destroy"), "ケルベロス召喚: self_destroy持ち")
	assert_true(types.has("place_creature"), "ケルベロス召喚: place_creature持ち")


## 黄金献身(9015): clear_land=true確認
func test_golden_dedication_clear_land():
	var card = CardLoader.get_card_by_id(9015)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "self_destroy":
			assert_true(e.get("clear_land", false), "黄金献身: clear_land=true")


## ケルベロス召喚(9054): creature_id確認
func test_cerberus_creature_id():
	var card = CardLoader.get_card_by_id(9054)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "place_creature":
			assert_eq(int(e.get("creature_id", 0)), 27, "ケルベロス: creature_id=27")
			assert_eq(e.get("placement_mode", ""), "select", "ケルベロス: placement_mode=select")
			assert_true(e.get("set_down", false), "ケルベロス: set_down=true")


# ========================================
# apply_self_destroy: 基本テスト
# ========================================

## クリーチャーがいるタイルで自滅 → クリーチャー除去+所有権解除
func test_self_destroy_basic():
	_place_creature(3)
	assert_false(_board.tile_nodes[3].creature_data.is_empty(), "前提: クリーチャーあり")
	assert_eq(_board.tile_nodes[3].owner_id, 0, "前提: 所有者P0")

	var result = _spell_magic.apply_self_destroy(3, true)
	assert_true(result, "自滅成功")
	assert_true(_board.tile_nodes[3].creature_data.is_empty(), "クリーチャー除去済み")
	assert_eq(_board.tile_nodes[3].owner_id, -1, "所有権解除")


## clear_land=false → クリーチャー除去のみ、所有権維持
func test_self_destroy_keep_land():
	_place_creature(5)
	var result = _spell_magic.apply_self_destroy(5, false)
	assert_true(result, "自滅成功")
	assert_true(_board.tile_nodes[5].creature_data.is_empty(), "クリーチャー除去済み")
	assert_eq(_board.tile_nodes[5].owner_id, 0, "所有権維持")


## クリーチャーなしのタイル → 成功するがクリーチャーデータは元々空
func test_self_destroy_empty_tile():
	assert_true(_board.tile_nodes[3].creature_data.is_empty(), "前提: クリーチャーなし")
	var result = _spell_magic.apply_self_destroy(3, true)
	# remove_creatureは空でも動作する
	assert_true(result, "空タイルでも成功")


## 無効なタイルインデックス → false
func test_self_destroy_invalid_tile():
	var result = _spell_magic.apply_self_destroy(-1, true)
	assert_false(result, "無効インデックス: false")


## 存在しないタイルインデックス → false
func test_self_destroy_nonexistent_tile():
	var result = _spell_magic.apply_self_destroy(99, true)
	assert_false(result, "存在しないタイル: false")
