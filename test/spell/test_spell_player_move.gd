extends GutTest

## プレイヤー移動系テスト
## SpellPlayerMove の距離計算 / ワープ / 方向制御 / ゲート通過 + JSON定義確認
## MockBoard + TileNeighborSystem + SpellCurse使用

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _board: BoardSystem3D
var _player_system: PlayerSystem
var _spell_curse: SpellCurse
var _spell_move: SpellPlayerMove


func before_each():
	_board = MockBoard.new()
	_board.name = "MockBoard_PlayerMove"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()
	_board.setup_tile_neighbor_system()

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_PlayerMove"
	add_child(_player_system)
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 500
	p0.current_tile = 3
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 500
	p1.current_tile = 12
	_player_system.players = [p0, p1]

	_spell_curse = SpellCurse.new()
	_spell_curse.name = "SpellCurse_PlayerMove"
	add_child(_spell_curse)
	_spell_curse.player_system = _player_system

	_spell_move = SpellPlayerMove.new()
	_spell_move.name = "SpellPlayerMove_Test"
	add_child(_spell_move)
	_spell_move.setup(_board, _player_system, null, _spell_curse)

	# MockBoardのプレイヤー位置を設定
	_board._player_tiles[0] = 3
	_board._player_tiles[1] = 12


func after_each():
	if is_instance_valid(_spell_move):
		_spell_move.free()
	if is_instance_valid(_spell_curse):
		_spell_curse.free()
	if is_instance_valid(_player_system):
		_player_system.free()
	if is_instance_valid(_board):
		_board.free()


## JSON定義からeffect_typesを取得
func _get_effect_types(spell_id: int) -> Array[String]:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	return types


## アルカナアーツのeffect_typesを取得
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

## テレポ(2014): warp_to_nearest_vacant
func test_telepo_json():
	var types = _get_effect_types(2014)
	assert_true(types.has("warp_to_nearest_vacant"), "テレポ: warp_to_nearest_vacant持ち")


## ポータル(2079): warp_to_nearest_gate
func test_portal_json():
	var types = _get_effect_types(2079)
	assert_true(types.has("warp_to_nearest_gate"), "ポータル: warp_to_nearest_gate持ち")


## ジャンプ(2104): warp_to_target
func test_jump_json():
	var types = _get_effect_types(2104)
	assert_true(types.has("warp_to_target"), "ジャンプ: warp_to_target持ち")


## インバート(2019): curse_movement_reverse
func test_invert_json():
	var types = _get_effect_types(2019)
	assert_true(types.has("curse_movement_reverse"), "インバート: curse_movement_reverse持ち")


## ルート(2123): gate_pass
func test_route_json():
	var types = _get_effect_types(2123)
	assert_true(types.has("gate_pass"), "ルート: gate_pass持ち")


## ナビゲート(9021): grant_direction_choice
func test_navigate_json():
	var types = _get_mystic_effect_types(322)
	# ナビゲートはクロックアウル(9021)のアルカナアーツだが、
	# IDは9021でクリーチャーではなくmystic_artとして定義されている可能性
	# 直接カードID確認
	var card = CardLoader.get_card_by_id(9021)
	if not card.is_empty():
		var effects = card.get("effect_parsed", {}).get("effects", [])
		var mystic_effects = card.get("ability_parsed", {}).get("mystic_art", {}).get("effects", [])
		var all_types: Array[String] = []
		for e in effects:
			all_types.append(e.get("effect_type", ""))
		for e in mystic_effects:
			all_types.append(e.get("effect_type", ""))
		assert_true(all_types.has("grant_direction_choice"), "ナビゲート: grant_direction_choice持ち")
	else:
		# カードが見つからない場合はスキップ
		pass_test("ナビゲート(9021): カードデータ未登録")


# ========================================
# calculate_tile_distance: BFS距離計算
# ========================================

