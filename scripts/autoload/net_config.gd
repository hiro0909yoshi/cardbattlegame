extends Node

# ネット対戦のサーバー接続設定
# user://net_config.json に保存、未存在ならDEFAULTを使用

const CONFIG_PATH: String = "user://net_config.json"
const DEFAULT_HOST: String = "192.168.3.12"
const DEFAULT_PORT: int = 8080

var server_host: String = DEFAULT_HOST
var server_port: int = DEFAULT_PORT


func _ready() -> void:
	load_config()


func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return
	var data: Dictionary = json.data
	server_host = str(data.get("server_host", DEFAULT_HOST))
	server_port = int(data.get("server_port", DEFAULT_PORT))


func save_config() -> void:
	var data: Dictionary = {
		"server_host": server_host,
		"server_port": server_port,
	}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func set_server(host: String, port: int) -> void:
	server_host = host
	server_port = port
	save_config()


func get_api_url() -> String:
	return "http://%s:%d" % [server_host, server_port]


func reset_to_default() -> void:
	server_host = DEFAULT_HOST
	server_port = DEFAULT_PORT
	save_config()
