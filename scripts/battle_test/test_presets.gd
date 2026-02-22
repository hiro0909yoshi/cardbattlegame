# バトルテスト用プリセット定義
class_name BattleTestPresets
extends RefCounted

## クリーチャープリセット
static var CREATURE_PRESETS = {
	"火属性": [2, 4, 7, 9, 15, 16, 19],
	"水属性": [101, 104, 108, 113, 116, 120],
	"風属性": [300, 303, 307, 309, 315, 320],
	"地属性": [201, 205, 210, 215, 220],
	"先制攻撃持ち": [7, 303, 405],
	"強化持ち": [4, 9, 19],
	"無効化持ち": [1, 6, 11, 16, 112, 325, 413],
}

## アイテムプリセット（手動追加予定）
static var ITEM_PRESETS = {
	"武器系": [],
	"防具系": [],
	"アクセサリ系": [],
	"巻物系": [],
}

## スペルプリセット（手動追加予定）
static var SPELL_PRESETS = {
	"攻撃系": [],
	"防御系": [],
	"補助系": [],
}

## クリーチャープリセット取得
static func get_creature_preset(name: String) -> Array:
	if CREATURE_PRESETS.has(name):
		return CREATURE_PRESETS[name].duplicate()
	return []

## アイテムプリセット取得
static func get_item_preset(name: String) -> Array:
	if ITEM_PRESETS.has(name):
		return ITEM_PRESETS[name].duplicate()
	return []

## スペルプリセット取得
static func get_spell_preset(name: String) -> Array:
	if SPELL_PRESETS.has(name):
		return SPELL_PRESETS[name].duplicate()
	return []

## 全クリーチャープリセット名取得
static func get_all_creature_preset_names() -> Array:
	return CREATURE_PRESETS.keys()

## 全アイテムプリセット名取得
static func get_all_item_preset_names() -> Array:
	return ITEM_PRESETS.keys()

## 全スペルプリセット名取得
static func get_all_spell_preset_names() -> Array:
	return SPELL_PRESETS.keys()
