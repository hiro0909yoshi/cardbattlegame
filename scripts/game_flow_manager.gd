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

# チュートリアルモード（CPUは常にバトルを仕掛ける）
var is_tutorial_mode: bool = false

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var player_buff_system: PlayerBuffSystem
var ui_manager: UIManager
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem
var battle_screen_manager: BattleScreenManager

# アイテムフェーズ用バトルステータスオーバーレイ
var battle_status_overlay = null

# 魔法石システム
var magic_stone_system: MagicStoneSystem

# スペル効果システム
var spell_draw: SpellDraw
var spell_magic: SpellMagic
var spell_land: SpellLand
var spell_curse: SpellCurse
var spell_curse_toll: SpellCurseToll
var spell_cost_modifier: SpellCostModifier
var spell_dice: SpellDice
var spell_curse_stat: SpellCurseStat
var spell_world_curse: SpellWorldCurse
var spell_player_move: SpellPlayerMove

# 破産処理ハンドラー
var bankruptcy_handler: BankruptcyHandler = null

# ターン終了制御用フラグ（BUG-000対策）
var is_ending_turn = false

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
func set_lap_system(system: LapSystem) -> void:
	lap_system = system
	if lap_system:
		lap_system.lap_completed.connect(func(player_id): lap_completed.emit(player_id))


# 3Dモード設定
func setup_3d_mode(board_3d, cpu_settings: Array):
	board_system_3d = board_3d
	player_is_cpu = cpu_settings
	
	# 3Dボードのシグナル接続
	if board_system_3d:
		board_system_3d.tile_action_completed.connect(_on_tile_action_completed_3d)
		# デバッグフラグを転送
		board_system_3d.debug_manual_control_all = debug_manual_control_all
		
		# MovementControllerにgame_flow_managerを設定
		if board_system_3d.movement_controller:
			board_system_3d.movement_controller.game_flow_manager = self
		
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
		lap_system._setup_ui()

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

## スペル効果システムを外部から設定（一括）
func set_spell_systems(systems_dict: Dictionary) -> void:
	spell_draw = systems_dict.get("spell_draw")
	spell_magic = systems_dict.get("spell_magic")
	spell_land = systems_dict.get("spell_land")
	spell_curse = systems_dict.get("spell_curse")
	spell_dice = systems_dict.get("spell_dice")
	spell_curse_stat = systems_dict.get("spell_curse_stat")
	spell_world_curse = systems_dict.get("spell_world_curse")
	spell_player_move = systems_dict.get("spell_player_move")
	bankruptcy_handler = systems_dict.get("bankruptcy_handler")
	
	# 子ノードとして追加（ノードタイプの場合）
	if spell_curse_stat and not spell_curse_stat.get_parent():
		add_child(spell_curse_stat)
	if spell_world_curse and not spell_world_curse.get_parent():
		add_child(spell_world_curse)
	if bankruptcy_handler and not bankruptcy_handler.get_parent():
		add_child(bankruptcy_handler)

