class_name CPUBattleAI

# CPUバトル評価クラス
# バトルシミュレーションを使用した組み合わせ評価、即死スキル判断を担当
# 合体判断はCPUMergeEvaluatorに委譲

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")

# システム参照
var card_system: CardSystem
var board_system
var player_system: PlayerSystem
var player_buff_system: PlayerBuffSystem
var game_flow_manager_ref = null
var tile_action_processor = null  # デバッグフラグ参照用

# バトルシミュレーター
var battle_simulator: BattleSimulator = null

# 手札ユーティリティ参照
var hand_utils: CPUHandUtils = null

# 合体評価クラス
var merge_evaluator: CPUMergeEvaluator = null

## システム参照を設定
func setup_systems(c_system: CardSystem, b_system, p_system: PlayerSystem, s_system: PlayerBuffSystem, gf_manager = null):
	card_system = c_system
	board_system = b_system
	player_system = p_system
	
	# TileActionProcessor参照を取得（デバッグフラグ用）
	if b_system:
		tile_action_processor = b_system.tile_action_processor
	player_buff_system = s_system
	game_flow_manager_ref = gf_manager
	
	# BattleSimulatorを初期化
	battle_simulator = BattleSimulatorScript.new()
	battle_simulator.setup_systems(board_system, card_system, player_system, game_flow_manager_ref)
	battle_simulator.enable_log = true  # デバッグ用にログ有効

