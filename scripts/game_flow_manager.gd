extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム（3D専用版）
# 修正日: 2025/01/10 - BUG-000対応: シグナル経路を完全一本化

signal phase_changed(new_phase: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)
@warning_ignore("unused_signal")  # 旧版ダイス用、互換性のため残す
signal dice_rolled(value: int)

# 定数をpreload
const DominioCommandHandlerClass = preload("res://scripts/game_flow/dominio_command_handler.gd")
const BankruptcyHandlerClass = preload("res://scripts/game_flow/bankruptcy_handler.gd")
const PlayerSystemClass = preload("res://scripts/player_system.gd")
const CardSystemClass = preload("res://scripts/card_system.gd")
const PlayerBuffSystemClass = preload("res://scripts/player_buff_system.gd")
const UIManagerClass = preload("res://scripts/ui_manager.gd")
const BattleSystemClass = preload("res://scripts/battle_system.gd")
const SpecialTileSystemClass = preload("res://scripts/special_tile_system.gd")
const BattleScreenManagerClass = preload("res://scripts/battle_screen/battle_screen_manager.gd")
const MagicStoneSystemClass = preload("res://scripts/tiles/magic_stone_system.gd")
const LapSystemClass = preload("res://scripts/game_flow/lap_system.gd")

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
var board_system_3d: BoardSystem3D = null
var player_is_cpu = []

# チュートリアルモード（CPUは常にバトルを仕掛ける）
var is_tutorial_mode: bool = false

# システム参照
var player_system: PlayerSystem = null
var card_system: CardSystem = null
var player_buff_system: PlayerBuffSystem = null
var ui_manager: UIManager = null
var battle_system: BattleSystem = null
var special_tile_system
var battle_screen_manager

# アイテムフェーズ用バトルステータスオーバーレイ
var battle_status_overlay = null

# 魔法石システム
var magic_stone_system

# スペル効果システム（コンテナ方式）
var spell_container: SpellSystemContainer = null

# State Machine for phase transitions
var _state_machine: GameFlowStateMachine = null

# 破産処理ハンドラー
var bankruptcy_handler = null

# 通行料支払いハンドラー
var toll_payment_handler = null

# ダイスフェーズハンドラー
var dice_phase_handler = null

# 手札調整ハンドラー
var discard_handler = null

# ターン終了制御用フラグ（BUG-000対策）
var _is_ending_turn = false

# 入力ロック機能（連打防止・フェーズ遷移中の入力ガード）
var _input_locked: bool = false

# 周回管理システム（ファサード方式: lap_systemに直接アクセス）
var lap_system: LapSystem = null
signal lap_completed(player_id: int)

# ターン（ラウンド）カウンター
var current_turn_number = 1

# ゲーム全体の共有ステート（世界呪い等）
var game_stats: Dictionary = {}

# 注: _ready()は使用しない。初期化はGameSystemManagerが担当
# LapSystemはGameSystemManagerで作成され、set_lap_system()で設定される

## LapSystemを外部から設定
func set_lap_system(system) -> void:
	lap_system = system
	if lap_system:
		if not lap_system.lap_completed.is_connected(_on_lap_completed):
			lap_system.lap_completed.connect(_on_lap_completed)

func _on_lap_completed(player_id: int):
	lap_completed.emit(player_id)

# 3Dモード設定
func setup_3d_mode(board_3d, cpu_settings: Array):
	board_system_3d = board_3d
	player_is_cpu = cpu_settings

	# 3Dボードのシグナル接続
	if board_system_3d:
		if not board_system_3d.tile_action_completed.is_connected(_on_tile_action_completed_3d):
			board_system_3d.tile_action_completed.connect(_on_tile_action_completed_3d)

		# MovementControllerにgame_flow_managerを設定
		board_system_3d.set_movement_controller_gfm(self)

		# MovementControllerにCardSelectionUIを設定（destination_predictor向け）
		if ui_manager and ui_manager.card_selection_ui:
			board_system_3d.set_movement_controller_card_selection_ui(ui_manager.card_selection_ui)

		# MovementControllerにUIManagerを設定（セレクター向け）
		if ui_manager:
			board_system_3d.set_movement_controller_ui_manager(ui_manager)

		# LapSystemにboard_system_3dを設定し、チェックポイントシグナルを接続
		if lap_system:
			lap_system.board_system_3d = board_system_3d
			lap_system.connect_checkpoint_signals()

	# 周回状態を初期化
	if lap_system:
		lap_system.initialize_lap_state(cpu_settings.size())

