extends Node
class_name MovementController3D

# 3D移動制御システム
# プレイヤーの3D移動、カメラ追従、ワープ処理を管理

signal movement_started(player_id: int)
signal movement_step_completed(player_id: int, tile_index: int)
signal movement_completed(player_id: int, final_tile: int)
signal warp_executed(player_id: int, from_tile: int, to_tile: int)
signal start_passed(player_id: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# 移動設定
const MOVE_DURATION = 0.5  # 1マスの移動時間
const MOVE_HEIGHT = 1.0    # 駒の高さオフセット

# 参照
var tile_nodes = {}        # tile_index -> BaseTile
var player_nodes = []      # プレイヤー駒ノード配列
var player_tiles = []      # 各プレイヤーの現在位置
var camera = null          # Camera3D参照

# 状態
var is_moving = false
var current_moving_player = -1

# システム参照
var player_system: PlayerSystem = null
var special_tile_system: SpecialTileSystem = null
var game_flow_manager = null  # GameFlowManager参照（呪い削除用）
var spell_movement: SpellMovement = null  # 足どめ判定用
var spell_player_move = null  # 方向選択権判定用

# 方向選択状態（タイプA: ゲームスタート/ワープ後）
var is_direction_selection_active: bool = false
var selected_direction: int = 1
var available_directions: Array = []
signal direction_selected(direction: int)

# 分岐選択状態（タイプB: 移動中の分岐点）
var is_branch_selection_active: bool = false
var selected_branch_index: int = 0
var available_branches: Array = []  # タイル番号のリスト
signal branch_selected(tile_index: int)

func _ready():
	pass

# 初期化
func initialize(tiles: Dictionary, players: Array, cam: Camera3D = null):
	tile_nodes = tiles
	player_nodes = players
	camera = cam
	
	# 初期位置配列を作成
	player_tiles.clear()
	for i in range(player_nodes.size()):
		player_tiles.append(0)

# システム参照を設定
func setup_systems(p_system: PlayerSystem, st_system: SpecialTileSystem = null, gf_manager = null):
	player_system = p_system
	
	# SpellMovementを初期化
	spell_movement = SpellMovement.new()
	if gf_manager and gf_manager.creature_manager:
		spell_movement.setup(gf_manager.creature_manager, null)
	special_tile_system = st_system
	game_flow_manager = gf_manager

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
		return
	
	is_moving = true
	current_moving_player = player_id
	emit_signal("movement_started", player_id)
	
	# ダイス条件バフをチェックして適用（移動前）
	if dice_value > 0:
		apply_dice_condition_buffs(player_id, dice_value)
	
	# 方向選択権チェック
	var has_direction_choice = _check_direction_choice_pending(player_id)
	
	# 歩行逆転呪いチェック
	var is_reversed = _has_movement_reverse_curse(player_id)
	if is_reversed:
		print("[MovementController] 歩行逆転中: プレイヤー%d" % (player_id + 1))
	
	if has_direction_choice:
		# 現在位置の接続情報をチェック
		var current_tile = player_tiles[player_id]
		var came_from = _get_player_came_from(player_id)
		var first_tile = await _select_first_tile(current_tile, came_from)
		
		# 歩行逆転呪いがある場合、first_tileを逆転（current_directionは変更しない）
		if is_reversed:
			var direction = _get_player_current_direction(player_id)
			var reversed_direction = -direction
			# first_tileを再計算（分岐点でない場合）
			var tile = tile_nodes.get(current_tile)
			if not tile or not tile.connections or tile.connections.is_empty():
				var loop_size = _get_loop_size()
				first_tile = (current_tile + reversed_direction + loop_size) % loop_size
			print("[MovementController] 歩行逆転適用: first_tile=タイル%d" % first_tile)
		
		# came_fromを更新して方向選択権を消費
		_set_player_came_from(player_id, current_tile)
		_consume_direction_choice(player_id)
		
		# 移動実行（1歩ずつ、分岐があれば都度選択）
		await _move_steps_with_branch(player_id, steps, first_tile, is_reversed)
	else:
		# 方向選択権がない場合は came_from ベースで自動進行
		await _move_steps_with_branch(player_id, steps, -1, is_reversed)
	
	# 最終位置を取得
	var final_tile = player_tiles[player_id]
	
	is_moving = false
	current_moving_player = -1
	
	emit_signal("movement_completed", player_id, final_tile)

# 1歩ずつ移動（分岐があれば選択）
# is_reversed: 歩行逆転呪いが有効な場合true（移動計算時に方向を逆転）
func _move_steps_with_branch(player_id: int, steps: int, first_tile: int = -1, is_reversed: bool = false) -> void:
	var current_tile = player_tiles[player_id]
	var came_from = _get_player_came_from(player_id)
	
	for step in range(steps):
		var next_tile: int
		
		if step == 0 and first_tile >= 0:
			# 最初の1歩は指定タイル
			next_tile = first_tile
		else:
			# 次のタイルを決定
			next_tile = await _get_next_tile_with_branch(current_tile, came_from, player_id, is_reversed)
		
		# 移動前のチェック
		if next_tile == 0 and current_tile > next_tile:
			handle_start_pass(player_id)
		check_and_handle_checkpoint(player_id, next_tile, current_tile)
		
		# タイルへ移動
		await move_to_tile(player_id, next_tile)
		
		# 状態を更新
		came_from = current_tile
		current_tile = next_tile
		player_tiles[player_id] = next_tile
		_set_player_came_from(player_id, came_from)
		
		# ワープチェック
		var warp_result = await check_and_handle_warp(player_id, next_tile)
		if warp_result.warped:
			current_tile = warp_result.new_tile
			player_tiles[player_id] = current_tile
			came_from = next_tile  # ワープ元がcame_from
			_set_player_came_from(player_id, came_from)
		
		# 足どめチェック
		var stop_result = check_forced_stop_at_tile(current_tile, player_id)
		if stop_result["stopped"]:
			print("[足どめ] ", stop_result["reason"])
			emit_signal("movement_step_completed", player_id, current_tile)
			break
		
		emit_signal("movement_step_completed", player_id, current_tile)

# ループサイズを動的に計算（connectionsが空のタイルの最大インデックス+1）
func _get_loop_size() -> int:
	var max_normal_tile = -1
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		# connectionsが空 = 通常タイル（ループの一部）
		if tile.connections.is_empty():
			max_normal_tile = max(max_normal_tile, tile_index)
	# 最大の通常タイル + 1 がループサイズ
	# 例: タイル1-19が通常 → 最大19 → ループ=20
	if max_normal_tile >= 0:
		return max_normal_tile + 1
	else:
		return tile_nodes.size()

# 次のタイルを取得（分岐があれば選択UI）
# is_reversed: 歩行逆転呪いが有効な場合true（current_directionは変更しない）
func _get_next_tile_with_branch(current_tile: int, came_from: int, player_id: int, is_reversed: bool = false) -> int:
	var tile = tile_nodes.get(current_tile)
	
	# connectionsがなければループ内移動
	if not tile or not tile.connections or tile.connections.is_empty():
		var direction = _get_player_current_direction(player_id)
		# 歩行逆転呪いがある場合は方向を逆転
		if is_reversed:
			direction = -direction
		var loop_size = _get_loop_size()
		return (current_tile + direction + loop_size) % loop_size
	
	# connectionsがある場合：came_fromを除外
	var choices = []
	for conn in tile.connections:
		if conn != came_from:
			choices.append(conn)
	
	# 選択肢がなければ来た方向に戻る（行き止まり）
	if choices.is_empty():
		print("[MovementController] 行き止まり: タイル%dに戻る" % came_from)
		return came_from
	
	var chosen: int
	# 選択肢が1つなら自動選択
	if choices.size() == 1:
		chosen = choices[0]
	else:
		# 選択肢が2つ以上なら選択UI
		chosen = await _show_branch_tile_selection(choices)
	
	# 選んだタイルから方向を推測して設定
	var inferred_direction = _infer_direction_from_choice(current_tile, chosen, player_id)
	_set_player_current_direction(player_id, inferred_direction)
	print("[MovementController] 移動中分岐: タイル%d → 方向%s" % [chosen, "+" if inferred_direction > 0 else "-"])
	
	return chosen

# 最初の1歩を選択（分岐点の場合）
func _select_first_tile(current_tile: int, came_from: int) -> int:
	var tile = tile_nodes.get(current_tile)
	
	# connectionsがなければ+1/-1選択
	if not tile or not tile.connections or tile.connections.is_empty():
		var selected_dir = await _show_simple_direction_selection()
		_set_player_current_direction(current_moving_player, selected_dir)
		var first_loop_size = _get_loop_size()
		return (current_tile + selected_dir + first_loop_size) % first_loop_size
	
	# connectionsがある場合：came_fromを除外して選択
	var choices = []
	for conn in tile.connections:
		if conn != came_from:
			choices.append(conn)
	
	# 選択肢がなければ来た方向
	if choices.is_empty():
		return came_from
	
	var chosen: int
	# 選択肢が1つなら自動
	if choices.size() == 1:
		chosen = choices[0]
	else:
		# 選択肢が2つ以上なら選択UI
		chosen = await _show_branch_tile_selection(choices)
	
	# 選んだタイルから方向を推測して設定
	var inferred_dir = _infer_direction_from_choice(current_tile, chosen)
	_set_player_current_direction(current_moving_player, inferred_dir)
	print("[MovementController] 分岐選択: タイル%d → 方向%s" % [chosen, "+" if inferred_dir > 0 else "-"])
	
	return chosen

# 方向選択UIを表示
func _show_direction_selection(directions: Array) -> int:
	is_direction_selection_active = true
	available_directions = directions
	selected_direction = directions[0]  # 初期選択
	
	print("[MovementController] 方向選択: ↑↓キーで選択、Enterで確定")
	_update_direction_selection_ui()
	
	# 選択完了を待つ
	var result = await direction_selected
	is_direction_selection_active = false
	
	return result

# 方向選択UIを更新
func _update_direction_selection_ui():
	if game_flow_manager and game_flow_manager.ui_manager:
		var dir_text = "順方向 →" if selected_direction == 1 else "← 逆方向"
		game_flow_manager.ui_manager.phase_label.text = "移動方向を選択: [↑↓] %s [Enter確定]" % dir_text

# シンプルな方向選択（+1 か -1 を選ぶ）
func _show_simple_direction_selection() -> int:
	is_direction_selection_active = true
	available_directions = [1, -1]
	selected_direction = 1  # デフォルトは順方向
	
	print("[MovementController] 方向選択: ↑↓キーで選択、Enter確定")
	_update_direction_selection_ui()
	
	var result = await direction_selected
	is_direction_selection_active = false
	
	return result

# 方向選択権（buffs）をチェック
func _check_direction_choice_pending(player_id: int) -> bool:
	if not player_system:
		return false
	if player_id < 0 or player_id >= player_system.players.size():
		return false
	return player_system.players[player_id].buffs.get("direction_choice_pending", false)

# 方向選択権を消費
func _consume_direction_choice(player_id: int) -> void:
	if not player_system:
		return
	if player_id < 0 or player_id >= player_system.players.size():
		return
	player_system.players[player_id].buffs.erase("direction_choice_pending")
	print("[MovementController] プレイヤー%d: 方向選択権を消費" % (player_id + 1))

# プレイヤーの現在の移動方向を取得
func _get_player_current_direction(player_id: int) -> int:
	if not player_system:
		return 1
	if player_id < 0 or player_id >= player_system.players.size():
		return 1
	return player_system.players[player_id].current_direction

# プレイヤーの移動方向を設定
func _set_player_current_direction(player_id: int, direction: int) -> void:
	if not player_system:
		return
	if player_id < 0 or player_id >= player_system.players.size():
		return
	player_system.players[player_id].current_direction = direction
	print("[MovementController] プレイヤー%d: 移動方向を%sに設定" % [player_id + 1, "順方向" if direction == 1 else "逆方向"])

# プレイヤーのcame_from（前にいたタイル）を取得
func _get_player_came_from(player_id: int) -> int:
	if not player_system:
		return -1
	if player_id < 0 or player_id >= player_system.players.size():
		return -1
	return player_system.players[player_id].came_from

# プレイヤーのcame_fromを設定
func _set_player_came_from(player_id: int, tile: int) -> void:
	if not player_system:
		return
	if player_id < 0 or player_id >= player_system.players.size():
		return
	player_system.players[player_id].came_from = tile

# 選んだタイルから方向を推測
func _infer_direction_from_choice(current_tile: int, chosen_tile: int, player_id: int = -1) -> int:
	var loop_size = _get_loop_size()
	var pid = player_id if player_id >= 0 else current_moving_player
	
	# 選んだタイルがループ外（分岐先）の場合は現在の方向を維持
	if chosen_tile >= loop_size:
		return _get_player_current_direction(pid)
	
	# ループ内の場合、どちらの方向かを推測
	var next_plus = (current_tile + 1) % loop_size
	var next_minus = (current_tile - 1 + loop_size) % loop_size
	
	if chosen_tile == next_plus:
		return 1
	elif chosen_tile == next_minus:
		return -1
	else:
		# どちらでもない場合は現在の方向を維持
		return _get_player_current_direction(pid)

# 入力処理（方向選択・分岐タイル選択用）
func _input(event):
	# 方向選択（+1/-1）
	if is_direction_selection_active:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
				# 方向を切り替え
				if available_directions.size() > 1:
					var current_idx = available_directions.find(selected_direction)
					current_idx = (current_idx + 1) % available_directions.size()
					selected_direction = available_directions[current_idx]
					_update_direction_selection_ui()
				get_viewport().set_input_as_handled()
			
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				# 確定
				print("[MovementController] 方向選択確定: %s" % ("順方向" if selected_direction == 1 else "逆方向"))
				direction_selected.emit(selected_direction)
				get_viewport().set_input_as_handled()
		return
	
	# 分岐タイル選択（タイル番号から選ぶ）
	if is_branch_selection_active:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_LEFT:
				selected_branch_index = (selected_branch_index - 1 + available_branches.size()) % available_branches.size()
				_update_branch_selection_ui()
				get_viewport().set_input_as_handled()
			
			elif event.keycode == KEY_RIGHT:
				selected_branch_index = (selected_branch_index + 1) % available_branches.size()
				_update_branch_selection_ui()
				get_viewport().set_input_as_handled()
			
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				var selected_tile = available_branches[selected_branch_index]
				print("[MovementController] 分岐タイル選択確定: タイル%d" % selected_tile)
				branch_selected.emit(selected_tile)
				get_viewport().set_input_as_handled()
		return
	


# 移動経路を計算（シンプル版：direction方向にsteps歩進む）
func calculate_path(player_id: int, steps: int, direction: int = 1) -> Array:
	var path = []
	var current_tile = player_tiles[player_id]
	var loop_size = _get_loop_size()
	
	# 歩行逆転呪いをチェックして方向に反映
	var final_direction = direction
	if _has_movement_reverse_curse(player_id):
		final_direction = -direction
		print("[MovementController] 歩行逆転中: プレイヤー%d" % (player_id + 1))
	
	for i in range(steps):
		# 単純に direction 方向に進む
		current_tile = (current_tile + final_direction + loop_size) % loop_size
		path.append(current_tile)
	
	print("[MovementController] 経路計算: 方向=%d, 経路=%s" % [final_direction, str(path)])
	return path

# 次のタイルを取得（connectionsベース or 従来計算）
func _get_next_tile(current_tile: int, direction: int, came_from: int) -> int:
	var tile = tile_nodes.get(current_tile)
	var loop_size = _get_loop_size()
	
	if not tile:
		# タイルがなければループ計算
		return (current_tile + direction + loop_size) % loop_size
	
	# connectionsが設定されていれば接続情報ベース
	if tile.connections and not tile.connections.is_empty():
		return _get_next_from_connections(tile.connections, came_from, direction)
	
	# 設定されていなければループ計算
	return (current_tile + direction + loop_size) % loop_size

# 接続情報から次のタイルを取得（分岐選択UIあり）
func _get_next_from_connections(connections: Array, came_from: int, direction: int) -> int:
	# 来た方向を除外
	var choices = connections.filter(func(n): return n != came_from)
	
	# 選択肢がなければ来た方向に戻る（行き止まり）
	if choices.is_empty():
		print("[MovementController] 行き止まり: タイル%dに戻る" % came_from)
		return came_from
	
	# 選択肢が1つなら自動選択
	if choices.size() == 1:
		return choices[0]
	
	# 複数の場合：方向に基づいてデフォルト選択（calculate_path用）
	# move_along_path内では_show_branch_selectionを使う
	choices.sort()
	if direction > 0:
		return choices[-1]  # 最大値
	else:
		return choices[0]   # 最小値

# 分岐タイル選択UIを表示して選択を待つ
func _show_branch_tile_selection(choices: Array) -> int:
	is_branch_selection_active = true
	available_branches = choices
	selected_branch_index = 0
	
	print("[MovementController] 分岐タイル選択: %s から選択 [←→キーで選択、Enter確定]" % str(choices))
	_update_branch_selection_ui()
	
	var result = await branch_selected
	is_branch_selection_active = false
	
	return result

# 分岐/方向選択UI更新（共用）
func _update_branch_selection_ui():
	if game_flow_manager and game_flow_manager.ui_manager:
		var choices_text = ""
		for i in range(available_branches.size()):
			var tile_num = available_branches[i]
			if i == selected_branch_index:
				choices_text += "[→タイル%d←] " % tile_num
			else:
				choices_text += " タイル%d " % tile_num
		game_flow_manager.ui_manager.phase_label.text = "進む方向を選択: %s [←→] [Enter確定]" % choices_text

# 分岐チェックと処理（Dictionary形式：{タイル番号: 方向}から選ぶ）
func _check_and_handle_branch(current_tile: int, _came_from: int, path: Array, current_index: int) -> Dictionary:
	var tile = tile_nodes.get(current_tile)
	if not tile:
		return {"recalculated": false}
	
	# connectionsが設定されていなければスキップ（分岐点ではない）
	if not tile.connections or tile.connections.is_empty():
		return {"recalculated": false}
	
	var choices = tile.connections.keys()  # 選択可能なタイル番号
	var new_direction: int
	var first_tile: int
	
	if choices.size() >= 2:
		# 選択肢が2つ以上 → UIで選択
		first_tile = await _show_branch_tile_selection(choices)
		new_direction = tile.connections[first_tile]
	else:
		# 選択肢が1つ → 自動選択（行き止まり）
		first_tile = choices[0]
		new_direction = tile.connections[first_tile]
		print("[MovementController] 行き止まり: タイル%d方向(%s)に自動選択" % [first_tile, "+" if new_direction > 0 else "-"])
	
	# 方向を保存
	if current_moving_player >= 0:
		_set_player_current_direction(current_moving_player, new_direction)
	
	# 残りの経路を再計算（最初の1歩は選択したタイル、以降は方向で進む）
	var remaining_steps = path.size() - current_index - 1
	var new_path = path.slice(0, current_index + 1)  # 現在位置まで
	
	if remaining_steps > 0:
		new_path.append(first_tile)  # 最初の1歩は選択したタイル
		var loop_size = _get_loop_size()
		var current = first_tile
		for j in range(remaining_steps - 1):
			current = (current + new_direction + loop_size) % loop_size
			new_path.append(current)
	
	print("[MovementController] 分岐後の経路: 方向=%d, %s" % [new_direction, str(new_path)])
	return {"recalculated": true, "new_path": new_path}

# 歩行逆転呪いを持っているかチェック
func _has_movement_reverse_curse(player_id: int) -> bool:
	if not player_system:
		return false
	if player_id < 0 or player_id >= player_system.players.size():
		return false
	
	var curse = player_system.players[player_id].curse
	return curse.get("curse_type", "") == "movement_reverse"

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
		
		# スタート通過チェック
		if tile_index == 0 and previous_tile > tile_index:
			handle_start_pass(player_id)
		
		# チェックポイント通過チェック
		check_and_handle_checkpoint(player_id, tile_index, previous_tile)
		
		# タイルへ移動
		await move_to_tile(player_id, tile_index)
		
		# 位置を更新
		player_tiles[player_id] = tile_index
		
		# 分岐チェック（残り歩数がある場合のみ）
		if i < path.size() - 1:
			var branch_result = await _check_and_handle_branch(tile_index, previous_tile, path, i)
			if branch_result.recalculated:
				# 経路が再計算された
				path = branch_result.new_path
		
		# 通過型ワープチェック（ビジュアルエフェクトのみ）
		var warp_result = await check_and_handle_warp(player_id, tile_index)
		if warp_result.warped:
			# ワープ発生：経路を修正する
			var warped_tile = warp_result.new_tile
			player_tiles[player_id] = warped_tile
			
			# 経路の残りを再計算（ワープ先から続ける）
			var new_path = [warped_tile]  # ワープ先
			var current = warped_tile
			var came_from = tile_index  # ワープ元
			for j in range(i + 1, path.size()):
				var next = _get_next_tile(current, 1, came_from)
				came_from = current
				current = next
				new_path.append(current)
			
			# 経路を置き換え
			for j in range(new_path.size()):
				if i + j + 1 < path.size():
					path[i + j + 1] = new_path[j]
				else:
					path.append(new_path[j])
			
			tile_index = warped_tile
		
		# 足どめ判定（呪い・スキル）
		var stop_result = check_forced_stop_at_tile(tile_index, player_id)
		if stop_result["stopped"]:
			print("[足どめ] ", stop_result["reason"])
			emit_signal("movement_step_completed", player_id, tile_index)
			# 残りの移動をキャンセル
			break
		
		emit_signal("movement_step_completed", player_id, tile_index)
		previous_tile = tile_index
		i += 1

# 単一タイルへの移動
func move_to_tile(player_id: int, tile_index: int) -> void:
	if not tile_nodes.has(tile_index):
		return
	
	var player_node = player_nodes[player_id]
	var target_pos = tile_nodes[tile_index].global_position
	target_pos.y += MOVE_HEIGHT
	
	# Tweenで滑らかな移動
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# プレイヤー駒を移動
	tween.tween_property(player_node, "global_position", target_pos, MOVE_DURATION)
	
	# カメラを追従（現在のプレイヤーのみ）
	if camera and player_system and player_id == player_system.current_player_index:
		var cam_target = target_pos + GameConstants.CAMERA_OFFSET
		tween.tween_property(camera, "global_position", cam_target, MOVE_DURATION)
	
	# Tweenの完了を待つ
	await tween.finished
	
	# カメラをプレイヤーに向ける（移動完了後に実行）
	if camera and player_system and player_id == player_system.current_player_index:
		camera.look_at(target_pos + Vector3(0, 1.0, 0), Vector3.UP)

# === ワープ処理 ===

# ワープをチェックして処理
func check_and_handle_warp(player_id: int, tile_index: int) -> Dictionary:
	if not special_tile_system:
		return {"warped": false}
	
	# 通過型ワープかチェック
	if special_tile_system.is_warp_gate(tile_index):
		var warp_pair = special_tile_system.get_warp_pair(tile_index)
		if warp_pair != -1 and warp_pair != tile_index:
			await execute_warp(player_id, tile_index, warp_pair)
			return {"warped": true, "new_tile": warp_pair}
	
	return {"warped": false}

# ワープを実行（3D版）
func warp_player_3d(player_id: int, to_tile: int) -> void:
	if player_id >= player_nodes.size() or not tile_nodes.has(to_tile):
		return
	
	var from_tile = player_tiles[player_id]
	await execute_warp(player_id, from_tile, to_tile)
	player_tiles[player_id] = to_tile

# ワープアニメーション実行
func execute_warp(player_id: int, from_tile: int, to_tile: int) -> void:
	
	var player_node = player_nodes[player_id]
	
	# ワープエフェクト（簡易版：縮小して消える→移動→拡大して現れる）
	# 注意: Vector3.ZEROだとTransform3D.invert()でエラーが出るため極小値を使用
	const WARP_MIN_SCALE = Vector3(0.001, 0.001, 0.001)
	var tween = get_tree().create_tween()
	
	# 縮小して消える（ほぼゼロまで）
	tween.tween_property(player_node, "scale", WARP_MIN_SCALE, 0.2)
	
	# 瞬間移動
	await tween.finished
	if tile_nodes.has(to_tile):
		var target_pos = tile_nodes[to_tile].global_position
		target_pos.y += MOVE_HEIGHT
		player_node.global_position = target_pos
		
		# カメラも瞬間移動
		if camera and player_system and player_id == player_system.current_player_index:
			var cam_target = target_pos + GameConstants.CAMERA_OFFSET
			camera.global_position = cam_target
	
	# 拡大して現れる
	var tween2 = get_tree().create_tween()
	tween2.tween_property(player_node, "scale", Vector3.ONE, 0.2)
	await tween2.finished
	
	emit_signal("warp_executed", player_id, from_tile, to_tile)

# === 特殊処理 ===

# スタート地点通過処理（特別な効果なし、周回完了ボーナスは_complete_lapで処理）
func handle_start_pass(player_id: int):
	emit_signal("start_passed", player_id)

# チェックポイント通過処理
func check_and_handle_checkpoint(player_id: int, tile_index: int, previous_tile: int):
	if not tile_nodes.has(tile_index):
		return
	
	var tile = tile_nodes[tile_index]
	
	# CheckpointTileかチェック
	if tile.has_signal("checkpoint_passed"):
		# タイル0は2回目以降のみ通過扱い（previous_tile > tile_indexで判定）
		if tile_index == 0 and previous_tile <= tile_index:
			return
		
		# CheckpointTileのon_player_passedを呼ぶ
		if tile.has_method("on_player_passed"):
			tile.on_player_passed(player_id)

# 特定タイルへ直接配置（初期配置用）
func place_player_at_tile(player_id: int, tile_index: int) -> void:
	if player_id >= player_nodes.size() or not tile_nodes.has(tile_index):
		return
	
	var player_node = player_nodes[player_id]
	var target_pos = tile_nodes[tile_index].global_position
	target_pos.y += MOVE_HEIGHT
	
	# オフセットを追加（プレイヤーごとに少しずらす）
	target_pos.x += player_id * 0.5
	
	player_node.global_position = target_pos
	player_tiles[player_id] = tile_index

# 全クリーチャーのHP回復
func heal_all_creatures_for_player(player_id: int, heal_amount: int):
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.creature_data:
			var creature = tile.creature_data
			
			# MHP計算
			var base_hp = creature.get("hp", 0)  # 元のHP（不変）
			var base_up_hp = creature.get("base_up_hp", 0)  # 永続ボーナス
			var max_hp = base_hp + base_up_hp
			
			# 現在HP取得（ない場合は満タン）
			var current_hp = creature.get("current_hp", max_hp)
			
			# HP回復（MHPを超えない）
			var new_hp = min(current_hp + heal_amount, max_hp)
			creature["current_hp"] = new_hp

# Phase 1-A: プレイヤーの全土地のダウン状態をクリア
func clear_all_down_states_for_player(player_id: int):
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.has_method("is_down") and tile.is_down():
			tile.clear_down_state()

# カメラをプレイヤーにフォーカス
func focus_camera_on_player(player_id: int, smooth: bool = true) -> void:
	if not camera or player_id >= player_nodes.size():
		return
	
	var player_node = player_nodes[player_id]
	if not player_node:
		return
		
	var target_pos = player_node.global_position + GameConstants.CAMERA_OFFSET
	
	if smooth:
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "global_position", target_pos, 0.8)
		await tween.finished
	else:
		camera.global_position = target_pos

