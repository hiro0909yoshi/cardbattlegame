class_name CPUAIHandler
extends Node

# CPU AI処理クラス（オーケストレーター）
# 各判断をcpu_battle_ai.gdとcpu_hand_utils.gdに委譲

signal summon_decided(card_index: int)
signal battle_decided(creature_index: int, item_index: int)
signal level_up_decided(do_upgrade: bool)
signal territory_command_decided(command: Dictionary)

# 定数・共通クラスをpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")
const CPUAIConstantsScript = preload("res://scripts/cpu_ai/cpu_ai_constants.gd")
const CPUBattlePolicyScript = preload("res://scripts/cpu_ai/cpu_battle_policy.gd")

# 試行回数カウンター
var decision_attempts = 0

# バトルポリシー（性格）
var battle_policy: CPUBattlePolicyScript = null

# ターン内の侵略ポリシーキャッシュ（同一ターン内で一貫した判断を保つ）
var _turn_attack_action_cache: int = -1

# 共有コンテキスト
var context: CPUAIContextScript = null

# システム参照（後方互換性のため残す、contextから取得）
var card_system: CardSystem:
	get: return context.card_system if context else null
var board_system:
	get: return context.board_system if context else null
var player_system: PlayerSystem:
	get: return context.player_system if context else null
var battle_system: BattleSystem:
	get: return context.battle_system if context else null
var player_buff_system: PlayerBuffSystem:
	get: return context.player_buff_system if context else null
var game_flow_manager_ref:
	get: return context.game_flow_manager if context else null

# 分割されたAIモジュール
var hand_utils: CPUHandUtils:
	get: return context.get_hand_utils() if context else null
var battle_ai: CPUBattleAI = null
var territory_ai: CPUTerritoryAI = null

func _ready():
	pass

# システム参照を設定
func setup_systems(c_system: CardSystem, b_system, p_system: PlayerSystem, bt_system: BattleSystem, s_system: PlayerBuffSystem, gf_manager = null):
	# 既存のbattle_policyを保持
	var existing_policy = battle_policy
	# コンテキストを初期化
	context = CPUAIContextScript.new()
	context.setup(b_system, p_system, c_system)
	context.setup_optional(
		BaseTile.creature_manager if BaseTile.creature_manager else null,
		null,  # lap_system
		gf_manager,
		bt_system,
		s_system
	)
	
	# バトルAIを初期化（context方式）
	battle_ai = CPUBattleAI.new()
	battle_ai.setup_with_context(context)
	
	# ドミニオコマンドAIを初期化（context方式）
	territory_ai = CPUTerritoryAI.new()
	territory_ai.setup_with_context(context)
	
	# クリーチャー合成システムを設定（カード犠牲選択用）
	if CardLoader:
		var creature_synth = CreatureSynthesis.new(CardLoader)
		territory_ai.set_creature_synthesis(creature_synth)
	
	# TileActionProcessorを設定（土地条件チェック用）
	if context.tile_action_processor:
		territory_ai.set_tile_action_processor(context.tile_action_processor)
	
	# 既存のbattle_policyを復元
	if existing_policy:
		battle_policy = existing_policy


## 共有コンテキストを取得（他のAIモジュールから参照用）
func get_context() -> CPUAIContextScript:
	return context


# GameFlowManagerを後から設定
func set_game_flow_manager(gf_manager) -> void:
	if context:
		context.set_game_flow_manager(gf_manager)
	if battle_ai:
		battle_ai.set_game_flow_manager(gf_manager)

## バトルポリシーを設定
func set_battle_policy(policy: CPUBattlePolicyScript) -> void:
	battle_policy = policy
	if policy:
		print("[CPU AI] バトルポリシーを設定")
		policy.print_weights()

## JSONデータからバトルポリシーを読み込んで設定
func load_battle_policy_from_json(policy_data: Dictionary) -> void:
	battle_policy = CPUBattlePolicyScript.new()
	battle_policy.load_from_json(policy_data)
	print("[CPU AI] JSONからバトルポリシーを読み込み")
	battle_policy.print_weights()
	# コンテキストにも反映
	if context:
		context.battle_policy = battle_policy

