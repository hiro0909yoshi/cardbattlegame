extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム（クリーンアップ版）

signal phase_changed(new_phase: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# ゲーム状態
enum GamePhase {
	SETUP,
	DICE_ROLL,
	MOVING,
	TILE_ACTION,
	BATTLE,
	END_TURN
}

var current_phase = GamePhase.SETUP

# ハンドラークラス
var tile_action_handler: TileActionHandler
var battle_handler: BattleHandler
var cpu_ai_handler: CPUAIHandler
var player_action_handler: PlayerActionHandler

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var board_system: BoardSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem

func _ready():
	# ハンドラーをインスタンス化
	tile_action_handler = TileActionHandler.new()
	battle_handler = BattleHandler.new()
	cpu_ai_handler = CPUAIHandler.new()
	player_action_handler = PlayerActionHandler.new()
	
	# 子ノードとして追加
	add_child(tile_action_handler)
	add_child(battle_handler)
	add_child(cpu_ai_handler)
	add_child(player_action_handler)
	
	# ハンドラーのシグナルを接続
	connect_handler_signals()

# ハンドラーのシグナルを接続
func connect_handler_signals():
	# タイルアクションハンドラー
	tile_action_handler.action_completed.connect(_on_tile_action_completed)
	tile_action_handler.summon_requested.connect(_on_summon_requested)
	tile_action_handler.battle_requested.connect(_on_battle_requested)
	tile_action_handler.level_up_requested.connect(_on_level_up_requested)
	tile_action_handler.toll_payment_required.connect(_on_toll_payment_required)
	
	# バトルハンドラー
	battle_handler.battle_completed.connect(_on_battle_completed)
	battle_handler.card_selection_required.connect(_on_card_selection_required)
	
	# CPU AIハンドラー
	cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided)
	cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided)
	cpu_ai_handler.level_up_decided.connect(_on_cpu_level_up_decided)
	
	# プレイヤーアクションハンドラー
	player_action_handler.summon_selected.connect(_on_player_summon_selected)
	player_action_handler.battle_selected.connect(_on_player_battle_selected)
	player_action_handler.level_up_selected.connect(_on_player_level_up_selected)
	player_action_handler.pass_selected.connect(_on_player_pass_selected)

# システム参照を設定
func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BoardSystem, 
					s_system: SkillSystem, ui_system: UIManager, 
					bt_system: BattleSystem = null, st_system: SpecialTileSystem = null):
	player_system = p_system
	card_system = c_system
	board_system = b_system
	skill_system = s_system
	ui_manager = ui_system
	battle_system = bt_system
	special_tile_system = st_system
	
	# 各ハンドラーにシステム参照を設定
	tile_action_handler.setup_systems(board_system, player_system, card_system, special_tile_system)
	battle_handler.setup_systems(battle_system, board_system, card_system, player_system, skill_system)
	cpu_ai_handler.setup_systems(card_system, board_system, player_system, battle_system, skill_system)
	player_action_handler.setup_systems(ui_manager, card_system)

# ゲーム開始
func start_game():
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	print("ターン開始: ", current_player.name)  # 最小デバッグ
	
	# カードを1枚引く
	draw_card_for_turn(current_player)
	
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()

# ターン開始時のカードドロー
func draw_card_for_turn(current_player):
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	
	if hand_size < card_system.max_hand_size:
		var drawn_card = card_system.draw_card_for_player(current_player.id)
		if not drawn_card.is_empty() and current_player.id > 0:
			ui_manager.update_cpu_hand_display(current_player.id)

# フェーズ変更
func change_phase(new_phase: GamePhase):
	current_phase = new_phase
	emit_signal("phase_changed", current_phase)
	update_ui()

# サイコロを振る
func roll_dice():
	if current_phase != GamePhase.DICE_ROLL:
		return
	
	ui_manager.set_dice_button_enabled(false)
	change_phase(GamePhase.MOVING)
	
	var dice_value = player_system.roll_dice()
	var modified_dice = skill_system.modify_dice_roll(dice_value, player_system.current_player_index)
	
	ui_manager.show_dice_result(modified_dice, get_parent())
	
	var current_player = player_system.get_current_player()
	await get_tree().create_timer(1.0).timeout
	player_system.move_player_steps(current_player.id, modified_dice, board_system)

# 移動完了
func on_movement_completed(final_tile: int):
	change_phase(GamePhase.TILE_ACTION)
	
	var current_player = player_system.get_current_player()
	tile_action_handler.process_tile_action(final_tile, current_player)

# === タイルアクションイベント ===
func _on_tile_action_completed():
	end_turn()

func _on_summon_requested():
	var current_player = player_system.get_current_player()
	
	if current_player.id == 0:
		# プレイヤー
		await player_action_handler.show_summon_choice(current_player)
		await player_action_handler.wait_for_player_choice()
	else:
		# CPU
		cpu_ai_handler.decide_summon(current_player)

