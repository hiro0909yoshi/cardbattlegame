extends Node
class_name GameSystemManager

# ゲームシステム統括管理者
# 全システムの作成・初期化・連携を一元管理する
# 6フェーズ初期化により、複雑な初期化プロセスを明確化

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const SpellCurseTollClass = preload("res://scripts/spells/spell_curse_toll.gd")

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

# === 親ノード参照 ===
var parent_node: Node

# 初期化完了フラグ
var is_initialized: bool = false

func _ready():
	print("[GameSystemManager] 作成完了")

# === 公開インターフェース ===

# 全フェーズを実行
func initialize_all(p_node: Node, p_count: int, p_is_cpu: Array, debug_mode: bool) -> void:
	parent_node = p_node
	player_count = p_count
	player_is_cpu = p_is_cpu
	debug_manual_control_all = debug_mode
	
	print("[GameSystemManager] 初期化開始（6フェーズ）")
	
	phase_1_create_systems()
	phase_2_collect_3d_nodes()
	phase_3_setup_basic_config()
	phase_4_setup_system_interconnections()
	phase_5_connect_signals()
	phase_6_prepare_game_start()
	
	is_initialized = true
	print("[GameSystemManager] 初期化完了")

# ゲーム開始
func start_game() -> void:
	if not is_initialized:
		push_error("[GameSystemManager] 初期化されていません")
		return
	
	if game_flow_manager:
		game_flow_manager.start_game()

# === フェーズ実装 ===

# Phase 1: システム作成
func phase_1_create_systems() -> void:
	print("[GameSystemManager] Phase 1: システム作成開始")
	
	# SignalRegistry（最初に作成：他が参照する可能性）
	signal_registry = SignalRegistry.new()
	signal_registry.name = "SignalRegistry"
	add_child(signal_registry)
	systems["SignalRegistry"] = signal_registry
	
	# BoardSystem3D
	var BoardSystem3DClass = load("res://scripts/board_system_3d.gd")
	board_system_3d = BoardSystem3DClass.new()
	board_system_3d.name = "BoardSystem3D"
	add_child(board_system_3d)
	systems["BoardSystem3D"] = board_system_3d
	
	# PlayerSystem
	player_system = PlayerSystem.new()
	player_system.name = "PlayerSystem"
	add_child(player_system)
	systems["PlayerSystem"] = player_system
	
	# CardSystem
	card_system = CardSystem.new()
	card_system.name = "CardSystem"
	add_child(card_system)
	systems["CardSystem"] = card_system
	
	# BattleSystem
	battle_system = BattleSystem.new()
	battle_system.name = "BattleSystem"
	add_child(battle_system)
	systems["BattleSystem"] = battle_system
	
	# PlayerBuffSystem
	player_buff_system = PlayerBuffSystem.new()
	player_buff_system.name = "PlayerBuffSystem"
	add_child(player_buff_system)
	systems["PlayerBuffSystem"] = player_buff_system
	
	# SpecialTileSystem
	special_tile_system = SpecialTileSystem.new()
	special_tile_system.name = "SpecialTileSystem"
	add_child(special_tile_system)
	systems["SpecialTileSystem"] = special_tile_system
	
	# UIManager
	ui_manager = UIManager.new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	systems["UIManager"] = ui_manager
	
	# DebugController
	debug_controller = DebugController.new()
	debug_controller.name = "DebugController"
	add_child(debug_controller)
	systems["DebugController"] = debug_controller
	
	# GameFlowManager
	game_flow_manager = GameFlowManager.new()
	game_flow_manager.name = "GameFlowManager"
	add_child(game_flow_manager)
	systems["GameFlowManager"] = game_flow_manager
	
	print("[GameSystemManager] Phase 1: システム作成完了（11個）")

# Phase 2: 3D ノード収集
func phase_2_collect_3d_nodes() -> void:
	print("[GameSystemManager] Phase 2: 3D ノード収集")
	
	if not parent_node:
		push_error("[GameSystemManager] parent_node が設定されていません")
		return
	
	tiles_container = parent_node.get_node_or_null("Tiles")
	players_container = parent_node.get_node_or_null("Players")
	camera_3d = parent_node.get_node_or_null("Camera3D")
	# ui_layer は create_ui() で作成される
	
	var all_found = tiles_container and players_container and camera_3d
	
	if all_found:
		print("[GameSystemManager] Phase 2: 3D ノード収集完了")
	else:
		push_warning("[GameSystemManager] WARNING: 一部の3Dノードが見つかりません")
		if not tiles_container:
			print("  - Tiles が見つかりません")
		if not players_container:
			print("  - Players が見つかりません")
		if not camera_3d:
			print("  - Camera3D が見つかりません")

