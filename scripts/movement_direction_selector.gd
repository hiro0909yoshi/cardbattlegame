extends RefCounted
class_name MovementDirectionSelector

# 方向選択UI（タイプA: ゲームスタート/ワープ後の+1/-1選択）
# MovementController3Dから委譲される

# 状態
var is_active: bool = false
var selected_direction: int = 1
var available_directions: Array = []
signal direction_selected(direction: int)

# 参照
var controller: MovementController3D = null


func _init(p_controller: MovementController3D) -> void:
	controller = p_controller


# 方向選択UIを表示して結果を返す
func show_direction_selection(directions: Array) -> int:
	is_active = true
	available_directions = directions
	selected_direction = directions[0]

	_update_ui()
	setup_navigation()

	var result = await direction_selected
	is_active = false
	_clear_navigation()

	return result


# シンプルな方向選択（+1 か -1 を選ぶ）
func show_simple_direction_selection() -> int:
	is_active = true
	available_directions = [1, -1]
	selected_direction = 1  # デフォルトは順方向

	_update_ui()
	setup_navigation()

	var result = await direction_selected
	is_active = false
	_clear_navigation()

	return result


# 方向選択UIを更新
func _update_ui():
	var gfm = controller.game_flow_manager
	if gfm and gfm.ui_manager:
		var dir_text = "順方向 →" if selected_direction == 1 else "← 逆方向"
		if gfm.ui_manager.phase_display:
			gfm.ui_manager.show_action_prompt("移動方向を選択: %s" % dir_text)
	# カメラを選択方向に少しずらす
	var player_id = controller.current_moving_player
	if player_id >= 0:
		var ct = controller.player_tiles[player_id]
		var nt = ct + selected_direction
		if controller.tile_nodes.has(ct) and controller.tile_nodes.has(nt):
			var cp = controller.tile_nodes[ct].global_position
			var np = controller.tile_nodes[nt].global_position
			var dv = (np - cp).normalized()
			var offset_pos = cp + dv * cp.distance_to(np) * 5.0
			if gfm and gfm.board_system_3d and gfm.board_system_3d.camera_controller:
				gfm.board_system_3d.camera_controller.focus_on_position_slow(offset_pos, 0.5)

	# 到着予想タイルに基づいて手札の配置制限表示を更新
	if player_id >= 0:
		var ct = controller.player_tiles[player_id]
		var first_tile = ct + selected_direction
		if controller.current_remaining_steps > 1:
			var destinations = controller.destination_predictor.predict_all_destinations(first_tile, controller.current_remaining_steps - 1, ct)
			controller.destination_predictor.update_hand_restriction_for_destinations(destinations)
		else:
			controller.destination_predictor.update_hand_restriction_for_destinations([first_tile])


# ナビゲーションボタンを設定
func setup_navigation():
	var gfm = controller.game_flow_manager
	if gfm and gfm.ui_manager:
		gfm.ui_manager.enable_navigation(
			func(): _confirm_selection(),  # 決定
			Callable(),  # 戻るなし
			func(): _cycle_selection(),    # 上
			func(): _cycle_selection()     # 下
		)


# 閲覧モードから戻る時のナビゲーション復元
func restore_navigation():
	if not is_active:
		return
	setup_navigation()
	_update_ui()


# ナビゲーションボタンをクリア
func _clear_navigation():
	var gfm = controller.game_flow_manager
	if gfm and gfm.ui_manager:
		gfm.ui_manager.disable_navigation()


# 方向選択を切り替え（上下どちらでも同じ動作）
func cycle_selection():
	_cycle_selection()


func _cycle_selection():
	if not is_active:
		return
	if available_directions.size() > 1:
		var current_idx = available_directions.find(selected_direction)
		current_idx = (current_idx + 1) % available_directions.size()
		selected_direction = available_directions[current_idx]
		_update_ui()


# 方向選択を確定
func confirm_selection():
	_confirm_selection()


func _confirm_selection():
	if not is_active:
		return
	controller.destination_predictor.update_hand_restriction_for_destinations([])  # 到着予想制限をクリア
	direction_selected.emit(selected_direction)


# キーボード入力処理
func handle_input(event: InputEvent) -> bool:
	if not is_active:
		return false

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
			_cycle_selection()
			return true
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_confirm_selection()
			return true

	return false
