# DicePhaseHandler - ダイスロール（DICE_ROLL）フェーズの処理を担当
extends Node
class_name DicePhaseHandler

# 依存システム
var player_system
var player_buff_system
var spell_dice
var ui_manager
var board_system_3d
var game_flow_manager  # change_phase()呼び出し用

# ゲームフェーズ定数（GameFlowManagerと同期）
enum GamePhase {
	SETUP,
	DICE_ROLL,
	MOVING,
	TILE_ACTION,
	BATTLE,
	END_TURN
}

var current_phase = GamePhase.SETUP

# セットアップメソッド
func setup(p_player_system, p_player_buff_system, p_spell_dice, p_ui_manager, p_board_system_3d, p_game_flow_manager):
	player_system = p_player_system
	player_buff_system = p_player_buff_system
	spell_dice = p_spell_dice
	ui_manager = p_ui_manager
	board_system_3d = p_board_system_3d
	game_flow_manager = p_game_flow_manager

# メインメソッド（GFMのroll_dice()の中身をそのまま移動）
# spell_phase_handler: SpellPhaseHandler型（スペルフェーズ処理用）
func roll_dice(p_current_phase: int, spell_phase_handler) -> void:
	# フェーズ情報を更新
	current_phase = p_current_phase

	# スペルフェーズ中の場合は、スペルを使わずにダイスロールに進む
	if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
		spell_phase_handler.pass_spell(false)  # auto_roll=false（ここで既にroll_dice中なので）
		# フェーズ完了を待つ必要はない（pass_spellが即座に完了する）

	if current_phase != GamePhase.DICE_ROLL:
		return

	# ナビゲーションをクリア（連打防止）
	_clear_dice_phase_navigation()

	# カメラをプレイヤー位置に戻す（即座に移動）
	if board_system_3d:
		board_system_3d.focus_camera_on_player_pos(player_system.current_player_index, false)

	# GameFlowManagerのchange_phase()経由でフェーズ遷移
	if game_flow_manager:
		game_flow_manager.change_phase(GamePhase.MOVING)

	# フライ効果（3個ダイス）の判定
	var needs_third = spell_dice and spell_dice.needs_third_dice(player_system.current_player_index)

	var dice1: int
	var dice2: int
	var dice3: int = 0
	var total_dice: int

	if needs_third:
		# 3個ダイスを振る（フライ効果）
		var dice_result = player_system.roll_dice_triple()
		dice1 = dice_result.dice1
		dice2 = dice_result.dice2
		dice3 = dice_result.dice3
		total_dice = dice_result.total
		print("[ダイス/フライ] %d + %d + %d = %d" % [dice1, dice2, dice3, total_dice])
	else:
		# 2個ダイスを振る（通常）
		var dice_result = player_system.roll_dice_double()
		dice1 = dice_result.dice1
		dice2 = dice_result.dice2
		total_dice = dice_result.total

	# 呪いによるダイス変更を適用（dice_multi以外）
	if spell_dice and not needs_third:
		total_dice = spell_dice.get_modified_dice_value(player_system.current_player_index, total_dice)

	# バフによるダイス変更を適用
	var modified_dice = player_buff_system.modify_dice_roll(total_dice, player_system.current_player_index)

	# ダイス結果を大きく表示（1.5秒）
	if ui_manager:
		ui_manager.show_big_dice_result(modified_dice, 1.5)

	# ダイス結果を詳細表示（上部）
	if ui_manager:
		# ダイス範囲呪いがある場合は特殊表示
		if spell_dice and spell_dice.has_dice_range_curse(player_system.current_player_index):
			var range_info = spell_dice.get_dice_range_info(player_system.current_player_index)
			ui_manager.show_dice_result_range(range_info.get("name", ""), modified_dice)
			print("[ダイス/%s] %d（範囲: %d〜%d）" % [range_info.get("name", ""), modified_dice, range_info.get("min", 1), range_info.get("max", 6)])
		elif needs_third:
			ui_manager.show_dice_result_triple(dice1, dice2, dice3, modified_dice)
			print("[ダイス] %d + %d + %d = %d (修正後: %d)" % [dice1, dice2, dice3, total_dice, modified_dice])
		else:
			ui_manager.show_dice_result_double(dice1, dice2, modified_dice)
			print("[ダイス] %d + %d = %d (修正後: %d)" % [dice1, dice2, total_dice, modified_dice])

	# ダイスロール後のEP付与（チャージステップなど）
	if spell_dice:
		await spell_dice.process_magic_grant(player_system.current_player_index, ui_manager)

	# 表示待ち
	await get_tree().create_timer(1.0).timeout

	print("[DicePhaseHandler] roll_dice: await完了、移動開始 (phase=%s)" % current_phase)

	var current_player = player_system.get_current_player()

	# 3D移動
	if board_system_3d:
		if ui_manager:
			ui_manager.set_phase_text("移動中...")
		print("[DicePhaseHandler] roll_dice: move_player_3d呼び出し (player=%d, dice=%d)" % [current_player.id, modified_dice])
		board_system_3d.move_player_3d(current_player.id, modified_dice, modified_dice)

# ナビゲーションボタンのクリア（GameFlowManagerの_clear_dice_phase_navigation()から移動）
func _clear_dice_phase_navigation() -> void:
	if ui_manager:
		ui_manager.disable_navigation()
