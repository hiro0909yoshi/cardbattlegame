extends RefCounted
class_name UITapHandler

# カメラタップによるクリーチャー情報表示
# UIManagerから委譲される

var ui_manager: UIManager = null


func _init(p_ui_manager: UIManager) -> void:
	ui_manager = p_ui_manager


## CameraControllerのシグナルを接続
func connect_camera_signals():
	print("[UITapHandler] connect_camera_signals 呼び出し")

	if not ui_manager.board_system_ref:
		print("[UITapHandler] board_system_ref がない")
		return

	if not ui_manager.board_system_ref.camera_controller:
		print("[UITapHandler] camera_controller がない")
		return

	var cam_ctrl = ui_manager.board_system_ref.camera_controller

	if cam_ctrl.creature_tapped.is_connected(_on_creature_tapped):
		print("[UITapHandler] シグナル既に接続済み")
		return

	cam_ctrl.creature_tapped.connect(_on_creature_tapped)
	cam_ctrl.tile_tapped.connect(_on_tile_tapped)
	cam_ctrl.empty_tapped.connect(_on_empty_tapped)
	print("[UITapHandler] カメラタップシグナル接続完了")


## クリーチャーがタップされた時のハンドラ
func _on_creature_tapped(tile_index: int, creature_data: Dictionary):
	print("[UITapHandler] _on_creature_tapped: タイル%d" % tile_index)

	if creature_data.is_empty():
		return

	# TapTargetManagerでターゲット選択中かチェック
	if ui_manager.tap_target_manager and ui_manager.tap_target_manager.is_active:
		if ui_manager.tap_target_manager.handle_creature_tap(tile_index, creature_data):
			return

	var gfm = ui_manager.game_flow_manager_ref
	var is_dominio_order_active = gfm and gfm.dominio_command_handler and gfm.dominio_command_handler.current_state != gfm.dominio_command_handler.State.CLOSED
	var is_tap_target_active = ui_manager.tap_target_manager and ui_manager.tap_target_manager.is_active
	var is_tutorial_active = ui_manager.global_action_buttons and ui_manager.global_action_buttons.explanation_mode_active
	var is_spell_phase_active = gfm and gfm.spell_phase_handler and gfm.spell_phase_handler.is_spell_phase_active()
	var setup_buttons = not is_tap_target_active and not is_dominio_order_active and not is_tutorial_active and not is_spell_phase_active

	if ui_manager.creature_info_panel_ui:
		ui_manager.creature_info_panel_ui.show_view_mode(creature_data, tile_index, setup_buttons)
		print("[UITapHandler] クリーチャー情報パネル表示: タイル%d - %s (setup_buttons=%s)" % [tile_index, creature_data.get("name", "不明"), setup_buttons])

		if is_dominio_order_active:
			ui_manager.register_back_action(func():
				ui_manager.creature_info_panel_ui.hide_panel(false)
				gfm.dominio_command_handler._restore_navigation()
			, "閉じる")
		elif is_spell_phase_active:
			if not ui_manager._spell_phase_buttons_saved:
				ui_manager._spell_phase_saved_confirm = ui_manager._compat_confirm_cb
				ui_manager._spell_phase_saved_back = ui_manager._compat_back_cb
				ui_manager._spell_phase_saved_up = ui_manager._compat_up_cb
				ui_manager._spell_phase_saved_down = ui_manager._compat_down_cb
				ui_manager._spell_phase_buttons_saved = true
			ui_manager.register_back_action(func():
				ui_manager.creature_info_panel_ui.hide_panel(false)
				ui_manager._restore_spell_phase_buttons()
			, "閉じる")


## タイルがタップされた時のハンドラ（クリーチャーがいない場合）
func _on_tile_tapped(tile_index: int, tile_data: Dictionary):
	if ui_manager.tap_target_manager and ui_manager.tap_target_manager.is_active:
		if ui_manager.tap_target_manager.handle_tile_tap(tile_index, tile_data):
			return

		if ui_manager.creature_info_panel_ui and ui_manager.creature_info_panel_ui.is_panel_visible():
			ui_manager.creature_info_panel_ui.hide_panel(false)
		return

	if ui_manager.creature_info_panel_ui and ui_manager.creature_info_panel_ui.is_panel_visible():
		var is_tutorial_active = ui_manager.global_action_buttons and ui_manager.global_action_buttons.explanation_mode_active
		var gfm = ui_manager.game_flow_manager_ref
		var is_spell_phase_active = gfm and gfm.spell_phase_handler and gfm.spell_phase_handler.is_spell_phase_active()
		var clear_buttons = not is_tutorial_active and not is_spell_phase_active
		ui_manager.creature_info_panel_ui.hide_panel(clear_buttons)
		if is_spell_phase_active:
			ui_manager._restore_spell_phase_buttons()


## 空（タイル外）がタップされた時のハンドラ
func _on_empty_tapped():
	if ui_manager.tap_target_manager and ui_manager.tap_target_manager.is_active:
		if ui_manager.tap_target_manager.handle_empty_tap():
			return

	if ui_manager.creature_info_panel_ui and ui_manager.creature_info_panel_ui.is_panel_visible():
		ui_manager.creature_info_panel_ui.hide_panel(false)
		if ui_manager._spell_phase_buttons_saved:
			ui_manager._restore_spell_phase_buttons()
		print("[UITapHandler] 空タップでパネル閉じ")


## TapTargetManagerからターゲットが選択された時
func _on_tap_target_selected(tile_index: int, _creature_data: Dictionary):
	print("[UITapHandler] タップターゲット選択: タイル%d" % tile_index)


## TapTargetManagerから選択がキャンセルされた時
func _on_tap_target_cancelled():
	print("[UITapHandler] タップターゲット選択キャンセル")
