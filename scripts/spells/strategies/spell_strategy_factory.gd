## SpellStrategyFactory - スペル戦略のファクトリーパターン実装
class_name SpellStrategyFactory

## スペルID → Strategy クラスのマッピング
## Day 1-2: EarthShift (2001) のみ実装
## Day 3-4: 他のスペルは順次追加
const STRATEGIES = {
	2001: preload("res://scripts/spells/strategies/spell_strategies/earth_shift_strategy.gd"),
	# 以下のスペルは Day 3-4 で追加予定
	# 2002: Outrage
	# 2003: Asteroid
	# 2004: Assemble Card
	# ... その他のスペル
}

## スペルIDに対応する Strategy インスタンスを生成
## 戻り値: Strategy インスタンス、存在しない場合は null
static func create_strategy(spell_id: int) -> SpellStrategy:
	var strategy_class = STRATEGIES.get(spell_id)

	if strategy_class:
		return strategy_class.new()
	else:
		# 未知のスペルID → null を返す
		# SpellPhaseHandler がフォールバック（既存ロジック）を使用
		return null

## デバッグ: 登録済みスペルIDの一覧を取得
static func get_registered_spell_ids() -> Array:
	return STRATEGIES.keys()

## デバッグ: 指定スペルIDが Strategy 実装済みか確認
static func has_strategy(spell_id: int) -> bool:
	return STRATEGIES.has(spell_id)

## ================================================================================
## effect_type ベース Strategy 生成（Phase 3-A-1）
## ================================================================================

## effect_type に対応する Strategy インスタンスを生成
## 戻り値: Strategy インスタンス、存在しない場合は null
static func create_effect_strategy(effect_type: String) -> SpellStrategy:
	var effect_strategies = {
		"damage": preload("res://scripts/spells/strategies/effect_strategies/damage_effect_strategy.gd"),
		"heal": preload("res://scripts/spells/strategies/effect_strategies/heal_effect_strategy.gd"),
		"full_heal": preload("res://scripts/spells/strategies/effect_strategies/heal_effect_strategy.gd"),
		"move_to_adjacent_enemy": preload("res://scripts/spells/strategies/effect_strategies/creature_move_effect_strategy.gd"),
		"move_steps": preload("res://scripts/spells/strategies/effect_strategies/creature_move_effect_strategy.gd"),
		"move_self": preload("res://scripts/spells/strategies/effect_strategies/creature_move_effect_strategy.gd"),
		"destroy_and_move": preload("res://scripts/spells/strategies/effect_strategies/creature_move_effect_strategy.gd"),
		"dice_fixed": preload("res://scripts/spells/strategies/effect_strategies/dice_effect_strategy.gd"),
		"dice_range": preload("res://scripts/spells/strategies/effect_strategies/dice_effect_strategy.gd"),
		"dice_multi": preload("res://scripts/spells/strategies/effect_strategies/dice_effect_strategy.gd"),
		"dice_range_magic": preload("res://scripts/spells/strategies/effect_strategies/dice_effect_strategy.gd"),
		"change_element": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"change_level": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"set_level": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"abandon_land": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"destroy_creature": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"change_element_bidirectional": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"change_element_to_dominant": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"find_and_change_highest_level": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"conditional_level_change": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"align_mismatched_lands": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"self_destruct": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"change_caster_tile_element": preload("res://scripts/spells/strategies/effect_strategies/land_change_effect_strategy.gd"),
		"draw": preload("res://scripts/spells/strategies/effect_strategies/draw_effect_strategy.gd"),
		"draw_cards": preload("res://scripts/spells/strategies/effect_strategies/draw_effect_strategy.gd"),
		"draw_by_rank": preload("res://scripts/spells/strategies/effect_strategies/draw_effect_strategy.gd"),
		"draw_by_type": preload("res://scripts/spells/strategies/effect_strategies/draw_effect_strategy.gd"),
		"draw_from_deck_selection": preload("res://scripts/spells/strategies/effect_strategies/draw_effect_strategy.gd"),
		"draw_and_place": preload("res://scripts/spells/strategies/effect_strategies/draw_effect_strategy.gd"),
		# === クリーチャー呪い系（19個）===
		"skill_nullify": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"battle_disable": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"ap_nullify": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"stat_reduce": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"random_stat_curse": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"command_growth_curse": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"plague_curse": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"creature_curse": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"forced_stop": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"indomitable": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"land_effect_disable": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"land_effect_grant": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"metal_form": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"magic_barrier": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"destroy_after_battle": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"bounty_curse": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"grant_mystic_arts": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"land_curse": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		"apply_curse": preload("res://scripts/spells/strategies/effect_strategies/creature_curse_effect_strategy.gd"),
		# === プレイヤー呪い系（1個）===
		"player_curse": preload("res://scripts/spells/strategies/effect_strategies/player_curse_effect_strategy.gd"),
		# === 世界呪い系（1個）===
		"world_curse": preload("res://scripts/spells/strategies/effect_strategies/world_curse_effect_strategy.gd"),
		# === 通行料呪い系（6個）===
		"toll_share": preload("res://scripts/spells/strategies/effect_strategies/toll_curse_effect_strategy.gd"),
		"toll_disable": preload("res://scripts/spells/strategies/effect_strategies/toll_curse_effect_strategy.gd"),
		"toll_fixed": preload("res://scripts/spells/strategies/effect_strategies/toll_curse_effect_strategy.gd"),
		"toll_multiplier": preload("res://scripts/spells/strategies/effect_strategies/toll_curse_effect_strategy.gd"),
		"peace": preload("res://scripts/spells/strategies/effect_strategies/toll_curse_effect_strategy.gd"),
		"curse_toll_half": preload("res://scripts/spells/strategies/effect_strategies/toll_curse_effect_strategy.gd"),
		# === ステータス呪い系（1個）===
		"stat_boost": preload("res://scripts/spells/strategies/effect_strategies/stat_boost_effect_strategy.gd"),
	}

	if effect_type in effect_strategies:
		return effect_strategies[effect_type].new()
	else:
		# 未知の effect_type → null を返す
		# SpellEffectExecutor がフォールバック（既存ロジック）を使用
		return null

