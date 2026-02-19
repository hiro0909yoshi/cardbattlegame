## CPU スペル ターゲット選択クラス
## スペル使用時の最適ターゲット選択ロジックを担当
class_name CPUSpellTargetSelector
extends RefCounted

const CPUAIContextScript = preload("res://scripts/cpu_ai/cpu_ai_context.gd")

## 共有コンテキスト
var _context: CPUAIContextScript = null

## 参照
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var condition_checker = null  # CPUSpellConditionChecker
var lap_system: Node = null
var target_resolver: CPUTargetResolver = null
var game_flow_manager: Node = null

# === 直接参照（GFM経由を廃止） ===
var game_stats  # GameFlowManager.game_stats への直接参照

## 共有コンテキストで初期化
func initialize(ctx: CPUAIContextScript) -> void:
	_context = ctx
	if ctx:
		board_system = _context.board_system
		player_system = _context.player_system
		card_system = _context.card_system
		lap_system = _context.lap_system
		game_flow_manager = _context.game_flow_manager

		# CPUTargetResolverの初期化
		target_resolver = CPUTargetResolver.new()
		var board_analyzer = CPUBoardAnalyzer.new()
		board_analyzer.initialize(board_system, player_system, card_system, _context.creature_manager, lap_system, game_flow_manager)
		target_resolver.initialize(board_analyzer, board_system, player_system, card_system, game_flow_manager)

## game_statsを設定（GFM経由を廃止）
func set_game_stats(p_game_stats) -> void:
	game_stats = p_game_stats

# =============================================================================
# メインターゲット選択
# =============================================================================

## デフォルトターゲット取得（TargetSelectionHelper共通ロジック使用）
func get_default_targets(spell: Dictionary, context: Dictionary) -> Array:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var target_info = effect_parsed.get("target_info", {}).duplicate()
	
	# systemsを構築
	var systems = {
		"board_system": board_system,
		"player_system": player_system,
		"current_player_id": context.get("player_id", 0),
		"game_flow_manager": game_flow_manager
	}
	
	# TargetSelectionHelperの共通ロジックを使用
	# 防魔・HP効果無効フィルタは get_valid_targets_core 内で適用される
	var targets = TargetSelectionHelper.get_valid_targets_core(systems, target_type, target_info)
	
	# 呪いスペルの場合、追加のフィルタリングを適用
	if target_type == "creature" and target_resolver:
		var curse_info = target_resolver.analyze_curse_spell(spell)
		if curse_info.is_curse:
			targets = target_resolver.filter_curse_spell_targets(
				curse_info.is_beneficial,
				targets,
				context
			)
	
	return targets

## 防魔・HP効果無効のクリーチャーをフィルタリング（共通ロジック使用）
func _filter_spell_immune_targets(targets: Array, spell: Dictionary) -> Array:
	var effect_parsed = spell.get("effect_parsed", {})
	
	# 世界呪いコンテキスト構築
	var context = _build_world_curse_context()
	
	var filtered = []
	for target in targets:
		var creature = target.get("creature", {})
		if creature.is_empty():
			filtered.append(target)
			continue
		
		# 防魔チェック（SpellProtection使用）
		if SpellProtection.is_creature_protected(creature, context):
			continue
		
		# HP効果無効チェック
		if SpellProtection.should_skip_hp_effect(creature, effect_parsed):
			continue
		
		filtered.append(target)
	
	return filtered

## 世界呪いコンテキストを構築
func _build_world_curse_context() -> Dictionary:
	var context = {}
	# 直接参照を優先
	if game_stats and game_stats is Dictionary:
		context["world_curse"] = game_stats.get("world_curse", {})
	return context

## 最適なターゲット選択（スコア付き）
func select_best_target_with_score(targets: Array, spell: Dictionary, context: Dictionary) -> Dictionary:
	if targets.is_empty():
		return {"target": {}, "score": 0.0}
	
	var player_id = context.get("player_id", 0)
	var damage_value = context.get("damage_value", 0)
	var is_damage_spell = damage_value > 0
	
	# 呪いスペルかどうか判定
	var curse_info = _analyze_curse_spell(spell)
	print("[SpellAI] curse_info: %s (spell: %s)" % [str(curse_info), spell.get("name", "?")])
	
	var best_target = targets[0]
	var best_score = -999.0
	
	for target in targets:
		var score = _calculate_target_score(target, player_id, damage_value, is_damage_spell, curse_info, spell)
		if score > best_score:
			best_score = score
			best_target = target
	
	return {"target": best_target, "score": best_score}

