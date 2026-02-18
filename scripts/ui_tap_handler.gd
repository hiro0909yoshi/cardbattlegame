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

	var cam_ctrl = ui_manager.board_system_ref.get_camera_controller_ref()
	if not cam_ctrl:
		print("[UITapHandler] camera_controller がない")
		return

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
	var is_card_selection_active = ui_manager.card_selection_ui and ui_manager.card_selection_ui.is_active
	var setup_buttons = not is_tap_target_active and not is_dominio_order_active and not is_tutorial_active and not is_spell_phase_active and not is_card_selection_active

	ui_manager.show_card_info(creature_data, tile_index, setup_buttons)
	print("[UITapHandler] クリーチャー情報パネル表示: タイル%d - %s (setup_buttons=%s)" % [tile_index, creature_data.get("name", "不明"), setup_buttons])


## タイルがタップされた時のハンドラ（クリーチャーがいない場合）
func _on_tile_tapped(tile_index: int, tile_data: Dictionary):
	if ui_manager.tap_target_manager and ui_manager.tap_target_manager.is_active:
		if ui_manager.tap_target_manager.handle_tile_tap(tile_index, tile_data):
			return

		ui_manager.hide_all_info_panels(false)
		return

	if ui_manager.is_any_info_panel_visible():
		_close_info_panel_and_restore()


## 空（タイル外）がタップされた時のハンドラ
func _on_empty_tapped():
	if ui_manager.tap_target_manager and ui_manager.tap_target_manager.is_active:
		if ui_manager.tap_target_manager.handle_empty_tap():
			return

	if ui_manager.is_any_info_panel_visible():
		_close_info_panel_and_restore()
		print("[UITapHandler] 空タップでパネル閉じ")


## インフォパネルを閉じてフェーズ状態を復元する共通処理
func _close_info_panel_and_restore():
	ui_manager.hide_all_info_panels(true)
	if ui_manager.is_nav_state_saved():
		# show_card_info() で開かれたパネル → 保存されたナビを復元
		ui_manager.restore_current_phase()
	# else: show_card_info_only() で開かれたパネル
	# ナビは変更されていないので復元不要
	# カードのホバー状態を解除
	var card_script = load("res://scripts/card.gd")
	if card_script.currently_selected_card:
		card_script.currently_selected_card.deselect_card()


## TapTargetManagerからターゲットが選択された時
func on_tap_target_selected(tile_index: int, _creature_data: Dictionary):
	print("[UITapHandler] タップターゲット選択: タイル%d" % tile_index)


## TapTargetManagerから選択がキャンセルされた時
func on_tap_target_cancelled():
	print("[UITapHandler] タップターゲット選択キャンセル")
