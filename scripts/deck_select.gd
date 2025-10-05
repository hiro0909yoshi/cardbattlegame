extends Control

func _ready():
	# 6個のブックボタンを接続
	for i in range(1, 7):
		var button = get_node("DeckButton" + str(i))
		button.pressed.connect(_on_deck_button_pressed.bind(i))
	
	$BackButton.pressed.connect(_on_back_pressed)

func _on_deck_button_pressed(deck_index: int):
	# ブック番号を保存（1〜6を0〜5に変換）
	GameData.selected_deck_index = deck_index - 1
	
	print("ブック", deck_index, "を選択")
	get_tree().change_scene_to_file("res://scenes/DeckEditor.tscn")

func _on_back_pressed():
	# アルバムメニューに戻る
	get_tree().change_scene_to_file("res://scenes/Album.tscn")
