class_name CPUBattleAI

# CPUバトル評価クラス
# バトルシミュレーションを使用した組み合わせ評価、合体判断、即死スキル判断を担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")

# システム参照
var card_system: CardSystem
var board_system
var player_system: PlayerSystem
var player_buff_system: PlayerBuffSystem
var game_flow_manager_ref = null

# バトルシミュレーター
var battle_simulator: BattleSimulator = null

# 手札ユーティリティ参照
var hand_utils: CPUHandUtils = null

# 最後に選択した合体データ（攻撃側）
var pending_merge_data: Dictionary = {}

## システム参照を設定
func setup_systems(c_system: CardSystem, b_system, p_system: PlayerSystem, s_system: PlayerBuffSystem, gf_manager = null):
	card_system = c_system
	board_system = b_system
	player_system = p_system
	player_buff_system = s_system
	game_flow_manager_ref = gf_manager
	
	# BattleSimulatorを初期化
	battle_simulator = BattleSimulatorScript.new()
	battle_simulator.setup_systems(board_system, card_system, player_system, game_flow_manager_ref)
	battle_simulator.enable_log = true  # デバッグ用にログ有効

## 手札ユーティリティを設定
func set_hand_utils(utils: CPUHandUtils):
	hand_utils = utils

## GameFlowManagerを後から設定
func set_game_flow_manager(gf_manager) -> void:
	game_flow_manager_ref = gf_manager
	if battle_simulator:
		battle_simulator.setup_systems(board_system, card_system, player_system, game_flow_manager_ref)

## BattleSimulatorのログ出力を切り替え
func set_simulator_log_enabled(enabled: bool) -> void:
	if battle_simulator:
		battle_simulator.enable_log = enabled

# ============================================================
# バトル評価
# ============================================================

## バトル用の全カード評価
func evaluate_all_cards_for_battle(current_player, defender: Dictionary, tile_info: Dictionary) -> Dictionary:
	var best_result = {"index": -1, "score": -999, "sim_result": null}
	
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	for i in range(hand_size):
		var card = card_system.get_card_data_for_player(current_player.id, i)
		if card.is_empty():
			continue
		
		# クリーチャーカードのみ対象
		if card.get("type", "") != "creature":
			continue
		
		# コストチェック
		if not hand_utils.can_afford_card(current_player, i):
			continue
		
		# バトルシミュレーション
		var eval_result = evaluate_battle_outcome(card, defender, tile_info, current_player.id)
		if eval_result.score > best_result.score:
			best_result.score = eval_result.score
			best_result.index = i
			best_result.sim_result = eval_result.sim_result
	
	# 最良の選択をログ出力
	if best_result.index >= 0:
		var best_card = card_system.get_card_data_for_player(current_player.id, best_result.index)
		print("[CPU AI] 最良の選択: %s (スコア: %d)" % [best_card.get("name", "?"), best_result.score])
	
	return best_result

## バトル結果を評価（BattleSimulatorを使用）
func evaluate_battle_outcome(attacker: Dictionary, defender: Dictionary, tile_info: Dictionary, attacker_player_id: int) -> Dictionary:
	if not battle_simulator:
		# フォールバック: 簡易評価
		return _evaluate_battle_simple(attacker, defender)
	
	# tile_infoからタイル情報を構築
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", -1),
		"tile_index": tile_info.get("index", -1)
	}
	
	# シミュレーション実行
	var sim_result = battle_simulator.simulate_battle(
		attacker,
		defender,
		sim_tile_info,
		attacker_player_id,
		{},  # 攻撃側アイテム
		{}   # 防御側アイテム
	)
	
	# スコア計算
	var score = _calculate_battle_score(sim_result, attacker, defender)
	
	return {"score": score, "sim_result": sim_result}