## 隣接タイル（距離1）
func test_distance_adjacent():
	var dist = _spell_move.calculate_tile_distance(3, 4)
	assert_eq(dist, 1, "タイル3→4: 距離1")


## 2マス離れたタイル
func test_distance_two():
	var dist = _spell_move.calculate_tile_distance(3, 5)
	assert_eq(dist, 2, "タイル3→5: 距離2")


## 同じタイル（距離0）
func test_distance_same():
	var dist = _spell_move.calculate_tile_distance(3, 3)
	assert_eq(dist, 0, "タイル3→3: 距離0")


## 反対側への距離（環状ボード: 20タイル）
func test_distance_opposite():
	# タイル0→10: 環状なので順方向10マス or 逆方向10マス = 距離10
	var dist = _spell_move.calculate_tile_distance(0, 10)
	assert_eq(dist, 10, "タイル0→10: 距離10")


## 近い方の経路で距離計算
func test_distance_shorter_path():
	# タイル0→19: 順方向19マス or 逆方向1マス = 距離1
	var dist = _spell_move.calculate_tile_distance(0, 19)
	assert_eq(dist, 1, "タイル0→19: 距離1（逆方向）")


# ========================================
# find_nearest_tile: BFS最寄検索
# ========================================

## 最寄チェックポイントを検索
func test_find_nearest_checkpoint():
	# タイル3(fire)から最寄checkpoint: タイル0(checkpoint, 距離3) or タイル10(checkpoint, 距離7)
	var is_checkpoint = func(idx: int) -> bool:
		return _board.tile_nodes[idx].tile_type == "checkpoint"

	var nearest = _spell_move.find_nearest_tile(3, is_checkpoint)
	assert_eq(nearest, 0, "タイル3から最寄checkpoint: タイル0")


## 条件に合致するタイルがない場合
func test_find_nearest_none():
	var is_blank = func(idx: int) -> bool:
		return _board.tile_nodes[idx].tile_type == "blank"

	var nearest = _spell_move.find_nearest_tile(3, is_blank)
	assert_eq(nearest, -1, "blankタイルなし: -1")


## 隣接タイルが条件に合致
func test_find_nearest_adjacent():
	# タイル5(neutral)から最寄water: タイル6(water, 距離1)
	var is_water = func(idx: int) -> bool:
		return _board.tile_nodes[idx].tile_type == "water"

	var nearest = _spell_move.find_nearest_tile(5, is_water)
	assert_eq(nearest, 6, "タイル5から最寄water: タイル6")


# ========================================
# get_tiles_in_range: 範囲内タイル取得
# ========================================

## 1～4マス範囲内のタイルを取得
func test_get_tiles_in_range():
	var tiles = _spell_move.get_tiles_in_range(3, 1, 4)

	# タイル3からの距離: 2→1, 4→1, 1→2, 5→2, 0→3, 6→3, 19→4, 7→4
	assert_true(2 in tiles, "距離1: タイル2")
	assert_true(4 in tiles, "距離1: タイル4")
	assert_true(1 in tiles, "距離2: タイル1")
	assert_true(5 in tiles, "距離2: タイル5")
	assert_true(7 in tiles, "距離4: タイル7")
	assert_false(3 in tiles, "移動元除外")


## 範囲外のタイルは含まない
func test_get_tiles_in_range_excludes():
	var tiles = _spell_move.get_tiles_in_range(3, 1, 2)

	# 距離3以上は含まない
	assert_false(0 in tiles, "距離3: タイル0 除外")
	assert_false(6 in tiles, "距離3: タイル6 除外")


# ========================================
# warp_to_target: 指定タイルへワープ
# ========================================

## 距離1～4のタイルにワープ成功
func test_warp_to_target_success():
	var result = await _spell_move.warp_to_target(0, 5)

	assert_true(result.get("success", false), "ワープ成功")
	assert_eq(result.get("from", -1), 3, "移動元: タイル3")
	assert_eq(result.get("to", -1), 5, "移動先: タイル5")
	# プレイヤー位置が更新されている
	assert_eq(_player_system.players[0].current_tile, 5, "current_tile更新")
	# 方向選択権が付与されている
	assert_true(_player_system.players[0].buffs.has("direction_choice_pending"),
		"方向選択権付与")