# ゲーム開始
func start_game():
	print("=== ゲーム開始 ===")
	
	# ゲーム統計の初期化
	game_stats["total_creatures_destroyed"] = 0
	
	# 全プレイヤーに方向選択権を付与（ゲームスタート時）
	for player in player_system.players:
		player.buffs["direction_choice_pending"] = true
		print("[GameFlowManager] プレイヤー%d: スタート時方向選択権付与" % (player.id + 1))
	
	current_phase = GamePhase.DICE_ROLL
	update_ui()
	start_turn()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	
	# Phase 1-A: ターン開始時はドミニオコマンドボタンを隠す
	if ui_manager:
		ui_manager.hide_dominio_order_button()
	
	# カードドロー処理（常に1枚引く）
	# チュートリアルモードではドローをスキップ
	if not _is_tutorial_mode():
		var drawn = spell_draw.draw_one(current_player.id)
		if not drawn.is_empty() and current_player.id == 0:
			await get_tree().create_timer(0.1).timeout
	
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
		var current_tile = board_system_3d.movement_controller.get_player_tile(current_player.id)
		board_system_3d.process_tile_landing(current_tile)
		return
	
	# CPUターンの場合（デバッグモードでは無効化可能）
	var is_cpu_turn = current_player.id < player_is_cpu.size() and player_is_cpu[current_player.id] and not debug_manual_control_all
	if is_cpu_turn:
		ui_manager.phase_label.text = "CPUのターン..."
		current_phase = GamePhase.DICE_ROLL
		await get_tree().create_timer(1.0).timeout
		roll_dice()
	else:
		current_phase = GamePhase.DICE_ROLL
		ui_manager.phase_label.text = "サイコロを振ってください"
		update_ui()
		
		# カメラを手動モードに設定（マップ確認可能にする）
		if board_system_3d and board_system_3d.camera_controller:
			board_system_3d.camera_controller.enable_manual_mode()
		
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

## ダイスフェーズのナビゲーションをクリア
func _clear_dice_phase_navigation():
	if ui_manager:
		ui_manager.disable_navigation()

# サイコロを振る
func roll_dice():
	# スペルフェーズ中の場合は、スペルを使わずにダイスロールに進む
	if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
		spell_phase_handler.pass_spell(false)  # auto_roll=false（ここで既にroll_dice中なので）
		# フェーズ完了を待つ必要はない（pass_spellが即座に完了する）
	
	if current_phase != GamePhase.DICE_ROLL:
		return
	
	# ナビゲーションをクリア（連打防止）
	_clear_dice_phase_navigation()
	
	# カメラをプレイヤー位置に戻す（即座に移動、向きも正しく設定）
	if board_system_3d and board_system_3d.camera_controller:
		board_system_3d.camera_controller.focus_on_player(player_system.current_player_index, false)
	
	change_phase(GamePhase.MOVING)
	
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
	
	# ダイス結果を表示
	if ui_manager and ui_manager.phase_display:
		# ダイス範囲呪いがある場合は特殊表示
		if spell_dice and spell_dice.has_dice_range_curse(player_system.current_player_index):
			var range_info = spell_dice.get_dice_range_info(player_system.current_player_index)
			ui_manager.phase_display.show_dice_result_range(range_info.get("name", ""), modified_dice)
			print("[ダイス/%s] %d（範囲: %d〜%d）" % [range_info.get("name", ""), modified_dice, range_info.get("min", 1), range_info.get("max", 6)])
		elif needs_third:
			ui_manager.phase_display.show_dice_result_triple(dice1, dice2, dice3, modified_dice)
			print("[ダイス] %d + %d + %d = %d (修正後: %d)" % [dice1, dice2, dice3, total_dice, modified_dice])
		else:
			ui_manager.phase_display.show_dice_result_double(dice1, dice2, modified_dice)
			print("[ダイス] %d + %d = %d (修正後: %d)" % [dice1, dice2, total_dice, modified_dice])
	
	# ダイスロール後のEP付与（チャージステップなど）
	if spell_dice:
		spell_dice.process_magic_grant(player_system.current_player_index, ui_manager)
		if spell_dice.should_grant_magic(player_system.current_player_index):
			await get_tree().create_timer(1.0).timeout
	
	# 表示待ち
	await get_tree().create_timer(1.5).timeout
	
	print("[GameFlowManager] roll_dice: await完了、移動開始 (phase=%s)" % current_phase)
	
	var current_player = player_system.get_current_player()
	
	# 3D移動
	if board_system_3d:
		ui_manager.phase_label.text = "移動中..."
		print("[GameFlowManager] roll_dice: move_player_3d呼び出し (player=%d, dice=%d)" % [current_player.id, modified_dice])
		board_system_3d.move_player_3d(current_player.id, modified_dice, modified_dice)

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



# === UIコールバック ===

