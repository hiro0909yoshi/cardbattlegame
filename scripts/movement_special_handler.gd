extends RefCounted
class_name MovementSpecialHandler

# チェックポイント・ダウンクリア・回復・カメラフォーカス・ダイスバフ
# MovementController3Dから委譲される

# 参照
var controller: MovementController3D = null


func _init(p_controller: MovementController3D) -> void:
	controller = p_controller


# スタート地点通過処理（特別な効果なし、周回完了ボーナスは_complete_lapで処理）
func handle_start_pass(player_id: int):
	controller.start_passed.emit(player_id)


# チェックポイント通過処理
func check_and_handle_checkpoint(player_id: int, tile_index: int, previous_tile: int):
	if not controller.tile_nodes.has(tile_index):
		return

	var tile = controller.tile_nodes[tile_index]

	# CheckpointTileかチェック
	if tile.has_signal("checkpoint_passed"):
		# タイル0は2回目以降のみ通過扱い
		if tile_index == 0 and previous_tile <= tile_index:
			return

		if tile.has_method("on_player_passed"):
			tile.on_player_passed(player_id)

			var lap_system = _get_lap_system()
			if lap_system:
				await lap_system.checkpoint_processing_completed


# 特定タイルへ直接配置（初期配置用）
func place_player_at_tile(player_id: int, tile_index: int) -> void:
	if player_id >= controller.player_nodes.size() or not controller.tile_nodes.has(tile_index):
		return

	var player_node = controller.player_nodes[player_id]
	var target_pos = controller.tile_nodes[tile_index].global_position
	target_pos.y += MovementController3D.MOVE_HEIGHT

	# オフセットを追加（プレイヤーごとに少しずらす）
	target_pos.x += player_id * 0.5

	player_node.global_position = target_pos
	controller.player_tiles[player_id] = tile_index


# 全クリーチャーのHP回復
func heal_all_creatures_for_player(player_id: int, heal_amount: int):
	for tile_index in controller.tile_nodes.keys():
		var tile = controller.tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.creature_data:
			var creature = tile.creature_data

			# 周回回復不可チェック
			var keywords = creature.get("ability_parsed", {}).get("keywords", [])
			if "周回回復不可" in keywords:
				print("[周回回復不可] ", creature.get("name", "?"), " は回復しない")
				continue

			# MHP計算
			var base_hp = creature.get("hp", 0)
			var base_up_hp = creature.get("base_up_hp", 0)
			var max_hp = base_hp + base_up_hp

			var current_hp = creature.get("current_hp", max_hp)

			# HP回復（MHPを超えない）
			var new_hp = min(current_hp + heal_amount, max_hp)
			creature["current_hp"] = new_hp


# プレイヤーの全土地のダウン状態をクリア
func clear_all_down_states_for_player(player_id: int) -> int:
	var cleared_count = 0
	for tile_index in controller.tile_nodes.keys():
		var tile = controller.tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.has_method("is_down") and tile.is_down():
			tile.clear_down_state()
			cleared_count += 1
	return cleared_count


# カメラをプレイヤーにフォーカス
func focus_camera_on_player(player_id: int, smooth: bool = true) -> void:
	if not controller.camera or player_id >= controller.player_nodes.size():
		return

	var player_node = controller.player_nodes[player_id]
	if not player_node:
		return

	var player_pos = player_node.global_position
	var look_target = player_pos + Vector3(0, 1.0, 0)
	var target_pos = look_target + GameConstants.CAMERA_OFFSET

	if smooth:
		var tween = controller.get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(controller.camera, "global_position", target_pos, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.set_parallel(false)
		tween.tween_callback(func(): controller.camera.look_at(look_target + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP))
		await tween.finished
	else:
		controller.camera.global_position = target_pos
		controller.camera.look_at(look_target + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)


# === ダイス条件バフ処理 ===

# ダイス条件に基づく永続バフを適用
func apply_dice_condition_buffs(player_id: int, dice_value: int):
	if not controller.tile_nodes:
		return

	for tile_index in controller.tile_nodes.keys():
		var tile = controller.tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and tile.creature_data:
			_check_and_apply_dice_buff(tile.creature_data, dice_value)


# 個別クリーチャーのダイス条件バフをチェック・適用
func _check_and_apply_dice_buff(creature_data: Dictionary, dice_value: int):
	if not creature_data.has("ability_parsed"):
		return

	var effects = creature_data.get("ability_parsed", {}).get("effects", [])

	for effect in effects:
		if effect.get("effect_type") == "dice_condition_bonus":
			_apply_dice_condition_effect(creature_data, effect, dice_value)


# ダイス条件効果を適用
func _apply_dice_condition_effect(creature_data: Dictionary, effect: Dictionary, dice_value: int):
	var dice_check = effect.get("dice_check", {})
	var operator = dice_check.get("operator", "<=")
	var threshold = dice_check.get("value", 3)

	var condition_met = false
	match operator:
		"<=":
			condition_met = dice_value <= threshold
		">=":
			condition_met = dice_value >= threshold
		"==":
			condition_met = dice_value == threshold
		"<":
			condition_met = dice_value < threshold
		">":
			condition_met = dice_value > threshold

	if not condition_met:
		return

	var stat_changes = effect.get("stat_changes", {})

	if stat_changes.has("ap"):
		if not creature_data.has("base_up_ap"):
			creature_data["base_up_ap"] = 0
		creature_data["base_up_ap"] += stat_changes["ap"]
		print("[Dice Buff] ", creature_data.get("name", ""), " ST+", stat_changes["ap"],
			  " (ダイス: ", dice_value, ")")

	if stat_changes.has("max_hp"):
		EffectManager.apply_max_hp_effect(creature_data, stat_changes["max_hp"])
		print("[Dice Buff] ", creature_data.get("name", ""), " MHP+", stat_changes["max_hp"],
			  " (ダイス: ", dice_value, ")")


# LapSystemを取得
func _get_lap_system():
	var gfm = controller.game_flow_manager
	if gfm and "lap_system" in gfm:
		return gfm.lap_system
	return null
