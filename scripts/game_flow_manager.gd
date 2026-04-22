extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム（3D専用版）
# 修正日: 2025/01/10 - BUG-000対応: シグナル経路を完全一本化

signal phase_changed(new_phase: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)
@warning_ignore("unused_signal")  # 旧版ダイス用、互換性のため残す
signal dice_rolled(value: int)
signal creature_updated_relay(tile_index: int, creature_data: Dictionary)
# ネット対戦: GFM内部の操作をサーバー送信に置き換えるため、NetworkBridge が接続する
signal net_action_requested(msg_type: String, data: Variant)

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

# プレイヤー制御タイプ（"local" / "cpu"、将来 "remote" 追加予定）
var _player_control_types: Array[String] = []
var _control_type_overridden: Dictionary = {}  # player_id -> true: convert_to_*で明示変更済み

# 互換プロパティ: 外部から player_is_cpu として参照可能
var player_is_cpu: Array:
	get:
		var result: Array = []
		for ct in _player_control_types:
			result.append(ct == "cpu")
		return result
	set(value):
		_player_control_types.clear()
		for is_cpu in value:
			_player_control_types.append("cpu" if is_cpu else "local")

# チュートリアルモード（CPUは常にバトルを仕掛ける）
var is_tutorial_mode: bool = false

# ネット対戦モード: 薄型リレー方式。
# true の場合、GFM は自律的なターン遷移・ダイス生成・CPU起動を行わず、
# サーバー指示（on_server_* メソッド経由）で動作する。
var is_net_battle: bool = false

# ネット対戦時の自分のスロット（_player_slot と同じ値を保持）
var net_local_slot: int = 0

# 直前に _setup_net_phase_ui で処理したフェーズ（重複回避）
var _net_last_setup_phase: String = ""

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

# TutorialManager取得用Callable（外部から注入）
var _get_tutorial_manager_cb: Callable = Callable()

# UI操作用Callable（GSMから注入）
var _ui_set_phase_text_cb: Callable = Callable()
var _ui_update_panels_cb: Callable = Callable()
var _ui_show_dominio_btn_cb: Callable = Callable()
var _ui_hide_dominio_btn_cb: Callable = Callable()
var _ui_show_card_selection_cb: Callable = Callable()
var _ui_hide_card_selection_cb: Callable = Callable()
var _ui_enable_navigation_cb: Callable = Callable()
var _ui_disable_navigation_cb: Callable = Callable()
var _ui_show_action_prompt_cb: Callable = Callable()
var _ui_show_big_dice_cb: Callable = Callable()

# 周回管理システム（ファサード方式: lap_systemに直接アクセス）
var lap_system: LapSystem = null
signal lap_completed(player_id: int)

# ターン（ラウンド）カウンター
var current_turn_number = 1

# ゲーム全体の共有ステート（世界刻印等）
var game_stats: Dictionary = {}

# 現在プレイ中のステージID（セーブ/復帰用）
var current_stage_id: String = ""

# ゲームモード（セーブ/復帰用: "quest" / "solo"）
var current_game_mode: String = "solo"

# ダイス結果（セーブ/復帰用: -1 = 未確定）
var last_dice_result: int = -1

## 復帰時のフェーズ（"" = 通常, "turn_start", "after_dice", "after_movement", "after_battle", "after_tile_action"）
var _restore_phase: String = ""

## 現在のセーブフェーズ（_save_game_state で保存される）
var _current_save_phase: String = "turn_start"

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

		# MovementControllerにサービスを設定（セレクター向け）
		if ui_manager:
			board_system_3d.set_movement_controller_services(ui_manager.message_service, ui_manager.navigation_service)

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

	# BattleSystemに自身の参照を渡す
	if battle_system:
		battle_system.game_flow_manager_ref = self
	
	# LapSystemに参照を設定（lap_systemはset_lap_system()で事前設定済み）
	# Phase B-2: ui_manager 直接参照を削除、初期化は GameSystemManager で完了
	if lap_system:
		lap_system.player_system = player_system
		lap_system.set_game_ended_checker(
			func() -> bool: return is_game_ended
		)
	
	# GameResultHandlerを初期化（Phase A-2: GFM逆参照解消）
	game_result_handler = GameResultHandler.new()
	game_result_handler.initialize(player_system)

	# Phase A-2: Callable一括注入
	var _show_win_cb = func(delay):
		if ui_manager: ui_manager.show_win_screen(delay)
	var _show_win_async_cb = func(delay):
		if ui_manager: await ui_manager.show_win_screen_async(delay)
	var _show_lose_async_cb = func(delay):
		if ui_manager: await ui_manager.show_lose_screen_async(delay)
	game_result_handler.inject_callbacks(
		func(): change_phase(GamePhase.SETUP),
		func() -> int: return current_turn_number,
		func() -> SceneTree: return get_tree(),
		_show_win_cb,
		_show_win_async_cb,
		_show_lose_async_cb,
	)

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


## State Machineのstate_changedシグナルハンドラー
func _on_state_changed(new_phase: int) -> void:
	# 既存の互換性のためphase_changedシグナルをemit
	emit_signal("phase_changed", new_phase)

# ゲーム開始
func start_game():
	print("=== ゲーム開始 ===")
	GameLogger.info("Game", "ゲーム開始: %d人" % player_system.players.size())

	# ゲーム中フラグを設定（クラッシュ復帰判定用）
	GameData.set_in_game(true)

	# State Machineの初期化（ゲーム開始時に実施）
	_init_state_machine()

	# ゲーム統計の初期化
	game_stats["total_creatures_destroyed"] = 0

	# 全プレイヤーに方向選択権を付与（ゲームスタート時）
	for player in player_system.players:
		player.direction_choice_pending = true

	# ネット対戦: サーバーの turn_start を待機（change_phase/start_turn はスキップ）
	# NetworkBridge.setup() 内で meta game_state から初期フェーズが発火される
	if is_net_battle:
		GameLogger.info("Game", "net_battle: start_game → サーバー指示待ち (state_machine初期化済み)")
		return

	change_phase(GamePhase.DICE_ROLL)
	start_turn()