func on_card_selected(card_index: int):

	# カード選択ハンドラーが選択中の場合
	if spell_phase_handler and spell_phase_handler.card_selection_handler:
		var handler = spell_phase_handler.card_selection_handler
		if handler.is_selecting_enemy_card():
			handler.on_enemy_card_selected(card_index)
			return
		if handler.is_selecting_deck_card():
			handler.on_deck_card_selected(card_index)
			return
		if handler.is_selecting_transform_card():
			handler.on_transform_card_selected(card_index)
			return
	
	# アイテムフェーズ中は、ItemPhaseHandlerのcurrent_player_idを使用
	var target_player_id = player_system.get_current_player().id
	if item_phase_handler and item_phase_handler.is_item_phase_active():
		target_player_id = item_phase_handler.current_player_id
	
	var hand = card_system.get_all_cards_for_player(target_player_id)
	

	
	if card_index >= hand.size():
		return
	
	var card = hand[card_index]
	var card_type = card.get("type", "")

	
	# アイテムフェーズ中かチェック（スペルフェーズより優先）
	# ※スペル移動による侵略時、スペルフェーズがアクティブなままアイテムフェーズが開始されるため
	if item_phase_handler and item_phase_handler.is_item_phase_active():
		# アイテムカードまたは援護対象クリーチャーが使用可能
		if card_type == "item":
			item_phase_handler.use_item(card)
			return
		elif card_type == "creature":
			# アイテムクリーチャー判定
			var keywords = card.get("ability_parsed", {}).get("keywords", [])
			if "アイテムクリーチャー" in keywords:
				item_phase_handler.use_item(card)
				return
			# 援護スキルがある場合のみクリーチャーを使用可能
			elif item_phase_handler.has_assist_skill():
				var assist_elements = item_phase_handler.get_assist_target_elements()
				var card_element = card.get("element", "")
				# 対象属性かチェック
				if "all" in assist_elements or card_element in assist_elements:
					item_phase_handler.use_item(card)
					return
			return
		else:
			return
	
	# スペルフェーズ中かチェック（アイテムフェーズがアクティブでない場合）
	if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
		# スペルカードのみ使用可能
		if card_type == "spell":
			spell_phase_handler.use_spell(card)
			return
		else:
			return
	
	# スペルフェーズ以外でスペルカードが選択された場合
	if card_type == "spell":
		return
	
	# アイテムフェーズ以外でアイテムカードが選択された場合
	if card_type == "item":
		return
	
	# Phase 1-D: 交換モードチェック
	if dominio_command_handler and dominio_command_handler._swap_mode:
		dominio_command_handler.on_card_selected_for_swap(card_index)
	elif board_system_3d:
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
	if is_ending_turn:
		print("Warning: Already ending turn (flag check)")
		return
	
	if current_phase == GamePhase.END_TURN:
		print("Warning: Already ending turn (phase check)")
		return
	
	# ★重要: フラグを最優先で立てる
	is_ending_turn = true
	
	# Phase 1-A: ドミニオコマンドを閉じる、カード選択UIとボタンを隠す
	if dominio_command_handler and dominio_command_handler.current_state != dominio_command_handler.State.CLOSED:
		dominio_command_handler.close_dominio_order()
	
	if ui_manager:
		ui_manager.hide_dominio_order_button()
		ui_manager.hide_card_selection_ui()
	
	var current_player = player_system.get_current_player()
	print("ターン終了: プレイヤー", current_player.id + 1)
	
	# 手札調整が必要かチェック
	await check_and_discard_excess_cards()
	
	# 敵地判定・通行料支払い実行
	await check_and_pay_toll_on_enemy_land()
	
	# 破産チェック（通行料支払い後）
	await check_and_handle_bankruptcy()
	
	emit_signal("turn_ended", current_player.id)
	
	change_phase(GamePhase.END_TURN)
	player_buff_system.end_turn_cleanup()
	
	# 現在のプレイヤーの呪いのduration更新
	if spell_curse:
		spell_curse.update_player_curse(player_system.current_player_index)
	
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
				_toggle_all_branch_tiles()
			
			# 世界呪いのduration更新
			if spell_world_curse:
				spell_world_curse.on_round_start()
		
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