# システム参照を設定（初期化ロジックはGameSystemManagerが担当）
func setup_systems(p_system, c_system, _b_system, s_system, ui_system, 
					bt_system = null, st_system = null):
	player_system = p_system
	card_system = c_system
	player_buff_system = s_system
	ui_manager = ui_system
	battle_system = bt_system
	special_tile_system = st_system
	
	# UIManagerに自身の参照を渡す
	if ui_manager:
		ui_manager.game_flow_manager_ref = self
	
	# BattleSystemに自身の参照を渡す
	if battle_system:
		battle_system.game_flow_manager_ref = self
	
	# LapSystemに参照を設定（lap_systemはset_lap_system()で事前設定済み）
	if lap_system:
		lap_system.player_system = player_system
		lap_system.ui_manager = ui_manager
		lap_system.setup_ui()
	
	# GameResultHandlerを初期化
	game_result_handler = GameResultHandler.new()
	game_result_handler.initialize(self, player_system, ui_manager)

## バトル画面マネージャーを外部から設定
func set_battle_screen_manager(manager: BattleScreenManager, overlay) -> void:
	battle_screen_manager = manager
	battle_status_overlay = overlay
	if battle_system and battle_screen_manager:
		battle_system.battle_screen_manager = battle_screen_manager

## 魔法石システムを外部から設定
func set_magic_stone_system(system: MagicStoneSystem) -> void:
	magic_stone_system = system

## CPU特殊タイルAIの変数宣言
var cpu_special_tile_ai: CPUSpecialTileAI = null

## CPU特殊タイルAIを外部から設定
func set_cpu_special_tile_ai(ai: CPUSpecialTileAI) -> void:
	cpu_special_tile_ai = ai

## SpellSystemContainerを設定（コンテナ方式）
func set_spell_container(container: SpellSystemContainer) -> void:
	spell_container = container

	# Node型システムのadd_child()はGFMで継続
	if container.spell_curse_stat and not container.spell_curse_stat.get_parent():
		add_child(container.spell_curse_stat)
	if container.spell_world_curse and not container.spell_world_curse.get_parent():
		add_child(container.spell_world_curse)

## State Machineを初期化
func _init_state_machine() -> void:
	if _state_machine:
		return  # Already initialized

	_state_machine = GameFlowStateMachine.new()
	_state_machine.initialize(GamePhase)

	# State MachineのシグナルをUIのphase_changedシグナルに橋渡し
	if not _state_machine.state_changed.is_connected(_on_state_changed):
		_state_machine.state_changed.connect(_on_state_changed)

	print("[GFM] State Machine initialized")

## State Machineのstate_changedシグナルハンドラー
func _on_state_changed(new_phase: int) -> void:
	# 既存の互換性のためphase_changedシグナルをemit
	emit_signal("phase_changed", new_phase)
	update_ui()