# ターン開始
func start_turn():
	# 復帰モードでない場合のみリセット＋セーブ
	if _restore_phase.is_empty():
		last_dice_result = -1
		_current_save_phase = "turn_start"
		_save_game_state()

	var current_player = player_system.get_current_player()
	GameLogger.info("GFM", "ターン開始: P%d, ラウンド%d" % [current_player.id + 1, current_turn_number])

	# ターン開始時に順番アイコンを即座に更新（最初に呼ぶ）
	emit_signal("turn_started", current_player.id)

	# ネット対戦: 以降の自律動作（ドロー・スペルフェーズ・CPU判定等）は
	# サーバー指示で行うためスキップ。on_server_turn_started() で別途処理。
	if is_net_battle:
		GameLogger.info("GFM", "net_battle: start_turn をサーバー指示待ちで終了 (P%d)" % (current_player.id + 1))
		return

	# カードドロー処理（常に1枚引く）
	# チュートリアルモードではドローをスキップ
	if not _is_tutorial_mode():
		if spell_container and spell_container.spell_draw:
			var drawn = spell_container.spell_draw.draw_one(current_player.id)
			if not drawn.is_empty():
				GameLogger.info("GFM", "ドロー: P%d %s(id:%d)" % [current_player.id + 1, drawn.get("name", "?"), drawn.get("id", -1)])
				if current_player.id == 0:
					await get_tree().create_timer(0.1).timeout
		else:
			GameLogger.error("GFM", "ターン開始: spell_draw が初期化されていません (P%d)" % (current_player.id + 1))
	
	# 破産チェック（敵スペル等でEPマイナスの場合）
	await check_and_handle_bankruptcy()
	
	# UI更新
	if _ui_update_panels_cb.is_valid():
		_ui_update_panels_cb.call()
	
	# === 復帰フェーズ別スキップ処理 ===
	if not _restore_phase.is_empty():
		var phase = _restore_phase
		_restore_phase = ""  # 復帰モード解除（1回限り）

		if phase == "after_tile_action":
			# タイルアクション完了後 → そのままターン終了して次プレイヤーへ
			print("[GFM] 復帰: タイルアクション完了済み → ターン終了")
			end_turn()
			return

		if phase == "after_battle":
			# バトル結果確定後 → バトルUIを出さずにターン終了へ
			# （バトル結果はボード状態に反映済み、dominio_command_handlerの後続処理も不要）
			print("[GFM] 復帰: バトル結果確定済み → ターン終了")
			end_turn()
			return

		if phase == "after_movement":
			# 移動完了後 → タイルアクション処理へスキップ
			print("[GFM] 復帰: 移動完了済み → タイルアクション開始")
			change_phase(GamePhase.TILE_ACTION)
			# 人間プレイヤーの場合はドミニオコマンドボタンを表示
			if not is_cpu_player(current_player.id) and _ui_show_dominio_btn_cb.is_valid():
				_ui_show_dominio_btn_cb.call()
			var current_tile = board_system_3d.get_player_tile(current_player.id) if board_system_3d else 0
			if board_system_3d:
				board_system_3d.process_tile_landing(current_tile)
			return

		if phase == "after_dice":
			# ダイス確定後 → 移動へスキップ
			var saved_dice = last_dice_result
			print("[GFM] 復帰: ダイス結果 %d → 移動開始" % saved_dice)
			change_phase(GamePhase.MOVING)
			if board_system_3d:
				if _ui_set_phase_text_cb.is_valid():
					_ui_set_phase_text_cb.call("移動中...")
				board_system_3d.move_player_3d(current_player.id, saved_dice, saved_dice)
			return

		# "turn_start" の場合はそのまま通常フロー（フォールスルー）

	# ダイス結果が保存済みの場合 → スペル/ダイスフェーズをスキップして移動へ
	# （後方互換: _restore_phase が空でも last_dice_result で判定）
	if last_dice_result >= 0:
		var saved_dice = last_dice_result
		print("[GFM] ダイス結果復帰: %d → 移動開始" % saved_dice)
		change_phase(GamePhase.MOVING)
		if board_system_3d:
			if _ui_set_phase_text_cb.is_valid():
				_ui_set_phase_text_cb.call("移動中...")
			board_system_3d.move_player_3d(current_player.id, saved_dice, saved_dice)
		return

	# スペルフェーズを開始
	if spell_phase_handler:
		spell_phase_handler.start_spell_phase(current_player.id)
		# スペルフェーズ完了を待つ
		await spell_phase_handler.spell_phase_completed

	# ワープ系スペル使用時はサイコロフェーズをスキップしてタイルアクションへ
	if spell_phase_handler and spell_phase_handler.spell_state and spell_phase_handler.spell_state.should_skip_dice_phase():
		print("[GameFlowManager] ワープ使用によりサイコロフェーズをスキップ")
		change_phase(GamePhase.TILE_ACTION)
		# 現在のプレイヤー位置でタイルアクションを開始
		var current_tile = board_system_3d.get_player_tile(current_player.id)
		board_system_3d.process_tile_landing(current_tile)
		return

	# CPUターンの場合（デバッグモードでは無効化可能）
	var is_cpu_turn = is_cpu_player(current_player.id)
	if is_cpu_turn:
		if _ui_set_phase_text_cb.is_valid():
			_ui_set_phase_text_cb.call("CPUのターン...")
		change_phase(GamePhase.DICE_ROLL)
		await get_tree().create_timer(1.0).timeout
		roll_dice()
	else:
		change_phase(GamePhase.DICE_ROLL)
		if _ui_set_phase_text_cb.is_valid():
			_ui_set_phase_text_cb.call("サイコロを振ってください")
		if _ui_show_action_prompt_cb.is_valid():
			_ui_show_action_prompt_cb.call("サイコロを振ってください")

		# カメラを手動モードに設定（マップ確認可能にする）
		board_system_3d.enable_manual_camera()
		
		# 決定ボタンでサイコロを振るナビゲーション設定
		_setup_dice_phase_navigation()

## ダイスフェーズ用ナビゲーション設定（決定ボタンでサイコロを振る）
func _setup_dice_phase_navigation():
	if _ui_enable_navigation_cb.is_valid():
		_ui_enable_navigation_cb.call(
			func(): roll_dice(),  # 決定 = サイコロを振る
			Callable()            # 戻るなし
		)

