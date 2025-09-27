extends Node
class_name BoardSystem3D

# 3Dボード管理システム

signal tile_action_completed()
signal movement_started()
signal movement_completed(final_tile: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# 3Dタイル管理
var tile_nodes = {}        # tile_index -> BaseTile
var player_nodes = []      # 3D駒のノード配列
var player_tiles = []      # 各プレイヤーの現在位置

# ゲーム設定
var player_count = 2
var player_is_cpu = [false, true]
var current_player_index = 0

# 移動制御
var is_moving = false
var is_waiting_for_action = false

# カメラ参照
var camera = null

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var cpu_ai_handler: CPUAIHandler

# === 初期化 ===

func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BattleSystem, s_system: SkillSystem):
	player_system = p_system
	card_system = c_system
	battle_system = b_system
	skill_system = s_system
	
	# CPUAIHandlerを作成
	cpu_ai_handler = CPUAIHandler.new()
	cpu_ai_handler.name = "CPUAIHandler"
	add_child(cpu_ai_handler)
	
	if cpu_ai_handler.has_method("setup_systems"):
		cpu_ai_handler.setup_systems(c_system, null, p_system, b_system, s_system)
	
	# シグナル接続
	cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided)
	cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided)
	cpu_ai_handler.level_up_decided.connect(_on_cpu_level_up_decided)

# 3Dタイル収集
func collect_tiles(tiles_container: Node):
	for child in tiles_container.get_children():
		if child is BaseTile:
			tile_nodes[child.tile_index] = child

# 3Dプレイヤー駒収集
func collect_players(players_container: Node):
	player_nodes = players_container.get_children()
	
	# 初期位置設定
	player_tiles.clear()
	for i in range(player_nodes.size()):
		player_tiles.append(0)
		if tile_nodes.has(0):
			var start_pos = tile_nodes[0].global_position
			start_pos.y += 1.0
			start_pos.x += i * 0.5  # 少しずらす
			player_nodes[i].global_position = start_pos

# === BoardSystem互換メソッド ===

# タイル情報取得
func get_tile_info(tile_index: int) -> Dictionary:
	if not tile_nodes.has(tile_index):
		return {}
	
	var tile = tile_nodes[tile_index]
	return {
		"index": tile_index,
		"type": get_tile_type(tile.tile_type),
		"element": tile.tile_type if tile.tile_type in ["火", "水", "風", "土"] else "",
		"owner": tile.owner_id,
		"level": tile.level,
		"creature": tile.creature_data,
		"is_special": is_special_tile_type(tile.tile_type)
	}

# タイルタイプ変換
func get_tile_type(tile_type_str: String) -> int:
	match tile_type_str:
		"start": return 1
		"checkpoint": return 2
		"warp", "card", "neutral": return 3
		_: return 0

# 特殊マス判定
func is_special_tile_type(tile_type: String) -> bool:
	return tile_type in ["warp", "card", "checkpoint", "neutral", "start"]

# タイル位置取得（2D座標として返す）
func get_tile_position(tile_index: int) -> Vector2:
	if tile_nodes.has(tile_index):
		var pos3d = tile_nodes[tile_index].global_position
		return Vector2(pos3d.x * 100 + 400, pos3d.z * 100 + 300)
	return Vector2(400, 300)

# 土地の所有者設定
func set_tile_owner(tile_index: int, owner_id: int):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].set_tile_owner(owner_id)

# クリーチャー配置
func place_creature(tile_index: int, creature_data: Dictionary):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].place_creature(creature_data)

# レベルアップ
func upgrade_tile_level(tile_index: int) -> bool:
	if tile_nodes.has(tile_index):
		return tile_nodes[tile_index].level_up()
	return false

# レベルアップコスト取得
func get_upgrade_cost(tile_index: int) -> int:
	if tile_nodes.has(tile_index):
		var level = tile_nodes[tile_index].level
		if level < GameConstants.MAX_LEVEL:
			return level * GameConstants.LEVEL_UP_COST_RATE
	return 0

