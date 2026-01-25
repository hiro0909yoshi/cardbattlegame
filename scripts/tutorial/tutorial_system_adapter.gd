extends Node
class_name TutorialSystemAdapter
## 新チュートリアルシステムと既存システムの橋渡し
## 既存のTutorialManagerと同じインターフェースを提供

signal tutorial_started
signal tutorial_ended
signal step_changed(step_id: int)
signal message_shown(message: String)

# 新システムのコントローラー
var controller: TutorialController = null

# 互換性のためのプロパティ
var is_active: bool:
	get: return controller.is_active() if controller else false

var current_step: int:
	get: return controller.get_current_step().get("id", 0) if controller else 0

var current_turn: int:
	get: return controller.get_current_turn() if controller else 1

# 旧システムとの互換性用
var tutorial_popup:
	get: return controller.ui._popup if controller and controller.ui else null

var tutorial_overlay:
	get: return controller.highlighter._overlay if controller and controller.highlighter else null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_controller()

func _create_controller():
	controller = TutorialController.new()
	controller.name = "TutorialController"
	add_child(controller)
	
	# シグナル転送
	controller.tutorial_started.connect(func(_stage_id): tutorial_started.emit())
	controller.tutorial_completed.connect(func(_stage_id): tutorial_ended.emit())
	controller.step_started.connect(func(step): 
		step_changed.emit(step.get("id", 0))
		var msg = step.get("message", "")
		if msg != "":
			message_shown.emit(msg)
	)

## system_managerから初期化（既存互換）
func initialize_with_systems(system_manager):
	if controller:
		controller.setup_systems(system_manager)

## チュートリアル開始（既存互換）
func start_tutorial():
	if not controller:
		return
	
	# ステージ1をロード
	if controller.load_stage("res://data/tutorial/tutorial_stage1.json"):
		controller.start()

## チュートリアル終了（既存互換）
func end_tutorial():
	if controller:
		controller.stop()

## 現在のフェーズを取得（既存互換）
func is_phase(phase_name: String) -> bool:
	if not controller:
		return false
	return controller.get_current_phase() == phase_name

## 現在のステップを取得（既存互換）
func get_current_step() -> Dictionary:
	if not controller:
		return {}
	return controller.get_current_step()

## ターンを進める（既存互換）
func advance_turn():
	if controller:
		controller.advance_turn()