# サイコロを振る
func roll_dice():
	# ネット対戦: ダイス生成はサーバー権威のためローカル実行せず、送信のみ
	if is_net_battle:
		GameLogger.info("GFM", "net_battle: dice_roll をサーバー送信")
		net_action_requested.emit("dice_roll", null)
		return

	if not dice_phase_handler:
		GameLogger.error("GFM", "roll_dice: dice_phase_handler が初期化されていません")
		return

	if not spell_phase_handler:
		GameLogger.error("GFM", "roll_dice: spell_phase_handler が初期化されていません")
		return

	await dice_phase_handler.roll_dice(current_phase, spell_phase_handler)

# === 3Dモード用イベント ===

func _on_tile_action_completed_3d():
	# 重複呼び出しを防ぐ（BUG-000対策: フェーズチェック + フラグチェック）
	if current_phase == GamePhase.END_TURN or current_phase == GamePhase.SETUP or current_phase == GamePhase.DICE_ROLL:
		return

	if _is_ending_turn:
		return

	# タイルアクション完了後セーブ（Save④）
	_current_save_phase = "after_tile_action"
	_save_game_state()

	end_turn()

func _on_invasion_completed_from_board(success: bool, tile_index: int):
	# デバッグログ
	print("[GameFlowManager] invasion_completed 受信: success=%s, tile=%d" % [success, tile_index])

	# バトル結果確定後セーブ（Save⑤: バトル画面クラッシュループ防止）
	_current_save_phase = "after_battle"
	_save_game_state()

	# DominioCommandHandler へ通知（完了処理を一元管理）
	# NOTE: CPUTurnProcessor への通知は不要（DCH.complete_action() がターン終了を処理）
	# CPUTurnProcessor._on_invasion_completed は冗長なUI操作 + _complete_action() で二重発火を起こしていた
	if dominio_command_handler:
		dominio_command_handler._on_invasion_completed(success, tile_index)

func _on_movement_completed_from_board(player_id: int, final_tile: int):
	# ネット対戦: 自分のターンの時だけ move_complete をサーバーに送信
	# （他プレイヤーの移動アニメもローカル再生されるが、送信権限があるのは動かしている本人のみ）
	if is_net_battle:
		if player_id == net_local_slot:
			# 薄型リレー: クライアントが計算した final_tile をサーバーに渡す。
			# サーバーの MoveComplete は direction >= 0 && direction < tileCount なら
			# その値をそのまま最終位置として使う（action.go:115-117）。
			GameLogger.info("GFM", "net: 移動完了 → move_complete送信 (player=%d tile=%d)" % [player_id, final_tile])
			net_action_requested.emit("move_complete", {"direction": final_tile})
		else:
			GameLogger.info("GFM", "net: 他プレイヤー移動完了 (player=%d)、送信なし" % player_id)
		return

	# ローカル: 各ハンドラーへ通知
	if dominio_command_handler:
		dominio_command_handler._on_movement_completed(player_id, final_tile)

	# 移動完了後セーブ（Save③）
	_current_save_phase = "after_movement"
	_save_game_state()

func _on_level_up_completed_from_board(tile_index: int, new_level: int):
	# デバッグログ
	print("[GameFlowManager] level_up_completed 受信: tile=%d, level=%d" % [tile_index, new_level])

	# 各ハンドラーへ通知
	if dominio_command_handler:
		dominio_command_handler._on_level_up_completed(tile_index, new_level)

	# UI更新
	if _ui_update_panels_cb.is_valid():
		_ui_update_panels_cb.call()

func _on_terrain_changed_from_board(tile_index: int, old_element: String, new_element: String):
	# デバッグログ
	print("[GameFlowManager] terrain_changed 受信: tile=%d, %s → %s" % [tile_index, old_element, new_element])

	# UI更新やスペルハンドラーへの通知が必要な場合はここに追加
	if _ui_update_panels_cb.is_valid():
		_ui_update_panels_cb.call()

func _on_start_passed_from_board(player_id: int):
	# LapSystem へ通知
	if lap_system:
		lap_system.on_start_passed(player_id)

func _on_warp_executed_from_board(player_id: int, from_tile: int, to_tile: int):
	# デバッグログ
	print("[GameFlowManager] warp_executed 受信: player=%d, from=%d, to=%d" % [player_id, from_tile, to_tile])

	# ワープ処理は既に完了しているため、ログのみ
	# 必要に応じてスペルハンドラーなどに通知

# === UIコールバック ===

