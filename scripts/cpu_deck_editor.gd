extends Control

# CPUデッキ編集画面
# 全カード4枚ずつのプールから選択してCPUデッキを編集

var current_deck = {}  # 現在編集中のデッキ
var current_filter = "all"  # フィルター状態
var card_dialog = null
var selected_card_id = 0
var count_buttons = []  # 枚数選択ボタンの配列

# 正確なノードパス
@onready var title_label = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/TitleLabel
@onready var button_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/Control/HBoxContainer
@onready var scroll_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer
@onready var grid_container = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/ContentHBox/DeckScrollContainer/GridContainer
@onready var info_panel_container = $MarginContainer/HBoxContainer/LeftPanel/InfoPanelContainer
@onready var right_vbox = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer
@onready var card_type_count = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardTypeCount
@onready var card_count_label = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/CardCountLabel
@onready var save_button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/SaveButton
@onready var rename_button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/RenameButton
@onready var reset_button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/ResetButton
@onready var back_button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/BackButton

# インフォパネル
var CreatureInfoPanelScene = preload("res://scenes/ui/creature_info_panel.tscn")
var ItemInfoPanelScene = preload("res://scenes/ui/item_info_panel.tscn")
var SpellInfoPanelScene = preload("res://scenes/ui/spell_info_panel.tscn")
var current_info_panel: Control = null

func _ready():
	# フィルターボタン接続（9個）
	var buttons = button_container.get_children()
	if buttons.size() >= 9:
		buttons[0].pressed.connect(_on_filter_pressed.bind("deck"))     # DeckButton
		buttons[1].pressed.connect(_on_filter_pressed.bind("all"))      # AllButton
		buttons[2].pressed.connect(_on_filter_pressed.bind("無"))       # NeutralButton
		buttons[3].pressed.connect(_on_filter_pressed.bind("火"))       # FireButton
		buttons[4].pressed.connect(_on_filter_pressed.bind("水"))       # WaterButton
		buttons[5].pressed.connect(_on_filter_pressed.bind("地"))       # EarthButton
		buttons[6].pressed.connect(_on_filter_pressed.bind("風"))       # WindButton
		buttons[7].pressed.connect(_on_filter_pressed.bind("item"))     # ItemButton
		buttons[8].pressed.connect(_on_filter_pressed.bind("spell"))    # SpellButton
	
	# InfoPanelContainerのマウスフィルターを設定
	info_panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 右側ボタン接続
	save_button.pressed.connect(_on_save_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# 選択したデッキを読み込み
	load_deck()
	
	# タイトル設定
	var deck_name = CpuDeckData.get_current_deck()["name"]
	title_label.text = "CPUデッキ編集 - " + deck_name
	
	# ダイアログ作成
	create_card_dialog()
	
	# カード一覧を表示（最初はデッキ内のカードのみ）
	display_cards("deck")

func load_deck():
	# CpuDeckDataから現在のデッキを読み込み
	current_deck = CpuDeckData.get_current_deck()["cards"].duplicate()
	update_card_count()

func create_card_dialog():
	card_dialog = VBoxContainer.new()
	card_dialog.name = "CardDialog"
	card_dialog.add_theme_constant_override("separation", 10)
	card_dialog.visible = false

	# 背景パネル
	var bg = PanelContainer.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	bg_style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", bg_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	bg.add_child(vbox)

	# 所持枚数/デッキ内枚数ラベル
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.add_theme_font_size_override("font_size", 30)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	# 枚数選択ボタン（横並び）
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)

	count_buttons.clear()
	for i in range(5):
		var btn = Button.new()
		btn.text = str(i) + "枚"
		btn.custom_minimum_size = Vector2(80, 70)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_count_selected.bind(i))
		hbox.add_child(btn)
		count_buttons.append(btn)

	vbox.add_child(hbox)

	# スペーサー
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	# 閉じるボタン
	var close_btn = Button.new()
	close_btn.text = "閉じる"
	close_btn.custom_minimum_size = Vector2(160, 70)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(_on_dialog_closed)
	vbox.add_child(close_btn)

	card_dialog.add_child(bg)

	# InfoPanelContainer内に配置（Popup不使用でスクロールをブロックしない）
	info_panel_container.add_child(card_dialog)

