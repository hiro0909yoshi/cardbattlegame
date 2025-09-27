extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム（3D対応版）

signal phase_changed(new_phase: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)
signal dice_rolled(value: int)

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

# 3D用追加変数
var is_3d_mode = false
var board_system_3d = null
var player_is_cpu = []

# ハンドラークラス（3D版では一部のみ使用）
var cpu_ai_handler: CPUAIHandler

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var board_system  # 2D/3D両対応
var skill_system: SkillSystem
var ui_manager: UIManager
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem

func _ready():
	# CPUAIHandlerは3Dでも使用
	cpu_ai_handler = CPUAIHandler.new()
	add_child(cpu_ai_handler)
	
	# CPUハンドラーのシグナル接続
	cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided)
	cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided)
	cpu_ai_handler.level_up_decided.connect(_on_cpu_level_up_decided)

# 3Dモード設定
func setup_3d_mode(board_3d, cpu_settings: Array):
	is_3d_mode = true
	board_system_3d = board_3d
	player_is_cpu = cpu_settings
	
	# 3Dボードのシグナル接続
	if board_system_3d:
		board_system_3d.tile_action_completed.connect(_on_tile_action_completed_3d)
		board_system_3d.movement_started.connect(_on_movement_started_3d)
		board_system_3d.movement_completed.connect(_on_movement_completed_3d)

# システム参照を設定
func setup_systems(p_system, c_system, b_system, s_system, ui_system, 
					bt_system = null, st_system = null):
	player_system = p_system
	card_system = c_system
	board_system = b_system
	skill_system = s_system
	ui_manager = ui_system
	battle_system = bt_system
	special_tile_system = st_system
	
	# CPU AIハンドラー設定（3D対応）
	if cpu_ai_handler:
		cpu_ai_handler.setup_systems(c_system, b_system, p_system, bt_system, s_system)

# ゲーム開始
func start_game():
	print("\n=== ゲーム開始 ===")
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()
	start_turn()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	
	# カードドロー処理
	if card_system.get_hand_size_for_player(current_player.id) < GameConstants.MAX_HAND_SIZE:
		var drawn = card_system.draw_card_for_player(current_player.id)
		if not drawn.is_empty() and current_player.id == 0:
			await get_tree().create_timer(0.1).timeout
	
	# UI更新
	ui_manager.update_player_info_panels()
	
	# 3Dモードの場合
	if is_3d_mode and current_player.id < player_is_cpu.size() and player_is_cpu[current_player.id]:
		ui_manager.set_dice_button_enabled(false)
		ui_manager.phase_label.text = "CPUのターン..."
		current_phase = GamePhase.DICE_ROLL
		await get_tree().create_timer(1.0).timeout
		roll_dice()
	else:
		current_phase = GamePhase.DICE_ROLL
		ui_manager.set_dice_button_enabled(true)
		ui_manager.phase_label.text = "サイコロを振ってください"
		update_ui()

# サイコロを振る
func roll_dice():
	if current_phase != GamePhase.DICE_ROLL:
		return
	
	ui_manager.set_dice_button_enabled(false)
	change_phase(GamePhase.MOVING)
	
	var dice_value = player_system.roll_dice()
	var modified_dice = skill_system.modify_dice_roll(dice_value, player_system.current_player_index)
	
	emit_signal("dice_rolled", modified_dice)
	
	await get_tree().create_timer(1.0).timeout
	
	var current_player = player_system.get_current_player()
	
	# 3Dモードの移動
	if is_3d_mode and board_system_3d:
		board_system_3d.move_player_3d(current_player.id, modified_dice)
	else:
		player_system.move_player_steps(current_player.id, modified_dice, board_system)

# === 3Dモード用イベント ===

func _on_movement_started_3d():
	ui_manager.phase_label.text = "移動中..."

func _on_movement_completed_3d(final_tile: int):
	change_phase(GamePhase.TILE_ACTION)
	if board_system_3d:
		board_system_3d.process_tile_landing(final_tile)

func _on_tile_action_completed_3d():
	end_turn()

# === CPU処理（3D対応） ===

func _on_cpu_summon_decided(card_index: int):
	if is_3d_mode and board_system_3d:
		if card_index >= 0:
			board_system_3d.execute_summon(card_index)
		else:
			board_system_3d.emit_signal("tile_action_completed")
	else:
		# 2D版の処理
		execute_summon(player_system.get_current_player(), card_index)
		end_turn()

