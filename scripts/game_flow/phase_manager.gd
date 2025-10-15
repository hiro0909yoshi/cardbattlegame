# PhaseManager - ゲームフェーズの状態管理を担当
extends Node
class_name PhaseManager

## ゲームフェーズの定義
enum GamePhase {
	NONE,                  # 初期状態
	SPELL,                 # スペルフェーズ
	DICE,                  # ダイスフェーズ
	MOVE,                  # 移動フェーズ
	SUMMON,                # 召喚フェーズ（デフォルト画面）
	LAND_COMMAND,          # 領地コマンドフェーズ
	BATTLE_PREPARATION,    # バトル準備フェーズ（アイテム選択）
	BATTLE,                # バトルフェーズ
	TURN_END              # ターン終了フェーズ
}

## フェーズ遷移の定義（どのフェーズから何へ遷移可能か）
const VALID_TRANSITIONS = {
	GamePhase.NONE: [GamePhase.SPELL],
	GamePhase.SPELL: [GamePhase.DICE],
	GamePhase.DICE: [GamePhase.MOVE, GamePhase.SUMMON],
	GamePhase.MOVE: [GamePhase.SUMMON, GamePhase.BATTLE_PREPARATION],
	GamePhase.SUMMON: [GamePhase.LAND_COMMAND, GamePhase.BATTLE_PREPARATION, GamePhase.TURN_END],
	GamePhase.LAND_COMMAND: [GamePhase.SUMMON, GamePhase.BATTLE_PREPARATION, GamePhase.TURN_END],
	GamePhase.BATTLE_PREPARATION: [GamePhase.BATTLE],
	GamePhase.BATTLE: [GamePhase.TURN_END, GamePhase.SUMMON],
	GamePhase.TURN_END: [GamePhase.SPELL]
}

## 現在のフェーズ
var current_phase: GamePhase = GamePhase.NONE
var previous_phase: GamePhase = GamePhase.NONE

## フェーズ履歴（デバッグ用）
var phase_history: Array = []
var max_history_size: int = 20

## シグナル
signal phase_changed(new_phase: GamePhase, old_phase: GamePhase)
signal phase_transition_failed(attempted_phase: GamePhase, reason: String)

func _ready():
	print("[PhaseManager] 初期化完了")

## フェーズ変更（バリデーション付き）
func change_phase(new_phase: GamePhase) -> bool:
	if not is_transition_valid(current_phase, new_phase):
		var reason = "不正な遷移: %s → %s" % [
			GamePhase.keys()[current_phase],
			GamePhase.keys()[new_phase]
		]
		phase_transition_failed.emit(new_phase, reason)
		push_warning(reason)
		return false
	
	# フェーズ変更を実行
	previous_phase = current_phase
	current_phase = new_phase
	
	# 履歴に追加
	add_to_history(new_phase)
	
	# シグナル発行
	phase_changed.emit(new_phase, previous_phase)
	
	print("[PhaseManager] フェーズ変更: %s → %s" % [
		GamePhase.keys()[previous_phase],
		GamePhase.keys()[new_phase]
	])
	
	return true

## 遷移が有効かチェック
func is_transition_valid(from_phase: GamePhase, to_phase: GamePhase) -> bool:
	if from_phase not in VALID_TRANSITIONS:
		return false
	return to_phase in VALID_TRANSITIONS[from_phase]

## 履歴に追加
func add_to_history(phase: GamePhase):
	phase_history.append({
		"phase": phase,
		"timestamp": Time.get_ticks_msec()
	})
	
	# 履歴サイズ制限
	if phase_history.size() > max_history_size:
		phase_history.pop_front()

## 現在のフェーズ名を取得
func get_current_phase_name() -> String:
	return GamePhase.keys()[current_phase]

## フェーズ履歴を取得（デバッグ用）
func get_phase_history() -> Array:
	return phase_history.duplicate()

## フェーズをリセット
func reset():
	current_phase = GamePhase.NONE
	previous_phase = GamePhase.NONE
	phase_history.clear()
	print("[PhaseManager] リセット完了")
