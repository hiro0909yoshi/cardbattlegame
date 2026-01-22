# チュートリアル管理クラス
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
var global_comment_ui = null
var debug_controller = null
var card_system = null

# ステップデータ
var steps: Array = []

func _ready():
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
			"wait_for_click": true
		},
		{
			"id": 2,
			"turn": 1,
			"phase": "direction",
			"message": "まず進む方向を選びましょう。\n\n好きな方向を選んでください。",
			"wait_for_click": false
		},
		{
			"id": 3,
			"turn": 1,
			"phase": "dice",
			"message": "✓ボタンを押してダイスを振りましょう！",
			"wait_for_click": false
		},
		{
			"id": 4,
			"turn": 1,
			"phase": "summon",
			"message": "空き地に到着しました！\n\nクリーチャーを召喚して領地にしましょう。\n手札のグリーンオーガをタップしてください。",
			"wait_for_click": false
		},
		{
			"id": 5,
			"turn": 1,
			"phase": "summon_cost",
			"message": "召喚にはMPが必要です。\n\n左上の魔力からコスト分が消費されます。\n✓ボタンで召喚を決定しましょう。",
			"wait_for_click": false
		},
		{
			"id": 6,
			"turn": 1,
			"phase": "land_bonus",
			"message": "領地ボーナス！\n\n属性が一致する領地に召喚すると、\nクリーチャーのHPにボーナスがつきます。",
			"wait_for_click": true
		},
		# ターン1: CPU
		{
			"id": 7,
			"turn": 1,
			"phase": "cpu_turn",
			"message": "相手のターンです...",
			"wait_for_click": false,
			"auto_advance": true
		},
		# ターン2: プレイヤー
		{
			"id": 8,
			"turn": 2,
			"phase": "dice",
			"message": "ターン2です！\n\nダイスを振りましょう。",
			"wait_for_click": false
		},
		{
			"id": 9,
			"turn": 2,
			"phase": "item",
			"message": "敵の領地に到着しました！\n\nバトル前にアイテムを使用できます。\nロングソードを使ってみましょう。",
			"wait_for_click": false
		},
		{
			"id": 10,
			"turn": 2,
			"phase": "item_explain",
			"message": "アイテムは1バトルにつき1つまで使用できます。\n\n武器はSTを上げ、防具はHPを上げます。",
			"wait_for_click": true
		},
		{
			"id": 11,
			"turn": 2,
			"phase": "battle",
			"message": "バトル開始！\n\n敵を倒して領地を奪いましょう！",
			"wait_for_click": false
		},
		{
			"id": 12,
			"turn": 2,
			"phase": "battle_win",
			"message": "勝利！領地を奪いました！\n\nバトルに勝つと敵の領地を自分のものにできます。",
			"wait_for_click": true
		},
		# ターン2: CPU
		{
			"id": 13,
			"turn": 2,
			"phase": "cpu_battle",
			"message": "相手のターン...\n\n相手があなたの領地に侵入してきました！",
			"wait_for_click": false,
			"auto_advance": true
		},
		{
			"id": 14,
			"turn": 2,
			"phase": "toll_explain",
			"message": "相手はバトルに負けました。\n\nバトルに負けると通行料を支払わなければなりません。",
			"wait_for_click": true
		},
		# ターン3: プレイヤー
		{
			"id": 15,
			"turn": 3,
			"phase": "dice",
			"message": "最終ターンです！\n\nダイスを振って城に戻りましょう。",
			"wait_for_click": false
		},
		{
			"id": 16,
			"turn": 3,
			"phase": "checkpoint",
			"message": "砦を通過しました！\n\n砦を通過するとシグナルを獲得できます。\nシグナルを全て集めると周回ボーナスがもらえます。",
			"wait_for_click": true
		},
		{
			"id": 17,
			"turn": 3,
			"phase": "lap_bonus",
			"message": "城に到着！周回ボーナス獲得！\n\n魔力が増え、クリーチャーのHPも全回復します。",
			"wait_for_click": true
		},
		{
			"id": 18,
			"turn": 3,
			"phase": "victory",
			"message": "おめでとうございます！\n\n目標魔力に到達して城に戻ったので勝利です！\n\nチュートリアル完了！",
			"wait_for_click": true
		}
	]

# 初期化
func initialize(gfm, uim, dc = null, cs = null):
	game_flow_manager = gfm
	ui_manager = uim
	debug_controller = dc
	card_system = cs
	
	# GlobalCommentUIを取得
	if ui_manager:
		global_comment_ui = ui_manager.get_node_or_null("GlobalCommentUI")
	
	print("[TutorialManager] 初期化完了")
	print("  - GameFlowManager: ", game_flow_manager != null)
	print("  - UIManager: ", ui_manager != null)
	print("  - DebugController: ", debug_controller != null)
	print("  - CardSystem: ", card_system != null)