func on_card_selected(card_index: int):
	# 優先順位順にハンドラーに処理を委譲

	# 1. アイテムフェーズハンドラー（最優先: 移動侵略スペル中のバトル等、
	#    spell_state が残ったままアイテム選択が走るケースを正しくルーティング）
	if item_phase_handler and item_phase_handler.try_handle_card_selection(card_index):
		return

	# 2. スペルフェーズハンドラー（カード選択ハンドラー + スペル処理）
	if spell_phase_handler and spell_phase_handler.try_handle_card_selection(card_index):
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
		# update_ui() はGSMの_on_phase_changedシグナルハンドラーで処理

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

	# ネット対戦: サーバーは PhaseEndTurn でしか end_turn を受け付けないため、
	# tile_action 等の中間フェーズからは pass を送って phase 遷移を進める。
	# サーバー: pass → PhaseEndTurn → turn_start(phase=end_turn) broadcast
	# クライアント: _setup_net_phase_ui("end_turn") で end_turn 送信
	if is_net_battle:
		var server_msg: String = "pass"
		if current_phase == GamePhase.END_TURN:
			server_msg = "end_turn"
		GameLogger.info("GFM", "net_battle: end_turn呼び出し → %s送信 (current_phase=%d)" % [server_msg, current_phase])
		# ローカルのUIクリーンアップ（ドミニオマーカー・カード選択・ドミニオボタン等）
		# ネット対戦でも自分が実行したコマンドの後始末は必要
		if dominio_command_handler:
			GameLogger.info("GFM", "net_battle cleanup: dominio state=%d" % dominio_command_handler.current_state)
			if dominio_command_handler.current_state != dominio_command_handler.State.CLOSED:
				dominio_command_handler.close_dominio_order()
				GameLogger.info("GFM", "net_battle cleanup: close_dominio_order 呼出")
		if _ui_hide_dominio_btn_cb.is_valid():
			_ui_hide_dominio_btn_cb.call()
		if _ui_hide_card_selection_cb.is_valid():
			_ui_hide_card_selection_cb.call()
		net_action_requested.emit(server_msg, null)
		_is_ending_turn = false
		return
	
	# Phase 1-A: ドミニオコマンドを閉じる、カード選択UIとボタンを隠す
	if dominio_command_handler and dominio_command_handler.current_state != dominio_command_handler.State.CLOSED:
		dominio_command_handler.close_dominio_order()
	
	if _ui_hide_dominio_btn_cb.is_valid():
		_ui_hide_dominio_btn_cb.call()
	if _ui_hide_card_selection_cb.is_valid():
		_ui_hide_card_selection_cb.call()
	
	var current_player = player_system.get_current_player()
	print("ターン終了: プレイヤー", current_player.id + 1)
	GameLogger.info("GFM", "ターン終了: P%d, ラウンド%d" % [current_player.id + 1, current_turn_number])

	# 手札調整が必要かチェック
	if discard_handler and discard_handler.has_method("check_and_discard_excess_cards"):
		await discard_handler.check_and_discard_excess_cards(current_player.id)
	elif discard_handler:
		GameLogger.error("GFM", "end_turn: discard_handler.check_and_discard_excess_cards が利用不可 (P%d)" % (current_player.id + 1))

	# 敵地判定・通行料支払い実行
	if toll_payment_handler and toll_payment_handler.has_method("check_and_pay_toll_on_enemy_land"):
		await toll_payment_handler.check_and_pay_toll_on_enemy_land()
	elif toll_payment_handler:
		GameLogger.error("GFM", "end_turn: toll_payment_handler.check_and_pay_toll_on_enemy_land が利用不可 (P%d)" % (current_player.id + 1))

	# 破産チェック（通行料支払い後）
	await check_and_handle_bankruptcy()
	
	emit_signal("turn_ended", current_player.id)
	
	change_phase(GamePhase.END_TURN)
	player_buff_system.end_turn_cleanup()
	
	# 現在のプレイヤーの刻印のduration更新
	if spell_container and spell_container.spell_curse:
		spell_container.spell_curse.update_player_curse(player_system.current_player_index)
	else:
		GameLogger.error("GFM", "end_turn: spell_curse が初期化されていません (P%d)" % (current_player.id + 1))
	
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
			
			# 世界刻印のduration更新
			if spell_container and spell_container.spell_world_curse:
				spell_container.spell_world_curse.on_round_start()
			else:
				GameLogger.error("GFM", "ラウンド%d開始: spell_world_curse が初期化されていません" % current_turn_number)
		
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
	var is_cpu = is_cpu_player(current_player_index)

	# Logger埋め込み
	var player_ep = player_system.players[current_player_index].magic_power if current_player_index < player_system.players.size() else 0
	GameLogger.warn("Game", "破産: P%d EP:%d" % [current_player_index + 1, player_ep])

	# 破産処理実行
	await bankruptcy_handler.process_bankruptcy(current_player_index, is_cpu)

# === 土地刻印（移動完了時発動） ===

## 土地刻印発動（移動完了時に呼ばれる公開メソッド）
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

	# ネット対戦: level_up/move_creature 成功後に close_dominio_order が呼ばれるが、
	# サーバー側は既に PhaseEndTurn に遷移済みで、turn_start(end_turn) が直後に来る。
	# ここで card selection UI を再表示するのは不要（ターン終了が確定している）。
	if is_net_battle:
		return

	# カメラをプレイヤーに戻す
	if board_system_3d:
		board_system_3d.return_camera_to_player()

	# カード選択UIの再初期化を次のフレームで実行（awaitを避ける）
	_reinitialize_card_selection.call_deferred()

# カード選択UIを再初期化（遅延実行用）
func _reinitialize_card_selection():
	var current_player = player_system.get_current_player()
	if current_player:
		# TileActionProcessorのフラグを再設定（召喚フェーズに戻る）
		if board_system_3d and board_system_3d.tile_action_processor:
			board_system_3d.tile_action_processor.begin_action_processing()

		# 特殊タイル上の場合は専用UI復元（召喚不可状態）
		var current_tile = board_system_3d.get_player_tile(current_player.id) if board_system_3d else -1
		var is_special = false
		if current_tile >= 0 and board_system_3d.tile_nodes.has(current_tile):
			var tile = board_system_3d.tile_nodes[current_tile]
			is_special = TileHelper.is_special_type(tile.tile_type)

		# カード選択UIを完全に再初期化（一度非表示にしてから再表示）
		if _ui_hide_card_selection_cb.is_valid():
			_ui_hide_card_selection_cb.call()

		if is_special:
			# 特殊タイル: TileActionProcessorの特殊タイル用UI表示を使用
			if board_system_3d.tile_action_processor:
				board_system_3d.tile_action_processor.show_special_tile_ui()
		else:
			if _ui_show_card_selection_cb.is_valid():
				_ui_show_card_selection_cb.call(current_player)

		# ドミニオコマンドボタンも再表示
		if _ui_show_dominio_btn_cb.is_valid():
			_ui_show_dominio_btn_cb.call()
			

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

# ============================================
# カメラ制御
# ============================================

## フェーズに応じてカメラモードを更新
func _update_camera_mode(phase: GamePhase):
	if not board_system_3d:
		return

	# ネット対戦: 現在プレイヤー（active）の位置にカメラを移動
	# 相手ターン: follow mode で相手を追う
	# 自分ターン: 自分の位置にカメラ移動（フェーズに応じて manual/follow）
	if is_net_battle and player_system:
		var active_slot: int = player_system.current_player_index
		var is_local_turn: bool = active_slot == net_local_slot
		GameLogger.info("Camera", "net: update active=%d local=%d phase=%d" % [active_slot, net_local_slot, phase])
		board_system_3d.set_camera_player(active_slot)
		if is_local_turn:
			# 自分ターン: ダイス/タイルアクションは手動、それ以外は追従
			match phase:
				GamePhase.DICE_ROLL, GamePhase.TILE_ACTION:
					board_system_3d.enable_manual_camera()
				_:
					board_system_3d.enable_follow_camera()
		else:
			board_system_3d.enable_follow_camera()
		# 自分/相手問わず、新フェーズ開始時はカメラを active プレイヤーの位置に寄せる
		if board_system_3d.has_method("focus_camera_on_player_pos"):
			board_system_3d.focus_camera_on_player_pos(active_slot, true)
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
	return not is_cpu_player(player_system.current_player_index)


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

