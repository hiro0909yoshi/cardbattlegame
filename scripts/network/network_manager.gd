extends Node
class_name NetworkManager

## ネットワーク対戦管理クラス
## WebSocketを使用したシンプルなP2P通信

signal connected()
signal disconnected()
signal connection_failed()
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal game_action_received(action: Dictionary)

enum Mode { NONE, HOST, CLIENT }
enum State { DISCONNECTED, CONNECTING, CONNECTED }

var current_mode: Mode = Mode.NONE
var current_state: State = State.DISCONNECTED

# WebSocket関連
var tcp_server: TCPServer = null
var websocket_peers: Dictionary = {}  # peer_id -> WebSocketPeer
var client_websocket: WebSocketPeer = null

# 設定
const DEFAULT_PORT = 9080
var server_port: int = DEFAULT_PORT
var server_ip: String = "127.0.0.1"

# 自分のプレイヤーID（ホスト=0, クライアント=1）
var local_player_id: int = -1

func _ready():
	pass

func _process(_delta):
	if current_mode == Mode.HOST:
		_process_host()
	elif current_mode == Mode.CLIENT:
		_process_client()

# === ホスト（サーバー）処理 ===

## ホストとしてサーバーを起動
func start_host(port: int = DEFAULT_PORT) -> bool:
	if current_state != State.DISCONNECTED:
		push_warning("[Network] Already connected")
		return false
	
	server_port = port
	tcp_server = TCPServer.new()
	
	var err = tcp_server.listen(port)
	if err != OK:
		push_error("[Network] Failed to start server on port %d: %s" % [port, error_string(err)])
		return false
	
	current_mode = Mode.HOST
	current_state = State.CONNECTED
	local_player_id = 0
	
	print("[Network] Host started on port %d" % port)
	print("[Network] Your IP addresses:")
	_print_local_ips()
	
	connected.emit()
	return true

## ローカルIPアドレスを表示
func _print_local_ips():
	for ip in IP.get_local_addresses():
		# IPv4のみ表示（192.168.x.x など）
		if ip.count(".") == 3 and not ip.begins_with("127."):
			print("  - %s:%d" % [ip, server_port])

## ホスト側の更新処理
func _process_host():
	# 新規接続をチェック
	if tcp_server and tcp_server.is_connection_available():
		var tcp_peer = tcp_server.take_connection()
		if tcp_peer:
			_accept_new_peer(tcp_peer)
	
	# 既存のピアを処理
	var peers_to_remove = []
	for peer_id in websocket_peers:
		var ws: WebSocketPeer = websocket_peers[peer_id]
		ws.poll()
		
		var state = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var packet = ws.get_packet()
				_handle_packet(peer_id, packet)
		elif state == WebSocketPeer.STATE_CLOSED:
			peers_to_remove.append(peer_id)
	
	# 切断したピアを削除
	for peer_id in peers_to_remove:
		websocket_peers.erase(peer_id)
		print("[Network] Peer %d disconnected" % peer_id)
		peer_disconnected.emit(peer_id)

## 新規接続を受け入れ
func _accept_new_peer(tcp_peer: StreamPeerTCP):
	var ws = WebSocketPeer.new()
	ws.accept_stream(tcp_peer)
	
	var peer_id = tcp_peer.get_instance_id()
	websocket_peers[peer_id] = ws
	
	print("[Network] New peer connecting: %d" % peer_id)
	
	# 接続完了を待つ（非同期で処理される）
	_wait_for_websocket_handshake(peer_id, ws)

## WebSocketハンドシェイク完了を待つ
func _wait_for_websocket_handshake(peer_id: int, ws: WebSocketPeer):
	# 次フレームで状態をチェック
	await get_tree().process_frame
	
	for i in range(100):  # 最大100フレーム待機
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			print("[Network] Peer %d connected" % peer_id)
			peer_connected.emit(peer_id)
			
			# プレイヤーID割り当てを送信
			send_to_peer(peer_id, {
				"type": "assign_player_id",
				"player_id": 1  # クライアントはプレイヤー1
			})
			return
		elif ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			websocket_peers.erase(peer_id)
			return
		
		await get_tree().process_frame

# === クライアント処理 ===

