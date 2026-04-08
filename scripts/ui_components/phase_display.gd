extends Node
class_name PhaseDisplay

const GC = preload("res://scripts/game_constants.gd")

# PhaseDisplay - フェーズ表示UI管理
# UIManagerから分離されたフェーズ表示関連のUI処理


# UI要素
var phase_label: Label = null
var current_dice_label: Label = null

# アクション指示用UI
var action_prompt_panel: PanelContainer = null
var action_prompt_label: Label = null
var action_prompt_layer: CanvasLayer = null
var action_prompt_center_container: Control = null  # 中央配置用
var action_prompt_right_container: Control = null  # 右側配置用

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
	phase_label.add_theme_font_size_override("font_size", 44)
	phase_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))  # 白、薄め
	
	# 画面幅いっぱいに広げて中央揃え
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.set_anchors_preset(Control.PRESET_TOP_WIDE)  # 上部全幅
	phase_label.offset_top = 78
	phase_label.offset_bottom = 130
	
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

## ダイス結果を表示（位置調整）- 旧版（互換性のため残す）
func show_dice_result(value: int):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# 新しいダイスラベルを作成
	current_dice_label = Label.new()
	current_dice_label.text = "🎲 " + str(value)
	current_dice_label.add_theme_font_size_override("font_size", 35)
	current_dice_label.position = Vector2(275, 47)
	current_dice_label.add_theme_color_override("font_color", Color(1, 1, 0))
	current_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	
	ui_layer.add_child(current_dice_label)
	
	# 2秒後に自動的に消す
	await get_tree().create_timer(2.0).timeout
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
		current_dice_label = null

## ダイス結果を画面中央に大きく表示（1.5秒）
var _big_dice_label: Label = null

func show_big_dice_result(value: int, duration: float = 1.5):
	# 既存のラベルがあれば削除
	if _big_dice_label and is_instance_valid(_big_dice_label):
		_big_dice_label.queue_free()
	
	# 新しいラベルを作成
	_big_dice_label = Label.new()
	_big_dice_label.text = str(value)
	_big_dice_label.add_theme_font_size_override("font_size", 104)
	_big_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 画面中央に配置
	_big_dice_label.set_anchors_preset(Control.PRESET_CENTER)
	_big_dice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big_dice_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 白い文字に黒いアウトライン
	_big_dice_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_big_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_big_dice_label.add_theme_constant_override("shadow_offset_x", 4)
	_big_dice_label.add_theme_constant_override("shadow_offset_y", 4)
	_big_dice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	ui_layer.add_child(_big_dice_label)
	
	# 指定時間後に自動的に消す
	await get_tree().create_timer(duration).timeout
	if _big_dice_label and is_instance_valid(_big_dice_label):
		_big_dice_label.queue_free()
		_big_dice_label = null

## 2個ダイス結果を表示
## dice1: 0-5 (0は特殊マーク)
## dice2: 0,2-6 (0は特殊マーク)
## total: 合計値（両方0なら12）
func show_dice_result_double(dice1: int, dice2: int, total: int):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# ダイス目の表示文字列を作成
	var dice1_str = "★" if dice1 == 0 else str(dice1)
	var dice2_str = "★" if dice2 == 0 else str(dice2)
	
	# 両方0の場合は特殊表示
	var display_text: String
	if dice1 == 0 and dice2 == 0:
		display_text = "🎲 %s + 🎲 %s = 12!" % [dice1_str, dice2_str]
	else:
		display_text = "🎲 %s + 🎲 %s = %d" % [dice1_str, dice2_str, total]
	
	# 新しいダイスラベルを作成
	current_dice_label = Label.new()
	current_dice_label.text = display_text
	current_dice_label.add_theme_font_size_override("font_size", 31)

	# 画面中央上部に配置
	current_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_dice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	current_dice_label.offset_top = 42
	current_dice_label.offset_bottom = 83

	# 両方0の場合はゴールド色、それ以外は黄色
	if dice1 == 0 and dice2 == 0:
		current_dice_label.add_theme_color_override("font_color", Color(1, 0.84, 0))  # ゴールド
	else:
		current_dice_label.add_theme_color_override("font_color", Color(1, 1, 0))  # 黄色
	
	current_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	current_dice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	ui_layer.add_child(current_dice_label)
	
	# 2秒後に自動的に消す
	await get_tree().create_timer(2.0).timeout
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
		current_dice_label = null

