# LandActionHelper - アクション実行関連の処理を提供
class_name LandActionHelper

## レベルアップ実行（レベル選択後）
static func execute_level_up_with_level(handler, target_level: int, cost: int) -> bool:
	if not handler.board_system or handler.selected_tile_index == -1:
		return false

	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false

	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]

	# ダウンチェック（ダウン中はドミニオコマンド使用不可）
	if tile.has_method("is_down") and tile.is_down():
		print("[LandActionHelper] レベルアップ失敗: タイル%d はダウン中" % handler.selected_tile_index)
		return false

	var p_system = handler.player_system
	var current_player = p_system.get_current_player() if p_system else null

	if not current_player:
		return false
	
	# EPチェック
	if current_player.magic_power < cost:
		return false
	
	# EP消費
	handler.player_system.add_magic(current_player.id, -cost)

	GameLogger.info("Dominio", "コマンド確定: P%d level_up タイル%d Lv%d→%d (EP-%d)" % [current_player.id + 1, handler.selected_tile_index, tile.level, target_level, cost])

	# レベルアップ実行
	tile.level = target_level

	# 昇華刻印結果（後で通知表示に使用）
	var growth_result: Dictionary = {}

	# レベルアップイベント発火（永続バフ更新用）
	if handler.board_system:
		handler.board_system.level_up_completed.emit(handler.selected_tile_index, target_level)

		# 永続バフ更新（アースズピリット/デュータイタン）
		if not tile.creature_data.is_empty():
			_apply_level_up_buff(tile.creature_data)

		# 昇華刻印トリガー（ドミナントグロース）
		growth_result = _get_command_growth_result(handler, handler.selected_tile_index)

	# ダウン状態設定（奮闘チェック）
	if tile.has_method("set_down_state"):
		# BaseTileのcreature_dataプロパティを直接参照
		var creature = tile.creature_data
		if not PlayerBuffSystem.has_unyielding(creature):
			tile.set_down_state(true)
		else:
			pass  # 奮闘スキル保持のためダウンしない

	# UI更新
	if handler._player_info_service:
		handler._player_info_service.update_panels()

	# ドミニオコマンド使用コメント表示（TileActionProcessorに委譲）
	if handler.board_system and handler.board_system.tile_action_processor:
		var player_name = _get_player_name(handler)
		var comment = "%s がドミニオコマンド：レベルアップ" % player_name
		handler.board_system.set_pending_comment(comment)

		# 昇華刻印がトリガーされた場合は2つ目のコメントとして追加
		if growth_result.get("triggered", false):
			var creature_name = growth_result.get("creature_name", "クリーチャー")
			var hp_bonus = growth_result.get("hp_bonus", 20)
			var new_mhp = growth_result.get("new_mhp", 0)
			var growth_comment = "【昇華】%s MHP+%d → MHP%d" % [creature_name, hp_bonus, new_mhp]
			handler.board_system.tile_action_processor.add_pending_comment(growth_comment)

	# アクション完了を通知（正しいターン終了フロー）
	# 注: ドミニオコマンドはend_turn()で閉じられる
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.complete_action()

	return true

## レベルアップ実行
static func execute_level_up(handler) -> bool:
	if not handler.board_system:
		return false

	# Phase 1-A修正: board_system.get_tile()ではなくtile_nodesを使用
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false

	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]

	# ダウンチェック（ダウン中はドミニオコマンド使用不可）
	if tile.has_method("is_down") and tile.is_down():
		if handler._message_service:
			handler._message_service.show_toast("ダウン中は使用できません")
		return false

	# 最大レベルチェック
	if tile.level >= 5:
		if handler._message_service:
			handler._message_service.show_toast("既に最大レベルです")
		return false
	
	# 状態をレベル選択中に変更
	handler.current_state = handler.State.SELECTING_LEVEL
	
	# 選択可能なレベルを設定（現在レベル+1 〜 5）
	handler.available_levels = []
	for level in range(tile.level + 1, 6):
		handler.available_levels.append(level)
	handler.current_level_selection_index = 0
	
	#　 Phase 1-A: レベル選択UIを表示
	if handler._show_level_selection_cb.is_valid():
		var p_system = handler.player_system
		var current_player = p_system.get_current_player() if p_system else null
		var player_magic = current_player.magic_power if current_player else 0

		handler._show_level_selection_cb.call(handler.selected_tile_index, tile.level, player_magic)

	# ナビゲーションボタン設定（レベル選択用）
	if handler._navigation_service:
		handler._navigation_service.enable_navigation(
			func(): handler.confirm_level_selection(),  # 決定
			func(): handler.cancel(),  # 戻る
			func(): handler.on_arrow_up(),  # 上
			func(): handler.on_arrow_down()  # 下
		)
	
	return true

