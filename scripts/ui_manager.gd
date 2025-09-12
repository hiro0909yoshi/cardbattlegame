extends Node
class_name UIManager

# UI要素の統括管理システム（リファクタリング版）
# 各UIコンポーネントを管理・調整

signal dice_button_pressed()
signal pass_button_pressed()
signal card_selected(card_index: int)
signal level_up_selected(target_level: int, cost: int)

# UIコンポーネント
var player_info_panel: PlayerInfoPanel
var card_selection_ui: CardSelectionUI
var level_up_ui: LevelUpUI
var debug_panel: DebugPanel

# 基本UI要素
var dice_button: Button
var phase_label: Label
var current_dice_label: Label = null

# システム参照
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var board_system_ref: BoardSystem = null

# デバッグモード
var debug_mode = false

func _ready():
	# UIコンポーネントをインスタンス化
	player_info_panel = PlayerInfoPanel.new()
	card_selection_ui = CardSelectionUI.new()
	level_up_ui = LevelUpUI.new()
	debug_panel = DebugPanel.new()
	
	# 子ノードとして追加
	add_child(player_info_panel)
	add_child(card_selection_ui)
	add_child(level_up_ui)
	add_child(debug_panel)
	
	# シグナル接続
	connect_ui_signals()

# UIコンポーネントのシグナルを接続
func connect_ui_signals():
	# カード選択UI
	card_selection_ui.card_selected.connect(_on_card_ui_selected)
	card_selection_ui.selection_cancelled.connect(_on_selection_cancelled)
	
	# レベルアップUI
	level_up_ui.level_selected.connect(_on_level_ui_selected)
	level_up_ui.selection_cancelled.connect(_on_level_up_cancelled)
	
	# デバッグパネル
	debug_panel.debug_mode_changed.connect(_on_debug_mode_changed)

# UIを作成

# UIを作成
func create_ui(parent: Node):
	# システム参照を取得
	if parent.has_node("CardSystem"):
		card_system_ref = parent.get_node("CardSystem")
	if parent.has_node("PlayerSystem"):
		player_system_ref = parent.get_node("PlayerSystem")
	if parent.has_node("BoardSystem"):
		board_system_ref = parent.get_node("BoardSystem")
	
	# UIレイヤー（CanvasLayer）を作成
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	parent.add_child(ui_layer)
	
	# 基本UI要素を作成（UIレイヤーの子として）
	create_basic_ui(ui_layer)
	
	# 各コンポーネントを初期化
	player_info_panel.initialize(ui_layer, player_system_ref, board_system_ref)
	card_selection_ui.initialize(ui_layer, card_system_ref, phase_label)
	level_up_ui.initialize(ui_layer, board_system_ref, phase_label)
	debug_panel.initialize(ui_layer, card_system_ref, board_system_ref, player_system_ref)
# 基本UI要素を作成
func create_basic_ui(parent: Node):
	# フェーズ表示
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	phase_label.position = Vector2(350, 50)
	phase_label.add_theme_font_size_override("font_size", 24)
	parent.add_child(phase_label)
	
	# サイコロボタン
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	dice_button.position = Vector2(350, 250)
	dice_button.size = Vector2(120, 40)
	dice_button.pressed.connect(_on_dice_button_pressed)
	dice_button.disabled = true
	parent.add_child(dice_button)

# === プレイヤー情報パネル関連 ===
func update_player_info_panels():
	player_info_panel.update_all_panels()

# === カード選択UI関連 ===
func show_card_selection_ui(current_player):
	card_selection_ui.show_selection(current_player, "summon")

func hide_card_selection_ui():
	card_selection_ui.hide_selection()

# カードボタンが押された（card.gdから呼ばれる）
func _on_card_button_pressed(card_index: int):
	card_selection_ui.on_card_selected(card_index)

# === レベルアップUI関連 ===
func show_level_up_ui(tile_info: Dictionary, current_magic: int):
	level_up_ui.show_level_up_selection(tile_info, current_magic)

func hide_level_up_ui():
	level_up_ui.hide_selection()

# === デバッグパネル関連 ===
func toggle_debug_mode():
	debug_panel.toggle_visibility()
	debug_mode = debug_panel.is_debug_visible()

func update_cpu_hand_display(player_id: int):
	debug_panel.update_cpu_hand(player_id)

# === 基本UI操作 ===
func update_ui(current_player, current_phase):
	# プレイヤー情報パネルを更新
	player_info_panel.update_all_panels()
	
	# 現在のターンプレイヤーを設定
	if current_player:
		player_info_panel.set_current_turn(current_player.id)
	
	# フェーズ表示を更新
	update_phase_display(current_phase)

# フェーズ表示を更新
func update_phase_display(phase):
	match phase:
		0: # SETUP
			phase_label.text = "準備中..."
		1: # DICE_ROLL
			phase_label.text = "サイコロを振ってください"
		2: # MOVING
			phase_label.text = "移動中..."
		3: # TILE_ACTION
			phase_label.text = "アクション選択"
		4: # BATTLE
			phase_label.text = "バトル！"
		5: # END_TURN
			phase_label.text = "ターン終了"

# ダイス結果を表示
func show_dice_result(value: int, parent: Node):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# 新しいダイスラベルを作成
	current_dice_label = Label.new()
	current_dice_label.text = "🎲 " + str(value)
	current_dice_label.add_theme_font_size_override("font_size", 48)
	current_dice_label.position = Vector2(350, 300)
	parent.add_child(current_dice_label)

# サイコロボタンの有効/無効
func set_dice_button_enabled(enabled: bool):
	dice_button.disabled = not enabled

# === イベントハンドラ ===
func _on_dice_button_pressed():
	emit_signal("dice_button_pressed")

func _on_pass_button_pressed():
	emit_signal("pass_button_pressed")

func _on_card_ui_selected(card_index: int):
	emit_signal("card_selected", card_index)

func _on_selection_cancelled():
	emit_signal("pass_button_pressed")

func _on_level_ui_selected(target_level: int, cost: int):
	emit_signal("level_up_selected", target_level, cost)

func _on_level_up_cancelled():
	emit_signal("level_up_selected", 0, 0)

func _on_debug_mode_changed(enabled: bool):
	debug_mode = enabled
	if debug_mode:
		print("デバッグモード: ON")
	else:
		print("デバッグモード: OFF")

# デバッグ入力を処理
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			toggle_debug_mode()
