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
const TollPaymentHandlerClass = preload("res://scripts/game_flow/toll_payment_handler.gd")
const SpellEffectExecutorClass = preload("res://scripts/game_flow/spell_effect_executor.gd")
const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")
const CPUSpellAIScript = preload("res://scripts/cpu_ai/cpu_spell_ai.gd")
const CPUMysticArtsAIScript = preload("res://scripts/cpu_ai/cpu_mystic_arts_ai.gd")
const CPUBattleAIScript = preload("res://scripts/cpu_ai/cpu_battle_ai.gd")
const CPUDefenseAIScript = preload("res://scripts/cpu_ai/cpu_defense_ai.gd")
const CPUMovementEvaluatorScript = preload("res://scripts/cpu_ai/cpu_movement_evaluator.gd")
const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
const CPUSpellAIContainerScript = preload("res://scripts/cpu_ai/cpu_spell_ai_container.gd")

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

# === UIEventHub（EventHub駆動化） ===
var ui_event_hub: UIEventHub = null

# === CPU AI コンテキスト管理（P0統一） ===
var cpu_ai_context: CPUAIContextScript = null
var cpu_spell_ai: CPUSpellAI = null
var cpu_mystic_arts_ai: CPUMysticArtsAI = null
var cpu_hand_utils: CPUHandUtils = null
var cpu_battle_ai: CPUBattleAI = null
var cpu_defense_ai: CPUDefenseAI = null
var cpu_movement_evaluator: CPUMovementEvaluator = null

# === CPU Spell Phase Handler ===
var cpu_spell_phase_handler: CPUSpellPhaseHandler = null

# === CPU Spell AI Container ===
var cpu_spell_ai_container: CPUSpellAIContainerScript = null

# === 設定 ===
var player_count: int = 2
var player_is_cpu: Array = [false, true]

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
	DebugSettings.manual_control_all = debug_mode
	
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

	# UIEventHub（UIManager直後に作成）
	ui_event_hub = UIEventHub.new()
	ui_event_hub.name = "UIEventHub"
	add_child(ui_event_hub)
	systems["UIEventHub"] = ui_event_hub

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

		# === サービス注入: message_service ===
		if ui_manager and ui_manager.get("message_service"):
			board_system_3d._message_service = ui_manager.message_service

		# === Phase 2: invasion_completed リレーチェーン接続 ===
		# TileActionProcessor → BoardSystem3D の接続
		if board_system_3d.tile_action_processor:
			if not board_system_3d.tile_action_processor.invasion_completed.is_connected(board_system_3d._on_invasion_completed):
				board_system_3d.tile_action_processor.invasion_completed.connect(board_system_3d._on_invasion_completed)
				print("[GameSystemManager] TileActionProcessor → BoardSystem3D invasion_completed 接続完了")

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

	# Step 5.5: MovementController に game_3d_ref を設定（get_parent()廃止）
	if board_system_3d and parent_node:
		board_system_3d.set_movement_controller_game_3d_ref(parent_node)

	# Step 10: UIManager.create_ui() 実行（全参照設定後）
	if ui_manager and parent_node:
		ui_manager.create_ui(parent_node)
		# 作成されたUILayerを参照
		ui_layer = parent_node.get_node_or_null("UILayer")
		# カメラタップシグナルを接続（Phase 3のawait完了後に実行）
		_connect_camera_signals_deferred()

	# === Phase 11-B: TapTargetManager直接注入（UIManager経由アクセス除去） ===
	_inject_tap_target_manager()

	# Step 7: CardSelectionUI に設定
	if ui_manager and ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager
	
	# Step 8: BattleSystem に設定
	if battle_system:
		battle_system.game_flow_manager_ref = game_flow_manager

		# === サービス注入: message_service ===
		if ui_manager and ui_manager.get("message_service"):
			battle_system._message_service = ui_manager.message_service
	
	# Step 9: GameFlowManager の 3D 設定
	if game_flow_manager:
		game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)

	# Step 9.5: BoardSystem3D → GameFlowManager シグナル接続（Phase 2 リレー）
	if board_system_3d and game_flow_manager:
		# invasion_completed
		if not board_system_3d.invasion_completed.is_connected(game_flow_manager._on_invasion_completed_from_board):
			board_system_3d.invasion_completed.connect(game_flow_manager._on_invasion_completed_from_board)
			print("[GameSystemManager] BoardSystem3D → GameFlowManager invasion_completed 接続完了")

		# movement_completed
		if not board_system_3d.movement_completed.is_connected(game_flow_manager._on_movement_completed_from_board):
			board_system_3d.movement_completed.connect(game_flow_manager._on_movement_completed_from_board)
			print("[GameSystemManager] BoardSystem3D → GameFlowManager movement_completed 接続完了")

		# level_up_completed
		if not board_system_3d.level_up_completed.is_connected(game_flow_manager._on_level_up_completed_from_board):
			board_system_3d.level_up_completed.connect(game_flow_manager._on_level_up_completed_from_board)
			print("[GameSystemManager] BoardSystem3D → GameFlowManager level_up_completed 接続完了")

		# terrain_changed
		if not board_system_3d.terrain_changed.is_connected(game_flow_manager._on_terrain_changed_from_board):
			board_system_3d.terrain_changed.connect(game_flow_manager._on_terrain_changed_from_board)
			print("[GameSystemManager] BoardSystem3D → GameFlowManager terrain_changed 接続完了")

		# start_passed (Day 3)
		if not board_system_3d.start_passed.is_connected(game_flow_manager._on_start_passed_from_board):
			board_system_3d.start_passed.connect(game_flow_manager._on_start_passed_from_board)
			print("[GameSystemManager] BoardSystem3D → GameFlowManager start_passed 接続完了")

		# warp_executed (Day 3)
		if not board_system_3d.warp_executed.is_connected(game_flow_manager._on_warp_executed_from_board):
			board_system_3d.warp_executed.connect(game_flow_manager._on_warp_executed_from_board)
			print("[GameSystemManager] BoardSystem3D → GameFlowManager warp_executed 接続完了")

	# MovementController3D → BoardSystem3D シグナル接続（Day 3）
	if board_system_3d and board_system_3d.movement_controller:
		# start_passed
		if not board_system_3d.movement_controller.start_passed.is_connected(board_system_3d._on_start_passed):
			board_system_3d.movement_controller.start_passed.connect(board_system_3d._on_start_passed)
			print("[GameSystemManager] MovementController3D → BoardSystem3D start_passed 接続完了")

		# warp_executed
		if not board_system_3d.movement_controller.warp_executed.is_connected(board_system_3d._on_warp_executed):
			board_system_3d.movement_controller.warp_executed.connect(board_system_3d._on_warp_executed)
			print("[GameSystemManager] MovementController3D → BoardSystem3D warp_executed 接続完了")

	# === Phase 4: CreatureManager シグナル接続（Day 1） ===
	_setup_phase_4_creature_signals()

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
		
		# SpellCurseToll の初期化
		if game_flow_manager.spell_container and game_flow_manager.spell_container.spell_curse:
			# SkillTollChange の作成
			var skill_toll_change = preload("res://scripts/skills/skill_toll_change.gd").new()

			# CreatureManager の取得（BoardSystem3D 配下から動的に取得）
			var creature_manager = null
			if board_system_3d:
				# board_system_3d の子ノードから CreatureManager を検索
				creature_manager = board_system_3d.get_node_or_null("CreatureManager")

			# SpellCurseToll の初期化
			var spell_curse_toll = SpellCurseTollClass.new()
			spell_curse_toll.setup(
				game_flow_manager.spell_container.spell_curse,
				skill_toll_change,
				creature_manager
			)
			spell_curse_toll.name = "SpellCurseToll"
			game_flow_manager.add_child(spell_curse_toll)

			# コンテナに設定
			game_flow_manager.spell_container.set_spell_curse_toll(spell_curse_toll)
			print("[SpellCurseToll] 初期化完了（SkillTollChange と CreatureManager 参照設定済み）")

			# ★重要: board_system_3d にメタデータとして設定（MovementHelper から参照可能にする）
			if board_system_3d:
				board_system_3d.set_meta("spell_curse_toll", spell_curse_toll)
				board_system_3d.set_meta("spell_world_curse", game_flow_manager.spell_container.spell_world_curse)
				# tile_data_managerにも参照を渡す（表示用通行料のタイル呪い補正で使用）
				if board_system_3d.tile_data_manager:
					board_system_3d.tile_data_manager.spell_curse_toll = spell_curse_toll
					# === game_stats直接参照も設定（チェーンアクセス解消） ===
					board_system_3d.tile_data_manager.set_game_stats(game_flow_manager.game_stats)
				print("[SpellCurseToll/SpellWorldCurse] BoardSystem3D のメタデータとして設定完了")

			# SpellCostModifier の初期化
			var spell_cost_modifier = SpellCostModifierClass.new()
			spell_cost_modifier.setup(
				game_flow_manager.spell_container.spell_curse,
				player_system,
				game_flow_manager
			)

			# コンテナに設定
			game_flow_manager.spell_container.set_spell_cost_modifier(spell_cost_modifier)
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

	# PlayerInfoService セットアップ（Phase 8-H）
	if ui_manager and ui_manager.get("player_info_service"):
		var pis = ui_manager.player_info_service
		if pis and pis.has_method("setup") and ui_manager.player_info_panel:
			pis.setup(ui_manager.player_info_panel)
			print("[GameSystemManager] PlayerInfoService セットアップ完了")

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
		# CardSelectionService のシグナルを直接接続（Phase 8-M）
		var css = ui_manager.card_selection_service
		if css and not css.card_selected.is_connected(game_flow_manager.on_card_selected):
			css.card_selected.connect(game_flow_manager.on_card_selected)
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
	if ui_manager and ui_manager.player_info_service:
		await get_tree().create_timer(0.1).timeout
		ui_manager.player_info_service.update_panels()
	
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

