extends GutTest

## クリーチャー移動系テスト
## SpellCreatureMove の移動先計算 / 移動実行 / 破壊移動 + JSON定義確認
## MockBoard + TileNeighborSystem使用

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _board: BoardSystem3D
var _player_system: PlayerSystem
var _spell_move: SpellCreatureMove


func before_each():
	_board = MockBoard.new()
	_board.name = "MockBoard_Move"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()
	_board.setup_tile_neighbor_system()
	_board.current_player_index = 0

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_Move"
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

	_spell_move = SpellCreatureMove.new(_board, _player_system)


func after_each():
	if _board and is_instance_valid(_board):
		_board.free()
	if _player_system and is_instance_valid(_player_system):
		_player_system.free()


## クリーチャー配置
func _place_creature(tile_index: int, owner_id: int = 0,
		creature_name: String = "テストクリーチャー", hp: int = 40, ap: int = 30,
		element: String = "fire") -> void:
	var creature = Helper.make_creature(creature_name, hp, ap, element)
	creature["id"] = tile_index * 100 + owner_id
	var tile = _board.tile_nodes[tile_index]
	tile.creature_data = creature.duplicate(true)
	tile.owner_id = owner_id


## JSON定義からeffect_typesを取得（スペル用）
func _get_spell_effect_types(spell_id: int) -> Array[String]:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	return types


## JSON定義からeffect_typesを取得（アルカナアーツ用）
func _get_mystic_effect_types(creature_id: int) -> Array[String]:
	var card = CardLoader.get_card_by_id(creature_id)
	var mystic = card.get("ability_parsed", {}).get("mystic_art", {})
	var effects: Array = mystic.get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	return types


# ========================================
# JSON定義確認
# ========================================

## インベイド(2002): move_to_adjacent_enemy
func test_invade_json():
	var types = _get_spell_effect_types(2002)
	assert_true(types.has("move_to_adjacent_enemy"), "インベイド: move_to_adjacent_enemy持ち")
	var card = CardLoader.get_card_by_id(2002)
	var target_info = card.get("effect_parsed", {}).get("target_info", {})
	assert_true(target_info.get("has_adjacent_enemy", false), "インベイド: has_adjacent_enemy条件")
	assert_true(target_info.get("can_move", false), "インベイド: can_move条件")


## ラッシュ(2052): move_steps, exact_steps=true, steps=2
func test_rush_json():
	var types = _get_spell_effect_types(2052)
	assert_true(types.has("move_steps"), "ラッシュ: move_steps持ち")
	var card = CardLoader.get_card_by_id(2052)
	var effects = card.get("effect_parsed", {}).get("effects", [])
	assert_eq(int(effects[0].get("steps", 0)), 2, "ラッシュ: 2マス移動")
	assert_true(effects[0].get("exact_steps", false), "ラッシュ: ちょうど2マス")
	var effect_parsed = card.get("effect_parsed", {})
	assert_true(effect_parsed.get("return_to_deck", false), "ラッシュ: 復帰[ブック]")


## ワンダーフレア(10): move_self, exclude_enemy_creatures=true（堅守）
func test_wonder_flare_json():
	var types = _get_mystic_effect_types(10)
	assert_true(types.has("move_self"), "ワンダーフレア: move_self持ち")
	var card = CardLoader.get_card_by_id(10)
	var effects = card.get("ability_parsed", {}).get("mystic_art", {}).get("effects", [])
	assert_eq(int(effects[0].get("steps", 0)), 1, "ワンダーフレア: 1マス移動")
	assert_true(effects[0].get("exclude_enemy_creatures", false), "ワンダーフレア: 敵除外")


## ファントムクロー(21): destroy_and_move
func test_phantom_claw_json():
	var types = _get_mystic_effect_types(21)
	assert_true(types.has("destroy_and_move"), "ファントムクロー: destroy_and_move持ち")
	var card = CardLoader.get_card_by_id(21)
	var target_info = card.get("ability_parsed", {}).get("mystic_art", {}).get("target_info", {})
	assert_eq(target_info.get("owner_filter", ""), "enemy", "ファントムクロー: 敵対象")
	assert_true(target_info.get("hp_reduced", false), "ファントムクロー: HP減少条件")
	assert_true(target_info.get("is_down", false), "ファントムクロー: ダウン条件")


## ゲイルスタリオン(322): move_steps, steps=2
func test_gale_stallion_json():
	var types = _get_mystic_effect_types(322)
	assert_true(types.has("move_steps"), "ゲイルスタリオン: move_steps持ち")
	var card = CardLoader.get_card_by_id(322)
	var effects = card.get("ability_parsed", {}).get("mystic_art", {}).get("effects", [])
	assert_eq(int(effects[0].get("steps", 0)), 2, "ゲイルスタリオン: 2マス移動")


