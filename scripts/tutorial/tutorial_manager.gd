# チュートリアルの進行、ガイドメッセージ表示、操作制限を管理
extends Node

class_name TutorialManager

## チュートリアルの進行を管理するクラス
## JSONファイルからステップデータを読み込み、ExplanationModeを使用して表示を行う

# =============================================================================
# シグナル
# =============================================================================

signal tutorial_started
signal tutorial_ended
signal step_changed(step_id: int)

# =============================================================================
# 定数
# =============================================================================

const DEFAULT_TUTORIAL_PATH = "res://data/tutorial/tutorial_stage1.json"

# =============================================================================
# チュートリアル状態
# =============================================================================

var is_active: bool = false
var current_step: int = 0
var current_turn: int = 1
var tutorial_data_path: String = DEFAULT_TUTORIAL_PATH

# =============================================================================
# 設定データ（JSONから読み込み）
# =============================================================================

var player_initial_hand: Array = []
var cpu_initial_hand: Array = []
var player_deck: Array = []
var cpu_deck: Array = []
var dice_sequence: Array = []
var cpu_dice_sequence: Array = []
var enable_draw: bool = false  # ドロー有効化フラグ
var steps: Array = []

# =============================================================================
# システム参照
# =============================================================================

var game_flow_manager = null
var ui_manager = null
var debug_controller = null
var card_system = null
var board_system_3d = null

# === 直接参照（GFM経由を廃止） ===
var spell_phase_handler = null
var lap_system = null  # LapSystem: 周回管理（シグナル接続用）
var player_system = null  # PlayerSystem: プレイヤー情報
var dominio_command_handler = null  # DominioCommandHandler: ドミニオコマンド

# =============================================================================
# チュートリアル専用UI
# =============================================================================

var tutorial_popup = null
var tutorial_overlay = null
var explanation_mode: ExplanationMode = null

# =============================================================================
# 内部状態
# =============================================================================

var _last_player_id: int = -1
var _is_showing_step: bool = false  # ステップ表示中フラグ（再入防止）

# チュートリアル用カード選択制限
var allowed_card_ids: Array = []  # 空なら制限なし

# チュートリアル用ターゲット選択制限
var allowed_target_tile_condition: String = ""  # 空なら制限なし（条件ベース）

# チュートリアル用アクション選択制限
var allowed_action: String = ""  # 空なら制限なし

# チュートリアル用レベル選択制限
var allowed_level: int = -1  # -1なら制限なし

# =============================================================================
# 初期化
# =============================================================================

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tutorial_data()

## チュートリアルデータパスを設定
func set_tutorial_path(path: String):
	tutorial_data_path = path
	_load_tutorial_data()

