class_name CPUAIHandler
extends Node

# CPU AI処理クラス（オーケストレーター）
# 各判断をcpu_battle_ai.gdとcpu_hand_utils.gdに委譲

signal summon_decided(card_index: int)
signal battle_decided(creature_index: int, item_index: int)
signal level_up_decided(do_upgrade: bool)
signal territory_command_decided(command: Dictionary)

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
var territory_ai: CPUTerritoryAI = null

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
	
	# 領地コマンドAIを初期化
	territory_ai = CPUTerritoryAI.new()
	# creature_managerはBaseTileの静的参照から取得
	var creature_manager = BaseTile.creature_manager if BaseTile.creature_manager else null
	territory_ai.setup(board_system, card_system, player_system, creature_manager)
	
	# クリーチャー合成システムを設定（カード犠牲選択用）
	if CardLoader:
		var creature_synth = CreatureSynthesis.new(CardLoader)
		territory_ai.set_creature_synthesis(creature_synth)
	
	# TileActionProcessorを設定（土地条件チェック用）
	if board_system and board_system.has_node("TileActionProcessor"):
		var tap = board_system.get_node("TileActionProcessor")
		territory_ai.set_tile_action_processor(tap)

# GameFlowManagerを後から設定
func set_game_flow_manager(gf_manager) -> void:
	game_flow_manager_ref = gf_manager
	if battle_ai:
		battle_ai.set_game_flow_manager(gf_manager)

# ============================================================
# 判断メソッド（外部から呼ばれる）
# ============================================================

# CPU召喚判断（タイル属性を考慮）
func decide_summon(current_player, tile_element: String = "") -> void:
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
	
	# 属性一致カードを優先選択
	var card_index = hand_utils.select_best_summon_card(current_player, affordable_cards, tile_element)
	if card_index >= 0:
		var card = card_system.get_card_data_for_player(current_player.id, card_index)
		var card_element = card.get("element", "")
		
		# 属性一致なら必ず召喚、不一致なら確率で召喚
		var is_element_match = (card_element == tile_element or tile_element == "neutral")
		if is_element_match or randf() < GameConstants.CPU_SUMMON_RATE:
			print("[CPU AI] 召喚: %s (属性: %s, タイル: %s)" % [card.get("name", "?"), card_element, tile_element])
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
	
	print("[CPU AI] バトル判断結果: can_win=%s, instant_death=%s, nullify_instant=%s, creature_index=%d" % [
		best_result.can_win,
		best_result.get("is_instant_death_gamble", false),
		best_result.get("is_nullify_instant_death", false),
		best_result.creature_index
	])
	
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
# 領地コマンド判断
# ============================================================

## 領地コマンド判断（召喚フェーズ用）
## 召喚 vs 領地コマンドのどちらが得かを判断
func decide_territory_command(current_player, tile_info: Dictionary, situation: String = "own_land") -> void:
	decision_attempts += 1
	
	if decision_attempts > MAX_DECISION_ATTEMPTS:
		decision_attempts = 0
		emit_signal("territory_command_decided", {})
		return
	
	if territory_ai == null:
		print("[CPU AI] territory_ai未初期化")
		decision_attempts = 0
		emit_signal("territory_command_decided", {})
		return
	
	# コンテキストを構築
	var context = _build_territory_context(current_player, tile_info, situation)
	
	# 全オプションを評価
	var best_option = territory_ai.evaluate_all_options(context)
	
	if best_option.is_empty():
		print("[CPU AI] 領地コマンド: 有効なオプションなし")
		decision_attempts = 0
		emit_signal("territory_command_decided", {})
		return
	
	print("[CPU AI] 領地コマンド決定: %s (スコア: %d)" % [best_option.get("type", "?"), best_option.get("score", 0)])
	decision_attempts = 0
	emit_signal("territory_command_decided", best_option)


## 召喚 vs 領地コマンドを比較して最適な行動を返す
func decide_summon_or_territory(current_player, tile_info: Dictionary) -> Dictionary:
	print("[CPU Territory] decide_summon_or_territory 開始")
	print("[CPU Territory] tile_info: %s" % tile_info)
	
	if territory_ai == null:
		print("[CPU Territory] territory_ai is null → 召喚")
		return {"action": "summon"}
	
	var context = _build_territory_context(current_player, tile_info, "empty_land")
	print("[CPU Territory] context: %s" % context)
	
	# 属性一致クリーチャーがあれば召喚優先
	var tile_element = tile_info.get("element", "")
	var has_matching_creature = _has_matching_creature(current_player, tile_element)
	print("[CPU Territory] tile_element: %s, has_matching_creature: %s" % [tile_element, has_matching_creature])
	
	if has_matching_creature:
		print("[CPU Territory] 属性一致クリーチャーあり → 召喚優先")
		return {"action": "summon"}
	
	# 領地コマンドを評価
	print("[CPU Territory] 領地コマンドを評価中...")
	var best_option = territory_ai.evaluate_all_options(context)
	print("[CPU Territory] best_option: %s" % best_option)
	
	if best_option.is_empty():
		print("[CPU Territory] 有効なオプションなし → 召喚")
		return {"action": "summon"}
	
	# 属性不一致召喚のスコアは低い
	var summon_score = CPUTerritoryAI.SUMMON_MISMATCH_SCORE
	var command_score = best_option.get("score", 0)
	print("[CPU Territory] summon_score(不一致): %d, command_score: %d" % [summon_score, command_score])
	
	if command_score > summon_score:
		print("[CPU Territory] 領地コマンド選択: %s" % best_option.get("type", "?"))
		return {"action": "territory_command", "command": best_option}
	
	print("[CPU Territory] スコア不足 → 召喚")
	return {"action": "summon"}