# ゲーム開始
func start_game():
	print("=== ゲーム開始 ===")

	# State Machineの初期化（ゲーム開始時に実施）
	_init_state_machine()

	# ゲーム統計の初期化
	game_stats["total_creatures_destroyed"] = 0

	# 全プレイヤーに方向選択権を付与（ゲームスタート時）
	for player in player_system.players:
		player.buffs["direction_choice_pending"] = true
		print("[GameFlowManager] プレイヤー%d: スタート時方向選択権付与" % (player.id + 1))

	change_phase(GamePhase.DICE_ROLL)
	start_turn()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	
	# ターン開始時に順番アイコンを即座に更新（最初に呼ぶ）
	emit_signal("turn_started", current_player.id)
	
	# UI更新：順番アイコンを設定
	if ui_manager:
		ui_manager.set_current_turn(current_player.id)
	
	# Phase 1-A: ターン開始時はドミニオコマンドボタンを隠す
	if ui_manager:
		ui_manager.hide_dominio_order_button()
	
	# カードドロー処理（常に1枚引く）
	# チュートリアルモードではドローをスキップ
	if not _is_tutorial_mode():
		if spell_container and spell_container.spell_draw:
			var drawn = spell_container.spell_draw.draw_one(current_player.id)
			if not drawn.is_empty() and current_player.id == 0:
				await get_tree().create_timer(0.1).timeout
		else:
			push_error("[GFM] spell_draw が初期化されていません")
	
	# 破産チェック（敵スペル等でEPマイナスの場合）
	await check_and_handle_bankruptcy()
	
	# UI更新
	ui_manager.update_player_info_panels()
	
	# スペルフェーズを開始
	if spell_phase_handler:
		spell_phase_handler.start_spell_phase(current_player.id)
		# スペルフェーズ完了を待つ
		await spell_phase_handler.spell_phase_completed
	
	# ワープ系スペル使用時はサイコロフェーズをスキップしてタイルアクションへ
	if spell_phase_handler and spell_phase_handler.skip_dice_phase:
		print("[GameFlowManager] ワープ使用によりサイコロフェーズをスキップ")
		change_phase(GamePhase.TILE_ACTION)
		# 現在のプレイヤー位置でタイルアクションを開始
		var current_tile = board_system_3d.get_player_tile(current_player.id)
		board_system_3d.process_tile_landing(current_tile)
		return
	
	# CPUターンの場合（デバッグモードでは無効化可能）
	var is_cpu_turn = current_player.id < player_is_cpu.size() and player_is_cpu[current_player.id] and not DebugSettings.manual_control_all
	if is_cpu_turn:
		ui_manager.set_phase_text("CPUのターン...")
		change_phase(GamePhase.DICE_ROLL)
		await get_tree().create_timer(1.0).timeout
		roll_dice()
	else:
		change_phase(GamePhase.DICE_ROLL)
		ui_manager.set_phase_text("サイコロを振ってください")
		
		# カメラを手動モードに設定（マップ確認可能にする）
		board_system_3d.enable_manual_camera()
		
		# 決定ボタンでサイコロを振るナビゲーション設定
		_setup_dice_phase_navigation()

## ダイスフェーズ用ナビゲーション設定（決定ボタンでサイコロを振る）
func _setup_dice_phase_navigation():
	print("[GameFlowManager] _setup_dice_phase_navigation called")
	if ui_manager:
		ui_manager.enable_navigation(
			func(): roll_dice(),  # 決定 = サイコロを振る
			Callable()            # 戻るなし
		)

# サイコロを振る
func roll_dice():
	if dice_phase_handler:
		await dice_phase_handler.roll_dice(current_phase, spell_phase_handler)

# === 3Dモード用イベント ===

func _on_tile_action_completed_3d():
	# 重複呼び出しを防ぐ（BUG-000対策: フェーズチェック + フラグチェック）
	if current_phase == GamePhase.END_TURN or current_phase == GamePhase.SETUP:
		print("Warning: tile_action_completed ignored (phase:", current_phase, ")")
		return
	
	if _is_ending_turn:
		print("Warning: tile_action_completed ignored (already ending turn)")
		return
	
	end_turn()



# === UIコールバック ===

func on_card_selected(card_index: int):
	# 優先順位順にハンドラーに処理を委譲

	# 1. スペルフェーズハンドラー（カード選択ハンドラー + スペル処理）
	if spell_phase_handler and spell_phase_handler.try_handle_card_selection(card_index):
		return

	# 2. アイテムフェーズハンドラー
	if item_phase_handler and item_phase_handler.try_handle_card_selection(card_index):
		return

	# 3. ドミニオコマンドハンドラー（交換モード）
	if dominio_command_handler and dominio_command_handler.try_handle_card_selection(card_index):
		return

	# 4. 通常のカード選択（召喚）
	if board_system_3d:
		board_system_3d.on_card_selected(card_index)

func on_pass_button_pressed():
	print("[GFM] on_pass_button_pressed: item_phase_active=%s" % [item_phase_handler.is_item_phase_active() if item_phase_handler else false])
	# アイテムフェーズ中の場合
	if item_phase_handler and item_phase_handler.is_item_phase_active():
		item_phase_handler.pass_item()
		return
	
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
	# State Machine経由でフェーズを変更
	if _state_machine:
		_state_machine.transition_to(new_phase)
		current_phase = _state_machine.current_state  # 状態を同期
	else:
		# フォールバック（State Machine未初期化の場合）
		current_phase = new_phase
		emit_signal("phase_changed", current_phase)
		update_ui()

	# 全てのインフォパネルを閉じる
	if ui_manager:
		ui_manager.close_all_info_panels()

	# カメラモード切り替え
	_update_camera_mode(new_phase)