## ダイアログが閉じられたとき（インフォパネルも閉じる）
func _on_dialog_closed():
	card_dialog.visible = false
	_close_info_panel()

## インフォパネルを閉じる
func _close_info_panel():
	if current_info_panel and is_instance_valid(current_info_panel):
		current_info_panel.queue_free()
		current_info_panel = null

func _on_filter_pressed(filter_type: String):
	current_filter = filter_type
	display_cards(filter_type)

func display_cards(filter: String):
	clear_card_list()
	
	var cards_to_show = []
	
	# 属性フィルターのマッピング（日本語 → 英語）
	var element_map = {
		"無": "neutral",
		"火": "fire",
		"水": "water",
		"地": "earth",
		"風": "wind"
	}
	
	# フィルターに応じてカードを取得
	if filter == "deck":
		# デッキに入っているカードだけ
		for card_id in current_deck.keys():
			var card = CardLoader.get_card_by_id(card_id)
			if not card.is_empty():
				cards_to_show.append(card)
	elif filter == "all":
		# 全クリーチャーカード
		for card in CardLoader.all_cards:
			if card.type == "creature":
				cards_to_show.append(card)
	elif filter == "spell":
		# スペルカード
		for card in CardLoader.all_cards:
			if card.type == "spell":
				cards_to_show.append(card)
	elif filter == "item":
		# アイテムカード
		for card in CardLoader.all_cards:
			if card.type == "item":
				cards_to_show.append(card)
	else:
		# 属性フィルター（火・水・地・風・無）
		var target_element = element_map.get(filter, filter)
		
		for card in CardLoader.all_cards:
			# この属性のクリーチャーカードか？
			if card.has("element") and card.element == target_element:
				cards_to_show.append(card)
	
	# カードボタンを生成
	for card in cards_to_show:
		create_card_button(card)

func clear_card_list():
	for child in grid_container.get_children():
		child.queue_free()

func create_card_button(card_data: Dictionary):
	# CPUデッキは全カード4枚ずつ
	var owned_count = CpuDeckData.MAX_COPIES_PER_CARD
	var deck_count = current_deck.get(card_data.id, 0)
	var rarity = card_data.get("rarity", "N")
	
	# ボタン
	var button = Button.new()
	button.custom_minimum_size = Vector2(263, 420)
	button.set_meta("card_id", card_data.id)
	
	# テキスト表示
	var card_name = card_data.get("name", "???")
	var dev_name = card_data.get("dev_name", "")
	var element = card_data.get("element", "")
	var card_type = card_data.get("type", "")

	button.text = card_name
	if not dev_name.is_empty():
		button.text += "\n" + dev_name
	button.text += "\n[" + rarity + "]"
	if not element.is_empty():
		button.text += " " + element
	button.text += "\n使用可: " + str(owned_count) + "枚"
	if deck_count > 0:
		button.text += "\nデッキ: " + str(deck_count) + "枚"
	
	# クリーチャーならAP/HP表示
	if card_type == "creature":
		var ap = card_data.get("ap", 0)
		var hp = card_data.get("hp", 0)
		button.text += "\nAP:%d / HP:%d" % [ap, hp]
	
	button.add_theme_font_size_override("font_size", 24)

	# レアリティで背景色
	match rarity:
		"R":
			button.modulate = Color(1.0, 0.9, 0.7)
		"S":
			button.modulate = Color(0.9, 0.85, 1.0)
		"N":
			button.modulate = Color(0.85, 0.9, 1.0)
		"C":
			button.modulate = Color(0.9, 0.9, 0.9)
	
	button.pressed.connect(_on_card_button_pressed.bind(card_data.id))
	grid_container.add_child(button)

func _on_card_button_pressed(card_id: int):
	selected_card_id = card_id
	var card = CardLoader.get_card_by_id(card_id)
	var card_type = card.get("type", "")
	
	# カードタイプに応じたインフォパネルを表示
	_show_info_panel(card, card_type)

