## CPU合体判断クラス
## 攻撃側・防御側の合体オプション評価とシミュレーションを担当
class_name CPUMergeEvaluator
extends RefCounted

## システム参照
var card_system: Node = null
var hand_utils: CPUHandUtils = null
var battle_simulator = null

## 最後に選択した合体データ（攻撃側）
var pending_merge_data: Dictionary = {}

## 初期化
func initialize(c_system: Node, h_utils: CPUHandUtils, b_sim) -> void:
	card_system = c_system
	hand_utils = h_utils
	battle_simulator = b_sim

# ============================================================
# 攻撃側合体判断
# ============================================================

## 攻撃側の合体オプションをチェック
## 合体スキルを持ち、手札に合体相手がいて、コストを支払えて、合体で勝てる/生き残れるかを判定
func check_merge_option_for_attack(
	current_player,
	creatures: Array,
	defender: Dictionary,
	tile_info: Dictionary
) -> Dictionary:
	var result = {
		"can_merge": false,
		"wins_or_survives": false,
		"is_win": false,
		"creature_index": -1,
		"partner_index": -1,
		"partner_data": {},
		"result_id": -1,
		"result_name": "",
		"cost": 0,
		"sim_result": null
	}
	
	if not card_system:
		return result
	
	var hand = card_system.get_all_cards_for_player(current_player.id)
	
	# 各クリーチャーについて合体可能かチェック
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		
		# 合体スキルを持っているかチェック
		if not SkillMerge.has_merge_skill(creature):
			continue
		
		# 手札に合体相手がいるかチェック
		var partner_index = SkillMerge.find_merge_partner_in_hand(creature, hand)
		if partner_index == -1:
			continue
		
		# 合体相手のデータ
		var partner_data = hand[partner_index]
		var partner_cost = SkillMerge.get_merge_cost(hand, partner_index)
		
		# クリーチャーのコスト
		var creature_cost = hand_utils.calculate_card_cost(creature, current_player.id) if hand_utils else 0
		var total_cost = creature_cost + partner_cost
		
		# コストチェック
		if total_cost > current_player.magic_power:
			print("[CPU合体] 魔力不足: 必要%dG, 現在%dG" % [total_cost, current_player.magic_power])
			continue
		
		# 合体結果のクリーチャーを取得
		var result_id = SkillMerge.get_merge_result_id(creature)
		var result_creature = CardLoader.get_card_by_id(result_id)
		
		if result_creature.is_empty():
			continue
		
		print("[CPU合体] 合体可能: %s + %s → %s (コスト: %dG)" % [
			creature.get("name", "?"),
			partner_data.get("name", "?"),
			result_creature.get("name", "?"),
			total_cost
		])
		
		# 合体後のクリーチャーでシミュレーション
		var sim_result = simulate_attack_with_merge(result_creature, defender, tile_info, current_player.id)
		var outcome = sim_result.get("result", -1)
		
		print("[CPU合体] シミュレーション結果: %s" % merge_result_to_string(outcome))
		
		var is_win = outcome == BattleSimulator.BattleResult.ATTACKER_WIN
		var is_survive = outcome == BattleSimulator.BattleResult.ATTACKER_SURVIVED
		
		if is_win or is_survive:
			result["can_merge"] = true
			result["wins_or_survives"] = true
			result["is_win"] = is_win
			result["creature_index"] = creature_index
			result["partner_index"] = partner_index
			result["partner_data"] = partner_data
			result["result_id"] = result_id
			result["result_name"] = result_creature.get("name", "?")
			result["cost"] = total_cost
			result["sim_result"] = sim_result
			result["merged_creature"] = result_creature
			
			# 勝てる場合は即座に返す（生き残りより勝利を優先）
			if is_win:
				return result
	
	return result

## 合体後のクリーチャーで攻撃シミュレーション
func simulate_attack_with_merge(
	merged_creature: Dictionary,
	defender: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int
) -> Dictionary:
	if not battle_simulator:
		return {}
	
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", -1),
		"tile_index": tile_info.get("index", -1)
	}
	
	return battle_simulator.simulate_battle(
		merged_creature,  # 攻撃側（合体後）
		defender,         # 防御側
		sim_tile_info,
		attacker_player_id,
		{},               # 攻撃側アイテム（合体のみ）
		{}                # 防御側アイテム（不明）
	)

# ============================================================
# 合体データ管理
# ============================================================

## 合体データを保存
func set_pending_merge_data(data: Dictionary) -> void:
	pending_merge_data = data

## 保存された合体データを取得
func get_pending_merge_data() -> Dictionary:
	return pending_merge_data

## 合体データをクリア
func clear_pending_merge_data() -> void:
	pending_merge_data = {}

## 合体が選択されているかチェック
func has_pending_merge() -> bool:
	return not pending_merge_data.is_empty() and pending_merge_data.get("can_merge", false)

# ============================================================
# ユーティリティ
# ============================================================

## 合体シミュレーション結果を文字列に変換
func merge_result_to_string(outcome: int) -> String:
	match outcome:
		BattleSimulator.BattleResult.ATTACKER_WIN:
			return "攻撃側勝利"
		BattleSimulator.BattleResult.DEFENDER_WIN:
			return "防御側勝利"
		BattleSimulator.BattleResult.ATTACKER_SURVIVED:
			return "両者生存"
		BattleSimulator.BattleResult.BOTH_DEFEATED:
			return "相打ち"
		_:
			return "不明"