## Phase 4: CreatureManager シグナル接続（Day 1, Day 3 拡張）
func _setup_phase_4_creature_signals() -> void:
	print("[GameSystemManager] creature シグナル接続開始")

	# Day 1: CreatureManager → BoardSystem3D
	if board_system_3d and board_system_3d.creature_manager:
		var creature_manager = board_system_3d.creature_manager

		if not creature_manager.creature_changed.is_connected(board_system_3d._on_creature_changed):
			creature_manager.creature_changed.connect(board_system_3d._on_creature_changed)
			print("[GameSystemManager] creature_changed 接続完了")
		else:
			push_warning("[GameSystemManager] creature_changed は既に接続済み")
	else:
		push_error("[GameSystemManager] creature_manager または board_system_3d が null")

	# Day 3 追加: BoardSystem3D → GameFlowManager
	if board_system_3d and game_flow_manager:
		if not board_system_3d.creature_updated.is_connected(game_flow_manager._on_creature_updated_from_board):
			board_system_3d.creature_updated.connect(game_flow_manager._on_creature_updated_from_board)
			print("[GameSystemManager] creature_updated → GFM 接続完了")
		else:
			push_warning("[GameSystemManager] creature_updated → GFM は既に接続済み")
	else:
		push_error("[GameSystemManager] board_system_3d または game_flow_manager が null")

	# Day 3 追加: GameFlowManager → UIManager
	if game_flow_manager and ui_manager:
		if not game_flow_manager.creature_updated_relay.is_connected(ui_manager.on_creature_updated):
			game_flow_manager.creature_updated_relay.connect(ui_manager.on_creature_updated)
			print("[GameSystemManager] creature_updated_relay → UI 接続完了")
		else:
			push_warning("[GameSystemManager] creature_updated_relay → UI は既に接続済み")
	else:
		push_error("[GameSystemManager] game_flow_manager または ui_manager が null")

