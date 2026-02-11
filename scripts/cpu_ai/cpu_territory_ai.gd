class_name CPUTerritoryAI
extends RefCounted
## CPUドミニオコマンドAI
## 
## ドミニオコマンド（レベルアップ、属性変更、移動侵略、クリーチャー交換）の
## 利益スコアを計算し、最適な行動を選択する。

# 定数・共通クラスをpreload
const CardRateEvaluator = preload("res://scripts/cpu_ai/card_rate_evaluator.gd")
const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")
const CPUAIConstantsScript = preload("res://scripts/cpu_ai/cpu_ai_constants.gd")

# === 定数（CPUAIConstantsへのエイリアス） ===
# 後方互換性のため、既存コードが参照できるようにエイリアスを定義

## 基準スコア: 空き地に属性一致召喚
const SUMMON_BASE_SCORE = CPUAIConstantsScript.SUMMON_BASE_SCORE
## 基準スコア: 空き地に属性不一致召喚
const SUMMON_MISMATCH_SCORE = CPUAIConstantsScript.SUMMON_MISMATCH_SCORE
## 移動侵略（空き地）: 属性一致ボーナス
const MOVE_ELEMENT_MATCH_BONUS = CPUAIConstantsScript.MOVE_ELEMENT_MATCH_BONUS
## 移動侵略（空き地）: 連鎖数係数
const MOVE_CHAIN_MULTIPLIER = CPUAIConstantsScript.MOVE_CHAIN_MULTIPLIER
## 移動侵略/侵略: 属性一致ボーナス
const INVASION_ELEMENT_MATCH_BONUS = CPUAIConstantsScript.INVASION_ELEMENT_MATCH_BONUS
## 侵略: 敵資産減少倍率（自分の増加 + 敵の減少）
const INVASION_ASSET_MULTIPLIER = CPUAIConstantsScript.INVASION_ASSET_MULTIPLIER
## クリーチャー交換: レート差係数
const SWAP_RATE_MULTIPLIER = CPUAIConstantsScript.SWAP_RATE_MULTIPLIER
## クリーチャー交換: 属性一致ボーナス
const SWAP_ELEMENT_MATCH_BONUS = CPUAIConstantsScript.SWAP_ELEMENT_MATCH_BONUS
## クリーチャー交換: 属性不一致ペナルティ
const SWAP_ELEMENT_MISMATCH_PENALTY = CPUAIConstantsScript.SWAP_ELEMENT_MISMATCH_PENALTY
## クリーチャー交換: 土地レベル係数
const SWAP_LEVEL_MULTIPLIER = CPUAIConstantsScript.SWAP_LEVEL_MULTIPLIER
## クリーチャー交換: 最低スコア閾値
const SWAP_MIN_SCORE_THRESHOLD = CPUAIConstantsScript.SWAP_MIN_SCORE_THRESHOLD
## 属性変更: 基本スコア
const ELEMENT_CHANGE_BASE_SCORE = CPUAIConstantsScript.ELEMENT_CHANGE_BASE_SCORE
## 属性変更: 無属性ボーナス
const ELEMENT_CHANGE_NEUTRAL_BONUS = CPUAIConstantsScript.ELEMENT_CHANGE_NEUTRAL_BONUS
## 属性変更: コスト係数
const ELEMENT_CHANGE_COST_MULTIPLIER = CPUAIConstantsScript.ELEMENT_CHANGE_COST_MULTIPLIER
## 危機モード: 残りEP閾値
const CRISIS_MODE_THRESHOLD = CPUAIConstantsScript.CRISIS_MODE_THRESHOLD
## 危機モード: スコア（最優先）
const CRISIS_MODE_SCORE = CPUAIConstantsScript.CRISIS_MODE_SCORE
## EP温存: 残す割合（30%）
const MAGIC_RESERVE_RATIO = CPUAIConstantsScript.MAGIC_RESERVE_RATIO
## EP温存: 最低残高
const MAGIC_RESERVE_MINIMUM = CPUAIConstantsScript.MAGIC_RESERVE_MINIMUM

# === 共有コンテキスト ===
var _context: CPUAIContextScript = null

# システム参照のgetter（contextから取得）
var board_system:
	get: return _context.board_system if _context else null
