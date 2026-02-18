## SpellUIManager - スペルフェーズUI統合管理システム
##
## 責務: ナビゲーション状態管理、UI表示制御、スペル発動確認、Signal接続
## 統合元: SpellNavigationController, SpellUIController, SpellConfirmationHandler

extends Node
class_name SpellUIManager

# === 参照 ===
var _spell_phase_handler = null
var _ui_manager = null
var _board_system = null
var _player_system = null
var _game_3d_ref = null
var _card_system = null

# === UI状態 ===
var _spell_phase_ui_manager = null
var _spell_cast_notification_ui: SpellCastNotificationUI = null
var _waiting_for_notification_click: bool = false

# === 公開サービスアクセサ（_ui_manager private アクセス解消用） ===
var message_service: get: return _ui_manager.message_service if _ui_manager else null
var navigation_service: get: return _ui_manager.navigation_service if _ui_manager else null
var info_panel_service: get: return _ui_manager.info_panel_service if _ui_manager else null
var tap_target_manager: get: return _ui_manager.tap_target_manager if _ui_manager else null
var ui_manager: get: return _ui_manager  # UIManager への参照を取得（特殊な場合のみ）

# === 初期化 ===
func setup(
	spell_phase_handler,
	ui_manager,
	board_system,
	player_system,
	game_3d_ref,
	card_system
) -> void:
	_spell_phase_handler = spell_phase_handler
	_ui_manager = ui_manager
	_board_system = board_system
	_player_system = player_system
	_game_3d_ref = game_3d_ref
	_card_system = card_system

	if not _spell_phase_handler:
		push_error("[SpellUIManager] spell_phase_handler が null です")
	if not _ui_manager:
		push_error("[SpellUIManager] ui_manager が null です")


# =============================================================================
# ナビゲーション復元
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
	var spell_state = _spell_phase_handler.spell_state if _spell_phase_handler else null
	if not _ui_manager or not spell_state:
		return

	match spell_state.current_state:
		SpellStateHandler.State.WAITING_FOR_INPUT:
			_setup_spell_selection_navigation()
			show_spell_phase_buttons()
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

## 外部からの状態別ナビゲーション復元用エイリアス
func update_navigation_ui() -> void:
	restore_navigation_for_state()


# =============================================================================
# ナビゲーション設定
# =============================================================================

## スペル選択時のナビゲーション設定（決定 = スペルを使わない → サイコロ）
func _setup_spell_selection_navigation() -> void:
	if _ui_manager:
		_ui_manager.enable_navigation(
			func(): _pass_spell(),
			Callable()
		)

## ナビゲーション設定（ターゲット選択）
func _setup_target_selection_navigation() -> void:
	var target_handler = _spell_phase_handler.spell_target_selection_handler if _spell_phase_handler else null
	if target_handler:
		target_handler._setup_target_selection_navigation()
	elif _ui_manager:
		_ui_manager.enable_navigation(
			func(): _on_target_confirm(),
			func(): _on_target_cancel(),
			func(): _on_target_prev(),
			func(): _on_target_next()
		)

## ナビゲーション設定解除
func _clear_spell_navigation() -> void:
	var target_handler = _spell_phase_handler.spell_target_selection_handler if _spell_phase_handler else null
	if target_handler:
		target_handler._clear_spell_navigation()
	elif _ui_manager:
		_ui_manager.disable_navigation()


# =============================================================================
# ナビゲーション入力ハンドラー
# =============================================================================

## スペル使用スキップ（ダイス移動へ）
func _pass_spell() -> void:
	if _spell_phase_handler and _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow.pass_spell()

## ターゲット確認
func _on_target_confirm() -> void:
	var target_handler = _spell_phase_handler.spell_target_selection_handler if _spell_phase_handler else null
	if target_handler:
		target_handler._on_target_confirm()

## ターゲット選択キャンセル
func _on_target_cancel() -> void:
	var target_handler = _spell_phase_handler.spell_target_selection_handler if _spell_phase_handler else null
	if target_handler:
		target_handler._on_target_cancel()

## ターゲット選択前へ
func _on_target_prev() -> void:
	var target_handler = _spell_phase_handler.spell_target_selection_handler if _spell_phase_handler else null
	if target_handler:
		target_handler._on_target_prev()

## ターゲット選択次へ
func _on_target_next() -> void:
	var target_handler = _spell_phase_handler.spell_target_selection_handler if _spell_phase_handler else null
	if target_handler:
		target_handler._on_target_next()

