class_name CPUHandUtils

# CPU手札ユーティリティクラス
# 手札の取得、コスト計算、敵手札参照などを担当

# 定数をpreload

# システム参照
var card_system: CardSystem
var board_system
var player_system: PlayerSystem
var player_buff_system: PlayerBuffSystem
var tile_action_processor = null  # 土地条件チェック用

# === 直接参照（GFM経由を廃止） ===
var spell_cost_modifier = null  # SpellCostModifier: コスト計算

## システム参照を設定
func setup_systems(c_system: CardSystem, b_system, p_system: PlayerSystem, s_system: PlayerBuffSystem):
	card_system = c_system
	board_system = b_system
	player_system = p_system
	player_buff_system = s_system

	# TileActionProcessorを取得
	if board_system and board_system.has_node("TileActionProcessor"):
		tile_action_processor = board_system.get_node("TileActionProcessor")
		# 直接参照を取得
		if tile_action_processor:
			spell_cost_modifier = tile_action_processor.spell_cost_modifier

# ============================================================
# コスト計算
# ============================================================

## カードコストを計算
func calculate_card_cost(card_data: Dictionary, player_id: int) -> int:
	var cost_data = card_data.get("cost", 1)
	var base_cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		base_cost = cost_data.get("ep", 0) * GameConstants.CARD_COST_MULTIPLIER
	else:
		base_cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
	
	# エンジェルギフト刻印チェック（クリーチャー/アイテムコスト0化）
	if spell_cost_modifier:
		var modified_cost = spell_cost_modifier.get_modified_cost(player_id, card_data)
		if modified_cost == 0:
			return 0  # エンジェルギフトでコスト0化
	
	if player_buff_system:
		return player_buff_system.modify_card_cost(base_cost, card_data, player_id)
	
	return base_cost

## アイテムのコストを取得
func get_item_cost(item: Dictionary) -> int:
	var cost_data = item.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("ep", 0) * GameConstants.CARD_COST_MULTIPLIER
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

## 召喚用の最適カードを選択（属性一致優先、レート最高、土地条件考慮）
func select_best_summon_card(current_player, affordable_cards: Array, tile_element: String = "") -> int:
	if affordable_cards.is_empty():
		return -1
	
	# まず召喚可能なカード（土地条件・配置制限を満たすもの）をフィルタ
	var summonable_cards = _filter_summonable_cards(current_player.id, affordable_cards, tile_element)
	if summonable_cards.is_empty():
		print("[CPU HandUtils] 召喚可能なカードなし（土地条件/配置制限）")
		return -1
	
	# 属性一致カードを探す
	if not tile_element.is_empty():
		var matching_cards = []
		for index in summonable_cards:
			var card = card_system.get_card_data_for_player(current_player.id, index)
			if card.is_empty():
				continue
			var card_element = card.get("element", "")
			# 属性一致またはneutralタイルならOK
			if card_element == tile_element or tile_element == "neutral":
				matching_cards.append(index)
		
		# 属性一致カードがあれば、その中からレート最高のものを選択
		if not matching_cards.is_empty():
			print("[CPU HandUtils] 属性一致カード発見: %d枚" % matching_cards.size())
			return _select_highest_rate_from_list(current_player.id, matching_cards)
	
	# 属性一致がなければアルカナアーツ持ちを優先
	var mystic_cards = _filter_mystic_arts_cards(current_player.id, summonable_cards)
	if not mystic_cards.is_empty():
		print("[CPU HandUtils] 属性一致なし、アルカナアーツ持ちカード発見: %d枚" % mystic_cards.size())
		return _select_highest_rate_from_list(current_player.id, mystic_cards)
	
	# アルカナアーツ持ちもなければレート最低のカードを選択
	print("[CPU HandUtils] 属性一致・アルカナアーツ持ちなし、レート最低カードを選択")
	return _select_lowest_rate_from_list(current_player.id, summonable_cards)


## 土地条件・配置制限を満たすカードのみフィルタ
## tile_element: 配置先タイルの属性（cannot_summonチェック用）
func _filter_summonable_cards(player_id: int, card_indices: Array, tile_element: String = "") -> Array:
	var result = []
	
	# デバッグフラグを取得
	var disable_lands = false
	var disable_cannot_summon = false
	if tile_action_processor:
		disable_lands = tile_action_processor.debug_disable_lands_required
		disable_cannot_summon = tile_action_processor.debug_disable_cannot_summon
	
	for index in card_indices:
		var card = card_system.get_card_data_for_player(player_id, index)
		if card.is_empty():
			continue
		
		# 土地条件チェック（フラグで無効化可能）
		if not disable_lands and not check_lands_required(card, player_id):
			print("[CPU HandUtils] 土地条件未達: %s" % card.get("name", "?"))
			continue
		
		# 配置制限チェック（フラグで無効化可能）
		if not disable_cannot_summon and not tile_element.is_empty() and not check_cannot_summon(card, tile_element):
			print("[CPU HandUtils] 配置制限: %s は%s属性の土地に配置不可" % [card.get("name", "?"), tile_element])
			continue
		
		result.append(index)
	
	return result


