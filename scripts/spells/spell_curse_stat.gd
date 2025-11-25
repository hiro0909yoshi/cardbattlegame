extends Node
class_name SpellCurseStat

# ステータス増減呪い実装
# ドキュメント: docs/design/spells/ステータス増減.md

var spell_curse: SpellCurse
var creature_manager: CreatureManager

func setup(curse: SpellCurse, creature_mgr: CreatureManager):
	spell_curse = curse
	creature_manager = creature_mgr
	print("[SpellCurseStat] 初期化完了")

# ========================================
# スペル使用時（SpellPhaseHandlerから呼ばれる）
# ========================================

# 能力値上昇呪いを付与
func apply_stat_boost(tile_index: int, effect: Dictionary):
	var value = effect.get("value", 20)
	var duration = effect.get("duration", -1)
	var _name = effect.get("name", "能力値+20")
	
	spell_curse.curse_creature(tile_index, "stat_boost", duration, {
		"name": name,
		"value": value
	})

# 能力値減少呪いを付与
func apply_stat_reduce(tile_index: int, effect: Dictionary):
	var value = effect.get("value", -20)
	var duration = effect.get("duration", -1)
	var _name = effect.get("name", "能力値-20")
	
	spell_curse.curse_creature(tile_index, "stat_reduce", duration, {
		"name": name,
		"value": value
	})

# ========================================
# 汎用効果適用（統合版）
# ========================================

## スペル効果から呪いを適用（統合メソッド）
func apply_curse_from_effect(effect: Dictionary, tile_index: int):
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"stat_boost":
			apply_stat_boost(tile_index, effect)
		
		"stat_reduce":
			apply_stat_reduce(tile_index, effect)
		
		_:
			print("[SpellCurseStat] 未対応の効果タイプ: ", effect_type)

# ========================================
# バトル時（BattlePreparationから呼ばれる）
# ========================================

# 呪いをtemporary_effectsに変換
func apply_to_creature_data(tile_index: int):
	var curse = spell_curse.get_creature_curse(tile_index)
	if curse.is_empty():
		return
	
	var creature = creature_manager.get_data_ref(tile_index)
	if creature.is_empty():
		return
	
	var curse_type = curse.get("curse_type", "")
	var params = curse.get("params", {})
	
	match curse_type:
		"stat_boost":
			var value = params.get("value", 20)
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "hp",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "ap",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			print("[呪い変換] stat_boost: HP+", value, ", AP+", value)
		
		"stat_reduce":
			var value = params.get("value", -20)
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "hp",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "ap",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			print("[呪い変換] stat_reduce: HP", value, ", AP", value)
