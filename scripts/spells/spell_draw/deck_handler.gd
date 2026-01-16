class_name DeckHandler
extends RefCounted
## デッキ操作処理ハンドラー
##
## 担当effect_type:
## - destroy_from_deck_selection: デッキから選択破壊（ポイズンマインド）
## - draw_from_deck_selection: デッキから選択ドロー（フォーサイト）
## - reset_deck: デッキ初期化（リバイバル）


# ============================================================
# システム参照
# ============================================================

var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var card_selection_handler = null


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
		"destroy_from_deck_selection":
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var look_count = effect.get("look_count", 6)
				var draw_after = effect.get("draw_after", 0)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_deck_card_selection(target_player_id, look_count, func(_card_index: int):
					if draw_after > 0:
						_draw_cards_for_player(player_id, draw_after)
				)
				result["async"] = true
		
		"draw_from_deck_selection":
			if card_selection_handler:
				var look_count = effect.get("look_count", 6)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_deck_draw_selection(player_id, look_count, func(_card_index: int):
					pass
				)
				result["async"] = true
		
		"reset_deck":
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0:
				result = reset_deck_to_original(target_player_id)
		
		_:
			return {}
	
	return result


## このハンドラーが処理可能なeffect_typeか判定
func can_handle(effect_type: String) -> bool:
	return effect_type in [
		"destroy_from_deck_selection", "draw_from_deck_selection", "reset_deck"
	]


# ============================================================
# デッキ操作
# ============================================================

## デッキ上部のカードを取得（破壊はしない）
func get_top_cards_from_deck(player_id: int, count: int) -> Array:
	if not card_system_ref:
		return []
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	if deck.is_empty():
		return []
	
	var actual_count = min(count, deck.size())
	var result = []
	
	var RateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
	print("[デッキ確認] プレイヤー%d のデッキ上部%d枚:" % [player_id + 1, actual_count])
	for i in range(actual_count):
		var card_id = deck[i]
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data and not card_data.is_empty():
			var data_copy = card_data.duplicate(true)
			result.append(data_copy)
			var rate = RateEvaluator.get_rate(card_data)
			print("  [%d] %s (ID: %d, レート: %d)" % [i, card_data.get("name", "?"), card_id, rate])
	
	return result


## デッキ上部の指定インデックスのカードを手札に加える（フォーサイト用）
func draw_from_deck_at_index(player_id: int, card_index: int) -> Dictionary:
	if not card_system_ref:
		push_error("DeckHandler: CardSystemが設定されていません")
		return {"drawn": false, "card_name": "", "card_data": {}}
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	
	if card_index < 0 or card_index >= deck.size():
		print("[デッキドロー] 無効なインデックス: %d（デッキ枚数: %d）" % [card_index, deck.size()])
		return {"drawn": false, "card_name": "", "card_data": {}}
	
	var card_id = deck[card_index]
	var drawn_card = CardLoader.get_card_by_id(card_id)
	var card_name = drawn_card.get("name", "?") if drawn_card else "?"
	
	card_system_ref.player_decks[player_id].remove_at(card_index)
	
	if drawn_card:
		card_system_ref.return_card_to_hand(player_id, drawn_card.duplicate(true))
		print("[フォーサイト] プレイヤー%d: デッキから『%s』を選んで引きました" % [player_id + 1, card_name])
	
	return {
		"drawn": true,
		"card_name": card_name,
		"card_data": drawn_card if drawn_card else {}
	}


## デッキを元の構成で再構築（リバイバル用）
func reset_deck_to_original(target_player_id: int) -> Dictionary:
	if not card_system_ref:
		push_error("DeckHandler: CardSystemが設定されていません")
		return {"success": false, "new_deck_size": 0, "player_name": ""}
	
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system_ref and target_player_id < player_system_ref.players.size():
		player_name = player_system_ref.players[target_player_id].name
	
	var original_deck_data = _get_original_deck_data(target_player_id)
	if original_deck_data.is_empty():
		print("[リバイバル] プレイヤー%d: 元のデッキデータが取得できません" % [target_player_id + 1])
		return {"success": false, "new_deck_size": 0, "player_name": player_name}
	
	card_system_ref.player_decks[target_player_id].clear()
	
	for card_id in original_deck_data.keys():
		var count = original_deck_data[card_id]
		for i in range(count):
			card_system_ref.player_decks[target_player_id].append(card_id)
	
	card_system_ref.player_decks[target_player_id].shuffle()
	
	var new_deck_size = card_system_ref.player_decks[target_player_id].size()
	print("[リバイバル] %s: デッキを初期化（%d枚）" % [player_name, new_deck_size])
	
	return {
		"success": true,
		"new_deck_size": new_deck_size,
		"player_name": player_name
	}


## 元のデッキデータを取得（プレイヤーIDに応じて）
func _get_original_deck_data(player_id: int) -> Dictionary:
	if player_id == 0 or player_id == 1:
		return GameData.get_current_deck().get("cards", {})
	
	var default_deck = {}
	for card_id in range(1, 13):
		default_deck[card_id] = 3
	return default_deck


# ============================================================
# ヘルパー
# ============================================================

## ドロー処理（コールバック用）
func _draw_cards_for_player(player_id: int, count: int) -> void:
	if card_system_ref:
		card_system_ref.draw_cards_for_player(player_id, count)
