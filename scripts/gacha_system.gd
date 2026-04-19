## ガチャシステム
extends Node

# ガチャタイプ（ゴールドガチャ）
enum GachaType { NORMAL, S_GACHA, R_GACHA }

# 課金ガチャタイプ（属性/カードタイプ固定）
enum PremiumGachaType { FIRE, WATER, EARTH, WIND, NEUTRAL, SPELL, ITEM }

# 排出確率（ゴールドガチャ）
const RARITY_RATES = {
	GachaType.NORMAL: {  # C + N のみ
		"C": 60.0,
		"N": 40.0
	},
	GachaType.S_GACHA: {  # C + N + S
		"C": 50.0,
		"N": 35.0,
		"S": 15.0
	},
	GachaType.R_GACHA: {  # C + N + S + R
		"C": 50.0,
		"N": 35.0,
		"S": 12.0,
		"R": 3.0
	}
}

# 課金ガチャ排出確率（全タイプ共通）
const PREMIUM_RARITY_RATES: Dictionary = {
	"S": 70.0,
	"R": 30.0
}

# ガチャ価格（ゴールドガチャ）
const GACHA_COSTS = {
	GachaType.NORMAL: { "single": 50, "multi_10": 500, "multi_100": 5000 },
	GachaType.S_GACHA: { "single": 80, "multi_10": 800, "multi_100": 8000 },
	GachaType.R_GACHA: { "single": 100, "multi_10": 1000, "multi_100": 10000 }
}

# 課金ガチャ価格（ジェム）
const PREMIUM_GACHA_COSTS: Dictionary = { "single": 100, "multi_10": 900 }

# 課金ガチャタイプ → フィルター条件
const PREMIUM_GACHA_FILTERS: Dictionary = {
	PremiumGachaType.FIRE: { "card_type": "creature", "element": "fire" },
	PremiumGachaType.WATER: { "card_type": "creature", "element": "water" },
	PremiumGachaType.EARTH: { "card_type": "creature", "element": "earth" },
	PremiumGachaType.WIND: { "card_type": "creature", "element": "wind" },
	PremiumGachaType.NEUTRAL: { "card_type": "creature", "element": "neutral" },
	PremiumGachaType.SPELL: { "card_type": "spell", "element": "" },
	PremiumGachaType.ITEM: { "card_type": "item", "element": "" },
}

# 課金ガチャ表示名
const PREMIUM_GACHA_NAMES: Dictionary = {
	PremiumGachaType.FIRE: "火属性ガチャ",
	PremiumGachaType.WATER: "水属性ガチャ",
	PremiumGachaType.EARTH: "地属性ガチャ",
	PremiumGachaType.WIND: "風属性ガチャ",
	PremiumGachaType.NEUTRAL: "無属性ガチャ",
	PremiumGachaType.SPELL: "スペルガチャ",
	PremiumGachaType.ITEM: "アイテムガチャ",
}

# GachaType → UnlockManagerキーのマッピング
const GACHA_UNLOCK_KEYS = {
	GachaType.NORMAL: "gacha.normal",
	GachaType.S_GACHA: "gacha.s_gacha",
	GachaType.R_GACHA: "gacha.r_gacha"
}

# 旧API互換用
const SINGLE_COST = 100
const MULTI_10_COST = 1000
const MULTI_10_COUNT = 10
const MULTI_100_COST = 10000
const MULTI_100_COUNT = 100

# ガチャから排出しないカードIDリスト（合成・変身専用カード等）
const EXCLUDED_CARD_IDS: Array[int] = [1, 300, 408]  # フレイムパラディン, ヴァルキリー, オーディン

# 現在選択中のガチャタイプ
var current_gacha_type: GachaType = GachaType.NORMAL

## ガチャタイプを設定
func set_gacha_type(type: GachaType) -> void:
	current_gacha_type = type

## ガチャタイプを取得
func get_gacha_type() -> GachaType:
	return current_gacha_type

## ガチャが解禁されているか確認（UnlockManager委譲）
func is_gacha_unlocked(type: GachaType) -> bool:
	var key = GACHA_UNLOCK_KEYS.get(type, "")
	if key.is_empty():
		return false
	return UnlockManager.is_unlocked(key)

