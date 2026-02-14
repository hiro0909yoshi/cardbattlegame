extends Node
class_name CreatureManager
## クリーチャー管理システム（参照方式）
## タイルから独立してクリーチャーデータを一元管理
## tile.creature_dataへのアクセスを透過的にリダイレクト

# シグナル: クリーチャーデータが変更された時に emit
signal creature_changed(tile_index: int, old_data: Dictionary, new_data: Dictionary)

# すべてのクリーチャーデータを一元管理
var creatures: Dictionary = {}  # {tile_index: creature_data辞書}

# 3D表示ノードの管理（オプション）
var visual_nodes: Dictionary = {}  # {tile_index: Node3D}

# BoardSystemへの参照
var board_system: Node = null

# テストモード（整合性チェックを有効化）
# NOTE: debug_modeはDebugSettings.creature_manager_debugに移行済み

func _ready():
	print("[CreatureManager] 初期化完了（参照方式）")

## BoardSystemを設定
func set_board_system(p_board_system: Node):
	board_system = p_board_system
	print("[CreatureManager] BoardSystem参照を設定")

## データへの参照を返す（重要: コピーではなく参照！）
## @param tile_index: タイルのインデックス
## @return: creature_data辞書への参照
func get_data_ref(tile_index: int) -> Dictionary:
	if not creatures.has(tile_index):
		creatures[tile_index] = {}
	
	# 空辞書の自動クリーンアップ
	var data = creatures[tile_index]
	if data.is_empty() and creatures.has(tile_index):
		creatures.erase(tile_index)
		return {}
	
	return data

## クリーチャーデータを設定（シグナル emit 付き）
## @param tile_index: タイルのインデックス
## @param data: 設定するクリーチャーデータ
func set_creature(tile_index: int, data: Dictionary) -> void:
	# ステップ1: 変更前のデータを保存
	var old_data = creatures.get(tile_index, {})

	# ステップ2: データ設定
	if data.is_empty():
		# 空の辞書 = 削除
		creatures.erase(tile_index)
	else:
		# 常に duplicate(true) を使用（外部からの変更を防ぐ）
		creatures[tile_index] = data.duplicate(true)

	# ステップ3: 変更後のデータを取得
	var new_data = creatures.get(tile_index, {})

	# ステップ4: 変更がない場合はシグナルを emit しない（無駄なシグナルを防ぐ）
	if old_data.is_empty() and new_data.is_empty():
		if DebugSettings.creature_manager_debug:
			print("[CreatureManager] 変更なし（空→空）: tile=%d, シグナル emit スキップ" % tile_index)
		return

	if DebugSettings.creature_manager_debug:
		print("[CreatureManager] emit 直前: tile=%d, old=%s, new=%s" % [
			tile_index,
			"empty" if old_data.is_empty() else "exists",
			"empty" if new_data.is_empty() else "exists"
		])

	# ステップ5: シグナルを emit
	creature_changed.emit(tile_index, old_data, new_data)

	if DebugSettings.creature_manager_debug:
		print("[CreatureManager] emit 完了: tile=%d" % tile_index)

## 後方互換性ラッパー
## @param tile_index: タイルのインデックス
## @param data: 設定するクリーチャーデータ
func set_data(tile_index: int, data: Dictionary):
	set_creature(tile_index, data)

## クリーチャーが存在するか確認
## @param tile_index: タイルのインデックス
## @return: 存在するかどうか
func has_creature(tile_index: int) -> bool:
	return creatures.has(tile_index) and not creatures[tile_index].is_empty()

## データをクリア（削除）
## @param tile_index: タイルのインデックス
func clear_data(tile_index: int):
	_remove_creature_internal(tile_index)

## 内部削除処理（3D表示も削除）
func _remove_creature_internal(tile_index: int):
	if creatures.has(tile_index):
		if DebugSettings.creature_manager_debug:
			var creature_name = creatures[tile_index].get("name", "???")
			print("[CreatureManager] データ削除: tile=", tile_index, " name=", creature_name)
		creatures.erase(tile_index)
	
	if visual_nodes.has(tile_index):
		var node = visual_nodes[tile_index]
		if node:
			node.queue_free()
		visual_nodes.erase(tile_index)

## 3D表示ノードを設定
## @param tile_index: タイルのインデックス
## @param node: 3D表示ノード
func set_visual_node(tile_index: int, node: Node3D):
	visual_nodes[tile_index] = node
	if DebugSettings.creature_manager_debug:
		print("[CreatureManager] 3D表示設定: tile=", tile_index)

## 3D表示ノードを取得
## @param tile_index: タイルのインデックス
## @return: 3D表示ノード（存在しない場合はnull）
func get_visual_node(tile_index: int) -> Node3D:
	return visual_nodes.get(tile_index, null)

