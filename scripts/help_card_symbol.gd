extends Control

## カード記号説明画面

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var content_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/ContentLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_setup_content()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _setup_content():
	var text = ""
	
	# カード記号の説明
	text += "[font_size=48][b]カード記号の説明[/b][/font_size]\n\n"
	
	text += "[font_size=36][b]クリーチャー[/b] [color=#ffffff]●[/color][/font_size]\n"
	text += "[font_size=32]"
	text += "　[color=#ff4545]●[/color] 火属性\n"
	text += "　[color=#4587ff]●[/color] 水属性\n"
	text += "　[color=#87cc45]●[/color] 地属性\n"
	text += "　[color=#ffcc45]●[/color] 風属性\n"
	text += "　[color=#aaaaaa]●[/color] 無属性\n"
	text += "[/font_size]\n"
	
	text += "[font_size=36][b]アイテム[/b] [color=#ffffff]▲[/color][/font_size]\n"
	text += "[font_size=32]"
	text += "　[color=#ff6645]▲[/color] 武器\n"
	text += "　[color=#4566ff]▲[/color] 防具\n"
	text += "　[color=#45cc87]▲[/color] アクセサリ\n"
	text += "　[color=#cc45ff]▲[/color] 巻物\n"
	text += "[/font_size]\n"
	
	text += "[font_size=36][b]スペル[/b] [color=#ffffff]◆[/color][/font_size]\n"
	text += "[font_size=32]"
	text += "　[color=#ff4545]◆[/color] 単体対象\n"
	text += "　[color=#45ff87]◆[/color] 単体特殊能力付与\n"
	text += "　[color=#ffaa45]◆[/color] 複数対象\n"
	text += "　[color=#45ccff]◆[/color] 複数特殊能力付与\n"
	text += "　[color=#aa45ff]◆[/color] 世界呪\n"
	text += "[/font_size]\n"
	
	content_label.text = text