func _on_battle_requested():
	change_phase(GamePhase.BATTLE)
	var tile_info = tile_action_handler.get_current_tile_info()
	var current_player = tile_action_handler.get_current_player()
	battle_handler.start_battle_sequence(tile_info, current_player)

func _on_level_up_requested():
	var current_player = player_system.get_current_player()
	var tile_info = tile_action_handler.get_current_tile_info()
	
	if current_player.id == 0:
		# プレイヤー
		await player_action_handler.show_level_up_choice(tile_info, current_player)
		await player_action_handler.wait_for_player_choice()
	else:
		# CPU
		cpu_ai_handler.decide_level_up(current_player, tile_info)

func _on_toll_payment_required(amount: int):
	var current_player = player_system.get_current_player()
	var tile_info = tile_action_handler.get_current_tile_info()
	player_system.pay_toll(current_player.id, tile_info.get("owner", -1), amount)
	end_turn()

# === バトルイベント ===
func _on_battle_completed(result: Dictionary):
	# 通行料支払いも含めて全てのバトル終了後にターンエンド
	end_turn()

func _on_card_selection_required(mode: String):
	var current_player = player_system.get_current_player()
	var tile_info = battle_handler.get_current_context().tile_info
	
	if current_player.id == 0:
		# プレイヤー
		await player_action_handler.show_battle_choice(current_player, tile_info, mode)
		await player_action_handler.wait_for_player_choice()
	else:
		# CPU
		if mode == "invasion":
			cpu_ai_handler.decide_invasion(current_player, tile_info)
		else:
			cpu_ai_handler.decide_battle(current_player, tile_info)

# === プレイヤーアクションイベント ===
func _on_player_summon_selected(card_index: int):
	if card_index >= 0:
		execute_summon(player_system.get_current_player(), card_index)
	end_turn()

func _on_player_battle_selected(card_index: int):
	if card_index >= 0:
		battle_handler.on_card_selected(card_index)
	else:
		battle_handler.cancel_battle()

func _on_player_level_up_selected(target_level: int, cost: int):
	if target_level > 0:
		execute_level_up(player_system.get_current_player(), target_level, cost)
	end_turn()

func _on_player_pass_selected():
	var context = battle_handler.get_current_context()
	if not context.is_empty():
		battle_handler.cancel_battle()
	else:
		end_turn()

# === CPU AIイベント ===
func _on_cpu_summon_decided(card_index: int):
	if card_index >= 0:
		execute_summon(player_system.get_current_player(), card_index)
	end_turn()

func _on_cpu_battle_decided(card_index: int):
	if card_index >= 0:
		battle_handler.on_card_selected(card_index)
	else:
		battle_handler.cancel_battle()

func _on_cpu_level_up_decided(do_upgrade: bool):
	if do_upgrade:
		var current_player = player_system.get_current_player()
		var tile_info = tile_action_handler.get_current_tile_info()
		var cost = board_system.get_upgrade_cost(tile_info.get("index", 0))
		execute_level_up(current_player, tile_info.get("level", 1) + 1, cost)
	end_turn()

# === 実行処理 ===
func execute_summon(current_player, card_index: int):
	var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
	if not card_data.is_empty():
		var cost = skill_system.modify_card_cost(
			card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER,
			card_data,
			current_player.id
		)
		
		if current_player.magic_power >= cost:
			var used_card = card_system.use_card_for_player(current_player.id, card_index)
			if not used_card.is_empty():
				tile_action_handler.place_creature(used_card)
				player_system.add_magic(current_player.id, -cost)
				
				if current_player.id > 0:
					ui_manager.update_cpu_hand_display(current_player.id)

func execute_level_up(current_player, target_level: int, cost: int):
	tile_action_handler.execute_level_up(target_level)
	player_system.add_magic(current_player.id, -cost)

# === UIコールバック ===
func on_card_selected(card_index: int):
	player_action_handler.on_card_selected(card_index)

func on_level_up_selected(target_level: int, cost: int):
	player_action_handler.on_level_up_selected(target_level, cost)

func on_pass_button_pressed():
	player_action_handler.on_pass_button_pressed()

# ターン終了
func end_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_ended", current_player.id)
	print("ターン終了: ", current_player.name)  # 最小デバッグ
	
	change_phase(GamePhase.END_TURN)
	skill_system.end_turn_cleanup()
	player_system.next_player()
	
	await get_tree().create_timer(GameConstants.TURN_END_DELAY).timeout
	start_turn()

# プレイヤー勝利処理
func on_player_won(player_id: int):
	var player = player_system.players[player_id]
	change_phase(GamePhase.SETUP)
	ui_manager.set_dice_button_enabled(false)
	ui_manager.phase_label.text = player.name + "の勝利！"

# UI更新
func update_ui():
	var current_player = player_system.get_current_player()
	ui_manager.update_ui(current_player, current_phase)