var card_system:
	get: return _context.card_system if _context else null
var player_system:
	get: return _context.player_system if _context else null
var creature_manager:
	get: return _context.creature_manager if _context else null
var battle_simulator: BattleSimulator:
	get: return _context.get_battle_simulator() if _context else null
var tile_action_processor:
	get: return _context.tile_action_processor if _context else null

var battle_ai: CPUBattleAI = null
var sacrifice_selector: CPUSacrificeSelector = null
var creature_synthesis: CreatureSynthesis = null


## 共有コンテキストでセットアップ
func setup_with_context(ctx: CPUAIContextScript) -> void:
	_context = ctx
	
	# BattleAIを作成（コンテキストを共有）
	battle_ai = CPUBattleAI.new()
	battle_ai.setup_with_context(ctx)
	
	# 犠牲カード選択クラスを初期化
	sacrifice_selector = CPUSacrificeSelector.new()
	sacrifice_selector.initialize(card_system, board_system)


## CreatureSynthesisを設定（クリーチャー合成判定用）
func set_creature_synthesis(synth: CreatureSynthesis) -> void:
	creature_synthesis = synth
	if sacrifice_selector:
		sacrifice_selector.creature_synthesis = synth


## TileActionProcessorを設定（土地条件チェック用）
func set_tile_action_processor(processor) -> void:
	tile_action_processor = processor


## メイン判断関数: 全オプションを評価して最適なものを返す
func evaluate_all_options(context: Dictionary) -> Dictionary:
	var options: Array = []
	
	print("[CPUTerritoryAI] evaluate_all_options 開始")
	print("[CPUTerritoryAI] context: %s" % context)
	
	# 危機モード判定
	if is_crisis_mode(context):
		print("[CPUTerritoryAI] 危機モード発動!")
		var crisis_option = evaluate_crisis_level_up(context)
		if not crisis_option.is_empty():
			return crisis_option
	
	# 各コマンドを評価
	var invasion_options = _evaluate_invasion(context)
	print("[CPUTerritoryAI] 侵略オプション: %d件" % invasion_options.size())
	options.append_array(invasion_options)
	
	var move_options = _evaluate_move_invasion(context)
	print("[CPUTerritoryAI] 移動侵略オプション: %d件" % move_options.size())
	options.append_array(move_options)
	
	var level_up_options = _evaluate_level_up(context)
	print("[CPUTerritoryAI] レベルアップオプション: %d件" % level_up_options.size())
	for opt in level_up_options:
		print("[CPUTerritoryAI]   - tile:%d, score:%d" % [opt.get("tile_index", -1), opt.get("score", 0)])
	options.append_array(level_up_options)
	
	var swap_options = _evaluate_creature_swap(context)
	print("[CPUTerritoryAI] 交換オプション: %d件" % swap_options.size())
	options.append_array(swap_options)
	
	var element_options = _evaluate_element_change(context)
	print("[CPUTerritoryAI] 属性変更オプション: %d件" % element_options.size())
	options.append_array(element_options)
	
	print("[CPUTerritoryAI] 合計オプション: %d件" % options.size())
	
	var best = _get_best_option(options)
	print("[CPUTerritoryAI] best_option: %s" % best)
	
	return best


## 危機モード判定
func is_crisis_mode(context: Dictionary) -> bool:
	var current_magic = context.get("current_magic", 0)
	var toll = context.get("toll", 0)
	return (current_magic - toll) < CRISIS_MODE_THRESHOLD


## 危機モード用レベルアップ評価
func evaluate_crisis_level_up(context: Dictionary) -> Dictionary:
	var player_id = context.get("player_id", -1)
	var current_magic = context.get("current_magic", 0)
	var toll = context.get("toll", 0)
	var remaining_magic = current_magic - toll
	
	if remaining_magic <= 0:
		return {}
	
	# 最大連鎖数の属性を特定
	var best_chain_info = _get_best_chain_element(player_id)
	if best_chain_info.is_empty():
		return {}
	
	var best_element = best_chain_info.get("element", "")
	
	# その属性の土地を取得
	var target_lands = _get_own_lands_by_element(player_id, best_element)
	
	for land in target_lands:
		if land.level >= 5:
			continue
		if land.is_downed:
			continue
		if not land.element_match:
			continue
		
		var max_level = _get_max_affordable_level(land.tile_index, land.level, remaining_magic)
		
		if max_level > land.level:
			return {
				"type": "level_up",
				"tile_index": land.tile_index,
				"target_level": max_level,
				"score": CRISIS_MODE_SCORE
			}
	
	return {}