## 敵領地での判断（侵略 vs 領地コマンド）
func decide_invasion_or_territory(current_player, tile_info: Dictionary) -> Dictionary:
	if territory_ai == null:
		return {"action": "battle"}
	
	var context = _build_territory_context(current_player, tile_info, "enemy_land")
	
	# 戦闘可能か判定
	var can_win = _can_win_current_battle(current_player, tile_info)
	
	if not can_win:
		# 倒せない場合は領地コマンドを検討
		var territory_option = territory_ai.evaluate_all_options(context)
		if not territory_option.is_empty():
			return {"action": "territory_command", "command": territory_option}
		return {"action": "skip"}
	
	# 倒せる場合は侵略スコアと領地コマンドスコアを比較
	var best_option = territory_ai.evaluate_all_options(context)
	
	# 侵略スコアを計算（territory_aiの_evaluate_invasionと同じ計算）
	var tile = board_system.tile_nodes.get(tile_info.get("index", -1))
	if tile == null:
		return {"action": "battle"}
	
	var chain_bonus = board_system.tile_data_manager.calculate_chain_bonus(tile_info.get("index", 0), tile.owner_id)
	var level = tile.level
	var invasion_score = (level * chain_bonus * 100 + 50) * 2  # ×2は敵資産減少
	
	var command_score = best_option.get("score", 0)
	
	if command_score > invasion_score:
		return {"action": "territory_command", "command": best_option}
	
	return {"action": "battle"}


## 領地コマンド用コンテキストを構築
func _build_territory_context(current_player, tile_info: Dictionary, situation: String) -> Dictionary:
	var toll = 0
	if situation == "enemy_land":
		toll = tile_info.get("toll", 0)
	
	return {
		"player_id": current_player.id,
		"current_magic": current_player.magic_power,
		"current_tile_index": tile_info.get("index", -1),
		"situation": situation,
		"toll": toll
	}


## 属性一致クリーチャーを持っているかチェック
func _has_matching_creature(current_player, tile_element: String) -> bool:
	if hand_utils == null:
		print("[CPU Territory] _has_matching_creature: hand_utils is null")
		return false
	
	# デバッグフラグを取得
	var disable_lands = false
	var disable_cannot_summon = false
	if hand_utils.tile_action_processor:
		disable_lands = hand_utils.tile_action_processor.debug_disable_lands_required
		disable_cannot_summon = hand_utils.tile_action_processor.debug_disable_cannot_summon
	
	var creatures = hand_utils.get_creatures_from_hand(current_player.id)
	print("[CPU Territory] _has_matching_creature: tile_element=%s, creatures count=%d" % [tile_element, creatures.size()])
	
	for creature_entry in creatures:
		# get_creatures_from_handは{"index": i, "data": card}を返す
		var card_index = creature_entry.get("index", -1)
		var card_data = creature_entry.get("data", {})
		var creature_element = card_data.get("element", "")
		var creature_name = card_data.get("name", "?")
		var can_afford = hand_utils.can_afford_card(current_player, card_index)
		
		# 土地条件チェック（フラグで無効化可能）
		var can_summon_lands = disable_lands or hand_utils._check_lands_required(card_data, current_player.id)
		# 配置制限チェック（フラグで無効化可能）
		var can_summon_element = disable_cannot_summon or hand_utils._check_cannot_summon(card_data, tile_element)
		var can_summon = can_summon_lands and can_summon_element
		print("[CPU Territory]   - %s (element=%s, can_afford=%s, can_summon=%s)" % [creature_name, creature_element, can_afford, can_summon])
		
		if creature_element == tile_element or tile_element == "neutral":
			if can_afford and can_summon:
				print("[CPU Territory]   → 属性一致で召喚可能!")
				return true
	
	print("[CPU Territory] _has_matching_creature: 属性一致クリーチャーなし")
	return false


## 現在のタイルでの戦闘に勝てるかチェック
func _can_win_current_battle(current_player, tile_info: Dictionary) -> bool:
	if battle_ai == null:
		return false
	
	var defender = tile_info.get("creature", {})
	if defender.is_empty():
		return true  # クリーチャーがいなければ勝ち
	
	# ワーストケースを考慮した評価を行う
	var best_result = battle_ai.evaluate_all_combinations_for_battle(current_player, defender, tile_info)
	
	# can_winがtrue、または即死ギャンブル/無効化+即死が可能な場合
	var can_attack = best_result.get("can_win", false) or \
		best_result.get("is_instant_death_gamble", false) or \
		best_result.get("is_nullify_instant_death", false)
	
	return can_attack


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