## スペル効果確認
func _confirm_spell_effect() -> void:
	if _spell_phase_handler and _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow._confirm_spell_effect()

## スペル確認キャンセル
func _cancel_confirmation() -> void:
	if _spell_phase_handler and _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow._cancel_confirmation()


# =============================================================================
# UI表示制御
# =============================================================================

## SpellPhaseUIManager を初期化
func initialize_spell_phase_ui() -> void:
	if not _spell_phase_ui_manager:
		_spell_phase_ui_manager = SpellPhaseUIManager.new()
		if _spell_phase_handler:
			_spell_phase_handler.add_child(_spell_phase_ui_manager)

		if _spell_phase_ui_manager:
			_spell_phase_ui_manager.spell_phase_handler_ref = _spell_phase_handler

## スペルフェーズUIの更新
func update_spell_phase_ui() -> void:
	if not _ui_manager or not _card_system:
		push_error("[SpellUIManager] ui_manager または card_system が初期化されていません")
		return

	var current_player = _player_system.get_current_player() if _player_system else null
	if not current_player:
		push_error("[SpellUIManager] current_player が取得できません")
		return

	var hand_data = _card_system.get_all_cards_for_player(current_player.id)

	# スペル不可呪いチェック
	var context = _build_spell_context()
	var is_spell_disabled = SpellProtection.is_player_spell_disabled(current_player, context)

	if is_spell_disabled:
		_ui_manager.card_selection_filter = "spell_disabled"
		if _ui_manager.phase_display and _ui_manager.phase_display.has_method("show_toast"):
			_ui_manager.phase_display.show_toast("スペル不可の呪いがかかっています")
	else:
		_ui_manager.card_selection_filter = "spell"

	if _ui_manager and _ui_manager.hand_display:
		_ui_manager.hand_display.update_hand_display(current_player.id)

	# スペル選択UIを表示（人間プレイヤーのみ）
	if not (_spell_phase_handler and _spell_phase_handler.game_flow_manager and _spell_phase_handler.game_flow_manager.is_cpu_player(current_player.id)):
		show_spell_selection_ui(hand_data, current_player.magic_power)

## スペル選択UIを表示
func show_spell_selection_ui(_hand_data: Array, _available_magic: int) -> void:
	if not _ui_manager or not _ui_manager.card_selection_ui:
		return

	var current_player = _player_system.get_current_player() if _player_system else null
	if not current_player:
		return

	_ui_manager.card_selection_filter = "spell"
	if _ui_manager.card_selection_ui.has_method("show_selection"):
		_ui_manager.card_selection_ui.show_selection(current_player, "spell")

## スペル選択UIを非表示
func hide_spell_selection_ui() -> void:
	if not _ui_manager or not _ui_manager.card_selection_ui:
		return

	if _ui_manager.card_selection_ui.has_method("hide_selection"):
		_ui_manager.card_selection_ui.hide_selection()

