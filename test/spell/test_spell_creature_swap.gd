extends GutTest

## クリーチャー交換系テスト
## SpellCreatureSwap の swap_with_hand / swap_board_creatures + JSON定義確認
## MockBoard + CardSystem使用

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _board: BoardSystem3D
var _card_system: CardSystem
var _player_system: PlayerSystem
var _spell_swap: SpellCreatureSwap


func before_each():
	_board = MockBoard.new()
	_board.name = "MockBoard_Swap"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()

	_card_system = CardSystem.new()
	_card_system.name = "CardSystem_Swap"
	add_child(_card_system)
	for pid in range(2):
		_card_system.player_decks[pid] = []
		_card_system.player_discards[pid] = []
		_card_system.player_hands[pid] = {"data": []}

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_Swap"
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

	_spell_swap = SpellCreatureSwap.new(_board, _player_system, _card_system)


func after_each():
	if _board and is_instance_valid(_board):
		_board.free()
	if _card_system and is_instance_valid(_card_system):
		_card_system.free()
	if _player_system and is_instance_valid(_player_system):
		_player_system.free()


## クリーチャー配置
func _place_creature(tile_index: int, creature_id: int, owner_id: int = 0,
		creature_name: String = "テストクリーチャー", hp: int = 40, ap: int = 30) -> void:
	var creature = Helper.make_creature(creature_name, hp, ap)
	creature["id"] = creature_id
	var tile = _board.tile_nodes[tile_index]
	tile.creature_data = creature.duplicate(true)
	tile.owner_id = owner_id


## 手札にクリーチャーカードを追加
func _add_creature_to_hand(player_id: int, card_id: int) -> void:
	var card_data = CardLoader.get_card_by_id(card_id).duplicate(true)
	if not card_data.is_empty():
		_card_system.player_hands[player_id]["data"].append(card_data)


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

## トレード(2013): swap_with_hand
func test_trade_json():
	var types = _get_effect_types(2013)
	assert_true(types.has("swap_with_hand"), "トレード: swap_with_hand持ち")
	var card = CardLoader.get_card_by_id(2013)
	var target_info = card.get("effect_parsed", {}).get("target_info", {})
	assert_eq(target_info.get("owner_filter", ""), "own", "トレード: 自クリーチャー対象")


## ローテート(2126): swap_board_creatures
func test_rotate_json():
	var types = _get_effect_types(2126)
	assert_true(types.has("swap_board_creatures"), "ローテート: swap_board_creatures持ち")
	var card = CardLoader.get_card_by_id(2126)
	assert_true(card.get("return_to_deck", false), "ローテート: 復帰[ブック]")


# ========================================
# can_cast_exchange: 発動可能判定
# ========================================

## 盤面クリーチャー+手札クリーチャーあり → 発動可
func test_can_cast_exchange_true():
	_place_creature(3, 1, 0)
	_add_creature_to_hand(0, 100)  # waterクリーチャー
	assert_true(_spell_swap.can_cast_exchange(0), "発動可能")


## 盤面クリーチャーなし → 不可
func test_can_cast_exchange_no_board():
	_add_creature_to_hand(0, 100)
	assert_false(_spell_swap.can_cast_exchange(0), "盤面なし: 不可")


## 手札クリーチャーなし → 不可
func test_can_cast_exchange_no_hand():
	_place_creature(3, 1, 0)
	# スペルのみ手札に追加
	var spell_data = CardLoader.get_card_by_id(2016).duplicate(true)
	_card_system.player_hands[0]["data"].append(spell_data)
	assert_false(_spell_swap.can_cast_exchange(0), "手札クリーチャーなし: 不可")


# ========================================
# can_cast_relief: 発動可能判定
# ========================================

## 自クリーチャー2体以上 → 発動可
func test_can_cast_relief_true():
	_place_creature(3, 1, 0)
	_place_creature(7, 100, 0)
	assert_true(_spell_swap.can_cast_relief(0), "2体以上: 発動可")


## 自クリーチャー1体 → 不可
func test_can_cast_relief_one():
	_place_creature(3, 1, 0)
	assert_false(_spell_swap.can_cast_relief(0), "1体: 不可")


