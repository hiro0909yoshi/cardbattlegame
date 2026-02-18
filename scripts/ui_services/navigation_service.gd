## NavigationService
## UIManager から GlobalActionButtons のナビゲーション状態管理を抽出したサービスクラス
## ナビゲーションボタンの設定・保存・復元を一元管理する
extends Node
class_name NavigationService

## コンポーネント参照
var _global_action_buttons: GlobalActionButtons = null

## 入力ロック解除コールバック（GFM.unlock_input の代替）
var _unlock_input_callback: Callable = Callable()

## 後方互換API用のコールバック変数
var _compat_confirm_cb: Callable = Callable()
var _compat_back_cb: Callable = Callable()
var _compat_up_cb: Callable = Callable()
var _compat_down_cb: Callable = Callable()

## インフォパネル閲覧モード中のナビゲーション保存/復元
var _saved_nav_confirm: Callable = Callable()
var _saved_nav_back: Callable = Callable()
var _saved_nav_up: Callable = Callable()
var _saved_nav_down: Callable = Callable()
var _saved_nav_special_cb: Callable = Callable()
var _saved_nav_special_text: String = ""
var _saved_nav_phase_comment: String = ""
var _nav_state_saved: bool = false

## インフォパネルの×ボタンロック状態（enable_navigation/disable_navigationの上書きを防止）
var _info_panel_back_locked: bool = false


## 初期化
## global_action_buttons: GlobalActionButtons コンポーネント
## unlock_input_callback: 入力ロック解除時に呼ばれるコールバック
func setup(global_action_buttons: GlobalActionButtons, unlock_input_callback: Callable = Callable()) -> void:
	_global_action_buttons = global_action_buttons
	_unlock_input_callback = unlock_input_callback


## インフォパネルの×ボタンを保護（enable_navigation等による上書きを防止）
func lock_info_panel_back() -> void:
	_info_panel_back_locked = true


## インフォパネルの×ボタン保護を解除
func unlock_info_panel_back() -> void:
	_info_panel_back_locked = false


## ナビゲーションボタンを設定
## 入力待ち状態になったのでロック解除
## 新しいナビゲーション設定時は前の保存状態を無効化
func enable_navigation(confirm_cb: Callable = Callable(), back_cb: Callable = Callable(), up_cb: Callable = Callable(), down_cb: Callable = Callable()) -> void:
	if _unlock_input_callback.is_valid():
		_unlock_input_callback.call()
	if _info_panel_back_locked:
		return
	_nav_state_saved = false
	_compat_confirm_cb = confirm_cb
	_compat_back_cb = back_cb
	_compat_up_cb = up_cb
	_compat_down_cb = down_cb
	if _global_action_buttons:
		_global_action_buttons.setup(confirm_cb, back_cb, up_cb, down_cb)


## ナビゲーションボタンを全てクリア
func disable_navigation() -> void:
	if _info_panel_back_locked:
		return
	_compat_confirm_cb = Callable()
	_compat_back_cb = Callable()
	_compat_up_cb = Callable()
	_compat_down_cb = Callable()
	if _global_action_buttons:
		_global_action_buttons.clear_all()


## ナビゲーション状態が保存されているか
func is_nav_state_saved() -> bool:
	return _nav_state_saved


## 現在のナビゲーション状態を保存（閲覧モード用）
## 既に保存済みの場合は上書きしない（連続閲覧対応）
## コールバックが全て空の場合は保存しない（restore_current_phase のフォールバックを使う）
func save_navigation_state() -> void:
	if _nav_state_saved:
		return
	# tile_tapped → creature_tapped 連続処理時、tile_tapped でコールバックがクリアされた
	# 空の状態を保存すると restore 時にボタンが全消滅するため、保存をスキップ
	if not _compat_confirm_cb.is_valid() and not _compat_back_cb.is_valid() \
		and not _compat_up_cb.is_valid() and not _compat_down_cb.is_valid():
		return
	_saved_nav_confirm = _compat_confirm_cb
	_saved_nav_back = _compat_back_cb
	_saved_nav_up = _compat_up_cb
	_saved_nav_down = _compat_down_cb
	# special_button状態を保存
	if _global_action_buttons:
		_saved_nav_special_cb = _global_action_buttons.special_callback
		_saved_nav_special_text = _global_action_buttons.special_text
	_nav_state_saved = true
	# 特殊ボタンをクリア
	clear_special_button()