# === 個別評価関数 ===

## 侵略評価（敵ドミニオに止まった場合）
func _evaluate_invasion(context: Dictionary) -> Array:
	var options: Array = []
	
	var tile_index = context.get("current_tile_index", -1)
	var player_id = context.get("player_id", -1)
	
	if tile_index < 0 or player_id < 0:
		return options
	
	var tile = _get_tile(tile_index)
	if tile == null:
		return options
	
	# 敵ドミニオでない場合はスキップ
	if tile.owner_id == -1 or tile.owner_id == player_id:
		return options
	
	# クリーチャーがいない場合はスキップ
	if tile.creature_data.is_empty():
		return options
	
	# 戦闘可能か判定（BattleSimulator使用）
	var can_win = _can_win_battle(context, tile_index)
	if not can_win:
		return options
	
	# スコア計算
	var chain_bonus = board_system.tile_data_manager.calculate_chain_bonus(tile_index, tile.owner_id)
	var level = tile.level
	var element_match = _is_element_match_for_invasion(context, tile)
	
	var base_score = level * chain_bonus * 100
	if element_match:
		base_score += INVASION_ELEMENT_MATCH_BONUS
	
	var score = base_score * INVASION_ASSET_MULTIPLIER
	
	options.append({
		"type": "invasion",
		"tile_index": tile_index,
		"score": score
	})
	
	return options


## 移動侵略評価
func _evaluate_move_invasion(context: Dictionary) -> Array:
	var options: Array = []
	
	var player_id = context.get("player_id", -1)
	
	# 自分のドミニオでダウンしていないクリーチャーを取得
	var own_lands = _get_own_lands(player_id)
	
	for land in own_lands:
		if land.is_downed:
			continue
		
		# === 移動禁止条件 ===
		# 1. レベル2以上の土地からは移動させない
		if land.level >= 2:
			continue
		
		# 2. 属性一致している土地からは移動させない
		if land.element_match:
			continue
		
		# 移動可能先を取得
		var destinations = MovementHelper.get_move_destinations(
			board_system,
			land.creature_data,
			land.tile_index
		)
		
		for dest_index in destinations:
			var dest_tile = _get_tile(dest_index)
			if dest_tile == null:
				continue
			
			var option = _evaluate_move_destination(context, land, dest_tile)
			if not option.is_empty():
				options.append(option)
	
	return options


## 移動先の評価
func _evaluate_move_destination(context: Dictionary, from_land: Dictionary, dest_tile) -> Dictionary:
	var player_id = context.get("player_id", -1)
	var creature_element = from_land.creature_data.get("element", "")
	
	# 空き地の場合
	if dest_tile.owner_id == -1:
		return _evaluate_move_to_vacant(from_land, dest_tile, player_id, creature_element)
	
	# 敵ドミニオの場合
	if dest_tile.owner_id != player_id:
		return _evaluate_move_to_enemy(context, from_land, dest_tile, creature_element)
	
	return {}


## 空き地への移動評価
func _evaluate_move_to_vacant(from_land: Dictionary, dest_tile, player_id: int, creature_element: String) -> Dictionary:
	var dest_element = dest_tile.tile_type
	
	# 配置制限チェック
	var land_info = {
		"tile_index": dest_tile.tile_index,
		"tile_element": dest_element,
		"owner": -1
	}
	if not _can_place_creature(from_land.creature_data, land_info, player_id):
		return {}
	
	# 属性一致チェック
	var element_match = (creature_element == dest_element) or (dest_element == "neutral")
	if not element_match:
		return {}
	
	# 連鎖数を計算（移動後）
	var chain_count = _calculate_potential_chain_count(dest_tile.tile_index, player_id, creature_element)
	
	var score = MOVE_ELEMENT_MATCH_BONUS + (chain_count * MOVE_CHAIN_MULTIPLIER)
	
	return {
		"type": "move_invasion",
		"from_tile_index": from_land.tile_index,
		"to_tile_index": dest_tile.tile_index,
		"target_type": "vacant",
		"score": score
	}


