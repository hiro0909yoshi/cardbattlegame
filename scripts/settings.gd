extends Control

## 設定画面
## チュートリアル開始、各種設定を行う


@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var tutorial_button: Button = $MarginContainer/VBoxContainer/TutorialButton
@onready var help_button: Button = $MarginContainer/VBoxContainer/HelpButton
@onready var cpu_deck_button: Button = $MarginContainer/VBoxContainer/CpuDeckButton
@onready var player_card_button: Button = $MarginContainer/VBoxContainer/PlayerCardButton
@onready var map_button: Button = $MarginContainer/VBoxContainer/MapButton
@onready var reset_button: Button = $MarginContainer/VBoxContainer/ResetButton


func _ready():
	# ボタン接続
	back_button.pressed.connect(_on_back_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	help_button.pressed.connect(_on_help_pressed)
	cpu_deck_button.pressed.connect(_on_cpu_deck_pressed)
	player_card_button.pressed.connect(_on_player_card_pressed)
	map_button.pressed.connect(_on_map_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	_setup_reset_button_style()


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_tutorial_pressed():
	print("チュートリアル選択画面へ")
	get_tree().change_scene_to_file("res://scenes/TutorialSelect.tscn")

func _on_help_pressed():
	print("説明画面へ")
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _on_cpu_deck_pressed():
	print("CPUデッキ選択画面へ")
	get_tree().change_scene_to_file("res://scenes/CpuDeckSelect.tscn")

func _on_player_card_pressed():
	print("プレイヤーカード管理画面へ")
	get_tree().change_scene_to_file("res://scenes/PlayerCardManager.tscn")

func _on_map_pressed():
	var dialog = MapPreviewDialog.new()
	add_child(dialog)
	dialog.popup_centered()


func _setup_reset_button_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.1, 0.1, 1.0)
	style.set_corner_radius_all(6)
	reset_button.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.75, 0.15, 0.15, 1.0)
	hover_style.set_corner_radius_all(6)
	reset_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.5, 0.05, 0.05, 1.0)
	pressed_style.set_corner_radius_all(6)
	reset_button.add_theme_stylebox_override("pressed", pressed_style)


func _on_reset_pressed():
	var dialog = ConfirmationDialog.new()
	dialog.title = "セーブデータリセット"
	dialog.ok_button_text = "リセット実行"
	dialog.cancel_button_text = "キャンセル"

	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(300, 80)
	ok_btn.add_theme_font_size_override("font_size", 32)
	ok_btn.disabled = true

	var cancel_btn = dialog.get_cancel_button()
	cancel_btn.custom_minimum_size = Vector2(300, 80)
	cancel_btn.add_theme_font_size_override("font_size", 32)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var warn_label = Label.new()
	warn_label.text = "全てのセーブデータが削除されます。\nこの操作は取り消せません。"
	warn_label.add_theme_font_size_override("font_size", 28)
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(warn_label)

	var player_name = GameData.player_data.profile.name

	var input_label = Label.new()
	input_label.text = "確認のためプレイヤー名を入力してください:"
	input_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(input_label)

	var line_edit = LineEdit.new()
	line_edit.custom_minimum_size = Vector2(400, 60)
	line_edit.add_theme_font_size_override("font_size", 32)
	line_edit.placeholder_text = player_name
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.text_changed.connect(func(text: String):
		ok_btn.disabled = text != player_name
	)
	vbox.add_child(line_edit)

	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		GameData.reset_all_data()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 350))
