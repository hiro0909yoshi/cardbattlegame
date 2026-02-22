class_name CPUTileActionExecutor
extends RefCounted
## CPUのタイルアクション実行処理
##
## TileActionProcessorからCPU専用の実行ロジックを分離
## - 召喚実行（条件チェック、犠牲処理、合成処理）
## - バトル実行（アイテム選択、合体処理）
## - 犠牲カード自動選択


# ============================================================
# システム参照
# ============================================================

var tile_action_processor = null  # 親プロセッサー参照
var board_system: BoardSystem3D = null
var player_system: PlayerSystem = null
var card_system: CardSystem = null
var game_flow_manager = null
var creature_synthesis: CreatureSynthesis = null
var sacrifice_selector: CPUSacrificeSelector = null

# === 直接参照（GFM経由を廃止） ===
var spell_cost_modifier = null  # SpellCostModifier: コスト計算


# ============================================================
# 初期化
# ============================================================

func initialize(processor) -> void:
	tile_action_processor = processor
	_sync_references()


func _sync_references() -> void:
	"""親プロセッサーから参照を同期"""
	if not tile_action_processor:
		return

	board_system = tile_action_processor.board_system
	player_system = tile_action_processor.player_system
	card_system = tile_action_processor.card_system
	game_flow_manager = tile_action_processor.game_flow_manager
	creature_synthesis = tile_action_processor.creature_synthesis
	sacrifice_selector = tile_action_processor.sacrifice_selector
	# 直接参照も同期
	spell_cost_modifier = tile_action_processor.spell_cost_modifier


# ============================================================
# 召喚実行
# ============================================================

## CPU用召喚実行
## 戻り値: Dictionary {success: bool, card_data: Dictionary, cost: int}
func prepare_summon(card_index: int, player_id: int) -> Dictionary:
	_sync_references()
	
	if card_index < 0:
		return {"success": false, "reason": "invalid_index"}
	
	var card_data = card_system.get_card_data_for_player(player_id, card_index)
	if card_data.is_empty():
		return {"success": false, "reason": "card_not_found"}
	
	var target_tile = board_system.get_player_tile(player_id)
	var tile = board_system.tile_nodes.get(target_tile)
	
	# 配置可能タイルかチェック
	if tile and not tile.can_place_creature():
		return {"success": false, "reason": "cannot_place"}
	
	# 堅守チェック: 空き地以外には召喚できない
	var creature_type = card_data.get("creature_type", "normal")
	if creature_type == "defensive":
		var tile_info = board_system.get_tile_info(target_tile)
		if tile_info["owner"] != -1:
			return {"success": false, "reason": "defensive_not_empty"}
	
	# 土地条件チェック
	if not _is_condition_check_disabled("lands_required"):
		var check_result = tile_action_processor.check_lands_required(card_data, player_id)
		if not check_result.passed:
			return {"success": false, "reason": "lands_required", "message": check_result.message}
	
	# タイル属性を取得
	var tile_element = tile.tile_type if tile and "tile_type" in tile else ""
	
	# 配置制限チェック（cannot_summon）
	if not _is_condition_check_disabled("cannot_summon"):
		var cannot_result = tile_action_processor.check_cannot_summon(card_data, tile_element)
		if not cannot_result.passed:
			return {"success": false, "reason": "cannot_summon", "message": cannot_result.message}
	
	# カード犠牲処理
	var sacrifice_card = {}
	if _requires_card_sacrifice(card_data) and not _is_condition_check_disabled("card_sacrifice"):
		sacrifice_card = select_sacrifice_card(player_id, card_data, tile_element)
		if sacrifice_card.is_empty():
			return {"success": false, "reason": "no_sacrifice"}
	
	# クリーチャー合成処理
	var is_synthesized = false
	if not sacrifice_card.is_empty() and creature_synthesis:
		is_synthesized = creature_synthesis.check_condition(card_data, sacrifice_card)
		if is_synthesized:
			card_data = creature_synthesis.apply_synthesis(card_data, sacrifice_card, true)
			print("[CPUTileActionExecutor] 合成成立: %s" % card_data.get("name", "?"))
	
	# コスト計算
	var cost = _calculate_cost(card_data, player_id)
	
	# EPチェック
	var current_magic = player_system.get_magic(player_id)
	if current_magic < cost:
		return {"success": false, "reason": "insufficient_magic"}
	
	return {
		"success": true,
		"card_data": card_data,
		"card_index": card_index,
		"cost": cost,
		"target_tile": target_tile,
		"is_synthesized": is_synthesized
	}


## CPU召喚を実行
func execute_summon(prep: Dictionary, player_id: int) -> bool:
	if not prep.get("success", false):
		return false
	
	var card_data = prep.get("card_data", {})
	var card_index = prep.get("card_index", -1)
	var cost = prep.get("cost", 0)
	var target_tile = prep.get("target_tile", -1)
	
	# カード使用とEP消費
	card_system.use_card_for_player(player_id, card_index)
	player_system.add_magic(player_id, -cost)
	
	# 土地取得とクリーチャー配置
	board_system.set_tile_owner(target_tile, player_id)
	board_system.place_creature(target_tile, card_data)
	
	# ダウン状態設定（奮闘チェック）
	var tile = board_system.tile_nodes.get(target_tile)
	if tile and tile.has_method("set_down_state"):
		if not PlayerBuffSystem.has_unyielding(card_data):
			tile.set_down_state(true)
	
	print("[CPUTileActionExecutor] 召喚成功: %s" % card_data.get("name", "?"))
	return true


