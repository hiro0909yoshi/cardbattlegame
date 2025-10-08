extends Control

@onready var left_vbox = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer
@onready var right_panel = $MarginContainer/HBoxContainer/RightPanel
@onready var scroll_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer/GridContainer

# モード管理
var is_battle_mode = false  # バトル用かデッキ編集用か

func _ready():
	# GameDataから起動モードを取得（メタデータを使用）
	if GameData.has_meta("is_selecting_for_battle"):
		is_battle_mode = GameData.get_meta("is_selecting_for_battle")
	else:
		is_battle_mode = false
	
	# バトルモードなら最初からブック選択表示
	if is_battle_mode:
		scroll_container.visible = true
		print("バトル用ブック選択モード")
	else:
		scroll_container.visible = false
		print("通常アルバムモード")
	
	# 左側ボタン接続
	left_vbox.get_node("DeckEditButton").pressed.connect(_on_deck_edit_pressed)
	left_vbox.get_node("CardListButton").pressed.connect(_on_card_list_pressed)
	left_vbox.get_node("BackButton").pressed.connect(_on_back_pressed)
	
	# ブックボタン接続（book1〜book6）
	for i in range(1, 7):
		var book_button = grid_container.get_node("book" + str(i))
		book_button.pressed.connect(_on_book_selected.bind(i - 1))

func _on_deck_edit_pressed():
	print("ブック選択画面表示")
	# 右側パネルを表示
	scroll_container.visible = true

func _on_book_selected(book_index: int):
	print("ブック", book_index + 1, "選択")
	# 選択したブックを保存
	GameData.selected_deck_index = book_index
	
	# モードに応じて遷移先を変える
	if is_battle_mode:
		# バトルモードの場合はフラグを消してバトル画面へ
		GameData.remove_meta("is_selecting_for_battle")
		print("→ バトル開始")
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		# 通常モードの場合はデッキ編集画面へ
		print("→ デッキ編集")
		get_tree().change_scene_to_file("res://scenes/DeckEditor.tscn")

func _on_card_list_pressed():
	print("カード一覧（未実装）")
	scroll_container.visible = false

func _on_back_pressed():
	# バトルモードの場合はフラグをクリア
	if is_battle_mode:
		GameData.remove_meta("is_selecting_for_battle")
	
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
