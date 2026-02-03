# SpellCreatureSwap - クリーチャー交換スペル
class_name SpellCreatureSwap

# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var card_system_ref: Object
var spell_phase_handler_ref: Object
var creature_synthesis: CreatureSynthesis = null


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, card_sys: Object, spell_phase_handler: Object = null) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler
	
	# クリーチャー合成システムを初期化
	if CardLoader:
		creature_synthesis = CreatureSynthesis.new(CardLoader)


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
	
	var hand_creature: Dictionary
	var is_cpu = _is_cpu_player(caster_player_id)
	
	if is_cpu:
		# CPU: 自動で最適なクリーチャーを選択（属性一致 + HP/APの合計が高いもの）
		var tile_element = tile.tile_type if tile else ""
		hand_creature = _cpu_select_best_creature(hand_creatures, tile.creature_data, tile_element)
	else:
		# 人間: 手札クリーチャー選択UI
		var selected_hand_index = await _select_hand_creature(hand_creatures, "交換するクリーチャーを選択")
		if selected_hand_index == -1:
			return {"success": false, "reason": "cancelled"}
		hand_creature = hand_creatures[selected_hand_index]
	
	# カード犠牲処理（クリーチャー合成用）- CPUはスキップ
	if not is_cpu and _requires_card_sacrifice(hand_creature):
		var sacrifice_result = await _process_card_sacrifice(caster_player_id, hand_creature)
		if sacrifice_result.get("cancelled", false):
			return {"success": false, "reason": "cancelled"}
		
		# 合成判定・適用
		var sacrifice_card = sacrifice_result.get("sacrifice_card", {})
		if not sacrifice_card.is_empty() and creature_synthesis:
			var is_synthesized = creature_synthesis.check_condition(hand_creature, sacrifice_card)
			if is_synthesized:
				hand_creature = creature_synthesis.apply_synthesis(hand_creature, sacrifice_card, true)
				print("[SpellCreatureSwap] 合成成立: %s" % hand_creature.get("name", "?"))
	
	# 交換実行
	_execute_swap_with_hand(tile_index, caster_player_id, hand_creature)
	
	return {
		"success": true,
		"tile_index": tile_index,
		"hand_creature": hand_creature.get("name", "クリーチャー")
	}

## CPUプレイヤー判定
func _is_cpu_player(player_id: int) -> bool:
	return player_id > 0

## CPU用：最適なクリーチャーを選択（タイルの属性と一致 + HP+APが高いもの）
func _cpu_select_best_creature(hand_creatures: Array, _current_creature: Dictionary, tile_element: String = "") -> Dictionary:
	var best = hand_creatures[0]
	var best_score = _get_creature_score_with_element(best, tile_element)
	
	for creature in hand_creatures:
		var score = _get_creature_score_with_element(creature, tile_element)
		if score > best_score:
			best = creature
			best_score = score
	
	return best

## クリーチャーのスコア計算（レート + 属性一致ボーナス）
func _get_creature_score_with_element(creature: Dictionary, tile_element: String) -> int:
	var CardRateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
	var base_score = CardRateEvaluator.get_rate(creature)
	
	# 属性一致ボーナス
	var creature_element = creature.get("element", "")
	if tile_element != "" and creature_element == tile_element:
		base_score += 200
	
	return base_score