## 単発ガチャの価格を取得
func get_single_cost(type: GachaType = current_gacha_type) -> int:
	return GACHA_COSTS[type]["single"]

## 10連ガチャの価格を取得
func get_multi_10_cost(type: GachaType = current_gacha_type) -> int:
	return GACHA_COSTS[type]["multi_10"]

## ガチャを1回引く（タイプ指定版）
func pull_single_typed(type: GachaType) -> Dictionary:
	var cost = get_single_cost(type)
	if not _can_afford(cost):
		return {"success": false, "error": "ゴールドが足りません（必要: %dG）" % cost}
	
	if not is_gacha_unlocked(type):
		return {"success": false, "error": "このガチャはまだ解禁されていません"}
	
	# ゴールド消費
	GameData.player_data.profile.gold -= cost
	GameData.save_to_file()
	
	# カード抽選
	var card = _pull_one_typed(type)
	
	# DBに追加
	UserCardDB.add_card(card.id, 1)
	UserCardDB.flush()
	
	return {"success": true, "cards": [card]}

## ガチャを10連で引く（タイプ指定版）
func pull_multi_10_typed(type: GachaType) -> Dictionary:
	var cost = get_multi_10_cost(type)
	if not _can_afford(cost):
		return {"success": false, "error": "ゴールドが足りません（必要: %dG）" % cost}
	
	if not is_gacha_unlocked(type):
		return {"success": false, "error": "このガチャはまだ解禁されていません"}
	
	# ゴールド消費
	GameData.player_data.profile.gold -= cost
	GameData.save_to_file()
	
	# カード抽選（10回）
	var cards = []
	for i in range(10):
		var card = _pull_one_typed(type)
		cards.append(card)
		UserCardDB.add_card(card.id, 1)
	
	# DBをフラッシュ
	UserCardDB.flush()
	
	return {"success": true, "cards": cards}

## ガチャを1回引く（旧API互換）
func pull_single() -> Dictionary:
	return pull_single_typed(current_gacha_type)

## ガチャを10連で引く（旧API互換）
func pull_multi_10() -> Dictionary:
	return pull_multi_10_typed(current_gacha_type)

## 100連ガチャの価格を取得
func get_multi_100_cost(type: GachaType = current_gacha_type) -> int:
	return GACHA_COSTS[type]["multi_100"]

## ガチャを100連で引く（タイプ指定版）
func pull_multi_100_typed(type: GachaType) -> Dictionary:
	var cost = get_multi_100_cost(type)
	if not _can_afford(cost):
		return {"success": false, "error": "ゴールドが足りません（必要: %dG）" % cost}

	if not is_gacha_unlocked(type):
		return {"success": false, "error": "このガチャはまだ解禁されていません"}

	# ゴールド消費
	GameData.player_data.profile.gold -= cost
	GameData.save_to_file()

	# カード抽選（100回）
	var cards: Array[Dictionary] = []
	for i in range(100):
		var card = _pull_one_typed(type)
		cards.append(card)
		UserCardDB.add_card(card.id, 1)

	# DBをフラッシュ
	UserCardDB.flush()

	return {"success": true, "cards": cards}

## ガチャを100連で引く（旧API互換）
func pull_multi_100() -> Dictionary:
	return pull_multi_100_typed(current_gacha_type)

# ==================== 課金ガチャ ====================

## 課金ガチャ単発
func pull_premium_single(premium_type: PremiumGachaType) -> Dictionary:
	var cost: int = PREMIUM_GACHA_COSTS["single"]
	if GameData.get_stone() < cost:
		return {"success": false, "error": "ジェムが足りません（必要: %d個）" % cost}

	if not GameData.spend_stone(cost):
		return {"success": false, "error": "ジェムの消費に失敗しました"}

	var card: Dictionary = _pull_one_premium(premium_type)
	if card.is_empty():
		# 候補なし → 石を返却
		GameData.add_stone(cost)
		return {"success": false, "error": "排出対象のカードがありません"}

	UserCardDB.add_card(card.id, 1)
	UserCardDB.flush()
	return {"success": true, "cards": [card]}


