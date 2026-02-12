extends BaseTile
class_name BranchTile

# 分岐タイル
# 通過時: 現在の分岐方向（branch_direction）に従って自動で進む
# 停止時: プレイヤーが方向を選択可能（後で実装）
# 分岐切替: 4ターンごとに自動切替（後で実装）
#
# connections配列の構造:
#   [0] = main（メイン方向、常にアクセス可能）
#   [1], [2], ... = branches（分岐選択肢）
#
# branch_direction: どの分岐が「開」かを示す（0 = branches[0]が開、1 = branches[1]が開）
#
# branch_dirs: 各分岐の視覚的な方向 ["down", "right"] など
#   "left", "right", "up", "down"

var branch_direction: int = 0:
	set(value):
		branch_direction = value % max(1, _get_branches().size())
		_update_indicator()

var main_dir: String = ""      # 自動計算される（メイン方向）
var branch_dirs: Array = []    # 自動計算される（分岐方向）
var _tile_nodes: Dictionary = {}  # 座標計算用

@onready var main_indicator: MeshInstance3D = $MainIndicator
@onready var indicator1: MeshInstance3D = $Indicator1
@onready var indicator2: MeshInstance3D = $Indicator2

const DIRECTION_OFFSET = {
	"left": Vector3(-0.8, 0, 0),
	"right": Vector3(0.8, 0, 0),
	"up": Vector3(0, 0, -0.8),
	"down": Vector3(0, 0, 0.8)
}

# 方向に応じたメッシュサイズ（中心に向かって長い）
const DIRECTION_MESH_SIZE = {
	"left": Vector3(2.5, 0.2, 1.0),   # X方向に長い
	"right": Vector3(2.5, 0.2, 1.0),  # X方向に長い
	"up": Vector3(1.0, 0.2, 2.5),     # Z方向に長い
	"down": Vector3(1.0, 0.2, 2.5)    # Z方向に長い
}

func _init():
	tile_type = "branch"

func _ready():
	_setup_indicators()
	_update_indicator()

## メイン方向を取得
func _get_main() -> int:
	if connections.is_empty():
		return -1
	return connections[0]

## 分岐選択肢を取得
func _get_branches() -> Array:
	if connections.size() <= 1:
		return []
	return connections.slice(1)

## 現在「開」の分岐を取得
func _get_open_branch() -> int:
	var branches = _get_branches()
	if branches.is_empty():
		return -1
	var idx = branch_direction % branches.size()
	return branches[idx]

## タイルノード参照を設定し、インジケーターを初期化
## StageLoaderからconnections設定後に呼び出す
func setup_with_tile_nodes(tile_nodes: Dictionary):
	_tile_nodes = tile_nodes
	_calculate_directions_from_connections()
	_setup_indicators()

## connectionsから方向を自動計算
func _calculate_directions_from_connections():
	if connections.is_empty() or _tile_nodes.is_empty():
		return
	
	var my_pos = global_position
	
	# main方向を計算
	var main_tile = _get_main()
	if _tile_nodes.has(main_tile):
		main_dir = _calculate_direction(my_pos, _tile_nodes[main_tile].global_position)
	
	# branch方向を計算
	branch_dirs.clear()
	var branches = _get_branches()
	for branch_tile in branches:
		if _tile_nodes.has(branch_tile):
			var dir = _calculate_direction(my_pos, _tile_nodes[branch_tile].global_position)
			branch_dirs.append(dir)
	


## 2点間の方向を計算（left/right/up/down）
func _calculate_direction(from_pos: Vector3, to_pos: Vector3) -> String:
	var diff = to_pos - from_pos
	
	# X方向の差が大きい場合
	if abs(diff.x) > abs(diff.z):
		return "right" if diff.x > 0 else "left"
	else:
		return "down" if diff.z > 0 else "up"

## インジケーターの初期位置とサイズを設定
func _setup_indicators():
	# メイン方向インジケーター（常時表示、緑色）
	if main_dir != "" and main_indicator:
		_setup_single_indicator(main_indicator, main_dir, false)
	
	# 分岐インジケーター1（赤色）
	if branch_dirs.size() >= 1 and indicator1:
		_setup_single_indicator(indicator1, branch_dirs[0], true)
	
	# 分岐インジケーター2（赤色）
	if branch_dirs.size() >= 2 and indicator2:
		_setup_single_indicator(indicator2, branch_dirs[1], true)

