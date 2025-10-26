extends Node
class_name SpecialTileSystem

# 特殊マス管理システム - 3D専用版
# 注意: ワープ機能は将来的にマス自体（BaseTile派生）が持つ予定

signal special_tile_activated(tile_type: String, player_id: int, tile_index: int)
# TODO: 将来実装予定
# signal warp_triggered(from_tile: int, to_tile: int)
signal card_draw_triggered(player_id: int, count: int)
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
func handle_checkpoint_tile(player_id: int):
	var bonus = GameConstants.CHECKPOINT_BONUS
	player_system.add_magic(player_id, bonus)
	print("チェックポイント！魔力+", bonus, "G")
	
	# UI更新
	if ui_manager and ui_manager.has_method("update_player_info_panels"):
		ui_manager.update_player_info_panels()
	
	emit_signal("checkpoint_passed", player_id, bonus)
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

# ワープゲートかチェック（MovementController3Dから使用）
# 注意: 3D版ではマス自体がワープ機能を持つため、常にfalseを返す
# ワープペア定義（通過後の移動先）
var warp_pairs = {
	5: 6,    # タイル5を通過 → タイル6へワープ
	15: 16   # タイル15を通過 → タイル16へワープ
}

func is_warp_gate(tile_index: int) -> bool:
	return warp_pairs.has(tile_index)

# ワープペアを取得（MovementControllerから使用）
func get_warp_pair(tile_index: int) -> int:
	return warp_pairs.get(tile_index, -1)

# タイルが特殊マスかチェック
func is_special_tile_3d(tile_type: String) -> bool:
	return tile_type in ["start", "checkpoint", "warp", "card", "neutral"]

# 無属性マスかチェック（連鎖計算用）
func is_neutral_tile(tile_type: String) -> bool:
	return tile_type == "neutral"