## LapSystem初期化
func _setup_lap_system() -> void:
	var lap_system = LapSystem.new()
	lap_system.name = "LapSystem"
	game_flow_manager.add_child(lap_system)
	game_flow_manager.set_lap_system(lap_system)

	# システム参照を設定
	lap_system.player_system = player_system
	lap_system.ui_manager = ui_manager
	lap_system._message_service = ui_manager.message_service if ui_manager else null
	# game_flow_manager 参照削除（Callable注入に変更済み）
	lap_system.set_game_3d_ref(parent_node)  # game_3d参照を直接注入（get_parent()廃止）
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

	# === Step 1: SpellSystemContainer を作成 ===
	var spell_container = SpellSystemContainer.new()

	# SpellDraw
	var spell_draw = SpellDraw.new()
	spell_draw.setup(card_system, player_system)
	spell_draw.set_board_system(board_system_3d)
	print("[SpellDraw] 初期化完了")

	# SpellMagic
	var spell_magic = SpellMagic.new()
	spell_magic.setup(player_system, board_system_3d, game_flow_manager, null)
	print("[SpellMagic] 初期化完了")

	# CreatureManager取得
	var creature_manager = board_system_3d.get_node_or_null("CreatureManager") if board_system_3d else null
	if not creature_manager:
		push_error("[GameSystemManager] CreatureManagerが見つかりません")
		return

	# SpellLand
	var spell_land = SpellLand.new()
	spell_land.setup(board_system_3d, creature_manager, player_system, card_system)
	spell_land.set_game_flow_manager(game_flow_manager)
	if board_system_3d:
		board_system_3d.set_spell_land(spell_land)
	print("[SpellLand] 初期化完了")

	# SpellCurse
	var spell_curse = SpellCurse.new()
	spell_curse.setup(board_system_3d, creature_manager, player_system, game_flow_manager)
	print("[SpellCurse] 初期化完了")

	# SpellMagicにSpellCurse参照を追加
	spell_magic.spell_curse_ref = spell_curse

	# SpellDice
	var spell_dice = SpellDice.new()
	spell_dice.setup(player_system, spell_curse)
	print("[SpellDice] 初期化完了")

	# SpellCurseStat
	var spell_curse_stat = SpellCurseStat.new()
	spell_curse_stat.setup(spell_curse, creature_manager)
	print("[SpellCurseStat] 初期化完了")

	# SpellWorldCurse
	var spell_world_curse = SpellWorldCurse.new()
	spell_world_curse.setup(spell_curse, game_flow_manager)
	print("[SpellWorldCurse] 初期化完了")

	# SpellPlayerMove
	var spell_player_move = SpellPlayerMove.new()
	spell_player_move.setup(board_system_3d, player_system, game_flow_manager, spell_curse)
	if board_system_3d:
		board_system_3d.set_spell_player_move(spell_player_move)
	print("[SpellPlayerMove] 初期化完了")

	# === Step 3: コンテナにコアシステム（8個）を設定 ===
	spell_container.setup(
		spell_draw,
		spell_magic,
		spell_land,
		spell_curse,
		spell_dice,
		spell_curse_stat,
		spell_world_curse,
		spell_player_move
	)

	# ★ NEW: 初期化検証
	if not spell_container.is_valid():
		push_error("[GameSystemManager] spell_container が完全に初期化されていません")
		spell_container.debug_print_status()
		return
	else:
		print("[GameSystemManager] spell_container 初期化確認: 8個のコアシステムが設定済み")
		# spell_container.debug_print_status()  # 詳細ログが不要な場合はコメントアウト

	# === Step 4: BankruptcyHandlerは別途GameFlowManagerに設定（コンテナ外）===
	var BankruptcyHandlerClass = preload("res://scripts/game_flow/bankruptcy_handler.gd")
	var bankruptcy_handler = BankruptcyHandlerClass.new()
	bankruptcy_handler.setup(player_system, board_system_3d, creature_manager, spell_curse)
	print("[BankruptcyHandler] 初期化完了")

	# === Step 5: GameFlowManager に参照を設定 ===
	game_flow_manager.set_spell_container(spell_container)

	# BankruptcyHandlerもGameFlowManagerに設定（add_child）
	game_flow_manager.bankruptcy_handler = bankruptcy_handler
	if not bankruptcy_handler.get_parent():
		game_flow_manager.add_child(bankruptcy_handler)

	# Phase 6-C: BankruptcyHandler UI Signal接続
	_connect_bankruptcy_signals(bankruptcy_handler, ui_manager)

	# SpellCostModifierにSpellWorldCurse参照を設定
	if spell_container.spell_cost_modifier:
		spell_container.spell_cost_modifier.set_spell_world_curse(spell_container.spell_world_curse)

	# === game_stats直接参照を各システムに設定（チェーンアクセス解消） ===
	if spell_container.spell_curse:
		spell_container.spell_curse.set_game_stats(game_flow_manager.game_stats)
	if spell_container.spell_world_curse:
		spell_container.spell_world_curse.set_game_stats(game_flow_manager.game_stats)

	# BattleSystemにspell_magic/spell_drawを設定（setup_systemsより後に初期化されるため）
	if battle_system:
		battle_system.spell_magic = spell_magic
		battle_system.spell_draw = spell_draw
		if battle_system.battle_special_effects:
			battle_system.battle_special_effects.spell_magic_ref = spell_magic
			battle_system.battle_special_effects.spell_draw_ref = spell_draw
			# === 直接参照を設定（チェーンアクセス解消） ===
			battle_system.battle_special_effects.set_game_stats(game_flow_manager.game_stats)
			battle_system.battle_special_effects.set_player_system(player_system)
		if battle_system.battle_preparation:
			battle_system.battle_preparation.spell_magic_ref = spell_magic

	# TileActionProcessorにspell参照を設定
	if board_system_3d:
		board_system_3d.set_tile_action_processor_spells(
			spell_container.spell_cost_modifier,
			spell_container.spell_world_curse
		)

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
	target_selection_helper.initialize(board_system_3d, ui_manager.message_service, ui_manager.navigation_service, game_flow_manager)
	
	# DominioCommandHandlerを作成
	var DominioCommandHandlerClass = preload("res://scripts/game_flow/dominio_command_handler.gd")
	var dominio_command_handler = DominioCommandHandlerClass.new()
	game_flow_manager.add_child(dominio_command_handler)
	dominio_command_handler.initialize(ui_manager, board_system_3d, game_flow_manager, player_system)
	dominio_command_handler.set_game_3d_ref(parent_node)  # game_3d参照を直接注入（get_parent()廃止）
	dominio_command_handler.set_spell_systems_direct(
		game_flow_manager.spell_container.spell_world_curse,
		game_flow_manager.spell_container.spell_land,
		game_flow_manager.spell_container.spell_curse
	)

	# === Phase 8-B2: dominio_order_ui を直接注入 ===
	if ui_manager and ui_manager.dominio_order_ui:
		dominio_command_handler.set_dominio_order_ui(ui_manager.dominio_order_ui)

	# SpellPhaseHandlerを作成
	var SpellPhaseHandlerClass = preload("res://scripts/game_flow/spell_phase_handler.gd")
	var spell_phase_handler = SpellPhaseHandlerClass.new()
	game_flow_manager.add_child(spell_phase_handler)
	spell_phase_handler.initialize(ui_manager, game_flow_manager, card_system, player_system, board_system_3d)
	spell_phase_handler.set_game_3d_ref(parent_node)  # game_3d参照を直接注入（get_parent()廃止）
	spell_phase_handler.set_game_stats(game_flow_manager.game_stats)  # === game_stats直接参照を設定 ===

	# === 新規: SpellPhaseHandler のサブシステム初期化（先に実行：spell_effect_executor作成） ===
	_initialize_spell_phase_subsystems(spell_phase_handler, game_flow_manager, ui_manager)

	# SpellEffectExecutorにスペルコンテナを直接設定（辞書展開廃止）
	# 注: _initialize_spell_phase_subsystems() で spell_effect_executor が作成済みになった
	spell_phase_handler.set_spell_effect_executor_container(game_flow_manager.spell_container)

	# ★ P0修正: card_selection_handler を初期化（シャッター実行失敗の修正）
	if spell_phase_handler and game_flow_manager and game_flow_manager.spell_container:
		spell_phase_handler._initialize_card_selection_handler(ui_manager)
		if spell_phase_handler.card_selection_handler and game_flow_manager.spell_container.spell_draw:
			game_flow_manager.spell_container.spell_draw.set_card_selection_handler(spell_phase_handler.card_selection_handler)
			print("[GSM] card_selection_handler 初期化・設定完了")

	# DebugControllerにspell_phase_handler参照を設定
	if debug_controller:
		debug_controller.spell_phase_handler = spell_phase_handler

	# SpellCurseにspell_phase_handler参照を設定
	if game_flow_manager.spell_container.spell_curse:
		game_flow_manager.spell_container.spell_curse.set_spell_phase_handler(spell_phase_handler)

	# SpellWorldCurseにspell_cast_notification_ui参照を設定
	if game_flow_manager.spell_container.spell_world_curse and spell_phase_handler.spell_cast_notification_ui:
		game_flow_manager.spell_container.spell_world_curse.set_notification_ui(spell_phase_handler.spell_cast_notification_ui)

	# CPUSpecialTileAIにspell_phase_handler参照を設定
	if game_flow_manager.cpu_special_tile_ai:
		game_flow_manager.cpu_special_tile_ai.spell_phase_handler = spell_phase_handler
		game_flow_manager.cpu_special_tile_ai.cpu_spell_ai = cpu_spell_ai

	# 注: TutorialManagerはgame_3d.gdに存在し、spell_phase_handlerから
	# game_3d.tutorial_manager経由でアクセスするため、ここでの注入は不要

	# デバッグ: 密命カードを一時的に無効化（テスト用）
	DebugSettings.disable_secret_cards = true
	
	# ItemPhaseHandlerを作成
	var ItemPhaseHandlerClass = preload("res://scripts/game_flow/item_phase_handler.gd")
	var item_phase_handler = ItemPhaseHandlerClass.new()
	game_flow_manager.add_child(item_phase_handler)
	item_phase_handler.initialize(game_flow_manager, card_system, player_system, battle_system)
	item_phase_handler.set_spell_cost_modifier(game_flow_manager.spell_container.spell_cost_modifier)

	# Phase 8-A: ItemPhaseHandler UI Signal接続
	_connect_item_phase_signals(item_phase_handler, ui_manager)

	# DicePhaseHandlerを作成
	var DicePhaseHandlerClass = preload("res://scripts/game_flow/dice_phase_handler.gd")
	var dice_phase_handler = DicePhaseHandlerClass.new()
	game_flow_manager.add_child(dice_phase_handler)
	dice_phase_handler.setup(player_system, player_buff_system, game_flow_manager.spell_container.spell_dice, board_system_3d, game_flow_manager)
	game_flow_manager.dice_phase_handler = dice_phase_handler

	# Phase 6-B: DicePhaseHandler UI Signal接続
	_connect_dice_phase_signals(dice_phase_handler, ui_manager)

	# TollPaymentHandlerを作成
	var toll_payment_handler = TollPaymentHandlerClass.new()
	game_flow_manager.add_child(toll_payment_handler)
	toll_payment_handler.setup(player_system, board_system_3d, game_flow_manager.spell_container.spell_curse_toll)
	game_flow_manager.toll_payment_handler = toll_payment_handler

	# Phase 6-C: TollPaymentHandler UI Signal接続
	_connect_toll_payment_signals(toll_payment_handler, ui_manager)

	# DiscardHandlerを作成
	var DiscardHandlerClass = preload("res://scripts/game_flow/discard_handler.gd")
	var discard_handler = DiscardHandlerClass.new()
	game_flow_manager.add_child(discard_handler)
	discard_handler.setup(player_system, card_system, spell_phase_handler, player_is_cpu)
	discard_handler.cpu_hand_utils = cpu_hand_utils  # CPU手札ユーティリティ直接注入（SPHパススルー廃止）
	game_flow_manager.discard_handler = discard_handler

	# Phase 6-C: DiscardHandler UI Signal接続
	_connect_discard_signals(discard_handler, ui_manager, player_system)

	# GameFlowManagerにハンドラーを設定
	game_flow_manager.set_phase1a_handlers(
		target_selection_helper,
		dominio_command_handler,
		spell_phase_handler,
		item_phase_handler
	)

	# target_selection_helper を設定（move_self など複数タイル選択時に必要）
	if game_flow_manager and game_flow_manager.target_selection_helper:
		spell_phase_handler.target_selection_helper = game_flow_manager.target_selection_helper

	# Phase 10-C: DominioOrderUI に DCH を直接注入（初期化順序バグ修正）
	if ui_manager and ui_manager.dominio_order_ui:
		ui_manager.dominio_order_ui.dominio_command_handler = dominio_command_handler
		print("[GameSystemManager] DominioOrderUI → DCH 直接参照を設定")

	# battle_status_overlayの直接参照を設定（チェーンアクセス解消）
	if game_flow_manager.battle_status_overlay:
		dominio_command_handler.set_battle_status_overlay(game_flow_manager.battle_status_overlay)
		spell_phase_handler.set_battle_status_overlay(game_flow_manager.battle_status_overlay)
		if board_system_3d:
			board_system_3d.set_tile_action_processor_battle_overlay(game_flow_manager.battle_status_overlay)

	print("[Phase1A Handlers] 初期化完了")

	# Phase 10-C: UI Callable/Signal 注入
	_setup_ui_callbacks(ui_manager, game_flow_manager, board_system_3d, dominio_command_handler, spell_phase_handler)

	# Phase 11: UIEventHub イベント配線
	_setup_ui_events()

	# ★ NEW: スペルシステム初期化検証
	if not game_flow_manager or not game_flow_manager.spell_container:
		push_error("[GameSystemManager] game_flow_manager または spell_container が null です")
		return
	if not game_flow_manager.spell_container.is_valid():
		push_error("[GameSystemManager] spell_container: コアシステムが不完全です")
		game_flow_manager.spell_container.debug_print_status()
		return

	if not spell_phase_handler or not spell_phase_handler.spell_effect_executor:
		push_error("[GameSystemManager] spell_phase_handler.spell_effect_executor が未設定です")
		return

	if not spell_phase_handler.spell_effect_executor.spell_container:
		push_error("[GameSystemManager] spell_effect_executor.spell_container が null です")
		return

	if not spell_phase_handler.spell_effect_executor.spell_container.is_valid():
		push_error("[GameSystemManager] spell_effect_executor.spell_container: 無効です")
		return

	print("[GameSystemManager] スペルシステム初期化検証完了 ✓")

