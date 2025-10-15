# PhaseDisplay - フェーズ表示とサイコロUI管理
# UIManagerから分離されたフェーズ表示関連のUI処理
class_name PhaseDisplay
extends Node

# シグナル
signal dice_button_pressed()

# UI要素
var phase_label: Label = null
var dice_button: Button = null
var current_dice_label: Label = null

# 親UIレイヤー
var ui_layer: Node = null

func _ready():
	pass

## 初期化
func initialize(ui_parent: Node):
	ui_layer = ui_parent
	create_phase_label()
	create_dice_button()
	print("[PhaseDisplay] 初期化完了")

## フェーズラベルを作成
func create_phase_label():
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	
	var viewport_size = get_viewport().get_visible_rect().size
	var player_panel_bottom = 20 + 240 + 20  # パネルY + パネル高さ(240) + マージン
	
	# サイコロボタンの少し上に配置
	phase_label.position = Vector2(viewport_size.x / 2 - 150, player_panel_bottom)
	phase_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(phase_label)

## サイコロボタンを作成
func create_dice_button():
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
	
	ui_layer.add_child(dice_button)

## フェーズ表示を更新
func update_phase_display(phase: int):
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

## ダイス結果を表示（位置調整）
func show_dice_result(value: int):
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
	
	ui_layer.add_child(current_dice_label)
	
	# 2秒後に自動的に消す
	await get_tree().create_timer(2.0).timeout
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
		current_dice_label = null

## サイコロボタンの有効/無効
func set_dice_button_enabled(enabled: bool):
	if not dice_button:
		return
		
	dice_button.disabled = not enabled
	
	# 有効時は目立たせる
	if enabled:
		dice_button.modulate = Color(1, 1, 1, 1)
	else:
		dice_button.modulate = Color(0.7, 0.7, 0.7, 0.8)

## フェーズラベルのテキストを直接設定
func set_phase_text(text: String):
	if phase_label:
		phase_label.text = text

## シグナルハンドラ
func _on_dice_button_pressed():
	dice_button_pressed.emit()
