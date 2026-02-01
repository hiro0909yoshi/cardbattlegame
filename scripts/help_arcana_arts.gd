extends Control

## アルカナアーツ説明画面

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var content_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_setup_content()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _setup_content():
	var text = "[font_size=56]"
	text += "アルカナアーツは、クリーチャーが持つ特殊な能力です。\n\n"
	text += "[b]発動タイミング[/b]\n"
	text += "・スペルフェーズで発動できます\n"
	text += "・1ターンに1回のみ使用可能です\n"
	text += "・スペルカードを使用した場合は使えません（逆も同様）\n\n"
	text += "[b]発動条件[/b]\n"
	text += "・配置済みの自分のクリーチャーのみが使用できます\n"
	text += "・発動に必要なEPを消費します（コストはクリーチャーごとに異なります）\n"
	text += "・ダウン状態のクリーチャーは使用できません\n\n"
	text += "[b]発動後の状態[/b]\n"
	text += "・発動したクリーチャーはダウン状態になります\n"
	text += "[b]効果の例[/b]\n"
	text += "・ダメージを与える、HPを回復する\n"
	text += "・土地の属性を変更する\n"
	text += "[/font_size]"
	content_label.text = text
