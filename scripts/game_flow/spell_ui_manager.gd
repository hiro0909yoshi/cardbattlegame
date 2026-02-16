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
