extends GutTest

## クリーチャー配置系テスト
## SpellCreaturePlace + JSON定義確認
## MockBoard使用（place_creature/set_tile_ownerオーバーライド済み）

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _board: BoardSystem3D
var _spell_place: SpellCreaturePlace
var _player_system: PlayerSystem


func before_each():
	_board = MockBoard.new()
	_board.name = "MockBoard_CreaturePlace"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_CreaturePlace"
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

	_spell_place = SpellCreaturePlace.new()
	_spell_place.name = "SpellCreaturePlace_Test"
	add_child(_spell_place)


func after_each():
	if _board and is_instance_valid(_board):
		_board.free()
	if _player_system and is_instance_valid(_player_system):
		_player_system.free()
	if _spell_place and is_instance_valid(_spell_place):
		_spell_place.free()


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

## サモン(2028): place_creature
func test_summon_json():
	var types = _get_effect_types(2028)
	assert_true(types.has("place_creature"), "サモン: place_creature持ち")
	var card = CardLoader.get_card_by_id(2028)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "place_creature":
			assert_eq(e.get("placement_mode", ""), "conditional", "サモン: conditional")


## ネクロ(2043): place_creature
func test_necro_json():
	var types = _get_effect_types(2043)
	assert_true(types.has("place_creature"), "ネクロ: place_creature持ち")
	var card = CardLoader.get_card_by_id(2043)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "place_creature":
			assert_eq(e.get("placement_mode", ""), "random", "ネクロ: random")


## ケルベロス召喚(9054): place_creature + self_destroy
func test_cerberus_json():
	var types = _get_effect_types(9054)
	assert_true(types.has("place_creature"), "ケルベロス召喚: place_creature持ち")
	assert_true(types.has("self_destroy"), "ケルベロス召喚: self_destroy持ち")


## ダートリング召喚(9055): place_creature
func test_dartling_json():
	var types = _get_effect_types(9055)
	assert_true(types.has("place_creature"), "ダートリング召喚: place_creature持ち")
	var card = CardLoader.get_card_by_id(9055)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "place_creature":
			assert_eq(e.get("placement_mode", ""), "select", "ダートリング: select")
			assert_true(e.get("set_down", false), "ダートリング: set_down=true")


## ストーンゴーレム召喚(9056): place_creature
func test_stone_golem_json():
	var types = _get_effect_types(9056)
	assert_true(types.has("place_creature"), "ストーンゴーレム: place_creature持ち")
	var card = CardLoader.get_card_by_id(9056)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "place_creature":
			assert_eq(e.get("placement_mode", ""), "adjacent", "ストーンゴーレム: adjacent")


# ========================================
# validate_placement: 配置検証
# ========================================

## 空タイルへの配置は有効
func test_validate_placement_empty():
	var result = _spell_place.validate_placement(_board, 3, 1)
	assert_true(result, "空タイル: 配置可能")


## クリーチャーがいるタイルへの配置は無効
func test_validate_placement_occupied():
	_place_creature(3)
	var result = _spell_place.validate_placement(_board, 3, 1)
	assert_false(result, "占有タイル: 配置不可")


## 存在しないタイルは無効
func test_validate_placement_nonexistent():
	var result = _spell_place.validate_placement(_board, 99, 1)
	assert_false(result, "存在しないタイル: 配置不可")


# ========================================
# get_empty_tiles: 空きタイル取得
# ========================================

## 全タイル空き → 配置可能タイルのみ（checkpoint除外）
func test_get_empty_tiles_all_empty():
	var empty = _spell_place.get_empty_tiles(_board)
	# checkpointは配置不可なので除外される
	assert_gt(empty.size(), 0, "空きタイルあり")
	for tile_index in empty:
		var tile = _board.tile_nodes[tile_index]
		assert_ne(tile.tile_type, "checkpoint", "checkpointは除外")


## 一部占有 → 占有タイルは除外
func test_get_empty_tiles_some_occupied():
	var all_empty = _spell_place.get_empty_tiles(_board)
	_place_creature(3)
	_place_creature(7)
	var after_place = _spell_place.get_empty_tiles(_board)
	assert_eq(after_place.size(), all_empty.size() - 2, "2タイル分減少")
	assert_false(after_place.has(3), "タイル3は除外")
	assert_false(after_place.has(7), "タイル7は除外")


# ========================================
# place_creature_at_target: ターゲット配置
# ========================================

## 指定タイルにクリーチャーを配置
func test_place_at_target():
	var target_data = {"tile_index": 3}
	var success = _spell_place.place_creature_at_target(_board, 0, 1, target_data, false)
	assert_true(success, "配置成功")
	assert_false(_board.tile_nodes[3].creature_data.is_empty(), "クリーチャーあり")


## ダウン状態で配置
func test_place_at_target_with_down():
	var target_data = {"tile_index": 3}
	var success = _spell_place.place_creature_at_target(_board, 0, 1, target_data, true)
	assert_true(success, "配置成功")
	assert_false(_board.tile_nodes[3].creature_data.is_empty(), "クリーチャーあり")
	# set_downはset_down_stateメソッドまたはcreature_data.is_downで確認
	var creature = _board.tile_nodes[3].creature_data
	assert_true(creature.get("is_down", false), "ダウン状態")


## 無効なtile_index → 失敗
func test_place_at_target_invalid():
	var target_data = {"tile_index": -1}
	var success = _spell_place.place_creature_at_target(_board, 0, 1, target_data, false)
	assert_false(success, "無効tile_index: 失敗")


# ========================================
# apply_place_effect: 統合配置テスト
# ========================================

## selectモード配置
func test_apply_place_effect_select():
	var effect = {
		"effect_type": "place_creature",
		"creature_id": 208,
		"placement_mode": "select",
		"set_down": true
	}
	var target_data = {"tile_index": 3}
	var result = _spell_place.apply_place_effect(effect, target_data, 0, _board)
	assert_true(result.get("success", false), "select配置成功")
	assert_true(result.get("placed_tiles", []).has(3), "タイル3に配置")


## randomモード配置
func test_apply_place_effect_random():
	var effect = {
		"effect_type": "place_creature",
		"creature_id": 420,
		"placement_mode": "random"
	}
	var result = _spell_place.apply_place_effect(effect, {}, 0, _board)
	assert_true(result.get("success", false), "random配置成功")


## 無効なcreature_id → 失敗
func test_apply_place_effect_invalid_creature():
	var effect = {
		"effect_type": "place_creature",
		"creature_id": -1,
		"placement_mode": "select"
	}
	var result = _spell_place.apply_place_effect(effect, {"tile_index": 3}, 0, _board)
	assert_false(result.get("success", true), "無効creature_id: 失敗")
