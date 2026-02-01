extends Control

## スキル説明画面

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var content_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_setup_content()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _setup_content():
	var text = "[font_size=56]"
	text += "スキルは、クリーチャーが持つ特殊能力です。\n\n"
	text += "[b]スキルの種類[/b]\n"
	text += "・先制：相手より先に攻撃できる\n"
	text += "・強打：特定の属性に対してダメージ増加\n"
	text += "・応援：味方クリーチャーのステータスを強化\n"
	text += "・再生：ターン終了時にHPを回復\n"
	text += "・その他多数のスキルがあります\n\n"
	text += "[b]スキルの発動[/b]\n"
	text += "・多くのスキルは自動的に発動します\n"
	text += "・条件付きのスキルは条件を満たすと発動します\n\n"
	text += "[b]注意点[/b]\n"
	text += "・呪いによりスキルが無効化される場合があります\n"
	text += "[/font_size]"
	content_label.text = text
