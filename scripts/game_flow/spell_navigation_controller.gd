# SpellNavigationController - スペルフェーズのナビゲーション・UI管理
extends RefCounted
class_name SpellNavigationController

## スペルフェーズのナビゲーション・UI管理を担当
##
## 責務:
## - ナビゲーション状態の復元（フェーズ別）
## - ナビゲーション設定（選択、ターゲット、確認）
## - ナビゲーション入力ハンドラー
## - UI表示/非表示の切り替え

var _spell_phase_handler
var _ui_manager
var _spell_ui_controller
var _spell_target_selection_handler
var _spell_state

## 初期化
func setup(sph, ui_mgr, spell_ui_ctrl, target_sel_handler, spell_state) -> void:
	_spell_phase_handler = sph
	_ui_manager = ui_mgr
	_spell_ui_controller = spell_ui_ctrl
	_spell_target_selection_handler = target_sel_handler
	_spell_state = spell_state

# =============================================================================
# ナビゲーション復元メソッド
# =============================================================================

## ナビゲーション復元（アルカナアーツ判定を含む）
func restore_navigation() -> void:
	if not _ui_manager:
		return

	# アルカナアーツがアクティブなら優先委譲
	if _spell_phase_handler and _spell_phase_handler.spell_mystic_arts and _spell_phase_handler.spell_mystic_arts.is_active():
		_spell_phase_handler.spell_mystic_arts.restore_navigation()
		return

	restore_navigation_for_state()

## state別のナビゲーション復元（アルカナアーツ判定をスキップ）
## spell_mystic_arts.restore_navigation()からの再帰呼び出し時に使用
func restore_navigation_for_state() -> void:
	if not _ui_manager or not _spell_state:
		return

	match _spell_state.current_state:
		SpellStateHandler.State.WAITING_FOR_INPUT:
			_setup_spell_selection_navigation()
			_show_spell_phase_buttons()
			if _ui_manager.phase_display:
				_ui_manager.show_action_prompt("スペルを使用するか、ダイスを振ってください")

		SpellStateHandler.State.SELECTING_TARGET:
			_setup_target_selection_navigation()
			if _ui_manager.phase_display:
				_ui_manager.show_action_prompt("対象を選択してください")

		SpellStateHandler.State.CONFIRMING_EFFECT:
			_ui_manager.enable_navigation(
				func(): _confirm_spell_effect(),
				func(): _cancel_confirmation()
			)

# =============================================================================
# ナビゲーション設定メソッド
# =============================================================================

## スペル選択時のナビゲーション設定（決定 = スペルを使わない → サイコロ）
func _setup_spell_selection_navigation() -> void:
	if _ui_manager:
		_ui_manager.enable_navigation(
			func(): _pass_spell(),  # 決定 = スペルを使わない → サイコロを振る
			Callable()              # 戻るなし
		)

## ナビゲーション設定（ターゲット選択）
func _setup_target_selection_navigation() -> void:
	print("[SpellNav-DEBUG] _setup_target_selection_navigation() 開始")

	if _spell_target_selection_handler:
		_spell_target_selection_handler._setup_target_selection_navigation()
	elif _ui_manager:
		print("[SpellNav-DEBUG] enable_navigation() 呼び出し直前:")
		print("  ui_manager: %s" % ("✓" if _ui_manager else "✗"))
		_ui_manager.enable_navigation(
			func(): _on_target_confirm(),
			func(): _on_target_cancel(),
			func(): _on_target_prev(),
			func(): _on_target_next()
		)
		print("[SpellNav-DEBUG] enable_navigation() 呼び出し後:")
		print("  on_confirm: %s" % ("✓" if _ui_manager._compat_confirm_cb.is_valid() else "✗"))
		print("  on_cancel: %s" % ("✓" if _ui_manager._compat_back_cb.is_valid() else "✗"))
		print("  on_prev: %s" % ("✓" if _ui_manager._compat_up_cb.is_valid() else "✗"))
		print("  on_next: %s" % ("✓" if _ui_manager._compat_down_cb.is_valid() else "✗"))

	print("[SpellNav-DEBUG] _setup_target_selection_navigation() 完了")

## ナビゲーション設定解除
func _clear_spell_navigation() -> void:
	if _spell_target_selection_handler:
		_spell_target_selection_handler._clear_spell_navigation()
	elif _ui_manager:
		_ui_manager.disable_navigation()

# =============================================================================
# UI表示/非表示メソッド
# =============================================================================

## UI初期化
func _initialize_spell_phase_ui() -> void:
	if _spell_ui_controller:
		_spell_ui_controller.initialize_spell_phase_ui()

## スペルフェーズボタン表示
func _show_spell_phase_buttons() -> void:
	if _spell_ui_controller:
		_spell_ui_controller.show_spell_phase_buttons()

## スペルフェーズボタン非表示
func _hide_spell_phase_buttons() -> void:
	if _spell_ui_controller:
		_spell_ui_controller.hide_spell_phase_buttons()

# =============================================================================
# ナビゲーション入力ハンドラー
# =============================================================================

## スペル使用スキップ（ダイス移動へ）
func _pass_spell() -> void:
	if _spell_phase_handler and _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow.pass_spell()

## ターゲット確認
func _on_target_confirm() -> void:
	if _spell_target_selection_handler:
		_spell_target_selection_handler._on_target_confirm()

## ターゲット選択キャンセル
func _on_target_cancel() -> void:
	if _spell_target_selection_handler:
		_spell_target_selection_handler._on_target_cancel()

## ターゲット選択前へ
func _on_target_prev() -> void:
	if _spell_target_selection_handler:
		_spell_target_selection_handler._on_target_prev()

## ターゲット選択次へ
func _on_target_next() -> void:
	if _spell_target_selection_handler:
		_spell_target_selection_handler._on_target_next()

## スペル効果確認
func _confirm_spell_effect() -> void:
	if _spell_phase_handler and _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow._confirm_spell_effect()

## スペル確認キャンセル
func _cancel_confirmation() -> void:
	if _spell_phase_handler and _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow._cancel_confirmation()
