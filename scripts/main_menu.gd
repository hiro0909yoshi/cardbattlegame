extends Control

func _ready():
	# ボタンを取得してシグナル接続
	$StartButton.pressed.connect(_on_start_pressed)
	$DeckButton.pressed.connect(_on_deck_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	# ゲーム画面に移動
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_deck_pressed():
	# デッキ編集画面に移動（まだ作ってないので後で）
	get_tree().change_scene_to_file("res://scenes/Album.tscn")
	print("デッキ編集画面（未実装）")

func _on_quit_pressed():
	# ゲーム終了
	get_tree().quit()
