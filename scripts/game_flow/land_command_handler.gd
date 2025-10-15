# LandCommandHandler - 領地コマンドの処理を担当
extends Node
class_name LandCommandHandler

## シグナル
signal land_command_opened()
signal land_command_closed()
signal land_selected(tile_index: int)
signal action_selected(action_type: String)

## 状態
enum State {
	CLOSED,              # 領地コマンド非表示
	SELECTING_LAND,      # 土地選択中
	SELECTING_ACTION,    # アクション選択中
	SELECTING_MOVE_DEST  # 移動先選択中
}

var current_state: State = State.CLOSED
var selected_tile_index: int = -1
var player_owned_lands: Array = []

# Phase 1-A: 選択マーカー
var selection_marker: MeshInstance3D = null

# Phase 1-A: 移動先選択
var move_source_tile: int = -1  # 移動元タイル
var move_destinations: Array = []  # 移動可能な隣接タイル
var current_destination_index: int = 0  # 現在選択中の移動先インデックス

## 参照
var ui_manager = null
var board_system = null
var game_flow_manager = null
var player_system = null

func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	rotate_selection_marker(delta)

## 初期化
func initialize(ui_mgr, board_sys, flow_mgr, player_sys = null):
	ui_manager = ui_mgr
	board_system = board_sys
	game_flow_manager = flow_mgr
	player_system = player_sys
	
	# player_systemが渡されない場合はboard_systemから取得
	if not player_system and board_system:
		player_system = board_system.player_system
	
	# Phase 1-A: UIManagerのシグナルを接続
	if ui_manager and ui_manager.has_signal("level_up_selected"):
		ui_manager.level_up_selected.connect(_on_level_up_selected)
	
	print("[LandCommandHandler] 参照を設定しました")

## 領地コマンドを開く
func open_land_command(player_id: int):
	if current_state != State.CLOSED:
		print("[LandCommandHandler] 既に開いています")
		return
	
	# プレイヤーの所有地を取得
	player_owned_lands = get_player_owned_lands(player_id)
	
	if player_owned_lands.is_empty():
		print("[LandCommandHandler] 所有地がありません")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "所有地がありません"
		return
	
	# 土地選択モードに移行
	current_state = State.SELECTING_LAND
	land_command_opened.emit()
	
	print("[LandCommandHandler] 領地コマンドを開きました（所有地数: ", player_owned_lands.size(), "）")
	
	# UIに表示要請
	if ui_manager and ui_manager.has_method("show_land_selection_mode"):
		ui_manager.show_land_selection_mode(player_owned_lands)

## 土地選択
func select_land(tile_index: int) -> bool:
	if current_state != State.SELECTING_LAND:
		print("[LandCommandHandler] 土地選択モードではありません")
		return false
	
	# 所有地かチェック
	if tile_index not in player_owned_lands:
		print("[LandCommandHandler] 所有していない土地です: ", tile_index)
		return false
	
	# ダウン状態チェック（二重チェック）
	if board_system and board_system.tile_nodes.has(tile_index):
		var tile = board_system.tile_nodes[tile_index]
		if tile.has_method("is_down") and tile.is_down():
			print("[LandCommandHandler] この土地はダウン状態です: ", tile_index)
			return false
	
	selected_tile_index = tile_index
	current_state = State.SELECTING_ACTION
	land_selected.emit(tile_index)
	
	print("[LandCommandHandler] 土地を選択: ", tile_index)
	
	# Phase 1-A: 選択マーカーを表示
	show_selection_marker(tile_index)
	
	# Phase 1-A: 選択した土地にカメラをフォーカス
	focus_camera_on_tile(tile_index)
	
	# アクション選択UIを表示（Phase 1-A: 新UIパネル）
	if ui_manager and ui_manager.has_method("show_action_menu"):
		ui_manager.show_action_menu(tile_index)
	
	return true