## SpellPhaseHandler の全初期化
func _initialize_spell_phase_subsystems(spell_phase_handler, p_game_flow_manager, p_ui_manager = null) -> void:
	"""
	SpellPhaseHandler の全初期化をGameSystemManagerで一元管理する。

	初期化内容:
	- Base references (CreatureManager, TargetSelectionHelper)
	- SpellSubsystemContainer (11 spell subsystems)
	- SpellEffectExecutor
	- 4 Handlers (SpellTargetSelectionHandler, SpellUIManager, MysticArtsHandler, etc.)
	- CPU AI context
	"""
	if not spell_phase_handler or not p_game_flow_manager:
		push_error("[GameSystemManager] spell_phase_handler または p_game_flow_manager が null です")
		return

	if not board_system_3d:
		push_error("[GameSystemManager] board_system_3d が null です")
		return

	# === SpellPhaseHandler 子システムを直接初期化 ===
	# 以下の初期化内容を実行:
	# - Base references (CreatureManager, target_selection_helper)
	# - SpellSubsystemContainer の 11 spell subsystems
	# - SpellEffectExecutor
	# - 4 Handlers (SpellTargetSelectionHandler, SpellUIManager, MysticArtsHandler, etc.)
	# - CPU AI context

	# Step 1: 基本参照の取得
	if spell_phase_handler.board_system:
		spell_phase_handler.creature_manager = spell_phase_handler.board_system.get_node_or_null("CreatureManager")
		if not spell_phase_handler.creature_manager:
			push_error("[GameSystemManager] CreatureManager が見つかりません")

	if p_game_flow_manager and p_game_flow_manager.target_selection_helper:
		spell_phase_handler.target_selection_helper = p_game_flow_manager.target_selection_helper

	# Step 2: 11個のSpell**** クラスを初期化（SpellSubsystemContainer 経由）
	if not spell_phase_handler.spell_systems:
		spell_phase_handler.spell_systems = SpellSubsystemContainer.new()

	# SpellDamage を初期化
	if not spell_phase_handler.spell_systems.spell_damage and spell_phase_handler.board_system:
		spell_phase_handler.spell_systems.spell_damage = SpellDamage.new(spell_phase_handler.board_system)

	# SpellCreatureMove を初期化
	if not spell_phase_handler.spell_systems.spell_creature_move and spell_phase_handler.board_system and spell_phase_handler.player_system:
		spell_phase_handler.spell_systems.spell_creature_move = SpellCreatureMove.new(spell_phase_handler.board_system, spell_phase_handler.player_system, spell_phase_handler)
		if p_game_flow_manager:
			spell_phase_handler.spell_systems.spell_creature_move.set_game_flow_manager(p_game_flow_manager)
		if spell_phase_handler.battle_status_overlay:
			spell_phase_handler.spell_systems.spell_creature_move.set_battle_status_overlay(spell_phase_handler.battle_status_overlay)

	# SpellCreatureSwap を初期化
	if not spell_phase_handler.spell_systems.spell_creature_swap and spell_phase_handler.board_system and spell_phase_handler.player_system and spell_phase_handler.card_system:
		spell_phase_handler.spell_systems.spell_creature_swap = SpellCreatureSwap.new(spell_phase_handler.board_system, spell_phase_handler.player_system, spell_phase_handler.card_system, spell_phase_handler)
		# Phase 8-P: サービス直接注入
		var _css2 = p_ui_manager.card_selection_service if p_ui_manager else null
		var _msg2 = p_ui_manager.message_service if p_ui_manager else null
		var _nav2 = p_ui_manager.navigation_service if p_ui_manager else null
		spell_phase_handler.spell_systems.spell_creature_swap.set_services(_css2, _msg2, _nav2)

	# SpellCreatureReturn を初期化
	if not spell_phase_handler.spell_systems.spell_creature_return and spell_phase_handler.board_system and spell_phase_handler.player_system and spell_phase_handler.card_system:
		spell_phase_handler.spell_systems.spell_creature_return = SpellCreatureReturn.new(spell_phase_handler.board_system, spell_phase_handler.player_system, spell_phase_handler.card_system, spell_phase_handler)

	# SpellCreaturePlace を初期化
	if not spell_phase_handler.spell_systems.spell_creature_place:
		spell_phase_handler.spell_systems.spell_creature_place = SpellCreaturePlace.new()

	# SpellDrawにSpellCreaturePlace参照を設定
	if p_game_flow_manager and p_game_flow_manager.spell_container and p_game_flow_manager.spell_container.spell_draw and spell_phase_handler.spell_systems.spell_creature_place:
		p_game_flow_manager.spell_container.spell_draw.set_spell_creature_place(spell_phase_handler.spell_systems.spell_creature_place)

	# SpellBorrow を初期化
	if not spell_phase_handler.spell_systems.spell_borrow and spell_phase_handler.board_system and spell_phase_handler.player_system and spell_phase_handler.card_system:
		spell_phase_handler.spell_systems.spell_borrow = SpellBorrow.new(spell_phase_handler.board_system, spell_phase_handler.player_system, spell_phase_handler.card_system, spell_phase_handler)
		# Phase 8-P: サービス直接注入
		var _css = p_ui_manager.card_selection_service if p_ui_manager else null
		var _msg = p_ui_manager.message_service if p_ui_manager else null
		spell_phase_handler.spell_systems.spell_borrow.set_services(_css, _msg)

	# SpellTransform を初期化
	if not spell_phase_handler.spell_systems.spell_transform and spell_phase_handler.board_system and spell_phase_handler.player_system and spell_phase_handler.card_system:
		spell_phase_handler.spell_systems.spell_transform = SpellTransform.new(spell_phase_handler.board_system, spell_phase_handler.player_system, spell_phase_handler.card_system, spell_phase_handler)

	# SpellPurify を初期化
	if not spell_phase_handler.spell_systems.spell_purify and spell_phase_handler.board_system and spell_phase_handler.creature_manager and spell_phase_handler.player_system and p_game_flow_manager:
		spell_phase_handler.spell_systems.spell_purify = SpellPurify.new(spell_phase_handler.board_system, spell_phase_handler.creature_manager, spell_phase_handler.player_system, p_game_flow_manager)
		spell_phase_handler.spell_systems.spell_purify.set_game_stats(p_game_flow_manager.game_stats)

	# CardSacrificeHelper を初期化（スペル合成・クリーチャー合成共通）
	if not spell_phase_handler.spell_systems.card_sacrifice_helper and spell_phase_handler.card_system and spell_phase_handler.player_system:
		var _css3 = p_ui_manager.card_selection_service if p_ui_manager else null
		spell_phase_handler.spell_systems.card_sacrifice_helper = CardSacrificeHelper.new(spell_phase_handler.card_system, spell_phase_handler.player_system, _css3)

	# SpellSynthesis を初期化
	if not spell_phase_handler.spell_systems.spell_synthesis and spell_phase_handler.spell_systems.card_sacrifice_helper:
		spell_phase_handler.spell_systems.spell_synthesis = SpellSynthesis.new(spell_phase_handler.spell_systems.card_sacrifice_helper)

	# CPUTurnProcessorを取得（BoardSystem3Dの子ノードから）
	if spell_phase_handler.board_system and not spell_phase_handler.spell_systems.cpu_turn_processor:
		spell_phase_handler.spell_systems.cpu_turn_processor = spell_phase_handler.board_system.get_node_or_null("CPUTurnProcessor")

	# Step 2.5: SpellEffectExecutor を初期化（ハンドラー初期化の前に必須）
	if not spell_phase_handler.spell_effect_executor:
		spell_phase_handler.spell_effect_executor = SpellEffectExecutorClass.new(spell_phase_handler)

	# Phase 6: SpellEffectExecutor UI Signal接続
	if spell_phase_handler.spell_effect_executor:
		spell_phase_handler.spell_effect_executor.effect_ui_comment_and_wait_requested.connect(
			func(message: String):
				if ui_manager and ui_manager.has_method("show_comment_and_wait"):
					await ui_manager.show_comment_and_wait(message)
				spell_phase_handler.spell_effect_executor.effect_ui_comment_and_wait_completed.emit()
		)
		print("[GSM] SpellEffectExecutor UI Signal接続完了")

	# Step 3: 6個のハンドラーを初期化（inline化）

	# SpellTargetSelectionHandler を初期化（Phase 6-1）
	if not spell_phase_handler.spell_target_selection_handler:
		spell_phase_handler.spell_target_selection_handler = SpellTargetSelectionHandler.new()
		spell_phase_handler.spell_target_selection_handler.name = "SpellTargetSelectionHandler"
		spell_phase_handler.add_child(spell_phase_handler.spell_target_selection_handler)

		spell_phase_handler.spell_target_selection_handler.setup(
			spell_phase_handler,
			ui_manager,
			spell_phase_handler.board_system,
			spell_phase_handler.player_system,
			spell_phase_handler.game_3d_ref
		)

	# MysticArtsHandler を初期化（Phase 8-1）
	if not spell_phase_handler.mystic_arts_handler:
		spell_phase_handler.mystic_arts_handler = MysticArtsHandler.new()
		spell_phase_handler.mystic_arts_handler.name = "MysticArtsHandler"
		spell_phase_handler.add_child(spell_phase_handler.mystic_arts_handler)

		spell_phase_handler.mystic_arts_handler.setup(
			spell_phase_handler,
			spell_phase_handler.board_system,
			spell_phase_handler.player_system,
			spell_phase_handler.card_system,
			spell_phase_handler.game_3d_ref
		)

	# SpellStateHandler と SpellFlowHandler を初期化（Phase 3-A Day 9-12）
	if not spell_phase_handler.spell_state:
		spell_phase_handler.spell_state = SpellStateHandler.new()

		spell_phase_handler.spell_flow = SpellFlowHandler.new(spell_phase_handler.spell_state)

		spell_phase_handler.spell_flow.setup(
			spell_phase_handler,
			game_flow_manager,
			spell_phase_handler.board_system,
			spell_phase_handler.player_system,
			spell_phase_handler.card_system,
			spell_phase_handler.game_3d_ref,
			p_game_flow_manager.spell_container.spell_cost_modifier if p_game_flow_manager and p_game_flow_manager.spell_container else null,
			spell_phase_handler.spell_systems.spell_synthesis if spell_phase_handler.spell_systems else null,
			spell_phase_handler.spell_systems.card_sacrifice_helper if spell_phase_handler.spell_systems else null,
			spell_phase_handler.spell_effect_executor,
			spell_phase_handler.spell_target_selection_handler,
			spell_phase_handler.target_selection_helper
		)

		print("[GameSystemManager] SpellStateHandler と SpellFlowHandler を初期化完了")

	# SpellUIManager 初期化（統合版: ナビゲーション + UI制御 + 発動確認）
	if not spell_phase_handler.spell_ui_manager:
		spell_phase_handler.spell_ui_manager = SpellUIManager.new()
		spell_phase_handler.spell_ui_manager.name = "SpellUIManager"
		spell_phase_handler.add_child(spell_phase_handler.spell_ui_manager)

		spell_phase_handler.spell_ui_manager.setup(
			spell_phase_handler,
			ui_manager,
			spell_phase_handler.board_system,
			spell_phase_handler.player_system,
			spell_phase_handler.game_3d_ref,
			spell_phase_handler.card_system
		)

		# 統合された初期化処理
		spell_phase_handler.spell_ui_manager.initialize_spell_phase_ui()
		spell_phase_handler.spell_ui_manager.initialize_spell_cast_notification_ui()

		print("[SpellUIManager] 初期化完了")

		# === Phase 7-B: SpellPhaseHandler の UI Signal を接続
		spell_phase_handler.spell_ui_manager.connect_spell_phase_handler_signals(spell_phase_handler)
		print("[GameSystemManager] SpellPhaseHandler UI Signal 接続完了")

		# spell_cast_notification_ui を SPH に設定（外部システムが参照するため）
		spell_phase_handler.spell_cast_notification_ui = spell_phase_handler.spell_ui_manager.get_spell_cast_notification_ui()

		# === Phase 6-A: SpellFlowHandler の UI Signal を接続（SpellUIManager 初期化後）
		if spell_phase_handler.spell_flow:
			spell_phase_handler.spell_ui_manager.connect_spell_flow_signals(spell_phase_handler.spell_flow)
			print("[GameSystemManager] SpellFlowHandler UI Signal 接続完了")

	# Step 4: CPU AI を初期化（GameSystemManagerから参照を取得）
	if not cpu_ai_context:
		_initialize_cpu_ai_systems()

	# Step 4.5: CPUSpellPhaseHandler を初期化（spell_phase_handlerの初期化後）
	_initialize_cpu_spell_phase_handler(spell_phase_handler)

	# CPU AI 参照を CPUSpellPhaseHandler に直接注入（SPH パススルー廃止）
	if cpu_spell_phase_handler:
		cpu_spell_phase_handler.set_cpu_spell_ai(cpu_spell_ai)
		cpu_spell_phase_handler.set_cpu_mystic_arts_ai(cpu_mystic_arts_ai)

	if cpu_spell_ai and spell_phase_handler.spell_systems and spell_phase_handler.spell_systems.spell_synthesis:
		cpu_spell_ai.set_spell_synthesis(spell_phase_handler.spell_systems.spell_synthesis)

	# Step 4.6: CPUSpellAIContainer を初期化（Phase 5-2）
	_initialize_cpu_spell_ai_container()

	# MysticArtsHandler の初期化（spell_mystic_arts を設定）
	if spell_phase_handler.mystic_arts_handler:
		spell_phase_handler.mystic_arts_handler.initialize_spell_mystic_arts()
		spell_phase_handler.spell_mystic_arts = spell_phase_handler.mystic_arts_handler.get_spell_mystic_arts()

	# === Phase 6-A: MysticArtsHandler の UI Signal を接続
	if spell_phase_handler.spell_ui_manager and spell_phase_handler.mystic_arts_handler:
		spell_phase_handler.spell_ui_manager.connect_mystic_arts_signals(spell_phase_handler.mystic_arts_handler)
		print("[GameSystemManager] MysticArtsHandler UI Signal 接続完了")

	print("[GameSystemManager] _initialize_spell_phase_subsystems 完了")

