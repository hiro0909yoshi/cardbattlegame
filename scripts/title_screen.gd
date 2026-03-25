extends Control

## タイトル画面
## 初回起動時は名前入力フローを実行

@onready var _tap_label: Label = $VBox/TapLabel
@onready var _version_label: Label = $VersionLabel

var _tween: Tween


func _ready():
	_start_tap_animation()
	_version_label.text = "v0.1.0"


func _start_tap_animation():
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(_tap_label, "modulate:a", 0.3, 1.0)
	_tween.tween_property(_tap_label, "modulate:a", 1.0, 1.0)


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_tap()
	elif event is InputEventScreenTouch and event.pressed:
		_on_tap()


func _on_tap():
	# 二重タップ防止
	set_process_input(false)

	if not GameData.player_data.has_initialized:
		_show_name_input()
	else:
		_go_to_main_menu()


func _show_name_input():
	var dialog = AcceptDialog.new()
	dialog.title = "プレイヤー名を決めよう"
	dialog.ok_button_text = "決定"

	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(300, 80)
	ok_btn.add_theme_font_size_override("font_size", 36)
	ok_btn.disabled = true

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var info_label = Label.new()
	info_label.text = "ゲームで使う名前を入力してください"
	info_label.add_theme_font_size_override("font_size", 28)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	var line_edit = LineEdit.new()
	line_edit.custom_minimum_size = Vector2(500, 60)
	line_edit.add_theme_font_size_override("font_size", 36)
	line_edit.placeholder_text = "名前を入力"
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.max_length = 20
	line_edit.text_changed.connect(func(text: String):
		ok_btn.disabled = text.strip_edges().is_empty()
	)
	vbox.add_child(line_edit)

	dialog.add_child(vbox)

	dialog.confirmed.connect(func():
		var new_name = line_edit.text.strip_edges()
		if new_name.is_empty():
			return
		GameData.player_data.profile.name = new_name
		GameData.player_data.has_initialized = true
		GameData.save_to_file()
		print("[TitleScreen] 初回設定完了: %s" % new_name)
		_go_to_main_menu()
	)

	# ダイアログ閉じた場合（キャンセル）はタップを再有効化
	dialog.canceled.connect(func():
		set_process_input(true)
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 250))


func _go_to_main_menu():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
