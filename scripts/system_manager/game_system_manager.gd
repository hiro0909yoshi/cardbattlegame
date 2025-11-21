class_name GameSystemManager
extends Node

# === ゲームシステム初期化マネージャー ===
# 目的: game_3d.gd の複雑な初期化ロジックを一元管理
# 責務: 全システムの作成・初期化・参照設定・シグナル接続
#
# 6フェーズ初期化方式:
#   Phase 1: システム作成
#   Phase 2: 3D ノード収集
#   Phase 3: システム基本設定
#   Phase 4: システム間連携設定
#   Phase 5: シグナル接続
#   Phase 6: ゲーム開始準備

# === システム参照 ===
var systems: Dictionary = {}

# 個別参照（アクセス便宜用）
var signal_registry: SignalRegistry
var board_system_3d: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var player_buff_system: PlayerBuffSystem
var special_tile_system: SpecialTileSystem
var ui_manager: UIManager
var debug_controller: DebugController
var game_flow_manager: GameFlowManager

# === 設定 ===
var player_count: int = 2
var player_is_cpu: Array = [false, true]
var debug_manual_control_all: bool = true

# === 3D シーンノード ===
var tiles_container: Node
var players_container: Node
var camera_3d: Camera3D
var ui_layer: CanvasLayer

# === 親ノード（game_3d） ===
var parent_node: Node

# === Phase 1: システム作成 ===
func phase_1_create_systems() -> void:
	print("[GameSystemManager] Phase 1: システム作成開始")
	
	# システム作成順序（重要：依存関係順）
	_create_signal_registry()      # 最初（他が使う可能性）
	_create_board_system_3d()
	_create_player_system()
	_create_card_system()
	_create_battle_system()
	_create_player_buff_system()
	_create_special_tile_system()
	_create_ui_manager()
	_create_debug_controller()
	_create_game_flow_manager()
	
	print("[GameSystemManager] Phase 1: システム作成完了（10個）")

# === Phase 2: 3D ノード収集 ===
func phase_2_collect_3d_nodes(parent: Node) -> bool:
	print("[GameSystemManager] Phase 2: 3D ノード収集")
	
	parent_node = parent
	tiles_container = parent.get_node_or_null("Tiles")
	players_container = parent.get_node_or_null("Players")
	camera_3d = parent.get_node_or_null("Camera3D")
	ui_layer = parent.get_node_or_null("UILayer")
	
	var all_found = (tiles_container != null) and (players_container != null) and (camera_3d != null) and (ui_layer != null)
	
	if all_found:
		print("[GameSystemManager] Phase 2: 3D ノード収集完了")
	else:
		print("[GameSystemManager] WARNING: 一部の3Dノードが見つかりません")
		print("  Tiles: ", tiles_container != null)
		print("  Players: ", players_container != null)
		print("  Camera3D: ", camera_3d != null)
		print("  UILayer: ", ui_layer != null)
	
	return all_found

# === Phase 3: システム基本設定 ===
func phase_3_setup_basic_config() -> void:
	print("[GameSystemManager] Phase 3: システム基本設定")
	
	# PlayerSystem
	player_system.initialize_players(player_count)
	
	# BoardSystem3D
	board_system_3d.camera = camera_3d
	board_system_3d.player_count = player_count
	board_system_3d.player_is_cpu = player_is_cpu
	board_system_3d.current_player_index = 0
	
	# 3D ノード収集
	if tiles_container:
		board_system_3d.collect_tiles(tiles_container)
	if players_container:
		board_system_3d.collect_players(players_container)
	
	# UIManager をUILayerに移動
	if ui_layer:
		remove_child(ui_manager)
		ui_layer.add_child(ui_manager)
		print("  [UIManager] UILayerに移動完了")
	else:
		print("[GameSystemManager] WARNING: UILayerが見つかりません。UIManagerはGameSystemManagerの子のままです")
	
	print("[GameSystemManager] Phase 3: システム基本設定完了")

