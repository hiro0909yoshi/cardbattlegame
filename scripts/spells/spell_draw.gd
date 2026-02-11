class_name SpellDraw
extends RefCounted
## スペルドロー処理ディスパッチャー
##
## 手札操作（ドロー、破壊、奪取など）を担当
## 各effect_typeは専用ハンドラーに委譲
##
## ハンドラー構成:
## - BasicDrawHandler: 基本ドロー（draw, draw_by_type, add_specific_card等）
## - DestroyHandler: 破壊系（destroy_curse_cards, destroy_selected_card等）
## - StealHandler: 奪取系（steal_selected_card, swap_creature等）
## - DeckHandler: デッキ操作（reset_deck, draw_from_deck_selection等）
## - ConditionHandler: 条件チェック（check_hand_elements, transform_to_card等）


# ============================================================
# Preload
# ============================================================

const BasicDrawHandlerScript = preload("res://scripts/spells/spell_draw/basic_draw_handler.gd")
const DestroyHandlerScript = preload("res://scripts/spells/spell_draw/destroy_handler.gd")
const StealHandlerScript = preload("res://scripts/spells/spell_draw/steal_handler.gd")
const DeckHandlerScript = preload("res://scripts/spells/spell_draw/deck_handler.gd")
const ConditionHandlerScript = preload("res://scripts/spells/spell_draw/condition_handler.gd")


# ============================================================
# システム参照
# ============================================================

var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var card_selection_handler: CardSelectionHandler = null
var ui_manager_ref = null
var board_system_ref = null
var spell_creature_place_ref = null


# ============================================================
# ハンドラー
# ============================================================

var _basic_draw_handler = null
var _destroy_handler = null
var _steal_handler = null
var _deck_handler = null
var _condition_handler = null


# ============================================================
# 初期化
# ============================================================

func setup(card_system: CardSystem, player_system = null) -> void:
	card_system_ref = card_system
	player_system_ref = player_system
	
	# ハンドラー初期化
	_basic_draw_handler = BasicDrawHandlerScript.new()
	_basic_draw_handler.setup(card_system, player_system)
	
	_destroy_handler = DestroyHandlerScript.new()
	_destroy_handler.setup(card_system, player_system)
	
	_steal_handler = StealHandlerScript.new()
	_steal_handler.setup(card_system, player_system)
	
	_deck_handler = DeckHandlerScript.new()
	_deck_handler.setup(card_system, player_system)
	
	_condition_handler = ConditionHandlerScript.new()
	_condition_handler.setup(card_system, player_system)


func set_board_system(board_system) -> void:
	board_system_ref = board_system
	if _basic_draw_handler:
		_basic_draw_handler.set_board_system(board_system)
	if _steal_handler:
		_steal_handler.set_board_system(board_system)


func set_ui_manager(ui_manager) -> void:
	ui_manager_ref = ui_manager
	if _basic_draw_handler:
		_basic_draw_handler.set_ui_manager(ui_manager)
	if _condition_handler:
		_condition_handler.set_ui_manager(ui_manager)


func set_card_selection_handler(handler: CardSelectionHandler) -> void:
	card_selection_handler = handler
	if _destroy_handler:
		_destroy_handler.set_card_selection_handler(handler)
	if _steal_handler:
		_steal_handler.set_card_selection_handler(handler)
	if _deck_handler:
		_deck_handler.set_card_selection_handler(handler)
	if _condition_handler:
		_condition_handler.set_card_selection_handler(handler)


func set_spell_creature_place(spell_creature_place) -> void:
	spell_creature_place_ref = spell_creature_place
	if _basic_draw_handler:
		_basic_draw_handler.set_spell_creature_place(spell_creature_place)


# ============================================================
# メイン処理
# ============================================================

## エフェクトを適用（メインエントリポイント）
func apply_effect(effect: Dictionary, player_id: int, context: Dictionary = {}) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	
	# 各ハンドラーに委譲
	if _basic_draw_handler and _basic_draw_handler.can_handle(effect_type):
		return _basic_draw_handler.apply_effect(effect, player_id, context)
	
	if _destroy_handler and _destroy_handler.can_handle(effect_type):
		return _destroy_handler.apply_effect(effect, player_id, context)
	
	if _steal_handler and _steal_handler.can_handle(effect_type):
		return _steal_handler.apply_effect(effect, player_id, context)
	
	if _deck_handler and _deck_handler.can_handle(effect_type):
		return _deck_handler.apply_effect(effect, player_id, context)
	
	if _condition_handler and _condition_handler.can_handle(effect_type):
		return _condition_handler.apply_effect(effect, player_id, context)
	
	print("[SpellDraw] 未対応の効果タイプ: ", effect_type)
	return {}


# ============================================================
# 公開API（後方互換性のため維持）
# ============================================================

# --- 基本ドロー ---

func draw_one(player_id: int) -> Dictionary:
	if _basic_draw_handler:
		return _basic_draw_handler.draw_one(player_id)
	return {}


func draw_cards(player_id: int, count: int) -> Array:
	if _basic_draw_handler:
		return _basic_draw_handler.draw_cards(player_id, count)
	return []


func draw_until(player_id: int, target_hand_size: int) -> Array:
	if _basic_draw_handler:
		return _basic_draw_handler.draw_until(player_id, target_hand_size)
	return []


