class_name RankCalculator
extends RefCounted

## ランク計算クラス
## ターン数からクリアランクを計算する
## 将来的に他の判定基準も追加可能な設計

# ランク閾値（このターン数以下なら該当ランク）
const RANK_THRESHOLDS = {
	"SS": 14,
	"S": 19,
	"A": 24,
	"B": 29,
	# C は 30以上
}

# ランクの順序（比較用）
const RANK_ORDER = ["SS", "S", "A", "B", "C"]


## ターン数からランクを計算
static func calculate_rank(turn_count: int) -> String:
	if turn_count <= RANK_THRESHOLDS["SS"]:
		return "SS"
	elif turn_count <= RANK_THRESHOLDS["S"]:
		return "S"
	elif turn_count <= RANK_THRESHOLDS["A"]:
		return "A"
	elif turn_count <= RANK_THRESHOLDS["B"]:
		return "B"
	else:
		return "C"


## 拡張版：複合判定（将来用）
## context には turn_count 以外にも tep_ratio, destroy_count 等を追加可能
static func calculate_rank_extended(context: Dictionary) -> String:
	var turn_count = context.get("turn_count", 999)
	
	# 将来的に他の要素も加味可能
	# var tep_ratio = context.get("tep_ratio", 0.0)
	# var destroy_count = context.get("destroy_count", 0)
	
	return calculate_rank(turn_count)


## ランク比較（rank_a が rank_b より良いか）
static func is_better_rank(rank_a: String, rank_b: String) -> bool:
	var index_a = RANK_ORDER.find(rank_a)
	var index_b = RANK_ORDER.find(rank_b)
	
	if index_a == -1:
		return false
	if index_b == -1:
		return true
	
	return index_a < index_b


## ランクが有効かチェック
static func is_valid_rank(rank: String) -> bool:
	return rank in RANK_ORDER
