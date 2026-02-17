# DominioCommandHandler - ドミニオコマンドの処理を担当
extends Node
class_name DominioCommandHandler


## シグナル
signal dominio_command_opened()
signal dominio_command_closed()
@warning_ignore("unused_signal")
signal land_selected(tile_index: int)
@warning_ignore("unused_signal")
signal action_selected(action_type: String)

## 状態
enum State {
	CLOSED,              # ドミニオコマンド非表示
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
var swap_mode: bool = false  # 交換モード中フラグ
var swap_old_creature: Dictionary = {}  # 交換前のクリーチャーデータ
var swap_tile_index: int = -1  # 交換対象の土地インデックス

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

## 移動バトル関連フラグをリセット
func reset_move_battle_flags():
	is_waiting_for_move_defender_item = false
	is_boulder_eater_move = false

## バウダーイーター移動フラグを設定
func set_boulder_eater_move(enabled: bool):
	is_boulder_eater_move = enabled

# 移動先土地情報表示用
var land_info_panel = null

## 参照
var ui_manager = null
var board_system = null
var game_flow_manager = null
var game_3d_ref = null  # game_3d直接参照（get_parent()チェーン廃止用）
var player_system = null
var _item_phase_handler = null  # gfm.item_phase_handler参照（遅延取得）
var battle_system = null       # board_system.battle_system参照
var spell_cast_notification_ui = null  # spell_phase_handler.spell_cast_notification_ui参照

## サービス参照（DI パターン）
var _message_service = null
var _navigation_service = null
var _card_selection_service = null
var _info_panel_service = null

# === 直接参照（GFM経由を廃止） ===
var spell_world_curse = null  # SpellWorldCurse: 世界呪い
var spell_land = null  # SpellLand: 土地操作
var spell_curse = null  # SpellCurse: 呪い管理
var battle_status_overlay = null  # BattleStatusOverlay: バトルステータス表示

func set_battle_status_overlay(overlay) -> void:
	battle_status_overlay = overlay
	print("[DominioCommandHandler] battle_status_overlay 直接参照を設定")

## item_phase_handlerの遅延取得（初期化順序の都合でinitialize時にはまだ存在しない場合がある）
func _get_item_phase_handler():
	if not _item_phase_handler and game_flow_manager and game_flow_manager.get("item_phase_handler"):
		_item_phase_handler = game_flow_manager.item_phase_handler
	return _item_phase_handler

func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	TargetSelectionHelper.rotate_selection_marker(self, delta)

## 初期化
func initialize(ui_mgr, board_sys, flow_mgr, player_sys = null):
	ui_manager = ui_mgr

	# サービス解決
	if ui_mgr:
		_message_service = ui_mgr.message_service if ui_mgr.get("message_service") else null
		_navigation_service = ui_mgr.navigation_service if ui_mgr.get("navigation_service") else null
		_card_selection_service = ui_mgr.card_selection_service if ui_mgr.get("card_selection_service") else null
		_info_panel_service = ui_mgr.info_panel_service if ui_mgr.get("info_panel_service") else null

	board_system = board_sys
	game_flow_manager = flow_mgr
	player_system = player_sys

	# player_systemが渡されない場合はboard_systemから取得
	if not player_system and board_system:
		player_system = board_system.player_system
	
	# 子コンポーネント参照のキャッシュ
	if board_system and board_system.get("battle_system"):
		battle_system = board_system.battle_system

		# BattleSystem の invasion_completed シグナルに接続
		if battle_system and battle_system.has_signal("invasion_completed"):
			if not battle_system.invasion_completed.is_connected(_on_invasion_completed):
				battle_system.invasion_completed.connect(_on_invasion_completed)
				print("[DominioCommandHandler] BattleSystem.invasion_completed シグナル接続完了")

	# Phase 1-A: UIManagerのシグナルを接続
	if ui_manager and ui_manager.has_signal("level_up_selected"):
		if not ui_manager.level_up_selected.is_connected(_on_level_up_selected):
			ui_manager.level_up_selected.connect(_on_level_up_selected)
	
