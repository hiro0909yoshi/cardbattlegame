extends Control

# クエスト選択画面
# ステージ選択 + デッキ選択

@onready var stage_list = $MarginContainer/HBoxContainer/LeftPanel/StageList
@onready var deck_list = $MarginContainer/HBoxContainer/RightPanel/DeckList
@onready var start_button = $MarginContainer/HBoxContainer/RightPanel/StartButton
@onready var back_button = $MarginContainer/HBoxContainer/RightPanel/BackButton
@onready var stage_info_label = $MarginContainer/HBoxContainer/LeftPanel/StageInfoLabel

# ワールドごとにステージをグループ化
var worlds = [
	{
		"id": "world_1",
		"name": "ワールド1 - 草原の国",
		"stages": [
			{"id": "stage_1_1", "name": "1-1 はじまりの草原"},
			{"id": "stage_1_2", "name": "1-2 分岐の迷路"},
			{"id": "stage_1_3", "name": "1-3 十字路の試練"},
			{"id": "stage_1_4", "name": "1-4 新マップテスト"},
			{"id": "stage_1_5", "name": "1-5 8の字の試練"},
			{"id": "stage_1_6", "name": "1-6 迷路の試練"}
		]
	},
	{
		"id": "world_2", 
		"name": "ワールド2 - 荒野",
		"stages": [
			{"id": "stage_2_1", "name": "2-1 荒野の試練"},
			{"id": "stage_2_2", "name": "2-2 テスト"}
		]
	}
]

# フラット化したステージリスト（内部用）
var stages = []
var selected_stage_index = 0
var selected_deck_index = 0

# ワールド展開状態
var world_expanded = {}

func _ready():
	# ステージリストをフラット化
	_flatten_stages()
	
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

func _flatten_stages():
	stages.clear()
	for world in worlds:
		for stage in world.stages:
			stages.append(stage)

func _create_stage_buttons():
	# 既存の子を削除
	for child in stage_list.get_children():
		child.free()
	
	var stage_index = 0
	
	for world in worlds:
		# ワールドヘッダー（折りたたみボタン）
		var world_btn = Button.new()
		world_btn.text = "▼ " + world.name
		world_btn.custom_minimum_size = Vector2(400, 80)
		world_btn.add_theme_font_size_override("font_size", 24)
		var world_id = world.id
		world_btn.pressed.connect(_on_world_toggled.bind(world_id))
		stage_list.add_child(world_btn)
		
		# 初期状態は展開
		if not world_expanded.has(world_id):
			world_expanded[world_id] = true
		
		# ステージコンテナ
		var stage_container = VBoxContainer.new()
		stage_container.name = world_id + "_stages"
		stage_list.add_child(stage_container)
		
		# ステージボタン作成
		for stage in world.stages:
			var btn = Button.new()
			btn.text = "    " + stage.name
			btn.custom_minimum_size = Vector2(380, 120)
			btn.add_theme_font_size_override("font_size", 28)
			btn.pressed.connect(_on_stage_selected.bind(stage_index))
			stage_container.add_child(btn)
			stage_index += 1
		
		# スペーサー
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 20)
		stage_list.add_child(spacer)

func _on_world_toggled(world_id: String):
	world_expanded[world_id] = not world_expanded[world_id]
	
	# コンテナの表示切り替え
	var container = stage_list.get_node_or_null(world_id + "_stages")
	if container:
		container.visible = world_expanded[world_id]
	
	# ボタンテキスト更新
	for child in stage_list.get_children():
		if child is Button and world_id in child.text:
			var prefix = "▼ " if world_expanded[world_id] else "▶ "
			for world in worlds:
				if world.id == world_id:
					child.text = prefix + world.name
					break

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
	
	# 全ステージボタンの見た目を更新
	var current_index = 0
	for world in worlds:
		var container = stage_list.get_node_or_null(world.id + "_stages")
		if container:
			for btn in container.get_children():
				if btn is Button:
					btn.disabled = (current_index == index)
					current_index += 1
	
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
