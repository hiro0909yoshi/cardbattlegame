class_name RewardCalculator
extends RefCounted

## 報酬計算クラス
## ステージクリア時の報酬を計算する

# 2回目以降の報酬倍率
const REPEAT_REWARD_RATE = 0.2


## 報酬を計算
## stage_data: ステージJSONデータ
## rank: クリアランク（SS/S/A/B/C）
## is_first_clear: 初回クリアかどうか
static func calculate_rewards(stage_data: Dictionary, rank: String, is_first_clear: bool) -> Dictionary:
	var rewards = stage_data.get("rewards", {})
	var base_gold = rewards.get("gold", 0)
	var rank_bonus_table = rewards.get("rank_bonus", {})
	
	var result = {
		"base_gold": 0,
		"rank_bonus": 0,
		"total": 0,
		"is_first_clear": is_first_clear
	}
	
	if is_first_clear:
		# 初回クリア：ステージ報酬 + ランクボーナス
		result.base_gold = base_gold
		result.rank_bonus = rank_bonus_table.get(rank, 0)
	else:
		# 2回目以降：ステージ報酬 × 20%（切り上げ）
		result.base_gold = int(ceil(base_gold * REPEAT_REWARD_RATE))
		result.rank_bonus = 0
	
	result.total = result.base_gold + result.rank_bonus
	return result


## 敗北時の報酬（常に0）
static func calculate_defeat_rewards() -> Dictionary:
	return {
		"base_gold": 0,
		"rank_bonus": 0,
		"total": 0,
		"is_first_clear": false,
		"is_defeat": true
	}