## シミュレーション結果からスコアを計算
func _calculate_battle_score(sim_result: Dictionary, attacker: Dictionary, _defender: Dictionary) -> int:
	var score = 0
	var result = sim_result.get("result", -1)
	
	# 勝敗による基本スコア
	match result:
		BattleSimulator.BattleResult.ATTACKER_WIN:
			score = 100  # 勝利
		BattleSimulator.BattleResult.DEFENDER_WIN:
			score = -100  # 敗北
		BattleSimulator.BattleResult.ATTACKER_SURVIVED:
			score = -20  # 侵略失敗（両方生存）
		BattleSimulator.BattleResult.BOTH_DEFEATED:
			score = -50  # 相打ち
	
	# ダメージ差によるボーナス/ペナルティ
	var attacker_ap = sim_result.get("attacker_ap", 0)
	var defender_hp = sim_result.get("defender_hp", 0)
	var overkill = attacker_ap - defender_hp
	if overkill > 0:
		score += min(overkill / 10, 20)  # オーバーキル分のボーナス（最大20）
	
	# 攻撃側の残りHP
	var attacker_hp = sim_result.get("attacker_hp", 0)
	var defender_ap = sim_result.get("defender_ap", 0)
	var hp_margin = attacker_hp - defender_ap
	if hp_margin > 0:
		score += min(hp_margin / 10, 20)  # HP余裕分のボーナス（最大20）
	
	# クリーチャーのレアリティ/コストを考慮（高コストクリーチャーを失うリスク）
	var attacker_cost = attacker.get("cost", {})
	if typeof(attacker_cost) == TYPE_DICTIONARY:
		attacker_cost = attacker_cost.get("mp", 0)
	if result == BattleSimulator.BattleResult.DEFENDER_WIN or result == BattleSimulator.BattleResult.BOTH_DEFEATED:
		score -= attacker_cost * 5  # 高コストクリーチャーを失うペナルティ
	
	return score

## フォールバック: 簡易評価（BattleSimulatorがない場合）
func _evaluate_battle_simple(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var attacker_st = attacker.get("ap", 0)
	var attacker_hp = attacker.get("hp", 0)
	var defender_st = defender.get("ap", 0)
	var defender_hp = defender.get("hp", 0)
	
	var score = attacker_st - defender_hp
	
	if attacker_st >= defender_hp:
		score += 50
	elif defender_st >= attacker_hp:
		score -= 50
	
	return {"score": score, "sim_result": null}

## アイテム付きバトルを評価
func evaluate_battle_with_item(
	attacker: Dictionary,
	defender: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	attacker_item: Dictionary = {}
) -> Dictionary:
	if not battle_simulator:
		return _evaluate_battle_simple(attacker, defender)
	
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", -1),
		"tile_index": tile_info.get("index", -1)
	}
	
	# シミュレーション実行（アイテム付き）
	var sim_result = battle_simulator.simulate_battle(
		attacker,
		defender,
		sim_tile_info,
		attacker_player_id,
		attacker_item,
		{}  # 防御側アイテム（敵の使用アイテムは不明なので空）
	)
	
	# スコア計算
	var score = _calculate_battle_score(sim_result, attacker, defender)
	
	# アイテムコストを考慮（アイテムを使うとコストがかかる）
	if not attacker_item.is_empty():
		var item_cost = hand_utils.get_item_cost(attacker_item)
		# アイテムを使う価値があるか：勝てるようになる場合はボーナス、既に勝てる場合はペナルティ
		if sim_result.get("result") == BattleSimulator.BattleResult.ATTACKER_WIN:
			score += 10  # アイテムで勝てるならボーナス
		score -= item_cost / 10  # アイテムコスト分のペナルティ
	
	return {"score": score, "sim_result": sim_result, "item": attacker_item}

