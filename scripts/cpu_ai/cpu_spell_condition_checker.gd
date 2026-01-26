## CPU AI用 スペル使用条件チェッカー
## スペルのconditionに基づいて使用可否を判定
class_name CPUSpellConditionChecker
extends RefCounted

const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")

## 共有コンテキスト
var _context: CPUAIContextScript = null

## 外部クラス参照
var board_analyzer: CPUBoardAnalyzer = null
var target_resolver: CPUTargetResolver = null

## システム参照
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var creature_manager: Node = null
var lap_system: Node = null
var game_flow_manager: Node = null

## BattleSimulator
const BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")
var _battle_simulator_local = null

## BattleSimulatorのgetter（contextがあればcontextから取得）
var _battle_simulator:
	get:
		if _context:
			return _context.get_battle_simulator()
		return _battle_simulator_local

## 手札ユーティリティ（ワーストケースシミュレーション用）
var hand_utils: CPUHandUtils = null

## CPUBattleAI（共通バトル評価用）
var battle_ai: CPUBattleAI = null


## 共有コンテキストを設定
func initialize(ctx: CPUAIContextScript) -> void:
	_context = ctx
	# contextからシステム参照を取得
	if ctx:
		board_system = _context.board_system
		player_system = _context.player_system
		card_system = _context.card_system
		creature_manager = _context.creature_manager
		lap_system = _context.lap_system
		game_flow_manager = _context.game_flow_manager
		
		# CPUBoardAnalyzerを初期化
		board_analyzer = CPUBoardAnalyzer.new()
		board_analyzer.initialize(board_system, player_system, card_system, creature_manager, lap_system, game_flow_manager)
		
		# CPUTargetResolverを初期化
		target_resolver = CPUTargetResolver.new()
		target_resolver.initialize(board_analyzer, board_system, player_system, card_system, game_flow_manager)


## 手札ユーティリティを設定
func set_hand_utils(utils: CPUHandUtils) -> void:
	hand_utils = utils

## CPUBattleAIを設定
func set_battle_ai(ai: CPUBattleAI) -> void:
	battle_ai = ai

## ワーストケースシミュレーション（敵がアイテム/援護を使った場合でも勝てるか）
func _check_worst_case_win(attacker: Dictionary, defender: Dictionary, tile_info: Dictionary, player_id: int) -> bool:
	# battle_aiがあればそれを使用
	if battle_ai != null:
		var worst_case = battle_ai.simulate_worst_case_common(
			attacker,
			defender,
			tile_info,
			player_id,
			{},    # 自分のアイテム（なし）
			true   # is_attacker = true（攻撃側として）
		)
		return worst_case.is_win
	
	# battle_aiがない場合は基本シミュレーションのみ（フォールバック）
	if _battle_simulator:
		var result = _battle_simulator.simulate_battle(attacker, defender, tile_info, player_id, {}, {})
		return result.get("result", -1) == BattleSimulatorScript.BattleResult.ATTACKER_WIN
	
	return false

# =============================================================================
# 外部からのアクセス用ラッパー（後方互換性）
# =============================================================================

## 盤面上の自クリーチャーを取得（後方互換性）
func _get_own_creatures_on_board(player_id: int) -> Array:
	return board_analyzer.get_own_creatures_on_board(player_id)

## 到達可能な敵タイルを取得（後方互換性）
func _get_reachable_enemy_tiles(from_tile: int, player_id: int, steps: int, exact_steps: bool) -> Array:
	return board_analyzer.get_reachable_enemy_tiles(from_tile, player_id, steps, exact_steps)

# =============================================================================
# メイン条件チェック（condition フィールド用）
# =============================================================================

