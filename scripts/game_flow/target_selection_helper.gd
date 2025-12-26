# TargetSelectionHelper - 対象選択の汎用ヘルパー
# TargetSelectionHelper - 対象選択の汎用ヘルパー
# 土地、クリーチャー、プレイヤーなど、あらゆる対象の選択に使用可能
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
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = message
	
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
	
	# フェーズラベル更新
	if ui_manager and ui_manager.phase_label:
		var base_text = ui_manager.phase_label.text.split("\n")[0]  # 最初の行を維持
		ui_manager.phase_label.text = "%s\nタイル%d (%d/%d) [←→で切替]" % [
			base_text,
			tile_index,
			current_tile_index + 1,
			available_tile_indices.size()
		]

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
		selection_marker = _create_marker_mesh()
	
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
	camera.look_at(tile_pos, Vector3.UP)

# ============================================
# 選択マーカーシステム（staticメソッド）
# ============================================

## 選択マーカーを作成
## 
## handler: 選択マーカーを保持するオブジェクト（LandCommandHandler、SpellPhaseHandlerなど）
##          handler.selection_marker プロパティが必要
static func create_selection_marker(handler):
	if handler.selection_marker:
		return  # 既に存在する場合は何もしない
	
	# シンプルなリング形状のマーカーを作成
	handler.selection_marker = MeshInstance3D.new()
	
	# トーラス（ドーナツ型）メッシュを作成
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 16
	
	handler.selection_marker.mesh = torus
	
	# マテリアル設定（黄色で発光）
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.0, 1.0)  # 黄色
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 0.0)
	material.emission_energy_multiplier = 2.0
	handler.selection_marker.material_override = material

## 選択マーカーを表示
## 
## handler: 選択マーカーを保持するオブジェクト
##          handler.selection_marker と handler.board_system が必要
## tile_index: マーカーを表示する土地のインデックス
static func show_selection_marker(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	
	# マーカーが未作成なら作成
	if not handler.selection_marker:
		create_selection_marker(handler)
	
	# マーカーを土地の子として追加
	if handler.selection_marker.get_parent():
		handler.selection_marker.get_parent().remove_child(handler.selection_marker)
	
	tile.add_child(handler.selection_marker)
	
	# 位置を土地の少し上に設定
	handler.selection_marker.position = Vector3(0, 0.5, 0)
	
	# 回転アニメーションを追加
	if not handler.selection_marker.has_meta("rotating"):
		handler.selection_marker.set_meta("rotating", true)

## 選択マーカーを非表示
## 
## handler: 選択マーカーを保持するオブジェクト
static func hide_selection_marker(handler):
	if handler.selection_marker and handler.selection_marker.get_parent():
		handler.selection_marker.get_parent().remove_child(handler.selection_marker)

## 選択マーカーを回転（_process内で呼ぶ）
## 
## handler: 選択マーカーを保持するオブジェクト
## delta: フレーム間の経過時間
static func rotate_selection_marker(handler, delta: float):
	if handler.selection_marker and handler.selection_marker.has_meta("rotating"):
		handler.selection_marker.rotate_y(delta * 2.0)  # 1秒で約114度回転


## 複数マーカーを表示（確認フェーズ用）
## 
## handler: confirmation_markers配列とboard_systemを持つオブジェクト
## tile_indices: マーカーを表示するタイルインデックスの配列
static func show_multiple_markers(handler, tile_indices: Array):
	# 既存のマーカーをクリア
	clear_confirmation_markers(handler)
	
	if not handler.board_system:
		return
	
	for tile_index in tile_indices:
		if not handler.board_system.tile_nodes.has(tile_index):
			continue
		
		var tile = handler.board_system.tile_nodes[tile_index]
		
		# マーカーを作成
		var marker = _create_marker_mesh()
		tile.add_child(marker)
		marker.position = Vector3(0, 0.5, 0)
		marker.set_meta("rotating", true)
		
		handler.confirmation_markers.append(marker)


## 確認フェーズ用マーカーをすべてクリア
## 
## handler: confirmation_markers配列を持つオブジェクト
static func clear_confirmation_markers(handler):
	if not "confirmation_markers" in handler:
		return
	
	for marker in handler.confirmation_markers:
		if marker and is_instance_valid(marker):
			if marker.get_parent():
				marker.get_parent().remove_child(marker)
			marker.queue_free()
	
	handler.confirmation_markers.clear()


## 確認フェーズ用マーカーを回転（_process内で呼ぶ）
## 
## handler: confirmation_markers配列を持つオブジェクト
## delta: フレーム間の経過時間
static func rotate_confirmation_markers(handler, delta: float):
	if not "confirmation_markers" in handler:
		return
	
	for marker in handler.confirmation_markers:
		if marker and is_instance_valid(marker) and marker.has_meta("rotating"):
			marker.rotate_y(delta * 2.0)


## マーカーメッシュを作成（内部用 - create_selection_markerと同じ設定）
static func _create_marker_mesh() -> MeshInstance3D:
	var marker = MeshInstance3D.new()
	
	# トーラス（ドーナツ型）メッシュを作成
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 16
	marker.mesh = torus
	
	# マテリアル設定（黄色で発光）
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.0, 1.0)  # 黄色
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 0.0)
	material.emission_energy_multiplier = 2.0
	marker.material_override = material
	
	return marker