## 盤面上の2体のクリーチャーを交換（リリーフ）
func _apply_swap_board_creatures(target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var tile_index_1 = target_data.get("tile_index", -1)
	var tile_index_2 = target_data.get("tile_index_2", -1)
	var is_cpu = _is_cpu_player(caster_player_id)
	
	# CPUの場合は自動で最適なペアを選択
	if is_cpu:
		var best_pair = _cpu_select_best_swap_pair(caster_player_id)
		if best_pair.is_empty():
			return {"success": false, "reason": "no_valid_swap"}
		tile_index_1 = best_pair.tile_1
		tile_index_2 = best_pair.tile_2
	else:
		# 人間プレイヤーの場合
		# 1体目が選択されていない場合
		if tile_index_1 == -1:
			var own_creatures = _get_own_creature_tiles(caster_player_id)
			if own_creatures.size() < 2:
				return {"success": false, "reason": "not_enough_creatures", "return_to_deck": true}
			
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

## CPU用：属性一致が改善する交換ペアを選択
func _cpu_select_best_swap_pair(player_id: int) -> Dictionary:
	if not board_system_ref:
		return {}
	
	var own_tiles = []
	for tile_index in board_system_ref.tile_nodes.keys():
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.owner_id == player_id and not tile.creature_data.is_empty():
			own_tiles.append({
				"index": tile_index,
				"element": tile.tile_type,
				"creature_element": tile.creature_data.get("element", "")
			})
	
	if own_tiles.size() < 2:
		return {}
	
	# 現在の属性一致数を計算
	var current_matches = 0
	for t in own_tiles:
		if t.element == t.creature_element:
			current_matches += 1
	
	# 最も改善するペアを探す
	var best_pair = {}
	var best_improvement = 0
	
	for i in range(own_tiles.size()):
		for j in range(i + 1, own_tiles.size()):
			var tile_a = own_tiles[i]
			var tile_b = own_tiles[j]
			
			var swap_matches = current_matches
			
			# 現在の一致を解除
			if tile_a.element == tile_a.creature_element:
				swap_matches -= 1
			if tile_b.element == tile_b.creature_element:
				swap_matches -= 1
			
			# 交換後の一致を追加
			if tile_a.element == tile_b.creature_element:
				swap_matches += 1
			if tile_b.element == tile_a.creature_element:
				swap_matches += 1
			
			var improvement = swap_matches - current_matches
			if improvement > best_improvement:
				best_improvement = improvement
				best_pair = {"tile_1": tile_a.index, "tile_2": tile_b.index}
	
	return best_pair


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
	
	# 手札からクリーチャーを削除（インデックスを探して削除）
	if card_system_ref:
		var hand = card_system_ref.get_all_cards_for_player(player_id)
		for i in range(hand.size()):
			if hand[i].get("id") == hand_creature.get("id"):
				# 捨て札ではなく手札から直接削除
				card_system_ref.player_hands[player_id]["data"].remove_at(i)
				print("[SpellCreatureSwap] 手札から %s を削除" % hand_creature_name)
				break
	
	# 盤面のクリーチャーを手札に戻す（HPリセット）
	if card_system_ref:
		var card_id = board_creature.get("id", -1)
		var clean_creature = card_system_ref._get_clean_card_data(card_id)
		if clean_creature.is_empty():
			# フォールバック: 元データが取得できない場合
			clean_creature = board_creature.duplicate(true)
			clean_creature.erase("current_hp")
			clean_creature.erase("curse")
			clean_creature.erase("is_down")
		card_system_ref.player_hands[player_id]["data"].append(clean_creature)
		print("[SpellCreatureSwap] %s を手札に戻す" % board_creature_name)
	
	# 古い3Dカード表示を削除
	if tile.has_method("remove_creature"):
		tile.remove_creature()
	
	# 手札のクリーチャーを盤面に配置
	var new_creature = hand_creature.duplicate()
	var base_hp = new_creature.get("hp", 0)
	new_creature["current_hp"] = base_hp
	
	# クリーチャーを配置（3Dカードも作成される）
	board_system_ref.place_creature(tile_index, new_creature, player_id)
	
	# ダウン状態にする
	if tile.has_method("set_down_state"):
		tile.set_down_state(true)
	
	# hand_updatedシグナルを発行
	if card_system_ref:
		card_system_ref.emit_signal("hand_updated")
	
	print("[SpellCreatureSwap] %s ↔ %s を交換" % [board_creature_name, hand_creature_name])


## 盤面上の2体のクリーチャーを交換
func _execute_swap_board(tile_index_1: int, tile_index_2: int) -> void:
	var tile_1 = board_system_ref.tile_nodes.get(tile_index_1)
	var tile_2 = board_system_ref.tile_nodes.get(tile_index_2)
	
	if not tile_1 or not tile_2:
		push_error("[SpellCreatureSwap] 交換対象のタイルが無効です")
		return
	
	# クリーチャーデータを保存
	var creature_1 = tile_1.creature_data.duplicate() if tile_1.creature_data else {}
	var creature_2 = tile_2.creature_data.duplicate() if tile_2.creature_data else {}
	var owner_1 = tile_1.owner_id
	var owner_2 = tile_2.owner_id
	
	var name_1 = creature_1.get("name", "クリーチャー")
	var name_2 = creature_2.get("name", "クリーチャー")
	
	# 古い3Dカード表示を削除
	if tile_1.has_method("remove_creature"):
		tile_1.remove_creature()
	if tile_2.has_method("remove_creature"):
		tile_2.remove_creature()
	
	# 交換して配置（3Dカードも作成される）
	board_system_ref.place_creature(tile_index_1, creature_2, owner_2)
	board_system_ref.place_creature(tile_index_2, creature_1, owner_1)
	
	# owner_idも交換
	tile_1.owner_id = owner_2
	tile_2.owner_id = owner_1
	
	# ダウン状態にする（両方）
	if tile_1.has_method("set_down_state"):
		tile_1.set_down_state(true)
	if tile_2.has_method("set_down_state"):
		tile_2.set_down_state(true)
	
	print("[SpellCreatureSwap] %s ↔ %s を交換" % [name_1, name_2])


# ============ ユーティリティ ============

## プレイヤーの手札からクリーチャーを取得
func _get_hand_creatures(player_id: int) -> Array:
	var creatures: Array = []
	
	if not card_system_ref:
		return creatures
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
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
	# UI参照取得
	var ui_manager = null
	if spell_phase_handler_ref and spell_phase_handler_ref.ui_manager:
		ui_manager = spell_phase_handler_ref.ui_manager
	
	if not ui_manager:
		print("[SpellCreatureSwap] UIManager未設定、最初の候補を使用")
		return 0 if creatures.size() > 0 else -1
	
	# フィルターをクリーチャーのみに設定（スペル/アイテムはグレーアウト）
	ui_manager.card_selection_filter = ""
	
	# メッセージ表示
	if ui_manager.has_method("set_message"):
		ui_manager.set_message(message)
	
	# カード選択UIを表示
	var current_player_id = spell_phase_handler_ref.current_player_id
	if player_system_ref:
		var player = player_system_ref.players[current_player_id]
		ui_manager.show_card_selection_ui_mode(player, "summon")
	
	# 戻るボタンを登録（キャンセル可能に）
	ui_manager.enable_navigation(
		Callable(),  # 決定なし
		func(): ui_manager.emit_signal("card_selected", -1)
	)
	
	# カード選択を待つ
	var selected_index = await ui_manager.card_selected
	
	# UIを閉じる
	ui_manager.hide_card_selection_ui()
	
	# 選択されたカードがクリーチャーか確認
	if selected_index >= 0:
		var hand = card_system_ref.get_all_cards_for_player(current_player_id)
		if selected_index < hand.size():
			var selected_card = hand[selected_index]
			if selected_card.get("type") == "creature":
				# クリーチャー配列内でのインデックスを返す
				for i in range(creatures.size()):
					if creatures[i].get("id") == selected_card.get("id"):
						return i
	
	return -1


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


# ============ カード犠牲処理 ============

## カード犠牲が必要か判定
func _requires_card_sacrifice(card_data: Dictionary) -> bool:
	# 正規化されたフィールドをチェック
	if card_data.get("cost_cards_sacrifice", 0) > 0:
		return true
	# 正規化されていない場合、元のcostフィールドもチェック
	var cost = card_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		return cost.get("cards_sacrifice", 0) > 0
	return false


## カード犠牲処理（手札選択UI表示→カード破棄）
func _process_card_sacrifice(player_id: int, summon_creature: Dictionary) -> Dictionary:
	# UI参照取得
	var ui_manager = null
	if spell_phase_handler_ref and spell_phase_handler_ref.ui_manager:
		ui_manager = spell_phase_handler_ref.ui_manager
	
	if not ui_manager:
		print("[SpellCreatureSwap] UIManager未設定、カード犠牲スキップ")
		return {"cancelled": false, "sacrifice_card": {}}
	
	# 手札選択UIを表示（犠牲モード）
	if ui_manager.phase_display:
		ui_manager.phase_display.show_action_prompt("犠牲にするカードを選択")
	ui_manager.card_selection_filter = ""
	ui_manager.excluded_card_id = summon_creature.get("id", "")  # 召喚カードを除外
	var player = player_system_ref.players[player_id]
	ui_manager.show_card_selection_ui_mode(player, "sacrifice")
	
	# 戻るボタンを登録（キャンセル可能に）
	ui_manager.enable_navigation(
		Callable(),  # 決定なし
		func(): ui_manager.emit_signal("card_selected", -1)
	)
	
	# カード選択を待つ
	var selected_index = await ui_manager.card_selected
	
	# UIを閉じる
	ui_manager.hide_card_selection_ui()
	
	# 除外IDをリセット
	ui_manager.excluded_card_id = ""
	
	# 選択されたカードを取得
	if selected_index < 0:
		return {"cancelled": true, "sacrifice_card": {}}
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	if selected_index >= hand.size():
		return {"cancelled": true, "sacrifice_card": {}}
	
	var sacrifice_card = hand[selected_index]
	
	# 召喚するクリーチャーと同じカードは犠牲にできない
	if sacrifice_card.get("id") == summon_creature.get("id"):
		if ui_manager.phase_display:
			ui_manager.phase_display.show_toast("召喚するカードは犠牲にできません")
		return {"cancelled": true, "sacrifice_card": {}}
	
	# カードを破棄
	card_system_ref.discard_card(player_id, selected_index, "sacrifice")
	print("[SpellCreatureSwap] %s を犠牲にしました" % sacrifice_card.get("name", "?"))
	
	return {"cancelled": false, "sacrifice_card": sacrifice_card}
