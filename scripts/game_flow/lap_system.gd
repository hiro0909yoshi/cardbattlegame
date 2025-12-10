extends Node
class_name LapSystem

## 周回管理システム
## ゲーム内の周回状態、チェックポイント通過、周回完了ボーナスを管理
## 破壊カウンターも含む

const GameConstants = preload("res://scripts/game_constants.gd")

## シグナル
signal lap_completed(player_id: int)

## 周回状態
var player_lap_state: Dictionary = {}  # {player_id: {N: bool, S: bool, lap_count: int}}

## ゲーム統計データ
var game_stats: Dictionary = {
	"total_creatures_destroyed": 0
}

## 外部参照（初期化時に設定）
var player_system = null
var board_system_3d = null

## 初期化
func setup(p_system, b_system):
	player_system = p_system
	board_system_3d = b_system

## 周回状態を初期化
func initialize_lap_state(player_count: int):
	player_lap_state.clear()
	game_stats["total_creatures_destroyed"] = 0
	
	for i in range(player_count):
		player_lap_state[i] = {
			"N": false,
			"S": false,
			"lap_count": 1  # 周回数カウント（1周目からスタート）
		}

## CheckpointTileのシグナルを接続
func connect_checkpoint_signals():
	if not board_system_3d or not board_system_3d.tile_nodes:
		return
	
	# 少し待ってからシグナル接続（CheckpointTileの_ready()を待つ）
	await get_tree().process_frame
	await get_tree().process_frame
	
	for tile_index in board_system_3d.tile_nodes.keys():
		var tile = board_system_3d.tile_nodes[tile_index]
		if tile and is_instance_valid(tile):
			if tile.has_signal("checkpoint_passed"):
				if not tile.checkpoint_passed.is_connected(_on_checkpoint_passed):
					tile.checkpoint_passed.connect(_on_checkpoint_passed)

## チェックポイント通過イベント
func _on_checkpoint_passed(player_id: int, checkpoint_type: String):
	if not player_lap_state.has(player_id):
		return
	
	# チェックポイントフラグを立てる
	player_lap_state[player_id][checkpoint_type] = true
	
	# N + S 両方揃ったか確認
	if player_lap_state[player_id]["N"] and player_lap_state[player_id]["S"]:
		complete_lap(player_id)

## 周回完了処理
func complete_lap(player_id: int):
	# 周回数をインクリメント
	player_lap_state[player_id]["lap_count"] += 1
	print("[周回完了] プレイヤー%d 周回数: %d" % [player_id + 1, player_lap_state[player_id]["lap_count"]])
	
	# フラグをリセット
	player_lap_state[player_id]["N"] = false
	player_lap_state[player_id]["S"] = false
	
	# 魔力ボーナスを付与
	if player_system:
		player_system.add_magic(player_id, GameConstants.PASS_BONUS)
		print("[周回完了] プレイヤー%d 魔力+%d" % [player_id + 1, GameConstants.PASS_BONUS])
	
	# ダウン解除
	if board_system_3d and board_system_3d.movement_controller:
		board_system_3d.movement_controller.clear_all_down_states_for_player(player_id)
		print("[周回完了] プレイヤー%d ダウン解除" % [player_id + 1])
	
	# HP回復+10
	if board_system_3d and board_system_3d.movement_controller:
		board_system_3d.movement_controller.heal_all_creatures_for_player(player_id, 10)
		print("[周回完了] プレイヤー%d HP回復+10" % [player_id + 1])
	
	# 全クリーチャーに周回ボーナスを適用
	if board_system_3d:
		_apply_lap_bonus_to_all_creatures(player_id)
	
	# シグナル発行
	lap_completed.emit(player_id)

## 全クリーチャーに周回ボーナスを適用
func _apply_lap_bonus_to_all_creatures(player_id: int):
	var tiles = board_system_3d.get_player_tiles(player_id)
	
	for tile in tiles:
		if tile.creature_data:
			_apply_lap_bonus_to_creature(tile.creature_data)

## クリーチャーに周回ボーナスを適用
func _apply_lap_bonus_to_creature(creature_data: Dictionary):
	if not creature_data.has("ability_parsed"):
		return
	
	var effects = creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "per_lap_permanent_bonus":
			_apply_per_lap_bonus(creature_data, effect)

## 周回ごと永続ボーナスを適用
func _apply_per_lap_bonus(creature_data: Dictionary, effect: Dictionary):
	var stat = effect.get("stat", "ap")
	var value = effect.get("value", 10)
	
	# 周回カウントを増加
	if not creature_data.has("map_lap_count"):
		creature_data["map_lap_count"] = 0
	creature_data["map_lap_count"] += 1
	
	# base_up_hp/ap に加算
	if stat == "ap":
		if not creature_data.has("base_up_ap"):
			creature_data["base_up_ap"] = 0
		creature_data["base_up_ap"] += value
		print("[Lap Bonus] ", creature_data.get("name", ""), " ST+", value, 
			  " (周回", creature_data["map_lap_count"], "回目)")
	
	elif stat == "max_hp":
		if not creature_data.has("base_up_hp"):
			creature_data["base_up_hp"] = 0
		
		# リセット条件チェック（モスタイタン用）
		var reset_condition = effect.get("reset_condition")
		if reset_condition:
			var reset_max_hp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
			var check = reset_condition.get("max_hp_check", {})
			var operator = check.get("operator", ">=")
			var threshold = check.get("value", 80)
			
			# MHP + 新しいボーナスがしきい値を超えるかチェック
			if operator == ">=" and (reset_max_hp + value) >= threshold:
				var reset_to = check.get("reset_to", 0)
				var reset_base_hp = creature_data.get("hp", 0)
				creature_data["base_up_hp"] = reset_to - reset_base_hp
				creature_data["current_hp"] = reset_to
				
				print("[Lap Bonus] ", creature_data.get("name", ""), 
					  " MHPリセット → ", reset_to, " HP:", reset_to)
				return
		
		creature_data["base_up_hp"] += value
		
		# 現在HPも回復
		var base_hp = creature_data.get("hp", 0)
		var base_up_hp = creature_data["base_up_hp"]
		var max_hp = base_hp + base_up_hp
		var current_hp = creature_data.get("current_hp", max_hp)
		var new_hp = min(current_hp + value, max_hp)
		creature_data["current_hp"] = new_hp
		
		print("[Lap Bonus] ", creature_data.get("name", ""), 
			  " MHP+", value, " HP+", value,
			  " (周回", creature_data["map_lap_count"], "回目)",
			  " HP:", current_hp, "→", new_hp, " / MHP:", max_hp)

# ========================================
# 破壊カウンター管理
# ========================================

## クリーチャー破壊時に呼ばれる
func on_creature_destroyed():
	game_stats["total_creatures_destroyed"] += 1
	print("[破壊カウント] 累計: ", game_stats["total_creatures_destroyed"])

## 破壊カウント取得
func get_destroy_count() -> int:
	return game_stats["total_creatures_destroyed"]

## 破壊カウントリセット（スペル用）
func reset_destroy_count():
	game_stats["total_creatures_destroyed"] = 0
	print("[破壊カウント] リセットしました")

## 周回数取得
func get_lap_count(player_id: int) -> int:
	if player_lap_state.has(player_id):
		return player_lap_state[player_id].get("lap_count", 0)
	return 0

## チェックポイントフラグを設定（外部から呼び出し用）
func set_checkpoint_flag(player_id: int, checkpoint_type: String):
	if player_lap_state.has(player_id):
		player_lap_state[player_id][checkpoint_type] = true
