extends Node
class_name SpecialTileSystem

# 特殊マス管理システム - 3D専用版
# 注意: ワープ機能は将来的にマス自体（BaseTile派生）が持つ予定

signal special_tile_activated(tile_type: String, player_id: int, tile_index: int)
# TODO: 将来実装予定
# signal warp_triggered(from_tile: int, to_tile: int)
@warning_ignore("unused_signal")  # 将来のチェックポイント処理で使用予定
signal checkpoint_passed(player_id: int, bonus: int)
signal special_action_completed()

# 定数をpreload

# システム参照
var board_system
var card_system: CardSystem
var player_system: PlayerSystem
var ui_manager: UIManager = null
var game_flow_manager = null  # GameFlowManager参照（魔法タイル用）

func _ready():
	pass

# システム参照を設定
func setup_systems(b_system, c_system: CardSystem, p_system: PlayerSystem, ui_system: UIManager = null, gfm = null):
	board_system = b_system
	card_system = c_system
	player_system = p_system
	ui_manager = ui_system
	game_flow_manager = gfm

# ============================================
# 特殊タイル停止後の共通UI設定
# ============================================

## ワープ後の着地処理（着地先のタイルでタイルアクションを実行）
func _process_warp_landing(player_id: int) -> void:
	if not game_flow_manager or not game_flow_manager.board_system_3d:
		return
	
	var b_system = game_flow_manager.board_system_3d
	
	# 現在のプレイヤー位置を取得
	var current_tile = -1
	if b_system.movement_controller:
		current_tile = b_system.get_player_tile(player_id)
	
	if current_tile < 0:
		print("[SpecialTile] ワープ後の位置が不明 - 着地処理スキップ")
		return
	
	print("[SpecialTile] ワープ後の着地処理: タイル%d" % current_tile)
	
	# 現在のアクション処理を完了（is_action_processingをリセット）
	if b_system.tile_action_processor:
		b_system.tile_action_processor.reset_action_processing()
	
	# 着地先のタイルアクションを実行
	if b_system.tile_action_processor:
		await b_system.tile_action_processor.process_tile_landing(
			current_tile,
			player_id,
			b_system.player_is_cpu
		)

## 特殊タイル停止後の共通UI状態を設定
## 全ての特殊タイルハンドラの最後で呼び出す（CPU/プレイヤー共通）
func _show_special_tile_landing_ui(player_id: int):
	if not ui_manager:
		return
	
	# カードをグレーアウト（召喚不可）
	ui_manager.card_selection_filter = "disabled"
	
	# 手札UI表示
	var current_player = null
	if player_system and player_id < player_system.players.size():
		current_player = player_system.players[player_id]
	if current_player:
		ui_manager.show_card_selection_ui(current_player)
	
	# フェーズ表示（show_card_selection_ui後に設定して上書きされないようにする）
	if ui_manager.phase_display:
		ui_manager.show_action_prompt("特殊タイル: 召喚不可（×でパス）")
	
	# 人間プレイヤーの場合、ドミニオコマンドボタンを再表示
	if board_system and board_system.game_flow_manager and not board_system.game_flow_manager.is_cpu_player(player_id):
		ui_manager.show_dominio_order_button()

# 3Dタイル処理（BoardSystem3Dから呼び出される）
# 注意: この関数はawaitで呼び出すこと
func process_special_tile_3d(tile_type: String, tile_index: int, player_id: int) -> void:
	print("特殊タイル処理: ", tile_type, " (マス", tile_index, ")")
	
	# 特殊タイル処理中はドミニオコマンドボタンを非表示
	if ui_manager:
		ui_manager.hide_dominio_order_button()
	
	# タイルオブジェクトを取得（タイルに処理を委譲する場合に使用）
	var tile = _get_tile_by_index(tile_index)
	
	match tile_type:
		"checkpoint":
			await handle_checkpoint_tile(player_id)
		"warp_stop":
			await handle_warp_stop_tile(tile_index, player_id)
		"card_buy":
			await handle_card_buy_tile(player_id, tile)
		"card_give":
			await handle_card_give_tile(player_id, tile)
		"magic_stone":
			await handle_magic_stone_tile(player_id, tile)
		"magic":
			await handle_magic_tile(player_id, tile)
		"base":
			var base_result = await handle_base_tile(player_id, tile)
			# 遠隔召喚モードに入った場合は、召喚完了を待ってからspecial_action_completedを発火
			if base_result.get("wait_for_summon", false):
				return  # special_action_completedは発火しない（召喚完了時にaction_completedが発火）
		"branch":
			await handle_branch_tile(player_id, tile)
		"neutral":
			# 無属性マスは通常タイルとして処理しない（土地取得不可）
			print("無属性マス - 連鎖は切れます")
		_:
			print("未実装の特殊タイル: ", tile_type)
	
	# 処理完了シグナル（全てのハンドラ共通）
	emit_signal("special_action_completed")