## クリーチャー移動実行
static func execute_move_creature(handler) -> bool:
	# 移動元を保存
	handler.move_source_tile = handler.selected_tile_index
	
	if not handler.board_system or not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	# 移動可能なマスを取得（瞬移対応）
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]

	# ダウンチェック（ダウン中はドミニオコマンド使用不可）
	if tile.has_method("is_down") and tile.is_down():
		if handler._message_service:
			handler._message_service.show_toast("ダウン中は使用できません")
		return false

	# 移動先選択モードに移行
	handler.current_state = handler.State.SELECTING_MOVE_DEST
	var creature_data = tile.creature_data
	
	# MovementHelperを使用して移動先を取得
	handler.move_destinations = MovementHelper.get_move_destinations(
		handler.board_system,
		creature_data,
		handler.selected_tile_index
	)
	
	# 移動先が存在しない場合
	if handler.move_destinations.is_empty():
		var move_type = MovementHelper.detect_move_type(creature_data)
		var error_msg = ""
		if move_type == "vacant_move":
			error_msg = "移動可能な空き地がありません"
		elif move_type == "enemy_move":
			error_msg = "移動可能な敵地がありません"
		else:
			error_msg = "移動可能なマスがありません"

		if handler._message_service:
			handler._message_service.show_toast(error_msg)
		# アクション選択に戻る
		handler.current_state = handler.State.SELECTING_ACTION
		return false
	
	# 最初の移動先を選択
	handler.current_destination_index = 0
	var first_dest = handler.move_destinations[handler.current_destination_index]

	# アクションメニューを閉じる
	if handler._hide_action_menu_keep_buttons_cb.is_valid():
		handler._hide_action_menu_keep_buttons_cb.call()
	
	# マーカーを最初の移動先に表示
	TargetSelectionHelper.show_selection_marker(handler, first_dest)
	TargetSelectionHelper.focus_camera_on_tile(handler, first_dest)
	
	# UIを更新（移動先選択画面を表示）
	update_move_destination_ui(handler)

	# ナビゲーションボタン設定（移動先選択用）
	if handler._navigation_service:
		handler._navigation_service.enable_navigation(
			func(): LandActionHelper.confirm_move_selection(handler),  # 決定
			func(): handler.cancel(),  # 戻る
			func(): handler.on_arrow_up(),  # 上
			func(): handler.on_arrow_down()  # 下
		)

	return true

## 移動先選択UIを更新
static func update_move_destination_ui(handler):
	if not handler._message_service:
		return

	if handler.move_destinations.is_empty():
		handler._message_service.show_toast("移動可能なマスがありません")
		LandActionHelper.hide_move_creature_info(handler)
		return

	var current_tile = handler.move_destinations[handler.current_destination_index]
	var text = "移動先を選択: タイル%d (%d/%d)" % [
		current_tile,
		handler.current_destination_index + 1,
		handler.move_destinations.size()
	]

	handler._message_service.show_action_prompt(text)

	# 移動先にクリーチャーがいる場合、情報パネルを表示
	_show_move_creature_info(handler, current_tile)

