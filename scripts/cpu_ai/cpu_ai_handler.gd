extends Node
class_name CPUAIHandler

# CPU AI処理クラス
# CPU判断ロジックを管理

signal summon_decided(card_index: int)
signal battle_decided(creature_index: int, item_index: int)
signal level_up_decided(do_upgrade: bool)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")

# 無限ループ防止用定数
const MAX_DECISION_ATTEMPTS = 3

# 試行回数カウンター
var decision_attempts = 0

# システム参照
var card_system: CardSystem
var board_system
var player_system: PlayerSystem
var battle_system: BattleSystem
var player_buff_system: PlayerBuffSystem
var game_flow_manager_ref = null

# バトルシミュレーター
var battle_simulator: BattleSimulator = null

func _ready():
	pass

# システム参照を設定
func setup_systems(c_system: CardSystem, b_system, p_system: PlayerSystem, bt_system: BattleSystem, s_system: PlayerBuffSystem, gf_manager = null):
	card_system = c_system
	board_system = b_system
	player_system = p_system
	battle_system = bt_system
	player_buff_system = s_system
	game_flow_manager_ref = gf_manager
	
	# BattleSimulatorを初期化
	battle_simulator = BattleSimulatorScript.new()
	battle_simulator.setup_systems(board_system, card_system, player_system, game_flow_manager_ref)
	battle_simulator.enable_log = true  # デバッグ用にログ有効

# GameFlowManagerを後から設定
func set_game_flow_manager(gf_manager) -> void:
	game_flow_manager_ref = gf_manager
	if battle_simulator:
		battle_simulator.setup_systems(board_system, card_system, player_system, game_flow_manager_ref)

# CPU召喚判断
func decide_summon(current_player) -> void:
	decision_attempts += 1
	
	# 最大試行回数チェック
	if decision_attempts > MAX_DECISION_ATTEMPTS:
		decision_attempts = 0
		emit_signal("summon_decided", -1)
		return
	
	var affordable_cards = find_affordable_cards(current_player)
	if affordable_cards.is_empty():
		decision_attempts = 0
		emit_signal("summon_decided", -1)
		return
	
	# 確率で召喚を決定
	if randf() < GameConstants.CPU_SUMMON_RATE:
		var card_index = select_best_summon_card(current_player, affordable_cards)
		if card_index >= 0:
			var card = card_system.get_card_data_for_player(current_player.id, card_index)
			print("[CPU AI] 召喚: %s" % card.get("name", "?"))
			decision_attempts = 0
			emit_signal("summon_decided", card_index)
			return
	
	decision_attempts = 0
	emit_signal("summon_decided", -1)

# CPU侵略判断（守備なしの敵地）
func decide_invasion(current_player, _tile_info: Dictionary) -> void:
	decision_attempts += 1
	
	# 最大試行回数チェック
	if decision_attempts > MAX_DECISION_ATTEMPTS:
		decision_attempts = 0
		emit_signal("battle_decided", -1, -1)
		return
	
	# 確率で侵略を決定
	if randf() < GameConstants.CPU_INVASION_RATE:
		var card_index = select_cheapest_card(current_player)
		if card_index >= 0 and can_afford_card(current_player, card_index):
			var card = card_system.get_card_data_for_player(current_player.id, card_index)
			print("[CPU AI] 侵略: %s で無防備な土地を侵略" % card.get("name", "?"))
			decision_attempts = 0
			emit_signal("battle_decided", card_index, -1)  # アイテムなし
			return
	
	decision_attempts = 0
	emit_signal("battle_decided", -1, -1)

# CPUバトル判断（クリーチャー×アイテムの組み合わせを評価）
# 基本ルール: 勝てるなら攻撃、勝てないなら見送り
func decide_battle(current_player, tile_info: Dictionary) -> void:
	decision_attempts += 1
	print("[CPU AI] バトル判断中...")
	
	# 最大試行回数チェック
	if decision_attempts > MAX_DECISION_ATTEMPTS:
		print("[CPU AI] 最大試行回数に達しました（バトル）")
		decision_attempts = 0
		emit_signal("battle_decided", -1, -1)
		return
	
	var defender = tile_info.creature
	var defender_name = defender.get("name", "?")
	print("[CPU AI] 防御側: %s (AP:%d, HP:%d)" % [defender_name, defender.get("ap", 0), defender.get("hp", 0)])
	
	# クリーチャー×アイテムの全組み合わせを評価
	var best_result = evaluate_all_combinations_for_battle(current_player, defender, tile_info)
	
	# 勝てるなら攻撃、勝てないなら見送り
	if best_result.can_win:
		var creature = card_system.get_card_data_for_player(current_player.id, best_result.creature_index)
		if best_result.item_index >= 0:
			var item = card_system.get_card_data_for_player(current_player.id, best_result.item_index)
			print("[CPU AI] バトル決定: %s + %s で侵略します" % [
				creature.get("name", "?"),
				item.get("name", "?")
			])
		else:
			print("[CPU AI] バトル決定: %s で侵略します" % creature.get("name", "?"))
		decision_attempts = 0
		emit_signal("battle_decided", best_result.creature_index, best_result.item_index)
	else:
		print("[CPU AI] 勝てる組み合わせなし → 通行料を支払います")
		decision_attempts = 0
		emit_signal("battle_decided", -1, -1)

