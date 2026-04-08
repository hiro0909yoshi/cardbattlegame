extends GutTest

## GameFlowStateMachine のフェーズ遷移テスト
## 不正遷移の検出・ワープ系スペルのスキップフロー等を検証

# GameFlowManager.GamePhase を模倣（テスト用）
const _GamePhase = preload("res://scripts/game_flow_manager.gd")

var _sm: GameFlowStateMachine


func before_each():
	_sm = GameFlowStateMachine.new()
	_sm.initialize(_GamePhase.GamePhase)


## === 基本遷移テスト ===

func test_initial_state_is_setup():
	assert_eq(_sm.current_state, _GamePhase.GamePhase.SETUP)


func test_setup_to_dice_roll():
	assert_true(_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL))


func test_dice_roll_to_moving():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	assert_true(_sm.transition_to(_GamePhase.GamePhase.MOVING))


func test_moving_to_tile_action():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	_sm.transition_to(_GamePhase.GamePhase.MOVING)
	assert_true(_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION))


func test_tile_action_to_battle():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	_sm.transition_to(_GamePhase.GamePhase.MOVING)
	_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION)
	assert_true(_sm.transition_to(_GamePhase.GamePhase.BATTLE))


func test_tile_action_to_end_turn():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	_sm.transition_to(_GamePhase.GamePhase.MOVING)
	_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION)
	assert_true(_sm.transition_to(_GamePhase.GamePhase.END_TURN))


func test_end_turn_to_setup():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	_sm.transition_to(_GamePhase.GamePhase.MOVING)
	_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION)
	_sm.transition_to(_GamePhase.GamePhase.END_TURN)
	assert_true(_sm.transition_to(_GamePhase.GamePhase.SETUP))


## === ワープ系スペルのスキップフロー（BUG再発防止） ===

func test_setup_to_tile_action_warp_skip():
	## ワープ系スペル使用時: SETUP → TILE_ACTION（ダイスフェーズスキップ）
	## ジャンプ(2104)等のテレポート系スペル使用後のフロー
	assert_true(
		_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION),
		"SETUP -> TILE_ACTION: ワープ系スペルでダイスフェーズをスキップ可能であること"
	)


func test_dice_roll_to_tile_action_warp():
	## DICE_ROLL中のワープ: DICE_ROLL → TILE_ACTION
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	assert_true(
		_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION),
		"DICE_ROLL -> TILE_ACTION: ワープ系スペル使用可能であること"
	)


## === 完全なターンサイクルテスト ===

func test_full_turn_cycle_normal():
	## 通常フロー: SETUP → DICE_ROLL → MOVING → TILE_ACTION → END_TURN → SETUP
	assert_true(_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.MOVING))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.END_TURN))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.SETUP))


func test_full_turn_cycle_with_battle():
	## バトルフロー: ... → TILE_ACTION → BATTLE → END_TURN → SETUP
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	_sm.transition_to(_GamePhase.GamePhase.MOVING)
	_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION)
	assert_true(_sm.transition_to(_GamePhase.GamePhase.BATTLE))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.END_TURN))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.SETUP))


func test_full_turn_cycle_warp_skip():
	## ワープフロー: SETUP → TILE_ACTION → END_TURN → SETUP
	## ジャンプ等のテレポート系スペルでダイスフェーズをスキップした場合
	assert_true(_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.END_TURN))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.SETUP))


func test_full_turn_cycle_warp_then_battle():
	## ワープ+バトル: SETUP → TILE_ACTION → BATTLE → END_TURN → SETUP
	## テレポート先に敵クリーチャーがいた場合
	assert_true(_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.BATTLE))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.END_TURN))
	assert_true(_sm.transition_to(_GamePhase.GamePhase.SETUP))


## === 不正遷移の検出 ===

func test_invalid_setup_to_moving():
	assert_false(
		_sm.transition_to(_GamePhase.GamePhase.MOVING),
		"SETUP -> MOVING は不正遷移"
	)


func test_invalid_setup_to_battle():
	assert_false(
		_sm.transition_to(_GamePhase.GamePhase.BATTLE),
		"SETUP -> BATTLE は不正遷移"
	)


func test_invalid_setup_to_end_turn():
	assert_false(
		_sm.transition_to(_GamePhase.GamePhase.END_TURN),
		"SETUP -> END_TURN は不正遷移"
	)


func test_invalid_dice_roll_to_end_turn():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	assert_false(
		_sm.transition_to(_GamePhase.GamePhase.END_TURN),
		"DICE_ROLL -> END_TURN は不正遷移"
	)


func test_invalid_tile_action_to_setup():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	_sm.transition_to(_GamePhase.GamePhase.MOVING)
	_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION)
	assert_false(
		_sm.transition_to(_GamePhase.GamePhase.SETUP),
		"TILE_ACTION -> SETUP は不正遷移"
	)


## === 再遷移テスト ===

func test_setup_re_entry():
	assert_true(_sm.transition_to(_GamePhase.GamePhase.SETUP))


func test_tile_action_re_entry():
	_sm.transition_to(_GamePhase.GamePhase.DICE_ROLL)
	_sm.transition_to(_GamePhase.GamePhase.MOVING)
	_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION)
	assert_true(_sm.transition_to(_GamePhase.GamePhase.TILE_ACTION))