# Phase 3: システム基本設定
func phase_3_setup_basic_config() -> void:
	print("[GameSystemManager] Phase 3: システム基本設定")
	
	# PlayerSystem初期化
	if player_system:
		player_system.initialize_players(player_count)
	
	# BoardSystem3D基本設定
	if board_system_3d and camera_3d:
		# カメラ初期位置設定
		camera_3d.position = GameConstants.CAMERA_OFFSET
		
		# カメラ参照を最初に設定（重要：collect_players()内で使用される）
		board_system_3d.camera = camera_3d
		board_system_3d.player_count = player_count
		board_system_3d.player_is_cpu = player_is_cpu
		board_system_3d.current_player_index = 0
		
		# 3D ノード収集
		if tiles_container:
			board_system_3d.collect_tiles(tiles_container)
		if players_container:
			# collect_players() はカメラ参照を必要とする
			board_system_3d.collect_players(players_container)
			
			# === カメラをプレイヤーに向かせる ===
			if board_system_3d.player_nodes and board_system_3d.player_nodes.size() > 0:
				var current_player_node = board_system_3d.player_nodes[0]  # プレイヤー0（現在のプレイヤー）
				var player_look_target = current_player_node.global_position
				player_look_target.y += 1.0  # 頭方向に向かせる
				
				camera_3d.look_at(player_look_target, Vector3.UP)
	
	print("[GameSystemManager] Phase 3: システム基本設定完了")

# Phase 4: システム間連携設定
func phase_4_setup_system_interconnections() -> void:
	print("[GameSystemManager] Phase 4: システム間連携設定開始")
	
	# ===== 4-1: 基本システム参照設定 =====
	print("[GameSystemManager] Phase 4-1: 基本システム参照設定")
	
	# Step 1: GameFlowManager に全システムを設定
	if game_flow_manager:
		game_flow_manager.setup_systems(
			player_system, card_system, board_system_3d, player_buff_system,
			ui_manager, battle_system, special_tile_system
		)
	
	# Step 2: BoardSystem3D に全システムを設定
	if board_system_3d:
		board_system_3d.setup_systems(
			player_system, card_system, battle_system, player_buff_system,
			special_tile_system, game_flow_manager
		)
		board_system_3d.ui_manager = ui_manager
	
	# Step 3: SpecialTileSystem に必要なシステムを設定
	if special_tile_system:
		special_tile_system.setup_systems(
			board_system_3d, card_system, player_system, ui_manager
		)
	
	# Step 4: DebugController に設定
	if debug_controller:
		debug_controller.setup_systems(
			player_system, board_system_3d, card_system, ui_manager
		)
		player_system.set_debug_controller(debug_controller)
	
	# Step 5: UIManager に参照を設定
	if ui_manager:
		ui_manager.board_system_ref = board_system_3d
		ui_manager.player_system_ref = player_system
		ui_manager.card_system_ref = card_system
		ui_manager.game_flow_manager_ref = game_flow_manager
	
	# Step 10: UIManager.create_ui() 実行（全参照設定後）
	if ui_manager and parent_node:
		ui_manager.create_ui(parent_node)
		# 作成されたUILayerを参照
		ui_layer = parent_node.get_node_or_null("UILayer")
	
	# Step 7: CardSelectionUI に設定
	if ui_manager and ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager
	
	# Step 8: BattleSystem に設定
	if battle_system:
		battle_system.game_flow_manager_ref = game_flow_manager
	
	# Step 9: GameFlowManager の 3D 設定
	if game_flow_manager:
		game_flow_manager.debug_manual_control_all = debug_manual_control_all
		game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)
	
	print("[GameSystemManager] Phase 4-1: 基本システム参照設定完了")
	
	# ===== 4-2: GameFlowManager 子システム初期化 =====
	# 注記: Spell系は GameFlowManager._setup_spell_systems() で既に作成・初期化されている
	# ここではハンドラーの参照設定のみを行う
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム参照設定")
	
	if game_flow_manager:
		# LandCommandHandler の初期化
		if game_flow_manager.land_command_handler:
			game_flow_manager.land_command_handler.board_system_3d = board_system_3d
			game_flow_manager.land_command_handler.player_system = player_system
			game_flow_manager.land_command_handler.ui_manager = ui_manager
		
		# SpellPhaseHandler の初期化
		if game_flow_manager.spell_phase_handler:
			game_flow_manager.spell_phase_handler.board_system_3d = board_system_3d
			game_flow_manager.spell_phase_handler.game_flow_manager = game_flow_manager
			game_flow_manager.spell_phase_handler.ui_manager = ui_manager
		
		# ItemPhaseHandler の初期化
		if game_flow_manager.item_phase_handler:
			game_flow_manager.item_phase_handler.board_system_3d = board_system_3d
			game_flow_manager.item_phase_handler.player_system = player_system
			game_flow_manager.item_phase_handler.ui_manager = ui_manager
		
		# SpellCurseToll の初期化
		if game_flow_manager.spell_curse:
			# SkillTollChange の作成
			var skill_toll_change = preload("res://scripts/skills/skill_toll_change.gd").new()
			
			# CreatureManager の取得（BoardSystem3D 配下から動的に取得）
			var creature_manager = null
			if board_system_3d:
				# board_system_3d の子ノードから CreatureManager を検索
				creature_manager = board_system_3d.get_node_or_null("CreatureManager")
			
			# SpellCurseToll の初期化
			game_flow_manager.spell_curse_toll = SpellCurseTollClass.new()
			game_flow_manager.spell_curse_toll.setup(
				game_flow_manager.spell_curse,
				skill_toll_change,
				creature_manager
			)
			game_flow_manager.spell_curse_toll.name = "SpellCurseToll"
			game_flow_manager.add_child(game_flow_manager.spell_curse_toll)
			print("[SpellCurseToll] 初期化完了（SkillTollChange と CreatureManager 参照設定済み）")
			
			# ★重要: board_system_3d にメタデータとして設定（MovementHelper から参照可能にする）
			if board_system_3d:
				board_system_3d.set_meta("spell_curse_toll", game_flow_manager.spell_curse_toll)
				print("[SpellCurseToll] BoardSystem3D のメタデータとして設定完了")
		
		# CPUAIHandler の初期化（setup_systems で行われる）
		# GameFlowManager._ready() で既に初期化済みなため、ここでは参照設定のみ
	
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム初期化完了")
	
	# ===== 4-3: BoardSystem3D 子システム初期化 =====
	# 注記: BoardSystem3D._ready() で既に全子システムが作成・初期化済みのため、
	# GameSystemManager では参照設定は不要
	print("[GameSystemManager] Phase 4-3: BoardSystem3D 子システム初期化完了（既に初期化済み）")
	
	# ===== 4-4: 特別な初期化 =====
	print("[GameSystemManager] Phase 4-4: 特別な初期化")
	
	# GameFlowManager の最終初期化
	if game_flow_manager:
		game_flow_manager.initialize_phase1a_systems()
	
	# 手札UIを初期化
	if ui_manager and ui_layer:
		ui_manager.initialize_hand_container(ui_layer)
		ui_manager.connect_card_system_signals()
	
	print("[GameSystemManager] Phase 4: システム間連携設定完了")

