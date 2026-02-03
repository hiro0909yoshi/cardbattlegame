extends Control
class_name GlobalCommentUI
const GC = preload("res://scripts/game_constants.gd")


## グローバルコメント表示UI
## スペル効果、周回ボーナス、バトル結果など様々な場面で使用
## 
## 使用方法:
## クリック待ち: await ui_manager.global_comment_ui.show_and_wait("メッセージ")

@onready var panel: PanelContainer
@onready var label: RichTextLabel

var display_duration: float = 2.0
var fade_duration: float = 0.3
var current_tween: Tween

## クリック待ち用
signal click_confirmed
var waiting_for_click: bool = false
var click_wait_timeout: float = 7.0
var timeout_timer: Timer = null

## CPU自動進行用
var game_flow_manager_ref = null
var cpu_auto_advance_delay: float = 0.5  # CPUの場合の自動進行遅延（秒）

## チュートリアルモード用
var is_tutorial_style: bool = false

func _ready():
	_setup_ui()

func _setup_ui():
	# 自身を全画面に設定（マウス入力は透過）
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 背景パネル
	panel = PanelContainer.new()
	panel.name = "CommentPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# サイズを内容に合わせる
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	
	# RichTextLabel
	label = RichTextLabel.new()
	label.name = "CommentLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", GC.FONT_SIZE_COMMENT)
	label.add_theme_color_override("default_color", Color.WHITE)
	# ラベルのサイズも内容に合わせる
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size = Vector2.ZERO
	
	panel.add_child(label)
	add_child(panel)
	
	visible = false

# ============================================
# 表示のみモード（待機なし）
# ============================================

## メッセージを表示（クリック待ちなし）
## 外部でボタン選択などを行う場合に使用
func show_message(message: String) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	var text = "[center]" + message + "[/center]"
	label.text = text
	
	modulate.a = 1.0
	visible = true
	waiting_for_click = false
	
	if is_tutorial_style:
		_position_panel_top()
	else:
		_center_panel()

## メッセージを非表示
func hide_message() -> void:
	visible = false
	waiting_for_click = false

# ============================================
# クリック待ちモード（スペル効果等）
# ============================================

## 通知を表示してクリック待ち（await可能）
## CPUターンの場合は自動で進行する
## この関数をawaitすると、クリックまたは自動進行まで待機する
## player_id: 明示的にプレイヤーIDを指定する場合（-1の場合はcurrent_player_idを使用）
## force_click_wait: trueの場合、CPUターンでも自動進行せずクリック待ちにする
func show_and_wait(message: String, player_id: int = -1, force_click_wait: bool = false) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# CPUターンかどうかを判定（force_click_waitがtrueなら強制的にクリック待ち）
	var is_cpu_turn = _is_current_player_cpu(player_id) and not force_click_wait
	
	# テキスト設定（中央揃え + クリック待ちの案内）
	var hint_text = "[color=gray][自動進行][/color]" if is_cpu_turn else "[color=gray][クリックで次へ][/color]"
	var text = "[center]" + message + "\n\n" + hint_text + "[/center]"
	label.text = text
	
	modulate.a = 1.0
	visible = true
	waiting_for_click = true
	
	if is_tutorial_style:
		_position_panel_top()
	else:
		_center_panel()
	
	# CPUターンの場合は短い遅延後に自動進行、人間の場合は通常のタイムアウト
	if is_cpu_turn:
		_start_cpu_auto_advance_timer()
	else:
		_start_timeout_timer()
	
	# 完了するまで待機（これにより呼び出し側のawaitが機能する）
	await click_confirmed

## 指定プレイヤーがCPUかどうかを判定
## player_id: -1の場合はcurrent_player_idを使用
func _is_current_player_cpu(player_id: int = -1) -> bool:
	if not game_flow_manager_ref or not is_instance_valid(game_flow_manager_ref):
		return false
	
	var check_id = player_id
	var cpu_flags = []
	
	# player_idが-1の場合はcurrent_player_idを使用
	if check_id < 0:
		if "current_player_id" in game_flow_manager_ref:
			check_id = game_flow_manager_ref.current_player_id
	
	if "player_is_cpu" in game_flow_manager_ref:
		cpu_flags = game_flow_manager_ref.player_is_cpu
	
	if check_id >= 0 and check_id < cpu_flags.size():
		return cpu_flags[check_id]
	
	return false

