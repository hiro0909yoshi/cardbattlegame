extends Node
class_name MovementController3D

# 3D移動制御システム
# プレイヤーの3D移動、カメラ追従を管理
# サブシステム: 方向選択、分岐選択、経路予測、ワープ、特殊処理

signal movement_started(player_id: int)
signal movement_step_completed(player_id: int, tile_index: int)
signal movement_completed(player_id: int, final_tile: int)
@warning_ignore("unused_signal")  # movement_warp_handlerで使用
signal warp_executed(player_id: int, from_tile: int, to_tile: int)  # ワープ実行時に発火
@warning_ignore("unused_signal")  # movement_special_handlerで使用
signal start_passed(player_id: int)  # スタート地点通過時に発火

# 移動設定
const MOVE_DURATION = 0.1  # 1マスの移動時間
const MOVE_HEIGHT = 1.0    # 駒の高さオフセット

# 参照
var tile_nodes = {}        # tile_index -> BaseTile
var player_nodes = []      # プレイヤー駒ノード配列
var player_tiles = []      # 各プレイヤーの現在位置
var camera = null          # Camera3D参照
var camera_controller = null  # CameraController参照

# 状態
var is_moving = false
var current_moving_player = -1

# システム参照
var player_system: PlayerSystem = null
var special_tile_system: SpecialTileSystem = null
var game_flow_manager = null  # カメラ制御・CPU判定用（is_game_ended は Callable 化済み）
var is_game_ended_checker: Callable = func() -> bool: return false
var game_3d_ref = null  # game_3d直接参照（get_parent()チェーン廃止用）
var spell_movement: SpellMovement = null
var spell_player_move = null

# CPU移動評価システム
var cpu_movement_evaluator: CPUMovementEvaluator = null

# 移動中の残り歩数（CPU分岐選択用）
var current_remaining_steps: int = 0

# サブシステム
var direction_selector: MovementDirectionSelector = null
var branch_selector: MovementBranchSelector = null
var destination_predictor: MovementDestinationPredictor = null
var warp_handler: MovementWarpHandler = null
var special_handler: MovementSpecialHandler = null


func _ready():
	# サブシステムを初期化
	direction_selector = MovementDirectionSelector.new(self)
	branch_selector = MovementBranchSelector.new(self)
	destination_predictor = MovementDestinationPredictor.new(self)
	warp_handler = MovementWarpHandler.new(self)
	special_handler = MovementSpecialHandler.new(self)


# 初期化
func initialize(tiles: Dictionary, players: Array, cam: Camera3D = null):
	tile_nodes = tiles
	player_nodes = players
	camera = cam

	player_tiles.clear()
	for i in range(player_nodes.size()):
		player_tiles.append(0)


# システム参照を設定
func setup_systems(p_system: PlayerSystem, st_system: SpecialTileSystem = null, gf_manager = null):
	player_system = p_system

	spell_movement = SpellMovement.new()
	if gf_manager and gf_manager.creature_manager:
		spell_movement.setup(gf_manager.creature_manager, null)
	special_tile_system = st_system
	game_flow_manager = gf_manager


# is_game_ended チェック用の Callable を設定
func set_game_ended_checker(checker: Callable) -> void:
	is_game_ended_checker = checker


# CardSelectionUIを設定（destination_predictorに直接参照を渡す）
func set_card_selection_ui(ui: CardSelectionUI) -> void:
	if destination_predictor:
		destination_predictor.set_card_selection_ui(ui)


# サービスを設定（セレクターに直接参照を渡す）
func set_services(p_message_service, p_navigation_service) -> void:
	if direction_selector:
		direction_selector.set_services(p_message_service, p_navigation_service)
	if branch_selector:
		branch_selector.set_services(p_message_service, p_navigation_service)


# game_3d参照を設定（TutorialManager取得用）
func set_game_3d_ref(p_game_3d) -> void:
	game_3d_ref = p_game_3d