# ========================================
# _execute_move: 移動実行
# ========================================

## 基本移動: クリーチャーが移動先に配置される
func test_execute_move_basic():
	_place_creature(3, 0, "移動者", 40, 30)
	var original_creature = _board.tile_nodes[3].creature_data.duplicate(true)

	_spell_move._execute_move(3, 5)

	# 移動元: クリーチャーなし、所有者なし
	assert_true(_board.tile_nodes[3].creature_data.is_empty(), "移動元: クリーチャーなし")
	assert_eq(_board.tile_nodes[3].owner_id, -1, "移動元: 所有者クリア")
	# 移動先: クリーチャーあり、所有者設定
	assert_false(_board.tile_nodes[5].creature_data.is_empty(), "移動先: クリーチャーあり")
	assert_eq(_board.tile_nodes[5].owner_id, 0, "移動先: 所有者=P0")
	assert_eq(_board.tile_nodes[5].creature_data.get("name", ""), "移動者", "移動先: 名前一致")


## 移動後ダウン状態になる
func test_execute_move_down_state():
	_place_creature(3, 0)

	_spell_move._execute_move(3, 5)

	assert_true(_board.tile_nodes[5].is_down(), "移動後: ダウン状態")


## 移動で刻印が消滅する
func test_execute_move_removes_curse():
	_place_creature(3, 0)
	_board.tile_nodes[3].creature_data["curse"] = {
		"curse_type": "stat_reduction",
		"name": "テスト刻印"
	}

	_spell_move._execute_move(3, 5)

	assert_false(_board.tile_nodes[5].creature_data.has("curse"), "移動: 刻印消滅")


## 所有者が正しく移動する
func test_execute_move_owner_transfer():
	_place_creature(3, 1, "P1のクリーチャー")

	_spell_move._execute_move(3, 7)

	assert_eq(_board.tile_nodes[7].owner_id, 1, "移動先: P1所有")
	assert_eq(_board.tile_nodes[3].owner_id, -1, "移動元: 所有者クリア")


## 無効なタイルへの移動（存在しないタイル）
func test_execute_move_invalid_tile():
	_place_creature(3, 0)

	# 存在しないタイルへの移動（クラッシュしない）
	_spell_move._execute_move(3, 99)

	# to_tile_nodeがnullなので何も起きず、元のクリーチャーはそのまま
	assert_false(_board.tile_nodes[3].creature_data.is_empty(), "移動元: クリーチャー残存")


# ========================================
# _apply_destroy_and_move: 破壊移動
# ========================================

## 基本: HP減少+ダウン状態のクリーチャーを破壊して移動
func test_destroy_and_move_basic():
	# 発動者（タイル1）
	_place_creature(1, 0, "発動者", 40, 30)
	# 対象（タイル3）: HP減少 + ダウン状態
	_place_creature(3, 1, "対象", 50, 20)
	_board.tile_nodes[3].creature_data["current_hp"] = 30  # HP減少
	_board.tile_nodes[3].set_down_state(true)

	var target_data = {
		"tile_index": 3,
		"caster_tile_index": 1
	}

	var result = _spell_move._apply_destroy_and_move(target_data)

	assert_true(result.get("success", false), "破壊移動: 成功")
	# 対象が破壊されている
	assert_true(_board.tile_nodes[3].creature_data.is_empty() == false, "タイル3: 発動者が移動")
	# 発動者がタイル3に移動
	assert_eq(_board.tile_nodes[3].creature_data.get("name", ""), "発動者", "タイル3: 発動者")
	# 発動者の元の場所は空
	assert_true(_board.tile_nodes[1].creature_data.is_empty(), "タイル1: 空")


## HP満タンの場合は破壊不可
func test_destroy_and_move_full_hp():
	_place_creature(1, 0, "発動者", 40, 30)
	_place_creature(3, 1, "対象", 50, 20)
	# HP満タン + ダウン
	_board.tile_nodes[3].set_down_state(true)

	var target_data = {
		"tile_index": 3,
		"caster_tile_index": 1
	}

	var result = _spell_move._apply_destroy_and_move(target_data)

	assert_false(result.get("success", true), "HP満タン: 破壊不可")
	assert_eq(result.get("reason", ""), "condition_not_met", "理由: condition_not_met")


## ダウンしていない場合は破壊不可
func test_destroy_and_move_not_down():
	_place_creature(1, 0, "発動者", 40, 30)
	_place_creature(3, 1, "対象", 50, 20)
	_board.tile_nodes[3].creature_data["current_hp"] = 30  # HP減少
	# ダウンしていない

	var target_data = {
		"tile_index": 3,
		"caster_tile_index": 1
	}

	var result = _spell_move._apply_destroy_and_move(target_data)

	assert_false(result.get("success", true), "ダウンなし: 破壊不可")