## プリセットポリシーを設定
func set_battle_policy_preset(preset_name: String) -> void:
	match preset_name:
		"tutorial":
			battle_policy = CPUBattlePolicyScript.create_tutorial_policy()
		"standard":
			battle_policy = CPUBattlePolicyScript.create_standard_policy()
		"optimistic":
			battle_policy = CPUBattlePolicyScript.create_optimistic_policy()
		"passive":
			battle_policy = CPUBattlePolicyScript.create_passive_policy()
		"balanced":
			battle_policy = CPUBattlePolicyScript.create_balanced_policy()
		_:
			battle_policy = CPUBattlePolicyScript.create_balanced_policy()
	print("[CPU AI] プリセットポリシー '%s' を設定" % preset_name)
	battle_policy.print_weights()
	# コンテキストにも反映
	if context:
		context.battle_policy = battle_policy

# ============================================================
# ターン管理
# ============================================================

## ターン開始時にキャッシュをリセット
## CPUターン開始時に必ず呼び出すこと
func reset_turn_cache() -> void:
	_turn_attack_action_cache = -1
	print("[CPU AI] ターンキャッシュをリセット")

# ============================================================
# 判断メソッド（外部から呼ばれる）
# ============================================================

# CPU召喚判断（タイル属性を考慮）
func decide_summon(current_player, tile_element: String = "") -> void:
	decision_attempts += 1
	
	# 最大試行回数チェック
	if decision_attempts > CPUAIConstantsScript.MAX_DECISION_ATTEMPTS:
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
		var summon_rate = _get_summon_rate()
		print("[CPU AI] 召喚判定: card=%s, element=%s, tile=%s, match=%s, rate=%.2f" % [
			card.get("name", "?"), card_element, tile_element, is_element_match, summon_rate])
		if is_element_match or randf() < summon_rate:
			print("[CPU AI] 召喚: %s (属性: %s, タイル: %s)" % [card.get("name", "?"), card_element, tile_element])
			decision_attempts = 0
			emit_signal("summon_decided", card_index)
			return
		else:
			print("[CPU AI] 召喚スキップ: 確率判定失敗")
	
	decision_attempts = 0
	emit_signal("summon_decided", -1)

# CPU侵略判断（守備なしの敵地）
func decide_invasion(current_player, _tile_info: Dictionary) -> void:
	decision_attempts += 1
	
	# 最大試行回数チェック
	if decision_attempts > CPUAIConstantsScript.MAX_DECISION_ATTEMPTS:
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
	if decision_attempts > CPUAIConstantsScript.MAX_DECISION_ATTEMPTS:
		print("[CPU AI] 最大試行回数に達しました（バトル）")
		decision_attempts = 0
		emit_signal("battle_decided", -1, -1)
		return
	
	var defender = tile_info.creature
	var defender_name = defender.get("name", "?")
	print("[CPU AI] 防御側: %s (AP:%d, HP:%d)" % [defender_name, defender.get("ap", 0), defender.get("hp", 0)])
	
	# クリーチャー×アイテムの全組み合わせを評価（battle_aiに委譲）
	var eval_result = battle_ai.evaluate_all_combinations_for_battle(current_player, defender, tile_info)
	
	print("[CPU AI] バトル評価結果: can_win_both_no_item=%s, can_win_vs_enemy_item=%s, creature_index=%d" % [
		eval_result.get("can_win_both_no_item", false),
		eval_result.get("can_win_vs_enemy_item", false),
		eval_result.creature_index
	])
	
	# 即死ギャンブルや無効化+即死は特別扱い（ポリシーより優先）
	if eval_result.get("is_instant_death_gamble", false) or eval_result.get("is_nullify_instant_death", false):
		var instant_death_creature_idx = eval_result.creature_index
		var creature = card_system.get_card_data_for_player(current_player.id, instant_death_creature_idx)
		if eval_result.get("is_instant_death_gamble", false):
			print("[CPU AI] バトル決定: %s で即死に賭けます（確率: %d%%）" % [
				creature.get("name", "?"),
				eval_result.get("instant_death_probability", 0)
			])
		else:
			print("[CPU AI] バトル決定: %s で無効化+即死を狙います（確率: %d%%）" % [
				creature.get("name", "?"),
				eval_result.get("instant_death_probability", 0)
			])
		decision_attempts = 0
		emit_signal("battle_decided", instant_death_creature_idx, -1)
		return
	
	# ポリシーに基づいて行動を決定
	var action = _decide_attack_action_by_policy(eval_result)
	
	print("[CPU AI] ポリシー判断結果: %s" % CPUBattlePolicyScript.AttackAction.keys()[action])
	
	var creature_index = -1
	var item_index = -1
	
	match action:
		CPUBattlePolicyScript.AttackAction.ALWAYS_BATTLE:
			# 必ず戦闘（最初のクリーチャーを使用）
			creature_index = eval_result.get("first_creature_index", -1)
			item_index = -1
			if creature_index >= 0:
				var creature = card_system.get_card_data_for_player(current_player.id, creature_index)
				print("[CPU AI] バトル決定（ALWAYS_BATTLE）: %s で強行突破" % creature.get("name", "?"))
		
		CPUBattlePolicyScript.AttackAction.BATTLE_IF_BOTH_NO_ITEM:
			# 両方アイテムなしで勝てるクリーチャーを選択
			creature_index = eval_result.get("best_both_no_item_creature_index", -1)
			item_index = -1
			if creature_index >= 0:
				var creature = card_system.get_card_data_for_player(current_player.id, creature_index)
				print("[CPU AI] バトル決定（BOTH_NO_ITEM）: %s で侵略" % creature.get("name", "?"))
		
		CPUBattlePolicyScript.AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM:
			# ワーストケースで勝てる組み合わせを選択（従来ロジック）
			# アイテムなしで勝てるならアイテムなし、アイテム必要ならアイテムあり
			creature_index = eval_result.creature_index
			item_index = eval_result.item_index
			if creature_index >= 0:
				var creature = card_system.get_card_data_for_player(current_player.id, creature_index)
				if item_index >= 0:
					var item = card_system.get_card_data_for_player(current_player.id, item_index)
					print("[CPU AI] バトル決定（VS_ENEMY_ITEM）: %s + %s で侵略" % [creature.get("name", "?"), item.get("name", "?")])
				else:
					print("[CPU AI] バトル決定（VS_ENEMY_ITEM）: %s で侵略" % creature.get("name", "?"))
		
		CPUBattlePolicyScript.AttackAction.NEVER_BATTLE:
			print("[CPU AI] バトルしない → 通行料を支払います")
	
	decision_attempts = 0
	emit_signal("battle_decided", creature_index, item_index)

