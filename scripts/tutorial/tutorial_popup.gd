# チュートリアル専用ポップアップUI
extends Control

class_name TutorialPopup

signal clicked(wait_id: int)

var panel: PanelContainer
var label: RichTextLabel
var waiting_for_click: bool = false
var _current_wait_id: int = 0

func _ready():
	# ポーズ中でも動作するように設定
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()

func _setup_ui():
	# 全画面に設定
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1002  # オーバーレイ(1001)より上
	
	# パネル
	panel = PanelContainer.new()
	panel.name = "TutorialPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	
	# ラベル
	label = RichTextLabel.new()
	label.name = "TutorialLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 100)
	label.add_theme_color_override("default_color", Color.WHITE)
	
	panel.add_child(label)
	add_child(panel)
	
	# クリック検出
	panel.gui_input.connect(_on_panel_input)
	
	visible = false

func _on_panel_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if waiting_for_click:
				waiting_for_click = false
				clicked.emit(_current_wait_id)

## メッセージを表示（クリック待ちなし）
func show_message(message: String, pos_name: String = "top", offset_y: float = 0.0):
	label.text = "[center]" + message + "[/center]"
	visible = true
	waiting_for_click = false
	_apply_position(pos_name, offset_y)

## メッセージを表示してクリック待ち
func show_and_wait(message: String, pos_name: String = "top", offset_y: float = 0.0):
	# 新しい待機IDを生成
	_current_wait_id += 1
	var my_wait_id = _current_wait_id
	
	label.text = "[center]" + message + "\n[color=gray][font_size=50]タップで次へ[/font_size][/color][/center]"
	visible = true
	waiting_for_click = true
	_apply_position(pos_name, offset_y)
	
	# 自分のwait_idと一致するクリックが来るまで待機
	while true:
		var received_id = await clicked
		if received_id == my_wait_id:
			break
		# 違うIDのクリックは無視して待ち続ける

## 位置を設定
func _apply_position(pos_name: String, offset_y: float = 0.0):
	match pos_name:
		"left":
			_position_left()
		"right":
			_position_right()
		_:
			_position_top()
	# Y軸オフセットを適用
	if offset_y != 0.0:
		panel.position.y += offset_y

## 左寄せ配置
func _position_left():
	var viewport_size = get_viewport().get_visible_rect().size
	# パネル幅をビューポートの40%に制限
	label.custom_minimum_size.x = viewport_size.x * 0.4
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.reset_size()
	await get_tree().process_frame
	var panel_size = panel.size
	# 左端から5%の位置、垂直は中央より少し上
	panel.position = Vector2(
		viewport_size.x * 0.02,
		(viewport_size.y - panel_size.y) / 2 - viewport_size.y * 0.1
	)

## 右寄せ配置
func _position_right():
	var viewport_size = get_viewport().get_visible_rect().size
	# パネル幅をビューポートの40%に制限
	label.custom_minimum_size.x = viewport_size.x * 0.4
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.reset_size()
	await get_tree().process_frame
	var panel_size = panel.size
	# 右端から5%の位置、垂直は中央より少し上
	panel.position = Vector2(
		viewport_size.x - panel_size.x - viewport_size.x * 0.02,
		(viewport_size.y - panel_size.y) / 2 - viewport_size.y * 0.1
	)

## 非表示
func hide_message():
	visible = false
	waiting_for_click = false

## 上部に配置
func _position_top():
	# パネル幅制限を解除
	label.custom_minimum_size.x = 0
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.reset_size()
	await get_tree().process_frame
	
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = panel.size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		viewport_size.y * 0.08
	)
