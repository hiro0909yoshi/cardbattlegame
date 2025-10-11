extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム（3D専用版）
# 修正日: 2025/01/10 - BUG-000対応: シグナル経路を完全一本化

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

# 3D用変数
var board_system_3d = null
var player_is_cpu = []

# デバッグ用: 全プレイヤーを手動操作にする（trueで有効）
@export var debug_manual_control_all: bool = false

# ハンドラークラス
var cpu_ai_handler: CPUAIHandler

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem

# ターン終了制御用フラグ（BUG-000対策）
var is_ending_turn = false

func _ready():
	# CPUAIHandler初期化
	cpu_ai_handler = CPUAIHandler.new()
	add_child(cpu_ai_handler)
	
	# CPUハンドラーのシグナル接続
	cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided)
	cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided)
	cpu_ai_handler.level_up_decided.connect(_on_cpu_level_up_decided)

# 3Dモード設定
func setup_3d_mode(board_3d, cpu_settings: Array):
	board_system_3d = board_3d
	player_is_cpu = cpu_settings
	
	# 3Dボードのシグナル接続
	if board_system_3d:
		board_system_3d.tile_action_completed.connect(_on_tile_action_completed_3d)
		# デバッグフラグを転送
		board_system_3d.debug_manual_control_all = debug_manual_control_all

# システム参照を設定
func setup_systems(p_system, c_system, b_system, s_system, ui_system, 
					bt_system = null, st_system = null):
	player_system = p_system
	card_system = c_system
	skill_system = s_system
	ui_manager = ui_system
	battle_system = bt_system
	special_tile_system = st_system
	
	# UIManagerに自身の参照を渡す
	if ui_manager:
		ui_manager.game_flow_manager_ref = self
	
	# CPU AIハンドラー設定
	if cpu_ai_handler:
		cpu_ai_handler.setup_systems(c_system, b_system, p_system, bt_system, s_system)

# ゲーム開始
func start_game():
	print("=== ゲーム開始 ===")
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()
	start_turn()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	
	# カードドロー処理（常に1枚引く）
	var drawn = card_system.draw_card_for_player(current_player.id)
	if not drawn.is_empty() and current_player.id == 0:
		await get_tree().create_timer(0.1).timeout
	
	# UI更新
	ui_manager.update_player_info_panels()
	
	# CPUターンの場合（デバッグモードでは無効化可能）
	var is_cpu_turn = current_player.id < player_is_cpu.size() and player_is_cpu[current_player.id] and not debug_manual_control_all
	print("【デバッグ】プレイヤー", current_player.id + 1, " is_cpu:", player_is_cpu[current_player.id] if current_player.id < player_is_cpu.size() else "N/A", " debug_manual:", debug_manual_control_all, " → CPU自動:", is_cpu_turn)
	if is_cpu_turn:
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
	
	# 3D移動
	if board_system_3d:
		ui_manager.phase_label.text = "移動中..."
		board_system_3d.move_player_3d(current_player.id, modified_dice)

# === 3Dモード用イベント ===

func _on_tile_action_completed_3d():
	# 重複呼び出しを防ぐ（BUG-000対策: フェーズチェック + フラグチェック）
	if current_phase == GamePhase.END_TURN or current_phase == GamePhase.SETUP:
		print("Warning: tile_action_completed ignored (phase:", current_phase, ")")
		return
	
	if is_ending_turn:
		print("Warning: tile_action_completed ignored (already ending turn)")
		return
	
	end_turn()

# === CPU処理 ===
# 修正: 全てのCPU処理でboard_system_3dに処理を委譲し、直接emit_signalしない

func _on_cpu_summon_decided(card_index: int):
	if not board_system_3d:
		return
	
	# 修正: TileActionProcessorに処理を委譲（シグナルは自動発火）
	if board_system_3d.tile_action_processor:
		board_system_3d.tile_action_processor.execute_summon(card_index)
	else:
		# フォールバック: 旧方式（tile_action_processorがない場合）
		if card_index >= 0:
			board_system_3d.execute_summon(card_index)
		else:
			# パス処理
			board_system_3d.on_action_pass()

func _on_cpu_battle_decided(card_index: int):
	if not board_system_3d:
		return
	
	var current_tile = board_system_3d.movement_controller.get_player_tile(board_system_3d.current_player_index)
	var tile_info = board_system_3d.get_tile_info(current_tile)
	
	if card_index >= 0:
		# バトル処理をBattleSystemに委譲
		if not battle_system.invasion_completed.is_connected(board_system_3d._on_invasion_completed):
			battle_system.invasion_completed.connect(board_system_3d._on_invasion_completed, CONNECT_ONE_SHOT)
		battle_system.execute_3d_battle(board_system_3d.current_player_index, card_index, tile_info)
	else:
		# 修正: 通行料支払い処理を委譲（シグナルは自動発火）
		board_system_3d.on_action_pass()

