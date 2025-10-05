extends Control

func _ready():
	$DeckEditButton.pressed.connect(_on_deck_edit_pressed)
	$CardListButton.pressed.connect(_on_card_list_pressed)
	$BackButton.pressed.connect(_on_back_pressed)

func _on_deck_edit_pressed():
	# ブック選択画面に移動（まだ未作成）
	get_tree().change_scene_to_file("res://scenes/DeckSelect.tscn")
	print("ブック選択画面（未実装）")

func _on_card_list_pressed():
	# 所持カード一覧に移動（まだ未作成）
	print("所持カード一覧（未実装）")

func _on_back_pressed():
	# メインメニューに戻る
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
