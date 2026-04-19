extends Node

class_name WsClient

signal connected()
signal disconnected()
signal message_received(msg_type: String, data: Variant)

var _ws: WebSocketPeer = null
var _url: String = ""
var _is_connected: bool = false


func connect_to_server(host: String, port: int, token: String) -> void:
	_ws = WebSocketPeer.new()
	_url = "ws://%s:%d/ws?token=%s" % [host, port, token]
	_ws.connect_to_url(_url)


func disconnect_from_server() -> void:
	if _ws:
		_ws.close()


func send_msg(msg_type: String, data: Variant = null) -> void:
	if not _ws or not _is_connected or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	var msg: Dictionary = {"type": msg_type}
	if data != null:
		msg["data"] = data

	var json_str: String = JSON.stringify(msg)
	_ws.send_text(json_str)


func is_connected_to_server() -> bool:
	return _is_connected


func _process(_delta: float) -> void:
	if not _ws:
		return

	_ws.poll()

	var ready_state: int = _ws.get_ready_state()

	if ready_state == WebSocketPeer.STATE_OPEN:
		if not _is_connected:
			_is_connected = true
			connected.emit()
	elif ready_state == WebSocketPeer.STATE_CLOSED or ready_state == WebSocketPeer.STATE_CLOSING:
		if _is_connected:
			_is_connected = false
			disconnected.emit()

	while _ws.get_available_packet_count() > 0:
		var packet: PackedByteArray = _ws.get_packet()
		var json_str: String = packet.get_string_from_utf8()

		var json: JSON = JSON.new()
		var error: Error = json.parse(json_str)

		if error == OK:
			var msg_dict: Dictionary = json.data as Dictionary
			var msg_type: String = msg_dict.get("type", "")
			var msg_data: Variant = msg_dict.get("data", null)
			message_received.emit(msg_type, msg_data)