## 空タイルへの破壊移動は不可
func test_destroy_and_move_empty_tile():
	_place_creature(1, 0, "発動者", 40, 30)
	# タイル3にクリーチャーなし

	var target_data = {
		"tile_index": 3,
		"caster_tile_index": 1
	}

	var result = _spell_move._apply_destroy_and_move(target_data)

	assert_false(result.get("success", true), "空タイル: 破壊不可")
	assert_eq(result.get("reason", ""), "no_creature", "理由: no_creature")


## 無効なタイルインデックス
func test_destroy_and_move_invalid_tile():
	var target_data = {
		"tile_index": -1,
		"caster_tile_index": 1
	}

	var result = _spell_move._apply_destroy_and_move(target_data)

	assert_false(result.get("success", true), "無効タイル: 失敗")
	assert_eq(result.get("reason", ""), "invalid_tile", "理由: invalid_tile")


# ========================================
# 枷刻印チェック
# ========================================

## 枷刻印がある場合は移動不可を検出
func test_has_move_disable_curse():
	_place_creature(3, 0)
	_board.tile_nodes[3].creature_data["curse"] = {
		"curse_type": "move_disable",
		"name": "枷"
	}

	assert_true(_spell_move._has_move_disable_curse(3), "枷刻印: 移動不可")


## 枷以外の刻印は移動可能
func test_no_move_disable_with_other_curse():
	_place_creature(3, 0)
	_board.tile_nodes[3].creature_data["curse"] = {
		"curse_type": "stat_reduction",
		"name": "テスト刻印"
	}

	assert_false(_spell_move._has_move_disable_curse(3), "他の刻印: 移動可能")


## 刻印なしは移動可能
func test_no_curse_allows_move():
	_place_creature(3, 0)

	assert_false(_spell_move._has_move_disable_curse(3), "刻印なし: 移動可能")


## 空タイルは移動不可判定にならない
func test_move_disable_empty_tile():
	assert_false(_spell_move._has_move_disable_curse(3), "空タイル: false")


# ========================================
# 移動先取得: get_adjacent_enemy_destinations
# ========================================

## 隣接する敵ドミニオが移動候補になる
func test_get_adjacent_enemy_destinations_basic():
	# タイル3にP0のクリーチャー、タイル2とタイル4にP1のクリーチャー
	# connections: tile3 → [2, 4]
	_place_creature(3, 0, "自軍", 40, 30)
	_place_creature(2, 1, "敵1", 40, 30)
	_place_creature(4, 1, "敵2", 40, 30)
	_board.current_player_index = 0

	var destinations = _spell_move.get_adjacent_enemy_destinations(3)

	assert_eq(destinations.size(), 2, "隣接敵ドミニオ: 2箇所")
	assert_true(2 in destinations, "タイル2が候補")
	assert_true(4 in destinations, "タイル4が候補")


## 隣接に自クリーチャーしかない場合は候補なし
func test_get_adjacent_enemy_destinations_no_enemy():
	_place_creature(3, 0, "自軍", 40, 30)
	_place_creature(2, 0, "味方", 40, 30)
	_place_creature(4, 0, "味方2", 40, 30)
	_board.current_player_index = 0

	var destinations = _spell_move.get_adjacent_enemy_destinations(3)

	assert_eq(destinations.size(), 0, "敵なし: 候補0")


## 隣接に空タイルのみの場合は候補なし
func test_get_adjacent_enemy_destinations_empty_tiles():
	_place_creature(3, 0, "自軍", 40, 30)
	_board.current_player_index = 0

	var destinations = _spell_move.get_adjacent_enemy_destinations(3)

	assert_eq(destinations.size(), 0, "空タイルのみ: 候補0")


# ========================================
# 移動先取得: _get_tiles_within_steps
# ========================================

## 1マス以内の候補（タイル3 → 隣接の2, 4）
func test_get_tiles_within_steps_one():
	_board.current_player_index = 0

	var destinations = _spell_move._get_tiles_within_steps(3, 1)

	# タイル3の隣接: 2, 4。checkpointは除外されない（fire, fire）
	assert_true(2 in destinations, "1マス: タイル2")
	assert_true(4 in destinations, "1マス: タイル4")
	assert_false(3 in destinations, "1マス: 移動元除外")