## TutorialManager取得Callableを外部から設定
func set_tutorial_manager_getter(getter: Callable) -> void:
	_get_tutorial_manager_cb = getter

## UI操作Callableを一括注入（GSMから呼ばれる）
func inject_ui_callbacks(callbacks: Dictionary) -> void:
	_ui_set_phase_text_cb = callbacks.get("set_phase_text", Callable())
	_ui_update_panels_cb = callbacks.get("update_panels", Callable())
	_ui_show_dominio_btn_cb = callbacks.get("show_dominio_btn", Callable())
	_ui_hide_dominio_btn_cb = callbacks.get("hide_dominio_btn", Callable())
	_ui_show_card_selection_cb = callbacks.get("show_card_selection", Callable())
	_ui_hide_card_selection_cb = callbacks.get("hide_card_selection", Callable())
	_ui_enable_navigation_cb = callbacks.get("enable_navigation", Callable())
	_ui_disable_navigation_cb = callbacks.get("disable_navigation", Callable())
	_ui_show_action_prompt_cb = callbacks.get("show_action_prompt", Callable())
	_ui_show_big_dice_cb = callbacks.get("show_big_dice", Callable())

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
	if _get_tutorial_manager_cb.is_valid():
		return _get_tutorial_manager_cb.call()
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


## セーブデータからゲームを復帰
## 通常のstart_game()の代わりに呼ばれる
func restore_game(save_data: Dictionary) -> bool:
	print("=== ゲーム復帰開始 ===")
	GameLogger.info("Game", "ゲーム復帰: ラウンド%d" % save_data.get("progress", {}).get("current_turn_number", 0))

	# ゲーム中フラグを維持
	GameData.set_in_game(true)

	# ステージID・ゲームモードを復元
	current_stage_id = save_data.get("stage_id", current_stage_id)
	current_game_mode = save_data.get("game_mode", current_game_mode)

	# State Machineの初期化
	_init_state_machine()

	# ゲーム統計の初期化（セーブデータで上書きされる）
	game_stats["total_creatures_destroyed"] = 0

	# セーブデータを適用
	var systems: Dictionary = {
		"player_system": player_system,
		"card_system": card_system,
		"board_system_3d": board_system_3d,
		"game_flow_manager": self,
		"lap_system": lap_system,
		"player_buff_system": player_buff_system,
	}
	if not GameStateSaver.apply_save_data(save_data, systems):
		GameLogger.error("Game", "セーブデータの適用に失敗、通常開始にフォールバック")
		start_game()
		return false

	# 復帰フェーズを設定（start_turnでのスキップ制御に使用）
	_restore_phase = _current_save_phase
	GameLogger.info("Game", "復帰フェーズ: %s, ダイス結果: %d" % [_restore_phase, last_dice_result])

	# 3D駒を復元位置に配置
	if board_system_3d:
		for player in player_system.players:
			board_system_3d.place_player_at_tile(player.id, player.current_tile)
			board_system_3d.set_player_tile(player.id, player.current_tile)

	# UI更新（apply後に手札・パネル等を再描画）
	if card_system:
		card_system.hand_updated.emit()
	if _ui_update_panels_cb.is_valid():
		_ui_update_panels_cb.call()

	# カメラを復帰プレイヤーに移動
	if board_system_3d:
		board_system_3d.set_camera_player(player_system.current_player_index)

	# フェーズをSETUPからDICE_ROLLへ
	change_phase(GamePhase.DICE_ROLL)
	start_turn()

	print("=== ゲーム復帰完了 ===")
	return true


## ダイス結果確定時のコールバック（DicePhaseHandlerから呼ばれる）
func _on_dice_confirmed(dice_value: int) -> void:
	last_dice_result = dice_value
	_current_save_phase = "after_dice"
	_save_game_state()


## ゲーム状態をセーブ（各セーブポイントから呼ばれる）
func _save_game_state() -> void:
	var systems: Dictionary = {
		"player_system": player_system,
		"card_system": card_system,
		"board_system_3d": board_system_3d,
		"game_flow_manager": self,
		"lap_system": lap_system,
		"player_buff_system": player_buff_system,
		"stage_id": current_stage_id,
	}
	var save_data: Dictionary = GameStateSaver.build_save_data(systems)
	GameStateSaver.save_to_file(save_data)

## プレイヤーの制御タイプを取得（"local" / "cpu" / 将来 "remote"）
## convert_to_*で明示変更された場合はmanual_control_allより優先
func get_control_type(player_id: int) -> String:
	if player_id < 0 or player_id >= _player_control_types.size():
		return "local"
	# 明示的にconvert_to_*で変更された場合はそちらを優先
	if _control_type_overridden.has(player_id):
		return _player_control_types[player_id]
	if DebugSettings.manual_control_all:
		return "local"
	return _player_control_types[player_id]

## CPUプレイヤーかどうかを判定（統一メソッド・既存互換）
## ネット対戦時は全プレイヤーを remote 扱いとし、ローカルでのCPU AI起動を防ぐ。
func is_cpu_player(player_id: int) -> bool:
	if is_net_battle:
		return false
	return get_control_type(player_id) == "cpu"

## 制御タイプをCPUに変更（次のターン/フェーズ開始時に反映）
## "balanced"ポリシーを自動適用（プレイヤーキャラにはCPU設定がないため）
func convert_to_cpu(player_id: int) -> void:
	if player_id >= 0 and player_id < _player_control_types.size():
		_player_control_types[player_id] = "cpu"
		_control_type_overridden[player_id] = true
		_apply_default_cpu_policy()
		_sync_board_cpu_flags()
		GameLogger.info("Game", "P%d: control_type → cpu (balanced policy)" % [player_id + 1])

