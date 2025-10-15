extends Node
class_name UIManager

# UI要素の統括管理システム（3D対応版）

signal dice_button_pressed()
signal pass_button_pressed()
signal card_selected(card_index: int)
signal level_up_selected(target_level: int, cost: int)
signal land_command_button_pressed()  # Phase 1-A: 領地コマンドボタン

# UIコンポーネント（動的ロード用）
var player_info_panel = null
var card_selection_ui = null
var level_up_ui = null
var debug_panel = null

# 基本UI要素
var dice_button: Button
var phase_label: Label
var current_dice_label: Label = null

# システム参照（型指定なし - 3D対応のため）
var card_system_ref = null
var player_system_ref = null
var board_system_ref = null  # BoardSystem3Dも格納可能
var game_flow_manager_ref = null  # GameFlowManagerの参照

# デバッグモード
var debug_mode = false

# 手札UI管理
var hand_container: Control = null
var card_scene = preload("res://scenes/Card.tscn")
var player_card_nodes = {}  # player_id -> [card_nodes]

# カード表示定数
const CARD_WIDTH = 290
const CARD_HEIGHT = 390
const CARD_SPACING = 30

func _ready():
	# UIコンポーネントを動的にロードして作成
	var PlayerInfoPanelClass = load("res://scripts/ui_components/player_info_panel.gd")
	var CardSelectionUIClass = load("res://scripts/ui_components/card_selection_ui.gd")
	var LevelUpUIClass = load("res://scripts/ui_components/level_up_ui.gd")
	var DebugPanelClass = load("res://scripts/ui_components/debug_panel.gd")
	
	if PlayerInfoPanelClass:
		player_info_panel = PlayerInfoPanelClass.new()
		add_child(player_info_panel)
	
	if CardSelectionUIClass:
		card_selection_ui = CardSelectionUIClass.new()
		add_child(card_selection_ui)
	
	if LevelUpUIClass:
		level_up_ui = LevelUpUIClass.new()
		add_child(level_up_ui)
	
	if DebugPanelClass:
		debug_panel = DebugPanelClass.new()
		add_child(debug_panel)
	
	# シグナル接続
	connect_ui_signals()

# UIコンポーネントのシグナルを接続
func connect_ui_signals():
	# カード選択UI
	if card_selection_ui:
		card_selection_ui.card_selected.connect(_on_card_ui_selected)
		card_selection_ui.selection_cancelled.connect(_on_selection_cancelled)
	
	# レベルアップUI
	if level_up_ui:
		level_up_ui.level_selected.connect(_on_level_ui_selected)
		level_up_ui.selection_cancelled.connect(_on_level_up_cancelled)
	
	# デバッグパネル
	if debug_panel:
		debug_panel.debug_mode_changed.connect(_on_debug_mode_changed)

# UIを作成
func create_ui(parent: Node):
	# システム参照を取得（既に設定されている場合はスキップ）
	if not card_system_ref and parent.has_node("CardSystem"):
		card_system_ref = parent.get_node("CardSystem")
	if not player_system_ref and parent.has_node("PlayerSystem"):
		player_system_ref = parent.get_node("PlayerSystem")
	# board_system_ref は BoardSystem3D から設定される
	
	# UIレイヤー（CanvasLayer）を作成
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	parent.add_child(ui_layer)
	
	# 基本UI要素を作成（UIレイヤーの子として）
	create_basic_ui(ui_layer)
	
	# 各コンポーネントを初期化（3D版対応）
	if player_info_panel and player_info_panel.has_method("initialize"):
		print("PlayerInfoPanel初期化開始")
		# 3D版の場合、board_systemは渡さずに初期化
		player_info_panel.initialize(ui_layer, player_system_ref, null)
		# 3D版のboard_systemを手動で設定（プロパティとして直接設定）
		player_info_panel.set("board_system_ref", board_system_ref)
		print("PlayerInfoPanel初期化完了")
		# 初期化後にパネルの状態を確認
		if player_info_panel.has_method("update_all_panels"):
			print("update_all_panels呼び出し")
			player_info_panel.update_all_panels()
			
	if card_selection_ui and card_selection_ui.has_method("initialize"):
		card_selection_ui.initialize(ui_layer, card_system_ref, phase_label, self)
		# GameFlowManager参照を設定
		card_selection_ui.game_flow_manager_ref = game_flow_manager_ref
		
	if level_up_ui and level_up_ui.has_method("initialize"):
		level_up_ui.initialize(ui_layer, null, phase_label)  # board_systemはnullで初期化
		level_up_ui.set("board_system_ref", board_system_ref)  # set()で設定
		
	if debug_panel and debug_panel.has_method("initialize"):
		debug_panel.initialize(ui_layer, card_system_ref, null, player_system_ref)  # board_systemはnullで初期化
		debug_panel.set("board_system_ref", board_system_ref)  # set()で設定

