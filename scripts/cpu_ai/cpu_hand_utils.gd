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

## 召喚用の最適カードを選択（属性一致優先）
func select_best_summon_card(current_player, affordable_cards: Array, tile_element: String = "") -> int:
	if affordable_cards.is_empty():
		return -1
	
	# 属性一致カードを探す
	if not tile_element.is_empty():
		var matching_cards = []
		for index in affordable_cards:
			var card = card_system.get_card_data_for_player(current_player.id, index)
			if card.is_empty():
				continue
			var card_element = card.get("element", "")
			# 属性一致またはneutralタイルならOK
			if card_element == tile_element or tile_element == "neutral":
				matching_cards.append(index)
		
		# 属性一致カードがあれば、その中から最も安いものを選択
		if not matching_cards.is_empty():
			print("[CPU HandUtils] 属性一致カード発見: %d枚" % matching_cards.size())
			return select_cheapest_from_list(current_player, matching_cards)
	
	# 属性一致がなければ最も安いカードを選択
	print("[CPU HandUtils] 属性一致なし、最安カードを選択")
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
		if card.get("type", "") != "item":
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
		if card.get("type", "") != "item":
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
		if card.get("type", "") == "item":
			items.append(card)
	
	return items

## 敵が援護を使えるかチェック（防御側クリーチャーが援護スキルを持ち、手札に対象属性クリーチャーがいる）
## @param enemy_player_id: 敵プレイヤーID
## @param defender_creature: 防御側クリーチャーデータ
## @return: 援護可能なクリーチャーの配列
func get_enemy_assist_creatures(enemy_player_id: int, defender_creature: Dictionary) -> Array:
	# 防御側クリーチャーが援護スキルを持っているかチェック
	var ability_parsed = defender_creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "援護" not in keywords:
		return []
	
	# 援護対象属性を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var assist_condition = keyword_conditions.get("援護", {})
	var target_elements = assist_condition.get("target_elements", [])
	
	if target_elements.is_empty():
		return []
	
	# 敵の手札から援護対象属性のクリーチャーを収集
	var enemy_hand = get_enemy_hand(enemy_player_id)
	var assist_creatures: Array = []
	
	# "all"が含まれている場合は全属性を対象
	var is_all_elements = "all" in target_elements
	
	for card in enemy_hand:
		if card.get("type", "") != "creature":
			continue
		
		var card_element = card.get("element", "")
		if is_all_elements or card_element in target_elements:
			assist_creatures.append(card)
	
	return assist_creatures

# ============================================================
# アイテム破壊・盗みスキル判定
# ============================================================

## 敵クリーチャーがアイテム破壊スキルを持っているかチェック
## @param defender_creature: 防御側クリーチャーデータ
## @return: アイテム破壊可能なタイプの配列（空なら持っていない）
func defender_has_item_destroy(defender_creature: Dictionary) -> Array:
	var ability_parsed = defender_creature.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				var target_types = effect.get("target_types", [])
				if not target_types.is_empty():
					return target_types
	
	return []

## 敵クリーチャーがアイテム盗みスキルを持っているかチェック
## @param defender_creature: 防御側クリーチャーデータ
## @return: アイテム盗みを持っているか
func defender_has_item_steal(defender_creature: Dictionary) -> bool:
	var ability_parsed = defender_creature.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "steal_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				return true
	
	return false

## アイテムが敵のアイテム破壊対象かチェック
## @param item: アイテムデータ
## @param destroy_target_types: 破壊対象タイプの配列（defender_has_item_destroyの戻り値）
## @return: 破壊対象ならtrue
func is_item_destroy_target(item: Dictionary, destroy_target_types: Array) -> bool:
	if destroy_target_types.is_empty():
		return false
	
	var item_type = item.get("item_type", "")
	
	# 直接一致チェック
	if item_type in destroy_target_types:
		return true
	
	# 「道具」は武器・防具・アクセサリを含む
	if "道具" in destroy_target_types and item_type in ["武器", "防具", "アクセサリ"]:
		return true
	
	return false


## 攻撃側クリーチャーがアイテム破壊スキルを持っているかチェック（エイリアス）
## 防御側から見た場合に使用
func attacker_has_item_destroy(attacker_creature: Dictionary) -> Array:
	return defender_has_item_destroy(attacker_creature)


## 攻撃側クリーチャーがアイテム盗みスキルを持っているかチェック（エイリアス）
## 防御側から見た場合に使用
func attacker_has_item_steal(attacker_creature: Dictionary) -> bool:
	return defender_has_item_steal(attacker_creature)

# ============================================================
# 即死スキル関連
# ============================================================

## 攻撃側が即死スキルを持っているかチェック
## クリーチャー自身のスキル + アイテムの効果を両方確認
## @param attacker_creature: 攻撃側クリーチャーデータ
## @param attacker_item: 攻撃側が使用するアイテム（空の場合あり）
## @return: 即死を持っている場合は即死情報を返す、なければ空のDictionary
func attacker_has_instant_death(attacker_creature: Dictionary, attacker_item: Dictionary = {}) -> Dictionary:
	# クリーチャー自身の即死スキルをチェック
	var ability_parsed = attacker_creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "即死" in keywords:
		var keyword_conditions = ability_parsed.get("keyword_conditions", {})
		var instant_death_info = keyword_conditions.get("即死", {})
		if not instant_death_info.is_empty():
			return instant_death_info
	
	# アイテムの即死効果をチェック
	if not attacker_item.is_empty():
		var item_instant_death = _get_item_instant_death_info(attacker_item)
		if not item_instant_death.is_empty():
			return item_instant_death
	
	return {}

## アイテムの即死効果情報を取得
func _get_item_instant_death_info(item: Dictionary) -> Dictionary:
	var effect_parsed = item.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "instant_death":
			# 道連れ（on_death）は除外、攻撃時の即死のみ
			var trigger = effect.get("trigger", "")
			if trigger != "on_death":
				return effect
	
	return {}

## 手札から無効化アイテムを取得
## @param player_id: プレイヤーID
## @return: 無効化効果を持つアイテムの配列 [{index, data}]
func get_nullify_items_from_hand(player_id: int) -> Array:
	var result = []
	var items = get_items_from_hand(player_id)
	
	for item_entry in items:
		var item = item_entry.get("data", {})
		if _item_has_nullify_effect(item):
			result.append(item_entry)
	
	return result

## アイテムが無効化効果を持っているかチェック
func _item_has_nullify_effect(item: Dictionary) -> bool:
	var effect_parsed = item.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		# 無効化系の効果タイプをチェック
		if effect_type in ["nullify", "nullify_attack", "nullify_instant_death"]:
			return true
	
	# キーワードもチェック
	var keywords = effect_parsed.get("keywords", [])
	for keyword in keywords:
		if "無効化" in str(keyword):
			return true
	
	return false

## クリーチャーが無効化スキルを持っているかチェック
func creature_has_nullify_skill(creature: Dictionary) -> bool:
	var ability_parsed = creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "無効化" in keywords