## 条件をチェック
func check_condition(condition: String, context: Dictionary) -> bool:
	match condition:
		# 属性関連
		"element_mismatch":
			return _check_element_mismatch(context)
		
		# 敵土地関連
		"enemy_high_level":
			return _check_enemy_high_level(context)
		"enemy_level_4":
			return _check_enemy_level_4(context)
		
		# 移動・侵略関連
		"move_invasion_win":
			return _check_move_invasion_win(context)
		
		# 自クリーチャー状態
		"has_downed_creature":
			return _check_has_downed_creature(context)
		"self_creature_damaged":
			return _check_self_creature_damaged(context)
		"has_cursed_creature":
			return _check_has_cursed_creature(context)
		
		# 盤面状態
		"standing_on_vacant_land":
			return _check_standing_on_vacant_land(context)
		
		# 呪い関連
		"has_any_curse":
			return _check_has_any_curse(context)
		"has_world_curse":
			return _check_has_world_curse(context)
		"has_player_curse":
			return _check_has_player_curse(context)
		
		# クリーチャー交換
		"can_upgrade_creature":
			return _check_can_upgrade_creature(context)
		"swap_improves_element_match":
			return _check_swap_improves_element_match(context)
		
		# 手札関連
		"has_spare_hand_card":
			return _check_has_spare_hand_card(context)
		
		# その他
		"has_unvisited_gate":
			return _check_has_unvisited_gate(context)
		"nearest_checkpoint_unvisited":
			return _check_nearest_checkpoint_unvisited(context)
		
		_:
			push_warning("CPUSpellConditionChecker: Unknown condition: " + condition)
			return false

# =============================================================================
# ターゲット条件チェック（target_condition フィールド用）
# CPUTargetResolverに委譲
# =============================================================================

## ターゲット条件をチェックし、有効なターゲットを返す
func check_target_condition(target_condition: String, context: Dictionary) -> Array:
	return target_resolver.check_target_condition(target_condition, context)

# =============================================================================
# 条件チェック実装
# =============================================================================

