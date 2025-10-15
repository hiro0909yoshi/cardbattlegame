# SpellPhaseHandler - スペルフェーズの処理を担当
extends Node
class_name SpellPhaseHandler

## シグナル
signal spell_phase_started()
signal spell_phase_completed()
signal spell_passed()

## 状態
var is_active: bool = false
var current_player_id: int = -1

## 参照
var ui_manager = null
var game_flow_manager = null

func _ready():
	pass

## 初期化
func initialize(ui_mgr, flow_mgr):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if is_active:
		print("[SpellPhaseHandler] 既にアクティブです")
		return
	
	is_active = true
	current_player_id = player_id
	spell_phase_started.emit()
	
	print("[SpellPhaseHandler] スペルフェーズ開始: プレイヤー ", player_id + 1)
	
	# Phase 1-Aではパス処理のみ実装
	# 将来的にスペルカード選択UIを表示
	auto_pass()

## 自動パス（Phase 1-A用）
func auto_pass():
	print("[SpellPhaseHandler] スペルフェーズをパスします")
	await get_tree().create_timer(0.5).timeout
	complete_spell_phase()

## スペルフェーズ完了
func complete_spell_phase():
	if not is_active:
		return
	
	is_active = false
	spell_phase_completed.emit()
	
	print("[SpellPhaseHandler] スペルフェーズ完了")
	
	# 次のフェーズ（ダイスフェーズ）への遷移は game_flow_manager が行う

## スペルをパス
func pass_spell():
	spell_passed.emit()
	complete_spell_phase()

## アクティブか
func is_spell_phase_active() -> bool:
	return is_active
