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
const LandCommandHandlerClass = preload("res://scripts/game_flow/land_command_handler.gd")

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
var player_buff_system: PlayerBuffSystem
var ui_manager: UIManager
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem

# スペル効果システム
var spell_draw: SpellDraw
var spell_magic: SpellMagic
var spell_land: SpellLand
var spell_curse: SpellCurse
var spell_curse_toll: SpellCurseToll
var spell_dice: SpellDice
var spell_curse_stat: SpellCurseStat

# ターン終了制御用フラグ（BUG-000対策）
var is_ending_turn = false

# 周回管理システム
var player_lap_state = {}  # プレイヤーごとの周回状態
signal lap_completed(player_id: int)

# ゲーム統計データ（破壊カウンター）
var game_stats = {
	"total_creatures_destroyed": 0  # 1ゲーム内の累計破壊数
}

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
		
		# MovementControllerにgame_flow_managerを設定
		if board_system_3d.movement_controller:
			board_system_3d.movement_controller.game_flow_manager = self
		
		# CheckpointTileのシグナルを接続
		_connect_checkpoint_signals()
	
	# 周回状態を初期化
	_initialize_lap_state(cpu_settings.size())

# システム参照を設定
func setup_systems(p_system, c_system, b_system, s_system, ui_system, 
					bt_system = null, st_system = null):
	player_system = p_system
	card_system = c_system
	player_buff_system = s_system
	ui_manager = ui_system
	battle_system = bt_system
	special_tile_system = st_system
	
	# スペル効果システムの初期化
	_setup_spell_systems(b_system)
	
	# UIManagerに自身の参照を渡す
	if ui_manager:
		ui_manager.game_flow_manager_ref = self
	
	# BattleSystemに自身の参照を渡す
	if battle_system:
		battle_system.game_flow_manager_ref = self
	
	# CPU AIハンドラー設定
	if cpu_ai_handler:
		cpu_ai_handler.setup_systems(c_system, b_system, p_system, bt_system, s_system)

## スペル効果システムの初期化
func _setup_spell_systems(board_system):
	# 必要な参照の確認
	if not card_system:
		push_error("GameFlowManager: CardSystemが初期化されていません")
		return
	
	if not player_system:
		push_error("GameFlowManager: PlayerSystemが初期化されていません")
		return
	
	# SpellDrawの初期化
	spell_draw = SpellDraw.new()
	spell_draw.setup(card_system)
	print("[SpellDraw] 初期化完了")
	
	# SpellMagicの初期化
	spell_magic = SpellMagic.new()
	spell_magic.setup(player_system)
	print("[SpellMagic] 初期化完了")
	
	# SpellLandの初期化
	if board_system:
		# CreatureManagerはBoardSystem3D内の子ノードとして存在
		var creature_manager = board_system.get_node_or_null("CreatureManager")
		if creature_manager:
			spell_land = SpellLand.new()
			spell_land.setup(board_system, creature_manager, player_system, card_system)
			print("[SpellLand] 初期化完了")
			
			# SpellCurseの初期化
			spell_curse = SpellCurse.new()
			spell_curse.setup(board_system, creature_manager, player_system, self)
			print("[SpellCurse] 初期化完了")
			
			# SpellDiceの初期化
			spell_dice = SpellDice.new()
			spell_dice.setup(player_system, spell_curse)
			print("[SpellDice] 初期化完了")
			
			# SpellCurseStatの初期化
			spell_curse_stat = SpellCurseStat.new()
			spell_curse_stat.setup(spell_curse, creature_manager)
			add_child(spell_curse_stat)
			print("[SpellCurseStat] 初期化完了")
		else:
			push_error("GameFlowManager: CreatureManagerが見つかりません")
	else:
		push_warning("GameFlowManager: BoardSystemが未設定のため、SpellLandは初期化されません")

