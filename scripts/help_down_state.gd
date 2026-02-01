extends Control

## ダウン状態説明画面

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var content_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_setup_content()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _setup_content():
	var text = "[font_size=56]"
	text += "ダウン状態は、クリーチャーが一時的に行動不能になる状態です。\n\n"
	text += "[b]ダウン状態になる条件[/b]\n"
	text += "・召喚直後、ドミニオコマンド使用後、アルカナアーツ使用後\n"
	text += "・特定のスキルや効果を受けた場合\n\n"
	text += "[b]ダウン状態の影響[/b]\n"
	text += "・ダウン中のクリーチャーはドミニオコマンドやアルカナアーツの使用ができません\n"
	text += "[b]ダウン状態の回復[/b]\n"
	text += "・周回ボーナスとチェックポイント停止時に自動的に回復します\n"
	text += "・特定のスペルやスキルで回復可能\n"
	text += "[/font_size]"
	content_label.text = text