func draw_card_by_type(player_id: int, card_type: String) -> Dictionary:
	if _basic_draw_handler:
		return _basic_draw_handler.draw_card_by_type(player_id, card_type)
	return {"drawn": false, "card_name": "", "card_data": {}}


func draw_by_rank(player_id: int, rank: int) -> Array:
	if _basic_draw_handler:
		return _basic_draw_handler.draw_by_rank(player_id, rank)
	return []


func discard_and_draw_plus(player_id: int) -> Array:
	if _basic_draw_handler:
		return _basic_draw_handler.discard_and_draw_plus(player_id)
	return []


func exchange_all_hand(player_id: int) -> Array:
	if _basic_draw_handler:
		return _basic_draw_handler.exchange_all_hand(player_id)
	return []


func add_specific_card_to_hand(player_id: int, card_id: int) -> Dictionary:
	if _basic_draw_handler:
		return _basic_draw_handler.add_specific_card_to_hand(player_id, card_id)
	return {"success": false, "card_name": ""}


# --- 破壊系 ---

func destroy_curse_cards() -> Dictionary:
	if _destroy_handler:
		return _destroy_handler.destroy_curse_cards()
	return {"total_destroyed": 0, "by_player": []}


func destroy_expensive_cards(cost_threshold: int) -> Dictionary:
	if _destroy_handler:
		return _destroy_handler.destroy_expensive_cards(cost_threshold)
	return {"total_destroyed": 0, "by_player": []}


func destroy_duplicate_cards(target_player_id: int) -> Dictionary:
	if _destroy_handler:
		return _destroy_handler.destroy_duplicate_cards(target_player_id)
	return {"total_destroyed": 0, "duplicates": []}


func destroy_duplicate_cards_all_players() -> Dictionary:
	if _destroy_handler:
		return _destroy_handler.destroy_duplicate_cards_all_players()
	return {"total_destroyed": 0, "by_player": []}


func destroy_card_at_index(target_player_id: int, card_index: int) -> Dictionary:
	if _destroy_handler:
		return _destroy_handler.destroy_card_at_index(target_player_id, card_index)
	return {"destroyed": false, "card_name": "", "card_data": {}}


func destroy_deck_card_at_index(player_id: int, card_index: int) -> Dictionary:
	if _destroy_handler:
		return _destroy_handler.destroy_deck_card_at_index(player_id, card_index)
	return {"destroyed": false, "card_name": "", "card_data": {}}


func is_curse_card(card: Dictionary) -> bool:
	if _destroy_handler:
		return _destroy_handler.is_curse_card(card)
	return false


# --- 奪取系 ---

func steal_card_at_index(from_player_id: int, to_player_id: int, card_index: int) -> Dictionary:
	if _steal_handler:
		return _steal_handler.steal_card_at_index(from_player_id, to_player_id, card_index)
	return {"stolen": false, "card_name": "", "card_data": {}}


func count_items_in_hand(target_player_id: int) -> int:
	if _steal_handler:
		return _steal_handler.count_items_in_hand(target_player_id)
	return 0


func has_cards_matching_filter(target_player_id: int, filter_mode: String) -> bool:
	if _steal_handler:
		return _steal_handler.has_cards_matching_filter(target_player_id, filter_mode)
	return false


# --- デッキ操作 ---

func get_top_cards_from_deck(player_id: int, count: int) -> Array:
	if _deck_handler:
		return _deck_handler.get_top_cards_from_deck(player_id, count)
	return []


func draw_from_deck_at_index(player_id: int, card_index: int) -> Dictionary:
	if _deck_handler:
		return _deck_handler.draw_from_deck_at_index(player_id, card_index)
	return {"drawn": false, "card_name": "", "card_data": {}}


func reset_deck_to_original(target_player_id: int) -> Dictionary:
	if _deck_handler:
		return _deck_handler.reset_deck_to_original(target_player_id)
	return {"success": false, "new_deck_size": 0, "player_name": ""}


# --- 条件チェック ---

func get_hand_creature_elements(player_id: int) -> Array:
	if _condition_handler:
		return _condition_handler.get_hand_creature_elements(player_id)
	return []


func has_all_elements(player_id: int, required_elements: Array) -> bool:
	if _condition_handler:
		return _condition_handler.has_all_elements(player_id, required_elements)
	return false


func has_item_or_spell_in_hand(target_player_id: int) -> bool:
	if _condition_handler:
		return _condition_handler.has_item_or_spell_in_hand(target_player_id)
	return false


func transform_cards_to_specific(target_player_id: int, selected_card_name: String, selected_card_id: int, transform_to_id: int) -> Dictionary:
	if _condition_handler:
		return _condition_handler.transform_cards_to_specific(target_player_id, selected_card_name, selected_card_id, transform_to_id)
	return {"transformed_count": 0, "hand_count": 0, "deck_count": 0, "original_name": "", "new_name": ""}


# --- 内部参照用（レムレース用） ---

func _move_caster_to_enemy_hand(tile_index: int, target_player_id: int) -> void:
	if _steal_handler:
		_steal_handler.move_caster_to_enemy_hand(tile_index, target_player_id)