# 基本UI要素を作成（サイコロボタン位置修正）
func create_basic_ui(parent: Node):
	# フェーズ表示（画面中央上部、サイコロボタンの上）
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	
	var viewport_size_phase = get_viewport().get_visible_rect().size
	var player_panel_bottom_phase = 20 + 240 + 20  # パネルY + パネル高さ(240) + マージン
	
	# サイコロボタンの少し上に配置
	phase_label.position = Vector2(viewport_size_phase.x / 2 - 150, player_panel_bottom_phase)
	phase_label.add_theme_font_size_override("font_size", 24)
	parent.add_child(phase_label)
	
	# サイコロボタン（プレイヤー情報パネルの下、画面中央）
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	
	var viewport_size = get_viewport().get_visible_rect().size
	var button_width = 200
	var button_height = 60
	var player_panel_bottom = 20 + 240 + 70  # パネルY + パネル高さ(240) + マージン(70)
	
	dice_button.position = Vector2((viewport_size.x - button_width) / 2, player_panel_bottom)
	dice_button.size = Vector2(button_width, button_height)
	dice_button.disabled = true
	dice_button.pressed.connect(_on_dice_button_pressed)
	
	# サイコロボタンのスタイルを設定
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.5, 0.8, 0.9)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(1, 1, 1, 1)
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	dice_button.add_theme_stylebox_override("normal", button_style)
	
	# ホバー時のスタイル
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.6, 0.9, 1.0)
	dice_button.add_theme_stylebox_override("hover", hover_style)
	
	# 押下時のスタイル
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.4, 0.7, 1.0)
	dice_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# 無効時のスタイル
	var disabled_style = button_style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	dice_button.add_theme_stylebox_override("disabled", disabled_style)
	
	# フォントサイズを大きく
	dice_button.add_theme_font_size_override("font_size", 18)
	
	parent.add_child(dice_button)
	
	# Phase 1-A: 領地コマンドボタンを作成
	create_land_command_button(parent)

# === プレイヤー情報パネル関連 ===
func update_player_info_panels():
	if player_info_panel and player_info_panel.has_method("update_all_panels"):
		player_info_panel.update_all_panels()

# === カード選択UI関連 ===
func show_card_selection_ui(current_player):
	if card_selection_ui and card_selection_ui.has_method("show_selection"):
		card_selection_ui.show_selection(current_player, "summon")

# モード指定でカード選択UIを表示
func show_card_selection_ui_mode(current_player, mode: String):
	if card_selection_ui and card_selection_ui.has_method("show_selection"):
		card_selection_ui.show_selection(current_player, mode)

func hide_card_selection_ui():
	if card_selection_ui and card_selection_ui.has_method("hide_selection"):
		card_selection_ui.hide_selection()

# カードボタンが押された（card.gdから呼ばれる）
func _on_card_button_pressed(card_index: int):
	if card_selection_ui and card_selection_ui.has_method("on_card_selected"):
		card_selection_ui.on_card_selected(card_index)

# === レベルアップUI関連 ===
func show_level_up_ui(tile_info: Dictionary, current_magic: int):
	if level_up_ui and level_up_ui.has_method("show_level_up_selection"):
		level_up_ui.show_level_up_selection(tile_info, current_magic)

func hide_level_up_ui():
	if level_up_ui and level_up_ui.has_method("hide_selection"):
		level_up_ui.hide_selection()

# === デバッグパネル関連 ===
func toggle_debug_mode():
	if debug_panel and debug_panel.has_method("toggle_visibility"):
		debug_panel.toggle_visibility()
		if debug_panel.has_method("is_debug_visible"):
			debug_mode = debug_panel.is_debug_visible()

func update_cpu_hand_display(player_id: int):
	if debug_panel and debug_panel.has_method("update_cpu_hand"):
		debug_panel.update_cpu_hand(player_id)

