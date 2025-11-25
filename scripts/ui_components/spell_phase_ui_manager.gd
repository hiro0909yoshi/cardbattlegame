class_name SpellPhaseUIManager
extends Control

# ボタン参照
var mystic_button: Button = null
var spell_skip_button: Button = null

# UI参照
var card_ui_helper = null  # CardUIHelper
var hand_display = null    # HandDisplay
var spell_phase_handler_ref = null  # SpellPhaseHandler参照

# 定数
const BUTTON_WIDTH = 300
const BUTTON_HEIGHT = 70
const BUTTON_MARGIN = 20

# === ボタン作成 ===

func create_mystic_button(parent: Node) -> Button:
	"""秘術ボタンを作成（全画面対応）"""
	if mystic_button:
		return mystic_button
	
	mystic_button = Button.new()
	mystic_button.name = "MysticButton"
	mystic_button.text = "秘術を使う"
	
	# 位置計算（CardUIHelper を使用）
	_update_button_positions()
	
	# スタイル設定
	_apply_mystic_button_style(mystic_button)
	
	# ボタンのシグナル接続
	mystic_button.pressed.connect(_on_mystic_button_pressed)
	
	# Z-index
	mystic_button.z_index = 100
	
	parent.add_child(mystic_button)
	mystic_button.visible = false  # 初期状態は非表示
	
	# add_child() 後に position/size を再度設定（親の layout システムが上書きを防ぐため）
	_update_button_positions()
	
	var viewport_size = get_viewport().get_visible_rect().size
	print("[SpellPhaseUIManager] 秘術ボタン作成: size=", mystic_button.size, " position=", mystic_button.position)
	
	# デバッグ: layout情報を出力
	var layout_mystic = card_ui_helper.calculate_card_layout(viewport_size, 6) if card_ui_helper else null
	if layout_mystic:
		print("  layout: start_x=", layout_mystic.start_x, " card_width=", layout_mystic.card_width, " spacing=", layout_mystic.spacing)
	
	return mystic_button


func create_spell_skip_button(parent: Node) -> Button:
	"""スペルを使わないボタンを作成"""
	if spell_skip_button:
		return spell_skip_button
	
	spell_skip_button = Button.new()
	spell_skip_button.name = "SpellSkipButton"
	spell_skip_button.text = "スペルを使わない"
	
	_update_button_positions()
	_apply_spell_skip_button_style(spell_skip_button)
	
	# ボタンのシグナル接続
	spell_skip_button.pressed.connect(_on_spell_skip_button_pressed)
	
	spell_skip_button.z_index = 100
	parent.add_child(spell_skip_button)
	spell_skip_button.visible = false
	
	# add_child() 後に position/size を再度設定（親の layout システムが上書きを防ぐため）
	_update_button_positions()
	
	var viewport_size2 = get_viewport().get_visible_rect().size
	print("[SpellPhaseUIManager] スペルボタン作成: size=", spell_skip_button.size, " position=", spell_skip_button.position)
	
	# デバッグ: layout情報を出力
	var layout = card_ui_helper.calculate_card_layout(viewport_size2, 6) if card_ui_helper else null
	if layout:
		print("  layout: start_x=", layout.start_x, " card_width=", layout.card_width, " spacing=", layout.spacing)
	
	return spell_skip_button


# === 位置更新 ===