# ゲーム終了フラグ（勝敗判定の重複防止）
var _game_ended: bool = false

# プレイヤー勝利処理
func on_player_won(player_id: int):
	# 重複防止
	if _game_ended:
		print("[GameFlowManager] ゲームは既に終了しています")
		return
	_game_ended = true
	
	var _player = player_system.players[player_id]  # 将来の拡張用
	change_phase(GamePhase.SETUP)
	
	print("🎉 プレイヤー", player_id + 1, "の勝利！ 🎉")
	
	# プレイヤー0（人間）が勝利した場合のみリザルト処理
	# call_deferredで次フレームに実行（シグナル経由のawait問題回避）
	if player_id == 0:
		_start_victory_result.call_deferred()
	else:
		# CPU勝利 = プレイヤー敗北
		_start_defeat_result.call_deferred("cpu_win")


# 勝利リザルト開始（call_deferred用ラッパー）
func _start_victory_result():
	_process_victory_result()


# 敗北リザルト開始（call_deferred用ラッパー）
func _start_defeat_result(reason: String = ""):
	_process_defeat_result(reason)


# プレイヤー敗北処理（降参・ターン制限）
func on_player_defeated(reason: String = ""):
	# 重複防止
	if _game_ended:
		print("[GameFlowManager] ゲームは既に終了しています")
		return
	_game_ended = true
	
	change_phase(GamePhase.SETUP)
	print("😢 プレイヤー敗北... (理由: %s)" % reason)
	await _process_defeat_result(reason)

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
	
	# CPUの場合はレートの低いカードから捨てる（デバッグモードでは無効化）
	var is_cpu = current_player.id < player_is_cpu.size() and player_is_cpu[current_player.id] and not debug_manual_control_all
	if is_cpu:
		if spell_phase_handler and spell_phase_handler.cpu_hand_utils:
			spell_phase_handler.cpu_hand_utils.discard_excess_cards_by_rate(current_player.id, GameConstants.MAX_HAND_SIZE)
		else:
			# フォールバック: 従来の方法
			card_system.discard_excess_cards_auto(current_player.id, GameConstants.MAX_HAND_SIZE)
		return
	
	# 人間プレイヤーの場合は手動で選択
	for i in range(cards_to_discard):
		await prompt_discard_card()

# カード捨て札をプロンプト
func prompt_discard_card():
	var current_player = player_system.get_current_player()
	
	# フィルターをリセット（グレーアウト解除）
	ui_manager.card_selection_filter = ""
	
	# カード選択UIを表示（discardモード）
	ui_manager.show_card_selection_ui_mode(current_player, "discard")
	
	# カード選択を待つ
	var card_index = await ui_manager.card_selected
	
	# カードを捨てる（理由: discard）
	card_system.discard_card(current_player.id, card_index, "discard")
	
	# UIを閉じる
	ui_manager.hide_card_selection_ui()
	
	# アクション指示を非表示
	if ui_manager.phase_display:
		ui_manager.phase_display.hide_action_prompt()

# === 敵地判定・通行料支払い ===

