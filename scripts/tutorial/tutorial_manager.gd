# チュートリアルの進行、ガイドメッセージ表示、操作制限を管理
extends Node

class_name TutorialManager

# シグナル
signal tutorial_started
signal tutorial_ended
signal step_changed(step_id: int)
signal message_shown(message: String)

# チュートリアル状態
var is_active: bool = false
var current_step: int = 0
var current_turn: int = 1

# 固定データ
const PLAYER_INITIAL_HAND = [210, 210, 1073]  # グリーンオーガ×2、ロングソード
const CPU_INITIAL_HAND = [210, 210]  # グリーンオーガ×2
const DICE_SEQUENCE = [3, 6, 5]  # ターン1, 2, 3のダイス目

# プレイヤーが選んだ方向（CPUは逆方向に進む）
var player_chosen_direction: int = 0

# 参照
var game_flow_manager = null
var ui_manager = null
var debug_controller = null
var card_system = null

# チュートリアル専用UI
var tutorial_popup = null
var tutorial_overlay = null

# ステップデータ
var steps: Array = []

# システム参照
var board_system_3d = null

# 内部状態
var _last_player_id: int = -1

func _ready():
	# ポーズ中でも動作するように設定
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_steps()

# ステップデータを設定
func _setup_steps():
	steps = [
		# ターン1: プレイヤー
		{
			"id": 1,
			"turn": 1,
			"phase": "start",
			"message": "チュートリアルへようこそ！\n\nこのゲームの目標は、魔力を貯めて城に戻ることです。",
			"wait_for_click": true,
			"highlight": [],
			"disable_all_buttons": true
		},
		{
			"id": 2,
			"turn": 1,
			"phase": "dice",
			"message": "✓ボタンを押してダイスを振りましょう！",
			"wait_for_click": false,
			"highlight": ["confirm"]
		},
		{
			"id": 3,
			"turn": 1,
			"phase": "direction",
			"message": "進む方向を選んでください\n\n▲▼ボタンで方向を選び\n✓ボタンで決定します",
			"wait_for_click": false,
			"highlight": ["up", "down", "confirm"]
		},
		{
			"id": 4,
			"turn": 1,
			"phase": "summon_select",
			"message": "クリーチャーを召喚しましょう\n召喚したいカードをタップしてください",
			"wait_for_click": false,
			"highlight_card": true,
			"highlight_card_filter": "green_ogre",
			"highlight": []
		},
		{
			"id": 5,
			"turn": 1,
			"phase": "summon_info",
			"message": "これはクリーチャーの能力が書かれた説明書です\n召喚をする前に確認をしましょう\n\n設定＞説明＞インフォパネル で\n読み方を確認できます",
			"wait_for_click": true,
			"highlight": [],
			"disable_all_buttons": true,
			"popup_position": "right"
		},
		{
			"id": 6,
			"turn": 1,
			"phase": "summon_confirm",
			"message": "もう一度カードをタップして召喚を決定しましょう",
			"wait_for_click": false,
			"highlight_card": true,
			"highlight_card_filter": "green_ogre"
		},
		{
			"id": 7,
			"turn": 1,
			"phase": "summon_execute",
			"message": "",
			"wait_for_click": false
		},
		{
			"id": 8,
			"turn": 1,
			"phase": "summon_complete",
			"message": "クリーチャーを召喚しました！\n\nこの土地はあなたの領地になりました\n領地の価値が総魔力に加算されます",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		# ターン1: CPU
		{
			"id": 9,
			"turn": 1,
			"phase": "cpu_turn_start",
			"message": "相手のターンです\n\n相手の行動を見てみましょう",
			"wait_for_click": false,
			"disable_all_buttons": true
		},
		{
			"id": 10,
			"turn": 1,
			"phase": "cpu_turn",
			"message": "",
			"wait_for_click": false
		},
		{
			"id": 11,
			"turn": 1,
			"phase": "cpu_summon_complete",
			"message": "相手がクリーチャーを召喚しました！\n\nこの土地は相手の領地になりました\nあなたが敵の領地に止まると通行料を取られます",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		# ターン2: プレイヤー
		{
			"id": 12,
			"turn": 2,
			"phase": "turn2_start",
			"message": "あなたのターンです\n\n✓ボタンを押してサイコロを振りましょう",
			"wait_for_click": false,
			"highlight": ["confirm"]
		},
		{
			"id": 13,
			"turn": 2,
			"phase": "dice",
			"message": "",
			"wait_for_click": false
		},
		{
			"id": 14,
			"turn": 2,
			"phase": "checkpoint",
			"message": "砦を通過しました！\n\n砦に書かれているシグナルを獲得できます\nシグナルを取得すると魔力がもらえます\n\nシグナルを全て集めると周回ボーナスがもらえます",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		{
			"id": 15,
			"turn": 2,
			"phase": "wait_movement",
			"message": "",
			"wait_for_click": false
		},
		{
			"id": 16,
			"turn": 2,
			"phase": "battle_arrival",
			"message": "敵の領地に止まってしまいました！\n\nバトルが始まります",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		{
			"id": 17,
			"turn": 2,
			"phase": "battle_select_creature",
			"message": "バトルに出すクリーチャーを選んでください\n\nカードを2回タップして選択します",
			"wait_for_click": false,
			"highlight_card": true,
			"disable_all_buttons": true,
			"popup_position": "right"
		},
		{
			"id": 18,
			"turn": 2,
			"phase": "battle_info1",
			"message": "攻撃側はあなたが選んだクリーチャーです\n\n防御側は土地に配置されているクリーチャーです",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true,
			"popup_position": "left"
		},
		{
			"id": 19,
			"turn": 2,
			"phase": "battle_info2",
			"message": "カードの属性と土地の属性が一致していると\n土地のレベルに応じてHPにボーナスが入ります\n\n敵のグリーンオーガは地属性の土地に\n配置されているのでHPが+10されています",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true,
			"popup_position": "left"
		},
		{
			"id": 20,
			"turn": 2,
			"phase": "battle_info3",
			"message": "あなたのグリーンオーガの攻撃力はAP40です\n\n敵のグリーンオーガのHPは50+10で60です\n\nこのままでは倒せません！\nアイテムを使用しましょう",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true,
			"popup_position": "left"
		},
		{
			"id": 21,
			"turn": 2,
			"phase": "battle_item_prompt",
			"message": "アイテムカードを選択しましょう\n\nロングソードをタップしてください",
			"wait_for_click": false,
			"highlight_card": true,
			"highlight_card_filter": "long_sword",
			"disable_all_buttons": true,
			"popup_position": "right"
		},
		{
			"id": 22,
			"turn": 2,
			"phase": "battle_item_info",
			"message": "ロングソードはAPを30上昇させる\nアイテムカードです\n\nもう一度タップして装備しましょう",
			"wait_for_click": false,
			"disable_all_buttons": true,
			"popup_position": "right"
		},
		{
			"id": 23,
			"turn": 2,
			"phase": "battle_start",
			"message": "",
			"wait_for_click": false
		},
		{
			"id": 24,
			"turn": 2,
			"phase": "battle_ap_explain",
			"message": "ロングソードの効果でAPが40→70に上昇します！\n\n敵のHP60を上回っているので勝てます\n\n画面をタップしてバトルを進めましょう",
			"wait_for_click": false,
			"disable_all_buttons": true
		},
		{
			"id": 25,
			"turn": 2,
			"phase": "battle_win",
			"message": "勝利！領地を奪いました！\n\nバトルに勝つと敵の領地を自分のものにできます",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		# ターン2: CPU
		{
			"id": 26,
			"turn": 2,
			"phase": "cpu_turn_start2",
			"message": "相手のターンです",
			"wait_for_click": false,
			"disable_all_buttons": true
		},
		{
			"id": 27,
			"turn": 2,
			"phase": "cpu_battle_explain",
			"message": "相手があなたの領地に止まりました！\n\nお互いにアイテムがない場合\nバトルは自動で進行します\n\n相手がアイテムを持っている場合でも\n何を使うかは事前には分かりません",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		{
			"id": 28,
			"turn": 2,
			"phase": "cpu_battle",
			"message": "",
			"wait_for_click": false
		},
		{
			"id": 29,
			"turn": 2,
			"phase": "toll_explain",
			"message": "相手はバトルに負けました！\n\nバトルに負けると通行料を支払います",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		# ターン3: プレイヤー
		{
			"id": 30,
			"turn": 3,
			"phase": "turn3_start",
			"message": "最終ターンです！\n\n✓ボタンを押してサイコロを振りましょう",
			"wait_for_click": false,
			"highlight": ["confirm"]
		},
		{
			"id": 31,
			"turn": 3,
			"phase": "dice",
			"message": "",
			"wait_for_click": false
		},
		{
			"id": 32,
			"turn": 3,
			"phase": "checkpoint",
			"message": "2つ目のシグナルを獲得しました！\n\nこれで全てのシグナルが揃いました\n城に戻ると周回ボーナスがもらえます",
			"wait_for_click": true,
			"pause_game": true,
			"disable_all_buttons": true
		},
		{
			"id": 33,
			"turn": 3,
			"phase": "lap_bonus",
			"message": "城に到着！周回ボーナス獲得！\n\n魔力が増え、クリーチャーのHPも全回復します。",
			"wait_for_click": true
		},
		{
			"id": 34,
			"turn": 3,
			"phase": "victory",
			"message": "おめでとうございます！\n\n目標魔力に到達して城に戻ったので勝利です！\n\nチュートリアル完了！",
			"wait_for_click": true,
			"is_final": true
		}
	]

# system_managerから初期化（推奨）
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
	_connect_signals()

# チュートリアル専用UIをセットアップ
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

# シグナル接続
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

# === シグナルハンドラ ===

func _on_turn_started(player_id: int):
	print("[TutorialManager] _on_turn_started: player_id=%d, current_phase=%s" % [player_id, get_current_step().get("phase", "")])
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
	
	# CPUターン開始時（summon_complete後）
	if player_id == 1 and is_phase("summon_complete"):
		advance_step()  # cpu_turn_startへ
	
	# CPUターン開始時（battle_win後）- ターン2のCPUバトル
	if player_id == 1 and is_phase("battle_win"):
		advance_step()  # cpu_turn_start2へ
	
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
				advance_step()

func _on_movement_completed(player_id: int, _final_tile: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	if player_id == 0:
		if phase == "direction":
			advance_step()
		# 移動完了待ちフェーズなら次へ（敵領地に到着）
		elif phase == "wait_movement":
			advance_step()  # battle_arrivalへ
	# CPU移動完了時（プレイヤーの領地に止まった）
	elif player_id == 1:
		if phase == "cpu_turn_start2":
			advance_step()  # cpu_battle_explainへ

func _on_card_info_shown(_card_index: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	if phase == "summon_select":
		advance_step()
	# アイテムカード1回目タップ
	elif phase == "battle_item_prompt":
		advance_step()  # battle_item_infoへ

func _on_card_selected(_card_index: int):
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# summon_infoフェーズ中にカード選択 → summon_confirmをスキップしてsummon_executeへ
	if phase == "summon_info":
		advance_step()  # summon_confirmへ
		advance_step()  # summon_executeへ
	elif phase == "summon_confirm":
		advance_step()
	# バトルクリーチャー選択確定時（2回目タップ）
	elif phase == "battle_select_creature":
		advance_step()  # battle_info1へ
	# アイテム選択確定時（2回目タップ）- battle_startへ進む
	elif phase == "battle_item_info":
		# コメントを消す
		if tutorial_popup:
			tutorial_popup.hide()
		advance_step()  # battle_startへ

func _on_action_completed():
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	
	# プレイヤーの召喚関連フェーズなら召喚完了フェーズへスキップ
	if phase in ["summon_info", "summon_confirm", "summon_execute"]:
		while is_active and not is_phase("summon_complete"):
			advance_step()
	
	# CPUターン中（cpu_turn_startまたはcpu_turn）なら召喚完了フェーズへ
	elif phase in ["cpu_turn_start", "cpu_turn"]:
		# cpu_summon_completeまでスキップ
		while is_active and not is_phase("cpu_summon_complete"):
			advance_step()

func _on_checkpoint_passed(player_id: int, checkpoint_type: String):
	print("[TutorialManager] _on_checkpoint_passed: player_id=%d, type=%s, current_phase=%s" % [player_id, checkpoint_type, get_current_step().get("phase", "")])
	if not is_active:
		return
	# プレイヤー0がチェックポイント通過時、diceフェーズならcheckpointへ
	if player_id == 0:
		var phase = get_current_step().get("phase", "")
		if phase == "dice":
			print("[TutorialManager] -> checkpointへ進む（少し待機）")
			# 少し待ってからコメント表示（移動アニメーションがチェックポイントに到達するのを待つ）
			await get_tree().create_timer(0.15).timeout
			advance_step()  # checkpointへ

func _on_battle_intro_completed():
	print("[TutorialManager] _on_battle_intro_completed: current_phase=%s" % get_current_step().get("phase", ""))
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# バトル開始フェーズならAP説明へ進む
	if phase == "battle_start":
		advance_step()  # battle_ap_explainへ

func _on_battle_screen_closed():
	print("[TutorialManager] _on_battle_screen_closed: current_phase=%s" % get_current_step().get("phase", ""))
	if not is_active:
		return
	var phase = get_current_step().get("phase", "")
	# バトルAP説明フェーズならバトル勝利へ進む
	if phase == "battle_ap_explain":
		# コメントを消す
		if tutorial_popup:
			tutorial_popup.hide()
		advance_step()  # battle_winへ

# 旧initialize（互換性のため残す）
func initialize(gfm, uim, dc = null, cs = null):
	game_flow_manager = gfm
	ui_manager = uim
	debug_controller = dc
	card_system = cs

# チュートリアル開始
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
		print("[TutorialManager] CPUにチュートリアルポリシーを設定")

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
		print("[TutorialManager] CPUのポリシーをデフォルトに戻す")

# 次のステップへ
func advance_step():
	if not is_active:
		return
	
	current_step += 1
	
	if current_step >= steps.size():
		end_tutorial()
		return
	
	step_changed.emit(current_step)
	_show_current_step()

# ターンを進める
func advance_turn():
	current_turn += 1
	print("[TutorialManager] advance_turn: current_turn=%d" % current_turn)

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
	var message = step.get("message", "")
	var with_overlay = step.get("with_overlay", false)
	
	print("[TutorialManager] Step %d: %s" % [step.id, step.phase])
	
	# ハイライト処理
	if tutorial_overlay:
		var highlight = step.get("highlight", [])
		var highlight_card = step.get("highlight_card", false)
		var disable_all = step.get("disable_all_buttons", false)
		
		# まずボタン無効化を処理
		if disable_all:
			tutorial_overlay.disable_all_buttons()
		
		# 次にハイライト処理
		if highlight_card:
			# カードをハイライト（ボタンは発光しない）
			var card_filter = step.get("highlight_card_filter", "")
			var card_nodes = _get_hand_card_nodes(card_filter)
			tutorial_overlay.highlight_hand_cards(card_nodes, with_overlay)
		elif not highlight.is_empty():
			# ボタンをハイライト
			tutorial_overlay.highlight_buttons(highlight, with_overlay)
		elif not disable_all:
			tutorial_overlay.hide_overlay()
	
	# ゲーム一時停止（SceneTreeをポーズ）
	var should_pause = step.get("pause_game", false)
	if should_pause:
		get_tree().paused = true
	
	if message and tutorial_popup:
		message_shown.emit(message)
		var popup_position = step.get("popup_position", "top")
		
		if step.get("wait_for_click", false):
			# クリック待ちモード
			await tutorial_popup.show_and_wait(message, popup_position)
			# ゲーム再開
			if should_pause:
				get_tree().paused = false
			# ハイライトを消す
			if tutorial_overlay:
				tutorial_overlay.hide_overlay()
			# 最終ステップなら終了、そうでなければ次へ
			if step.get("is_final", false):
				end_tutorial()
			else:
				advance_step()
		else:
			# 単純表示（他の操作待ち）
			tutorial_popup.show_message(message, popup_position)
			
			# 自動進行（指定秒数後に次のステップへ）
			var auto_delay = step.get("auto_advance_delay", 0)
			if auto_delay > 0:
				await get_tree().create_timer(auto_delay).timeout
				advance_step()
	else:
		# メッセージが空の場合はポップアップを非表示
		if tutorial_popup:
			tutorial_popup.hide()

# 手札のカードノードを取得（フィルタ指定可能）
func _get_hand_card_nodes(filter: String = "") -> Array:
	if not ui_manager:
		return []
	
	# UIManagerのhand_displayプロパティから取得
	var hand_display = ui_manager.hand_display if "hand_display" in ui_manager else null
	
	if not hand_display:
		return []
	
	# player_card_nodesからプレイヤー0のカードを取得
	var cards = []
	if "player_card_nodes" in hand_display:
		var player_cards = hand_display.player_card_nodes
		if player_cards.has(0):
			for card in player_cards[0]:
				if is_instance_valid(card) and card.visible:
					# フィルタがある場合はカード名でチェック
					if filter.is_empty():
						cards.append(card)
					else:
						var card_name = _get_card_name(card)
						if _matches_filter(card_name, filter):
							cards.append(card)
	
	return cards

# カードノードからカード名を取得
func _get_card_name(card_node) -> String:
	if card_node.has_method("get_card_data"):
		var data = card_node.get_card_data()
		return data.get("name", "")
	elif "card_data" in card_node:
		return card_node.card_data.get("name", "")
	return ""

# フィルタにマッチするかチェック
func _matches_filter(card_name: String, filter: String) -> bool:
	match filter:
		"green_ogre":
			return card_name == "グリーンオーガ"
		"long_sword":
			return card_name == "ロングソード"
		_:
			return card_name.to_lower().contains(filter.to_lower())

# 現在のステップデータを取得
func get_current_step() -> Dictionary:
	if current_step < steps.size():
		return steps[current_step]
	return {}

# 固定ダイス目を取得
func get_fixed_dice() -> int:
	if current_turn <= DICE_SEQUENCE.size():
		return DICE_SEQUENCE[current_turn - 1]
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
	card_system.set_fixed_hand_for_player(0, PLAYER_INITIAL_HAND.duplicate())
	
	# プレイヤー1（CPU）の手札
	card_system.set_fixed_hand_for_player(1, CPU_INITIAL_HAND.duplicate())
	
	print("[TutorialManager] 初期手札設定完了")
