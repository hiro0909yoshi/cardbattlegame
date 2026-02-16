## SpellUIManager - スペルフェーズUI管理システム
##
## Phase 5-1: UI制御を集約し、SpellPhaseHandler からUI参照削除の準備
## 責務: スペル選択UI、ナビゲーション、カメラ制御、ボタン管理を統一管理
##
## 初期化パターン: GameSystemManager._initialize_spell_phase_subsystems() で作成
## 削減効果: SpellPhaseHandler から UI相関メソッド 5-6個削減準備

extends Node
class_name SpellUIManager

# === 参照 ===
var _spell_phase_handler = null
var _ui_manager = null
var _spell_navigation_controller = null
var _spell_confirmation_handler = null
var _spell_ui_controller = null

# === 初期化 ===
func setup(
	spell_phase_handler,
	ui_manager,
	spell_navigation_controller,
	spell_confirmation_handler,
	spell_ui_controller
) -> void:
	"""UI管理システムを初期化

	Args:
		spell_phase_handler: SpellPhaseHandler への参照
		ui_manager: UIManager への参照
		spell_navigation_controller: ナビゲーションコントローラー
		spell_confirmation_handler: 確認ハンドラー
		spell_ui_controller: UI制御ハンドラー
	"""
	_spell_phase_handler = spell_phase_handler
	_ui_manager = ui_manager
	_spell_navigation_controller = spell_navigation_controller
	_spell_confirmation_handler = spell_confirmation_handler
	_spell_ui_controller = spell_ui_controller

	# 初期化検証
	if not _spell_phase_handler:
		push_error("[SpellUIManager] spell_phase_handler が null です")
	if not _ui_manager:
		push_error("[SpellUIManager] ui_manager が null です")
	if not _spell_navigation_controller:
		push_error("[SpellUIManager] spell_navigation_controller が null です")
	if not _spell_confirmation_handler:
		push_error("[SpellUIManager] spell_confirmation_handler が null です")
	if not _spell_ui_controller:
		push_error("[SpellUIManager] spell_ui_controller が null です")


# === UI初期化 ===

func initialize_spell_phase_ui() -> void:
	"""スペルフェーズUIを初期化（SpellPhaseUIManager作成）"""
	if not _spell_ui_controller:
		push_error("[SpellUIManager] spell_ui_controller が初期化されていません")
		return

	if not _spell_ui_controller.has_method("initialize_spell_phase_ui"):
		push_error("[SpellUIManager] spell_ui_controller に initialize_spell_phase_ui メソッドがありません")
		return

	_spell_ui_controller.initialize_spell_phase_ui()


func initialize_spell_cast_notification_ui() -> void:
	"""スペル発動通知UIを初期化"""
	if not _spell_confirmation_handler:
		push_error("[SpellUIManager] spell_confirmation_handler が初期化されていません")
		return

	if not _spell_confirmation_handler.has_method("initialize_spell_cast_notification_ui"):
		push_error("[SpellUIManager] spell_confirmation_handler に initialize_spell_cast_notification_ui メソッドがありません")
		return

	_spell_confirmation_handler.initialize_spell_cast_notification_ui()

# === UI表示制御 ===

func show_spell_selection_ui(hand_data: Array, magic_power: int) -> void:
	"""スペル選択UIを表示"""
	if not _ui_manager:
		push_error("[SpellUIManager] ui_manager が見つかりません")
		return

	if not _spell_ui_controller:
		push_error("[SpellUIManager] spell_ui_controller が見つかりません")
		return

	_spell_ui_controller.show_spell_selection_ui(hand_data, magic_power)


func hide_spell_selection_ui() -> void:
	"""スペル選択UIを非表示"""
	if not _ui_manager or not _ui_manager.card_selection_ui:
		return

	if _ui_manager.card_selection_ui.has_method("hide_selection"):
		_ui_manager.card_selection_ui.hide_selection()


func update_spell_phase_ui() -> void:
	"""スペルフェーズUIを更新"""
	if not _spell_ui_controller:
		push_error("[SpellUIManager] spell_ui_controller が初期化されていません")
		return

	if not _spell_ui_controller.has_method("update_spell_phase_ui"):
		return

	_spell_ui_controller.update_spell_phase_ui()