## CPU自動進行タイマーを開始
func _start_cpu_auto_advance_timer():
	_stop_timeout_timer()
	
	timeout_timer = Timer.new()
	timeout_timer.one_shot = true
	timeout_timer.wait_time = cpu_auto_advance_delay
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)
	timeout_timer.start()

## パネルを画面中央に配置
func _center_panel():
	# パネルサイズをリセットして内容に合わせる
	panel.reset_size()
	await get_tree().process_frame
	
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = panel.size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		(viewport_size.y - panel_size.y) / 2
	)

## パネルを画面上部に配置（チュートリアル用）
func _position_panel_top():
	# パネルサイズをリセットして内容に合わせる
	panel.reset_size()
	await get_tree().process_frame
	
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = panel.size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		viewport_size.y * 0.1  # 上から10%の位置
	)

## チュートリアルモード用のスタイル設定
func set_tutorial_style():
	is_tutorial_style = true
	label.add_theme_font_size_override("normal_font_size", GC.FONT_SIZE_COMMENT_LARGE)
	
	# パネルのマージンをコンパクトに
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

## 通常モード用のスタイル設定
func set_normal_style():
	is_tutorial_style = false
	label.add_theme_font_size_override("normal_font_size", GC.FONT_SIZE_COMMENT)
	
	# パネルのマージンを通常に
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	panel.add_theme_stylebox_override("panel", style)

func _start_timeout_timer():
	_stop_timeout_timer()
	
	timeout_timer = Timer.new()
	timeout_timer.one_shot = true
	timeout_timer.wait_time = click_wait_timeout
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)
	timeout_timer.start()

func _stop_timeout_timer():
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
		timeout_timer = null

func _on_timeout():
	if waiting_for_click:
		_confirm_and_close()

func _confirm_and_close():
	_stop_timeout_timer()
	waiting_for_click = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_confirmed.emit()

## 入力処理（マウス・キーボード両方）
func _input(event):
	if not waiting_for_click:
		return
	
	var confirmed = false
	
	# マウスクリックで確認
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		confirmed = true
	
	# キーボードで確認
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			confirmed = true
	
	if confirmed:
		_confirm_and_close()
		get_viewport().set_input_as_handled()

# ============================================
# ============================================
# SpellCastNotificationUI互換メソッド
# ============================================

## show_notification_and_wait互換（スペルシステムからの移行用）
func show_notification_and_wait(message: String, player_id: int = -1) -> void:
	await show_and_wait(message, player_id)

# ============================================
# 選択式ダイアログ
# ============================================

signal choice_made(result: bool)

## 選択式ダイアログを表示してawait可能
## 戻り値: true=yes_text選択、false=no_text選択
func show_choice_and_wait(message: String, player_id: int = -1, yes_text: String = "はい", no_text: String = "いいえ") -> bool:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# CPUターンの場合は自動でfalse（しない）を選択
	if _is_current_player_cpu(player_id):
		return false
	
	# 表示状態にする
	visible = true
	
	# 一時的な選択UIを作成
	var choice_panel = PanelContainer.new()
	choice_panel.name = "ChoicePanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	choice_panel.add_theme_stylebox_override("panel", style)
	
	# VBoxContainerでラベルとボタンを縦に並べる
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	
	# メッセージラベル
	var msg_label = Label.new()
	msg_label.text = message
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(msg_label)
	
	# ボタンコンテナ
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	
	# Yesボタン
	var yes_button = Button.new()
	yes_button.text = yes_text
	yes_button.custom_minimum_size = Vector2(120, 40)
	yes_button.pressed.connect(func(): _on_choice_button_pressed(true, choice_panel))
	
	# Noボタン
	var no_button = Button.new()
	no_button.text = no_text
	no_button.custom_minimum_size = Vector2(120, 40)
	no_button.pressed.connect(func(): _on_choice_button_pressed(false, choice_panel))
	
	button_container.add_child(yes_button)
	button_container.add_child(no_button)
	vbox.add_child(button_container)
	
	choice_panel.add_child(vbox)
	add_child(choice_panel)
	
	# 中央に配置
	await get_tree().process_frame
	choice_panel.position = (get_viewport_rect().size - choice_panel.size) / 2
	
	# 選択を待つ
	var result = await choice_made
	
	return result

## 選択ボタンが押された
func _on_choice_button_pressed(result: bool, button_container: Node):
	# ボタンコンテナを削除
	if button_container and is_instance_valid(button_container):
		button_container.queue_free()
	
	# UIを閉じる
	visible = false
	
	# 結果を通知
	choice_made.emit(result)
