extends RefCounted
class_name MovementBranchSelector

# 分岐タイル選択UI（タイプB: 移動中の分岐点）
# MovementController3Dから委譲される

# 状態
var is_active: bool = false
var selected_branch_index: int = 0
var available_branches: Array = []  # タイル番号のリスト
signal branch_selected(tile_index: int)

# 分岐選択インジケーター
var branch_indicator: MeshInstance3D = null
var current_branch_tile: int = -1  # 現在分岐選択中のタイル

# インジケーター設定（BranchTileの定数を参照）
const INDICATOR_HEIGHT = 0.4

# 参照
var controller: MovementController3D = null
var _message_service = null
var _navigation_service = null


func _init(p_controller: MovementController3D) -> void:
	controller = p_controller


# サービスを設定
func set_services(p_message_service, p_navigation_service) -> void:
	_message_service = p_message_service
	_navigation_service = p_navigation_service


# 分岐タイル選択UIを表示して選択を待つ
func show_branch_tile_selection(choices: Array) -> int:
	is_active = true
	available_branches = choices

	# 次のチェックポイントに近い方向をデフォルト選択
	if controller.cpu_movement_evaluator and current_branch_tile >= 0:
		selected_branch_index = controller.cpu_movement_evaluator.get_nearest_checkpoint_branch_index(controller.current_moving_player, choices, current_branch_tile)
	else:
		selected_branch_index = 0

	# カメラを手動モードに切り替え（分岐先を確認できるように）
	var gfm = controller.game_flow_manager
	if gfm and gfm.board_system_3d:
		gfm.board_system_3d.enable_manual_camera()

	_update_ui()
	_update_indicator()
	setup_navigation()

	var result = await branch_selected
	is_active = false
	_clear_navigation()
	_hide_indicator()

	# 到着予測ハイライトをクリア
	controller.destination_predictor.clear_destination_highlight()

	# 到着予測地点にカメラを移動（awaitしない＝移動と並行）
	if gfm and gfm.board_system_3d:
		if controller.current_remaining_steps > 1:
			var from_tile = controller.player_tiles[controller.current_moving_player] if controller.current_moving_player >= 0 else -1
			var destinations = controller.destination_predictor.predict_all_destinations(result, controller.current_remaining_steps - 1, from_tile)
			if not destinations.is_empty() and controller.tile_nodes.has(destinations[0]):
				gfm.board_system_3d.focus_camera_on_tile_slow(destinations[0], 1.2)
		elif controller.tile_nodes.has(result):
			gfm.board_system_3d.focus_camera_on_tile_slow(result, 0.8)
		gfm.board_system_3d.enable_follow_camera()

	return result


# 分岐選択UI更新
func _update_ui():
	if _message_service:
		var choices_text = ""
		for i in range(available_branches.size()):
			var tile_num = available_branches[i]
			if i == selected_branch_index:
				choices_text += "[→タイル%d←] " % tile_num
			else:
				choices_text += " タイル%d " % tile_num
		var remaining_text = "（残り%dマス）" % controller.current_remaining_steps if controller.current_remaining_steps > 0 else ""
		_message_service.show_action_prompt("進む方向を選択: %s %s" % [choices_text, remaining_text])

	# 到着予測ハイライトを更新
	controller.destination_predictor.update_destination_highlight_for_branch(
		is_active, available_branches, selected_branch_index,
		controller.current_remaining_steps, current_branch_tile
	)

	# 到着予想タイルに基づいて手札の配置制限表示を更新
	if is_active and not available_branches.is_empty():
		var selected_tile = available_branches[selected_branch_index]
		var steps_after_branch = controller.current_remaining_steps - 1
		if steps_after_branch <= 0:
			controller.destination_predictor.update_hand_restriction_for_destinations([selected_tile])
		else:
			var destinations = controller.destination_predictor.predict_all_destinations(selected_tile, steps_after_branch, current_branch_tile)
			controller.destination_predictor.update_hand_restriction_for_destinations(destinations)

	# カメラを選択中の分岐方向にずらす
	var gfm2 = controller.game_flow_manager
	if not available_branches.is_empty() and current_branch_tile >= 0 and gfm2 and gfm2.board_system_3d:
		var target_tile = available_branches[selected_branch_index]
		if controller.tile_nodes.has(current_branch_tile) and controller.tile_nodes.has(target_tile):
			var bp = controller.tile_nodes[current_branch_tile].global_position
			var tp = controller.tile_nodes[target_tile].global_position
			var dv = (tp - bp).normalized()
			var offset_pos = bp + dv * bp.distance_to(tp) * 3.0
			gfm2.board_system_3d.focus_camera_slow(offset_pos, 0.5)


# ナビゲーションボタンを設定
func setup_navigation():
	if _navigation_service:
		_navigation_service.enable_navigation(
			func(): _confirm_selection(),    # 決定
			Callable(),                       # 戻るなし
			func(): _cycle_selection(-1),    # 上（左へ）
			func(): _cycle_selection(1)      # 下（右へ）
		)


