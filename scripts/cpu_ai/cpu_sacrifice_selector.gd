## CPU用カード犠牲選択
## スペル/クリーチャー合成時の犠牲カード選択ロジック
## 既存のSpellSynthesis/CreatureSynthesisのcheck_condition()を使用
class_name CPUSacrificeSelector
extends RefCounted


# ============ 参照 ============

var card_system: Node = null
var board_system: Node = null
var spell_synthesis: SpellSynthesis = null
var creature_synthesis: CreatureSynthesis = null
var CardRateEvaluator = preload("res://scripts/cpu_ai/card_rate_evaluator.gd")


# ============ 初期化 ============

func initialize(c_system: Node, b_system: Node = null, 
                spell_synth: SpellSynthesis = null, 
                creature_synth: CreatureSynthesis = null) -> void:
	card_system = c_system
	board_system = b_system
	spell_synthesis = spell_synth
	creature_synthesis = creature_synth


# ============ メイン選択メソッド ============

## スペル用: 犠牲カードを選択（合成条件を考慮）
## spell_card: 使用するスペル
## player_id: プレイヤーID
## should_synthesize: 合成するか（true=合成条件に合うカード優先、false=レート最低）
## 戻り値: 犠牲にするカード（見つからなければ空）
func select_sacrifice_card(spell_card: Dictionary, player_id: int, should_synthesize: bool) -> Dictionary:
	var hand = _get_hand_excluding_card(player_id, spell_card)
	if hand.is_empty():
		return {}
	
	if should_synthesize and spell_synthesis:
		# 合成条件に合うカードの中からレート最低を選択
		var valid_cards = _filter_for_spell_synthesis(hand, spell_card)
		
		if not valid_cards.is_empty():
			return CardRateEvaluator.get_lowest_rate_card(valid_cards)
	
	# 合成しない or 合成条件に合うカードがない場合、レート最低を選択
	return CardRateEvaluator.get_lowest_rate_card(hand)


## クリーチャー召喚用の犠牲カード選択
## creature_card: 召喚するクリーチャー
## player_id: プレイヤーID
## tile_element: 配置先タイルの属性（イド用）
## 戻り値: {card: 犠牲カード, should_synthesize: 合成するか}
func select_sacrifice_for_creature(creature_card: Dictionary, player_id: int, tile_element: String = "") -> Dictionary:
	var hand = _get_hand_excluding_card(player_id, creature_card)
	if hand.is_empty():
		return {"card": {}, "should_synthesize": false}
	
	var synthesis = creature_card.get("synthesis", {})
	if synthesis.is_empty():
		# 合成効果なし、レート最低を選択
		return {
			"card": CardRateEvaluator.get_lowest_rate_card(hand),
			"should_synthesize": false
		}
	
	var effect_type = synthesis.get("effect_type", "")
	
	# イド（犠牲クリーチャーに変身）の特殊処理
	if effect_type == "transform" and synthesis.get("transform_to") == "sacrifice":
		var best_creature = _select_best_creature_for_ido(hand, tile_element)
		if not best_creature.is_empty():
			return {"card": best_creature, "should_synthesize": true}
		# 条件に合うクリーチャーがなければ合成せず、レート最低
		return {
			"card": CardRateEvaluator.get_lowest_rate_card(hand),
			"should_synthesize": false
		}
	
	# 通常の合成条件チェック（CreatureSynthesis.check_condition使用）
	if creature_synthesis:
		var valid_cards = _filter_for_creature_synthesis(hand, creature_card)
		if not valid_cards.is_empty():
			return {
				"card": CardRateEvaluator.get_lowest_rate_card(valid_cards),
				"should_synthesize": true
			}
	
	# 合成条件に合うカードがない場合、レート最低
	return {
		"card": CardRateEvaluator.get_lowest_rate_card(hand),
		"should_synthesize": false
	}


# ============ フィルタリング（既存クラスのcheck_condition使用） ============

## スペル合成条件でフィルタリング
func _filter_for_spell_synthesis(cards: Array, spell_card: Dictionary) -> Array:
	var result: Array = []
	
	if not spell_synthesis:
		return result
	
	for card in cards:
		if spell_synthesis.check_condition(spell_card, card):
			result.append(card)
	
	return result


## クリーチャー合成条件でフィルタリング
func _filter_for_creature_synthesis(cards: Array, creature_card: Dictionary) -> Array:
	var result: Array = []
	
	if not creature_synthesis:
		return result
	
	for card in cards:
		if creature_synthesis.check_condition(creature_card, card):
			result.append(card)
	
	return result


# ============ イド専用処理 ============

## イド用: 土地属性に合うクリーチャーの中でレート最高を選択
func _select_best_creature_for_ido(hand: Array, tile_element: String) -> Dictionary:
	var matching_creatures: Array = []
	
	for card in hand:
		if card.get("type") != "creature":
			continue
		
		# 土地属性と一致するクリーチャー
		if card.get("element", "") == tile_element:
			matching_creatures.append(card)
	
	if matching_creatures.is_empty():
		return {}
	
	# レート最高を選択（イドは強いクリーチャーに変身したい）
	return CardRateEvaluator.get_highest_rate_card(matching_creatures)


# ============ ユーティリティ ============

## 手札から使用するカードを除外して取得
func _get_hand_excluding_card(player_id: int, exclude_card: Dictionary) -> Array:
	if not card_system:
		return []
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var result: Array = []
	var exclude_id = exclude_card.get("id", -1)
	var excluded = false
	
	for card in hand:
		if not excluded and card.get("id") == exclude_id:
			excluded = true
			continue
		result.append(card)
	
	return result


## 手札に合成条件に合うカードがあるか確認（スペル用）
func has_valid_sacrifice_for_spell(spell_card: Dictionary, player_id: int, for_synthesis: bool) -> bool:
	var hand = _get_hand_excluding_card(player_id, spell_card)
	if hand.is_empty():
		return false
	
	if not for_synthesis:
		return true  # 合成不要なら任意のカードでOK
	
	if not spell_synthesis:
		return false
	
	var valid_cards = _filter_for_spell_synthesis(hand, spell_card)
	return not valid_cards.is_empty()


## 手札に合成条件に合うカードがあるか確認（クリーチャー用）
func has_valid_sacrifice_for_creature(creature_card: Dictionary, player_id: int, for_synthesis: bool) -> bool:
	var hand = _get_hand_excluding_card(player_id, creature_card)
	if hand.is_empty():
		return false
	
	if not for_synthesis:
		return true  # 合成不要なら任意のカードでOK
	
	if not creature_synthesis:
		return false
	
	var valid_cards = _filter_for_creature_synthesis(hand, creature_card)
	return not valid_cards.is_empty()
