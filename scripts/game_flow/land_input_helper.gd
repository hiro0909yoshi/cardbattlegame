# LandInputHelper - 入力処理を提供
class_name LandInputHelper

## キーボード入力処理
static func process_input(handler, event):
	if event is InputEventKey and event.pressed:
		# 土地選択モード時
		if handler.current_state == handler.State.SELECTING_LAND:
			handle_land_selection_input(handler, event)
		# アクション選択モード時
		elif handler.current_state == handler.State.SELECTING_ACTION:
			handle_action_selection_input(handler, event)
		# 移動先選択モード時
		elif handler.current_state == handler.State.SELECTING_MOVE_DEST:
			handle_move_destination_input(handler, event)
		# 地形選択モード時
		elif handler.current_state == handler.State.SELECTING_TERRAIN:
			handle_terrain_selection_input(handler, event)
		# レベル選択モード時
		elif handler.current_state == handler.State.SELECTING_LEVEL:
			handle_level_selection_input(handler, event)

## 土地選択時のキー入力処理
static func handle_land_selection_input(handler, event):
	# ↑↓キーで土地を切り替え（プレビューのみ）
	if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
		if handler.current_land_selection_index > 0:
			handler.current_land_selection_index -= 1
			var tile_index = handler.player_owned_lands[handler.current_land_selection_index]
			LandSelectionHelper.preview_land(handler, tile_index)
			LandSelectionHelper.update_land_selection_ui(handler)
	elif event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
		if handler.current_land_selection_index < handler.player_owned_lands.size() - 1:
			handler.current_land_selection_index += 1
			var tile_index = handler.player_owned_lands[handler.current_land_selection_index]
			LandSelectionHelper.preview_land(handler, tile_index)
			LandSelectionHelper.update_land_selection_ui(handler)
	
	# Enterキーで確定（アクションメニュー表示）
	elif event.keycode == KEY_ENTER:
		LandSelectionHelper.confirm_land_selection(handler)
	
	# 数字キー1-0で選択して即確定
	elif is_number_key(event.keycode):
		var index = get_number_from_key(event.keycode)
		if index < handler.player_owned_lands.size():
			handler.current_land_selection_index = index
			var tile_index = handler.player_owned_lands[index]
			LandSelectionHelper.preview_land(handler, tile_index)
			LandSelectionHelper.update_land_selection_ui(handler)
			# 数字キーの場合は即座に確定
			LandSelectionHelper.confirm_land_selection(handler)
		else:
			print("[LandInputHelper] 無効な番号: ", index + 1)
	
	# Cキーでキャンセル（EscapeキーはグローバルボタンでUIManager経由で処理）
	elif event.keycode == KEY_C:
		handler.cancel()

## アクション選択時のキー入力処理
static func handle_action_selection_input(handler, event):
	match event.keycode:
		KEY_L:
			handler.execute_action("level_up")
		KEY_M:
			handler.execute_action("move_creature")
		KEY_S:
			handler.execute_action("swap_creature")
		KEY_T:
			handler.execute_action("terrain_change")
		KEY_C:
			# CキーでキャンセルEscapeキーはグローバルボタン経由）
			handler.cancel()

