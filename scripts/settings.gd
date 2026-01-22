extends Control

## 設定画面
## チュートリアル開始、各種設定を行う

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var tutorial_button: Button = $MarginContainer/VBoxContainer/TutorialButton
@onready var help_button: Button = $MarginContainer/VBoxContainer/HelpButton

func _ready():
	# ボタン接続
	back_button.pressed.connect(_on_back_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	help_button.pressed.connect(_on_help_pressed)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_tutorial_pressed():
	print("チュートリアル開始")
	# チュートリアルモードフラグを設定
	GameData.set_meta("is_tutorial_mode", true)
	GameData.set_meta("stage_id", "stage_tutorial")
	# ゲーム画面へ遷移
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_help_pressed():
	print("説明画面へ")
	get_tree().change_scene_to_file("res://scenes/Help.tscn")
