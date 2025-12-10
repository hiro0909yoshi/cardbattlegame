# LandCommandHandler - 領地コマンドの処理を担当
extends Node
class_name LandCommandHandler

const GameConstants = preload("res://scripts/game_constants.gd")

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
	SELECTING_MOVE_DEST, # 移動先選択中
	SELECTING_TERRAIN    # 地形選択中
}

var current_state: State = State.CLOSED
var selected_tile_index: int = -1
var player_owned_lands: Array = []
var current_land_selection_index: int = 0  # 現在選択中の土地インデックス

# Phase 1-A: 選択マーカー
var selection_marker: MeshInstance3D = null

# Phase 1-A: 移動先選択
var move_source_tile: int = -1  # 移動元タイル
var is_boulder_eater_move: bool = false  # バウダーイーター分裂移動フラグ
var move_destinations: Array = []  # 移動可能な隣接タイル
var current_destination_index: int = 0  # 現在選択中の移動先インデックス

# Phase 1-D: 交換モード
var _swap_mode: bool = false  # 交換モード中フラグ
var _swap_old_creature: Dictionary = {}  # 交換前のクリーチャーデータ
var _swap_tile_index: int = -1  # 交換対象の土地インデックス

# 地形選択モード
var terrain_change_tile_index: int = -1  # 地形変化対象のタイル
var terrain_options: Array = ["fire", "water", "earth", "wind"]  # 選択可能な属性
var current_terrain_index: int = 0  # 現在選択中の属性インデックス

# Phase 1-E: 移動バトル用の一時保存
var pending_move_battle_creature_data: Dictionary = {}
var pending_move_battle_tile_info: Dictionary = {}
var pending_move_attacker_item: Dictionary = {}
var pending_move_defender_item: Dictionary = {}
var is_waiting_for_move_defender_item: bool = false

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
		return
	
	# プレイヤーの所有地を取得
	player_owned_lands = LandSelectionHelper.get_player_owned_lands(board_system, player_id)
	
	if player_owned_lands.is_empty():
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "所有地がありません"
		return
	
	# カード選択UIを無効化
	if ui_manager and ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.is_active = false
	
	# 土地選択モードに移行
	current_state = State.SELECTING_LAND
	current_land_selection_index = 0  # 最初の土地を選択
	land_command_opened.emit()
	
	
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
		return false
	
	if selected_tile_index == -1:
		return false
	
	
	match action_type:
		"level_up":
			return LandActionHelper.execute_level_up(self)
		"move_creature":
			return LandActionHelper.execute_move_creature(self)
		"swap_creature":
			return LandActionHelper.execute_swap_creature(self)
		"terrain_change":
			return execute_terrain_change()
		_:
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
	
	
	# カメラを現在のプレイヤーに戻す
	# MovementControllerからプレイヤーの実際の位置を取得
	if board_system and player_system and board_system.movement_controller:
		var player_id = player_system.current_player_index
		var player_tile_index = board_system.movement_controller.get_player_tile(player_id)
		
		if board_system.camera and board_system.tile_nodes.has(player_tile_index):
			var tile_pos = board_system.tile_nodes[player_tile_index].global_position
			
			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + GameConstants.CAMERA_OFFSET
			
			board_system.camera.position = new_camera_pos
			board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)
	
	# UIを非表示
	if ui_manager:
		if ui_manager.has_method("hide_land_command_ui"):
			ui_manager.hide_land_command_ui()
		# カード選択UIも非表示にする
		if ui_manager.has_method("hide_card_selection_ui"):
			ui_manager.hide_card_selection_ui()

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
	if current_state == State.SELECTING_TERRAIN:
		# 地形選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		terrain_change_tile_index = -1
		current_terrain_index = 0
		
		# UIを更新（アクションメニューを再表示）
		if ui_manager and ui_manager.has_method("show_action_menu"):
			ui_manager.show_action_menu(selected_tile_index)
	
	elif current_state == State.SELECTING_MOVE_DEST:
		# 移動先選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		
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
	
	
	# 交換処理用に変数を保存
	var tile_index = _swap_tile_index
	var old_creature = _swap_old_creature.duplicate()
	
	# 交換モードをリセット
	_swap_mode = false
	_swap_old_creature = {}
	_swap_tile_index = -1
	
	# TileActionProcessorの交換処理を呼び出す
	# 注: 領地コマンドはend_turn()で閉じられる
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

