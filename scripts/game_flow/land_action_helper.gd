# LandActionHelper - アクション実行関連の処理を提供
class_name LandActionHelper

## レベルアップ実行（レベル選択後）
static func execute_level_up_with_level(handler, target_level: int, cost: int) -> bool:
	if not handler.board_system or handler.selected_tile_index == -1:
		return false
	
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]
	var p_system = handler.game_flow_manager.player_system if handler.game_flow_manager else null
	var current_player = p_system.get_current_player() if p_system else null
	
	if not current_player:
		return false
	
	# 魔力チェック
	if current_player.magic_power < cost:
		return false
	
	# 魔力消費
	handler.player_system.add_magic(current_player.id, -cost)
	
	# レベルアップ実行
	tile.level = target_level
	
	# レベルアップイベント発火（永続バフ更新用）
	if handler.board_system:
		handler.board_system.level_up_completed.emit(handler.selected_tile_index, target_level)
		
		# 永続バフ更新（アースズピリット/デュータイタン）
		if not tile.creature_data.is_empty():
			_apply_level_up_buff(tile.creature_data)
	
	# ダウン状態設定（不屈チェック）
	if tile.has_method("set_down_state"):
		# BaseTileのcreature_dataプロパティを直接参照
		var creature = tile.creature_data
		if not SkillSystem.has_unyielding(creature):
			tile.set_down_state(true)
		else:
			pass  # 不屈スキル保持のためダウンしない
	
	# UI更新
	if handler.ui_manager:
		handler.ui_manager.update_player_info_panels()
	
	
	# アクション完了を通知（正しいターン終了フロー）
	# 注: 領地コマンドはend_turn()で閉じられる
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.tile_action_processor.complete_action()
	
	return true

## レベルアップ実行
static func execute_level_up(handler) -> bool:
	if not handler.board_system:
		return false
	
	# Phase 1-A修正: board_system.get_tile()ではなくtile_nodesを使用
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]
	
	# 最大レベルチェック
	if tile.level >= 5:
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = "既に最大レベルです"
		return false
	
	#　 Phase 1-A: レベル選択UIを表示
	if handler.ui_manager and handler.ui_manager.has_method("show_level_selection"):
		var p_system = handler.game_flow_manager.player_system if handler.game_flow_manager else null
		var current_player = p_system.get_current_player() if p_system else null
		var player_magic = current_player.magic_power if current_player else 0
		
		handler.ui_manager.show_level_selection(handler.selected_tile_index, tile.level, player_magic)
	
	return true

## クリーチャー移動実行
static func execute_move_creature(handler) -> bool:
	# 移動元を保存
	handler.move_source_tile = handler.selected_tile_index
	
	# 移動先選択モードに移行
	handler.current_state = handler.State.SELECTING_MOVE_DEST
	
	# 移動可能なマスを取得（空地移動対応）
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]
	var creature_data = tile.creature_data
	
	# MovementHelperを使用して移動先を取得
	handler.move_destinations = MovementHelper.get_move_destinations(
		handler.board_system,
		creature_data,
		handler.selected_tile_index
	)
	
	# 移動先が存在しない場合
	if handler.move_destinations.is_empty():
		var move_type = MovementHelper._detect_move_type(creature_data)
		var error_msg = ""
		if move_type == "vacant_move":
			error_msg = "移動可能な空き地がありません"
		elif move_type == "enemy_move":
			error_msg = "移動可能な敵地がありません"
		else:
			error_msg = "移動可能なマスがありません"
		
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = error_msg
		# アクション選択に戻る
		handler.current_state = handler.State.SELECTING_ACTION
		return false
	
	# 最初の移動先を選択
	handler.current_destination_index = 0
	var first_dest = handler.move_destinations[handler.current_destination_index]
	
	# マーカーを最初の移動先に表示
	LandSelectionHelper.show_selection_marker(handler, first_dest)
	LandSelectionHelper.focus_camera_on_tile(handler, first_dest)
	
	# UIを更新（移動先選択画面を表示）
	update_move_destination_ui(handler)
	
	return true