## ターゲットスコアを計算
func _calculate_target_score(target: Dictionary, player_id: int, damage_value: int, is_damage_spell: bool, curse_info: Dictionary = {}, spell: Dictionary = {}) -> float:
	var score = 0.0
	
	var tile_index = target.get("tile_index", -1)
	var creature = target.get("creature", {})
	var tile_data = {}
	
	# タイル情報を取得
	if tile_index >= 0 and board_system:
		tile_data = board_system.get_tile_data(tile_index)
		if tile_data and creature.is_empty():
			creature = tile_data.get("creature", tile_data.get("placed_creature", {}))
	
	if creature.is_empty():
		# 空き土地の場合：配置するクリーチャーの属性と土地属性の一致をチェック
		return _calculate_empty_land_score(target, tile_data, spell)
	
	# 敵クリーチャーかどうか
	var owner_id = -1
	if tile_data:
		owner_id = tile_data.get("owner", tile_data.get("owner_id", -1))
	var is_enemy = owner_id != player_id and owner_id >= 0
	
	if is_enemy:
		score += 1.0
	
	# ダメージスペルの場合
	if is_damage_spell:
		var current_hp = creature.get("current_hp", creature.get("hp", 0))
		
		# 倒せる場合は最優先
		if current_hp > 0 and current_hp <= damage_value:
			score += 200.0
		# ダメージ効率（HPに対するダメージ割合）
		elif current_hp > 0:
			var damage_ratio = float(damage_value) / float(current_hp)
			score += min(damage_ratio, 1.0)  # 最大+1.0
	
	# 呪いスペルの場合、既存の呪い状態でスコア調整
	if curse_info.get("is_curse", false):
		score += _calculate_curse_overwrite_score(creature, player_id, owner_id, curse_info.get("is_beneficial", false))
	
	# 土地レベル（属性一致の場合のみスコア加算）
	if tile_data and not creature.is_empty():
		var level = tile_data.get("level", 1)
		var tile_element = tile_data.get("element", "")
		var creature_element = creature.get("element", "")
		if tile_element == creature_element or tile_element == "neutral" or creature_element == "neutral":
			score += 30 * level
	
	# アルカナアーツ持ちの敵クリーチャーは優先ターゲット
	if is_enemy and _has_mystic_arts(creature):
		score += 50.0
	
	# クリーチャーのレート
	var creature_rate = 0.0
	if not creature.is_empty():
		var CardRateEvaluator = load("res://scripts/cpu_ai/card_rate_evaluator.gd")
		creature_rate = CardRateEvaluator.get_rate(creature)
		score += creature_rate
	
	# デバッグ: 最終スコア
	var creature_name = creature.get("name", "?")
	var debug_level = tile_data.get("level", 1) if tile_data else 1
	var has_ma = _has_mystic_arts(creature)
	print("[SpellAI] 最終スコア: %s = %.1f (level=%d, rate=%.1f%s)" % [creature_name, score, debug_level, creature_rate, ", MA持ち" if has_ma else ""])
	
	return score


## 空き土地のスコアを計算（配置クリーチャーの属性一致を考慮）
func _calculate_empty_land_score(target: Dictionary, tile_data: Dictionary, spell: Dictionary) -> float:
	var score = 1.0  # 空き土地の基本スコア
	
	if tile_data.is_empty():
		return score
	
	var tile_element = tile_data.get("element", "")
	if tile_element.is_empty():
		tile_element = target.get("element", "")
	
	# place_creature効果からcreature_idを取得
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	var creature_id = 0
	
	for effect in effects:
		if effect.get("effect_type") == "place_creature":
			creature_id = effect.get("creature_id", 0)
			break
	
	if creature_id == 0:
		return score
	
	# creature_idから属性を取得
	var creature_element = _get_creature_element_by_id(creature_id)
	
	if creature_element.is_empty():
		return score
	
	# 属性一致で大幅加点（最優先）
	if tile_element == creature_element:
		score += 100.0
		print("[SpellAI] 空き土地スコア: tile=%d, element=%s, creature_element=%s → 属性一致ボーナス" % [target.get("tile_index", -1), tile_element, creature_element])
	elif tile_element == "neutral":
		score += 10.0  # ニュートラルは次善
	
	# 分岐数ボーナス（複数の道に繋がる土地を優先）
	var connections = tile_data.get("connections", [])
	if connections.size() >= 3:
		score += 20.0  # 3分岐以上
		print("[SpellAI] 空き土地スコア: tile=%d, 分岐数=%d → 分岐ボーナス" % [target.get("tile_index", -1), connections.size()])
	elif connections.size() == 2:
		score += 5.0   # 2分岐
	
	return score


