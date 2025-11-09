# TargetSelectionHelper - 対象選択の汎用ヘルパー
# 土地、クリーチャー、プレイヤーなど、あらゆる対象の選択に使用可能
class_name TargetSelectionHelper

# ============================================
# 選択マーカーシステム
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

# ============================================
# 対象タイプ別の処理
# ============================================

## 対象データから土地インデックスを取得
## 
## target_data: 対象データ（type, tile_index, player_idなどを含む）
## board_system: BoardSystem3Dの参照（プレイヤー位置取得に必要）
## 戻り値: 土地インデックス、取得できない場合は-1
static func get_tile_index_from_target(target_data: Dictionary, board_system) -> int:
	var target_type = target_data.get("type", "")
	
	match target_type:
		"land", "creature":
			# 土地またはクリーチャーの場合、tile_indexを直接使用
			return target_data.get("tile_index", -1)
		
		"player":
			# プレイヤーの場合、プレイヤーの位置を取得
			var player_id = target_data.get("player_id", -1)
			if player_id >= 0 and board_system and board_system.movement_controller:
				return board_system.movement_controller.get_player_tile(player_id)
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

## 対象選択を完全にクリア（マーカー、ハイライト）
## 
## handler: board_system と selection_marker を持つオブジェクト
static func clear_selection(handler):
	# ハイライトをクリア
	clear_all_highlights(handler)
	
	# マーカーを非表示
	hide_selection_marker(handler)

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
