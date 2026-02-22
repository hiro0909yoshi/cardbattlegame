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

## ========== 新規追加: ビジュアルモード設定 ==========
## ビジュアルモードUI（動的に作成）
var visual_mode_check: CheckBox = null
var auto_advance_check: CheckBox = null

## ========== 新規追加: 呪いスペル選択UI ==========
var attacker_curse_option: OptionButton = null
var defender_curse_option: OptionButton = null

## ========== 新規追加: BattleScreenManager参照 ==========
var _battle_screen_manager: BattleScreenManager = null

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

	# ========== 新規追加: BattleScreenManager作成 ==========
	_battle_screen_manager = BattleScreenManager.new()
	_battle_screen_manager.name = "BattleScreenManager_Test"
	add_child(_battle_screen_manager)
	print("[BattleTestUI] BattleScreenManager作成完了")

## UI初期化
func _setup_ui():
	# カード一覧ボタンを動的に追加
	_add_card_list_button()

	# 入力フィールドのフォーカスイベントを設定
	_setup_focus_tracking()

	# ========== 新規追加: 呪いスペル選択UI ==========
	_setup_curse_ui()

	# ========== 新規追加: ビジュアルモード設定UI ==========
	_setup_visual_mode_ui()

## ========== 新規追加: ビジュアルモード設定UI作成 ==========
func _setup_visual_mode_ui():
	# 実行ボタンの親コンテナを取得
	var execute_button_parent = execute_button.get_parent()
	if not execute_button_parent:
		push_error("[BattleTestUI] execute_button の親コンテナが見つかりません")
		return

	# ビジュアルモード設定コンテナ
	var visual_mode_container = HBoxContainer.new()
	visual_mode_container.name = "VisualModeContainer"

	# ビジュアルモードチェックボックス
	visual_mode_check = CheckBox.new()
	visual_mode_check.text = "ビジュアルモード（BattleScreen表示）"
	visual_mode_check.tooltip_text = "バトル画面を表示してエフェクトを確認"
	visual_mode_container.add_child(visual_mode_check)

	# 自動進行チェックボックス
	auto_advance_check = CheckBox.new()
	auto_advance_check.text = "自動進行"
	auto_advance_check.tooltip_text = "クリック待ちなしで連続実行"
	visual_mode_container.add_child(auto_advance_check)

	# 実行ボタンの前に挿入
	var button_index = execute_button.get_index()
	execute_button_parent.add_child(visual_mode_container)
	execute_button_parent.move_child(visual_mode_container, button_index)

	print("[BattleTestUI] ビジュアルモード設定UI作成完了")

## ========== 新規追加: 呪いスペル選択UI作成 ==========
func _setup_curse_ui():
	# アイテムリストの親コンテナを取得
	var item_list_parent = attacker_item_list.get_parent()
	if not item_list_parent:
		push_error("[BattleTestUI] アイテムリストの親コンテナが見つかりません")
		return

	# 攻撃側呪いスペル選択コンテナ
	var attacker_curse_container = VBoxContainer.new()
	attacker_curse_container.name = "AttackerCurseContainer"

	var attacker_curse_label = Label.new()
	attacker_curse_label.text = "攻撃側呪いスペル:"
	attacker_curse_container.add_child(attacker_curse_label)

	attacker_curse_option = OptionButton.new()
	attacker_curse_option.name = "AttackerCurseOption"
	_populate_curse_options(attacker_curse_option)
	attacker_curse_option.item_selected.connect(_on_attacker_curse_selected)
	attacker_curse_container.add_child(attacker_curse_option)

	# アイテムリストの後ろに挿入
	item_list_parent.add_child(attacker_curse_container)

	# 防御側呪いスペル選択コンテナ
	var defender_item_list_parent = defender_item_list.get_parent()
	if not defender_item_list_parent:
		push_error("[BattleTestUI] 防御側アイテムリストの親コンテナが見つかりません")
		return

	var defender_curse_container = VBoxContainer.new()
	defender_curse_container.name = "DefenderCurseContainer"

	var defender_curse_label = Label.new()
	defender_curse_label.text = "防御側呪いスペル:"
	defender_curse_container.add_child(defender_curse_label)

	defender_curse_option = OptionButton.new()
	defender_curse_option.name = "DefenderCurseOption"
	_populate_curse_options(defender_curse_option)
	defender_curse_option.item_selected.connect(_on_defender_curse_selected)
	defender_curse_container.add_child(defender_curse_option)

	# アイテムリストの後ろに挿入
	defender_item_list_parent.add_child(defender_curse_container)

	print("[BattleTestUI] 呪いスペル選択UI作成完了")

