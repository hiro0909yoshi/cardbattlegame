extends Node

signal mission_completed(mission_id: String)
signal mission_claimed(mission_id: String)
signal progress_updated(mission_id: String, current: int, target: int)

const SAVE_PATH := "user://mission_save.json"
const MISSIONS_PATH := "res://data/missions.json"
const RESET_HOUR := 4

var _definitions: Dictionary = {}
var _save_data: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	_load_save()
	_check_reset()


func _load_definitions() -> void:
	var file := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	if not file:
		push_warning("[MissionManager] missions.json が読み込めません")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[MissionManager] missions.json パースエラー")
		return
	_definitions = json.data


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_save_data = _create_default_save()
		_save()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_save_data = _create_default_save()
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_save_data = _create_default_save()
		return
	_save_data = json.data


func _create_default_save() -> Dictionary:
	return {
		"daily": {
			"last_reset": "",
			"progress": {}
		},
		"weekly": {
			"last_reset": "",
			"progress": {}
		},
		"permanent": {
			"claimed": []
		}
	}


func _save() -> void:
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(_save_data, "\t"))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.rename_absolute(tmp_path, SAVE_PATH)


# ==========================================
# リセット判定
# ==========================================

func _check_reset() -> void:
	var now := _get_jst_dict()
	_check_daily_reset(now)
	_check_weekly_reset(now)


func _check_daily_reset(now: Dictionary) -> void:
	var last_str: String = _save_data.get("daily", {}).get("last_reset", "")
	var reset_time := _get_daily_reset_time(now)
	if last_str == "" or _is_before(last_str, reset_time):
		_save_data["daily"]["progress"] = {}
		_save_data["daily"]["last_reset"] = reset_time
		_save()


func _check_weekly_reset(now: Dictionary) -> void:
	var last_str: String = _save_data.get("weekly", {}).get("last_reset", "")
	var reset_time := _get_weekly_reset_time(now)
	if last_str == "" or _is_before(last_str, reset_time):
		_save_data["weekly"]["progress"] = {}
		_save_data["weekly"]["last_reset"] = reset_time
		_save()


func _get_jst_dict() -> Dictionary:
	var utc := Time.get_datetime_dict_from_system(true)
	# UTC+9 簡易変換
	utc["hour"] = utc["hour"] + 9
	if utc["hour"] >= 24:
		utc["hour"] -= 24
		utc["day"] += 1
	return utc


func _get_daily_reset_time(now: Dictionary) -> String:
	var y: int = now["year"]
	var m: int = now["month"]
	var d: int = now["day"]
	if now["hour"] < RESET_HOUR:
		d -= 1
		if d <= 0:
			m -= 1
			if m <= 0:
				m = 12
				y -= 1
			d = _days_in_month(y, m)
	return "%04d-%02d-%02dT%02d:00:00" % [y, m, d, RESET_HOUR]


func _get_weekly_reset_time(now: Dictionary) -> String:
	var y: int = now["year"]
	var m: int = now["month"]
	var d: int = now["day"]
	if now["hour"] < RESET_HOUR:
		d -= 1
	var weekday: int = Time.get_datetime_dict_from_system(true).get("weekday", 0)
	# 月曜(1)にリセット。weekday: 0=日, 1=月, ..., 6=土
	var days_since_monday: int = (weekday - 1) % 7
	if days_since_monday < 0:
		days_since_monday += 7
	d -= days_since_monday
	if d <= 0:
		m -= 1
		if m <= 0:
			m = 12
			y -= 1
		d += _days_in_month(y, m)
	return "%04d-%02d-%02dT%02d:00:00" % [y, m, d, RESET_HOUR]


func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12: return 31
		4, 6, 9, 11: return 30
		2:
			if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
				return 29
			return 28
		_: return 30


func _is_before(a: String, b: String) -> bool:
	return a < b


# ==========================================
# 進捗管理
# ==========================================

func add_progress(condition_type: String, amount: int = 1) -> void:
	_update_category_progress("daily", condition_type, amount)
	_update_category_progress("weekly", condition_type, amount)
	_update_permanent_progress(condition_type, amount)
	_save()


func _update_category_progress(category: String, condition_type: String, amount: int) -> void:
	var missions: Array = _definitions.get(category, [])
	var progress: Dictionary = _save_data.get(category, {}).get("progress", {})

	for mission in missions:
		var mid: String = mission.get("id", "")
		var cond: Dictionary = mission.get("condition", {})
		if cond.get("type", "") != condition_type:
			continue

		if not progress.has(mid):
			progress[mid] = {"current": 0, "claimed": false}

		if progress[mid].get("claimed", false):
			continue

		var target: int = int(cond.get("target", 1))
		var before: int = int(progress[mid].get("current", 0))
		progress[mid]["current"] = before + amount
		var after: int = int(progress[mid]["current"])

		progress_updated.emit(mid, after, target)

		if before < target and after >= target:
			mission_completed.emit(mid)
			print("[MissionManager] ミッション達成: %s" % mission.get("title", mid))


