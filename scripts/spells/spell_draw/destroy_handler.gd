class_name DestroyHandler
extends RefCounted
## カード破壊処理ハンドラー
##
## 担当effect_type:
## - destroy_curse_cards: 全プレイヤーの呪いカード破壊（レイオブパージ）
## - destroy_expensive_cards: 全プレイヤーの高コストカード破壊（レイオブロウ）
## - destroy_duplicate_cards: 重複カード破壊（エロージョン）
## - destroy_selected_card: 選択破壊（シャッター、スクイーズ）
## - destroy_and_draw: 破壊＋ドロー（クラウドギズモ）
## - destroy_deck_top: デッキ上部破壊（コアトリクエ秘術）


# ============================================================
# システム参照
# ============================================================

var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var card_selection_handler = null


# ============================================================
# 定数
# ============================================================

const CURSE_SPELL_TYPES = [
	"複数特殊能力付与",
	"世界呪い",
	"単体特殊能力付与"
]


# ============================================================
# 初期化
# ============================================================

func setup(card_system: CardSystem, player_system = null) -> void:
	card_system_ref = card_system
	player_system_ref = player_system


func set_card_selection_handler(handler) -> void:
	card_selection_handler = handler


# ============================================================
# メイン処理
# ============================================================

## effect_typeに応じた処理を実行
func apply_effect(effect: Dictionary, player_id: int, context: Dictionary = {}) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	var result = {}
	
	match effect_type:
		"destroy_curse_cards":
			result = destroy_curse_cards()
		
		"destroy_expensive_cards":
			var cost_threshold = effect.get("cost_threshold", 100)
			result = destroy_expensive_cards(cost_threshold)
		
		"destroy_duplicate_cards":
			var all_players = effect.get("all_players", false)
			if all_players:
				result = destroy_duplicate_cards_all_players()
			else:
				var target_player_id = context.get("target_player_id", player_id)
				result = destroy_duplicate_cards(target_player_id)
		
		"destroy_selected_card":
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var filter_mode = effect.get("filter_mode", "destroy_any")
				var magic_bonus = effect.get("magic_bonus", 0)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, filter_mode, func(card_index: int):
					if card_index >= 0 and magic_bonus > 0:
						if player_system_ref and target_player_id < player_system_ref.players.size():
							player_system_ref.players[target_player_id].magic_power += magic_bonus
							print("[スクイーズ] プレイヤー%d: G%d を獲得" % [target_player_id + 1, magic_bonus])
				)
				result["async"] = true
		
		"destroy_and_draw":
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, "destroy_any", func(_card_index: int):
					_draw_cards_for_player(target_player_id, 1)
				)
				result["async"] = true
		
		"destroy_deck_top":
			var target_player_id = context.get("target_player_id", -1)
			var count = effect.get("count", 1)
			if target_player_id >= 0:
				for i in range(count):
					var destroy_result = destroy_deck_card_at_index(target_player_id, 0)
					if destroy_result.get("destroyed", false):
						result["destroyed"] = true
						result["card_name"] = destroy_result.get("card_name", "")
					else:
						break
		
		_:
			return {}
	
	return result


## このハンドラーが処理可能なeffect_typeか判定
func can_handle(effect_type: String) -> bool:
	return effect_type in [
		"destroy_curse_cards", "destroy_expensive_cards", "destroy_duplicate_cards",
		"destroy_selected_card", "destroy_and_draw", "destroy_deck_top"
	]


# ============================================================
# 破壊処理
# ============================================================

## 呪いカードかどうか判定
func is_curse_card(card: Dictionary) -> bool:
	if card.get("type") != "spell":
		return false
	return card.get("spell_type", "") in CURSE_SPELL_TYPES


## 全プレイヤーの手札から呪いカードを破壊
func destroy_curse_cards() -> Dictionary:
	if not card_system_ref:
		push_error("DestroyHandler: CardSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	for player_id in range(4):
		var destroyed_count = 0
		var hand = card_system_ref.get_all_cards_for_player(player_id)
		
		for i in range(hand.size() - 1, -1, -1):
			var card = hand[i]
			if is_curse_card(card):
				card_system_ref.discard_card(player_id, i, "destroy")
				print("[呪いカード破壊] プレイヤー%d: %s" % [player_id + 1, card.get("name", "?")])
				destroyed_count += 1
		
		by_player.append(destroyed_count)
		total_destroyed += destroyed_count
	
	print("[レイオブパージ] 合計 %d 枚の呪いカードを破壊" % total_destroyed)
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}


## 全プレイヤーの手札から高コストカードを破壊
func destroy_expensive_cards(cost_threshold: int) -> Dictionary:
	if not card_system_ref:
		push_error("DestroyHandler: CardSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	for player_id in range(4):
		var destroyed_count = 0
		var hand = card_system_ref.get_all_cards_for_player(player_id)
		
		for i in range(hand.size() - 1, -1, -1):
			var card = hand[i]
			var cost_data = card.get("cost", 0)
			var card_cost = 0
			if cost_data is Dictionary:
				card_cost = cost_data.get("mp", 0)
			else:
				card_cost = cost_data
			
			if card_cost >= cost_threshold:
				card_system_ref.discard_card(player_id, i, "destroy")
				print("[高コストカード破壊] プレイヤー%d: %s (G%d)" % [player_id + 1, card.get("name", "?"), card_cost])
				destroyed_count += 1
		
		by_player.append(destroyed_count)
		total_destroyed += destroyed_count
	
	print("[レイオブロウ] 合計 %d 枚のG%d以上カードを破壊" % [total_destroyed, cost_threshold])
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}


