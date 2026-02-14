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
	]
