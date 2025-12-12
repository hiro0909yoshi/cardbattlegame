# バトルテストツールのメインUI
extends Control

## 参照
var config: BattleTestConfig = BattleTestConfig.new()
var results: Array = []  # BattleTestResult配列
var statistics: BattleTestStatistics = null

## 最後にフォーカスされた入力フィールドを記憶
var last_focused_side: String = "attacker"  # "attacker" or "defender"
var last_focused_type: String = "creature"  # "creature" or "item"

## 攻撃側クリーチャー
@onready var attacker_creature_id_input: LineEdit = $MainSplitContainer/MainContainer/AttackerContainer/AttackerCreatureInput
@onready var attacker_creature_add_button: Button = $MainSplitContainer/MainContainer/AttackerContainer/AttackerCreatureAddButton
@onready var attacker_creature_preset_option: OptionButton = $MainSplitContainer/MainContainer/AttackerContainer/CreaturePresetOption
@onready var attacker_creature_preset_add_button: Button = $MainSplitContainer/MainContainer/AttackerContainer/AttackerCreaturePresetAddButton
@onready var attacker_creature_list: ItemList = $MainSplitContainer/MainContainer/AttackerCreatureList
@onready var attacker_creature_delete_button: Button = $MainSplitContainer/MainContainer/AttackerCreatureButtonContainer/AttackerCreatureDeleteButton
@onready var attacker_creature_clear_button: Button = $MainSplitContainer/MainContainer/AttackerCreatureButtonContainer/AttackerCreatureClearButton

## 攻撃側アイテム
@onready var attacker_item_id_input: LineEdit = $MainSplitContainer/MainContainer/AttackerItemInputContainer/AttackerItemIdInput
@onready var attacker_item_add_button: Button = $MainSplitContainer/MainContainer/AttackerItemInputContainer/AttackerItemAddButton
@onready var attacker_item_add_none_button: Button = $MainSplitContainer/MainContainer/AttackerItemInputContainer/AttackerItemAddNoneButton
@onready var attacker_item_list: ItemList = $MainSplitContainer/MainContainer/AttackerItemList
@onready var attacker_item_delete_button: Button = $MainSplitContainer/MainContainer/AttackerItemButtonContainer/AttackerItemDeleteButton
@onready var attacker_item_clear_button: Button = $MainSplitContainer/MainContainer/AttackerItemButtonContainer/AttackerItemClearButton

## 防御側クリーチャー
@onready var defender_creature_id_input: LineEdit = $MainSplitContainer/MainContainer/DefenderContainer/DefenderCreatureInput
@onready var defender_creature_add_button: Button = $MainSplitContainer/MainContainer/DefenderContainer/DefenderCreatureAddButton
@onready var defender_creature_preset_option: OptionButton = $MainSplitContainer/MainContainer/DefenderContainer/CreaturePresetOption
@onready var defender_creature_preset_add_button: Button = $MainSplitContainer/MainContainer/DefenderContainer/DefenderCreaturePresetAddButton
@onready var defender_creature_list: ItemList = $MainSplitContainer/MainContainer/DefenderCreatureList
@onready var defender_creature_delete_button: Button = $MainSplitContainer/MainContainer/DefenderCreatureButtonContainer/DefenderCreatureDeleteButton
@onready var defender_creature_clear_button: Button = $MainSplitContainer/MainContainer/DefenderCreatureButtonContainer/DefenderCreatureClearButton

## 防御側アイテム
@onready var defender_item_id_input: LineEdit = $MainSplitContainer/MainContainer/DefenderItemInputContainer/DefenderItemIdInput
@onready var defender_item_add_button: Button = $MainSplitContainer/MainContainer/DefenderItemInputContainer/DefenderItemAddButton
@onready var defender_item_add_none_button: Button = $MainSplitContainer/MainContainer/DefenderItemInputContainer/DefenderItemAddNoneButton
@onready var defender_item_list: ItemList = $MainSplitContainer/MainContainer/DefenderItemList
@onready var defender_item_delete_button: Button = $MainSplitContainer/MainContainer/DefenderItemButtonContainer/DefenderItemDeleteButton
@onready var defender_item_clear_button: Button = $MainSplitContainer/MainContainer/DefenderItemButtonContainer/DefenderItemClearButton

## 土地設定（攻撃側）
@onready var attacker_fire_spin: SpinBox = $MainSplitContainer/MainContainer/AttackerLandContainer/AttackerFireSpin
@onready var attacker_water_spin: SpinBox = $MainSplitContainer/MainContainer/AttackerLandContainer/AttackerWaterSpin
@onready var attacker_wind_spin: SpinBox = $MainSplitContainer/MainContainer/AttackerLandContainer/AttackerWindSpin
@onready var attacker_earth_spin: SpinBox = $MainSplitContainer/MainContainer/AttackerLandContainer/AttackerEarthSpin