## CPUSpellPhaseHandler 初期化
func _initialize_cpu_spell_phase_handler(spell_phase_handler) -> void:
	if not spell_phase_handler:
		push_error("[GameSystemManager] spell_phase_handler が null です")
		return

	if not cpu_spell_phase_handler:
		cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
		cpu_spell_phase_handler.initialize(spell_phase_handler)
		print("[CPUSpellPhaseHandler] 初期化完了")

	# SpellPhaseHandler に参照を設定
	spell_phase_handler.cpu_spell_phase_handler = cpu_spell_phase_handler

## CPU移動評価システムの初期化
func _initialize_cpu_movement_evaluator() -> void:
	if not game_flow_manager or not board_system_3d:
		return

	# CPU AI共有コンテキストを作成
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
		# === 直接参照を設定（チェーンアクセス解消） ===
		if game_flow_manager.battle_status_overlay:
			board_system_3d.cpu_turn_processor.set_battle_status_overlay(game_flow_manager.battle_status_overlay)
		if game_flow_manager.item_phase_handler:
			board_system_3d.cpu_turn_processor.set_item_phase_handler(game_flow_manager.item_phase_handler)
		if game_flow_manager.dominio_command_handler:
			board_system_3d.cpu_turn_processor.set_dominio_command_handler(game_flow_manager.dominio_command_handler)

	# CPUMovementEvaluatorを作成（コンテキスト経由）
	cpu_movement_evaluator = CPUMovementEvaluator.new()
	cpu_movement_evaluator.setup_with_context(
		cpu_context,
		board_system_3d.get_movement_controller_ref(),
		spell_mov,
		battle_ai,
		cpu_ai_handler
	)

	# GameFlowManagerに設定（board_system_3d へのパス）
	game_flow_manager.set_cpu_movement_evaluator(cpu_movement_evaluator)

	# cpu_spell_ai に直接注入（SPHパススルー廃止）
	if cpu_spell_ai:
		cpu_spell_ai.set_movement_evaluator(cpu_movement_evaluator)

	print("[CPUMovementEvaluator] 初期化完了（距離計算は遅延実行）")