# ============================================
# カメラ制御
# ============================================

## カメラを土地にフォーカス
## 
## handler: board_system を持つオブジェクト
## tile_index: フォーカスする土地のインデックス
static func focus_camera_on_tile(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	var camera = handler.board_system.camera
	
	if not camera:
		return
	
	# カメラを土地の上方に移動
	var tile_pos = tile.global_position
	var camera_offset = Vector3(12, 15, 12)
	camera.position = tile_pos + camera_offset
	
	# カメラを土地に向ける
	camera.look_at(tile_pos, Vector3.UP)

## カメラをプレイヤーにフォーカス
## 
## handler: board_system を持つオブジェクト
## player_id: フォーカスするプレイヤーのID
static func focus_camera_on_player(handler, player_id: int):
	if not handler.board_system or not handler.board_system.movement_controller:
		return
	
	# プレイヤーの位置（タイル）を取得
	var player_tile = handler.board_system.movement_controller.get_player_tile(player_id)
	
	if player_tile >= 0:
		# プレイヤーがいる土地にカメラをフォーカス
		focus_camera_on_tile(handler, player_tile)

# ============================================
# ハイライト制御
# ============================================

## 土地をハイライト
## 
## handler: board_system を持つオブジェクト
## tile_index: ハイライトする土地のインデックス
static func highlight_tile(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	if tile.has_method("set_highlight"):
		tile.set_highlight(true)

## すべてのハイライトをクリア
## 
## handler: board_system を持つオブジェクト
static func clear_all_highlights(handler):
	if not handler.board_system:
		return
	
	for tile_idx in handler.board_system.tile_nodes.keys():
		var tile = handler.board_system.tile_nodes[tile_idx]
		if tile.has_method("set_highlight"):
			tile.set_highlight(false)


## 複数タイルをハイライト
## 
## handler: board_system を持つオブジェクト
## tile_indices: ハイライトするタイルインデックスの配列
static func highlight_multiple_tiles(handler, tile_indices: Array):
	if not handler.board_system:
		return
	
	for tile_index in tile_indices:
		if handler.board_system.tile_nodes.has(tile_index):
			var tile = handler.board_system.tile_nodes[tile_index]
			if tile.has_method("set_highlight"):
				tile.set_highlight(true)


## 確認フェーズ用：対象タイプに応じたハイライト表示
## 
## handler: SpellPhaseHandler等
## target_type: "self", "all_creatures", "all_players", "world", "none"
## target_info: フィルター条件
## 戻り値: ハイライトしたタイル数
static func show_confirmation_highlights(handler, target_type: String, target_info: Dictionary) -> int:
	clear_all_highlights(handler)
	clear_confirmation_markers(handler)
	
	var highlighted_tiles: Array = []
	
	match target_type:
		"self", "none":
			# 自分の位置にマーカー表示
			if handler.board_system and handler.board_system.movement_controller:
				var player_tile = handler.board_system.movement_controller.get_player_tile(handler.current_player_id)
				if player_tile >= 0:
					show_selection_marker(handler, player_tile)
					highlight_tile(handler, player_tile)
					highlighted_tiles.append(player_tile)
		
		"all_creatures":
			# 全クリーチャー対象（防魔除外済み）- 各タイルにマーカー表示
			var targets = get_valid_targets(handler, "creature", target_info)
			for target in targets:
				var tile_index = target.get("tile_index", -1)
				if tile_index >= 0:
					highlighted_tiles.append(tile_index)
			highlight_multiple_tiles(handler, highlighted_tiles)
			show_multiple_markers(handler, highlighted_tiles)
		
		"all_players":
			# 全プレイヤー対象（防魔除外済み）- 各プレイヤー位置にマーカー表示
			var targets = get_valid_targets(handler, "player", target_info)
			for target in targets:
				var player_id = target.get("player_id", -1)
				if player_id >= 0 and handler.board_system and handler.board_system.movement_controller:
					var player_tile = handler.board_system.movement_controller.get_player_tile(player_id)
					if player_tile >= 0:
						highlighted_tiles.append(player_tile)
			highlight_multiple_tiles(handler, highlighted_tiles)
			show_multiple_markers(handler, highlighted_tiles)
		
		"world":
			# 世界呪い：全タイルをハイライト（マーカーは多すぎるので省略）
			if handler.board_system:
				for tile_index in handler.board_system.tile_nodes.keys():
					highlighted_tiles.append(tile_index)
				highlight_multiple_tiles(handler, highlighted_tiles)
	
	return highlighted_tiles.size()


## 確認フェーズ用：対象の説明テキストを生成
## 
## target_type: "self", "all_creatures", "all_players", "world", "none"
## target_count: ハイライトされた対象数
## 戻り値: 説明テキスト
static func get_confirmation_text(target_type: String, target_count: int) -> String:
	match target_type:
		"self":
			return "自分自身に効果を発動します"
		"none":
			return "効果を発動します"
		"all_creatures":
			if target_count > 0:
				return "クリーチャー %d体に効果を発動します" % target_count
			else:
				return "対象となるクリーチャーがいません"
		"all_players":
			if target_count > 0:
				return "プレイヤー %d人に効果を発動します" % target_count
			else:
				return "対象となるプレイヤーがいません"
		"world":
			return "世界全体に効果を発動します"
		_:
			return "効果を発動します"


# ============================================
# 対象タイプ別の処理
# ============================================

## 対象データから土地インデックスを取得
## 
## target_data: 対象データ（type, tile_index, player_idなどを含む）
## board_sys: BoardSystem3Dの参照（プレイヤー位置取得に必要）
## 戻り値: 土地インデックス、取得できない場合は-1
static func get_tile_index_from_target(target_data: Dictionary, board_sys) -> int:
	var target_type = target_data.get("type", "")
	
	match target_type:
		"land", "creature", "gate":
			# 土地、クリーチャー、ゲートの場合、tile_indexを直接使用
			return target_data.get("tile_index", -1)
		
		"player":
			# プレイヤーの場合、プレイヤーの位置を取得
			var player_id = target_data.get("player_id", -1)
			if player_id >= 0 and board_sys and board_sys.movement_controller:
				return board_sys.movement_controller.get_player_tile(player_id)
			return -1
		
		_:
			return -1

## 対象を視覚的に選択（マーカー、カメラ、ハイライト）
## 
## handler: board_system と selection_marker を持つオブジェクト
## target_data: 対象データ
static func select_target_visually(handler, target_data: Dictionary):
	# 前のハイライトをクリア
	clear_all_highlights(handler)
	
	# 対象の土地インデックスを取得
	var tile_index = get_tile_index_from_target(target_data, handler.board_system)
	
	if tile_index >= 0:
		# マーカーを表示
		show_selection_marker(handler, tile_index)
		
		# カメラをフォーカス
		focus_camera_on_tile(handler, tile_index)
		
		# ハイライトを表示
		highlight_tile(handler, tile_index)
	
	# クリーチャー対象の場合、情報パネルを表示
	_show_creature_info_panel(handler, target_data)

## 対象選択を完全にクリア（マーカー、ハイライト）
## 
## handler: board_system と selection_marker を持つオブジェクト
static func clear_selection(handler):
	# ハイライトをクリア
	clear_all_highlights(handler)
	
	# マーカーを非表示
	hide_selection_marker(handler)
	
	# クリーチャー情報パネルを非表示
	_hide_creature_info_panel(handler)

# ============================================
# 入力ヘルパー
# ============================================

## 数字キーかどうか
static func is_number_key(keycode: int) -> bool:
	return keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

## キーコードから数字を取得（0-9）
static func get_number_from_key(keycode: int) -> int:
	var key_to_index = {
		KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4,
		KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9
	}
	return key_to_index.get(keycode, -1)

# ============================================
# ターゲット検索システム
# ============================================

## 条件付きで全クリーチャーを取得（handlerなしで使用可能）
## 
## board_sys: BoardSystem3Dの参照
## condition: 条件辞書（condition_type, operator, value等）
## 戻り値: [{tile_index: int, creature: Dictionary}, ...]
static func get_all_creatures(board_sys, condition: Dictionary = {}) -> Array:
	var results = []
	
	if not board_sys:
		return results
	
	var condition_type = condition.get("condition_type", "")
	var operator = condition.get("operator", "")
	var check_value = condition.get("value", 0)
	
	for tile_index in board_sys.tile_nodes.keys():
		var tile = board_sys.tile_nodes[tile_index]
		if not tile or tile.creature_data.is_empty():
			continue
		
		var creature = tile.creature_data
		
		# 条件チェック
		var matches = true
		if condition_type == "mhp_check":
			var mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
			match operator:
				"<=":
					matches = (mhp <= check_value)
				"<":
					matches = (mhp < check_value)
				">=":
					matches = (mhp >= check_value)
				">":
					matches = (mhp > check_value)
				"==":
					matches = (mhp == check_value)
		
		if matches:
			results.append({
				"tile_index": tile_index,
				"creature": creature
			})
	
	return results

## 隣接する敵領地があるかチェック（アウトレイジ用）
static func _check_has_adjacent_enemy(board_sys, tile_index: int, current_player_id: int) -> bool:
	if not board_sys or not board_sys.tile_neighbor_system:
		return false
	
	var adjacent_tiles = board_sys.tile_neighbor_system.get_spatial_neighbors(tile_index)
	for adj_tile_index in adjacent_tiles:
		var adj_tile = board_sys.tile_nodes.get(adj_tile_index)
		if not adj_tile:
			continue
		# 敵領地かチェック（空地や自領地は除外）
		if adj_tile.owner_id != -1 and adj_tile.owner_id != current_player_id:
			return true
	
	return false


## 有効なターゲットを取得
## 
## handler: board_system, player_system, current_player_id を持つオブジェクト
## target_type: "land", "creature", "player" など
## target_info: フィルター条件（owner_filter, max_level, required_elements など）
## 戻り値: ターゲット情報の配列
static func get_valid_targets(handler, target_type: String, target_info: Dictionary) -> Array:
	var targets = []
	
	match target_type:
		"creature":
			# クリーチャーを探す（条件フィルタ対応）
			if handler.board_system:
				# タイル番号順にソート
				var tile_indices = handler.board_system.tile_nodes.keys()
				tile_indices.sort()
				
				for tile_index in tile_indices:
					var tile_info = handler.board_system.get_tile_info(tile_index)
					var creature = tile_info.get("creature", {})
					if creature.is_empty():
						continue
					
					var tile_owner = tile_info.get("owner", -1)
					var tile_element = tile_info.get("element", "")
					var tile = handler.board_system.tile_nodes[tile_index]
					
					# owner_filter チェック
					var owner_filter = target_info.get("owner_filter", "enemy")
					if owner_filter == "own" and tile_owner != handler.current_player_id:
						continue
					if owner_filter == "enemy" and (tile_owner == handler.current_player_id or tile_owner < 0):
						continue
					# "any" は全てのクリーチャー（所有者がいる場合のみ）
					if owner_filter == "any" and tile_owner < 0:
						continue
					
					# creature_elements チェック（クリーチャー属性制限）
					var creature_elements = target_info.get("creature_elements", [])
					if not creature_elements.is_empty():
						var creature_element = creature.get("element", "")
						if creature_element not in creature_elements:
							continue
					
					# has_curse チェック（クリーチャーの呪いはcreature_data["curse"]に保存）
					if target_info.get("has_curse", false):
						if creature.get("curse", {}).is_empty():
							continue
					
					# has_no_curse チェック（呪いを持っていないクリーチャーのみ）
					if target_info.get("has_no_curse", false):
						if not creature.get("curse", {}).is_empty():
							continue
					
					# has_no_mystic_arts チェック（秘術を持っていないクリーチャーのみ）
					if target_info.get("has_no_mystic_arts", false):
						var mystic_arts = creature.get("ability_parsed", {}).get("mystic_arts", [])
						if not mystic_arts.is_empty():
							continue
					
					# has_summon_condition チェック
					# cost_lands_required または cost_cards_sacrifice があれば召喚条件あり
					if target_info.get("has_summon_condition", false):
						var has_lands = creature.has("cost_lands_required")
						var has_sacrifice = creature.has("cost_cards_sacrifice")
						if not has_lands and not has_sacrifice:
							continue
					
					# no_summon_condition チェック（召喚条件がないクリーチャーのみ）
					if target_info.get("no_summon_condition", false):
						var has_lands = creature.has("cost_lands_required") and creature.cost_lands_required > 0
						var has_sacrifice = creature.has("cost_cards_sacrifice") and creature.cost_cards_sacrifice > 0
						if has_lands or has_sacrifice:
							continue
					
					# hp_reduced チェック
					if target_info.get("hp_reduced", false):
						var base_hp = creature.get("hp", 0)
						var base_up_hp = creature.get("base_up_hp", 0)
						var max_hp = base_hp + base_up_hp
						var current_hp = creature.get("current_hp", max_hp)
						if current_hp >= max_hp:
							continue
					
					# is_down チェック
					if target_info.get("is_down", false):
						var is_down = tile.is_down() if tile.has_method("is_down") else false
						if not is_down:
							continue
					
					# has_adjacent_enemy チェック（アウトレイジ用：隣接敵領地があるか）
					if target_info.get("has_adjacent_enemy", false):
						var has_adjacent = _check_has_adjacent_enemy(handler.board_system, tile_index, handler.current_player_id)
						if not has_adjacent:
							continue
					
					# mhp_check チェック
					var mhp_check = target_info.get("mhp_check", {})
					if not mhp_check.is_empty():
						var base_hp = creature.get("hp", 0)
						var base_up_hp = creature.get("base_up_hp", 0)
						var mhp = base_hp + base_up_hp
						var op = mhp_check.get("operator", "")
						var val = mhp_check.get("value", 0)
						match op:
							">=":
								if mhp < val: continue
							"<=":
								if mhp > val: continue
							">":
								if mhp <= val: continue
							"<":
								if mhp >= val: continue
					
					# element_mismatch チェック（領地属性とクリーチャー属性の不一致）
					if target_info.get("element_mismatch", false):
						var creature_element = creature.get("element", "")
						if creature_element == tile_element or creature_element == "neutral":
							continue
					
					# can_move チェック（移動不可呪いがないこと）- 移動系スペル/秘術用
					if target_info.get("can_move", false):
						var curse = creature.get("curse", {})
						if curse.get("curse_type", "") == "move_disable":
							continue
					
					# require_mystic_arts チェック（秘術を持つクリーチャーのみ）- テンプテーション用
					# use_hand_spell秘術は除外（ルーンアデプトのスペル借用）
					if target_info.get("require_mystic_arts", false):
						var mystic_arts = creature.get("ability_parsed", {}).get("mystic_arts", [])
						# use_hand_spellを除外した秘術があるかチェック
						var usable_arts = mystic_arts.filter(func(art):
							var effects = art.get("effects", [])
							for effect in effects:
								if effect.get("effect_type", "") == "use_hand_spell":
									return false
							return true
						)
						if usable_arts.is_empty():
							continue
					
					# require_not_down チェック（ダウンしていないクリーチャーのみ）- テンプテーション用
					if target_info.get("require_not_down", false):
						var is_down = tile.is_down() if tile.has_method("is_down") else false
						if is_down:
							continue
					
					# HP効果無効チェック（affects_hpスペルの場合、HP効果無効持ちは除外）
					if target_info.get("affects_hp", false):
						if SpellHpImmune.has_hp_effect_immune(creature):
							continue
					
					# most_common_element チェックはここではスキップ（後処理で絞り込む）
					
					# 全条件を満たしたターゲットを追加
					targets.append({
						"type": "creature",
						"tile_index": tile_index,
						"creature": creature,
						"owner": tile_owner
					})
		
		"player":
			# プレイヤーを対象とする
			if handler.player_system:
				var target_filter = target_info.get("target_filter", "any")  # "own", "enemy", "any"
				
				for player in handler.player_system.players:
					var is_current = (player.id == handler.current_player_id)
					
					# フィルター判定
					var matches = false
					if target_filter == "own":
						matches = is_current
					elif target_filter == "enemy":
						matches = not is_current
					elif target_filter == "any":
						matches = true
					
					if matches:
						targets.append({
							"type": "player",
							"player_id": player.id,
							"player": {
								"name": player.name,
								"magic_power": player.magic_power,
								"id": player.id
							}
						})
		
		"land", "own_land", "enemy_land":
			# 土地を対象とする
			if handler.board_system:
				# target_typeに応じてデフォルトのowner_filterを設定
				var default_owner_filter = "any"
				if target_type == "own_land":
					default_owner_filter = "own"
				elif target_type == "enemy_land":
					default_owner_filter = "enemy"
				var owner_filter = target_info.get("owner_filter", default_owner_filter)
				var target_filter = target_info.get("target_filter", "")  # "creature", "empty", ""
				
				# タイル番号順にソート
				var tile_indices = handler.board_system.tile_nodes.keys()
				tile_indices.sort()
				
				for tile_index in tile_indices:
					var tile_info = handler.board_system.get_tile_info(tile_index)
					var tile_owner = tile_info.get("owner", -1)
					var creature = tile_info.get("creature", {})
					
					# 距離制限がある場合は全土地対象（マジカルリープ等のプレイヤー移動スペル）
					var has_distance_filter = target_info.has("distance_min") or target_info.has("distance_max")
					
					# 空き地フィルター（target_filter: "empty"）- 所有者フィルターより優先
					if target_filter == "empty":
						# クリーチャーがいない土地のみ対象
						if not creature.is_empty():
							continue
						# 特殊タイル（配置不可）は除外
						var tile = handler.board_system.tile_nodes.get(tile_index)
						if tile and TileHelper.is_special_tile(tile):
							continue
						# 空き地の場合は所有者フィルターをスキップ
					elif has_distance_filter:
						# 距離制限がある場合は所有者チェックをスキップ（全土地対象）
						pass
					else:
						# 所有者フィルター（従来の処理）
						var matches_owner = false
						if owner_filter == "own":
							matches_owner = (tile_owner == handler.current_player_id)
						elif owner_filter == "enemy":
							matches_owner = (tile_owner >= 0 and tile_owner != handler.current_player_id)
						else:  # "any"
							matches_owner = (tile_owner >= 0)
						
						if not matches_owner:
							continue
					
					var tile_level = tile_info.get("level", 1)
					var tile_element = tile_info.get("element", "")
					
					# レベル制限チェック
					var max_level = target_info.get("max_level", 999)
					var min_level = target_info.get("min_level", 1)
					var required_level = target_info.get("required_level", -1)
					
					# required_levelが指定されている場合は、そのレベルのみ対象
					if required_level > 0:
						if tile_level != required_level:
							continue
					elif tile_level < min_level or tile_level > max_level:
						continue
					
					# 属性制限チェック
					var required_elements = target_info.get("required_elements", [])
					if not required_elements.is_empty():
						if tile_element not in required_elements:
							continue
					
					# 距離制限チェック（プレイヤー移動スペル用: マジカルリープ等）
					var distance_min = target_info.get("distance_min", -1)
					var distance_max = target_info.get("distance_max", -1)
					if distance_min > 0 or distance_max > 0:
						# ワープタイルは飛べない（neutral, checkpoint等は可）
						var tile = handler.board_system.tile_nodes.get(tile_index)
						if tile and tile.tile_type == "warp":
							continue
						
						# 使用者の現在位置から距離を計算（MovementController優先）
						var player_tile = -1
						if handler.board_system and handler.board_system.movement_controller:
							player_tile = handler.board_system.movement_controller.get_player_tile(handler.current_player_id)
						elif handler.player_system and handler.current_player_id >= 0:
							player_tile = handler.player_system.players[handler.current_player_id].current_tile
						
						if player_tile >= 0 and handler.game_flow_manager and handler.game_flow_manager.spell_player_move:
							var dist = handler.game_flow_manager.spell_player_move.calculate_tile_distance(player_tile, tile_index)
							if distance_min > 0 and dist < distance_min:
								continue
							if distance_max > 0 and dist > distance_max:
								continue
					
					# クリーチャー存在チェック（target_filter: "creature"）
					if target_filter == "creature":
						if creature.is_empty():
							continue
						
						# クリーチャー条件チェック（has_no_curse, has_no_mystic_arts等）
						if target_info.get("has_no_curse", false):
							if not creature.get("curse", {}).is_empty():
								continue
						
						if target_info.get("has_no_mystic_arts", false):
							var mystic_arts = creature.get("ability_parsed", {}).get("mystic_arts", [])
							if not mystic_arts.is_empty():
								continue
						
						# is_down チェック（ダウン状態のクリーチャーのみ対象）
						if target_info.get("is_down", false):
							var tile = handler.board_system.tile_nodes.get(tile_index)
							var is_down = tile.is_down() if tile and tile.has_method("is_down") else false
							if not is_down:
								continue
					
					# 条件を満たす土地を追加
					var land_target = {
						"type": "land",
						"tile_index": tile_index,
						"element": tile_element,
						"level": tile_level,
						"owner": tile_owner
					}
					targets.append(land_target)
		
		"unvisited_gate":
			# 未通過ゲートを対象とする（リミッション用）
			if handler.game_flow_manager and handler.game_flow_manager.spell_player_move:
				var gate_tiles = handler.game_flow_manager.spell_player_move.get_selectable_gate_tiles(handler.current_player_id)
				for gate_info in gate_tiles:
					targets.append({
						"type": "gate",
						"tile_index": gate_info.get("tile_index", -1),
						"gate_key": gate_info.get("gate_key", "")
					})
	
	# most_common_element 後処理（クリーチャーターゲットのみ）
	if target_info.get("most_common_element", false) and not targets.is_empty():
		targets = _filter_by_most_common_element(targets)
	
	# 防魔フィルター（ignore_protection: true でスキップ可能）
	if not target_info.get("ignore_protection", false):
		targets = SpellProtection.filter_protected_targets(targets, handler)
	
	return targets


## 最多属性でフィルタリング（クラスターバースト用）
static func _filter_by_most_common_element(targets: Array) -> Array:
	# 属性ごとのカウント
	var element_counts = {}
	for target in targets:
		var creature = target.get("creature", {})
		var element = creature.get("element", "neutral")
		if not element_counts.has(element):
			element_counts[element] = 0
		element_counts[element] += 1
	
	# 最多属性を特定
	var max_count = 0
	for element in element_counts.keys():
		if element_counts[element] > max_count:
			max_count = element_counts[element]
	
	# 同数の場合は全て対象（複数属性が最多の場合）
	var most_common_elements = []
	for element in element_counts.keys():
		if element_counts[element] == max_count:
			most_common_elements.append(element)
	
	# 最多属性のクリーチャーのみ返す
	var filtered = []
	for target in targets:
		var creature = target.get("creature", {})
		var element = creature.get("element", "neutral")
		if element in most_common_elements:
			filtered.append(target)
	
	print("[TargetSelectionHelper] 最多属性: %s (%d体)" % [most_common_elements, filtered.size()])
	return filtered

## ターゲットインデックスを次へ移動
## 
## handler: available_targets, current_target_index を持つオブジェクト
## 戻り値: インデックスが変更されたか
static func move_target_next(handler) -> bool:
	if handler.current_target_index < handler.available_targets.size() - 1:
		handler.current_target_index += 1
		return true
	return false

## ターゲットインデックスを前へ移動
## 
## handler: available_targets, current_target_index を持つオブジェクト
## 戻り値: インデックスが変更されたか
static func move_target_previous(handler) -> bool:
	if handler.current_target_index > 0:
		handler.current_target_index -= 1
		return true
	return false

## ターゲットを数字で直接選択
## 
## handler: available_targets, current_target_index を持つオブジェクト
## index: 選択するインデックス
## 戻り値: 選択が成功したか
static func select_target_by_index(handler, index: int) -> bool:
	if index < handler.available_targets.size():
		handler.current_target_index = index
		return true
	return false

# ============================================
# UI表示ヘルパー
# ============================================

## ターゲット情報を日本語テキストに変換
## 
## target_data: ターゲット情報
## current_index: 現在のインデックス（1始まり）
## total_count: 総ターゲット数
## 戻り値: 表示用テキスト
static func format_target_info(target_data: Dictionary, current_index: int, total_count: int) -> String:
	var text = "対象を選択: [↑↓で切替]
"
	text += "対象 %d/%d: " % [current_index, total_count]
	
	# ターゲット情報表示
	match target_data.get("type", ""):
		"land":
			var tile_idx = target_data.get("tile_index", -1)
			var element = target_data.get("element", "neutral")
			var level = target_data.get("level", 1)
			var owner_id = target_data.get("owner", -1)
			
			# 属性名を日本語に変換
			var element_name = element
			match element:
				"fire": element_name = "火"
				"water": element_name = "水"
				"earth": element_name = "地"
				"wind": element_name = "風"
				"neutral": element_name = "無"
			
			var owner_id_text = ""
			if owner_id >= 0:
				owner_id_text = " (P%d)" % (owner_id + 1)
			
			text += "タイル%d %s Lv%d%s" % [tile_idx, element_name, level, owner_id_text]
		
		"creature":
			var tile_idx = target_data.get("tile_index", -1)
			var creature_name = target_data.get("creature", {}).get("name", "???")
			text += "タイル%d %s" % [tile_idx, creature_name]
		
		"player":
			var player_id = target_data.get("player_id", -1)
			text += "プレイヤー%d" % (player_id + 1)
		
		"gate":
			var tile_idx = target_data.get("tile_index", -1)
			var gate_key = target_data.get("gate_key", "")
			var gate_name = "北ゲート" if gate_key == "N" else "南ゲート"
			text += "%s (タイル%d)" % [gate_name, tile_idx]
	
	text += "
[Enter: 次へ] [C: 閉じる]"
	return text


# ============================================
# クリーチャー情報パネル
# ============================================

## ターゲットがクリーチャーの場合、情報パネルを表示
static func _show_creature_info_panel(handler, target_data: Dictionary) -> void:
	var target_type = target_data.get("type", "")
	var tile_index = target_data.get("tile_index", -1)
	
	# クリーチャー対象でない場合はパネルを閉じる
	if target_type != "creature":
		_hide_creature_info_panel(handler)
		return
	
	var creature_data = target_data.get("creature", {})
	
	# クリーチャーデータがない場合はパネルを閉じる
	if creature_data.is_empty():
		_hide_creature_info_panel(handler)
		return
	
	# handlerからui_managerを取得
	var ui_mgr = null
	if handler.has_method("get") and handler.get("ui_manager"):
		ui_mgr = handler.ui_manager
	elif "ui_manager" in handler:
		ui_mgr = handler.ui_manager
	
	if not ui_mgr or not ui_mgr.creature_info_panel_ui:
		return
	
	# setup_buttons=false でナビゲーションボタンを設定しない
	ui_mgr.creature_info_panel_ui.show_view_mode(creature_data, tile_index, false)


## クリーチャー情報パネルを非表示
static func _hide_creature_info_panel(handler) -> void:
	# handlerからui_managerを取得
	var ui_mgr = null
	if handler.has_method("get") and handler.get("ui_manager"):
		ui_mgr = handler.ui_manager
	elif "ui_manager" in handler:
		ui_mgr = handler.ui_manager
	
	if not ui_mgr or not ui_mgr.creature_info_panel_ui:
		return
	
	ui_mgr.creature_info_panel_ui.hide_panel(false)  # clear_buttons=false