## 手札ユーティリティを設定
func set_hand_utils(utils: CPUHandUtils):
	hand_utils = utils
	# 合体評価クラスを初期化
	merge_evaluator = CPUMergeEvaluator.new()
	merge_evaluator.initialize(card_system, hand_utils, battle_simulator)

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
		score += min(overkill / 10.0, 20)  # オーバーキル分のボーナス（最大20）
	
	# 攻撃側の残りHP
	var attacker_hp = sim_result.get("attacker_hp", 0)
	var defender_ap = sim_result.get("defender_ap", 0)
	var hp_margin = attacker_hp - defender_ap
	if hp_margin > 0:
		score += min(hp_margin / 10.0, 20)  # HP余裕分のボーナス（最大20）
	
	# クリーチャーのレートを考慮（高レートクリーチャーを失うリスク）
	var CardRateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
	var attacker_rate = CardRateEvaluator.get_rate(attacker)
	if result == BattleSimulator.BattleResult.DEFENDER_WIN or result == BattleSimulator.BattleResult.BOTH_DEFEATED:
		score -= attacker_rate * 0.5  # 高レートクリーチャーを失うペナルティ
	
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
		score -= item_cost / 10.0  # アイテムコスト分のペナルティ
	
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
	if merge_evaluator:
		var merge_result = merge_evaluator.check_merge_option_for_attack(current_player, creatures, defender, tile_info)
		if merge_result.can_merge and merge_result.wins_or_survives:
			print("[CPU AI] 合体で勝利/生存可能 → 合体を選択: %s" % merge_result.result_name)
			result.creature_index = merge_result.creature_index
			result.item_index = -1  # 合体は item_index を使わない
			result.sim_result = merge_result.sim_result
			result.can_win = merge_result.is_win or merge_result.wins_or_survives  # 生存も勝ち扱い
			result.score = 150 if merge_result.is_win else 80  # 合体は高スコア
			result["merge_data"] = merge_result  # 合体データを追加
			# 合体データを保存（バトル実行時に使用）
			merge_evaluator.set_pending_merge_data(merge_result)
			return result
		
		# 合体データをクリア（通常バトルを選択する場合）
		merge_evaluator.clear_pending_merge_data()
	
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
	
	# 1. 敵のアイテム破壊・盗みスキルをチェック
	var enemy_destroy_types = hand_utils.defender_has_item_destroy(defender)
	var enemy_has_steal = hand_utils.defender_has_item_steal(defender)
	var should_avoid_items = not enemy_destroy_types.is_empty() or enemy_has_steal
	
	print("[CPU AI] アイテム回避判定: destroy_types=%s, has_steal=%s, should_avoid=%s" % [
		enemy_destroy_types, enemy_has_steal, should_avoid_items
	])
	
	if should_avoid_items:
		if not enemy_destroy_types.is_empty():
			print("[CPU AI] 警告: 敵がアイテム破壊スキルを所持 → 全アイテム使用不可")
		if enemy_has_steal:
			print("[CPU AI] 警告: 敵がアイテム盗みスキルを所持 → 全アイテム使用不可")
	
	# 勝てる組み合わせを収集（ワーストケース対応版）
	var winning_combinations: Array = []
	
	print("[CPU AI] クリーチャー評価開始（%d体）" % creatures.size())
	
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		var creature_cost = hand_utils.calculate_card_cost(creature, current_player.id)
		
		# コストチェック
		if not hand_utils.can_afford_card(current_player, creature_index):
			print("  [スキップ] %s: コスト不足" % creature.get("name", "?"))
			continue
		
		# ワーストケースシミュレーション（敵がアイテム/援護を使った場合）
		print("  [評価中] %s (コスト: %d)" % [creature.get("name", "?"), creature_cost])
		var worst_case = simulate_worst_case(creature, defender, tile_info, current_player.id, {})
		
		if worst_case.is_win:
			# ワーストケースでも勝てる → アイテムなしで攻撃可能
			winning_combinations.append({
				"creature_index": creature_index,
				"creature": creature,
				"creature_cost": creature_cost,
				"item_index": -1,
				"item": {},
				"item_cost": 0,
				"total_cost": creature_cost,
				"sim_result": worst_case.sim_result,
				"overkill": worst_case.overkill,
				"uses_item": false,
				"worst_case_option": worst_case.get("worst_case_option", "なし")
			})
			print("  [勝利可能] %s (アイテムなし, ワーストケースでも勝利): オーバーキル %d" % [
				creature.get("name", "?"), worst_case.overkill
			])
		else:
			# ワーストケースで負ける → 自分もアイテムを使って勝てるか探す
			# ただし、敵がアイテム破壊・盗みを持っている場合はアイテムを使わない
			if should_avoid_items:
				print("  [攻撃不可] %s: ワーストケースで負け、敵がアイテム破壊/盗みを持つためアイテム使用不可" % creature.get("name", "?"))
			else:
				var counter_item = find_item_to_beat_worst_case(
					creature, defender, tile_info, current_player.id, current_player, creature_cost,
					enemy_destroy_types
				)
				
				if counter_item.can_win:
					winning_combinations.append({
						"creature_index": creature_index,
						"creature": creature,
						"creature_cost": creature_cost,
						"item_index": counter_item.item_index,
						"item": counter_item.item,
						"item_cost": hand_utils.get_item_cost(counter_item.item),
						"total_cost": creature_cost + hand_utils.get_item_cost(counter_item.item),
						"sim_result": null,
						"overkill": 0,
						"uses_item": true,
						"worst_case_counter": true
					})
					print("  [勝利可能] %s + %s (ワーストケース対策): アイテムで逆転" % [
						creature.get("name", "?"),
						counter_item.item.get("name", "?")
					])
				else:
					print("  [攻撃不可] %s: ワーストケースで負け、対抗アイテムなし" % creature.get("name", "?"))
	
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
	print("[CPU AI] 勝てる組み合わせ数: %d" % winning_combinations.size())
	var best = _select_optimal_combination(winning_combinations)
	
	print("[CPU AI] 最適組み合わせ選択: creature_index=%d, item_index=%d" % [
		best.get("creature_index", -1), best.get("item_index", -1)
	])
	
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
# ワーストケースシミュレーション（敵の対抗手段を考慮）
# ============================================================

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
	
	if defender_owner < 0 or not hand_utils:
		# 敵情報がない場合は通常シミュレーション
		return _simulate_and_check_win(attacker, defender, tile_info, attacker_player_id, attacker_item)
	
	print("[CPU攻撃] ワーストケース分析開始")
	
	# 敵の対抗手段を収集
	var enemy_items = hand_utils.get_enemy_items(defender_owner)
	var enemy_assists = hand_utils.get_enemy_assist_creatures(defender_owner, defender)
	
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
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	
	# 敵アイテムをすべて試す
	for enemy_item in enemy_items:
		# 防御側クリーチャーのcannot_use制限をチェック
		if not disable_cannot_use:
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
	
	var sim_result = battle_simulator.simulate_battle(
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
	
	if not hand_utils:
		return result
	
	var items = hand_utils.get_items_from_hand(attacker_player_id)
	print("    [アイテム検索] ワーストケース対策アイテムを検索: %d個のアイテム" % items.size())
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	
	for item_entry in items:
		var item_index = item_entry["index"]
		var item = item_entry["data"]
		var item_cost = hand_utils.get_item_cost(item)
		
		# コストチェック
		if creature_cost + item_cost > current_player.magic_power:
			continue
		
		# アイテム破壊対象チェック（敵がアイテム破壊スキルを持っている場合）
		if not enemy_destroy_types.is_empty():
			if hand_utils.is_item_destroy_target(item, enemy_destroy_types):
				print("    [スキップ] %s: 敵のアイテム破壊対象" % item.get("name", "?"))
				continue
		
		# cannot_use制限チェック
		if not disable_cannot_use:
			var check_result = ItemUseRestriction.check_can_use(attacker, item)
			if not check_result.can_use:
				print("    [スキップ] %s: %s" % [item.get("name", "?"), check_result.reason])
				continue
		
		# ワーストケースシミュレーション
		var worst = simulate_worst_case(attacker, defender, tile_info, attacker_player_id, item)
		
		if worst.is_win:
			# 勝てるアイテムが見つかった
			if not result.can_win or item_cost < hand_utils.get_item_cost(result.item):
				# 初めて見つかった or より安いアイテム
				result.can_win = true
				result.item = item
				result.item_index = item_index
	
	return result

# ============================================================
# 共通バトル評価（指定クリーチャーで勝てるか＋最適アイテムを返す）
# ============================================================

## 指定クリーチャーで勝てるか評価し、必要なら最適アイテムを返す
## 通常バトル、移動侵略、スペル移動、防衛で共通使用
## @param my_creature: 自分のクリーチャー
## @param enemy_creature: 相手のクリーチャー
## @param tile_info: タイル情報 {index, element, level, owner}
## @param my_player_id: 自分のプレイヤーID
## @param is_attacker: true=攻撃側, false=防御側
## @return: {can_win: bool, item_index: int, item_data: Dictionary, worst_case: Dictionary}
func evaluate_single_creature_battle(
	my_creature: Dictionary,
	enemy_creature: Dictionary,
	tile_info: Dictionary,
	my_player_id: int,
	is_attacker: bool = true
) -> Dictionary:
	var result = {
		"can_win": false,
		"item_index": -1,
		"item_data": {},
		"worst_case": {}
	}
	
	if not hand_utils or not battle_simulator:
		return result
	
	# 相手がいない場合は勝利
	if enemy_creature.is_empty():
		result.can_win = true
		return result
	
	# 攻撃側/防御側に応じてパラメータを設定
	var attacker: Dictionary
	var defender: Dictionary
	
	if is_attacker:
		attacker = my_creature
		defender = enemy_creature
	else:
		attacker = enemy_creature
		defender = my_creature
	
	# 1. 敵のアイテム破壊・盗みスキルをチェック
	var enemy_destroy_types: Array
	var enemy_has_steal: bool
	
	if is_attacker:
		enemy_destroy_types = hand_utils.defender_has_item_destroy(defender)
		enemy_has_steal = hand_utils.defender_has_item_steal(defender)
	else:
		enemy_destroy_types = hand_utils.attacker_has_item_destroy(attacker)
		enemy_has_steal = hand_utils.attacker_has_item_steal(attacker)
	
	var should_avoid_items = not enemy_destroy_types.is_empty() or enemy_has_steal
	
	# 2. ワーストケースシミュレーション（敵がアイテム/援護を使った場合）
	var worst_case = simulate_worst_case_common(
		my_creature, enemy_creature, tile_info, my_player_id, {}, is_attacker
	)
	result.worst_case = worst_case
	
	if worst_case.is_win:
		# ワーストケースでも勝てる → アイテムなしで可
		result.can_win = true
		return result
	
	# 3. ワーストケースで負ける → アイテムを使って勝てるか探す
	# ただし、敵がアイテム破壊・盗みを持っている場合はアイテムを使わない
	if should_avoid_items:
		return result
	
	# 4. 勝てるアイテムを探す
	var items = hand_utils.get_items_from_hand(my_player_id)
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	
	for item_entry in items:
		var item_index = item_entry.get("index", -1)
		var item_data = item_entry.get("data", {})
		
		# アイテム破壊対象チェック
		if not enemy_destroy_types.is_empty():
			if hand_utils.is_item_destroy_target(item_data, enemy_destroy_types):
				continue  # このアイテムは破壊される
		
		# cannot_use制限チェック
		if not disable_cannot_use:
			var check_result = ItemUseRestriction.check_can_use(my_creature, item_data)
			if not check_result.can_use:
				continue
		
		# ワーストケースシミュレーション（アイテム込み）
		var item_worst_case = simulate_worst_case_common(
			my_creature, enemy_creature, tile_info, my_player_id, item_data, is_attacker
		)
		
		if item_worst_case.is_win:
			result.can_win = true
			result.item_index = item_index
			result.item_data = item_data
			return result
	
	return result


## 攻撃側/防御側両対応のワーストケースシミュレーション
## @param my_creature: 自分のクリーチャー
## @param enemy_creature: 相手のクリーチャー
## @param tile_info: タイル情報
## @param my_player_id: 自分のプレイヤーID
## @param my_item: 自分が使うアイテム
## @param is_attacker: true=攻撃側, false=防御側
func simulate_worst_case_common(
	my_creature: Dictionary,
	enemy_creature: Dictionary,
	tile_info: Dictionary,
	my_player_id: int,
	my_item: Dictionary,
	is_attacker: bool
) -> Dictionary:
	# 攻撃側の場合は既存のsimulate_worst_caseを使用
	if is_attacker:
		return simulate_worst_case(my_creature, enemy_creature, tile_info, my_player_id, my_item)
	
	# 防御側の場合
	return _simulate_worst_case_as_defender(my_creature, enemy_creature, tile_info, my_player_id, my_item)


## 防御側としてのワーストケースシミュレーション
## 敵（攻撃側）がアイテム/援護を使った場合を想定
func _simulate_worst_case_as_defender(
	defender: Dictionary,
	attacker: Dictionary,
	tile_info: Dictionary,
	defender_player_id: int,
	defender_item: Dictionary
) -> Dictionary:
	# 攻撃側プレイヤーIDを計算（2人対戦前提）
	var attacker_player_id = 1 - defender_player_id
	
	if not hand_utils:
		# hand_utilsがない場合は単純シミュレーション
		var simple_tile_info = {
			"element": tile_info.get("element", ""),
			"level": tile_info.get("level", 1),
			"owner": tile_info.get("owner", defender_player_id),
			"tile_index": tile_info.get("index", -1)
		}
		var sim_result = battle_simulator.simulate_battle(
			attacker, defender, simple_tile_info, attacker_player_id, {}, defender_item
		)
		var is_win = sim_result.get("result") == BattleSimulator.BattleResult.DEFENDER_WIN
		return {"is_win": is_win, "sim_result": sim_result, "overkill": 0}
	
	# 敵（攻撃側）の対抗手段を収集
	var enemy_items = hand_utils.get_enemy_items(attacker_player_id)
	var enemy_assists = hand_utils.get_enemy_assist_creatures(attacker_player_id, attacker)
	
	print("[CPU防御WC] 攻撃側プレイヤー: %d, 敵アイテム数: %d, 敵援護数: %d" % [attacker_player_id, enemy_items.size(), enemy_assists.size()])
	for ei in enemy_items:
		print("[CPU防御WC]   敵アイテム: %s" % ei.get("name", "?"))
	
	var sim_tile_info = {
		"element": tile_info.get("element", ""),
		"level": tile_info.get("level", 1),
		"owner": tile_info.get("owner", defender_player_id),
		"tile_index": tile_info.get("index", -1)
	}
	
	# ベースライン: 敵がアイテム/援護なし
	var base_result = battle_simulator.simulate_battle(
		attacker, defender, sim_tile_info, attacker_player_id, {}, defender_item
	)
	# 防御側にとっては「防御側勝利」または「両者生存」が成功（土地を守れた）
	var base_outcome = base_result.get("result", -1)
	var base_is_win = (base_outcome == BattleSimulator.BattleResult.DEFENDER_WIN or 
					   base_outcome == BattleSimulator.BattleResult.ATTACKER_SURVIVED)
	
	var worst_result = {
		"is_win": base_is_win,
		"sim_result": base_result,
		"overkill": 0,
		"worst_case_option": "なし"
	}
	
	print("[CPU防御WC] ベースライン結果: %s → is_win=%s" % [base_outcome, base_is_win])
	
	# 対抗手段がない場合はベースラインを返す
	if enemy_items.is_empty() and enemy_assists.is_empty():
		return worst_result
	
	# cannot_useチェックのためのフラグ確認
	var disable_cannot_use = tile_action_processor and tile_action_processor.debug_disable_cannot_use
	
	# 敵アイテムをすべて試す
	for enemy_item in enemy_items:
		# 攻撃側クリーチャーのcannot_use制限をチェック
		if not disable_cannot_use:
			var check_result = ItemUseRestriction.check_can_use(attacker, enemy_item)
			if not check_result.can_use:
				continue
		
		var sim_result = battle_simulator.simulate_battle(
			attacker, defender, sim_tile_info, attacker_player_id, enemy_item, defender_item
		)
		var outcome = sim_result.get("result", -1)
		# 防御側にとっては「防御側勝利」または「両者生存」が成功
		var is_win = (outcome == BattleSimulator.BattleResult.DEFENDER_WIN or 
					  outcome == BattleSimulator.BattleResult.ATTACKER_SURVIVED)
		
		print("[CPU防御WC]   敵アイテム %s 試行: 結果=%s → is_win=%s" % [enemy_item.get("name", "?"), outcome, is_win])
		
		# 悪化した場合（防御側にとって）
		if worst_result.is_win and not is_win:
			worst_result.is_win = false
			worst_result.sim_result = sim_result
			worst_result.worst_case_option = "アイテム: " + enemy_item.get("name", "?")
			print("[CPU防御WC]   → ワーストケース更新: %s" % worst_result.worst_case_option)
	
	# 敵援護をすべて試す
	for assist in enemy_assists:
		var boosted_attacker = attacker.duplicate(true)
		boosted_attacker["ap"] = boosted_attacker.get("ap", 0) + assist.get("ap", 0)
		boosted_attacker["hp"] = boosted_attacker.get("hp", 0) + assist.get("hp", 0)
		
		var sim_result = battle_simulator.simulate_battle(
			boosted_attacker, defender, sim_tile_info, attacker_player_id, {}, defender_item
		)
		var outcome = sim_result.get("result", -1)
		var is_win = (outcome == BattleSimulator.BattleResult.DEFENDER_WIN or 
					  outcome == BattleSimulator.BattleResult.ATTACKER_SURVIVED)
		
		print("[CPU防御WC]   敵援護 %s 試行: 結果=%s → is_win=%s" % [assist.get("name", "?"), outcome, is_win])
		
		if worst_result.is_win and not is_win:
			worst_result.is_win = false
			worst_result.sim_result = sim_result
			worst_result.worst_case_option = "援護: " + assist.get("name", "?")
			print("[CPU防御WC]   → ワーストケース更新: %s" % worst_result.worst_case_option)
	
	return worst_result

# ============================================================
# 合体データアクセス（CPUMergeEvaluatorへの委譲）
# ============================================================

## 保存された合体データを取得
func get_pending_merge_data() -> Dictionary:
	if merge_evaluator:
		return merge_evaluator.get_pending_merge_data()
	return {}

## 合体データをクリア
func clear_pending_merge_data() -> void:
	if merge_evaluator:
		merge_evaluator.clear_pending_merge_data()

## 合体が選択されているかチェック
func has_pending_merge() -> bool:
	if merge_evaluator:
		return merge_evaluator.has_pending_merge()
	return false

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
