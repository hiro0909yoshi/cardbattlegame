extends Control

## ブック選択画面
## ステージ選択後にブックを選んでクエスト開始

@onready var stage_info_label: Label = $MarginContainer/VBox/StageInfoLabel
@onready var deck_container: GridContainer = $MarginContainer/VBox/DeckContainer
@onready var start_button: Button = $MarginContainer/VBox/ButtonContainer/StartButton
@onready var back_button: Button = $MarginContainer/VBox/ButtonContainer/BackButton

var selected_deck_index: int = 0
var deck_buttons: Array = []

func _ready():
	# ボタン接続
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# ステージ情報表示
	_show_stage_info()
	
	# デッキボタン作成
	_create_deck_buttons()
	
	# 前回の選択を復元
	_select_deck(GameData.selected_deck_index)

## ステージ情報を表示
func _show_stage_info():
	var stage_id = GameData.selected_stage_id
	if stage_id.is_empty():
		stage_info_label.text = "ステージ未選択"
		return
	
	# ステージデータ読み込み
	var path = "res://data/master/stages/%s.json" % stage_id
	if not FileAccess.file_exists(path):
		stage_info_label.text = "ステージ: " + stage_id
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		stage_info_label.text = "ステージ: " + stage_id
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		stage_info_label.text = "ステージ: " + stage_id
		return
	
	var data = json.get_data()
	var stage_name = data.get("name", stage_id)
	stage_info_label.text = "ステージ: " + stage_name

## デッキボタンを作成
func _create_deck_buttons():
	# 既存をクリア
	for child in deck_container.get_children():
		child.queue_free()
	deck_buttons.clear()
	
	# デッキボタン作成（6個）
	for i in range(6):
		var deck = GameData.player_data.decks[i] if i < GameData.player_data.decks.size() else {"name": "ブック" + str(i + 1)}
		
		var btn = Button.new()
		btn.text = deck.get("name", "ブック" + str(i + 1))
		btn.custom_minimum_size = Vector2(200, 100)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_deck_selected.bind(i))
		
		deck_container.add_child(btn)
		deck_buttons.append(btn)

## デッキ選択
func _select_deck(index: int):
	selected_deck_index = index
	
	# ボタンの見た目を更新
	for i in range(deck_buttons.size()):
		var btn = deck_buttons[i]
		if i == index:
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color.YELLOW)
		else:
			btn.disabled = false
			btn.remove_theme_color_override("font_color")

## デッキ選択時
func _on_deck_selected(index: int):
	print("[BookSelect] デッキ選択: ブック", index + 1)
	_select_deck(index)

## 開始ボタン押下
func _on_start_pressed():
	# 選択を保存
	GameData.selected_deck_index = selected_deck_index
	
	print("[BookSelect] クエスト開始: ステージ=%s, デッキ=%d" % [GameData.selected_stage_id, selected_deck_index + 1])
	
	# クエスト画面へ遷移
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Quest.tscn")

## 戻るボタン押下
func _on_back_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/WorldStageSelect.tscn")