## 敵ドミニオへの移動評価
func _evaluate_move_to_enemy(context: Dictionary, from_land: Dictionary, dest_tile, creature_element: String) -> Dictionary:
	# クリーチャーがいない場合はスキップ
	if dest_tile.creature_data.is_empty():
		return {}
	
	# 配置制限チェック
	var player_id = context.get("player_id", -1)
	var land_info = {
		"tile_index": dest_tile.tile_index,
		"tile_element": dest_tile.tile_type,
		"owner": dest_tile.owner_id
	}
	if not _can_place_creature(from_land.creature_data, land_info, player_id):
		return {}
	
	# 戦闘シミュレーション（アイテム込み）
	var battle_result = _evaluate_move_battle(from_land, dest_tile, player_id)
	if not battle_result.can_win:
		return {}
	
	# スコア計算
	var chain_bonus = board_system.tile_data_manager.calculate_chain_bonus(dest_tile.tile_index, dest_tile.owner_id)
	var level = dest_tile.level
	var dest_element = dest_tile.tile_type
	var element_match = (creature_element == dest_element) or (dest_element == "neutral")
	
	var score = level * chain_bonus * 100
	if element_match:
		score += INVASION_ELEMENT_MATCH_BONUS
	
	var result = {
		"type": "move_invasion",
		"from_tile_index": from_land.tile_index,
		"to_tile_index": dest_tile.tile_index,
		"target_type": "enemy",
		"score": score
	}
	
	# アイテム情報を追加
	if battle_result.item_index >= 0:
		result["item_index"] = battle_result.item_index
		result["item_data"] = battle_result.item_data
	
	return result


## レベルアップ評価
func _evaluate_level_up(context: Dictionary) -> Array:
	var options: Array = []
	
	var player_id = context.get("player_id", -1)
	var current_magic = context.get("current_magic", 0)
	
	# 使用可能EPを計算（30%または100EPは残す）
	var available_magic = _calculate_available_magic(current_magic)
	
	var own_lands = _get_own_lands(player_id)
	
	for land in own_lands:
		if land.is_downed:
			continue
		if land.level >= 5:
			continue
		# 属性一致していない場合はスキップ
		if not land.element_match:
			continue
		
		# 使用可能EPで上げられる最大レベルと合計コストを計算
		var result = _calculate_affordable_level_up(land.tile_index, land.level, available_magic)
		var max_level = result.max_level
		var total_cost = result.total_cost
		
		if max_level <= land.level:
			continue
		
		# スコア = 手持ちEPで上げられる分の合計コスト
		var score = total_cost
		
		options.append({
			"type": "level_up",
			"tile_index": land.tile_index,
			"target_level": max_level,
			"cost": total_cost,
			"score": score
		})
	
	return options


## 手持ちEPで上げられる最大レベルと合計コストを計算（動的計算）
func _calculate_affordable_level_up(tile_index: int, current_level: int, magic: int) -> Dictionary:
	var max_level = current_level
	var total_cost = 0
	var remaining_magic = magic
	
	for target_level in range(current_level + 1, 6):  # 現在+1 〜 5
		# calculate_level_up_costは「タイルの現在レベルから目標レベルへの差分コスト」を返す
		var cost = board_system.tile_data_manager.calculate_level_up_cost(tile_index, target_level)
		
		if cost <= remaining_magic:
			max_level = target_level
			total_cost = cost  # 差分コストをそのまま使う
			remaining_magic = magic - cost  # 残りEPも累計から計算
		else:
			break
	
	return {
		"max_level": max_level,
		"total_cost": total_cost
	}