## JSONからチュートリアルデータを読み込む
func _load_tutorial_data():
	var file = FileAccess.open(tutorial_data_path, FileAccess.READ)
	if not file:
		push_error("[TutorialManager] チュートリアルデータを読み込めません: %s" % tutorial_data_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[TutorialManager] JSONパースエラー: %s" % json.get_error_message())
		return
	
	var data = json.data
	
	# 設定データを読み込み
	var config = data.get("config", {})
	player_initial_hand = config.get("player_initial_hand", [210, 210, 1073])
	cpu_initial_hand = config.get("cpu_initial_hand", [210, 210])
	player_deck = config.get("player_deck", [])
	cpu_deck = config.get("cpu_deck", [])
	dice_sequence = config.get("dice_sequence", [3, 6, 5])
	cpu_dice_sequence = config.get("cpu_dice_sequence", [])
	enable_draw = config.get("enable_draw", false)  # ドロー有効化フラグ
	
	# ステップデータを読み込み
	steps = data.get("steps", [])
	
	print("[TutorialManager] チュートリアルデータ読み込み完了: %d ステップ" % steps.size())

# =============================================================================
# システム初期化
# =============================================================================

## system_managerから初期化
func initialize_with_systems(system_manager):
	if not system_manager:
		print("[TutorialManager] ERROR: system_managerがnull")
		return

	game_flow_manager = system_manager.game_flow_manager
	ui_manager = system_manager.ui_manager
	debug_controller = system_manager.debug_controller
	card_system = system_manager.card_system
	board_system_3d = system_manager.board_system_3d

	# 直接参照を設定（チェーンアクセス解消）
	if game_flow_manager:
		if game_flow_manager.lap_system:
			lap_system = game_flow_manager.lap_system
		if game_flow_manager.player_system:
			player_system = game_flow_manager.player_system
		if game_flow_manager.dominio_command_handler:
			dominio_command_handler = game_flow_manager.dominio_command_handler

	_setup_ui()
	_setup_explanation_mode()
	_connect_signals()

## ExplanationModeをセットアップ
func _setup_explanation_mode():
	explanation_mode = ExplanationMode.new()
	explanation_mode.name = "ExplanationMode"
	add_child(explanation_mode)
	explanation_mode.setup(ui_manager, board_system_3d)

## チュートリアル専用UIをセットアップ
func _setup_ui():
	# TutorialPopup
	var TutorialPopupClass = load("res://scripts/tutorial/tutorial_popup.gd")
	tutorial_popup = TutorialPopupClass.new()
	tutorial_popup.name = "TutorialPopup"
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TutorialCanvasLayer"
	canvas_layer.layer = 200  # ゲーム内ポップアップより前面に表示
	canvas_layer.add_child(tutorial_popup)
	add_child(canvas_layer)
	
	# TutorialOverlay
	var TutorialOverlayClass = load("res://scripts/tutorial/tutorial_overlay.gd")
	tutorial_overlay = TutorialOverlayClass.new()
	tutorial_overlay.name = "TutorialOverlay"
	
	# GlobalActionButtonsへの参照を設定
	if ui_manager and ui_manager.global_action_buttons:
		tutorial_overlay.set_global_action_buttons(ui_manager.global_action_buttons)
	
	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.name = "TutorialOverlayCanvas"
	overlay_canvas.layer = 99
	overlay_canvas.add_child(tutorial_overlay)
	add_child(overlay_canvas)

# =============================================================================
# シグナル接続
# =============================================================================

## ゲームシステムのシグナルを接続
func _connect_signals():
	# ターン開始・ダイス
	if game_flow_manager:
		game_flow_manager.turn_started.connect(_on_turn_started)
		game_flow_manager.dice_rolled.connect(_on_dice_rolled)
	
	# 移動完了（BoardSystem3Dの転送シグナル経由）
	if board_system_3d:
		board_system_3d.movement_completed.connect(_on_movement_completed)
	
	# チェックポイント通過（直接参照経由）
	if lap_system:
		lap_system.checkpoint_signal_obtained.connect(_on_checkpoint_passed)
	
	# バトル画面イントロ完了
	call_deferred("_connect_battle_signals")
	
	# カード選択（遅延接続）
	call_deferred("_connect_card_signals")
	
	# アクション完了（遅延接続）
	call_deferred("_connect_action_signals")

func _connect_card_signals():
	if ui_manager and ui_manager.card_selection_ui:
		var csu = ui_manager.card_selection_ui
		if not csu.card_selected.is_connected(_on_card_selected):
			csu.card_selected.connect(_on_card_selected)
		if csu.has_signal("card_info_shown") and not csu.card_info_shown.is_connected(_on_card_info_shown):
			csu.card_info_shown.connect(_on_card_info_shown)

func _connect_action_signals():
	if board_system_3d and board_system_3d.tile_action_processor:
		var tap = board_system_3d.tile_action_processor
		if not tap.action_completed.is_connected(_on_action_completed):
			tap.action_completed.connect(_on_action_completed)
	
	# スペルフェーズ完了シグナル
	if spell_phase_handler:
		if not spell_phase_handler.spell_phase_completed.is_connected(_on_spell_phase_completed):
			spell_phase_handler.spell_phase_completed.connect(_on_spell_phase_completed)
	
	# アイテム使用シグナル（バトル時）
	if game_flow_manager and game_flow_manager.item_phase_handler:
		var iph = game_flow_manager.item_phase_handler
		if not iph.item_used.is_connected(_on_item_used):
			iph.item_used.connect(_on_item_used)
	
	# 破産完了シグナル
	if game_flow_manager and game_flow_manager.bankruptcy_handler:
		var bh = game_flow_manager.bankruptcy_handler
		if not bh.bankruptcy_completed.is_connected(_on_bankruptcy_completed):
			bh.bankruptcy_completed.connect(_on_bankruptcy_completed)
	
	# ドミニオコマンド関連シグナル（直接参照経由）
	if dominio_command_handler:
		var dch = dominio_command_handler
		if not dch.land_selected.is_connected(_on_dominio_land_selected):
			dch.land_selected.connect(_on_dominio_land_selected)
		if not dch.dominio_command_opened.is_connected(_on_dominio_command_opened):
			dch.dominio_command_opened.connect(_on_dominio_command_opened)
		if not dch.action_selected.is_connected(_on_dominio_action_selected):
			dch.action_selected.connect(_on_dominio_action_selected)
	
	# レベルアップ選択シグナル
	if ui_manager and ui_manager.has_signal("level_up_selected"):
		if not ui_manager.level_up_selected.is_connected(_on_level_up_selected):
			ui_manager.level_up_selected.connect(_on_level_up_selected)
	
	# アルカナアーツ関連シグナル
	if spell_phase_handler and spell_phase_handler.spell_mystic_arts:
		var sma = spell_phase_handler.spell_mystic_arts
		if not sma.target_selection_requested.is_connected(_on_mystic_target_selection_requested):
			sma.target_selection_requested.connect(_on_mystic_target_selection_requested)
		if not sma.mystic_phase_completed.is_connected(_on_mystic_phase_completed):
			sma.mystic_phase_completed.connect(_on_mystic_phase_completed)
	
	# スペシャルボタン押下シグナル
	if ui_manager and ui_manager.global_action_buttons:
		var gab = ui_manager.global_action_buttons
		if not gab.special_button_pressed.is_connected(_on_special_button_pressed):
			gab.special_button_pressed.connect(_on_special_button_pressed)

func _connect_battle_signals():
	# BattleScreenManagerへの参照を取得
	if board_system_3d:
		var battle_screen_manager = board_system_3d.get_battle_screen_manager()
		if battle_screen_manager:
			if not battle_screen_manager.intro_completed.is_connected(_on_battle_intro_completed):
				battle_screen_manager.intro_completed.connect(_on_battle_intro_completed)
			if not battle_screen_manager.battle_screen_closed.is_connected(_on_battle_screen_closed):
				battle_screen_manager.battle_screen_closed.connect(_on_battle_screen_closed)

# =============================================================================
# シグナルハンドラ
# =============================================================================

func _on_turn_started(player_id: int):
	if not is_active:
		return
	
	# CPUターン(1)からプレイヤーターン(0)に戻った時 = 新しいターン
	if _last_player_id == 1 and player_id == 0:
		advance_turn()
		# cpu_turn*_complete または cpu_summon_complete フェーズなら次のプレイヤーターンステップへ
		var phase = get_current_step().get("phase", "")
		if phase.begins_with("cpu_") and phase.ends_with("_complete"):
			advance_step()
	
	# ダイスを設定（プレイヤーIDに応じて）
	set_dice_for_current_turn(player_id)
	
	# CPUターン開始時（battle_ap_explain後）- battle_winへ進む
	# battle_winはwait_for_clickなので、クリック後に自動でcpu_turn_start2へ進む
	if player_id == 1:
		var phase = get_current_step().get("phase", "")
		if phase == "battle_ap_explain":
			advance_step()  # battle_winへ
	
	_last_player_id = player_id

func _on_dice_rolled(_value: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# turn2_startやturn3_startの場合はdiceを経由してcheckpointへ
	if phase in ["turn2_start", "turn3_start"]:
		advance_step()  # diceへ
	# dice_promptフェーズ → diceへ進む
	# dice_prompt（番号なし）は分岐選択があるのでdirectionへも進む
	# dice_prompt2以降は分岐なしなので移動完了後に次へ進む
	elif phase.begins_with("dice_prompt"):
		_exit_explanation_mode_if_active()
		advance_step()  # diceへ
		# dice_prompt（番号なし、最初のダイス）の場合のみdirectionへ進む
		if phase == "dice_prompt":
			advance_step()  # directionへ
	# diceフェーズでは次のフェーズがcheckpointなら待機、そうでなければ進む
	elif phase.begins_with("dice") and not phase.begins_with("dice_prompt"):
		var next_step_index = current_step + 1
		if next_step_index < steps.size():
			var next_phase = steps[next_step_index].get("phase", "")
			if not next_phase.begins_with("checkpoint"):
				_exit_explanation_mode_if_active()
				advance_step()

func _on_movement_completed(player_id: int, _final_tile: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	if player_id == 0:
		# directionで始まるフェーズ（direction, direction2, direction4, etc.）
		if phase.begins_with("direction"):
			_exit_explanation_mode_if_active()
			advance_step()
		# diceフェーズ（dice2, dice3など、dice_prompt以外）で移動完了 → 次へ
		elif phase.begins_with("dice") and not phase.begins_with("dice_prompt"):
			_exit_explanation_mode_if_active()
			advance_step()
		# 移動完了待ちフェーズなら次へ（敵ドミニオに到着）
		elif phase.begins_with("wait_movement"):
			_exit_explanation_mode_if_active()
			advance_step()
	# CPU移動完了時（プレイヤーのドミニオに止まった）
	elif player_id == 1:
		if phase == "cpu_turn_start2":
			_exit_explanation_mode_if_active()
			advance_step()  # cpu_battle_explainへ

func _on_card_info_shown(_card_index: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# summon_selectで始まるフェーズ（summon_select, summon_sakuya_select, summon_ogre3_select, etc.）
	if phase.begins_with("summon") and phase.ends_with("_select"):
		_exit_explanation_mode_if_active()
		advance_step()
	# アイテムカード1回目タップ
	elif phase == "battle_item_prompt":
		_exit_explanation_mode_if_active()
		advance_step()  # battle_item_infoへ
	# スペルカード1回目タップ
	elif phase.ends_with("_select") and ("spell" in phase or "vitality" in phase or "greed" in phase or "holyword" in phase or "earth_shift" in phase):
		_exit_explanation_mode_if_active()
		advance_step()

func _on_card_selected(_card_index: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# summon_infoフェーズ中にカード選択 → summon_confirmをスキップしてsummon_executeへ
	if phase == "summon_info":
		_exit_explanation_mode_if_active()
		advance_step()  # summon_confirmへ
		advance_step()  # summon_executeへ
	# summon_confirmで始まるフェーズ（summon_confirm, summon_sakuya_confirm, etc.）
	elif phase.begins_with("summon") and phase.ends_with("_confirm"):
		_exit_explanation_mode_if_active()
		advance_step()
	# スペルカード確定（2回目タップ）
	elif phase.ends_with("_confirm") and ("spell" in phase or "vitality" in phase or "greed" in phase or "holyword" in phase or "earth_shift" in phase):
		_exit_explanation_mode_if_active()
		advance_step()
	# バトルクリーチャー選択確定時（2回目タップ）
	elif phase.begins_with("battle") and phase.ends_with("_select"):
		_exit_explanation_mode_if_active()
		advance_step()
	# アイテム選択確定時（2回目タップ）- battle_startへ進む
	elif phase == "battle_item_info":
		_exit_explanation_mode_if_active()
		advance_step()  # battle_startへ
	# 武器選択（1回目タップ）→ weapon_confirmへ
	elif phase.ends_with("_weapon_prompt"):
		_exit_explanation_mode_if_active()
		advance_step()
	# 武器選択確定（2回目タップ）→ battle_startへ
	elif phase.ends_with("_weapon_confirm"):
		_exit_explanation_mode_if_active()
		advance_step()

func _on_spell_phase_completed():
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# スペルターゲット選択フェーズならスペル完了フェーズへ進む
	# spell_target, vitality_target, greed_target など *_target フェーズ全般に対応
	if phase == "spell_target" or phase.ends_with("_target"):
		_exit_explanation_mode_if_active()
		advance_step()  # *_completeへ

func _on_item_used(_item_card: Dictionary):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# 武器選択フェーズならバトル開始フェーズへ進む
	if phase.ends_with("_weapon_prompt"):
		_exit_explanation_mode_if_active()
		advance_step()  # battle_startへ

func _on_bankruptcy_completed(player_id: int, was_reset: bool):
	if not is_active:
		return
	print("[TutorialManager] 破産完了シグナル: player=%d, was_reset=%s, phase=%s" % [player_id, was_reset, get_current_step().get("phase", "")])
	
	# CPUが破産した場合、破産関連フェーズを進める
	if player_id == 1:  # CPU
		var phase = get_current_step().get("phase", "")
		
		# cpu_toll_paidフェーズなら、リセット完了を待ってから進める
		if phase == "cpu_toll_paid" and was_reset:
			# 少し待ってから表示（移動アニメーション完了を待つ）
			await get_tree().create_timer(0.8).timeout
			_exit_explanation_mode_if_active()
			# 最後のwait_for_click（victory）まで進める
			while is_active:
				var step = get_current_step()
				if step.get("wait_for_click", false) or step.get("pause_game", false):
					break
				advance_step()

func _on_dominio_land_selected(_tile_index: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# レベルアップ土地選択フェーズなら次へ進む
	if phase == "levelup_select":
		_exit_explanation_mode_if_active()
		advance_step()

func _on_dominio_command_opened():
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# ドミニオコマンド説明フェーズならレベルアップ選択へ進む
	if phase == "dominion_command_explain":
		_exit_explanation_mode_if_active()
		advance_step()

func _on_dominio_action_selected(_action_type: String):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# アクション選択フェーズなら次へ進む
	if phase == "action_select":
		_exit_explanation_mode_if_active()
		advance_step()

func _on_level_up_selected(_target_level: int, _cost: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# レベル選択フェーズなら次へ進む
	if phase == "level_select":
		_exit_explanation_mode_if_active()
		advance_step()

func _on_special_button_pressed():
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# アルカナアーツ説明フェーズなら選択へ進む
	if phase == "mystic_arts_explain":
		_exit_explanation_mode_if_active()
		advance_step()
	# ドミニオコマンド説明フェーズなら選択へ進む
	elif phase == "dominion_command_explain":
		_exit_explanation_mode_if_active()
		advance_step()

func _on_mystic_target_selection_requested(_targets: Array):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# アルカナアーツ選択フェーズなら対象選択へ進む
	if phase == "mystic_arts_select":
		_exit_explanation_mode_if_active()
		advance_step()

func _on_mystic_phase_completed():
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# アルカナアーツ対象選択フェーズなら次へ進む
	if phase == "mystic_arts_target":
		_exit_explanation_mode_if_active()
		advance_step()

func _on_action_completed():
	if not is_active:
		return
	# phaseは最初に取得して保持（awaitで変わる可能性があるため）
	var initial_phase = get_current_step().get("phase", "")
	
	# プレイヤーの召喚関連フェーズなら_completeステップまで進む
	# summon_select, summon_confirm, summon_execute, summon_sakuya_select, etc.
	if initial_phase.begins_with("summon"):
		# 次のwait_for_click: trueまたはpause_game: trueのステップまで進める
		while is_active:
			var step = get_current_step()
			if step.get("wait_for_click", false) or step.get("pause_game", false):
				break
			advance_step()
		return
	
	# CPUターン中（cpu_turnで始まるフェーズ）なら_completeステップまで進む
	if initial_phase.begins_with("cpu_turn"):
		# cpu_turn*_completeステップまで進める（プレイヤーターンのステップには進まない）
		while is_active:
			var step = get_current_step()
			var phase = step.get("phase", "")
			# cpu_turn*_completeで停止
			if phase.begins_with("cpu_") and phase.ends_with("_complete"):
				break
			# wait_for_click/pause_gameでも停止（安全策）
			if step.get("wait_for_click", false) or step.get("pause_game", false):
				break
			advance_step()

func _on_checkpoint_passed(player_id: int, _checkpoint_type: String):
	if not is_active:
		return
	# プレイヤー0がチェックポイント通過時、diceフェーズならcheckpointへ
	if player_id == 0:
		var phase = get_current_step().get("phase", "")
		if phase == "dice":
			# 少し待ってからコメント表示（移動アニメーションがチェックポイントに到達するのを待つ）
			await get_tree().create_timer(0.15).timeout
			advance_step()  # checkpointへ


func _on_battle_intro_completed():
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# バトル開始フェーズならAP説明へ進む
	if phase == "battle_start":
		advance_step()  # battle_ap_explainへ

func _on_battle_screen_closed():
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# バトルAP説明フェーズならバトル勝利へ進む
	if phase == "battle_ap_explain":
		# コメントを消す
		if tutorial_popup:
			tutorial_popup.hide()
		# 通行料ラベルが更新されるまで少し待つ
		await get_tree().create_timer(0.3).timeout
		advance_step()  # battle_winへ
	# CPUバトル終了後 → ダメージ説明へ
	elif phase == "cpu_battle":
		await get_tree().create_timer(0.3).timeout
		advance_step()  # damage_explainへ
	# スタチューバトル完了 → battle_statue_winへ
	elif phase == "battle_statue_start":
		await get_tree().create_timer(0.3).timeout
		advance_step()  # battle_statue_winへ

# =============================================================================
# チュートリアル開始・終了
# =============================================================================

## チュートリアル開始
func start_tutorial():
	is_active = true
	current_step = 0
	current_turn = 1
	_last_player_id = -1
	tutorial_started.emit()
	
	# CPUのバトルポリシーをチュートリアル用に設定（常に戦闘する）
	_set_cpu_tutorial_policy()
	
	# 初期手札を設定
	_set_initial_hands()
	
	# ダイスを設定
	set_dice_for_current_turn()
	
	# 最初のステップを表示
	_show_current_step()

## CPUにチュートリアル用のバトルポリシーを設定
func _set_cpu_tutorial_policy():
	if not board_system_3d:
		return
	
	# CPUTurnProcessorからcpu_ai_handlerを取得
	var cpu_turn_processor = board_system_3d.get_node_or_null("CPUTurnProcessor")
	if cpu_turn_processor and cpu_turn_processor.cpu_ai_handler:
		cpu_turn_processor.cpu_ai_handler.set_battle_policy_preset("tutorial")

# チュートリアル終了
func end_tutorial():
	is_active = false
	
	# カード制限をクリア
	allowed_card_ids.clear()
	
	# CPUのバトルポリシーをデフォルトに戻す
	_reset_cpu_policy()
	
	if tutorial_popup:
		tutorial_popup.hide()
	if tutorial_overlay:
		tutorial_overlay.hide_overlay()
	tutorial_ended.emit()

## CPUのバトルポリシーをデフォルトに戻す
func _reset_cpu_policy():
	if not board_system_3d:
		return
	
	var cpu_turn_processor = board_system_3d.get_node_or_null("CPUTurnProcessor")
	if cpu_turn_processor and cpu_turn_processor.cpu_ai_handler:
		cpu_turn_processor.cpu_ai_handler.set_battle_policy_preset("balanced")

# 次のステップへ
func advance_step():
	if not is_active:
		return
	
	# 前のステップ表示中フラグをリセット（シグナルハンドラからの呼び出し対応）
	_is_showing_step = false
	
	current_step += 1
	
	if current_step >= steps.size():
		# 最後のステップを超えた場合は何もしない
		# （is_final: trueのステップでend_tutorial()が呼ばれる）
		print("[TutorialManager] 全ステップ完了")
		return
	
	step_changed.emit(current_step)
	_show_current_step()

# ターンを進める
func advance_turn():
	current_turn += 1
	
# 現在のフェーズかどうか
func is_phase(phase_name: String) -> bool:
	if current_step >= steps.size():
		return false
	return steps[current_step].get("phase", "") == phase_name

# 現在のステップを表示
func _show_current_step():
	if current_step >= steps.size():
		return
	
	# 再入防止（前のステップ表示中に次のステップが呼ばれた場合はスキップ）
	if _is_showing_step:
		return
	_is_showing_step = true
	
	var step = steps[current_step]
	print("[TutorialManager] Step %d: %s" % [step.id, step.phase])
	
	# ExplanationModeでステップを表示
	await _show_step_with_explanation_mode(step)
	
	# ステップ表示完了（シグナル待ち以外のパターン）
	_is_showing_step = false

# 現在のステップデータを取得
func get_current_step() -> Dictionary:
	if current_step < steps.size():
		return steps[current_step]
	return {}

# 固定ダイス目を取得（プレイヤーID指定）
func get_fixed_dice(player_id: int = 0) -> int:
	var seq = dice_sequence if player_id == 0 else cpu_dice_sequence
	if current_turn <= seq.size():
		return seq[current_turn - 1]
	return -1

# 現在のターンのダイスを設定（プレイヤーID指定）
func set_dice_for_current_turn(player_id: int = 0):
	var dice_value = get_fixed_dice(player_id)
	if dice_value > 0 and debug_controller:
		debug_controller.set_debug_dice(dice_value)
		print("[TutorialManager] 【デバッグ】固定ダイス: %d" % dice_value)

# 初期手札を設定
func _set_initial_hands():
	if not card_system:
		return
	
	# プレイヤー0の手札
	card_system.set_fixed_hand_for_player(0, player_initial_hand.duplicate())
	
	# プレイヤー1（CPU）の手札
	card_system.set_fixed_hand_for_player(1, cpu_initial_hand.duplicate())
	
	# プレイヤー0のデッキ（ドロー順固定）
	if not player_deck.is_empty():
		card_system.set_fixed_deck_for_player(0, player_deck.duplicate())
	
	# プレイヤー1（CPU）のデッキ
	if not cpu_deck.is_empty():
		card_system.set_fixed_deck_for_player(1, cpu_deck.duplicate())
	
	print("[TutorialManager] 初期手札・デッキ設定完了")
# =============================================================================
# ExplanationMode関連
# =============================================================================

## ExplanationModeがアクティブなら終了する
func _exit_explanation_mode_if_active():
	if explanation_mode and explanation_mode.is_active():
		explanation_mode.exit()

## ドミニオコマンドを開く
func _open_dominio_command():
	if dominio_command_handler:
		var player_id = game_flow_manager.get("current_player_id") if game_flow_manager else 0
		if player_id == null:
			player_id = 0
		dominio_command_handler.open_dominio_order(player_id)

## ドミニオボタンを表示
func _show_dominio_button():
	if ui_manager and ui_manager.has_method("show_dominio_order_button"):
		ui_manager.show_dominio_order_button()

## アルカナアーツボタンを表示
func _show_arcana_arts_button():
	if ui_manager and ui_manager.has_method("show_arcana_arts_button"):
		ui_manager.show_arcana_arts_button()

## カードUIが準備完了するまで待つ
func _wait_for_card_ui_ready():
	var max_wait = 60  # 最大60フレーム
	for i in range(max_wait):
		await get_tree().process_frame
		# card_selection_uiがアクティブかつhand_displayにカードがあることを確認
		if ui_manager:
			# card_selection_uiがアクティブになるまで待つ
			if ui_manager.card_selection_ui and ui_manager.card_selection_ui.is_active:
				# hand_displayのplayer_card_nodesを確認
				if ui_manager.hand_display:
					var hd = ui_manager.hand_display
					if "player_card_nodes" in hd and hd.player_card_nodes.has(0):
						if hd.player_card_nodes[0].size() > 0:
							return
	print("[TutorialManager] WARNING: Card UI not ready after %d frames" % max_wait)

## チュートリアル用カード制限を更新
func _update_allowed_cards(filter: String):
	allowed_card_ids.clear()
	
	if filter == "":
		return
	
	# フィルタはIDのみ（数値文字列）
	if filter.is_valid_int():
		allowed_card_ids.append(int(filter))

## 指定カードIDが選択可能かチェック（card_selection_uiから呼び出し）
func is_card_allowed(card_id: int) -> bool:
	if allowed_card_ids.is_empty():
		return true  # 制限なし
	return card_id in allowed_card_ids

## 指定タイルがターゲットとして選択可能かチェック（TapTargetManagerから呼び出し）
func is_target_tile_allowed(tile_index: int) -> bool:
	if allowed_target_tile_condition == "":
		return true  # 制限なし
	
	# BoardSystemを取得
	var board_system = _get_board_system()
	if not board_system:
		return true
	
	# タイル情報を取得（get_tile_infoを使用）
	var tile_info = board_system.get_tile_info(tile_index)
	if tile_info.is_empty():
		return false
	
	# 条件をパース
	var condition = allowed_target_tile_condition
	
	# "creature:<creature_name>" - 特定のクリーチャーがいる土地
	if condition.begins_with("creature:"):
		var creature_name = condition.substr(9)  # "creature:"の後
		return _check_creature_on_tile(tile_info, creature_name)
	
	# "mismatched_creature:<creature_name>" - 属性が合っていない特定クリーチャーの土地
	if condition.begins_with("mismatched_creature:"):
		var creature_name = condition.substr(20)  # "mismatched_creature:"の後
		return _check_mismatched_creature_on_tile(tile_info, creature_name)
	
	# "enemy_player" - 敵プレイヤーのみ（プレイヤー選択スペル用）
	if condition == "enemy_player":
		return _check_enemy_player_target(tile_index)
	
	# 数値（タイルインデックス）- 後方互換
	if condition.is_valid_int():
		return tile_index == int(condition)
	
	return true  # 不明な条件は許可

## BoardSystemを取得
func _get_board_system():
	return board_system_3d

## タイル上に特定のクリーチャーがいるかチェック
func _check_creature_on_tile(tile_info: Dictionary, creature_name: String) -> bool:
	if not tile_info.get("has_creature", false):
		return false
	var creature = tile_info.get("creature", {})
	if creature.is_empty():
		return false
	# クリーチャー名をチェック（部分一致）
	var name = creature.get("name", "")
	return name.to_lower().contains(creature_name.to_lower())

## タイル上に属性が合っていない特定クリーチャーがいるかチェック
func _check_mismatched_creature_on_tile(tile_info: Dictionary, creature_name: String) -> bool:
	if not _check_creature_on_tile(tile_info, creature_name):
		return false
	# タイルの属性とクリーチャーの属性を比較
	var creature = tile_info.get("creature", {})
	var tile_element = tile_info.get("element", "")  # タイルの属性
	var creature_element = creature.get("element", "")  # クリーチャーの属性
	# 属性が異なる場合にtrue
	return tile_element != creature_element

## 敵プレイヤーかどうかチェック（プレイヤー選択スペル用）
func _check_enemy_player_target(tile_index: int) -> bool:
	# プレイヤーの位置を取得（直接参照経由）
	if not player_system:
		return true

	var current_player_id = game_flow_manager.current_player_index if game_flow_manager else 0

	# 敵プレイヤー（CPU）の位置を取得
	for player in player_system.players:
		if player.id != current_player_id:
			var enemy_tile = board_system_3d.get_player_tile(player.id) if board_system_3d else -1
			if tile_index == enemy_tile:
				return true

	return false

## 指定プレイヤーがターゲットとして選択可能かチェック（SpellPhaseHandlerから呼び出し）
func is_player_target_allowed(player_id: int) -> bool:
	if allowed_target_tile_condition == "":
		return true  # 制限なし
	
	# 現在のプレイヤーIDを取得（直接参照経由）
	var current_player_id = 0
	if player_system:
		current_player_id = player_system.current_player_index
	
	# "enemy_player" - 敵プレイヤーのみ
	if allowed_target_tile_condition == "enemy_player":
		return player_id != current_player_id
	
	# "self_player" - 自分のみ
	if allowed_target_tile_condition == "self_player":
		return player_id == current_player_id
	
	return true  # 不明な条件は許可

## 指定アクションが選択可能かチェック（DominioCommandHandlerから呼び出し）
func is_action_allowed(action_type: String) -> bool:
	if allowed_action == "":
		return true  # 制限なし
	return action_type == allowed_action

## 指定レベルが選択可能かチェック（LevelUpUIから呼び出し）
func is_level_allowed(level: int) -> bool:
	if allowed_level < 0:
		return true  # 制限なし
	return level == allowed_level

# ExplanationModeでステップを表示
func _show_step_with_explanation_mode(step: Dictionary):
	if not explanation_mode:
		return
	
	var message = step.get("message", "")
	var popup_position = step.get("popup_position", "top")
	var popup_offset_y = step.get("popup_offset_y", 0.0)
	var wait_for_click = step.get("wait_for_click", false)
	var highlight_buttons = step.get("highlight", [])
	var highlight_card = step.get("highlight_card", false)
	var highlight_card_filter = step.get("highlight_card_filter", "")
	var disable_all_buttons = step.get("disable_all_buttons", false)
	var explicit_exit_trigger = step.get("exit_trigger", "")  # 明示的な終了トリガー
	
	# チュートリアル用カード制限を設定
	_update_allowed_cards(highlight_card_filter)
	
	# チュートリアル用ターゲット制限を設定（数値または文字列条件）
	var target_tile_value = step.get("allowed_target_tile", "")
	if target_tile_value is int:
		allowed_target_tile_condition = str(target_tile_value) if target_tile_value >= 0 else ""
	else:
		allowed_target_tile_condition = str(target_tile_value)
	
	# チュートリアル用アクション制限を設定
	allowed_action = step.get("allowed_action", "")
	
	# チュートリアル用レベル制限を設定
	allowed_level = step.get("allowed_level", -1)
	
	# ドミニオボタンを表示
	if step.get("show_dominio_button", false):
		_show_dominio_button()
	
	# アルカナアーツボタンを表示
	if step.get("show_arcana_arts_button", false):
		_show_arcana_arts_button()
		# ボタン状態を保護するためにexplanation_mode_activeを設定
		if ui_manager and ui_manager.global_action_buttons:
			ui_manager.global_action_buttons.explanation_mode_active = true
	
	# 空メッセージ、かつwait_for_clickでない場合はスキップ（シグナル待ち）
	if message == "" and not wait_for_click:
		# ポップアップを非表示
		if explanation_mode.popup:
			explanation_mode.popup.hide()
		# フラグをリセット（シグナルハンドラからadvance_step可能にする）
		_is_showing_step = false
		# シグナルで次のステップへ進む
		return
	
	# ハイライト設定を構築
	var highlights = []
	
	# ボタンハイライト
	if not highlight_buttons.is_empty():
		highlights.append({"type": "button", "targets": highlight_buttons})
	
	# カードハイライト
	if highlight_card:
		highlights.append({"type": "card", "filter": highlight_card_filter})
	
	# タイル通行料ハイライト
	if step.has("highlight_tile_toll"):
		var tile_value = step.get("highlight_tile_toll")
		highlights.append({"type": "tile_toll", "target": tile_value})
	
	# プレイヤーインフォパネルハイライト
	if step.has("highlight_player_info"):
		var player_id = step.get("highlight_player_info")
		highlights.append({"type": "player_info", "player_id": player_id})
	
	# 終了トリガーを決定
	var exit_trigger = "click"
	var allowed_buttons = []
	
	# 明示的に指定されていればそれを使用
	if explicit_exit_trigger != "":
		exit_trigger = explicit_exit_trigger
		if exit_trigger == "button":
			allowed_buttons = highlight_buttons
	elif wait_for_click:
		exit_trigger = "click"
	elif highlight_card:
		# カード選択待ち: カードをタップしたら終了
		exit_trigger = "card_tap"
	elif not highlight_buttons.is_empty():
		# ボタン待ち: ハイライトされたボタンのいずれかを押したら終了
		exit_trigger = "button"
		allowed_buttons = highlight_buttons
	elif disable_all_buttons and message != "":
		# ボタン無効化 + メッセージあり → シグナル待ち（表示だけしてシグナルで進む）
		exit_trigger = "signal"
	
	# ExplanationMode設定
	var pause_game = step.get("pause_game", true)  # デフォルトはtrue
	var config = {
		"message": message,
		"popup_position": popup_position,
		"popup_offset_y": popup_offset_y,
		"exit_trigger": exit_trigger,
		"allowed_buttons": allowed_buttons,
		"highlights": highlights,
		"pause_game": pause_game
	}
	
		
	# ボタン待ち/カード選択/シグナル待ちパターンの場合は、enterだけ呼んでawaitしない
	# ゲームのシグナルで次のステップへ進む
	if exit_trigger in ["button", "card_tap", "card_select", "signal"]:
		# カード選択の場合は、UIが表示されるまで待つ
		if exit_trigger in ["card_tap", "card_select"]:
			await _wait_for_card_ui_ready()
		explanation_mode.enter(config)
		# フラグをリセット（シグナルハンドラからadvance_step可能にする）
		_is_showing_step = false
		# 操作後に説明モードを抜けて、ゲームが進行する
		# 次のステップへはシグナルハンドラで進む
		return
	
	# クリック待ちパターンの場合はawaitで待つ
	await explanation_mode.enter_and_wait(config)
	
	# 最終ステップなら終了
	if step.get("is_final", false):
		end_tutorial()
		return
	
	# ドミニオコマンドを開く指定がある場合
	if step.get("open_dominio_command", false):
		_open_dominio_command()
	
	# クリック待ちパターンの場合は次のステップへ
	await get_tree().process_frame
	advance_step()