## 対象プレイヤーの手札から重複カードを破壊
func destroy_duplicate_cards(target_player_id: int) -> Dictionary:
	if not card_system_ref:
		push_error("DestroyHandler: CardSystemが設定されていません")
		return {"total_destroyed": 0, "duplicates": []}
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	var name_count = {}
	for card in hand:
		var card_name = card.get("name", "")
		if card_name != "":
			name_count[card_name] = name_count.get(card_name, 0) + 1
	
	var duplicate_names = []
	for card_name in name_count.keys():
		if name_count[card_name] >= 2:
			duplicate_names.append(card_name)
	
	if duplicate_names.is_empty():
		print("[エロージョン] プレイヤー%d: 重複カードなし" % [target_player_id + 1])
		return {"total_destroyed": 0, "duplicates": []}
	
	var destroyed_count = 0
	for i in range(hand.size() - 1, -1, -1):
		var card = hand[i]
		var card_name = card.get("name", "")
		if card_name in duplicate_names:
			card_system_ref.discard_card(target_player_id, i, "destroy")
			print("[重複カード破壊] プレイヤー%d: %s" % [target_player_id + 1, card_name])
			destroyed_count += 1
	
	print("[エロージョン] プレイヤー%d: %d 枚の重複カードを破壊（%s）" % [target_player_id + 1, destroyed_count, str(duplicate_names)])
	
	return {
		"total_destroyed": destroyed_count,
		"duplicates": duplicate_names
	}


## 全プレイヤーの重複カードを破壊（エロージョン合成用）
func destroy_duplicate_cards_all_players() -> Dictionary:
	if not player_system_ref:
		push_error("DestroyHandler: PlayerSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	for player_id in range(player_system_ref.players.size()):
		var result = destroy_duplicate_cards(player_id)
		total_destroyed += result.get("total_destroyed", 0)
		by_player.append({
			"player_id": player_id,
			"destroyed": result.get("total_destroyed", 0),
			"duplicates": result.get("duplicates", [])
		})
	
	print("[エロージョン合成] 全プレイヤーから合計 %d 枚の重複カードを破壊" % total_destroyed)
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}


## 指定インデックスのカードを破壊
func destroy_card_at_index(target_player_id: int, card_index: int) -> Dictionary:
	if not card_system_ref:
		push_error("DestroyHandler: CardSystemが設定されていません")
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	if card_index < 0 or card_index >= hand.size():
		print("[手札破壊] 無効なインデックス: %d（手札枚数: %d）" % [card_index, hand.size()])
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	var destroyed_card = hand[card_index]
	var card_name = destroyed_card.get("name", "?")
	
	card_system_ref.discard_card(target_player_id, card_index, "destroy")
	print("[手札破壊] プレイヤー%d: %s を破壊" % [target_player_id + 1, card_name])
	
	return {
		"destroyed": true,
		"card_name": card_name,
		"card_data": destroyed_card
	}


## デッキ上部の指定インデックスのカードを破壊
func destroy_deck_card_at_index(player_id: int, card_index: int) -> Dictionary:
	if not card_system_ref:
		push_error("DestroyHandler: CardSystemが設定されていません")
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	
	if card_index < 0 or card_index >= deck.size():
		print("[デッキ破壊] 無効なインデックス: %d（デッキ枚数: %d）" % [card_index, deck.size()])
		return {"destroyed": false, "card_name": "", "card_data": {}}
	
	var card_id = deck[card_index]
	var destroyed_card = CardLoader.get_card_by_id(card_id)
	var card_name = destroyed_card.get("name", "?") if destroyed_card else "?"
	
	card_system_ref.player_decks[player_id].remove_at(card_index)
	print("[デッキ破壊] プレイヤー%d: インデックス%d の %s をデッキから破壊" % [player_id + 1, card_index, card_name])
	
	var remaining_deck = card_system_ref.player_decks[player_id]
	var show_count = min(3, remaining_deck.size())
	print("[デッキ破壊後] 次にドローされる%d枚:" % show_count)
	for i in range(show_count):
		var next_card_id = remaining_deck[i]
		var next_card = CardLoader.get_card_by_id(next_card_id)
		print("  [%d] %s" % [i, next_card.get("name", "?") if next_card else "?"])
	
	return {
		"destroyed": true,
		"card_name": card_name,
		"card_data": destroyed_card if destroyed_card else {}
	}


# ============================================================
# ヘルパー（destroy_and_draw用）
# ============================================================

## ドロー処理（コールバック用）
func _draw_cards_for_player(player_id: int, count: int) -> void:
	if card_system_ref:
		card_system_ref.draw_cards_for_player(player_id, count)
