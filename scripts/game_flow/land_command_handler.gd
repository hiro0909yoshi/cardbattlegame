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
	SELECTING_LEVEL,     # レベル選択中
	SELECTING_SWAP,      # 交換クリーチャー選択中
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

# レベル選択モード
var available_levels: Array = []  # 選択可能なレベル（現在レベル+1〜5）
var current_level_selection_index: int = 0  # 現在選択中のレベルインデックス

# Phase 1-E: 移動バトル用の一時保存
var pending_move_battle_creature_data: Dictionary = {}
var pending_move_battle_tile_info: Dictionary = {}
var pending_move_attacker_item: Dictionary = {}
var pending_move_defender_item: Dictionary = {}
var is_waiting_for_move_defender_item: bool = false

# 移動先土地情報表示用
var land_info_panel = null

## 参照
var ui_manager = null
var board_system = null
var game_flow_manager = null
var player_system = null

func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	TargetSelectionHelper.rotate_selection_marker(self, delta)

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
	
	# 土地情報パネルを初期化
	_setup_land_info_panel()

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
	
	# カード選択UIを無効化（グローバルボタンもクリア）
	if ui_manager and ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.is_active = false
		ui_manager.clear_back_action()  # 「召喚しない」をクリア
	
	# 土地選択モードに移行
	current_state = State.SELECTING_LAND
	current_land_selection_index = 0  # 最初の土地を選択
	land_command_opened.emit()
	
	# 入力ロックを解除（土地選択待ち状態になった）
	if game_flow_manager:
		game_flow_manager.unlock_input()
	
	
	# 最初の土地を自動プレビュー
	if player_owned_lands.size() > 0:
		var first_tile = player_owned_lands[0]
		LandSelectionHelper.preview_land(self, first_tile)
		LandSelectionHelper.update_land_selection_ui(self)
	
	# UIに表示要請
	if ui_manager and ui_manager.has_method("show_land_selection_mode"):
		ui_manager.show_land_selection_mode(player_owned_lands)
	
	# ナビゲーションボタン設定（土地選択用）
	if ui_manager:
		ui_manager.enable_navigation(
			func(): LandSelectionHelper.confirm_land_selection(self),  # 決定
			func(): cancel(),  # 戻る
			func(): _on_arrow_up(),  # 上
			func(): _on_arrow_down()  # 下
		)

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
	TargetSelectionHelper.hide_selection_marker(self)
	
	# すべての状態をリセット
	current_state = State.CLOSED
	selected_tile_index = -1
	player_owned_lands.clear()
	current_land_selection_index = 0
	
	# 移動関連のリセット
	move_source_tile = -1
	is_boulder_eater_move = false
	move_destinations.clear()
	current_destination_index = 0
	
	# 交換関連のリセット
	_swap_mode = false
	_swap_old_creature = {}
	_swap_tile_index = -1
	
	# 地形変化関連のリセット
	terrain_change_tile_index = -1
	current_terrain_index = 0
	
	# レベル選択関連のリセット
	available_levels.clear()
	current_level_selection_index = 0
	
	# TileActionProcessorのフラグをリセット
	if board_system and board_system.tile_action_processor:
		board_system.tile_action_processor.is_action_processing = false
	
	# ナビゲーションボタンをクリア
	if ui_manager:
		ui_manager.disable_navigation()
	
	# パネルを閉じる
	if ui_manager and ui_manager.land_command_ui:
		ui_manager.land_command_ui.hide_level_selection()
		ui_manager.land_command_ui.hide_terrain_selection()
	
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
	TargetSelectionHelper.create_selection_marker(self)

## 選択マーカーを表示
func show_selection_marker(tile_index: int):
	TargetSelectionHelper.show_selection_marker(self, tile_index)

## 選択マーカーを非表示
func hide_selection_marker():
	TargetSelectionHelper.hide_selection_marker(self)

## 選択マーカーを回転（process内で呼ぶ）
func rotate_selection_marker(delta: float):
	TargetSelectionHelper.rotate_selection_marker(self, delta)