func return_camera_to_player() -> void:
	"""カメラをプレイヤーに戻す"""
	if not _spell_ui_controller:
		push_error("[SpellUIManager] spell_ui_controller が初期化されていません")
		return

	if not _spell_ui_controller.has_method("return_camera_to_player"):
		return

	_spell_ui_controller.return_camera_to_player()


# === ボタン管理 ===

func show_spell_phase_buttons() -> void:
	"""スペルフェーズボタンを表示

	アルカナアーツなどの選択肢を表示
	"""
	if not _spell_ui_controller:
		push_error("[SpellUIManager] spell_ui_controller が初期化されていません")
		return

	if not _spell_ui_controller.has_method("show_spell_phase_buttons"):
		return

	_spell_ui_controller.show_spell_phase_buttons()


func hide_spell_phase_buttons() -> void:
	"""スペルフェーズボタンを非表示"""
	if not _spell_ui_controller:
		push_error("[SpellUIManager] spell_ui_controller が初期化されていません")
		return

	if not _spell_ui_controller.has_method("hide_spell_phase_buttons"):
		return

	_spell_ui_controller.hide_spell_phase_buttons()


# === ナビゲーション連携 ===

func restore_navigation() -> void:
	"""ナビゲーション状態を復帰"""
	if not _spell_navigation_controller:
		push_error("[SpellUIManager] spell_navigation_controller が初期化されていません")
		return

	if not _spell_navigation_controller.has_method("restore_navigation"):
		push_error("[SpellUIManager] spell_navigation_controller に restore_navigation メソッドがありません")
		return

	_spell_navigation_controller.restore_navigation()


func update_navigation_ui() -> void:
	"""ナビゲーションUIを更新"""
	if not _spell_navigation_controller:
		push_error("[SpellUIManager] spell_navigation_controller が初期化されていません")
		return

	if not _spell_navigation_controller.has_method("restore_navigation_for_state"):
		return

	_spell_navigation_controller.restore_navigation_for_state()


# === スペル確認ハンドラー連携 ===

func show_spell_confirmation(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool = false):
	"""スペル発動確認を表示（クリック待ち）"""
	if not _spell_confirmation_handler:
		push_error("[SpellUIManager] spell_confirmation_handler が初期化されていません")
		return

	if not _spell_confirmation_handler.has_method("show_spell_cast_notification"):
		push_error("[SpellUIManager] spell_confirmation_handler に show_spell_cast_notification メソッドがありません")
		return

	await _spell_confirmation_handler.show_spell_cast_notification(caster_name, target_data, spell_or_mystic, is_mystic)


func hide_spell_confirmation() -> void:
	"""スペル発動確認を非表示"""
	if not _spell_confirmation_handler:
		push_error("[SpellUIManager] spell_confirmation_handler が初期化されていません")
		return

	if not _spell_confirmation_handler.has_method("clear_spell_cast_notification"):
		return

	_spell_confirmation_handler.clear_spell_cast_notification()


# === 検証メソッド ===

func is_valid() -> bool:
	"""初期化状態を確認

	Returns:
		すべての参照が正常に初期化されている場合は true
	"""
	return (
		_spell_phase_handler != null and
		_ui_manager != null and
		_spell_navigation_controller != null and
		_spell_confirmation_handler != null and
		_spell_ui_controller != null
	)

# === ヘルパーメソッド ===

func _get_current_player_id() -> int:
	"""現在のプレイヤーIDを取得

	Returns:
		現在のプレイヤーID、取得失敗時は -1
	"""
	if not _spell_phase_handler:
		return -1

	# SpellPhaseHandler の spell_state を経由して取得
	if _spell_phase_handler.has_method("get_current_player_id"):
		return _spell_phase_handler.get_current_player_id()

	# spell_state から直接取得
	if _spell_phase_handler.get("spell_state"):
		var spell_state = _spell_phase_handler.spell_state
		if spell_state and spell_state.has_method("get_current_player_id"):
			return spell_state.get_current_player_id()
		if spell_state and spell_state.get("current_player_id"):
			return spell_state.current_player_id

	# GameFlowManager 経由で取得
	if _spell_phase_handler.get("game_flow_manager"):
		var gfm = _spell_phase_handler.game_flow_manager
		if gfm and gfm.has_method("get_current_player_id"):
			return gfm.get_current_player_id()

	return -1


