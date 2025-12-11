class_name SpellAndMysticUI
extends Control

# シグナル
signal creature_selected(index: int)
signal mystic_art_selected(index: int)
signal type_selected(type_name: String)
signal selection_cancelled

# UI要素
var creature_list: ItemList
var mystic_art_list: ItemList
var type_list: ItemList

# システム参照
var ui_manager_ref = null

# タイプ選択用
var type_options: Array = []

# 状態
var available_creatures: Array = []
var selected_creature_index: int = -1

func _ready():
	# 親Controlの設定（マウス入力を子に通す）
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	_create_ui_elements()
	_setup_signals()

func _create_ui_elements():
	"""UI要素を動的作成"""
	
	# クリーチャーリスト
	creature_list = ItemList.new()
	creature_list.name = "CreatureList"
	creature_list.custom_minimum_size = Vector2(300, 250)
	creature_list.select_mode = ItemList.SELECT_SINGLE
	creature_list.allow_reselect = true
	creature_list.z_index = 100
	creature_list.mouse_filter = Control.MOUSE_FILTER_STOP
	creature_list.item_selected.connect(_on_creature_selected)
	add_child(creature_list)
	
	# 秘術リスト
	mystic_art_list = ItemList.new()
	mystic_art_list.name = "MysticArtList"
	mystic_art_list.custom_minimum_size = Vector2(300, 250)
	mystic_art_list.select_mode = ItemList.SELECT_SINGLE
	mystic_art_list.allow_reselect = true
	mystic_art_list.z_index = 100
	mystic_art_list.mouse_filter = Control.MOUSE_FILTER_STOP
	mystic_art_list.item_selected.connect(_on_mystic_art_selected)
	add_child(mystic_art_list)
	mystic_art_list.visible = false
	
	# タイプ選択リスト
	type_list = ItemList.new()
	type_list.name = "TypeList"
	type_list.custom_minimum_size = Vector2(300, 150)
	type_list.select_mode = ItemList.SELECT_SINGLE
	type_list.allow_reselect = true
	type_list.z_index = 100
	type_list.mouse_filter = Control.MOUSE_FILTER_STOP
	type_list.item_selected.connect(_on_type_selected)
	add_child(type_list)
	type_list.visible = false
	
	_update_positions()

func _setup_signals():
	"""シグナルハンドラーを設定"""
	pass

## UIManager参照を設定
func set_ui_manager(manager) -> void:
	ui_manager_ref = manager


func _update_positions():
	"""UI要素の位置を更新"""
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 20
	var list_width = 300
	var list_height = 250
	
	# クリーチャーリスト（画面右上）
	creature_list.position = Vector2(
		viewport_size.x - list_width - margin,
		margin
	)
	creature_list.size = Vector2(list_width, list_height)
	
	# 秘術リスト（クリーチャーリスト下）
	mystic_art_list.position = Vector2(
		viewport_size.x - list_width - margin,
		margin + list_height + margin
	)
	mystic_art_list.size = Vector2(list_width, list_height)
	
	# タイプ選択リスト（画面中央）
	var type_list_height = 150
	type_list.position = Vector2(
		viewport_size.x - list_width - margin,
		margin
	)
	type_list.size = Vector2(list_width, type_list_height)

func show_creature_selection(creatures: Array):
	"""クリーチャー選択を表示"""
	available_creatures = creatures
	creature_list.clear()
	
	for creature in creatures:
		var creature_data = creature.get("creature_data", {})
		var name_text = creature_data.get("name", "Unknown")
		creature_list.add_item(name_text)
	
	# 位置を再計算
	_update_positions()
	
	creature_list.visible = true
	mystic_art_list.visible = false
	
	# グローバルボタンに登録
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_cancel_button_pressed, "やめる")

func show_mystic_art_selection(mystic_arts: Array):
	"""秘術選択を表示"""
	mystic_art_list.clear()
	
	for mystic_art in mystic_arts:
		var name_text = "%s [%dG]" % [
			mystic_art.get("name", "Unknown"),
			mystic_art.get("cost", 0)
		]
		mystic_art_list.add_item(name_text)
	
	creature_list.visible = false
	mystic_art_list.visible = true
	type_list.visible = false
	
	# グローバルボタンに登録
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_cancel_button_pressed, "やめる")

func show_type_selection(types: Array = ["creature", "item", "spell"]):
	"""カードタイプ選択を表示"""
	type_options = types
	type_list.clear()
	
	# 日本語表示名
	var type_names = {
		"creature": "クリーチャー",
		"item": "アイテム",
		"spell": "スペル"
	}
	
	for type_key in types:
		var display_name = type_names.get(type_key, type_key)
		type_list.add_item(display_name)
	
	# 位置を再計算
	_update_positions()
	
	creature_list.visible = false
	mystic_art_list.visible = false
	type_list.visible = true
	
	# グローバルボタンに登録
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_cancel_button_pressed, "やめる")

func hide_all():
	"""全UI非表示"""
	creature_list.visible = false
	mystic_art_list.visible = false
	type_list.visible = false
	
	# グローバルボタンをクリア
	if ui_manager_ref:
		ui_manager_ref.clear_back_action()

func _on_creature_selected(index: int):
	"""クリーチャーが選択された（item_selectedシグナル）"""
	selected_creature_index = index
	creature_selected.emit(index)

func _on_mystic_art_selected(index: int):
	"""秘術が選択された（item_selectedシグナル）"""
	mystic_art_selected.emit(index)

func _on_type_selected(index: int):
	"""タイプが選択された（item_selectedシグナル）"""
	if index >= 0 and index < type_options.size():
		var selected_type = type_options[index]
		type_selected.emit(selected_type)

func _on_cancel_button_pressed():
	"""キャンセルボタンが押された"""
	hide_all()
	selection_cancelled.emit()