## キャンセル処理
func cancel():
	if current_state == State.SELECTING_TERRAIN:
		# 地形選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		terrain_change_tile_index = -1
		current_terrain_index = 0
		
		if board_system and board_system.tile_action_processor:
			board_system.tile_action_processor.is_action_processing = false
		
		# UIを先に更新
		if ui_manager and ui_manager.land_command_ui:
			ui_manager.land_command_ui.hide_terrain_selection()
			ui_manager.land_command_ui.show_action_menu(selected_tile_index)
		
		# ナビゲーションはActionMenuUI内で設定される
	
	elif current_state == State.SELECTING_MOVE_DEST:
		# 移動先選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		
		# クリーチャー情報パネルを閉じる
		LandActionHelper._hide_move_creature_info(self)
		
		if move_source_tile >= 0:
			TargetSelectionHelper.show_selection_marker(self, move_source_tile)
			TargetSelectionHelper.focus_camera_on_tile(self, move_source_tile)
		
		move_destinations.clear()
		move_source_tile = -1
		current_destination_index = 0
		
		# UIを先に更新
		if ui_manager and ui_manager.has_method("show_action_menu"):
			ui_manager.show_action_menu(selected_tile_index)
		
		# ナビゲーションはActionMenuUI内で設定される
	
	elif current_state == State.SELECTING_LEVEL:
		# レベル選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		available_levels.clear()
		current_level_selection_index = 0
		
		# UIを先に更新
		if ui_manager and ui_manager.land_command_ui:
			ui_manager.land_command_ui.hide_level_selection()
		
		if ui_manager and ui_manager.has_method("show_action_menu"):
			ui_manager.show_action_menu(selected_tile_index)
		
		# ナビゲーションはActionMenuUI内で設定される
	
	elif current_state == State.SELECTING_SWAP:
		# 交換クリーチャー選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		
		_swap_mode = false
		_swap_old_creature = {}
		_swap_tile_index = -1
		
		if board_system and board_system.tile_action_processor:
			board_system.tile_action_processor.is_action_processing = false
		
		# カード選択UIを閉じる（先にクリア）
		if ui_manager and ui_manager.card_selection_ui:
			ui_manager.card_selection_ui.hide_selection()
		
		# クリーチャー情報パネルを閉じる
		if ui_manager and ui_manager.creature_info_panel_ui:
			ui_manager.creature_info_panel_ui.hide_panel(false)
		
		# アクションメニューを表示
		if ui_manager and ui_manager.has_method("show_action_menu"):
			ui_manager.show_action_menu(selected_tile_index)
		
		# ナビゲーションはActionMenuUI内で設定される
		
	elif current_state == State.SELECTING_ACTION:
		# アクション選択中なら土地選択に戻る
		if ui_manager and ui_manager.land_command_ui:
			ui_manager.land_command_ui.hide_action_menu(false)  # ボタンクリアしない
		
		current_state = State.SELECTING_LAND
		
		# 現在選択中の土地を再プレビュー（selected_tile_indexを維持）
		if player_owned_lands.size() > 0:
			var tile_index = player_owned_lands[current_land_selection_index]
			LandSelectionHelper.preview_land(self, tile_index)
			LandSelectionHelper.update_land_selection_ui(self)
		
		if ui_manager and ui_manager.has_method("show_land_selection_mode"):
			ui_manager.show_land_selection_mode(player_owned_lands)
		
		# 土地選択用ナビゲーション（全ボタン）
		_set_land_selection_navigation()
	
	elif current_state == State.SELECTING_LAND:
		# 土地選択中なら閉じる
		close_land_command()

## アクション選択用ナビゲーション設定（戻るのみ）
func _set_action_selection_navigation():
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): cancel()  # 戻る
		)

## 土地選択用ナビゲーション設定（全ボタン）
func _set_land_selection_navigation():
	if ui_manager:
		ui_manager.enable_navigation(
			func(): LandSelectionHelper.confirm_land_selection(self),  # 決定
			func(): cancel(),  # 戻る
			func(): _on_arrow_up(),  # 上
			func(): _on_arrow_down()  # 下
		)

