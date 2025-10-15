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
	CLOSED,          # 領地コマンド非表示
	SELECTING_LAND,  # 土地選択中
	SELECTING_ACTION # アクション選択中
}

var current_state: State = State.CLOSED
var selected_tile_index: int = -1
var player_owned_lands: Array = []

## 参照
var ui_manager = null
var board_system = null
var game_flow_manager = null

func _ready():
	pass

## 初期化
func initialize(ui_mgr, board_sys, flow_mgr):
	ui_manager = ui_mgr
	board_system = board_sys
	game_flow_manager = flow_mgr
	
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
	action_selected.emit("move_creature")
	close_land_command()
	return true

## クリーチャー交換実行
func execute_swap_creature() -> bool:
	action_selected.emit("swap_creature")
	close_land_command()
	return true

## 領地コマンドを閉じる
func close_land_command():
	current_state = State.CLOSED
	selected_tile_index = -1
	player_owned_lands.clear()
	land_command_closed.emit()
	
	print("[LandCommandHandler] 領地コマンドを閉じました")
	
	# UIを非表示
	if ui_manager and ui_manager.has_method("hide_land_command_ui"):
		ui_manager.hide_land_command_ui()

## キャンセル処理
func cancel():
	if current_state == State.SELECTING_ACTION:
		# アクション選択中なら土地選択に戻る
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
