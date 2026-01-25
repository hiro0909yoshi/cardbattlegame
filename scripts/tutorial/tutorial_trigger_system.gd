extends Node
class_name TutorialTriggerSystem
## ゲームシグナルを監視し、チュートリアルのトリガー条件と照合する

signal trigger_fired(trigger_type: String, data: Dictionary)

# 外部参照
var game_flow_manager = null
var board_system_3d = null
var ui_manager = null

# 登録されたトリガー
var _completion_trigger: Dictionary = {}  # 現在のステップの完了トリガー
var _step_triggers: Array = []  # 次のステップへのトリガー

# 現在のステップ情報
var _current_step: Dictionary = {}

func setup(gfm, bsys, uim):
	game_flow_manager = gfm
	board_system_3d = bsys
	ui_manager = uim
	
	_connect_game_signals()

## ゲームシグナルを接続
func _connect_game_signals():
	# GameFlowManager
	if game_flow_manager:
		if game_flow_manager.has_signal("turn_started"):
			game_flow_manager.turn_started.connect(_on_turn_started)
		if game_flow_manager.has_signal("dice_rolled"):
			game_flow_manager.dice_rolled.connect(_on_dice_rolled)
		if game_flow_manager.lap_system and game_flow_manager.lap_system.has_signal("checkpoint_signal_obtained"):
			game_flow_manager.lap_system.checkpoint_signal_obtained.connect(_on_checkpoint_passed)
	
	# BoardSystem3D
	if board_system_3d:
		if board_system_3d.movement_controller:
			board_system_3d.movement_controller.movement_completed.connect(_on_movement_completed)
		if board_system_3d.tile_action_processor:
			board_system_3d.tile_action_processor.action_completed.connect(_on_action_completed)
		if board_system_3d.battle_system and board_system_3d.battle_system.battle_screen_manager:
			var bsm = board_system_3d.battle_system.battle_screen_manager
			if bsm.has_signal("intro_completed"):
				bsm.intro_completed.connect(_on_battle_intro_completed)
			if bsm.has_signal("battle_screen_closed"):
				bsm.battle_screen_closed.connect(_on_battle_screen_closed)
	
	# UIManager - カード選択
	if ui_manager and ui_manager.card_selection_ui:
		var csu = ui_manager.card_selection_ui
		if csu.has_signal("card_selected"):
			csu.card_selected.connect(_on_card_selected)
		if csu.has_signal("card_info_shown"):
			csu.card_info_shown.connect(_on_card_info_shown)

## 現在のステップを設定
func set_current_step(step: Dictionary):
	_current_step = step

## 完了トリガーを登録
func register_completion_trigger(signal_name: String, conditions: Dictionary, step_id: int):
	_completion_trigger = {
		"signal": signal_name,
		"conditions": conditions,
		"step_id": step_id
	}

## 完了トリガーをクリア
func clear_completion_trigger():
	_completion_trigger = {}

## ステップトリガーを登録
func register_step_trigger(signal_name: String, conditions: Dictionary, step_id: int):
	_step_triggers.append({
		"signal": signal_name,
		"conditions": conditions,
		"step_id": step_id
	})

## 全てクリア
func clear_all():
	_completion_trigger = {}
	_step_triggers.clear()
	_current_step = {}

## シグナルとトリガーを照合
func _check_trigger(signal_name: String, signal_data: Dictionary = {}):
	# 完了トリガーをチェック
	if _completion_trigger.get("signal", "") == signal_name:
		if _match_conditions(_completion_trigger.get("conditions", {}), signal_data):
			trigger_fired.emit("completion", {})
			return
	
	# ステップトリガーをチェック
	for trigger in _step_triggers:
		if trigger.get("signal", "") == signal_name:
			if _match_conditions(trigger.get("conditions", {}), signal_data):
				trigger_fired.emit("next_step", {"step_id": trigger.get("step_id", -1)})
				_step_triggers.erase(trigger)
				return

## 条件をマッチング
func _match_conditions(conditions: Dictionary, data: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	
	for key in conditions.keys():
		var expected = conditions[key]
		var actual = data.get(key, null)
		
		# phase_match: 現在のフェーズが配列内のいずれかにマッチ
		if key == "phase_match":
			var current_phase = _current_step.get("phase", "")
			if current_phase not in expected:
				return false
		elif actual != expected:
			return false
	
	return true

# === シグナルハンドラ ===

func _on_turn_started(player_id: int):
	_check_trigger("turn_started", {"player_id": player_id})

func _on_dice_rolled(value: int):
	_check_trigger("dice_rolled", {"value": value})

func _on_movement_completed(player_id: int, final_tile: int):
	_check_trigger("movement_completed", {"player_id": player_id, "final_tile": final_tile})

func _on_action_completed():
	_check_trigger("action_completed", {"phase": _current_step.get("phase", "")})

func _on_checkpoint_passed(player_id: int, checkpoint_type: String):
	_check_trigger("checkpoint_passed", {"player_id": player_id, "checkpoint_type": checkpoint_type})

func _on_battle_intro_completed():
	_check_trigger("battle_intro_completed", {})

func _on_battle_screen_closed():
	_check_trigger("battle_screen_closed", {})

func _on_card_selected(card_index: int):
	_check_trigger("card_selected", {"card_index": card_index})

func _on_card_info_shown(card_index: int):
	_check_trigger("card_info_shown", {"card_index": card_index})
