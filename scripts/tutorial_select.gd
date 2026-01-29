extends Control

## チュートリアル選択画面

@onready var tutorial1_button: Button = $MarginContainer/VBoxContainer/Tutorial1Button
@onready var tutorial2_button: Button = $MarginContainer/VBoxContainer/Tutorial2Button
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

func _ready():
	tutorial1_button.pressed.connect(_on_tutorial1_pressed)
	tutorial2_button.pressed.connect(_on_tutorial2_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_tutorial1_pressed():
	print("基本チュートリアル開始")
	_start_tutorial("stage1")

func _on_tutorial2_pressed():
	print("応用チュートリアル開始")
	_start_tutorial("stage2")

func _start_tutorial(tutorial_id: String):
	# チュートリアルモードフラグを設定
	GameData.set_meta("is_tutorial_mode", true)
	GameData.set_meta("stage_id", "stage_tutorial")
	GameData.set_meta("tutorial_id", tutorial_id)
	# ゲーム画面へ遷移
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")
