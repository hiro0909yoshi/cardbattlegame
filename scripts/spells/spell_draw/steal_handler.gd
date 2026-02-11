class_name StealHandler
extends RefCounted
## カード奪取・交換処理ハンドラー
##
## 担当effect_type:
## - steal_selected_card: 選択奪取（セフト）
## - steal_item_conditional: 条件付き奪取（スニークハンド）
## - swap_creature: クリーチャー交換（レムレース）


# ============================================================
# システム参照
# ============================================================

var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var board_system_ref = null
var card_selection_handler = null


# ============================================================
# 初期化
# ============================================================

func setup(card_system: CardSystem, player_system = null) -> void:
	card_system_ref = card_system
	player_system_ref = player_system


func set_board_system(board_system) -> void:
	board_system_ref = board_system


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
		"steal_selected_card":
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id >= 0 and card_selection_handler:
				var filter_mode = effect.get("filter_mode", "destroy_spell")
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, filter_mode, func(_card_index: int):
					pass
				, true)
				result["async"] = true
		
		"steal_item_conditional":
			var target_player_id = context.get("target_player_id", -1)
			if target_player_id < 0 or not card_selection_handler:
				pass
			else:
				var required_count = effect.get("required_item_count", 2)
				var item_count = count_items_in_hand(target_player_id)
				if item_count >= required_count:
					card_selection_handler.set_current_player(player_id)
					card_selection_handler.start_enemy_card_selection(target_player_id, "item", func(_card_index: int):
						pass
					, true)
					result["async"] = true
				else:
					print("[スニークハンド] 条件未達: プレイヤー%d のアイテム数 %d < 必要数 %d" % [target_player_id + 1, item_count, required_count])
					result["failed"] = true
		
		"swap_creature":
			var target_player_id = context.get("target_player_id", -1)
			var caster_tile_index = context.get("tile_index", -1)
			if target_player_id >= 0 and card_selection_handler and caster_tile_index >= 0:
				card_selection_handler.set_current_player(player_id)
				card_selection_handler.start_enemy_card_selection(target_player_id, "creature", func(_card_index: int):
					pass
				, true)
				move_caster_to_enemy_hand(caster_tile_index, target_player_id)
				result["async"] = true
		
		_:
			return {}
	
	return result


## このハンドラーが処理可能なeffect_typeか判定
func can_handle(effect_type: String) -> bool:
	return effect_type in [
		"steal_selected_card", "steal_item_conditional", "swap_creature"
	]


# ============================================================
# 奪取処理
# ============================================================

## 指定インデックスのカードを奪取
func steal_card_at_index(from_player_id: int, to_player_id: int, card_index: int) -> Dictionary:
	if not card_system_ref:
		push_error("StealHandler: CardSystemが設定されていません")
		return {"stolen": false, "card_name": "", "card_data": {}}
	
	var hand = card_system_ref.get_all_cards_for_player(from_player_id)
	
	if card_index < 0 or card_index >= hand.size():
		print("[カード奪取] 無効なインデックス: %d（手札枚数: %d）" % [card_index, hand.size()])
		return {"stolen": false, "card_name": "", "card_data": {}}
	
	var stolen_card = hand[card_index].duplicate(true)
	var card_name = stolen_card.get("name", "?")
	
	card_system_ref.player_hands[from_player_id]["data"].remove_at(card_index)
	card_system_ref.player_hands[to_player_id]["data"].append(stolen_card)
	
	print("[カード奪取] プレイヤー%d → プレイヤー%d: %s を奪取" % [from_player_id + 1, to_player_id + 1, card_name])
	
	card_system_ref.emit_signal("hand_updated")
	
	return {
		"stolen": true,
		"card_name": card_name,
		"card_data": stolen_card
	}


# ============================================================
# ヘルパーメソッド
# ============================================================

## 対象プレイヤーの手札のアイテム数をカウント
func count_items_in_hand(target_player_id: int) -> int:
	if not card_system_ref:
		return 0
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	var count = 0
	
	for card in hand:
		if card.get("type", "") == "item":
			count += 1
	
	return count


## 対象プレイヤーの手札に条件に合うカードがあるかチェック
func has_cards_matching_filter(target_player_id: int, filter_mode: String) -> bool:
	if not card_system_ref:
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	if hand.is_empty():
		return false
	
	for card in hand:
		var card_type = card.get("type", "")
		match filter_mode:
			"destroy_item_spell", "item_or_spell":
				if card_type == "item" or card_type == "spell":
					return true
			"destroy_any":
				return true
			"destroy_spell":
				if card_type == "spell":
					return true
			"item":
				if card_type == "item":
					return true
			"creature":
				if card_type == "creature":
					return true
	
	return false


## キャスタークリーチャーを土地から敵手札へ移動（レムレース用）
func move_caster_to_enemy_hand(tile_index: int, target_player_id: int) -> void:
	if not board_system_ref:
		push_error("StealHandler: board_system_refが未設定")
		return
	
	if not board_system_ref.tile_nodes.has(tile_index):
		push_error("StealHandler: タイル %d が見つかりません" % tile_index)
		return
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		push_error("StealHandler: タイル %d にクリーチャーがいません" % tile_index)
		return
	
	var creature_data = tile.creature_data.duplicate(true)
	var creature_name = creature_data.get("name", "?")
	
	tile.remove_creature()
	
	if card_system_ref:
		card_system_ref.return_card_to_hand(target_player_id, creature_data)
		print("[クリーチャー交換] 『%s』がプレイヤー%dの手札に移動" % [creature_name, target_player_id + 1])
