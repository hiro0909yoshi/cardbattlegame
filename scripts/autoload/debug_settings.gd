extends Node

# デバッグ用フラグの一元管理
# 各システムから参照される召喚条件・アイテム制限のデバッグフラグ

## 全プレイヤーを手動操作にする（true=有効）
var manual_control_all: bool = false

## カード犠牲を無効化（true=無効化）
var disable_card_sacrifice: bool = false

## 土地条件（必要シンボル）を無効化（true=無効化）
var disable_lands_required: bool = false

## 配置制限を無効化（true=無効化）
var disable_cannot_summon: bool = false

## アイテム使用制限を無効化（true=無効化）
var disable_cannot_use: bool = false

## 秘密カードを無効化（true=無効化：秘密カードは裏向きのまま）
var disable_secret_cards: bool = false

## クリーチャーマネージャのデバッグログ表示
var creature_manager_debug: bool = false

## UIマネージャのデバッグモード（CPU手札表示等）
var ui_debug_mode: bool = false

## シグナルレジストリのデバッグログ表示
var signal_registry_debug: bool = true

## 課金石を表示する（false=非表示、公開時にtrueに変更）
var show_premium_stone: bool = true

## CPU切り替えテスト（true=ソロバトルでCPU1を人間操作で開始、途中CPU切り替え可能）
var test_cpu_takeover: bool = false

## FPS表示（全画面共通）
var show_fps: bool = true

## パフォーマンス検証: 城背景を無効化
var disable_castle: bool = false

## パフォーマンス検証: 手札カードを非表示
var disable_hand_cards: bool = false

## パフォーマンス検証: キャラモデルを非表示
var disable_characters: bool = false

## パフォーマンス検証: タイルを非表示
var disable_tiles: bool = false

## パフォーマンス検証: 全_processを停止
var disable_all_process: bool = false
var _fps_label: Label = null

func _ready():
	# デフォルト値を設定（必要に応じて環境変数やコマンドライン引数から読み込み可能）
	_setup_fps_display()

func _setup_fps_display():
	_fps_label = Label.new()
	_fps_label.name = "GlobalFPS"
	_fps_label.text = "FPS: --"
	_fps_label.position = Vector2(10, 10)
	_fps_label.add_theme_font_size_override("font_size", 28)
	_fps_label.add_theme_color_override("font_color", Color.YELLOW)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 3)
	_fps_label.z_index = 4096
	_fps_label.visible = show_fps
	add_child(_fps_label)

func _process(_delta: float):
	if _fps_label and show_fps:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
