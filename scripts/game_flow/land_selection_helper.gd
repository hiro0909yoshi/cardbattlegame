# LandSelectionHelper - 土地コマンド特有の処理を提供
# 汎用的な選択処理は TargetSelectionHelper を使用してください
class_name LandSelectionHelper

## 土地をプレビュー（ハイライトのみ、状態は変更しない）
## 
## 領地コマンド専用：所有地チェックとダウン状態チェックを行う
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
	
	# 汎用ヘルパーを使用して視覚的に選択
	TargetSelectionHelper.clear_all_highlights(handler)
	TargetSelectionHelper.show_selection_marker(handler, tile_index)
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	TargetSelectionHelper.highlight_tile(handler, tile_index)
	
	return true

## 土地選択を確定してアクションメニューを表示
## 
## 領地コマンド専用：状態遷移とUIメニュー表示を行う
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
## 
## 領地コマンド専用：ダウン状態の土地を自動的に除外する
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
## 
## 領地コマンド専用：領地コマンド固有のUI表示
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
# 互換性のための転送メソッド
# 汎用処理は TargetSelectionHelper に委譲
# ============================================

## 選択マーカーを作成
static func create_selection_marker(handler):
	TargetSelectionHelper.create_selection_marker(handler)

## 選択マーカーを表示
static func show_selection_marker(handler, tile_index: int):
	TargetSelectionHelper.show_selection_marker(handler, tile_index)

## 選択マーカーを非表示
static func hide_selection_marker(handler):
	TargetSelectionHelper.hide_selection_marker(handler)

## 選択マーカーを回転（process内で呼ぶ）
static func rotate_selection_marker(handler, delta: float):
	TargetSelectionHelper.rotate_selection_marker(handler, delta)

## 選択した土地にカメラをフォーカス
static func focus_camera_on_tile(handler, tile_index: int):
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
