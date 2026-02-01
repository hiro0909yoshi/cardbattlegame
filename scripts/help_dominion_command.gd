extends Control

## ドミニオコマンド説明画面

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var content_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_setup_content()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _setup_content():
	var text = "[font_size=56]"
	text += "ドミニオコマンド（支配地指令）は、自分のドミニオ（支配地）に指令を出して行えるコマンドです。\n\n"
	text += "[b]レベルアップ[/b]\n"
	text += "・EPを消費してドミニオ（支配地）のレベルを上げます\n"
	text += "・レベルが上がるとEPが増加します\n\n"
	text += "[b]属性変更[/b]\n"
	text += "・ドミニオの属性を変更できます\n"
	text += "・クリーチャーと同じ属性にすると地形効果を得られます\n\n"
	text += "[b]クリーチャー交換[/b]\n"
	text += "・配置されているクリーチャーを手札のクリーチャーと交換します\n\n"
	text += "[b]クリーチャー移動[/b]\n"
	text += "・クリーチャーを別の土地に移動させます\n"
	text += "・移動先が敵地なら戦闘が発生します\n"
	text += "[/font_size]"
	content_label.text = text