# ゲーム開始
func start_game():
	print("=== ゲーム開始 ===")
	
	# ゲーム統計の初期化
	game_stats["total_creatures_destroyed"] = 0
	
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()
	start_turn()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	
	# Phase 1-A: ターン開始時は領地コマンドボタンを隠す
	if ui_manager:
		ui_manager.hide_land_command_button()
	
	# カードドロー処理（常に1枚引く）
	var drawn = spell_draw.draw_one(current_player.id)
	if not drawn.is_empty() and current_player.id == 0:
		await get_tree().create_timer(0.1).timeout
	
	# UI更新
	ui_manager.update_player_info_panels()
	
	# スペルフェーズを開始
	if spell_phase_handler:
		spell_phase_handler.start_spell_phase(current_player.id)
		# スペルフェーズ完了を待つ
		await spell_phase_handler.spell_phase_completed
	
	# CPUターンの場合（デバッグモードでは無効化可能）
	var is_cpu_turn = current_player.id < player_is_cpu.size() and player_is_cpu[current_player.id] and not debug_manual_control_all
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
	# スペルフェーズ中の場合は、スペルを使わずにダイスロールに進む
	if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
		spell_phase_handler.pass_spell()
		# フェーズ完了を待つ必要はない（pass_spellが即座に完了する）
	
	if current_phase != GamePhase.DICE_ROLL:
		return
	
	ui_manager.set_dice_button_enabled(false)
	change_phase(GamePhase.MOVING)
	
	# 複数ダイスロールの判定
	var total_dice = 0
	var roll_count = 1
	
	if spell_dice and spell_dice.needs_multi_roll(player_system.current_player_index):
		roll_count = spell_dice.get_multi_roll_count(player_system.current_player_index)
		print("[複数ダイス] ", roll_count, "回振ります")
	
	# ダイスを指定回数振る
	for i in range(roll_count):
		var dice_value = player_system.roll_dice()
		
		# 呪いによるダイス変更を適用（dice_multi以外）
		if spell_dice:
			dice_value = spell_dice.get_modified_dice_value(player_system.current_player_index, dice_value)
		
		var modified = player_buff_system.modify_dice_roll(dice_value, player_system.current_player_index)
		total_dice += modified
		
		# 各ダイスの結果を表示
		if roll_count > 1:
			print("[ダイス", i + 1, "/", roll_count, "] ", modified)
			emit_signal("dice_rolled", modified)
			await get_tree().create_timer(0.8).timeout
		else:
			# 通常の1回のみのダイス
			emit_signal("dice_rolled", modified)
	
	var modified_dice = total_dice
	
	# ダイスロール後の魔力付与（チャージステップなど）
	if spell_dice:
		spell_dice.process_magic_grant(player_system.current_player_index, ui_manager)
		if spell_dice.should_grant_magic(player_system.current_player_index):
			await get_tree().create_timer(1.0).timeout
	
	# 複数ダイスの場合は合計を表示
	if roll_count > 1:
		print("[ダイス合計] ", modified_dice)
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "合計: " + str(modified_dice) + "マス移動"
		await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(1.0).timeout
	
	var current_player = player_system.get_current_player()
	
	# 3D移動
	if board_system_3d:
		ui_manager.phase_label.text = "移動中..."
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
	# アイテムフェーズ中は、ItemPhaseHandlerのcurrent_player_idを使用
	var target_player_id = player_system.get_current_player().id
	if item_phase_handler and item_phase_handler.is_item_phase_active():
		target_player_id = item_phase_handler.current_player_id
	
	var hand = card_system.get_all_cards_for_player(target_player_id)
	
	if card_index >= hand.size():
		return
	
	var card = hand[card_index]
	var card_type = card.get("type", "")
	
	# スペルフェーズ中かチェック
	if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
		# スペルカードのみ使用可能
		if card_type == "spell":
			spell_phase_handler.use_spell(card)
			return
		else:
			return
	
	# アイテムフェーズ中かチェック
	if item_phase_handler and item_phase_handler.is_item_phase_active():
		# アイテムカードまたは援護対象クリーチャーが使用可能
		if card_type == "item":
			item_phase_handler.use_item(card)
			return
		elif card_type == "creature":
			# 援護スキルがある場合のみクリーチャーを使用可能
			if item_phase_handler.has_assist_skill():
				var assist_elements = item_phase_handler.get_assist_target_elements()
				var card_element = card.get("element", "")
				# 対象属性かチェック
				if "all" in assist_elements or card_element in assist_elements:
					item_phase_handler.use_item(card)
					return
			return
		else:
			return
	
	# スペルフェーズ以外でスペルカードが選択された場合
	if card_type == "spell":
		return
	
	# アイテムフェーズ以外でアイテムカードが選択された場合
	if card_type == "item":
		return
	
	# peace 呪いをチェック（戦闘不可）
	if card_type == "creature" and spell_curse_toll:
		# 現在位置のタイルを取得
		var current_tile_index = board_system_3d.movement_controller.get_player_tile(player_system.current_player_index) if board_system_3d and board_system_3d.movement_controller else -1
		if current_tile_index >= 0 and spell_curse_toll.is_invasion_disabled(current_tile_index):
			print("[peace呪い] 戦闘不可: この領地では戦闘できません")
			if ui_manager and ui_manager.phase_label:
				ui_manager.phase_label.text = "peace の呪いにより戦闘できません"
			return
	
	# Phase 1-D: 交換モードチェック
	if land_command_handler and land_command_handler._swap_mode:
		land_command_handler.on_card_selected_for_swap(card_index)
	elif board_system_3d:
		board_system_3d.on_card_selected(card_index)