## クリーチャー × アイテムの全組み合わせを評価
## 戻り値: {creature_index, item_index, score, sim_result, can_win}
## 
## 新ロジック:
## 1. ATTACKER_WINの組み合わせのみ候補
## 2. 勝てる中から「ギリギリで勝てる」ものを選ぶ（リソース温存）
## 3. アイテムなしで勝てるならアイテムは使わない
func evaluate_all_combinations_for_battle(
	current_player,
	defender: Dictionary,
	tile_info: Dictionary
) -> Dictionary:
	var result = {
		"creature_index": -1,
		"item_index": -1,  # -1 = アイテムなし
		"score": -999,
		"sim_result": null,
		"can_win": false
	}
	
	var creatures = hand_utils.get_creatures_from_hand(current_player.id)
	var items = hand_utils.get_items_from_hand(current_player.id)
	
	print("[CPU AI] バトル組み合わせ評価: クリーチャー%d体, アイテム%d個" % [creatures.size(), items.size()])
	
	# 0. 合体判断（最優先）
	var merge_result = _check_merge_option_for_attack(current_player, creatures, defender, tile_info)
	if merge_result.can_merge and merge_result.wins_or_survives:
		print("[CPU AI] 合体で勝利/生存可能 → 合体を選択: %s" % merge_result.result_name)
		result.creature_index = merge_result.creature_index
		result.item_index = -1  # 合体は item_index を使わない
		result.sim_result = merge_result.sim_result
		result.can_win = merge_result.is_win or merge_result.wins_or_survives  # 生存も勝ち扱い
		result.score = 150 if merge_result.is_win else 80  # 合体は高スコア
		result["merge_data"] = merge_result  # 合体データを追加
		# 合体データを保存（バトル実行時に使用）
		pending_merge_data = merge_result
		return result
	
	# 合体データをクリア（通常バトルを選択する場合）
	pending_merge_data = {}
	
	# 0.5. 敵が無効化アイテムを持っている場合、無効化+即死クリーチャーを優先
	var enemy_player_id = tile_info.get("owner", -1)
	if enemy_player_id >= 0 and hand_utils.enemy_has_nullify_item(enemy_player_id):
		print("[CPU AI] 敵が無効化アイテムを所持 → 無効化+即死クリーチャーを優先検討")
		var nullify_instant_death_result = _check_nullify_instant_death_priority(
			current_player, creatures, defender
		)
		if nullify_instant_death_result.can_use:
			print("[CPU AI] 無効化+即死クリーチャーを優先使用: %s (確率: %d%%)" % [
				nullify_instant_death_result.creature.get("name", "?"),
				nullify_instant_death_result.probability
			])
			result.creature_index = nullify_instant_death_result.creature_index
			result.item_index = -1  # アイテムなし
			result.can_win = false  # 確実な勝利ではないが、戦略的に有利
			result.score = 70  # 通常即死より高いスコア
			result["is_nullify_instant_death"] = true
			result["instant_death_probability"] = nullify_instant_death_result.probability
			return result
	
	# 勝てる組み合わせを収集
	var winning_combinations: Array = []
	
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		var creature_cost = hand_utils.calculate_card_cost(creature, current_player.id)
		
		# コストチェック
		if not hand_utils.can_afford_card(current_player, creature_index):
			continue
		
		# 1. アイテムなしで評価
		var no_item_result = _simulate_and_check_win(
			creature, defender, tile_info, current_player.id, {}
		)
		
		if no_item_result.is_win:
			winning_combinations.append({
				"creature_index": creature_index,
				"creature": creature,
				"creature_cost": creature_cost,
				"item_index": -1,
				"item": {},
				"item_cost": 0,
				"total_cost": creature_cost,
				"sim_result": no_item_result.sim_result,
				"overkill": no_item_result.overkill,
				"uses_item": false
			})
			print("  [勝利可能] %s (アイテムなし): オーバーキル %d" % [
				creature.get("name", "?"), no_item_result.overkill
			])
		
		# 2. 各アイテムを使った場合を評価
		for item_entry in items:
			var item_index = item_entry["index"]
			var item = item_entry["data"]
			var item_cost = hand_utils.get_item_cost(item)
			
			# アイテムコストチェック
			if creature_cost + item_cost > current_player.magic_power:
				continue
			
			var with_item_result = _simulate_and_check_win(
				creature, defender, tile_info, current_player.id, item
			)
			
			if with_item_result.is_win:
				winning_combinations.append({
					"creature_index": creature_index,
					"creature": creature,
					"creature_cost": creature_cost,
					"item_index": item_index,
					"item": item,
					"item_cost": item_cost,
					"total_cost": creature_cost + item_cost,
					"sim_result": with_item_result.sim_result,
					"overkill": with_item_result.overkill,
					"uses_item": true
				})
				print("  [勝利可能] %s + %s[%s]: オーバーキル %d" % [
					creature.get("name", "?"),
					item.get("name", "?"),
					item.get("item_type", "?"),
					with_item_result.overkill
				])
	
	# 勝てる組み合わせがない場合 → 即死スキルで賭けるか検討
	if winning_combinations.is_empty():
		print("[CPU AI] 勝てる組み合わせなし → 即死スキルをチェック")
		var instant_death_result = _check_instant_death_gamble(current_player, creatures, defender)
		if instant_death_result.can_gamble:
			print("[CPU AI] 即死スキルで賭ける: %s (確率: %d%%)" % [
				instant_death_result.creature.get("name", "?"),
				instant_death_result.probability
			])
			result.creature_index = instant_death_result.creature_index
			result.item_index = -1  # アイテムなし
			result.can_win = false  # 確実な勝利ではない
			result.score = 50  # 賭けなので低めのスコア
			result["is_instant_death_gamble"] = true
			result["instant_death_probability"] = instant_death_result.probability
			return result
		print("[CPU AI] 即死スキルも使えない → バトル見送り")
		return result
	
	# ギリギリで勝てる組み合わせを選択
	var best = _select_optimal_combination(winning_combinations)
	
	result.creature_index = best.creature_index
	result.item_index = best.item_index
	result.sim_result = best.sim_result
	result.can_win = true
	result.score = 100  # 勝てる場合は高スコア
	
	# 最終結果をログ出力
	var best_creature = best.creature
	if best.uses_item:
		print("[CPU AI] 最適な組み合わせ: %s + %s[%s] (コスト: %d, オーバーキル: %d)" % [
			best_creature.get("name", "?"),
			best.item.get("name", "?"),
			best.item.get("item_type", "?"),
			best.total_cost,
			best.overkill
		])
	else:
		print("[CPU AI] 最適な組み合わせ: %s (アイテムなし, コスト: %d, オーバーキル: %d)" % [
			best_creature.get("name", "?"),
			best.total_cost,
			best.overkill
		])
	
	return result

