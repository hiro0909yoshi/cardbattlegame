extends Control

## 説明画面
## ゲームの各種説明を表示する

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var card_symbol_button: Button = $MarginContainer/VBoxContainer/CardSymbolButton
@onready var info_panel_button: Button = $MarginContainer/VBoxContainer/InfoPanelButton
@onready var arcana_arts_button: Button = $MarginContainer/VBoxContainer/ArcanaArtsButton
@onready var dominion_command_button: Button = $MarginContainer/VBoxContainer/DominionCommandButton
@onready var down_state_button: Button = $MarginContainer/VBoxContainer/DownStateButton
@onready var skill_button: Button = $MarginContainer/VBoxContainer/SkillButton

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	card_symbol_button.pressed.connect(_on_card_symbol_pressed)
	info_panel_button.pressed.connect(_on_info_panel_pressed)
	arcana_arts_button.pressed.connect(_on_arcana_arts_pressed)
	dominion_command_button.pressed.connect(_on_dominion_command_pressed)
	down_state_button.pressed.connect(_on_down_state_pressed)
	skill_button.pressed.connect(_on_skill_pressed)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_card_symbol_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpCardSymbol.tscn")

func _on_info_panel_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpInfoPanel.tscn")

func _on_arcana_arts_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpArcanaArts.tscn")

func _on_dominion_command_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpDominionCommand.tscn")

func _on_down_state_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpDownState.tscn")

func _on_skill_pressed():
	get_tree().change_scene_to_file("res://scenes/HelpSkill.tscn")