## クリーチャー交換評価
func _evaluate_creature_swap(context: Dictionary) -> Array:
	var options: Array = []
	
	var player_id = context.get("player_id", -1)
	var hand_creatures = _get_hand_creatures(player_id)
	
	print("[CPUTerritoryAI] 交換評価: 手札クリーチャー数=%d" % hand_creatures.size())
	
	if hand_creatures.is_empty():
		return options
	
	var own_lands = _get_own_lands(player_id)
	print("[CPUTerritoryAI] 交換評価: 自ドミニオ数=%d" % own_lands.size())
	
	for land in own_lands:
		print("[CPUTerritoryAI] 交換評価: tile=%d, downed=%s" % [land.tile_index, land.is_downed])
		if land.is_downed:
			continue
		
		var current_creature = land.creature_data
		var land_element = land.tile_element
		var current_element = current_creature.get("element", "")
		var current_match = (current_element == land_element) or (land_element == "neutral")
		
		# アルカナアーツ持ちは交換対象外
		if _has_mystic_arts(current_creature):
			print("[CPUTerritoryAI] 交換評価: %s はアルカナアーツ持ちのため交換対象外" % current_creature.get("name", "?"))
			continue
		
		# 現在のクリーチャーのレートを取得
		var current_rate = CardRateEvaluator.get_rate(current_creature)
		
		for hand_creature in hand_creatures:
			# hand_creatureがDictionaryでない場合はスキップ
			if typeof(hand_creature) != TYPE_DICTIONARY:
				continue
			
			# 召喚条件チェック
			if not _can_place_creature(hand_creature, land, player_id):
				print("[CPUTerritoryAI] 交換評価: %s は配置条件を満たさない" % hand_creature.get("name", "?"))
				continue
			
			var new_rate = CardRateEvaluator.get_rate(hand_creature)
			var new_element = hand_creature.get("element", "")
			var new_match = (new_element == land_element) or (land_element == "neutral")
			
			# スコア計算（コスト差→レート差に変更）
			var rate_diff = new_rate - current_rate
			var element_bonus = 0
			
			if new_match and not current_match:
				element_bonus = SWAP_ELEMENT_MATCH_BONUS
			elif not new_match and current_match:
				element_bonus = SWAP_ELEMENT_MISMATCH_PENALTY
			
			var score = (rate_diff * SWAP_RATE_MULTIPLIER) + element_bonus + (land.level * SWAP_LEVEL_MULTIPLIER)
			
			# 最低スコア閾値チェック
			if score < SWAP_MIN_SCORE_THRESHOLD:
				print("[CPUTerritoryAI] 交換評価: %s → %s スコア%d < 閾値%d でスキップ" % [
					current_creature.get("name", "?"), hand_creature.get("name", "?"), score, SWAP_MIN_SCORE_THRESHOLD])
				continue
			
			print("[CPUTerritoryAI] 交換候補: %s(rate:%d) → %s(rate:%d), スコア:%d" % [
				current_creature.get("name", "?"), current_rate,
				hand_creature.get("name", "?"), new_rate, score])
			
			options.append({
				"type": "creature_swap",
				"tile_index": land.tile_index,
				"hand_index": hand_creature.get("hand_index", -1),
				"score": score
			})
	
	return options


## 属性変更評価
func _evaluate_element_change(context: Dictionary) -> Array:
	var options: Array = []
	
	var player_id = context.get("player_id", -1)
	var current_magic = context.get("current_magic", 0)
	
	# 使用可能EPを計算（30%または100EPは残す）
	var available_magic = _calculate_available_magic(current_magic)
	
	var own_lands = _get_own_lands(player_id)
	
	for land in own_lands:
		if land.is_downed:
			continue
		# 既に属性一致している場合はスキップ
		if land.element_match:
			continue
		
		var cost = board_system.calculate_terrain_change_cost(land.tile_index)
		if cost < 0 or cost > available_magic:
			continue
		
		var is_neutral = (land.tile_element == "neutral" or land.tile_element == "")
		
		var score = ELEMENT_CHANGE_BASE_SCORE
		if is_neutral:
			score += ELEMENT_CHANGE_NEUTRAL_BONUS
		score -= cost * ELEMENT_CHANGE_COST_MULTIPLIER
		
		var creature_element = land.creature_data.get("element", "")
		
		# 無属性クリーチャーの場合は属性変更しない（無属性への変更は無意味）
		if creature_element.is_empty() or creature_element == "neutral":
			continue
		
		options.append({
			"type": "element_change",
			"tile_index": land.tile_index,
			"new_element": creature_element,
			"cost": cost,
			"score": score
		})
	
	return options