# 通行料計算
func calculate_toll(tile_index: int) -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	var tile = tile_nodes[tile_index]
	if tile.owner_id == -1:
		return 0
	
	var base_toll = GameConstants.BASE_TOLL
	var level_multiplier = tile.level
	var chain_bonus = calculate_chain_bonus(tile_index, tile.owner_id)
	
	return int(base_toll * level_multiplier * chain_bonus)

# 連鎖ボーナス計算
func calculate_chain_bonus(tile_index: int, owner_id: int) -> float:
	if not tile_nodes.has(tile_index):
		return 1.0
	
	var target_element = tile_nodes[tile_index].tile_type
	if target_element == "" or not target_element in ["火", "水", "風", "土"]:
		return 1.0
	
	var same_element_count = get_element_chain_count(tile_index, owner_id)
	
	if same_element_count >= 4:
		return GameConstants.CHAIN_BONUS_4
	elif same_element_count == 3:
		return GameConstants.CHAIN_BONUS_3
	elif same_element_count == 2:
		return GameConstants.CHAIN_BONUS_2
	
	return 1.0

# 属性連鎖数取得
func get_element_chain_count(tile_index: int, owner_id: int) -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	var target_element = tile_nodes[tile_index].tile_type
	var chain_count = 0
	
	for i in tile_nodes:
		var tile = tile_nodes[i]
		if tile.owner_id == owner_id and tile.tile_type == target_element:
			chain_count += 1
	
	return min(chain_count, 4)

# 所有者の土地数を取得
func get_owner_land_count(owner_id: int) -> int:
	var count = 0
	for i in tile_nodes:
		if tile_nodes[i].owner_id == owner_id:
			count += 1
	return count

# 2D版との互換性メソッド
func get_tile_data_array() -> Array:
	var data = []
	for i in range(20):
		if tile_nodes.has(i):
			data.append({
				"element": tile_nodes[i].tile_type,
				"type": get_tile_type(tile_nodes[i].tile_type),
				"owner": tile_nodes[i].owner_id,
				"level": tile_nodes[i].level
			})
		else:
			data.append({"element": "", "type": 0, "owner": -1, "level": 1})
	return data

# === 3D移動処理 ===

# サイコロ開始
func start_dice_roll():
	if is_moving:
		return
	
	var dice_value = player_system.roll_dice()
	if skill_system:
		dice_value = skill_system.modify_dice_roll(dice_value, current_player_index)

# 3Dプレイヤー移動
func move_player_3d(player_id: int, steps: int):
	if is_moving or player_id >= player_nodes.size():
		return
	
	is_moving = true
	emit_signal("movement_started")
	
	var current_tile = player_tiles[player_id]
	var path = []
	
	# 経路作成
	for i in range(steps):
		current_tile = (current_tile + 1) % 20
		path.append(current_tile)
	
	# 移動実行
	await move_along_path(player_id, path)
	
	player_tiles[player_id] = current_tile
	is_moving = false
	emit_signal("movement_completed", current_tile)

# 経路に沿って移動
func move_along_path(player_id: int, path: Array):
	var player_node = player_nodes[player_id]
	
	for tile_index in path:
		if not tile_nodes.has(tile_index):
			continue
			
		var target_pos = tile_nodes[tile_index].global_position
		target_pos.y += 1.0
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		
		# プレイヤー駒移動
		tween.tween_property(player_node, "global_position", target_pos, 0.5)
		
		# カメラ追従
		if camera:
			var cam_offset = Vector3(0, 10, 10)
			var cam_target = target_pos + cam_offset
			tween.tween_property(camera, "global_position", cam_target, 0.5)
		
		await tween.finished
		
		if camera:
			camera.look_at(player_node.global_position, Vector3.UP)
		
		# スタート通過チェック
		if tile_index == 0 and tile_index != path[0]:
			player_system.add_magic(player_id, GameConstants.PASS_BONUS)

# === タイル処理 ===