# プレイヤーの現在位置を取得
func get_player_tile(player_id: int) -> int:
	if player_id >= 0 and player_id < player_tiles.size():
		return player_tiles[player_id]
	return -1


# プレイヤーの位置を設定
func set_player_tile(player_id: int, tile_index: int):
	if player_id >= 0 and player_id < player_tiles.size():
		player_tiles[player_id] = tile_index


# === メイン移動処理 ===

# プレイヤーを移動（外部から呼ばれるメイン関数）
func move_player(player_id: int, steps: int, dice_value: int = 0) -> void:
	if is_moving or player_id >= player_nodes.size():
		print("[MovementController] move_player早期リターン: is_moving=%s, player_id=%d, player_nodes.size=%d" % [is_moving, player_id, player_nodes.size()])
		return

	# ゲーム終了チェック
	if is_game_ended_checker.call():
		print("[MovementController] ゲーム終了済み、移動スキップ")
		return

	is_moving = true
	current_moving_player = player_id
	print("[MovementController] 移動開始: player=%d, steps=%d" % [player_id, steps])
	emit_signal("movement_started", player_id)

	# ダイス条件バフをチェックして適用（移動前）
	if dice_value > 0:
		special_handler.apply_dice_condition_buffs(player_id, dice_value)

	# 方向選択権チェック
	var has_direction_choice = _check_direction_choice_pending(player_id)
	print("[MovementController] direction_choice=%s, player=%d" % [has_direction_choice, player_id])

	if has_direction_choice:
		var current_tile = player_tiles[player_id]
		var came_from = _get_player_came_from(player_id)
		current_remaining_steps = steps
		var first_tile = await _select_first_tile(current_tile, came_from)

		_set_player_came_from(player_id, current_tile)
		_consume_direction_choice(player_id)

		await _move_steps_with_branch(player_id, steps, first_tile)
	else:
		await _move_steps_with_branch(player_id, steps, -1)

	var final_tile = player_tiles[player_id]

	is_moving = false
	current_moving_player = -1

	print("[MovementController] 移動完了: player=%d, final_tile=%d" % [player_id, final_tile])
	emit_signal("movement_completed", player_id, final_tile)


# 1歩ずつ移動（分岐があれば選択）
func _move_steps_with_branch(player_id: int, steps: int, first_tile: int = -1) -> void:
	print("[MovementController] _move_steps_with_branch開始: steps=%d, first_tile=%d" % [steps, first_tile])
	var current_tile = player_tiles[player_id]
	var came_from = _get_player_came_from(player_id)
	var remaining_steps = steps
	var is_first_step = true

	while remaining_steps > 0:
		print("[MovementController] 移動ループ: remaining=%d, current=%d" % [remaining_steps, current_tile])
		if is_game_ended_checker.call():
			print("[MovementController] ゲーム終了済み、移動中断")
			break
		current_remaining_steps = remaining_steps

		var next_tile: int

		if is_first_step and first_tile >= 0:
			next_tile = first_tile
			is_first_step = false
		else:
			next_tile = await _get_next_tile_with_branch(current_tile, came_from, player_id)
			is_first_step = false

		# スタート通過チェック
		if next_tile == 0 and current_tile > next_tile:
			special_handler.handle_start_pass(player_id)

		await move_to_tile(player_id, next_tile)
		await special_handler.check_and_handle_checkpoint(player_id, next_tile, current_tile)

		came_from = current_tile
		current_tile = next_tile
		player_tiles[player_id] = next_tile
		_set_player_came_from(player_id, came_from)

		remaining_steps -= 1

		# ワープチェック
		var warp_result = await warp_handler.check_and_handle_warp(player_id, next_tile)
		if warp_result.warped:
			current_tile = warp_result.new_tile
			player_tiles[player_id] = current_tile
			came_from = next_tile
			_set_player_came_from(player_id, came_from)
			remaining_steps += 1
			continue

		# 通過イベントチェック（最終歩でない場合）
		if remaining_steps > 0:
			await warp_handler.check_pass_through_event(player_id, current_tile)

		# 足どめチェック
		var stop_result = warp_handler.check_forced_stop_at_tile(current_tile, player_id)
		if stop_result["stopped"]:
			print("[足どめ] ", stop_result["reason"])
			emit_signal("movement_step_completed", player_id, current_tile)
			break

		emit_signal("movement_step_completed", player_id, current_tile)


