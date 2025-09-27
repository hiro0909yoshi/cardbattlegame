extends Node
class_name BoardSystem3D

# 3Dボード管理システム - スリム化版
# タイル管理とゲームフロー制御に特化

signal tile_action_completed()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# 3Dタイル管理
var tile_nodes = {}        # tile_index -> BaseTile
var player_nodes = []      # 3D駒のノード配列

# サブシステム
var movement_controller: MovementController3D
var tile_info_display: TileInfoDisplay

# ゲーム設定
var player_count = 2
var player_is_cpu = [false, true]
var current_player_index = 0

# 状態管理
var is_waiting_for_action = false

# カメラ参照
var camera = null

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var skill_system: SkillSystem
var special_tile_system: SpecialTileSystem
var ui_manager: UIManager
var cpu_ai_handler: CPUAIHandler

# === 初期化 ===

func _ready():
	# サブシステムを作成
	create_subsystems()

func create_subsystems():
	# タイル情報表示システム
	tile_info_display = TileInfoDisplay.new()
	tile_info_display.name = "TileInfoDisplay"
	add_child(tile_info_display)
	
	# 移動制御システム
	movement_controller = MovementController3D.new()
	movement_controller.name = "MovementController3D"
	add_child(movement_controller)
	
	# シグナル接続
	movement_controller.movement_started.connect(_on_movement_started)
	movement_controller.movement_completed.connect(_on_movement_completed)

func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BattleSystem, 
				   s_system: SkillSystem, st_system: SpecialTileSystem = null):
	player_system = p_system
	card_system = c_system
	battle_system = b_system
	skill_system = s_system
	special_tile_system = st_system
	
	# BattleSystemに参照を設定
	if battle_system.has_method("setup_systems"):
		battle_system.setup_systems(self, card_system, player_system)
	
	# MovementControllerに参照を設定
	if movement_controller:
		movement_controller.setup_systems(player_system, special_tile_system)
	
	# CPUAIHandlerを設定
	setup_cpu_ai_handler()

func setup_cpu_ai_handler():
	cpu_ai_handler = get_node_or_null("CPUAIHandler")
	if not cpu_ai_handler:
		cpu_ai_handler = CPUAIHandler.new()
		cpu_ai_handler.name = "CPUAIHandler"
		add_child(cpu_ai_handler)
	
	if cpu_ai_handler.has_method("setup_systems"):
		cpu_ai_handler.setup_systems(card_system, self, player_system, battle_system, skill_system)

# 3Dタイル収集
func collect_tiles(tiles_container: Node):
	for child in tiles_container.get_children():
		if child is BaseTile:
			tile_nodes[child.tile_index] = child
	
	# サブシステムに渡す
	if tile_info_display:
		tile_info_display.setup_labels(tile_nodes, self)
	
	if movement_controller:
		movement_controller.tile_nodes = tile_nodes
	
	update_all_tile_displays()

# 3Dプレイヤー駒収集
func collect_players(players_container: Node):
	player_nodes = players_container.get_children()
	
	print("プレイヤーノード収集: ", player_nodes.size(), "個")
	
	# MovementControllerに渡す（cameraも含めて）
	if movement_controller:
		movement_controller.initialize(tile_nodes, player_nodes, camera)
		
		# カメラが設定されているか確認
		if camera:
			print("カメラ設定完了: ", camera)
			movement_controller.camera = camera
		else:
			print("Warning: カメラが設定されていません")
		
		# 初期配置
		for i in range(player_nodes.size()):
			movement_controller.place_player_at_tile(i, 0)

# === タイル情報管理 ===

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

func get_tile_type(tile_type_str: String) -> int:
	match tile_type_str:
		"start": return 1
		"checkpoint": return 2
		"warp", "card", "neutral": return 3
		_: return 0

func is_special_tile_type(tile_type: String) -> bool:
	return tile_type in ["warp", "card", "checkpoint", "neutral", "start"]

func set_tile_owner(tile_index: int, owner_id: int):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].set_tile_owner(owner_id)
		if tile_info_display:
			tile_info_display.update_display(tile_index, get_tile_info(tile_index))

func place_creature(tile_index: int, creature_data: Dictionary):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].place_creature(creature_data)
		if tile_info_display:
			tile_info_display.update_display(tile_index, get_tile_info(tile_index))

func upgrade_tile_level(tile_index: int) -> bool:
	if tile_nodes.has(tile_index):
		var success = tile_nodes[tile_index].level_up()
		if success and tile_info_display:
			tile_info_display.update_display(tile_index, get_tile_info(tile_index))
		return success
	return false

func get_upgrade_cost(tile_index: int) -> int:
	if tile_nodes.has(tile_index):
		var current_level = tile_nodes[tile_index].level
		var next_level = current_level + 1
		if next_level <= GameConstants.MAX_LEVEL:
			var current_value = GameConstants.LEVEL_VALUES.get(current_level, 0)
			var next_value = GameConstants.LEVEL_VALUES.get(next_level, 0)
			return next_value - current_value
	return 0

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

