## ガチャシステム
extends Node

# 排出確率（合計100%）
# C = 最低、N、S、R = 最高
const RARITY_RATES = {
	"C": 50.0,
	"N": 35.0,
	"S": 12.0,
	"R": 3.0
}

# ガチャ価格
const SINGLE_COST = 100
const MULTI_10_COST = 1000
const MULTI_10_COUNT = 10
const MULTI_100_COST = 10000
const MULTI_100_COUNT = 100

## ガチャを1回引く
func pull_single() -> Dictionary:
	if not _can_afford(SINGLE_COST):
		return {"success": false, "error": "ゴールドが足りません"}
	
	# ゴールド消費
	GameData.player_data.profile.gold -= SINGLE_COST
	GameData.save_to_file()
	
	# カード抽選
	var card = _pull_one()
	
	# DBに追加
	UserCardDB.add_card(card.id, 1)
	UserCardDB.flush()
	
	return {"success": true, "cards": [card]}

## ガチャを10連で引く
func pull_multi_10() -> Dictionary:
	if not _can_afford(MULTI_10_COST):
		return {"success": false, "error": "ゴールドが足りません"}
	
	# ゴールド消費
	GameData.player_data.profile.gold -= MULTI_10_COST
	GameData.save_to_file()
	
	# カード抽選（10回）
	var cards = []
	for i in range(MULTI_10_COUNT):
		var card = _pull_one()
		cards.append(card)
		UserCardDB.add_card(card.id, 1)
	
	# DBをフラッシュ
	UserCardDB.flush()
	
	return {"success": true, "cards": cards}

## ガチャを100連で引く
func pull_multi_100() -> Dictionary:
	if not _can_afford(MULTI_100_COST):
		return {"success": false, "error": "ゴールドが足りません"}
	
	# ゴールド消費
	GameData.player_data.profile.gold -= MULTI_100_COST
	GameData.save_to_file()
	
	# カード抽選（100回）
	var cards = []
	for i in range(MULTI_100_COUNT):
		var card = _pull_one()
		cards.append(card)
		UserCardDB.add_card(card.id, 1)
	
	# DBをフラッシュ
	UserCardDB.flush()
	
	return {"success": true, "cards": cards}

## 1枚抽選
func _pull_one() -> Dictionary:
	# レアリティを決定
	var rarity = _determine_rarity()
	
	# そのレアリティのクリーチャーを取得
	var candidates = _get_cards_by_rarity(rarity)
	
	if candidates.is_empty():
		# フォールバック：Cレアリティ
		candidates = _get_cards_by_rarity("C")
	
	# ランダムに1枚選択
	var index = randi() % candidates.size()
	return candidates[index]

## レアリティを確率で決定
func _determine_rarity() -> String:
	var roll = randf() * 100.0
	var cumulative = 0.0
	
	for rarity in RARITY_RATES.keys():
		cumulative += RARITY_RATES[rarity]
		if roll < cumulative:
			return rarity
	
	return "C"  # フォールバック

## 指定レアリティのカードを取得（クリーチャー、アイテム、スペル全て）
func _get_cards_by_rarity(rarity: String) -> Array:
	var result = []
	
	for card in CardLoader.all_cards:
		var card_rarity = card.get("rarity", "N")
		if card_rarity == rarity:
			result.append(card)
	
	return result

## ゴールドが足りるか確認
func _can_afford(cost: int) -> bool:
	return GameData.player_data.profile.gold >= cost

## 現在のゴールドを取得
func get_gold() -> int:
	return GameData.player_data.profile.gold