## 制御タイプをローカルに変更（再接続用）
func convert_to_local(player_id: int) -> void:
	if player_id >= 0 and player_id < _player_control_types.size():
		_player_control_types[player_id] = "local"
		_control_type_overridden[player_id] = true
		_sync_board_cpu_flags()
		GameLogger.info("Game", "P%d: control_type → local" % [player_id + 1])

## CPU切り替え時にデフォルトポリシー（balanced）を適用
## ネット対戦では全員人間スタートなので、切断者のCPU化時に統一ポリシーで上書き
func _apply_default_cpu_policy() -> void:
	if board_system_3d and board_system_3d.cpu_ai_handler:
		board_system_3d.cpu_ai_handler.set_battle_policy_preset("balanced")
		GameLogger.info("Game", "CPU引き継ぎ: balancedポリシー適用")

## 外部システムのplayer_is_cpuコピーを同期
func _sync_board_cpu_flags() -> void:
	var flags = player_is_cpu
	if board_system_3d:
		board_system_3d.player_is_cpu = flags
	if discard_handler and "player_is_cpu" in discard_handler:
		discard_handler.player_is_cpu = flags

## Day 3 追加: BoardSystem3D からの creature_updated を受信・リレー
func _on_creature_updated_from_board(tile_index: int, creature_data: Dictionary):
	# シグナルリレー（UIManager はこのシグナルを受信）
	creature_updated_relay.emit(tile_index, creature_data)


# =============================================================================
# ネット対戦 API（薄型リレー方式）
# =============================================================================
# サーバーからの指示をGFMに流すためのエントリーポイント。
# NetworkBridge が WSメッセージ受信時に呼び出す。
# 実装方針: 既存のシグナル（turn_started / phase_changed / dice_rolled）を
# emit することで、UIManager・HandDisplay等の既存UIが自然に反応する。
# =============================================================================

## ネット対戦モードを設定
func set_is_net_battle(enabled: bool, local_slot: int = 0) -> void:
	is_net_battle = enabled
	net_local_slot = local_slot
	GameLogger.info("Game", "is_net_battle=%s local_slot=%d" % [str(enabled), local_slot])


## サーバーからの turn_start メッセージを受けて、GFMのターン状態を更新する
## data: {"active_player": int, "phase": String, "hand": [int], "turn": int, ...}
func on_server_turn_started(data: Dictionary) -> void:
	if not is_net_battle:
		return
	var active_player_slot: int = int(data.get("active_player", -1))
	if active_player_slot < 0:
		return

	# PlayerSystem の current_player_index を同期
	if player_system:
		player_system.current_player_index = active_player_slot

	# BoardSystem3D の current_player_index も同期（process_tile_landing 等で使用）
	if board_system_3d:
		board_system_3d.current_player_index = active_player_slot

	# ターン番号
	if data.has("turn"):
		current_turn_number = int(data.get("turn", 1))

	# 既存シグナル発火 → UIManager.set_current_turn 等が自然に動く
	turn_started.emit(active_player_slot)

	# UI更新
	if _ui_update_panels_cb.is_valid():
		_ui_update_panels_cb.call()

	# フェーズを反映（文字列→enum）
	var server_phase: String = String(data.get("phase", "spell"))
	var gfm_phase = _server_phase_to_enum(server_phase)
	if gfm_phase != current_phase:
		change_phase(gfm_phase)

	# 自分のターンの場合、フェーズに応じたUIを起動
	if active_player_slot == net_local_slot:
		# 同一フェーズの重複turn_startを無視（summon後のpass broadcastで再発火するケース等）
		# 例: summon → turn_start(end_turn) → end_turn送信 → pass処理→ turn_start(end_turn) 再発火
		#     2回目の _setup_net_phase_ui("end_turn") で end_turn を重複送信してしまう
		var phase_key: String = "%d:%s" % [active_player_slot, server_phase]
		if _net_last_setup_phase == phase_key:
			GameLogger.info("GFM", "net: turn_start 重複スキップ (%s)" % phase_key)
		else:
			_net_last_setup_phase = phase_key
			_setup_net_phase_ui(server_phase)
	else:
		# 相手のターン: ナビゲーション無効化
		_net_last_setup_phase = ""
		_disable_net_phase_ui()


## ネット対戦: サーバーフェーズに応じて既存UIを起動（自分のターンのみ）
func _setup_net_phase_ui(server_phase: String) -> void:
	match server_phase:
		"spell":
			# 暫定: スペルフェーズは自動パス（Phase 2でスペル選択UI実装）
			GameLogger.info("GFM", "net: spell phase → auto-pass (暫定)")
			net_action_requested.emit("spell_pass", null)
		"dice":
			# 既存のダイス待機UIを起動
			if _ui_set_phase_text_cb.is_valid():
				_ui_set_phase_text_cb.call("サイコロを振ってください")
			if _ui_show_action_prompt_cb.is_valid():
				_ui_show_action_prompt_cb.call("サイコロを振ってください")
			if board_system_3d:
				board_system_3d.enable_manual_camera()
			_setup_dice_phase_navigation()
		"move":
			# 移動フェーズ: 分岐がなければ自動、分岐があればUIが出る
			# Phase 2 で分岐処理を実装
			GameLogger.info("GFM", "net: move phase (待機)")
		"tile_action":
			# ダイスフェーズで設定した ✓ボタン=roll_dice のバインディングを解除（誤発火防止）
			if _ui_disable_navigation_cb.is_valid():
				_ui_disable_navigation_cb.call()
			# 既存のタイル着地処理を起動（空タイル=召喚UI、自タイル=ドミニオ、敵タイル=バトル）
			# 既存の TileActionProcessor 経由で UI が自動で出る
			var ctp_player = player_system.get_current_player()
			if ctp_player and board_system_3d:
				# 既に _on_movement_completed 経由で process_tile_landing が走って
				# UI が出ていれば二重実行しない（tile_action_processor の is_action_processing で判定）
				var tap = board_system_3d.tile_action_processor if board_system_3d else null
				if tap and tap.is_action_processing:
					GameLogger.info("GFM", "net: tile_action → 既に処理中のため process_tile_landing スキップ")
				else:
					var current_tile = board_system_3d.get_player_tile(ctp_player.id)
					GameLogger.info("GFM", "net: tile_action → process_tile_landing(tile=%d)" % current_tile)
					board_system_3d.process_tile_landing(current_tile)
				# ドミニオコマンドボタン（D）を明示表示（自分の土地があれば自動判定）
				if _ui_show_dominio_btn_cb.is_valid():
					_ui_show_dominio_btn_cb.call()
			else:
				GameLogger.warn("GFM", "net: tile_action → player or board 不在、auto-pass")
				net_action_requested.emit("pass", null)
		"end_turn":
			# サーバー指示で end_turn を送信
			net_action_requested.emit("end_turn", null)
		_:
			GameLogger.warn("GFM", "net: unknown phase %s" % server_phase)


