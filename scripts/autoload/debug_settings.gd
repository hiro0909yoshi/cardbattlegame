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

func _ready():
	# デフォルト値を設定（必要に応じて環境変数やコマンドライン引数から読み込み可能）
	pass