## タイルインデックスからタイルオブジェクトを取得
func _get_tile_by_index(tile_index: int):
	if board_system and board_system.tile_nodes and board_system.tile_nodes.has(tile_index):
		return board_system.tile_nodes[tile_index]
	return null

# チェックポイント処理
# 注意: EPボーナスはLapSystemで管理、ダウン解除は停止時にここで実行
func handle_checkpoint_tile(player_id: int):
	print("チェックポイント停止")
	
	# ダウン解除
	if board_system:
		var cleared_count = board_system.clear_all_down_states_for_player(player_id)
		if cleared_count > 0:
			print("[チェックポイント] プレイヤー%d ダウン解除: %d体" % [player_id + 1, cleared_count])
			# ダウン解除によりドミニオコマンドが使用可能になった場合、ボタンを表示
			if ui_manager and ui_manager.has_method("show_dominio_order_button"):
				ui_manager.show_dominio_order_button()
	
	# UI更新
	if ui_manager and ui_manager.has_method("update_player_info_panels"):
		ui_manager.update_player_info_panels()
	
	emit_signal("special_tile_activated", "checkpoint", player_id, 5)
	
	# 共通UI設定
	_show_special_tile_landing_ui(player_id)

# 停止型ワープマス処理
func handle_warp_stop_tile(tile_index: int, player_id: int):
	var warp_pair = get_warp_pair(tile_index)
	if warp_pair == -1 or warp_pair == tile_index:
		print("停止型ワープ: ワープ先なし")
		# 共通UI設定
		_show_special_tile_landing_ui(player_id)
		return
	
	print("停止型ワープ発動！ タイル%d → タイル%d" % [tile_index, warp_pair])
	
	# movement_controllerでワープ実行
	if board_system:
		await board_system.execute_warp(player_id, tile_index, warp_pair)
		# プレイヤー位置を更新
		board_system.set_player_tile(player_id, warp_pair)
	
	emit_signal("special_tile_activated", "warp_stop", player_id, warp_pair)
	
	# 共通UI設定
	_show_special_tile_landing_ui(player_id)

# カード購入マス処理（タイルに委譲）
func handle_card_buy_tile(player_id: int, tile = null):
	print("[SpecialTile] カード購入マス - Player%d" % (player_id + 1))
	
	# タイルに処理を委譲
	if tile and tile.has_method("handle_special_action"):
		var context = _create_tile_context()
		var result = await tile.handle_special_action(player_id, context)
		print("[SpecialTile] カード購入マス処理完了: %s" % result)
		emit_signal("special_tile_activated", "card_buy", player_id, -1)
		_show_special_tile_landing_ui(player_id)
		return
	
	# フォールバック：タイルがない場合
	print("[SpecialTile] カード購入タイルが見つかりません - スキップ")
	emit_signal("special_tile_activated", "card_buy", player_id, -1)
	_show_special_tile_landing_ui(player_id)

# カード譲渡マス処理（タイルに委譲）
func handle_card_give_tile(player_id: int, tile = null):
	print("[SpecialTile] カード譲渡マス - Player%d" % (player_id + 1))
	
	# タイルに処理を委譲
	if tile and tile.has_method("handle_special_action"):
		var context = _create_tile_context()
		var result = await tile.handle_special_action(player_id, context)
		print("[SpecialTile] カード譲渡マス処理完了: %s" % result)
		emit_signal("special_tile_activated", "card_give", player_id, -1)
		_show_special_tile_landing_ui(player_id)
		return
	
	# フォールバック：タイルがない場合
	print("[SpecialTile] カード譲渡タイルが見つかりません - スキップ")
	emit_signal("special_tile_activated", "card_give", player_id, -1)
	_show_special_tile_landing_ui(player_id)