## 上下ボタンのコールバック（上）
func _on_arrow_up():
	match current_state:
		State.SELECTING_LAND:
			# 前の土地を選択（ループ）
			if not player_owned_lands.is_empty():
				current_land_selection_index = (current_land_selection_index - 1 + player_owned_lands.size()) % player_owned_lands.size()
				var tile_index = player_owned_lands[current_land_selection_index]
				LandSelectionHelper.preview_land(self, tile_index)
				LandSelectionHelper.update_land_selection_ui(self)
		
		State.SELECTING_MOVE_DEST:
			# 前の移動先を選択（ループ）
			if not move_destinations.is_empty():
				current_destination_index = (current_destination_index - 1 + move_destinations.size()) % move_destinations.size()
				var dest_tile_index = move_destinations[current_destination_index]
				TargetSelectionHelper.show_selection_marker(self, dest_tile_index)
				TargetSelectionHelper.focus_camera_on_tile(self, dest_tile_index)
				LandActionHelper.update_move_destination_ui(self)
		
		State.SELECTING_TERRAIN:
			# 前の属性を選択（ループ）
			current_terrain_index = (current_terrain_index - 1 + terrain_options.size()) % terrain_options.size()
			LandActionHelper.update_terrain_selection_ui(self)
		
		State.SELECTING_LEVEL:
			# 前のレベルを選択（ループ）
			_select_previous_level()

## 上下ボタンのコールバック（下）
func _on_arrow_down():
	match current_state:
		State.SELECTING_LAND:
			# 次の土地を選択（ループ）
			if not player_owned_lands.is_empty():
				current_land_selection_index = (current_land_selection_index + 1) % player_owned_lands.size()
				var tile_index = player_owned_lands[current_land_selection_index]
				LandSelectionHelper.preview_land(self, tile_index)
				LandSelectionHelper.update_land_selection_ui(self)
		
		State.SELECTING_MOVE_DEST:
			# 次の移動先を選択（ループ）
			if not move_destinations.is_empty():
				current_destination_index = (current_destination_index + 1) % move_destinations.size()
				var dest_tile_index = move_destinations[current_destination_index]
				TargetSelectionHelper.show_selection_marker(self, dest_tile_index)
				TargetSelectionHelper.focus_camera_on_tile(self, dest_tile_index)
				LandActionHelper.update_move_destination_ui(self)
		
		State.SELECTING_TERRAIN:
			# 次の属性を選択（ループ）
			current_terrain_index = (current_terrain_index + 1) % terrain_options.size()
			LandActionHelper.update_terrain_selection_ui(self)
		
		State.SELECTING_LEVEL:
			# 次のレベルを選択（ループ）
			_select_next_level()

## レベル選択: 前のレベルを選択（ループ）
func _select_previous_level():
	if available_levels.is_empty():
		return
	current_level_selection_index = (current_level_selection_index - 1 + available_levels.size()) % available_levels.size()
	_update_level_selection_highlight()

## レベル選択: 次のレベルを選択（ループ）
func _select_next_level():
	if available_levels.is_empty():
		return
	current_level_selection_index = (current_level_selection_index + 1) % available_levels.size()
	_update_level_selection_highlight()

## レベル選択: ハイライト更新
func _update_level_selection_highlight():
	if ui_manager and ui_manager.land_command_ui:
		var selected_level = available_levels[current_level_selection_index]
		ui_manager.land_command_ui.highlight_level_button(selected_level)

## レベル選択: 確定
func _confirm_level_selection():
	if available_levels.is_empty():
		return
	var selected_level = available_levels[current_level_selection_index]
	# LandCommandUIのシグナル経由で処理
	if ui_manager and ui_manager.land_command_ui:
		ui_manager.land_command_ui._on_level_selected(selected_level)

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
	TargetSelectionHelper.focus_camera_on_tile(self, tile_index)

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


## 土地情報パネルの初期化
func _setup_land_info_panel():
	if land_info_panel:
		return
	
	var ActionMenuUIClass = load("res://scripts/ui_components/action_menu_ui.gd")
	if not ActionMenuUIClass:
		return
	
	land_info_panel = ActionMenuUIClass.new()
	land_info_panel.name = "LandInfoPanel"
	land_info_panel.set_position_left(false)  # 右側（上下ボタンの左）に配置
	
	if ui_manager:
		land_info_panel.set_ui_manager(ui_manager)
		ui_manager.add_child(land_info_panel)