## アイテムフェーズ完了後のコールバック（移動侵略用）
func _on_move_item_phase_completed():
	if not is_waiting_for_move_defender_item:
		# 攻撃側のアイテムフェーズ完了 → 防御側のアイテムフェーズ開始
		
		# 攻撃側のアイテムを保存
		if game_flow_manager and game_flow_manager.item_phase_handler:
			pending_move_attacker_item = game_flow_manager.item_phase_handler.get_selected_item()
		
		# 防御側のアイテムフェーズを開始
		var defender_owner = pending_move_battle_tile_info.get("owner", -1)
		if defender_owner >= 0:
			is_waiting_for_move_defender_item = true
			
			# 防御側のアイテムフェーズ開始
			if game_flow_manager and game_flow_manager.item_phase_handler:
				# 再度シグナルに接続（ONE_SHOTなので再接続が必要）
				if not game_flow_manager.item_phase_handler.item_phase_completed.is_connected(_on_move_item_phase_completed):
					game_flow_manager.item_phase_handler.item_phase_completed.connect(_on_move_item_phase_completed, CONNECT_ONE_SHOT)
				
				# 防御側クリーチャーのデータを取得して渡す
				var defender_creature = pending_move_battle_tile_info.get("creature", {})
				game_flow_manager.item_phase_handler.start_item_phase(defender_owner, defender_creature)
			else:
				# ItemPhaseHandlerがない場合は直接バトル
				_execute_move_battle()
		else:
			# 防御側がいない場合（ありえないが念のため）
			_execute_move_battle()
	else:
		# 防御側のアイテムフェーズ完了 → バトル開始
		
		# 防御側のアイテムを保存
		if game_flow_manager and game_flow_manager.item_phase_handler:
			pending_move_defender_item = game_flow_manager.item_phase_handler.get_selected_item()
		
		is_waiting_for_move_defender_item = false
		_execute_move_battle()

## 保留中の移動バトルを実行
func _execute_move_battle():
	if pending_move_battle_creature_data.is_empty():
		if board_system and board_system.tile_action_processor:
			board_system.tile_action_processor.complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	
	# バトル完了シグナルに接続
	var callable = Callable(self, "_on_move_battle_completed")
	if not board_system.battle_system.invasion_completed.is_connected(callable):
		board_system.battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
	
	# バトル実行（移動元タイル情報も渡す）
	await board_system.battle_system.execute_3d_battle_with_data(
		current_player_index,
		pending_move_battle_creature_data,
		pending_move_battle_tile_info,
		pending_move_attacker_item,
		pending_move_defender_item,
		move_source_tile
	)
	
	# バトル情報をクリア
	pending_move_battle_creature_data = {}
	pending_move_battle_tile_info = {}
	pending_move_attacker_item = {}
	pending_move_defender_item = {}
	is_waiting_for_move_defender_item = false

## 移動バトル完了時のコールバック
func _on_move_battle_completed(success: bool, tile_index: int):
	
	# 衰弱（プレイグ）ダメージ処理
	await _apply_plague_damage_after_battle(tile_index)
	
	if success:
		# 勝利時: battle_systemが既に土地獲得とクリーチャー配置を完了している
		# ここでは何もしない
		
		# 移動元情報をクリア
		move_source_tile = -1
	else:
		# 敗北時: battle_systemが既に移動元に戻している
		# ここでは何もしない
		
		# 移動元情報をクリア
		move_source_tile = -1
	
	# アクション完了を通知
	if board_system and board_system.tile_action_processor:
		board_system.tile_action_processor.complete_action()


## バトル終了後の衰弱ダメージ処理
func _apply_plague_damage_after_battle(tile_index: int) -> void:
	if not game_flow_manager or not game_flow_manager.spell_phase_handler:
		return
	
	var spell_damage = game_flow_manager.spell_phase_handler.spell_damage
	if not spell_damage:
		return
	
	# 衰弱ダメージを適用
	var result = spell_damage.apply_plague_damage(tile_index)
	
	if result["triggered"]:
		# 通知を表示
		var notification_text = SpellDamage.format_plague_notification(result)
		if spell_damage.spell_cast_notification_ui:
			spell_damage.spell_cast_notification_ui.show_notification_and_wait(notification_text)
			await spell_damage.spell_cast_notification_ui.click_confirmed

## 簡易移動バトル（カードシステム使用不可時）
func _execute_simple_move_battle(dest_index: int, attacker_data: Dictionary, attacker_player: int):
	LandActionHelper.execute_simple_move_battle(self, dest_index, attacker_data, attacker_player)

## 地形変化実行
func execute_terrain_change() -> bool:
	return LandActionHelper.execute_terrain_change(self)
