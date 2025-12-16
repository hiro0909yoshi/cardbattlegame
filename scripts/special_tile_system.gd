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
const GameConstants = preload("res://scripts/game_constants.gd")

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
	if ui_manager.phase_label:
		ui_manager.phase_label.text = "特殊タイル: 召喚不可（パスまたは領地コマンドを使用）"

# 3Dタイル処理（BoardSystem3Dから呼び出される）
# 注意: この関数はawaitで呼び出すこと
func process_special_tile_3d(tile_type: String, tile_index: int, player_id: int) -> void:
	print("特殊タイル処理: ", tile_type, " (マス", tile_index, ")")
	
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
			await handle_magic_stone_tile(player_id)
		"magic":
			await handle_magic_tile(player_id, tile)
		"base":
			await handle_base_tile(player_id)
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
# 注意: 魔力ボーナスとダウン解除はLapSystemで管理
func handle_checkpoint_tile(player_id: int):
	print("チェックポイント通過")
	
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
	if board_system and board_system.movement_controller:
		await board_system.movement_controller.execute_warp(player_id, tile_index, warp_pair)
		# プレイヤー位置を更新
		board_system.movement_controller.player_tiles[player_id] = warp_pair
	
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

# 魔法石マス処理（未実装）
func handle_magic_stone_tile(player_id: int):
	print("魔法石マス - TODO: 実装予定")
	emit_signal("special_tile_activated", "magic_stone", player_id, -1)
	
	# 共通UI設定
	_show_special_tile_landing_ui(player_id)

# 魔法マス処理（タイルに委譲）
func handle_magic_tile(player_id: int, tile = null):
	print("[SpecialTile] 魔法マス - Player%d" % (player_id + 1))
	
	# タイルに処理を委譲
	if tile and tile.has_method("handle_special_action"):
		var context = _create_tile_context()
		var result = await tile.handle_special_action(player_id, context)
		print("[SpecialTile] 魔法マス処理完了: %s" % result)
	else:
		# フォールバック: CPUの場合はスキップ
		if _is_cpu_player(player_id):
			print("[SpecialTile] CPU - 魔法マススキップ")
	
	emit_signal("special_tile_activated", "magic", player_id, -1)
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

# 拠点マス処理（未実装）
func handle_base_tile(player_id: int):
	print("拠点マス - TODO: 実装予定")
	emit_signal("special_tile_activated", "base", player_id, -1)
	
	# 共通UI設定
	_show_special_tile_landing_ui(player_id)

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

# CPUプレイヤーかチェック
func _is_cpu_player(player_id: int) -> bool:
	if board_system and "player_is_cpu" in board_system:
		var cpu_flags = board_system.player_is_cpu
		if player_id < cpu_flags.size():
			return cpu_flags[player_id]
	return false