## 移動先選択UIを更新
static func update_move_destination_ui(handler):
	if not handler.ui_manager or not handler.ui_manager.phase_label:
		return
	
	if handler.move_destinations.is_empty():
		handler.ui_manager.phase_label.text = "移動可能なマスがありません"
		return
	
	var current_tile = handler.move_destinations[handler.current_destination_index]
	var text = "移動先を選択: [↑↓で切替]\n"
	text += "移動先 " + str(handler.current_destination_index + 1) + "/" + str(handler.move_destinations.size()) + ": "
	text += "タイル" + str(current_tile) + "\n"
	text += "[Enter: 確定] [C: 戻る]"
	
	handler.ui_manager.phase_label.text = text

## クリーチャー交換実行
static func execute_swap_creature(handler) -> bool:
	if handler.selected_tile_index < 0:
		return false
	
	# 選択した土地を取得
	if not handler.board_system or not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile_info = handler.board_system.get_tile_info(handler.selected_tile_index)
	
	# クリーチャーがいるかチェック
	if tile_info.get("creature", {}).is_empty():
		return false
	
	# 現在のプレイヤーIDを取得
	var current_player_index = handler.board_system.current_player_index
	
	# 召喚条件チェック（手札にクリーチャーカードがあるか）
	if not check_swap_conditions(handler, current_player_index):
		return false
	
	# 🔄 元のクリーチャーデータ保存（ダミー、実際はexecute_swapで再取得する）
	var old_creature_data = tile_info["creature"].duplicate()
	
	print("  対象土地: タイル", handler.selected_tile_index)
	print("  元のクリーチャー: ", old_creature_data.get("name", "不明"), " (※最終的には最新データで処理)")
	
	# TileActionProcessorに交換モードを設定
	if handler.board_system.tile_action_processor:
		# is_action_processingをtrueに設定（通常のアクション処理と同じ）
		handler.board_system.tile_action_processor.is_action_processing = true
		
		# 交換情報を保存
		handler._swap_mode = true
		handler._swap_old_creature = old_creature_data
		handler._swap_tile_index = handler.selected_tile_index
	
	# カード選択UIを表示
	if handler.ui_manager:
		handler.ui_manager.phase_label.text = "交換する新しいクリーチャーを選択"
		handler.ui_manager.show_card_selection_ui(handler.player_system.get_current_player())
	
	handler.action_selected.emit("swap_creature")
	return true

## 交換条件チェック
static func check_swap_conditions(handler, player_id: int) -> bool:
	if not handler.board_system or not handler.board_system.card_system:
		return false
	
	var card_system = handler.board_system.card_system
	
	# 手札データを取得
	if not card_system.player_hands.has(player_id):
		return false
	
	var player_hand = card_system.player_hands[player_id]["data"]
	
	# 手札にクリーチャーカードが1枚以上あるかチェック
	var has_creature_card = false
	for card in player_hand:
		if card.get("type", "") == "creature":
			has_creature_card = true
			break
	
	if not has_creature_card:
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = "手札にクリーチャーカードがありません"
		return false
	
	return true