## 土地設定（防御側）
@onready var defender_fire_spin: SpinBox = $MainSplitContainer/MainContainer/DefenderLandContainer/DefenderFireSpin
@onready var defender_water_spin: SpinBox = $MainSplitContainer/MainContainer/DefenderLandContainer/DefenderWaterSpin
@onready var defender_wind_spin: SpinBox = $MainSplitContainer/MainContainer/DefenderLandContainer/DefenderWindSpin
@onready var defender_earth_spin: SpinBox = $MainSplitContainer/MainContainer/DefenderLandContainer/DefenderEarthSpin

## バトル条件
@onready var battle_land_option: OptionButton = $MainSplitContainer/MainContainer/BattleLandContainer/BattleLandOption
@onready var battle_land_level_spin: SpinBox = $MainSplitContainer/MainContainer/BattleLandContainer/BattleLandLevelSpin
@onready var attacker_adjacent_check: CheckBox = $MainSplitContainer/MainContainer/AdjacentContainer/AttackerAdjacentCheck
@onready var defender_adjacent_check: CheckBox = $MainSplitContainer/MainContainer/AdjacentContainer/DefenderAdjacentCheck

## 実行
@onready var swap_button: Button = $MainSplitContainer/MainContainer/SwapContainer/SwapButton
@onready var execute_button: Button = $MainSplitContainer/MainContainer/ExecuteButton
@onready var result_label: Label = $MainSplitContainer/MainContainer/ResultLabel

## 結果表示
@onready var statistics_label: RichTextLabel = $MainSplitContainer/ResultPanel/ResultContainer/ResultTabs/StatisticsTab/StatisticsLabel
@onready var detail_table: ItemList = $MainSplitContainer/ResultPanel/ResultContainer/ResultTabs/DetailTable

## 詳細ウィンドウ
@onready var detail_window: Window = $DetailWindow
@onready var detail_window_label: RichTextLabel = $DetailWindow/DetailLabel

func _ready():
	print("[BattleTestUI] 初期化")
	await get_tree().process_frame
	_setup_ui()

## UI初期化
func _setup_ui():
	# カード一覧ボタンを動的に追加
	_add_card_list_button()
	
	# 入力フィールドのフォーカスイベントを設定
	_setup_focus_tracking()

## フォーカストラッキングを設定
func _setup_focus_tracking():
	# 攻撃側クリーチャー
	attacker_creature_id_input.focus_entered.connect(func():
		last_focused_side = "attacker"
		last_focused_type = "creature"
	)
	
	# 攻撃側アイテム
	attacker_item_id_input.focus_entered.connect(func():
		last_focused_side = "attacker"
		last_focused_type = "item"
	)
	
	# 防御側クリーチャー
	defender_creature_id_input.focus_entered.connect(func():
		last_focused_side = "defender"
		last_focused_type = "creature"
	)
	
	# 防御側アイテム
	defender_item_id_input.focus_entered.connect(func():
		last_focused_side = "defender"
		last_focused_type = "item"
	)

## カード一覧ボタンを追加
func _add_card_list_button():
	var main_container = $MainSplitContainer/MainContainer
	if not main_container:
		print("[BattleTestUI] MainContainer が見つかりません")
		return
	
	var button = Button.new()
	button.name = "CardListButton"
	button.text = "📋 全カード一覧"
	button.custom_minimum_size = Vector2(0, 56)  # 1.4倍
	button.pressed.connect(show_card_list_window)
	
	# Label（タイトル）とHSeparatorの間に追加
	main_container.add_child(button)
	main_container.move_child(button, 1)  # タイトルの直後
	
	print("[BattleTestUI] カード一覧ボタンを追加しました")
	
	# ノード存在チェック
	if not attacker_creature_add_button:
		push_error("attacker_creature_add_button が見つかりません")
		return
	
	# 攻撃側クリーチャー
	attacker_creature_add_button.pressed.connect(_on_attacker_creature_add_pressed)
	attacker_creature_preset_add_button.pressed.connect(_on_attacker_creature_preset_add_pressed)
	attacker_creature_delete_button.pressed.connect(_on_attacker_creature_delete_pressed)
	attacker_creature_clear_button.pressed.connect(_on_attacker_creature_clear_pressed)
	
	# 攻撃側アイテム
	attacker_item_add_button.pressed.connect(_on_attacker_item_add_pressed)
	attacker_item_add_none_button.pressed.connect(_on_attacker_item_add_none_pressed)
	attacker_item_delete_button.pressed.connect(_on_attacker_item_delete_pressed)
	attacker_item_clear_button.pressed.connect(_on_attacker_item_clear_pressed)
	
	# 防御側クリーチャー
	defender_creature_add_button.pressed.connect(_on_defender_creature_add_pressed)
	defender_creature_preset_add_button.pressed.connect(_on_defender_creature_preset_add_pressed)
	defender_creature_delete_button.pressed.connect(_on_defender_creature_delete_pressed)
	defender_creature_clear_button.pressed.connect(_on_defender_creature_clear_pressed)
	
	# 防御側アイテム
	defender_item_add_button.pressed.connect(_on_defender_item_add_pressed)
	defender_item_add_none_button.pressed.connect(_on_defender_item_add_none_pressed)
	defender_item_delete_button.pressed.connect(_on_defender_item_delete_pressed)
	defender_item_clear_button.pressed.connect(_on_defender_item_clear_pressed)
	
	# 土地設定
	if attacker_fire_spin:
		attacker_fire_spin.value_changed.connect(_on_attacker_land_changed)
		attacker_water_spin.value_changed.connect(_on_attacker_land_changed)
		attacker_wind_spin.value_changed.connect(_on_attacker_land_changed)
		attacker_earth_spin.value_changed.connect(_on_attacker_land_changed)
	
	if defender_fire_spin:
		defender_fire_spin.value_changed.connect(_on_defender_land_changed)
		defender_water_spin.value_changed.connect(_on_defender_land_changed)
		defender_wind_spin.value_changed.connect(_on_defender_land_changed)
		defender_earth_spin.value_changed.connect(_on_defender_land_changed)
	
	# バトル条件
	if battle_land_option:
		battle_land_option.item_selected.connect(_on_battle_land_selected)
		# 初期状態は未選択（-1）にして、無属性で戦闘
		battle_land_option.selected = -1
	if battle_land_level_spin:
		battle_land_level_spin.value_changed.connect(_on_battle_land_level_changed)
	if attacker_adjacent_check:
		attacker_adjacent_check.toggled.connect(_on_attacker_adjacent_toggled)
	if defender_adjacent_check:
		defender_adjacent_check.toggled.connect(_on_defender_adjacent_toggled)
	
	# 実行
	swap_button.pressed.connect(_on_swap_button_pressed)
	execute_button.pressed.connect(_on_execute_button_pressed)
	
	# 詳細テーブル（ダブルクリックで詳細表示）
	if detail_table:
		detail_table.item_activated.connect(_on_detail_table_item_activated)