# === ヘルパー関数 ===

## コスト値を取得（Dictionaryの場合はmpを取得）
func _get_cost_value(cost) -> int:
	if typeof(cost) == TYPE_DICTIONARY:
		return cost.get("ep", 0)
	return int(cost)

## 使用可能EPを計算（30%または100EPは残す）
func _calculate_available_magic(current_magic: int) -> int:
	var reserve = max(current_magic * MAGIC_RESERVE_RATIO, MAGIC_RESERVE_MINIMUM)
	return max(0, current_magic - int(reserve))

## 最高スコアのオプションを返す
func _get_best_option(options: Array) -> Dictionary:
	if options.is_empty():
		return {}
	
	var best_option = options[0]
	for option in options:
		if option.get("score", 0) > best_option.get("score", 0):
			best_option = option
	
	return best_option


## タイルを取得
func _get_tile(tile_index: int):
	if board_system == null:
		return null
	if not board_system.tile_nodes.has(tile_index):
		return null
	return board_system.tile_nodes[tile_index]


## 自分のドミニオ一覧を取得
func _get_own_lands(player_id: int) -> Array:
	var lands: Array = []
	
	if board_system == null:
		return lands
	
	for tile_index in board_system.tile_nodes:
		var tile = board_system.tile_nodes[tile_index]
		if tile.owner_id != player_id:
			continue
		if tile.creature_data.is_empty():
			continue
		
		var creature_element = tile.creature_data.get("element", "")
		var tile_element = tile.tile_type
		var element_match = (creature_element == tile_element)
		
		# ダウン状態はタイルのメソッドで確認
		var is_downed = tile.is_down() if tile.has_method("is_down") else false
		
		lands.append({
			"tile_index": tile_index,
			"level": tile.level,
			"tile_element": tile_element,
			"creature_data": tile.creature_data,
			"element_match": element_match,
			"is_downed": is_downed
		})
	
	return lands


## 特定属性の自分のドミニオを取得
func _get_own_lands_by_element(player_id: int, element: String) -> Array:
	var all_lands = _get_own_lands(player_id)
	var filtered: Array = []
	
	for land in all_lands:
		if land.tile_element == element:
			filtered.append(land)
	
	return filtered


## 最大連鎖数の属性を取得
func _get_best_chain_element(player_id: int) -> Dictionary:
	if board_system == null:
		return {}
	
	var element_counts: Dictionary = {}
	
	for tile_index in board_system.tile_nodes:
		var tile = board_system.tile_nodes[tile_index]
		if tile.owner_id != player_id:
			continue
		
		var element = tile.tile_type
		if not TileHelper.is_element_type(element):
			continue
		
		if not element_counts.has(element):
			element_counts[element] = 0
		element_counts[element] += 1
	
	if element_counts.is_empty():
		return {}
	
	var best_element = ""
	var best_count = 0
	
	for element in element_counts:
		if element_counts[element] > best_count:
			best_count = element_counts[element]
			best_element = element
	
	return {
		"element": best_element,
		"count": best_count
	}


## 残りEPで上げられる最大レベルを計算
func _get_max_affordable_level(tile_index: int, current_level: int, magic: int) -> int:
	var max_level = current_level
	
	for target_level in range(current_level + 1, 6):
		var cost = board_system.tile_data_manager.calculate_level_up_cost(tile_index, target_level)
		if cost <= magic:
			max_level = target_level
		else:
			break
	
	return max_level


## 手札のクリーチャーを取得
func _get_hand_creatures(player_id: int) -> Array:
	var creatures: Array = []
	
	if card_system == null:
		return creatures
	
	var hand_size = card_system.get_hand_size_for_player(player_id)
	print("[CPUTerritoryAI] _get_hand_creatures: hand_size=%d" % hand_size)
	
	for i in range(hand_size):
		var card = card_system.get_card_data_for_player(player_id, i)
		var card_type = card.get("card_type", card.get("type", ""))
		var rate = CardRateEvaluator.get_rate(card)
		print("[CPUTerritoryAI]   - %s (card_type=%s, type=%s, rate=%d)" % [card.get("name", "?"), card.get("card_type", "N/A"), card.get("type", "N/A"), rate])
		if card_type == "creature":
			card["hand_index"] = i
			creatures.append(card)
	
	return creatures