## 2マス以内の候補（タイル3 → 1,2,4,5）
func test_get_tiles_within_steps_two():
	_board.current_player_index = 0

	var destinations = _spell_move._get_tiles_within_steps(3, 2)

	# タイル3: connections=[2,4], タイル2: connections=[1,3], タイル4: connections=[3,5]
	# 1マス: 2, 4 / 2マス: 1, 5（3は移動元で除外、2と4は既に1マスで発見済み）
	assert_true(1 in destinations, "2マス: タイル1")
	assert_true(2 in destinations, "2マス: タイル2")
	assert_true(4 in destinations, "2マス: タイル4")
	assert_true(5 in destinations, "2マス: タイル5")


## チェックポイントタイルは配置不可で除外される
func test_get_tiles_within_steps_excludes_checkpoint():
	# タイル1(fire)からの1マス移動 → タイル0(checkpoint), タイル2(fire)
	_board.current_player_index = 0

	var destinations = _spell_move._get_tiles_within_steps(1, 1)

	# checkpoint(タイル0)は配置不可
	assert_false(0 in destinations, "checkpoint除外")
	assert_true(2 in destinations, "fireタイルは含む")


## 自クリーチャーがいるタイルは含む（_get_tiles_within_stepsでは除外しない）
func test_get_tiles_within_steps_includes_own_creature():
	_place_creature(2, 0, "味方", 40, 30)
	_board.current_player_index = 0

	var destinations = _spell_move._get_tiles_within_steps(3, 1)

	# _get_tiles_within_stepsは自クリーチャーを除外しない
	# （除外は呼び出し元の_apply_move_stepsで行う）
	assert_true(2 in destinations, "自クリーチャータイル: 含む")


# ========================================
# 移動先取得: _get_tiles_at_exact_steps
# ========================================

## ちょうど2マス先の候補（チャリオット用）
func test_get_tiles_at_exact_steps_two():
	_board.current_player_index = 0

	var destinations = _spell_move._get_tiles_at_exact_steps(3, 2)

	# タイル3→[2,4]→[1,3,5] ちょうど2マス: 1, 5 (3は移動元なので結果に含まれるが距離0)
	# visited: {3:0, 2:1, 4:1, 1:2, 5:2}
	# exact_steps=2: 1, 5
	assert_true(1 in destinations, "ちょうど2マス: タイル1")
	assert_true(5 in destinations, "ちょうど2マス: タイル5")
	assert_false(2 in destinations, "1マスは除外: タイル2")
	assert_false(4 in destinations, "1マスは除外: タイル4")


## ちょうど1マス先の候補
func test_get_tiles_at_exact_steps_one():
	_board.current_player_index = 0

	var destinations = _spell_move._get_tiles_at_exact_steps(3, 1)

	assert_true(2 in destinations, "ちょうど1マス: タイル2")
	assert_true(4 in destinations, "ちょうど1マス: タイル4")


## チェックポイントはちょうどN歩先でも除外
func test_get_tiles_at_exact_steps_excludes_checkpoint():
	# タイル2(fire)からちょうど2マス → タイル0(checkpoint), タイル4(fire)
	_board.current_player_index = 0

	var destinations = _spell_move._get_tiles_at_exact_steps(2, 2)

	assert_false(0 in destinations, "checkpoint除外")
	assert_true(4 in destinations, "fireタイルは含む")


# ========================================
# ターゲット取得
# ========================================

## get_outrage_targets: 隣接敵ドミニオがあるクリーチャータイルを取得
func test_get_outrage_targets():
	_place_creature(3, 0, "自軍1", 40, 30)
	_place_creature(4, 1, "敵1", 40, 30)
	_place_creature(7, 0, "自軍2", 40, 30)
	_board.current_player_index = 0

	var targets = _spell_move.get_outrage_targets()

	# タイル3の隣接4に敵がいる → 3がターゲット
	assert_true(3 in targets, "タイル3: 隣接敵あり")
	# タイル7の隣接6,8には敵がいない
	assert_false(7 in targets, "タイル7: 隣接敵なし")


## get_chariot_targets: 自クリーチャーのタイル一覧
func test_get_chariot_targets():
	_place_creature(3, 0, "自軍1", 40, 30)
	_place_creature(7, 0, "自軍2", 40, 30)
	_place_creature(12, 1, "敵", 40, 30)

	var targets = _spell_move.get_chariot_targets(0)

	assert_eq(targets.size(), 2, "自クリーチャー2体")
	assert_true(3 in targets, "タイル3")
	assert_true(7 in targets, "タイル7")
	assert_false(12 in targets, "敵タイル除外")


## get_chariot_targets: 自クリーチャーなし
func test_get_chariot_targets_none():
	_place_creature(12, 1, "敵", 40, 30)

	var targets = _spell_move.get_chariot_targets(0)

	assert_eq(targets.size(), 0, "自クリーチャーなし")
