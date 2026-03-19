extends Node
class_name SignalRegistry

# 汎用シグナル管理システム
# シグナルの重複接続を防ぎ、デバッグを容易にする

# シングルトンインスタンス
static var instance: SignalRegistry = null

# 接続情報を保存
var connections: Dictionary = {}  # key: String -> connection_data: Dictionary
var connection_count: Dictionary = {}  # signal_name -> count

# デバッグモード
# NOTE: debug_modeはDebugSettings.signal_registry_debugに移行済み

func _ready():
	# シングルトン設定
	if instance == null:
		instance = self
	else:
		queue_free()

# 安全なシグナル接続
static func connect_safe(
	from_object: Object, 
	signal_name: String, 
	to_object: Object, 
	method_name: String,
	flags: int = 0,
	unique_id: String = ""
) -> bool:
	
	if not instance:
		GameLogger.error("System", "SignalRegistry is not initialized（connect_safe）")
		return false
	
	# ユニークキーを生成
	var key = _generate_key(from_object, signal_name, to_object, method_name, unique_id)
	
	# 既に接続されているかチェック
	if instance.connections.has(key):
		if DebugSettings.signal_registry_debug:
			print("⚠️ 既に接続済み: ", key)
		return false
	
	# シグナルを接続
	var callable = Callable(to_object, method_name)
	from_object.connect(signal_name, callable, flags)
	
	# 接続情報を記録
	instance.connections[key] = {
		"from": from_object.get_path() if from_object.is_inside_tree() else str(from_object),
		"signal": signal_name,
		"to": to_object.get_path() if to_object.is_inside_tree() else str(to_object),
		"method": method_name,
		"time": Time.get_ticks_msec(),
		"flags": flags
	}
	
	# カウント更新
	var count_key = signal_name
	if not instance.connection_count.has(count_key):
		instance.connection_count[count_key] = 0
	instance.connection_count[count_key] += 1
	
	if DebugSettings.signal_registry_debug:
		print("✅ シグナル接続: ", signal_name, " [", instance.connection_count[count_key], "個目]")
	
	return true

# 安全なシグナル切断
static func disconnect_safe(
	from_object: Object,
	signal_name: String,
	to_object: Object,
	method_name: String,
	unique_id: String = ""
) -> bool:
	
	if not instance:
		return false
	
	var key = _generate_key(from_object, signal_name, to_object, method_name, unique_id)
	
	if not instance.connections.has(key):
		if DebugSettings.signal_registry_debug:
			print("⚠️ 接続が見つかりません: ", key)
		return false
	
	# シグナルを切断
	var callable = Callable(to_object, method_name)
	if from_object.is_connected(signal_name, callable):
		from_object.disconnect(signal_name, callable)
	
	# 記録を削除
	instance.connections.erase(key)
	
	# カウント更新
	if instance.connection_count.has(signal_name):
		instance.connection_count[signal_name] -= 1
	
	if DebugSettings.signal_registry_debug:
		print("🔌 シグナル切断: ", signal_name)
	
	return true

# 一度だけ接続（CONNECT_ONE_SHOT相当）
static func connect_oneshot(
	from_object: Object,
	signal_name: String,
	to_object: Object,
	method_name: String,
	unique_id: String = ""
) -> bool:
	
	# まず既存の接続を切断
	disconnect_safe(from_object, signal_name, to_object, method_name, unique_id)
	
	# CONNECT_ONE_SHOT付きで接続
	return connect_safe(
		from_object, 
		signal_name, 
		to_object, 
		method_name,
		CONNECT_ONE_SHOT,
		unique_id
	)

# オブジェクトの全接続をクリア
static func clear_object_connections(object: Object):
	if not instance:
		return
	
	var to_remove = []
	for key in instance.connections:
		var data = instance.connections[key]
		if data["from"] == object.get_path() or data["to"] == object.get_path():
			to_remove.append(key)
	
	for key in to_remove:
		instance.connections.erase(key)
	
	if DebugSettings.signal_registry_debug and to_remove.size() > 0:
		print("🧹 " + str(to_remove.size()) + "個の接続をクリア")

	# デバッグ：接続状態を表示
static func debug_print_connections():
	if not instance:
		print("SignalRegistry not initialized")
		return
	
	print("")
	print("==================================================")
	print("📡 シグナル接続状態")
	print("==================================================")
	
	# シグナル別にグループ化
	var grouped = {}
	for key in instance.connections:
		var data = instance.connections[key]
		var signal_name = data["signal"]
		if not grouped.has(signal_name):
			grouped[signal_name] = []
		grouped[signal_name].append(data)
	
	# 表示
	for signal_name in grouped:
		print("")
		print("[" + signal_name + "] (" + str(grouped[signal_name].size()) + "個)")
		for data in grouped[signal_name]:
			print("  " + str(data["from"]) + " → " + str(data["to"]) + "::" + data["method"])
	
	print("")
	print("==================================================")
	print("")

# 統計情報を取得
static func get_stats() -> Dictionary:
	if not instance:
		return {}
	
	return {
		"total_connections": instance.connections.size(),
		"by_signal": instance.connection_count
	}

# プライベート：ユニークキー生成
static func _generate_key(from: Object, signal_name: String, to: Object, method: String, id: String) -> String:
	var from_id = from.get_instance_id()
	var to_id = to.get_instance_id()
	
	if id != "":
		return "%d_%s_%d_%s_%s" % [from_id, signal_name, to_id, method, id]
	else:
		return "%d_%s_%d_%s" % [from_id, signal_name, to_id, method]

# デバッグモード切替
static func set_debug_mode(enabled: bool):
	if instance:
		DebugSettings.signal_registry_debug = enabled
		print("📡 SignalRegistry: デバッグモード ", "ON" if enabled else "OFF")