## 3個ダイス結果を表示（フライ効果用）
## dice1: 0-5 (0は★)
## dice2: 0,2-6 (0は★)
## dice3: 1-6 (通常ダイス)
## total: 合計値（dice1とdice2が両方0なら18）
func show_dice_result_triple(dice1: int, dice2: int, dice3: int, total: int):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# ダイス目の表示文字列を作成
	var dice1_str = "★" if dice1 == 0 else str(dice1)
	var dice2_str = "★" if dice2 == 0 else str(dice2)
	var dice3_str = str(dice3)
	
	# dice1とdice2が両方0の場合は特殊表示（12 + dice3）
	var display_text: String
	if dice1 == 0 and dice2 == 0:
		display_text = "🎲 %s + 🎲 %s + 🎲 %s = %d!" % [dice1_str, dice2_str, dice3_str, total]
	else:
		display_text = "🎲 %s + 🎲 %s + 🎲 %s = %d" % [dice1_str, dice2_str, dice3_str, total]
	
	# 新しいダイスラベルを作成
	current_dice_label = Label.new()
	current_dice_label.text = display_text
	current_dice_label.add_theme_font_size_override("font_size", 29)

	# 画面中央上部に配置
	current_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_dice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	current_dice_label.offset_top = 42
	current_dice_label.offset_bottom = 83
	
	# dice1とdice2が両方0の場合はゴールド色、それ以外は黄色
	if dice1 == 0 and dice2 == 0:
		current_dice_label.add_theme_color_override("font_color", Color(1, 0.84, 0))  # ゴールド
	else:
		current_dice_label.add_theme_color_override("font_color", Color(1, 1, 0))  # 黄色
	
	current_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	current_dice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	ui_layer.add_child(current_dice_label)
	
	# 2秒後に自動的に消す
	await get_tree().create_timer(2.0).timeout
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
		current_dice_label = null

## ダイス範囲刻印用の結果表示（ジャーニーなど）
func show_dice_result_range(curse_name: String, total: int):
	# 既存のダイスラベルがあれば削除
	if current_dice_label and is_instance_valid(current_dice_label):
		current_dice_label.queue_free()
	
	# 刻印名と結果のみ表示
	var display_text = "🎲 %s → %d" % [curse_name, total]
	
	# 新しいダイスラベルを作成
	current_dice_label = Label.new()
	current_dice_label.text = display_text
	current_dice_label.add_theme_font_size_override("font_size", GC.FONT_SIZE_ACTION_PROMPT)
	
	# 画面中央上部に配置
	current_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_dice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	current_dice_label.offset_top = 80
	current_dice_label.offset_bottom = 160
	
	# 紫色（刻印効果を示す）
	current_dice_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	current_dice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	current_dice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
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

# ========================================
# アクション指示表示（手札調整など）
# ========================================

## アクション指示用のUIを作成
func _create_action_prompt_ui():
	if action_prompt_layer:
		return  # 既に作成済み
	
	# 専用レイヤー（通常UIより前面）
	action_prompt_layer = CanvasLayer.new()
	action_prompt_layer.name = "ActionPromptLayer"
	action_prompt_layer.layer = 50
	ui_layer.get_parent().add_child(action_prompt_layer)
	
	# 中央配置用コンテナ（CenterContainerで確実に水平中央）
	action_prompt_center_container = CenterContainer.new()
	action_prompt_center_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	action_prompt_center_container.offset_top = 10
	action_prompt_center_container.offset_bottom = 70
	action_prompt_center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_prompt_layer.add_child(action_prompt_center_container)
	
	# 右側配置用コンテナ（CenterContainerで中央配置）
	action_prompt_right_container = CenterContainer.new()
	action_prompt_right_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	action_prompt_right_container.offset_top = 10
	action_prompt_right_container.offset_bottom = 70
	action_prompt_right_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_prompt_layer.add_child(action_prompt_right_container)
	
	action_prompt_panel = PanelContainer.new()
	action_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_prompt_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# パネルのスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	action_prompt_panel.add_theme_stylebox_override("panel", style)
	
	# ラベル（自動サイズ、折り返しなし）
	action_prompt_label = Label.new()
	action_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_prompt_label.add_theme_font_size_override("font_size", GC.FONT_SIZE_ACTION_PROMPT)
	action_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	
	action_prompt_panel.add_child(action_prompt_label)
	# 初期は中央コンテナに配置
	action_prompt_center_container.add_child(action_prompt_panel)
	
	# 初期状態は非表示
	action_prompt_panel.visible = false