# 魔法石マス処理（タイルに委譲）
func handle_magic_stone_tile(player_id: int, tile = null):
	print("[SpecialTile] 魔法石マス - Player%d" % (player_id + 1))
	
	# タイルに処理を委譲
	if tile and tile.has_method("handle_special_action"):
		var context = _create_tile_context()
		var result = await tile.handle_special_action(player_id, context)
		print("[SpecialTile] 魔法石マス処理完了: %s" % result)
	else:
		# フォールバック: CPUの場合はスキップ
		if board_system and board_system.game_flow_manager and board_system.game_flow_manager.is_cpu_player(player_id):
			print("[SpecialTile] CPU - 魔法石マススキップ")

	emit_signal("special_tile_activated", "magic_stone", player_id, -1)
	
	# 共通UI設定
	_show_special_tile_landing_ui(player_id)

# 魔法マス処理（タイルに委譲）
func handle_magic_tile(player_id: int, tile = null):
	print("[SpecialTile] 魔法マス - Player%d" % (player_id + 1))
	
	var was_warped = false
	
	# タイルに処理を委譲
	if tile and tile.has_method("handle_special_action"):
		var context = _create_tile_context()
		var result = await tile.handle_special_action(player_id, context)
		print("[SpecialTile] 魔法マス処理完了: %s" % result)
		was_warped = result.get("warped", false)
	else:
		# フォールバック: CPUの場合はスキップ
		if board_system and board_system.game_flow_manager and board_system.game_flow_manager.is_cpu_player(player_id):
			print("[SpecialTile] CPU - 魔法マススキップ")
	
	emit_signal("special_tile_activated", "magic", player_id, -1)
	
	# ワープした場合は着地先でタイルアクションを実行
	if was_warped:
		print("[SpecialTile] ワープ後の着地処理を実行")
		await _process_warp_landing(player_id)
	else:
		_show_special_tile_landing_ui(player_id)

# 分岐マス処理（タイルに委譲）
func handle_branch_tile(player_id: int, tile = null):
	print("[SpecialTile] 分岐マス - Player%d" % (player_id + 1))
	
	# タイルに処理を委譲
	if tile and tile.has_method("handle_special_action"):
		var context = _create_tile_context()
		var result = await tile.handle_special_action(player_id, context)
		print("[SpecialTile] 分岐マス処理完了: %s" % result)
	else:
		print("[SpecialTile] 分岐タイルが見つかりません - スキップ")
	
	emit_signal("special_tile_activated", "branch", player_id, -1)
	_show_special_tile_landing_ui(player_id)

## タイル処理用のコンテキストを作成
func _create_tile_context() -> Dictionary:
	return {
		"player_system": player_system,
		"card_system": card_system,
		"ui_manager": ui_manager,
		"game_flow_manager": game_flow_manager,
		"board_system": board_system
	}

# 拠点マス処理（タイルに委譲 → 空き地選択後に召喚フローへ）
func handle_base_tile(player_id: int, tile = null):
	print("[SpecialTile] 拠点マス - Player%d" % (player_id + 1))
	
	# タイルに処理を委譲（空き地選択のみ）
	if tile and tile.has_method("handle_special_action"):
		var context = _create_tile_context()
		var result = await tile.handle_special_action(player_id, context)
		print("[SpecialTile] 拠点マス空き地選択完了: %s" % result)
		
		var selected_tile = result.get("selected_tile", -1)
		
		if selected_tile >= 0:
			# 空き地が選択された → 遠隔配置モードで召喚フローへ
			if board_system and board_system.tile_action_processor:
				board_system.set_remote_placement(selected_tile)
			
			# 1フレーム待って入力イベントをクリア（空き地選択の決定ボタンが伝播しないように）
			await board_system.get_tree().process_frame
			
			# CPUの場合は自動召喚処理
			if board_system and board_system.game_flow_manager and board_system.game_flow_manager.is_cpu_player(player_id):
				await _cpu_remote_summon(player_id, selected_tile)
				emit_signal("special_tile_activated", "base", player_id, selected_tile)
				return {"wait_for_summon": false}  # CPU処理完了
			
			# プレイヤーの場合：召喚UIを表示（通常の召喚フローを使用）
			_show_remote_summon_ui(player_id, selected_tile)
			emit_signal("special_tile_activated", "base", player_id, selected_tile)
			# 召喚完了を待つフラグを返す
			return {"wait_for_summon": true}
		else:
			# キャンセルまたは空き地なし → 通常の特殊タイル着地処理
			emit_signal("special_tile_activated", "base", player_id, -1)
			_show_special_tile_landing_ui(player_id)
			return {"wait_for_summon": false}
	
	# フォールバック：タイルがない場合
	print("[SpecialTile] 拠点タイルが見つかりません - スキップ")
	emit_signal("special_tile_activated", "base", player_id, -1)
	_show_special_tile_landing_ui(player_id)
	return {"wait_for_summon": false}