# === 足どめ判定 ===

## タイルでの足どめ判定（SpellMovement経由）
func check_forced_stop_at_tile(tile_index: int, player_id: int) -> Dictionary:
	if not spell_movement:
		return {"stopped": false, "reason": "", "source_type": ""}
	
	# tile_nodesを直接渡す
	return spell_movement.check_forced_stop_with_tiles(tile_index, player_id, tile_nodes)

# === ユーティリティ ===

# 移動中かチェック
func is_player_moving() -> bool:
	return is_moving

# 移動中のプレイヤーIDを取得
func get_moving_player() -> int:
	return current_moving_player

# === ダイス条件バフ処理 ===

# ダイス条件に基づく永続バフを適用
func apply_dice_condition_buffs(player_id: int, dice_value: int):
	if not tile_nodes:
		return
	
	# プレイヤーの配置クリーチャーをチェック
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and tile.creature_data:
			_check_and_apply_dice_buff(tile.creature_data, dice_value)

# 個別クリーチャーのダイス条件バフをチェック・適用
func _check_and_apply_dice_buff(creature_data: Dictionary, dice_value: int):
	if not creature_data.has("ability_parsed"):
		return
	
	var effects = creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "dice_condition_bonus":
			_apply_dice_condition_effect(creature_data, effect, dice_value)

