extends Control

@onready var _grid_container: GridContainer = $MarginContainer/VBoxContainer/ContentArea/ScrollContainer/GridContainer
@onready var _stamina_label: Label = $MarginContainer/VBoxContainer/Header/StaminaLabel
@onready var _back_button: Button = $MarginContainer/VBoxContainer/Footer/BackButton

func _ready():
	_back_button.pressed.connect(_on_back_pressed)
	_setup_background()
	_update_stamina_display()

	# デバッグ用: アイテムが空なら初期付与
	if GameData.get_inventory_item_count(1) <= 0 and GameData.get_inventory_item_count(2) <= 0:
		GameData.add_inventory_item(1, 5)  # スタミナ回復薬（小）×5
		GameData.add_inventory_item(2, 5)  # スタミナ回復薬（大）×5

	_display_items()

	# スタミナ表示の定期更新
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_stamina_display)
	add_child(timer)


func _update_stamina_display():
	if _stamina_label:
		var current = GameData.get_stamina()
		var max_val = GameData.get_stamina_max()
		_stamina_label.text = "⚡ %d/%d" % [current, max_val]


func _display_items():
	# グリッドをクリア
	for child in _grid_container.get_children():
		child.queue_free()

	_grid_container.add_theme_constant_override("h_separation", 40)
	_grid_container.add_theme_constant_override("v_separation", 40)

	var item_defs = GameData.get_all_inventory_item_defs()
	var _has_items = false

	for item_def in item_defs:
		var item_id = int(item_def.get("id", 0))
		var count = GameData.get_inventory_item_count(item_id)
		if count <= 0:
			continue

		_has_items = true
		var panel = _create_item_panel(item_def, count)
		_grid_container.add_child(panel)

	if not _has_items:
		var empty_label = Label.new()
		empty_label.text = "アイテムを所持していません"
		empty_label.add_theme_font_size_override("font_size", 40)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_grid_container.add_child(empty_label)


func _create_item_panel(item_def: Dictionary, count: int) -> PanelContainer:
	var item_id = int(item_def.get("id", 0))
	var item_name = item_def.get("name", "???")
	var description = item_def.get("description", "")
	var rarity = item_def.get("rarity", "N")

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 250)

	# スタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.border_color = _get_rarity_color(rarity)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)

	# 左側: アイテム情報
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 8)

	var name_label = Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 40)
	name_label.add_theme_color_override("font_color", _get_rarity_color(rarity))
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 28)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_label)

	var count_label = Label.new()
	count_label.text = "所持数: %d" % count
	count_label.add_theme_font_size_override("font_size", 30)
	info_vbox.add_child(count_label)

	hbox.add_child(info_vbox)

	# 右側: 使用ボタン
	var use_button = Button.new()
	use_button.text = "使う"
	use_button.custom_minimum_size = Vector2(160, 80)
	use_button.add_theme_font_size_override("font_size", 36)
	use_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	use_button.pressed.connect(_on_use_item.bind(item_id))

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.3, 0.9)
	btn_style.set_corner_radius_all(8)
	use_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.6, 0.35, 0.95)
	use_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.3, 0.7, 0.4, 1.0)
	use_button.add_theme_stylebox_override("pressed", btn_pressed)

	hbox.add_child(use_button)
	panel.add_child(hbox)
	return panel


func _on_use_item(item_id: int):
	var item_def = GameData.get_inventory_item_def(item_id)
	var item_name = item_def.get("name", "アイテム")

	if GameData.use_inventory_item(item_id):
		_show_result_dialog(item_name + " を使用しました！")
		_update_stamina_display()
		_display_items()
	else:
		_show_result_dialog("使用できませんでした")


func _show_result_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "アイテム使用"
	dialog.ok_button_text = "OK"

	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 36)
	dialog.add_child(label)

	var ok_button = dialog.get_ok_button()
	ok_button.custom_minimum_size = Vector2(240, 60)
	ok_button.add_theme_font_size_override("font_size", 32)

	add_child(dialog)
	dialog.popup_centered()


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"R":
			return Color(1.0, 0.85, 0.3)
		"S":
			return Color(0.85, 0.7, 1.0)
		"N":
			return Color(0.7, 0.8, 0.9)
		_:
			return Color.WHITE


func _setup_background():
	var bg_container = Control.new()
	bg_container.name = "BG"
	bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.08, 0.08, 0.12, 0.95))
	gradient.set_color(1, Color(0.02, 0.02, 0.05, 0.98))

	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)

	bg.texture = grad_tex
	bg_container.add_child(bg)

	add_child(bg_container)
	move_child(bg_container, 0)


func _on_back_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")