## 遠隔召喚UI表示（ベースタイル用）
func _show_remote_summon_ui(player_id: int, target_tile: int):
	if not ui_manager:
		return
	
	# グローバルナビゲーションを一度クリア（空き地選択の入力が伝播しないように）
	ui_manager.disable_navigation()
	
	# 入力ロックを解除（特殊タイル処理中にロックされている可能性がある）
	if game_flow_manager and game_flow_manager.has_method("unlock_input"):
		game_flow_manager.unlock_input()
	
	# 通常の召喚フィルター（スペル以外が選択可能）
	ui_manager.card_selection_filter = ""
	
	# フェーズラベル更新
	if ui_manager.phase_display:
		ui_manager.show_action_prompt("タイル%dに召喚するクリーチャーを選択" % target_tile)
	
	# 手札UI表示
	var current_player = null
	if player_system and player_id < player_system.players.size():
		current_player = player_system.players[player_id]
	if current_player:
		ui_manager.show_card_selection_ui(current_player)

# ワープペア定義（マップデータから動的に設定）
var warp_pairs = {}

func is_warp_gate(tile_index: int) -> bool:
	return warp_pairs.has(tile_index)

# ワープペアを取得（MovementControllerから使用）
func get_warp_pair(tile_index: int) -> int:
	return warp_pairs.get(tile_index, -1)

# ワープペアを登録（StageLoaderから呼び出し）
func register_warp_pair(from_tile: int, to_tile: int) -> void:
	warp_pairs[from_tile] = to_tile

# ワープペアをクリア（ステージ切り替え時）
func clear_warp_pairs() -> void:
	warp_pairs.clear()

# タイルが特殊マスかチェック（TileHelperに委譲）
func is_special_tile_3d(tile_type: String) -> bool:
	return TileHelper.is_special_type(tile_type)

# 無属性マスかチェック（連鎖計算用）
func is_neutral_tile(tile_type: String) -> bool:
	return tile_type == "neutral"

## CPU用遠隔召喚処理
## tile_action_processorの既存処理を使用
func _cpu_remote_summon(player_id: int, target_tile: int):
	print("[SpecialTile] CPU遠隔召喚開始 - Player%d → タイル%d" % [player_id + 1, target_tile])
	
	# 手札からクリーチャーを取得
	if not card_system:
		print("[SpecialTile] CardSystemなし - 召喚スキップ")
		_clear_remote_placement()
		return
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var creatures = []
	for i in range(hand.size()):
		if hand[i].get("type", "") == "creature":
			creatures.append({"index": i, "card": hand[i]})
	
	if creatures.is_empty():
		print("[SpecialTile] CPU: 手札にクリーチャーなし - 召喚スキップ")
		_clear_remote_placement()
		return
	
	# タイル情報を取得
	var tile_info = {}
	if board_system and board_system.has_method("get_tile_info"):
		tile_info = board_system.get_tile_info(target_tile)
	var tile_element = tile_info.get("element", "neutral")
	
	# 属性一致するクリーチャーを探す
	var best_creature_info = null
	for creature_info in creatures:
		var creature = creature_info.card
		var creature_element = creature.get("element", "neutral")
		if creature_element == tile_element or tile_element == "neutral" or creature_element == "neutral":
			best_creature_info = creature_info
			break
	
	# 属性一致がなければ最初のクリーチャー
	if not best_creature_info and not creatures.is_empty():
		best_creature_info = creatures[0]
	
	if not best_creature_info:
		print("[SpecialTile] CPU: 配置可能なクリーチャーなし - 召喚スキップ")
		_clear_remote_placement()
		return
	
	print("[SpecialTile] CPU: %s を配置（手札インデックス: %d）" % [best_creature_info.card.get("name", "?"), best_creature_info.index])
	
	# tile_action_processorのexecute_summonを使用（遠隔配置モードは既に設定済み）
	if board_system and board_system.tile_action_processor:
		await board_system.execute_summon_action(best_creature_info.index)
	
	# コメント表示
	if ui_manager and ui_manager.global_comment_ui:
		await ui_manager.show_comment_and_wait(
			"%sを配置した！" % best_creature_info.card.get("name", "クリーチャー"), player_id, true
		)
	
	print("[SpecialTile] CPU遠隔召喚完了")

## 遠隔配置モードをクリア
func _clear_remote_placement():
	if board_system and board_system.tile_action_processor:
		board_system.clear_remote_placement()