# タイル到着処理
func process_tile_landing(tile_index: int):
	if not tile_nodes.has(tile_index):
		emit_signal("tile_action_completed")
		return
	
	var tile = tile_nodes[tile_index]
	var tile_info = get_tile_info(tile_index)
	
	# 特殊マス処理
	if is_special_tile_type(tile.tile_type):
		handle_special_tile(tile, tile_info)
		return
	
	# 通常タイル処理
	process_normal_tile(tile, tile_info)

# 特殊マスの処理
func handle_special_tile(tile: BaseTile, tile_info: Dictionary):
	match tile.tile_type:
		"start":
			emit_signal("tile_action_completed")
		"checkpoint":
			player_system.add_magic(current_player_index, GameConstants.CHECKPOINT_BONUS)
			if ui_manager:
				ui_manager.update_player_info_panels()
			emit_signal("tile_action_completed")
		"card":
			card_system.draw_card_for_player(current_player_index)
			emit_signal("tile_action_completed")
		"warp":
			emit_signal("tile_action_completed")
		"neutral":
			process_normal_tile(tile, tile_info)
		_:
			emit_signal("tile_action_completed")

# 通常タイルの処理
func process_normal_tile(tile: BaseTile, tile_info: Dictionary):
	if player_is_cpu[current_player_index]:
		process_cpu_action(tile, tile_info)
		return
	
	# 人間プレイヤーの処理
	if tile_info["owner"] == -1:
		# 空き地
		set_tile_owner(tile_info["index"], current_player_index)
		show_summon_ui()
	elif tile_info["owner"] == current_player_index:
		# 自分の土地
		emit_signal("tile_action_completed")
	else:
		# 敵の土地（インライン処理）
		if tile_info.get("creature", {}).is_empty():
			show_battle_ui("invasion")
		else:
			show_battle_ui("battle")
		
# CPU行動処理
func process_cpu_action(tile: BaseTile, tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	await get_tree().create_timer(0.5).timeout
	
	if tile_info["owner"] == -1:
		set_tile_owner(tile_info["index"], current_player.id)
		
		if card_system.get_hand_size_for_player(current_player.id) > 0:
			cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided, CONNECT_ONE_SHOT)
			cpu_ai_handler.decide_summon(current_player)
		else:
			emit_signal("tile_action_completed")
			
	elif tile_info["owner"] != current_player.id:
		if tile_info.get("creature", {}).is_empty():
			cpu_ai_handler.battle_decided.connect(_on_cpu_invasion_decided, CONNECT_ONE_SHOT)
			cpu_ai_handler.decide_invasion(current_player, tile_info)
		else:
			cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided, CONNECT_ONE_SHOT)
			cpu_ai_handler.decide_battle(current_player, tile_info)
	else:
		emit_signal("tile_action_completed")
# === UI表示 ===

# 召喚UI表示
func show_summon_ui():
	is_waiting_for_action = true
	
	if not ui_manager:
		emit_signal("tile_action_completed")
		return
	
	ui_manager.phase_label.text = "召喚するクリーチャーを選択"
	ui_manager.show_card_selection_ui(player_system.get_current_player())
	card_system.set_cards_selectable(true)

# バトルUI表示
func show_battle_ui(mode: String):
	is_waiting_for_action = true
	
	if not ui_manager:
		emit_signal("tile_action_completed")
		return
	
	if mode == "invasion":
		ui_manager.phase_label.text = "侵略するクリーチャーを選択"
	else:
		ui_manager.phase_label.text = "バトルするクリーチャーを選択"
	
	ui_manager.show_card_selection_ui(player_system.get_current_player())
	card_system.set_cards_selectable(true)

# === アクション処理 ===

# カード選択時
func on_card_selected(card_index: int):
	if not is_waiting_for_action:
		return
	
	is_waiting_for_action = false
	var current_tile = player_tiles[current_player_index]
	var tile_info = get_tile_info(current_tile)
	
	if tile_info["owner"] == -1:
		execute_summon(card_index)
	else:
		execute_battle(card_index, tile_info)