## ポリシーに基づいて侵略時の行動を決定（ターン内キャッシュあり）
func _decide_attack_action_by_policy(eval_result: Dictionary) -> int:
	# 既にこのターンで決定済みならキャッシュを返す
	if _turn_attack_action_cache >= 0:
		print("[CPU AI] キャッシュされたポリシーを使用: %s" % CPUBattlePolicyScript.AttackAction.keys()[_turn_attack_action_cache])
		return _turn_attack_action_cache
	
	# ポリシーが設定されていない場合はデフォルト（バランス型）を使用
	var policy = battle_policy
	if policy == null:
		print("[CPU AI] ポリシー未設定、デフォルト（balanced）を使用")
		policy = CPUBattlePolicyScript.create_balanced_policy()
	else:
		print("[CPU AI] ポリシー設定済み")
		policy.print_weights()
	
	# 抽選してキャッシュに保存
	var action = policy.decide_attack_action(eval_result)
	_turn_attack_action_cache = action
	print("[CPU AI] ポリシー抽選結果をキャッシュ: %s" % CPUBattlePolicyScript.AttackAction.keys()[action])
	
	return action

## 性格を反映したバトル結果を取得（移動シミュレーション用）
## 戻り値: { "will_battle": bool, "will_win": bool }
func get_policy_based_battle_result(eval_result: Dictionary) -> Dictionary:
	var action = _decide_attack_action_by_policy(eval_result)
	
	match action:
		CPUBattlePolicyScript.AttackAction.ALWAYS_BATTLE:
			# 勝てるかどうかに関わらず戦闘する
			var can_win = eval_result.get("can_win_both_no_item", false) or eval_result.get("can_win_vs_enemy_item", false)
			return {"will_battle": true, "will_win": can_win}
		
		CPUBattlePolicyScript.AttackAction.BATTLE_IF_BOTH_NO_ITEM:
			if eval_result.get("can_win_both_no_item", false):
				return {"will_battle": true, "will_win": true}
			else:
				return {"will_battle": false, "will_win": false}
		
		CPUBattlePolicyScript.AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM:
			if eval_result.get("can_win_vs_enemy_item", false):
				return {"will_battle": true, "will_win": true}
			else:
				return {"will_battle": false, "will_win": false}
		
		CPUBattlePolicyScript.AttackAction.NEVER_BATTLE:
			return {"will_battle": false, "will_win": false}
	
	# フォールバック
	return {"will_battle": false, "will_win": false}

