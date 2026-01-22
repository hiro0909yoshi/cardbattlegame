extends Control

## インフォパネル説明画面
## 4ページ構成: プレイヤー、クリーチャー、スペル、アイテム

@onready var back_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var prev_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/PrevButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/NextButton
@onready var page_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PageLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var left_panel: Control = $MarginContainer/VBoxContainer/ContentHBox/LeftPanel
@onready var right_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentHBox/RightPanel/RightLabel

const PAGE_TITLES = [
	"プレイヤーインフォパネル",
	"クリーチャーインフォパネル",
	"スペルインフォパネル",
	"アイテムインフォパネル"
]

var current_page: int = 0
var total_pages: int = 4

# 各インフォパネルのインスタンス
var player_info_panel_instance = null
var creature_info_panel_instance = null
var spell_info_panel_instance = null
var item_info_panel_instance = null

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	_load_info_panels()
	_update_page()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _on_prev_pressed():
	current_page = (current_page - 1 + total_pages) % total_pages
	_update_page()

func _on_next_pressed():
	current_page = (current_page + 1) % total_pages
	_update_page()

func _load_info_panels():
	# プレイヤーインフォパネル（シーンがあれば読み込む）
	var player_scene = load("res://scenes/ui/player_status_dialog.tscn")
	if player_scene:
		player_info_panel_instance = player_scene.instantiate()
		player_info_panel_instance.visible = false
		left_panel.add_child(player_info_panel_instance)
	
	# クリーチャーインフォパネル
	var creature_scene = load("res://scenes/ui/creature_info_panel.tscn")
	if creature_scene:
		creature_info_panel_instance = creature_scene.instantiate()
		creature_info_panel_instance.visible = false
		left_panel.add_child(creature_info_panel_instance)
	
	# スペルインフォパネル
	var spell_scene = load("res://scenes/ui/spell_info_panel.tscn")
	if spell_scene:
		spell_info_panel_instance = spell_scene.instantiate()
		spell_info_panel_instance.visible = false
		left_panel.add_child(spell_info_panel_instance)
	
	# アイテムインフォパネル
	var item_scene = load("res://scenes/ui/item_info_panel.tscn")
	if item_scene:
		item_info_panel_instance = item_scene.instantiate()
		item_info_panel_instance.visible = false
		left_panel.add_child(item_info_panel_instance)

func _update_page():
	# タイトル更新
	title_label.text = PAGE_TITLES[current_page]
	page_label.text = str(current_page + 1) + " / " + str(total_pages)
	
	# 全パネル非表示
	if player_info_panel_instance:
		player_info_panel_instance.visible = false
	if creature_info_panel_instance:
		creature_info_panel_instance.visible = false
	if spell_info_panel_instance:
		spell_info_panel_instance.visible = false
	if item_info_panel_instance:
		item_info_panel_instance.visible = false
	
	# 現在のページのパネルを表示
	match current_page:
		0:
			_show_player_info_panel()
		1:
			_show_creature_info_panel()
		2:
			_show_spell_info_panel()
		3:
			_show_item_info_panel()

func _show_player_info_panel():
	if player_info_panel_instance:
		player_info_panel_instance.visible = true
		# 位置とサイズ調整
		player_info_panel_instance.position = Vector2.ZERO
		player_info_panel_instance.scale = Vector2(0.5, 0.5)
	
	right_label.text = _get_player_info_description()

func _show_creature_info_panel():
	if creature_info_panel_instance:
		creature_info_panel_instance.visible = true
		creature_info_panel_instance.position = Vector2.ZERO
		creature_info_panel_instance.scale = Vector2(0.8, 0.8)
		
		# サンプルデータを設定（ID 43）
		var sample_data = _get_sample_creature_data()
		if creature_info_panel_instance.has_method("show_view_mode"):
			creature_info_panel_instance.show_view_mode(sample_data, -1, false)
	
	right_label.text = _get_creature_info_description()

func _show_spell_info_panel():
	if spell_info_panel_instance:
		spell_info_panel_instance.visible = true
		spell_info_panel_instance.position = Vector2.ZERO
		spell_info_panel_instance.scale = Vector2(0.8, 0.8)
		
		# サンプルデータを設定
		var sample_data = _get_sample_spell_data()
		if spell_info_panel_instance.has_method("show_spell_info"):
			spell_info_panel_instance.show_spell_info(sample_data, -1)
	
	right_label.text = _get_spell_info_description()

func _show_item_info_panel():
	if item_info_panel_instance:
		item_info_panel_instance.visible = true
		item_info_panel_instance.position = Vector2.ZERO
		item_info_panel_instance.scale = Vector2(0.8, 0.8)
		
		# サンプルデータを設定
		var sample_data = _get_sample_item_data()
		if item_info_panel_instance.has_method("show_item_info"):
			item_info_panel_instance.show_item_info(sample_data, -1)
	
	right_label.text = _get_item_info_description()

# サンプルデータ取得
func _get_sample_creature_data() -> Dictionary:
	# ID 43 のクリーチャーを使用
	if CardLoader:
		var data = CardLoader.get_card_by_id(43)
		if not data.is_empty():
			return data
	
	# フォールバック
	return {
		"id": 43,
		"name": "サンプル",
		"type": "creature",
		"element": "fire",
		"ap": 30,
		"hp": 30,
		"cost": {"mp": 50},
		"ability": ""
	}

func _get_sample_spell_data() -> Dictionary:
	# ID 2001 のアースシフト
	if CardLoader:
		var data = CardLoader.get_card_by_id(2001)
		if not data.is_empty():
			return data
	
	return {
		"id": 2001,
		"name": "アースシフト",
		"type": "spell",
		"spell_type": "単体対象",
		"cost": {"mp": 100},
		"effect": "対象自領地を地に変える"
	}

func _get_sample_item_data() -> Dictionary:
	# アイテムデータを取得
	if CardLoader:
		var data = CardLoader.get_card_by_id(3001)
		if not data.is_empty():
			return data
	
	return {
		"id": 3001,
		"name": "サンプルアイテム",
		"type": "item",
		"item_type": "武器",
		"effect": "ST+10"
	}

# 説明テキスト
func _get_player_info_description() -> String:
	var text = "[font_size=36][b]プレイヤーインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "画面左上のプレイヤー情報パネルをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・基本情報（名前、魔力、総魔力）\n"
	text += "・マップ情報（周回数、ターン数、破壊数）\n"
	text += "・手札一覧\n"
	text += "・保有土地（属性別）\n"
	text += "・保有クリーチャー一覧\n"
	text += "[/font_size]"
	return text

func _get_creature_info_description() -> String:
	var text = "[font_size=36][b]クリーチャーインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "クリーチャーカードをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・カード名と属性\n"
	text += "・コスト（MP、必要領地）\n"
	text += "・ST（攻撃力）/ HP（体力）\n"
	text += "・能力説明\n"
	text += "・秘術情報（ある場合）\n"
	text += "[/font_size]"
	return text

func _get_spell_info_description() -> String:
	var text = "[font_size=36][b]スペルインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "スペルカードをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・カード名\n"
	text += "・スペルタイプ\n"
	text += "・コスト（MP、カード犠牲など）\n"
	text += "・効果説明\n"
	text += "[/font_size]"
	return text

func _get_item_info_description() -> String:
	var text = "[font_size=36][b]アイテムインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "アイテムカードをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・カード名\n"
	text += "・アイテムタイプ（武器/防具/アクセサリ/巻物）\n"
	text += "・コスト\n"
	text += "・効果説明\n"
	text += "・使用条件（ある場合）\n"
	text += "[/font_size]"
	return text
