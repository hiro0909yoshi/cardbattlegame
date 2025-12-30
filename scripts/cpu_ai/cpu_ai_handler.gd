class_name CPUAIHandler
extends Node

# CPU AI処理クラス（オーケストレーター）
# 各判断をcpu_battle_ai.gdとcpu_hand_utils.gdに委譲

signal summon_decided(card_index: int)
signal battle_decided(creature_index: int, item_index: int)
signal level_up_decided(do_upgrade: bool)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

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

# 分割されたAIモジュール
var hand_utils: CPUHandUtils = null
var battle_ai: CPUBattleAI = null

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
	
	# 手札ユーティリティを初期化
	hand_utils = CPUHandUtils.new()
	hand_utils.setup_systems(card_system, board_system, player_system, player_buff_system)
	
	# バトルAIを初期化
	battle_ai = CPUBattleAI.new()
	battle_ai.setup_systems(card_system, board_system, player_system, player_buff_system, game_flow_manager_ref)
	battle_ai.set_hand_utils(hand_utils)

# GameFlowManagerを後から設定
func set_game_flow_manager(gf_manager) -> void:
	game_flow_manager_ref = gf_manager
	if battle_ai:
		battle_ai.set_game_flow_manager(gf_manager)

# ============================================================
# 判断メソッド（外部から呼ばれる）
# ============================================================

# CPU召喚判断
func decide_summon(current_player) -> void:
	decision_attempts += 1
	
	# 最大試行回数チェック
	if decision_attempts > MAX_DECISION_ATTEMPTS:
		decision_attempts = 0
		emit_signal("summon_decided", -1)
		return
	
	var affordable_cards = hand_utils.find_affordable_cards(current_player)
	if affordable_cards.is_empty():
		decision_attempts = 0
		emit_signal("summon_decided", -1)
		return
	
	# 確率で召喚を決定
	if randf() < GameConstants.CPU_SUMMON_RATE:
		var card_index = hand_utils.select_best_summon_card(current_player, affordable_cards)
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
		var card_index = hand_utils.select_cheapest_card(current_player)
		if card_index >= 0 and hand_utils.can_afford_card(current_player, card_index):
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
	
	# クリーチャー×アイテムの全組み合わせを評価（battle_aiに委譲）
	var best_result = battle_ai.evaluate_all_combinations_for_battle(current_player, defender, tile_info)
	
	# 勝てるなら攻撃、勝てないなら見送り
	# 即死ギャンブルや無効化+即死の場合も攻撃する
	var should_attack = best_result.can_win or \
		best_result.get("is_instant_death_gamble", false) or \
		best_result.get("is_nullify_instant_death", false)
	
	if should_attack:
		var creature = card_system.get_card_data_for_player(current_player.id, best_result.creature_index)
		if best_result.get("is_instant_death_gamble", false):
			print("[CPU AI] バトル決定: %s で即死に賭けます（確率: %d%%）" % [
				creature.get("name", "?"),
				best_result.get("instant_death_probability", 0)
			])
		elif best_result.get("is_nullify_instant_death", false):
			print("[CPU AI] バトル決定: %s で無効化+即死を狙います（確率: %d%%）" % [
				creature.get("name", "?"),
				best_result.get("instant_death_probability", 0)
			])
		elif best_result.item_index >= 0:
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

# ============================================================
# ユーティリティメソッド（互換性のため残す）
# ============================================================

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
	if battle_ai:
		battle_ai.set_simulator_log_enabled(enabled)

# ============================================================
# 合体データアクセサ（互換性のため委譲）
# ============================================================

## 保存された合体データを取得
func get_pending_merge_data() -> Dictionary:
	if battle_ai:
		return battle_ai.get_pending_merge_data()
	return {}

## 合体データをクリア
func clear_pending_merge_data():
	if battle_ai:
		battle_ai.clear_pending_merge_data()

## 合体が選択されているかチェック
func has_pending_merge() -> bool:
	if battle_ai:
		return battle_ai.has_pending_merge()
	return false

# ============================================================
# 手札アクセサ（互換性のため委譲）
# ============================================================

## 支払い可能なカードを検索
func find_affordable_cards(current_player) -> Array:
	if hand_utils:
		return hand_utils.find_affordable_cards(current_player)
	return []

## カードが支払い可能かチェック
func can_afford_card(current_player, card_index: int) -> bool:
	if hand_utils:
		return hand_utils.can_afford_card(current_player, card_index)
	return false

## カードコストを計算
func calculate_card_cost(card_data: Dictionary, player_id: int) -> int:
	if hand_utils:
		return hand_utils.calculate_card_cost(card_data, player_id)
	return 0

## 手札からアイテムカードを抽出
func get_items_from_hand(player_id: int) -> Array:
	if hand_utils:
		return hand_utils.get_items_from_hand(player_id)
	return []

## 手札からクリーチャーカードを抽出
func get_creatures_from_hand(player_id: int) -> Array:
	if hand_utils:
		return hand_utils.get_creatures_from_hand(player_id)
	return []

## 敵プレイヤーの手札を取得（密命カードを除外）
func get_enemy_hand(enemy_player_id: int) -> Array:
	if hand_utils:
		return hand_utils.get_enemy_hand(enemy_player_id)
	return []

## 敵がアイテムを持っているかチェック（種類指定可能）
func enemy_has_item(enemy_player_id: int, item_type: String = "") -> bool:
	if hand_utils:
		return hand_utils.enemy_has_item(enemy_player_id, item_type)
	return false

## 敵が無効化アイテム（防具）を持っているかチェック
func enemy_has_nullify_item(enemy_player_id: int) -> bool:
	if hand_utils:
		return hand_utils.enemy_has_nullify_item(enemy_player_id)
	return false

## 敵の手札からアイテム一覧を取得
func get_enemy_items(enemy_player_id: int) -> Array:
	if hand_utils:
		return hand_utils.get_enemy_items(enemy_player_id)
	return []