## ============================================
## 攻撃側クリーチャー
## ============================================

func _on_attacker_creature_add_pressed():
	var id_text = attacker_creature_id_input.text
	var id = id_text.to_int()
	if id <= 0:
		print("[BattleTestUI] 無効なクリーチャーID: ", id_text)
		return
	
	# カード名取得
	var card = CardLoader.get_card_by_id(id)
	if not card:
		print("[BattleTestUI] クリーチャーが見つかりません: ID ", id)
		return
	
	# リストに追加
	var display_text = "%s (ID:%d)" % [card.name, id]
	attacker_creature_list.add_item(display_text)
	attacker_creature_list.set_item_metadata(attacker_creature_list.item_count - 1, id)
	
	# configに追加
	config.attacker_creatures.append(id)
	
	print("[BattleTestUI] 攻撃側クリーチャー追加: ", card.name, " (ID:", id, ")")
	attacker_creature_id_input.text = ""

func _on_attacker_creature_preset_add_pressed():
	var index = attacker_creature_preset_option.selected
	var preset_names = BattleTestPresets.get_all_creature_preset_names()
	if index < 0 or index >= preset_names.size():
		return
	
	var preset_name = preset_names[index]
	var creature_ids = BattleTestPresets.get_creature_preset(preset_name)
	
	for id in creature_ids:
		var card = CardLoader.get_card_by_id(id)
		if card:
			var display_text = "%s (ID:%d)" % [card.name, id]
			attacker_creature_list.add_item(display_text)
			attacker_creature_list.set_item_metadata(attacker_creature_list.item_count - 1, id)
			config.attacker_creatures.append(id)
	
	print("[BattleTestUI] プリセット一括追加: ", preset_name, " (", creature_ids.size(), "体)")

func _on_attacker_creature_delete_pressed():
	var selected = attacker_creature_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	var id = attacker_creature_list.get_item_metadata(index)
	attacker_creature_list.remove_item(index)
	config.attacker_creatures.erase(id)
	print("[BattleTestUI] 攻撃側クリーチャー削除: ID ", id)

func _on_attacker_creature_clear_pressed():
	attacker_creature_list.clear()
	config.attacker_creatures.clear()
	print("[BattleTestUI] 攻撃側クリーチャー全削除")

## ============================================
## 攻撃側アイテム
## ============================================

func _on_attacker_item_add_pressed():
	var id_text = attacker_item_id_input.text
	if id_text.is_empty():
		print("[BattleTestUI] アイテムIDが空です")
		return
	
	var id = id_text.to_int()
	if id <= 0:
		print("[BattleTestUI] 無効なアイテムID: ", id_text)
		return
	
	# アイテム名取得
	var item = CardLoader.get_item_by_id(id)
	var display_text = ""
	if item.is_empty():
		display_text = "アイテム (ID:%d) ※見つかりません" % id
		print("[BattleTestUI] アイテムが見つかりません: ID ", id)
		return  # 見つからない場合は追加しない
	
	if not item.has("name"):
		display_text = "アイテム (ID:%d) ※名前なし" % id
		print("[BattleTestUI] アイテムに名前がありません: ID ", id)
	else:
		display_text = "%s (ID:%d)" % [item.name, id]
	
	attacker_item_list.add_item(display_text)
	attacker_item_list.set_item_metadata(attacker_item_list.item_count - 1, id)
	
	config.attacker_items.append(id)
	print("[BattleTestUI] 攻撃側アイテム追加: %s (ID:%d)" % [display_text, id])
	attacker_item_id_input.text = ""