# CPUレベルアップ判断
func decide_level_up(current_player, tile_info: Dictionary) -> void:
	decision_attempts += 1
	
	# 最大試行回数チェック
	if decision_attempts > CPUAIConstantsScript.MAX_DECISION_ATTEMPTS:
		decision_attempts = 0
		emit_signal("level_up_decided", false)
		return
	
	var upgrade_cost = board_system.get_upgrade_cost(tile_info.get("index", 0))
	
	# EPとレベルアップ確率で判断
	if current_player.magic_power >= upgrade_cost and randf() < GameConstants.CPU_LEVELUP_RATE:
		print("[CPU AI] レベルアップ: コスト%dEP" % upgrade_cost)
		decision_attempts = 0
		emit_signal("level_up_decided", true)
	else:
		decision_attempts = 0
		emit_signal("level_up_decided", false)

# ============================================================
# ドミニオコマンド判断
# ============================================================

## ドミニオコマンド判断（召喚フェーズ用）
## 召喚 vs ドミニオコマンドのどちらが得かを判断
func decide_territory_command(current_player, tile_info: Dictionary, situation: String = "own_land") -> void:
	decision_attempts += 1
	
	if decision_attempts > CPUAIConstantsScript.MAX_DECISION_ATTEMPTS:
		decision_attempts = 0
		emit_signal("territory_command_decided", {})
		return
	
	if territory_ai == null:
		print("[CPU AI] territory_ai未初期化")
		decision_attempts = 0
		emit_signal("territory_command_decided", {})
		return
	
	# コンテキストを構築
	var cmd_context = _build_territory_context(current_player, tile_info, situation)
	
	# 全オプションを評価
	var best_option = territory_ai.evaluate_all_options(cmd_context)
	
	if best_option.is_empty():
		print("[CPU AI] ドミニオコマンド: 有効なオプションなし")
		decision_attempts = 0
		emit_signal("territory_command_decided", {})
		return
	
	print("[CPU AI] ドミニオコマンド決定: %s (スコア: %d)" % [best_option.get("type", "?"), best_option.get("score", 0)])
	decision_attempts = 0
	emit_signal("territory_command_decided", best_option)


## 召喚 vs ドミニオコマンドを比較して最適な行動を返す
func decide_summon_or_territory(current_player, tile_info: Dictionary) -> Dictionary:
	if territory_ai == null:
		return {"action": "summon"}
	
	var cmd_context = _build_territory_context(current_player, tile_info, "empty_land")
	
	# 属性一致クリーチャーがあれば召喚優先
	var tile_element = tile_info.get("element", "")
	var has_matching_creature = _has_matching_creature(current_player, tile_element)
	
	if has_matching_creature:
		return {"action": "summon"}
	
	# ドミニオコマンドを評価
	var best_option = territory_ai.evaluate_all_options(cmd_context)
	
	if best_option.is_empty():
		return {"action": "summon"}
	
	# 属性不一致召喚のスコアは低い
	var summon_score = CPUAIConstantsScript.SUMMON_MISMATCH_SCORE
	var command_score = best_option.get("score", 0)
	
	if command_score > summon_score:
		return {"action": "territory_command", "command": best_option}
	
	return {"action": "summon"}


