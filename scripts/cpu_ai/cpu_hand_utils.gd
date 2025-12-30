class_name CPUHandUtils

# CPU手札ユーティリティクラス
# 手札の取得、コスト計算、敵手札参照などを担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# システム参照
var card_system: CardSystem
var board_system
var player_system: PlayerSystem
var player_buff_system: PlayerBuffSystem

## システム参照を設定
func setup_systems(c_system: CardSystem, b_system, p_system: PlayerSystem, s_system: PlayerBuffSystem):
	card_system = c_system
	board_system = b_system
	player_system = p_system
	player_buff_system = s_system

# ============================================================
# コスト計算
# ============================================================

## カードコストを計算
func calculate_card_cost(card_data: Dictionary, player_id: int) -> int:
	var cost_data = card_data.get("cost", 1)
	var base_cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		base_cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
	else:
		base_cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
	
	# ライフフォース呪いチェック（クリーチャー/アイテムコスト0化）
	if board_system and board_system.game_flow_manager and board_system.game_flow_manager.spell_cost_modifier:
		var modified_cost = board_system.game_flow_manager.spell_cost_modifier.get_modified_cost(player_id, card_data)
		if modified_cost == 0:
			return 0  # ライフフォースでコスト0化
	
	if player_buff_system:
		return player_buff_system.modify_card_cost(base_cost, card_data, player_id)
	
	return base_cost

## アイテムのコストを取得
func get_item_cost(item: Dictionary) -> int:
	var cost_data = item.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
	return cost_data * GameConstants.CARD_COST_MULTIPLIER

# ============================================================
# 手札検索
# ============================================================

## 支払い可能なカードを検索
func find_affordable_cards(current_player) -> Array:
	if not card_system:
		return []
	
	var affordable = []
	var available_magic = current_player.magic_power
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	
	for i in range(hand_size):
		var card_data = card_system.get_card_data_for_player(current_player.id, i)
		if card_data.is_empty():
			continue
		
		# クリーチャーカードのみ対象
		if card_data.get("type", "") != "creature":
			continue
		
		var cost = calculate_card_cost(card_data, current_player.id)
		if cost <= available_magic:
			affordable.append(i)
	
	return affordable

## カードが支払い可能かチェック
func can_afford_card(current_player, card_index: int) -> bool:
	var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
	if card_data.is_empty():
		return false
	
	var cost = calculate_card_cost(card_data, current_player.id)
	return current_player.magic_power >= cost

## 召喚用の最適カードを選択
func select_best_summon_card(current_player, affordable_cards: Array) -> int:
	# 簡易実装：最も安いカードを選択
	return select_cheapest_from_list(current_player, affordable_cards)

## 最も安いカードを選択
func select_cheapest_card(current_player) -> int:
	if not card_system:
		return -1
	
	return card_system.get_cheapest_card_index_for_player(current_player.id)

## リストから最も安いカードを選択
func select_cheapest_from_list(current_player, card_indices: Array) -> int:
	if card_indices.is_empty():
		return -1
	
	var min_cost = 999999
	var best_index = -1
	
	for index in card_indices:
		var card = card_system.get_card_data_for_player(current_player.id, index)
		if not card.is_empty():
			var cost = calculate_card_cost(card, current_player.id)
			if cost < min_cost:
				min_cost = cost
				best_index = index
	
	return best_index

## 手札からアイテムカードを抽出
func get_items_from_hand(player_id: int) -> Array:
	var items = []
	var hand = card_system.get_all_cards_for_player(player_id)
	
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") == "item":
			items.append({"index": i, "data": card})
	
	return items

## 手札からクリーチャーカードを抽出
func get_creatures_from_hand(player_id: int) -> Array:
	var creatures = []
	var hand = card_system.get_all_cards_for_player(player_id)
	
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") == "creature":
			creatures.append({"index": i, "data": card})
	
	return creatures

# ============================================================
# 敵手札参照機能
# ============================================================

## 敵プレイヤーの手札を取得（密命カードを除外）
func get_enemy_hand(enemy_player_id: int) -> Array:
	if not card_system:
		return []
	
	var enemy_hand = card_system.get_hand(enemy_player_id)
	var visible_cards: Array = []
	
	for card in enemy_hand:
		# 密命カードは見えない
		if card.get("is_secret", false):
			continue
		visible_cards.append(card)
	
	return visible_cards

## 敵がアイテムを持っているかチェック（種類指定可能）
func enemy_has_item(enemy_player_id: int, item_type: String = "") -> bool:
	var enemy_hand = get_enemy_hand(enemy_player_id)
	
	for card in enemy_hand:
		if card.get("card_type", "") != "item":
			continue
		
		# 種類指定がなければアイテムがあればtrue
		if item_type.is_empty():
			return true
		
		# 種類指定がある場合はマッチするかチェック
		if card.get("item_type", "") == item_type:
			return true
	
	return false

## 敵が無効化アイテム（防具）を持っているかチェック
func enemy_has_nullify_item(enemy_player_id: int) -> bool:
	var enemy_hand = get_enemy_hand(enemy_player_id)
	
	for card in enemy_hand:
		if card.get("card_type", "") != "item":
			continue
		
		# 防具は無効化効果を持つことが多い
		if card.get("item_type", "") == "armor":
			# effect_parsedに無効化効果があるかチェック
			var effect_parsed = card.get("effect_parsed", {})
			var effects = effect_parsed.get("effects", [])
			for effect in effects:
				if effect.get("effect_type", "") == "nullify":
					return true
			
			# keywordsに無効化があるかチェック
			var keywords = effect_parsed.get("keywords", [])
			if "無効化" in keywords:
				return true
	
	return false

## 敵の手札からアイテム一覧を取得
func get_enemy_items(enemy_player_id: int) -> Array:
	var enemy_hand = get_enemy_hand(enemy_player_id)
	var items: Array = []
	
	for card in enemy_hand:
		if card.get("card_type", "") == "item":
			items.append(card)
	
	return items