func on_pass_button_pressed():
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
	
	# Phase 1-A: 領地コマンドを閉じる、カード選択UIとボタンを隠す
	if land_command_handler and land_command_handler.current_state != land_command_handler.State.CLOSED:
		land_command_handler.close_land_command()
	
	if ui_manager:
		ui_manager.hide_land_command_button()
		ui_manager.hide_card_selection_ui()
	
	var current_player = player_system.get_current_player()
	print("ターン終了: プレイヤー", current_player.id + 1)
	
	# 手札調整が必要かチェック
	await check_and_discard_excess_cards()
	
	# 敵地判定・通行料支払い実行
	await check_and_pay_toll_on_enemy_land()
	
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
		print("[敵地支払い] 通行料 ", main_toll, "G を支払いました (受取: プレイヤー", receiver_id + 1, ")")
	
	# 副収入の支払い実行
	if bonus_toll > 0 and bonus_receiver_id >= 0 and bonus_receiver_id < player_system.players.size():
		player_system.pay_toll(current_player_index, bonus_receiver_id, bonus_toll)
		print("[副収入] 通行料 ", bonus_toll, "G を支払いました (受取: プレイヤー", bonus_receiver_id + 1, ")")

# ============================================
# Phase 1-A: 新システム統合
# ============================================

# Phase 1-A用ハンドラー
var phase_manager: PhaseManager = null
var land_command_handler: LandCommandHandler = null
var spell_phase_handler: SpellPhaseHandler = null
var item_phase_handler = null  # ItemPhaseHandler

# Phase 1-A: ハンドラーを初期化
func initialize_phase1a_systems():
	# PhaseManagerを作成
	phase_manager = PhaseManager.new()
	add_child(phase_manager)
	phase_manager.phase_changed.connect(_on_phase_manager_phase_changed)
	
	# LandCommandHandlerを作成
	land_command_handler = LandCommandHandlerClass.new()
	add_child(land_command_handler)
	land_command_handler.initialize(ui_manager, board_system_3d, self, player_system)
	
	# land_command_closedシグナルを接続
	if land_command_handler.has_signal("land_command_closed"):
		land_command_handler.land_command_closed.connect(_on_land_command_closed)
	
	# SpellPhaseHandlerを作成
	spell_phase_handler = SpellPhaseHandler.new()
	add_child(spell_phase_handler)
	spell_phase_handler.initialize(ui_manager, self, card_system, player_system, board_system_3d)
	
	# デバッグ: 密命カードを一時的に無効化（テスト用）
	spell_phase_handler.debug_disable_secret_cards = true
	
	# ItemPhaseHandlerを作成
	var ItemPhaseHandlerClass = load("res://scripts/game_flow/item_phase_handler.gd")
	if ItemPhaseHandlerClass:
		item_phase_handler = ItemPhaseHandlerClass.new()
		add_child(item_phase_handler)
		item_phase_handler.initialize(ui_manager, self, card_system, player_system, battle_system)

