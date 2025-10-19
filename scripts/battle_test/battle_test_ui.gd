# バトルテストツールのメインUI
extends Control

## 参照
var config: BattleTestConfig = BattleTestConfig.new()
var results: Array = []  # BattleTestResult配列
var statistics: BattleTestStatistics = null

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
@onready var attacker_adjacent_check: CheckBox = $MainSplitContainer/MainContainer/AdjacentContainer/AttackerAdjacentCheck
@onready var defender_adjacent_check: CheckBox = $MainSplitContainer/MainContainer/AdjacentContainer/DefenderAdjacentCheck

## 実行
@onready var swap_button: Button = $MainSplitContainer/MainContainer/SwapContainer/SwapButton
@onready var execute_button: Button = $MainSplitContainer/MainContainer/ExecuteButton
@onready var result_label: Label = $MainSplitContainer/MainContainer/ResultLabel

## 結果表示
@onready var statistics_label: RichTextLabel = $MainSplitContainer/ResultPanel/ResultContainer/ResultTabs/StatisticsTab/StatisticsLabel
@onready var detail_table: ItemList = $MainSplitContainer/ResultPanel/ResultContainer/ResultTabs/DetailTable

func _ready():
	print("[BattleTestUI] 初期化")
	await get_tree().process_frame
	_setup_ui()

## UI初期化
func _setup_ui():
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
	if attacker_adjacent_check:
		attacker_adjacent_check.toggled.connect(_on_attacker_adjacent_toggled)
	if defender_adjacent_check:
		defender_adjacent_check.toggled.connect(_on_defender_adjacent_toggled)
	
	# 実行
	swap_button.pressed.connect(_on_swap_button_pressed)
	execute_button.pressed.connect(_on_execute_button_pressed)

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
	var id = id_text.to_int()
	if id <= 0:
		print("[BattleTestUI] 無効なアイテムID: ", id_text)
		return
	
	# TODO: アイテム名取得（CardLoaderにアイテム機能が実装されたら）
	var display_text = "アイテム (ID:%d)" % id
	attacker_item_list.add_item(display_text)
	attacker_item_list.set_item_metadata(attacker_item_list.item_count - 1, id)
	
	config.attacker_items.append(id)
	print("[BattleTestUI] 攻撃側アイテム追加: ID ", id)
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
	var id = id_text.to_int()
	if id <= 0:
		print("[BattleTestUI] 無効なアイテムID: ", id_text)
		return
	
	var display_text = "アイテム (ID:%d)" % id
	defender_item_list.add_item(display_text)
	defender_item_list.set_item_metadata(defender_item_list.item_count - 1, id)
	config.defender_items.append(id)
	print("[BattleTestUI] 防御側アイテム追加: ID ", id)
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
	var elements = ["fire", "water", "wind", "earth"]
	var element = elements[index]
	config.attacker_battle_land = element
	config.defender_battle_land = element
	print("[BattleTestUI] バトル発生土地: ", element)

func _on_attacker_adjacent_toggled(toggled_on: bool):
	config.attacker_has_adjacent = toggled_on
	print("[BattleTestUI] 攻撃側隣接条件: ", toggled_on)

func _on_defender_adjacent_toggled(toggled_on: bool):
	config.defender_has_adjacent = toggled_on
	print("[BattleTestUI] 防御側隣接条件: ", toggled_on)

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
		
		# 1行にまとめて表示
		var line = "[%d] %s vs %s → %s (残HP: %d vs %d)" % [
			result.battle_id,
			result.attacker_name,
			result.defender_name,
			"攻撃側勝利" if result.winner == "attacker" else "防御側勝利",
			result.attacker_final_hp,
			result.defender_final_hp
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