## アクション実行
func execute_action(action_type: String) -> bool:
	if current_state != State.SELECTING_ACTION:
		print("[LandCommandHandler] アクション選択モードではありません")
		return false
	
	if selected_tile_index == -1:
		print("[LandCommandHandler] 土地が選択されていません")
		return false
	
	print("[LandCommandHandler] アクション実行: ", action_type, " on tile ", selected_tile_index)
	
	match action_type:
		"level_up":
			return execute_level_up()
		"move_creature":
			return execute_move_creature()
		"swap_creature":
			return execute_swap_creature()
		_:
			print("[LandCommandHandler] 不明なアクション: ", action_type)
			return false

## レベルアップ実行（レベル選択後）
func execute_level_up_with_level(target_level: int, cost: int) -> bool:
	if not board_system or selected_tile_index == -1:
		return false
	
	if not board_system.tile_nodes.has(selected_tile_index):
		return false
	
	var tile = board_system.tile_nodes[selected_tile_index]
	var player_system = game_flow_manager.player_system if game_flow_manager else null
	var current_player = player_system.get_current_player() if player_system else null
	
	if not current_player:
		return false
	
	# 魔力チェック
	if current_player.magic_power < cost:
		print("[LandCommandHandler] 魔力不足: 必要%d / 所持%d" % [cost, current_player.magic_power])
		return false
	
	# 魔力消費
	player_system.add_magic(current_player.id, -cost)
	
	# レベルアップ実行
	tile.level = target_level
	
	# ダウン状態設定
	if tile.has_method("set_down_state"):
		tile.set_down_state(true)
	
	# UI更新
	if ui_manager:
		ui_manager.update_player_info_panels()
	
	print("[LandCommandHandler] レベルアップ完了: tile ", selected_tile_index, " -> Lv.", target_level)
	
	# 領地コマンドを閉じる
	close_land_command()
	
	# ターン終了
	if game_flow_manager and game_flow_manager.has_method("end_turn"):
		game_flow_manager.end_turn()
	
	return true

## レベルアップ実行
func execute_level_up() -> bool:
	if not board_system:
		return false
	
	# Phase 1-A修正: board_system.get_tile()ではなくtile_nodesを使用
	if not board_system.tile_nodes.has(selected_tile_index):
		print("[LandCommandHandler] タイルが見つかりません: ", selected_tile_index)
		return false
	
	var tile = board_system.tile_nodes[selected_tile_index]
	
	# 最大レベルチェック
	if tile.level >= 5:
		print("[LandCommandHandler] 既に最大レベルです")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "既に最大レベルです"
		return false
	
	# Phase 1-A: レベル選択UIを表示
	if ui_manager and ui_manager.has_method("show_level_selection"):
		var player_system = game_flow_manager.player_system if game_flow_manager else null
		var current_player = player_system.get_current_player() if player_system else null
		var player_magic = current_player.magic_power if current_player else 0
		
		ui_manager.show_level_selection(selected_tile_index, tile.level, player_magic)
	
	return true

## クリーチャー移動実行
func execute_move_creature() -> bool:
	# 移動元を保存
	move_source_tile = selected_tile_index
	
	# 移動先選択モードに移行
	current_state = State.SELECTING_MOVE_DEST
	
	print("[LandCommandHandler] 移動先選択モードに移行")
	
	# 移動可能な隣接マスを取得
	move_destinations = get_adjacent_tiles(selected_tile_index)
	
	print("[LandCommandHandler] 移動可能なマス: ", move_destinations)
	
	# 移動先が存在しない場合
	if move_destinations.is_empty():
		print("[LandCommandHandler] 移動可能なマスがありません")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "移動可能なマスがありません"
		# アクション選択に戻る
		current_state = State.SELECTING_ACTION
		return false
	
	# 最初の移動先を選択
	current_destination_index = 0
	var first_dest = move_destinations[current_destination_index]
	
	# マーカーを最初の移動先に表示
	show_selection_marker(first_dest)
	focus_camera_on_tile(first_dest)
	
	# UIを更新（移動先選択画面を表示）
	update_move_destination_ui()
	
	return true

## 移動先選択UIを更新
func update_move_destination_ui():
	if not ui_manager or not ui_manager.phase_label:
		return
	
	if move_destinations.is_empty():
		ui_manager.phase_label.text = "移動可能なマスがありません"
		return
	
	var current_tile = move_destinations[current_destination_index]
	var text = "移動先を選択: [↑↓で切替]
