extends Node
class_name TutorialController
## チュートリアルのメインコントローラー
## ステップの進行管理とサブシステムの統括を行う

signal tutorial_started(stage_id: String)
signal tutorial_completed(stage_id: String)
signal step_started(step: Dictionary)
signal step_completed(step_id: int)

# サブシステム
var trigger_system: TutorialTriggerSystem
var step_executor: TutorialStepExecutor
var highlighter: TutorialHighlighter
var ui: TutorialUI

# ステージデータ
var _stage_data: Dictionary = {}
var _steps: Array = []
var _step_index_map: Dictionary = {}  # id -> index

# 状態
var _current_step_index: int = -1
var _is_active: bool = false
var _current_turn: int = 1

# 外部参照
var game_flow_manager = null
var board_system_3d = null
var ui_manager = null
var card_system = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_subsystems()

func _create_subsystems():
	# TriggerSystem
	trigger_system = TutorialTriggerSystem.new()
	trigger_system.name = "TriggerSystem"
	add_child(trigger_system)
	trigger_system.trigger_fired.connect(_on_trigger_fired)
	
	# StepExecutor
	step_executor = TutorialStepExecutor.new()
	step_executor.name = "StepExecutor"
	add_child(step_executor)
	
	# Highlighter
	highlighter = TutorialHighlighter.new()
	highlighter.name = "Highlighter"
	add_child(highlighter)
	
	# UI
	ui = TutorialUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.click_received.connect(_on_ui_click)

## 外部システムの参照を設定
func setup_systems(system_manager):
	if not system_manager:
		push_error("[TutorialController] system_manager is null")
		return
	
	game_flow_manager = system_manager.game_flow_manager
	board_system_3d = system_manager.board_system_3d
	ui_manager = system_manager.ui_manager
	card_system = system_manager.card_system
	
	# サブシステムに参照を渡す
	trigger_system.setup(game_flow_manager, board_system_3d, ui_manager)
	step_executor.setup(game_flow_manager, board_system_3d, card_system)
	highlighter.setup(board_system_3d, ui_manager)
	ui.setup(ui_manager)

## JSONファイルからステージを読み込み
func load_stage(json_path: String) -> bool:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("[TutorialController] Failed to open: " + json_path)
		return false
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("[TutorialController] JSON parse error: " + json.get_error_message())
		return false
	
	_stage_data = json.data
	_steps = _stage_data.get("steps", [])
	
	# ID -> インデックスのマップを作成
	_step_index_map.clear()
	for i in range(_steps.size()):
		var step_id = _steps[i].get("id", -1)
		if step_id >= 0:
			_step_index_map[step_id] = i
	
	print("[TutorialController] Loaded stage: %s (%d steps)" % [_stage_data.get("stage_id", "unknown"), _steps.size()])
	return true

## チュートリアル開始
func start():
	if _steps.is_empty():
		push_error("[TutorialController] No steps loaded")
		return
	
	_is_active = true
	_current_turn = 1
	
	# ステージ設定を適用
	_apply_stage_config()
	
	var stage_id = _stage_data.get("stage_id", "unknown")
	tutorial_started.emit(stage_id)
	
	# 最初のステップを実行
	_execute_step(0)

## 既存互換: start_tutorial
func start_tutorial():
	start()

## チュートリアル停止
func stop():
	_is_active = false
	_cleanup_current_step()
	trigger_system.clear_all()
	
	var stage_id = _stage_data.get("stage_id", "unknown")
	tutorial_completed.emit(stage_id)

## ステージ設定を適用
func _apply_stage_config():
	var config = _stage_data.get("config", {})
	
	# 初期手札の設定
	if config.has("player_initial_hand"):
		var player_hand = config.get("player_initial_hand", [])
		var cpu_hand = config.get("cpu_initial_hand", [])
		step_executor.set_initial_hands(player_hand, cpu_hand)
	
	# ダイスシーケンスの設定
	if config.has("dice_sequence"):
		var dice_seq = config.get("dice_sequence", [])
		step_executor.set_dice_sequence(dice_seq)

