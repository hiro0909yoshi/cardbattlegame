extends RefCounted
class_name MovementDestinationPredictor

# 到着予測システム（経路予測・ハイライト表示）
# MovementController3Dから委譲される

# 現在ハイライト中のタイル
var _highlighted_destination_tiles: Array = []

# 参照
var controller: MovementController3D = null
var card_selection_ui: CardSelectionUI = null


func _init(p_controller: MovementController3D) -> void:
	controller = p_controller


## CardSelectionUIを設定
func set_card_selection_ui(ui: CardSelectionUI) -> void:
	card_selection_ui = ui


## 全ての到着可能地点を取得（分岐を全探索）
## start_tile: 開始タイル
## steps: 残り歩数
## came_from: 来た方向のタイル（-1なら不明）
## 返り値: Array[int] - 到着可能なタイル番号の配列
func predict_all_destinations(start_tile: int, steps: int, came_from: int) -> Array:
	var results: Array = []
	_predict_destinations_recursive(start_tile, steps, came_from, results)
	# 重複を除去
	var unique_results: Array = []
	for tile in results:
		if tile not in unique_results:
			unique_results.append(tile)
	return unique_results


## 再帰的に到着地点を探索
func _predict_destinations_recursive(current_tile: int, remaining_steps: int, came_from: int, results: Array, visited: Array = [], just_warped: bool = false):
	# 無限ループ防止（同じタイルを同じ歩数で再訪問した場合のみ）
	var visit_key = "%d_%d" % [current_tile, remaining_steps]
	if visit_key in visited:
		return
	visited.append(visit_key)

	# ワープタイル（通過型）の処理（ワープ直後でなければ）
	var tile = controller.tile_nodes.get(current_tile)
	if tile and tile.tile_type == "warp" and not just_warped:
		var warp_dest = _get_warp_destination(current_tile)
		if warp_dest >= 0 and warp_dest != current_tile:
			_predict_destinations_recursive(warp_dest, remaining_steps + 1, current_tile, results, visited, true)
			return

	# 残り歩数が0なら現在地が到着地点
	if remaining_steps <= 0:
		results.append(current_tile)
		return

	# 次に進める選択肢を取得
	var choices = _get_next_tile_choices(current_tile, came_from)

	if choices.is_empty():
		results.append(current_tile)
		return

	# 各選択肢について再帰的に探索
	for next_tile in choices:
		_predict_destinations_recursive(next_tile, remaining_steps - 1, current_tile, results, visited.duplicate(), false)


## 次に進める選択肢を取得（came_fromを除外）
func _get_next_tile_choices(current_tile: int, came_from: int) -> Array:
	var tile = controller.tile_nodes.get(current_tile)

	if not tile or not tile.connections or tile.connections.is_empty():
		var simple_choices = []
		if came_from != current_tile + 1:
			simple_choices.append(current_tile + 1)
		if came_from != current_tile - 1:
			simple_choices.append(current_tile - 1)
		if came_from < 0:
			return [current_tile + 1, current_tile - 1]
		return simple_choices

	# BranchTileの場合
	if tile is BranchTile:
		var branch_result = tile.get_next_tile_for_direction(came_from)
		if branch_result.tile >= 0:
			return [branch_result.tile]
		elif not branch_result.choices.is_empty():
			return branch_result.choices

	# 通常タイル（connectionsあり）: came_fromを除外
	var choices = []
	for conn in tile.connections:
		if conn != came_from:
			choices.append(conn)

	if choices.is_empty() and came_from >= 0:
		return [came_from]

	return choices


## 分岐選択中の到着予測ハイライトを更新
func update_destination_highlight_for_branch(is_branch_active: bool, branches: Array, branch_index: int, remaining_steps: int, branch_tile: int):
	clear_destination_highlight()

	if not is_branch_active or branches.is_empty():
		return

	var selected_tile = branches[branch_index]
	var steps_after_branch = remaining_steps - 1

	if steps_after_branch <= 0:
		_highlight_tile(selected_tile)
		return

	var destinations = predict_all_destinations(selected_tile, steps_after_branch, branch_tile)
	for dest_tile in destinations:
		_highlight_tile(dest_tile)


## タイルをハイライト
func _highlight_tile(tile_index: int):
	var tile = controller.tile_nodes.get(tile_index)
	if tile and tile.has_method("start_destination_highlight"):
		tile.start_destination_highlight()
		_highlighted_destination_tiles.append(tile_index)


## 到着予測ハイライトをクリア
func clear_destination_highlight():
	for tile_index in _highlighted_destination_tiles:
		var tile = controller.tile_nodes.get(tile_index)
		if tile and tile.has_method("stop_destination_highlight"):
			tile.stop_destination_highlight()
	_highlighted_destination_tiles.clear()


## 到着予想タイルに基づいて手札の配置制限表示を更新
func update_hand_restriction_for_destinations(destination_tiles: Array):
	if card_selection_ui:
		card_selection_ui.update_restriction_for_destinations(destination_tiles)


## ワープ先タイルを取得（到着予測用）
func _get_warp_destination(tile_index: int) -> int:
	if controller.special_tile_system:
		var warp_pair = controller.special_tile_system.get_warp_pair(tile_index)
		if warp_pair >= 0:
			return warp_pair
	return -1