# 敵地判定・通行料支払い処理（end_turn()内で実行）
func check_and_pay_toll_on_enemy_land():
	# 現在のプレイヤーとタイル情報を取得
	var current_player_index = player_system.current_player_index
	if not board_system_3d or not board_system_3d.movement_controller:
		return
	
	var current_tile_index = board_system_3d.movement_controller.get_player_tile(current_player_index)
	if current_tile_index < 0:
		return
	
	var tile_info = board_system_3d.get_tile_info(current_tile_index)
	
	# 敵地判定：タイルの所有者が現在のプレイヤーではない場合
	if tile_info.get("owner", -1) == -1 or tile_info.get("owner", -1) == current_player_index:
		# 自分の土地または無所有タイル → 支払いなし
		return
	
	# 敵地にいる場合：通行料を計算・支払い
	var receiver_id = tile_info.get("owner", -1)
	var toll = board_system_3d.calculate_toll(current_tile_index)
	var toll_info = {"main_toll": toll, "bonus_toll": 0, "bonus_receiver_id": -1}
	
	# 通行料呪いがある場合、呪いシステムに全ての計算を委譲
	if spell_curse_toll:
		toll_info = spell_curse_toll.calculate_final_toll(current_tile_index, current_player_index, receiver_id, toll)
	
	var main_toll = toll_info.get("main_toll", 0)
	var bonus_toll = toll_info.get("bonus_toll", 0)
	var bonus_receiver_id = toll_info.get("bonus_receiver_id", -1)
	
	# 主通行料の支払い実行
	if receiver_id >= 0 and receiver_id < player_system.players.size():
		player_system.pay_toll(current_player_index, receiver_id, main_toll)
		print("[敵地支払い] 通行料 ", main_toll, "EP を支払いました (受取: プレイヤー", receiver_id + 1, ")")
		
		# 通行料支払いコメント表示
		if main_toll > 0:
			await _show_toll_comment(current_player_index, main_toll)
	
	# 副収入の支払い実行
	if bonus_toll > 0 and bonus_receiver_id >= 0 and bonus_receiver_id < player_system.players.size():
		player_system.pay_toll(current_player_index, bonus_receiver_id, bonus_toll)
		print("[副収入] 通行料 ", bonus_toll, "EP を支払いました (受取: プレイヤー", bonus_receiver_id + 1, ")")

## 通行料支払いコメント表示
func _show_toll_comment(payer_id: int, toll_amount: int):
	if not ui_manager or not ui_manager.global_comment_ui:
		return
	
	var player_name = "プレイヤー"
	if payer_id < player_system.players.size():
		var player = player_system.players[payer_id]
		if player:
			player_name = player.name
	
	var message = "%s が %dEP 奪われた" % [player_name, toll_amount]
	await ui_manager.global_comment_ui.show_and_wait(message, payer_id, true)


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
	if spell_magic:
		spell_magic.trigger_land_curse(tile_index, stopped_player_id)

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
		dominio_command_handler.dominio_command_closed.connect(_on_dominio_command_closed)
	
	# SpellCurseStatにシステム参照と通知UIを設定
	if spell_curse_stat:
		spell_curse_stat.set_systems(board_system_3d, player_system, card_system)
		if spell_phase_handler and spell_phase_handler.spell_cast_notification_ui:
			spell_curse_stat.set_notification_ui(spell_phase_handler.spell_cast_notification_ui)
	
	# SpellMagicに通知UIを設定
	if spell_magic and spell_phase_handler and spell_phase_handler.spell_cast_notification_ui:
		spell_magic.set_notification_ui(spell_phase_handler.spell_cast_notification_ui)
	
	# BankruptcyHandlerにTargetSelectionHelper参照を設定
	if bankruptcy_handler and target_selection_helper:
		bankruptcy_handler.target_selection_helper = target_selection_helper

# Phase 1-A: ドミニオコマンドが閉じられたときの処理
func _on_dominio_command_closed():
	
	# ターンエンド中またはターンエンドフェーズの場合は処理しない
	if is_ending_turn or current_phase == GamePhase.END_TURN:
		return
	
	# カメラをプレイヤーに戻す
	if board_system_3d and board_system_3d.camera_controller:
		board_system_3d.camera_controller.return_to_player()
	
	# カード選択UIの再初期化を次のフレームで実行（awaitを避ける）
	_reinitialize_card_selection.call_deferred()

