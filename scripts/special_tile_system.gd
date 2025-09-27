extends Node
class_name SpecialTileSystem

# 特殊マス管理システム - GameConstants対応版

signal special_tile_activated(tile_type: String, player_id: int, tile_index: int)
signal warp_triggered(from_tile: int, to_tile: int)
signal card_draw_triggered(player_id: int, count: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# 特殊マスタイプ
enum SpecialType {
	NONE,
	WARP_GATE,    # 通過型ワープ
	WARP_POINT,   # 停止型ワープ  
	NEUTRAL,      # 無属性マス（土地）
	CARD,         # カードマス
	FORT,         # 砦（将来実装）
	SHRINE,       # 神殿（将来実装）
	TRAP          # トラップ（将来実装）
}

# 特殊マス設定データ
var special_tiles = {}  # tile_index -> SpecialTileData
var warp_pairs = []      # ワープマスのペア [{from: int, to: int, type: String}]

# システム参照
var board_system
var card_system: CardSystem
var player_system: PlayerSystem

func _ready():
	pass

# システム参照を設定
func setup_systems(b_system, c_system: CardSystem, p_system: PlayerSystem):
	board_system = b_system
	card_system = c_system
	player_system = p_system

# 特殊マスを配置（ボード生成時に呼ぶ）
func setup_special_tiles(total_tiles: int):
	special_tiles.clear()
	warp_pairs.clear()
	
	# 通過型ワープマスを配置（マス3 ↔ マス5）
	setup_warp_gates(total_tiles)
	
	# 停止型ワープマスを配置（マス14 → マス16）
	setup_warp_points(total_tiles)
	
	# カードマスを配置
	setup_card_tiles(total_tiles)
	
	# 無属性マスを配置
	setup_neutral_tiles(total_tiles)

# 通過型ワープマスを設定
func setup_warp_gates(total_tiles: int):
	# マス3とマス5の相互ワープ（マス5はチェックポイント）
	if total_tiles > 5:
		add_special_tile(3, SpecialType.WARP_GATE, {"pair_index": 5})
		add_special_tile(5, SpecialType.WARP_GATE, {"pair_index": 3})
		warp_pairs.append({"from": 3, "to": 5, "type": "gate"})
		warp_pairs.append({"from": 5, "to": 3, "type": "gate"})

# 停止型ワープマスを設定
func setup_warp_points(total_tiles: int):
	# マス14からマス16への一方向ワープ
	if total_tiles > 15:
		add_special_tile(14, SpecialType.WARP_POINT, {"pair_index": 15})
		warp_pairs.append({"from": 14, "to": 15, "type": "point"})
		# マス16自体はカードマス（後で設定）

# カードマスを設定
func setup_card_tiles(total_tiles: int):
	# マス2, 8, 12, 16にカードマス
	var card_positions = [2, 8, 12, 16]
	for pos in card_positions:
		if pos < total_tiles:
			add_special_tile(pos, SpecialType.CARD, {"draw_count": 1})

# 無属性マスを設定
func setup_neutral_tiles(total_tiles: int):
	# マス1, 9, 18, 19に無属性マス
	var neutral_positions = [1, 9, 18, 19]
	for pos in neutral_positions:
		if pos < total_tiles:
			add_special_tile(pos, SpecialType.NEUTRAL, {})

# 特殊マスを追加
func add_special_tile(tile_index: int, type: SpecialType, data: Dictionary = {}):
	special_tiles[tile_index] = {
		"type": type,
		"data": data
	}
	
	# ボードシステムに特殊マスフラグを設定
	if board_system:
		board_system.mark_as_special_tile(tile_index, type)

# 特殊マスかチェック
func is_special_tile(tile_index: int) -> bool:
	return special_tiles.has(tile_index)

# 特殊マスタイプを取得
func get_special_type(tile_index: int) -> SpecialType:
	if special_tiles.has(tile_index):
		return special_tiles[tile_index].type
	return SpecialType.NONE

# 通過型ワープマスかチェック（移動中に判定）
func is_warp_gate(tile_index: int) -> bool:
	if special_tiles.has(tile_index):
		return special_tiles[tile_index].type == SpecialType.WARP_GATE
	return false

# 通過型ワープを処理（移動カウントを消費しない）
func process_warp_gate(tile_index: int, player_id: int, remaining_steps: int) -> Dictionary:
	if not is_warp_gate(tile_index):
		return {"warped": false}
	
	var tile_data = special_tiles[tile_index]
	var target_tile = tile_data.data.get("pair_index", tile_index)
	
	if target_tile != tile_index:
		print("ワープゲート通過！マス", tile_index, " → マス", target_tile)
		emit_signal("warp_triggered", tile_index, target_tile)
		
		return {
			"warped": true,
			"new_tile": target_tile,
			"remaining_steps": remaining_steps  # 移動カウントは減らない
		}
	
	return {"warped": false}

# 特殊マスの効果を発動（停止時）
func activate_special_tile(tile_index: int, player_id: int) -> Dictionary:
	if not special_tiles.has(tile_index):
		return {"success": false, "type": SpecialType.NONE}
	
	var tile_data = special_tiles[tile_index]
	var result = {"success": true, "type": tile_data.type}
	
	match tile_data.type:
		SpecialType.WARP_POINT:
			result["warp_to"] = activate_warp_point(tile_index, player_id)
			
		SpecialType.CARD:
			result["cards_drawn"] = activate_card_draw(tile_index, player_id)
			
		SpecialType.NEUTRAL:
			result["message"] = "無属性マス - 連鎖が切れます（土地として取得可能）"
			
		SpecialType.WARP_GATE:
			# 通過型は停止時には何もしない
			result["message"] = "ワープゲート（通過時のみ発動）"
			
		_:
			result["message"] = "未実装の特殊マス"
	
	emit_signal("special_tile_activated", get_type_name(tile_data.type), player_id, tile_index)
	return result

# 停止型ワープマスの効果
func activate_warp_point(tile_index: int, player_id: int) -> int:
	var tile_data = special_tiles[tile_index]
	var target_tile = tile_data.data.get("pair_index", tile_index)
	
	if target_tile != tile_index:
		print("ワープポイント発動！マス", tile_index, " → マス", target_tile)
		emit_signal("warp_triggered", tile_index, target_tile)
		
		# プレイヤーを移動
		if player_system:
			player_system.place_player_at_tile(player_id, target_tile, board_system)
		
		return target_tile
	
	return tile_index

# カードマスの効果
func activate_card_draw(tile_index: int, player_id: int) -> int:
	var tile_data = special_tiles[tile_index]
	var draw_count = tile_data.data.get("draw_count", 1)
	
	print("カードマス！", draw_count, "枚ドロー")
	emit_signal("card_draw_triggered", player_id, draw_count)
	
	# カードを引く
	if card_system:
		var drawn_cards = card_system.draw_cards_for_player(player_id, draw_count)
		return drawn_cards.size()
	
	return 0

# 特殊マスタイプ名を取得
func get_type_name(type: SpecialType) -> String:
	match type:
		SpecialType.WARP_GATE: return "ワープゲート"
		SpecialType.WARP_POINT: return "ワープポイント"
		SpecialType.CARD: return "カード"
		SpecialType.NEUTRAL: return "無属性"
		SpecialType.FORT: return "砦"
		SpecialType.SHRINE: return "神殿"
		SpecialType.TRAP: return "トラップ"
		_: return "不明"

# 特殊マス色を取得（GameConstantsから取得）
func get_special_tile_color(type: SpecialType) -> Color:
	match type:
		SpecialType.WARP_GATE: 
			return GameConstants.SPECIAL_TILE_COLORS.get("WARP_GATE", Color(1.0, 0.5, 0.0))
		SpecialType.WARP_POINT: 
			return GameConstants.SPECIAL_TILE_COLORS.get("WARP_POINT", Color(0.8, 0.3, 0.8))
		SpecialType.CARD: 
			return GameConstants.SPECIAL_TILE_COLORS.get("CARD", Color(0.3, 0.8, 0.8))
		SpecialType.NEUTRAL: 
			return GameConstants.SPECIAL_TILE_COLORS.get("NEUTRAL", Color(0.5, 0.5, 0.5))
		_: 
			return Color(0.7, 0.7, 0.7)

# ワープペアを取得
func get_warp_pair(tile_index: int) -> int:
	if special_tiles.has(tile_index):
		var tile_data = special_tiles[tile_index]
		if tile_data.type == SpecialType.WARP_GATE or tile_data.type == SpecialType.WARP_POINT:
			return tile_data.data.get("pair_index", -1)
	return -1

# 無属性マスかチェック（連鎖計算用）
func is_neutral_tile(tile_index: int) -> bool:
	if special_tiles.has(tile_index):
		return special_tiles[tile_index].type == SpecialType.NEUTRAL
	return false

# デバッグ：特殊マス一覧を表示
func debug_print_special_tiles():
	print("\n=== 特殊マス一覧 ===")
	for tile_index in special_tiles:
		var tile_data = special_tiles[tile_index]
		print("マス", tile_index, ": ", get_type_name(tile_data.type))
		if tile_data.type == SpecialType.WARP_GATE or tile_data.type == SpecialType.WARP_POINT:
			print("  → ワープ先: マス", tile_data.data.get("pair_index", -1))