"
	text += "移動先 " + str(current_destination_index + 1) + "/" + str(move_destinations.size()) + ": "
	text += "タイル" + str(current_tile) + "
"
	text += "[Enter: 確定] [C: 戻る]"
	
	ui_manager.phase_label.text = text

## クリーチャー交換実行
func execute_swap_creature() -> bool:
	action_selected.emit("swap_creature")
	close_land_command()
	return true

## 領地コマンドを閉じる
func close_land_command():
	# マーカーを非表示
	hide_selection_marker()
	
	current_state = State.CLOSED
	selected_tile_index = -1
	player_owned_lands.clear()
	land_command_closed.emit()
	
	print("[LandCommandHandler] 領地コマンドを閉じました")
	
	# カメラを現在のプレイヤーに戻す
	# MovementControllerからプレイヤーの実際の位置を取得
	if board_system and player_system and board_system.movement_controller:
		var player_id = player_system.current_player_index
		var player_tile_index = board_system.movement_controller.get_player_tile(player_id)
		
		print("[LandCommandHandler] プレイヤー", player_id, "の実際の位置: タイル", player_tile_index)
		
		if board_system.camera and board_system.tile_nodes.has(player_tile_index):
			var tile_pos = board_system.tile_nodes[player_tile_index].global_position
			
			# MovementControllerと同じカメラオフセットを使用
			const CAMERA_OFFSET = Vector3(19, 19, 19)
			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + CAMERA_OFFSET
			
			board_system.camera.position = new_camera_pos
			board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)
			print("[LandCommandHandler] カメラをプレイヤー位置（タイル", player_tile_index, "）に戻しました")
	
	# UIを非表示
	if ui_manager and ui_manager.has_method("hide_land_command_ui"):
		ui_manager.hide_land_command_ui()

# ============================================
# Phase 1-A: 選択マーカーシステム
# ============================================

## 選択マーカーを作成
func create_selection_marker():
	if selection_marker:
		return  # 既に存在する場合は何もしない
	
	# シンプルなリング形状のマーカーを作成
	selection_marker = MeshInstance3D.new()
	
	# トーラス（ドーナツ型）メッシュを作成
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 16
	
	selection_marker.mesh = torus
	
	# マテリアル設定（黄色で発光）
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.0, 1.0)  # 黄色
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 0.0)
	material.emission_energy_multiplier = 2.0
	selection_marker.material_override = material
	
	print("[LandCommandHandler] 選択マーカーを作成")

## 選択マーカーを表示
func show_selection_marker(tile_index: int):
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	
	# マーカーが未作成なら作成
	if not selection_marker:
		create_selection_marker()
	
	# マーカーを土地の子として追加
	if selection_marker.get_parent():
		selection_marker.get_parent().remove_child(selection_marker)
	
	tile.add_child(selection_marker)
	
	# 位置を土地の少し上に設定
	selection_marker.position = Vector3(0, 0.5, 0)
	
	# 回転アニメーションを追加
	if not selection_marker.has_meta("rotating"):
		selection_marker.set_meta("rotating", true)
	
	print("[LandCommandHandler] 選択マーカーを表示: タイル", tile_index)

## 選択マーカーを非表示
func hide_selection_marker():
	if selection_marker and selection_marker.get_parent():
		selection_marker.get_parent().remove_child(selection_marker)
		print("[LandCommandHandler] 選択マーカーを非表示")

## 選択マーカーを回転（process内で呼ぶ）
func rotate_selection_marker(delta: float):
	if selection_marker and selection_marker.has_meta("rotating"):
		selection_marker.rotate_y(delta * 2.0)  # 1秒で約114度回転

