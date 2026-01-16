# CPU防御時評価システム
# 敵の対抗手段（アイテム・援護）を考慮したワーストケースシミュレーションを担当
#
# 機能:
# - ワーストケースシミュレーション
# - 対抗アイテム検索
# - 敵援護の考慮
#
# 使用例:
#   var evaluator = CPUBattleDefenseEvaluator.new()
#   evaluator.setup(battle_simulator, hand_utils, tile_action_processor, player_system)
#   var result = evaluator.simulate_worst_case(attacker, defender, tile_info, player_id)
extends RefCounted
class_name CPUBattleDefenseEvaluator

# システム参照
var _battle_simulator: BattleSimulator = null
var _hand_utils: CPUHandUtils = null
var _tile_action_processor = null
var _player_system: PlayerSystem = null


## セットアップ
func setup(battle_simulator: BattleSimulator, hand_utils: CPUHandUtils, 
		tile_action_processor = null, player_system: PlayerSystem = null) -> void:
	_battle_simulator = battle_simulator
	_hand_utils = hand_utils
	_tile_action_processor = tile_action_processor
	_player_system = player_system


## 敵の対抗手段（アイテム・援護）を考慮したワーストケースシミュレーション
## @param attacker: 攻撃側クリーチャー
## @param defender: 防御側クリーチャー
## @param tile_info: タイル情報
## @param attacker_player_id: 攻撃側プレイヤーID
## @param attacker_item: 攻撃側アイテム（空の場合あり）
## @return: ワーストケースのシミュレーション結果
func simulate_worst_case(
	attacker: Dictionary,
	defender: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	attacker_item: Dictionary = {}
) -> Dictionary:
	var defender_owner = tile_info.get("owner", -1)
	
	if defender_owner < 0 or not _hand_utils:
		# 敵情報がない場合は通常シミュレーション
		return _simulate_base(attacker, defender, tile_info, attacker_player_id, attacker_item)
	
	print("[CPU攻撃] ワーストケース分析開始")
	
	# 敵の対抗手段を収集
	var enemy_items = _hand_utils.get_enemy_items(defender_owner)
	var enemy_assists = _hand_utils.get_enemy_assist_creatures(defender_owner, defender)
	
	print("[CPU攻撃] 敵の対抗手段: アイテム%d個, 援護%d体" % [enemy_items.size(), enemy_assists.size()])
	
	# まず何もない場合のシミュレーション
	var base_result = _simulate_with_defender_option(attacker, defender, tile_info, attacker_player_id, attacker_item, {}, {})
	
	# 対抗手段がない場合はそのまま返す
	if enemy_items.is_empty() and enemy_assists.is_empty():
		return base_result
	
	# ワーストケースを探す
	var worst_result = base_result
	var worst_option_name = "なし"
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = _tile_action_processor and _tile_action_processor.debug_disable_cannot_use
	
	# 敵アイテムをすべて試す
	for enemy_item in enemy_items:
		# 防御側クリーチャーのcannot_use制限をチェック（リリース呪いで解除可能）
		if not disable_cannot_use and not _is_item_restriction_released(defender_owner):
			var check_result = ItemUseRestriction.check_can_use(defender, enemy_item)
			if not check_result.can_use:
				continue
		
		var result = _simulate_with_defender_option(attacker, defender, tile_info, attacker_player_id, attacker_item, enemy_item, {})
		if _is_worse_result(result, worst_result):
			worst_result = result
			worst_option_name = "アイテム: " + enemy_item.get("name", "?")
	
	# 敵援護をすべて試す
	for enemy_assist in enemy_assists:
		var result = _simulate_with_defender_option(attacker, defender, tile_info, attacker_player_id, attacker_item, {}, enemy_assist)
		if _is_worse_result(result, worst_result):
			worst_result = result
			worst_option_name = "援護: " + enemy_assist.get("name", "?")
	
	print("[CPU攻撃] ワーストケース: %s → %s" % [worst_option_name, "敗北" if not worst_result.is_win else "勝利"])
	
	worst_result["worst_case_option"] = worst_option_name
	return worst_result


## 基本シミュレーション（敵対抗手段なし）
func _simulate_base(
	attacker: Dictionary,
	defender: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	attacker_item: Dictionary
) -> Dictionary:
	return _simulate_with_defender_option(attacker, defender, tile_info, attacker_player_id, attacker_item, {}, {})