## 単一インジケーターの位置とメッシュを設定
func _setup_single_indicator(indicator: MeshInstance3D, dir: String, is_branch: bool = false):
	if not DIRECTION_OFFSET.has(dir):
		return
	
	# 位置設定
	indicator.position = DIRECTION_OFFSET[dir] + Vector3(0, 0.4, 0)
	
	# メッシュサイズ設定
	if DIRECTION_MESH_SIZE.has(dir):
		var box_mesh = BoxMesh.new()
		box_mesh.size = DIRECTION_MESH_SIZE[dir]
		indicator.mesh = box_mesh
	
	# マテリアル設定（分岐インジケーターは赤、メインは緑）
	var material = StandardMaterial3D.new()
	if is_branch:
		material.albedo_color = Color(1, 0, 0, 1)  # 赤
		material.emission_enabled = true
		material.emission = Color(1, 0, 0, 1)
	else:
		material.albedo_color = Color(0, 1, 0, 1)  # 緑
		material.emission_enabled = true
		material.emission = Color(0, 1, 0, 1)
	material.emission_energy_multiplier = 0.5
	indicator.material_override = material

## インジケーターの表示を更新
func _update_indicator():
	if not indicator1 or not indicator2:
		return
	
	# branch_directionに応じて表示切替
	indicator1.visible = (branch_direction == 0)
	indicator2.visible = (branch_direction == 1)

## 現在の分岐方向に基づいて次のタイルを取得
## 戻り値: {"tile": 次のタイル, "choices": 選択肢（複数あればUI表示用）}
func get_next_tile_for_direction(came_from: int) -> Dictionary:
	if connections.is_empty():
		return {"tile": -1, "choices": []}
	
	var main_tile = _get_main()
	var open_branch = _get_open_branch()
	
	# 進める方向 = [main, 開いている分岐] からcame_fromを除外
	var available = []
	if main_tile != came_from:
		available.append(main_tile)
	if open_branch >= 0 and open_branch != came_from:
		available.append(open_branch)
	
	# 進める方向が0 → 来た方向に戻る（本来起きないはず）
	if available.is_empty():
		return {"tile": came_from, "choices": []}
	
	# 進める方向が1つ → 自動選択
	if available.size() == 1:
		return {"tile": available[0], "choices": []}
	
	# 進める方向が2つ以上 → 選択UI表示
	return {"tile": -1, "choices": available}

## 分岐方向を切り替え
func toggle_branch_direction():
	var branches = _get_branches()
	if branches.size() < 2:
		return
	branch_direction = (branch_direction + 1) % branches.size()

## 分岐方向を設定
func set_branch_direction(direction: int):
	var branches = _get_branches()
	if branches.is_empty():
		return
	branch_direction = direction % branches.size()

# ============================================
# 停止時の特殊アクション
# ============================================

var _ui_manager = null
var _board_system = null

signal direction_change_selected(change: bool)

## 特殊タイルアクション実行（special_tile_systemから呼び出される）
func handle_special_action(player_id: int, context: Dictionary) -> Dictionary:
	# コンテキストからシステム参照を取得
	_ui_manager = context.get("ui_manager")
	_board_system = context.get("board_system")
	
	# 分岐が1つしかない場合はスキップ
	var branches = _get_branches()
	if branches.size() < 2:
		return {"success": true, "changed": false}
	
	# CPUの場合はスキップ
	if _is_cpu_player(player_id):
		return {"success": true, "changed": false}
	
	# プレイヤーの場合はUI表示
	var result = await _show_direction_change_selection()
	return result

## CPU判定
func _is_cpu_player(player_id: int) -> bool:
	if _board_system and "player_is_cpu" in _board_system:
		var cpu_flags = _board_system.player_is_cpu
		if player_id < cpu_flags.size():
			return cpu_flags[player_id]
	return player_id != 0

## 方向変更選択UI表示
func _show_direction_change_selection() -> Dictionary:
	if not _ui_manager:
		push_error("[BranchTile] UIManagerがありません")
		return {"success": false, "changed": false}
	
	# 現在の方向を表示
	var open_branch = _get_open_branch()
	
	# 通知ポップアップで表示
	if _ui_manager.global_comment_ui:
		var message = "分岐タイル\n現在タイル%dが開\n\n[color=yellow]✓変更する / ✕変更しない[/color]" % open_branch
		_ui_manager.show_comment_message(message)
	
	# グローバルボタンを設定
	_ui_manager.enable_navigation(
		func(): _on_change_selected(true),   # 決定 → 変更する
		func(): _on_change_selected(false),  # 戻る → 変更しない
		Callable(),  # 上
		Callable()   # 下
	)
	
	# 選択を待つ
	var changed = await direction_change_selected
	
	# ボタンをクリア
	_ui_manager.disable_navigation()
	
	# ポップアップを閉じる
	if _ui_manager.global_comment_ui:
		_ui_manager.hide_comment_message()
	
	if changed:
		toggle_branch_direction()
		return {"success": true, "changed": true}
	else:
		return {"success": true, "changed": false}

## 選択コールバック
func _on_change_selected(change: bool):
	direction_change_selected.emit(change)
