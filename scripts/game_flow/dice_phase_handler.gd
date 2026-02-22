# DicePhaseHandler - ダイスロール（DICE_ROLL）フェーズの処理を担当
extends Node
class_name DicePhaseHandler

# === UI Signal 定義（Phase 6-B: UI層分離） ===
signal dice_ui_big_result_requested(value: int, duration: float)
signal dice_ui_double_result_shown(d1: int, d2: int, total: int)
signal dice_ui_triple_result_shown(d1: int, d2: int, d3: int, total: int)
signal dice_ui_range_result_shown(curse_name: String, value: int)
signal dice_ui_phase_text_requested(text: String)
signal dice_ui_navigation_disabled()
signal dice_ui_comment_and_wait_requested(message: String, player_id: int)
signal dice_ui_comment_and_wait_completed()

# 依存システム
var player_system
var player_buff_system
var spell_dice
var board_system_3d

# === Phase A-3d: change_phase Callable 化 ===
var _change_phase_cb: Callable = Callable()

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
func setup(p_player_system, p_player_buff_system, p_spell_dice, p_board_system_3d):
	player_system = p_player_system
	player_buff_system = p_player_buff_system
	spell_dice = p_spell_dice
	board_system_3d = p_board_system_3d

## GFM依存のCallable一括注入（Phase A-3d）
func inject_callbacks(
	change_phase_cb: Callable,
) -> void:
	_change_phase_cb = change_phase_cb
	assert(_change_phase_cb.is_valid(), "[DPH] change_phase_cb must be valid")

# メインメソッド（GFMのroll_dice()の中身をそのまま移動）
# spell_phase_handler: SpellPhaseHandler型（スペルフェーズ処理用）
func roll_dice(p_current_phase: int, spell_phase_handler) -> void:
	# フェーズ情報を更新
	current_phase = p_current_phase as GamePhase

	# スペルフェーズ中の場合は、スペルを使わずにダイスロールに進む
	if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
		if spell_phase_handler.spell_flow:
			spell_phase_handler.spell_flow.pass_spell(false)  # auto_roll=false（ここで既にroll_dice中なので）
			# フェーズ完了を待つ必要はない（pass_spellが即座に完了する）
		else:
			push_error("[DicePhaseHandler] spell_flow が初期化されていません")

	if current_phase != GamePhase.DICE_ROLL:
		return

	# ナビゲーションをクリア（連打防止）
	_clear_dice_phase_navigation()

	# カメラをプレイヤー位置に戻す（即座に移動）
	if board_system_3d:
		board_system_3d.focus_camera_on_player_pos(player_system.current_player_index, false)

	# フェーズ遷移（Callable経由）
	if _change_phase_cb.is_valid():
		_change_phase_cb.call(GamePhase.MOVING)

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

	# 刻印によるダイス変更を適用（dice_multi以外）
	if spell_dice and not needs_third:
		total_dice = spell_dice.get_modified_dice_value(player_system.current_player_index, total_dice)

	# バフによるダイス変更を適用
	var modified_dice = player_buff_system.modify_dice_roll(total_dice, player_system.current_player_index)

	# ダイス結果を大きく表示（1.5秒）
	dice_ui_big_result_requested.emit(modified_dice, 1.5)

	# ダイス結果を詳細表示（上部）
	# ダイス範囲刻印がある場合は特殊表示
	if spell_dice and spell_dice.has_dice_range_curse(player_system.current_player_index):
		var range_info = spell_dice.get_dice_range_info(player_system.current_player_index)
		dice_ui_range_result_shown.emit(range_info.get("name", ""), modified_dice)
		print("[ダイス/%s] %d（範囲: %d〜%d）" % [range_info.get("name", ""), modified_dice, range_info.get("min", 1), range_info.get("max", 6)])
	elif needs_third:
		dice_ui_triple_result_shown.emit(dice1, dice2, dice3, modified_dice)
		print("[ダイス] %d + %d + %d = %d (修正後: %d)" % [dice1, dice2, dice3, total_dice, modified_dice])
	else:
		dice_ui_double_result_shown.emit(dice1, dice2, modified_dice)
		print("[ダイス] %d + %d = %d (修正後: %d)" % [dice1, dice2, total_dice, modified_dice])

	# ダイスロール後のEP付与（ジャーニーなど）
	if spell_dice:
		var grant_result = spell_dice.process_magic_grant(player_system.current_player_index)
		if not grant_result.is_empty():
			dice_ui_comment_and_wait_requested.emit(grant_result.message, grant_result.player_id)
			await dice_ui_comment_and_wait_completed

	# 表示待ち
	await get_tree().create_timer(1.0).timeout

	var current_player = player_system.get_current_player()

	# 3D移動
	if board_system_3d:
		dice_ui_phase_text_requested.emit("移動中...")
		board_system_3d.move_player_3d(current_player.id, modified_dice, modified_dice)

# ナビゲーションボタンのクリア（GameFlowManagerの_clear_dice_phase_navigation()から移動）
func _clear_dice_phase_navigation() -> void:
	dice_ui_navigation_disabled.emit()
