extends Node2D
# メインゲーム管理スクリプト（プレイヤー別手札対応版）

# システムの参照
var board_system: BoardSystem
var card_system: CardSystem
var player_system: PlayerSystem
var battle_system: BattleSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var game_flow: GameFlowManager

var player_count = 2  # プレイヤー数

func _ready():
	print("=== カルドセプト風ゲーム開始 ===")
	initialize_systems()
	setup_game()
	connect_signals()
	game_flow.start_game()

# システムを初期化
func initialize_systems():
	# 各システムをインスタンス化
	board_system = BoardSystem.new()
	card_system = CardSystem.new()
	player_system = PlayerSystem.new()
	battle_system = BattleSystem.new()
	skill_system = SkillSystem.new()
	ui_manager = UIManager.new()
	game_flow = GameFlowManager.new()
	
	# 名前を設定（参照用）
	board_system.name = "BoardSystem"
	card_system.name = "CardSystem"
	player_system.name = "PlayerSystem"
	battle_system.name = "BattleSystem"
	skill_system.name = "SkillSystem"
	ui_manager.name = "UIManager"
	game_flow.name = "GameFlowManager"
	
	# シーンツリーに追加
	add_child(board_system)
	add_child(card_system)
	add_child(player_system)
	add_child(battle_system)
	add_child(skill_system)
	add_child(ui_manager)
	add_child(game_flow)
	
	# GameFlowにシステム参照を設定
	game_flow.setup_systems(player_system, card_system, board_system, skill_system, ui_manager)
	
	print("全システム初期化完了")

# ゲームをセットアップ
func setup_game():
	# BoardMapノードがなければ作成
	if not has_node("BoardMap"):
		var board_map_node = Node2D.new()
		board_map_node.name = "BoardMap"
		add_child(board_map_node)
	
	# ボードを作成
	board_system.create_board($BoardMap)
	
	# プレイヤーを初期化
	player_system.initialize_players(player_count, self)
	
	# 各プレイヤーに初期手札を配る
	if not has_node("Hand"):
		var hand_node = Node2D.new()
		hand_node.name = "Hand"
		add_child(hand_node)
	
	# 全プレイヤーに初期手札を配る
	card_system.deal_initial_hands_all_players(player_count)
	
	# 初期配置
	for i in range(player_count):
		player_system.place_player_at_tile(i, 0, board_system)
	
	# UIを作成
	ui_manager.create_ui(self)
	
	# デバッグ表示用にCPU手札を更新
	if player_count > 1:
		ui_manager.update_cpu_hand_display(1)

# シグナルを接続
func connect_signals():
	# PlayerSystemのシグナル
	player_system.dice_rolled.connect(_on_dice_rolled)
	player_system.movement_completed.connect(_on_movement_completed)
	player_system.magic_changed.connect(_on_magic_changed)
	player_system.player_won.connect(_on_player_won)
	
	# CardSystemのシグナル
	card_system.card_used.connect(_on_card_used)
	card_system.hand_updated.connect(_on_hand_updated)
	
	# BattleSystemのシグナル
	battle_system.battle_ended.connect(_on_battle_ended)
	
	# UIManagerのシグナル
	ui_manager.dice_button_pressed.connect(_on_dice_button_pressed)
	ui_manager.summon_button_pressed.connect(_on_summon_button_pressed)
	ui_manager.pass_button_pressed.connect(_on_pass_button_pressed)
	ui_manager.card_selected.connect(_on_card_selected)
	
	# GameFlowManagerのシグナル
	game_flow.phase_changed.connect(_on_phase_changed)
	game_flow.turn_started.connect(_on_turn_started)
	game_flow.turn_ended.connect(_on_turn_ended)

# イベントハンドラー
func _on_dice_button_pressed():
	game_flow.roll_dice()

func _on_summon_button_pressed():
	game_flow.on_summon_button_pressed()

func _on_pass_button_pressed():
	game_flow.on_pass_button_pressed()

func _on_card_selected(card_index: int):
	game_flow.on_card_selected(card_index)

func _on_dice_rolled(value: int):
	print("ダイス: ", value)

func _on_movement_completed(final_tile: int):
	game_flow.on_movement_completed(final_tile)

func _on_card_used(card_data: Dictionary):
	print("カード使用: ", card_data.name)

func _on_hand_updated():
	# 現在のプレイヤーの手札数を表示
	var current_player = player_system.get_current_player()
	if current_player:
		var hand_size = card_system.get_hand_size_for_player(current_player.id)
		print(current_player.name, "の手札: ", hand_size, "枚")
		
		# デバッグモードの場合はCPU手札も更新
		if current_player.id > 0 and ui_manager.debug_mode:
			ui_manager.update_cpu_hand_display(current_player.id)

func _on_magic_changed(player_id: int, new_value: int):
	ui_manager.update_ui(player_system.get_current_player(), game_flow.current_phase)

func _on_battle_ended(winner: String, result: Dictionary):
	print("バトル終了: ", winner, "の勝利")
	game_flow.end_turn()

func _on_player_won(player_id: int):
	game_flow.on_player_won(player_id)

func _on_phase_changed(new_phase: int):
	print("フェーズ変更: ", new_phase)

func _on_turn_started(player_id: int):
	print("ターン開始: プレイヤー", player_id + 1)
	# デバッグ表示を更新
	if player_id > 0 and ui_manager.debug_mode:
		ui_manager.update_cpu_hand_display(player_id)

func _on_turn_ended(player_id: int):
	print("ターン終了: プレイヤー", player_id + 1)
