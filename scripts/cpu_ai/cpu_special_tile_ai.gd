## CPU特殊タイル判断AI
## 各特殊タイルでのCPU行動を決定する
class_name CPUSpecialTileAI
extends RefCounted

var card_system: CardSystem
var player_system: PlayerSystem
var board_system: Node
var game_flow_manager: Node

# === 直接参照（GFM経由を廃止） ===
var spell_phase_handler = null
var cpu_spell_ai = null  # CPUSpellAI直接参照（SPHパススルー廃止）
var _target_selection_helper = null
var _magic_stone_system = null

func setup(c_system: CardSystem, p_system: PlayerSystem, b_system: Node, gfm: Node) -> void:
	card_system = c_system
	player_system = p_system
	board_system = b_system
	game_flow_manager = gfm

# =============================================================================
# カードギブタイル判断
# =============================================================================

## カードギブで取得するカード種類を決定
## 戻り値: "creature", "item", "spell", または "" (スキップ)
func decide_card_give(player_id: int) -> String:
	# 手札7枚以上ならスキップ
	var hand = _get_hand(player_id)
	if hand.size() >= 7:
		print("[CPUSpecialTileAI] カードギブ: 手札7枚以上 - スキップ")
		return ""
	
	# 手札のカード種類を集計
	var type_counts = _count_card_types(hand)
	
	# 足りない種類を探す
	var missing_types = []
	if type_counts.creature == 0:
		missing_types.append("creature")
	if type_counts.item == 0:
		missing_types.append("item")
	if type_counts.spell == 0:
		missing_types.append("spell")
	
	if not missing_types.is_empty():
		# 足りない種類からランダムで選択
		var selected_type = missing_types[randi() % missing_types.size()]
		print("[CPUSpecialTileAI] カードギブ: %s が不足 - 補充" % selected_type)
		return selected_type
	
	# 全種類持っている場合はランダム
	var all_types = ["creature", "item", "spell"]
	var random_type = all_types[randi() % all_types.size()]
	print("[CPUSpecialTileAI] カードギブ: 全種類所持 - ランダムで %s" % random_type)
	return random_type

# =============================================================================
# カードバイタイル判断
# =============================================================================

## カードバイで購入するカードを決定
## 戻り値: 購入するカードのDictionary、または {} (スキップ)
func decide_card_buy(player_id: int, available_cards: Array) -> Dictionary:
	# 手札7枚以上ならスキップ
	var hand = _get_hand(player_id)
	if hand.size() >= 7:
		print("[CPUSpecialTileAI] カードバイ: 手札7枚以上 - スキップ")
		return {}
	
	# EP取得
	var magic = _get_magic(player_id)
	
	# 手札のカード種類を集計
	var type_counts = _count_card_types(hand)
	
	# 購入候補を絞り込む（購入後100EP以上残る）
	var buyable_cards = []
	for card in available_cards:
		var price = _get_card_price(card)
		if magic - price >= 100:
			buyable_cards.append(card)
	
	if buyable_cards.is_empty():
		print("[CPUSpecialTileAI] カードバイ: 購入可能なカードなし（EP不足）- スキップ")
		return {}
	
	# 足りない種類を探す
	var missing_types = []
	if type_counts.item == 0:
		missing_types.append("item")
	if type_counts.spell == 0:
		missing_types.append("spell")
	
	# 足りない種類のカードを探す
	if not missing_types.is_empty():
		for card in buyable_cards:
			var card_type = card.get("type", "")
			if card_type in missing_types:
				print("[CPUSpecialTileAI] カードバイ: %s が不足 - %s を購入" % [card_type, card.get("name", "?")])
				return card
	
	# 全種類持っている場合はランダム
	var selected = buyable_cards[randi() % buyable_cards.size()]
	print("[CPUSpecialTileAI] カードバイ: 全種類所持 - ランダムで %s を購入" % selected.get("name", "?"))
	return selected

# =============================================================================
# 魔法タイル判断
# =============================================================================

## 魔法タイルで使用するスペルを決定
## 戻り値: 使用するスペルのDictionary、または {} (スキップ)
func decide_magic_tile_spell(player_id: int, available_spells: Array) -> Dictionary:
	# CPUSpellAIを取得して評価に使用
	var local_cpu_spell_ai = _get_cpu_spell_ai()

	# EP取得
	var magic = _get_magic(player_id)

	# 各スペルを評価（CPUSpellAIがあればスコア評価、なければ対象チェックのみ）
	var best_spell = {}
	var best_score = 0.0

	for spell in available_spells:
		var cost = _get_spell_cost(spell)
		if cost > magic:
			continue

		# CPUSpellAIで評価
		if local_cpu_spell_ai and local_cpu_spell_ai.has_method("evaluate_spell_for_magic_tile"):
			var eval_result = local_cpu_spell_ai.evaluate_spell_for_magic_tile(spell, player_id)
			if eval_result.get("should_use", false) and eval_result.get("score", 0) > best_score:
				best_score = eval_result.get("score", 0)
				best_spell = spell
		else:
			# フォールバック：対象チェックのみ
			if _spell_has_valid_target(spell, player_id):
				print("[CPUSpecialTileAI] 魔法タイル: %s を使用（対象あり）" % spell.get("name", "?"))
				return spell

	if not best_spell.is_empty():
		print("[CPUSpecialTileAI] 魔法タイル: %s を使用（スコア: %.1f）" % [best_spell.get("name", "?"), best_score])
		return best_spell

	print("[CPUSpecialTileAI] 魔法タイル: 有効な対象なし - スキップ")
	return {}

