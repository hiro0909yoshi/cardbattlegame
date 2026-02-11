# TargetMarkerSystem - マーカー・カメラ・ハイライト管理
#
# ターゲット選択時の視覚的フィードバックを担当
# - 選択マーカーの作成・表示・回転
# - カメラフォーカス
# - タイルハイライト
#
# 使用例:
#   TargetMarkerSystem.show_selection_marker(handler, tile_index)
#   TargetMarkerSystem.focus_camera_on_tile(handler, tile_index)
extends RefCounted
class_name TargetMarkerSystem

# ============================================
# 選択マーカー管理
# ============================================

## 選択マーカーを作成
## 
## handler: 選択マーカーを保持するオブジェクト（DominioCommandHandler、SpellPhaseHandlerなど）
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
		var marker = create_marker_mesh()
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


## マーカーメッシュを作成（内部用）
static func create_marker_mesh() -> MeshInstance3D:
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
	camera.look_at(tile_pos + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)


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
