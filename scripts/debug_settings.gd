extends RefCounted
class_name DebugSettings

# デバッグ用フラグの一元管理
# 各システムから参照される召喚条件・アイテム制限のデバッグフラグ

## カード犠牲を無効化（false=有効）
static var disable_card_sacrifice: bool = false

## 土地条件（必要シンボル）を無効化（false=有効）
static var disable_lands_required: bool = false

## 配置制限を無効化（false=有効）
static var disable_cannot_summon: bool = false

## アイテム使用制限を無効化（false=有効）
static var disable_cannot_use: bool = false

## 秘密カードを無効化（false=有効：秘密カードは裏向きのまま）
static var disable_secret_cards: bool = false

## クリーチャーマネージャのデバッグログ表示
static var creature_manager_debug: bool = false

## UIマネージャのデバッグモード（CPU手札表示等）
static var ui_debug_mode: bool = false

## シグナルレジストリのデバッグログ表示
static var signal_registry_debug: bool = true