	# 土地情報パネルを初期化
	_setup_land_info_panel()

## game_3d参照を設定（TutorialManager取得用）
func set_game_3d_ref(p_game_3d) -> void:
	game_3d_ref = p_game_3d

## 直接参照を設定（GFM経由を廃止）
func set_spell_systems_direct(world_curse, land, curse) -> void:
	spell_world_curse = world_curse
	spell_land = land
	spell_curse = curse
	print("[DominioCommandHandler] spell_world_curse, spell_land, spell_curse 直接参照を設定")

## ドミニオコマンドを開く
func open_dominio_order(player_id: int):
	if current_state != State.CLOSED:
		return
	
	# プレイヤーの所有地を取得
	player_owned_lands = LandSelectionHelper.get_player_owned_lands(board_system, player_id)
	
	if player_owned_lands.is_empty():
		if _message_service:
			_message_service.show_toast("所有地がありません")
		return
	
	# ドミニオボタンを非表示（ドミニオコマンド中は表示しない）
	if ui_manager and ui_manager.has_method("hide_dominio_order_button"):
		ui_manager.hide_dominio_order_button()
	
	# カード選択UIを無効化
	if ui_manager and ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.deactivate()
	# 「召喚しない」をクリア
	if _navigation_service:
		_navigation_service.clear_back_action()

	# 前フェーズのナビゲーション保存状態をクリア
	if _navigation_service:
		_navigation_service.clear_navigation_saved_state()
	
	# 土地選択モードに移行
	current_state = State.SELECTING_LAND
	current_land_selection_index = 0  # 最初の土地を選択
	dominio_command_opened.emit()
	
	# 入力ロックを解除（土地選択待ち状態になった）
	if game_flow_manager:
		game_flow_manager.unlock_input()
	
	# ドミニオコマンドはグローバルキーで選択するため、TapTargetManagerは使用しない
	# _start_tap_target_selection(player_id)
	
	# 最初の土地を自動プレビュー
	if player_owned_lands.size() > 0:
		var first_tile = player_owned_lands[0]
		LandSelectionHelper.preview_land(self, first_tile)
		LandSelectionHelper.update_land_selection_ui(self)
	
	# UIに表示要請
	if ui_manager and ui_manager.has_method("show_land_selection_mode"):
		ui_manager.show_land_selection_mode(player_owned_lands)
	
