extends Control
class_name GlobalCommentUI

## グローバルコメント表示UI
## スペル効果、周回ボーナス、バトル結果など様々な場面で使用
## 
## 使用方法:
## 1. クリック待ち: await ui_manager.global_comment.show_and_wait("メッセージ")
## 2. 自動フェード: ui_manager.global_comment.show_auto_fade("メッセージ", 2.0)

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
	label.add_theme_font_size_override("normal_font_size", 24)
	label.add_theme_color_override("default_color", Color.WHITE)
	
	panel.add_child(label)
	add_child(panel)
	
	visible = false

# ============================================
# クリック待ちモード（スペル効果等）
# ============================================

## 通知を表示してクリック待ち（await可能）
func show_and_wait(message: String) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# テキスト設定（中央揃え + クリック待ちの案内）
	var text = "[center]" + message + "\n\n[color=gray][クリックで次へ][/color][/center]"
	label.text = text
	
	modulate.a = 1.0
	visible = true
	waiting_for_click = true
	
	_center_panel()
	_start_timeout_timer()

## パネルを画面中央に配置
func _center_panel():
	await get_tree().process_frame
	
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = panel.size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		(viewport_size.y - panel_size.y) / 2
	)

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
# 自動フェードモード（周回ボーナス等）
# ============================================

## 通知を表示して自動フェードアウト（await不要）
## position: "center"（画面中央）, "bottom"（画面下部）
func show_auto_fade(message: String, duration: float = 2.0, position: String = "bottom") -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# クリック待ち中なら中断
	if waiting_for_click:
		_confirm_and_close()
	
	label.text = "[center]" + message + "[/center]"
	modulate.a = 1.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 位置設定
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = panel.size
	
	if position == "center":
		panel.position = Vector2(
			(viewport_size.x - panel_size.x) / 2,
			(viewport_size.y - panel_size.y) / 2
		)
	else:  # bottom
		panel.position = Vector2(
			(viewport_size.x - panel_size.x) / 2,
			viewport_size.y - panel_size.y - 100
		)
	
	# フェードアウト
	current_tween = create_tween()
	current_tween.tween_interval(duration)
	current_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	current_tween.tween_callback(func(): visible = false)

## 遅延して自動フェード表示
func show_auto_fade_delayed(message: String, delay: float, duration: float = 2.0, position: String = "bottom") -> void:
	await get_tree().create_timer(delay).timeout
	show_auto_fade(message, duration, position)

# ============================================
# SpellCastNotificationUI互換メソッド
# ============================================

## show_notification_and_wait互換（スペルシステムからの移行用）
func show_notification_and_wait(message: String) -> void:
	show_and_wait(message)