## ネット対戦: 相手ターン時のUI抑制
func _disable_net_phase_ui() -> void:
	if _ui_set_phase_text_cb.is_valid():
		_ui_set_phase_text_cb.call("相手のターン")
	if _ui_hide_card_selection_cb.is_valid():
		_ui_hide_card_selection_cb.call()
	# グローバルアクションボタン（✓/×/▲/▼/特殊）を全てグレーアウト
	if _ui_disable_navigation_cb.is_valid():
		_ui_disable_navigation_cb.call()
	# ドミニオコマンドボタンも隠す
	if _ui_hide_dominio_btn_cb.is_valid():
		_ui_hide_dominio_btn_cb.call()


## サーバーからの dice_result メッセージを受けて、既存ダイス演出を再生
## data: {"value": int} または {"dice_value": int} または {"result": int, "player": int}
func on_server_dice_result(data: Dictionary) -> void:
	if not is_net_battle:
		return
	var value: int = int(data.get("dice_value", data.get("value", data.get("result", 0))))
	if value <= 0:
		return
	var player_id: int = int(data.get("player", net_local_slot))
	last_dice_result = value
	GameLogger.info("Game", "dice_result受信: player=%d value=%d" % [player_id, value])
	# 既存 dice_rolled シグナルを発火 → UIが演出再生
	dice_rolled.emit(value)
	# 大きなダイス結果を表示（両プレイヤー画面で視認性向上）
	if _ui_show_big_dice_cb.is_valid():
		GameLogger.info("Dice", "show_big_dice_result(%d) 呼出" % value)
		_ui_show_big_dice_cb.call(value)
	else:
		GameLogger.warn("Dice", "show_big_dice_cb が未接続")
	# フェーズを MOVING に遷移
	change_phase(GamePhase.MOVING)

	# 自分のターンの時だけ move_player_3d を呼ぶ（分岐UIも出るため）
	# 他プレイヤーのターンでは待機し、action_broadcast(move_complete) で最終位置を反映する
	if player_id == net_local_slot and board_system_3d:
		if _ui_set_phase_text_cb.is_valid():
			_ui_set_phase_text_cb.call("移動中...")
		board_system_3d.move_player_3d(player_id, value, value)
	else:
		GameLogger.info("Game", "net: 他プレイヤー(%d)の移動、action_broadcast待ち" % player_id)


