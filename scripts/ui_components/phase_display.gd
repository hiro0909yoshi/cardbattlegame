# PhaseDisplay - フェーズ表示UI管理
# UIManagerから分離されたフェーズ表示関連のUI処理
class_name PhaseDisplay
extends Node

# UI要素
var phase_label: Label = null
var current_dice_label: Label = null

# 親UIレイヤー
var ui_layer: Node = null

func _ready():
	pass

## 初期化
func initialize(ui_parent: Node):
	ui_layer = ui_parent
	create_phase_label()

## フェーズラベルを作成 ※1.4倍
func create_phase_label():
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	
	var viewport_size = get_viewport().get_visible_rect().size
	var player_panel_bottom = 28 + 336 + 28  # パネルY + パネル高さ(336) + マージン ※1.4倍
	
	phase_label.position = Vector2(viewport_size.x / 2 - 210, player_panel_bottom)
	phase_label.add_theme_font_size_override("font_size", 34)
	ui_layer.add_child(phase_label)

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
	
	# 新しいダイスラベルを作成
	current_dice_label = Label.new()
	current_dice_label.text = "🎲 " + str(value)
	current_dice_label.add_theme_font_size_override("font_size", 67)  # 1.4倍
	current_dice_label.position = Vector2(530, 90)
	current_dice_label.add_theme_color_override("font_color", Color(1, 1, 0))
	current_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	
	ui_layer.add_child(current_dice_label)
	
	# 2秒後に自動的に消す
	await get_tree().create_timer(2.0).timeout
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
		current_dice_label = null

## フェーズラベルのテキストを直接設定
func set_phase_text(text: String):
	if phase_label:
		phase_label.text = text