func _on_attacker_item_add_none_pressed():
	var display_text = "なし (ID:-1)"
	attacker_item_list.add_item(display_text)
	attacker_item_list.set_item_metadata(attacker_item_list.item_count - 1, -1)
	config.attacker_items.append(-1)
	print("[BattleTestUI] 攻撃側アイテム追加: なし")

func _on_attacker_item_delete_pressed():
	var selected = attacker_item_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	var id = attacker_item_list.get_item_metadata(index)
	attacker_item_list.remove_item(index)
	config.attacker_items.erase(id)
	print("[BattleTestUI] 攻撃側アイテム削除: ID ", id)

func _on_attacker_item_clear_pressed():
	attacker_item_list.clear()
	config.attacker_items.clear()
	print("[BattleTestUI] 攻撃側アイテム全削除")

## ============================================
## 防御側クリーチャー
## ============================================

func _on_defender_creature_add_pressed():
	var id_text = defender_creature_id_input.text
	var id = id_text.to_int()
	if id <= 0:
		print("[BattleTestUI] 無効なクリーチャーID: ", id_text)
		return
	
	var card = CardLoader.get_card_by_id(id)
	if not card:
		print("[BattleTestUI] クリーチャーが見つかりません: ID ", id)
		return
	
	var display_text = "%s (ID:%d)" % [card.name, id]
	defender_creature_list.add_item(display_text)
	defender_creature_list.set_item_metadata(defender_creature_list.item_count - 1, id)
	config.defender_creatures.append(id)
	
	print("[BattleTestUI] 防御側クリーチャー追加: ", card.name, " (ID:", id, ")")
	defender_creature_id_input.text = ""

func _on_defender_creature_preset_add_pressed():
	var index = defender_creature_preset_option.selected
	var preset_names = BattleTestPresets.get_all_creature_preset_names()
	if index < 0 or index >= preset_names.size():
		return
	
	var preset_name = preset_names[index]
	var creature_ids = BattleTestPresets.get_creature_preset(preset_name)
	
	for id in creature_ids:
		var card = CardLoader.get_card_by_id(id)
		if card:
			var display_text = "%s (ID:%d)" % [card.name, id]
			defender_creature_list.add_item(display_text)
			defender_creature_list.set_item_metadata(defender_creature_list.item_count - 1, id)
			config.defender_creatures.append(id)
	
	print("[BattleTestUI] プリセット一括追加: ", preset_name, " (", creature_ids.size(), "体)")

func _on_defender_creature_delete_pressed():
	var selected = defender_creature_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	var id = defender_creature_list.get_item_metadata(index)
	defender_creature_list.remove_item(index)
	config.defender_creatures.erase(id)
	print("[BattleTestUI] 防御側クリーチャー削除: ID ", id)

func _on_defender_creature_clear_pressed():
	defender_creature_list.clear()
	config.defender_creatures.clear()
	print("[BattleTestUI] 防御側クリーチャー全削除")

## ============================================
## 防御側アイテム
## ============================================

func _on_defender_item_add_pressed():
	var id_text = defender_item_id_input.text
	if id_text.is_empty():
		print("[BattleTestUI] アイテムIDが空です")
		return
	
	var id = id_text.to_int()
	if id <= 0:
		print("[BattleTestUI] 無効なアイテムID: ", id_text)
		return
	
	# アイテム名取得
	var item = CardLoader.get_item_by_id(id)
	var display_text = ""
	if item.is_empty():
		display_text = "アイテム (ID:%d) ※見つかりません" % id
		print("[BattleTestUI] アイテムが見つかりません: ID ", id)
		return  # 見つからない場合は追加しない
	
	if not item.has("name"):
		display_text = "アイテム (ID:%d) ※名前なし" % id
		print("[BattleTestUI] アイテムに名前がありません: ID ", id)
	else:
		display_text = "%s (ID:%d)" % [item.name, id]
	
	defender_item_list.add_item(display_text)
	defender_item_list.set_item_metadata(defender_item_list.item_count - 1, id)
	config.defender_items.append(id)
	print("[BattleTestUI] 防御側アイテム追加: %s (ID:%d)" % [display_text, id])
	defender_item_id_input.text = ""

func _on_defender_item_add_none_pressed():
	var display_text = "なし (ID:-1)"
	defender_item_list.add_item(display_text)
	defender_item_list.set_item_metadata(defender_item_list.item_count - 1, -1)
	config.defender_items.append(-1)
	print("[BattleTestUI] 防御側アイテム追加: なし")

func _on_defender_item_delete_pressed():
	var selected = defender_item_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	var id = defender_item_list.get_item_metadata(index)
	defender_item_list.remove_item(index)
	config.defender_items.erase(id)
	print("[BattleTestUI] 防御側アイテム削除: ID ", id)

func _on_defender_item_clear_pressed():
	defender_item_list.clear()
	config.defender_items.clear()
	print("[BattleTestUI] 防御側アイテム全削除")