# ターン終了
func end_turn():
	# 修正: 二重実行防止を強化（BUG-000対策）
	if _is_ending_turn:
		print("Warning: Already ending turn (flag check)")
		return
	
	if current_phase == GamePhase.END_TURN:
		print("Warning: Already ending turn (phase check)")
		return
	
	# ★重要: フラグを最優先で立てる
	_is_ending_turn = true
	
	# Phase 1-A: ドミニオコマンドを閉じる、カード選択UIとボタンを隠す
	if dominio_command_handler and dominio_command_handler.current_state != dominio_command_handler.State.CLOSED:
		dominio_command_handler.close_dominio_order()
	
	if ui_manager:
		ui_manager.hide_dominio_order_button()
		ui_manager.hide_card_selection_ui()
	
	var current_player = player_system.get_current_player()
	print("ターン終了: プレイヤー", current_player.id + 1)
	
	# 手札調整が必要かチェック
	if discard_handler:
		await discard_handler.check_and_discard_excess_cards(current_player.id)
	
	# 敵地判定・通行料支払い実行
	if toll_payment_handler:
		await toll_payment_handler.check_and_pay_toll_on_enemy_land()
	
	# 破産チェック（通行料支払い後）
	await check_and_handle_bankruptcy()
	
	emit_signal("turn_ended", current_player.id)
	
	change_phase(GamePhase.END_TURN)
	player_buff_system.end_turn_cleanup()
	
	# 現在のプレイヤーの呪いのduration更新
	if spell_container.spell_curse:
		spell_container.spell_curse.update_player_curse(player_system.current_player_index)
	
	# プレイヤー切り替え処理（3D専用）
	if board_system_3d:
		# 次のプレイヤーへ
		board_system_3d.current_player_index = (board_system_3d.current_player_index + 1) % board_system_3d.player_count
		player_system.current_player_index = board_system_3d.current_player_index
		
		# 全プレイヤーが1回ずつ行動したらラウンド数（ターン数）を増やす
		if board_system_3d.current_player_index == 0:
			current_turn_number += 1
			print("=== ラウンド", current_turn_number, "開始 ===")
			
			# 規定ターン終了判定
			if _check_turn_limit():
				return  # ゲーム終了
			
			# 4ターンごとに分岐タイルを切り替え
			if current_turn_number % 4 == 0:
				if board_system_3d:
					board_system_3d.toggle_all_branch_tiles()
			
			# 世界呪いのduration更新
			if spell_container.spell_world_curse:
				spell_container.spell_world_curse.on_round_start()
		
		print("次のプレイヤー: ", player_system.current_player_index + 1)
		
		# カメラの追従対象を次のプレイヤーに更新
		board_system_3d.set_camera_player(player_system.current_player_index)
		
		# カメラを次のプレイヤーに移動
		await move_camera_to_next_player()
	
	# 次のターン開始前に少し待機
	await get_tree().create_timer(GameConstants.TURN_END_DELAY).timeout

	# フェーズをリセットしてから次のターン開始
	change_phase(GamePhase.SETUP)
	_is_ending_turn = false  # フラグをリセット
	start_turn()

# カメラ移動関数
func move_camera_to_next_player():
	if not board_system_3d or not board_system_3d.camera:
		print("Warning: カメラまたはboard_system_3dが存在しません")
		return
	
	var current_index = board_system_3d.current_player_index
	
	# 委譲メソッドを使用してカメラフォーカス
	await board_system_3d.focus_camera_on_player_mc(current_index, true)

# ゲーム結果処理ハンドラー
var game_result_handler: GameResultHandler = null

# ゲーム終了フラグ（後方互換getter）
var is_game_ended: bool:
	get: return game_result_handler.is_game_ended() if game_result_handler else false

# プレイヤー勝利処理（GameResultHandlerに委譲）
func on_player_won(player_id: int):
	if game_result_handler:
		game_result_handler.on_player_won(player_id)


# プレイヤー敗北処理（GameResultHandlerに委譲）
func on_player_defeated(reason: String = ""):
	if game_result_handler:
		await game_result_handler.on_player_defeated(reason)

