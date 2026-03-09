# バトルテスト用プリセット定義
class_name BattleTestPresets
extends RefCounted

## クリーチャープリセット
static var CREATURE_PRESETS = {
	# === 全スキル代表 ===
	"オールスキル": [2, 7, 4, 1, 6, 16, 36, 326, 113, 17, 22, 426, 34, 136, 139, 232, 107, 410, 119, 442, 41, 12, 116, 416, 432, 25],
	# === 属性別 ===
	"火属性": [2, 4, 7, 9, 15, 16, 19],
	"水属性": [101, 104, 108, 113, 116, 120],
	"風属性": [300, 303, 307, 309, 315, 320],
	"地属性": [201, 205, 210, 215, 220],
	# === スキル別 ===
	"共鳴持ち": [2, 46, 115, 122, 213, 241, 308, 309, 345],
	"先制攻撃持ち": [7, 15, 19, 35, 41, 204, 303, 304, 316, 344, 404, 418],
	"強化持ち": [4, 9, 26, 42, 49, 235, 329, 333, 343, 437],
	"無効化[巻物]持ち": [1, 33, 112, 402, 406, 408, 409, 434],
	"無効化[その他]持ち": [6, 11, 16, 100, 104, 105, 106, 109, 111, 122, 212, 325, 424, 437, 447],
	"即死持ち": [16, 111, 118, 201, 325, 415, 424],
	"刺突持ち": [36, 334, 427],
	"2回攻撃持ち": [326],
	"再生持ち": [113, 125, 129, 133, 205, 233, 247, 420],
	"加勢持ち": [17, 35, 103, 137, 202, 221, 229, 300, 409, 428],
	"鼓舞持ち": [22, 43, 114, 144, 237, 342, 347, 436, 445],
	"反射持ち": [25, 426],
	"術攻撃持ち": [34, 44, 128],
	"形見持ち": [136, 315, 410, 439],
	"蘇生持ち": [139, 411],
	"復活持ち": [40, 232],
	"吸魔持ち": [107],
	"蓄魔持ち": [36, 127, 410],
	"後手持ち": [119, 201],
	"相討持ち": [442],
	"帰還持ち": [41, 314],
	"強化術持ち": [12, 39, 130, 147, 302, 303, 407, 429],
	"アイテム破壊持ち": [116, 219, 313],
	"アイテム盗み持ち": [416],
	"変身持ち": [432],
	"反射[1/2]持ち": [25],
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