## ============================================
## 土地設定
## ============================================

func _on_attacker_land_changed(_value):
	config.attacker_owned_lands["fire"] = int(attacker_fire_spin.value)
	config.attacker_owned_lands["water"] = int(attacker_water_spin.value)
	config.attacker_owned_lands["wind"] = int(attacker_wind_spin.value)
	config.attacker_owned_lands["earth"] = int(attacker_earth_spin.value)
	print("[BattleTestUI] 攻撃側土地: ", config.attacker_owned_lands)

func _on_defender_land_changed(_value):
	config.defender_owned_lands["fire"] = int(defender_fire_spin.value)
	config.defender_owned_lands["water"] = int(defender_water_spin.value)
	config.defender_owned_lands["wind"] = int(defender_wind_spin.value)
	config.defender_owned_lands["earth"] = int(defender_earth_spin.value)
	print("[BattleTestUI] 防御側土地: ", config.defender_owned_lands)

## ============================================
## バトル条件
## ============================================

func _on_battle_land_selected(index: int):
	# UIには火水風土の4つのみ（0:火, 1:水, 2:風, 3:土）
	var elements = ["fire", "water", "wind", "earth"]
	if index >= 0 and index < elements.size():
		var element = elements[index]
		config.attacker_battle_land = element
		config.defender_battle_land = element
		print("[BattleTestUI] バトル発生土地: ", element)
	else:
		# 不正なインデックスの場合は無属性
		config.attacker_battle_land = "neutral"
		config.defender_battle_land = "neutral"
		print("[BattleTestUI] バトル発生土地: neutral (デフォルト)")

func _on_attacker_adjacent_toggled(toggled_on: bool):
	config.attacker_has_adjacent = toggled_on
	print("[BattleTestUI] 攻撃側隣接条件: ", toggled_on)

func _on_defender_adjacent_toggled(toggled_on: bool):
	config.defender_has_adjacent = toggled_on
	print("[BattleTestUI] 防御側隣接条件: ", toggled_on)

func _on_battle_land_level_changed(value: float):
	var level = int(value)
	config.attacker_battle_land_level = level
	config.defender_battle_land_level = level
	print("[BattleTestUI] バトル土地レベル: ", level)

## ============================================
## 入れ替え・実行
## ============================================

func _on_swap_button_pressed():
	# 設定を入れ替え
	config.swap_attacker_defender()
	
	# UIのリストも入れ替え
	_swap_lists()
	_swap_land_settings()
	print("[BattleTestUI] 攻撃⇔防御を入れ替えました")

func _swap_lists():
	# クリーチャーリストを入れ替え
	var temp_creature_items = []
	for i in range(attacker_creature_list.item_count):
		temp_creature_items.append({
			"text": attacker_creature_list.get_item_text(i),
			"metadata": attacker_creature_list.get_item_metadata(i)
		})
	
	attacker_creature_list.clear()
	for i in range(defender_creature_list.item_count):
		var text = defender_creature_list.get_item_text(i)
		var metadata = defender_creature_list.get_item_metadata(i)
		attacker_creature_list.add_item(text)
		attacker_creature_list.set_item_metadata(i, metadata)
	
	defender_creature_list.clear()
	for item in temp_creature_items:
		var idx = defender_creature_list.item_count
		defender_creature_list.add_item(item.text)
		defender_creature_list.set_item_metadata(idx, item.metadata)
	
	# アイテムリストを入れ替え
	var temp_item_items = []
	for i in range(attacker_item_list.item_count):
		temp_item_items.append({
			"text": attacker_item_list.get_item_text(i),
			"metadata": attacker_item_list.get_item_metadata(i)
		})
	
	attacker_item_list.clear()
	for i in range(defender_item_list.item_count):
		var text = defender_item_list.get_item_text(i)
		var metadata = defender_item_list.get_item_metadata(i)
		attacker_item_list.add_item(text)
		attacker_item_list.set_item_metadata(i, metadata)
	
	defender_item_list.clear()
	for item in temp_item_items:
		var idx = defender_item_list.item_count
		defender_item_list.add_item(item.text)
		defender_item_list.set_item_metadata(idx, item.metadata)

func _swap_land_settings():
	# 土地設定を入れ替え
	var temp_fire = attacker_fire_spin.value
	attacker_fire_spin.value = defender_fire_spin.value
	defender_fire_spin.value = temp_fire
	
	var temp_water = attacker_water_spin.value
	attacker_water_spin.value = defender_water_spin.value
	defender_water_spin.value = temp_water
	
	var temp_wind = attacker_wind_spin.value
	attacker_wind_spin.value = defender_wind_spin.value
	defender_wind_spin.value = temp_wind
	
	var temp_earth = attacker_earth_spin.value
	attacker_earth_spin.value = defender_earth_spin.value
	defender_earth_spin.value = temp_earth
	
	# 隣接条件を入れ替え
	var temp_adjacent = attacker_adjacent_check.button_pressed
	attacker_adjacent_check.button_pressed = defender_adjacent_check.button_pressed
	defender_adjacent_check.button_pressed = temp_adjacent