# カード選択UIを再初期化（遅延実行用）
func _reinitialize_card_selection():
	if ui_manager:
		var current_player = player_system.get_current_player()
		if current_player:
			# TileActionProcessorのフラグを再設定（召喚フェーズに戻る）
			if board_system_3d and board_system_3d.tile_action_processor:
				board_system_3d.tile_action_processor.is_action_processing = true
			
			# カード選択UIを完全に再初期化（一度非表示にしてから再表示）
			ui_manager.hide_card_selection_ui()
			ui_manager.show_card_selection_ui(current_player)
			
			# ドミニオコマンドボタンも再表示（ドミニオを所有している場合のみ）
			if board_system_3d and board_system_3d._has_owned_lands(current_player.id):
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
	if board_system_3d and board_system_3d.movement_controller:
		board_system_3d.movement_controller.cpu_movement_evaluator = cpu_movement_evaluator
	
	# SpellPhaseHandlerに参照を渡す
	if spell_phase_handler:
		spell_phase_handler.cpu_movement_evaluator = cpu_movement_evaluator
		if spell_phase_handler.cpu_spell_ai:
			spell_phase_handler.cpu_spell_ai.set_movement_evaluator(cpu_movement_evaluator)

## 全分岐タイルの方向を切り替え
func _toggle_all_branch_tiles():
	if not board_system_3d or not board_system_3d.movement_controller:
		return
	
	var mc = board_system_3d.movement_controller
	if not mc.tile_nodes:
		return
	
	var toggled_count = 0
	for tile_index in mc.tile_nodes.keys():
		var tile = mc.tile_nodes[tile_index]
		if tile is BranchTile:
			tile.toggle_branch_direction()
			toggled_count += 1
	
	if toggled_count > 0:
		print("[GameFlowManager] 分岐タイル切替: %d 個" % toggled_count)

# ============================================
# カメラ制御
# ============================================

## フェーズに応じてカメラモードを更新
func _update_camera_mode(phase: GamePhase):
	if not board_system_3d or not board_system_3d.camera_controller:
		return
	
	var camera_ctrl = board_system_3d.camera_controller
	var is_my_turn = _is_current_player_human()
	
	if not is_my_turn:
		camera_ctrl.enable_follow_mode()
		return
	
	# ダイスロールとタイルアクションで手動モード
	match phase:
		GamePhase.DICE_ROLL, GamePhase.TILE_ACTION:
			camera_ctrl.enable_manual_mode()
		_:
			camera_ctrl.enable_follow_mode()

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
# ステージクリア・リザルト処理
# ============================================================

# リザルト画面への参照
var result_screen: ResultScreen = null

# 現在のステージデータ（クエストモード用）
var current_stage_data: Dictionary = {}

## ステージデータを設定（QuestGameから呼ばれる）
func set_stage_data(stage_data: Dictionary):
	current_stage_data = stage_data
	print("[GameFlowManager] ステージデータ設定: %s" % stage_data.get("id", "unknown"))


## リザルト画面を設定
func set_result_screen(screen: ResultScreen):
	result_screen = screen
	if result_screen:
		result_screen.result_confirmed.connect(_on_result_confirmed)