# CPUレベルアップ判断
func decide_level_up(current_player, tile_info: Dictionary) -> void:
	decision_attempts += 1
	
	# 最大試行回数チェック
	if decision_attempts > MAX_DECISION_ATTEMPTS:
		decision_attempts = 0
		emit_signal("level_up_decided", false)
		return
	
	var upgrade_cost = board_system.get_upgrade_cost(tile_info.get("index", 0))
	
	# 魔力とレベルアップ確率で判断
	if current_player.magic_power >= upgrade_cost and randf() < GameConstants.CPU_LEVELUP_RATE:
		print("[CPU AI] レベルアップ: コスト%dG" % upgrade_cost)
		decision_attempts = 0
		emit_signal("level_up_decided", true)
	else:
		decision_attempts = 0
		emit_signal("level_up_decided", false)

# 召喚用の最適カードを選択
func select_best_summon_card(current_player, affordable_cards: Array) -> int:
	# 簡易実装：最も安いカードを選択
	return select_cheapest_from_list(current_player, affordable_cards)

# 最も安いカードを選択
func select_cheapest_card(current_player) -> int:
	if not card_system:
		return -1
	
	return card_system.get_cheapest_card_index_for_player(current_player.id)

# リストから最も安いカードを選択
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

# 支払い可能なカードを検索
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

# カードが支払い可能かチェック
func can_afford_card(current_player, card_index: int) -> bool:
	var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
	if card_data.is_empty():
		return false
	
	var cost = calculate_card_cost(card_data, current_player.id)
	return current_player.magic_power >= cost

# カードコストを計算
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

# バトル用の全カード評価
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
		if not can_afford_card(current_player, i):
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

# バトル結果を評価（BattleSimulatorを使用）
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
		{},  # 攻撃側アイテム（後で実装）
		{}   # 防御側アイテム（後で実装）
	)
	
	# スコア計算
	var score = _calculate_battle_score(sim_result, attacker, defender)
	
	return {"score": score, "sim_result": sim_result}

# シミュレーション結果からスコアを計算
func _calculate_battle_score(sim_result: Dictionary, attacker: Dictionary, defender: Dictionary) -> int:
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

# フォールバック: 簡易評価（BattleSimulatorがない場合）
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

# CPUの思考時間をシミュレート
func simulate_thinking_time() -> void:
	await get_tree().create_timer(0.5).timeout

# デバッグ：CPU判断を表示
func debug_print_decision(action: String, params: Dictionary):
	print("[CPU AI] アクション: ", action)
	for key in params:
		print("  ", key, ": ", params[key])

# BattleSimulatorのログ出力を切り替え
func set_simulator_log_enabled(enabled: bool) -> void:
	if battle_simulator:
		battle_simulator.enable_log = enabled

# ============================================================
# アイテム付きバトル評価
# ============================================================

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
		var item_cost = _get_item_cost(attacker_item)
		# アイテムを使う価値があるか：勝てるようになる場合はボーナス、既に勝てる場合はペナルティ
		if sim_result.get("result") == BattleSimulator.BattleResult.ATTACKER_WIN:
			score += 10  # アイテムで勝てるならボーナス
		score -= item_cost / 10  # アイテムコスト分のペナルティ
	
	return {"score": score, "sim_result": sim_result, "item": attacker_item}

## アイテムのコストを取得
func _get_item_cost(item: Dictionary) -> int:
	var cost_data = item.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
	return cost_data * GameConstants.CARD_COST_MULTIPLIER

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
	
	var creatures = get_creatures_from_hand(current_player.id)
	var items = get_items_from_hand(current_player.id)
	
	print("[CPU AI] バトル組み合わせ評価: クリーチャー%d体, アイテム%d個" % [creatures.size(), items.size()])
	
	# 勝てる組み合わせを収集
	var winning_combinations: Array = []
	
	for creature_entry in creatures:
		var creature_index = creature_entry["index"]
		var creature = creature_entry["data"]
		var creature_cost = calculate_card_cost(creature, current_player.id)
		
		# コストチェック
		if not can_afford_card(current_player, creature_index):
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
			var item_cost = _get_item_cost(item)
			
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
	
	# 勝てる組み合わせがない場合
	if winning_combinations.is_empty():
		print("[CPU AI] 勝てる組み合わせなし → バトル見送り")
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