# 次のタイルを取得（分岐があれば選択UI）
func _get_next_tile_with_branch(current_tile: int, came_from: int, player_id: int) -> int:
	var tile = tile_nodes.get(current_tile)

	if not tile or not tile.connections or tile.connections.is_empty():
		var direction = _get_player_current_direction(player_id)
		return current_tile + direction

	var choices = []
	for conn in tile.connections:
		if conn != came_from:
			choices.append(conn)

	if choices.is_empty():
		return came_from

	var chosen: int
	if tile is BranchTile:
		var result = tile.get_next_tile_for_direction(came_from)
		if result.tile >= 0:
			chosen = result.tile
		elif not result.choices.is_empty():
			if game_flow_manager and game_flow_manager.is_cpu_player(player_id) and cpu_movement_evaluator:
				chosen = cpu_movement_evaluator.decide_branch_choice(player_id, result.choices, current_remaining_steps, current_tile)
				print("[CPU分岐選択] プレイヤー%d: タイル %d を選択 (残り%d歩)" % [player_id + 1, chosen, current_remaining_steps])
			else:
				branch_selector.current_branch_tile = current_tile
				chosen = await branch_selector.show_branch_tile_selection(result.choices)
		else:
			chosen = came_from
	elif choices.size() == 1:
		chosen = choices[0]
	else:
		if game_flow_manager and game_flow_manager.is_cpu_player(player_id) and cpu_movement_evaluator:
			chosen = cpu_movement_evaluator.decide_branch_choice(player_id, choices, current_remaining_steps, current_tile)
			print("[CPU分岐選択] プレイヤー%d: タイル %d を選択 (残り%d歩)" % [player_id + 1, chosen, current_remaining_steps])
		else:
			branch_selector.current_branch_tile = current_tile
			chosen = await branch_selector.show_branch_tile_selection(choices)

	var inferred_direction = _infer_direction_from_choice(current_tile, chosen, player_id)
	set_player_current_direction(player_id, inferred_direction)

	return chosen


# 最初の1歩を選択（分岐点の場合）
func _select_first_tile(current_tile: int, came_from: int) -> int:
	var tile = tile_nodes.get(current_tile)

	if not tile or not tile.connections or tile.connections.is_empty():
		var selected_dir: int
		if game_flow_manager and game_flow_manager.is_cpu_player(current_moving_player):
			var tutorial_manager = _get_tutorial_manager()
			if tutorial_manager and tutorial_manager.is_active:
				selected_dir = tutorial_manager.get_cpu_direction()
				print("[CPU方向選択] チュートリアル: プレイヤー%d: 方向 %d" % [current_moving_player + 1, selected_dir])
			elif cpu_movement_evaluator:
				selected_dir = cpu_movement_evaluator.decide_direction(current_moving_player, [1, -1])
				print("[CPU方向選択] プレイヤー%d: 方向 %d を選択" % [current_moving_player + 1, selected_dir])
			else:
				selected_dir = 1
		else:
			selected_dir = await direction_selector.show_simple_direction_selection()
			var tutorial_manager = _get_tutorial_manager()
			if tutorial_manager and tutorial_manager.is_active:
				tutorial_manager.set_player_direction(selected_dir)
		set_player_current_direction(current_moving_player, selected_dir)
		return current_tile + selected_dir

	var choices = []
	for conn in tile.connections:
		if conn != came_from:
			choices.append(conn)

	if choices.is_empty():
		return came_from

	var chosen: int
	if tile is BranchTile:
		var result = tile.get_next_tile_for_direction(came_from)
		if result.tile >= 0:
			chosen = result.tile
		elif not result.choices.is_empty():
			if game_flow_manager and game_flow_manager.is_cpu_player(current_moving_player) and cpu_movement_evaluator:
				chosen = cpu_movement_evaluator.decide_branch_choice(current_moving_player, result.choices, current_remaining_steps, current_tile)
				print("[CPU分岐選択] プレイヤー%d: タイル %d を選択 (残り%d歩)" % [current_moving_player + 1, chosen, current_remaining_steps])
			else:
				branch_selector.current_branch_tile = current_tile
				chosen = await branch_selector.show_branch_tile_selection(result.choices)
		else:
			chosen = came_from
	elif choices.size() == 1:
		chosen = choices[0]
	else:
		if game_flow_manager and game_flow_manager.is_cpu_player(current_moving_player) and cpu_movement_evaluator:
			chosen = cpu_movement_evaluator.decide_branch_choice(current_moving_player, choices, current_remaining_steps, current_tile)
			print("[CPU分岐選択] プレイヤー%d: タイル %d を選択 (残り%d歩)" % [current_moving_player + 1, chosen, current_remaining_steps])
		else:
			branch_selector.current_branch_tile = current_tile
			chosen = await branch_selector.show_branch_tile_selection(choices)

	var inferred_dir = _infer_direction_from_choice(current_tile, chosen)
	set_player_current_direction(current_moving_player, inferred_dir)

	return chosen