# Phase 1-A: PhaseManagerのフェーズ変更を受信
func _on_phase_manager_phase_changed(_new_phase, _old_phase):
	pass

# Phase 1-A: 領地コマンドが閉じられたときの処理
func _on_land_command_closed():
	
	# ターンエンド中またはターンエンドフェーズの場合は、カード選択UIを再初期化しない
	if is_ending_turn or current_phase == GamePhase.END_TURN:
		return
	
	# カード選択UIの再初期化を次のフレームで実行（awaitを避ける）
	_reinitialize_card_selection.call_deferred()

# カード選択UIを再初期化（遅延実行用）
func _reinitialize_card_selection():
	if ui_manager:
		var current_player = player_system.get_current_player()
		if current_player:
			# カード選択UIを完全に再初期化（一度非表示にしてから再表示）
			ui_manager.hide_card_selection_ui()
			ui_manager.show_card_selection_ui(current_player)
			
			# 領地コマンドボタンも再表示
			ui_manager.show_land_command_button()
			

# Phase 1-A: 領地コマンドを開く
func open_land_command():
	if not land_command_handler:
		return
	
	var current_player = player_system.get_current_player()
	if current_player:
		land_command_handler.open_land_command(current_player.id)

# Phase 1-A: デバッグ情報表示
func debug_print_phase1a_status():
	if phase_manager:
		print("[Phase 1-A] 現在フェーズ: ", phase_manager.get_current_phase_name())
	if land_command_handler:
		print("[Phase 1-A] 領地コマンド状態: ", land_command_handler.get_current_state())

# ============================================
# 周回管理システム
# ============================================

# 周回状態を初期化
func _initialize_lap_state(player_count: int):
	player_lap_state.clear()
	for i in range(player_count):
		player_lap_state[i] = {
			"N": false,
			"S": false
		}

# CheckpointTileのシグナルを接続
func _connect_checkpoint_signals():
	if not board_system_3d or not board_system_3d.tile_nodes:
		return
	
	# 少し待ってからシグナル接続（CheckpointTileの_ready()を待つ）
	await get_tree().process_frame
	await get_tree().process_frame
	
	for tile_index in board_system_3d.tile_nodes.keys():
		var tile = board_system_3d.tile_nodes[tile_index]
		if tile and is_instance_valid(tile):
			if tile.has_signal("checkpoint_passed"):
				if not tile.checkpoint_passed.is_connected(_on_checkpoint_passed):
					tile.checkpoint_passed.connect(_on_checkpoint_passed)
			elif tile.get("tile_type") == "checkpoint":
				pass  # チェックポイントタイルだがシグナルがない

# チェックポイント通過イベント
func _on_checkpoint_passed(player_id: int, checkpoint_type: String):
	if not player_lap_state.has(player_id):
		return
	
	# チェックポイントフラグを立てる
	player_lap_state[player_id][checkpoint_type] = true
	
	# N + S 両方揃ったか確認
	if player_lap_state[player_id]["N"] and player_lap_state[player_id]["S"]:
		_complete_lap(player_id)

