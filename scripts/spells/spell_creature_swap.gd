# SpellCreatureSwap - クリーチャー交換スペル
class_name SpellCreatureSwap

# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var card_system_ref: Object
var spell_phase_handler_ref: Object


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, card_sys: Object, spell_phase_handler: Object = null) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler


# ============ メイン効果適用 ============

## 効果を適用（effect_typeに応じて分岐）
func apply_effect(effect: Dictionary, target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"swap_with_hand":
			# エクスチェンジ: 盤面クリーチャーと手札クリーチャーを交換
			return await _apply_swap_with_hand(target_data, caster_player_id)
		"swap_board_creatures":
			# リリーフ: 盤面上の2体のクリーチャーを交換
			return await _apply_swap_board_creatures(target_data, caster_player_id)
		_:
			push_error("[SpellCreatureSwap] 未対応のeffect_type: %s" % effect_type)
			return {"success": false, "reason": "unknown_effect_type"}


# ============ 交換効果実装 ============

## 盤面クリーチャーと手札クリーチャーを交換（エクスチェンジ）
func _apply_swap_with_hand(target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var tile_index = target_data.get("tile_index", -1)
	if tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if not tile or tile.creature_data.is_empty():
		return {"success": false, "reason": "no_creature"}
	
	# 手札からクリーチャーを選択
	var hand_creatures = _get_hand_creatures(caster_player_id)
	if hand_creatures.is_empty():
		return {"success": false, "reason": "no_hand_creature", "return_to_deck": true}
	
	# 手札クリーチャー選択UI
	var selected_hand_index = await _select_hand_creature(hand_creatures, "交換するクリーチャーを選択")
	if selected_hand_index == -1:
		return {"success": false, "reason": "cancelled"}
	
	var hand_creature = hand_creatures[selected_hand_index]
	
	# 交換実行
	_execute_swap_with_hand(tile_index, caster_player_id, hand_creature)
	
	return {
		"success": true,
		"tile_index": tile_index,
		"hand_creature": hand_creature.get("name", "クリーチャー")
	}


## 盤面上の2体のクリーチャーを交換（リリーフ）
func _apply_swap_board_creatures(target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var tile_index_1 = target_data.get("tile_index", -1)  # 最初に選択されたクリーチャー
	var tile_index_2 = target_data.get("tile_index_2", -1)
	
	# 1体目が選択されていない場合
	if tile_index_1 == -1:
		var own_creatures = _get_own_creature_tiles(caster_player_id)
		if own_creatures.size() < 2:
			return {"success": false, "reason": "not_enough_creatures", "return_to_deck": true}
		
		# 1体目選択
		tile_index_1 = await _select_tile(own_creatures, "交換する1体目を選択")
		if tile_index_1 == -1:
			return {"success": false, "reason": "cancelled"}
	
	# 2体目選択
	if tile_index_2 == -1:
		var own_creatures = _get_own_creature_tiles(caster_player_id)
		var remaining = own_creatures.filter(func(t): return t != tile_index_1)
		
		if remaining.is_empty():
			return {"success": false, "reason": "not_enough_creatures", "return_to_deck": true}
		
		tile_index_2 = await _select_tile(remaining, "交換する2体目を選択")
		if tile_index_2 == -1:
			return {"success": false, "reason": "cancelled"}
	
	# 交換実行
	_execute_swap_board(tile_index_1, tile_index_2)
	
	return {
		"success": true,
		"tile_1": tile_index_1,
		"tile_2": tile_index_2
	}


# ============ 交換実行 ============

## 盤面クリーチャーと手札クリーチャーを交換
func _execute_swap_with_hand(tile_index: int, player_id: int, hand_creature: Dictionary) -> void:
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if not tile:
		return
	
	# 盤面のクリーチャーを取得
	var board_creature = tile.creature_data.duplicate()
	var board_creature_name = board_creature.get("name", "クリーチャー")
	var hand_creature_name = hand_creature.get("name", "クリーチャー")
	
	# 手札からクリーチャーを削除
	if card_system_ref and card_system_ref.has_method("remove_card_from_hand"):
		card_system_ref.remove_card_from_hand(player_id, hand_creature)
	
	# 盤面のクリーチャーを手札に戻す
	if card_system_ref and card_system_ref.has_method("add_card_to_hand"):
		card_system_ref.add_card_to_hand(player_id, board_creature)
	
	# 手札のクリーチャーを盤面に配置
	tile.creature_data = hand_creature.duplicate()
	
	# HPをリセット（新しいクリーチャーなので）
	var base_hp = hand_creature.get("hp", 0)
	tile.creature_data["current_hp"] = base_hp
	
	# ダウン状態にする
	if tile.has_method("set_down_state"):
		tile.set_down_state(true)
	
	# 表示更新
	if tile.has_method("update_display"):
		tile.update_display()
	
	print("[SpellCreatureSwap] %s ↔ %s を交換" % [board_creature_name, hand_creature_name])


## 盤面上の2体のクリーチャーを交換
func _execute_swap_board(tile_index_1: int, tile_index_2: int) -> void:
	var tile_1 = board_system_ref.tile_nodes.get(tile_index_1)
	var tile_2 = board_system_ref.tile_nodes.get(tile_index_2)
	
	if not tile_1 or not tile_2:
		push_error("[SpellCreatureSwap] 交換対象のタイルが無効です")
		return
	
	# クリーチャーデータを交換
	var creature_1 = tile_1.creature_data.duplicate() if tile_1.creature_data else {}
	var creature_2 = tile_2.creature_data.duplicate() if tile_2.creature_data else {}
	
	tile_1.creature_data = creature_2
	tile_2.creature_data = creature_1
	
	# owner_idも交換
	var owner_1 = tile_1.owner_id
	var owner_2 = tile_2.owner_id
	tile_1.owner_id = owner_2
	tile_2.owner_id = owner_1
	
	# ダウン状態にする（両方）
	if tile_1.has_method("set_down_state"):
		tile_1.set_down_state(true)
	if tile_2.has_method("set_down_state"):
		tile_2.set_down_state(true)
	
	# 表示更新
	if tile_1.has_method("update_display"):
		tile_1.update_display()
	if tile_2.has_method("update_display"):
		tile_2.update_display()
	
	var name_1 = creature_1.get("name", "クリーチャー")
	var name_2 = creature_2.get("name", "クリーチャー")
	print("[SpellCreatureSwap] %s ↔ %s を交換" % [name_1, name_2])


# ============ ユーティリティ ============

## プレイヤーの手札からクリーチャーを取得
func _get_hand_creatures(player_id: int) -> Array:
	var creatures: Array = []
	
	if not card_system_ref:
		return creatures
	
	var hand = card_system_ref.get_hand(player_id)
	for card in hand:
		if card.get("type") == "creature":
			creatures.append(card)
	
	return creatures


## プレイヤーの自クリーチャーがいるタイル一覧を取得
func _get_own_creature_tiles(player_id: int) -> Array:
	var tiles: Array = []
	
	var player_tiles = board_system_ref.get_player_tiles(player_id)
	for tile in player_tiles:
		if tile and not tile.creature_data.is_empty():
			tiles.append(tile.tile_index)
	
	return tiles


## タイル選択UI
func _select_tile(tile_indices: Array, message: String) -> int:
	if spell_phase_handler_ref and spell_phase_handler_ref.has_method("select_tile_from_list"):
		return await spell_phase_handler_ref.select_tile_from_list(tile_indices, message)
	
	# フォールバック
	print("[SpellCreatureSwap] UI選択なし、最初の候補を使用: %s" % message)
	return tile_indices[0] if tile_indices.size() > 0 else -1


## 手札クリーチャー選択UI
func _select_hand_creature(creatures: Array, message: String) -> int:
	# TODO: 手札選択UIを実装
	# 現在はフォールバックとして最初のクリーチャーを選択
	if spell_phase_handler_ref and spell_phase_handler_ref.has_method("select_hand_card"):
		return await spell_phase_handler_ref.select_hand_card(creatures, message)
	
	print("[SpellCreatureSwap] 手札選択UI未実装、最初の候補を使用: %s" % message)
	return 0 if creatures.size() > 0 else -1


# ============ 発動判定 ============

## エクスチェンジの発動可能判定
func can_cast_exchange(player_id: int) -> bool:
	var own_creatures = _get_own_creature_tiles(player_id)
	var hand_creatures = _get_hand_creatures(player_id)
	return own_creatures.size() > 0 and hand_creatures.size() > 0


## リリーフの発動可能判定
func can_cast_relief(player_id: int) -> bool:
	var own_creatures = _get_own_creature_tiles(player_id)
	return own_creatures.size() >= 2