# === Phase 4: システム間連携設定 ===
func phase_4_setup_system_interconnections() -> void:
	print("[GameSystemManager] Phase 4: システム間連携設定開始")
	
	# ===== 4-1: 基本システム参照設定 =====
	print("[GameSystemManager] Phase 4-1: 基本システム参照設定")
	
	# Step 1: GameFlowManager に全システムを設定
	game_flow_manager.setup_systems(
		player_system, card_system, board_system_3d,
		player_buff_system, ui_manager, battle_system, special_tile_system
	)
	
	# Step 2: BoardSystem3D に全システムを設定
	board_system_3d.setup_systems(
		player_system, card_system, battle_system,
		player_buff_system, special_tile_system, game_flow_manager
	)
	board_system_3d.ui_manager = ui_manager
	
	# Step 3: SpecialTileSystem に必要なシステムを設定
	special_tile_system.setup_systems(
		board_system_3d, card_system, player_system, ui_manager
	)
	
	# Step 4: DebugController に設定
	debug_controller.setup_systems(
		player_system, board_system_3d, card_system, ui_manager
	)
	player_system.set_debug_controller(debug_controller)
	
	# Step 5: UIManager に参照を再設定（Phase 3 後の設定）
	ui_manager.board_system_ref = board_system_3d
	ui_manager.player_system_ref = player_system
	ui_manager.card_system_ref = card_system
	ui_manager.game_flow_manager_ref = game_flow_manager
	
	# Step 6: CardSelectionUI に設定
	if ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager
	
	# Step 7: BattleSystem に設定
	if battle_system:
		battle_system.game_flow_manager_ref = game_flow_manager
	
	# Step 8: GameFlowManager の 3D 設定
	game_flow_manager.debug_manual_control_all = debug_manual_control_all
	game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)
	
	# Step 9: UIManager の最終初期化（全システム参照が揃った後）
	if ui_layer:
		ui_manager.initialize_hand_container(ui_layer)
	
	# プレイヤー情報パネルの初期化
	if ui_manager.has_method("update_player_info_panels"):
		ui_manager.update_player_info_panels()
	
	print("[GameSystemManager] Phase 4-1: 基本システム参照設定完了")

	# ===== 4-2: GameFlowManager 子システム初期化 =====
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム初期化")
	
	# Step 10: SpellDraw の初期化
	if game_flow_manager.spell_draw:
		game_flow_manager.spell_draw.setup(card_system)
	
	# Step 10: SpellMagic の初期化
	# 依存: player_system
	if game_flow_manager.spell_magic:
		game_flow_manager.spell_magic.setup(player_system)
	
	# Step 11: SpellDice の初期化
	# 依存: player_system, spell_curse
	if game_flow_manager.spell_dice:
		game_flow_manager.spell_dice.setup(player_system, game_flow_manager.spell_curse)
	
	# Step 12: SpellCurse の初期化
	# 依存: board_system_3d, player_system
	if game_flow_manager.spell_curse:
		game_flow_manager.spell_curse.setup(board_system_3d, board_system_3d.creature_manager, player_system, game_flow_manager)
	
	# Step 13: SpellCurseStat の初期化
	# 依存: spell_curse, creature_manager
	if game_flow_manager.spell_curse_stat:
		game_flow_manager.spell_curse_stat.setup(game_flow_manager.spell_curse, board_system_3d.creature_manager)
	
	# Step 14: SpellLand の初期化（複雑な依存関係）
	# 依存: board_system_3d, player_system, card_system
	if game_flow_manager.spell_land:
		game_flow_manager.spell_land.setup(board_system_3d, board_system_3d.creature_manager, player_system, card_system)
	
	# Step 15: LandCommandHandler の初期化
	# 依存: board_system_3d, player_system, ui_manager
	if game_flow_manager.land_command_handler:
		game_flow_manager.land_command_handler.initialize(ui_manager, board_system_3d, game_flow_manager, player_system)
	
	# Step 16: SpellPhaseHandler の初期化
	# 依存: board_system_3d, game_flow_manager, ui_manager
	if game_flow_manager.spell_phase_handler:
		game_flow_manager.spell_phase_handler.initialize(ui_manager, game_flow_manager, card_system, player_system, board_system_3d)
	
	# Step 17: ItemPhaseHandler の初期化
	# 依存: game_flow_manager, card_system, player_system, battle_system
	if game_flow_manager.item_phase_handler:
		game_flow_manager.item_phase_handler.initialize(ui_manager, game_flow_manager, card_system, player_system, battle_system)
	
	# Step 18: CPUAIHandler の初期化
	# 依存: card_system, board_system_3d, player_system, battle_system, player_buff_system
	if game_flow_manager.cpu_ai_handler:
		game_flow_manager.cpu_ai_handler.setup_systems(card_system, board_system_3d, player_system, battle_system, player_buff_system)
	
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム初期化完了")

	# ===== 4-3: BoardSystem3D 子システム初期化 =====
	print("[GameSystemManager] Phase 4-3: BoardSystem3D 子システム初期化")
	
	# BoardSystem3D内の子システムは既にsetup_systems()で初期化済み
	# (TileActionProcessor, CPUTurnProcessor, MovementControllerなど)
	# ここでは特に追加の初期化は不要（Phase 4-1で済み）
	
	print("[GameSystemManager] Phase 4-3: BoardSystem3D 子システム初期化完了")

	# ===== 4-4: 特別な初期化 =====
	print("[GameSystemManager] Phase 4-4: 特別な初期化")
	
	# Step 23: GameFlowManager の最終初期化
	game_flow_manager.initialize_phase1a_systems()
	
	print("[GameSystemManager] Phase 4: システム間連携設定完了")