## すべてのクリーチャーをクリア
func clear_all():
	# 3D表示を削除
	for node in visual_nodes.values():
		if node:
			node.queue_free()
	
	creatures.clear()
	visual_nodes.clear()
	print("[CreatureManager] すべてのクリーチャーをクリア")

## デバッグ: 現在の状態を出力
func debug_print():
	print("\n[CreatureManager] === 状態ダンプ ===")
	print("  管理中のクリーチャー数: ", creatures.size())
	
	if creatures.is_empty():
		print("  （クリーチャーなし）")
	else:
		for tile_index in creatures.keys():
			var data = creatures[tile_index]
			if not data.is_empty():
				var has_visual = visual_nodes.has(tile_index) and visual_nodes[tile_index] != null
				var owner_id = "???"
				if board_system:
					var tile_info = board_system.get_tile_info(tile_index)
					owner_id = "P" + str(tile_info.get("owner", "?"))
				
				print("  [%d] %s (HP:%d/%d, 属性:%s, 所有:%s, 3D:%s)" % [
					tile_index,
					data.get("name", "???"),
					data.get("hp", 0),
					data.get("max_hp", 0),
					data.get("element", "?"),
					owner_id,
					"○" if has_visual else "×"
				])
	print("=============================\n")

## デバッグモードの切り替え
func set_debug_mode(enabled: bool):
	DebugSettings.creature_manager_debug = enabled
	print("[CreatureManager] デバッグモード: ", "ON" if enabled else "OFF")

## 整合性チェック（テスト用）
## @return: 問題がなければtrue
func validate_integrity() -> bool:
	var valid = true
	
	# 空辞書のチェック
	for tile_index in creatures.keys():
		if creatures[tile_index].is_empty():
			print("[WARNING] 空の辞書が残っている: tile ", tile_index)
			valid = false
	
	# 孤立した3D表示のチェック
	for tile_index in visual_nodes.keys():
		if not creatures.has(tile_index):
			print("[WARNING] データのない3D表示が存在: tile ", tile_index)
			valid = false
	
	if valid:
		print("[CreatureManager] 整合性チェック: OK")
	else:
		print("[CreatureManager] 整合性チェック: NG")
	
	return valid

## ========================================
## 拡張機能（検索・集計）
## ========================================

## 特定プレイヤーのクリーチャーを検索
## @param player_id: プレイヤーID
## @return: [{tile_index: int, data: Dictionary}, ...]
func find_by_player(player_id: int) -> Array:
	var result = []
	if not board_system:
		return result
	
	for tile_index in creatures.keys():
		var tile_info = board_system.get_tile_info(tile_index)
		if tile_info.get("owner") == player_id:
			result.append({
				"tile_index": tile_index,
				"data": creatures[tile_index]
			})
	return result

## 特定属性のクリーチャーを検索
## @param element: 属性名（"fire", "water", "wind", "earth", "neutral"）
## @return: [{tile_index: int, data: Dictionary}, ...]
func find_by_element(element: String) -> Array:
	var result = []
	for tile_index in creatures.keys():
		if creatures[tile_index].get("element") == element:
			result.append({
				"tile_index": tile_index,
				"data": creatures[tile_index]
			})
	return result

## すべてのクリーチャー情報を取得
## @return: [{tile_index: int, data: Dictionary}, ...]
func get_all_creatures() -> Array:
	var result = []
	for tile_index in creatures.keys():
		result.append({
			"tile_index": tile_index,
			"data": creatures[tile_index]
		})
	return result

## クリーチャー数を取得
## @return: クリーチャーの総数
func get_creature_count() -> int:
	return creatures.size()

## プレイヤーのクリーチャー数を取得
## @param player_id: プレイヤーID
## @return: そのプレイヤーのクリーチャー数
func get_player_creature_count(player_id: int) -> int:
	return find_by_player(player_id).size()

## すべての3D表示を更新
func update_all_visuals():
	for tile_index in creatures.keys():
		if visual_nodes.has(tile_index) and visual_nodes[tile_index]:
			var node = visual_nodes[tile_index]
			if node.has_method("update_creature_data"):
				node.update_creature_data(creatures[tile_index])

## ========================================
## セーブ/ロード用（将来の実装用）
## ========================================

## セーブ用データを取得
## @return: セーブ可能な辞書形式
func get_save_data() -> Dictionary:
	var save_data = {}
	for tile_index in creatures.keys():
		save_data[str(tile_index)] = creatures[tile_index].duplicate(true)
	return save_data

## セーブデータから復元
## @param save_data: セーブデータ
func load_from_save_data(save_data: Dictionary):
	clear_all()
	for key in save_data.keys():
		var tile_index = int(key)
		creatures[tile_index] = save_data[key].duplicate(true)
	print("[CreatureManager] セーブデータから復元: ", creatures.size(), "体")