# === 基本UI操作 ===
func update_ui(current_player, current_phase):
	# プレイヤー情報パネルを更新
	update_player_info_panels()
	
	# 現在のターンプレイヤーを設定
	if current_player and player_info_panel and player_info_panel.has_method("set_current_turn"):
		player_info_panel.set_current_turn(current_player.id)
	
	# フェーズ表示を更新
	update_phase_display(current_phase)

# フェーズ表示を更新
func update_phase_display(phase):
	if not phase_label:
		return
		
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

# ダイス結果を表示（位置調整）
func show_dice_result(value: int, parent: Node):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# 新しいダイスラベルを作成（サイコロボタンの近くに表示）
	current_dice_label = Label.new()
	current_dice_label.text = "🎲 " + str(value)
	current_dice_label.add_theme_font_size_override("font_size", 48)
	current_dice_label.position = Vector2(530, 90)  # サイコロボタンの右横
	current_dice_label.add_theme_color_override("font_color", Color(1, 1, 0))
	current_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	
	# UILayerがある場合はそこに追加
	if parent.has_node("UILayer"):
		parent.get_node("UILayer").add_child(current_dice_label)
	else:
		parent.add_child(current_dice_label)
	
	# 2秒後に自動的に消す
	await get_tree().create_timer(2.0).timeout
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
		current_dice_label = null

# サイコロボタンの有効/無効
func set_dice_button_enabled(enabled: bool):
	if not dice_button:
		return
		
	dice_button.disabled = not enabled
	
	# 有効時は目立たせる
	if enabled:
		dice_button.modulate = Color(1, 1, 1, 1)
	else:
		dice_button.modulate = Color(0.7, 0.7, 0.7, 0.8)

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

func _on_land_command_button_pressed():
	print("[UIManager] 領地コマンドボタンがクリックされました！")
	emit_signal("land_command_button_pressed")

func _on_cancel_land_command_button_pressed():
	print("[UIManager] キャンセルボタンがクリックされました！")
	# GameFlowManagerのland_command_handlerに通知
	if game_flow_manager_ref and game_flow_manager_ref.land_command_handler:
		game_flow_manager_ref.land_command_handler.cancel()

# === 手札UI管理 ===

# 手札コンテナを初期化
func initialize_hand_container(ui_layer: Node):
	hand_container = Control.new()
	hand_container.name = "Hand"
	hand_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # マウス入力を透過させる
	ui_layer.add_child(hand_container)
	
	for i in range(4):
		player_card_nodes[i] = []
	
	print("手札コンテナ初期化完了")

# CardSystemのシグナルに接続
func connect_card_system_signals():
	if not card_system_ref:
		return
	
	if card_system_ref.has_signal("card_drawn"):
		card_system_ref.card_drawn.connect(_on_card_drawn)
	if card_system_ref.has_signal("card_used"):
		card_system_ref.card_used.connect(_on_card_used)
	if card_system_ref.has_signal("hand_updated"):
		card_system_ref.hand_updated.connect(_on_hand_updated)

# カードが引かれた時の処理
func _on_card_drawn(_card_data: Dictionary):
	pass

# カードが使用された時の処理
func _on_card_used(_card_data: Dictionary):
	pass

# 手札が更新された時の処理
func _on_hand_updated():
	# 現在のターンプレイヤーの手札を表示
	if player_system_ref:
		var current_player = player_system_ref.get_current_player()
		if current_player:
			update_hand_display(current_player.id)

# 手札表示を更新
func update_hand_display(player_id: int):
	
	if not card_system_ref or not hand_container:
		return
	
	print("[UIManager] 手札表示を更新中...")
	
	# 全プレイヤーの既存カードノードを削除（ターン切り替え時に前のプレイヤーの手札を消す）
	for pid in player_card_nodes.keys():
		for card_node in player_card_nodes[pid]:
			if is_instance_valid(card_node):
				card_node.queue_free()
		player_card_nodes[pid].clear()
	
	# カードデータを取得
	var hand_data = card_system_ref.get_all_cards_for_player(player_id)
	
	# カードノードを生成
	for i in range(hand_data.size()):
		var card_data = hand_data[i]
		var card_node = create_card_node(card_data, i)
		if card_node:
			player_card_nodes[player_id].append(card_node)
	
	# 全カードを中央配置
	rearrange_hand(player_id)