# =============================================================================
# 委譲メソッド（チェーンアクセス解消用）
# =============================================================================

## lap_systemにマップ設定を適用（game_3d.gd, quest_game.gd用）
func apply_map_settings_to_lap_system(map_data: Dictionary) -> void:
	if game_flow_manager and game_flow_manager.lap_system:
		game_flow_manager.lap_system.apply_map_settings(map_data)
		print("[GameSystemManager] lap_system マップ設定適用完了")

## GameFlowManagerにステージデータを設定（quest_game.gd用）
func set_stage_data(stage_data: Dictionary) -> void:
	if game_flow_manager:
		game_flow_manager.set_stage_data(stage_data)
		print("[GameSystemManager] ステージデータ設定完了")

## GameFlowManagerにリザルト画面を設定（quest_game.gd用）
func set_result_screen(result_screen) -> void:
	if game_flow_manager:
		game_flow_manager.set_result_screen(result_screen)
		print("[GameSystemManager] リザルト画面設定完了")

## CPU AI 全体初期化（GameSystemManagerで一元管理）
func _initialize_cpu_ai_systems() -> void:
	print("[GameSystemManager] CPU AI 初期化開始")

	if not cpu_ai_context:
		# === Step 1: CPU AI共有コンテキスト作成 ===
		cpu_ai_context = CPUAIContextScript.new()
		cpu_ai_context.setup(board_system_3d, player_system, card_system)
		cpu_ai_context.setup_optional(
			BaseTile.creature_manager if BaseTile.creature_manager else null,
			game_flow_manager.lap_system if game_flow_manager else null,
			game_flow_manager,
			battle_system,
			player_buff_system
		)
		print("[GameSystemManager] CPU AI コンテキスト作成完了")

	# === Step 2: CPU AI インスタンス作成（SpellPhaseHandler用） ===
	var has_game_stats = game_flow_manager and game_flow_manager.has_method("get")

	if not cpu_battle_ai:
		cpu_battle_ai = CPUBattleAIScript.new()
		cpu_battle_ai.setup_with_context(cpu_ai_context)

	if not cpu_spell_ai:
		cpu_spell_ai = CPUSpellAIScript.new()
		cpu_spell_ai.initialize(cpu_ai_context)
		cpu_spell_ai.set_battle_ai(cpu_battle_ai)
		if has_game_stats:
			cpu_spell_ai.set_game_stats(game_flow_manager.game_stats)

	if not cpu_mystic_arts_ai:
		cpu_mystic_arts_ai = CPUMysticArtsAIScript.new()
		cpu_mystic_arts_ai.initialize(cpu_ai_context)
		cpu_mystic_arts_ai.set_battle_ai(cpu_battle_ai)
		if has_game_stats:
			cpu_mystic_arts_ai.set_game_stats(game_flow_manager.game_stats)

	# === Step 3: CPU AI インスタンス作成（ItemPhaseHandler用） ===
	if not cpu_defense_ai:
		cpu_defense_ai = CPUDefenseAIScript.new()
		cpu_defense_ai.setup_with_context(cpu_ai_context)
		var battle_policy = _get_cpu_battle_policy()
		if battle_policy:
			cpu_defense_ai.set_battle_policy(battle_policy)

	# === Step 4: ユーティリティ取得 ===
	cpu_hand_utils = cpu_ai_context.get_hand_utils()

	print("[GameSystemManager] CPU AI 初期化完了")