## クリーチャー交換実行
static func execute_swap_creature(handler) -> bool:
	if handler.selected_tile_index < 0:
		return false
	
	# 選択した土地を取得
	if not handler.board_system or not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]

	# ダウンチェック（ダウン中はドミニオコマンド使用不可）
	if tile.has_method("is_down") and tile.is_down():
		if handler._message_service:
			handler._message_service.show_toast("ダウン中は使用できません")
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
	
	# 状態を交換クリーチャー選択中に変更
	handler.current_state = handler.State.SELECTING_SWAP
	
	# TileActionProcessorに交換モードを設定
	if handler.board_system.tile_action_processor:
		# is_action_processingをtrueに設定（通常のアクション処理と同じ）
		handler.board_system.begin_action_processing()
		
		# 交換情報を保存
		handler.swap_mode = true
		handler.swap_old_creature = old_creature_data
		handler.swap_tile_index = handler.selected_tile_index
	
	# アクションメニューを閉じる
	if handler._hide_action_menu_keep_buttons_cb.is_valid():
		handler._hide_action_menu_keep_buttons_cb.call()  # グローバルボタンはクリアしない
	
	# ナビゲーション設定（交換選択用：戻るのみ）
	if handler._navigation_service:
		handler._navigation_service.enable_navigation(
			Callable(),  # 決定なし（カード選択で決定）
			func(): handler.cancel()  # 戻る
		)

	# カード選択UIを表示（交換モード）
	if handler._message_service:
		handler._message_service.show_action_prompt("交換する新しいクリーチャーを選択")
	if handler._card_selection_service:
		handler._card_selection_service.card_selection_filter = ""  # disabledフィルターをクリア
		handler._card_selection_service.show_card_selection_ui_mode(handler.player_system.get_current_player(), "swap")

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
		if handler._message_service:
			handler._message_service.show_toast("手札にクリーチャーカードがありません")
		return false

	return true

## 移動先選択を確定（決定ボタンから呼ばれる）
static func confirm_move_selection(handler):
	if handler.move_destinations.is_empty():
		return
	var dest_tile_index = handler.move_destinations[handler.current_destination_index]
	confirm_move(handler, dest_tile_index)