## 土地条件をチェック（召喚可能かどうか）
func check_lands_required(card_data: Dictionary, player_id: int) -> bool:
	# cost_lands_required がなければOK
	var cost = card_data.get("cost", {})
	var lands_required = []
	
	if card_data.has("cost_lands_required"):
		lands_required = card_data.get("cost_lands_required", [])
	elif typeof(cost) == TYPE_DICTIONARY:
		lands_required = cost.get("lands_required", [])
	
	if lands_required.is_empty():
		return true
	
	# フールズフリーダム発動中は召喚条件を無視
	if tile_action_processor:
		if SummonConditionChecker.is_summon_condition_ignored(-1, tile_action_processor.game_flow_manager, tile_action_processor.board_system):
			return true
	
	# TileActionProcessorがあればそれを使用
	if tile_action_processor and tile_action_processor.has_method("check_lands_required"):
		var result = tile_action_processor.check_lands_required(card_data, player_id)
		return result.passed
	
	# フォールバック: 簡易チェック
	return check_lands_required_simple(card_data, player_id)


## 簡易土地条件チェック（フォールバック用）
func check_lands_required_simple(card_data: Dictionary, player_id: int) -> bool:
	var cost = card_data.get("cost", {})
	var lands_required = []
	
	if card_data.has("cost_lands_required"):
		lands_required = card_data.get("cost_lands_required", [])
	elif typeof(cost) == TYPE_DICTIONARY:
		lands_required = cost.get("lands_required", [])
	
	if lands_required.is_empty():
		return true
	
	if not board_system:
		return false
	
	# プレイヤーの所有土地の属性をカウント
	var owned_elements = {}
	var player_tiles = board_system.get_player_tiles(player_id)
	for tile in player_tiles:
		var element = tile.tile_type if tile else ""
		if element != "" and element != "neutral":
			owned_elements[element] = owned_elements.get(element, 0) + 1
	
	# 必要な属性をカウント
	var required_elements = {}
	for element in lands_required:
		required_elements[element] = required_elements.get(element, 0) + 1
	
	# 各属性の条件を満たしているかチェック
	for element in required_elements.keys():
		var required_count = required_elements[element]
		var owned_count = owned_elements.get(element, 0)
		if owned_count < required_count:
			return false
	
	return true


## 配置制限チェック（cannot_summon）
## card_data: クリーチャーカード
## tile_element: 配置先タイルの属性
func check_cannot_summon(card_data: Dictionary, tile_element: String) -> bool:
	var restrictions = card_data.get("restrictions", {})
	var cannot_summon = restrictions.get("cannot_summon", [])
	
	if cannot_summon.is_empty():
		return true  # 制限なし
	
	# タイル属性が配置不可リストに含まれていればfalse
	if tile_element in cannot_summon:
		return false
	
	return true


## リストからレートが最も高いカードを選択
func _select_highest_rate_from_list(player_id: int, card_indices: Array) -> int:
	if card_indices.is_empty():
		return -1
	
	var highest_rate = -999999
	var best_index = -1
	
	for index in card_indices:
		var card = card_system.get_card_data_for_player(player_id, index)
		if card.is_empty():
			continue
		var rate = CardRateEvaluator.get_rate(card)
		if rate > highest_rate:
			highest_rate = rate
			best_index = index
	
	return best_index


## リストからレートが最も低いカードを選択
func _select_lowest_rate_from_list(player_id: int, card_indices: Array) -> int:
	if card_indices.is_empty():
		return -1
	
	var lowest_rate = 999999
	var best_index = -1
	
	for index in card_indices:
		var card = card_system.get_card_data_for_player(player_id, index)
		if card.is_empty():
			continue
		var rate = CardRateEvaluator.get_rate(card)
		if rate < lowest_rate:
			lowest_rate = rate
			best_index = index
	
	return best_index


## アルカナアーツ持ちカードをフィルタ
func _filter_mystic_arts_cards(player_id: int, card_indices: Array) -> Array:
	var result = []
	for index in card_indices:
		var card = card_system.get_card_data_for_player(player_id, index)
		if card.is_empty():
			continue
		var ability_parsed = card.get("ability_parsed", {})
		var keywords = ability_parsed.get("keywords", [])
		if "アルカナアーツ" in keywords:
			result.append(index)
	return result

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
func get_items_from_hand(player_id: int, skip_destroy_types: Array = []) -> Array:
	var items = []
	var hand = card_system.get_all_cards_for_player(player_id)

	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") != "item":
			continue
		if not skip_destroy_types.is_empty() and is_item_destroy_target(card, skip_destroy_types):
			continue
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

