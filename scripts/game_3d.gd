extends Node

# 3Dゲームメイン管理スクリプト

# システム参照
var board_system_3d: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var special_tile_system: SpecialTileSystem
var debug_controller: DebugController

# 設定
var player_count = 2
var player_is_cpu = [false, true]  # Player1=人間, Player2=CPU

func _ready():
	initialize_systems()
	setup_game()
	connect_signals()
	
	# 初期化完了待機
	await get_tree().create_timer(0.5).timeout
	
	start_game()

# システム初期化
func initialize_systems():
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

# ゲームセットアップ
func setup_game():
	# 3Dシーンのノードを収集
	var tiles_container = get_node_or_null("Tiles")
	var players_container = get_node_or_null("Players")
	var camera = get_node_or_null("Camera3D")
	
	if tiles_container:
		board_system_3d.collect_tiles(tiles_container)
	
	if players_container:
		board_system_3d.collect_players(players_container)
		
	if camera:
		board_system_3d.camera = camera
	
	# プレイヤーを初期化
	player_system.initialize_players(player_count, self)
	
	# BoardSystem3Dの設定
	board_system_3d.player_count = player_count
	board_system_3d.player_is_cpu = player_is_cpu
	board_system_3d.current_player_index = 0
	
	# UIManagerにシステム参照を手動設定（UI作成前に設定！）
	ui_manager.board_system_ref = board_system_3d  # 参照は設定するが、初期化時には使わない
	ui_manager.player_system_ref = player_system
	ui_manager.card_system_ref = card_system
	
	# UI作成（システム参照設定後）
	ui_manager.create_ui(self)
	
	# システム参照を設定（修正: battle_systemを正しく渡す）
	board_system_3d.setup_systems(player_system, card_system, battle_system, skill_system)
	board_system_3d.ui_manager = ui_manager
	board_system_3d.card_system = card_system
	
	# DebugControllerにシステム参照を設定
	debug_controller.setup_systems(player_system, null, card_system, ui_manager)
	player_system.set_debug_controller(debug_controller)
	
	# 初期手札を配る
	await get_tree().create_timer(0.1).timeout
	card_system.deal_initial_hands_all_players(player_count)
	
	# UIを初期更新
	await get_tree().create_timer(0.1).timeout
	ui_manager.update_player_info_panels()

# シグナル接続
func connect_signals():
	# PlayerSystemのシグナル
	player_system.dice_rolled.connect(_on_dice_rolled)
	player_system.movement_completed.connect(_on_movement_completed)
	player_system.magic_changed.connect(_on_magic_changed)
	player_system.player_won.connect(_on_player_won)
	
	# BoardSystem3Dのシグナル
	board_system_3d.tile_action_completed.connect(_on_tile_action_completed)
	board_system_3d.movement_started.connect(_on_movement_started)
	board_system_3d.movement_completed.connect(_on_board_movement_completed)
	
	# UIManagerのシグナル
	ui_manager.dice_button_pressed.connect(_on_dice_button_pressed)
	ui_manager.card_selected.connect(_on_card_selected)
	ui_manager.pass_button_pressed.connect(_on_pass_pressed)
	ui_manager.level_up_selected.connect(_on_level_up_selected)
	
	# CardSystemのシグナル
	card_system.card_drawn.connect(_on_card_drawn)
	card_system.card_used.connect(_on_card_used)
	card_system.hand_updated.connect(_on_hand_updated)

# ゲーム開始
func start_game():
	start_turn()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	
	# ターン開始時のカードドロー
	if card_system.get_hand_size_for_player(current_player.id) < 6:
		var drawn = card_system.draw_card_for_player(current_player.id)
		if not drawn.is_empty() and current_player.id == 0:
			await get_tree().create_timer(0.1).timeout
	
	# CPUかプレイヤーか判定
	if board_system_3d.player_is_cpu[current_player.id]:
		# CPUの場合
		ui_manager.set_dice_button_enabled(false)
		ui_manager.phase_label.text = "CPUのターン..."
		await get_tree().create_timer(1.0).timeout
		board_system_3d.start_dice_roll()
	else:
		# プレイヤーの場合
		ui_manager.set_dice_button_enabled(true)
		ui_manager.phase_label.text = "サイコロを振ってください"

# === イベントハンドラ ===

func _on_dice_button_pressed():
	if not board_system_3d.is_moving:
		board_system_3d.start_dice_roll()

func _on_dice_rolled(value: int):
	ui_manager.show_dice_result(value, self)
	
	# 3D移動開始
	var current_player = player_system.get_current_player()
	board_system_3d.move_player_3d(current_player.id, value)

func _on_movement_started():
	ui_manager.set_dice_button_enabled(false)
	ui_manager.phase_label.text = "移動中..."

func _on_movement_completed(_final_tile: int):
	pass

func _on_board_movement_completed(final_tile: int):
	board_system_3d.process_tile_landing(final_tile)

func _on_tile_action_completed():
	board_system_3d.end_current_turn()
	await get_tree().create_timer(0.5).timeout
	start_turn()

func _on_card_selected(card_index: int):
	board_system_3d.on_card_selected(card_index)

func _on_pass_pressed():
	board_system_3d.on_action_pass()

func _on_level_up_selected(target_level: int, cost: int):
	# TODO: レベルアップ処理実装
	pass

func _on_card_drawn(_card_data: Dictionary):
	pass

func _on_card_used(_card_data: Dictionary):
	ui_manager.update_player_info_panels()

func _on_hand_updated():
	pass

func _on_magic_changed(_player_id: int, _new_value: int):
	ui_manager.update_player_info_panels()

func _on_player_won(player_id: int):
	ui_manager.set_dice_button_enabled(false)
	ui_manager.phase_label.text = "プレイヤー" + str(player_id + 1) + "の勝利！"

# デバッグ入力
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_on_dice_button_pressed()
			KEY_6:
				debug_controller.set_debug_dice(6)
			KEY_7:
				debug_controller.set_debug_dice(1)
			KEY_8:
				debug_controller.set_debug_dice(2)
			KEY_9:
				debug_controller.set_debug_dice(3)
			KEY_0:
				debug_controller.clear_debug_dice()
			KEY_D:
				ui_manager.toggle_debug_mode()
