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

const TUTORIAL_DATA_PATH = "res://data/tutorial/tutorial_stage1.json"

# =============================================================================
# チュートリアル状態
# =============================================================================

var is_active: bool = false
var current_step: int = 0
var current_turn: int = 1

# =============================================================================
# 設定データ（JSONから読み込み）
# =============================================================================

var player_initial_hand: Array = []
var cpu_initial_hand: Array = []
var dice_sequence: Array = []
var steps: Array = []

# =============================================================================
# システム参照
# =============================================================================

var game_flow_manager = null
var ui_manager = null
var debug_controller = null
var card_system = null
var board_system_3d = null

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

# =============================================================================
# 初期化
# =============================================================================

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tutorial_data()

## JSONからチュートリアルデータを読み込む
func _load_tutorial_data():
	var file = FileAccess.open(TUTORIAL_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("[TutorialManager] チュートリアルデータを読み込めません: %s" % TUTORIAL_DATA_PATH)
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
	dice_sequence = config.get("dice_sequence", [3, 6, 5])
	
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
	
	# 移動完了
	if board_system_3d and board_system_3d.movement_controller:
		board_system_3d.movement_controller.movement_completed.connect(_on_movement_completed)
	
	# チェックポイント通過
	if game_flow_manager and game_flow_manager.lap_system:
		game_flow_manager.lap_system.checkpoint_signal_obtained.connect(_on_checkpoint_passed)
	
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

func _connect_battle_signals():
	# BattleScreenManagerへの参照を取得
	if board_system_3d and board_system_3d.battle_system:
		var battle_screen_manager = board_system_3d.battle_system.battle_screen_manager
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
		# cpu_summon_complete後ならturn2_startへ
		if is_phase("cpu_summon_complete"):
			advance_step()
	
	# プレイヤー0のターン開始時にダイスを設定
	if player_id == 0:
		set_dice_for_current_turn()
	
	# CPUターン開始時（land_value_info後）
	# land_value_infoはwait_for_clickでクリック後に自動でcpu_turn_startへ進むため、ここでは何もしない
	
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
	# diceフェーズでは次のフェーズがcheckpointなら待機、そうでなければ進む
	elif phase == "dice":
		var next_step_index = current_step + 1
		if next_step_index < steps.size():
			var next_phase = steps[next_step_index].get("phase", "")
			if next_phase != "checkpoint":
				_exit_explanation_mode_if_active()
				advance_step()

func _on_movement_completed(player_id: int, _final_tile: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	if player_id == 0:
		if phase == "direction":
			_exit_explanation_mode_if_active()
			advance_step()
		# 移動完了待ちフェーズなら次へ（敵ドミニオに到着）
		elif phase == "wait_movement":
			_exit_explanation_mode_if_active()
			advance_step()  # battle_arrivalへ
	# CPU移動完了時（プレイヤーのドミニオに止まった）
	elif player_id == 1:
		if phase == "cpu_turn_start2":
			_exit_explanation_mode_if_active()
			advance_step()  # cpu_battle_explainへ

func _on_card_info_shown(_card_index: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	if phase == "summon_select":
		_exit_explanation_mode_if_active()
		advance_step()
	# アイテムカード1回目タップ
	elif phase == "battle_item_prompt":
		_exit_explanation_mode_if_active()
		advance_step()  # battle_item_infoへ

func _on_card_selected(_card_index: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# summon_infoフェーズ中にカード選択 → summon_confirmをスキップしてsummon_executeへ
	if phase == "summon_info":
		_exit_explanation_mode_if_active()
		advance_step()  # summon_confirmへ
		advance_step()  # summon_executeへ
	elif phase == "summon_confirm":
		_exit_explanation_mode_if_active()
		advance_step()
	# バトルクリーチャー選択確定時（2回目タップ）
	elif phase == "battle_select_creature":
		_exit_explanation_mode_if_active()
		advance_step()  # battle_info1へ
	# アイテム選択確定時（2回目タップ）- battle_startへ進む
	elif phase == "battle_item_info":
		_exit_explanation_mode_if_active()
		advance_step()  # battle_startへ

func _on_action_completed():
	if not is_active:
		return
	# phaseは最初に取得して保持（awaitで変わる可能性があるため）
	var initial_phase = get_current_step().get("phase", "")
	
	# プレイヤーの召喚関連フェーズなら召喚完了フェーズへスキップ
	if initial_phase in ["summon_info", "summon_confirm", "summon_execute"]:
		# summon_completeまでステップを進める（wait_for_click: falseのステップのみスキップ）
		while is_active and not is_phase("summon_complete"):
			advance_step()
		# summon_completeに到達したら終了（クリック待ちは_show_current_step内で処理）
		return
	
	# CPUターン中（cpu_turn_startまたはcpu_turn）なら召喚完了フェーズへ
	if initial_phase in ["cpu_turn_start", "cpu_turn"]:
		# cpu_summon_completeまでスキップ
		while is_active and not is_phase("cpu_summon_complete"):
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
	
	var step = steps[current_step]
	print("[TutorialManager] Step %d: %s" % [step.id, step.phase])
	
	# ExplanationModeでステップを表示
	await _show_step_with_explanation_mode(step)

# 現在のステップデータを取得
func get_current_step() -> Dictionary:
	if current_step < steps.size():
		return steps[current_step]
	return {}

# 固定ダイス目を取得
func get_fixed_dice() -> int:
	if current_turn <= dice_sequence.size():
		return dice_sequence[current_turn - 1]
	return -1

# 現在のターンのダイスを設定
func set_dice_for_current_turn():
	var dice_value = get_fixed_dice()
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
	
	print("[TutorialManager] 初期手札設定完了")
# =============================================================================
# ExplanationMode関連
# =============================================================================

## ExplanationModeがアクティブなら終了する
func _exit_explanation_mode_if_active():
	if explanation_mode and explanation_mode.is_active():
		explanation_mode.exit()

## カードUIが準備完了するまで待つ
func _wait_for_card_ui_ready():
	var max_wait = 30  # 最大30フレーム
	for i in range(max_wait):
		await get_tree().process_frame
		# hand_displayのplayer_card_nodesを確認
		if ui_manager and ui_manager.hand_display:
			var hd = ui_manager.hand_display
			if "player_card_nodes" in hd and hd.player_card_nodes.has(0):
				if hd.player_card_nodes[0].size() > 0:
					return
	print("[TutorialManager] WARNING: Card UI not ready after %d frames" % max_wait)

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
	
	# 空メッセージ、かつwait_for_clickでない場合はスキップ（シグナル待ち）
	if message == "" and not wait_for_click:
		# ポップアップを非表示
		if explanation_mode._popup:
			explanation_mode._popup.hide()
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
	
	if wait_for_click:
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
	var config = {
		"message": message,
		"popup_position": popup_position,
		"popup_offset_y": popup_offset_y,
		"exit_trigger": exit_trigger,
		"allowed_buttons": allowed_buttons,
		"highlights": highlights
	}
	
		
	# ボタン待ち/カード選択/シグナル待ちパターンの場合は、enterだけ呼んでawaitしない
	# ゲームのシグナルで次のステップへ進む
	if exit_trigger in ["button", "card_tap", "card_select", "signal"]:
		# カード選択の場合は、UIが表示されるまで待つ
		if exit_trigger in ["card_tap", "card_select"]:
			await _wait_for_card_ui_ready()
		explanation_mode.enter(config)
		# 操作後に説明モードを抜けて、ゲームが進行する
		# 次のステップへはシグナルハンドラで進む
		return
	
	# クリック待ちパターンの場合はawaitで待つ
	await explanation_mode.enter_and_wait(config)
	
	# 最終ステップなら終了
	if step.get("is_final", false):
		end_tutorial()
		return
	
	# クリック待ちパターンの場合は次のステップへ
	await get_tree().process_frame
	advance_step()