func _update_button_positions():
	"""画面解像度変更時にボタン位置とサイズを再計算"""
	var viewport_size = get_viewport().get_visible_rect().size
	var hand_count = 6  # 最大手札数（調整可能）
	
	# CardUIHelper でレイアウト計算
	if not card_ui_helper:
		card_ui_helper = load("res://scripts/ui_components/card_ui_helper.gd")
	
	if card_ui_helper and card_ui_helper.has_method("calculate_card_layout"):
		var layout = card_ui_helper.calculate_card_layout(viewport_size, hand_count)
		
		# 秘術ボタン：手札左側
		if mystic_button:
			# card_selection_ui.gd と同じ方法で position を直接設定
			var mystic_x = layout.start_x - layout.card_width - BUTTON_MARGIN
			mystic_button.position = Vector2(mystic_x, layout.card_y)
			mystic_button.size = Vector2(layout.card_width, layout.card_height)
		
		# スペルをしないボタン：手札右側
		if spell_skip_button:
			# card_selection_ui.gd と同じ計算式
			var last_card_x = layout.start_x + hand_count * layout.card_width + (hand_count - 1) * layout.spacing + layout.spacing
			spell_skip_button.position = Vector2(last_card_x, layout.card_y)
			spell_skip_button.size = Vector2(layout.card_width, layout.card_height)
	else:
		# フォールバック：固定位置
		if mystic_button:
			mystic_button.position = Vector2(20, 170)
			mystic_button.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
		if spell_skip_button:
			spell_skip_button.position = Vector2(viewport_size.x - BUTTON_WIDTH - 20, 170)
			spell_skip_button.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)


# === スタイル適用 ===

func _apply_mystic_button_style(button: Button):
	"""秘術ボタンのスタイル設定"""
	# Normal状態
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.4, 0.2, 0.6, 1.0)  # 紫系
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1, 1, 1, 1)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover状態
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.6, 0.3, 0.8, 1.0)  # 明るい紫
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed状態
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.3, 0.1, 0.5, 1.0)  # 暗い紫
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Disabled状態（排他制御用）
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.2, 0.1, 0.3, 0.5)  # 半透明紫
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	# フォント設定
	button.add_theme_font_size_override("font_size", 24)


func _apply_spell_skip_button_style(button: Button):
	"""スペルをしないボタンのスタイル設定"""
	# Normal状態
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.5, 0.5, 0.5, 1.0)  # グレー
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1, 1, 1, 1)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover状態
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.7, 0.7, 0.7, 1.0)  # ライトグレー
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed状態
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # ダークグレー
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Disabled状態
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # 半透明グレー
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	# フォント設定
	button.add_theme_font_size_override("font_size", 24)


# === 表示制御 ===

func show_mystic_button():
	"""秘術ボタン表示"""
	if mystic_button:
		mystic_button.visible = true
		mystic_button.disabled = false


func hide_mystic_button():
	"""秘術ボタン非表示"""
	if mystic_button:
		mystic_button.visible = false


func show_spell_skip_button():
	"""スペルをしないボタン表示"""
	if spell_skip_button:
		spell_skip_button.visible = true
		spell_skip_button.disabled = false


func hide_spell_skip_button():
	"""スペルをしないボタン非表示"""
	if spell_skip_button:
		spell_skip_button.visible = false


# === 排他制御 ===

func on_spell_used():
	"""スペル使用時：秘術ボタンを非表示"""
	hide_mystic_button()


func on_mystic_art_used():
	"""秘術使用時：スペルをしないボタンを非表示"""
	hide_spell_skip_button()


func reset_buttons():
	"""両ボタンをリセット"""
	show_mystic_button()
	show_spell_skip_button()


func disable_all():
	"""両ボタンを無効化"""
	if mystic_button:
		mystic_button.disabled = true
	if spell_skip_button:
		spell_skip_button.disabled = true


func enable_all():
	"""両ボタンを有効化"""
	if mystic_button:
		mystic_button.disabled = false
	if spell_skip_button:
		spell_skip_button.disabled = false


# === シグナルハンドラー ===

func _on_mystic_button_pressed():
	"""秘術ボタンが押された"""
	if spell_phase_handler_ref:
		spell_phase_handler_ref.start_mystic_arts_phase()

func _on_spell_skip_button_pressed():
	"""スペルを使わないボタンが押された"""
	# spell_phase_handler を通じて処理
	if spell_phase_handler_ref:
		spell_phase_handler_ref.pass_spell()
	else:
		# フォールバック: UIManager を通じてシグナル発行
		var ui_manager = get_tree().root.get_child(0).get_node_or_null("UIManager")
		if ui_manager and ui_manager.has_signal("pass_button_pressed"):
			ui_manager.pass_button_pressed.emit()