# ============================================================
# バトル実行
# ============================================================

## CPU用バトル準備
## 戻り値: Dictionary {success: bool, card_data: Dictionary, cost: int, item_data: Dictionary}
func prepare_battle(card_index: int, tile_info: Dictionary, item_index: int, player_id: int) -> Dictionary:
	_sync_references()
	
	if card_index < 0:
		return {"success": false, "reason": "invalid_index"}
	
	var card_data = card_system.get_card_data_for_player(player_id, card_index)
	if card_data.is_empty():
		return {"success": false, "reason": "card_not_found"}
	
	# 土地条件チェック
	if not _is_condition_check_disabled("lands_required"):
		var check_result = tile_action_processor.check_lands_required(card_data, player_id)
		if not check_result.passed:
			return {"success": false, "reason": "lands_required", "message": check_result.message}
	
	# カード犠牲処理用の属性を先に取得
	var tile_element = tile_info.get("element", "")
	
	# 配置制限チェック
	if not _is_condition_check_disabled("cannot_summon"):
		var cannot_result = tile_action_processor.check_cannot_summon(card_data, tile_element)
		if not cannot_result.passed:
			return {"success": false, "reason": "cannot_summon", "message": cannot_result.message}
	
	# カード犠牲処理
	var sacrifice_card = {}
	if _requires_card_sacrifice(card_data) and not _is_condition_check_disabled("card_sacrifice"):
		sacrifice_card = select_sacrifice_card(player_id, card_data, tile_element)
		if sacrifice_card.is_empty():
			return {"success": false, "reason": "no_sacrifice"}
	
	# クリーチャー合成処理
	var is_synthesized = false
	if not sacrifice_card.is_empty() and creature_synthesis:
		is_synthesized = creature_synthesis.check_condition(card_data, sacrifice_card)
		if is_synthesized:
			card_data = creature_synthesis.apply_synthesis(card_data, sacrifice_card, true)
			print("[CPUTileActionExecutor] 合成成立: %s" % card_data.get("name", "?"))
	
	# アイテムデータ取得
	var item_data = {}
	if item_index >= 0:
		item_data = card_system.get_card_data_for_player(player_id, item_index)
		if not item_data.is_empty():
			item_data = item_data.duplicate()
			item_data["_hand_index"] = item_index
	
	# コスト計算
	var cost = _calculate_cost(card_data, player_id)
	
	# EPチェック
	var current_magic = player_system.get_magic(player_id)
	if current_magic < cost:
		return {"success": false, "reason": "insufficient_magic"}
	
	return {
		"success": true,
		"card_data": card_data,
		"card_index": card_index,
		"cost": cost,
		"item_data": item_data,
		"tile_info": tile_info,
		"is_synthesized": is_synthesized
	}


# ============================================================
# 犠牲カード選択
# ============================================================

## CPU用犠牲カード自動選択
func select_sacrifice_card(player_id: int, creature_card: Dictionary, tile_element: String = "") -> Dictionary:
	# CPUSacrificeSelectorを初期化
	if not sacrifice_selector:
		sacrifice_selector = CPUSacrificeSelector.new()
		sacrifice_selector.initialize(card_system, board_system)
		if creature_synthesis:
			sacrifice_selector.creature_synthesis = creature_synthesis
	
	# 犠牲カードを選択
	var result = sacrifice_selector.select_sacrifice_for_creature(creature_card, player_id, tile_element)
	var sacrifice_card = result.get("card", {})
	
	if sacrifice_card.is_empty():
		print("[CPUTileActionExecutor] 犠牲カードが選択できませんでした")
		return {}
	
	# カードを破棄（インデックスを探して破棄）
	var hand = card_system.get_all_cards_for_player(player_id)
	for i in range(hand.size()):
		if hand[i].get("id") == sacrifice_card.get("id"):
			card_system.discard_card(player_id, i, "sacrifice")
			print("[CPUTileActionExecutor] %s を犠牲にしました" % sacrifice_card.get("name", "?"))
			break
	
	return sacrifice_card


# ============================================================
# ヘルパー
# ============================================================

## カード犠牲が必要か判定（SummonConditionCheckerに委譲）
func _requires_card_sacrifice(card_data: Dictionary) -> bool:
	return SummonConditionChecker.requires_card_sacrifice(card_data)


## コスト計算（エンジェルギフト刻印対応）
func _calculate_cost(card_data: Dictionary, player_id: int) -> int:
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)
	else:
		cost = cost_data
	
	# エンジェルギフト刻印チェック
	if spell_cost_modifier:
		cost = spell_cost_modifier.get_modified_cost(player_id, card_data)
	
	return cost


## 条件チェックが無効化されているか
func _is_condition_check_disabled(check_type: String) -> bool:
	if not tile_action_processor:
		return false
	
	# 召喚条件無視バフをチェック（SummonConditionChecker経由）
	if SummonConditionChecker.is_summon_condition_ignored(-1, game_flow_manager, board_system):
		return true
	
	match check_type:
		"card_sacrifice":
			return tile_action_processor.debug_disable_card_sacrifice
		"lands_required":
			return tile_action_processor.debug_disable_lands_required
		"cannot_summon":
			return tile_action_processor.debug_disable_cannot_summon
		_:
			return false