# === 入力処理 ===

func _input(event):
	# 方向選択
	if direction_selector.is_active:
		if direction_selector.handle_input(event):
			get_viewport().set_input_as_handled()
		return

	# 分岐タイル選択
	if branch_selector.is_active:
		if branch_selector.handle_input(event):
			get_viewport().set_input_as_handled()
		return


# === 経路計算 ===

func calculate_path(player_id: int, steps: int, direction: int = 1) -> Array:
	var path = []
	var current_tile = player_tiles[player_id]

	var final_direction = direction
	if _has_movement_reverse_curse(player_id):
		final_direction = -direction

	for i in range(steps):
		current_tile = current_tile + final_direction
		path.append(current_tile)

	return path


func _get_next_tile(current_tile: int, direction: int, came_from: int) -> int:
	var tile = tile_nodes.get(current_tile)

	if not tile:
		return current_tile + direction

	if tile.connections and not tile.connections.is_empty():
		return _get_next_from_connections(tile.connections, came_from, direction)

	return current_tile + direction


func _get_next_from_connections(connections: Array, came_from: int, direction: int) -> int:
	var choices = connections.filter(func(n): return n != came_from)

	if choices.is_empty():
		return came_from

	if choices.size() == 1:
		return choices[0]

	choices.sort()
	if direction > 0:
		return choices[-1]
	else:
		return choices[0]


# === 移動アニメーション ===

# 経路に沿って移動
func move_along_path(player_id: int, path: Array) -> void:
	var previous_tile = player_tiles[player_id]
	var i = 0

	while i < path.size():
		var tile_index = path[i]

		if not tile_nodes.has(tile_index):
			print("Warning: タイル", tile_index, "が見つかりません")
			i += 1
			continue

		if tile_index == 0 and previous_tile > tile_index:
			special_handler.handle_start_pass(player_id)

		await move_to_tile(player_id, tile_index)
		await special_handler.check_and_handle_checkpoint(player_id, tile_index, previous_tile)

		player_tiles[player_id] = tile_index

		# 通過イベントチェック
		if i < path.size() - 1:
			await warp_handler.check_pass_through_event(player_id, tile_index)

		# 分岐チェック
		if i < path.size() - 1:
			var branch_result = await branch_selector.check_and_handle_branch(tile_index, previous_tile, path, i)
			if branch_result.recalculated:
				path = branch_result.new_path

		# ワープチェック
		var warp_result = await warp_handler.check_and_handle_warp(player_id, tile_index)
		if warp_result.warped:
			var warped_tile = warp_result.new_tile
			player_tiles[player_id] = warped_tile

			var new_path = [warped_tile]
			var current = warped_tile
			var came_from = tile_index
			for j in range(i + 1, path.size()):
				var next = _get_next_tile(current, 1, came_from)
				came_from = current
				current = next
				new_path.append(current)

			for j in range(new_path.size()):
				if i + j + 1 < path.size():
					path[i + j + 1] = new_path[j]
				else:
					path.append(new_path[j])

			tile_index = warped_tile

		# 足どめ判定
		var stop_result = warp_handler.check_forced_stop_at_tile(tile_index, player_id)
		if stop_result["stopped"]:
			print("[足どめ] ", stop_result["reason"])
			emit_signal("movement_step_completed", player_id, tile_index)
			break

		emit_signal("movement_step_completed", player_id, tile_index)
		previous_tile = tile_index
		i += 1


