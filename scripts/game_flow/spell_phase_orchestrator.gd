# SpellPhaseOrchestrator - スペルフェーズのオーケストレーションを担当
extends RefCounted
class_name SpellPhaseOrchestrator

## スペルフェーズのオーケストレーションを担当
## start_spell_phase() と complete_spell_phase() のロジックを集約

var spell_phase_handler = null
var spell_state: SpellStateHandler = null
var cpu_spell_phase_handler = null

signal spell_phase_completed()

func _init(handler, state: SpellStateHandler) -> void:
	"""初期化"""
	spell_phase_handler = handler
	spell_state = state
	# cpu_spell_phase_handler は SpellPhaseHandler の遅延初期化を使用

## ========================================
## フェーズ開始処理
## ========================================

func start_spell_phase(player_id: int) -> void:
	"""スペルフェーズを開始"""
	if not spell_phase_handler or not spell_state:
		push_error("[SpellPhaseOrchestrator] 初期化が不完全")
		return

	# フェーズ状態をリセット
	spell_state.reset_turn_state()
	spell_state.set_current_player_id(player_id)

	# スペルフェーズの初期状態に遷移（reset_turn_state() は INACTIVE に設定するため）
	spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)

	# CPU / 人間プレイヤーで分岐
	var is_cpu = spell_phase_handler and spell_phase_handler.game_flow_manager and spell_phase_handler.game_flow_manager.is_cpu_player(player_id)

	if is_cpu:
		# CPU スペル処理に委譲
		await _delegate_to_cpu_spell_handler(player_id)
	else:
		# 人間プレイヤー向け: UI初期化のみ
		# シグナル駆動で自動的にフェーズが進行（spell_flow.use_spell() or pass_spell()）
		spell_phase_handler._initialize_human_player_ui()

## ========================================
## フェーズ完了処理
## ========================================

func complete_spell_phase() -> void:
	"""スペルフェーズを完了"""
	if not spell_state:
		push_error("[SpellPhaseOrchestrator] spell_state が見つかりません")
		return

	# フェーズ状態を INACTIVE に遷移
	spell_state.transition_to(SpellStateHandler.State.INACTIVE)

	# SpellPhaseHandler のシグナルを発行（GameFlowManager が待っている）
	if spell_phase_handler and spell_phase_handler.spell_phase_completed:
		spell_phase_handler.spell_phase_completed.emit()

	# Orchestrator 自身のシグナルも発行（内部使用）
	spell_phase_completed.emit()

## ========================================
## ヘルパーメソッド
## ========================================

func _delegate_to_cpu_spell_handler(player_id: int) -> void:
	"""CPU スペル処理に委譲"""
	if not spell_phase_handler:
		push_error("[SpellPhaseOrchestrator] spell_phase_handler が見つかりません")
		return

	# SpellPhaseHandler の既存メソッドを直接呼び出し
	await spell_phase_handler._delegate_to_cpu_spell_handler(player_id)

	# SpellEffectExecutor が既に complete_spell_phase() を呼んでいるため、ここでは呼ばない