## creature_idからクリーチャーの属性を取得
func _get_creature_element_by_id(creature_id: int) -> String:
	if not card_system:
		return ""
	
	# CardLoaderから取得を試みる
	if CardLoader:
		var creature_data = CardLoader.get_creature_by_id(creature_id)
		if creature_data and not creature_data.is_empty():
			return creature_data.get("element", "")
	
	return ""


## 呪い上書きスコアを計算
## 敵の有利な呪いを消す / 自分の不利な呪いを消す → +150
## 敵の不利な呪いを消す / 自分の有利な呪いを消す → -300
func _calculate_curse_overwrite_score(creature: Dictionary, player_id: int, owner_id: int, _spell_is_beneficial: bool) -> float:
	var curse_benefit = CpuCurseEvaluator.get_creature_curse_benefit(creature)
	var is_own = (owner_id == player_id)
	var score = 0.0
	
	if curse_benefit != 0:
		if is_own:
			if curse_benefit > 0:
				score = -300.0  # 自分の有利な呪いを消したくない
			else:
				score = 150.0   # 不利な呪いを消したい
		else:
			if curse_benefit > 0:
				score = 150.0   # 敵の有利な呪いを消したい
			else:
				score = -300.0  # 敵の不利な呪いを残したい
	
	# デバッグログ
	var creature_name = creature.get("name", "?")
	print("[SpellAI] 呪いスコア: %s, benefit=%d, is_own=%s, score=%.1f" % [creature_name, curse_benefit, str(is_own), score])
	
	return score


## スペルが呪いスペルかどうか判定し、有利/不利を返す
func _analyze_curse_spell(spell_data: Dictionary) -> Dictionary:
	var result = {"is_curse": false, "is_beneficial": false}
	
	var effect_parsed = spell_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	# 呪い系のeffect_type（有利 - 自クリーチャー向け）
	const BENEFICIAL_CURSE_EFFECTS = [
		"command_growth_curse",  # コマンド成長
		"remote_move",           # 遠隔移動
		"toll_multiplier",       # 通行料倍率（グリード等）
		"magic_barrier",         # EP結界
		"forced_stop",           # 強制停止
		"toll_share",            # 通行料促進
		"grant_mystic_arts",     # アルカナアーツ付与
		"stat_boost",            # 能力値+20
		"indomitable",           # 不屈
		"peace",                 # 平和
		"metal_form",            # 金属化
	]
	
	# 呪い系のeffect_type（不利 - 敵クリーチャー向け）
	const HARMFUL_CURSE_EFFECTS = [
		"skill_nullify",         # スキル無効
		"battle_disable",        # 戦闘不能
		"plague_curse",          # 疫病
		"move_disable",          # 移動不可
		"stat_reduce",           # ステータス減少
		"destroy_after_battle",  # 戦闘後破壊
		"land_effect_disable",   # 地形効果無効
		"ap_nullify",            # AP=0
		"bounty_curse",          # 賞金首
		"life_force_curse",      # ライフフォース
		"random_stat_curse",     # 能力値不定
		"toll_fixed",            # 通行料固定
	]
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var curse_type = effect.get("curse_type", "")
		
		# effect_typeで判定
		if effect_type in BENEFICIAL_CURSE_EFFECTS:
			result.is_curse = true
			result.is_beneficial = true
			break
		elif effect_type in HARMFUL_CURSE_EFFECTS:
			result.is_curse = true
			result.is_beneficial = false
			break
		elif effect_type == "creature_curse" or effect_type == "player_curse":
			result.is_curse = true
			# curse_typeで有利/不利を判定
			if curse_type in CpuCurseEvaluator.BENEFICIAL_CREATURE_CURSES:
				result.is_beneficial = true
			elif curse_type in CpuCurseEvaluator.HARMFUL_CREATURE_CURSES:
				result.is_beneficial = false
			break
		elif curse_type != "":
			result.is_curse = true
			if curse_type in CpuCurseEvaluator.BENEFICIAL_CREATURE_CURSES:
				result.is_beneficial = true
			elif curse_type in CpuCurseEvaluator.HARMFUL_CREATURE_CURSES:
				result.is_beneficial = false
			break
	
	return result

## 旧互換（他の箇所で使用されている場合）
func select_best_target(targets: Array, spell: Dictionary, context: Dictionary) -> Dictionary:
	var result = select_best_target_with_score(targets, spell, context)
	return result.target

