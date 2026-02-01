extends Control

## カード記号説明画面

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var creature_list: RichTextLabel = $MarginContainer/VBoxContainer/ContentHBox/CreatureColumn/CreatureList
@onready var item_list: RichTextLabel = $MarginContainer/VBoxContainer/ContentHBox/ItemColumn/ItemList
@onready var spell_list: RichTextLabel = $MarginContainer/VBoxContainer/ContentHBox/SpellColumn/SpellList

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_setup_content()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _setup_content():
	# クリーチャー
	var creature_text = "[font_size=100]"
	creature_text += "[color=#ff4545]●[/color] 火属性\n"
	creature_text += "[color=#4587ff]●[/color] 水属性\n"
	creature_text += "[color=#87cc45]●[/color] 地属性\n"
	creature_text += "[color=#ffcc45]●[/color] 風属性\n"
	creature_text += "[color=#aaaaaa]●[/color] 無属性\n"
	creature_text += "[/font_size]"
	creature_list.text = creature_text
	
	# アイテム
	var item_text = "[font_size=100]"
	item_text += "[color=#ff6645]▲[/color] 武器\n"
	item_text += "[color=#4566ff]▲[/color] 防具\n"
	item_text += "[color=#45cc87]▲[/color] アクセサリ\n"
	item_text += "[color=#cc45ff]▲[/color] 巻物\n"
	item_text += "[/font_size]"
	item_list.text = item_text
	
	# スペル
	var spell_text = "[font_size=100]"
	spell_text += "[color=#ff4545]◆[/color] 単体対象\n"
	spell_text += "[color=#45ff87]◆[/color] 単体特殊能力付与\n"
	spell_text += "[color=#ffaa45]◆[/color] 複数対象\n"
	spell_text += "[color=#45ccff]◆[/color] 複数特殊能力付与\n"
	spell_text += "[color=#aa45ff]◆[/color] 世界呪\n"
	spell_text += "[/font_size]"
	spell_list.text = spell_text
