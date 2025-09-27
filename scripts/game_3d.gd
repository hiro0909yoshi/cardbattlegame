extends Node

# 3Dゲームメイン管理スクリプト（スリム化版）
# システム初期化とシグナル接続のみを担当

# システム参照
var board_system_3d: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var special_tile_system: SpecialTileSystem
var debug_controller: DebugController
var game_flow_manager: GameFlowManager

# 設定
var player_count = 2
var player_is_cpu = [false, true]  # Player1=人間, Player2=CPU

func _ready():
	initialize_systems()
	setup_game()
	connect_signals()
	
	await get_tree().create_timer(0.5).timeout
	
	# GameFlowManagerにゲーム開始を委任
	game_flow_manager.start_game()

# システム初期化
func initialize_systems():
	# SignalRegistryを最初に作成（重要）
	var signal_registry = SignalRegistry.new()
	signal_registry.name = "SignalRegistry"
	add_child(signal_registry)
	
	# BoardSystem3Dを作成
	board_system_3d = BoardSystem3D.new()
	board_system_3d.name = "BoardSystem3D"
	add_child(board_system_3d)
	
	# PlayerSystemを作成
	player_system = PlayerSystem.new()
	player_system.name = "PlayerSystem"
	add_child(player_system)
	
	# CardSystemを作成
	card_system = CardSystem.new()
	card_system.name = "CardSystem"
	add_child(card_system)
	
	# BattleSystemを作成
	battle_system = BattleSystem.new()
	battle_system.name = "BattleSystem"
	add_child(battle_system)
	
	# SkillSystemを作成
	skill_system = SkillSystem.new()
	skill_system.name = "SkillSystem"
	add_child(skill_system)
	
	# SpecialTileSystemを作成
	special_tile_system = SpecialTileSystem.new()
	special_tile_system.name = "SpecialTileSystem"
	add_child(special_tile_system)
	
	# UIManagerを作成
	ui_manager = UIManager.new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	
	# DebugControllerを作成
	debug_controller = DebugController.new()
	debug_controller.name = "DebugController"
	add_child(debug_controller)
	
	# GameFlowManagerを作成
	game_flow_manager = GameFlowManager.new()
	game_flow_manager.name = "GameFlowManager"
	add_child(game_flow_manager)

# ゲームセットアップ
func setup_game():
	# 3Dノード収集
	var tiles_container = get_node_or_null("Tiles")
	var players_container = get_node_or_null("Players")
	var camera = get_node_or_null("Camera3D")
	
	if tiles_container:
		board_system_3d.collect_tiles(tiles_container)
	
	if players_container:
		board_system_3d.collect_players(players_container)
		
	if camera:
		board_system_3d.camera = camera
	
	# プレイヤー初期化
	player_system.initialize_players(player_count, self)
	
	# BoardSystem3D設定
	board_system_3d.player_count = player_count
	board_system_3d.player_is_cpu = player_is_cpu
	board_system_3d.current_player_index = 0
	
	# UIManager設定
	ui_manager.board_system_ref = board_system_3d
	ui_manager.player_system_ref = player_system
	ui_manager.card_system_ref = card_system
	ui_manager.create_ui(self)
	
	# システム連携設定
	board_system_3d.setup_systems(player_system, card_system, battle_system, skill_system)
	board_system_3d.ui_manager = ui_manager
	
	# GameFlowManager設定（3D対応）
	game_flow_manager.setup_systems(player_system, card_system, board_system_3d, 
									skill_system, ui_manager, battle_system, special_tile_system)
	game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)
	
	# Debug設定
	debug_controller.setup_systems(player_system, board_system_3d, card_system, ui_manager)
	player_system.set_debug_controller(debug_controller)
	
	# 初期手札配布
	await get_tree().create_timer(0.1).timeout
	card_system.deal_initial_hands_all_players(player_count)
	
	await get_tree().create_timer(0.1).timeout
	ui_manager.update_player_info_panels()
	
	# 操作説明を表示
	print("\n=== 操作方法 ===")
	print("【V】キー: 通行料/HP/ST表示切替")
	print("【S】キー: シグナル接続状態を表示")
	print("【D】キー: デバッグモード切替")
	print("【数字1-6】: サイコロ固定（デバッグ）")
	print("【0】キー: サイコロ固定解除")
	print("================\n")

# シグナル接続
func connect_signals():
	# GameFlowManagerのシグナル
	game_flow_manager.dice_rolled.connect(_on_dice_rolled)
	game_flow_manager.turn_started.connect(_on_turn_started)
	game_flow_manager.turn_ended.connect(_on_turn_ended)
	game_flow_manager.phase_changed.connect(_on_phase_changed)
	
	# PlayerSystemのシグナル
	player_system.magic_changed.connect(ui_manager.update_player_info_panels)
	player_system.player_won.connect(game_flow_manager.on_player_won)
	
	# UIManagerのシグナル
	ui_manager.dice_button_pressed.connect(game_flow_manager.roll_dice)
	ui_manager.card_selected.connect(game_flow_manager.on_card_selected)
	ui_manager.pass_button_pressed.connect(game_flow_manager.on_pass_button_pressed)
	ui_manager.level_up_selected.connect(game_flow_manager.on_level_up_selected)

# === イベントハンドラ（最小限） ===

func _on_dice_rolled(value: int):
	ui_manager.show_dice_result(value, self)

func _on_turn_started(player_id: int):
	print("\n=== プレイヤー", player_id + 1, "のターン ===")

func _on_turn_ended(player_id: int):
	pass  # 必要に応じて処理追加

func _on_phase_changed(new_phase):
	pass  # 必要に応じて処理追加

# デバッグ入力
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				game_flow_manager.roll_dice()
			KEY_V:
				# Vキーで表示切替
				if board_system_3d and board_system_3d.tile_info_display:
					board_system_3d.tile_info_display.switch_mode()
					board_system_3d.update_all_tile_displays()
					var mode_name = board_system_3d.tile_info_display.get_current_mode_name()
					print("表示切替: ", mode_name)
					# UIに表示（オプション）
					if ui_manager and ui_manager.phase_label:
						var original_text = ui_manager.phase_label.text
						ui_manager.phase_label.text = "表示: " + mode_name
						await get_tree().create_timer(1.0).timeout
						ui_manager.phase_label.text = original_text
			KEY_S:
				# Sキーでシグナル接続状態を表示（デバッグ）
				SignalRegistry.debug_print_connections()
				var stats = SignalRegistry.get_stats()
				print("総接続数: ", stats.get("total_connections", 0))
			KEY_6:
				debug_controller.set_debug_dice(6)
			KEY_1:
				debug_controller.set_debug_dice(1)
			KEY_2:
				debug_controller.set_debug_dice(2)
			KEY_3:
				debug_controller.set_debug_dice(3)
			KEY_4:
				debug_controller.set_debug_dice(4)
			KEY_5:
				debug_controller.set_debug_dice(5)
			KEY_0:
				debug_controller.clear_debug_dice()
			KEY_D:
				ui_manager.toggle_debug_mode()