# UI更新
func update_ui():
	var current_player = player_system.get_current_player()
	ui_manager.update_ui(current_player, current_phase)


# === 敵地判定・通行料支払い ===

# 敵地判定・通行料支払い処理（end_turn()内で実行）


# === 破産処理 ===

## 破産チェック＆処理
func check_and_handle_bankruptcy():
	if not bankruptcy_handler:
		return
	
	var current_player_index = player_system.current_player_index
	
	# 破産状態でなければスキップ
	if not bankruptcy_handler.check_bankruptcy(current_player_index):
		return
	
	# CPUかどうか判定
	var is_cpu = current_player_index < player_is_cpu.size() and player_is_cpu[current_player_index]
	
	# 破産処理実行
	await bankruptcy_handler.process_bankruptcy(current_player_index, is_cpu)

# === 土地呪い（移動完了時発動） ===

## 土地呪い発動（移動完了時に呼ばれる公開メソッド）
## 実処理はSpellMagicに委譲
func trigger_land_curse_on_stop(tile_index: int, stopped_player_id: int):
	if spell_container.spell_magic:
		spell_container.spell_magic.trigger_land_curse(tile_index, stopped_player_id)

# ============================================
# Phase 1-A: 新システム統合
# ============================================

# Phase 1-A用ハンドラー
var dominio_command_handler: DominioCommandHandler = null
var spell_phase_handler: SpellPhaseHandler = null
var item_phase_handler = null  # ItemPhaseHandler
var target_selection_helper: TargetSelectionHelper = null  # タイル選択ヘルパー

# Phase 1-A: ハンドラーを外部から設定（初期化はGameSystemManagerが担当）
func set_phase1a_handlers(
	p_target_selection_helper: TargetSelectionHelper,
	p_dominio_command_handler: DominioCommandHandler,
	p_spell_phase_handler: SpellPhaseHandler,
	p_item_phase_handler
) -> void:
	target_selection_helper = p_target_selection_helper
	dominio_command_handler = p_dominio_command_handler
	spell_phase_handler = p_spell_phase_handler
	item_phase_handler = p_item_phase_handler
	
	# dominio_command_closedシグナルを接続
	if dominio_command_handler and dominio_command_handler.has_signal("dominio_command_closed"):
		if not dominio_command_handler.dominio_command_closed.is_connected(_on_dominio_command_closed):
			dominio_command_handler.dominio_command_closed.connect(_on_dominio_command_closed)
	
	# SpellCurseStatにシステム参照と通知UIを設定
	if spell_container.spell_curse_stat:
		spell_container.spell_curse_stat.set_systems(board_system_3d, player_system, card_system)
		if spell_phase_handler and spell_phase_handler.spell_cast_notification_ui:
			spell_container.spell_curse_stat.set_notification_ui(spell_phase_handler.spell_cast_notification_ui)
	
	# dominio_command_handlerにspell_cast_notification_ui参照を渡す
	if dominio_command_handler and spell_phase_handler and spell_phase_handler.spell_cast_notification_ui:
		dominio_command_handler.spell_cast_notification_ui = spell_phase_handler.spell_cast_notification_ui
	
	# SpellMagicに通知UIを設定
	if spell_container.spell_magic and spell_phase_handler and spell_phase_handler.spell_cast_notification_ui:
		spell_container.spell_magic.set_notification_ui(spell_phase_handler.spell_cast_notification_ui)
	
	# BankruptcyHandlerにTargetSelectionHelper参照を設定
	if bankruptcy_handler and target_selection_helper:
		bankruptcy_handler.target_selection_helper = target_selection_helper

# Phase 1-A: ドミニオコマンドが閉じられたときの処理
func _on_dominio_command_closed():
	
	# ターンエンド中またはターンエンドフェーズの場合は処理しない
	if _is_ending_turn or current_phase == GamePhase.END_TURN:
		return
	
	# カメラをプレイヤーに戻す
	if board_system_3d:
		board_system_3d.return_camera_to_player()
	
	# カード選択UIの再初期化を次のフレームで実行（awaitを避ける）
	_reinitialize_card_selection.call_deferred()