## 属性不一致チェック：配置クリーチャーと土地の属性が違う自ドミニオがあるか
func _check_element_mismatch(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var mismatched = board_analyzer.get_mismatched_own_lands(player_id)
	return mismatched.size() > 0

## 敵高レベル土地チェック（Lv2以上）
func _check_enemy_high_level(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var enemy_lands = board_analyzer.get_enemy_lands_by_level(player_id, 2)
	return enemy_lands.size() > 0

## 敵レベル4土地チェック
func _check_enemy_level_4(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	var enemy_lands = board_analyzer.get_enemy_lands_by_level(player_id, 4)
	return enemy_lands.size() > 0

## 移動侵略で勝てるかチェック（アウトレイジ、チャリオット等）
## CPUBattleAI.evaluate_single_creature_battle を使用（共通ロジック）
func _check_move_invasion_win(context: Dictionary) -> bool:
	if not board_system:
		return false
	
	var player_id = context.get("player_id", 0)
	
	# スペル情報から移動距離を取得
	var spell = context.get("spell", {})
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	var steps = 1  # デフォルト: 隣接（アウトレイジ）
	var exact_steps = false
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		if effect_type == "move_steps":
			steps = effect.get("steps", 2)
			exact_steps = effect.get("exact_steps", false)
			break
		elif effect_type == "move_to_adjacent_enemy":
			steps = 1
			exact_steps = false
			break
	
	# 自クリーチャーを取得（盤面上）
	var own_creatures = board_analyzer.get_own_creatures_on_board(player_id)
	if own_creatures.is_empty():
		return false
	
	# 各自クリーチャーから移動可能な敵ドミニオを探し、勝てるかシミュレーション
	for own_tile in own_creatures:
		var attacker = own_tile.get("creature", {})
		if attacker.is_empty():
			continue
		
		var from_tile = own_tile.get("tile_index", -1)
		if from_tile < 0:
			continue
		
		# 移動可能な敵ドミニオを取得
		var reachable_enemy_tiles = board_analyzer.get_reachable_enemy_tiles(from_tile, player_id, steps, exact_steps)
		
		for enemy_tile in reachable_enemy_tiles:
			var defender = enemy_tile.get("creature", {})
			if defender.is_empty():
				continue
			
			var tile_info = {
				"index": enemy_tile.get("tile_index", -1),
				"element": enemy_tile.get("element", ""),
				"level": enemy_tile.get("level", 1),
				"owner": enemy_tile.get("owner", -1)
			}
			
			# CPUBattleAIの共通メソッドを使用
			if battle_ai != null:
				var eval_result = battle_ai.evaluate_single_creature_battle(
					attacker, defender, tile_info, player_id, true
				)
				if eval_result.can_win:
					return true
				# 即死ギャンブルも考慮（50%以上）
				if eval_result.get("is_instant_death_gamble", false):
					var probability = eval_result.get("instant_death_probability", 0)
					if probability >= 50:
						return true
			else:
				# フォールバック: 単純シミュレーション
				var sim_result = _battle_simulator.simulate_battle(
					attacker, defender, tile_info, player_id, {}, {}
				)
				if sim_result.get("result") == BattleSimulatorScript.BattleResult.ATTACKER_WIN:
					return true
	
	return false


## ダウン中の自クリーチャーがいるか
func _check_has_downed_creature(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	return board_analyzer.has_downed_creature(player_id)

## 自クリーチャーがダメージを受けているか
func _check_self_creature_damaged(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	return board_analyzer.has_damaged_creature(player_id)

## 呪い付きクリーチャーがいるか（自分の）
func _check_has_cursed_creature(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	return board_analyzer.has_cursed_creature(player_id)

## 何らかの呪いがあるか
func _check_has_any_curse(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	
	# クリーチャー呪いチェック
	if board_analyzer.has_cursed_creature(player_id):
		return true
	
	# プレイヤー呪いチェック
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		var player = player_system.players[player_id]
		if player and player.curse.size() > 0:
			return true
	
	return false

## 世界呪いがあるか
func _check_has_world_curse(_ctx: Dictionary) -> bool:
	if not game_flow_manager:
		return false
	
	# WorldCurseManagerを参照
	var world_curse_manager = game_flow_manager.get("world_curse_manager")
	if world_curse_manager and world_curse_manager.has_method("get_active_curses"):
		var active_curses = world_curse_manager.get_active_curses()
		return active_curses.size() > 0
	
	return false

## プレイヤー呪いがあるか
func _check_has_player_curse(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not player_system:
		return false
	
	if player_id < 0 or player_id >= player_system.players.size():
		return false
	
	var player = player_system.players[player_id]
	return player and player.curse.size() > 0

## 未訪問ゲートがあるか（1周完了を引き起こすゲートは除外）
func _check_has_unvisited_gate(context: Dictionary) -> bool:
	if not lap_system:
		return false
	
	var player_id = context.get("player_id", 0)
	var player_state = lap_system.player_lap_state.get(player_id, {})
	var required_checkpoints = lap_system.required_checkpoints
	
	# 未訪問ゲートをカウント
	var unvisited_count = 0
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			unvisited_count += 1
	
	# 未訪問が2つ以上あれば使用可能（1つだけだと1周完了を引き起こす）
	return unvisited_count >= 2

## プレイヤーが空地に止まっているか（ゴブリンズレア用）
func _check_standing_on_vacant_land(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not board_system:
		return false
	
	# movement_controllerから正確な位置を取得
	var player_pos = board_analyzer.get_player_current_tile(player_id)
	
	var tile = board_system.get_tile_data(player_pos)
	if not tile:
		return false
	
	# 特殊タイルでないかチェック
	if tile.get("is_special", false):
		return false
	
	# クリーチャーがいないかチェック
	var creature = tile.get("creature", {})
	if creature and not creature.is_empty():
		return false
	
	# 所有者がいないかチェック（空き地 = 所有者なし）
	var owner = tile.get("owner", -1)
	return owner == -1


## 手札にクリーチャーを1枚残せるか（スクイーズ用）
## 手札に2枚以上カードがあれば使用可能
func _check_has_spare_hand_card(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not card_system:
		return false
	
	var hand = card_system.get_all_cards_for_player(player_id)
	# 2枚以上あれば1枚捨てても残る
	return hand.size() >= 2


## 手札のクリーチャーで属性一致に改善できるか（エクスチェンジ用）
func _check_can_upgrade_creature(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not card_system or not board_system:
		return false
	
	# 手札のクリーチャーを取得
	var hand = card_system.get_all_cards_for_player(player_id)
	var hand_creatures = []
	for card in hand:
		if card.get("type") == "creature":
			hand_creatures.append(card)
	
	if hand_creatures.is_empty():
		return false
	
	# 手札クリーチャーの属性セットを作成
	var hand_elements = {}
	for hc in hand_creatures:
		var elem = hc.get("element", "")
		if elem != "" and elem != "neutral":
			hand_elements[elem] = true
	
	# 配置中の自クリーチャーで属性不一致のものを探す
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id:
			continue
		
		var creature = tile.get("creature", {})
		if creature.is_empty():
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		
		# 属性不一致かチェック
		if tile_element == "" or tile_element == "neutral":
			continue
		if creature_element == tile_element:
			continue  # 既に一致している
		
		# 手札にこのタイル属性と一致するクリーチャーがいるか
		if hand_elements.has(tile_element):
			return true
	
	return false

## クリーチャー交換で属性一致が改善するか（リリーフ用）
func _check_swap_improves_element_match(context: Dictionary) -> bool:
	var player_id = context.get("player_id", 0)
	if not board_system:
		return false
	
	var own_tiles = []
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		if tile.get("owner", tile.get("owner_id", -1)) == player_id:
			var creature = tile.get("creature", tile.get("placed_creature", {}))
			if creature and not creature.is_empty():
				own_tiles.append(tile)
	
	if own_tiles.size() < 2:
		return false
	
	# 現在の属性一致数を計算
	var current_matches = 0
	for tile in own_tiles:
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if tile.get("element") == creature.get("element"):
			current_matches += 1
	
	# 交換後の改善可能性をチェック
	for i in range(own_tiles.size()):
		for j in range(i + 1, own_tiles.size()):
			var tile_a = own_tiles[i]
			var tile_b = own_tiles[j]
			var creature_a = tile_a.get("creature", tile_a.get("placed_creature", {}))
			var creature_b = tile_b.get("creature", tile_b.get("placed_creature", {}))
			
			# 交換後の一致数
			var swap_matches = current_matches
			
			# 現在の一致を解除
			if tile_a.get("element") == creature_a.get("element"):
				swap_matches -= 1
			if tile_b.get("element") == creature_b.get("element"):
				swap_matches -= 1
			
			# 交換後の一致を追加
			if tile_a.get("element") == creature_b.get("element"):
				swap_matches += 1
			if tile_b.get("element") == creature_a.get("element"):
				swap_matches += 1
			
			if swap_matches > current_matches:
				return true
	
	return false

## 最寄りチェックポイントが未訪問かチェック（フォームポータル用）
func _check_nearest_checkpoint_unvisited(context: Dictionary) -> bool:
	if not board_system or not lap_system:
		return false
	
	var player_id = context.get("player_id", 0)
	var current_tile = board_analyzer.get_player_current_tile(player_id)
	
	# 最寄りチェックポイントを探す
	var nearest_checkpoint = board_analyzer.find_nearest_checkpoint(current_tile)
	if nearest_checkpoint.tile_index < 0:
		return false
	
	# そのチェックポイントが未訪問かチェック
	var checkpoint_type = nearest_checkpoint.checkpoint_type
	var player_state = lap_system.player_lap_state.get(player_id, {})
	var is_visited = player_state.get(checkpoint_type, false)
	
	return not is_visited
