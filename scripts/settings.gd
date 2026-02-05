extends Control

## 設定画面
## チュートリアル開始、各種設定を行う

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var tutorial_button: Button = $MarginContainer/VBoxContainer/TutorialButton
@onready var help_button: Button = $MarginContainer/VBoxContainer/HelpButton
@onready var cpu_deck_button: Button = $MarginContainer/VBoxContainer/CpuDeckButton
@onready var player_card_button: Button = $MarginContainer/VBoxContainer/PlayerCardButton
@onready var map_button: Button = $MarginContainer/VBoxContainer/MapButton


func _ready():
	# ボタン接続
	back_button.pressed.connect(_on_back_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	help_button.pressed.connect(_on_help_pressed)
	cpu_deck_button.pressed.connect(_on_cpu_deck_pressed)
	player_card_button.pressed.connect(_on_player_card_pressed)
	map_button.pressed.connect(_on_map_pressed)


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


