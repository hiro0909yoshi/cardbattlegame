extends Control

# クエスト選択画面
# ステージ選択 + デッキ選択

@onready var stage_list = $MarginContainer/HBoxContainer/LeftPanel/StageList
@onready var deck_list = $MarginContainer/HBoxContainer/RightPanel/DeckList
@onready var start_button = $MarginContainer/HBoxContainer/RightPanel/StartButton
@onready var back_button = $MarginContainer/HBoxContainer/RightPanel/BackButton
@onready var stage_info_label = $MarginContainer/HBoxContainer/LeftPanel/StageInfoLabel

# ステージデータ
var stages = [
	{"id": "stage_1_1", "name": "1-1 はじまりの草原"},
	{"id": "stage_1_2", "name": "1-2 分岐の迷路"},
	{"id": "stage_2_1", "name": "2-1 荒野の試練"},
	{"id": "stage_2_2", "name": "2-2 テスト"}
]

var selected_stage_index = 0
var selected_deck_index = 0

func _ready():
	# ステージボタン作成
	_create_stage_buttons()
	
	# デッキボタン作成
	_create_deck_buttons()
	
	# ボタン接続
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# 初期選択
	_select_stage(0)
	_select_deck(GameData.selected_deck_index)

func _create_stage_buttons():
	# 既存の子を削除（即時削除でWeb版のタイミング問題を回避）
	for child in stage_list.get_children():
		child.free()
	
	# ステージボタン作成
	for i in range(stages.size()):
		var btn = Button.new()
		btn.text = stages[i].name
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_stage_selected.bind(i))
		stage_list.add_child(btn)

func _create_deck_buttons():
	# 既存の子を削除（即時削除でWeb版のタイミング問題を回避）
	for child in deck_list.get_children():
		child.free()
	
	# デッキボタン作成（6個）
	for i in range(6):
		var btn = Button.new()
		var deck = GameData.player_data.decks[i] if i < GameData.player_data.decks.size() else {"name": "ブック" + str(i + 1)}
		btn.text = deck.get("name", "ブック" + str(i + 1))
		btn.custom_minimum_size = Vector2(150, 40)
		btn.pressed.connect(_on_deck_selected.bind(i))
		deck_list.add_child(btn)

func _select_stage(index: int):
	selected_stage_index = index
	
	# ボタンの見た目を更新
	for i in range(stage_list.get_child_count()):
		var btn = stage_list.get_child(i)
		if btn is Button:
			btn.disabled = (i == index)
	
	# ステージ情報表示
	if stage_info_label:
		var stage = stages[index]
		stage_info_label.text = "選択中: " + stage.name

func _select_deck(index: int):
	selected_deck_index = index
	
	# ボタンの見た目を更新
	for i in range(deck_list.get_child_count()):
		var btn = deck_list.get_child(i)
		if btn is Button:
			btn.disabled = (i == index)

func _on_stage_selected(index: int):
	print("ステージ選択: ", stages[index].name)
	_select_stage(index)

func _on_deck_selected(index: int):
	print("デッキ選択: ブック", index + 1)
	_select_deck(index)

func _on_start_pressed():
	# 選択を保存
	GameData.selected_stage_id = stages[selected_stage_index].id
	GameData.selected_deck_index = selected_deck_index
	
	print("クエスト開始: ", GameData.selected_stage_id, " / デッキ: ", selected_deck_index + 1)
	
	# クエスト画面へ遷移
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Quest.tscn")

func _on_back_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")
