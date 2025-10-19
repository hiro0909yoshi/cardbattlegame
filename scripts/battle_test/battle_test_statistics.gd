# バトルテスト統計データ
class_name BattleTestStatistics
extends RefCounted

## 基本統計
var total_battles: int = 0
var attacker_wins: int = 0
var defender_wins: int = 0
var total_duration_ms: int = 0

## クリーチャー別統計
# { "クリーチャー名": { "wins": int, "total": int, "win_rate": float } }
var creature_stats: Dictionary = {}

## アイテム別統計
# { "アイテム名": { "wins": int, "total": int, "win_rate": float } }
var item_stats: Dictionary = {}

## スキル発動統計
# { "スキル名": { "triggered": int, "total_possible": int, "rate": float } }
var skill_stats: Dictionary = {}

## スキル付与統計
# { "スキル名": { "granted": int, "from_item": int, "from_spell": int } }
var skill_grant_stats: Dictionary = {}

## 統計計算
static func calculate(results: Array) -> BattleTestStatistics:
	var stats = BattleTestStatistics.new()
	stats.total_battles = results.size()
	
	for result in results:
		if not (result is BattleTestResult):
			continue
		
		# 勝敗集計
		if result.winner == "attacker":
			stats.attacker_wins += 1
		else:
			stats.defender_wins += 1
		
		# 実行時間集計
		stats.total_duration_ms += result.battle_duration_ms
		
		# クリーチャー統計更新
		_update_creature_stats(stats.creature_stats, result)
		
		# アイテム統計更新
		_update_item_stats(stats.item_stats, result)
		
		# スキル統計更新
		_update_skill_stats(stats.skill_stats, result)
		
		# スキル付与統計更新
		_update_skill_grant_stats(stats.skill_grant_stats, result)
	
	# 勝率計算
	_calculate_win_rates(stats)
	
	return stats

## クリーチャー統計更新
static func _update_creature_stats(stats_dict: Dictionary, result: BattleTestResult):
	# 攻撃側
	if not stats_dict.has(result.attacker_name):
		stats_dict[result.attacker_name] = {"wins": 0, "total": 0}
	stats_dict[result.attacker_name].total += 1
	if result.winner == "attacker":
		stats_dict[result.attacker_name].wins += 1
	
	# 防御側
	if not stats_dict.has(result.defender_name):
		stats_dict[result.defender_name] = {"wins": 0, "total": 0}
	stats_dict[result.defender_name].total += 1
	if result.winner == "defender":
		stats_dict[result.defender_name].wins += 1

## アイテム統計更新
static func _update_item_stats(stats_dict: Dictionary, result: BattleTestResult):
	# 攻撃側アイテム
	if result.attacker_item_name != "" and result.attacker_item_name != "なし":
		if not stats_dict.has(result.attacker_item_name):
			stats_dict[result.attacker_item_name] = {"wins": 0, "total": 0}
		stats_dict[result.attacker_item_name].total += 1
		if result.winner == "attacker":
			stats_dict[result.attacker_item_name].wins += 1
	
	# 防御側アイテム
	if result.defender_item_name != "" and result.defender_item_name != "なし":
		if not stats_dict.has(result.defender_item_name):
			stats_dict[result.defender_item_name] = {"wins": 0, "total": 0}
		stats_dict[result.defender_item_name].total += 1
		if result.winner == "defender":
			stats_dict[result.defender_item_name].wins += 1

## スキル統計更新
static func _update_skill_stats(stats_dict: Dictionary, result: BattleTestResult):
	# 攻撃側の発動スキル
	for skill in result.attacker_skills_triggered:
		if not stats_dict.has(skill):
			stats_dict[skill] = {"triggered": 0, "total_possible": 0}
		stats_dict[skill].triggered += 1
	
	# 防御側の発動スキル
	for skill in result.defender_skills_triggered:
		if not stats_dict.has(skill):
			stats_dict[skill] = {"triggered": 0, "total_possible": 0}
		stats_dict[skill].triggered += 1

## スキル付与統計更新
static func _update_skill_grant_stats(stats_dict: Dictionary, result: BattleTestResult):
	# 攻撃側の付与スキル
	for skill in result.attacker_granted_skills:
		if not stats_dict.has(skill):
			stats_dict[skill] = {"granted": 0, "from_item": 0, "from_spell": 0}
		stats_dict[skill].granted += 1
		# アイテムかスペルかを判定
		if result.attacker_item_id > 0:
			stats_dict[skill].from_item += 1
		if result.attacker_spell_id > 0:
			stats_dict[skill].from_spell += 1
	
	# 防御側の付与スキル
	for skill in result.defender_granted_skills:
		if not stats_dict.has(skill):
			stats_dict[skill] = {"granted": 0, "from_item": 0, "from_spell": 0}
		stats_dict[skill].granted += 1
		if result.defender_item_id > 0:
			stats_dict[skill].from_item += 1
		if result.defender_spell_id > 0:
			stats_dict[skill].from_spell += 1

## 勝率計算
static func _calculate_win_rates(stats: BattleTestStatistics):
	# クリーチャー勝率
	for creature_name in stats.creature_stats:
		var data = stats.creature_stats[creature_name]
		if data.total > 0:
			data["win_rate"] = float(data.wins) / float(data.total) * 100.0
	
	# アイテム勝率
	for item_name in stats.item_stats:
		var data = stats.item_stats[item_name]
		if data.total > 0:
			data["win_rate"] = float(data.wins) / float(data.total) * 100.0
	
	# スキル発動率
	for skill_name in stats.skill_stats:
		var data = stats.skill_stats[skill_name]
		if data.total_possible > 0:
			data["rate"] = float(data.triggered) / float(data.total_possible) * 100.0