# パス選択時
func on_action_pass():
	if not is_waiting_for_action:
		return
		
	is_waiting_for_action = false
	var current_tile = player_tiles[current_player_index]
	var tile_info = get_tile_info(current_tile)
	
	if tile_info["owner"] != -1 and tile_info["owner"] != current_player_index:
		pay_toll(tile_info)
	else:
		emit_signal("tile_action_completed")

# 召喚実行
func execute_summon(card_index: int):
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	if card_data.is_empty():
		emit_signal("tile_action_completed")
		return
	
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		
		var current_tile = player_tiles[current_player_index]
		set_tile_owner(current_tile, current_player_index)
		place_creature(current_tile, card_data)
		
		if ui_manager:
			ui_manager.hide_card_selection_ui()
			ui_manager.update_player_info_panels()
	
	emit_signal("tile_action_completed")

# バトル実行
func execute_battle(card_index: int, tile_info: Dictionary):
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	if card_data.is_empty():
		pay_toll(tile_info)
		return
	
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power < cost:
		pay_toll(tile_info)
		return
	
	# 簡易バトル判定
	var attacker_st = card_data.get("damage", 0)
	var defender_hp = tile_info["creature"].get("block", 0) if not tile_info["creature"].is_empty() else 0
	
	# カード使用
	card_system.use_card_for_player(current_player_index, card_index)
	player_system.add_magic(current_player_index, -cost)
	
	if attacker_st >= defender_hp:
		# 勝利：土地を奪取
		set_tile_owner(tile_info["index"], current_player_index)
		place_creature(tile_info["index"], card_data)
	else:
		# 敗北：通行料支払い
		pay_toll(tile_info)
	
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	await get_tree().create_timer(1.0).timeout
	emit_signal("tile_action_completed")

# 通行料支払い
func pay_toll(tile_info: Dictionary):
	var toll = calculate_toll(tile_info["index"])
	var payer_id = current_player_index
	var receiver_id = tile_info["owner"]
	
	if receiver_id >= 0 and receiver_id < player_system.players.size():
		player_system.pay_toll(payer_id, receiver_id, toll)
	
	emit_signal("tile_action_completed")

# === CPUコールバック ===

func _on_cpu_summon_decided(card_index: int):
	if card_index >= 0:
		execute_summon(card_index)
	else:
		emit_signal("tile_action_completed")

func _on_cpu_invasion_decided(card_index: int):
	var current_tile = player_tiles[current_player_index]
	var tile_info = get_tile_info(current_tile)
	
	if card_index >= 0:
		execute_battle(card_index, tile_info)
	else:
		pay_toll(tile_info)

func _on_cpu_battle_decided(card_index: int):
	var current_tile = player_tiles[current_player_index]
	var tile_info = get_tile_info(current_tile)
	
	if card_index >= 0:
		execute_battle(card_index, tile_info)
	else:
		pay_toll(tile_info)

func _on_cpu_level_up_decided(do_upgrade: bool):
	if do_upgrade:
		var current_tile = player_tiles[current_player_index]
		var cost = get_upgrade_cost(current_tile)
		if player_system.get_current_player().magic_power >= cost:
			upgrade_tile_level(current_tile)
			player_system.add_magic(current_player_index, -cost)
	
	emit_signal("tile_action_completed")

# ターン終了処理
func end_current_turn():
	switch_to_next_player()

# 次のプレイヤーに切り替え
func switch_to_next_player():
	current_player_index = (current_player_index + 1) % player_count
	player_system.current_player_index = current_player_index
	
	# カメラフォーカスのみ（ドロー処理は削除）
	if camera and current_player_index < player_nodes.size():
		var next_player_node = player_nodes[current_player_index]
		if next_player_node:
			var tween = get_tree().create_tween()
			var cam_offset = Vector3(0, 10, 10)
			var cam_target = next_player_node.global_position + cam_offset
			tween.tween_property(camera, "global_position", cam_target, 0.8)
			await tween.finished
			if camera:
				camera.look_at(next_player_node.global_position, Vector3.UP)