## スペルに有効な対象があるかチェック（フォールバック用）
func _spell_has_valid_target(spell: Dictionary, player_id: int) -> bool:
	# スペルの対象情報を取得
	var effect_parsed = spell.get("effect_parsed", {})
	var target_info = effect_parsed.get("target", {})
	var target_type = target_info.get("type", "")
	
	# 対象不要スペル（自分自身など）は常にtrue
	if target_type == "" or target_type == "self" or target_type == "all_players":
		return true
	
	# システム情報を構築
	var systems = {
		"board_system": board_system,
		"player_system": player_system,
		"current_player_id": player_id,
		"game_flow_manager": game_flow_manager
	}
	
	# 対象を取得
	var targets = TargetSelectionHelper.get_valid_targets_core(systems, target_type, target_info)
	return not targets.is_empty()

# =============================================================================
# 分岐タイル判断
# =============================================================================

## 分岐タイルでの判断（常にスキップ）
func decide_branch_tile(_player_id: int) -> bool:
	print("[CPUSpecialTileAI] 分岐タイル: 操作しない")
	return false  # false = 変更しない

# =============================================================================
# 指令タイル（ベースタイル）判断
# =============================================================================

## 指令タイルで配置する空き地を決定
## 戻り値: 配置先タイルインデックス、または -1 (スキップ)
func decide_base_tile(player_id: int, empty_tiles: Array) -> int:
	if empty_tiles.is_empty():
		print("[CPUSpecialTileAI] 指令タイル: 空き地なし - スキップ")
		return -1
	
	# 手札のクリーチャーを取得
	var hand = _get_hand(player_id)
	var creatures = hand.filter(func(c): return c.get("type", "") == "creature")
	
	if creatures.is_empty():
		print("[CPUSpecialTileAI] 指令タイル: 手札にクリーチャーなし - スキップ")
		return -1
	
	# 手札クリーチャーの属性を集計
	var creature_elements = {}
	for creature in creatures:
		var element = creature.get("element", "neutral")
		if not creature_elements.has(element):
			creature_elements[element] = 0
		creature_elements[element] += 1
	
	# 空き地の属性と照合して、配置可能な場所を探す
	for tile_index in empty_tiles:
		var tile_info = _get_tile_info(tile_index)
		var tile_element = tile_info.get("element", "neutral")
		
		# 属性一致するクリーチャーがあるか
		if creature_elements.has(tile_element) or tile_element == "neutral":
			print("[CPUSpecialTileAI] 指令タイル: タイル%d（%s）に配置" % [tile_index, tile_element])
			return tile_index
		
		# neutralクリーチャーは任意の場所に配置可能
		if creature_elements.has("neutral"):
			print("[CPUSpecialTileAI] 指令タイル: タイル%d に無属性クリーチャーを配置" % tile_index)
			return tile_index
	
	print("[CPUSpecialTileAI] 指令タイル: 属性一致する空き地なし - スキップ")
	return -1

# =============================================================================
# 魔法石タイル判断
# =============================================================================

## 魔法石タイルでの購入判断
## 戻り値: {"action": "buy"/"skip", "element": "fire"等, "count": 1}
func decide_magic_stone(player_id: int) -> Dictionary:
	# 手札のクリーチャーを取得
	var hand = _get_hand(player_id)
	var creatures = hand.filter(func(c): return c.get("type", "") == "creature")
	
	if creatures.is_empty():
		print("[CPUSpecialTileAI] 魔法石タイル: 手札にクリーチャーなし - スキップ")
		return {"action": "skip"}
	
	# 手札クリーチャーの属性を集計
	var element_counts = {"fire": 0, "water": 0, "earth": 0, "wind": 0}
	for creature in creatures:
		var element = creature.get("element", "")
		if element_counts.has(element):
			element_counts[element] += 1
	
	# 最多属性を決定
	var max_element = ""
	var max_count = 0
	for element in element_counts.keys():
		if element_counts[element] > max_count:
			max_count = element_counts[element]
			max_element = element
	
	if max_element == "" or max_count == 0:
		print("[CPUSpecialTileAI] 魔法石タイル: 有効な属性なし - スキップ")
		return {"action": "skip"}
	
	# 石の価格を確認（購入可能か）
	var magic = _get_magic(player_id)
	var stone_system = _get_magic_stone_system()
	if stone_system:
		var price = stone_system.calculate_stone_value(max_element)
		if magic < price:
			print("[CPUSpecialTileAI] 魔法石タイル: EP不足 - スキップ")
			return {"action": "skip"}
	
	print("[CPUSpecialTileAI] 魔法石タイル: %sの石を1つ購入" % max_element)
	return {"action": "buy", "element": max_element, "count": 1}

# =============================================================================
# ヘルパー関数
# =============================================================================

func _get_hand(player_id: int) -> Array:
	if card_system:
		return card_system.get_all_cards_for_player(player_id)
	return []

func _get_magic(player_id: int) -> int:
	if player_system and player_id < player_system.players.size():
		return player_system.players[player_id].magic_power
	return 0

func _count_card_types(hand: Array) -> Dictionary:
	var counts = {"creature": 0, "item": 0, "spell": 0}
	for card in hand:
		var card_type = card.get("type", "")
		if counts.has(card_type):
			counts[card_type] += 1
	return counts

func _get_card_price(card: Dictionary) -> int:
	var cost_data = card.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)
	else:
		cost = int(cost_data)
	return int(ceil(cost / 2.0))

func _get_spell_cost(spell: Dictionary) -> int:
	var cost_data = spell.get("cost", {})
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("ep", 0)
	return int(cost_data)

func _get_tile_info(tile_index: int) -> Dictionary:
	if board_system and board_system.has_method("get_tile_info"):
		return board_system.get_tile_info(tile_index)
	return {}

func _get_cpu_spell_ai():
	return cpu_spell_ai

func _get_target_selection_helper():
	return _target_selection_helper

func _get_magic_stone_system():
	return _magic_stone_system
