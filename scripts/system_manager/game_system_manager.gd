extends Node
class_name GameSystemManager

# ゲームシステム統括管理者
# 全システムの作成・初期化・連携を一元管理する
# 6フェーズ初期化により、複雑な初期化プロセスを明確化

# 定数をpreload
const SpellCurseTollClass = preload("res://scripts/spells/spell_curse_toll.gd")
const SpellCostModifierClass = preload("res://scripts/spells/spell_cost_modifier.gd")
const GameFlowManagerClass = preload("res://scripts/game_flow_manager.gd")
const BoardSystem3DClass = preload("res://scripts/board_system_3d.gd")
const PlayerSystemClass = preload("res://scripts/player_system.gd")
const CardSystemClass = preload("res://scripts/card_system.gd")
const BattleSystemClass = preload("res://scripts/battle_system.gd")
const PlayerBuffSystemClass = preload("res://scripts/player_buff_system.gd")
const DebugControllerClass = preload("res://scripts/debug_controller.gd")
const UIManagerClass = preload("res://scripts/ui_manager.gd")
const SpecialTileSystemClass = preload("res://scripts/special_tile_system.gd")

# === システム参照 ===
var systems: Dictionary = {}

# 個別参照（アクセス便宜用）
var signal_registry: SignalRegistry
var board_system_3d
var player_system
var card_system
var battle_system
var player_buff_system
var special_tile_system
var ui_manager
var debug_controller
var game_flow_manager

# === 設定 ===
var player_count: int = 2
var player_is_cpu: Array = [false, true]
var debug_manual_control_all: bool = true

# === 3D シーンノード ===
var tiles_container: Node
var players_container: Node
var camera_3d: Camera3D
var ui_layer: CanvasLayer
var camera_controller: CameraController

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
	board_system_3d = BoardSystem3DClass.new()
	board_system_3d.name = "BoardSystem3D"
	add_child(board_system_3d)
	systems["BoardSystem3D"] = board_system_3d
	
	# PlayerSystem
	player_system = PlayerSystemClass.new()
	player_system.name = "PlayerSystem"
	add_child(player_system)
	systems["PlayerSystem"] = player_system
	
	# CardSystem
	card_system = CardSystemClass.new()
	card_system.name = "CardSystem"
	add_child(card_system)
	systems["CardSystem"] = card_system
	
	# BattleSystem
	battle_system = BattleSystemClass.new()
	battle_system.name = "BattleSystem"
	add_child(battle_system)
	systems["BattleSystem"] = battle_system
	
	# PlayerBuffSystem
	player_buff_system = PlayerBuffSystemClass.new()
	player_buff_system.name = "PlayerBuffSystem"
	add_child(player_buff_system)
	systems["PlayerBuffSystem"] = player_buff_system
	
	# SpecialTileSystem
	special_tile_system = SpecialTileSystemClass.new()
	special_tile_system.name = "SpecialTileSystem"
	add_child(special_tile_system)
	systems["SpecialTileSystem"] = special_tile_system
	
	# UIManager
	ui_manager = UIManagerClass.new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	systems["UIManager"] = ui_manager
	
	# DebugController
	debug_controller = DebugControllerClass.new()
	debug_controller.name = "DebugController"
	add_child(debug_controller)
	systems["DebugController"] = debug_controller
	
	# GameFlowManager
	game_flow_manager = GameFlowManagerClass.new()
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
	
	# CardSystemを正しいプレイヤー数で再初期化
	if card_system and card_system.has_method("initialize_decks"):
		card_system.initialize_decks(player_count)
	
	# BoardSystem3D基本設定
	if board_system_3d and camera_3d:
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
			
			# プレイヤー配置が反映されるまで待つ
			await get_tree().process_frame
			
			# === カメラ初期位置をタイル位置基準で設定（移動時と同じ計算） ===
			if board_system_3d.tile_nodes.has(0):
				var tile_pos = board_system_3d.tile_nodes[0].global_position
				tile_pos.y += 1.0  # MOVE_HEIGHT
				var look_target = tile_pos + Vector3(0, 1.0, 0)
				
				# カメラ位置 = タイル位置 + オフセット（移動時と同じ）
				var cam_pos = tile_pos + GameConstants.CAMERA_OFFSET
				camera_3d.global_position = cam_pos
				camera_3d.look_at(look_target + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)
	
	# CameraController初期化
	if camera_3d and board_system_3d:
		camera_controller = CameraController.new()
		camera_controller.name = "CameraController"
		parent_node.add_child(camera_controller)
		camera_controller.setup(camera_3d, board_system_3d, player_system)
		# BoardSystem3D本体 + MovementControllerの両方に参照を設定
		board_system_3d.set_camera_controller_ref(camera_controller)
	
	print("[GameSystemManager] Phase 3: システム基本設定完了")