## 自クリーチャーなし → 不可
func test_can_cast_relief_none():
	assert_false(_spell_swap.can_cast_relief(0), "0体: 不可")


# ========================================
# _execute_swap_with_hand: 手札交換実行
# ========================================

## 盤面クリーチャーと手札クリーチャーが交換される
func test_execute_swap_with_hand():
	_place_creature(3, 1, 0, "盤面クリーチャー", 40, 30)
	_add_creature_to_hand(0, 100)  # 手札クリーチャー
	var hand_creature = _card_system.player_hands[0]["data"][0].duplicate(true)
	var hand_creature_id = hand_creature.get("id", 0)

	assert_eq(_card_system.player_hands[0]["data"].size(), 1, "前提: 手札1枚")

	_spell_swap._execute_swap_with_hand(3, 0, hand_creature)

	# 盤面のクリーチャーが手札のものに変わっている
	var new_board_creature = _board.tile_nodes[3].creature_data
	assert_eq(new_board_creature.get("id", 0), hand_creature_id, "盤面に手札クリーチャー配置")
	# 元の盤面クリーチャーが手札に戻っている
	assert_eq(_card_system.player_hands[0]["data"].size(), 1, "手札枚数維持")
	# ダウン状態
	assert_true(_board.tile_nodes[3].is_down(), "交換後ダウン状態")


## 交換後のHPは新クリーチャーの基礎HPになる
func test_swap_hand_hp_reset():
	_place_creature(3, 1, 0, "盤面", 40, 30)
	_add_creature_to_hand(0, 100)
	var hand_creature = _card_system.player_hands[0]["data"][0].duplicate(true)
	var base_hp = hand_creature.get("hp", 0)

	_spell_swap._execute_swap_with_hand(3, 0, hand_creature)

	var new_creature = _board.tile_nodes[3].creature_data
	assert_eq(new_creature.get("current_hp", 0), base_hp, "HP=基礎HP")


# ========================================
# _execute_swap_board: 盤面交換実行
# ========================================

## 2体のクリーチャーが入れ替わる
func test_execute_swap_board():
	_place_creature(3, 1, 0, "クリーチャーA", 40, 30)
	_place_creature(7, 100, 0, "クリーチャーB", 50, 20)

	_spell_swap._execute_swap_board(3, 7)

	# クリーチャーが入れ替わっている
	assert_eq(_board.tile_nodes[3].creature_data.get("id", 0), 100, "タイル3: ID=100")
	assert_eq(_board.tile_nodes[7].creature_data.get("id", 0), 1, "タイル7: ID=1")


## 所有者も入れ替わる
func test_swap_board_owner_exchange():
	_place_creature(3, 1, 0, "P0のクリーチャー", 40, 30)
	_place_creature(7, 100, 1, "P1のクリーチャー", 50, 20)

	_spell_swap._execute_swap_board(3, 7)

	assert_eq(_board.tile_nodes[3].owner_id, 1, "タイル3: P1所有に")
	assert_eq(_board.tile_nodes[7].owner_id, 0, "タイル7: P0所有に")


## 交換後ダウン状態
func test_swap_board_down_state():
	_place_creature(3, 1, 0)
	_place_creature(7, 100, 0)

	_spell_swap._execute_swap_board(3, 7)

	assert_true(_board.tile_nodes[3].is_down(), "タイル3: ダウン状態")
	assert_true(_board.tile_nodes[7].is_down(), "タイル7: ダウン状態")


## HPは維持される（盤面交換ではHPリセットしない）
func test_swap_board_preserves_hp():
	_place_creature(3, 1, 0, "A", 40, 30)
	_board.tile_nodes[3].creature_data["current_hp"] = 15  # ダメージ受けた状態
	_place_creature(7, 100, 0, "B", 50, 20)

	_spell_swap._execute_swap_board(3, 7)

	# タイル7に移動したクリーチャーAのHPが維持されている
	assert_eq(_board.tile_nodes[7].creature_data.get("current_hp", 0), 15, "HP維持: 15")