## クリーチャーを配置可能かチェック（召喚条件）
## player_id: チェック対象のプレイヤーID
## _land: 配置先の土地情報（空き地の場合owner=-1）
func _can_place_creature(creature_data: Dictionary, _land: Dictionary, player_id: int = -1) -> bool:
	# player_idが指定されていなければ_landのownerを使用
	var check_player_id = player_id if player_id >= 0 else _land.get("owner", -1)
	
	# cannot_summon チェック（配置制限）
	if tile_action_processor and not tile_action_processor.debug_disable_cannot_summon:
		var tile_element = _land.get("tile_element", _land.get("element", ""))
		var cannot_summon_result = tile_action_processor.check_cannot_summon(creature_data, tile_element)
		if not cannot_summon_result.passed:
			return false
	
	# cost_lands_required チェック（TileActionProcessorの機能を使用）
	if creature_data.has("cost_lands_required"):
		var required_lands = creature_data.get("cost_lands_required", [])
		if not required_lands.is_empty():
			# ブライトワールドまたはリリース呪い発動中は召喚条件を無視
			if _is_summon_condition_ignored(check_player_id):
				pass  # 条件チェックをスキップ
			elif tile_action_processor and check_player_id >= 0:
				var check_result = tile_action_processor.check_lands_required(creature_data, check_player_id)
				if not check_result.passed:
					return false
			else:
				# tile_action_processorがない場合は簡易チェック
				if check_player_id < 0:
					return true  # player_idが不明な場合は一旦許可
				if not _check_lands_required_simple(creature_data, check_player_id):
					return false
	
	# cost_cards_sacrifice チェック
	if creature_data.has("cost_cards_sacrifice") and creature_data.get("cost_cards_sacrifice", 0) > 0:
		# ブライトワールドまたはリリース呪い発動中は召喚条件を無視
		if _is_summon_condition_ignored(check_player_id):
			pass  # 条件チェックをスキップ
		else:
			# 犠牲カードが選択可能かチェック
			if not sacrifice_selector:
				return false
			if check_player_id < 0:
				return true  # player_idが不明な場合は一旦許可
			var sacrifice_result = sacrifice_selector.select_sacrifice_for_creature(creature_data, check_player_id, _land.get("element", ""))
			if sacrifice_result.card.is_empty():
				return false
	
	return true


## ブライトワールド（召喚条件解除）が発動中か
func _is_summon_condition_ignored(player_id: int = -1) -> bool:
	var gfm = tile_action_processor.game_flow_manager if tile_action_processor else null
	return SummonConditionChecker.is_summon_condition_ignored(player_id, gfm, board_system)


## 簡易土地条件チェック（tile_action_processorがない場合のフォールバック）
func _check_lands_required_simple(creature_data: Dictionary, player_id: int) -> bool:
	var required_lands = creature_data.get("cost_lands_required", [])
	if required_lands.is_empty():
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
	for element in required_lands:
		required_elements[element] = required_elements.get(element, 0) + 1
	
	# 各属性の条件を満たしているかチェック
	for element in required_elements.keys():
		var required_count = required_elements[element]
		var owned_count = owned_elements.get(element, 0)
		if owned_count < required_count:
			return false
	
	return true


## 侵略時の属性一致チェック
func _is_element_match_for_invasion(_ctx: Dictionary, _tile) -> bool:
	# 攻撃側クリーチャーの属性と土地属性の一致をチェック
	# TODO: 攻撃クリーチャーを特定して判定
	return false


## アルカナアーツ持ちかどうかをチェック
func _has_mystic_arts(creature_data: Dictionary) -> bool:
	# トップレベルのmystic_artsをチェック
	if creature_data.has("mystic_arts") and creature_data.get("mystic_arts") != null:
		return true
	
	# ability_parsed.mystic_artsをチェック
	var ability_parsed = creature_data.get("ability_parsed", {})
	if ability_parsed and ability_parsed.has("mystic_arts"):
		var mystic_arts = ability_parsed.get("mystic_arts", [])
		if not mystic_arts.is_empty():
			return true
	
	# keywordsにアルカナアーツがあるかチェック
	if ability_parsed:
		var keywords = ability_parsed.get("keywords", [])
		if "アルカナアーツ" in keywords:
			return true
	
	return false