## 移動を確定
static func confirm_move(handler, dest_tile_index: int):
	
	if not handler.board_system or not handler.board_system.tile_nodes.has(handler.move_source_tile) or not handler.board_system.tile_nodes.has(dest_tile_index):
		handler.close_land_command()
		return
	
	var source_tile = handler.board_system.tile_nodes[handler.move_source_tile]
	var dest_tile = handler.board_system.tile_nodes[dest_tile_index]
	
	# 移動元のクリーチャー情報を取得
	var creature_data = source_tile.creature_data.duplicate()
	if creature_data.is_empty():
		handler.close_land_command()
		return
	
	var current_player_index = source_tile.owner_id
	
	# 1. 移動元のクリーチャーを削除し、空き地にする
	source_tile.remove_creature()
	handler.board_system.set_tile_owner(handler.move_source_tile, -1)  # 空き地化
	
	# 2. 移動先の状況を確認
	var dest_owner = dest_tile.owner_id
	
	if dest_owner == -1:
		# 空き地の場合: 土地を獲得してクリーチャー配置
		
		# place_creature()を使って3Dカードも含めて正しく配置
		dest_tile.place_creature(creature_data)
		
		# ダウン状態設定（不屈チェック）
		if dest_tile.has_method("set_down_state"):
			if not SkillSystem.has_unyielding(creature_data):
				dest_tile.set_down_state(true)
		
		# 移動先の所有権を設定
		handler.board_system.set_tile_owner(dest_tile_index, current_player_index)
		
		# アクション完了を通知
		# 注: 領地コマンドはend_turn()で閉じられる
		if handler.board_system and handler.board_system.tile_action_processor:
			handler.board_system.tile_action_processor.complete_action()
		
	elif dest_owner == current_player_index:
		# 自分の土地の場合: エラー（通常はありえない）
		# クリーチャーを元に戻す
		source_tile.place_creature(creature_data)
		handler.close_land_command()
		
	else:
		# 敵の土地の場合: バトル発生
		
		# 移動元情報を保存（敗北時に戻すため）
		handler.move_source_tile = handler.move_source_tile  # 既に設定済み
		
		# バトル情報を保存
		# 注: 領地コマンドはバトル開始前に閉じる必要があるため、ここでは閉じない
		handler.pending_move_battle_creature_data = creature_data
		handler.pending_move_battle_tile_info = handler.board_system.get_tile_info(dest_tile_index)
		handler.pending_move_attacker_item = {}
		handler.pending_move_defender_item = {}
		handler.is_waiting_for_move_defender_item = false
		
		# アイテムフェーズを開始（攻撃側）
		if handler.game_flow_manager and handler.game_flow_manager.item_phase_handler:
			# アイテムフェーズ完了シグナルに接続
			if not handler.game_flow_manager.item_phase_handler.item_phase_completed.is_connected(handler._on_move_item_phase_completed):
				handler.game_flow_manager.item_phase_handler.item_phase_completed.connect(handler._on_move_item_phase_completed, CONNECT_ONE_SHOT)
			
			# 攻撃側のアイテムフェーズ開始
			handler.game_flow_manager.item_phase_handler.start_item_phase(current_player_index, creature_data)
		else:
			# ItemPhaseHandlerがない場合は直接バトル
			_execute_move_battle(handler)

## 簡易移動バトル（カードシステム使用不可時）
static func execute_simple_move_battle(handler, dest_index: int, attacker_data: Dictionary, attacker_player: int):
	var dest_tile = handler.board_system.tile_nodes[dest_index]
	var defender_data = dest_tile.creature_data
	
	# 非常にシンプルなAP比較バトル
	var attacker_ap = attacker_data.get("ap", 0)
	var defender_hp = defender_data.get("hp", 0)
	
	var success = attacker_ap >= defender_hp
	
	if success:
		handler.board_system.set_tile_owner(dest_index, attacker_player)
		handler.board_system.place_creature(dest_index, attacker_data)
		# 不屈チェック
		if not SkillSystem.has_unyielding(attacker_data):
			dest_tile.set_down_state(true)
		else:
			pass  # 不屈スキル保持のためダウンしない
	else:
		pass  # 簡易バトルで敗北
	
	# アクション完了を通知
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.tile_action_processor.complete_action()

## 隣接タイルを取得
static func get_adjacent_tiles(handler, tile_index: int) -> Array:
	if not handler.board_system:
		return []
	
	# TileNeighborSystemを使用
	if not handler.board_system.tile_neighbor_system:
		return []
	
	var neighbors = handler.board_system.tile_neighbor_system.get_spatial_neighbors(tile_index)
	return neighbors

## 移動バトルを実行（アイテムフェーズ完了後）
static func _execute_move_battle(handler):
	if handler.pending_move_battle_creature_data.is_empty():
		if handler.board_system and handler.board_system.tile_action_processor:
			handler.board_system.tile_action_processor.complete_action()
		return
	
	var current_player_index = handler.board_system.current_player_index
	
	# バトル完了シグナルに接続
	var callable = Callable(handler, "_on_move_battle_completed")
	if handler.board_system.battle_system and not handler.board_system.battle_system.invasion_completed.is_connected(callable):
		handler.board_system.battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
	
	# バトル実行（移動元タイルを渡す）
	handler.board_system.battle_system.execute_3d_battle_with_data(
		current_player_index,
		handler.pending_move_battle_creature_data,
		handler.pending_move_battle_tile_info,
		handler.pending_move_attacker_item,
		handler.pending_move_defender_item,
		handler.move_source_tile
	)
	
	# バトル情報をクリア
	handler.pending_move_battle_creature_data = {}
	handler.pending_move_battle_tile_info = {}
	handler.pending_move_attacker_item = {}
	handler.pending_move_defender_item = {}
	handler.is_waiting_for_move_defender_item = false


