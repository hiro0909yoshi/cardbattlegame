# LandSelectionHelper - 土地選択関連の処理を提供
class_name LandSelectionHelper

## 土地をプレビュー（ハイライトのみ、状態は変更しない）
static func preview_land(handler, tile_index: int) -> bool:
	if handler.current_state != handler.State.SELECTING_LAND:
		return false
	
	# 所有地かチェック
	if tile_index not in handler.player_owned_lands:
		print("[LandSelectionHelper] 所有していない土地です: ", tile_index)
		return false
	
	# ダウン状態チェック
	if handler.board_system and handler.board_system.tile_nodes.has(tile_index):
		var tile = handler.board_system.tile_nodes[tile_index]
		if tile.has_method("is_down") and tile.is_down():
			print("[LandSelectionHelper] この土地はダウン状態です: ", tile_index)
			return false
	
	handler.selected_tile_index = tile_index
	
	# 選択マーカーを表示
	show_selection_marker(handler, tile_index)
	
	# 選択した土地にカメラをフォーカス
	focus_camera_on_tile(handler, tile_index)
	
	return true

## 土地選択を確定してアクションメニューを表示
static func confirm_land_selection(handler) -> bool:
	if handler.current_state != handler.State.SELECTING_LAND:
		return false
	
	if handler.selected_tile_index == -1:
		print("[LandSelectionHelper] 土地が選択されていません")
		return false
	
	handler.current_state = handler.State.SELECTING_ACTION
	handler.land_selected.emit(handler.selected_tile_index)
	
	print("[LandSelectionHelper] 土地を確定: ", handler.selected_tile_index)
	
	# アクション選択UIを表示
	if handler.ui_manager and handler.ui_manager.has_method("show_action_menu"):
		handler.ui_manager.show_action_menu(handler.selected_tile_index)
	
	return true

## 土地選択（旧メソッド - 互換性のため残す）
static func select_land(handler, tile_index: int) -> bool:
	return preview_land(handler, tile_index)

## プレイヤーの所有地を取得（ダウン状態を除外）
static func get_player_owned_lands(board_system, player_id: int) -> Array:
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
				print("[LandSelectionHelper] タイル", tile_index, "はダウン状態なので除外")
				continue
			owned_lands.append(tile.tile_index)
	
	return owned_lands

## 土地選択UIを更新
static func update_land_selection_ui(handler):
	if not handler.ui_manager or not handler.ui_manager.phase_label:
		return
	
	if handler.player_owned_lands.is_empty():
		handler.ui_manager.phase_label.text = "所有している土地がありません"
		return
	
	var text = "土地を選択: [↑↓で切替]\n"
	text += "土地 " + str(handler.current_land_selection_index + 1) + "/" + str(handler.player_owned_lands.size()) + ": "
	text += "タイル" + str(handler.selected_tile_index) + "\n"
	text += "[Enter: 次へ] [C: 閉じる]"
	
	handler.ui_manager.phase_label.text = text

# ============================================
# 選択マーカーシステム
# ============================================

## 選択マーカーを作成
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
static func hide_selection_marker(handler):
	if handler.selection_marker and handler.selection_marker.get_parent():
		handler.selection_marker.get_parent().remove_child(handler.selection_marker)

## 選択マーカーを回転（process内で呼ぶ）
static func rotate_selection_marker(handler, delta: float):
	if handler.selection_marker and handler.selection_marker.has_meta("rotating"):
		handler.selection_marker.rotate_y(delta * 2.0)  # 1秒で約114度回転

## 選択した土地にカメラをフォーカス
static func focus_camera_on_tile(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	var camera = handler.board_system.camera
	
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
