class_name ConditionHandler
extends RefCounted
## 条件チェック・変換処理ハンドラー
##
## 担当effect_type:
## - check_hand_elements: 手札属性チェック（アセンブルカード/密命）
## - check_hand_synthesis: 合成カードチェック（フィロソフィー）
## - transform_to_card: カード変換（メタモルフォシス）


# ============================================================
# システム参照
# ============================================================

var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var card_selection_handler = null
var _card_selection_service = null


# ============================================================
# 初期化
# ============================================================

func setup(card_system: CardSystem, player_system = null) -> void:
	card_system_ref = card_system
	player_system_ref = player_system


func inject_services(card_selection_service) -> void:
	_card_selection_service = card_selection_service


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
		"check_hand_elements":
			var required_elements = effect.get("required_elements", ["fire", "water", "wind", "earth"])
			var success_effect = effect.get("success_effect", {})
			var fail_effect = effect.get("fail_effect", {})
			
			var hand_elements = get_hand_creature_elements(player_id)
			var has_all = has_all_elements(player_id, required_elements)
			
			if has_all:
				print("[密命成功] 手札に4属性あり: %s" % str(hand_elements))
				result["next_effect"] = success_effect
			else:
				print("[密命失敗] 手札の属性: %s（必要: %s）" % [str(hand_elements), str(required_elements)])
				result["next_effect"] = fail_effect
		
		"check_hand_synthesis":
			var success_effect = effect.get("success_effect", {})
			var fail_effect = effect.get("fail_effect", {})
			
			var has_synthesis = _has_synthesis_card_in_hand(player_id)
			if has_synthesis:
				print("[フィロソフィー] 合成持ちカードあり")
				result["next_effect"] = success_effect
			else:
				print("[フィロソフィー] 合成持ちカードなし")
				result["next_effect"] = fail_effect
		
		"transform_to_card":
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var transform_to_id = effect.get("transform_to_id", -1)
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_transform_card_selection(target_player_id, "item_or_spell", transform_to_id)
				result["async"] = true
		
		_:
			return {}
	
	return result


## このハンドラーが処理可能なeffect_typeか判定
func can_handle(effect_type: String) -> bool:
	return effect_type in [
		"check_hand_elements", "check_hand_synthesis", "transform_to_card"
	]


# ============================================================
# 属性チェック
# ============================================================

## 手札のクリーチャー属性を取得
func get_hand_creature_elements(player_id: int) -> Array:
	var elements = []
	if not card_system_ref:
		return elements
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	for card in hand:
		if card.get("type", "") == "creature":
			var elem = card.get("element", "")
			if elem != "" and elem not in elements:
				elements.append(elem)
	
	return elements


## 手札に指定属性が全てあるかチェック
func has_all_elements(player_id: int, required_elements: Array) -> bool:
	var hand_elements = get_hand_creature_elements(player_id)
	
	for elem in required_elements:
		if elem not in hand_elements:
			return false
	
	return true


# ============================================================
# 合成チェック
# ============================================================

## 手札に合成を持つカードがあるかチェック（フィロソフィー用）
func _has_synthesis_card_in_hand(player_id: int) -> bool:
	if not card_system_ref:
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	var synthesis_creature_ids = CreatureSynthesis.get_synthesis_creature_ids()
	var synthesis_spell_ids = SpellSynthesis.get_synthesis_spell_ids()
	
	for card in hand:
		var card_id = card.get("id", -1)
		var card_type = card.get("type", "")
		
		if card_type == "creature" and card_id in synthesis_creature_ids:
			print("[フィロソフィー] 合成カード発見（クリーチャー）: %s" % card.get("name", "?"))
			return true
		
		if card_type == "spell" and card_id in synthesis_spell_ids:
			print("[フィロソフィー] 合成カード発見（スペル）: %s" % card.get("name", "?"))
			return true
	
	return false


# ============================================================
# カード変換
# ============================================================

## 同名カードを全て特定カードに変換（メタモルフォシス用）
func transform_cards_to_specific(target_player_id: int, selected_card_name: String, selected_card_id: int, transform_to_id: int) -> Dictionary:
	if not card_system_ref:
		push_error("ConditionHandler: CardSystemが設定されていません")
		return {"transformed_count": 0, "hand_count": 0, "deck_count": 0, "original_name": "", "new_name": ""}
	
	var new_card_data = CardLoader.get_card_by_id(transform_to_id)
	if new_card_data.is_empty():
		push_error("ConditionHandler: 変換先カードID %d が見つかりません" % transform_to_id)
		return {"transformed_count": 0, "hand_count": 0, "deck_count": 0, "original_name": selected_card_name, "new_name": ""}
	
	var new_card_name = new_card_data.get("name", "?")
	var hand_count = 0
	var deck_count = 0
	
	var hand = card_system_ref.player_hands[target_player_id]["data"]
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("name", "") == selected_card_name:
			hand[i] = new_card_data.duplicate(true)
			hand_count += 1
			print("[メタモルフォシス] 手札: 『%s』→『%s』に変換" % [selected_card_name, new_card_name])
	
	var deck = card_system_ref.player_decks.get(target_player_id, [])
	for i in range(deck.size()):
		if deck[i] == selected_card_id:
			card_system_ref.player_decks[target_player_id][i] = transform_to_id
			deck_count += 1
			print("[メタモルフォシス] デッキ: 『%s』→『%s』に変換" % [selected_card_name, new_card_name])
	
	var total_count = hand_count + deck_count
	print("[メタモルフォシス] プレイヤー%d: 合計 %d 枚を『%s』に変換（手札: %d, デッキ: %d）" % [target_player_id + 1, total_count, new_card_name, hand_count, deck_count])
	
	card_system_ref.emit_signal("hand_updated")
	
	if _card_selection_service:
		_card_selection_service.update_hand_display(target_player_id)
	
	return {
		"transformed_count": total_count,
		"hand_count": hand_count,
		"deck_count": deck_count,
		"original_name": selected_card_name,
		"new_name": new_card_name
	}


## 手札にアイテムまたはスペルがあるかチェック
func has_item_or_spell_in_hand(target_player_id: int) -> bool:
	if not card_system_ref:
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	for card in hand:
		var card_type = card.get("type", "")
		if card_type == "item" or card_type == "spell":
			return true
	
	return false
