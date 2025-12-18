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

func _ready():
	# CPUAIHandler初期化
	cpu_ai_handler = CPUAIHandler.new()
	add_child(cpu_ai_handler)
	
	# CPUハンドラーのシグナル接続
	cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided)
	cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided)
	cpu_ai_handler.level_up_decided.connect(_on_cpu_level_up_decided)
	
	# LapSystem初期化
	lap_system = LapSystem.new()
	lap_system.name = "LapSystem"
	add_child(lap_system)
	# LapSystemのシグナルを転送
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
	
	# LapSystemにplayer_systemとui_managerを設定
	if lap_system:
		lap_system.player_system = player_system
		lap_system.ui_manager = ui_manager
		lap_system._setup_ui()
	
	# MagicStoneSystemの初期化
	_setup_magic_stone_system(b_system)

## 魔法石システムの初期化
func _setup_magic_stone_system(board_system):
	magic_stone_system = MagicStoneSystem.new()
	magic_stone_system.initialize(board_system, player_system)
	
	# PlayerSystemに参照を設定
	if player_system:
		player_system.set_board_system(board_system)
		player_system.set_magic_stone_system(magic_stone_system)
	
	print("[MagicStoneSystem] 初期化完了")

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
	spell_draw.setup(card_system, player_system)
	spell_draw.set_board_system(board_system)
	print("[SpellDraw] 初期化完了")
	
	# SpellMagicの初期化
	spell_magic = SpellMagic.new()
	spell_magic.setup(player_system, board_system, self, null)  # spell_curseは後から設定
	print("[SpellMagic] 初期化完了")
	
	# SpellLandの初期化
	if board_system:
		# CreatureManagerはBoardSystem3D内の子ノードとして存在
		var creature_manager = board_system.get_node_or_null("CreatureManager")
		if creature_manager:
			spell_land = SpellLand.new()
			spell_land.setup(board_system, creature_manager, player_system, card_system)
			spell_land.set_game_flow_manager(self)
			print("[SpellLand] 初期化完了")
			
			# SpellCurseの初期化
			spell_curse = SpellCurse.new()
			spell_curse.setup(board_system, creature_manager, player_system, self)
			print("[SpellCurse] 初期化完了")
			
			# SpellMagicにSpellCurse参照を追加
			if spell_magic:
				spell_magic.spell_curse_ref = spell_curse
			
			# SpellDiceの初期化
			spell_dice = SpellDice.new()
			spell_dice.setup(player_system, spell_curse)
			print("[SpellDice] 初期化完了")
			
			# SpellCurseStatの初期化
			spell_curse_stat = SpellCurseStat.new()
			spell_curse_stat.setup(spell_curse, creature_manager)
			add_child(spell_curse_stat)
			print("[SpellCurseStat] 初期化完了")
			
			# SpellWorldCurseの初期化
			spell_world_curse = SpellWorldCurse.new()
			spell_world_curse.setup(spell_curse, self)
			add_child(spell_world_curse)
			print("[SpellWorldCurse] 初期化完了")
			
			# SpellPlayerMoveの初期化
			spell_player_move = SpellPlayerMove.new()
			spell_player_move.setup(board_system, player_system, self, spell_curse)
			# MovementControllerにも設定（方向選択権判定用）
			if board_system.movement_controller:
				board_system.movement_controller.spell_player_move = spell_player_move
			print("[SpellPlayerMove] 初期化完了")
		else:
			push_error("GameFlowManager: CreatureManagerが見つかりません")
	else:
		push_warning("GameFlowManager: BoardSystemが未設定のため、SpellLandは初期化されません")

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
		
		# 決定ボタンでサイコロを振るナビゲーション設定
		_setup_dice_phase_navigation()

## ダイスフェーズ用ナビゲーション設定（決定ボタンでサイコロを振る）
func _setup_dice_phase_navigation():
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
	
	board_system_3d.tile_action_processor.execute_summon(card_index)

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
	
	if do_upgrade:
		var current_tile = board_system_3d.movement_controller.get_player_tile(board_system_3d.current_player_index)
		var cost = board_system_3d.get_upgrade_cost(current_tile)
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
	
	# スペルフェーズ以外でスペルカードが選択された場合
	if card_type == "spell":
		return
	
	# アイテムフェーズ以外でアイテムカードが選択された場合
	if card_type == "item":
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
		
		# 全プレイヤーが1回ずつ行動したらラウンド数（ターン数）を増やす
		if board_system_3d.current_player_index == 0:
			current_turn_number += 1
			print("=== ラウンド", current_turn_number, "開始 ===")
			
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

# プレイヤー勝利処理
func on_player_won(player_id: int):
	var _player = player_system.players[player_id]  # 将来の拡張用
	change_phase(GamePhase.SETUP)
	
	# 勝利演出を表示
	if ui_manager:
		ui_manager.show_win_screen(player_id)
	
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
var land_command_handler: LandCommandHandler = null
var spell_phase_handler: SpellPhaseHandler = null
var item_phase_handler = null  # ItemPhaseHandler
var target_selection_helper: TargetSelectionHelper = null  # タイル選択ヘルパー

# Phase 1-A: ハンドラーを初期化
func initialize_phase1a_systems():
	# TargetSelectionHelperを作成（他のハンドラーより先に）
	target_selection_helper = TargetSelectionHelper.new()
	add_child(target_selection_helper)
	target_selection_helper.initialize(board_system_3d, ui_manager, self)
	
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
	
	# SpellCurseStatにシステム参照と通知UIを設定
	if spell_curse_stat:
		spell_curse_stat.set_systems(board_system_3d, player_system, card_system)
		if spell_phase_handler.spell_cast_notification_ui:
			spell_curse_stat.set_notification_ui(spell_phase_handler.spell_cast_notification_ui)
	
	# SpellMagicに通知UIを設定
	if spell_magic and spell_phase_handler.spell_cast_notification_ui:
		spell_magic.set_notification_ui(spell_phase_handler.spell_cast_notification_ui)
	
	# デバッグ: 密命カードを一時的に無効化（テスト用）
	spell_phase_handler.debug_disable_secret_cards = true
	
	# ItemPhaseHandlerを作成
	var ItemPhaseHandlerClass = load("res://scripts/game_flow/item_phase_handler.gd")
	if ItemPhaseHandlerClass:
		item_phase_handler = ItemPhaseHandlerClass.new()
		add_child(item_phase_handler)
		item_phase_handler.initialize(ui_manager, self, card_system, player_system, battle_system)

# Phase 1-A: 領地コマンドが閉じられたときの処理
func _on_land_command_closed():
	
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
	if land_command_handler:
		print("[Phase 1-A] 領地コマンド状態: ", land_command_handler.get_current_state())

# ============================================
# ターン数取得
# ============================================

func get_current_turn() -> int:
	return current_turn_number

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
	
	# スペルフェーズと召喚フェーズ（TILE_ACTION）で手動モード
	match phase:
		GamePhase.TILE_ACTION:
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
