extends Control

var current_deck = {}  # 現在編集中のデッキ
var current_filter = "all"  # フィルター状態

func _ready():
	# ボタン接続
	$BackButton.pressed.connect(_on_back_pressed)
	$SaveButton.pressed.connect(_on_save_pressed)
	
	# フィルターボタン接続
	$DeckButton.pressed.connect(_on_filter_pressed.bind("deck"))
	$NeutralButton.pressed.connect(_on_filter_pressed.bind("無"))
	$FireButton.pressed.connect(_on_filter_pressed.bind("火"))
	$WaterButton.pressed.connect(_on_filter_pressed.bind("水"))
	$EarthButton.pressed.connect(_on_filter_pressed.bind("地"))
	$WindButton.pressed.connect(_on_filter_pressed.bind("風"))
	$ItemButton.pressed.connect(_on_filter_pressed.bind("item"))
	$SpellButton.pressed.connect(_on_filter_pressed.bind("spell"))
	# 選択したブックを読み込み
	load_deck()
	
	# タイトルを更新
	var deck_name = GameData.player_data.decks[GameData.selected_deck_index]["name"]
	$TitleLabel.text = "デッキ編集 - " + deck_name

func load_deck():
	# GameDataから現在のブックを読み込み
	current_deck = GameData.get_current_deck()["cards"].duplicate()
	update_card_count()

func _on_filter_pressed(filter_type: String):
	current_filter = filter_type
	# TODO: カードリストを更新
	print("フィルター: ", filter_type)

func update_card_count():
	var total = 0
	for count in current_deck.values():
		total += count
	
	$CardCountLabel.text = "現在: " + str(total) + "/50"
	
	# 50枚の時だけ保存ボタン有効化
	$SaveButton.disabled = (total != 50)

func _on_save_pressed():
	# GameDataに保存
	GameData.save_deck(GameData.selected_deck_index, current_deck)
	print("保存完了")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/DeckSelect.tscn")
