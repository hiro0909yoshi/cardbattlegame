class_name ObjectPool
extends RefCounted

## 汎用オブジェクトプール実装
## メモリ割り当て/解放の頻度を削減し、GC圧力を軽減

# プール内のオブジェクト
var _available_objects: Array = []  # 利用可能なオブジェクト
var _in_use_objects: Array = []     # 使用中のオブジェクト
var _object_class: Script           # インスタンス化するクラス
var _max_pool_size: int = 0         # プールの最大サイズ


## ObjectPool を初期化
## object_class: インスタンス化するクラス
## initial_size: プールの初期サイズ
func _init(object_class: Script, initial_size: int = 3) -> void:
	_object_class = object_class
	_max_pool_size = initial_size

	# 初期オブジェクトを生成
	for i in range(initial_size):
		var obj = _create_instance()
		if obj:
			_available_objects.append(obj)


## プール内のオブジェクトを新規作成
func _create_instance():
	if not _object_class:
		push_error("[ObjectPool] object_class が設定されていません")
		return null

	var instance = _object_class.new()
	return instance


## プールからオブジェクトを取得
func get_instance():
	var obj = null

	if _available_objects.size() > 0:
		# 利用可能なオブジェクトから取得
		obj = _available_objects.pop_front()
	else:
		# プール枯渇時は動的に生成
		obj = _create_instance()
		if obj:
			push_warning("[ObjectPool] プール枯渇。新規作成しました (current size: %d)" % _in_use_objects.size())

	if obj:
		_in_use_objects.append(obj)

	return obj


## オブジェクトをプールに返却
func return_instance(obj) -> void:
	if not obj:
		push_error("[ObjectPool] null のオブジェクトは返却できません")
		return

	# 使用中リストから削除
	var index = _in_use_objects.find(obj)
	if index == -1:
		push_warning("[ObjectPool] このオブジェクトはプール内にありません")
		return

	_in_use_objects.remove_at(index)

	# reset() メソッドがあれば呼び出し
	if obj.has_method("reset"):
		obj.reset()

	# 利用可能リストに戻す
	_available_objects.append(obj)


## プール統計情報を取得（デバッグ用）
func get_stats() -> Dictionary:
	return {
		"available": _available_objects.size(),
		"in_use": _in_use_objects.size(),
		"max_size": _max_pool_size,
		"total": _available_objects.size() + _in_use_objects.size()
	}


## プールをクリア（全オブジェクトを破棄）
func clear() -> void:
	for obj in _available_objects:
		if obj:
			obj.queue_free()

	for obj in _in_use_objects:
		if obj:
			obj.queue_free()

	_available_objects.clear()
	_in_use_objects.clear()