## CPUSpellAIContainer 初期化（Phase 5-2）
func _initialize_cpu_spell_ai_container() -> void:
	# CPU AI が先に初期化されていることを確認
	if not cpu_ai_context:
		_initialize_cpu_ai_systems()

	# === 追加: CPU Movement Evaluator の初期化を確認 ===
	if not cpu_movement_evaluator:
		_initialize_cpu_movement_evaluator()

	if not cpu_spell_ai_container:
		cpu_spell_ai_container = CPUSpellAIContainerScript.new()
		cpu_spell_ai_container.setup(
			cpu_spell_ai,
			cpu_mystic_arts_ai,
			cpu_hand_utils,
			cpu_movement_evaluator
		)

		if cpu_spell_ai_container.is_valid():
			print("[CPUSpellAIContainer] 初期化完了 ✓")
			systems["CPUSpellAIContainer"] = cpu_spell_ai_container
		else:
			push_error("[CPUSpellAIContainer] 初期化失敗")

## CPU バトルポリシー取得
func _get_cpu_battle_policy():
	if not game_flow_manager or not game_flow_manager.board_system_3d:
		const CPUBattlePolicyScript = preload("res://scripts/cpu_ai/cpu_battle_policy.gd")
		return CPUBattlePolicyScript.create_balanced_policy()

	var board_system = game_flow_manager.board_system_3d
	var cpu_ai_handler = board_system.cpu_ai_handler if board_system else null
	if not cpu_ai_handler:
		const CPUBattlePolicyScript = preload("res://scripts/cpu_ai/cpu_battle_policy.gd")
		return CPUBattlePolicyScript.create_balanced_policy()

	var policy = cpu_ai_handler.battle_policy
	if not policy:
		const CPUBattlePolicyScript = preload("res://scripts/cpu_ai/cpu_battle_policy.gd")
		policy = CPUBattlePolicyScript.create_balanced_policy()
		cpu_ai_handler.battle_policy = policy
	return policy

## Phase 6-B: DicePhaseHandler UI Signal接続
func _connect_dice_phase_signals(dice_handler, p_ui_manager) -> void:
	if not dice_handler or not p_ui_manager:
		push_error("[GSM] DicePhaseHandler または UIManager が null です")
		return

	if not dice_handler.dice_ui_big_result_requested.is_connected(p_ui_manager.show_big_dice_result):
		dice_handler.dice_ui_big_result_requested.connect(p_ui_manager.show_big_dice_result)
	if not dice_handler.dice_ui_double_result_shown.is_connected(p_ui_manager.show_dice_result_double):
		dice_handler.dice_ui_double_result_shown.connect(p_ui_manager.show_dice_result_double)
	if not dice_handler.dice_ui_triple_result_shown.is_connected(p_ui_manager.show_dice_result_triple):
		dice_handler.dice_ui_triple_result_shown.connect(p_ui_manager.show_dice_result_triple)
	if not dice_handler.dice_ui_range_result_shown.is_connected(p_ui_manager.show_dice_result_range):
		dice_handler.dice_ui_range_result_shown.connect(p_ui_manager.show_dice_result_range)
	if not dice_handler.dice_ui_phase_text_requested.is_connected(p_ui_manager.set_phase_text):
		dice_handler.dice_ui_phase_text_requested.connect(p_ui_manager.set_phase_text)
	if not dice_handler.dice_ui_navigation_disabled.is_connected(p_ui_manager.disable_navigation):
		dice_handler.dice_ui_navigation_disabled.connect(p_ui_manager.disable_navigation)

	# Comment & Wait（ラムダ接続 - 初回のみ接続されるため is_connected 不要）
	dice_handler.dice_ui_comment_and_wait_requested.connect(
		func(message: String, player_id: int):
			if p_ui_manager and p_ui_manager.global_comment_ui:
				await p_ui_manager.show_comment_and_wait(message, player_id)
			dice_handler.dice_ui_comment_and_wait_completed.emit()
	)
	print("[GSM] DicePhaseHandler UI Signal接続完了（7シグナル）")

## Phase 6-C: TollPaymentHandler UI Signal接続
func _connect_toll_payment_signals(toll_handler, p_ui_manager) -> void:
	if not toll_handler or not p_ui_manager:
		push_error("[GSM] TollPaymentHandler または UIManager が null です")
		return

	toll_handler.toll_ui_comment_and_wait_requested.connect(
		func(message: String, player_id: int):
			if p_ui_manager and p_ui_manager.global_comment_ui:
				await p_ui_manager.show_comment_and_wait(message, player_id, true)
			toll_handler.toll_ui_comment_and_wait_completed.emit()
	)
	print("[GSM] TollPaymentHandler UI Signal接続完了（1シグナル）")

## Phase 6-C: DiscardHandler UI Signal接続
func _connect_discard_signals(discard_handler, p_ui_manager, p_player_system) -> void:
	if not discard_handler or not p_ui_manager:
		push_error("[GSM] DiscardHandler または UIManager が null です")
		return

	discard_handler.discard_ui_prompt_requested.connect(
		func(player_id: int):
			var current_player = p_player_system.get_player_by_id(player_id) if p_player_system.has_method("get_player_by_id") else p_player_system.get_current_player()
			if not current_player:
				discard_handler.discard_ui_prompt_completed.emit(-1)
				return
			p_ui_manager.card_selection_filter = ""
			p_ui_manager.show_card_selection_ui_mode(current_player, "discard")
			var card_index = await p_ui_manager.card_selected
			p_ui_manager.hide_card_selection_ui()
			if p_ui_manager.phase_display:
				p_ui_manager.hide_action_prompt()
			discard_handler.discard_ui_prompt_completed.emit(card_index)
	)
	print("[GSM] DiscardHandler UI Signal接続完了（1シグナル）")

## Phase 6-C: BankruptcyHandler UI Signal接続 + Phase 8-C: パネル分離
func _connect_bankruptcy_signals(bankruptcy_handler_ref, p_ui_manager) -> void:
	if not bankruptcy_handler_ref or not p_ui_manager:
		push_error("[GSM] BankruptcyHandler または UIManager が null です")
		return

	bankruptcy_handler_ref.bankruptcy_ui_comment_and_wait_requested.connect(
		func(message: String, player_id: int):
			if p_ui_manager and p_ui_manager.global_comment_ui:
				await p_ui_manager.show_comment_and_wait(message, player_id, true)
			bankruptcy_handler_ref.bankruptcy_ui_comment_and_wait_completed.emit()
	)
	if p_ui_manager and p_ui_manager.player_info_service:
		if not bankruptcy_handler_ref.bankruptcy_ui_player_info_updated.is_connected(p_ui_manager.player_info_service.update_panels):
			bankruptcy_handler_ref.bankruptcy_ui_player_info_updated.connect(p_ui_manager.player_info_service.update_panels)
	bankruptcy_handler_ref.bankruptcy_ui_card_info_shown.connect(
		func(creature_data: Dictionary, tile_index: int):
			p_ui_manager.show_card_info(creature_data, tile_index, false)
	)
	bankruptcy_handler_ref.bankruptcy_ui_info_panels_hidden.connect(
		func():
			p_ui_manager.hide_all_info_panels(false)
	)

	# Phase 8-C: BankruptcyInfoPanelUI を作成して接続
	if ui_layer:
		var bankruptcy_info_panel_ui = BankruptcyInfoPanelUI.new(ui_layer)
		if not bankruptcy_handler_ref.bankruptcy_info_panel_show_requested.is_connected(bankruptcy_info_panel_ui.show_panel):
			bankruptcy_handler_ref.bankruptcy_info_panel_show_requested.connect(bankruptcy_info_panel_ui.show_panel)
		if not bankruptcy_handler_ref.bankruptcy_info_panel_hide_requested.is_connected(bankruptcy_info_panel_ui.hide_panel):
			bankruptcy_handler_ref.bankruptcy_info_panel_hide_requested.connect(bankruptcy_info_panel_ui.hide_panel)
		print("[GSM] BankruptcyInfoPanelUI Signal接続完了（2シグナル）")
	else:
		push_warning("[GSM] ui_layer が利用できません - BankruptcyInfoPanelUI を作成できません")

	print("[GSM] BankruptcyHandler UI Signal接続完了（6シグナル）")