func _on_execute_button_pressed():
	print("[BattleTestUI] テスト実行開始")
	
	if not config.validate():
		push_error("設定が不正です")
		result_label.text = "エラー: クリーチャーが未登録です"
		return
	
	# ボタンを無効化
	execute_button.disabled = true
	result_label.text = "実行中..."
	
	# 次フレームでバトル実行（UIをブロックしないため）
	await get_tree().process_frame
	
	# バトル実行
	results = BattleTestExecutor.execute_all_battles(config)
	
	# 統計計算
	statistics = BattleTestStatistics.calculate(results)
	
	# 結果表示
	_display_results()
	
	# ボタンを有効化
	execute_button.disabled = false
	
	print("[BattleTestUI] テスト実行完了")

## 結果表示
func _display_results():
	if results.is_empty():
		result_label.text = "結果なし"
		return
	
	var text = "=== バトルテスト結果 ===
"
	text += "総バトル数: %d
" % statistics.total_battles
	text += "実行時間: %.2f秒
" % (statistics.total_duration_ms / 1000.0)
	text += "
"
	text += "攻撃側勝利: %d (%.1f%%)
" % [statistics.attacker_wins, statistics.attacker_wins * 100.0 / statistics.total_battles]
	text += "防御側勝利: %d (%.1f%%)
" % [statistics.defender_wins, statistics.defender_wins * 100.0 / statistics.total_battles]
	text += "
"
	text += "詳細結果は %d 件のバトルデータに記録されています" % results.size()
	
	# 統計サマリー表示
	_display_statistics()
	
	# 詳細テーブル表示
	_display_detail_table()
	
	# 簡易メッセージ（左側）
	result_label.text = "テスト完了！右側のタブで結果を確認してください。"
	
	print("[BattleTestUI] 結果表示完了")

## 統計サマリー表示
func _display_statistics():
	if not statistics:
		return
	
	var text = "[b]📊 統計サマリー[/b]

"
	text += "総バトル数: [b]%d[/b]
" % statistics.total_battles
	text += "実行時間: [b]%.2f秒[/b]

" % (statistics.total_duration_ms / 1000.0)
	
	# 勝率
	text += "[color=cyan]■ 勝率[/color]
"
	if statistics.total_battles > 0:
		var att_rate = statistics.attacker_wins * 100.0 / statistics.total_battles
		var def_rate = statistics.defender_wins * 100.0 / statistics.total_battles
		text += "  攻撃側勝利: %d (%.1f%%)
" % [statistics.attacker_wins, att_rate]
		text += "  防御側勝利: %d (%.1f%%)

" % [statistics.defender_wins, def_rate]
	
	# クリーチャー別勝率（Top 5）
	text += "[color=yellow]■ クリーチャー別勝率 (Top 5)[/color]
"
	var sorted_creatures = []
	for creature_name in statistics.creature_stats:
		var data = statistics.creature_stats[creature_name]
		sorted_creatures.append({"name": creature_name, "rate": data.get("win_rate", 0.0), "wins": data.wins, "total": data.total})
	
	sorted_creatures.sort_custom(func(a, b): return a.rate > b.rate)
	
	for i in range(min(5, sorted_creatures.size())):
		var creature = sorted_creatures[i]
		text += "  %d. %s: %.1f%% (%d/%d)
" % [i+1, creature.name, creature.rate, creature.wins, creature.total]
	
	# スキル付与統計
	if not statistics.skill_grant_stats.is_empty():
		text += "
[color=lime]■ スキル付与統計[/color]
"
		for skill_name in statistics.skill_grant_stats:
			var data = statistics.skill_grant_stats[skill_name]
			text += "  %s: %d回付与 (アイテム:%d, スペル:%d)
" % [skill_name, data.granted, data.from_item, data.from_spell]
	
	statistics_label.text = text

## 詳細テーブル表示
func _display_detail_table():
	detail_table.clear()
	
	for result in results:
		if not (result is BattleTestResult):
			continue
		
		# 1行にまとめて表示（最終HP/AP表示）
		var line = "[%d] %s vs %s → %s | HP: %d vs %d | AP: %d vs %d" % [
			result.battle_id,
			result.attacker_name,
			result.defender_name,
			"攻撃側勝利" if result.winner == "attacker" else "防御側勝利",
			result.attacker_final_hp,
			result.defender_final_hp,
			result.attacker_final_ap,
			result.defender_final_ap
		]
		
		# 付与スキルがあれば追加
		if not result.attacker_granted_skills.is_empty():
			line += " [攻:" + ",".join(result.attacker_granted_skills) + "]"
		if not result.defender_granted_skills.is_empty():
			line += " [防:" + ",".join(result.defender_granted_skills) + "]"
		
		detail_table.add_item(line)

## 結果表示クリア
func _clear_result_display():
	if statistics_label:
		statistics_label.text = ""
	if detail_table:
		detail_table.clear()

## ============================================
## 詳細ウィンドウ
## ============================================

## テーブル行がダブルクリックされた時
func _on_detail_table_item_activated(index: int):
	if index < 0 or index >= results.size():
		return
	
	var result = results[index]
	if result is BattleTestResult:
		_show_detail_window(result)

