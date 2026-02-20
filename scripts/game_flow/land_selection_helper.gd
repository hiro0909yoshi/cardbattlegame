# LandSelectionHelper - 土地コマンド特有の処理を提供
# 汎用的な選択処理は TargetSelectionHelper を使用してください
class_name LandSelectionHelper

## 土地をプレビュー（ハイライトのみ、状態は変更しない）
## 
## ドミニオコマンド専用：所有地チェックとダウン状態チェックを行う
static func preview_land(handler, tile_index: int) -> bool:
	if handler.current_state != handler.State.SELECTING_LAND:
		return false
	
	# 所有地かチェック
	if tile_index not in handler.player_owned_lands:
			return false
	
	# ダウン状態チェック
	if handler.board_system and handler.board_system.tile_nodes.has(tile_index):
		var tile = handler.board_system.tile_nodes[tile_index]
		if tile.has_method("is_down") and tile.is_down():
			return false
	
	handler.selected_tile_index = tile_index
	
	# 汎用ヘルパーを使用して視覚的に選択
	TargetSelectionHelper.clear_all_highlights(handler)
	TargetSelectionHelper.show_selection_marker(handler, tile_index)
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	TargetSelectionHelper.highlight_tile(handler, tile_index)
	
	# クリーチャー情報パネルを表示
	_show_creature_info_for_tile(handler, tile_index)
	
	return true


## タイルのクリーチャー情報パネルを表示
static func _show_creature_info_for_tile(handler, tile_index: int) -> void:
	if not handler._info_panel_service:
		return

	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return

	var tile = handler.board_system.tile_nodes[tile_index]
	var creature = tile.creature_data if tile else {}

	if not creature.is_empty():
		handler._info_panel_service.show_card_info_only(creature, tile_index)

## 土地選択を確定してアクションメニューを表示
## 
## ドミニオコマンド専用：状態遷移とUIメニュー表示を行う
static func confirm_land_selection(handler) -> bool:
	if handler.current_state != handler.State.SELECTING_LAND:
		return false
	
	if handler.selected_tile_index == -1:
		return false
	
	# チュートリアルのターゲット制限チェック
	if not _check_tutorial_target_allowed(handler, handler.selected_tile_index):
		print("[LandSelectionHelper] チュートリアル制限: タイル%d は選択不可" % handler.selected_tile_index)
		return false
	
	handler.current_state = handler.State.SELECTING_ACTION
	handler.land_selected.emit(handler.selected_tile_index)
	
	# アクション選択UIを表示（ナビゲーションはActionMenuUI内で設定される）
	if handler._show_action_menu_cb.is_valid():
		handler._show_action_menu_cb.call(handler.selected_tile_index)
	
	return true

## 土地選択（旧メソッド - 互換性のため残す）
static func select_land(handler, tile_index: int) -> bool:
	return preview_land(handler, tile_index)

## プレイヤーの所有地を取得（ダウン状態を除外）
##
## ドミニオコマンド専用：ダウン状態の土地を自動的に除外する
static func get_player_owned_lands(board_system, player_id: int) -> Array:
	if not board_system:
		return []

	var owned_lands = []

	# BoardSystem3Dのtile_nodesから所有地を取得
	if not board_system.tile_nodes:
		return []

	# player_systemをmetaから取得（同盟判定用）
	var _ps = board_system.get_meta("player_system") if board_system and board_system.has_meta("player_system") else null

	for tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[tile_index]
		# 所有地 or 同盟の土地
		if tile.owner_id == player_id or (_ps and _ps.is_same_team(player_id, tile.owner_id)):
			# ダウン状態の土地は除外
			if tile.has_method("is_down") and tile.is_down():
				continue
			owned_lands.append(tile.tile_index)

	return owned_lands

## 土地選択UIを更新
##
## ドミニオコマンド専用：ドミニオコマンド固有のUI表示
static func update_land_selection_ui(handler):
	if not handler._message_service:
		return

	if handler.player_owned_lands.is_empty():
		handler._message_service.show_toast("所有している土地がありません")
		return

	var text = "土地を選択: タイル%d (%d/%d)" % [
		handler.selected_tile_index,
		handler.current_land_selection_index + 1,
		handler.player_owned_lands.size()
	]

	handler._message_service.show_action_prompt(text)


## チュートリアルのターゲット制限をチェック
static func _check_tutorial_target_allowed(handler, tile_index: int) -> bool:
	# TutorialManagerを取得（game_3d参照経由）
	if not handler or not handler.get("game_3d_ref"):
		return true
	var game_3d = handler.game_3d_ref
	if not game_3d or not "tutorial_manager" in game_3d:
		return true  # チュートリアルなし = 制限なし

	var tutorial_manager = game_3d.tutorial_manager
	if not tutorial_manager or not tutorial_manager.is_active:
		return true  # チュートリアル非アクティブ = 制限なし

	return tutorial_manager.is_target_tile_allowed(tile_index)

