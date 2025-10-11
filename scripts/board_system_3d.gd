extends Node
class_name BoardSystem3D

# 3Dボード管理システム - スリム化版
# サブシステムへの処理委譲に特化

signal tile_action_completed()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# サブシステム
var movement_controller: MovementController3D
var tile_info_display: TileInfoDisplay
var tile_data_manager: TileDataManager
var tile_neighbor_system: TileNeighborSystem
var tile_action_processor: TileActionProcessor
var cpu_turn_processor: CPUTurnProcessor

# ゲーム設定
var player_count = 2
var player_is_cpu = [false, true]
var current_player_index = 0
var debug_manual_control_all: bool = false  # GameFlowManagerから設定される

# 状態管理
var is_waiting_for_action = false

# 3Dノード参照
var tile_nodes = {}        # tile_index -> BaseTile
var player_nodes = []      # 3D駒のノード配列
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
	create_subsystems()

func create_subsystems():
	# 既存のサブシステム
	tile_info_display = TileInfoDisplay.new()
	tile_info_display.name = "TileInfoDisplay"
	add_child(tile_info_display)
	
	movement_controller = MovementController3D.new()
	movement_controller.name = "MovementController3D"
	add_child(movement_controller)
	
	# 新規サブシステム
	tile_data_manager = TileDataManager.new()
	tile_data_manager.name = "TileDataManager"
	add_child(tile_data_manager)
	
	tile_neighbor_system = TileNeighborSystem.new()
	tile_neighbor_system.name = "TileNeighborSystem"
	add_child(tile_neighbor_system)
	
	tile_action_processor = TileActionProcessor.new()
	tile_action_processor.name = "TileActionProcessor"
	add_child(tile_action_processor)
	
	cpu_turn_processor = CPUTurnProcessor.new()
	cpu_turn_processor.name = "CPUTurnProcessor"
	add_child(cpu_turn_processor)
	
	# シグナル接続
	movement_controller.movement_started.connect(_on_movement_started)
	movement_controller.movement_completed.connect(_on_movement_completed)
	tile_action_processor.action_completed.connect(_on_action_completed)
	cpu_turn_processor.cpu_action_completed.connect(_on_action_completed)

func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BattleSystem, 
				   s_system: SkillSystem, st_system: SpecialTileSystem = null):
	player_system = p_system
	card_system = c_system
	battle_system = b_system
	skill_system = s_system
	special_tile_system = st_system
	
	# CPUAIHandlerを先に設定（他のシステムが依存するため）
	setup_cpu_ai_handler()
	
	# BattleSystemに参照を設定
	if battle_system.has_method("setup_systems"):
		battle_system.setup_systems(self, card_system, player_system)
	
	# MovementControllerに参照を設定
	if movement_controller:
		movement_controller.setup_systems(player_system, special_tile_system)
	
	# TileDataManagerに参照を設定
	tile_data_manager.set_display_system(tile_info_display)
	
	# ui_managerが設定されてからサブシステムを初期化
	await get_tree().process_frame
	
	# TileActionProcessorに参照を設定（ui_manager必須）
	if ui_manager:
		tile_action_processor.setup(self, player_system, card_system, 
									battle_system, special_tile_system, ui_manager)
		tile_action_processor.set_cpu_processor(cpu_turn_processor)
		
		# CPUTurnProcessorに参照を設定
		cpu_turn_processor.setup(self, cpu_ai_handler, player_system, 
								card_system, ui_manager)

func setup_cpu_ai_handler():
	cpu_ai_handler = get_node_or_null("CPUAIHandler")
	if not cpu_ai_handler:
		cpu_ai_handler = CPUAIHandler.new()
		cpu_ai_handler.name = "CPUAIHandler"
		add_child(cpu_ai_handler)
	
	if cpu_ai_handler.has_method("setup_systems"):
		cpu_ai_handler.setup_systems(card_system, self, player_system, battle_system, skill_system)

# === 3Dノード収集 ===

func collect_tiles(tiles_container: Node):
	for child in tiles_container.get_children():
		if child is BaseTile:
			tile_nodes[child.tile_index] = child
	
	# サブシステムに渡す
	tile_data_manager.set_tile_nodes(tile_nodes)
	movement_controller.tile_nodes = tile_nodes
	
	if tile_info_display:
		tile_info_display.setup_labels(tile_nodes, self)
	
	# 隣接システムの初期化
	if tile_neighbor_system:
		tile_neighbor_system.setup(tile_nodes)
	
	tile_data_manager.update_all_displays()

func collect_players(players_container: Node):
	player_nodes = players_container.get_children()
	
	if movement_controller:
		movement_controller.initialize(tile_nodes, player_nodes, camera)
		
		# 初期配置
		for i in range(player_nodes.size()):
			movement_controller.place_player_at_tile(i, 0)

# === タイルデータ管理（TileDataManagerに委譲） ===

func get_tile_info(tile_index: int) -> Dictionary:
	return tile_data_manager.get_tile_info(tile_index)

func get_tile_type(tile_type_str: String) -> int:
	return tile_data_manager.get_tile_type(tile_type_str)

func is_special_tile_type(tile_type: String) -> bool:
	return tile_data_manager.is_special_tile_type(tile_type)

func set_tile_owner(tile_index: int, owner_id: int):
	tile_data_manager.set_tile_owner(tile_index, owner_id)

func place_creature(tile_index: int, creature_data: Dictionary):
	tile_data_manager.place_creature(tile_index, creature_data)

func upgrade_tile_level(tile_index: int) -> bool:
	return tile_data_manager.upgrade_tile_level(tile_index)

func get_upgrade_cost(tile_index: int) -> int:
	return tile_data_manager.get_upgrade_cost(tile_index)

func calculate_toll(tile_index: int) -> int:
	return tile_data_manager.calculate_toll(tile_index)

func calculate_chain_bonus(tile_index: int, owner_id: int) -> float:
	return tile_data_manager.calculate_chain_bonus(tile_index, owner_id)

func get_element_chain_count(tile_index: int, owner_id: int) -> int:
	return tile_data_manager.get_element_chain_count(tile_index, owner_id)

func get_owner_land_count(owner_id: int) -> int:
	return tile_data_manager.get_owner_land_count(owner_id)

func get_player_lands_by_element(player_id: int) -> Dictionary:
	return tile_data_manager.get_owner_element_counts(player_id)

func update_all_tile_displays():
	tile_data_manager.update_all_displays()

func get_tile_data_array() -> Array:
	return tile_data_manager.get_tile_data_array()

# === 移動処理（MovementController3Dに委譲） ===

func move_player_3d(player_id: int, steps: int):
	if movement_controller:
		movement_controller.move_player(player_id, steps)

func _on_movement_started(_player_id: int):
	if ui_manager:
		ui_manager.phase_label.text = "移動中..."

func _on_movement_completed(_player_id: int, final_tile: int):
	process_tile_landing(final_tile)

# === タイルアクション処理（TileActionProcessorに委譲） ===

func process_tile_landing(tile_index: int):
	is_waiting_for_action = true
	tile_action_processor.process_tile_landing(tile_index, current_player_index, player_is_cpu, debug_manual_control_all)

func on_card_selected(card_index: int):
	tile_action_processor.on_card_selected(card_index)

func on_action_pass():
	tile_action_processor.on_action_pass()

func on_level_up_selected(target_level: int, cost: int):
	tile_action_processor.on_level_up_selected(target_level, cost)

func _on_action_completed():
	# 既に処理済みの場合はスキップ
	if not is_waiting_for_action:
		return
		
	is_waiting_for_action = false
	emit_signal("tile_action_completed")