## サーバーからの action_result (broadcast) を受けて、他プレイヤーのアクションをローカルに反映
## サーバーペイロード形式（session.go:broadcastAction）:
##   {"player": int, "action_type": string, "turn_number": int, "state_version": int, "data": {...}}
## data フィールドにアクション別の詳細が入る（例: move_complete なら {"position": int, "phase": string}）
func on_server_action_broadcast(data: Dictionary) -> void:
	if not is_net_battle:
		return
	var action_type: String = String(data.get("action_type", data.get("type", data.get("action", ""))))
	var player: int = int(data.get("player", -1))
	var payload: Dictionary = data.get("data", {}) if data.has("data") and data["data"] is Dictionary else {}
	GameLogger.info("Game", "action_broadcast受信: player=%d type=%s" % [player, action_type])

	# 自分が送信したアクションは既に反映済みなのでスキップ
	if player == net_local_slot:
		return

	match action_type:
		"move_complete":
			# 他プレイヤーの移動結果を反映: 駒を最終位置に瞬間配置（3Dモデル位置も更新）
			# Phase 2 で経路アニメ補間に置き換え予定
			var final_position: int = int(payload.get("position", -1))
			if final_position >= 0 and board_system_3d:
				GameLogger.info("Game", "net: P%d 移動結果反映 → tile=%d" % [player, final_position])
				if board_system_3d.has_method("place_player_at_tile"):
					board_system_3d.place_player_at_tile(player, final_position)
				elif board_system_3d.has_method("set_player_tile"):
					board_system_3d.set_player_tile(player, final_position)
				# カメラを移動したプレイヤーに実際に追従させる（瞬間移動のため手動更新）
				GameLogger.info("Camera", "net: move_complete → P%d に追従" % player)
				board_system_3d.set_camera_player(player)
				board_system_3d.enable_follow_camera()
				if board_system_3d.has_method("focus_camera_on_player_pos"):
					board_system_3d.focus_camera_on_player_pos(player, true)
				# 着地タイルがチェックポイントならダウン解除（停止型checkpointの効果を再現）
				# 周回完了は別途 lap_complete broadcast で反映される
				if board_system_3d.tile_nodes.has(final_position):
					var landed_tile = board_system_3d.tile_nodes[final_position]
					if landed_tile and landed_tile.tile_type == "checkpoint":
						GameLogger.info("Game", "net: P%d チェックポイント着地 → ダウン解除" % player)
						if board_system_3d.has_method("clear_all_down_states_for_player"):
							board_system_3d.clear_all_down_states_for_player(player)
		"summon":
			# 他プレイヤーの召喚結果反映: タイル所有権・クリーチャー配置・手札/EP更新
			var card_id: int = int(payload.get("card_id", -1))
			var tile_index: int = int(payload.get("tile", -1))
			if card_id <= 0 or tile_index < 0 or not board_system_3d:
				GameLogger.warn("Game", "net: summon payload 不正 card_id=%d tile=%d" % [card_id, tile_index])
				return
			var creature_data: Dictionary = CardLoader.get_card_by_id(card_id)
			if creature_data.is_empty():
				GameLogger.warn("Game", "net: summon カードID不明 card_id=%d" % card_id)
				return
			GameLogger.info("Game", "net: P%d 召喚結果反映 card=%d tile=%d name=%s" % [player, card_id, tile_index, creature_data.get("name", "?")])

			# タイル所有権・クリーチャー配置
			board_system_3d.set_tile_owner(tile_index, player)
			board_system_3d.place_creature(tile_index, creature_data.duplicate(true), player)

			# ダウン状態を設定（奮闘キーワードを持たないクリーチャーはダウン）
			var _tile_node = board_system_3d.tile_nodes.get(tile_index) if board_system_3d.tile_nodes.has(tile_index) else null
			if _tile_node and _tile_node.has_method("set_down_state"):
				if not PlayerBuffSystem.has_unyielding(creature_data):
					_tile_node.set_down_state(true)

			# EP消費（コスト計算）
			if player_system and player >= 0 and player < player_system.players.size():
				var p = player_system.players[player]
				var cost_dict: Dictionary = creature_data.get("cost", {})
				var cost: int = int(cost_dict.get("base", 0))
				p.magic_power -= cost

			# 手札から該当カードを削除（card_id で検索）
			if card_system and card_system.player_hands.has(player):
				var hand_data: Array = card_system.player_hands[player]["data"]
				for i in range(hand_data.size()):
					if int(hand_data[i].get("id", -1)) == card_id:
						card_system.remove_card_from_hand(player, i)
						break

			# UI更新
			if _ui_update_panels_cb.is_valid():
				_ui_update_panels_cb.call()
		"dominio_action":
			# 他プレイヤーのドミニオコマンド結果反映
			var cmd: String = String(payload.get("command", ""))
			match cmd:
				"level_up":
					var t_idx: int = int(payload.get("source_tile", -1))
					var new_level: int = int(payload.get("target_level", -1))
					var ep_cost: int = int(payload.get("cost", 0))
					if t_idx < 0 or new_level <= 0 or not board_system_3d:
						GameLogger.warn("Game", "net: dominio level_up payload 不正")
						return
					if not board_system_3d.tile_nodes.has(t_idx):
						return
					var lu_tile = board_system_3d.tile_nodes[t_idx]
					GameLogger.info("Game", "net: P%d dominio level_up tile=%d Lv→%d cost=%d" % [player, t_idx, new_level, ep_cost])
					lu_tile.level = new_level
					if board_system_3d.level_up_completed:
						board_system_3d.level_up_completed.emit(t_idx, new_level)
					if player_system and player >= 0 and player < player_system.players.size():
						player_system.players[player].magic_power -= ep_cost
					# ダウン状態設定（奮闘除く）
					if lu_tile.has_method("set_down_state") and not PlayerBuffSystem.has_unyielding(lu_tile.creature_data):
						lu_tile.set_down_state(true)
				"move_creature":
					var src: int = int(payload.get("source_tile", -1))
					var dst: int = int(payload.get("target_tile", -1))
					if src < 0 or dst < 0 or not board_system_3d:
						GameLogger.warn("Game", "net: dominio move_creature payload 不正")
						return
					if not board_system_3d.tile_nodes.has(src) or not board_system_3d.tile_nodes.has(dst):
						return
					var src_tile = board_system_3d.tile_nodes[src]
					var dst_tile = board_system_3d.tile_nodes[dst]
					if src_tile.creature_data.is_empty():
						GameLogger.warn("Game", "net: dominio move 元タイル %d にクリーチャーなし" % src)
						return
					var moving_creature: Dictionary = src_tile.creature_data.duplicate(true)
					# 移動時に curse 消滅（通常移動の仕様）
					if moving_creature.has("curse"):
						moving_creature.erase("curse")
					GameLogger.info("Game", "net: P%d dominio move_creature tile=%d→%d name=%s" % [player, src, dst, moving_creature.get("name", "?")])
					# 移動元を空地化
					board_system_3d.remove_creature(src)
					board_system_3d.set_tile_owner(src, -1)
					# 移動先へ配置
					board_system_3d.set_tile_owner(dst, player)
					board_system_3d.place_creature(dst, moving_creature, player)
					if dst_tile.has_method("set_down_state") and not PlayerBuffSystem.has_unyielding(moving_creature):
						dst_tile.set_down_state(true)
				_:
					GameLogger.info("Game", "net: 未実装ドミニオコマンド %s" % cmd)
			# UI更新
			if _ui_update_panels_cb.is_valid():
				_ui_update_panels_cb.call()
		"lap_complete":
			# 他プレイヤーの周回完了を反映（ダウン解除 + HP回復+10）
			var lap_player: int = int(payload.get("player_id", player))
			if board_system_3d:
				GameLogger.info("Game", "net: P%d 周回完了反映 → ダウン解除+HP回復" % lap_player)
				if board_system_3d.has_method("clear_all_down_states_for_player"):
					board_system_3d.clear_all_down_states_for_player(lap_player)
				if board_system_3d.has_method("heal_all_creatures_for_player"):
					board_system_3d.heal_all_creatures_for_player(lap_player, 10)
		"spell_pass", "spell_cast", "pass":
			# 何もしない（フェーズ遷移は turn_start で通知される）
			pass
		_:
			GameLogger.info("Game", "net: 未実装アクション種別 %s" % action_type)


## サーバーからの game_over メッセージを受けて、試合終了処理
## data: {"winner": int, ...}
func on_server_game_over(data: Dictionary) -> void:
	if not is_net_battle:
		return
	var winner: int = int(data.get("winner", -1))
	GameLogger.info("Game", "game_over受信: winner=%d" % winner)
	# TODO Phase 2: GameResultHandler 経由で勝敗演出・シーン遷移


## サーバーフェーズ文字列を GFM の GamePhase enum に変換
func _server_phase_to_enum(server_phase: String) -> int:
	match server_phase:
		"spell": return GamePhase.SETUP  # スペルフェーズは既存の SETUP 相当として扱う
		"dice": return GamePhase.DICE_ROLL
		"move": return GamePhase.MOVING
		"tile_action": return GamePhase.TILE_ACTION
		"battle": return GamePhase.BATTLE
		"end_turn": return GamePhase.END_TURN
		_: return current_phase
