# TargetSelectionHelper - 対象選択の汎用ヘルパー
# 土地、クリーチャー、プレイヤーなど、あらゆる対象の選択に使用可能
# 
# 注意: このクラスは互換性のために維持されています。
# 実際の処理は以下のクラスに委譲されます:
# - TargetMarkerSystem: マーカー・カメラ・ハイライト
# - TargetFinder: ターゲット検索
# - TargetUIHelper: UI表示・入力処理
#
# 使い方:
# - staticメソッド: マーカー表示、ハイライト、ターゲット検索など
# - インスタンスメソッド: select_tile_from_list() などawaitが必要な処理
extends Node
class_name TargetSelectionHelper

# ============================================
# シグナル（インスタンス用）
# ============================================
signal tile_selection_completed(tile_index: int)
signal tile_selection_changed(tile_index: int)  # タイル切り替え時に発火

# ============================================
# インスタンス変数（タイル選択モード用）
# ============================================
var board_system = null
var ui_manager = null
var game_flow_manager = null

# タイル選択状態
var is_tile_selecting: bool = false
var available_tile_indices: Array = []
var current_tile_index: int = 0
var selection_marker: MeshInstance3D = null

# ============================================
# 初期化
# ============================================

## インスタンス初期化（GameFlowManagerから呼ばれる）
func initialize(board_sys, ui_mgr, flow_mgr):
	board_system = board_sys
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr

## マーカー回転処理（_processから呼ばれる）
func process(delta: float):
	if selection_marker and selection_marker.has_meta("rotating"):
		selection_marker.rotate_y(delta * 2.0)

# ============================================
# タイル選択（インスタンスメソッド - await対応）
# ============================================

## タイルリストから1つ選択（await対応）
## 
## tile_indices: 選択可能なタイルインデックスの配列
## message: 表示メッセージ
## 戻り値: 選択されたタイルインデックス（キャンセル時は-1）
func select_tile_from_list(tile_indices: Array, message: String) -> int:
	if tile_indices.is_empty():
		return -1
	
	# 選択モード開始
	is_tile_selecting = true
	available_tile_indices = tile_indices.duplicate()
	current_tile_index = 0
	
	# メッセージ表示
	if ui_manager and ui_manager.phase_display:
		ui_manager.show_action_prompt(message)
	
	# ナビゲーション設定
	_setup_tile_selection_navigation()
	
	# 最初のタイルを表示
	_update_tile_selection_display()
	
	# 選択完了を待機
	var result = await tile_selection_completed
	
	# 選択モード終了
	is_tile_selecting = false
	available_tile_indices.clear()
	
	# マーカーをクリア
	_hide_instance_marker()
	
	return result

## タイル選択のナビゲーション設定
func _setup_tile_selection_navigation():
	if not ui_manager:
		return
	
	ui_manager.enable_navigation(
		func(): _confirm_tile_selection(),  # 決定
		func(): _cancel_tile_selection(),   # キャンセル
		func(): _select_previous_tile(),    # 上（前へ）
		func(): _select_next_tile()         # 下（次へ）
	)

## タイル選択表示を更新
func _update_tile_selection_display():
	if available_tile_indices.is_empty():
		return
	
	var tile_index = available_tile_indices[current_tile_index]
	
	# マーカー表示
	_show_instance_marker(tile_index)
	
	# カメラフォーカス
	_focus_camera(tile_index)
	
	# アクション指示パネル更新
	if ui_manager and ui_manager.phase_display:
		var message = "タイル%d を選択中 (%d/%d) [←→で切替]" % [
			tile_index,
			current_tile_index + 1,
			available_tile_indices.size()
		]
		ui_manager.show_action_prompt(message)
	
	# タイル切り替えシグナル発火
	tile_selection_changed.emit(tile_index)

## 次のタイルを選択
func _select_next_tile():
	if available_tile_indices.is_empty():
		return
	current_tile_index = (current_tile_index + 1) % available_tile_indices.size()
	_update_tile_selection_display()

## 前のタイルを選択
func _select_previous_tile():
	if available_tile_indices.is_empty():
		return
	current_tile_index = (current_tile_index - 1 + available_tile_indices.size()) % available_tile_indices.size()
	_update_tile_selection_display()