## 勝利時のリザルト処理
func _process_victory_result():
	var stage_id = current_stage_data.get("id", "")
	
	# クエストモードでない場合は簡易表示
	if stage_id.is_empty():
		if ui_manager:
			ui_manager.show_win_screen(0)
		return
	
	# ランク計算
	var rank = RankCalculator.calculate_rank(current_turn_number)
	
	# 初回クリア判定
	var is_first_clear = StageRecordManager.is_first_clear(stage_id)
	
	# 報酬計算
	var rewards = RewardCalculator.calculate_rewards(current_stage_data, rank, is_first_clear)
	print("[GameFlowManager] 報酬計算結果: %s" % rewards)
	
	# 記録更新
	var record_result = StageRecordManager.update_record(stage_id, rank, current_turn_number)
	
	# ゴールド付与
	if rewards.total > 0:
		GameData.add_gold(rewards.total)
		print("[GameFlowManager] ゴールド付与: %d" % rewards.total)
	else:
		print("[GameFlowManager] 報酬なし（total: %d）" % rewards.total)
	
	# リザルト画面表示
	print("[GameFlowManager] リザルト画面: %s" % ("あり" if result_screen else "なし"))
	
	if result_screen:
		var result_data = {
			"stage_id": stage_id,
			"stage_name": current_stage_data.get("name", ""),
			"turn_count": current_turn_number,
			"rank": rank,
			"is_first_clear": is_first_clear,
			"is_best_updated": record_result.is_best_updated,
			"best_rank": record_result.best_rank,
			"best_turn": record_result.best_turn,
			"rewards": rewards
		}
		
		# 勝利演出
		if ui_manager:
			await ui_manager.show_win_screen_async(0)
		
		print("[GameFlowManager] リザルト画面表示開始")
		result_screen.show_victory(result_data)
	else:
		# リザルト画面がない場合は従来の勝利演出のみ
		print("[GameFlowManager] リザルト画面なし、勝利演出のみ")
		if ui_manager:
			ui_manager.show_win_screen(0)
		
		# 一定時間後にステージセレクトへ
		await get_tree().create_timer(3.0).timeout
		_return_to_stage_select()


## 敗北時のリザルト処理
func _process_defeat_result(reason: String):
	var stage_id = current_stage_data.get("id", "")
	
	# 報酬計算（敗北は0G）
	var rewards = RewardCalculator.calculate_defeat_rewards()
	
	# リザルト画面表示
	if result_screen:
		var result_data = {
			"stage_id": stage_id,
			"stage_name": current_stage_data.get("name", ""),
			"turn_count": current_turn_number,
			"defeat_reason": reason,
			"rewards": rewards
		}
		
		# 敗北演出
		if ui_manager:
			await ui_manager.show_lose_screen_async(0)
		
		result_screen.show_defeat(result_data)
	else:
		# リザルト画面がない場合
		print("[GameFlowManager] リザルト画面なし、タイトルへ戻る")
		_return_to_stage_select()


## リザルト確認後
func _on_result_confirmed():
	print("[GameFlowManager] リザルト確認完了、ステージセレクトへ")
	_return_to_stage_select()


## ステージセレクトへ戻る
func _return_to_stage_select():
	print("[GameFlowManager] _return_to_stage_select 開始")
	
	# チュートリアルはメインメニューへ
	var stage_id = current_stage_data.get("id", "")
	if stage_id == "stage_tutorial":
		print("[GameFlowManager] チュートリアル終了、メインメニューへ遷移")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	# クエストモードならクエストセレクトへ
	elif not current_stage_data.is_empty():
		print("[GameFlowManager] クエストセレクトへ遷移")
		get_tree().change_scene_to_file("res://scenes/WorldStageSelect.tscn")
	else:
		# それ以外はメインメニューへ
		print("[GameFlowManager] メインメニューへ遷移")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## 規定ターン終了判定
func _check_turn_limit() -> bool:
	var max_turns = current_stage_data.get("max_turns", 0)
	if max_turns <= 0:
		return false  # 制限なし
	
	if current_turn_number > max_turns:
		print("[GameFlowManager] 規定ターン(%d)終了" % max_turns)
		
		# TEP比較で勝敗判定
		var player_tep = player_system.calculate_total_assets(0)
		var highest_cpu_tep = 0
		
		for i in range(1, player_system.players.size()):
			var cpu_tep = player_system.calculate_total_assets(i)
			if cpu_tep > highest_cpu_tep:
				highest_cpu_tep = cpu_tep
		
		print("[GameFlowManager] プレイヤーTEP: %d, 最高CPU TEP: %d" % [player_tep, highest_cpu_tep])
		
		if player_tep > highest_cpu_tep:
			# プレイヤー勝利
			on_player_won(0)
		else:
			# プレイヤー敗北（同値も敗北）
			on_player_defeated("turn_limit")
		
		return true
	
	return false