# チュートリアル開始
func start_tutorial():
	is_active = true
	current_step = 0
	current_turn = 1
	
	print("[TutorialManager] チュートリアル開始")
	
	# 固定手札を設定
	_setup_fixed_hands()
	
	# 最初のダイスを固定
	_set_fixed_dice_for_turn(1)
	
	tutorial_started.emit()
	
	# 最初のステップを表示
	await get_tree().create_timer(0.5).timeout
	_show_current_step()

# 固定手札を設定
func _setup_fixed_hands():
	if not card_system:
		print("[TutorialManager] WARNING: CardSystemが見つかりません")
		return
	
	# プレイヤー0: グリーンオーガ×2、ロングソード×1
	card_system.set_fixed_hand_for_player(0, PLAYER_INITIAL_HAND)
	
	# CPU（プレイヤー1）: グリーンオーガ×2
	card_system.set_fixed_hand_for_player(1, CPU_INITIAL_HAND)
	
	print("[TutorialManager] 固定手札設定完了")

# ターンに応じたダイスを固定
func _set_fixed_dice_for_turn(turn: int):
	if not debug_controller:
		print("[TutorialManager] WARNING: DebugControllerが見つかりません")
		return
	
	var dice_value = get_fixed_dice()
	debug_controller.set_debug_dice(dice_value)
	print("[TutorialManager] ターン%d: ダイス固定 = %d" % [turn, dice_value])

# チュートリアル終了
func end_tutorial():
	is_active = false
	print("[TutorialManager] チュートリアル終了")
	tutorial_ended.emit()

# 次のステップへ
func advance_step():
	current_step += 1
	
	if current_step >= steps.size():
		end_tutorial()
		return
	
	step_changed.emit(current_step)
	_show_current_step()

# 現在のステップを表示
func _show_current_step():
	if current_step >= steps.size():
		return
	
	var step = steps[current_step]
	var message = step.get("message", "")
	
	print("[TutorialManager] Step %d: %s" % [step.id, step.phase])
	
	if message and global_comment_ui:
		message_shown.emit(message)
		
		if step.get("wait_for_click", false):
			# クリック待ちモード
			await global_comment_ui.show_and_wait(message, 0)
			# クリック後に次のステップへ
			advance_step()
		else:
			# 単純表示（他の操作待ち）
			global_comment_ui.show_message(message)

# 現在のステップデータを取得
func get_current_step() -> Dictionary:
	if current_step < steps.size():
		return steps[current_step]
	return {}

# 固定ダイス目を取得
func get_fixed_dice() -> int:
	if current_turn <= DICE_SEQUENCE.size():
		return DICE_SEQUENCE[current_turn - 1]
	return randi_range(1, 6)

# プレイヤーの初期手札を取得
func get_player_initial_hand() -> Array:
	return PLAYER_INITIAL_HAND.duplicate()

# CPUの初期手札を取得
func get_cpu_initial_hand() -> Array:
	return CPU_INITIAL_HAND.duplicate()

# 現在のフェーズをチェック
func is_phase(phase_name: String) -> bool:
	var step = get_current_step()
	return step.get("phase", "") == phase_name

# クリック待ちかどうか
func is_waiting_for_click() -> bool:
	var step = get_current_step()
	return step.get("wait_for_click", false)

# メッセージを非表示にする
func hide_message():
	if global_comment_ui:
		global_comment_ui.hide_message()

# プレイヤーの選択方向を記録
func set_player_direction(direction: int):
	player_chosen_direction = direction
	print("[TutorialManager] プレイヤー方向: %d" % direction)

# CPUの方向を取得（プレイヤーの逆）
func get_cpu_direction() -> int:
	var cpu_dir = -player_chosen_direction
	print("[TutorialManager] CPU方向: %d（プレイヤーの逆）" % cpu_dir)
	return cpu_dir

# ターンを進める（CPUターン終了後に呼ばれる）
func advance_turn():
	current_turn += 1
	print("[TutorialManager] ===== ターン %d に進む =====" % current_turn)

# 現在のターンのダイスを設定（プレイヤー0のターン開始時に呼ばれる）
func set_dice_for_current_turn():
	print("[TutorialManager] set_dice_for_current_turn: turn=%d" % current_turn)
	_set_fixed_dice_for_turn(current_turn)
	
	# 固定されたか確認
	if debug_controller:
		print("[TutorialManager] 固定ダイス確認: %d" % debug_controller.get_fixed_dice())
