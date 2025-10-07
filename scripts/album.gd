extends Control

@onready var left_vbox = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer
@onready var right_panel = $MarginContainer/HBoxContainer/RightPanel
@onready var scroll_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer/GridContainer

func _ready():
	# 初期状態：右側は非表示
	scroll_container.visible = false
	
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
	# デッキ編集画面へ
	get_tree().change_scene_to_file("res://scenes/DeckEditor.tscn")

func _on_card_list_pressed():
	print("カード一覧（未実装）")
	scroll_container.visible = false

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
