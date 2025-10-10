extends Node
class_name CPUAIHandler

# CPU AI処理クラス
# CPU判断ロジックを管理

signal summon_decided(card_index: int)
signal battle_decided(card_index: int)
signal level_up_decided(do_upgrade: bool)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# システム参照
var card_system: CardSystem
var board_system
var player_system: PlayerSystem
var battle_system: BattleSystem
var skill_system: SkillSystem

func _ready():
	pass

# システム参照を設定
func setup_systems(c_system: CardSystem, b_system, p_system: PlayerSystem, bt_system: BattleSystem, s_system: SkillSystem):
	card_system = c_system
	board_system = b_system
	player_system = p_system
	battle_system = bt_system
	skill_system = s_system

# CPU召喚判断
func decide_summon(current_player) -> void:
	print("CPU召喚判断中...")
	
	var affordable_cards = find_affordable_cards(current_player)
	if affordable_cards.is_empty():
		print("CPU: 召喚可能なカードがありません")
		emit_signal("summon_decided", -1)
		return
	
	# 確率で召喚を決定
	if randf() < GameConstants.CPU_SUMMON_RATE:
		var card_index = select_best_summon_card(current_player, affordable_cards)
		if card_index >= 0:
			print("CPU: クリーチャーを召喚します")
			emit_signal("summon_decided", card_index)
			return
	
	print("CPU: 召喚をスキップ")
	emit_signal("summon_decided", -1)

# CPU侵略判断（守備なしの敵地）
func decide_invasion(current_player, _tile_info: Dictionary) -> void:
	print("CPU侵略判断中...")
	
	# 確率で侵略を決定
	if randf() < GameConstants.CPU_INVASION_RATE:
		var card_index = select_cheapest_card(current_player)
		if card_index >= 0 and can_afford_card(current_player, card_index):
			print("CPU: 無防備な土地を侵略します！")
			emit_signal("battle_decided", card_index)
			return
	
	print("CPU: 侵略をスキップして通行料を支払います")
	emit_signal("battle_decided", -1)

# CPUバトル判断
func decide_battle(current_player, tile_info: Dictionary) -> void:
	print("CPU思考中...")
	
	var defender = tile_info.creature
	var best_result = evaluate_all_cards_for_battle(current_player, defender, tile_info)
	
	# 確率とスコアで判断
	if best_result.index >= 0 and best_result.score > -10 and randf() < GameConstants.CPU_BATTLE_RATE:
		print("CPU: バトルを仕掛けます！")
		emit_signal("battle_decided", best_result.index)
	else:
		print("CPU: 通行料を支払います")
		emit_signal("battle_decided", -1)

# CPUレベルアップ判断
func decide_level_up(current_player, tile_info: Dictionary) -> void:
	print("CPUレベルアップ判断中...")
	
	var upgrade_cost = board_system.get_upgrade_cost(tile_info.get("index", 0))
	
	# 魔力とレベルアップ確率で判断
	if current_player.magic_power >= upgrade_cost and randf() < GameConstants.CPU_LEVELUP_RATE:
		print("CPU: 土地をレベルアップします（コスト: ", upgrade_cost, "G）")
		emit_signal("level_up_decided", true)
	else:
		print("CPU: レベルアップをスキップ")
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
			var cost = card.get("cost", 999)
			if cost < min_cost:
				min_cost = cost
				best_index = index
	
	return best_index

# 支払い可能なカードを検索
func find_affordable_cards(current_player) -> Array:
	if not card_system:
		return []
	
	return card_system.find_affordable_cards_for_player(
		current_player.id, 
		current_player.magic_power
	)

# カードが支払い可能かチェック
func can_afford_card(current_player, card_index: int) -> bool:
	var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
	if card_data.is_empty():
		return false
	
	var cost = calculate_card_cost(card_data, current_player.id)
	return current_player.magic_power >= cost

# カードコストを計算
func calculate_card_cost(card_data: Dictionary, player_id: int) -> int:
	var base_cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	
	if skill_system:
		return skill_system.modify_card_cost(base_cost, card_data, player_id)
	
	return base_cost

# バトル用の全カード評価
func evaluate_all_cards_for_battle(current_player, defender: Dictionary, tile_info: Dictionary) -> Dictionary:
	var best_result = {"index": -1, "score": -999}
	
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	for i in range(hand_size):
		var card = card_system.get_card_data_for_player(current_player.id, i)
		if card.is_empty():
			continue
		
		# コストチェック
		if not can_afford_card(current_player, i):
			continue
		
		# バトル予測
		var score = evaluate_battle_outcome(card, defender, tile_info)
		if score > best_result.score:
			best_result.score = score
			best_result.index = i
	
	return best_result

# バトル結果を評価
# バトル結果を評価（予測ロジックを内包）
func evaluate_battle_outcome(attacker: Dictionary, defender: Dictionary, _tile_info: Dictionary) -> int:
	# 基本的な戦力差を計算
	var attacker_st = attacker.get("ap", 0)
	var attacker_hp = attacker.get("hp", 0)
	var defender_st = defender.get("ap", 0)
	var defender_hp = defender.get("hp", 0)
	
	# 簡易評価：攻撃力 - 防御HP
	var score = attacker_st - defender_hp
	
	# 勝利可能性の判定
	if attacker_st >= defender_hp:
		score += 50  # 勝利可能性ボーナス
	elif defender_st >= attacker_hp:
		score -= 50  # 負ける可能性ペナルティ
	
	return score

# CPUの思考時間をシミュレート
func simulate_thinking_time() -> void:
	await get_tree().create_timer(0.5).timeout
	print("CPU: 考え中...")

# デバッグ：CPU判断を表示
func debug_print_decision(action: String, params: Dictionary):
	print("[CPU AI] アクション: ", action)
	for key in params:
		print("  ", key, ": ", params[key])
