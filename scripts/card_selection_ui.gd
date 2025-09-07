extends Control
class_name CardSelectionUI

# カード選択UI

signal card_selected(card_index: int)
signal selection_cancelled()

var card_buttons = []
var pass_button: Button
var info_label: Label
var cost_labels = []

# 現在の選択状態
var is_active = false
var available_magic = 0

func _ready():
	visible = false
	setup_ui()

func setup_ui():
	# 背景パネル
	var panel = Panel.new()
	panel.size = Vector2(800, 300)
	panel.position = Vector2(100, 250)
	add_child(panel)
	
	# 情報ラベル
	info_label = Label.new()
	info_label.text = "召喚するクリーチャーを選んでください"
	info_label.position = Vector2(150, 270)
	info_label.add_theme_font_size_override("font_size", 20)
	add_child(info_label)
	
	# パスボタン
	pass_button = Button.new()
	pass_button.text = "召喚しない"
	pass_button.position = Vector2(350, 500)
	pass_button.size = Vector2(120, 40)
	pass_button.pressed.connect(_on_pass_pressed)
	add_child(pass_button)

# カード選択画面を表示
func show_selection(hand_data: Array, magic: int):
	if hand_data.is_empty():
		print("手札がありません")
		emit_signal("selection_cancelled")
		return
	
	visible = true
	is_active = true
	available_magic = magic
	
	# 既存のボタンをクリア
	for button in card_buttons:
		button.queue_free()
	card_buttons.clear()
	
	for label in cost_labels:
		label.queue_free()
	cost_labels.clear()
	
	# カードボタンを作成
	for i in range(hand_data.size()):
		var card_data = hand_data[i]
		create_card_button(card_data, i)
	
	info_label.text = "召喚するクリーチャーを選んでください (魔力: " + str(magic) + "G)"

# カードボタンを作成
func create_card_button(card_data: Dictionary, index: int):
	# カードボタン
	var button = Button.new()
	button.position = Vector2(150 + index * 110, 320)
	button.size = Vector2(100, 140)
	button.clip_contents = true
	
	# カード情報を表示
	var card_text = card_data.get("name", "不明") + "\n"
	card_text += "コスト: " + str(card_data.get("cost", 0)) + "\n"
	card_text += "ST: " + str(card_data.get("damage", 0)) + "\n"
	card_text += "HP: " + str(card_data.get("block", 0))
	button.text = card_text
	
	# 属性による色分け
	match card_data.get("element", ""):
		"火":
			button.modulate = Color(1.0, 0.7, 0.7)
		"水":
			button.modulate = Color(0.7, 0.7, 1.0)
		"風":
			button.modulate = Color(0.7, 1.0, 0.7)
		"土":
			button.modulate = Color(0.9, 0.8, 0.6)
	
	# コストが払えない場合は無効化
	var cost = card_data.get("cost", 0) * 10
	if cost > available_magic:
		button.disabled = true
		button.modulate.a = 0.5
	
	# クリックイベント
	button.pressed.connect(_on_card_selected.bind(index))
	
	add_child(button)
	card_buttons.append(button)
	
	# コストラベル
	var cost_label = Label.new()
	cost_label.text = str(cost) + "G"
	cost_label.position = Vector2(150 + index * 110, 470)
	cost_label.add_theme_font_size_override("font_size", 16)
	
	if cost > available_magic:
		cost_label.modulate = Color(1, 0.3, 0.3)
	else:
		cost_label.modulate = Color(0.3, 1, 0.3)
	
	add_child(cost_label)
	cost_labels.append(cost_label)

# カードが選択された
func _on_card_selected(index: int):
	if not is_active:
		return
	
	print("カード選択: インデックス ", index)
	hide_selection()
	emit_signal("card_selected", index)

# パスボタンが押された
func _on_pass_pressed():
	if not is_active:
		return
	
	print("召喚をパス")
	hide_selection()
	emit_signal("selection_cancelled")

# 選択画面を非表示
func hide_selection():
	visible = false
	is_active = false
	
	# ボタンをクリア
	for button in card_buttons:
		button.queue_free()
	card_buttons.clear()
	
	for label in cost_labels:
		label.queue_free()
	cost_labels.clear()

# 土地レベルアップ選択を表示（将来実装用）
func show_upgrade_selection(tile_info: Dictionary, magic: int):
	visible = true
	is_active = true
	available_magic = magic
	
	# 既存のボタンをクリア
	for button in card_buttons:
		button.queue_free()
	card_buttons.clear()
	
	info_label.text = "土地をレベルアップしますか？ (現在Lv" + str(tile_info.get("level", 1)) + ")"
	
	# レベルアップボタン
	var upgrade_button = Button.new()
	upgrade_button.text = "レベルアップ\n(コスト: " + str(tile_info.get("level", 1) * 100) + "G)"
	upgrade_button.position = Vector2(300, 350)
	upgrade_button.size = Vector2(150, 60)
	
	var upgrade_cost = tile_info.get("level", 1) * 100
	if upgrade_cost > magic:
		upgrade_button.disabled = true
	
	upgrade_button.pressed.connect(_on_upgrade_selected)
	add_child(upgrade_button)
	card_buttons.append(upgrade_button)
	
	pass_button.text = "レベルアップしない"

# レベルアップが選択された
func _on_upgrade_selected():
	print("土地レベルアップ選択")
	hide_selection()
	# TODO: レベルアップ処理を呼び出す
