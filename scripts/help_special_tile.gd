extends Control

## 特殊タイル説明画面

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var content_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/ContentLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_setup_content()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _setup_content():
	var text = "[font_size=56]"
	text += "特殊な機能を持つタイルの説明です。\n\n"

	for tile_key in SpecialTileDescriptions.TILE_ORDER:
		var info = SpecialTileDescriptions.TILES[tile_key]
		text += "[b][color=%s]%s[/color][/b]\n" % [info.color_hex, info.name]
		text += "%s\n\n" % info.description

	text += "[/font_size]"
	content_label.text = text