	# ナビゲーションボタン設定（土地選択用）※preview_landの後に設定する
	# （preview_land→show_card_info(false)がナビゲーションをクリアするため）
	if _navigation_service:
		_navigation_service.enable_navigation(
			func(): LandSelectionHelper.confirm_land_selection(self),  # 決定
			func(): cancel(),  # 戻る
			func(): on_arrow_up(),  # 上
			func(): on_arrow_down()  # 下
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
	
	# アクション選択シグナルを発火
	action_selected.emit(action_type)
	
	var success = false
	match action_type:
		"level_up":
			success = LandActionHelper.execute_level_up(self)
		"move_creature":
			success = LandActionHelper.execute_move_creature(self)
		"swap_creature":
			success = LandActionHelper.execute_swap_creature(self)
		"terrain_change":
			success = execute_terrain_change()
	
	# 失敗時はアクション選択に戻す
	if not success:
		current_state = State.SELECTING_ACTION
		set_action_selection_navigation()
		restore_phase_comment()
	
	return success

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

## ドミニオコマンドを閉じる
func close_dominio_order():
	# マーカーを非表示
	TargetSelectionHelper.hide_selection_marker(self)
	
	# ドミニオコマンドはグローバルキーで選択するため、TapTargetManagerは使用しない
	# _end_tap_target_selection()
	
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
	swap_mode = false
	swap_old_creature = {}
	swap_tile_index = -1
	
	# 地形変化関連のリセット
	terrain_change_tile_index = -1
	current_terrain_index = 0
	
	# レベル選択関連のリセット
	available_levels.clear()
	current_level_selection_index = 0
	
	# TileActionProcessorのフラグをリセット
	if board_system and board_system.tile_action_processor:
		board_system.reset_action_processing()
	
	# ナビゲーションボタンをクリア
	if _navigation_service:
		_navigation_service.disable_navigation()
	
	# パネルを閉じる
	if ui_manager and ui_manager.dominio_order_ui:
		ui_manager.dominio_order_ui.hide_level_selection()
		ui_manager.dominio_order_ui.hide_terrain_selection()
	
	dominio_command_closed.emit()
	
	
	# カメラを現在のプレイヤーに戻す
	# MovementControllerからプレイヤーの実際の位置を取得
	if board_system and player_system:
		var player_id = player_system.current_player_index
		var player_tile_index = board_system.get_player_tile(player_id)
		
		if board_system.camera and board_system.tile_nodes.has(player_tile_index):
			var tile_pos = board_system.tile_nodes[player_tile_index].global_position
			
			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + GameConstants.CAMERA_OFFSET
			
			board_system.camera.position = new_camera_pos
			board_system.camera.look_at(tile_pos + Vector3(0, 1.0 + GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)
	
	# UIを非表示
	if ui_manager:
		if ui_manager.has_method("hide_dominio_order_ui"):
			ui_manager.hide_dominio_order_ui()
	# カード選択UIも非表示にする
	if _card_selection_service:
		_card_selection_service.hide_card_selection_ui()

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
			board_system.reset_action_processing()
		
		# UIを先に更新
		if ui_manager and ui_manager.dominio_order_ui:
			ui_manager.dominio_order_ui.hide_terrain_selection()
			ui_manager.dominio_order_ui.show_action_menu(selected_tile_index)
		
		# ナビゲーションはActionMenuUI内で設定される
	
	elif current_state == State.SELECTING_MOVE_DEST:
		# 移動先選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION
		
		# クリーチャー情報パネルを閉じる
		LandActionHelper.hide_move_creature_info(self)
		
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
		if ui_manager and ui_manager.dominio_order_ui:
			ui_manager.dominio_order_ui.hide_level_selection()
		
		if ui_manager and ui_manager.has_method("show_action_menu"):
			ui_manager.show_action_menu(selected_tile_index)
		
		# ナビゲーションはActionMenuUI内で設定される
	
	elif current_state == State.SELECTING_SWAP:
		# 交換クリーチャー選択中ならアクション選択に戻る
		current_state = State.SELECTING_ACTION

		swap_mode = false
		swap_old_creature = {}
		swap_tile_index = -1

		if board_system and board_system.tile_action_processor:
			board_system.reset_action_processing()

		# カード選択UIを閉じる
		if _card_selection_service:
			_card_selection_service.hide_card_selection_ui()

		# クリーチャー情報パネルを閉じる
		if _info_panel_service:
			_info_panel_service.hide_all_info_panels(false)
		
		# アクションメニューを表示
		if ui_manager and ui_manager.has_method("show_action_menu"):
			ui_manager.show_action_menu(selected_tile_index)
		
		# ナビゲーションはActionMenuUI内で設定される
		
	elif current_state == State.SELECTING_ACTION:
		# アクション選択中なら土地選択に戻る
		if ui_manager and ui_manager.dominio_order_ui:
			ui_manager.dominio_order_ui.hide_action_menu(false)  # ボタンクリアしない
		
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
		close_dominio_order()

## アクション選択用ナビゲーション設定（戻るのみ）
func set_action_selection_navigation():
	if _navigation_service:
		_navigation_service.enable_navigation(
			Callable(),  # 決定なし
			func(): cancel()  # 戻る
		)

## 現在の状態に応じてナビゲーションを復元
func restore_navigation():
	match current_state:
		State.SELECTING_LAND:
			_set_land_selection_navigation()
		State.SELECTING_ACTION:
			# ActionMenuUIがナビゲーションを設定するので、ここでは戻るボタンのみ
			set_action_selection_navigation()
		State.SELECTING_MOVE_DEST:
			# 移動先選択用ナビゲーション
			if _navigation_service:
				_navigation_service.enable_navigation(
					func(): LandActionHelper.confirm_move_selection(self),
					func(): cancel(),
					func(): on_arrow_up(),
					func(): on_arrow_down()
				)
		State.SELECTING_LEVEL:
			# レベル選択用ナビゲーション（LevelSelectionUIで管理されるのでキャンセルのみ）
			if _navigation_service:
				_navigation_service.enable_navigation(
					Callable(),  # 決定はLevelSelectionUIで処理
					func(): cancel(),
					func(): on_arrow_up(),
					func(): on_arrow_down()
				)
		State.SELECTING_TERRAIN:
			# 地形選択用ナビゲーション
			if _navigation_service:
				_navigation_service.enable_navigation(
					func(): LandActionHelper.confirm_terrain_selection(self),
					func(): cancel(),
					func(): on_arrow_up(),
					func(): on_arrow_down()
				)
		State.SELECTING_SWAP:
			# 交換選択用ナビゲーション（カード選択UI側で管理）
			if _navigation_service:
				_navigation_service.enable_navigation(
					Callable(),  # 決定はカード選択で処理
					func(): cancel()
				)
		_:
			pass

## 現在のステートに応じたフェーズコメントを復元
func restore_phase_comment():
	match current_state:
		State.SELECTING_LAND:
			LandSelectionHelper.update_land_selection_ui(self)
		State.SELECTING_ACTION:
			if _message_service:
				_message_service.show_action_prompt("アクションを選択してください")
		State.SELECTING_MOVE_DEST:
			if _message_service:
				_message_service.show_action_prompt("移動先を選択")
		State.SELECTING_LEVEL:
			if _message_service:
				_message_service.show_action_prompt("レベルアップする土地を選択")
		State.SELECTING_TERRAIN:
			if _message_service:
				_message_service.show_action_prompt("地形を選択")
		_:
			if _message_service:
				_message_service.hide_action_prompt()

## 土地選択用ナビゲーション設定（全ボタン）
func _set_land_selection_navigation():
	if _navigation_service:
		_navigation_service.enable_navigation(
			func(): LandSelectionHelper.confirm_land_selection(self),  # 決定
			func(): cancel(),  # 戻る
			func(): on_arrow_up(),  # 上
			func(): on_arrow_down()  # 下
		)

## 上下ボタンのコールバック（上）
func on_arrow_up():
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
			select_previous_level()

## 上下ボタンのコールバック（下）
func on_arrow_down():
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
			select_next_level()

## レベル選択: 前のレベルを選択（ループ）
func select_previous_level():
	if available_levels.is_empty():
		return
	current_level_selection_index = (current_level_selection_index - 1 + available_levels.size()) % available_levels.size()
	_update_level_selection_highlight()

## レベル選択: 次のレベルを選択（ループ）
func select_next_level():
	if available_levels.is_empty():
		return
	current_level_selection_index = (current_level_selection_index + 1) % available_levels.size()
	_update_level_selection_highlight()

## レベル選択: ハイライト更新
func _update_level_selection_highlight():
	if ui_manager and ui_manager.dominio_order_ui:
		var selected_level = available_levels[current_level_selection_index]
		ui_manager.dominio_order_ui.highlight_level_button(selected_level)

## レベル選択: 確定
func confirm_level_selection():
	if available_levels.is_empty():
		return
	var selected_level = available_levels[current_level_selection_index]
	# DominioOrderUIのシグナル経由で処理
	if ui_manager and ui_manager.dominio_order_ui:
		ui_manager.dominio_order_ui.on_level_selected(selected_level)

## Phase 1-A: レベル選択シグナルハンドラ
func _on_level_up_selected(target_level: int, cost: int):
	var success = LandActionHelper.execute_level_up_with_level(self, target_level, cost)
	if not success:
		# レベル選択UIを閉じてアクション選択に戻す
		if ui_manager and ui_manager.dominio_order_ui:
			ui_manager.dominio_order_ui.hide_level_selection()
		current_state = State.SELECTING_ACTION
		set_action_selection_navigation()
		if ui_manager and ui_manager.dominio_order_ui:
			ui_manager.dominio_order_ui.show_action_menu(selected_tile_index)
		if _message_service:
			_message_service.show_toast("EPが足りません")

## カード選択時の処理（交換モード用）
func on_card_selected_for_swap(card_index: int):
	if not swap_mode:
		return  # 交換モードでない場合は何もしない
	
	
	# 交換処理用に変数を保存
	var tile_index = swap_tile_index
	var old_creature = swap_old_creature.duplicate()
	
	# 交換モードをリセット
	swap_mode = false
	swap_old_creature = {}
	swap_tile_index = -1
	
	# TileActionProcessorの交換処理を呼び出す
	# 注: ドミニオコマンドはend_turn()で閉じられる
	if board_system and board_system.tile_action_processor:
		board_system.execute_swap_action(
			tile_index,
			card_index,
			old_creature
		)

## カード選択を処理（GFMのルーティング用）
## 戻り値: true=処理済み, false=処理不要
func try_handle_card_selection(card_index: int) -> bool:
	# 交換モードチェック
	if swap_mode:
		on_card_selected_for_swap(card_index)
		return true

	return false

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
		if _get_item_phase_handler():
			pending_move_attacker_item = _get_item_phase_handler().get_selected_item()
		
		# 防御側のアイテムフェーズを開始
		var defender_owner = pending_move_battle_tile_info.get("owner", -1)
		if defender_owner >= 0:
			is_waiting_for_move_defender_item = true
			
			# 防御側のアイテムフェーズ開始
			if _get_item_phase_handler():
				# 再度シグナルに接続（ONE_SHOTなので再接続が必要）
				if not _get_item_phase_handler().item_phase_completed.is_connected(_on_move_item_phase_completed):
					_get_item_phase_handler().item_phase_completed.connect(_on_move_item_phase_completed, CONNECT_ONE_SHOT)
				
				# 防御側クリーチャーのデータを取得して渡す
				var defender_creature = pending_move_battle_tile_info.get("creature", {})
				
				# バトルステータスオーバーレイを防御側に切り替え
				if battle_status_overlay:
					battle_status_overlay.highlight_side("defender")
				
				_get_item_phase_handler().start_item_phase(defender_owner, defender_creature)
			else:
				# ItemPhaseHandlerがない場合は直接バトル
				_execute_move_battle()
		else:
			# 防御側がいない場合（ありえないが念のため）
			_execute_move_battle()
	else:
		# 防御側のアイテムフェーズ完了 → バトル開始
		
		# 防御側のアイテムを保存
		if _get_item_phase_handler():
			pending_move_defender_item = _get_item_phase_handler().get_selected_item()
		
		is_waiting_for_move_defender_item = false
		_execute_move_battle()

## 保留中の移動バトルを実行
func _execute_move_battle():
	if pending_move_battle_creature_data.is_empty():
		if board_system and board_system.tile_action_processor:
			board_system.complete_action()
		return
	
	# バトルステータスオーバーレイを非表示
	if battle_status_overlay:
		battle_status_overlay.hide_battle_status()
	
	var current_player_index = board_system.current_player_index

	# バトル実行（移動元タイル情報も渡す）
	await battle_system.execute_3d_battle_with_data(
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
func _on_invasion_completed(success: bool, tile_index: int):
	# デバッグログ（Phase 2 テスト期間中）
	print("[DominioCommandHandler] invasion_completed 受信: success=%s, tile=%d" % [success, tile_index])

	# 衰弱（プレイグ）ダメージ処理
	_apply_plague_damage_after_battle(tile_index)

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

	# コメントはバトル前に表示済みのため、ここでは表示しない

	# アクション完了を通知（ターンを進める）
	print("[DominioCommandHandler] complete_action() を呼び出します")
	if board_system and board_system.tile_action_processor:
		board_system.complete_action()

func _on_movement_completed(player_id: int, final_tile: int):
	# デバッグログ
	print("[DominioCommandHandler] movement_completed 受信: player_id=%d, tile=%d" % [player_id, final_tile])

	# 移動完了時の処理が必要な場合はここに追加

func _on_level_up_completed(tile_index: int, new_level: int):
	# デバッグログ
	print("[DominioCommandHandler] level_up_completed 受信: tile=%d, level=%d" % [tile_index, new_level])

	# レベルアップ完了時の処理が必要な場合はここに追加


## バトル終了後の衰弱ダメージ処理
## ※衰弱はSkillBattleEndEffectsで処理されるため、ここでは何もしない
func _apply_plague_damage_after_battle(_tile_index: int) -> void:
	# 衰弱ダメージはbattle_execution.gd内のSkillBattleEndEffects.process_allで処理
	# ナチュラルワールド等による無効化チェックもそちらで行う
	pass

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

# ============================================================
# CPU用インターフェース
# ============================================================

## CPUがドミニオコマンドを実行（統合メソッド）
## 戻り値: 実行成功/失敗
func execute_for_cpu(command: Dictionary) -> bool:
	var command_type = command.get("type", "")
	
	print("[DominioCommandHandler] CPU実行: %s" % command_type)
	
	# コマンドタイプに応じて処理（各関数内でバリデーション）
	match command_type:
		"level_up", "element_change", "creature_swap":
			# tile_indexを使用するコマンド
			var tile_index = command.get("tile_index", -1)
			if not _select_tile_for_cpu(tile_index):
				print("[DominioCommandHandler] CPU: 土地選択失敗 (tile=%d)" % tile_index)
				return false
			
			match command_type:
				"level_up":
					return _execute_level_up_for_cpu(command)
				"element_change":
					return _execute_element_change_for_cpu(command)
				"creature_swap":
					return _execute_swap_for_cpu(command)
		
		"move_invasion":
			# from_tile_indexを使用するコマンド（バリデーションは_execute_move_for_cpu内で行う）
			return _execute_move_for_cpu(command)
	
	print("[DominioCommandHandler] CPU: 不明なコマンドタイプ: %s" % command_type)
	return false

## CPU用土地選択（バリデーション）
func _select_tile_for_cpu(tile_index: int) -> bool:
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return false
	
	var tile = board_system.tile_nodes[tile_index]
	
	# ダウンチェック
	if tile.has_method("is_down") and tile.is_down():
		print("[DominioCommandHandler] CPU: タイル%d はダウン中" % tile_index)
		return false
	
	# 所有権チェック
	var current_player = player_system.get_current_player()
	if tile.owner_id != current_player.id:
		print("[DominioCommandHandler] CPU: タイル%d は所有していない" % tile_index)
		return false
	
	selected_tile_index = tile_index
	return true

## CPU用レベルアップ
func _execute_level_up_for_cpu(command: Dictionary) -> bool:
	var target_level = command.get("target_level", 1)
	var cost = command.get("cost", 0)
	
	# LandActionHelperの既存処理を使用
	var success = LandActionHelper.execute_level_up_with_level(self, target_level, cost)
	
	if success:
		print("[DominioCommandHandler] CPU: レベルアップ成功 → Lv%d" % target_level)
	
	return success

## CPU用属性変更
func _execute_element_change_for_cpu(command: Dictionary) -> bool:
	var new_element = command.get("new_element", "")
	
	if new_element.is_empty():
		return false
	
	# LandActionHelperの既存処理を使用
	var success = LandActionHelper.execute_terrain_change_with_element(self, new_element)
	
	if success:
		print("[DominioCommandHandler] CPU: 属性変更成功 → %s" % new_element)
	
	return success

## CPU用移動（空き地・敵ドミニオ両対応）
func _execute_move_for_cpu(command: Dictionary) -> bool:
	var from_tile_index = command.get("from_tile_index", -1)
	var to_tile_index = command.get("to_tile_index", -1)
	
	print("[DominioCommandHandler] CPU移動: from=%d, to=%d" % [from_tile_index, to_tile_index])
	
	if from_tile_index < 0 or to_tile_index < 0:
		print("[DominioCommandHandler] CPU: 移動失敗 - 無効なタイルインデックス")
		return false
	
	# 移動元を選択（ダウンチェック含む）
	if not _select_tile_for_cpu(from_tile_index):
		print("[DominioCommandHandler] CPU: 移動失敗 - 移動元選択不可")
		return false
	
	# 移動元を設定
	move_source_tile = from_tile_index
	move_destinations = [to_tile_index]
	current_destination_index = 0
	
	# CPU攻撃側アイテムを事前設定（敵ドミニオへの移動の場合）
	var item_index = command.get("item_index", -1)
	var item_data = command.get("item_data", {})
	if item_index >= 0 and not item_data.is_empty():
		if _get_item_phase_handler():
			var item_with_index = item_data.duplicate()
			item_with_index["_hand_index"] = item_index
			_get_item_phase_handler().set_preselected_attacker_item(item_with_index)
			print("[DominioCommandHandler] CPU: 移動侵略アイテム事前設定: %s (index=%d)" % [item_data.get("name", "?"), item_index])
	
	# LandActionHelper.confirm_move を使用（空き地・敵ドミニオ両対応）
	LandActionHelper.confirm_move(self, to_tile_index)
	
	print("[DominioCommandHandler] CPU: 移動実行 %d → %d" % [from_tile_index, to_tile_index])
	return true

## CPU用クリーチャー交換
func _execute_swap_for_cpu(command: Dictionary) -> bool:
	var tile_index = command.get("tile_index", -1)
	var hand_index = command.get("hand_index", -1)
	
	if tile_index < 0 or hand_index < 0:
		return false
	
	# 土地は既に選択済みなのでselected_tile_indexを使う
	
	# 交換情報を設定
	var tile_info = board_system.get_tile_info(tile_index)
	swap_mode = true
	swap_old_creature = tile_info.get("creature", {}).duplicate()
	swap_tile_index = tile_index
	
	# TileActionProcessorに交換モードを設定
	if board_system.tile_action_processor:
		board_system.begin_action_processing()
	
	# 交換実行（既存のexecute_swapを使用）
	_execute_swap_with_hand_index_for_cpu(hand_index)
	
	return true

## CPU用交換実行（手札インデックス指定）
func _execute_swap_with_hand_index_for_cpu(hand_index: int):
	var current_player_index = board_system.current_player_index
	var tile = board_system.tile_nodes.get(swap_tile_index)
	
	if not tile:
		_complete_swap_for_cpu(false)
		return
	
	# 新しいクリーチャーのデータを取得
	var card_system = board_system.card_system
	var new_creature = card_system.get_card_data_for_player(current_player_index, hand_index)
	
	if new_creature.is_empty():
		_complete_swap_for_cpu(false)
		return
	
	# 元のクリーチャーを手札に戻す
	var old_creature = tile.creature_data.duplicate()
	card_system.add_card_to_hand(current_player_index, old_creature)
	
	# 新しいクリーチャーを手札から消費
	card_system.use_card_for_player(current_player_index, hand_index)
	
	# タイルに新しいクリーチャーを配置
	tile.place_creature(new_creature)
	
	# ダウン状態設定（不屈チェック）
	if tile.has_method("set_down_state"):
		if not PlayerBuffSystem.has_unyielding(new_creature):
			tile.set_down_state(true)
	
	print("[DominioCommandHandler] CPU: 交換成功 %s → %s" % [
		old_creature.get("name", "?"), new_creature.get("name", "?")])
	
	_complete_swap_for_cpu(true)

## CPU用交換完了処理
func _complete_swap_for_cpu(_success: bool):
	swap_mode = false
	swap_old_creature = {}
	swap_tile_index = -1
	selected_tile_index = -1
	
	# UI更新
	if ui_manager:
		ui_manager.update_player_info_panels()
	
	# アクション完了通知
	if board_system and board_system.tile_action_processor:
		board_system.complete_action()


# ========================================
# TapTargetManager連携
# ========================================

## タップターゲット選択を開始
func _start_tap_target_selection(player_id: int):
	if not ui_manager or not ui_manager.tap_target_manager:
		return
	
	var ttm = ui_manager.tap_target_manager
	ttm.set_current_player(player_id)
	
	# シグナル接続（重複防止）
	if not ttm.target_selected.is_connected(_on_tap_target_selected):
		ttm.target_selected.connect(_on_tap_target_selected)
	
	# 有効なターゲット：自分の非ダウンクリーチャーがいるタイル
	var valid_targets = ttm.get_own_active_creature_tiles()
	
	ttm.start_selection(
		valid_targets,
		TapTargetManager.SelectionType.CREATURE,
		"DominioCommandHandler"
	)
	
	print("[DominioCommandHandler] タップターゲット選択開始: %d件" % valid_targets.size())


## タップターゲット選択を終了
func _end_tap_target_selection():
	if not ui_manager or not ui_manager.tap_target_manager:
		return
	
	var ttm = ui_manager.tap_target_manager
	
	# シグナル切断
	if ttm.target_selected.is_connected(_on_tap_target_selected):
		ttm.target_selected.disconnect(_on_tap_target_selected)
	
	ttm.end_selection()
	print("[DominioCommandHandler] タップターゲット選択終了")


## タップでターゲットが選択された時
func _on_tap_target_selected(tile_index: int, _creature_data: Dictionary):
	print("[DominioCommandHandler] タップでタイル選択: %d (状態: %s)" % [tile_index, State.keys()[current_state]])
	
	match current_state:
		State.SELECTING_LAND:
			# 土地選択中 → そのタイルを選択
			if tile_index in player_owned_lands:
				# インデックスを更新
				current_land_selection_index = player_owned_lands.find(tile_index)
				LandSelectionHelper.preview_land(self, tile_index)
				LandSelectionHelper.update_land_selection_ui(self)
				# 自動で確定
				LandSelectionHelper.confirm_land_selection(self)
		
		State.SELECTING_ACTION:
			# アクション選択中 → 別のタイルに切り替え
			if tile_index in player_owned_lands and tile_index != selected_tile_index:
				# 一旦土地選択に戻してから新しいタイルを選択
				current_state = State.SELECTING_LAND
				current_land_selection_index = player_owned_lands.find(tile_index)
				LandSelectionHelper.preview_land(self, tile_index)
				LandSelectionHelper.update_land_selection_ui(self)
				LandSelectionHelper.confirm_land_selection(self)
		
		State.SELECTING_MOVE_DEST:
			# 移動先選択中 → 移動先を選択（確認待ち）
			if tile_index in move_destinations:
				current_destination_index = move_destinations.find(tile_index)
				# マーカーを移動先に表示
				TargetSelectionHelper.show_selection_marker(self, tile_index)
				TargetSelectionHelper.focus_camera_on_tile(self, tile_index)
				# UI更新
				LandActionHelper.update_move_destination_ui(self)
				# 確認フェーズへ（即座に移動しない）
				print("[DominioCommandHandler] 移動先選択: タイル%d - 決定ボタンで確定してください" % tile_index)
		
		_:
			# その他の状態では何もしない
			pass


## 移動侵略シーケンス（カメラ移動→コメント→アイテムフェーズ）
func start_move_battle_sequence(dest_tile_index: int, attacker_player: int, creature_data: Dictionary):
	# 1. カメラを移動先タイルにフォーカス
	TargetSelectionHelper.focus_camera_on_tile(self, dest_tile_index)
	
	# 2. コメント表示（クリック待ち）
	await _show_dominio_order_comment("移動侵略")
	
	# 3. バトルステータスオーバーレイ表示
	if battle_status_overlay:
		var attacker_display = creature_data.duplicate()
		attacker_display["land_bonus_hp"] = 0  # 侵略側は土地ボーナスなし
		
		var defender_creature = pending_move_battle_tile_info.get("creature", {})
		var defender_display = defender_creature.duplicate()
		defender_display["land_bonus_hp"] = _calculate_land_bonus(defender_creature, pending_move_battle_tile_info)
		
		battle_status_overlay.show_battle_status(
			attacker_display, defender_display, "attacker")
	
	# 4. アイテムフェーズを開始（攻撃側）
	if _get_item_phase_handler():
		# アイテムフェーズ完了シグナルに接続
		if not _get_item_phase_handler().item_phase_completed.is_connected(_on_move_item_phase_completed):
			_get_item_phase_handler().item_phase_completed.connect(_on_move_item_phase_completed, CONNECT_ONE_SHOT)
		
		# 攻撃側のアイテムフェーズ開始（防御側情報を渡して事前選択）
		var defender_tile_info = pending_move_battle_tile_info
		_get_item_phase_handler().start_item_phase(
			attacker_player,
			creature_data,
			defender_tile_info
		)
	else:
		# ItemPhaseHandlerがない場合は直接バトル
		_execute_move_battle()


## ドミニオコマンド使用コメントを表示（アクション確定時）
func _show_dominio_order_comment(action_name: String):
	if not _message_service:
		return

	var player_id = board_system.current_player_index if board_system else 0
	var player_name = "プレイヤー"
	if player_system and player_id < player_system.players.size():
		var player = player_system.players[player_id]
		if player:
			player_name = player.name

	var message = "%s がドミニオコマンド：%s" % [player_name, action_name]
	await _message_service.show_comment_and_wait(message, player_id, true)


## 現在のプレイヤー名を取得（コメント表示用）
func _get_current_player_name() -> String:
	var player_id = board_system.current_player_index if board_system else 0
	if player_system and player_id < player_system.players.size():
		var player = player_system.players[player_id]
		if player:
			return player.name
	return "プレイヤー"


## バトルステータスオーバーレイ用の土地ボーナス計算
func _calculate_land_bonus(creature_data: Dictionary, tile_info: Dictionary) -> int:
	var creature_element = creature_data.get("element", "")
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	if tile_element == "neutral":
		return tile_level * 10
	
	if creature_element != "" and creature_element == tile_element:
		return tile_level * 10
	
	return 0
