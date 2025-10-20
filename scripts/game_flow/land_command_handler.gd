# LandCommandHandler - 領地コマンドの処理を担当
extends Node
class_name LandCommandHandler

## シグナル
signal land_command_opened()
signal land_command_closed()
@warning_ignore("unused_signal")
signal land_selected(tile_index: int)
@warning_ignore("unused_signal")
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
var current_land_selection_index: int = 0  # 現在選択中の土地インデックス

# Phase 1-A: 選択マーカー
var selection_marker: MeshInstance3D = null

# Phase 1-A: 移動先選択
var move_source_tile: int = -1  # 移動元タイル
var move_destinations: Array = []  # 移動可能な隣接タイル
var current_destination_index: int = 0  # 現在選択中の移動先インデックス

# Phase 1-D: 交換モード
var _swap_mode: bool = false  # 交換モード中フラグ
var _swap_old_creature: Dictionary = {}  # 交換前のクリーチャーデータ
var _swap_tile_index: int = -1  # 交換対象の土地インデックス

## 参照
var ui_manager = null
var board_system = null
var game_flow_manager = null
var player_system = null

func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	LandSelectionHelper.rotate_selection_marker(self, delta)

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

## 領地コマンドを開く
func open_land_command(player_id: int):
	if current_state != State.CLOSED:
		print("[LandCommandHandler] 既に開いています")
		return
	
	# プレイヤーの所有地を取得
	player_owned_lands = LandSelectionHelper.get_player_owned_lands(board_system, player_id)
	
	if player_owned_lands.is_empty():
		print("[LandCommandHandler] 所有地がありません")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "所有地がありません"
		return
	
	# 土地選択モードに移行
	current_state = State.SELECTING_LAND
	current_land_selection_index = 0  # 最初の土地を選択
	land_command_opened.emit()
	
	print("[LandCommandHandler] 領地コマンドを開きました（所有地数: ", player_owned_lands.size(), "）")
	
	# 最初の土地を自動プレビュー
	if player_owned_lands.size() > 0:
		var first_tile = player_owned_lands[0]
		LandSelectionHelper.preview_land(self, first_tile)
		LandSelectionHelper.update_land_selection_ui(self)
	
	# UIに表示要請
	if ui_manager and ui_manager.has_method("show_land_selection_mode"):
		ui_manager.show_land_selection_mode(player_owned_lands)

## 土地をプレビュー（ハイライトのみ、状態は変更しない）
func preview_land(tile_index: int) -> bool:
	return LandSelectionHelper.preview_land(self, tile_index)

## 土地選択を確定してアクションメニューを表示
func confirm_land_selection() -> bool:
	return LandSelectionHelper.confirm_land_selection(self)

## 土地選択（旧メソッド - 互換性のため残す）
func select_land(tile_index: int) -> bool:
	return LandSelectionHelper.select_land(self, tile_index)

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
			return LandActionHelper.execute_level_up(self)
		"move_creature":
			return LandActionHelper.execute_move_creature(self)
		"swap_creature":
			return LandActionHelper.execute_swap_creature(self)
		_:
			print("[LandCommandHandler] 不明なアクション: ", action_type)
			return false

## レベルアップ実行（レベル選択後）
func execute_level_up_with_level(target_level: int, cost: int) -> bool:
	return LandActionHelper.execute_level_up_with_level(self, target_level, cost)

## レベルアップ実行
func execute_level_up() -> bool:
	return LandActionHelper.execute_level_up(self)

## クリーチャー移動実行
func execute_move_creature() -> bool:
	return LandActionHelper.execute_move_creature(self)

## 移動先選択UIを更新
func update_move_destination_ui():
	LandActionHelper.update_move_destination_ui(self)

## 土地選択UIを更新
func update_land_selection_ui():
	LandSelectionHelper.update_land_selection_ui(self)

## クリーチャー交換実行
func execute_swap_creature() -> bool:
	return LandActionHelper.execute_swap_creature(self)

## 交換条件チェック
func _check_swap_conditions(player_id: int) -> bool:
	return LandActionHelper.check_swap_conditions(self, player_id)

## 領地コマンドを閉じる
func close_land_command():
	# マーカーを非表示
	LandSelectionHelper.hide_selection_marker(self)
	
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
		
		if board_system.camera and board_system.tile_nodes.has(player_tile_index):
			var tile_pos = board_system.tile_nodes[player_tile_index].global_position
			
			# MovementControllerと同じカメラオフセットを使用
			const CAMERA_OFFSET = Vector3(19, 19, 19)
			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + CAMERA_OFFSET
			
			board_system.camera.position = new_camera_pos
			board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)
	
	# UIを非表示
	if ui_manager and ui_manager.has_method("hide_land_command_ui"):
		ui_manager.hide_land_command_ui()