## タイル選択を確定
func _confirm_tile_selection():
	if available_tile_indices.is_empty():
		tile_selection_completed.emit(-1)
		return
	
	# 入力ロック
	if game_flow_manager and game_flow_manager.has_method("lock_input"):
		game_flow_manager.lock_input()
	
	var selected = available_tile_indices[current_tile_index]
	tile_selection_completed.emit(selected)

## タイル選択をキャンセル
func _cancel_tile_selection():
	# 入力ロック
	if game_flow_manager and game_flow_manager.has_method("lock_input"):
		game_flow_manager.lock_input()
	
	tile_selection_completed.emit(-1)

## インスタンス用マーカーを表示
func _show_instance_marker(tile_index: int):
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	
	# マーカーが未作成なら作成
	if not selection_marker:
		selection_marker = TargetMarkerSystem.create_marker_mesh()
	
	# マーカーを土地の子として追加
	if selection_marker.get_parent():
		selection_marker.get_parent().remove_child(selection_marker)
	
	tile.add_child(selection_marker)
	selection_marker.position = Vector3(0, 0.5, 0)
	selection_marker.set_meta("rotating", true)

## インスタンス用マーカーを非表示
func _hide_instance_marker():
	if selection_marker and selection_marker.get_parent():
		selection_marker.get_parent().remove_child(selection_marker)

## カメラをフォーカス
func _focus_camera(tile_index: int):
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	var camera = board_system.camera
	
	if not camera:
		return
	
	var tile_pos = tile.global_position
	var camera_offset = Vector3(12, 15, 12)
	camera.position = tile_pos + camera_offset
	camera.look_at(tile_pos + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)

# ============================================
# 委譲: TargetMarkerSystem
# ============================================

static func create_selection_marker(handler):
	TargetMarkerSystem.create_selection_marker(handler)

static func show_selection_marker(handler, tile_index: int):
	TargetMarkerSystem.show_selection_marker(handler, tile_index)

static func hide_selection_marker(handler):
	TargetMarkerSystem.hide_selection_marker(handler)

static func rotate_selection_marker(handler, delta: float):
	TargetMarkerSystem.rotate_selection_marker(handler, delta)

static func show_multiple_markers(handler, tile_indices: Array):
	TargetMarkerSystem.show_multiple_markers(handler, tile_indices)

static func clear_confirmation_markers(handler):
	TargetMarkerSystem.clear_confirmation_markers(handler)

static func rotate_confirmation_markers(handler, delta: float):
	TargetMarkerSystem.rotate_confirmation_markers(handler, delta)

static func focus_camera_on_tile(handler, tile_index: int):
	TargetMarkerSystem.focus_camera_on_tile(handler, tile_index)

static func focus_camera_on_player(handler, player_id: int):
	TargetMarkerSystem.focus_camera_on_player(handler, player_id)

static func highlight_tile(handler, tile_index: int):
	TargetMarkerSystem.highlight_tile(handler, tile_index)

static func clear_all_highlights(handler):
	TargetMarkerSystem.clear_all_highlights(handler)

static func highlight_multiple_tiles(handler, tile_indices: Array):
	TargetMarkerSystem.highlight_multiple_tiles(handler, tile_indices)

# ============================================
# 委譲: TargetFinder
# ============================================

static func get_all_creatures(board_sys, condition: Dictionary = {}) -> Array:
	return TargetFinder.get_all_creatures(board_sys, condition)

static func get_valid_targets(handler, target_type: String, target_info: Dictionary) -> Array:
	return TargetFinder.get_valid_targets(handler, target_type, target_info)

static func get_valid_targets_core(systems: Dictionary, target_type: String, target_info: Dictionary) -> Array:
	return TargetFinder.get_valid_targets_core(systems, target_type, target_info)

# ============================================
# 委譲: TargetUIHelper
# ============================================

static func format_target_info(target_data: Dictionary, current_index: int, total_count: int) -> String:
	return TargetUIHelper.format_target_info(target_data, current_index, total_count)