## カードタイプに応じたインフォパネルを表示
func _show_info_panel(card: Dictionary, card_type: String):
	# 既存のインフォパネルを削除
	if current_info_panel and is_instance_valid(current_info_panel):
		current_info_panel.queue_free()
		current_info_panel = null
	
	# インフォパネルの紙部分を右側パネルに表示
	_show_info_in_right_panel(card, card_type)
	
	# 枚数選択ダイアログを表示
	_show_count_dialog()

## InfoPanelContainerにインフォパネルを表示
func _show_info_in_right_panel(card: Dictionary, card_type: String):
	# 既存のプレビューを削除
	if current_info_panel and is_instance_valid(current_info_panel):
		current_info_panel.queue_free()
		current_info_panel = null

	# タイプに応じたパネルをインスタンス化
	match card_type:
		"creature":
			current_info_panel = CreatureInfoPanelScene.instantiate()
		"item":
			current_info_panel = ItemInfoPanelScene.instantiate()
		"spell":
			current_info_panel = SpellInfoPanelScene.instantiate()

	if not current_info_panel:
		return

	# InfoPanelContainerに追加
	info_panel_container.add_child(current_info_panel)

	# マウスイベントを透過させてスクロールを妨げない
	_set_mouse_filter_ignore(current_info_panel)

	# アンカーをリセットし、サイズをコンテナに制限
	current_info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	current_info_panel.anchor_left = 0
	current_info_panel.anchor_top = 0
	current_info_panel.anchor_right = 0
	current_info_panel.anchor_bottom = 0
	current_info_panel.size = info_panel_container.size
	current_info_panel.clip_contents = true

	# データを読み込む
	match card_type:
		"creature":
			current_info_panel.show_view_mode(card, -1, false)
		"item":
			current_info_panel.show_item_info(card)
		"spell":
			current_info_panel.show_spell_info(card)

	await get_tree().process_frame

	if not info_panel_container or not is_instance_valid(info_panel_container):
		return

	# データ読み込み後に再度マウスフィルター設定（動的追加ノード対応）
	_set_mouse_filter_ignore(current_info_panel)

	# コンテナ基準で配置
	current_info_panel.position = Vector2(0, 0)
	current_info_panel.scale = Vector2(1.0, 1.0)
	var main_container = current_info_panel.get_node_or_null("MainContainer")
	if main_container:
		main_container.position = Vector2(-80, -90)

## 枚数選択ダイアログを表示
func _show_count_dialog():
	var owned = CpuDeckData.MAX_COPIES_PER_CARD
	var in_deck = current_deck.get(selected_card_id, 0)

	# 情報ラベルを更新
	var info_label = card_dialog.find_child("InfoLabel", true, false)
	if info_label:
		info_label.text = "使用可: %d枚 / デッキ内: %d枚" % [owned, in_deck]

	# ボタンの有効/無効を設定（全て有効）
	for i in range(count_buttons.size()):
		count_buttons[i].disabled = false
		count_buttons[i].modulate = Color(1, 1, 1)

	# インフォパネルの下に配置（コンテナ下部）
	var container_h = info_panel_container.size.y
	card_dialog.position = Vector2(0, container_h - card_dialog.size.y - 10)
	card_dialog.size.x = info_panel_container.size.x
	card_dialog.visible = true
	# 最前面に表示
	info_panel_container.move_child(card_dialog, -1)

func _on_count_selected(count: int):
	# デッキに設定
	if count == 0:
		current_deck.erase(selected_card_id)
	else:
		current_deck[selected_card_id] = count
	
	update_card_count()
	
	# 該当カードのボタンだけ更新
	if current_filter == "deck":
		display_cards(current_filter)
	else:
		update_single_card_button(selected_card_id)
	
	card_dialog.visible = false

func update_single_card_button(card_id: int):
	var card = CardLoader.get_card_by_id(card_id)
	var owned_count = CpuDeckData.MAX_COPIES_PER_CARD
	var deck_count = current_deck.get(card_id, 0)
	
	# 既存のボタンを探して更新
	for button in grid_container.get_children():
		if button.has_meta("card_id") and button.get_meta("card_id") == card_id:
			var card_name = card.get("name", "???")
			var dev_name = card.get("dev_name", "")
			var element = card.get("element", "")

			button.text = card_name
			if not dev_name.is_empty():
				button.text += "\n" + dev_name
			button.text += "\n"
			if not element.is_empty():
				button.text += "[" + element + "] "
			button.text += str(owned_count) + "枚"
			if deck_count > 0:
				button.text += " (デッキ:" + str(deck_count) + ")"
			break

