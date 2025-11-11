# ステータス増減スペル設計

**最終更新**: 2025年11月12日 | **実装状況**: ❌ 未実装

---

## 概要

クリーチャーのST/HPを増減させるスペル。  
呪いシステムと既存のeffect_systemを利用。

---

## 実装スペル

| ID | 名前 | 効果 |
|----|------|------|
| 2066 | バイタリティ | ST&HP+20 |
| 2054 | ディジーズ | ST&HP-20 |

---

## アーキテクチャ

### クラス構成

- **SpellCurse**: 呪いの基盤
- **SpellCurseStat**: ステータス増減実装
- **BattlePreparation**: 1-2行の呼び出し

### データフロー

```
スペル使用
  ↓ SpellCurseStat.apply_stat_boost()
呪い付与 (creature_data["curse"])
  ↓ バトル発生
SpellCurseStat.apply_to_creature_data()
  ↓ temporary_effects追加
apply_effect_arrays() 自動適用
```

---

## 実装

### SpellCurseStat

```gdscript
class_name SpellCurseStat

var spell_curse: SpellCurse
var creature_manager: CreatureManager

# スペル使用時
func apply_stat_boost(tile_index: int, effect: Dictionary):
	spell_curse.curse_creature(tile_index, "stat_boost", -1, {
		"value": effect.get("value", 20)
	})

# バトル時変換
func apply_to_creature_data(tile_index: int):
	var curse = spell_curse.get_creature_curse(tile_index)
	var creature = creature_manager.get_data_ref(tile_index)
	
	match curse.get("curse_type"):
		"stat_boost":
			var value = curse["params"]["value"]
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "hp",
				"value": value
			})
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "ap",
				"value": value
			})
```

### BattlePreparation

```gdscript
func prepare_participants(...):
	# 呪いを変換
	spell_curse_stat.apply_to_creature_data(attacker_tile_index)
	spell_curse_stat.apply_to_creature_data(defender_tile_index)
	
	# 既存システムが適用
	apply_effect_arrays(attacker)
	apply_effect_arrays(defender)
```

---

## チェックリスト

- [ ] SpellCurseStat作成
- [ ] GameFlowManager初期化  
- [ ] SpellPhaseHandler統合
- [ ] BattlePreparation統合
- [ ] JSON設定