## 詳細ウィンドウを表示
func _show_detail_window(result: BattleTestResult):
	if not detail_window or not detail_window_label:
		push_error("DetailWindowが見つかりません")
		return
	
	# ウィンドウ内容を生成
	var text = "[b]🔍 バトル詳細 #%d[/b]

" % result.battle_id
	
	# 基本情報
	text += "[color=cyan]■ 基本情報[/color]
"
	text += "  攻撃側: %s (ID:%d)
" % [result.attacker_name, result.attacker_id]
	text += "  防御側: %s (ID:%d)
" % [result.defender_name, result.defender_id]
	text += "  勝者: [b]%s[/b]

" % ("攻撃側" if result.winner == "attacker" else "防御側")
	
	# アイテム・スペル
	text += "[color=yellow]■ 装備・使用[/color]
"
	text += "  攻撃側アイテム: %s
" % ("なし" if result.attacker_item_id == -1 else "ID:%d" % result.attacker_item_id)
	text += "  防御側アイテム: %s

" % ("なし" if result.defender_item_id == -1 else "ID:%d" % result.defender_item_id)
	
	# 付与スキル
	if not result.attacker_granted_skills.is_empty() or not result.defender_granted_skills.is_empty():
		text += "[color=lime]■ 付与されたスキル[/color]
"
		if not result.attacker_granted_skills.is_empty():
			text += "  攻撃側: %s
" % ", ".join(result.attacker_granted_skills)
		if not result.defender_granted_skills.is_empty():
			text += "  防御側: %s
" % ", ".join(result.defender_granted_skills)
		text += "
"
	
	# 発動したスキル
	if not result.attacker_skills_triggered.is_empty() or not result.defender_skills_triggered.is_empty():
		text += "[color=yellow]■ 発動したスキル[/color]
"
		if not result.attacker_skills_triggered.is_empty():
			text += "  攻撃側: %s
" % ", ".join(result.attacker_skills_triggered)
		if not result.defender_skills_triggered.is_empty():
			text += "  防御側: %s
" % ", ".join(result.defender_skills_triggered)
		text += "
"
	
	# 最終ステータス
	text += "[color=orange]■ 最終ステータス[/color]
"
	text += "  攻撃側 HP: %d (基礎: %d)
" % [result.attacker_final_hp, result.attacker_base_hp]
	text += "  防御側 HP: %d (基礎: %d)
" % [result.defender_final_hp, result.defender_base_hp]
	text += "  攻撃側 攻撃力: %d (基礎: %d)
" % [result.attacker_final_ap, result.attacker_base_ap]
	text += "  防御側 攻撃力: %d (基礎: %d)

" % [result.defender_final_ap, result.defender_base_ap]
	
	# バトル条件
	text += "[color=magenta]■ バトル条件[/color]
"
	text += "  バトル発生土地: %s
" % result.battle_land
	text += "  攻撃側隣接: %s
" % ("あり" if result.attacker_has_adjacent else "なし")
	text += "  防御側隣接: %s
" % ("あり" if result.defender_has_adjacent else "なし")
	
	# 土地保有状況
	text += "
[color=cyan]■ 土地保有状況[/color]
"
	text += "  攻撃側: "
	for element in ["fire", "water", "wind", "earth"]:
		var count = result.attacker_owned_lands.get(element, 0)
		if count > 0:
			text += "%s:%d " % [element, count]
	text += "
  防御側: "
	for element in ["fire", "water", "wind", "earth"]:
		var count = result.defender_owned_lands.get(element, 0)
		if count > 0:
			text += "%s:%d " % [element, count]
	
	# ラベルに設定
	detail_window_label.text = text
	
	# ウィンドウを表示
	detail_window.visible = true
	detail_window.popup_centered()
	
	print("[BattleTestUI] 詳細ウィンドウを表示: Battle #", result.battle_id)

## ============================================
## カード一覧機能
## ============================================