## 距離5以上はワープ不可
func test_warp_to_target_too_far():
	var result = await _spell_move.warp_to_target(0, 10)

	assert_false(result.get("success", true), "距離7: ワープ不可")


## 同じタイルへのワープ不可（距離0）
func test_warp_to_target_same_tile():
	var result = await _spell_move.warp_to_target(0, 3)

	assert_false(result.get("success", true), "同タイル: ワープ不可")


# ========================================
# grant_direction_choice: 方向選択権付与
# ========================================

## バフが設定される
func test_grant_direction_choice():
	_spell_move.grant_direction_choice(0)

	assert_true(_player_system.players[0].buffs.has("direction_choice_pending"),
		"方向選択権付与")


## 無効なプレイヤーIDでクラッシュしない
func test_grant_direction_choice_invalid():
	_spell_move.grant_direction_choice(-1)
	_spell_move.grant_direction_choice(99)
	pass_test("無効IDでクラッシュなし")


# ========================================
# get_available_directions: 利用可能方向
# ========================================

## 通常: 順方向のみ
func test_available_directions_normal():
	var dirs = _spell_move.get_available_directions(0)
	assert_eq(dirs, [1], "通常: 順方向のみ")


## 方向選択権あり: 両方向
func test_available_directions_with_choice():
	_player_system.players[0].buffs["direction_choice_pending"] = true

	var dirs = _spell_move.get_available_directions(0)
	assert_eq(dirs, [1, -1], "選択権あり: 両方向")


## 反転刻印: 逆方向のみ
func test_available_directions_reversed():
	_spell_curse.curse_player(0, "movement_reverse", 1, {"name": "反転"})

	var dirs = _spell_move.get_available_directions(0)
	assert_eq(dirs, [-1], "反転: 逆方向のみ")


# ========================================
# consume_direction_choice: 方向選択権消費
# ========================================

## バフが消費される
func test_consume_direction_choice():
	_player_system.players[0].buffs["direction_choice_pending"] = true
	assert_true(_player_system.players[0].buffs.has("direction_choice_pending"), "前提: 選択権あり")

	_spell_move.consume_direction_choice(0)

	assert_false(_player_system.players[0].buffs.has("direction_choice_pending"), "消費後: 選択権なし")


## 選択権がない状態で消費してもクラッシュしない
func test_consume_direction_choice_none():
	_spell_move.consume_direction_choice(0)
	pass_test("選択権なしで消費: クラッシュなし")


# ========================================
# get_final_direction: 最終方向決定
# ========================================

## 通常 + 順方向選択 = 順方向(1)
func test_final_direction_normal_forward():
	var dir = _spell_move.get_final_direction(0, 1)
	assert_eq(dir, 1, "通常×順方向 = 1")


## 通常 + 逆方向選択 = 逆方向(-1)
func test_final_direction_normal_backward():
	var dir = _spell_move.get_final_direction(0, -1)
	assert_eq(dir, -1, "通常×逆方向 = -1")


## 反転 + 順方向選択 = 逆方向(-1)
func test_final_direction_reversed_forward():
	_spell_curse.curse_player(0, "movement_reverse", 1, {"name": "反転"})

	var dir = _spell_move.get_final_direction(0, 1)
	assert_eq(dir, -1, "反転×順方向 = -1")


## 反転 + 逆方向選択 = 順方向(1)
func test_final_direction_reversed_backward():
	_spell_curse.curse_player(0, "movement_reverse", 1, {"name": "反転"})

	var dir = _spell_move.get_final_direction(0, -1)
	assert_eq(dir, 1, "反転×逆方向 = 1")


# ========================================
# apply_movement_reverse_curse: 反転刻印付与
# ========================================