func update_card_count():
	var total = 0
	var fire_count = 0
	var water_count = 0
	var earth_count = 0
	var wind_count = 0
	var neutral_count = 0
	var item_count = 0
	var spell_count = 0
	
	for card_id in current_deck.keys():
		var count = current_deck[card_id]
		total += count
		var card = CardLoader.get_card_by_id(card_id)
		if card.is_empty():
			continue
		if card.type == "item":
			item_count += count
		elif card.type == "spell":
			spell_count += count
		else:
			match card.get("element", ""):
				"fire": fire_count += count
				"water": water_count += count
				"earth": earth_count += count
				"wind": wind_count += count
				_: neutral_count += count
	
	# 種別カウント表示
	var type_text = "[font_size=48]"
	type_text += "[color=#ff4545]●[/color] %d\n" % fire_count
	type_text += "[color=#4587ff]●[/color] %d\n" % water_count
	type_text += "[color=#87cc45]●[/color] %d\n" % earth_count
	type_text += "[color=#ffcc45]●[/color] %d\n" % wind_count
	type_text += "[color=#aaaaaa]●[/color] %d\n" % neutral_count
	type_text += "[color=#aaaaaa]▲[/color] %d\n" % item_count
	type_text += "[color=#aaaaaa]◆[/color] %d" % spell_count
	type_text += "[/font_size]"
	card_type_count.text = type_text
	
	card_count_label.text = "現在: " + str(total) + "/50"
	
	# 50枚以下なら保存可能
	if total <= 50:
		save_button.disabled = false
		save_button.modulate = Color(1, 1, 1)
	else:
		save_button.disabled = true
		save_button.modulate = Color(0.5, 0.5, 0.5)

func _on_save_pressed():
	CpuDeckData.save_deck(CpuDeckData.selected_deck_index, current_deck)
	print("CPUデッキ保存完了")
	
	# 保存完了通知
	var info = AcceptDialog.new()
	info.dialog_text = "CPUデッキを保存しました。"
	info.title = "保存完了"
	add_child(info)
	info.popup_centered()

func _on_rename_pressed():
	var dialog = AcceptDialog.new()
	dialog.title = "デッキ名変更"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "新しいデッキ名を入力してください:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.name = "NameInput"
	line_edit.text = CpuDeckData.get_current_deck()["name"]
	line_edit.custom_minimum_size = Vector2(300, 50)
	vbox.add_child(line_edit)
	
	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		var new_name = line_edit.text.strip_edges()
		if not new_name.is_empty():
			CpuDeckData.rename_deck(CpuDeckData.selected_deck_index, new_name)
			title_label.text = "CPUデッキ編集 - " + new_name
	)
	
	add_child(dialog)
	dialog.popup_centered()

func _on_reset_pressed():
	var confirm_dialog = ConfirmationDialog.new()
	
	var current_deck_name = CpuDeckData.get_current_deck()["name"]
	
	confirm_dialog.dialog_text = "「" + current_deck_name + "」を空デッキ（0枚）にリセットしますか？\n\n現在の内容は失われます。"
	confirm_dialog.title = "デッキリセット確認"
	confirm_dialog.ok_button_text = "リセットする"
	confirm_dialog.cancel_button_text = "キャンセル"
	confirm_dialog.size = Vector2(500, 200)
	
	confirm_dialog.confirmed.connect(_on_reset_confirmed)
	
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _on_reset_confirmed():
	print("【CPUデッキリセット】デッキ", CpuDeckData.selected_deck_index, "をリセットします")
	
	# 空デッキ
	current_deck = {}
	
	# CpuDeckDataにも保存
	CpuDeckData.save_deck(CpuDeckData.selected_deck_index, current_deck)
	
	print("【CPUデッキリセット】完了")
	
	# 表示を更新
	update_card_count()
	display_cards(current_filter)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/CpuDeckSelect.tscn")

## マウスフィルターを再帰的にIGNOREに設定
func _set_mouse_filter_ignore(node: Control):
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_set_mouse_filter_ignore(child)