## 移動先選択時のキー入力処理
static func handle_move_destination_input(handler, event):
	# Cキーで前画面に戻る（EscapeキーはグローバルボタンでUIManager経由で処理）
	if event.keycode == KEY_C:
		handler.cancel()
		return
	
	# 移動先が存在しない場合は何もしない
	if handler.move_destinations.is_empty():
		return
	
	# ↓キーまたは→キー: 次の移動先
	if event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
		handler.current_destination_index = (handler.current_destination_index + 1) % handler.move_destinations.size()
		var dest_tile_index = handler.move_destinations[handler.current_destination_index]
		
		# マーカーを移動
		LandSelectionHelper.show_selection_marker(handler, dest_tile_index)
		LandSelectionHelper.focus_camera_on_tile(handler, dest_tile_index)
		
		# UI更新
		LandActionHelper.update_move_destination_ui(handler)
		
		print("[LandInputHelper] 移動先切替: タイル", dest_tile_index, " (", handler.current_destination_index + 1, "/", handler.move_destinations.size(), ")")
	
	# ↑キーまたは←キー: 前の移動先
	elif event.keycode == KEY_UP or event.keycode == KEY_LEFT:
		handler.current_destination_index = (handler.current_destination_index - 1 + handler.move_destinations.size()) % handler.move_destinations.size()
		var dest_tile_index = handler.move_destinations[handler.current_destination_index]
		
		# マーカーを移動
		LandSelectionHelper.show_selection_marker(handler, dest_tile_index)
		LandSelectionHelper.focus_camera_on_tile(handler, dest_tile_index)
		
		# UI更新
		LandActionHelper.update_move_destination_ui(handler)
		
		print("[LandInputHelper] 移動先切替: タイル", dest_tile_index, " (", handler.current_destination_index + 1, "/", handler.move_destinations.size(), ")")
	
	# Enterキー: 移動を確定
	elif event.keycode == KEY_ENTER:
		var dest_tile_index = handler.move_destinations[handler.current_destination_index]
		LandActionHelper.confirm_move(handler, dest_tile_index)

# ============================================
# ヘルパー関数
# ============================================

## 数字キーかどうか
static func is_number_key(keycode: int) -> bool:
	return keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

## キーコードから数字を取得
static func get_number_from_key(keycode: int) -> int:
	var key_to_index = {
		KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4,
		KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9
	}
	return key_to_index.get(keycode, -1)

## 地形選択時のキー入力処理
static func handle_terrain_selection_input(handler, event):
	# Cキーでキャンセル（EscapeキーはグローバルボタンでUIManager経由で処理）
	if event.keycode == KEY_C:
		handler.cancel()
		return
	
	# ↓キーまたは→キー: 次の属性
	if event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
		handler.current_terrain_index = (handler.current_terrain_index + 1) % handler.terrain_options.size()
		LandActionHelper.update_terrain_selection_ui(handler)
		print("[LandInputHelper] 属性切替: ", handler.terrain_options[handler.current_terrain_index])
	
	# ↑キーまたは←キー: 前の属性
	elif event.keycode == KEY_UP or event.keycode == KEY_LEFT:
		handler.current_terrain_index = (handler.current_terrain_index - 1 + handler.terrain_options.size()) % handler.terrain_options.size()
		LandActionHelper.update_terrain_selection_ui(handler)
		print("[LandInputHelper] 属性切替: ", handler.terrain_options[handler.current_terrain_index])
	
	# 数字キー1-4: 直接選択
	elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		var index = get_number_from_key(event.keycode)
		if index < handler.terrain_options.size():
			handler.current_terrain_index = index
			LandActionHelper.update_terrain_selection_ui(handler)
			print("[LandInputHelper] 属性選択: ", handler.terrain_options[handler.current_terrain_index])
	
	# Enterキー: 決定
	elif event.keycode == KEY_ENTER:
		var selected_element = handler.terrain_options[handler.current_terrain_index]
		print("[LandInputHelper] 地形変化決定: ", selected_element)
		LandActionHelper.execute_terrain_change_with_element(handler, selected_element)

## レベル選択時のキー入力処理
static func handle_level_selection_input(handler, event):
	# Cキーでキャンセル（EscapeキーはグローバルボタンでUIManager経由で処理）
	if event.keycode == KEY_C:
		handler.cancel()
		return
	
	# 選択可能なレベルがない場合は何もしない
	if handler.available_levels.is_empty():
		return
	
	# ↑キー: 前のレベル
	if event.keycode == KEY_UP:
		handler._select_previous_level()
	
	# ↓キー: 次のレベル
	elif event.keycode == KEY_DOWN:
		handler._select_next_level()
	
	# Enterキー: 決定
	elif event.keycode == KEY_ENTER:
		handler._confirm_level_selection()