func get_owner_land_count(owner_id: int) -> int:
	var count = 0
	for i in tile_nodes:
		if tile_nodes[i].owner_id == owner_id:
			count += 1
	return count

func update_all_tile_displays():
	if not tile_info_display:
		return
	
	for index in tile_nodes:
		var tile_info = get_tile_info(index)
		tile_info_display.update_display(index, tile_info)

# 2D互換用（PlayerInfoPanelから呼ばれる）
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

# === 移動処理（MovementController3Dに委譲） ===

func move_player_3d(player_id: int, steps: int):
	if movement_controller:
		movement_controller.move_player(player_id, steps)

func _on_movement_started(player_id: int):
	if ui_manager:
		ui_manager.phase_label.text = "移動中..."

func _on_movement_completed(player_id: int, final_tile: int):
	process_tile_landing(final_tile)

# === タイル到着処理 ===

func process_tile_landing(tile_index: int):
	if not tile_nodes.has(tile_index):
		emit_signal("tile_action_completed")
		return
	
	# 処理中フラグを立てる
	is_waiting_for_action = true
	
	var tile = tile_nodes[tile_index]
	var tile_info = get_tile_info(tile_index)
	
	# 特殊マス処理（neutralは通常タイルとして処理）
	if is_special_tile_type(tile.tile_type) and tile.tile_type != "neutral" and special_tile_system:
		special_tile_system.special_action_completed.connect(_on_special_action_completed, CONNECT_ONE_SHOT)
		special_tile_system.process_special_tile_3d(tile.tile_type, tile_index, current_player_index)
		return
	
	# 通常タイル処理（neutralマスも含む）
	process_normal_tile(tile, tile_info)

func _on_special_action_completed():
	# 重複防止
	if not is_waiting_for_action:
		return
	is_waiting_for_action = false
	emit_signal("tile_action_completed")

func process_normal_tile(tile: BaseTile, tile_info: Dictionary):
	if player_is_cpu[current_player_index]:
		process_cpu_action(tile, tile_info)
		return
	
	# 人間プレイヤーの処理
	if tile_info["owner"] == -1:
		show_summon_ui()
	elif tile_info["owner"] == current_player_index:
		if tile.level < GameConstants.MAX_LEVEL:
			show_level_up_ui(tile_info)
		else:
			# レベルMAXの自分の土地
			is_waiting_for_action = false  # フラグをリセット
			emit_signal("tile_action_completed")
	else:
		if tile_info.get("creature", {}).is_empty():
			show_battle_ui("invasion")
		else:
			show_battle_ui("battle")

# === CPU処理 ===

func process_cpu_action(tile: BaseTile, tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	await get_tree().create_timer(0.5).timeout
	
	_cleanup_cpu_connections()
	
	if tile_info["owner"] == -1:
		if card_system.get_hand_size_for_player(current_player.id) > 0:
			cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided, CONNECT_ONE_SHOT)
			cpu_ai_handler.decide_summon(current_player)
		else:
			is_waiting_for_action = false  # フラグをリセット
			emit_signal("tile_action_completed")
	elif tile_info["owner"] == current_player.id:
		if tile.level < GameConstants.MAX_LEVEL:
			cpu_ai_handler.level_up_decided.connect(_on_cpu_level_up_decided, CONNECT_ONE_SHOT)
			cpu_ai_handler.decide_level_up(current_player, tile_info)
		else:
			is_waiting_for_action = false  # フラグをリセット
			emit_signal("tile_action_completed")
	elif tile_info["owner"] != current_player.id:
		if tile_info.get("creature", {}).is_empty():
			cpu_ai_handler.battle_decided.connect(_on_cpu_invasion_decided, CONNECT_ONE_SHOT)
			cpu_ai_handler.decide_invasion(current_player, tile_info)
		else:
			cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided, CONNECT_ONE_SHOT)
			cpu_ai_handler.decide_battle(current_player, tile_info)
	else:
		is_waiting_for_action = false  # フラグをリセット
		emit_signal("tile_action_completed")

func _cleanup_cpu_connections():
	if not cpu_ai_handler:
		return
	
	var callables = [
		Callable(self, "_on_cpu_summon_decided"),
		Callable(self, "_on_cpu_battle_decided"),
		Callable(self, "_on_cpu_invasion_decided"),
		Callable(self, "_on_cpu_level_up_decided")
	]
	
	if cpu_ai_handler.summon_decided.is_connected(callables[0]):
		cpu_ai_handler.summon_decided.disconnect(callables[0])
	if cpu_ai_handler.battle_decided.is_connected(callables[1]):
		cpu_ai_handler.battle_decided.disconnect(callables[1])
	if cpu_ai_handler.battle_decided.is_connected(callables[2]):
		cpu_ai_handler.battle_decided.disconnect(callables[2])
	if cpu_ai_handler.level_up_decided.is_connected(callables[3]):
		cpu_ai_handler.level_up_decided.disconnect(callables[3])

# === UI表示 ===

func show_summon_ui():
	is_waiting_for_action = true
	if ui_manager:
		ui_manager.phase_label.text = "召喚するクリーチャーを選択"
		ui_manager.show_card_selection_ui(player_system.get_current_player())
		card_system.set_cards_selectable(true)

