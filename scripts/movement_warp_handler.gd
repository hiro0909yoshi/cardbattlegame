extends RefCounted
class_name MovementWarpHandler

# ワープ処理・通過イベント・足止め判定
# MovementController3Dから委譲される

# 参照
var controller: MovementController3D = null


func _init(p_controller: MovementController3D) -> void:
	controller = p_controller


# ワープをチェックして処理（通過型のみ）
func check_and_handle_warp(player_id: int, tile_index: int) -> Dictionary:
	if not controller.special_tile_system:
		return {"warped": false}

	# タイルタイプを確認（通過型warpのみ処理、warp_stopは停止時に処理）
	if controller.tile_nodes.has(tile_index):
		var tile = controller.tile_nodes[tile_index]
		if tile.tile_type != "warp":
			return {"warped": false}

	# 通過型ワープかチェック
	if controller.special_tile_system.is_warp_gate(tile_index):
		var warp_pair = controller.special_tile_system.get_warp_pair(tile_index)
		if warp_pair != -1 and warp_pair != tile_index:
			await execute_warp(player_id, tile_index, warp_pair)
			return {"warped": true, "new_tile": warp_pair}

	return {"warped": false}


# ワープを実行（3D版）
func warp_player_3d(player_id: int, to_tile: int) -> void:
	if player_id >= controller.player_nodes.size() or not controller.tile_nodes.has(to_tile):
		return

	var from_tile = controller.player_tiles[player_id]
	await execute_warp(player_id, from_tile, to_tile)
	controller.player_tiles[player_id] = to_tile


# ワープアニメーション実行
func execute_warp(player_id: int, from_tile: int, to_tile: int) -> void:
	var player_node = controller.player_nodes[player_id]

	# ワープエフェクト（簡易版：縮小して消える→移動→拡大して現れる）
	const WARP_MIN_SCALE = Vector3(0.001, 0.001, 0.001)
	var tween = controller.get_tree().create_tween()

	# 縮小して消える
	tween.tween_property(player_node, "scale", WARP_MIN_SCALE, 0.2)

	await tween.finished
	if controller.tile_nodes.has(to_tile):
		var target_pos = controller.tile_nodes[to_tile].global_position
		target_pos.y += MovementController3D.MOVE_HEIGHT
		player_node.global_position = target_pos

		# カメラも瞬間移動
		if controller.camera and controller.player_system and player_id == controller.player_system.current_player_index:
			var gfm = controller.game_flow_manager
			if gfm and gfm.board_system_3d:
				gfm.board_system_3d.cancel_direction_tween()
			var cam_target = target_pos + GameConstants.CAMERA_OFFSET
			controller.camera.global_position = cam_target

	# 拡大して現れる
	var tween2 = controller.get_tree().create_tween()
	tween2.tween_property(player_node, "scale", Vector3.ONE, 0.2)
	await tween2.finished

	controller.warp_executed.emit(player_id, from_tile, to_tile)


## 通過時に発動するタイルイベントをチェック
func check_pass_through_event(player_id: int, tile_index: int) -> void:
	if not controller.tile_nodes.has(tile_index):
		return

	var tile = controller.tile_nodes[tile_index]
	var tile_type = tile.tile_type if "tile_type" in tile else ""

	match tile_type:
		"magic_stone":
			await _handle_pass_through_magic_stone(player_id, tile)


## 魔法石タイル通過処理
func _handle_pass_through_magic_stone(player_id: int, tile) -> void:
	if not controller.special_tile_system:
		return

	if controller.special_tile_system.has_method("handle_magic_stone_tile"):
		await controller.special_tile_system.handle_magic_stone_tile(player_id, tile)


## タイルでの拘束判定（SpellMovement経由）
func check_forced_stop_at_tile(tile_index: int, player_id: int) -> Dictionary:
	if not controller.spell_movement:
		return {"stopped": false, "reason": "", "source_type": ""}

	return controller.spell_movement.check_forced_stop_with_tiles(tile_index, player_id, controller.tile_nodes)