# 単一タイルへの移動
func move_to_tile(player_id: int, tile_index: int) -> void:
	if not tile_nodes.has(tile_index):
		print("[MovementController] move_to_tile: tile_nodes has no tile %d" % tile_index)
		return

	var player_node = player_nodes[player_id]
	var target_pos = tile_nodes[tile_index].global_position
	target_pos.y += MOVE_HEIGHT

	var tween = get_tree().create_tween()
	tween.set_parallel(true)

	tween.tween_property(player_node, "global_position", target_pos, MOVE_DURATION)

	if camera and player_system and player_id == player_system.current_player_index:
		var bs = game_flow_manager.board_system_3d if game_flow_manager else null
		var skip_follow = bs and bs.is_direction_camera_active()
		if not skip_follow:
			var cam_target = target_pos + GameConstants.CAMERA_OFFSET
			tween.tween_property(camera, "global_position", cam_target, MOVE_DURATION)

	await tween.finished


# === 方向・状態管理 ===

func _check_direction_choice_pending(player_id: int) -> bool:
	if not player_system:
		return false
	if player_id < 0 or player_id >= player_system.players.size():
		return false
	return player_system.players[player_id].buffs.get("direction_choice_pending", false)


func _consume_direction_choice(player_id: int) -> void:
	if not player_system:
		return
	if player_id < 0 or player_id >= player_system.players.size():
		return
	player_system.players[player_id].buffs.erase("direction_choice_pending")


func _get_tutorial_manager():
	if game_3d_ref:
		if game_3d_ref.has_node("TutorialManager"):
			return game_3d_ref.get_node("TutorialManager")
	return null


func _get_player_current_direction(player_id: int) -> int:
	if not player_system:
		return 1
	if player_id < 0 or player_id >= player_system.players.size():
		return 1
	return player_system.players[player_id].current_direction


func set_player_current_direction(player_id: int, direction: int) -> void:
	if not player_system:
		return
	if player_id < 0 or player_id >= player_system.players.size():
		return
	player_system.players[player_id].current_direction = direction


## プレイヤーの進行方向を反転（歩行逆転スペル用）
func reverse_player_direction(player_id: int) -> void:
	var current_dir = _get_player_current_direction(player_id)
	var new_dir = -current_dir if current_dir != 0 else -1
	set_player_current_direction(player_id, new_dir)
	print("[MovementController] プレイヤー%d の方向を反転: %d → %d" % [player_id + 1, current_dir, new_dir])


## 歩行逆転用: came_fromを「次に進む予定だったタイル」に変更
func swap_came_from_for_reverse(player_id: int) -> void:
	if player_id < 0 or player_id >= player_tiles.size():
		return

	var current_tile = player_tiles[player_id]
	var old_came_from = _get_player_came_from(player_id)

	var tile = tile_nodes.get(current_tile)
	if not tile or not tile.connections or tile.connections.is_empty():
		var direction = _get_player_current_direction(player_id)
		var next_tile = current_tile + direction
		_set_player_came_from(player_id, next_tile)
		print("[MovementController] プレイヤー%d came_from反転(no conn): %d → %d" % [player_id + 1, old_came_from, next_tile])
		return

	for conn in tile.connections:
		if conn != old_came_from:
			_set_player_came_from(player_id, conn)
			print("[MovementController] プレイヤー%d came_from反転: %d → %d" % [player_id + 1, old_came_from, conn])
			return

	print("[MovementController] プレイヤー%d came_from反転失敗: connections=%s" % [player_id + 1, tile.connections])