## 敵ドミニオでの判断（侵略 vs ドミニオコマンド）
func decide_invasion_or_territory(current_player, tile_info: Dictionary) -> Dictionary:
	if territory_ai == null:
		return {"action": "battle"}
	
	var cmd_context = _build_territory_context(current_player, tile_info, "enemy_land")
	
	# バトル評価を取得
	var defender = tile_info.creature
	var eval_result = battle_ai.evaluate_all_combinations_for_battle(current_player, defender, tile_info)
	
	# ポリシーに基づいて行動を決定
	var action = _decide_attack_action_by_policy(eval_result)
	
	print("[CPU AI] decide_invasion_or_territory: ポリシー判断=%s" % CPUBattlePolicyScript.AttackAction.keys()[action])
	
	# ALWAYS_BATTLEまたはバトル可能な場合は戦闘を検討
	if action != CPUBattlePolicyScript.AttackAction.NEVER_BATTLE:
		# 戦闘を選択する場合でも、ドミニオコマンドの方が有利ならドミニオコマンドを選ぶ
		var can_win = eval_result.get("can_win_both_no_item", false) or eval_result.get("can_win_vs_enemy_item", false)
		if can_win:
			# 倒せる場合は侵略スコアとドミニオコマンドスコアを比較（下の処理へ）
			pass
		elif action == CPUBattlePolicyScript.AttackAction.ALWAYS_BATTLE:
			# ALWAYS_BATTLEで勝てない場合はドミニオコマンドを検討しない（戦闘を強行）
			return {"action": "battle"}
		else:
			# 勝てない場合はドミニオコマンドを検討
			var territory_option = territory_ai.evaluate_all_options(cmd_context)
			if not territory_option.is_empty():
				return {"action": "territory_command", "command": territory_option}
			return {"action": "skip"}
	else:
		# NEVER_BATTLEの場合はドミニオコマンドを検討
		var territory_option = territory_ai.evaluate_all_options(cmd_context)
		if not territory_option.is_empty():
			return {"action": "territory_command", "command": territory_option}
		return {"action": "skip"}
	
	# 倒せる場合は侵略スコアとドミニオコマンドスコアを比較
	var best_option = territory_ai.evaluate_all_options(cmd_context)
	
	# 侵略スコアを計算（territory_aiの_evaluate_invasionと同じ計算）
	var tile = board_system.tile_nodes.get(tile_info.get("index", -1))
	if tile == null:
		return {"action": "battle"}
	
	var chain_bonus = board_system.tile_data_manager.calculate_chain_bonus(tile_info.get("index", 0), tile.owner_id)
	var level = tile.level
	var invasion_score = (level * chain_bonus * 100 + 50) * CPUAIConstantsScript.INVASION_ASSET_MULTIPLIER
	
	var command_score = best_option.get("score", 0)
	
	if command_score > invasion_score:
		return {"action": "territory_command", "command": best_option}
	
	return {"action": "battle"}


## ドミニオコマンド用コンテキストを構築
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
		return false
	
	# デバッグフラグを取得
	var disable_lands = false
	var disable_cannot_summon = false
	if hand_utils.tile_action_processor:
		disable_lands = hand_utils.tile_action_processor.debug_disable_lands_required
		disable_cannot_summon = hand_utils.tile_action_processor.debug_disable_cannot_summon
	
	var creatures = hand_utils.get_creatures_from_hand(current_player.id)
	
	for creature_entry in creatures:
		var card_index = creature_entry.get("index", -1)
		var card_data = creature_entry.get("data", {})
		var creature_element = card_data.get("element", "")
		var can_afford = hand_utils.can_afford_card(current_player, card_index)
		
		# 土地条件チェック（フラグで無効化可能）
		var can_summon_lands = disable_lands or hand_utils._check_lands_required(card_data, current_player.id)
		# 配置制限チェック（フラグで無効化可能）
		var can_summon_element = disable_cannot_summon or hand_utils._check_cannot_summon(card_data, tile_element)
		var can_summon = can_summon_lands and can_summon_element
		
		if creature_element == tile_element or tile_element == "neutral":
			if can_afford and can_summon:
				return true
	
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
	await get_tree().create_timer(CPUAIConstantsScript.CPU_THINKING_DELAY).timeout

# デバッグ：CPU判断を表示
func debug_print_decision(action: String, params: Dictionary):
	print("[CPU AI] アクション: ", action)
	for key in params:
		print("  ", key, ": ", params[key])

# BattleSimulatorのログ出力を切り替え
func set_simulator_log_enabled(enabled: bool) -> void:
	if context:
		context.set_simulator_log_enabled(enabled)
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


## キャラクターポリシーから召喚確率を取得
func _get_summon_rate() -> float:
	# バトルポリシーから召喚確率を取得（設定されていればそれを使用）
	if battle_policy and battle_policy.has_method("get_summon_rate"):
		return battle_policy.get_summon_rate()
	# デフォルトはGameConstantsの値
	return GameConstants.CPU_SUMMON_RATE