## 注意: phase_comment の保存は MessageService 側で管理するため、外部から設定
func set_saved_phase_comment(comment: String) -> void:
	_saved_nav_phase_comment = comment


## 保存されたフェーズコメントを取得
func get_saved_phase_comment() -> String:
	return _saved_nav_phase_comment


## 保存したナビゲーション状態を復元
func restore_navigation_state() -> void:
	if not _nav_state_saved:
		return
	_compat_confirm_cb = _saved_nav_confirm
	_compat_back_cb = _saved_nav_back
	_compat_up_cb = _saved_nav_up
	_compat_down_cb = _saved_nav_down
	_nav_state_saved = false
	_info_panel_back_locked = false
	_update_compat_buttons()
	# special_button状態を復元
	if _global_action_buttons:
		if _saved_nav_special_cb.is_valid():
			_global_action_buttons.setup_special(_saved_nav_special_text, _saved_nav_special_cb)
		else:
			_global_action_buttons.clear_special()
	# 入力ロックを解除
	if _unlock_input_callback.is_valid():
		_unlock_input_callback.call()


## ナビゲーション保存状態をクリア
func clear_navigation_saved_state() -> void:
	_nav_state_saved = false
	_info_panel_back_locked = false


## [後方互換] スペルフェーズ中のインフォパネル閉じ後にボタンを復元
func restore_spell_phase_buttons() -> void:
	restore_navigation_state()


func _update_compat_buttons() -> void:
	if _global_action_buttons:
		_global_action_buttons.setup(_compat_confirm_cb, _compat_back_cb, _compat_up_cb, _compat_down_cb)


## Confirm アクションを登録
func register_confirm_action(callback: Callable, _text: String = "") -> void:
	if _unlock_input_callback.is_valid():
		_unlock_input_callback.call()
	_compat_confirm_cb = callback
	_update_compat_buttons()


## Back アクションを登録
func register_back_action(callback: Callable, _text: String = "") -> void:
	if _unlock_input_callback.is_valid():
		_unlock_input_callback.call()
	_compat_back_cb = callback
	_update_compat_buttons()


## 矢印キーアクションを登録
func register_arrow_actions(up_callback: Callable, down_callback: Callable) -> void:
	if _unlock_input_callback.is_valid():
		_unlock_input_callback.call()
	_compat_up_cb = up_callback
	_compat_down_cb = down_callback
	_update_compat_buttons()


## Confirm アクションをクリア
func clear_confirm_action() -> void:
	_compat_confirm_cb = Callable()
	_update_compat_buttons()


## Back アクションをクリア
func clear_back_action() -> void:
	_compat_back_cb = Callable()
	_update_compat_buttons()


## 矢印キーアクションをクリア
func clear_arrow_actions() -> void:
	_compat_up_cb = Callable()
	_compat_down_cb = Callable()
	_update_compat_buttons()


## グローバルアクションをすべてクリア
func clear_global_actions() -> void:
	_compat_confirm_cb = Callable()
	_compat_back_cb = Callable()
	_compat_up_cb = Callable()
	_compat_down_cb = Callable()
	if _global_action_buttons:
		_global_action_buttons.clear_all()


## 特殊ボタンを設定
func set_special_button(text: String, callback: Callable) -> void:
	if _global_action_buttons:
		_global_action_buttons.setup_special(text, callback)


## 特殊ボタンをクリア
func clear_special_button() -> void:
	if _global_action_buttons:
		_global_action_buttons.clear_special()


## グローバルアクション（Confirm + Back）を登録
func register_global_actions(confirm_callback: Callable, back_callback: Callable, _confirm_text: String = "", _back_text: String = "") -> void:
	if _unlock_input_callback.is_valid():
		_unlock_input_callback.call()
	_compat_confirm_cb = confirm_callback
	_compat_back_cb = back_callback
	_update_compat_buttons()
