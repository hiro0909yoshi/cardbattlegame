class_name StageRecordManager
extends RefCounted

## ステージ記録管理クラス
## クリア状況、ベストランク等を管理
## 
## 現在はGameData経由でJSONに保存
## 将来的にはSQLiteに移行可能な設計

# GameDataへの参照（Autoload）
# GameData.player_data.story_progress.stage_records を使用


## 記録データを取得（内部用）
static func _get_records() -> Dictionary:
	if not GameData.player_data.story_progress.has("stage_records"):
		GameData.player_data.story_progress["stage_records"] = {}
	return GameData.player_data.story_progress.stage_records


## ステージの記録を取得
static func get_record(stage_id: String) -> Dictionary:
	var records = _get_records()
	return records.get(stage_id, {})


## 初回クリアかどうか
static func is_first_clear(stage_id: String) -> bool:
	return not get_record(stage_id).get("cleared", false)


## クリア済みかどうか
static func is_cleared(stage_id: String) -> bool:
	return get_record(stage_id).get("cleared", false)


## ベストランクを取得
static func get_best_rank(stage_id: String) -> String:
	return get_record(stage_id).get("best_rank", "")


## ベストターン数を取得
static func get_best_turn(stage_id: String) -> int:
	return get_record(stage_id).get("best_turn", 0)


## クリア回数を取得
static func get_clear_count(stage_id: String) -> int:
	return get_record(stage_id).get("clear_count", 0)


## 記録を更新（クリア時に呼び出す）
static func update_record(stage_id: String, rank: String, turn_count: int) -> Dictionary:
	var records = _get_records()
	var is_first = not records.has(stage_id) or not records[stage_id].get("cleared", false)
	var is_best_updated = false
	
	if not records.has(stage_id):
		records[stage_id] = {}
	
	var record = records[stage_id]
	
	if is_first:
		# 初回クリア
		record["cleared"] = true
		record["first_clear_date"] = Time.get_datetime_string_from_system()
		record["clear_count"] = 1
		record["best_rank"] = rank
		record["best_turn"] = turn_count
		is_best_updated = true
		print("[StageRecordManager] 初回クリア記録: %s (ランク: %s, ターン: %d)" % [stage_id, rank, turn_count])
	else:
		# 2回目以降
		record["clear_count"] = record.get("clear_count", 0) + 1
		
		# ベスト更新判定（ターン数が少ない方が良い）
		var current_best_turn = record.get("best_turn", 999)
		if turn_count < current_best_turn:
			record["best_rank"] = rank
			record["best_turn"] = turn_count
			is_best_updated = true
			print("[StageRecordManager] ベスト更新: %s (ランク: %s, ターン: %d)" % [stage_id, rank, turn_count])
		else:
			print("[StageRecordManager] クリア記録追加: %s (ランク: %s, ターン: %d) ※ベスト更新なし" % [stage_id, rank, turn_count])
	
	GameData.save_to_file()
	
	return {
		"is_first_clear": is_first,
		"is_best_updated": is_best_updated,
		"best_rank": record["best_rank"],
		"best_turn": record["best_turn"],
		"clear_count": record["clear_count"]
	}


## クリア済みステージ一覧を取得
static func get_all_cleared_stages() -> Array:
	var result = []
	var records = _get_records()
	for stage_id in records.keys():
		if records[stage_id].get("cleared", false):
			result.append(stage_id)
	return result


## 特定ランク以上のクリア数を取得（称号用）
static func get_rank_clear_count(min_rank: String) -> int:
	var count = 0
	var records = _get_records()
	for stage_id in records.keys():
		var record = records[stage_id]
		if record.get("cleared", false):
			var best_rank = record.get("best_rank", "C")
			if RankCalculator.is_better_rank(best_rank, min_rank) or best_rank == min_rank:
				count += 1
	return count


## SSクリア数を取得
static func get_ss_count() -> int:
	return get_rank_clear_count("SS")


## 全ステージクリア済みか（将来用）
static func is_all_cleared(all_stage_ids: Array) -> bool:
	for stage_id in all_stage_ids:
		if not is_cleared(stage_id):
			return false
	return true


## 全ステージSSクリア済みか（将来用）
static func is_all_ss(all_stage_ids: Array) -> bool:
	for stage_id in all_stage_ids:
		if get_best_rank(stage_id) != "SS":
			return false
	return true