## シミュレーションを実行して勝利判定
func _simulate_and_check_win(
	attacker: Dictionary,
	defender: Dictionary,
	tile_info: Dictionary,
	attacker_player_id: int,
	attacker_item: Dictionary
) -> Dictionary:
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", -1),
		"tile_index": tile_info.get("index", -1)
	}
	
	var sim_result = battle_simulator.simulate_battle(
		attacker,
		defender,
		sim_tile_info,
		attacker_player_id,
		attacker_item,
		{}
	)
	
	var is_win = sim_result.get("result") == BattleSimulator.BattleResult.ATTACKER_WIN
	
	# オーバーキル計算（攻撃力 - 敵HP、低いほどギリギリ）
	var overkill = sim_result.get("attacker_ap", 0) - sim_result.get("defender_hp", 0)
	if overkill < 0:
		overkill = 0
	
	return {
		"is_win": is_win,
		"sim_result": sim_result,
		"overkill": overkill
	}

## 勝てる組み合わせから最適なものを選択
## 優先順位:
## 1. アイテムなし > アイテムあり（リソース温存）
## 2. アイテム種別: 巻物 > 武器 > アクセサリ > 防具
## 3. クリーチャーコストが低い（安いカードで勝つ）
## 4. オーバーキルが少ない（ギリギリで勝つ）
func _select_optimal_combination(combinations: Array) -> Dictionary:
	# アイテムなしで勝てる組み合わせを優先
	var no_item_combinations = combinations.filter(func(c): return not c.uses_item)
	var with_item_combinations = combinations.filter(func(c): return c.uses_item)
	
	# アイテムなしで勝てるならそちらから選ぶ
	if not no_item_combinations.is_empty():
		# アイテムなし: コスト昇順 → オーバーキル昇順
		no_item_combinations.sort_custom(func(a, b):
			if a.total_cost != b.total_cost:
				return a.total_cost < b.total_cost
			return a.overkill < b.overkill
		)
		return no_item_combinations[0]
	
	# アイテムありの場合: アイテム種別優先度 → コスト昇順 → オーバーキル昇順
	with_item_combinations.sort_custom(func(a, b):
		# アイテム種別の優先度で比較（低い数値が優先）
		var a_priority = _get_item_type_priority(a.item)
		var b_priority = _get_item_type_priority(b.item)
		if a_priority != b_priority:
			return a_priority < b_priority
		# コストで比較
		if a.total_cost != b.total_cost:
			return a.total_cost < b.total_cost
		# オーバーキルで比較
		return a.overkill < b.overkill
	)
	
	return with_item_combinations[0]