# カードノードを生成
func create_card_node(card_data: Dictionary, _index: int) -> Node:
	if not is_instance_valid(hand_container):
		print("ERROR: 手札コンテナが無効です")
		return null
	
	if not card_scene:
		print("ERROR: card_sceneがロードされていません")
		return null
		
	var card = card_scene.instantiate()
	if not card:
		print("ERROR: カードのインスタンス化に失敗")
		return null
	
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		
	hand_container.add_child(card)
	
	# 位置は後でrearrange_hand()で設定するので仮配置
	var viewport_size = get_viewport().get_visible_rect().size
	var card_y = viewport_size.y - CARD_HEIGHT - 20
	card.position = Vector2(0, card_y)
	
	if card.has_method("load_card_data"):
		card.load_card_data(card_data.id)
	else:
		print("WARNING: カードにload_card_dataメソッドがありません")
	
	# 手札表示用カードは初期状態で選択不可（CardSelectionUIが必要に応じて有効化する）
	card.is_selectable = false
	
	return card

# 手札を再配置（動的スケール対応）
func rearrange_hand(player_id: int):
	var card_nodes = player_card_nodes[player_id]
	if card_nodes.is_empty():
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var hand_size = card_nodes.size()
	
	# CardUIHelperを使用してレイアウト計算
	var layout = CardUIHelper.calculate_card_layout(viewport_size, hand_size)
	
	# カードを配置
	for i in range(card_nodes.size()):
		var card = card_nodes[i]
		if card and is_instance_valid(card):
			card.size = Vector2(layout.card_width, layout.card_height)
			card.position = Vector2(layout.start_x + i * (layout.card_width + layout.spacing), layout.card_y)
			if card.has_method("set_selectable"):
				card.card_index = i

# デバッグ入力を処理
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			toggle_debug_mode()

# ============================================
# Phase 1-A: 領地コマンドUI
# ============================================

var land_command_button: Button = null
var cancel_land_command_button: Button = null  # Phase 1-A: キャンセルボタン

# 領地コマンドボタンを作成（create_basic_ui内から呼ばれる想定）
func create_land_command_button(parent: Node):
	print("[UIManager] create_land_command_button()開始")
	print("[UIManager] parent is null? ", parent == null)
	
	land_command_button = Button.new()
	land_command_button.text = "📍領地コマンド"
	
	# CardUIHelperを使用してレイアウト計算（カードUIと連動）
	var viewport_size = get_viewport().get_visible_rect().size
	var layout = CardUIHelper.calculate_card_layout(viewport_size, 5)  # 5枚想定
	
	# 左側10%エリアにボタンを配置
	var button_width = viewport_size.x * 0.08  # 左側エリアの80%
	var button_height = 70
	var button_x = viewport_size.x * 0.01  # 左から1%
	var button_y = layout.card_y  # カードと同じ高さ
	
	land_command_button.position = Vector2(button_x, button_y)
	land_command_button.size = Vector2(button_width, button_height)
	
	land_command_button.disabled = false
	land_command_button.visible = false  # 初期は非表示
	land_command_button.z_index = 100  # 最前面に表示（重要！）
	land_command_button.mouse_filter = Control.MOUSE_FILTER_STOP  # マウス入力を受け付ける
	land_command_button.pressed.connect(_on_land_command_button_pressed)  # Phase 1-A: シグナル接続
	
	# スタイル設定
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.7, 0.3, 0.9)  # 緑系
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(1, 1, 1, 1)
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	land_command_button.add_theme_stylebox_override("normal", button_style)
	
	# ホバー時
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.8, 0.4, 1.0)
	land_command_button.add_theme_stylebox_override("hover", hover_style)
	
	# 押下時
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.6, 0.2, 1.0)
	land_command_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# フォントサイズ（ボタン高さに応じて調整）
	var font_size = int(button_height * 0.25)  # ボタン高さの25%
	land_command_button.add_theme_font_size_override("font_size", font_size)
	
	parent.add_child(land_command_button)
	
	print("[UIManager] 領地コマンドボタン作成完了")
	print("[UIManager] ボタンが正常に作成されました: ", land_command_button != null)
	print("[UIManager] ボタンの親: ", land_command_button.get_parent().name if land_command_button.get_parent() else "なし")
	
	# キャンセルボタンも作成
	create_cancel_land_command_button(parent)