## 移動を確定
static func confirm_move(handler, dest_tile_index: int):
	# クリーチャー情報パネルを閉じる
	LandActionHelper.hide_move_creature_info(handler)
	
	if not handler.board_system or not handler.board_system.tile_nodes.has(handler.move_source_tile) or not handler.board_system.tile_nodes.has(dest_tile_index):
		handler.close_dominio_order()
		return
	
	var source_tile = handler.board_system.tile_nodes[handler.move_source_tile]
	var dest_tile = handler.board_system.tile_nodes[dest_tile_index]
	
	# 移動元のクリーチャー情報を取得
	var creature_data = source_tile.creature_data.duplicate()
	if creature_data.is_empty():
		handler.close_dominio_order()
		return
	
	var current_player_index = source_tile.owner_id
	
	# バウダーイーターチェック（分裂移動）
	var is_boulder_eater = SkillCreatureSpawn.is_boulder_eater(creature_data)
	
	GameLogger.info("Dominio", "コマンド確定: P%d move_creature タイル%d→%d %s(id:%d)" % [current_player_index + 1, handler.move_source_tile, dest_tile_index, creature_data.get("name", "?"), creature_data.get("id", -1)])

	# 1. 移動元のクリーチャーを削除し、空き地にする（バウダーイーター以外）
	if not is_boulder_eater:
		# board_system経由で削除（スキルインデックスも更新される）
		handler.board_system.remove_creature(handler.move_source_tile)
		handler.board_system.set_tile_owner(handler.move_source_tile, -1)  # 空き地化

	# 2. 移動先の状況を確認
	var dest_owner = dest_tile.owner_id

	# 敵地への移動侵略ログ
	if dest_owner != -1 and dest_owner != current_player_index:
		GameLogger.info("Dominio", "移動侵略: P%d タイル%d → タイル%d %s(id:%d)" % [current_player_index + 1, handler.move_source_tile, dest_tile_index, creature_data.get("name", "?"), creature_data.get("id", -1)])

	if dest_owner == -1:
		# 空き地の場合: 土地を獲得してクリーチャー配置
		
		if is_boulder_eater:
			# バウダーイーター: 分裂移動
			var split_result = SkillCreatureSpawn.process_boulder_eater_split(creature_data)
			
			# 移動元に元のクリーチャーを残す（刻印維持、ダウン状態も維持）
			# 移動元は既に配置済みなので何もしない（削除していないので）
			
			# 移動先にコピーを配置（刻印除去済み）
			var copy_data = split_result["copy"]
			dest_tile.place_creature(copy_data)
			
			print("[LandActionHelper] バウダーイーター分裂: 移動元に残留 + 移動先にコピー配置")
		else:
			# 通常移動: 移動による刻印消滅
			if creature_data.has("curse"):
				var curse_name = creature_data["curse"].get("name", "不明")
				creature_data.erase("curse")
				print("[LandActionHelper] 刻印消滅（移動）: ", curse_name)
			
			# place_creature()を使って3Dカードも含めて正しく配置
			dest_tile.place_creature(creature_data)
		
		# ダウン状態設定（奮闘チェック）
		if dest_tile.has_method("set_down_state"):
			if not PlayerBuffSystem.has_unyielding(creature_data):
				dest_tile.set_down_state(true)
		
		# 移動先の所有権を設定
		handler.board_system.set_tile_owner(dest_tile_index, current_player_index)
		
		# 移動完了：状態をリセット
		handler.move_destinations.clear()
		handler.move_source_tile = -1
		handler.current_destination_index = 0
		
		# ドミニオコマンド使用コメント表示（TileActionProcessorに委譲）
		if handler.board_system and handler.board_system.tile_action_processor:
			var player_name = _get_player_name(handler)
			handler.board_system.set_pending_comment(
				"%s がドミニオコマンド：移動" % player_name
			)
		
		# アクション完了を通知
		# 注: ドミニオコマンドはend_turn()で閉じられる
		if handler.board_system and handler.board_system.tile_action_processor:
			handler.board_system.complete_action()
		
	elif dest_owner == current_player_index or (handler.player_system and handler.player_system.is_same_team(current_player_index, dest_owner)):
		# 自分 or 同盟の土地の場合: エラー（通常はありえない）
		# クリーチャーを元に戻す
		source_tile.place_creature(creature_data)
		handler.close_dominio_order()
		
	else:
		# 敵の土地の場合: peace刻印チェック
		var spell_curse_toll = null
		if handler.board_system.has_meta("spell_curse_toll"):
			spell_curse_toll = handler.board_system.get_meta("spell_curse_toll")
		
		# peace刻印があれば移動・戦闘不可
		if spell_curse_toll and spell_curse_toll.has_peace_curse(dest_tile_index):
			# peace刻印で移動・戦闘不可
			if handler._message_service:
				handler._message_service.show_toast("peace刻印: このタイルへは侵略できません")
			# 移動元にクリーチャーを戻す
			source_tile.place_creature(creature_data)
			handler.close_dominio_order()
			return
		
		# クリーチャー鉄壁チェック（グルイースラッグ、ランドアーチン等）
		if spell_curse_toll and dest_tile and not dest_tile.creature_data.is_empty():
			if spell_curse_toll.is_creature_invasion_immune(dest_tile.creature_data):
				var defender_name = dest_tile.creature_data.get("name", "クリーチャー")
				if handler._message_service:
					handler._message_service.show_toast("%s は移動侵略を受けません" % defender_name)
				source_tile.place_creature(creature_data)
				handler.close_dominio_order()
				return
		
		# プレイヤー休戦刻印チェック（トゥルース）
		var current_player_id = handler.board_system.current_player_index if handler.board_system else 0
		if spell_curse_toll and spell_curse_toll.is_player_invasion_disabled(current_player_id):
			if handler._message_service:
				handler._message_service.show_toast("休戦刻印: 侵略できません")
			source_tile.place_creature(creature_data)
			handler.close_dominio_order()
			return
		
		# テンパランスロウ（節制）チェック - SpellWorldCurseに委譲
		var defender_id = dest_tile.owner_id if dest_tile else -1
		if handler.spell_world_curse:
			if handler.spell_world_curse.check_invasion_blocked(current_player_id, defender_id, true):
				source_tile.place_creature(creature_data)
				handler.close_dominio_order()
				return
		
		# バトル発生
		
		# バウダーイーターの場合: 戦闘用にコピーを生成（刻印除去）
		var battle_creature_data = creature_data
		if is_boulder_eater:
			var split_result = SkillCreatureSpawn.process_boulder_eater_split(creature_data)
			battle_creature_data = split_result["copy"]  # 刻印除去済みコピーで戦闘
			# 元のドミニオにはオリジナルが残る（既に削除していないので何もしない）
			print("[LandActionHelper] バウダーイーター分裂: 元のドミニオに残留、コピーで戦闘")
		else:
			# 通常移動: 移動による刻印消滅（バトル前に消す）
			if creature_data.has("curse"):
				var curse_name = creature_data["curse"].get("name", "不明")
				creature_data.erase("curse")
				print("[LandActionHelper] 刻印消滅（移動侵略）: ", curse_name)
			battle_creature_data = creature_data
		
		# 移動元情報を保存（敗北時に戻すため - バウダーイーター以外）
		handler.move_source_tile = handler.move_source_tile  # 既に設定済み
		handler.set_boulder_eater_move(is_boulder_eater)  # バウダーイーターフラグを保存
		
		# 移動中フラグを設定（鼓舞スキル計算から除外するため）
		battle_creature_data["is_moving"] = true
		
		# バトル情報を保存
		# 注: ドミニオコマンドはバトル開始前に閉じる必要があるため、ここでは閉じない
		handler.pending_move_battle_creature_data = battle_creature_data
		handler.pending_move_battle_tile_info = handler.board_system.get_tile_info(dest_tile_index)
		handler.pending_move_attacker_item = {}
		handler.pending_move_defender_item = {}
		handler.reset_move_battle_flags()
		
		# 移動侵略シーケンスを開始（カメラ移動→コメント→アイテムフェーズ）
		handler.start_move_battle_sequence(dest_tile_index, current_player_index, creature_data)

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
		# 奮闘チェック
		if not PlayerBuffSystem.has_unyielding(attacker_data):
			dest_tile.set_down_state(true)
		else:
			pass  # 奮闘スキル保持のためダウンしない
	else:
		pass  # 簡易バトルで敗北
	
	# アクション完了を通知
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.complete_action()