# 周回完了処理
func _complete_lap(player_id: int):
	
	# フラグをリセット（game_startedは維持）
	player_lap_state[player_id]["N"] = false
	player_lap_state[player_id]["S"] = false
	
	# 全クリーチャーに周回ボーナスを適用
	if board_system_3d:
		_apply_lap_bonus_to_all_creatures(player_id)
	
	# シグナル発行
	emit_signal("lap_completed", player_id)

# 全クリーチャーに周回ボーナスを適用
func _apply_lap_bonus_to_all_creatures(player_id: int):
	var tiles = board_system_3d.get_player_tiles(player_id)
	
	for tile in tiles:
		if tile.creature_data:
			_apply_lap_bonus_to_creature(tile.creature_data)

# クリーチャーに周回ボーナスを適用
func _apply_lap_bonus_to_creature(creature_data: Dictionary):
	if not creature_data.has("ability_parsed"):
		return
	
	var effects = creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "per_lap_permanent_bonus":
			_apply_per_lap_bonus(creature_data, effect)

# 周回ごと永続ボーナスを適用
func _apply_per_lap_bonus(creature_data: Dictionary, effect: Dictionary):
	var stat = effect.get("stat", "ap")
	var value = effect.get("value", 10)
	
	# 周回カウントを増加
	if not creature_data.has("map_lap_count"):
		creature_data["map_lap_count"] = 0
	creature_data["map_lap_count"] += 1
	
	# base_up_hp/ap に加算
	if stat == "ap":
		if not creature_data.has("base_up_ap"):
			creature_data["base_up_ap"] = 0
		creature_data["base_up_ap"] += value
		print("[Lap Bonus] ", creature_data.get("name", ""), " ST+", value, 
			  " (周回", creature_data["map_lap_count"], "回目)")
	
	elif stat == "max_hp":
		if not creature_data.has("base_up_hp"):
			creature_data["base_up_hp"] = 0
		
		# リセット条件チェック（モスタイタン用）
		var reset_condition = effect.get("reset_condition")
		if reset_condition:
			var reset_max_hp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
			var check = reset_condition.get("max_hp_check", {})
			var operator = check.get("operator", ">=")
			var threshold = check.get("value", 80)
			
			# MHP + 新しいボーナスがしきい値を超えるかチェック
			if operator == ">=" and (reset_max_hp + value) >= threshold:
				var reset_to = check.get("reset_to", 0)
				var reset_base_hp = creature_data.get("hp", 0)
				creature_data["base_up_hp"] = reset_to - reset_base_hp
				
				# 現在HPもリセット値に
				creature_data["current_hp"] = reset_to
				
				print("[Lap Bonus] ", creature_data.get("name", ""), 
					  " MHPリセット → ", reset_to, " HP:", reset_to)
				return
		
		creature_data["base_up_hp"] += value
		
		# 現在HPも回復（増えたMHP分だけ）
		var base_hp = creature_data.get("hp", 0)
		var base_up_hp = creature_data["base_up_hp"]
		var max_hp = base_hp + base_up_hp
		var current_hp = creature_data.get("current_hp", max_hp)
		
		# HP回復（MHPを超えない）
		var new_hp = min(current_hp + value, max_hp)
		creature_data["current_hp"] = new_hp
		
		print("[Lap Bonus] ", creature_data.get("name", ""), 
			  " MHP+", value, " HP+", value,
			  " (周回", creature_data["map_lap_count"], "回目)",
			  " HP:", current_hp, "→", new_hp, " / MHP:", max_hp)

# ========================================
# 破壊カウンター管理
# ========================================

# クリーチャー破壊時に呼ばれる
func on_creature_destroyed():
	game_stats["total_creatures_destroyed"] += 1
	print("[破壊カウント] 累計: ", game_stats["total_creatures_destroyed"])

# 破壊カウント取得
func get_destroy_count() -> int:
	return game_stats["total_creatures_destroyed"]

# 破壊カウントリセット（スペル用）
func reset_destroy_count():
	game_stats["total_creatures_destroyed"] = 0
	print("[破壊カウント] リセットしました")
