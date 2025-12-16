extends Control

# ボタンへのパス（新しい構造に対応）
@onready var grid = $MarginContainer/HBoxContainer/RightPanel/CenterContainer/GridContainer

func _ready():
	# 各ボタンの接続（実際のボタン名で）
	grid.get_node("QuestButton").pressed.connect(_on_quest_pressed)
	grid.get_node("SoloBattleButton").pressed.connect(_on_solo_battle_pressed)
	grid.get_node("NetBattleButton").pressed.connect(_on_net_battle_pressed)
	grid.get_node("DeckButton").pressed.connect(_on_album_pressed)  # DeckButtonをアルバムに
	grid.get_node("SettingsButton").pressed.connect(_on_settings_pressed)
	grid.get_node("ShopButton").pressed.connect(_on_shop_pressed)

# ========== ボタン処理 ==========
func _on_quest_pressed():
	print("クエスト選択 → ステージ選択画面へ")
	get_tree().change_scene_to_file("res://scenes/QuestSelect.tscn")

func _on_solo_battle_pressed():
	print("一人対戦選択 → ブック選択へ")
	# バトル用フラグを設定（メタデータを使用）
	GameData.set_meta("is_selecting_for_battle", true)
	# Album.tscnに遷移（バトルモードで起動）
	get_tree().change_scene_to_file("res://scenes/Album.tscn")

func _on_net_battle_pressed():
	print("NET対戦選択")
	# get_tree().change_scene_to_file("res://scenes/NetBattle.tscn")

func _on_album_pressed():
	print("アルバム選択")
	# 通常モードでAlbum.tscnを開く（フラグなし）
	get_tree().change_scene_to_file("res://scenes/Album.tscn")

func _on_settings_pressed():
	print("設定選択")
	# get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_shop_pressed():
	print("ショップ選択")
	# get_tree().change_scene_to_file("res://scenes/Shop.tscn")
