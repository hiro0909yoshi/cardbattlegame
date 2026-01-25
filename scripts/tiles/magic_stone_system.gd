# 魔法石システム
# 魔法石の価値計算、売買処理を管理

class_name MagicStoneSystem

# 定数
const BASE_VALUE = 50  # 初期価値
const MIN_VALUE = 25   # 最低価値
const SAME_ELEMENT_BONUS = 4    # 同属性の石1つあたり+4EP
const OPPOSING_ELEMENT_PENALTY = 2  # 対照属性の石1つあたり-2EP

# 属性と相克関係
const OPPOSING_ELEMENTS = {
	"fire": "water",
	"water": "fire",
	"earth": "wind",
	"wind": "earth"
}

# システム参照
var board_system_ref = null
var player_system_ref = null

## 初期化
func initialize(board_system, player_system) -> void:
	board_system_ref = board_system
	player_system_ref = player_system

## 指定属性の石の現在価値を計算
func calculate_stone_value(element: String) -> int:
	if not element in OPPOSING_ELEMENTS:
		return BASE_VALUE
	
	# 全プレイヤーの石の所持数を集計
	var same_count = 0
	var opposing_count = 0
	var opposing_element = OPPOSING_ELEMENTS[element]
	
	if player_system_ref:
		for player in player_system_ref.players:
			same_count += player.magic_stones.get(element, 0)
			opposing_count += player.magic_stones.get(opposing_element, 0)
	
	# ボーナス計算（同属性の石1つにつき+4EP）
	var same_bonus = same_count * SAME_ELEMENT_BONUS
	
	# ペナルティ計算（対照属性の石1つにつき-2EP）
	var opposing_penalty = opposing_count * OPPOSING_ELEMENT_PENALTY
	
	# 最終価値（最低値保証）
	var value = BASE_VALUE + same_bonus - opposing_penalty
	return max(MIN_VALUE, value)

## 全属性の石価値を取得
func get_all_stone_values() -> Dictionary:
	return {
		"fire": calculate_stone_value("fire"),
		"water": calculate_stone_value("water"),
		"earth": calculate_stone_value("earth"),
		"wind": calculate_stone_value("wind")
	}

## プレイヤーの所持石の総価値を計算
func calculate_player_stone_value(player_id: int) -> int:
	if not player_system_ref or player_id < 0:
		return 0
	
	if player_id >= player_system_ref.players.size():
		return 0
	
	var player = player_system_ref.players[player_id]
	var stones = player.magic_stones
	var total_value = 0
	
	for element in stones:
		var count = stones[element]
		if count > 0:
			var unit_value = calculate_stone_value(element)
			total_value += unit_value * count
	
	return total_value

## 石を購入
func buy_stone(player_id: int, element: String, count: int = 1) -> Dictionary:
	if not player_system_ref or player_id < 0 or player_id >= player_system_ref.players.size():
		return {"success": false, "reason": "invalid_player"}
	
	if not element in OPPOSING_ELEMENTS:
		return {"success": false, "reason": "invalid_element"}
	
	var player = player_system_ref.players[player_id]
	var unit_value = calculate_stone_value(element)
	var total_cost = unit_value * count
	
	if player.magic_power < total_cost:
		return {"success": false, "reason": "insufficient_magic", "required": total_cost, "available": player.magic_power}
	
	# EPを消費
	player_system_ref.add_magic(player_id, -total_cost)
	
	# 石を追加
	player.magic_stones[element] += count
	
	print("[魔法石購入] プレイヤー%d: %s石 ×%d (単価%dEP, 合計%dEP)" % [player_id + 1, element, count, unit_value, total_cost])
	
	return {"success": true, "element": element, "count": count, "unit_value": unit_value, "total_cost": total_cost}

## 石を売却
func sell_stone(player_id: int, element: String, count: int = 1) -> Dictionary:
	if not player_system_ref or player_id < 0 or player_id >= player_system_ref.players.size():
		return {"success": false, "reason": "invalid_player"}
	
	if not element in OPPOSING_ELEMENTS:
		return {"success": false, "reason": "invalid_element"}
	
	var player = player_system_ref.players[player_id]
	var owned = player.magic_stones.get(element, 0)
	
	if owned < count:
		return {"success": false, "reason": "insufficient_stones", "owned": owned, "requested": count}
	
	var unit_value = calculate_stone_value(element)
	var total_value = unit_value * count
	
	# 石を減らす
	player.magic_stones[element] -= count
	
	# EPを獲得
	player_system_ref.add_magic(player_id, total_value)
	
	print("[魔法石売却] プレイヤー%d: %s石 ×%d (単価%dEP, 合計%dEP)" % [player_id + 1, element, count, unit_value, total_value])
	
	return {"success": true, "element": element, "count": count, "unit_value": unit_value, "total_value": total_value}

## プレイヤーの所持石情報を取得
func get_player_stones(player_id: int) -> Dictionary:
	if not player_system_ref or player_id < 0 or player_id >= player_system_ref.players.size():
		return {"fire": 0, "water": 0, "earth": 0, "wind": 0}
	
	return player_system_ref.players[player_id].magic_stones.duplicate()
