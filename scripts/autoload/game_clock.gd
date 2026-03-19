extends Node
class_name GameClockClass

## サーバー時刻管理
## 現在はローカル時計を使用。サーバー移行時はここだけ変更する。
##
## サーバー移行時の変更点:
##   1. _server_time_offset をサーバーから取得した差分で設定
##   2. sync_with_server() をログイン時に呼ぶ
##   3. get_now() が自動的にサーバー時刻を返すようになる

## サーバー時刻とローカル時刻の差分（秒）
## server_time = local_time + _server_time_offset
var _server_time_offset: int = 0

## サーバー同期済みフラグ
var _is_synced: bool = false


## 現在のUnix時刻を取得（サーバー同期済みならサーバー時刻）
func get_now() -> int:
	return int(Time.get_unix_time_from_system()) + _server_time_offset


## 現在の日付文字列を取得（YYYY-MM-DD）
func get_today() -> String:
	var unix = get_now()
	var dict = Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [dict.year, dict.month, dict.day]


## サーバー時刻と同期（サーバー移行時に実装）
## server_unix: サーバーから取得したUnix時刻
func sync_with_server(server_unix: int) -> void:
	var local_now = int(Time.get_unix_time_from_system())
	_server_time_offset = server_unix - local_now
	_is_synced = true
	print("[GameClock] サーバー同期完了 offset=%d秒" % _server_time_offset)


## サーバー同期済みかどうか
func is_synced() -> bool:
	return _is_synced