## ステップを実行
func _execute_step(index: int):
	if not _is_active:
		return
	
	if index < 0 or index >= _steps.size():
		print("[TutorialController] Tutorial completed")
		stop()
		return
	
	_current_step_index = index
	var step = _steps[index]
	
	print("[TutorialController] Executing step %d: %s" % [step.get("id", -1), step.get("phase", "")])
	step_started.emit(step)
	
	# トリガーシステムの状態を更新（現在のステップを登録）
	trigger_system.set_current_step(step)
	
	# アクションを実行
	var actions = step.get("actions", {})
	step_executor.execute_actions(actions)
	
	# ハイライトを適用
	var highlights = step.get("highlights", [])
	highlighter.apply_highlights(highlights)
	
	# UIを表示
	var message = step.get("message", "")
	var ui_config = step.get("ui", {})
	if message != "":
		ui.show_message(message, ui_config)
	
	# 完了条件を設定
	var completion = step.get("completion", {})
	_setup_completion(completion, step)

## 完了条件を設定
func _setup_completion(completion: Dictionary, step: Dictionary):
	var comp_type = completion.get("type", "auto")
	
	match comp_type:
		"click":
			# UIのクリック待ち（show_and_waitで処理）
			ui.enable_click_wait()
		"signal":
			# シグナル待ち（TriggerSystemに登録）
			var signal_name = completion.get("signal", "")
			var conditions = completion.get("conditions", {})
			trigger_system.register_completion_trigger(signal_name, conditions, step.get("id", -1))
		"auto":
			# 即座に次へ（after_stepトリガーを待つ）
			call_deferred("_on_step_auto_complete")

## クリック受信時
func _on_ui_click():
	if not _is_active or _current_step_index < 0:
		return
	
	var step = _steps[_current_step_index]
	var completion = step.get("completion", {})
	
	if completion.get("type", "") == "click":
		_complete_current_step()

## トリガー発火時
func _on_trigger_fired(trigger_type: String, data: Dictionary):
	if not _is_active:
		return
	
	print("[TutorialController] Trigger fired: %s" % trigger_type)
	
	# 完了トリガーの場合
	if trigger_type == "completion":
		_complete_current_step()
	# 次のステップのトリガーの場合
	elif trigger_type == "next_step":
		var next_id = data.get("step_id", -1)
		if _step_index_map.has(next_id):
			_execute_step(_step_index_map[next_id])

## 自動完了
func _on_step_auto_complete():
	if _is_active and _current_step_index >= 0:
		_complete_current_step()

## 現在のステップを完了
func _complete_current_step():
	if _current_step_index < 0 or _current_step_index >= _steps.size():
		return
	
	var step = _steps[_current_step_index]
	var step_id = step.get("id", -1)
	
	print("[TutorialController] Step %d completed" % step_id)
	
	# クリーンアップ
	_cleanup_current_step()
	
	step_completed.emit(step_id)
	
	# 最終ステップなら終了
	if step.get("is_final", false):
		stop()
		return
	
	# 次のステップを探す
	_find_and_execute_next_step(step)

## 現在のステップをクリーンアップ
func _cleanup_current_step():
	step_executor.cleanup()
	highlighter.clear_all()
	ui.hide_ui()
	trigger_system.clear_completion_trigger()

## 次のステップを探して実行
func _find_and_execute_next_step(current_step: Dictionary):
	var current_id = current_step.get("id", -1)
	
	# 次のステップの中で「after_step」トリガーを持つものを探す
	for i in range(_steps.size()):
		var step = _steps[i]
		var trigger = step.get("trigger", {})
		
		if trigger.get("type", "") == "after_step":
			if trigger.get("step_id", -1) == current_id:
				_execute_step(i)
				return
		elif trigger.get("type", "") == "immediate" and i == _current_step_index + 1:
			_execute_step(i)
			return
	
	# 見つからない場合、シグナルトリガーを待つ
	# TriggerSystemがシグナルを監視して次のステップを発火する
	_register_signal_triggers_for_next_steps(current_id)

## 次のステップのシグナルトリガーを登録
func _register_signal_triggers_for_next_steps(after_step_id: int):
	for i in range(_steps.size()):
		var step = _steps[i]
		var trigger = step.get("trigger", {})
		
		if trigger.get("type", "") == "signal":
			var signal_name = trigger.get("signal", "")
			var conditions = trigger.get("conditions", {})
			trigger_system.register_step_trigger(signal_name, conditions, step.get("id", -1))

## 現在アクティブか
func is_active() -> bool:
	return _is_active

## 現在のステップを取得
func get_current_step() -> Dictionary:
	if _current_step_index >= 0 and _current_step_index < _steps.size():
		return _steps[_current_step_index]
	return {}

## 現在のフェーズを取得
func get_current_phase() -> String:
	return get_current_step().get("phase", "")

## ターンを進める（外部から呼ばれる）
func advance_turn():
	_current_turn += 1

## 現在のターンを取得
func get_current_turn() -> int:
	return _current_turn
