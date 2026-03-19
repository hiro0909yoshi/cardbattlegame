extends Node

## ゲーム全体のログ記録システム
## ファイル書き込み + コンソール出力を担当
## 設計: docs/design/logger_system.md

enum LogLevel {
	INFO,
	WARN,
	ERROR
}

const _MAX_LOG_FILES: int = 10
const _LOG_DIR: String = "user://logs/"
var _LEVEL_LABELS: Array[String] = ["INFO", "WARN", "ERROR"]

var _log_file: FileAccess = null
var _session_file_path: String = ""


func _ready() -> void:
	_ensure_log_directory()
	_cleanup_old_logs()
	_open_new_log_file()
	_check_previous_session()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		info("Game", "アプリケーション終了")
		_close_log_file()
	elif what == NOTIFICATION_CRASH:
		error("Game", "クラッシュ検出")
		_close_log_file()


## 基本ログAPI

func info(tag: String, message: String) -> void:
	_write_log(LogLevel.INFO, tag, message)


func warn(tag: String, message: String) -> void:
	_write_log(LogLevel.WARN, tag, message)


func error(tag: String, message: String) -> void:
	_write_log(LogLevel.ERROR, tag, message)


## 内部処理

func _write_log(level: LogLevel, tag: String, message: String) -> void:
	var timestamp := _get_timestamp()
	var level_str := _LEVEL_LABELS[level]
	var line := "[%s] [%-5s] [%-10s] %s" % [timestamp, level_str, tag, message]

	# コンソール出力（レベル別: ERROR/WARN は Godot Errors タブにも表示）
	match level:
		LogLevel.ERROR:
			push_error(line)
		LogLevel.WARN:
			push_warning(line)
		_:
			print(line)

	# ファイル出力
	if _log_file:
		_log_file.store_line(line)
		_log_file.flush()


func _get_timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	var msec := Time.get_ticks_msec() % 1000
	return "%02d:%02d:%02d.%03d" % [time["hour"], time["minute"], time["second"], msec]


func _get_date_time_string() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]


## ファイル管理

func _ensure_log_directory() -> void:
	if not DirAccess.dir_exists_absolute(_LOG_DIR):
		DirAccess.make_dir_recursive_absolute(_LOG_DIR)


func _open_new_log_file() -> void:
	var filename := "game_%s.log" % _get_date_time_string()
	_session_file_path = _LOG_DIR + filename
	_log_file = FileAccess.open(_session_file_path, FileAccess.WRITE)
	if not _log_file:
		push_error("[Logger] ログファイルを開けません: %s" % _session_file_path)


func _close_log_file() -> void:
	if _log_file:
		_log_file.flush()
		_log_file = null


func _cleanup_old_logs() -> void:
	var dir := DirAccess.open(_LOG_DIR)
	if not dir:
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".log"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if files.size() <= _MAX_LOG_FILES:
		return

	files.sort()
	var to_delete := files.size() - _MAX_LOG_FILES
	for i in range(to_delete):
		dir.remove(_LOG_DIR + files[i])


## クラッシュ検知

func _check_previous_session() -> void:
	var prev_log := _get_latest_existing_log()
	if prev_log == "":
		return

	var last_line := _read_last_line(prev_log)
	if last_line == "":
		return

	if "ゲーム終了" not in last_line and "アプリケーション終了" not in last_line:
		warn("Game", "前回セッションが異常終了した可能性: %s" % prev_log.get_file())


func _get_latest_existing_log() -> String:
	var dir := DirAccess.open(_LOG_DIR)
	if not dir:
		return ""

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".log"):
			var full_path := _LOG_DIR + file_name
			if full_path != _session_file_path:
				files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	if files.is_empty():
		return ""

	files.sort()
	return files[-1]


func _read_last_line(file_path: String) -> String:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ""

	var content := file.get_as_text()
	file = null

	var lines := content.strip_edges().split("\n")
	if lines.is_empty():
		return ""

	return lines[-1]