## レベルアップ時の永続バフ更新
static func _apply_level_up_buff(creature_data: Dictionary):
	var creature_id = creature_data.get("id", -1)
	
	# アースズピリット（ID: 200）: MHP+10
	if creature_id == 200:
		EffectManager.apply_max_hp_effect(creature_data, 10)
		print("[アースズピリット] レベルアップ MHP+10 (合計: +%d)" % creature_data["base_up_hp"])
	
	# デュータイタン（ID: 328）: MHP-10
	if creature_id == 328:
		EffectManager.apply_max_hp_effect(creature_data, -10)
		print("[デュータイタン] レベルアップ MHP-10 (合計: %d)" % creature_data["base_up_hp"])

## 地形変化実行（属性選択後）
static func execute_terrain_change_with_element(handler, new_element: String) -> bool:
	if not handler.board_system or handler.selected_tile_index == -1:
		return false
	
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile_index = handler.selected_tile_index
	
	# TileActionProcessorに処理中フラグを設定
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.tile_action_processor.is_action_processing = true
	
	# 地形変化可能かチェック
	if not handler.board_system.can_change_terrain(tile_index):
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = "この土地は地形変化できません"
		return false
	
	# コスト計算
	var cost = handler.board_system.calculate_terrain_change_cost(tile_index)
	if cost < 0:
		return false
	
	# 魔力チェック
	var p_system = handler.game_flow_manager.player_system if handler.game_flow_manager else null
	var current_player = p_system.get_current_player() if p_system else null
	
	if not current_player:
		return false
	
	if current_player.magic_power < cost:
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = "魔力が足りません (必要: %dG)" % cost
		return false
	
	# 魔力消費
	handler.player_system.add_magic(current_player.id, -cost)
	
	# 地形変化実行
	var success = handler.board_system.change_tile_terrain(tile_index, new_element)
	if not success:
		# 魔力を返却
		handler.player_system.add_magic(current_player.id, cost)
		return false
	
	# タイルを取得（新しいタイルインスタンス）
	var tile = handler.board_system.tile_nodes[tile_index]
	
	# ダウン状態設定（不屈チェック）
	if tile.has_method("set_down_state"):
		var creature = tile.creature_data
		if not creature.is_empty() and not SkillSystem.has_unyielding(creature):
			tile.set_down_state(true)
		elif not creature.is_empty():
			pass  # 不屈スキル保持のためダウンしない
	
	# UI更新
	if handler.ui_manager:
		handler.ui_manager.update_player_info_panels()
	
	
	# アクション完了を通知（レベルアップと同様）
	# 注: 領地コマンドはend_turn()で閉じられる
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.tile_action_processor.complete_action()
	
	return true

## 地形変化実行（UI表示）
static func execute_terrain_change(handler) -> bool:
	if not handler.board_system:
		return false
	
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile_index = handler.selected_tile_index
	
	# 地形変化可能かチェック
	if not handler.board_system.can_change_terrain(tile_index):
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = "この土地は地形変化できません"
		return false
	
	# 地形選択モードに移行
	handler.terrain_change_tile_index = tile_index
	handler.current_state = handler.State.SELECTING_TERRAIN
	handler.current_terrain_index = 0
	
	# 地形選択UIを表示
	update_terrain_selection_ui(handler)
	
	return true

## 地形選択UIを更新
static func update_terrain_selection_ui(handler):
	if not handler.ui_manager or not handler.ui_manager.phase_label:
		return
	
	var tile = handler.board_system.tile_nodes[handler.terrain_change_tile_index]
	var cost = handler.board_system.calculate_terrain_change_cost(handler.terrain_change_tile_index)
	var current_element = handler.terrain_options[handler.current_terrain_index]
	
	# 属性名を日本語に変換
	var element_names = {
		"fire": "火",
		"water": "水",
		"earth": "土",
		"wind": "風"
	}
	
	var text = "地形変化: 属性を選択 [↑↓で切替]
"
	text += "現在: %s属性 → 変更後: %s属性
" % [element_names.get(tile.tile_type, "無"), element_names[current_element]]
	text += "コスト: %dG
" % cost
	text += "
"
	
	# 選択肢を表示
	for i in range(handler.terrain_options.size()):
		var element = handler.terrain_options[i]
		var name = element_names[element]
		var marker = "→ " if i == handler.current_terrain_index else "  "
		text += "%s[%d] %s属性
" % [marker, i + 1, name]
	
	text += "
[Enter] 決定  [C] キャンセル"
	handler.ui_manager.phase_label.text = text
