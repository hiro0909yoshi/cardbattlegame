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
		print("[LandActionHelper] 魔力不足: 必要%d / 所持%d" % [cost, current_player.magic_power])
		return false
	
	# 魔力消費
	handler.player_system.add_magic(current_player.id, -cost)
	
	# レベルアップ実行
	tile.level = target_level
	
	# ダウン状態設定（不屈チェック）
	if tile.has_method("set_down_state"):
		# BaseTileのcreature_dataプロパティを直接参照
		var creature = tile.creature_data
		if not SkillSystem.has_unyielding(creature):
			tile.set_down_state(true)
		else:
			print("[LandActionHelper] 不屈によりレベルアップ後もダウンしません")
	
	# UI更新
	if handler.ui_manager:
		handler.ui_manager.update_player_info_panels()
	
	print("[LandActionHelper] レベルアップ完了: tile ", handler.selected_tile_index, " -> Lv.", target_level)
	
	# 領地コマンドを閉じる
	handler.close_land_command()
	
	# ターン終了
	if handler.game_flow_manager and handler.game_flow_manager.has_method("end_turn"):
		handler.game_flow_manager.end_turn()
	
	return true

## レベルアップ実行
static func execute_level_up(handler) -> bool:
	if not handler.board_system:
		return false
	
	# Phase 1-A修正: board_system.get_tile()ではなくtile_nodesを使用
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		print("[LandActionHelper] タイルが見つかりません: ", handler.selected_tile_index)
		return false
	
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]
	
	# 最大レベルチェック
	if tile.level >= 5:
		print("[LandActionHelper] 既に最大レベルです")
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
	
	# 移動可能な隣接マスを取得
	handler.move_destinations = get_adjacent_tiles(handler, handler.selected_tile_index)
	
	# 移動先が存在しない場合
	if handler.move_destinations.is_empty():
		print("[LandActionHelper] 移動可能なマスがありません")
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = "移動可能なマスがありません"
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
		print("[LandActionHelper] エラー: 土地が選択されていません")
		return false
	
	# 選択した土地を取得
	if not handler.board_system or not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		print("[LandActionHelper] エラー: 土地ノードが見つかりません")
		return false
	
	var tile_info = handler.board_system.get_tile_info(handler.selected_tile_index)
	
	# クリーチャーがいるかチェック
	if tile_info.get("creature", {}).is_empty():
		print("[LandActionHelper] エラー: クリーチャーがいません")
		return false
	
	# 現在のプレイヤーIDを取得
	var current_player_index = handler.board_system.current_player_index
	
	# 召喚条件チェック（手札にクリーチャーカードがあるか）
	if not check_swap_conditions(handler, current_player_index):
		return false
	
	# 🔄 元のクリーチャーデータ保存（ダミー、実際はexecute_swapで再取得する）
	var old_creature_data = tile_info["creature"].duplicate()
	
	print("[LandActionHelper] クリーチャー交換開始")
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
		print("[LandActionHelper] エラー: システム参照が不正です")
		return false
	
	var card_system = handler.board_system.card_system
	
	# 手札データを取得
	if not card_system.player_hands.has(player_id):
		print("[LandActionHelper] エラー: プレイヤーIDが不正です")
		return false
	
	var player_hand = card_system.player_hands[player_id]["data"]
	
	# 手札にクリーチャーカードが1枚以上あるかチェック
	var has_creature_card = false
	for card in player_hand:
		if card.get("type", "") == "creature":
			has_creature_card = true
			break
	
	if not has_creature_card:
		print("[LandActionHelper] エラー: 手札にクリーチャーカードがありません")
		if handler.ui_manager and handler.ui_manager.phase_label:
			handler.ui_manager.phase_label.text = "手札にクリーチャーカードがありません"
		return false
	
	return true