static func get_confirmation_text(target_type: String, target_count: int) -> String:
	return TargetUIHelper.get_confirmation_text(target_type, target_count)

static func is_number_key(keycode: int) -> bool:
	return TargetUIHelper.is_number_key(keycode)

static func get_number_from_key(keycode: int) -> int:
	return TargetUIHelper.get_number_from_key(keycode)

static func move_target_next(handler) -> bool:
	return TargetUIHelper.move_target_next(handler)

static func move_target_previous(handler) -> bool:
	return TargetUIHelper.move_target_previous(handler)

static func select_target_by_index(handler, index: int) -> bool:
	return TargetUIHelper.select_target_by_index(handler, index)

# ============================================
# 複合処理（複数モジュールを使用）
# ============================================

## 対象データから土地インデックスを取得
static func get_tile_index_from_target(target_data: Dictionary, board_sys) -> int:
	var target_type = target_data.get("type", "")
	
	match target_type:
		"land", "creature", "gate":
			return target_data.get("tile_index", -1)
		"player":
			var player_id = target_data.get("player_id", -1)
			if player_id >= 0 and board_sys and board_sys.movement_controller:
				return board_sys.get_player_tile(player_id)
			return -1
		_:
			return -1

## 対象を視覚的に選択（マーカー、カメラ、ハイライト）
static func select_target_visually(handler, target_data: Dictionary):
	TargetMarkerSystem.clear_all_highlights(handler)
	
	var tile_index = get_tile_index_from_target(target_data, handler.board_system)
	
	if tile_index >= 0:
		TargetMarkerSystem.show_selection_marker(handler, tile_index)
		TargetMarkerSystem.focus_camera_on_tile(handler, tile_index)
		TargetMarkerSystem.highlight_tile(handler, tile_index)
	
	TargetUIHelper.show_creature_info_panel(handler, target_data)

## 対象選択を完全にクリア（マーカー、ハイライト）
static func clear_selection(handler):
	TargetMarkerSystem.clear_all_highlights(handler)
	TargetMarkerSystem.hide_selection_marker(handler)
	TargetUIHelper.hide_creature_info_panel(handler)

## 確認フェーズ用：対象タイプに応じたハイライト表示
static func show_confirmation_highlights(handler, target_type: String, target_info: Dictionary) -> int:
	TargetMarkerSystem.clear_all_highlights(handler)
	TargetMarkerSystem.clear_confirmation_markers(handler)
	
	var highlighted_tiles: Array = []
	
	match target_type:
		"self", "none":
			if handler.board_system:
				var current_player_id = handler.spell_state.current_player_id if (handler and handler.spell_state) else 0
				var player_tile = handler.board_system.get_player_tile(current_player_id)
				if player_tile >= 0:
					TargetMarkerSystem.show_selection_marker(handler, player_tile)
					TargetMarkerSystem.highlight_tile(handler, player_tile)
					highlighted_tiles.append(player_tile)
		
		"all_creatures":
			var targets = TargetFinder.get_valid_targets(handler, "creature", target_info)
			for target in targets:
				var tile_index = target.get("tile_index", -1)
				if tile_index >= 0:
					highlighted_tiles.append(tile_index)
			TargetMarkerSystem.highlight_multiple_tiles(handler, highlighted_tiles)
			TargetMarkerSystem.show_multiple_markers(handler, highlighted_tiles)
		
		"all_players":
			var targets = TargetFinder.get_valid_targets(handler, "player", target_info)
			for target in targets:
				var player_id = target.get("player_id", -1)
				if player_id >= 0 and handler.board_system:
					var player_tile = handler.board_system.get_player_tile(player_id)
					if player_tile >= 0:
						highlighted_tiles.append(player_tile)
			TargetMarkerSystem.highlight_multiple_tiles(handler, highlighted_tiles)
			TargetMarkerSystem.show_multiple_markers(handler, highlighted_tiles)
		
		"world":
			if handler.board_system:
				for tile_index in handler.board_system.tile_nodes.keys():
					highlighted_tiles.append(tile_index)
				TargetMarkerSystem.highlight_multiple_tiles(handler, highlighted_tiles)
	
	return highlighted_tiles.size()