## 外部から呼び出し用（魔法タイル等）
## 事前に取得済みのターゲットリストから最適な対象を選択
func select_best_target_from_list(targets: Array, spell: Dictionary, player_id: int) -> Dictionary:
	if targets.is_empty():
		return {}
	
	# コンテキスト構築
	var context = {
		"player_id": player_id,
		"magic": 0,
		"damage_value": 0
	}
	if player_system and player_id < player_system.players.size():
		context.magic = player_system.players[player_id].magic_power
	
	# スペルのダメージ値をコンテキストに設定
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		if effect_type == "damage" or effect_type == "hp_damage":
			context.damage_value = effect.get("value", effect.get("damage", 0))
			break
	
	# 既存のselect_best_target_with_scoreを使用
	var result = select_best_target_with_score(targets, spell, context)
	return result.target

# =============================================================================
# 条件別ターゲット選択
# =============================================================================

## 条件に基づくターゲット取得（スコア付き）
func get_condition_target_with_score(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var cpu_rule = spell.get("cpu_rule", {})
	var condition = cpu_rule.get("condition", "")
	
	# element_mismatch + creature の場合、スコア計算を使用
	if condition == "element_mismatch" and target_type == "creature":
		var mismatched = target_resolver.check_target_condition("element_mismatch_creatures", context)
		# 自クリーチャーのみフィルタ（防御型・防魔を除外）
		var own_mismatched = []
		for target in mismatched:
			var tile_index = target.get("tile_index", -1)
			if tile_index >= 0 and board_system:
				var tile = board_system.get_tile_data(tile_index)
				if tile and tile.get("owner", tile.get("owner_id", -1)) == context.player_id:
					var creature = target.get("creature", {})
					# 防御型クリーチャーは移動できないので除外
					if _is_defensive_creature(creature):
						continue
					# 防魔チェック
					if SpellProtection.is_creature_protected(creature, _build_world_curse_context()):
						continue
					own_mismatched.append(target)
		
		if own_mismatched.is_empty():
			return {"target": {}, "score": 0.0}
		
		# スコア計算を使用して最適なターゲットを選択
		return select_best_target_with_score(own_mismatched, spell, context)
	
	# その他の条件は従来通り（スコア0で返す）
	var target = get_condition_target(spell, context)
	return {"target": target, "score": 0.0}

## 条件に基づくターゲット取得（旧互換）
func get_condition_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var cpu_rule = spell.get("cpu_rule", {})
	var condition = cpu_rule.get("condition", "")
	
	match target_type:
		"self", "none":
			return {"type": "self", "player_id": context.player_id}
		"player":
			# target_conditionに応じてターゲットを決定
			var target_condition = cpu_rule.get("target_condition", "")
			if target_condition == "self":
				return {"type": "player", "player_id": context.player_id}
			# デフォルト: 敵プレイヤー
			var enemies = get_enemy_players(context)
			if not enemies.is_empty():
				return enemies[0]
			return {}
		"unvisited_gate":
			# リミッション用：進行方向から遠い未訪問ゲートを選ぶ
			var farthest_gate = get_farthest_unvisited_gate(context)
			if not farthest_gate.is_empty():
				return farthest_gate
			return {}
		"own_land":
			# 属性変更スペルの場合、属性一致を改善できる土地を選ぶ
			if condition == "element_mismatch":
				var best_land = get_best_element_shift_target(spell, context)
				if not best_land.is_empty():
					return best_land
				# 適切なターゲットがない場合は空を返す（使用しない）
				return {}
			# デフォルト: 最初の自ドミニオ
			var lands = get_land_targets("own", context)
			if not lands.is_empty():
				return lands[0]
		"land":
			# 条件に応じたターゲット取得
			match condition:
				"enemy_high_level":
					# 敵の高レベル土地（レベル3以上で最もレベルが高いもの）
					var enemy_lands = get_enemy_lands_by_level_sorted(context.player_id, 3)
					if not enemy_lands.is_empty():
						return {"type": "land", "tile_index": enemy_lands[0].get("index", -1)}
				"enemy_level_4":
					# 敵のレベル4土地
					var enemy_lands = get_enemy_lands_by_level_sorted(context.player_id, 4)
					if not enemy_lands.is_empty():
						return {"type": "land", "tile_index": enemy_lands[0].get("index", -1)}
				_:
					# デフォルト: 敵の土地から選択
					var lands = get_land_targets("enemy", context)
					if not lands.is_empty():
						return lands[0]
		"creature":
			# 移動侵略スペルの場合、勝てる自クリーチャーを選ぶ
			if condition == "move_invasion_win":
				var best_target = get_best_move_invasion_target(context)
				if not best_target.is_empty():
					return best_target
				return {}
			# エクスチェンジの場合、属性不一致のクリーチャーを優先
			if condition == "can_upgrade_creature":
				var best_target = get_best_exchange_target(context)
				if not best_target.is_empty():
					return best_target
			# 属性不一致の場合、属性不一致の自クリーチャーをターゲット（スコア計算使用）
			if condition == "element_mismatch":
				var mismatched = target_resolver.check_target_condition("element_mismatch_creatures", context)
				# 自クリーチャーのみフィルタ（防御型を除外）
				var own_mismatched = []
				for target in mismatched:
					var tile_index = target.get("tile_index", -1)
					if tile_index >= 0 and board_system:
						var tile = board_system.get_tile_data(tile_index)
						if tile and tile.get("owner", tile.get("owner_id", -1)) == context.player_id:
							var creature = target.get("creature", {})
							# 防御型クリーチャーは移動できないので除外
							if not _is_defensive_creature(creature):
								own_mismatched.append(target)
				if not own_mismatched.is_empty():
					# スコア計算を使用して最適なターゲットを選択
					var selection = select_best_target_with_score(own_mismatched, spell, context)
					return selection.target
				return {}
			var targets = get_default_targets(spell, context)
			if not targets.is_empty():
				return targets[0]
	
	return {}

## profit_calc用ターゲット取得
func get_profit_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	
	# 全体効果・ターゲット不要のスペル
	if target_type in ["all_players", "all_creatures", "all_lands", "world", "none"]:
		return {}
	
	if target_type == "player":
		var enemies = get_enemy_players(context)
		if not enemies.is_empty():
			return enemies[0]
	
	return {"type": "self", "player_id": context.player_id}

## strategic用ターゲット取得
func get_strategic_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	var target_filter = effect_parsed.get("target_filter", "any")
	
	match target_type:
		"player":
			if target_filter == "enemy":
				var enemies = get_enemy_players(context)
				if not enemies.is_empty():
					return enemies[randi() % enemies.size()]
			elif target_filter == "self":
				return {"type": "self", "player_id": context.player_id}
			else:
				# any: ランダム
				if randf() < 0.5:
					return {"type": "self", "player_id": context.player_id}
				else:
					var enemies = get_enemy_players(context)
					if not enemies.is_empty():
						return enemies[randi() % enemies.size()]
		"world", "none", "self", "all_players", "all_creatures", "all_lands":
			# 全体効果・自己対象・ターゲット不要のスペル
			return {}
	
	return {"type": "self", "player_id": context.player_id}

# =============================================================================
# 特殊ターゲット選択
# =============================================================================

## エクスチェンジ用：交換対象の自クリーチャーを選ぶ
## 属性不一致で、手札のクリーチャーで改善できるものを優先
func get_best_exchange_target(context: Dictionary) -> Dictionary:
	var player_id = context.get("player_id", 0)
	
	if not board_system or not card_system:
		return {}
	
	# 手札のクリーチャーを取得
	var hand = card_system.get_all_cards_for_player(player_id)
	var hand_creatures = []
	for card in hand:
		if card.get("type") == "creature":
			hand_creatures.append(card)
	
	if hand_creatures.is_empty():
		return {}
	
	# 手札クリーチャーの属性セットを作成
	var hand_elements = {}
	for hc in hand_creatures:
		hand_elements[hc.get("element", "")] = true
	
	# 自クリーチャーを取得
	var tiles = board_system.get_all_tiles()
	var candidates = []
	
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id:
			continue
		
		var creature = tile.get("creature", {})
		if creature.is_empty():
			continue
		
		# アルカナアーツ持ちは交換対象外
		if _has_mystic_arts(creature):
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		var is_mismatched = tile_element != creature_element and tile_element != "neutral" and creature_element != "neutral"
		
		# 手札に該当タイルと一致する属性のクリーチャーがいるか
		var can_improve = hand_elements.has(tile_element)
		
		candidates.append({
			"type": "creature",
			"tile_index": tile.get("index", -1),
			"creature": creature,
			"is_mismatched": is_mismatched,
			"can_improve": can_improve
		})
	
	if candidates.is_empty():
		return {}
	
	# ソート：改善可能 & 属性不一致を優先
	candidates.sort_custom(func(a, b):
		# 改善可能かつ属性不一致が最優先
		var a_priority = 0
		var b_priority = 0
		if a.can_improve and a.is_mismatched:
			a_priority = 2
		elif a.is_mismatched:
			a_priority = 1
		if b.can_improve and b.is_mismatched:
			b_priority = 2
		elif b.is_mismatched:
			b_priority = 1
		return a_priority > b_priority
	)
	
	return candidates[0]

## 移動侵略スペル用：勝てる自クリーチャーをターゲットとして返す
## アウトレイジ、チャリオット等で使用
## contextにspell情報がある場合、スペルの移動距離を考慮
func get_best_move_invasion_target(context: Dictionary) -> Dictionary:
	var player_id = context.get("player_id", 0)
	
	if not board_system or not condition_checker or not condition_checker._battle_simulator:
		return {}
	
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
	var own_creatures = condition_checker.get_own_creatures_on_board(player_id)
	if own_creatures.is_empty():
		return {}
	
	# 勝てる組み合わせを収集
	var winning_combos = []
	var battle_simulator = condition_checker._battle_simulator
	
	for own_tile in own_creatures:
		var attacker = own_tile.get("creature", {})
		if attacker.is_empty():
			continue
		
		var from_tile = own_tile.get("tile_index", -1)
		if from_tile < 0:
			continue
		
		# 移動可能な敵ドミニオを取得
		var reachable_enemies = condition_checker.get_reachable_enemy_tiles(from_tile, player_id, steps, exact_steps)
		
		for enemy_tile in reachable_enemies:
			var defender = enemy_tile.get("creature", {})
			if defender.is_empty():
				continue
			
			# シミュレーション
			var sim_tile_info = {
				"element": enemy_tile.get("element", ""),
				"level": enemy_tile.get("level", 1),
				"owner": enemy_tile.get("owner", -1),
				"tile_index": enemy_tile.get("tile_index", -1)
			}
			
			# まず両方アイテムなしでシミュレーション（攻撃の最低条件）
			var base_result = battle_simulator.simulate_battle(
				attacker,
				defender,
				sim_tile_info,
				player_id,
				{},
				{}
			)
			
			var base_win = base_result.get("result", -1) == condition_checker.BattleSimulatorScript.BattleResult.ATTACKER_WIN
			if not base_win:
				continue  # 両方アイテムなしで勝てない → 候補外
			
			# ワーストケースシミュレーション（敵がアイテム/援護を使った場合）
			var worst_case_win = condition_checker.check_worst_case_win(attacker, defender, sim_tile_info, player_id)
			
			if worst_case_win:
				# オーバーキル計算（低いほど効率的）
				var overkill = base_result.get("attacker_ap", 0) - base_result.get("defender_hp", 0)
				winning_combos.append({
					"own_tile_index": own_tile.get("tile_index", -1),
					"enemy_tile_index": enemy_tile.get("tile_index", -1),
					"attacker": attacker,
					"defender": defender,
					"enemy_level": enemy_tile.get("level", 1),
					"overkill": max(0, overkill)
				})
	
	if winning_combos.is_empty():
		return {}
	
	# 優先順位：敵土地レベルが高い > オーバーキルが低い
	winning_combos.sort_custom(func(a, b):
		if a.enemy_level != b.enemy_level:
			return a.enemy_level > b.enemy_level
		return a.overkill < b.overkill
	)
	
	var best = winning_combos[0]
	
	return {
		"type": "creature",
		"tile_index": best.own_tile_index,
		"creature": best.attacker,
		"enemy_tile_index": best.enemy_tile_index  # CPUが選んだ移動先
	}

## 属性変更スペルの最適ターゲットを取得
## 変更先属性とクリーチャーの属性が一致し、現在土地属性が不一致の土地を選ぶ
func get_best_element_shift_target(spell: Dictionary, context: Dictionary) -> Dictionary:
	var effect_parsed = spell.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	# 変更先属性を取得
	var target_element = ""
	for effect in effects:
		if effect.get("effect_type") == "change_element":
			target_element = effect.get("element", "")
			break
	
	if target_element.is_empty():
		return {}
	
	if not board_system:
		return {}
	
	var player_id = context.get("player_id", 0)
	var tiles = board_system.get_all_tiles()
	
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id != player_id:
			continue
		
		var creature = tile.get("creature", tile.get("placed_creature", {}))
		if not creature or creature.is_empty():
			continue
		
		var tile_element = tile.get("element", "")
		var creature_element = creature.get("element", "")
		
		# クリーチャーの属性が変更先属性と一致し、土地属性が不一致の場合
		if creature_element == target_element and tile_element != target_element:
			return {"type": "land", "tile_index": tile.get("index", -1)}
	
	# 見つからなければ空を返す（使用しない方がいい）
	return {}

# =============================================================================
# ゲート・チェックポイント関連
# =============================================================================

## 進行方向から最も遠い未訪問ゲートを取得（リミッション用）
func get_farthest_unvisited_gate(context: Dictionary) -> Dictionary:
	var player_id = context.get("player_id", 0)
	
	if not lap_system or not board_system:
		return {}
	
	var player_state = lap_system.player_lap_state.get(player_id, {})
	var required_checkpoints = lap_system.required_checkpoints
	
	# 未訪問ゲートを収集
	var unvisited_gates = []
	for checkpoint in required_checkpoints:
		if not player_state.get(checkpoint, false):
			var tile_index = _get_checkpoint_tile_index(checkpoint)
			if tile_index >= 0:
				unvisited_gates.append({
					"type": "unvisited_gate",
					"checkpoint": checkpoint,
					"tile_index": tile_index
				})
	
	if unvisited_gates.is_empty():
		return {}
	
	if unvisited_gates.size() == 1:
		return unvisited_gates[0]
	
	# プレイヤーの現在位置を取得
	var current_tile = _get_player_current_tile(player_id)
	
	# 進行方向での距離を計算し、最も遠いものを選択
	var farthest_gate = null
	var max_distance = -1
	
	for gate in unvisited_gates:
		var dist = _calculate_forward_distance(current_tile, gate.tile_index, player_id)
		if dist > max_distance:
			max_distance = dist
			farthest_gate = gate
	return farthest_gate if farthest_gate else {}

## チェックポイントのタイルインデックスを取得（N, S, E, W対応）
func _get_checkpoint_tile_index(checkpoint_type: String) -> int:
	if not board_system:
		return -1
	
	var tiles = board_system.tile_nodes if "tile_nodes" in board_system else {}
	for tile_index in tiles.keys():
		var tile = tiles[tile_index]
		if tile and tile.tile_type == "checkpoint":
			var type_str = get_checkpoint_type_string(tile)
			if type_str == checkpoint_type:
				return tile_index
	
	return -1

## タイルからチェックポイントタイプ文字列を取得（N, S, E, W対応）
func get_checkpoint_type_string(tile) -> String:
	if not tile:
		return ""
	var cp_type = tile.checkpoint_type if "checkpoint_type" in tile else 0
	match cp_type:
		0: return "N"
		1: return "S"
		2: return "E"
		3: return "W"
		_: return ""

# =============================================================================
# ヘルパー関数
# =============================================================================

## 敵プレイヤー取得
func get_enemy_players(context: Dictionary) -> Array:
	var player_id = context.player_id
	var results = []
	
	if not player_system:
		return results
	
	var player_count = player_system.players.size()
	for i in range(player_count):
		if i != player_id:
			results.append({"type": "player", "player_id": i})
	
	# EP（魔力）が多い順にソート
	results.sort_custom(func(a, b):
		var magic_a = player_system.get_magic(a.player_id)
		var magic_b = player_system.get_magic(b.player_id)
		return magic_a > magic_b
	)
	
	return results

## 土地ターゲット取得
func get_land_targets(owner_filter: String, context: Dictionary) -> Array:
	var player_id = context.player_id
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		
		match owner_filter:
			"own":
				if owner_id != player_id:
					continue
			"enemy":
				if owner_id == player_id or owner_id == -1:
					continue
			"any":
				pass
		
		results.append({"type": "land", "tile_index": tile.get("index", -1)})
	
	return results

## 指定レベル以上の敵土地をレベル降順でソートして取得
func get_enemy_lands_by_level_sorted(player_id: int, min_level: int) -> Array:
	var results = []
	
	if not board_system:
		return results
	
	var tiles = board_system.get_all_tiles()
	for tile in tiles:
		var owner_id = tile.get("owner", tile.get("owner_id", -1))
		if owner_id == player_id or owner_id == -1:
			continue
		
		var level = tile.get("level", 1)
		if level >= min_level:
			results.append(tile)
	
	# レベル降順でソート（最もレベルが高いものを優先）
	results.sort_custom(func(a, b): return a.get("level", 1) > b.get("level", 1))
	
	return results

## プレイヤーの現在位置を取得
func _get_player_current_tile(player_id: int) -> int:
	if board_system and board_system.has_method("get_player_tile"):
		return board_system.get_player_tile(player_id)
	if player_system:
		return player_system.get_player_position(player_id)
	return 0

## プレイヤーの進行方向での距離を計算
func _calculate_forward_distance(from_tile: int, to_tile: int, player_id: int) -> int:
	if not board_system or not "tile_neighbor_system" in board_system:
		return abs(to_tile - from_tile)
	
	var neighbor_system = board_system.tile_neighbor_system
	if not neighbor_system:
		return abs(to_tile - from_tile)
	
	# プレイヤーの進行方向を取得
	var direction = 1
	if player_system and player_id < player_system.players.size():
		direction = player_system.players[player_id].current_direction
	
	# プレイヤーの実際のcame_fromを取得
	var came_from = -1
	if player_system and player_id < player_system.players.size():
		came_from = player_system.players[player_id].came_from
	
	# 進行方向のみで探索
	var current = from_tile
	var dist = 0
	var max_steps = 100  # 無限ループ防止
	
	while dist < max_steps:
		# 次のタイルを取得（進行方向のみ）
		var next_tile = _get_next_tile_in_direction(current, came_from, direction)
		if next_tile < 0:
			break
		
		dist += 1
		
		if next_tile == to_tile:
			return dist
		
		came_from = current
		current = next_tile
	
	return 9999  # 到達不可

## 進行方向で次のタイルを取得
func _get_next_tile_in_direction(current_tile: int, came_from: int, direction: int) -> int:
	if not board_system:
		return current_tile + direction
	
	# tile_neighbor_systemを使用
	if "tile_neighbor_system" in board_system and board_system.tile_neighbor_system:
		var neighbor_system = board_system.tile_neighbor_system
		if neighbor_system.has_method("get_sequential_neighbors"):
			var neighbors = neighbor_system.get_sequential_neighbors(current_tile)
			var choices = []
			for n in neighbors:
				if n != came_from:
					choices.append(n)
			
			if choices.is_empty():
				return came_from if came_from >= 0 else current_tile + direction
			if choices.size() == 1:
				return choices[0]
			
			# came_from不明（スタート直後等）の場合、directionに基づいてインデックスで判定
			if came_from < 0:
				# direction > 0 ならインデックスが大きい方向、< 0 なら小さい方向
				# ただしループ端（例: 0→33）を考慮し、current_tileとの差で判定
				var best = choices[0]
				for c in choices:
					var diff_c = c - current_tile
					var diff_best = best - current_tile
					if direction > 0:
						# 正方向: current+1方向を優先（差が小さい正の値）
						if diff_c > 0 and (diff_best <= 0 or diff_c < diff_best):
							best = c
					else:
						# 逆方向: current-1方向を優先（差が大きい負の値）
						if diff_c < 0 and (diff_best >= 0 or diff_c > diff_best):
							best = c
				return best
			
			# came_fromがある場合、方向に基づいて選択
			choices.sort()
			if direction > 0:
				return choices[-1]
			else:
				return choices[0]
	
	# tile_neighbor_systemを使用
	if "tile_neighbor_system" in board_system and board_system.tile_neighbor_system:
		var neighbor_system = board_system.tile_neighbor_system
		if neighbor_system.has_method("get_sequential_neighbors"):
			var neighbors = neighbor_system.get_sequential_neighbors(current_tile)
			var choices = []
			for n in neighbors:
				if n != came_from:
					choices.append(n)
			
			if choices.is_empty():
				return came_from if came_from >= 0 else current_tile + direction
			if choices.size() == 1:
				return choices[0]
			
			# 複数選択肢がある場合、方向に基づいて選択
			choices.sort()
			if direction > 0:
				return choices[-1]
			else:
				return choices[0]
	
	# フォールバック: 単純に+direction
	return current_tile + direction


## アルカナアーツ持ちかどうかをチェック
func _has_mystic_arts(creature_data: Dictionary) -> bool:
	# トップレベルのmystic_artsをチェック
	if creature_data.has("mystic_arts") and creature_data.get("mystic_arts") != null:
		return true
	
	# ability_parsed.mystic_artsをチェック
	var ability_parsed = creature_data.get("ability_parsed", {})
	if ability_parsed and ability_parsed.has("mystic_arts"):
		var mystic_arts = ability_parsed.get("mystic_arts", [])
		if not mystic_arts.is_empty():
			return true
	
	# keywordsにアルカナアーツがあるかチェック
	if ability_parsed:
		var keywords = ability_parsed.get("keywords", [])
		if "アルカナアーツ" in keywords:
			return true
	
	return false

## 防御型クリーチャーかどうかをチェック（移動不可）
func _is_defensive_creature(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	# creature_typeで判定
	if creature_data.get("creature_type", "") == "defensive":
		return true
	# ability_parsed.keywordsで判定
	var ability_parsed = creature_data.get("ability_parsed", {})
	if ability_parsed:
		var keywords = ability_parsed.get("keywords", [])
		if "防御型" in keywords:
			return true
	# 呪いによる防御型付与（マジックシェルター等）
	var curse = creature_data.get("curse", {})
	var curse_params = curse.get("params", {})
	if curse_params.get("defensive_form", false):
		return true
	return false
