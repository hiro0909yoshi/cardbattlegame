## ガチャシステム
extends Node

# ガチャタイプ
enum GachaType { NORMAL, S_GACHA, R_GACHA }

# 排出確率（タイプ別）
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

# ガチャ価格（タイプ別）
const GACHA_COSTS = {
	GachaType.NORMAL: { "single": 50, "multi_10": 500 },
	GachaType.S_GACHA: { "single": 80, "multi_10": 800 },
	GachaType.R_GACHA: { "single": 100, "multi_10": 1000 }
}

# 解禁条件（ステージID文字列）
const UNLOCK_CONDITIONS = {
	GachaType.NORMAL: "",            # 最初から解禁
	GachaType.S_GACHA: "stage_1_8",  # 1-8クリアで解禁
	GachaType.R_GACHA: "stage_2_8"   # 2-8クリアで解禁
}

# 旧API互換用
const SINGLE_COST = 100
const MULTI_10_COST = 1000
const MULTI_10_COUNT = 10
const MULTI_100_COST = 10000
const MULTI_100_COUNT = 100

# 現在選択中のガチャタイプ
var current_gacha_type: GachaType = GachaType.NORMAL

## ガチャタイプを設定
func set_gacha_type(type: GachaType) -> void:
	current_gacha_type = type

## ガチャタイプを取得
func get_gacha_type() -> GachaType:
	return current_gacha_type

## ガチャが解禁されているか確認
func is_gacha_unlocked(type: GachaType) -> bool:
	var required_stage = UNLOCK_CONDITIONS.get(type, "")
	if required_stage.is_empty():
		return true  # 条件なし = 最初から解禁
	
	# StageRecordManager経由でクリア状況を確認
	return StageRecordManager.is_cleared(required_stage)

## 指定ステージクリアで新たに解禁されるガチャタイプを取得
## 戻り値: 解禁されたガチャタイプ名の配列
static func get_newly_unlocked_gacha_types(stage_id: String) -> Array:
	var unlocked = []
	for type in UNLOCK_CONDITIONS:
		if UNLOCK_CONDITIONS[type] == stage_id:
			var type_names = {
				GachaType.NORMAL: "ノーマルガチャ",
				GachaType.S_GACHA: "Sガチャ",
				GachaType.R_GACHA: "Rガチャ"
			}
			unlocked.append(type_names.get(type, ""))
	return unlocked

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

## ガチャを100連で引く（旧API互換）
func pull_multi_100() -> Dictionary:
	if not _can_afford(MULTI_100_COST):
		return {"success": false, "error": "ゴールドが足りません"}
	
	# ゴールド消費
	GameData.player_data.profile.gold -= MULTI_100_COST
	GameData.save_to_file()
	
	# カード抽選（100回）
	var cards = []
	for i in range(MULTI_100_COUNT):
		var card = _pull_one_typed(current_gacha_type)
		cards.append(card)
		UserCardDB.add_card(card.id, 1)
	
	# DBをフラッシュ
	UserCardDB.flush()
	
	return {"success": true, "cards": cards}

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