# === Phase 5: シグナル接続 ===
func phase_5_connect_signals() -> void:
	print("[GameSystemManager] Phase 5: シグナル接続")
	
	# GameFlowManager のシグナル
	game_flow_manager.dice_rolled.connect(_on_dice_rolled)
	game_flow_manager.turn_started.connect(_on_turn_started)
	game_flow_manager.turn_ended.connect(_on_turn_ended)
	game_flow_manager.phase_changed.connect(_on_phase_changed)
	
	# PlayerSystem のシグナル
	player_system.player_won.connect(game_flow_manager.on_player_won)
	
	# UIManager のシグナル
	ui_manager.dice_button_pressed.connect(game_flow_manager.roll_dice)
	ui_manager.card_selected.connect(game_flow_manager.on_card_selected)
	ui_manager.pass_button_pressed.connect(game_flow_manager.on_pass_button_pressed)
	ui_manager.level_up_selected.connect(game_flow_manager.on_level_up_selected)
	ui_manager.land_command_button_pressed.connect(game_flow_manager.open_land_command)
	
	print("[GameSystemManager] Phase 5: シグナル接続完了")

# === Phase 6: ゲーム開始準備 ===
func phase_6_prepare_game_start() -> void:
	print("[GameSystemManager] Phase 6: ゲーム開始準備")
	
	# 初期手札配布
	await get_tree().create_timer(0.1).timeout
	card_system.deal_initial_hands_all_players(player_count)
	
	await get_tree().create_timer(0.1).timeout
	ui_manager.update_player_info_panels()
	
	# 操作説明を表示
	_print_controls_help()
	
	print("[GameSystemManager] Phase 6: ゲーム開始準備完了")

# === ヘルパーメソッド: システム作成 ===

func _create_signal_registry() -> void:
	signal_registry = SignalRegistry.new()
	signal_registry.name = "SignalRegistry"
	add_child(signal_registry)
	systems["signal_registry"] = signal_registry
	print("  [SignalRegistry] 作成完了")

func _create_board_system_3d() -> void:
	var BoardSystem3DClass = load("res://scripts/board_system_3d.gd")
	board_system_3d = BoardSystem3DClass.new()
	board_system_3d.name = "BoardSystem3D"
	add_child(board_system_3d)
	systems["board_system_3d"] = board_system_3d
	print("  [BoardSystem3D] 作成完了")

func _create_player_system() -> void:
	player_system = PlayerSystem.new()
	player_system.name = "PlayerSystem"
	add_child(player_system)
	systems["player_system"] = player_system
	print("  [PlayerSystem] 作成完了")

func _create_card_system() -> void:
	card_system = CardSystem.new()
	card_system.name = "CardSystem"
	add_child(card_system)
	systems["card_system"] = card_system
	print("  [CardSystem] 作成完了")

func _create_battle_system() -> void:
	battle_system = BattleSystem.new()
	battle_system.name = "BattleSystem"
	add_child(battle_system)
	systems["battle_system"] = battle_system
	print("  [BattleSystem] 作成完了")

func _create_player_buff_system() -> void:
	player_buff_system = PlayerBuffSystem.new()
	player_buff_system.name = "PlayerBuffSystem"
	add_child(player_buff_system)
	systems["player_buff_system"] = player_buff_system
	print("  [PlayerBuffSystem] 作成完了")

func _create_special_tile_system() -> void:
	special_tile_system = SpecialTileSystem.new()
	special_tile_system.name = "SpecialTileSystem"
	add_child(special_tile_system)
	systems["special_tile_system"] = special_tile_system
	print("  [SpecialTileSystem] 作成完了")

func _create_ui_manager() -> void:
	ui_manager = UIManager.new()
	ui_manager.name = "UIManager"
	# UIManagerはGameSystemManagerの子としてのみ一時的に追加
	# Phase 3でUILayerに移動される
	add_child(ui_manager)
	systems["ui_manager"] = ui_manager
	print("  [UIManager] 作成完了")

func _create_debug_controller() -> void:
	debug_controller = DebugController.new()
	debug_controller.name = "DebugController"
	add_child(debug_controller)
	systems["debug_controller"] = debug_controller
	print("  [DebugController] 作成完了")

func _create_game_flow_manager() -> void:
	game_flow_manager = GameFlowManager.new()
	game_flow_manager.name = "GameFlowManager"
	add_child(game_flow_manager)
	systems["game_flow_manager"] = game_flow_manager
	print("  [GameFlowManager] 作成完了")

# === ヘルパーメソッド: シグナルハンドラ ===

func _on_dice_rolled(value: int) -> void:
	ui_manager.show_dice_result(value, parent_node)

func _on_turn_started(player_id: int) -> void:
	print("\n=== プレイヤー", player_id + 1, "のターン ===")

func _on_turn_ended(_player_id: int) -> void:
	pass  # 必要に応じて処理追加

func _on_phase_changed(_new_phase) -> void:
	pass  # 必要に応じて処理追加

# === ヘルパーメソッド: その他 ===

func _print_controls_help() -> void:
	print("\n=== 操作方法 ===")
	print("【V】キー: 通行料/HP/ST表示切替")
	print("【S】キー: シグナル接続状態を表示")
	print("【D】キー: デバッグモード切替")
	print("【数字1-6】: サイコロ固定（デバッグ）")
	print("【0】キー: サイコロ固定解除")
	print("================\n")
