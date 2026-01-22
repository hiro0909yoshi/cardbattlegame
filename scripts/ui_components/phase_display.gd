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

## フェーズラベルを作成（大きめ半透明スタイル）
func create_phase_label():
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	
	# フォントサイズ2.5倍（34 → 85）、半透明
	phase_label.add_theme_font_size_override("font_size", 85)
	phase_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))  # 白、薄め
	
	# 画面幅いっぱいに広げて中央揃え
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.set_anchors_preset(Control.PRESET_TOP_WIDE)  # 上部全幅
	phase_label.offset_top = 150
	phase_label.offset_bottom = 250
	
	# マウス入力を透過（クリック不可）
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 背面レイヤーに配置（インフォパネル等より後ろ）
	var background_layer = CanvasLayer.new()
	background_layer.name = "PhaseDisplayLayer"
	background_layer.layer = -1  # UILayer(0)より後ろ
	ui_layer.get_parent().add_child(background_layer)
	background_layer.add_child(phase_label)

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