## 隣接タイルを取得
static func get_adjacent_tiles(handler, tile_index: int) -> Array:
	if not handler.board_system:
		return []
	
	# TileNeighborSystemを使用
	if not handler.board_system.tile_neighbor_system:
		return []
	
	var neighbors = handler.board_system.get_spatial_neighbors(tile_index)
	return neighbors

## 移動バトルを実行（アイテムフェーズ完了後）
static func _execute_move_battle(handler):
	if handler.pending_move_battle_creature_data.is_empty():
		if handler.board_system and handler.board_system.tile_action_processor:
			handler.board_system.complete_action()
		return
	
	var current_player_index = handler.board_system.current_player_index

	# バトル実行（移動元タイルを渡す）
	# バウダーイーターの場合は移動元を-1にする（敗北時に戻す必要がないため）
	var from_tile = -1 if handler.is_boulder_eater_move else handler.move_source_tile
	await handler.battle_system.execute_3d_battle_with_data(
		current_player_index,
		handler.pending_move_battle_creature_data,
		handler.pending_move_battle_tile_info,
		handler.pending_move_attacker_item,
		handler.pending_move_defender_item,
		from_tile
	)
	
	# バトル情報をクリア
	handler.pending_move_battle_creature_data = {}
	handler.pending_move_battle_tile_info = {}
	handler.pending_move_attacker_item = {}
	handler.pending_move_defender_item = {}
	handler.reset_move_battle_flags()


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

## 昇華刻印の効果を適用し結果を返す（通知は呼び出し元で制御）
static func _get_command_growth_result(handler, tile_index: int) -> Dictionary:
	if not handler.game_flow_manager:
		return {}

	var spell_curse = handler.spell_curse
	if not spell_curse:
		return {}

	# 昇華刻印があればトリガー
	return spell_curse.trigger_command_growth(tile_index)