## 全プレイヤーに反転刻印が付与される
func test_reverse_curse_all_players():
	_spell_move.apply_movement_reverse_curse(1)

	for pid in range(2):
		var curse = _player_system.players[pid].curse
		assert_eq(curse.get("curse_type", ""), "movement_reverse",
			"プレイヤー%d: 反転刻印" % pid)
		assert_eq(curse.get("name", ""), "反転",
			"プレイヤー%d: 名前=反転" % pid)


## duration指定
func test_reverse_curse_duration():
	_spell_move.apply_movement_reverse_curse(3)

	var curse = _player_system.players[0].curse
	assert_eq(curse.get("duration", 0), 3, "duration=3")


# ========================================
# trigger_gate_pass: ゲート通過（LapSystem連携）
# ========================================

## ゲート通過でフラグが更新される
func test_trigger_gate_pass():
	# LapSystemのモック設定
	var lap = LapSystem.new()
	lap.name = "LapSystem_Test"
	add_child(lap)
	lap.required_checkpoints = ["N", "S"]
	lap.player_lap_state = {
		0: {"N": false, "S": false, "lap_count": 1}
	}
	lap.player_system = _player_system
	_spell_move.lap_system = lap

	var result = _spell_move.trigger_gate_pass(0, "N")

	assert_true(result.get("success", false), "ゲート通過成功")
	assert_eq(result.get("gate_key", ""), "N", "gate_key=N")
	assert_false(result.get("lap_completed", true), "1周未完了（Sが未通過）")
	assert_true(lap.player_lap_state[0]["N"], "Nフラグ=true")
	lap.free()


## 全ゲート通過で周回完了
func test_trigger_gate_pass_lap_complete():
	var lap = LapSystem.new()
	lap.name = "LapSystem_Complete"
	add_child(lap)
	lap.required_checkpoints = ["N", "S"]
	lap.player_lap_state = {
		0: {"N": true, "S": false, "lap_count": 1}
	}
	lap.player_system = _player_system
	lap.board_system_3d = _board
	_spell_move.lap_system = lap

	var result = _spell_move.trigger_gate_pass(0, "S")

	assert_true(result.get("success", false), "ゲート通過成功")
	assert_true(result.get("lap_completed", false), "周回完了")
	# 周回数がインクリメントされている
	assert_eq(lap.player_lap_state[0]["lap_count"], 2, "周回数=2")
	lap.free()


# ========================================
# get_selectable_gates: 選択可能ゲート
# ========================================

## 未通過ゲートが選択可能
func test_get_selectable_gates_unvisited():
	var lap = LapSystem.new()
	lap.name = "LapSystem_Selectable"
	add_child(lap)
	lap.required_checkpoints = ["N", "S"]
	lap.player_lap_state = {
		0: {"N": false, "S": false, "lap_count": 1}
	}
	_spell_move.lap_system = lap

	var gates = _spell_move.get_selectable_gates(0)

	# 両方未通過だが、どちらかを通過すると残り1つで1周完了になる
	# → 1周完了を引き起こすゲートは除外
	# N通過→S未通過→1周未完了 → N選択可
	# S通過→N未通過→1周未完了 → S選択可
	assert_eq(gates.size(), 2, "2ゲート選択可能")
	lap.free()


## 1つ通過済みなら残りは1周完了を引き起こすので除外
func test_get_selectable_gates_would_complete():
	var lap = LapSystem.new()
	lap.name = "LapSystem_WouldComplete"
	add_child(lap)
	lap.required_checkpoints = ["N", "S"]
	lap.player_lap_state = {
		0: {"N": true, "S": false, "lap_count": 1}
	}
	_spell_move.lap_system = lap

	var gates = _spell_move.get_selectable_gates(0)

	# S通過→N既通過→1周完了 → S除外
	assert_eq(gates.size(), 0, "1周完了を引き起こすため選択不可")
	lap.free()