## アクション指示を表示
## position: "center"（デフォルト）または "right"
func show_action_prompt(message: String, position: String = "center"):
	_create_action_prompt_ui()

	# パネルサイズをリセット（前のメッセージのサイズが残らないように）
	if action_prompt_panel:
		action_prompt_panel.reset_size()

	if action_prompt_label:
		action_prompt_label.text = message
	
	# パネルを適切なコンテナに移動
	if action_prompt_panel:
		var current_parent = action_prompt_panel.get_parent()
		var target_parent = action_prompt_center_container if position == "center" else action_prompt_right_container
		
		if current_parent != target_parent:
			current_parent.remove_child(action_prompt_panel)
			target_parent.add_child(action_prompt_panel)
		
		action_prompt_panel.visible = true
	
	# フェーズラベルは薄く（中央表示時のみ）
	if phase_label and position == "center":
		phase_label.modulate.a = 0.1


## アクション指示を非表示
func hide_action_prompt():
	if action_prompt_panel:
		action_prompt_panel.visible = false
	
	# フェーズラベルを元に戻す
	if phase_label:
		phase_label.modulate.a = 1.0

## 現在のアクションプロンプトテキストを取得
func get_current_action_prompt() -> String:
	if action_prompt_label and action_prompt_panel and action_prompt_panel.visible:
		return action_prompt_label.text
	return ""

# ========================================
# エラー・警告トースト表示（パターン3）
# ========================================

var toast_panel: PanelContainer = null
var toast_label: Label = null
var toast_layer: CanvasLayer = null
var toast_timer: Timer = null

## トースト用UIを作成
func _create_toast_ui():
	if toast_layer:
		return  # 既に作成済み
	
	# 専用レイヤー（アクション指示より前面）
	toast_layer = CanvasLayer.new()
	toast_layer.name = "ToastLayer"
	toast_layer.layer = 55
	ui_layer.get_parent().add_child(toast_layer)
	
	# CenterContainerで囲むことで確実に中央配置
	var toast_center = CenterContainer.new()
	toast_center.name = "ToastCenter"
	toast_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_center.offset_top = 150
	toast_center.offset_bottom = 250
	toast_layer.add_child(toast_center)
	
	# パネルコンテナ（文字数に応じて自動サイズ）
	toast_panel = PanelContainer.new()
	toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# パネルのスタイル（オレンジ/赤枠）
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.1, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.5, 0.2, 0.9)  # オレンジ
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	toast_panel.add_theme_stylebox_override("panel", style)
	
	# ラベル（自動サイズ、折り返しなし）
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", GC.FONT_SIZE_ACTION_PROMPT)
	toast_label.add_theme_color_override("font_color", Color(1, 0.9, 0.8, 1))
	
	toast_panel.add_child(toast_label)
	toast_center.add_child(toast_panel)
	
	# タイマー
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(_on_toast_timeout)
	add_child(toast_timer)
	
	# 初期状態は非表示
	toast_panel.visible = false

## エラー・警告トーストを表示（数秒で自動的に消える）
func show_toast(message: String, duration: float = 2.0):
	_create_toast_ui()
	
	if toast_label:
		toast_label.text = message
	if toast_panel:
		toast_panel.visible = true
	
	# タイマー開始
	if toast_timer:
		toast_timer.stop()
		toast_timer.wait_time = duration
		toast_timer.start()

## トーストを非表示
func hide_toast():
	if toast_panel:
		toast_panel.visible = false

## トーストタイマー完了
func _on_toast_timeout():
	hide_toast()