## 呪いスペル選択肢を追加
func _populate_curse_options(option_button: OptionButton):
	option_button.add_item("なし", 0)
	option_button.add_item("ディジーズ (AP&HP-20)", 2054)
	option_button.add_item("ディスペア (戦闘不可)", 2068)
	option_button.add_item("プレイグ (戦闘後HP減)", 2087)
	option_button.add_item("ハングドマンズシール (スキル無効)", 2064)
	option_button.add_item("ボーテックス (スキル無効)", 2094)
	option_button.add_item("バイタリティ (AP&HP+20)", 2066)
	option_button.add_item("エネルギーフィールド (攻撃無効)", 2015)
	option_button.add_item("リキッドフォーム (ランダム)", 2120)
	option_button.add_item("メタルフォーム (攻撃無効)", 2114)
	option_button.add_item("マジックシェルター (結界)", 2105)
	option_button.add_item("シニリティ (崩壊)", 2032)
	option_button.add_item("ディスエレメント (地形無効)", 2055)
	option_button.add_item("ディラニー (MHP30以下不可)", 2057)
	option_button.add_item("ハイプリーステス (呪い結界)", 2048)
	option_button.add_item("ハーミットズパラドックス (同種破壊)", 2111)
	option_button.add_item("ライズアップ (奮闘)", 2067)
	option_button.add_item("グラナイト (堅牢)", 2108)
	option_button.add_item("ブラストトラップ (焦土)", 2083)
	option_button.selected = 0  # デフォルト: なし

## 攻撃側呪いスペル選択ハンドラー
func _on_attacker_curse_selected(index: int):
	var spell_id = attacker_curse_option.get_item_id(index)
	config.attacker_curse_spell_id = spell_id
	print("[BattleTestUI] 攻撃側呪いスペル選択: ID=", spell_id)

## 防御側呪いスペル選択ハンドラー
func _on_defender_curse_selected(index: int):
	var spell_id = defender_curse_option.get_item_id(index)
	config.defender_curse_spell_id = spell_id
	print("[BattleTestUI] 防御側呪いスペル選択: ID=", spell_id)

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

	# ビジュアルモード設定を反映
	if visual_mode_check:
		config.visual_mode = visual_mode_check.button_pressed
		config.auto_advance = auto_advance_check.button_pressed

	# ボタンを無効化
	execute_button.disabled = true

	# 実行モード分岐
	if config.visual_mode:
		print("[BattleTestUI] ビジュアルモード実行開始")
		result_label.text = "ビジュアルモード実行中..."
		await _execute_visual_mode()
	else:
		print("[BattleTestUI] ロジックモード実行開始")
		result_label.text = "実行中..."
		_execute_logic_mode()

	# ボタンを有効化
	execute_button.disabled = false

	print("[BattleTestUI] テスト実行完了")

## ロジックモード実行（既存の処理）
func _execute_logic_mode():
	# 次フレームでバトル実行（UIをブロックしないため）
	await get_tree().process_frame

	# バトル実行
	results = BattleTestExecutor.execute_all_battles(config)

	# 統計計算
	statistics = BattleTestStatistics.calculate(results)

	# 結果表示
	_display_results()
	print("[BattleTestUI] ロジックモード実行完了")

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

## ========== ビジュアルモード実装 ==========