## アイテム種別の優先度を取得（低いほど優先）
## 巻物(0) > 武器(1) > アクセサリ(2) > 防具(3)
func _get_item_type_priority(item: Dictionary) -> int:
	var item_type = item.get("item_type", "")
	match item_type:
		"巻物":
			return 0
		"武器":
			return 1
		"アクセサリ":
			return 2
		"防具":
			return 3
		_:
			return 99  # 不明なタイプは最低優先度

# ============================================================
# 合体判断（攻撃側）
# ============================================================

## 攻撃側の合体オプションをチェック
## 合体スキルを持ち、手札に合体相手がいて、コストを支払えて、合体で勝てる/生き残れるかを判定
func _check_merge_option_for_attack(
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
		var creature_cost = hand_utils.calculate_card_cost(creature, current_player.id)
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
		var sim_result = _simulate_attack_with_merge(result_creature, defender, tile_info, current_player.id)
		var outcome = sim_result.get("result", -1)
		
		print("[CPU合体] シミュレーション結果: %s" % _merge_result_to_string(outcome))
		
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
func _simulate_attack_with_merge(
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

## 合体シミュレーション結果を文字列に変換
func _merge_result_to_string(outcome: int) -> String:
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

## 保存された合体データを取得
func get_pending_merge_data() -> Dictionary:
	return pending_merge_data

## 合体データをクリア
func clear_pending_merge_data():
	pending_merge_data = {}

## 合体が選択されているかチェック
func has_pending_merge() -> bool:
	return not pending_merge_data.is_empty() and pending_merge_data.get("can_merge", false)

# ============================================================
# 即死スキル判断
# ============================================================

## 無効化+即死クリーチャーを優先使用するかチェック
## 敵が無効化アイテムを持っている場合に呼び出される
func _check_nullify_instant_death_priority(current_player, creatures: Array, defender: Dictionary) -> Dictionary:
	var result = {
		"can_use": false,
		"creature_index": -1,
		"creature": {},
		"probability": 0
	}
	
	var best_candidate = null
	var best_probability = 0
	
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		
		# コストチェック
		if not hand_utils.can_afford_card(current_player, creature_index):
			continue
		
		# 無効化スキルを持っているかチェック
		if not _has_nullify_skill(creature):
			continue
		
		# 即死スキルを持っているかチェック
		var instant_death_info = _get_instant_death_info(creature)
		if instant_death_info.is_empty():
			continue
		
		# 即死条件を満たすかチェック
		if not _check_instant_death_condition_for_cpu(instant_death_info, defender):
			continue
		
		var probability = instant_death_info.get("probability", 0)
		print("  [無効化+即死候補] %s: 確率 %d%%" % [creature.get("name", "?"), probability])
		
		# 最も確率が高いクリーチャーを選択
		if probability > best_probability:
			best_probability = probability
			best_candidate = {
				"creature_index": creature_index,
				"creature": creature,
				"probability": probability
			}
	
	if best_candidate:
		result.can_use = true
		result.creature_index = best_candidate.creature_index
		result.creature = best_candidate.creature
		result.probability = best_candidate.probability
	
	return result

## クリーチャーが無効化スキルを持っているかチェック
func _has_nullify_skill(creature: Dictionary) -> bool:
	var ability_parsed = creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "無効化" in keywords

## 即死スキルで賭けるかチェック
## 勝てる組み合わせがない場合に、即死スキル持ちで条件を満たすクリーチャーを探す
func _check_instant_death_gamble(current_player, creatures: Array, defender: Dictionary) -> Dictionary:
	var result = {
		"can_gamble": false,
		"creature_index": -1,
		"creature": {},
		"probability": 0
	}
	
	var best_candidate = null
	var best_probability = 0
	
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		
		# コストチェック
		if not hand_utils.can_afford_card(current_player, creature_index):
			continue
		
		# 即死スキルをチェック
		var instant_death_info = _get_instant_death_info(creature)
		if instant_death_info.is_empty():
			continue
		
		# 即死条件を満たすかチェック
		if not _check_instant_death_condition_for_cpu(instant_death_info, defender):
			continue
		
		var probability = instant_death_info.get("probability", 0)
		print("  [即死候補] %s: 確率 %d%%" % [creature.get("name", "?"), probability])
		
		# 最も確率が高いクリーチャーを選択
		if probability > best_probability:
			best_probability = probability
			best_candidate = {
				"creature_index": creature_index,
				"creature": creature,
				"probability": probability
			}
	
	if best_candidate:
		result.can_gamble = true
		result.creature_index = best_candidate.creature_index
		result.creature = best_candidate.creature
		result.probability = best_candidate.probability
	
	return result

## クリーチャーの即死スキル情報を取得
func _get_instant_death_info(creature: Dictionary) -> Dictionary:
	var ability_parsed = creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "即死" in keywords:
		return {}
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	if instant_death_condition.is_empty():
		return {}
	
	return instant_death_condition

## 即死条件をCPU側でチェック（攻撃時）
func _check_instant_death_condition_for_cpu(condition: Dictionary, defender: Dictionary) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"none", "":
			# 無条件
			return true
		
		"enemy_is_element", "enemy_element":
			# 敵が特定属性
			var defender_element = defender.get("element", "")
			
			# 単一属性
			if condition.has("element"):
				var required_element = condition.get("element", "")
				if required_element == "全":
					return true
				return defender_element == required_element
			
			# 複数属性
			var required_elements = condition.get("elements", [])
			if typeof(required_elements) == TYPE_STRING:
				if required_elements == "全":
					return true
				required_elements = [required_elements]
			
			return defender_element in required_elements
		
		"defender_ap_check":
			# 防御側のAPが一定以上
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			var defender_base_ap = defender.get("ap", 0)
			
			match operator:
				">=": return defender_base_ap >= value
				">": return defender_base_ap > value
				"==": return defender_base_ap == value
				_: return false
		
		"defender_role":
			# 使用者が防御側の時のみ発動（キロネックス）
			# CPUが攻撃側なので、この条件は満たせない
			return false
		
		"後手":
			# 後手条件は先制判定で処理されるため、ここでは常にtrue
			return true
		
		_:
			print("[CPU AI] 未知の即死条件タイプ: ", condition_type)
			return false