## デバッグ: 登録済み effect_type の一覧を取得
static func get_registered_effect_types() -> Array:
	return [
		"damage",
		"heal",
		"full_heal",
		"move_to_adjacent_enemy",
		"move_steps",
		"move_self",
		"destroy_and_move",
		"dice_fixed",
		"dice_range",
		"dice_multi",
		"dice_range_magic",
		"change_element",
		"change_level",
		"set_level",
		"abandon_land",
		"destroy_creature",
		"change_element_bidirectional",
		"change_element_to_dominant",
		"find_and_change_highest_level",
		"conditional_level_change",
		"align_mismatched_lands",
		"self_destruct",
		"change_caster_tile_element",
		"draw",
		"draw_cards",
		"draw_by_rank",
		"draw_by_type",
		"draw_from_deck_selection",
		"draw_and_place",
		# === クリーチャー呪い系（19個）===
		"skill_nullify",
		"battle_disable",
		"ap_nullify",
		"stat_reduce",
		"random_stat_curse",
		"command_growth_curse",
		"plague_curse",
		"creature_curse",
		"forced_stop",
		"indomitable",
		"land_effect_disable",
		"land_effect_grant",
		"metal_form",
		"magic_barrier",
		"destroy_after_battle",
		"bounty_curse",
		"grant_mystic_arts",
		"land_curse",
		"apply_curse",
		# === プレイヤー呪い系（1個）===
		"player_curse",
		# === 世界呪い系（1個）===
		"world_curse",
		# === 通行料呪い系（6個）===
		"toll_share",
		"toll_disable",
		"toll_fixed",
		"toll_multiplier",
		"peace",
		"curse_toll_half",
		# === ステータス呪い系（1個）===
		"stat_boost",
	]

## デバッグ: 指定 effect_type が Strategy 実装済みか確認
static func has_effect_strategy(effect_type: String) -> bool:
	return effect_type in [
		"damage",
		"heal",
		"full_heal",
		"move_to_adjacent_enemy",
		"move_steps",
		"move_self",
		"destroy_and_move",
		"dice_fixed",
		"dice_range",
		"dice_multi",
		"dice_range_magic",
		"change_element",
		"change_level",
		"set_level",
		"abandon_land",
		"destroy_creature",
		"change_element_bidirectional",
		"change_element_to_dominant",
		"find_and_change_highest_level",
		"conditional_level_change",
		"align_mismatched_lands",
		"self_destruct",
		"change_caster_tile_element",
		"draw",
		"draw_cards",
		"draw_by_rank",
		"draw_by_type",
		"draw_from_deck_selection",
		"draw_and_place",
		# === クリーチャー呪い系（19個）===
		"skill_nullify",
		"battle_disable",
		"ap_nullify",
		"stat_reduce",
		"random_stat_curse",
		"command_growth_curse",
		"plague_curse",
		"creature_curse",
		"forced_stop",
		"indomitable",
		"land_effect_disable",
		"land_effect_grant",
		"metal_form",
		"magic_barrier",
		"destroy_after_battle",
		"bounty_curse",
		"grant_mystic_arts",
		"land_curse",
		"apply_curse",
		# === プレイヤー呪い系（1個）===
		"player_curse",
		# === 世界呪い系（1個）===
		"world_curse",
		# === 通行料呪い系（6個）===
		"toll_share",
		"toll_disable",
		"toll_fixed",
		"toll_multiplier",
		"peace",
		"curse_toll_half",
		# === ステータス呪い系（1個）===
		"stat_boost",
	]