# 閲覧モードから戻る時のナビゲーション復元
func restore_navigation():
	if not is_active:
		return
	setup_navigation()
	_update_ui()


# ナビゲーションボタンをクリア
func _clear_navigation():
	if _navigation_service:
		_navigation_service.disable_navigation()


# 分岐選択を切り替え
func cycle_selection(delta: int):
	_cycle_selection(delta)


func _cycle_selection(delta: int):
	if not is_active:
		return
	if available_branches.size() > 1:
		selected_branch_index = (selected_branch_index + delta + available_branches.size()) % available_branches.size()
		_update_ui()
		_update_indicator()


# 分岐選択を確定
func confirm_selection():
	_confirm_selection()


func _confirm_selection():
	if not is_active:
		return
	controller.destination_predictor.update_hand_restriction_for_destinations([])  # 到着予想制限をクリア
	var selected_tile = available_branches[selected_branch_index]
	branch_selected.emit(selected_tile)


# 分岐選択インジケーターを更新
func _update_indicator():
	if current_branch_tile < 0 or available_branches.is_empty():
		return

	var current_tile_node = controller.tile_nodes.get(current_branch_tile)
	var target_tile_index = available_branches[selected_branch_index]
	var target_tile_node = controller.tile_nodes.get(target_tile_index)

	if not current_tile_node or not target_tile_node:
		return

	# 方向を計算
	var current_pos = current_tile_node.global_position
	var target_pos = target_tile_node.global_position
	var diff = target_pos - current_pos

	# インジケーター生成（なければ）
	if not branch_indicator:
		branch_indicator = MeshInstance3D.new()
		branch_indicator.name = "BranchIndicator"

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 1, 0, 1)
		material.emission_enabled = true
		material.emission = Color(1, 1, 0, 1)
		material.emission_energy_multiplier = 0.5
		branch_indicator.material_override = material

		controller.get_tree().root.add_child(branch_indicator)

	# 方向に応じてメッシュサイズと位置を設定
	var offset = Vector3.ZERO
	var mesh_size = BranchTile.DIRECTION_MESH_SIZE["right"]

	if abs(diff.x) > abs(diff.z):
		mesh_size = BranchTile.DIRECTION_MESH_SIZE["right"]
		if diff.x > 0:
			offset = Vector3(BranchTile.DIRECTION_OFFSET["right"].x, 0, 0)
		else:
			offset = Vector3(BranchTile.DIRECTION_OFFSET["left"].x, 0, 0)
	else:
		mesh_size = BranchTile.DIRECTION_MESH_SIZE["down"]
		if diff.z > 0:
			offset = Vector3(0, 0, BranchTile.DIRECTION_OFFSET["down"].z)
		else:
			offset = Vector3(0, 0, BranchTile.DIRECTION_OFFSET["up"].z)

	var box_mesh = BoxMesh.new()
	box_mesh.size = mesh_size
	branch_indicator.mesh = box_mesh

	branch_indicator.global_position = current_pos + offset + Vector3(0, INDICATOR_HEIGHT, 0)
	branch_indicator.visible = true


# 分岐選択インジケーターを非表示
func _hide_indicator():
	if branch_indicator:
		branch_indicator.visible = false
	current_branch_tile = -1


# 分岐チェックと処理（Dictionary形式：{タイル番号: 方向}から選ぶ）
func check_and_handle_branch(current_tile: int, _came_from: int, path: Array, current_index: int) -> Dictionary:
	var tile = controller.tile_nodes.get(current_tile)
	if not tile:
		return {"recalculated": false}

	# connectionsが設定されていなければスキップ（分岐点ではない）
	if not tile.connections or tile.connections.is_empty():
		return {"recalculated": false}

	var choices = tile.connections.keys()  # 選択可能なタイル番号
	var new_direction: int
	var first_tile: int

	if choices.size() >= 2:
		first_tile = await show_branch_tile_selection(choices)
		new_direction = tile.connections[first_tile]
	else:
		first_tile = choices[0]
		new_direction = tile.connections[first_tile]

	# 方向を保存
	if controller.current_moving_player >= 0:
		controller.set_player_current_direction(controller.current_moving_player, new_direction)

	# 残りの経路を再計算
	var remaining_steps = path.size() - current_index - 1
	var new_path = path.slice(0, current_index + 1)

	if remaining_steps > 0:
		new_path.append(first_tile)
		var current = first_tile
		for j in range(remaining_steps - 1):
			current = current + new_direction
			new_path.append(current)

	return {"recalculated": true, "new_path": new_path}


# キーボード入力処理
func handle_input(event: InputEvent) -> bool:
	if not is_active:
		return false

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT or event.keycode == KEY_UP:
			_cycle_selection(-1)
			return true
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_DOWN:
			_cycle_selection(1)
			return true
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_confirm_selection()
			return true

	return false