## 防御側のオプション（アイテム or 援護）を考慮したシミュレーション
func _simulate_with_defender_option(
	attacker: Dictionary,
	defender: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	attacker_item: Dictionary,
	defender_item: Dictionary,
	assist_creature: Dictionary
) -> Dictionary:
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", -1),
		"tile_index": tile_info.get("index", -1)
	}
	
	# 援護がある場合、防御側のステータスに加算
	var defender_for_sim = defender.duplicate(true)
	if not assist_creature.is_empty():
		defender_for_sim["ap"] = defender_for_sim.get("ap", 0) + assist_creature.get("ap", 0)
		defender_for_sim["hp"] = defender_for_sim.get("hp", 0) + assist_creature.get("hp", 0)
	
	var sim_result = _battle_simulator.simulate_battle(
		attacker,
		defender_for_sim,
		sim_tile_info,
		attacker_player_id,
		attacker_item,
		defender_item
	)
	
	var is_win = sim_result.get("result") == BattleSimulator.BattleResult.ATTACKER_WIN
	var overkill = sim_result.get("attacker_ap", 0) - sim_result.get("defender_hp", 0)
	if overkill < 0:
		overkill = 0
	
	return {
		"is_win": is_win,
		"sim_result": sim_result,
		"overkill": overkill
	}


## 結果Aが結果Bより悪いか（攻撃側にとって）
func _is_worse_result(result_a: Dictionary, result_b: Dictionary) -> bool:
	# 勝ち → 負け は悪化
	if result_b.is_win and not result_a.is_win:
		return true
	# 両方勝ちの場合、オーバーキルが少ない方が悪い（ギリギリ）
	if result_a.is_win and result_b.is_win:
		return result_a.overkill < result_b.overkill
	return false


## ワーストケースでも勝てるアイテムを探す
## @param enemy_destroy_types: 敵のアイテム破壊対象タイプ（空なら破壊スキルなし）
## @return: {can_win: bool, item: Dictionary, item_index: int}
func find_item_to_beat_worst_case(
	attacker: Dictionary,
	defender: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	current_player,
	creature_cost: int,
	enemy_destroy_types: Array = []
) -> Dictionary:
	var result = {"can_win": false, "item": {}, "item_index": -1}
	
	if not _hand_utils:
		return result
	
	var items = _hand_utils.get_items_from_hand(attacker_player_id)
	print("    [アイテム検索] ワーストケース対策アイテムを検索: %d個のアイテム" % items.size())
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = _tile_action_processor and _tile_action_processor.debug_disable_cannot_use
	
	for item_entry in items:
		var item_index = item_entry["index"]
		var item = item_entry["data"]
		var item_cost = _hand_utils.get_item_cost(item)
		
		# コストチェック
		if creature_cost + item_cost > current_player.magic_power:
			continue
		
		# アイテム破壊対象チェック（敵がアイテム破壊スキルを持っている場合）
		if not enemy_destroy_types.is_empty():
			if _hand_utils.is_item_destroy_target(item, enemy_destroy_types):
				print("    [スキップ] %s: 敵のアイテム破壊対象" % item.get("name", "?"))
				continue
		
		# cannot_use制限チェック（リリース呪いで解除可能）
		if not disable_cannot_use and not _is_item_restriction_released(attacker_player_id):
			var check_result = ItemUseRestriction.check_can_use(attacker, item)
			if not check_result.can_use:
				print("    [スキップ] %s: %s" % [item.get("name", "?"), check_result.reason])
				continue
		
		# ワーストケースシミュレーション
		var worst = simulate_worst_case(attacker, defender, tile_info, attacker_player_id, item)
		
		if worst.is_win:
			# 勝てるアイテムが見つかった
			if not result.can_win or item_cost < _hand_utils.get_item_cost(result.item):
				# 初めて見つかった or より安いアイテム
				result.can_win = true
				result.item = item
				result.item_index = item_index
	
	return result


## リリース呪いによるアイテム制限解除をチェック
func _is_item_restriction_released(player_id: int) -> bool:
	if not _player_system or player_id < 0 or player_id >= _player_system.players.size():
		return false
	var player = _player_system.players[player_id]
	var player_dict = {"curse": player.curse}
	return SpellRestriction.is_item_restriction_released(player_dict)
