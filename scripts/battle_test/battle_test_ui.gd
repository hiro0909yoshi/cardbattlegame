# バトルテストツールのメインUI
extends Control

## 参照
var config: BattleTestConfig = BattleTestConfig.new()
var results: Array = []  # BattleTestResult配列
var statistics: BattleTestStatistics = null

## UI要素
@onready var attacker_creature_input: LineEdit = $MainContainer/AttackerContainer/AttackerCreatureInput
@onready var attacker_item_input: LineEdit = $MainContainer/AttackerItemContainer/AttackerItemInput
@onready var defender_creature_input: LineEdit = $MainContainer/DefenderContainer/DefenderCreatureInput
@onready var defender_item_input: LineEdit = $MainContainer/DefenderItemContainer/DefenderItemInput

# 土地設定（攻撃側）
@onready var attacker_fire_spin: SpinBox = $MainContainer/AttackerLandContainer/AttackerFireSpin
@onready var attacker_water_spin: SpinBox = $MainContainer/AttackerLandContainer/AttackerWaterSpin
@onready var attacker_wind_spin: SpinBox = $MainContainer/AttackerLandContainer/AttackerWindSpin
@onready var attacker_earth_spin: SpinBox = $MainContainer/AttackerLandContainer/AttackerEarthSpin

# 土地設定（防御側）
@onready var defender_fire_spin: SpinBox = $MainContainer/DefenderLandContainer/DefenderFireSpin
@onready var defender_water_spin: SpinBox = $MainContainer/DefenderLandContainer/DefenderWaterSpin
@onready var defender_wind_spin: SpinBox = $MainContainer/DefenderLandContainer/DefenderWindSpin
@onready var defender_earth_spin: SpinBox = $MainContainer/DefenderLandContainer/DefenderEarthSpin

@onready var swap_button: Button = $MainContainer/SwapContainer/SwapButton
@onready var execute_button: Button = $MainContainer/ExecuteButton
@onready var result_label: Label = $MainContainer/ResultLabel

func _ready():
	print("[BattleTestUI] 初期化")
	# @onready変数が初期化されるまで待つ
	await get_tree().process_frame
	_setup_ui()

## UI初期化
func _setup_ui():
	# シグナル接続
	attacker_creature_input.text_changed.connect(_on_attacker_creature_input_changed)
	attacker_item_input.text_changed.connect(_on_attacker_item_input_changed)
	defender_creature_input.text_changed.connect(_on_defender_creature_input_changed)
	defender_item_input.text_changed.connect(_on_defender_item_input_changed)
	
	# 土地設定（SpinBoxが存在するか確認）
	if attacker_fire_spin:
		attacker_fire_spin.value_changed.connect(_on_attacker_land_changed)
		attacker_water_spin.value_changed.connect(_on_attacker_land_changed)
		attacker_wind_spin.value_changed.connect(_on_attacker_land_changed)
		attacker_earth_spin.value_changed.connect(_on_attacker_land_changed)
	else:
		push_warning("攻撃側土地SpinBoxが見つかりません")
	
	if defender_fire_spin:
		defender_fire_spin.value_changed.connect(_on_defender_land_changed)
		defender_water_spin.value_changed.connect(_on_defender_land_changed)
		defender_wind_spin.value_changed.connect(_on_defender_land_changed)
		defender_earth_spin.value_changed.connect(_on_defender_land_changed)
	else:
		push_warning("防御側土地SpinBoxが見つかりません")
	
	swap_button.pressed.connect(_on_swap_button_pressed)
	execute_button.pressed.connect(_on_execute_button_pressed)

## 実行ボタン押下
func _on_execute_button_pressed():
	print("[BattleTestUI] テスト実行開始")
	
	# 設定をバリデーション
	if not config.validate():
		push_error("設定が不正です")
		return
	
	# TODO: Phase 4でバトル実行を実装
	print("[BattleTestUI] バトル実行準備完了")
	print("  攻撃側クリーチャー: ", config.attacker_creatures)
	print("  防御側クリーチャー: ", config.defender_creatures)

## クリーチャーID入力
func _on_attacker_creature_input_changed(text: String):
	var id = text.to_int()
	if id > 0:
		config.attacker_creatures = [id]
		print("[BattleTestUI] 攻撃側クリーチャーID: ", id)

func _on_defender_creature_input_changed(text: String):
	var id = text.to_int()
	if id > 0:
		config.defender_creatures = [id]
		print("[BattleTestUI] 防御側クリーチャーID: ", id)

## アイテムID入力
func _on_attacker_item_input_changed(text: String):
	if text.is_empty() or text == "なし":
		config.attacker_items = [-1]  # なし
		print("[BattleTestUI] 攻撃側アイテム: なし")
	else:
		var id = text.to_int()
		if id > 0:
			config.attacker_items = [id]
			print("[BattleTestUI] 攻撃側アイテムID: ", id)

func _on_defender_item_input_changed(text: String):
	if text.is_empty() or text == "なし":
		config.defender_items = [-1]  # なし
		print("[BattleTestUI] 防御側アイテム: なし")
	else:
		var id = text.to_int()
		if id > 0:
			config.defender_items = [id]
			print("[BattleTestUI] 防御側アイテムID: ", id)

## 土地設定変更
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

## 攻撃⇔防御入れ替え
func _on_swap_button_pressed():
	# 設定を入れ替え
	config.swap_attacker_defender()
	
	# UIに反映（クリーチャー・アイテム）
	var temp_creature = attacker_creature_input.text
	attacker_creature_input.text = defender_creature_input.text
	defender_creature_input.text = temp_creature
	
	var temp_item = attacker_item_input.text
	attacker_item_input.text = defender_item_input.text
	defender_item_input.text = temp_item
	
	# UIに反映（土地）
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
	
	print("[BattleTestUI] 攻撃⇔防御を入れ替えました")