# カード選択UIを再初期化（遅延実行用）
func _reinitialize_card_selection():
	if ui_manager:
		var current_player = player_system.get_current_player()
		if current_player:
			# TileActionProcessorのフラグを再設定（召喚フェーズに戻る）
			if board_system_3d and board_system_3d.tile_action_processor:
				board_system_3d.tile_action_processor.begin_action_processing()
			
			# カード選択UIを完全に再初期化（一度非表示にしてから再表示）
			ui_manager.hide_card_selection_ui()
			ui_manager.show_card_selection_ui(current_player)
			
			# ドミニオコマンドボタンも再表示
			ui_manager.show_dominio_order_button()
			

# Phase 1-A: ドミニオコマンドを開く
func open_dominio_order():
	if not dominio_command_handler:
		return
	
	var current_player = player_system.get_current_player()
	if current_player:
		dominio_command_handler.open_dominio_order(current_player.id)

# Phase 1-A: デバッグ情報表示
func debug_print_phase1a_status():
	if dominio_command_handler:
		print("[Phase 1-A] ドミニオコマンド状態: ", dominio_command_handler.get_current_state())

# ============================================
# ターン数取得
# ============================================

func get_current_turn() -> int:
	return current_turn_number

# ============================================
# CPU移動評価システム
# ============================================

## CPU移動評価システムを外部から設定（初期化はGameSystemManagerが担当）
func set_cpu_movement_evaluator(cpu_movement_evaluator: CPUMovementEvaluator) -> void:
	# MovementControllerに参照を渡す
	if board_system_3d:
		board_system_3d.set_cpu_movement_evaluator(cpu_movement_evaluator)
	
	# SpellPhaseHandlerに参照を渡す
	if spell_phase_handler:
		spell_phase_handler.cpu_movement_evaluator = cpu_movement_evaluator
		if spell_phase_handler.cpu_spell_ai:
			spell_phase_handler.cpu_spell_ai.set_movement_evaluator(cpu_movement_evaluator)

# ============================================
# カメラ制御
# ============================================

## フェーズに応じてカメラモードを更新
func _update_camera_mode(phase: GamePhase):
	if not board_system_3d:
		return
	
	var is_my_turn = _is_current_player_human()
	
	if not is_my_turn:
		board_system_3d.enable_follow_camera()
		return
	
	# ダイスロールとタイルアクションで手動モード
	match phase:
		GamePhase.DICE_ROLL, GamePhase.TILE_ACTION:
			board_system_3d.enable_manual_camera()
		_:
			board_system_3d.enable_follow_camera()

## 現在のプレイヤーが人間かどうか
func _is_current_player_human() -> bool:
	if not player_system:
		return true
	var current_id = player_system.current_player_index
	if current_id < 0 or current_id >= player_is_cpu.size():
		return true
	return not player_is_cpu[current_id]


# ============================================================
# 入力ロック機能（連打防止）
# ============================================================

## 入力をロック
func lock_input():
	_input_locked = true

## 入力ロックを解除
func unlock_input():
	_input_locked = false

## 入力がロック中かどうか
func is_input_locked() -> bool:
	return _input_locked

# ============================================================
# チュートリアルモード判定
# ============================================================

## チュートリアルモードかどうか
func _is_tutorial_mode() -> bool:
	var tm = get_tutorial_manager()
	if tm == null or not tm.is_active:
		return false
	# チュートリアルでもenable_drawがtrueならドローを有効にする
	if tm.enable_draw:
		return false
	return true

## TutorialManagerを取得
func get_tutorial_manager():
	var game_3d = get_parent().get_parent() if get_parent() else null
	if game_3d and "tutorial_manager" in game_3d:
		return game_3d.tutorial_manager
	return null


# ============================================================
# ステージクリア・リザルト処理（GameResultHandlerに委譲）
# ============================================================

## ステージデータを設定（GameResultHandlerに委譲）
func set_stage_data(stage_data: Dictionary):
	if game_result_handler:
		game_result_handler.set_stage_data(stage_data)

## リザルト画面を設定（GameResultHandlerに委譲）
func set_result_screen(screen: ResultScreen):
	if game_result_handler:
		game_result_handler.set_result_screen(screen)

## 規定ターン終了判定（GameResultHandlerに委譲）
func _check_turn_limit() -> bool:
	if game_result_handler:
		return game_result_handler.check_turn_limit()
	return false
