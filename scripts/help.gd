extends Control

## 説明画面
## ゲームの各種説明を表示する

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var card_symbol_button: Button = $MarginContainer/VBoxContainer/CardSymbolButton
@onready var info_panel_button: Button = $MarginContainer/VBoxContainer/InfoPanelButton

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	card_symbol_button.pressed.connect(_on_card_symbol_pressed)
	info_panel_button.pressed.connect(_on_info_panel_pressed)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_card_symbol_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpCardSymbol.tscn")

func _on_info_panel_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpInfoPanel.tscn")