# Phase 5: シグナル接続
func phase_5_connect_signals() -> void:
	print("[GameSystemManager] Phase 5: シグナル接続")
	
	# GameFlowManager のシグナル
	if game_flow_manager:
		game_flow_manager.dice_rolled.connect(_on_dice_rolled)
		game_flow_manager.turn_started.connect(_on_turn_started)
		game_flow_manager.turn_ended.connect(_on_turn_ended)
		game_flow_manager.phase_changed.connect(_on_phase_changed)
	
	# PlayerSystem のシグナル
	if player_system and game_flow_manager:
		player_system.player_won.connect(game_flow_manager.on_player_won)
	
	# UIManager のシグナル
	if ui_manager and game_flow_manager:
		ui_manager.dice_button_pressed.connect(game_flow_manager.roll_dice)
		ui_manager.card_selected.connect(game_flow_manager.on_card_selected)
		ui_manager.pass_button_pressed.connect(game_flow_manager.on_pass_button_pressed)
		ui_manager.level_up_selected.connect(game_flow_manager.on_level_up_selected)
		ui_manager.land_command_button_pressed.connect(game_flow_manager.open_land_command)
	
	print("[GameSystemManager] Phase 5: シグナル接続完了")

# Phase 6: ゲーム開始準備
func phase_6_prepare_game_start() -> void:
	print("[GameSystemManager] Phase 6: ゲーム開始準備")
	
	# 初期手札配布
	if card_system:
		card_system.deal_initial_hands_all_players(player_count)
	
	# UI更新
	if ui_manager:
		await get_tree().create_timer(0.1).timeout
		ui_manager.update_player_info_panels()
	
	# 操作説明を表示
	_print_controls_help()
	
	print("[GameSystemManager] Phase 6: ゲーム開始準備完了")
	


# === ヘルパーメソッド ===

func _print_controls_help() -> void:
	print("\n=== 操作方法 ===")
	print("【V】キー: 通行料/HP/ST表示切替")
	print("【S】キー: シグナル接続状態を表示")
	print("【D】キー: デバッグモード切替")
	print("【数字1-6】: サイコロ固定（デバッグ）")
	print("【0】キー: サイコロ固定解除")
	print("================\n")

# === イベントハンドラ ===

func _on_dice_rolled(value: int) -> void:
	if ui_manager:
		ui_manager.show_dice_result(value, parent_node)

func _on_turn_started(player_id: int) -> void:
	print("\n=== プレイヤー", player_id + 1, "のターン ===")

func _on_turn_ended(_player_id: int) -> void:
	pass  # 必要に応じて処理追加

func _on_phase_changed(_new_phase) -> void:
	pass  # 必要に応じて処理追加