## キャンセル処理
func cancel():
	if current_state == State.SELECTING_MOVE_DEST:
		# 移動先選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		print("[LandCommandHandler] アクション選択に戻りました")
		
		# マーカーを移動元（選択中の土地）に戻す
		if move_source_tile >= 0:
			show_selection_marker(move_source_tile)
			focus_camera_on_tile(move_source_tile)
		
		# 移動先リストをクリア
		move_destinations.clear()
		move_source_tile = -1
		current_destination_index = 0
		
		# UIを更新（アクションメニューを再表示）
		if ui_manager and ui_manager.has_method("show_action_menu"):
			ui_manager.show_action_menu(selected_tile_index)
		
	elif current_state == State.SELECTING_ACTION:
		# アクション選択中なら土地選択に戻る
		# マーカーを非表示
		hide_selection_marker()
		
		current_state = State.SELECTING_LAND
		selected_tile_index = -1
		print("[LandCommandHandler] 土地選択に戻りました")
		
		if ui_manager and ui_manager.has_method("show_land_selection_mode"):
			ui_manager.show_land_selection_mode(player_owned_lands)
	
	elif current_state == State.SELECTING_LAND:
		# 土地選択中なら閉じる
		close_land_command()

## Phase 1-A: レベル選択シグナルハンドラ
func _on_level_up_selected(target_level: int, cost: int):
	execute_level_up_with_level(target_level, cost)

## 隣接タイルを取得
func get_adjacent_tiles(tile_index: int) -> Array:
	if not board_system:
		print("[LandCommandHandler] ERROR: board_systemが存在しません")
		return []
	
	print("[LandCommandHandler] 隣接タイル取得開始: tile_index=", tile_index)
	
	# TileNeighborSystemを使用
	if not board_system.tile_neighbor_system:
		print("[LandCommandHandler] ERROR: tile_neighbor_systemが存在しません")
		return []
	
	print("[LandCommandHandler] tile_neighbor_system存在確認OK")
	var neighbors = board_system.tile_neighbor_system.get_spatial_neighbors(tile_index)
	print("[LandCommandHandler] タイル", tile_index, "の隣接タイル: ", neighbors)
	print("[LandCommandHandler] 隣接タイル数: ", neighbors.size())
	
	return neighbors

## プレイヤーの所有地を取得（ダウン状態を除外）
func get_player_owned_lands(player_id: int) -> Array:
	if not board_system:
		return []
	
	var owned_lands = []
	
	# BoardSystem3Dのtile_nodesから所有地を取得
	if not board_system.tile_nodes:
		return []
	
	for tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[tile_index]
		if tile.owner_id == player_id:
			# ダウン状態の土地は除外
			if tile.has_method("is_down") and tile.is_down():
				print("[LandCommandHandler] タイル", tile_index, "はダウン状態なので除外")
				continue
			owned_lands.append(tile.tile_index)
	
	return owned_lands

## 現在の状態を取得
func get_current_state() -> State:
	return current_state

## 土地選択中か
func is_selecting_land() -> bool:
	return current_state == State.SELECTING_LAND

## アクション選択中か
func is_selecting_action() -> bool:
	return current_state == State.SELECTING_ACTION

## Phase 1-A: 選択した土地にカメラをフォーカス
func focus_camera_on_tile(tile_index: int):
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	var camera = board_system.camera
	
	if not camera:
		return
	
	# カメラを土地の上方に移動（通常と同じくらいの距離）
	var tile_pos = tile.global_position
	var camera_offset = Vector3(12, 15, 12)  # 通常カメラと同じくらいの距離
	camera.position = tile_pos + camera_offset
	
	# カメラを土地に向ける
	camera.look_at(tile_pos, Vector3.UP)
	
	# 選択した土地をハイライト
	if tile.has_method("set_highlight"):
		tile.set_highlight(true)
	
	print("[LandCommandHandler] カメラを土地 ", tile_index, " にフォーカス")

# ============================================
# Phase 1-A: キーボード入力処理
# ============================================

## キーボード入力処理
func _input(event):
	if event is InputEventKey and event.pressed:
		# 土地選択モード時
		if current_state == State.SELECTING_LAND:
			handle_land_selection_input(event)
		# アクション選択モード時
		elif current_state == State.SELECTING_ACTION:
			handle_action_selection_input(event)
		# 移動先選択モード時
		elif current_state == State.SELECTING_MOVE_DEST:
			handle_move_destination_input(event)

