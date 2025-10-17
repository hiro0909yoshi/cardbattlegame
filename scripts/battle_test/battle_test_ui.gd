# バトルテストツールのメインUI
extends Control

## 参照
var config: BattleTestConfig = BattleTestConfig.new()
var results: Array = []  # BattleTestResult配列
var statistics: BattleTestStatistics = null

## UI要素（後で追加）
@onready var attacker_creature_input: LineEdit
@onready var defender_creature_input: LineEdit
@onready var execute_button: Button
@onready var result_label: Label

func _ready():
	print("[BattleTestUI] 初期化")
	_setup_ui()

## UI初期化
func _setup_ui():
	# UI要素の初期化（後で実装）
	pass

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
	# ID解析
	var id = text.to_int()
	if id > 0:
		config.attacker_creatures = [id]
		print("[BattleTestUI] 攻撃側クリーチャーID: ", id)

func _on_defender_creature_input_changed(text: String):
	# ID解析
	var id = text.to_int()
	if id > 0:
		config.defender_creatures = [id]
		print("[BattleTestUI] 防御側クリーチャーID: ", id)