## 地形変化実行（属性選択後）
static func execute_terrain_change_with_element(handler, new_element: String) -> bool:
	if not handler.board_system or handler.selected_tile_index == -1:
		return false
	
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]
	
	# ダウンチェック（ダウン中はドミニオコマンド使用不可）
	if tile.has_method("is_down") and tile.is_down():
		print("[LandActionHelper] 属性変更失敗: タイル%d はダウン中" % handler.selected_tile_index)
		return false
	
	var tile_index = handler.selected_tile_index
	
	# 地形変化可能かチェック
	if not handler.board_system.can_change_terrain(tile_index):
		if handler._message_service:
			handler._message_service.show_toast("この土地は地形変化できません")
		return false

	# コスト計算
	var cost = handler.board_system.calculate_terrain_change_cost(tile_index)
	if cost < 0:
		return false
	
	# EPチェック
	var p_system = handler.player_system
	var current_player = p_system.get_current_player() if p_system else null

	if not current_player:
		return false

	if current_player.magic_power < cost:
		if handler._message_service:
			handler._message_service.show_toast("EPが足りません (必要: %dEP)" % cost)
		return false

	# TileActionProcessorに処理中フラグを設定（EPチェック通過後）
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.begin_action_processing()

	# EP消費
	handler.player_system.add_magic(current_player.id, -cost)

	GameLogger.info("Dominio", "コマンド確定: P%d terrain_change タイル%d →%s (EP-%d)" % [current_player.id + 1, tile_index, new_element, cost])
	
	# 地形変化実行（SpellLand経由でインペリアルガードチェックも行う）
	var success = handler.spell_land.change_element(tile_index, new_element)
	if not success:
		# EPを返却
		handler.player_system.add_magic(current_player.id, cost)
		return false
	
	# タイルを再取得（属性変更後のインスタンス）
	tile = handler.board_system.tile_nodes[tile_index]
	
	# 昇華刻印トリガー（ドミナントグロース）
	var growth_result = _get_command_growth_result(handler, tile_index)

	# ダウン状態設定（奮闘チェック）
	if tile.has_method("set_down_state"):
		var creature = tile.creature_data
		if not creature.is_empty() and not PlayerBuffSystem.has_unyielding(creature):
			tile.set_down_state(true)
		elif not creature.is_empty():
			pass  # 奮闘スキル保持のためダウンしない

	# UI更新
	if handler._player_info_service:
		handler._player_info_service.update_panels()

	# 地形選択パネルを閉じる
	if handler._hide_terrain_selection_cb.is_valid():
		handler._hide_terrain_selection_cb.call()

	# ドミニオコマンド使用コメント表示（TileActionProcessorに委譲）
	if handler.board_system and handler.board_system.tile_action_processor:
		var player_name = _get_player_name(handler)
		var comment = "%s がドミニオコマンド：属性変更" % player_name
		handler.board_system.set_pending_comment(comment)

		# 昇華刻印がトリガーされた場合は2つ目のコメントとして追加
		if growth_result.get("triggered", false):
			var creature_name = growth_result.get("creature_name", "クリーチャー")
			var hp_bonus = growth_result.get("hp_bonus", 20)
			var new_mhp = growth_result.get("new_mhp", 0)
			var growth_comment = "【昇華】%s MHP+%d → MHP%d" % [creature_name, hp_bonus, new_mhp]
			handler.board_system.tile_action_processor.add_pending_comment(growth_comment)

	# アクション完了を通知（レベルアップと同様）
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.complete_action()

	return true

## 地形変化実行（UI表示）
static func execute_terrain_change(handler) -> bool:
	if not handler.board_system:
		return false
	
	if not handler.board_system.tile_nodes.has(handler.selected_tile_index):
		return false
	
	var tile = handler.board_system.tile_nodes[handler.selected_tile_index]

	# ダウンチェック（ダウン中はドミニオコマンド使用不可）
	if tile.has_method("is_down") and tile.is_down():
		if handler._message_service:
			handler._message_service.show_toast("ダウン中は使用できません")
		return false

	var tile_index = handler.selected_tile_index

	# インペリアルガード（不変）チェック - SpellWorldCurseに委譲
	if handler.spell_world_curse:
		if handler.spell_world_curse.check_land_change_blocked(true):
			return false
	
	# 地形変化可能かチェック
	if not handler.board_system.can_change_terrain(tile_index):
		if handler._message_service:
			handler._message_service.show_toast("この土地は地形変化できません")
		return false

	# 地形選択モードに移行
	handler.terrain_change_tile_index = tile_index
	handler.current_state = handler.State.SELECTING_TERRAIN
	handler.current_terrain_index = 0
	
	# 地形選択パネルを表示
	var cost = handler.board_system.calculate_terrain_change_cost(tile_index)
	var p_system = handler.player_system
	var current_player = p_system.get_current_player() if p_system else null
	var player_magic = current_player.magic_power if current_player else 0
	
	if handler._show_terrain_selection_cb.is_valid():
		handler._show_terrain_selection_cb.call(tile_index, tile.tile_type, cost, player_magic)
		# 最初の選択可能な属性をハイライト
		var first_selectable = _get_first_selectable_terrain(handler, tile.tile_type)
		if first_selectable != "":
			handler.current_terrain_index = handler.terrain_options.find(first_selectable)
			if handler._highlight_terrain_button_cb.is_valid():
				handler._highlight_terrain_button_cb.call(first_selectable)
	
	# ナビゲーションボタン設定（地形選択用）
	if handler._navigation_service:
		handler._navigation_service.enable_navigation(
			func(): LandActionHelper.confirm_terrain_selection(handler),  # 決定
			func(): _cancel_terrain_change(handler),  # 戻る
			func(): handler.on_arrow_up(),  # 上
			func(): handler.on_arrow_down()  # 下
		)

	return true

