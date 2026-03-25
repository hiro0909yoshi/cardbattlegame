## 汎用アンロックシステム
## キー方式 + イベント駆動で全解放要素を統一管理する
extends Node

signal unlocked(keys: Array[String], notification: String)

const _CONDITIONS_PATH = "res://data/master/unlock_conditions.json"

var _conditions: Array = []
## type別のインデックス（イベント駆動用）
var _conditions_by_type: Dictionary = {}


func _ready():
	_load_conditions()
	_build_index()
	# 起動時に全条件をチェック（既存セーブデータとの整合性確保）
	_sync_all_conditions()


## 起動時に全条件を一括チェックし、未解放のものを解放する
func _sync_all_conditions():
	for condition in _conditions:
		if _all_keys_unlocked(condition.unlock):
			continue
		if _evaluate(condition):
			var new_keys = _unlock_keys(condition.unlock)
			if not new_keys.is_empty():
				print("[Unlock] Sync: %s unlocked (condition: %s)" % [", ".join(new_keys), condition.id])


# ==============================================
# 判定API
# ==============================================

## キーが解放済みか
func is_unlocked(key: String) -> bool:
	return key in _get_keys()


## プレフィックスに一致する解放済みキー一覧
func get_unlocked_by_prefix(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for key in _get_keys():
		if key.begins_with(prefix):
			result.append(key)
	return result


## 指定キーを解放する条件を返す（ロック理由表示用）
func get_condition_for_key(key: String) -> Dictionary:
	for condition in _conditions:
		if key in condition.unlock:
			return condition
	return {}


## 指定typeの条件一覧を返す（ショップ表示用）
func get_conditions_by_type(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in _conditions_by_type.get(type, []):
		result.append(c)
	return result


# ==============================================
# イベントハンドラー
# ==============================================

## ステージクリア時
func on_stage_cleared(stage_id: String) -> Array[Dictionary]:
	return _process_conditions_by_type("stage_clear", "stage_id", stage_id)


## バトル終了時（勝敗問わず）
func on_battle_finished() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(_process_conditions_by_type("battle_count"))
	result.append_array(_process_conditions_by_type("win_count"))
	return result


## カード入手時
func on_card_obtained() -> Array[Dictionary]:
	return _process_conditions_by_type("card_count")


## ショップ購入時
func on_purchased(item_id: String) -> Array[Dictionary]:
	return _process_conditions_by_type("purchase", "item_id", item_id)


# ==============================================
# 内部処理
# ==============================================

## 指定typeの条件をチェックし、達成済みのキーを解放
func _process_conditions_by_type(type: String, filter_key: String = "", filter_value: String = "") -> Array[Dictionary]:
	var newly_unlocked: Array[Dictionary] = []
	var conditions = _conditions_by_type.get(type, [])

	for condition in conditions:
		# 既に全キーが解放済みならスキップ
		if _all_keys_unlocked(condition.unlock):
			continue
		# フィルター条件がある場合、一致するものだけ処理
		if filter_key != "" and str(condition.requirement.get(filter_key, "")) != filter_value:
			continue
		# 条件達成チェック
		if _evaluate(condition):
			var new_keys = _unlock_keys(condition.unlock)
			if not new_keys.is_empty():
				newly_unlocked.append({
					"id": condition.id,
					"keys": new_keys,
					"notification": condition.get("notification", "")
				})
				print("[Unlock] %s unlocked (condition: %s)" % [", ".join(new_keys), condition.id])
				unlocked.emit(new_keys, condition.get("notification", ""))
	return newly_unlocked


## 条件達成判定
func _evaluate(condition: Dictionary) -> bool:
	var req = condition.requirement
	match condition.type:
		"always":
			return true
		"stage_clear":
			return StageRecordManager.is_cleared(req.stage_id)
		"battle_count":
			return GameData.player_data.stats.total_battles >= req.count
		"win_count":
			return GameData.player_data.stats.wins >= req.count
		"card_count":
			return UserCardDB.get_all_obtained_cards().size() >= req.count
		"purchase":
			return true  # 購入成功時に呼ばれるので常にtrue
		_:
			push_warning("[Unlock] Unknown condition type: %s" % condition.type)
			return false


## キーを解放してセーブ
func _unlock_keys(keys: Array) -> Array[String]:
	var new_keys: Array[String] = []
	var unlock_keys = _get_keys()
	for key in keys:
		if key not in unlock_keys:
			unlock_keys.append(key)
			new_keys.append(key)
	if not new_keys.is_empty():
		GameData.save_to_file()
	return new_keys


## 指定キーが全て解放済みか
func _all_keys_unlocked(keys: Array) -> bool:
	var unlock_keys = _get_keys()
	for key in keys:
		if key not in unlock_keys:
			return false
	return true


## unlocks.keys への参照を返す
func _get_keys() -> Array:
	return GameData.player_data.unlocks.keys


## マスターデータ読み込み
func _load_conditions():
	var file = FileAccess.open(_CONDITIONS_PATH, FileAccess.READ)
	if not file:
		push_error("[Unlock] Failed to load: %s" % _CONDITIONS_PATH)
		return
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[Unlock] JSON parse error: %s" % json.get_error_message())
		return

	var data = json.get_data()
	_conditions = data.get("conditions", [])
	print("[Unlock] Loaded %d conditions" % _conditions.size())


## type別インデックス構築
func _build_index():
	_conditions_by_type.clear()
	for condition in _conditions:
		var condition_type = condition.type
		if not _conditions_by_type.has(condition_type):
			_conditions_by_type[condition_type] = []
		_conditions_by_type[condition_type].append(condition)