## 移動を確定
static func confirm_move(handler, dest_tile_index: int):
	
	if not handler.board_system or not handler.board_system.tile_nodes.has(handler.move_source_tile) or not handler.board_system.tile_nodes.has(dest_tile_index):
		print("[LandActionHelper] エラー: タイルが見つかりません")
		handler.close_land_command()
		return
	
	var source_tile = handler.board_system.tile_nodes[handler.move_source_tile]
	var dest_tile = handler.board_system.tile_nodes[dest_tile_index]
	
	# 移動元のクリーチャー情報を取得
	var creature_data = source_tile.creature_data.duplicate()
	if creature_data.is_empty():
		print("[LandActionHelper] エラー: 移動元にクリーチャーがいません")
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
		print("[LandActionHelper] 空き地への移動 - 土地獲得")
		handler.board_system.set_tile_owner(dest_tile_index, current_player_index)
		handler.board_system.place_creature(dest_tile_index, creature_data)
		
		# 移動先をダウン状態に（不屈チェック）
		if not SkillSystem.has_unyielding(creature_data):
			dest_tile.set_down_state(true)
		else:
			print("[LandActionHelper] 不屈により移動後もダウンしません")
		
		# 領地コマンドを閉じる
		handler.close_land_command()
		
		# アクション完了を通知
		if handler.board_system and handler.board_system.tile_action_processor:
			handler.board_system.tile_action_processor.complete_action()
		
	elif dest_owner == current_player_index:
		# 自分の土地の場合: エラー（通常はありえない）
		print("[LandActionHelper] エラー: 自分の土地には移動できません")
		# クリーチャーを元に戻す
		source_tile.place_creature(creature_data)
		handler.close_land_command()
		
	else:
		# 敵の土地の場合: バトル発生
		print("[LandActionHelper] 敵地への移動 - バトル発生")
		
		# 1. クリーチャーを手札に追加
		if handler.board_system.card_system:
			# 手札に直接追加
			handler.board_system.card_system.player_hands[current_player_index]["data"].append(creature_data)
			var card_index = handler.board_system.card_system.player_hands[current_player_index]["data"].size() - 1
			
			print("[LandActionHelper] クリーチャーを手札に追加: index=", card_index)
			
			# 2. 領地コマンドを閉じる
			handler.close_land_command()
			
			# 3. バトル完了シグナルに接続
			var callable = Callable(handler, "_on_move_battle_completed")
			if handler.board_system.battle_system and not handler.board_system.battle_system.invasion_completed.is_connected(callable):
				handler.board_system.battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
			
			# 4. 既存のバトルシステムを使用
			var tile_info = handler.board_system.get_tile_info(dest_tile_index)
			handler.board_system.battle_system.execute_3d_battle(current_player_index, card_index, tile_info)
		else:
			print("[LandActionHelper] エラー: card_systemが存在しません、簡易バトルを実行")
			handler.close_land_command()
			execute_simple_move_battle(handler, dest_tile_index, creature_data, current_player_index)

## 簡易移動バトル（カードシステム使用不可時）
static func execute_simple_move_battle(handler, dest_index: int, attacker_data: Dictionary, attacker_player: int):
	var dest_tile = handler.board_system.tile_nodes[dest_index]
	var defender_data = dest_tile.creature_data
	
	# 非常にシンプルなAP比較バトル
	var attacker_ap = attacker_data.get("ap", 0)
	var defender_hp = defender_data.get("hp", 0)
	
	var success = attacker_ap >= defender_hp
	
	if success:
		print("[LandActionHelper] 簡易バトル: 攻撃側勝利")
		handler.board_system.set_tile_owner(dest_index, attacker_player)
		handler.board_system.place_creature(dest_index, attacker_data)
		# 不屈チェック
		if not SkillSystem.has_unyielding(attacker_data):
			dest_tile.set_down_state(true)
		else:
			print("[LandActionHelper] 不屈により移動後もダウンしません")
	else:
		print("[LandActionHelper] 簡易バトル: 防御側勝利")
	
	# アクション完了を通知
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.tile_action_processor.complete_action()

## 隣接タイルを取得
static func get_adjacent_tiles(handler, tile_index: int) -> Array:
	if not handler.board_system:
		print("[LandActionHelper] ERROR: board_systemが存在しません")
		return []
	
	# TileNeighborSystemを使用
	if not handler.board_system.tile_neighbor_system:
		print("[LandActionHelper] ERROR: tile_neighbor_systemが存在しません")
		return []
	
	var neighbors = handler.board_system.tile_neighbor_system.get_spatial_neighbors(tile_index)
	return neighbors