## 地形選択を確定（決定ボタンから呼ばれる）
static func confirm_terrain_selection(handler):
	var selected_element = handler.terrain_options[handler.current_terrain_index]
	var success = execute_terrain_change_with_element(handler, selected_element)
	if not success:
		# 地形選択パネルを閉じてアクション選択に戻す
		if handler._hide_terrain_selection_cb.is_valid():
			handler._hide_terrain_selection_cb.call()
		handler.current_state = handler.State.SELECTING_ACTION
		handler.set_action_selection_navigation()
		if handler._show_action_menu_cb.is_valid():
			handler._show_action_menu_cb.call(handler.selected_tile_index)

## 最初の選択可能な属性を取得
static func _get_first_selectable_terrain(handler, current_element: String) -> String:
	for element in handler.terrain_options:
		if element != current_element:
			return element
	return ""

## 地形変化キャンセル
static func _cancel_terrain_change(handler):
	handler.terrain_change_tile_index = -1
	handler.current_state = handler.State.SELECTING_ACTION

	# TileActionProcessorのフラグをリセット
	if handler.board_system and handler.board_system.tile_action_processor:
		handler.board_system.reset_action_processing()

	# 地形選択パネルを閉じてアクションメニューに戻る
	if handler._hide_terrain_selection_cb.is_valid():
		handler._hide_terrain_selection_cb.call()
	if handler._show_action_menu_cb.is_valid():
		handler._show_action_menu_cb.call(handler.selected_tile_index)

	# アクション選択用ナビゲーション（戻るのみ）- 最後に設定
	if handler._navigation_service:
		handler._navigation_service.enable_navigation(
			Callable(),  # 決定なし
			func(): handler.cancel()  # 戻る
		)
	if handler._show_action_menu_cb.is_valid():
		handler._show_action_menu_cb.call(handler.selected_tile_index)

## 地形選択UIを更新
static func update_terrain_selection_ui(handler):
	if not handler._highlight_terrain_button_cb.is_valid():
		return

	# 現在選択中の属性をハイライト
	var current_element = handler.terrain_options[handler.current_terrain_index]
	handler._highlight_terrain_button_cb.call(current_element)


# ============================================
# 移動先クリーチャー情報パネル
# ============================================

## 移動先の情報パネルを表示（クリーチャーがいれば情報パネル、いなければ土地情報）
static func _show_move_creature_info(handler, tile_index: int) -> void:
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		LandActionHelper.hide_move_creature_info(handler)
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	if not tile:
		LandActionHelper.hide_move_creature_info(handler)
		return
	
	# クリーチャーがいる場合
	if not tile.creature_data.is_empty():
		# 土地情報パネルを閉じる
		_hide_land_info_panel(handler)

		if handler._info_panel_service:
			handler._info_panel_service.show_card_info_only(tile.creature_data, tile_index)
	else:
		# クリーチャーがいない場合は土地情報を表示
		_hide_creature_info_panel(handler)
		
		var tile_info = handler.board_system.get_tile_info(tile_index)
		var element = tile_info.get("element", "neutral")
		var level = tile_info.get("level", 1)
		_show_land_info_panel(handler, element, level)


## クリーチャー情報パネルを非表示
static func hide_move_creature_info(handler) -> void:
	_hide_creature_info_panel(handler)
	_hide_land_info_panel(handler)


## クリーチャー情報パネルのみ非表示
static func _hide_creature_info_panel(handler) -> void:
	if not handler._info_panel_service:
		return
	handler._info_panel_service.hide_all_info_panels(false)


## 土地情報パネルを表示
static func _show_land_info_panel(handler, element: String, level: int) -> void:
	if not handler.land_info_panel:
		return
	handler.land_info_panel.show_land_info(element, level)


## 土地情報パネルを非表示
static func _hide_land_info_panel(handler) -> void:
	if not handler.land_info_panel:
		return
	handler.land_info_panel.hide_land_info()


## プレイヤー名を取得（コメント表示用）
static func _get_player_name(handler) -> String:
	if not handler.player_system or not handler.board_system:
		return "プレイヤー"
	
	var player_id = handler.board_system.current_player_index
	if player_id < handler.player_system.players.size():
		var player = handler.player_system.players[player_id]
		if player:
			return player.name
	return "プレイヤー"
