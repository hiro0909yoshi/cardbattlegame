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
	set_process_input(true)


func _input(event):
	"""キーボード入力処理"""
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		# クリーチャーリスト表示中
		if creature_list.visible and creature_list.item_count > 0:
			_handle_list_input(event, creature_list, _on_creature_selected)
		# アルカナアーツリスト表示中
		elif mystic_art_list.visible and mystic_art_list.item_count > 0:
			_handle_list_input(event, mystic_art_list, _on_mystic_art_selected)
		# タイプリスト表示中
		elif type_list.visible and type_list.item_count > 0:
			_handle_list_input(event, type_list, _on_type_selected)


func _handle_list_input(event: InputEventKey, list: ItemList, select_callback: Callable):
	"""リストのキーボード入力を処理"""
	var current = list.get_selected_items()
	var current_index = current[0] if current.size() > 0 else 0
	
	match event.keycode:
		KEY_UP:
			var new_index = max(0, current_index - 1)
			list.select(new_index)
			list.ensure_current_is_visible()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			var new_index = min(list.item_count - 1, current_index + 1)
			list.select(new_index)
			list.ensure_current_is_visible()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if current.size() > 0:
				select_callback.call(current_index)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE, KEY_C:
			_on_cancel_button_pressed()
			get_viewport().set_input_as_handled()

func _create_ui_elements():
	"""UI要素を動的作成"""
	
	# クリーチャーリスト（大きめ）
	creature_list = ItemList.new()
	creature_list.name = "CreatureList"
	creature_list.custom_minimum_size = Vector2(400, 500)
	creature_list.select_mode = ItemList.SELECT_SINGLE
	creature_list.allow_reselect = true
	creature_list.z_index = 100
	creature_list.mouse_filter = Control.MOUSE_FILTER_STOP
	creature_list.item_selected.connect(_on_creature_selected)
	# フォントサイズを大きく
	creature_list.add_theme_font_size_override("font_size", 28)
	add_child(creature_list)
	
	# アルカナアーツリスト（大きめ）
	mystic_art_list = ItemList.new()
	mystic_art_list.name = "MysticArtList"
	mystic_art_list.custom_minimum_size = Vector2(400, 500)
	mystic_art_list.select_mode = ItemList.SELECT_SINGLE
	mystic_art_list.allow_reselect = true
	mystic_art_list.z_index = 100
	mystic_art_list.mouse_filter = Control.MOUSE_FILTER_STOP
	mystic_art_list.item_selected.connect(_on_mystic_art_selected)
	# フォントサイズを大きく
	mystic_art_list.add_theme_font_size_override("font_size", 28)
	add_child(mystic_art_list)
	mystic_art_list.visible = false
	
	# タイプ選択リスト
	type_list = ItemList.new()
	type_list.name = "TypeList"
	type_list.custom_minimum_size = Vector2(400, 300)
	type_list.select_mode = ItemList.SELECT_SINGLE
	type_list.allow_reselect = true
	type_list.z_index = 100
	type_list.mouse_filter = Control.MOUSE_FILTER_STOP
	type_list.item_selected.connect(_on_type_selected)
	# フォントサイズを大きく
	type_list.add_theme_font_size_override("font_size", 28)
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
	"""UI要素の位置を更新（左側に配置）"""
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 30
	var list_width = 400
	var list_height = 500
	
	# クリーチャーリスト（画面左上）
	creature_list.position = Vector2(margin, margin + 50)
	creature_list.size = Vector2(list_width, list_height)
	
	# アルカナアーツリスト（同じ位置 - クリーチャーリストと排他表示）
	mystic_art_list.position = Vector2(margin, margin + 50)
	mystic_art_list.size = Vector2(list_width, list_height)
	
	# タイプ選択リスト（画面左上）
	var type_list_height = 300
	type_list.position = Vector2(margin, margin + 50)
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
	type_list.visible = false
	
	# 最初の項目を選択状態に
	if creature_list.item_count > 0:
		creature_list.select(0)
	
	# グローバルボタンに登録
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_cancel_button_pressed, "やめる")

func show_mystic_art_selection(mystic_arts: Array):
	"""アルカナアーツ選択を表示"""
	mystic_art_list.clear()
	
	for mystic_art in mystic_arts:
		var name_text = "%s [%dEP]" % [
			mystic_art.get("name", "Unknown"),
			mystic_art.get("cost", 0)
		]
		mystic_art_list.add_item(name_text)
	
	creature_list.visible = false
	mystic_art_list.visible = true
	type_list.visible = false
	
	# 最初の項目を選択状態に
	if mystic_art_list.item_count > 0:
		mystic_art_list.select(0)
	
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
	
	# 最初の項目を選択状態に
	if type_list.item_count > 0:
		type_list.select(0)
	
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
	"""アルカナアーツが選択された（item_selectedシグナル）"""
	mystic_art_selected.emit(index)

func _on_type_selected(index: int):
	"""タイプが選択された（item_selectedシグナル）"""
	if index >= 0 and index < type_options.size():
		var selected_type = type_options[index]
		type_selected.emit(selected_type)

func _on_cancel_button_pressed():
	"""キャンセルボタンが押された"""
	hide_all()
	# キャンセル時は-1を返す（awaitで待機中の処理に通知）
	if creature_list.visible or selected_creature_index >= 0:
		creature_selected.emit(-1)
	elif mystic_art_list.visible:
		mystic_art_selected.emit(-1)
	selection_cancelled.emit()