## カメラを使用者に戻す
func return_camera_to_player() -> void:
	if not _player_system or not _board_system:
		return

	if not _spell_phase_handler or not _spell_phase_handler.spell_state:
		return

	if _board_system:
		var player_tile_index = _board_system.get_player_tile(_spell_phase_handler.spell_state.current_player_id)

		if _board_system.camera and _board_system.tile_nodes.has(player_tile_index):
			var tile_pos = _board_system.tile_nodes[player_tile_index].global_position

			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + GameConstants.CAMERA_OFFSET

			_board_system.camera.position = new_camera_pos
			_board_system.camera.look_at(tile_pos + Vector3(0, 1.0 + GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)


# =============================================================================
# ボタン管理
# =============================================================================

## スペルフェーズ開始時にボタンを表示
func show_spell_phase_buttons() -> void:
	if not _spell_phase_handler:
		return

	if _ui_manager and _spell_phase_handler and _spell_phase_handler.spell_state:
		var current_player_id = _spell_phase_handler.spell_state.current_player_id
		if _spell_phase_handler.mystic_arts_handler and _spell_phase_handler.mystic_arts_handler.has_available_mystic_arts(current_player_id):
			_ui_manager.show_mystic_button(func(): _spell_phase_handler.mystic_arts_handler.start_mystic_arts_phase())

## スペルフェーズ終了時にボタンを非表示
func hide_spell_phase_buttons() -> void:
	if _ui_manager:
		_ui_manager.hide_mystic_button()


# =============================================================================
# スペル発動確認
# =============================================================================

## 発動通知UIを初期化
func initialize_spell_cast_notification_ui() -> void:
	if _spell_cast_notification_ui:
		return

	_spell_cast_notification_ui = SpellCastNotificationUI.new()
	_spell_cast_notification_ui.name = "SpellCastNotificationUI"

	if _ui_manager:
		_ui_manager.add_child(_spell_cast_notification_ui)
	else:
		if _spell_phase_handler:
			_spell_phase_handler.add_child(_spell_cast_notification_ui)

## スペル/アルカナアーツ発動通知を表示（クリック待ち）
func show_spell_cast_notification(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool = false):
	if not _spell_cast_notification_ui:
		return

	var effect_name: String
	if is_mystic:
		effect_name = SpellCastNotificationUI.get_mystic_art_display_name(spell_or_mystic)
	else:
		effect_name = SpellCastNotificationUI.get_effect_display_name(spell_or_mystic)

	var target_name = SpellCastNotificationUI.get_target_display_name(target_data, _board_system, _player_system)

	_spell_cast_notification_ui.show_spell_cast_and_wait(caster_name, target_name, effect_name)
	await _spell_cast_notification_ui.click_confirmed

## 発動通知UIを取得
func get_spell_cast_notification_ui() -> SpellCastNotificationUI:
	return _spell_cast_notification_ui

## 発動通知UIをクリア
func clear_spell_cast_notification() -> void:
	if _spell_cast_notification_ui and _spell_cast_notification_ui.is_visible():
		_spell_cast_notification_ui.hide()
		_waiting_for_notification_click = false

## スペル関連のコンテキストを構築（世界呪い等）
func _build_spell_context() -> Dictionary:
	var context = {}

	if _spell_phase_handler and _spell_phase_handler.game_flow_manager and "game_stats" in _spell_phase_handler.game_flow_manager:
		context["world_curse"] = _spell_phase_handler.game_flow_manager.game_stats.get("world_curse", {})

	return context


# =============================================================================
# Signal接続（Phase 6-A: UI層分離）
# =============================================================================

# === SpellPhaseHandler Signal Listeners ===

func _on_human_spell_phase_started(_player_id: int, hand_data: Array, magic_power: int) -> void:
	initialize_spell_phase_ui()
	show_spell_phase_buttons()
	_setup_spell_selection_navigation()
	show_spell_selection_ui(hand_data, magic_power)

func _on_spell_cast_notification_requested(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool) -> void:
	await show_spell_cast_notification(caster_name, target_data, spell_or_mystic, is_mystic)
	if _spell_phase_handler:
		_spell_phase_handler.spell_cast_notification_completed.emit()


# === SpellFlowHandler Signal接続 ===

## SpellPhaseHandler の UI Signal を接続
func connect_spell_phase_handler_signals(sph) -> void:
	if not sph:
		push_error("[SpellUIManager] spell_phase_handler が null です")
		return

	if not sph.human_spell_phase_started.is_connected(_on_human_spell_phase_started):
		sph.human_spell_phase_started.connect(_on_human_spell_phase_started)

	if not sph.spell_cast_notification_requested.is_connected(_on_spell_cast_notification_requested):
		sph.spell_cast_notification_requested.connect(_on_spell_cast_notification_requested)


## SpellFlowHandler の UI Signal を接続
func connect_spell_flow_signals(spell_flow_handler) -> void:
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


# =============================================================================
# 検証・デバッグ
# =============================================================================

func is_valid() -> bool:
	return (
		_spell_phase_handler != null and
		_ui_manager != null
	)

func debug_print_status() -> void:
	var status = "[SpellUIManager] Status:\n"
	status += "  - spell_phase_handler: %s\n" % ("OK" if _spell_phase_handler else "NULL")
	status += "  - ui_manager: %s\n" % ("OK" if _ui_manager else "NULL")
	status += "  - board_system: %s\n" % ("OK" if _board_system else "NULL")
	status += "  - player_system: %s\n" % ("OK" if _player_system else "NULL")
	status += "  - card_system: %s\n" % ("OK" if _card_system else "NULL")
	status += "  - spell_cast_notification_ui: %s\n" % ("OK" if _spell_cast_notification_ui else "NULL")
	status += "  - spell_phase_ui_manager: %s\n" % ("OK" if _spell_phase_ui_manager else "NULL")
	status += "  - is_valid(): %s" % ("OK" if is_valid() else "NG")

	print(status)