## 土地選択時のキー入力処理
func handle_land_selection_input(event):
	# 数字キー1-0で土地を選択
	var key_to_index = {
		KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4,
		KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9
	}
	
	if event.keycode in key_to_index:
		var index = key_to_index[event.keycode]
		if index < player_owned_lands.size():
			var tile_index = player_owned_lands[index]
			select_land(tile_index)
		else:
			print("[LandCommandHandler] 無効な番号: ", index + 1)
	
	# Escキーでキャンセル
	elif event.keycode == KEY_ESCAPE:
		cancel()

## アクション選択時のキー入力処理
func handle_action_selection_input(event):
	match event.keycode:
		KEY_L:
			execute_action("level_up")
		KEY_M:
			execute_action("move_creature")
		KEY_S:
			execute_action("swap_creature")
		KEY_C:
			cancel()
		KEY_ESCAPE:
			cancel()

## 移動先選択時のキー入力処理
func handle_move_destination_input(event):
	# Cキーまたはエスケープで前画面に戻る
	if event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
		cancel()
		return
	
	# 移動先が存在しない場合は何もしない
	if move_destinations.is_empty():
		return
	
	# ↓キーまたは→キー: 次の移動先
	if event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
		current_destination_index = (current_destination_index + 1) % move_destinations.size()
		var dest_tile_index = move_destinations[current_destination_index]
		
		# マーカーを移動
		show_selection_marker(dest_tile_index)
		focus_camera_on_tile(dest_tile_index)
		
		# UI更新
		update_move_destination_ui()
		
		print("[LandCommandHandler] 移動先切替: タイル", dest_tile_index, " (", current_destination_index + 1, "/", move_destinations.size(), ")")
	
	# ↑キーまたは←キー: 前の移動先
	elif event.keycode == KEY_UP or event.keycode == KEY_LEFT:
		current_destination_index = (current_destination_index - 1 + move_destinations.size()) % move_destinations.size()
		var dest_tile_index = move_destinations[current_destination_index]
		
		# マーカーを移動
		show_selection_marker(dest_tile_index)
		focus_camera_on_tile(dest_tile_index)
		
		# UI更新
		update_move_destination_ui()
		
		print("[LandCommandHandler] 移動先切替: タイル", dest_tile_index, " (", current_destination_index + 1, "/", move_destinations.size(), ")")
	
	# Enterキー: 移動を確定
	elif event.keycode == KEY_ENTER:
		var dest_tile_index = move_destinations[current_destination_index]
		confirm_move(dest_tile_index)