func _update_permanent_progress(condition_type: String, _amount: int) -> void:
	var missions: Array = _definitions.get("permanent", [])
	var claimed: Array = _save_data.get("permanent", {}).get("claimed", [])

	for mission in missions:
		var mid: String = mission.get("id", "")
		if mid in claimed:
			continue
		var cond: Dictionary = mission.get("condition", {})
		if cond.get("type", "") != condition_type:
			continue
		# 永続ミッションは累計値で判定するため、ここでは達成通知のみ
		var target: int = int(cond.get("target", 1))
		var current := _get_permanent_current(condition_type)
		if current >= target:
			mission_completed.emit(mid)


func _get_permanent_current(condition_type: String) -> int:
	if not GameData or not GameData.player_data:
		return 0
	var stats: Dictionary = GameData.player_data.get("stats", {})
	var quest: Dictionary = stats.get("quest", {})
	var net: Dictionary = stats.get("net_battle", {})

	match condition_type:
		"quest_play":
			return int(quest.get("plays", 0))
		"quest_clear":
			return int(quest.get("clears", 0))
		"creature_battle":
			return int(quest.get("battles", 0)) + int(net.get("battles", 0))
		"creature_summon":
			return int(quest.get("creature_summons", 0)) + int(net.get("creature_summons", 0))
		"spell_use":
			return int(quest.get("spell_uses", 0)) + int(net.get("spell_uses", 0))
		"gacha_pull":
			return int(stats.get("gacha_count", 0))
		_:
			return 0


# ==========================================
# ミッション情報取得
# ==========================================

func get_missions(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var missions: Array = _definitions.get(category, [])

	for mission in missions:
		var mid: String = mission.get("id", "")
		var cond: Dictionary = mission.get("condition", {})
		var target: int = int(cond.get("target", 1))
		var current: int = 0
		var claimed := false

		if category == "permanent":
			current = _get_permanent_current(cond.get("type", ""))
			claimed = mid in _save_data.get("permanent", {}).get("claimed", [])
		else:
			var progress: Dictionary = _save_data.get(category, {}).get("progress", {})
			var p: Dictionary = progress.get(mid, {})
			current = int(p.get("current", 0))
			claimed = p.get("claimed", false)

		result.append({
			"id": mid,
			"title": mission.get("title", ""),
			"description": mission.get("description", ""),
			"target": target,
			"current": mini(current, target),
			"completed": current >= target,
			"claimed": claimed,
			"reward": mission.get("reward", {})
		})

	return result


func is_completed(mission_id: String) -> bool:
	for category in ["daily", "weekly", "permanent"]:
		var missions := get_missions(category)
		for m in missions:
			if m["id"] == mission_id:
				return m["completed"]
	return false


func is_claimed(mission_id: String) -> bool:
	for category in ["daily", "weekly", "permanent"]:
		var missions := get_missions(category)
		for m in missions:
			if m["id"] == mission_id:
				return m["claimed"]
	return false


# ==========================================
# 報酬受け取り
# ==========================================

func claim_reward(mission_id: String) -> bool:
	var category := _find_category(mission_id)
	if category == "":
		return false

	var mission := _find_mission(mission_id)
	if mission.is_empty():
		return false

	var cond: Dictionary = mission.get("condition", {})
	var target: int = int(cond.get("target", 1))

	if category == "permanent":
		var current := _get_permanent_current(cond.get("type", ""))
		if current < target:
			return false
		var claimed: Array = _save_data["permanent"]["claimed"]
		if mission_id in claimed:
			return false
		claimed.append(mission_id)
	else:
		var progress: Dictionary = _save_data[category]["progress"]
		if not progress.has(mission_id):
			return false
		var p: Dictionary = progress[mission_id]
		if int(p.get("current", 0)) < target:
			return false
		if p.get("claimed", false):
			return false
		p["claimed"] = true

	# 報酬付与
	var reward: Dictionary = mission.get("reward", {})
	var reward_type: String = reward.get("type", "gold")
	var amount: int = int(reward.get("amount", 0))

	match reward_type:
		"gold":
			GameData.add_gold(amount)
		"stone":
			GameData.add_stone(amount)

	mission_claimed.emit(mission_id)
	print("[MissionManager] 報酬受取: %s → %s %d" % [mission.get("title", ""), reward_type, amount])
	_save()
	return true


func _find_category(mission_id: String) -> String:
	if mission_id.begins_with("d"):
		return "daily"
	elif mission_id.begins_with("w"):
		return "weekly"
	elif mission_id.begins_with("p"):
		return "permanent"
	return ""


func _find_mission(mission_id: String) -> Dictionary:
	var category := _find_category(mission_id)
	if category == "":
		return {}
	var missions: Array = _definitions.get(category, [])
	for m in missions:
		if m.get("id", "") == mission_id:
			return m
	return {}


# ==========================================
# バッジ用
# ==========================================

func get_unclaimed_count() -> int:
	var count := 0
	for category in ["daily", "weekly", "permanent"]:
		var missions := get_missions(category)
		for m in missions:
			if m["completed"] and not m["claimed"]:
				count += 1
	return count