# ============================================
# Phase 1-A: 選択マーカーシステム
# ============================================

## 選択マーカーを作成
func create_selection_marker():
	LandSelectionHelper.create_selection_marker(self)

## 選択マーカーを表示
func show_selection_marker(tile_index: int):
	LandSelectionHelper.show_selection_marker(self, tile_index)

## 選択マーカーを非表示
func hide_selection_marker():
	LandSelectionHelper.hide_selection_marker(self)

## 選択マーカーを回転（process内で呼ぶ）
func rotate_selection_marker(delta: float):
	LandSelectionHelper.rotate_selection_marker(self, delta)

## キャンセル処理
func cancel():
	if current_state == State.SELECTING_MOVE_DEST:
		# 移動先選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		print("[LandCommandHandler] アクション選択に戻りました")
		
		# マーカーを移動元（選択中の土地）に戻す
		if move_source_tile >= 0:
			LandSelectionHelper.show_selection_marker(self, move_source_tile)
			LandSelectionHelper.focus_camera_on_tile(self, move_source_tile)
		
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
		LandSelectionHelper.hide_selection_marker(self)
		
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
	LandActionHelper.execute_level_up_with_level(self, target_level, cost)

## カード選択時の処理（交換モード用）
func on_card_selected_for_swap(card_index: int):
	if not _swap_mode:
		return  # 交換モードでない場合は何もしない
	
	print("[LandCommandHandler] 交換用カード選択: index=", card_index)
	
	# 交換処理用に変数を保存
	var tile_index = _swap_tile_index
	var old_creature = _swap_old_creature.duplicate()
	
	# 交換モードをリセット
	_swap_mode = false
	_swap_old_creature = {}
	_swap_tile_index = -1
	
	# 領地コマンドを閉じる
	close_land_command()
	
	# TileActionProcessorの交換処理を呼び出す（最後に実行）
	# これによりaction_completedシグナルが正しく処理される
	if board_system and board_system.tile_action_processor:
		board_system.tile_action_processor.execute_swap(
			tile_index,
			card_index,
			old_creature
		)

## 隣接タイルを取得
func get_adjacent_tiles(tile_index: int) -> Array:
	return LandActionHelper.get_adjacent_tiles(self, tile_index)

## プレイヤーの所有地を取得（ダウン状態を除外）
func get_player_owned_lands(player_id: int) -> Array:
	return LandSelectionHelper.get_player_owned_lands(board_system, player_id)

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
	LandSelectionHelper.focus_camera_on_tile(self, tile_index)

# ============================================
# Phase 1-A: キーボード入力処理
# ============================================

## キーボード入力処理
func _input(event):
	LandInputHelper.process_input(self, event)

## 土地選択時のキー入力処理
func handle_land_selection_input(event):
	LandInputHelper.handle_land_selection_input(self, event)

## アクション選択時のキー入力処理
func handle_action_selection_input(event):
	LandInputHelper.handle_action_selection_input(self, event)

## 移動先選択時のキー入力処理
func handle_move_destination_input(event):
	LandInputHelper.handle_move_destination_input(self, event)

## 移動を確定
func confirm_move(dest_tile_index: int):
	LandActionHelper.confirm_move(self, dest_tile_index)

## 移動バトル完了時のコールバック
func _on_move_battle_completed(success: bool, tile_index: int):
	print("[LandCommandHandler] 移動バトル完了: ", "勝利" if success else "敗北")
	
	if success:
		# 勝利時: 移動先の土地をダウン状態に
		if board_system and board_system.tile_nodes.has(tile_index):
			var tile = board_system.tile_nodes[tile_index]
			if tile and tile.has_method("set_down_state"):
				# 移動したクリーチャーが不屈持ちかチェック
				var creature = tile.creature_data
				if not SkillSystem.has_unyielding(creature):
					tile.set_down_state(true)
					print("[LandCommandHandler] 移動先をダウン状態に設定")
				else:
					print("[LandCommandHandler] 不屈により移動後もダウンしません")
	
	# アクション完了を通知
	if board_system and board_system.tile_action_processor:
		board_system.tile_action_processor.complete_action()

## 簡易移動バトル（カードシステム使用不可時）
func _execute_simple_move_battle(dest_index: int, attacker_data: Dictionary, attacker_player: int):
	LandActionHelper.execute_simple_move_battle(self, dest_index, attacker_data, attacker_player)