## 移動を確定
func confirm_move(dest_tile_index: int):
	print("[LandCommandHandler] 移動を確定: ", move_source_tile, " → ", dest_tile_index)
	
	if not board_system or not board_system.tile_nodes.has(move_source_tile) or not board_system.tile_nodes.has(dest_tile_index):
		print("[LandCommandHandler] エラー: タイルが見つかりません")
		close_land_command()
		return
	
	var source_tile = board_system.tile_nodes[move_source_tile]
	var dest_tile = board_system.tile_nodes[dest_tile_index]
	
	# 移動元のクリーチャー情報を取得
	var creature_data = source_tile.creature_data.duplicate()
	if creature_data.is_empty():
		print("[LandCommandHandler] エラー: 移動元にクリーチャーがいません")
		close_land_command()
		return
	
	var current_player_index = source_tile.owner_id
	
	print("[LandCommandHandler] クリーチャー移動開始: ", creature_data.get("name", "Unknown"))
	
	# 1. 移動元のクリーチャーを削除し、空き地にする
	source_tile.remove_creature()
	board_system.set_tile_owner(move_source_tile, -1)  # 空き地化
	print("[LandCommandHandler] 移動元を空き地化")
	
	# 2. 移動先の状況を確認
	var dest_owner = dest_tile.owner_id
	
	if dest_owner == -1:
		# 空き地の場合: 土地を獲得してクリーチャー配置
		print("[LandCommandHandler] 空き地への移動 - 土地獲得")
		board_system.set_tile_owner(dest_tile_index, current_player_index)
		board_system.place_creature(dest_tile_index, creature_data)
		
		# 移動先をダウン状態に
		dest_tile.set_down_state(true)
		
		# 領地コマンドを閉じる
		close_land_command()
		
		# アクション完了を通知
		# TileActionProcessorを経由してシグナルを発行
		if board_system and board_system.tile_action_processor:
			board_system.tile_action_processor._complete_action()
		# これによりTileActionProcessor → BoardSystem3D → GameFlowManager
		# とシグナルが伝播し、end_turn()が呼ばれる（集約ルール遵守）
		
	elif dest_owner == current_player_index:
		# 自分の土地の場合: エラー（通常はありえない）
		print("[LandCommandHandler] エラー: 自分の土地には移動できません")
		# クリーチャーを元に戻す
		source_tile.place_creature(creature_data)
		close_land_command()
		
	else:
		# 敵の土地の場合: バトル発生
		print("[LandCommandHandler] 敵地への移動 - バトル発生")
		
		# 1. クリーチャーを手札に追加
		if board_system.card_system:
			# 手札に直接追加
			board_system.card_system.player_hands[current_player_index]["data"].append(creature_data)
			var card_index = board_system.card_system.player_hands[current_player_index]["data"].size() - 1
			
			print("[LandCommandHandler] クリーチャーを手札に追加: index=", card_index)
			
			# 2. 領地コマンドを閉じる
			close_land_command()
			
			# 3. バトル完了シグナルに接続
			var callable = Callable(self, "_on_move_battle_completed")
			if board_system.battle_system and not board_system.battle_system.invasion_completed.is_connected(callable):
				board_system.battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
			
			# 4. 既存のバトルシステムを使用
			var tile_info = board_system.get_tile_info(dest_tile_index)
			board_system.battle_system.execute_3d_battle(current_player_index, card_index, tile_info)
		else:
			print("[LandCommandHandler] エラー: card_systemが存在しません、簡易バトルを実行")
			close_land_command()
			_execute_simple_move_battle(dest_tile_index, creature_data, current_player_index)

## 移動バトル完了時のコールバック
func _on_move_battle_completed(success: bool, tile_index: int):
	print("[LandCommandHandler] 移動バトル完了: ", "勝利" if success else "敗北")
	
	if success:
		# 勝利時: 移動先の土地をダウン状態に
		if board_system and board_system.tile_nodes.has(tile_index):
			var tile = board_system.tile_nodes[tile_index]
			if tile and tile.has_method("set_down_state"):
				tile.set_down_state(true)
				print("[LandCommandHandler] 移動先をダウン状態に設定")
	
	# アクション完了を通知
	# TileActionProcessorを経由してシグナルを発行
	if board_system and board_system.tile_action_processor:
		board_system.tile_action_processor._complete_action()
	# これによりTileActionProcessor → BoardSystem3D → GameFlowManager
	# とシグナルが伝播し、end_turn()が呼ばれる（集約ルール遵守）

## 簡易移動バトル（カードシステム使用不可時）
func _execute_simple_move_battle(dest_index: int, attacker_data: Dictionary, attacker_player: int):
	var dest_tile = board_system.tile_nodes[dest_index]
	var defender_data = dest_tile.creature_data
	var defender_player = dest_tile.owner_id
	
	# 非常にシンプルなAP比較バトル
	var attacker_ap = attacker_data.get("ap", 0)
	var defender_hp = defender_data.get("hp", 0)
	
	var success = attacker_ap >= defender_hp
	
	if success:
		print("[LandCommandHandler] 簡易バトル: 攻撃側勝利")
		board_system.set_tile_owner(dest_index, attacker_player)
		board_system.place_creature(dest_index, attacker_data)
		dest_tile.set_down_state(true)
	else:
		print("[LandCommandHandler] 簡易バトル: 防御側勝利")
	
	# アクション完了を通知
	# TileActionProcessorを経由してシグナルを発行
	if board_system and board_system.tile_action_processor:
		board_system.tile_action_processor._complete_action()
	# これによりTileActionProcessor → BoardSystem3D → GameFlowManager
	# とシグナルが伝播し、end_turn()が呼ばれる（集約ルール遵守）
