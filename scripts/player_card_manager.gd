extends Control

# プレイヤーカード管理画面
# 所持カードのリセットと全カード追加を行う

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var reset_button: Button = $MarginContainer/VBoxContainer/ResetButton
@onready var add_all_button: Button = $MarginContainer/VBoxContainer/AddAllButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	add_all_button.pressed.connect(_on_add_all_pressed)
	
	_update_status()

func _update_status():
	var owned_cards = UserCardDB.get_all_cards()
	var total_count = 0
	for card in owned_cards:
		total_count += card.get("count", 0)
	
	status_label.text = "所持カード: %d種類 / 合計%d枚" % [owned_cards.size(), total_count]

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_reset_pressed():
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "⚠️ 警告 ⚠️\n\n所持カードをすべて削除しますか？\n\nこの操作は取り消せません！"
	confirm.title = "所持カードリセット"
	confirm.ok_button_text = "リセットする"
	confirm.cancel_button_text = "キャンセル"
	confirm.size = Vector2(500, 250)
	
	confirm.confirmed.connect(_on_reset_confirmed)
	add_child(confirm)
	confirm.popup_centered()

func _on_reset_confirmed():
	UserCardDB.reset_database()
	print("[PlayerCardManager] 所持カードをリセットしました")
	
	_update_status()
	
	var info = AcceptDialog.new()
	info.dialog_text = "所持カードをリセットしました。"
	info.title = "完了"
	add_child(info)
	info.popup_centered()

func _on_add_all_pressed():
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "すべてのカードを4枚ずつ追加しますか？\n\n（既存の所持カードは上書きされます）"
	confirm.title = "全カード追加"
	confirm.ok_button_text = "追加する"
	confirm.cancel_button_text = "キャンセル"
	confirm.size = Vector2(500, 200)
	
	confirm.confirmed.connect(_on_add_all_confirmed)
	add_child(confirm)
	confirm.popup_centered()

func _on_add_all_confirmed():
	# まずリセット
	UserCardDB.reset_database()
	
	# 全カードを4枚ずつ追加
	UserCardDB.import_all_cards_from_json()
	
	print("[PlayerCardManager] 全カードを4枚ずつ追加しました")
	
	_update_status()
	
	var info = AcceptDialog.new()
	info.dialog_text = "すべてのカードを4枚ずつ追加しました。"
	info.title = "完了"
	add_child(info)
	info.popup_centered()
