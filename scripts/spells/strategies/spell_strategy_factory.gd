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
		# === EP/Magic 操作系（13個）===
		"drain_magic": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"drain_magic_conditional": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"drain_magic_by_land_count": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"drain_magic_by_lap_diff": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"gain_magic": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"gain_magic_by_rank": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"gain_magic_by_lap": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"gain_magic_from_destroyed_count": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"gain_magic_from_spell_cost": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"balance_all_magic": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"gain_magic_from_land_chain": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"mhp_to_magic": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		"drain_magic_by_spell_count": preload("res://scripts/spells/strategies/effect_strategies/magic_effect_strategy.gd"),
		# === 手札操作系（14個） ===
		"discard_and_draw_plus": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"check_hand_elements": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"check_hand_synthesis": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"destroy_curse_cards": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"destroy_expensive_cards": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"destroy_duplicate_cards": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"destroy_selected_card": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"steal_selected_card": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"destroy_from_deck_selection": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"steal_item_conditional": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"add_specific_card": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"destroy_and_draw": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"swap_creature": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"transform_to_card": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"reset_deck": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		"destroy_deck_top": preload("res://scripts/spells/strategies/effect_strategies/hand_manipulation_effect_strategy.gd"),
		# === プレイヤー移動系（6個） ===
		"warp_to_nearest_vacant": preload("res://scripts/spells/strategies/effect_strategies/player_move_effect_strategy.gd"),
		"warp_to_nearest_gate": preload("res://scripts/spells/strategies/effect_strategies/player_move_effect_strategy.gd"),
		"warp_to_target": preload("res://scripts/spells/strategies/effect_strategies/player_move_effect_strategy.gd"),
		"curse_movement_reverse": preload("res://scripts/spells/strategies/effect_strategies/player_move_effect_strategy.gd"),
		"gate_pass": preload("res://scripts/spells/strategies/effect_strategies/player_move_effect_strategy.gd"),
		"grant_direction_choice": preload("res://scripts/spells/strategies/effect_strategies/player_move_effect_strategy.gd"),
		# === ステータス増減系（4個） ===
		"permanent_hp_change": preload("res://scripts/spells/strategies/effect_strategies/stat_change_effect_strategy.gd"),
		"permanent_ap_change": preload("res://scripts/spells/strategies/effect_strategies/stat_change_effect_strategy.gd"),
		"conditional_ap_change": preload("res://scripts/spells/strategies/effect_strategies/stat_change_effect_strategy.gd"),
		"secret_tiny_army": preload("res://scripts/spells/strategies/effect_strategies/stat_change_effect_strategy.gd"),
		# === 呪い除去系（4個） ===
		"purify_all": preload("res://scripts/spells/strategies/effect_strategies/purify_effect_strategy.gd"),
		"remove_creature_curse": preload("res://scripts/spells/strategies/effect_strategies/purify_effect_strategy.gd"),
		"remove_world_curse": preload("res://scripts/spells/strategies/effect_strategies/purify_effect_strategy.gd"),
		"remove_all_player_curses": preload("res://scripts/spells/strategies/effect_strategies/purify_effect_strategy.gd"),
		# === ダウン操作系（2個） ===
		"down_clear": preload("res://scripts/spells/strategies/effect_strategies/down_state_effect_strategy.gd"),
		"set_down": preload("res://scripts/spells/strategies/effect_strategies/down_state_effect_strategy.gd"),
		# === クリーチャー配置系（1個） ===
		"place_creature": preload("res://scripts/spells/strategies/effect_strategies/creature_place_effect_strategy.gd"),
		# === クリーチャー交換系（2個） ===
		"swap_with_hand": preload("res://scripts/spells/strategies/effect_strategies/creature_swap_effect_strategy.gd"),
		"swap_board_creatures": preload("res://scripts/spells/strategies/effect_strategies/creature_swap_effect_strategy.gd"),
		# === スペル借用系（2個） ===
		"use_hand_spell": preload("res://scripts/spells/strategies/effect_strategies/spell_borrow_effect_strategy.gd"),
		"use_target_mystic_art": preload("res://scripts/spells/strategies/effect_strategies/spell_borrow_effect_strategy.gd"),
		# === クリーチャー変身系（2個） ===
		"transform": preload("res://scripts/spells/strategies/effect_strategies/transform_effect_strategy.gd"),
		"discord_transform": preload("res://scripts/spells/strategies/effect_strategies/transform_effect_strategy.gd"),
		# === クリーチャー手札戻し系（1個） ===
		"return_to_hand": preload("res://scripts/spells/strategies/effect_strategies/creature_return_effect_strategy.gd"),
		# === 自滅効果（1個） ===
		"self_destroy": preload("res://scripts/spells/strategies/effect_strategies/self_destroy_effect_strategy.gd"),
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
		# === EP/Magic 操作系（13個）===
		"drain_magic",
		"drain_magic_conditional",
		"drain_magic_by_land_count",
		"drain_magic_by_lap_diff",
		"gain_magic",
		"gain_magic_by_rank",
		"gain_magic_by_lap",
		"gain_magic_from_destroyed_count",
		"gain_magic_from_spell_cost",
		"balance_all_magic",
		"gain_magic_from_land_chain",
		"mhp_to_magic",
		"drain_magic_by_spell_count",
		# === 手札操作系（14個） ===
		"discard_and_draw_plus",
		"check_hand_elements",
		"check_hand_synthesis",
		"destroy_curse_cards",
		"destroy_expensive_cards",
		"destroy_duplicate_cards",
		"destroy_selected_card",
		"steal_selected_card",
		"destroy_from_deck_selection",
		"steal_item_conditional",
		"add_specific_card",
		"destroy_and_draw",
		"swap_creature",
		"transform_to_card",
		"reset_deck",
		"destroy_deck_top",
		# === プレイヤー移動系（6個） ===
		"warp_to_nearest_vacant",
		"warp_to_nearest_gate",
		"warp_to_target",
		"curse_movement_reverse",
		"gate_pass",
		"grant_direction_choice",
		# === ステータス増減系（4個） ===
		"permanent_hp_change",
		"permanent_ap_change",
		"conditional_ap_change",
		"secret_tiny_army",
		# === 呪い除去系（4個） ===
		"purify_all",
		"remove_creature_curse",
		"remove_world_curse",
		"remove_all_player_curses",
		# === ダウン操作系（2個） ===
		"down_clear",
		"set_down",
		# === クリーチャー配置系（1個） ===
		"place_creature",
		# === クリーチャー交換系（2個） ===
		"swap_with_hand",
		"swap_board_creatures",
		# === スペル借用系（2個） ===
		"use_hand_spell",
		"use_target_mystic_art",
		# === クリーチャー変身系（2個） ===
		"transform",
		"discord_transform",
		# === クリーチャー手札戻し系（1個） ===
		"return_to_hand",
		# === 自滅効果（1個） ===
		"self_destroy",
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
		# === EP/Magic 操作系（13個）===
		"drain_magic",
		"drain_magic_conditional",
		"drain_magic_by_land_count",
		"drain_magic_by_lap_diff",
		"gain_magic",
		"gain_magic_by_rank",
		"gain_magic_by_lap",
		"gain_magic_from_destroyed_count",
		"gain_magic_from_spell_cost",
		"balance_all_magic",
		"gain_magic_from_land_chain",
		"mhp_to_magic",
		"drain_magic_by_spell_count",
		# === 手札操作系（14個） ===
		"discard_and_draw_plus",
		"check_hand_elements",
		"check_hand_synthesis",
		"destroy_curse_cards",
		"destroy_expensive_cards",
		"destroy_duplicate_cards",
		"destroy_selected_card",
		"steal_selected_card",
		"destroy_from_deck_selection",
		"steal_item_conditional",
		"add_specific_card",
		"destroy_and_draw",
		"swap_creature",
		"transform_to_card",
		"reset_deck",
		"destroy_deck_top",
		# === プレイヤー移動系（6個） ===
		"warp_to_nearest_vacant",
		"warp_to_nearest_gate",
		"warp_to_target",
		"curse_movement_reverse",
		"gate_pass",
		"grant_direction_choice",
		# === ステータス増減系（4個） ===
		"permanent_hp_change",
		"permanent_ap_change",
		"conditional_ap_change",
		"secret_tiny_army",
		# === 呪い除去系（4個） ===
		"purify_all",
		"remove_creature_curse",
		"remove_world_curse",
		"remove_all_player_curses",
		# === ダウン操作系（2個） ===
		"down_clear",
		"set_down",
		# === クリーチャー配置系（1個） ===
		"place_creature",
		# === クリーチャー交換系（2個） ===
		"swap_with_hand",
		"swap_board_creatures",
		# === スペル借用系（2個） ===
		"use_hand_spell",
		"use_target_mystic_art",
		# === クリーチャー変身系（2個） ===
		"transform",
		"discord_transform",
		# === クリーチャー手札戻し系（1個） ===
		"return_to_hand",
		# === 自滅効果（1個） ===
		"self_destroy",
	]