## カード一覧ウィンドウを表示
func show_card_list_window():
	var card_list_window = Window.new()
	card_list_window.title = "全カード一覧"
	card_list_window.size = Vector2i(1000, 700)
	card_list_window.min_size = Vector2i(800, 500)
	card_list_window.popup_window = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_top = 10
	vbox.offset_bottom = -10
	card_list_window.add_child(vbox)
	
	# フィルターコンテナ
	var filter_hbox = HBoxContainer.new()
	vbox.add_child(filter_hbox)
	
	var type_label = Label.new()
	type_label.text = "タイプ: "
	filter_hbox.add_child(type_label)
	
	var type_option = OptionButton.new()
	type_option.add_item("全て", 0)
	type_option.add_item("クリーチャー", 1)
	type_option.add_item("アイテム", 2)
	type_option.add_item("スペル", 3)
	filter_hbox.add_child(type_option)
	
	var element_label = Label.new()
	element_label.text = "  属性: "
	filter_hbox.add_child(element_label)
	
	var element_option = OptionButton.new()
	element_option.add_item("全て", 0)
	element_option.add_item("火", 1)
	element_option.add_item("水", 2)
	element_option.add_item("風", 3)
	element_option.add_item("土", 4)
	element_option.add_item("無", 5)
	filter_hbox.add_child(element_option)
	
	# テーブル
	var table = Tree.new()
	table.columns = 6
	table.set_column_title(0, "ID")
	table.set_column_title(1, "名前")
	table.set_column_title(2, "タイプ")
	table.set_column_title(3, "AP")
	table.set_column_title(4, "HP")
	table.set_column_title(5, "スキル")
	
	# カラム幅を設定
	table.set_column_expand(0, false)  # ID
	table.set_column_custom_minimum_width(0, 50)
	table.set_column_expand(1, false)  # 名前
	table.set_column_custom_minimum_width(1, 150)
	table.set_column_expand(2, false)  # タイプ
	table.set_column_custom_minimum_width(2, 60)
	table.set_column_expand(3, false)  # AP
	table.set_column_custom_minimum_width(3, 50)
	table.set_column_expand(4, false)  # HP
	table.set_column_custom_minimum_width(4, 50)
	table.set_column_expand(5, true)   # スキル（残り全部）
	table.set_column_custom_minimum_width(5, 300)
	
	table.column_titles_visible = true
	table.hide_root = true
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(table)
	
	# データ読み込み
	var root = table.create_item()
	_populate_card_table(table, root, -1, "")
	
	# フィルター変更時の処理
	type_option.item_selected.connect(func(index):
		table.clear()
		var new_root = table.create_item()
		var filter_type = -1
		match index:
			1: filter_type = 0  # クリーチャー
			2: filter_type = 1  # アイテム
			3: filter_type = 2  # スペル
		_populate_card_table(table, new_root, filter_type, "")
	)
	
	element_option.item_selected.connect(func(index):
		table.clear()
		var new_root = table.create_item()
		var filter_element = ""
		match index:
			1: filter_element = "fire"
			2: filter_element = "water"
			3: filter_element = "wind"
			4: filter_element = "earth"
			5: filter_element = "neutral"
		_populate_card_table(table, new_root, -1, filter_element)
	)
	
	# ダブルクリックでIDを自動入力
	table.item_activated.connect(func():
		var selected = table.get_selected()
		if selected:
			var card_id = selected.get_metadata(0)
			_auto_fill_card_id(card_id)
			card_list_window.queue_free()
	)
	
	add_child(card_list_window)
	card_list_window.popup_centered()

## カードテーブルにデータを追加
func _populate_card_table(table: Tree, root: TreeItem, filter_type: int, filter_element: String):
	var all_cards = CardLoader.all_cards
	
	for card in all_cards:
		var card_type = card.get("type", "")
		var card_element = card.get("element", "")
		
		# フィルター適用
		if filter_type >= 0:
			if filter_type == 0 and card_type != "creature":
				continue
			elif filter_type == 1 and card_type != "item":
				continue
			elif filter_type == 2 and card_type != "spell":
				continue
		
		if filter_element != "" and card_element != filter_element:
			continue
		
		# 行を追加
		var item = table.create_item(root)
		item.set_text(0, str(card.get("id", 0)))
		item.set_text(1, card.get("name", "不明"))
		
		# タイプ
		var type_text = ""
		match card_type:
			"creature": type_text = "🎴"
			"item": type_text = "⚔️"
			"spell": type_text = "📜"
			_: type_text = "?"
		item.set_text(2, type_text)
		
		# AP/HP（クリーチャーのみ）
		if card_type == "creature":
			item.set_text(3, str(card.get("ap", 0)))
			item.set_text(4, str(card.get("hp", 0)))
		else:
			item.set_text(3, "-")
			item.set_text(4, "-")
		
		# スキル概要
		var ability = card.get("ability_detail", "")
		if ability.length() > 30:
			ability = ability.substr(0, 27) + "..."
		item.set_text(5, ability)
		
		# メタデータにIDを保存
		item.set_metadata(0, card.get("id", 0))

## ダブルクリックされたカードIDを自動入力
func _auto_fill_card_id(card_id: int):
	var card = CardLoader.get_card_by_id(card_id)
	if not card:
		return
	
	var card_type = card.get("type", "")
	
	match card_type:
		"creature":
			# 最後にフォーカスされた側に追加
			if last_focused_side == "attacker":
				attacker_creature_id_input.text = str(card_id)
				_on_attacker_creature_add_pressed()
			else:
				defender_creature_id_input.text = str(card_id)
				_on_defender_creature_add_pressed()
		
		"item":
			# 最後にフォーカスされた側に追加
			if last_focused_side == "attacker":
				attacker_item_id_input.text = str(card_id)
				_on_attacker_item_add_pressed()
			else:
				defender_item_id_input.text = str(card_id)
				_on_defender_item_add_pressed()
		
		"spell":
			# スペルの場合（将来実装時）
			print("[BattleTestUI] スペルID: ", card_id, " - 自動入力未実装")
	
	print("[BattleTestUI] カードID ", card_id, " を", last_focused_side, "に自動入力しました")