## 戦闘に勝てるか判定（敵ドミニオに止まった場合）
func _can_win_battle(context: Dictionary, tile_index: int) -> bool:
	if battle_simulator == null:
		return false
	
	var player_id = context.get("player_id", -1)
	var attacker_creatures = _get_hand_creatures(player_id)
	
	var tile = _get_tile(tile_index)
	if tile == null:
		return false
	
	var defender_data = tile.creature_data
	if defender_data.is_empty():
		return true
	
	var tile_info = {
		"index": tile_index,
		"element": tile.tile_type,
		"level": tile.level
	}
	
	# 手札のクリーチャーで勝てるか判定
	for creature in attacker_creatures:
		var result = battle_simulator.simulate_battle(
			creature,
			defender_data,
			tile_info,
			player_id
		)
		if result.get("result") == BattleSimulator.BattleResult.ATTACKER_WIN:
			return true
	
	return false


## 移動侵略時に勝てるか判定し、使用するアイテム情報も返す
## CPUBattleAI.evaluate_single_creature_battle を使用（共通ロジック）
## @return Dictionary: {can_win: bool, item_index: int, item_data: Dictionary}
func _evaluate_move_battle(from_land: Dictionary, dest_tile, player_id: int) -> Dictionary:
	var result_data = {
		"can_win": false,
		"item_index": -1,
		"item_data": {}
	}
	
	# battle_aiの共通メソッドを使用
	if battle_ai != null:
		var tile_info = {
			"index": dest_tile.tile_index,
			"element": dest_tile.tile_type,
			"level": dest_tile.level,
			"owner": dest_tile.owner_id
		}
		
		var eval_result = battle_ai.evaluate_single_creature_battle(
			from_land.creature_data,
			dest_tile.creature_data,
			tile_info,
			player_id
		)
		
		result_data.can_win = eval_result.can_win
		result_data.item_index = eval_result.item_index
		result_data.item_data = eval_result.item_data
		# 即死ギャンブルも考慮
		if not result_data.can_win and eval_result.get("is_instant_death_gamble", false):
			var probability = eval_result.get("instant_death_probability", 0)
			if probability >= 50:
				result_data.can_win = true  # ギャンブルで勝てる可能性
				result_data["is_instant_death_gamble"] = true
				result_data["instant_death_probability"] = probability
		return result_data
	
	# フォールバック: battle_aiがない場合は単純シミュレーション
	if battle_simulator == null:
		return result_data
	
	var defender_data = dest_tile.creature_data
	if defender_data.is_empty():
		result_data.can_win = true
		return result_data
	
	var fallback_tile_info = {
		"index": dest_tile.tile_index,
		"element": dest_tile.tile_type,
		"level": dest_tile.level,
		"owner": dest_tile.owner_id
	}
	
	var sim_result = battle_simulator.simulate_battle(
		from_land.creature_data,
		defender_data,
		fallback_tile_info,
		player_id
	)
	
	if sim_result.get("result") == BattleSimulator.BattleResult.ATTACKER_WIN:
		result_data.can_win = true
	
	return result_data


## 手札のアイテムを取得
func _get_hand_items(player_id: int) -> Array:
	if card_system == null:
		return []
	
	var items = []
	var hand = card_system.get_all_cards_for_player(player_id)
	
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("type", "") == "item":
			items.append({"index": i, "data": card})
	
	return items


## 移動後の連鎖数を計算
func _calculate_potential_chain_count(tile_index: int, player_id: int, element: String) -> int:
	if board_system == null:
		return 1
	
	# 同じプレイヤーの同属性タイル数をカウント
	var count = 1  # 移動先自体
	
	for i in board_system.tile_nodes:
		if i == tile_index:
			continue
		var tile = board_system.tile_nodes[i]
		if tile.owner_id == player_id and tile.tile_type == element:
			count += 1
	
	return count
