extends Control

# CPUデッキ選択画面
# 最大50個のCPUデッキから編集するデッキを選択

const DECKS_PER_PAGE = 10
var current_page = 0
var deck_buttons: Array = []

@onready var grid_container = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var page_label = $MarginContainer/VBoxContainer/PageContainer/PageLabel
@onready var prev_button = $MarginContainer/VBoxContainer/PageContainer/PrevButton
@onready var next_button = $MarginContainer/VBoxContainer/PageContainer/NextButton
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

func _ready():
	prev_button.pressed.connect(_on_prev_page)
	next_button.pressed.connect(_on_next_page)
	back_button.pressed.connect(_on_back_pressed)
	
	_display_decks()

func _display_decks():
	# 既存のボタンをクリア
	for child in grid_container.get_children():
		child.queue_free()
	deck_buttons.clear()
	
	# 現在のページのデッキを表示
	var start_index = current_page * DECKS_PER_PAGE
	var end_index = min(start_index + DECKS_PER_PAGE, CpuDeckData.MAX_DECKS)
	
	for i in range(start_index, end_index):
		var deck = CpuDeckData.get_deck(i)
		var button = _create_deck_button(i, deck)
		grid_container.add_child(button)
		deck_buttons.append(button)
	
	_update_page_label()

func _create_deck_button(index: int, deck: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(500, 200)
	button.add_theme_font_size_override("font_size", 36)
	
	var deck_name = deck.get("name", "CPUデッキ%d" % (index + 1))
	var card_count = CpuDeckData.get_deck_card_count(index)
	
	button.text = "%s\n%d / 50枚" % [deck_name, card_count]
	
	# カード枚数に応じて色を変更
	if card_count == 0:
		button.modulate = Color(0.7, 0.7, 0.7)  # グレー（空）
	elif card_count < 50:
		button.modulate = Color(1.0, 0.9, 0.7)  # 黄色（編集中）
	else:
		button.modulate = Color(0.7, 1.0, 0.7)  # 緑（完成）
	
	button.pressed.connect(_on_deck_selected.bind(index))
	return button

func _on_deck_selected(index: int):
	CpuDeckData.selected_deck_index = index
	get_tree().change_scene_to_file("res://scenes/CpuDeckEditor.tscn")

func _on_prev_page():
	if current_page > 0:
		current_page -= 1
		_display_decks()

func _on_next_page():
	var max_page = int(ceil(float(CpuDeckData.MAX_DECKS) / DECKS_PER_PAGE)) - 1
	if current_page < max_page:
		current_page += 1
		_display_decks()

func _update_page_label():
	var max_page = int(ceil(float(CpuDeckData.MAX_DECKS) / DECKS_PER_PAGE))
	page_label.text = "ページ %d / %d" % [current_page + 1, max_page]
	
	prev_button.disabled = (current_page == 0)
	next_button.disabled = (current_page >= max_page - 1)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")