# === Signal接続（Phase 6-A: UI層分離） ===

## SpellFlowHandler と MysticArtsHandler の UI Signal を接続
func connect_spell_flow_signals(spell_flow_handler) -> void:
	"""SpellFlowHandler の UI Signal を接続"""
	if not spell_flow_handler:
		push_error("[SpellUIManager] spell_flow_handler が null です")
		return

	var sfh = spell_flow_handler
	if not sfh.spell_ui_toast_requested.is_connected(_on_spell_ui_toast_requested):
		sfh.spell_ui_toast_requested.connect(_on_spell_ui_toast_requested)
	if not sfh.spell_ui_action_prompt_shown.is_connected(_on_spell_ui_action_prompt_shown):
		sfh.spell_ui_action_prompt_shown.connect(_on_spell_ui_action_prompt_shown)
	if not sfh.spell_ui_action_prompt_hidden.is_connected(_on_spell_ui_action_prompt_hidden):
		sfh.spell_ui_action_prompt_hidden.connect(_on_spell_ui_action_prompt_hidden)
	if not sfh.spell_ui_info_panels_hidden.is_connected(_on_spell_ui_info_panels_hidden):
		sfh.spell_ui_info_panels_hidden.connect(_on_spell_ui_info_panels_hidden)
	if not sfh.spell_ui_card_pending_cleared.is_connected(_on_spell_ui_card_pending_cleared):
		sfh.spell_ui_card_pending_cleared.connect(_on_spell_ui_card_pending_cleared)
	if not sfh.spell_ui_navigation_enabled.is_connected(_on_spell_ui_navigation_enabled):
		sfh.spell_ui_navigation_enabled.connect(_on_spell_ui_navigation_enabled)
	if not sfh.spell_ui_navigation_disabled.is_connected(_on_spell_ui_navigation_disabled):
		sfh.spell_ui_navigation_disabled.connect(_on_spell_ui_navigation_disabled)
	if not sfh.spell_ui_actions_cleared.is_connected(_on_spell_ui_actions_cleared):
		sfh.spell_ui_actions_cleared.connect(_on_spell_ui_actions_cleared)
	if not sfh.spell_ui_card_filter_set.is_connected(_on_spell_ui_card_filter_set):
		sfh.spell_ui_card_filter_set.connect(_on_spell_ui_card_filter_set)
	if not sfh.spell_ui_hand_updated.is_connected(_on_spell_ui_hand_updated):
		sfh.spell_ui_hand_updated.connect(_on_spell_ui_hand_updated)
	if not sfh.spell_ui_card_selection_deactivated.is_connected(_on_spell_ui_card_selection_deactivated):
		sfh.spell_ui_card_selection_deactivated.connect(_on_spell_ui_card_selection_deactivated)


func connect_mystic_arts_signals(mystic_arts_handler) -> void:
	"""MysticArtsHandler の UI Signal を接続"""
	if not mystic_arts_handler:
		push_error("[SpellUIManager] mystic_arts_handler が null です")
		return

	var mah = mystic_arts_handler
	if not mah.mystic_ui_toast_requested.is_connected(_on_mystic_ui_toast_requested):
		mah.mystic_ui_toast_requested.connect(_on_mystic_ui_toast_requested)
	if not mah.mystic_ui_button_shown.is_connected(_on_mystic_ui_button_shown):
		mah.mystic_ui_button_shown.connect(_on_mystic_ui_button_shown)
	if not mah.mystic_ui_button_hidden.is_connected(_on_mystic_ui_button_hidden):
		mah.mystic_ui_button_hidden.connect(_on_mystic_ui_button_hidden)
	if not mah.mystic_ui_navigation_disabled.is_connected(_on_mystic_ui_navigation_disabled):
		mah.mystic_ui_navigation_disabled.connect(_on_mystic_ui_navigation_disabled)
	if not mah.mystic_ui_action_prompt_shown.is_connected(_on_mystic_ui_action_prompt_shown):
		mah.mystic_ui_action_prompt_shown.connect(_on_mystic_ui_action_prompt_shown)