## 敵が加勢を使えるかチェック（防御側クリーチャーが加勢スキルを持ち、手札に対象属性クリーチャーがいる）
## @param enemy_player_id: 敵プレイヤーID
## @param defender_creature: 防御側クリーチャーデータ
## @return: 加勢可能なクリーチャーの配列
func get_enemy_assist_creatures(enemy_player_id: int, defender_creature: Dictionary) -> Array:
	# 防御側クリーチャーが加勢スキルを持っているかチェック
	var ability_parsed = defender_creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "加勢" not in keywords:
		return []
	
	# 加勢対象属性を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var assist_condition = keyword_conditions.get("加勢", {})
	var target_elements = assist_condition.get("target_elements", [])
	
	if target_elements.is_empty():
		return []
	
	# 敵の手札から加勢対象属性のクリーチャーを収集
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
## @param rarity_exclude: レア度除外配列（イビルアイ等: ["N"]）
## @return: 破壊対象ならtrue
func is_item_destroy_target(item: Dictionary, destroy_target_types: Array, rarity_exclude: Array = []) -> bool:
	if destroy_target_types.is_empty():
		return false

	var item_type = item.get("item_type", "")

	# 直接一致チェック
	var type_matches = false
	if item_type in destroy_target_types:
		type_matches = true
	elif "道具" in destroy_target_types and item_type in ["武器", "防具", "アクセサリ"]:
		type_matches = true

	if not type_matches:
		return false

	# レア度除外チェック（イビルアイ等: rarity_exclude: ["N"]）
	if not rarity_exclude.is_empty():
		var item_rarity = item.get("rarity", "N")
		if item_rarity in rarity_exclude:
			return false

	return true


## アイテムが持つ destroy_item 効果を取得
## @param item: アイテムデータ（effect_parsed を含む）
## @return: destroy_item 効果の Dictionary（なければ空）
func get_item_destroy_effect(item: Dictionary) -> Dictionary:
	var effect_parsed = item.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	for effect in effects:
		if effect.get("effect_type") == "destroy_item":
			if "before_battle" in effect.get("triggers", []):
				return effect
	return {}


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
			# 相討（on_death）は除外、攻撃時の即死のみ
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


# ============================================================
# カードレート評価
# ============================================================

const CardRateEvaluator = preload("res://scripts/cpu_ai/card_rate_evaluator.gd")

## 手札上限超過時にレートの低いカードから捨てる
func discard_excess_cards_by_rate(player_id: int, max_cards: int = 6) -> int:
	if not card_system:
		return 0
	
	var hand_size = card_system.get_hand_size_for_player(player_id)
	if hand_size <= max_cards:
		return 0  # 捨てる必要なし
	
	var cards_to_discard = hand_size - max_cards
	print("[CPU手札調整] %d枚 → %d枚（%d枚捨てる）" % [hand_size, max_cards, cards_to_discard])
	
	for i in range(cards_to_discard):
		var hand = card_system.get_all_cards_for_player(player_id)
		if hand.size() <= max_cards:
			break
		
		# レートの低いカードを探す（重複補正込み）
		var lowest_index = _find_lowest_rate_card_index_for_discard(player_id)
		if lowest_index >= 0:
			var card = card_system.get_card_data_for_player(player_id, lowest_index)
			var rate = _get_rate_for_discard(card, player_id)
			print("[CPU手札調整] 捨てるカード: %s (レート: %d)" % [card.get("name", "不明"), rate])
			card_system.discard_card(player_id, lowest_index, "discard")
	
	return cards_to_discard


## 捨て札判断用：手札の中で最もレートの低いカードのインデックスを取得
func _find_lowest_rate_card_index_for_discard(player_id: int) -> int:
	var hand = card_system.get_all_cards_for_player(player_id)
	if hand.is_empty():
		return -1
	
	var lowest_index = 0
	var lowest_rate = _get_rate_for_discard(hand[0], player_id)
	
	for i in range(1, hand.size()):
		var rate = _get_rate_for_discard(hand[i], player_id)
		if rate < lowest_rate:
			lowest_rate = rate
			lowest_index = i
	
	return lowest_index


## 捨て札判断用：重複補正込みのレート計算
func _get_rate_for_discard(card: Dictionary, player_id: int) -> int:
	var base_rate = CardRateEvaluator.get_rate(card)
	
	# 手札内の同名カード枚数をカウント
	var card_id = card.get("id", -1)
	var count = _count_same_card_in_hand(player_id, card_id)
	
	# 重複補正
	# 2枚目: -30
	# 3枚目以降: -100
	if count >= 3:
		base_rate -= 100
	elif count == 2:
		base_rate -= 30
	
	return base_rate


## 手札内の同一カード枚数をカウント
func _count_same_card_in_hand(player_id: int, card_id: int) -> int:
	var hand = card_system.get_all_cards_for_player(player_id)
	var count = 0
	for card in hand:
		if card.get("id", -1) == card_id:
			count += 1
	return count
