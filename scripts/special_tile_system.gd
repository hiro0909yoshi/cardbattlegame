extends Node
class_name SpecialTileSystem

# 特殊マス管理システム - 3D専用版
# 注意: ワープ機能は将来的にマス自体（BaseTile派生）が持つ予定

signal special_tile_activated(tile_type: String, player_id: int, tile_index: int)
# TODO: 将来実装予定
# signal warp_triggered(from_tile: int, to_tile: int)
signal card_draw_triggered(player_id: int, count: int)
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

func _ready():
	pass

# システム参照を設定
func setup_systems(b_system, c_system: CardSystem, p_system: PlayerSystem, ui_system: UIManager = null):
	board_system = b_system
	card_system = c_system
	player_system = p_system
	ui_manager = ui_system

# 3Dタイル処理（BoardSystem3Dから呼び出される）
func process_special_tile_3d(tile_type: String, tile_index: int, player_id: int) -> void:
	print("特殊タイル処理: ", tile_type, " (マス", tile_index, ")")
	
	match tile_type:
		"start":
			handle_start_tile(player_id)
		"checkpoint":
			handle_checkpoint_tile(player_id)
		"card":
			handle_card_tile(player_id)
		"warp_stop":
			handle_warp_stop_tile(tile_index, player_id)
		"neutral":
			# 無属性マスは通常タイルとして処理しない（土地取得不可）
			print("無属性マス - 連鎖は切れます")
			emit_signal("special_action_completed")
		_:
			print("未実装の特殊タイル: ", tile_type)
			emit_signal("special_action_completed")

# スタートマス処理
func handle_start_tile(player_id: int):
	print("スタート地点")
	emit_signal("special_tile_activated", "start", player_id, 0)
	emit_signal("special_action_completed")

# チェックポイント処理
# 注意: 魔力ボーナスとダウン解除はLapSystemで管理
func handle_checkpoint_tile(player_id: int):
	print("チェックポイント通過")
	
	# UI更新
	if ui_manager and ui_manager.has_method("update_player_info_panels"):
		ui_manager.update_player_info_panels()
	
	emit_signal("special_tile_activated", "checkpoint", player_id, 5)
	emit_signal("special_action_completed")

# カードマス処理
func handle_card_tile(player_id: int):
	var draw_count = 1
	
	if card_system:
		var drawn_cards = card_system.draw_cards_for_player(player_id, draw_count)
		if drawn_cards.size() > 0:
			print("カードマス！", drawn_cards.size(), "枚ドロー")
			emit_signal("card_draw_triggered", player_id, drawn_cards.size())
		else:
			print("カードマス！（手札上限のためドロー失敗）")
	
	emit_signal("special_tile_activated", "card", player_id, -1)
	emit_signal("special_action_completed")

# 停止型ワープマス処理
func handle_warp_stop_tile(tile_index: int, player_id: int):
	var warp_pair = get_warp_pair(tile_index)
	if warp_pair == -1 or warp_pair == tile_index:
		print("停止型ワープ: ワープ先なし")
		emit_signal("special_action_completed")
		return
	
	print("停止型ワープ発動！ タイル%d → タイル%d" % [tile_index, warp_pair])
	
	# movement_controllerでワープ実行
	if board_system and board_system.movement_controller:
		await board_system.movement_controller.execute_warp(player_id, tile_index, warp_pair)
		# プレイヤー位置を更新
		board_system.movement_controller.player_tiles[player_id] = warp_pair
	
	emit_signal("special_tile_activated", "warp_stop", player_id, warp_pair)
	emit_signal("special_action_completed")

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