# === SpellFlowHandler Signal Listeners ===

func _on_spell_ui_toast_requested(message: String) -> void:
	if _ui_manager and _ui_manager.phase_display:
		_ui_manager.show_toast(message)

func _on_spell_ui_action_prompt_shown(text: String) -> void:
	if _ui_manager and _ui_manager.phase_display:
		_ui_manager.show_action_prompt(text)

func _on_spell_ui_action_prompt_hidden() -> void:
	if _ui_manager and _ui_manager.phase_display:
		_ui_manager.hide_action_prompt()

func _on_spell_ui_info_panels_hidden() -> void:
	if _ui_manager:
		_ui_manager.hide_all_info_panels()

func _on_spell_ui_card_pending_cleared() -> void:
	if _ui_manager and _ui_manager.card_selection_ui:
		_ui_manager.card_selection_ui.pending_card_index = -1

func _on_spell_ui_navigation_enabled(confirm_cb: Callable, back_cb: Callable) -> void:
	if _ui_manager:
		_ui_manager.enable_navigation(confirm_cb, back_cb)

func _on_spell_ui_navigation_disabled() -> void:
	if _ui_manager:
		_ui_manager.disable_navigation()

func _on_spell_ui_actions_cleared() -> void:
	if _ui_manager:
		_ui_manager.clear_confirm_action()
		_ui_manager.clear_back_action()
		_ui_manager.clear_arrow_actions()

func _on_spell_ui_card_filter_set(filter: String) -> void:
	if _ui_manager:
		_ui_manager.card_selection_filter = filter

func _on_spell_ui_hand_updated(player_id: int) -> void:
	if _ui_manager and _ui_manager.hand_display:
		_ui_manager.hand_display.update_hand_display(player_id)

func _on_spell_ui_card_selection_deactivated() -> void:
	if _ui_manager and _ui_manager.card_selection_ui and _ui_manager.card_selection_ui.is_active:
		if _ui_manager.card_selection_ui.selection_mode == "spell":
			_ui_manager.card_selection_ui.deactivate()

# === MysticArtsHandler Signal Listeners ===

func _on_mystic_ui_toast_requested(message: String) -> void:
	if _ui_manager and _ui_manager.phase_display:
		_ui_manager.show_toast(message)

func _on_mystic_ui_button_shown(callback: Callable) -> void:
	if _ui_manager:
		_ui_manager.show_mystic_button(callback)

func _on_mystic_ui_button_hidden() -> void:
	if _ui_manager:
		_ui_manager.hide_mystic_button()

func _on_mystic_ui_navigation_disabled() -> void:
	if _ui_manager:
		_ui_manager.disable_navigation()

func _on_mystic_ui_action_prompt_shown(message: String) -> void:
	if _ui_manager and _ui_manager.phase_display:
		_ui_manager.show_action_prompt(message)

# === デバッグメソッド ===

func debug_print_status() -> void:
	"""デバッグ情報を出力"""
	var status = "[SpellUIManager] Status:\n"
	status += "  - spell_phase_handler: %s\n" % ("OK" if _spell_phase_handler else "NULL")
	status += "  - ui_manager: %s\n" % ("OK" if _ui_manager else "NULL")
	status += "  - spell_navigation_controller: %s\n" % ("OK" if _spell_navigation_controller else "NULL")
	status += "  - spell_confirmation_handler: %s\n" % ("OK" if _spell_confirmation_handler else "NULL")
	status += "  - spell_ui_controller: %s\n" % ("OK" if _spell_ui_controller else "NULL")
	status += "  - is_valid(): %s" % ("✓ 初期化完了" if is_valid() else "✗ 未初期化")

	print(status)