func _get_player_came_from(player_id: int) -> int:
	if not player_system:
		return -1
	if player_id < 0 or player_id >= player_system.players.size():
		return -1
	return player_system.players[player_id].came_from


func _set_player_came_from(player_id: int, tile: int) -> void:
	if not player_system:
		return
	if player_id < 0 or player_id >= player_system.players.size():
		return
	player_system.players[player_id].came_from = tile


## 歩行逆転呪いが解除された時に呼ばれる
func on_movement_reverse_curse_removed(player_id: int) -> void:
	swap_came_from_for_reverse(player_id)
	print("[MovementController] 歩行逆転呪い解除: プレイヤー%d came_fromを元に戻す" % [player_id + 1])


func _infer_direction_from_choice(current_tile: int, chosen_tile: int, player_id: int = -1) -> int:
	var pid = player_id if player_id >= 0 else current_moving_player

	if chosen_tile == current_tile + 1:
		return 1
	elif chosen_tile == current_tile - 1:
		return -1
	else:
		return _get_player_current_direction(pid)


func _has_movement_reverse_curse(player_id: int) -> bool:
	if not player_system:
		return false
	if player_id < 0 or player_id >= player_system.players.size():
		return false

	var curse = player_system.players[player_id].curse
	return curse.get("curse_type", "") == "movement_reverse"


# === 外部API（委譲） ===

# ワープ関連
func check_and_handle_warp(player_id: int, tile_index: int) -> Dictionary:
	return await warp_handler.check_and_handle_warp(player_id, tile_index)

func warp_player_3d(player_id: int, to_tile: int) -> void:
	await warp_handler.warp_player_3d(player_id, to_tile)

func execute_warp(player_id: int, from_tile: int, to_tile: int) -> void:
	await warp_handler.execute_warp(player_id, from_tile, to_tile)

# 特殊処理関連
func handle_start_pass(player_id: int):
	special_handler.handle_start_pass(player_id)

func check_and_handle_checkpoint(player_id: int, tile_index: int, previous_tile: int):
	await special_handler.check_and_handle_checkpoint(player_id, tile_index, previous_tile)

func place_player_at_tile(player_id: int, tile_index: int) -> void:
	special_handler.place_player_at_tile(player_id, tile_index)

func heal_all_creatures_for_player(player_id: int, heal_amount: int):
	special_handler.heal_all_creatures_for_player(player_id, heal_amount)

func clear_all_down_states_for_player(player_id: int) -> int:
	return special_handler.clear_all_down_states_for_player(player_id)

func focus_camera_on_player(player_id: int, smooth: bool = true) -> void:
	await special_handler.focus_camera_on_player(player_id, smooth)

func check_forced_stop_at_tile(tile_index: int, player_id: int) -> Dictionary:
	return warp_handler.check_forced_stop_at_tile(tile_index, player_id)

# ダイスバフ
func apply_dice_condition_buffs(player_id: int, dice_value: int):
	special_handler.apply_dice_condition_buffs(player_id, dice_value)

# 到着予測
func predict_all_destinations(start_tile: int, steps: int, came_from: int) -> Array:
	return destination_predictor.predict_all_destinations(start_tile, steps, came_from)

func update_destination_highlight():
	destination_predictor.update_destination_highlight_for_branch(
		branch_selector.is_active, branch_selector.available_branches,
		branch_selector.selected_branch_index, current_remaining_steps,
		branch_selector.current_branch_tile
	)

func clear_destination_highlight():
	destination_predictor.clear_destination_highlight()

# ユーティリティ
func is_player_moving() -> bool:
	return is_moving

func get_moving_player() -> int:
	return current_moving_player