## 課金ガチャ10連
func pull_premium_multi_10(premium_type: PremiumGachaType) -> Dictionary:
	var cost: int = PREMIUM_GACHA_COSTS["multi_10"]
	if GameData.get_stone() < cost:
		return {"success": false, "error": "ジェムが足りません（必要: %d個）" % cost}

	if not GameData.spend_stone(cost):
		return {"success": false, "error": "ジェムの消費に失敗しました"}

	var cards: Array[Dictionary] = []
	for i in range(10):
		var card: Dictionary = _pull_one_premium(premium_type)
		if card.is_empty():
			# 候補なし → 石を返却
			GameData.add_stone(cost)
			return {"success": false, "error": "排出対象のカードがありません"}
		cards.append(card)
		UserCardDB.add_card(card.id, 1)

	UserCardDB.flush()
	return {"success": true, "cards": cards}


## 課金ガチャ1枚抽選
func _pull_one_premium(premium_type: PremiumGachaType) -> Dictionary:
	var rarity: String = _determine_premium_rarity()
	var candidates: Array = _get_premium_cards(premium_type, rarity)

	# フォールバック: 該当レアリティがなければ別のレアリティを試す
	if candidates.is_empty():
		var fallback_rarity: String = "S" if rarity == "R" else "R"
		candidates = _get_premium_cards(premium_type, fallback_rarity)

	if candidates.is_empty():
		return {}

	var index: int = randi() % candidates.size()
	return candidates[index]


## 課金ガチャのレアリティ決定
func _determine_premium_rarity() -> String:
	var roll: float = randf() * 100.0
	var cumulative: float = 0.0
	for rarity in PREMIUM_RARITY_RATES.keys():
		cumulative += PREMIUM_RARITY_RATES[rarity]
		if roll < cumulative:
			return rarity
	return "S"


## 課金ガチャ用カード取得（属性/タイプ+レアリティでフィルター）
func _get_premium_cards(premium_type: PremiumGachaType, rarity: String) -> Array:
	var filter: Dictionary = PREMIUM_GACHA_FILTERS[premium_type]
	var target_card_type: String = filter["card_type"]
	var target_element: String = filter["element"]
	var result: Array = []

	for card in CardLoader.all_cards:
		var card_id: int = int(card.get("id", 0))
		if card_id in EXCLUDED_CARD_IDS:
			continue
		if String(card.get("rarity", "")) != rarity:
			continue

		var card_type: String = String(card.get("type", "creature"))
		if card_type.is_empty():
			card_type = "creature"
		if card_type != target_card_type:
			continue

		# 属性フィルター（クリーチャーのみ）
		if not target_element.is_empty():
			if String(card.get("element", "")) != target_element:
				continue

		result.append(card)

	return result


## 課金ガチャの価格取得
func get_premium_single_cost() -> int:
	return PREMIUM_GACHA_COSTS["single"]


func get_premium_multi_10_cost() -> int:
	return PREMIUM_GACHA_COSTS["multi_10"]


# ==================== ゴールドガチャ ====================

## 1枚抽選（タイプ指定版）
func _pull_one_typed(type: GachaType) -> Dictionary:
	# レアリティを決定
	var rarity = _determine_rarity_typed(type)
	
	# そのレアリティのカードを取得
	var candidates = _get_cards_by_rarity(rarity)
	
	if candidates.is_empty():
		# フォールバック：Cレアリティ
		candidates = _get_cards_by_rarity("C")
	
	# ランダムに1枚選択
	var index = randi() % candidates.size()
	return candidates[index]

## 1枚抽選（旧API互換）
func _pull_one() -> Dictionary:
	return _pull_one_typed(current_gacha_type)

## レアリティを確率で決定（タイプ指定版）
func _determine_rarity_typed(type: GachaType) -> String:
	var rates = RARITY_RATES[type]
	var roll = randf() * 100.0
	var cumulative = 0.0
	
	for rarity in rates.keys():
		cumulative += rates[rarity]
		if roll < cumulative:
			return rarity
	
	return "C"  # フォールバック

## レアリティを確率で決定（旧API互換）
func _determine_rarity() -> String:
	return _determine_rarity_typed(current_gacha_type)

## 指定レアリティのカードを取得（除外リストを適用）
func _get_cards_by_rarity(rarity: String) -> Array:
	var result = []

	for card in CardLoader.all_cards:
		var card_id: int = int(card.get("id", 0))
		if card_id in EXCLUDED_CARD_IDS:
			continue
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