## ビジュアルモード実行
func _execute_visual_mode():
	# テストケース生成
	var test_cases = _generate_test_cases()

	if test_cases.is_empty():
		push_error("[ビジュアルモード] テストケースが生成できません")
		return

	print("[ビジュアルモード] ", test_cases.size(), "バトル実行開始")

	for i in range(test_cases.size()):
		var test_case = test_cases[i]

		# プログレス表示
		result_label.text = "バトル %d / %d 実行中..." % [i + 1, test_cases.size()]

		# バトル実行
		await _execute_single_visual_battle(test_case, i + 1, test_cases.size())

		# 自動進行がOFFなら、ユーザーのクリック待ち
		if not config.auto_advance:
			result_label.text = "クリックして次のバトルへ... (%d / %d)" % [i + 1, test_cases.size()]
			await _wait_for_user_click()

	result_label.text = "ビジュアルモード完了: %d バトル実行" % test_cases.size()
	print("[ビジュアルモード] 完了")

## テストケース生成
func _generate_test_cases() -> Array:
	var cases = []

	# 攻撃側×防御側×アイテムの組み合わせ
	for att_creature_id in config.attacker_creatures:
		for def_creature_id in config.defender_creatures:
			# アイテムなしも含める
			var att_items = config.attacker_items if config.attacker_items.size() > 0 else [-1]
			for att_item_id in att_items:
				var def_items = config.defender_items if config.defender_items.size() > 0 else [-1]
				for def_item_id in def_items:
					cases.append({
						"attacker_creature_id": att_creature_id,
						"attacker_item_id": att_item_id,
						"defender_creature_id": def_creature_id,
						"defender_item_id": def_item_id
					})

	return cases