func _on_cpu_battle_decided(card_index: int):
	if is_3d_mode and board_system_3d:
		var current_tile = board_system_3d.player_tiles[board_system_3d.current_player_index]
		var tile_info = board_system_3d.get_tile_info(current_tile)
		
		if card_index >= 0:
			board_system_3d.execute_battle(card_index, tile_info)
		else:
			board_system_3d.pay_toll(tile_info)
	else:
		# 2D版の処理
		end_turn()

func _on_cpu_level_up_decided(do_upgrade: bool):
	if is_3d_mode and board_system_3d:
		if do_upgrade:
			var current_tile = board_system_3d.player_tiles[board_system_3d.current_player_index]
			var cost = board_system_3d.get_upgrade_cost(current_tile)
			if player_system.get_current_player().magic_power >= cost:
				board_system_3d.upgrade_tile_level(current_tile)
				player_system.add_magic(board_system_3d.current_player_index, -cost)
				
				# 表示更新
				if board_system_3d.tile_info_display:
					board_system_3d.update_all_tile_displays()
				if ui_manager:
					ui_manager.update_player_info_panels()
					
				print("CPU: 土地をレベルアップ！")
				
		board_system_3d.emit_signal("tile_action_completed")
	else:
		# 2D版の処理
		end_turn()

# === UIコールバック ===

func on_card_selected(card_index: int):
	if is_3d_mode and board_system_3d:
		board_system_3d.on_card_selected(card_index)
	# 2D版の処理は省略

func on_pass_button_pressed():
	if is_3d_mode and board_system_3d:
		board_system_3d.on_action_pass()
	# 2D版の処理は省略

func on_level_up_selected(target_level: int, cost: int):
	if is_3d_mode and board_system_3d:
		board_system_3d.on_level_up_selected(target_level, cost)
	# 2D版の処理は省略

# フェーズ変更
func change_phase(new_phase: GamePhase):
	current_phase = new_phase
	emit_signal("phase_changed", current_phase)
	update_ui()

# ターン終了
func end_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_ended", current_player.id)
	
	change_phase(GamePhase.END_TURN)
	skill_system.end_turn_cleanup()
	
	# プレイヤー切り替え処理
	if is_3d_mode and board_system_3d:
		# 3Dモードでプレイヤー切り替え
		board_system_3d.current_player_index = (board_system_3d.current_player_index + 1) % board_system_3d.player_count
		player_system.current_player_index = board_system_3d.current_player_index
		
		# カメラを次のプレイヤーに移動
		await move_camera_to_next_player()
	else:
		player_system.next_player()
	
	await get_tree().create_timer(GameConstants.TURN_END_DELAY).timeout
	start_turn()

# カメラ移動関数
func move_camera_to_next_player():
	if not board_system_3d or not board_system_3d.camera:
		return
	
	var current_index = board_system_3d.current_player_index
	if current_index >= board_system_3d.player_nodes.size():
		return
	
	var next_player_node = board_system_3d.player_nodes[current_index]
	if not next_player_node:
		return
	
	# カメラをスムーズに移動
	var camera = board_system_3d.camera
	var tween = get_tree().create_tween()
	var cam_offset = Vector3(0, 10, 10)
	var cam_target = next_player_node.global_position + cam_offset
	
	tween.tween_property(camera, "global_position", cam_target, 0.8)
	await tween.finished
	
	# カメラをプレイヤーに向ける
	if camera:
		camera.look_at(next_player_node.global_position, Vector3.UP)
	
	print("カメラをプレイヤー", current_index + 1, "に移動")

# プレイヤー勝利処理
func on_player_won(player_id: int):
	var player = player_system.players[player_id]
	change_phase(GamePhase.SETUP)
	ui_manager.set_dice_button_enabled(false)
	ui_manager.phase_label.text = player.name + "の勝利！"
	print("\n🎉 プレイヤー", player_id + 1, "の勝利！ 🎉")

# UI更新
func update_ui():
	var current_player = player_system.get_current_player()
	ui_manager.update_ui(current_player, current_phase)

# 2D版の召喚実行（互換性のため残す）
func execute_summon(current_player, card_index: int):
	# 2D版の実装（省略）
	pass
