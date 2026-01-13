# アイテム使用制限チェッカー
# クリーチャーのcannot_use制限をチェックする
class_name ItemUseRestriction
extends RefCounted


## アイテムカテゴリ一覧
const ITEM_CATEGORIES = ["武器", "防具", "アクセサリ", "巻物"]


## クリーチャーがアイテムを使用できるかチェック
## creature_data: クリーチャーのデータ
## item_data: アイテムのデータ
## 戻り値: {can_use: bool, reason: String}
static func check_can_use(creature_data: Dictionary, item_data: Dictionary) -> Dictionary:
	if creature_data.is_empty() or item_data.is_empty():
		return {"can_use": true, "reason": ""}
	
	# クリーチャーのcannot_use制限を取得
	var restrictions = creature_data.get("restrictions", {})
	var cannot_use = restrictions.get("cannot_use", [])
	
	if cannot_use.is_empty():
		return {"can_use": true, "reason": ""}
	
	# アイテムのカテゴリを取得
	var item_type = item_data.get("item_type", "")
	
	if item_type.is_empty():
		return {"can_use": true, "reason": ""}
	
	# 使用不可リストに含まれているかチェック
	if item_type in cannot_use:
		var creature_name = creature_data.get("name", "このクリーチャー")
		return {
			"can_use": false,
			"reason": "%sは%sを使用できません" % [creature_name, item_type]
		}
	
	return {"can_use": true, "reason": ""}


## 使用可能なアイテムのみをフィルタ
## creature_data: クリーチャーのデータ
## items: アイテムのリスト（配列）
## 戻り値: 使用可能なアイテムのリスト
static func filter_usable_items(creature_data: Dictionary, items: Array) -> Array:
	var result = []
	
	for item in items:
		var check = check_can_use(creature_data, item)
		if check.can_use:
			result.append(item)
	
	return result


## 使用可能なアイテムインデックスのみをフィルタ
## creature_data: クリーチャーのデータ
## items: アイテムのリスト（配列）
## 戻り値: 使用可能なアイテムのインデックスリスト
static func filter_usable_item_indices(creature_data: Dictionary, items: Array) -> Array:
	var result = []
	
	for i in range(items.size()):
		var check = check_can_use(creature_data, items[i])
		if check.can_use:
			result.append(i)
	
	return result


## クリーチャーのcannot_use制限を取得
## creature_data: クリーチャーのデータ
## 戻り値: 使用不可カテゴリの配列
static func get_cannot_use_list(creature_data: Dictionary) -> Array:
	var restrictions = creature_data.get("restrictions", {})
	return restrictions.get("cannot_use", [])


## アイテムカテゴリを取得
## item_data: アイテムのデータ
## 戻り値: カテゴリ文字列
static func get_item_category(item_data: Dictionary) -> String:
	return item_data.get("item_type", "")