## 単一バトルを視覚的に実行
func _execute_single_visual_battle(test_case: Dictionary, battle_num: int, total_battles: int):
	# クリーチャーデータ準備
	var attacker_card = CardLoader.get_card_by_id(test_case.attacker_creature_id)
	var defender_card = CardLoader.get_card_by_id(test_case.defender_creature_id)

	if not attacker_card or not defender_card:
		push_error("[ビジュアルモード] カードデータ取得失敗")
		return

	# データ複製（duplicate(true)で深いコピー）
	var attacker_data = attacker_card.duplicate(true)
	var defender_data = defender_card.duplicate(true)

	# アイテム追加
	if test_case.attacker_item_id > 0:
		var item = CardLoader.get_card_by_id(test_case.attacker_item_id)
		if item:
			attacker_data["items"] = [item]

	if test_case.defender_item_id > 0:
		var item = CardLoader.get_card_by_id(test_case.defender_item_id)
		if item:
			defender_data["items"] = [item]

	# 土地ボーナス計算（防御側のみ）
	var land_bonus = 0
	if defender_data.get("element", "") == config.defender_battle_land:
		land_bonus = config.defender_battle_land_level * 10

	# current_hp設定
	attacker_data["current_hp"] = attacker_data.get("hp", 0)
	defender_data["current_hp"] = defender_data.get("hp", 0) + land_bonus

	# current_ap設定
	attacker_data["current_ap"] = attacker_data.get("ap", 0)
	defender_data["current_ap"] = defender_data.get("ap", 0)

	print("[ビジュアルモード] バトル%d/%d: %s vs %s" % [
		battle_num, total_battles,
		attacker_data.get("name", "?"),
		defender_data.get("name", "?")
	])

	# BattleScreenManagerが存在するか確認
	if not _battle_screen_manager:
		push_error("[ビジュアルモード] BattleScreenManager が初期化されていません")
		return

	# バトル画面を開く
	await _battle_screen_manager.start_battle(attacker_data, defender_data)

	# start_battle()内でイントロ完了済み（await不要）

	# バトル実行（BattleSystemを使用）
	var battle_system = BattleSystem.new()
	battle_system._ready()

	# 実際のBoardSystem3Dを使用（テスト環境用に最小限の初期化）
	var mock_board = BoardSystem3D.new()
	mock_board.name = "BoardSystem3D_Test"
	battle_system.add_child(mock_board)

	# skill_indexを初期化（BattleSystemの鼓舞スキル処理で必須）
	mock_board.skill_index = {
		"support": {},
		"world_spell": {}
	}

	# TileDataManagerを作成（get_player_lands_by_elementで必須）
	var tile_data_mgr = TileDataManager.new()
	tile_data_mgr.name = "TileDataManager"
	mock_board.add_child(tile_data_mgr)
	mock_board.tile_data_manager = tile_data_mgr

	# テスト用のダミータイルノード辞書を設定
	tile_data_mgr.tile_nodes = {}

	var mock_card = BattleTestExecutor.MockCardSystem.new()
	var mock_player = BattleTestExecutor.MockPlayerSystem.new()

	# SpellMagicとSpellDrawのモックを作成
	var spell_magic = SpellMagic.new()
	spell_magic.setup(mock_player)

	var spell_draw = SpellDraw.new()
	spell_draw.setup(mock_card)

	battle_system.setup_systems(mock_board, mock_card, mock_player)

	# BattleSystemにSpellMagic/SpellDrawを手動で設定
	battle_system.spell_magic = spell_magic
	battle_system.spell_draw = spell_draw
	battle_system.battle_special_effects.setup_systems(mock_board, spell_draw, spell_magic, mock_card)
	battle_system.battle_preparation.setup_systems(mock_board, mock_card, mock_player, spell_magic)

	# BattleParticipant作成
	var attacker = BattleParticipant.new(
		attacker_data,
		attacker_data.get("hp", 0),
		0,
		attacker_data.get("ap", 0),
		true,
		0
	)
	attacker.current_hp = attacker_data.get("current_hp", attacker_data.get("hp", 0))
	attacker.spell_magic_ref = spell_magic

	var defender = BattleParticipant.new(
		defender_data,
		defender_data.get("hp", 0),
		land_bonus,
		defender_data.get("ap", 0),
		false,
		1
	)
	defender.current_hp = defender_data.get("current_hp", defender_data.get("hp", 0))
	defender.spell_magic_ref = spell_magic

	# ========== 新規追加: 呪いスペル適用 ==========
	if config.attacker_curse_spell_id > 0:
		_apply_curse_spell_visual(attacker, config.attacker_curse_spell_id)
	if config.defender_curse_spell_id > 0:
		_apply_curse_spell_visual(defender, config.defender_curse_spell_id)

	# ダメージ計算（簡易版）
	var attacker_damage = attacker.current_ap
	var defender_damage = defender.current_ap

	# 攻撃表示
	await _battle_screen_manager.show_attack("attacker", attacker_damage)

	# HP更新
	defender.current_hp -= attacker_damage
	var defender_hp_data = {
		"current_hp": defender.current_hp,
		"base_hp": defender.base_hp
	}
	await _battle_screen_manager.update_hp("defender", defender_hp_data)

	# 防御側が生きていれば反撃
	if defender.current_hp > 0:
		await _battle_screen_manager.show_attack("defender", defender_damage)
		attacker.current_hp -= defender_damage
		var attacker_hp_data = {
			"current_hp": attacker.current_hp,
			"base_hp": attacker.base_hp
		}
		await _battle_screen_manager.update_hp("attacker", attacker_hp_data)

	# 勝者判定
	var result = BattleSystem.BattleResult.ATTACKER_WIN
	if attacker.current_hp <= 0 and defender.current_hp <= 0:
		result = BattleSystem.BattleResult.BOTH_DEFEATED
	elif attacker.current_hp <= 0:
		result = BattleSystem.BattleResult.DEFENDER_WIN
	elif defender.current_hp > 0:
		result = BattleSystem.BattleResult.ATTACKER_SURVIVED

	# 結果表示
	await _battle_screen_manager.show_battle_result(result)

	# バトル画面を閉じる
	await _battle_screen_manager.close_battle_screen()

	print("[ビジュアルモード] バトル%d完了" % battle_num)

## ========== 新規追加: 呪いスペル適用（ビジュアルモード用） ==========
func _apply_curse_spell_visual(participant: BattleParticipant, spell_id: int):
	var spell_data = CardLoader.get_card_by_id(spell_id)
	if not spell_data:
		push_error("[BattleTestUI] 呪いスペルID ", spell_id, " が見つかりません")
		return

	if not participant.creature_data.has("curse"):
		participant.creature_data["curse"] = []

	participant.creature_data["curse"].append(spell_data.duplicate(true))
	print("[ビジュアルモード] ", participant.creature_data.get("name", "?"), " に呪いスペル適用: ", spell_data.get("name", "?"))

## ユーザークリック待ち
func _wait_for_user_click():
	# 簡易実装: 1秒待つ（本来はInputEventを待つ）
	await get_tree().create_timer(1.0).timeout
