extends Node
class_name TutorialStepExecutor
## ステップのアクションを実行する

# 外部参照
var game_flow_manager = null
var board_system_3d = null
var card_system = null

# ステージ設定
var _dice_sequence: Array = []
var _current_dice_index: int = 0

func setup(gfm, bsys, cs):
	game_flow_manager = gfm
	board_system_3d = bsys
	card_system = cs

## 初期手札を設定
func set_initial_hands(player_hand: Array, cpu_hand: Array):
	if not card_system:
		return
	
	# プレイヤー0の手札
	if card_system.has_method("set_hand_by_card_ids"):
		card_system.set_hand_by_card_ids(0, player_hand)
	
	# プレイヤー1（CPU）の手札
	if cpu_hand.size() > 0 and card_system.has_method("set_hand_by_card_ids"):
		card_system.set_hand_by_card_ids(1, cpu_hand)
	
	print("[TutorialStepExecutor] Initial hands set")

## ダイスシーケンスを設定
func set_dice_sequence(sequence: Array):
	_dice_sequence = sequence
	_current_dice_index = 0
	
	# 最初のダイスを設定
	_apply_current_dice()
	
	print("[TutorialStepExecutor] Dice sequence set: %s" % str(sequence))

## 現在のダイスを適用
func _apply_current_dice():
	if game_flow_manager and _current_dice_index < _dice_sequence.size():
		var dice_value = _dice_sequence[_current_dice_index]
		if game_flow_manager.has_method("set_next_dice"):
			game_flow_manager.set_next_dice(dice_value)

## 次のダイスへ
func advance_dice():
	_current_dice_index += 1
	_apply_current_dice()

## アクションを実行
func execute_actions(actions: Dictionary):
	if actions.is_empty():
		return
	
	# ゲーム一時停止
	if actions.get("pause_game", false):
		get_tree().paused = true
	
	# ボタン無効化
	if actions.get("disable_buttons", false):
		_disable_all_buttons()

## ボタンを全て無効化
func _disable_all_buttons():
	# TutorialHighlighterに委譲するか、直接UIManagerを操作
	pass  # Highlighterで処理

## クリーンアップ
func cleanup():
	# ポーズ解除
	if get_tree().paused:
		get_tree().paused = false