func show_level_up_ui(tile_info: Dictionary):
	is_waiting_for_action = true
	if ui_manager:
		var current_magic = player_system.get_magic(current_player_index)
		ui_manager.show_level_up_ui(tile_info, current_magic)

func show_battle_ui(mode: String):
	is_waiting_for_action = true
	if ui_manager:
		if mode == "invasion":
			ui_manager.phase_label.text = "侵略するクリーチャーを選択"
		else:
			ui_manager.phase_label.text = "バトルするクリーチャーを選択"
		ui_manager.show_card_selection_ui(player_system.get_current_player())
		card_system.set_cards_selectable(true)

# === アクション処理 ===

func on_card_selected(card_index: int):
	if not is_waiting_for_action:
		return
	
	is_waiting_for_action = false  # フラグをfalseにする
	var current_tile = movement_controller.get_player_tile(current_player_index)
	var tile_info = get_tile_info(current_tile)
	
	if tile_info["owner"] == -1 or tile_info["owner"] == current_player_index:
		# 召喚処理（execute_summon内でtile_action_completedが発行される）
		execute_summon(card_index)
	else:
		# バトル処理（_on_invasion_completedでtile_action_completedが発行される）
		var callable = Callable(self, "_on_invasion_completed")
		if not battle_system.invasion_completed.is_connected(callable):
			battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
		
		battle_system.execute_3d_battle(current_player_index, card_index, tile_info)

func _on_invasion_completed(success: bool, tile_index: int):
	print("バトル結果受信: success=", success, " tile=", tile_index)
	
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	# tile_action_completedを発行
	emit_signal("tile_action_completed")

func execute_summon(card_index: int):
	if card_index < 0:
		emit_signal("tile_action_completed")
		return
	
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	if card_data.is_empty():
		emit_signal("tile_action_completed")
		return
	
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		
		var current_tile = movement_controller.get_player_tile(current_player_index)
		set_tile_owner(current_tile, current_player_index)
		place_creature(current_tile, card_data)
		
		print("召喚成功！土地を取得しました")
		
		if ui_manager:
			ui_manager.hide_card_selection_ui()
			ui_manager.update_player_info_panels()
	else:
		print("魔力不足で召喚できません")
	
	emit_signal("tile_action_completed")

func on_action_pass():
	if not is_waiting_for_action:
		return
	
	is_waiting_for_action = false
	var current_tile = movement_controller.get_player_tile(current_player_index)
	var tile_info = get_tile_info(current_tile)
	
	if tile_info["owner"] != -1 and tile_info["owner"] != current_player_index:
		var toll = calculate_toll(tile_info["index"])
		player_system.pay_toll(current_player_index, tile_info["owner"], toll)
		print("通行料 ", toll, "G を支払いました")
	
	emit_signal("tile_action_completed")

func on_level_up_selected(target_level: int, cost: int):
	if not is_waiting_for_action:
		return
	
	is_waiting_for_action = false
	
	if target_level == 0 or cost == 0:
		# キャンセル
		emit_signal("tile_action_completed")
		return
	
	var current_tile = movement_controller.get_player_tile(current_player_index)
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# レベルアップ実行
		var tile = tile_nodes[current_tile]
		tile.set_level(target_level)
		player_system.add_magic(current_player_index, -cost)
		
		# 表示更新
		if tile_info_display:
			tile_info_display.update_display(current_tile, get_tile_info(current_tile))
		
		if ui_manager:
			ui_manager.update_player_info_panels()
			ui_manager.hide_level_up_ui()
		
		print("土地をレベル", target_level, "にアップグレード！（コスト: ", cost, "G）")
	
	emit_signal("tile_action_completed")

# === CPUコールバック ===

func _on_cpu_summon_decided(card_index: int):
	if card_index >= 0:
		execute_summon(card_index)
	else:
		is_waiting_for_action = false  # フラグをリセット
		emit_signal("tile_action_completed")

func _on_cpu_invasion_decided(card_index: int):
	var current_tile = movement_controller.get_player_tile(current_player_index)
	var tile_info = get_tile_info(current_tile)
	
	if not battle_system.invasion_completed.is_connected(_on_invasion_completed):
		battle_system.invasion_completed.connect(_on_invasion_completed, CONNECT_ONE_SHOT)
	
	battle_system.execute_3d_battle(current_player_index, card_index, tile_info)

func _on_cpu_battle_decided(card_index: int):
	_on_cpu_invasion_decided(card_index)

func _on_cpu_level_up_decided(do_upgrade: bool):
	if do_upgrade:
		var current_tile = movement_controller.get_player_tile(current_player_index)
		var cost = get_upgrade_cost(current_tile)
		if player_system.get_current_player().magic_power >= cost:
			upgrade_tile_level(current_tile)
			player_system.add_magic(current_player_index, -cost)
			
			if tile_info_display:
				update_all_tile_displays()
			if ui_manager:
				ui_manager.update_player_info_panels()
	
	is_waiting_for_action = false  # フラグをリセット
	emit_signal("tile_action_completed")
