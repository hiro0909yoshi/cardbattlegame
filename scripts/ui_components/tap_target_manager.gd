class_name TapTargetManager
extends Node

## タップによるターゲット選択を管理するシステム
## ドミニオオーダー、スペル、アルカナアーツなどで共通使用

# ========================================
# シグナル
# ========================================

## ターゲットが選択された時
signal target_selected(tile_index: int, creature_data: Dictionary)

## 選択がキャンセルされた時
signal selection_cancelled()

# ========================================
# 選択タイプ
# ========================================

enum SelectionType {
	NONE,           # 選択モードではない
	CREATURE,       # クリーチャー選択
	TILE,           # タイル選択（空タイル含む）
	PLAYER,         # プレイヤー選択
	CREATURE_OR_TILE  # クリーチャーまたはタイル
}

# ========================================
# 状態
# ========================================

## 選択モードがアクティブか
var is_active: bool = false

## 有効なターゲット（タイルインデックスの配列）
var valid_targets: Array = []

## 選択タイプ
var selection_type: SelectionType = SelectionType.NONE

## 選択元のシステム識別子（デバッグ用）
var source_system: String = ""

## 追加のフィルター条件（Callable）
var custom_filter: Callable = Callable()

## 選択時にインフォパネルを表示するか
var show_info_on_invalid: bool = true

# ========================================
# 外部参照
# ========================================

var board_system = null
var player_system = null
var current_player_id: int = 0

# ========================================
# 初期化
# ========================================

func setup(board_sys, player_sys):
	board_system = board_sys
	player_system = player_sys


func set_current_player(player_id: int):
	current_player_id = player_id

# ========================================
# 選択モード制御
# ========================================

## ターゲット選択を開始
func start_selection(
	targets: Array,
	type: SelectionType,
	source: String = "",
	filter: Callable = Callable()
) -> void:
	valid_targets = targets
	selection_type = type
	source_system = source
	custom_filter = filter
	is_active = true
	
	print("[TapTargetManager] 選択開始: %s (%d件) from %s" % [
		SelectionType.keys()[type],
		targets.size(),
		source
	])


## ターゲット選択を終了
func end_selection() -> void:
	if not is_active:
		return
	
	print("[TapTargetManager] 選択終了: %s" % source_system)
	
	valid_targets = []
	selection_type = SelectionType.NONE
	source_system = ""
	custom_filter = Callable()
	is_active = false


## 選択をキャンセル
func cancel_selection() -> void:
	if not is_active:
		return
	
	print("[TapTargetManager] 選択キャンセル: %s" % source_system)
	selection_cancelled.emit()
	end_selection()

# ========================================
# タップ処理
# ========================================

## タイルがタップされた時の処理
## 戻り値: true = ターゲットとして処理した, false = インフォパネル表示などに回す
func handle_tile_tap(tile_index: int, tile_data: Dictionary) -> bool:
	if not is_active:
		return false
	
	# 有効なターゲットかチェック
	if not _is_valid_target(tile_index, tile_data):
		print("[TapTargetManager] 無効なターゲット: タイル%d" % tile_index)
		return false  # インフォパネル表示に回す
	
	# カスタムフィルターがあれば適用
	if custom_filter.is_valid():
		if not custom_filter.call(tile_index, tile_data):
			print("[TapTargetManager] カスタムフィルターで除外: タイル%d" % tile_index)
			return false
	
	# ターゲットとして選択
	var creature_data = _get_creature_data(tile_index)
	print("[TapTargetManager] ターゲット選択: タイル%d" % tile_index)
	target_selected.emit(tile_index, creature_data)
	return true


## クリーチャーがタップされた時の処理
func handle_creature_tap(tile_index: int, creature_data: Dictionary) -> bool:
	if not is_active:
		return false
	
	# クリーチャー選択モードでない場合
	if selection_type != SelectionType.CREATURE and selection_type != SelectionType.CREATURE_OR_TILE:
		return false
	
	# 有効なターゲットかチェック
	if tile_index not in valid_targets:
		print("[TapTargetManager] 無効なクリーチャー: タイル%d" % tile_index)
		return false
	
	# カスタムフィルターがあれば適用
	if custom_filter.is_valid():
		var tile_data = _get_tile_data(tile_index)
		if not custom_filter.call(tile_index, tile_data):
			print("[TapTargetManager] カスタムフィルターで除外: タイル%d" % tile_index)
			return false
	
	# ターゲットとして選択
	print("[TapTargetManager] クリーチャー選択: タイル%d - %s" % [tile_index, creature_data.get("name", "不明")])
	target_selected.emit(tile_index, creature_data)
	return true


## 空タップ時の処理
## 戻り値: true = 処理した（何もしない）, false = 他の処理に回す
func handle_empty_tap() -> bool:
	if not is_active:
		return false
	
	# ターゲット選択中は空タップを無視（UIを閉じない）
	print("[TapTargetManager] 空タップ無視（選択モード中）")
	return true

# ========================================
# 内部ヘルパー
# ========================================

func _is_valid_target(tile_index: int, _tile_data: Dictionary) -> bool:
	# 基本チェック: 有効ターゲットリストに含まれているか
	if tile_index not in valid_targets:
		return false
	
	return true


func _get_creature_data(tile_index: int) -> Dictionary:
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return {}
	
	var tile = board_system.tile_nodes[tile_index]
	if "creature_data" in tile:
		return tile.creature_data
	return {}


func _get_tile_data(tile_index: int) -> Dictionary:
	if not board_system:
		return {}
	
	if board_system.has_method("get_tile_info"):
		return board_system.get_tile_info(tile_index)
	return {}

# ========================================
# ユーティリティ（ターゲットリスト生成）
# ========================================

## 現在のプレイヤーの非ダウンクリーチャーがいるタイルを取得
func get_own_active_creature_tiles() -> Array:
	var result = []
	
	if not board_system or not board_system.tile_nodes:
		return result
	
	for tile_index in board_system.tile_nodes:
		var tile = board_system.tile_nodes[tile_index]
		
		# 所有者チェック
		if tile.owner_id != current_player_id:
			continue
		
		# クリーチャーがいるかチェック
		if not "creature_data" in tile or tile.creature_data.is_empty():
			continue
		
		# ダウン状態チェック
		if tile.has_method("is_down") and tile.is_down():
			continue
		
		result.append(tile_index)
	
	return result


## 指定プレイヤーのクリーチャーがいるタイルを取得
func get_player_creature_tiles(player_id: int, include_down: bool = true) -> Array:
	var result = []
	
	if not board_system or not board_system.tile_nodes:
		return result
	
	for tile_index in board_system.tile_nodes:
		var tile = board_system.tile_nodes[tile_index]
		
		# 所有者チェック
		if tile.owner_id != player_id:
			continue
		
		# クリーチャーがいるかチェック
		if not "creature_data" in tile or tile.creature_data.is_empty():
			continue
		
		# ダウン状態チェック
		if not include_down and tile.has_method("is_down") and tile.is_down():
			continue
		
		result.append(tile_index)
	
	return result


## 全てのクリーチャーがいるタイルを取得
func get_all_creature_tiles(include_down: bool = true) -> Array:
	var result = []
	
	if not board_system or not board_system.tile_nodes:
		return result
	
	for tile_index in board_system.tile_nodes:
		var tile = board_system.tile_nodes[tile_index]
		
		# クリーチャーがいるかチェック
		if not "creature_data" in tile or tile.creature_data.is_empty():
			continue
		
		# ダウン状態チェック
		if not include_down and tile.has_method("is_down") and tile.is_down():
			continue
		
		result.append(tile_index)
	
	return result