## カメラシグナル接続を遅延実行（Phase 3のawait完了後）
func _connect_camera_signals_deferred():
	# 次フレームで実行（Phase 3のawait完了を待つ）
	await get_tree().process_frame
	await get_tree().process_frame  # 念のため2フレーム待つ
	
	if ui_manager and board_system_3d:
		ui_manager.board_system_ref = board_system_3d
		ui_manager.connect_camera_signals()
		print("[GameSystemManager] カメラシグナル遅延接続完了")

# Phase 4: システム間連携設定
func phase_4_setup_system_interconnections() -> void:
	print("[GameSystemManager] Phase 4: システム間連携設定開始")
	
	# BattleScreenManager を先に初期化（battle_system.setup_systems()より前に必要）
	_setup_battle_screen_manager()
	
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
			board_system_3d, card_system, player_system, ui_manager, game_flow_manager
		)
	
	# Step 4: DebugController に設定
	if debug_controller:
		debug_controller.setup_systems(
			player_system, board_system_3d, card_system, ui_manager, game_flow_manager
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
		# カメラタップシグナルを接続（Phase 3のawait完了後に実行）
		_connect_camera_signals_deferred()
	
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
	# 全初期化ロジックをGameSystemManagerが担当
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム初期化")
	
	# LapSystem 初期化
	_setup_lap_system()
	
	# スペルシステム初期化
	_setup_spell_systems()
	
	# BattleScreenManager は Phase 4開始時に初期化済み
	
	# MagicStoneSystem 初期化
	_setup_magic_stone_system()
	
	# CPUSpecialTileAI 初期化
	_setup_cpu_special_tile_ai()
	
	if game_flow_manager:
		# DominioCommandHandler の初期化
		if game_flow_manager.dominio_command_handler:
			game_flow_manager.dominio_command_handler.board_system_3d = board_system_3d
			game_flow_manager.dominio_command_handler.player_system = player_system
			game_flow_manager.dominio_command_handler.ui_manager = ui_manager
		
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
				# tile_data_managerにも参照を渡す（表示用通行料のタイル呪い補正で使用）
				if board_system_3d.tile_data_manager:
					board_system_3d.tile_data_manager.spell_curse_toll = game_flow_manager.spell_curse_toll
				print("[SpellCurseToll] BoardSystem3D のメタデータとして設定完了")
			
			# SpellCostModifier の初期化
			game_flow_manager.spell_cost_modifier = SpellCostModifierClass.new()
			game_flow_manager.spell_cost_modifier.setup(
				game_flow_manager.spell_curse,
				player_system,
				game_flow_manager
			)
			print("[SpellCostModifier] 初期化完了")
		
		# CPUAIHandler の初期化は initialize_phase1a_systems() で行われる
	
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム初期化完了")
	
	# ===== 4-3: BoardSystem3D 子システム初期化 =====
	# 注記: BoardSystem3D._ready() で既に全子システムが作成・初期化済みのため、
	# GameSystemManager では参照設定は不要
	print("[GameSystemManager] Phase 4-3: BoardSystem3D 子システム初期化完了（既に初期化済み）")
	
	# ===== 4-4: 特別な初期化 =====
	print("[GameSystemManager] Phase 4-4: 特別な初期化")
	
	# Phase 1-A ハンドラーの初期化（GameFlowManagerの子として作成）
	_initialize_phase1a_handlers()
	
	# CPU移動評価システムの初期化
	_initialize_cpu_movement_evaluator()
	
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
		ui_manager.card_selected.connect(game_flow_manager.on_card_selected)
		ui_manager.pass_button_pressed.connect(game_flow_manager.on_pass_button_pressed)
		ui_manager.level_up_selected.connect(game_flow_manager.on_level_up_selected)
		ui_manager.dominio_order_button_pressed.connect(game_flow_manager.open_dominio_order)
	
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
	
	print("[GameSystemManager] Phase 6: ゲーム開始準備完了")

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

# ============================================
# 初期化ヘルパー関数（GameFlowManagerから移動）
# ============================================

## LapSystem初期化
func _setup_lap_system() -> void:
	var lap_system = LapSystem.new()
	lap_system.name = "LapSystem"
	game_flow_manager.add_child(lap_system)
	game_flow_manager.set_lap_system(lap_system)
	
	# システム参照を設定
	lap_system.player_system = player_system
	lap_system.ui_manager = ui_manager
	lap_system.game_flow_manager = game_flow_manager  # ゲーム終了判定用
	lap_system.setup_ui()
	
	# board_system_3dを設定してシグナル接続
	if board_system_3d:
		lap_system.board_system_3d = board_system_3d
		lap_system.connect_checkpoint_signals()
	
	# 周回状態を初期化
	lap_system.initialize_lap_state(player_is_cpu.size())
	print("[LapSystem] 初期化完了")

## スペルシステム初期化
func _setup_spell_systems() -> void:
	if not card_system or not player_system:
		push_error("[GameSystemManager] CardSystem/PlayerSystemが初期化されていません")
		return
	
	var spell_systems: Dictionary = {}
	
	# SpellDraw
	var spell_draw = SpellDraw.new()
	spell_draw.setup(card_system, player_system)
	spell_draw.set_board_system(board_system_3d)
	spell_systems["spell_draw"] = spell_draw
	print("[SpellDraw] 初期化完了")
	
	# SpellMagic
	var spell_magic = SpellMagic.new()
	spell_magic.setup(player_system, board_system_3d, game_flow_manager, null)
	spell_systems["spell_magic"] = spell_magic
	print("[SpellMagic] 初期化完了")
	
	# CreatureManager取得
	var creature_manager = board_system_3d.get_node_or_null("CreatureManager") if board_system_3d else null
	if not creature_manager:
		push_error("[GameSystemManager] CreatureManagerが見つかりません")
		game_flow_manager.set_spell_systems(spell_systems)
		return
	
	# SpellLand
	var spell_land = SpellLand.new()
	spell_land.setup(board_system_3d, creature_manager, player_system, card_system)
	spell_land.set_game_flow_manager(game_flow_manager)
	spell_systems["spell_land"] = spell_land
	print("[SpellLand] 初期化完了")
	
	# SpellCurse
	var spell_curse = SpellCurse.new()
	spell_curse.setup(board_system_3d, creature_manager, player_system, game_flow_manager)
	spell_systems["spell_curse"] = spell_curse
	print("[SpellCurse] 初期化完了")
	
	# SpellMagicにSpellCurse参照を追加
	spell_magic.spell_curse_ref = spell_curse
	
	# SpellDice
	var spell_dice = SpellDice.new()
	spell_dice.setup(player_system, spell_curse)
	spell_systems["spell_dice"] = spell_dice
	print("[SpellDice] 初期化完了")
	
	# SpellCurseStat
	var spell_curse_stat = SpellCurseStat.new()
	spell_curse_stat.setup(spell_curse, creature_manager)
	spell_systems["spell_curse_stat"] = spell_curse_stat
	print("[SpellCurseStat] 初期化完了")
	
	# SpellWorldCurse
	var spell_world_curse = SpellWorldCurse.new()
	spell_world_curse.setup(spell_curse, game_flow_manager)
	spell_systems["spell_world_curse"] = spell_world_curse
	print("[SpellWorldCurse] 初期化完了")
	
	# SpellPlayerMove
	var spell_player_move = SpellPlayerMove.new()
	spell_player_move.setup(board_system_3d, player_system, game_flow_manager, spell_curse)
	if board_system_3d:
		board_system_3d.set_spell_player_move(spell_player_move)
	spell_systems["spell_player_move"] = spell_player_move
	print("[SpellPlayerMove] 初期化完了")
	
	# BankruptcyHandler
	var BankruptcyHandlerClass = preload("res://scripts/game_flow/bankruptcy_handler.gd")
	var bankruptcy_handler = BankruptcyHandlerClass.new()
	bankruptcy_handler.setup(player_system, board_system_3d, creature_manager, spell_curse, ui_manager, null)
	spell_systems["bankruptcy_handler"] = bankruptcy_handler
	print("[BankruptcyHandler] 初期化完了")
	
	# GameFlowManagerに一括設定
	game_flow_manager.set_spell_systems(spell_systems)
	
	# BattleSystemにspell_magic/spell_drawを設定（setup_systemsより後に初期化されるため）
	if battle_system:
		battle_system.spell_magic = spell_systems.get("spell_magic")
		battle_system.spell_draw = spell_systems.get("spell_draw")
		if battle_system.battle_special_effects:
			battle_system.battle_special_effects.spell_magic_ref = spell_systems.get("spell_magic")
			battle_system.battle_special_effects.spell_draw_ref = spell_systems.get("spell_draw")
		if battle_system.battle_preparation:
			battle_system.battle_preparation.spell_magic_ref = spell_systems.get("spell_magic")

## BattleScreenManager初期化
func _setup_battle_screen_manager() -> void:
	var battle_screen_manager = BattleScreenManager.new()
	battle_screen_manager.name = "BattleScreenManager"
	game_flow_manager.add_child(battle_screen_manager)
	
	# バトルステータスオーバーレイ
	var BattleStatusOverlayClass = preload("res://scripts/ui/battle_status_overlay.gd")
	var battle_status_overlay = BattleStatusOverlayClass.new()
	battle_status_overlay.name = "BattleStatusOverlay"
	game_flow_manager.add_child(battle_status_overlay)
	
	game_flow_manager.set_battle_screen_manager(battle_screen_manager, battle_status_overlay)
	print("[BattleScreenManager] 初期化完了")

## MagicStoneSystem初期化
func _setup_magic_stone_system() -> void:
	var magic_stone_system = MagicStoneSystem.new()
	magic_stone_system.initialize(board_system_3d, player_system)
	
	# PlayerSystemに参照を設定
	if player_system:
		player_system.set_board_system(board_system_3d)
		player_system.set_magic_stone_system(magic_stone_system)
	
	game_flow_manager.set_magic_stone_system(magic_stone_system)
	print("[MagicStoneSystem] 初期化完了")

## CPUSpecialTileAI初期化
func _setup_cpu_special_tile_ai() -> void:
	var cpu_special_tile_ai = CPUSpecialTileAI.new()
	cpu_special_tile_ai.setup(card_system, player_system, board_system_3d, game_flow_manager)
	game_flow_manager.set_cpu_special_tile_ai(cpu_special_tile_ai)
	print("[CPUSpecialTileAI] 初期化完了")

## Phase 1-A ハンドラーの初期化
func _initialize_phase1a_handlers() -> void:
	if not game_flow_manager:
		return
	
	# TargetSelectionHelperを作成
	var TargetSelectionHelperClass = preload("res://scripts/game_flow/target_selection_helper.gd")
	var target_selection_helper = TargetSelectionHelperClass.new()
	game_flow_manager.add_child(target_selection_helper)
	target_selection_helper.initialize(board_system_3d, ui_manager, game_flow_manager)
	
	# DominioCommandHandlerを作成
	var DominioCommandHandlerClass = preload("res://scripts/game_flow/dominio_command_handler.gd")
	var dominio_command_handler = DominioCommandHandlerClass.new()
	game_flow_manager.add_child(dominio_command_handler)
	dominio_command_handler.initialize(ui_manager, board_system_3d, game_flow_manager, player_system)
	
	# SpellPhaseHandlerを作成
	var SpellPhaseHandlerClass = preload("res://scripts/game_flow/spell_phase_handler.gd")
	var spell_phase_handler = SpellPhaseHandlerClass.new()
	game_flow_manager.add_child(spell_phase_handler)
	spell_phase_handler.initialize(ui_manager, game_flow_manager, card_system, player_system, board_system_3d)
	
	# デバッグ: 密命カードを一時的に無効化（テスト用）
	DebugSettings.disable_secret_cards = true
	
	# ItemPhaseHandlerを作成
	var ItemPhaseHandlerClass = preload("res://scripts/game_flow/item_phase_handler.gd")
	var item_phase_handler = ItemPhaseHandlerClass.new()
	game_flow_manager.add_child(item_phase_handler)
	item_phase_handler.initialize(ui_manager, game_flow_manager, card_system, player_system, battle_system)
	
	# GameFlowManagerにハンドラーを設定
	game_flow_manager.set_phase1a_handlers(
		target_selection_helper,
		dominio_command_handler,
		spell_phase_handler,
		item_phase_handler
	)
	
	# UIManagerにハンドラー参照をキャッシュ（チェーンアクセス解消用）
	if ui_manager:
		ui_manager.spell_phase_handler_ref = spell_phase_handler
		ui_manager.dominio_command_handler_ref = dominio_command_handler
	
	print("[Phase1A Handlers] 初期化完了")

## CPU移動評価システムの初期化
func _initialize_cpu_movement_evaluator() -> void:
	if not game_flow_manager or not board_system_3d:
		return
	
	# CPU AI共有コンテキストを作成
	const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")
	var cpu_context = CPUAIContextScript.new()
	cpu_context.setup(board_system_3d, player_system, card_system)
	cpu_context.setup_optional(
		BaseTile.creature_manager if BaseTile.creature_manager else null,
		game_flow_manager.lap_system,
		game_flow_manager,
		null,  # battle_system
		player_buff_system
	)
	
	# SpellMovementを取得（MovementControllerから）
	var spell_mov = board_system_3d.get_spell_movement() if board_system_3d else null
	
	# CPUBattleAIを作成（コンテキスト経由）
	var battle_ai = CPUBattleAI.new()
	battle_ai.setup_with_context(cpu_context)
	
	# CPUAIHandlerを取得（CPUTurnProcessorから）
	var cpu_ai_handler = null
	if board_system_3d.cpu_turn_processor:
		cpu_ai_handler = board_system_3d.cpu_turn_processor.cpu_ai_handler
	
	# CPUMovementEvaluatorを作成（コンテキスト経由）
	var cpu_movement_evaluator = CPUMovementEvaluator.new()
	cpu_movement_evaluator.setup_with_context(
		cpu_context,
		board_system_3d.get_movement_controller_ref(),
		spell_mov,
		battle_ai,
		cpu_ai_handler
	)
	
	# GameFlowManagerに設定
	game_flow_manager.set_cpu_movement_evaluator(cpu_movement_evaluator)
	
	print("[CPUMovementEvaluator] 初期化完了（距離計算は遅延実行）")