## Phase 8-A: ItemPhaseHandler UI Signal接続
func _connect_item_phase_signals(item_handler, p_ui_manager) -> void:
	if not item_handler or not p_ui_manager:
		push_error("[GSM] ItemPhaseHandler または UIManager が null です")
		return

	# フィルター設定 → UIManager のフィルター変数を設定
	item_handler.item_filter_configured.connect(
		func(config: Dictionary):
			if p_ui_manager:
				p_ui_manager.blocked_item_types = config.get("blocked_item_types", [])
				p_ui_manager.card_selection_filter = config.get("card_selection_filter", "")
				p_ui_manager.assist_target_elements = config.get("assist_target_elements", [])
	)

	# フィルタークリア → UIManager のフィルター変数をリセット
	item_handler.item_filter_cleared.connect(
		func():
			if p_ui_manager:
				p_ui_manager.card_selection_filter = ""
				p_ui_manager.assist_target_elements = []
				p_ui_manager.blocked_item_types = []
	)

	# 手札表示更新 → UIManager の update_hand_display を呼び出し
	item_handler.item_hand_display_update_requested.connect(
		func(player_id: int):
			if p_ui_manager:
				p_ui_manager.update_hand_display(player_id)
	)

	# カード選択UI表示 → UIManager の CardSelectionUI を操作
	item_handler.item_selection_ui_show_requested.connect(
		func(player, mode: String):
			if p_ui_manager and p_ui_manager.card_selection_ui and p_ui_manager.card_selection_ui.has_method("show_selection"):
				# アイテムフェーズではドミニオコマンドボタンを非表示
				p_ui_manager.clear_special_button()
				p_ui_manager.card_selection_ui.show_selection(player, mode)
	)

	print("[GSM] ItemPhaseHandler UI Signal接続完了（4シグナル）")

## Phase 10-C: UIManager/外部ハンドラーへのCallable/Signal注入
func _setup_ui_callbacks(
	p_ui_manager: UIManager,
	p_game_flow_manager: GameFlowManager,
	p_board_system_3d: BoardSystem3D,
	p_dominio_command_handler,
	p_spell_phase_handler
) -> void:
	if not p_ui_manager:
		return

	# === UIManager Callable 注入 ===
	if p_game_flow_manager:
		p_ui_manager._is_input_locked_cb = Callable(p_game_flow_manager, "is_input_locked")
		# NOTE: _on_card_selected_cb, _spell_card_selecting_cb は EventHub 移行済み（Phase 11）

	if p_board_system_3d:
		p_ui_manager._has_owned_lands_cb = func() -> bool:
			return p_board_system_3d.has_owned_lands(p_board_system_3d.current_player_index)

		p_ui_manager._update_tile_display_cb = func(tile_idx: int) -> void:
			if p_board_system_3d.tile_info_display:
				var tile_info = p_board_system_3d.get_tile_info(tile_idx)
				if not tile_info.is_empty():
					p_board_system_3d.tile_info_display.update_display(tile_idx, tile_info)

	# NOTE: dominio_cancel_requested は EventHub 移行済み（Phase 11）

	# === CardSelectionHandler Callable 注入 ===
	if p_spell_phase_handler and p_spell_phase_handler.card_selection_handler:
		var csh = p_spell_phase_handler.card_selection_handler
		if p_game_flow_manager:
			csh._unlock_input_cb = Callable(p_game_flow_manager, "unlock_input")
		if p_board_system_3d:
			csh._restore_camera_cb = func() -> void:
				p_board_system_3d.enable_follow_camera()
				p_board_system_3d.return_camera_to_player()

	# === UITapHandler Callable 注入 ===
	if p_ui_manager.tap_handler:
		if p_board_system_3d:
			p_ui_manager.tap_handler._get_camera_controller_cb = Callable(
				p_board_system_3d, "get_camera_controller_ref"
			)
		if p_dominio_command_handler:
			var dch = p_dominio_command_handler
			p_ui_manager.tap_handler._is_dominio_active_cb = func() -> bool:
				return dch.current_state != dch.State.CLOSED
		if p_spell_phase_handler:
			p_ui_manager.tap_handler._is_spell_phase_active_cb = Callable(
				p_spell_phase_handler, "is_spell_phase_active"
			)

	print("[GameSystemManager] Phase 10-C: UI Callable/Signal 注入完了")

## Phase 11: UIEventHub のイベント配線（GSMが配線責任者）
func _setup_ui_events() -> void:
	if not ui_event_hub:
		return

	# EventHub参照を注入
	if ui_manager:
		ui_manager._ui_event_hub = ui_event_hub
	if ui_manager and ui_manager.game_menu_handler:
		ui_manager.game_menu_handler._ui_event_hub = ui_event_hub

	# hand_card_tapped: ルーティングハンドラー
	if not ui_event_hub.hand_card_tapped.is_connected(_on_hand_card_tapped):
		ui_event_hub.hand_card_tapped.connect(_on_hand_card_tapped)

	# dominio_cancel: DCHに接続
	if game_flow_manager and game_flow_manager.dominio_command_handler:
		if not ui_event_hub.dominio_cancel_requested.is_connected(game_flow_manager.dominio_command_handler.cancel):
			ui_event_hub.dominio_cancel_requested.connect(game_flow_manager.dominio_command_handler.cancel)

	# surrender: GFMに接続
	if game_flow_manager:
		var surrender_cb = func(): game_flow_manager.on_player_defeated("surrender")
		ui_event_hub.surrender_requested.connect(surrender_cb)

	print("[GameSystemManager] UIEventHub イベント配線完了")


## 手札カードタップのルーティング（GSMが判断）
func _on_hand_card_tapped(card_index: int) -> void:
	# スペルフェーズ中: GFMが直接処理
	var sph = game_flow_manager.spell_phase_handler if game_flow_manager else null
	if sph and sph.card_selection_handler and sph.card_selection_handler.is_selecting():
		game_flow_manager.on_card_selected(card_index)
		return

	# その他: card_selection_ui が処理
	if ui_manager and ui_manager.card_selection_ui and ui_manager.card_selection_ui.has_method("on_card_selected"):
		ui_manager.card_selection_ui.on_card_selected(card_index)


## === Phase 11-B: TapTargetManager直接注入 ===
## UIManager経由アクセスを除去し、各消費者に直接参照を注入
func _inject_tap_target_manager() -> void:
	if not ui_manager or not ui_manager.tap_target_manager:
		push_warning("[GameSystemManager] TapTargetManager が初期化されていません")
		return

	var ttm = ui_manager.tap_target_manager

	# UITapHandler に注入
	if ui_manager and ui_manager.tap_handler:
		ui_manager.tap_handler._tap_target_manager = ttm
		print("[GameSystemManager] TapTargetManager → UITapHandler 注入完了")

	# SpellTargetSelectionHandler に注入
	var spell_phase_handler_ref = game_flow_manager.spell_phase_handler if game_flow_manager else null
	if spell_phase_handler_ref and spell_phase_handler_ref.spell_target_selection_handler:
		spell_phase_handler_ref.spell_target_selection_handler._tap_target_manager = ttm
		print("[GameSystemManager] TapTargetManager → SpellTargetSelectionHandler 注入完了")

	# SpellMysticArts に注入
	if game_flow_manager and game_flow_manager.spell_container and game_flow_manager.spell_container.spell_mystic_arts:
		game_flow_manager.spell_container.spell_mystic_arts._tap_target_manager = ttm
		print("[GameSystemManager] TapTargetManager → SpellMysticArts 注入完了")