# キャンセルボタンを作成
func create_cancel_land_command_button(parent: Node):
	cancel_land_command_button = Button.new()
	cancel_land_command_button.text = "✕ 閉じる"
	
	# 領地コマンドボタンの下に配置（同じレイアウト計算を使用）
	var viewport_size_cancel = get_viewport().get_visible_rect().size
	var layout_cancel = CardUIHelper.calculate_card_layout(viewport_size_cancel, 5)
	
	var button_width_cancel = viewport_size_cancel.x * 0.08
	var button_height_cancel = 70
	var button_x_cancel = viewport_size_cancel.x * 0.01
	var button_y_cancel = layout_cancel.card_y + button_height_cancel + 10  # 領地ボタンの下、10pxマージン
	
	cancel_land_command_button.position = Vector2(button_x_cancel, button_y_cancel)
	cancel_land_command_button.size = Vector2(button_width_cancel, button_height_cancel)
	
	cancel_land_command_button.disabled = false
	cancel_land_command_button.visible = false  # 初期は非表示
	cancel_land_command_button.z_index = 100  # 最前面に表示
	cancel_land_command_button.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_land_command_button.pressed.connect(_on_cancel_land_command_button_pressed)
	
	# スタイル設定（赤系）
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.8, 0.2, 0.2, 0.9)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(1, 1, 1, 1)
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	cancel_land_command_button.add_theme_stylebox_override("normal", button_style)
	
	# ホバー時
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.9, 0.3, 0.3, 1.0)
	cancel_land_command_button.add_theme_stylebox_override("hover", hover_style)
	
	# 押下時
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.7, 0.1, 0.1, 1.0)
	cancel_land_command_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# フォントサイズ（ボタン高さに応じて調整）
	var font_size_cancel = int(button_height_cancel * 0.25)
	cancel_land_command_button.add_theme_font_size_override("font_size", font_size_cancel)
	
	parent.add_child(cancel_land_command_button)
	
	print("[UIManager] キャンセルボタン作成完了")

# 領地コマンドボタンの表示/非表示
func show_land_command_button():
	print("[UIManager] show_land_command_button()が呼ばれました")
	print("[UIManager] land_command_button is null? ", land_command_button == null)
	
	if land_command_button:
		land_command_button.visible = true
		land_command_button.disabled = false
		print("[UIManager] 領地コマンドボタン表示")
		print("[UIManager] ボタン位置: ", land_command_button.position, " サイズ: ", land_command_button.size, " z_index: ", land_command_button.z_index)
	else:
		print("[UIManager] エラー: land_command_buttonがnullです！")

func hide_land_command_button():
	if land_command_button:
		land_command_button.visible = false
		print("[UIManager] 領地コマンドボタン非表示")
	# キャンセルボタンも非表示
	if cancel_land_command_button:
		cancel_land_command_button.visible = false

# キャンセルボタンの表示/非表示
func show_cancel_button():
	if cancel_land_command_button:
		cancel_land_command_button.visible = true
		print("[UIManager] キャンセルボタン表示")

func hide_cancel_button():
	if cancel_land_command_button:
		cancel_land_command_button.visible = false
		print("[UIManager] キャンセルボタン非表示")

# 土地選択モードを表示
func show_land_selection_mode(owned_lands: Array):
	print("[UIManager] 土地選択モード表示: ", owned_lands)
	if phase_label:
		var land_list = ""
		for i in range(owned_lands.size()):
			land_list += str(i + 1) + ":" + str(owned_lands[i]) + " "
		phase_label.text = "土地を選択（数字キー） " + land_list
	
	# キャンセルボタンを表示
	show_cancel_button()

# アクション選択UIを表示
func show_action_selection_ui(tile_index: int):
	print("[UIManager] アクション選択UI表示: tile ", tile_index)
	if phase_label:
		phase_label.text = "L:レベルアップ M:移動 S:交換 C:戻る"

# 領地コマンドUIを非表示
func hide_land_command_ui():
	print("[UIManager] 領地コマンドUI非表示")
	# Phase 1-A: 簡易実装
	if phase_label:
		phase_label.text = "召喚フェーズ"
	
	# キャンセルボタンを非表示
	hide_cancel_button()
