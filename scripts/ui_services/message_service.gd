## メッセージ表示サービス
## GlobalCommentUI と PhaseDisplay への委譲を一元管理
extends Node

class_name MessageService

## コンポーネント参照
var _global_comment_ui: GlobalCommentUI = null
var _phase_display: PhaseDisplay = null


## 初期化
func setup(global_comment_ui: GlobalCommentUI, phase_display: PhaseDisplay) -> void:
	_global_comment_ui = global_comment_ui
	_phase_display = phase_display


## ============================================================================
## GlobalCommentUI 委譲メソッド
## ============================================================================

## メッセージを表示して待機
func show_comment_and_wait(message: String, player_id: int = -1, force_click_wait: bool = false) -> void:
	if _global_comment_ui:
		await _global_comment_ui.show_and_wait(message, player_id, force_click_wait)


## 選択肢を表示して結果を返す
func show_choice_and_wait(message: String, player_id: int = -1, yes_text: String = "はい", no_text: String = "いいえ") -> bool:
	if _global_comment_ui:
		return await _global_comment_ui.show_choice_and_wait(message, player_id, yes_text, no_text)
	return false


## コメントメッセージを表示
func show_comment_message(message: String) -> void:
	if _global_comment_ui:
		_global_comment_ui.show_message(message)


## コメントメッセージを非表示
func hide_comment_message() -> void:
	if _global_comment_ui:
		_global_comment_ui.hide_message()


## 通知ポップアップが表示中かチェック
func is_notification_popup_active() -> bool:
	if _global_comment_ui and _global_comment_ui.waiting_for_click:
		return true
	return false


## ============================================================================
## PhaseDisplay 委譲メソッド
## ============================================================================

## フェーズ表示を更新
func update_phase_display(phase) -> void:
	if _phase_display:
		_phase_display.update_phase_display(phase)


## ダイス結果を表示
func show_dice_result(value: int) -> void:
	if _phase_display:
		_phase_display.show_dice_result(value)


## 大きなダイス結果を表示
func show_big_dice_result(value: int, duration: float = 1.5) -> void:
	if _phase_display and _phase_display.has_method("show_big_dice_result"):
		_phase_display.show_big_dice_result(value, duration)


## ダブルダイス結果を表示
func show_dice_result_double(dice1: int, dice2: int, total: int) -> void:
	if _phase_display and _phase_display.has_method("show_dice_result_double"):
		_phase_display.show_dice_result_double(dice1, dice2, total)


## トリプルダイス結果を表示
func show_dice_result_triple(dice1: int, dice2: int, dice3: int, total: int) -> void:
	if _phase_display and _phase_display.has_method("show_dice_result_triple"):
		_phase_display.show_dice_result_triple(dice1, dice2, dice3, total)


## ダイス範囲結果を表示
func show_dice_result_range(curse_name: String, value: int) -> void:
	if _phase_display and _phase_display.has_method("show_dice_result_range"):
		_phase_display.show_dice_result_range(curse_name, value)


## トースト通知を表示
func show_toast(message: String, duration: float = 2.0) -> void:
	if _phase_display:
		_phase_display.show_toast(message, duration)


## アクションプロンプトを表示
func show_action_prompt(message: String, position: String = "center") -> void:
	if _phase_display:
		_phase_display.show_action_prompt(message, position)


## アクションプロンプトを非表示
func hide_action_prompt() -> void:
	if _phase_display:
		_phase_display.hide_action_prompt()


## フェーズテキストを設定
func set_phase_text(text: String) -> void:
	if _phase_display and _phase_display.phase_label:
		_phase_display.phase_label.text = text


## フェーズテキストを取得
func get_phase_text() -> String:
	if _phase_display and _phase_display.phase_label:
		return _phase_display.phase_label.text
	return ""