# ダイス条件効果を適用
func _apply_dice_condition_effect(creature_data: Dictionary, effect: Dictionary, dice_value: int):
	var dice_check = effect.get("dice_check", {})
	var operator = dice_check.get("operator", "<=")
	var threshold = dice_check.get("value", 3)
	
	# 条件チェック
	var condition_met = false
	match operator:
		"<=":
			condition_met = dice_value <= threshold
		">=":
			condition_met = dice_value >= threshold
		"==":
			condition_met = dice_value == threshold
		"<":
			condition_met = dice_value < threshold
		">":
			condition_met = dice_value > threshold
	
	if not condition_met:
		return
	
	# 永続バフを適用
	var stat_changes = effect.get("stat_changes", {})
	
	if stat_changes.has("ap"):
		if not creature_data.has("base_up_ap"):
			creature_data["base_up_ap"] = 0
		creature_data["base_up_ap"] += stat_changes["ap"]
		print("[Dice Buff] ", creature_data.get("name", ""), " ST+", stat_changes["ap"], 
			  " (ダイス: ", dice_value, ")")
	
	if stat_changes.has("max_hp"):
		if not creature_data.has("base_up_hp"):
			creature_data["base_up_hp"] = 0
		creature_data["base_up_hp"] += stat_changes["max_hp"]
		
		# 現在HPも増加（MHPが増えた分だけ）
		var base_hp = creature_data.get("hp", 0)
		var base_up_hp = creature_data["base_up_hp"]
		var max_hp = base_hp + base_up_hp
		var current_hp = creature_data.get("current_hp", max_hp)
		
		# HP回復（増えたMHP分）
		var new_hp = min(current_hp + stat_changes["max_hp"], max_hp)
		creature_data["current_hp"] = new_hp
		
		print("[Dice Buff] ", creature_data.get("name", ""), " MHP+", stat_changes["max_hp"],
			  " HP: ", current_hp, " → ", new_hp, " / ", max_hp,
			  " (ダイス: ", dice_value, ")")