## クライアントとしてサーバーに接続
func start_client(ip: String, port: int = DEFAULT_PORT) -> bool:
	if current_state != State.DISCONNECTED:
		push_warning("[Network] Already connected")
		return false
	
	server_ip = ip
	server_port = port
	
	client_websocket = WebSocketPeer.new()
	var url = "ws://%s:%d" % [ip, port]
	
	var err = client_websocket.connect_to_url(url)
	if err != OK:
		push_error("[Network] Failed to connect to %s: %s" % [url, error_string(err)])
		return false
	
	current_mode = Mode.CLIENT
	current_state = State.CONNECTING
	
	print("[Network] Connecting to %s..." % url)
	return true

## クライアント側の更新処理
func _process_client():
	if not client_websocket:
		return
	
	client_websocket.poll()
	var state = client_websocket.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_CONNECTING:
			pass  # 接続中
		
		WebSocketPeer.STATE_OPEN:
			if current_state == State.CONNECTING:
				current_state = State.CONNECTED
				print("[Network] Connected to server")
				connected.emit()
			
			# パケット受信
			while client_websocket.get_available_packet_count() > 0:
				var packet = client_websocket.get_packet()
				_handle_packet(0, packet)  # サーバーからのパケット
		
		WebSocketPeer.STATE_CLOSED:
			if current_state == State.CONNECTING:
				print("[Network] Connection failed")
				connection_failed.emit()
			else:
				print("[Network] Disconnected from server")
				disconnected.emit()
			
			current_state = State.DISCONNECTED
			current_mode = Mode.NONE
			client_websocket = null

# === メッセージ処理 ===

## パケットを処理
func _handle_packet(from_peer_id: int, packet: PackedByteArray):
	var json_string = packet.get_string_from_utf8()
	var json = JSON.new()
	var err = json.parse(json_string)
	
	if err != OK:
		push_warning("[Network] Invalid JSON received")
		return
	
	var data = json.get_data()
	if not data is Dictionary:
		return
	
	print("[Network] Received from %d: %s" % [from_peer_id, data.get("type", "unknown")])
	
	# 特殊メッセージの処理
	match data.get("type"):
		"assign_player_id":
			local_player_id = data.get("player_id", 1)
			print("[Network] Assigned player ID: %d" % local_player_id)
		"game_action":
			game_action_received.emit(data)
		_:
			game_action_received.emit(data)

## 全員にメッセージを送信（ホスト用）
func broadcast(data: Dictionary):
	if current_mode != Mode.HOST:
		return
	
	var json_string = JSON.stringify(data)
	var packet = json_string.to_utf8_buffer()
	
	for peer_id in websocket_peers:
		var ws: WebSocketPeer = websocket_peers[peer_id]
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send(packet)

## 特定のピアにメッセージを送信（ホスト用）
func send_to_peer(peer_id: int, data: Dictionary):
	if current_mode != Mode.HOST:
		return
	
	if not websocket_peers.has(peer_id):
		return
	
	var ws: WebSocketPeer = websocket_peers[peer_id]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		ws.send(json_string.to_utf8_buffer())

## サーバーにメッセージを送信（クライアント用）
func send_to_server(data: Dictionary):
	if current_mode != Mode.CLIENT or not client_websocket:
		return
	
	if client_websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		client_websocket.send(json_string.to_utf8_buffer())

## 相手にゲームアクションを送信
func send_game_action(action_type: String, action_data: Dictionary = {}):
	var message = {
		"type": "game_action",
		"action": action_type,
		"player_id": local_player_id,
		"data": action_data
	}
	
	if current_mode == Mode.HOST:
		broadcast(message)
	elif current_mode == Mode.CLIENT:
		send_to_server(message)

# === 接続管理 ===

## 切断
func disconnect_network():
	if current_mode == Mode.HOST:
		# 全ピアを切断
		for peer_id in websocket_peers:
			var ws: WebSocketPeer = websocket_peers[peer_id]
			ws.close()
		websocket_peers.clear()
		
		if tcp_server:
			tcp_server.stop()
			tcp_server = null
	
	elif current_mode == Mode.CLIENT:
		if client_websocket:
			client_websocket.close()
			client_websocket = null
	
	current_mode = Mode.NONE
	current_state = State.DISCONNECTED
	local_player_id = -1
	
	print("[Network] Disconnected")
	disconnected.emit()

## 接続中かどうか
func is_connected_to_network() -> bool:
	return current_state == State.CONNECTED

## ホストかどうか
func is_host() -> bool:
	return current_mode == Mode.HOST

## 接続しているピア数を取得（ホスト用）
func get_peer_count() -> int:
	return websocket_peers.size()