func _on_cpu_level_up_decided(do_upgrade: bool):
	if not board_system_3d:
		return
	
	# 修正: TileActionProcessorに処理を委譲
	if board_system_3d.tile_action_processor:
		if do_upgrade:
			var current_tile = board_system_3d.movement_controller.get_player_tile(board_system_3d.current_player_index)
			var cost = board_system_3d.get_upgrade_cost(current_tile)
			# レベルアップ処理を委譲（target_levelは計算が必要なので、直接アップグレード）
			if player_system.get_current_player().magic_power >= cost:
				var tile = board_system_3d.tile_nodes[current_tile]
				var target_level = tile.level + 1
				board_system_3d.tile_action_processor.on_level_up_selected(target_level, cost)
			else:
				# 魔力不足の場合はキャンセル
				board_system_3d.tile_action_processor.on_level_up_selected(0, 0)
		else:
			# アップグレードしない場合
			board_system_3d.tile_action_processor.on_level_up_selected(0, 0)
	else:
		# フォールバック: 旧方式
		if do_upgrade:
			var current_tile = board_system_3d.movement_controller.get_player_tile(board_system_3d.current_player_index)
			var cost = board_system_3d.get_upgrade_cost(current_tile)
			if player_system.get_current_player().magic_power >= cost:
				board_system_3d.upgrade_tile_level(current_tile)
				player_system.add_magic(board_system_3d.current_player_index, -cost)
				
				if board_system_3d.tile_info_display:
					board_system_3d.update_all_tile_displays()
				if ui_manager:
					ui_manager.update_player_info_panels()
				
				print("CPU: 土地をレベルアップ！")
		
		# フォールバック用の完了通知
		if board_system_3d.tile_action_processor:
			board_system_3d.tile_action_processor._complete_action()

# === UIコールバック ===

func on_card_selected(card_index: int):
	if board_system_3d:
		board_system_3d.on_card_selected(card_index)

func on_pass_button_pressed():
	if board_system_3d:
		board_system_3d.on_action_pass()

func on_level_up_selected(target_level: int, cost: int):
	if not board_system_3d:
		return
	
	# 修正: 常にBoardSystem3Dに処理を委譲（直接emit_signalしない）
	if board_system_3d.has_method("on_level_up_selected"):
		board_system_3d.on_level_up_selected(target_level, cost)
	else:
		# tile_action_processorに直接委譲
		if board_system_3d.tile_action_processor:
			board_system_3d.tile_action_processor.on_level_up_selected(target_level, cost)

# フェーズ変更
func change_phase(new_phase: GamePhase):
	current_phase = new_phase
	emit_signal("phase_changed", current_phase)
	update_ui()

# ターン終了
func end_turn():
	# 修正: 二重実行防止を強化（BUG-000対策）
	if is_ending_turn:
		print("Warning: Already ending turn (flag check)")
		return
	
	if current_phase == GamePhase.END_TURN:
		print("Warning: Already ending turn (phase check)")
		return
	
	# フラグを立てる
	is_ending_turn = true
	
	var current_player = player_system.get_current_player()
	print("ターン終了: プレイヤー", current_player.id + 1)
	
	# 手札調整が必要かチェック
	await check_and_discard_excess_cards()
	
	emit_signal("turn_ended", current_player.id)
	
	change_phase(GamePhase.END_TURN)
	skill_system.end_turn_cleanup()
	
	# プレイヤー切り替え処理（3D専用）
	if board_system_3d:
		# 次のプレイヤーへ
		board_system_3d.current_player_index = (board_system_3d.current_player_index + 1) % board_system_3d.player_count
		player_system.current_player_index = board_system_3d.current_player_index
		
		print("次のプレイヤー: ", player_system.current_player_index + 1)
		
		# カメラを次のプレイヤーに移動
		await move_camera_to_next_player()
	
	# 次のターン開始前に少し待機
	await get_tree().create_timer(GameConstants.TURN_END_DELAY).timeout
	
	# フェーズをリセットしてから次のターン開始
	current_phase = GamePhase.SETUP
	is_ending_turn = false  # フラグをリセット
	start_turn()

# カメラ移動関数
func move_camera_to_next_player():
	if not board_system_3d or not board_system_3d.camera:
		print("Warning: カメラまたはboard_system_3dが存在しません")
		return
	
	var current_index = board_system_3d.current_player_index
	
	if board_system_3d.movement_controller:
		# MovementController3Dを使用してカメラフォーカス
		await board_system_3d.movement_controller.focus_camera_on_player(current_index, true)
	else:
		print("Warning: movement_controllerが存在しません")

# プレイヤー勝利処理
func on_player_won(player_id: int):
	var player = player_system.players[player_id]
	change_phase(GamePhase.SETUP)
	ui_manager.set_dice_button_enabled(false)
	ui_manager.phase_label.text = player.name + "の勝利！"
	print("🎉 プレイヤー", player_id + 1, "の勝利！ 🎉")

# UI更新
func update_ui():
	var current_player = player_system.get_current_player()
	ui_manager.update_ui(current_player, current_phase)

# 手札調整処理（ターン終了時）
func check_and_discard_excess_cards():
	var current_player = player_system.get_current_player()
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	
	if hand_size <= GameConstants.MAX_HAND_SIZE:
		return  # 調整不要
	
	var cards_to_discard = hand_size - GameConstants.MAX_HAND_SIZE
	print("手札調整が必要: ", hand_size, "枚 → 6枚（", cards_to_discard, "枚捨てる）")
	
	# CPUの場合は自動で捨てる（デバッグモードでは無効化）
	var is_cpu = current_player.id < player_is_cpu.size() and player_is_cpu[current_player.id] and not debug_manual_control_all
	if is_cpu:
		card_system.discard_excess_cards_auto(current_player.id, GameConstants.MAX_HAND_SIZE)
		return
	
	# 人間プレイヤーの場合は手動で選択
	for i in range(cards_to_discard):
		await prompt_discard_card()

# カード捨て札をプロンプト
func prompt_discard_card():
	var current_player = player_system.get_current_player()
	
	# カード選択UIを表示（discardモード）
	ui_manager.show_card_selection_ui_mode(current_player, "discard")
	
	# カード選択を待つ
	var card_index = await ui_manager.card_selected
	
	# カードを捨てる（理由: discard）
	card_system.discard_card(current_player.id, card_index, "discard")
	
	# UIを閉じる
	ui_manager.hide_card_selection_ui()
