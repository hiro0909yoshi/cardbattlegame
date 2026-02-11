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
