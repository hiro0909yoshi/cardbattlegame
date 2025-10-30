# MHP計算が実際に必要な箇所の正確なリスト

**作成日**: 2025年10月30日  
**目的**: MHP計算（`hp + base_up_hp`）が本当に必要な箇所だけを特定  

---

## 📋 MHP計算が実際に行われている箇所（32箇所）

### 1. 全クリーチャー共通処理（必須）

#### 1.1 バトル準備時のMHP計算（4箇所）

**ファイル**: `battle_preparation.gd`

| 行 | コード | 目的 | 影響 |
|----|--------|------|------|
| 42 | `attacker_max_hp = attacker_base_hp + attacker.base_up_hp` | 侵略側のMHP計算 | **全クリーチャー** |
| 78 | `defender_max_hp = defender_base_hp + defender.base_up_hp` | 防御側のMHP計算 | **全クリーチャー** |
| 46 | `attacker.base_hp = attacker_current_hp - attacker.base_up_hp` | 侵略側のbase_hp逆算 | **全クリーチャー** |
| 83 | `defender.base_hp = defender_current_hp - defender.base_up_hp` | 防御側のbase_hp逆算 | **全クリーチャー** |

**必要性**: 🔥🔥🔥 **絶対必須** - 全バトルに影響

---

#### 1.2 バトル後のHP保存（1箇所）

**ファイル**: `battle_special_effects.gd`

| 行 | コード | 目的 | 影響 |
|----|--------|------|------|
| 270 | `creature_data["current_hp"] = defender.base_hp + defender.base_up_hp` | バトル後の残りHP保存 | **全クリーチャー** |

**必要性**: 🔥🔥🔥 **絶対必須** - 全バトルに影響

---

#### 1.3 HP回復処理（2箇所）

**ファイル**: `movement_controller.gd`

| 行 | コード | 目的 | 影響 |
|----|--------|------|------|
| 300 | `max_hp = base_hp + base_up_hp` | スタート通過時のHP回復上限 | **全クリーチャー** |
| 413 | `max_hp = base_hp + base_up_hp` | ダイスバフ時のHP回復上限 | ダイス条件持ち |

**必要性**: 🔥🔥🔥 **絶対必須** - HP回復全般に影響

---

#### 1.4 BattleParticipantのcurrent_hp計算（1箇所）

**ファイル**: `battle_participant.gd`

| 行 | コード | 目的 | 影響 |
|----|--------|------|------|
| 82 | `current_hp = base_hp + base_up_hp + temporary_bonus_hp + ...` | 表示用HP計算 | **全クリーチャー** |

**必要性**: 🔥🔥🔥 **絶対必須** - HP表示全般に影響

---

### 2. 特定クリーチャー専用処理（8箇所）

#### 2.1 ブラッドプリン（ID: 137）専用（2箇所）

**ファイル**: `battle_preparation.gd`

| 行 | コード | 目的 |
|----|--------|------|
| 239 | `assist_mhp = assist_base_hp + assist_base_up_hp` | 援護クリーチャーのMHP取得 |
| 244 | `current_mhp = blood_purin_base_hp + blood_purin_base_up_hp` | ブラッドプリンの現在MHP |

**処理内容**:
```gdscript
# 援護クリーチャーのMHPを吸収
var assist_mhp = assist_base_hp + assist_base_up_hp
var current_mhp = blood_purin_base_hp + blood_purin_base_up_hp

# MHP上限100チェック
var max_increase = 100 - current_mhp
var actual_increase = min(assist_mhp, max_increase)

if actual_increase > 0:
	participant.creature_data["base_up_hp"] = blood_purin_base_up_hp + actual_increase
```

**必要性**: 🔥🔥🔥 **絶対必須** - ブラッドプリンのスキルに必須

---

#### 2.2 ジェネラルカン（ID: 15）専用（2箇所）

**ファイル**: `battle_skill_processor.gd`

| 行 | コード | 目的 |
|----|--------|------|
| 1087 | `creature_mhp = creature_hp + creature_base_up_hp` | 配置クリーチャーのMHP計算 |
| 1093 | `if creature_mhp >= threshold:` | MHP50以上カウント |

**処理内容**:
```gdscript
# ジェネラルカン: ST+MHP50以上配置数×5
for tile in player_tiles:
	var creature_mhp = creature_hp + creature_base_up_hp
	if creature_mhp >= threshold:  # 50
		qualified_count += 1

var bonus = qualified_count * multiplier
```

**必要性**: 🔥🔥🔥 **絶対必須** - ジェネラルカンのスキルに必須

---

#### 2.3 スペクター（ID: 321）専用（2箇所）

**ファイル**: `battle_preparation.gd`, `battle_skill_processor.gd`

| 行 | コード | 目的 |
|----|--------|------|
| 566 | `participant.temporary_bonus_hp = random_hp - (base_hp_value + base_up_hp)` | ランダムHP設定 |
| 1318 | `participant.temporary_bonus_hp = random_hp - (base_hp + base_up_hp)` | ランダムHP設定 |

**処理内容**:
```gdscript
# スペクター: HP=ランダム10~70
var random_hp = randi() % 61 + 10  # 10-70
participant.temporary_bonus_hp = random_hp - (base_hp + base_up_hp)
```

**必要性**: 🔥🔥 **必要** - スペクターのスキルに必須

---

#### 2.4 周回ボーナス処理（2箇所）

**ファイル**: `game_flow_manager.gd`

| 行 | コード | 目的 | 影響クリーチャー |
|----|--------|------|----------------|
| 665 | `reset_max_hp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)` | 周回ボーナスのMHPリセット判定 | モスタイタン |
| 688 | `max_hp = base_hp + base_up_hp` | 周回ボーナス後のHP回復上限 | モスタイタン |

**処理内容**:
```gdscript
# モスタイタン: 周回ごとにMHP+10
# リセット閾値チェック（MHP≥80で60にリセット）
var reset_max_hp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
if operator == ">=" and (reset_max_hp + value) >= threshold:
	creature_data["base_up_hp"] = reset_to - reset_base_hp

# HP回復（増えたMHP分）
var max_hp = base_hp + base_up_hp
var new_hp = min(current_hp + value, max_hp)
```

**必要性**: 🔥🔥 **必要** - モスタイタン（ID: 41）に必須

---

### 3. 条件判定処理（8箇所）

#### 3.1 MHP条件チェック（強打用）（4箇所）

**ファイル**: `condition_checker.gd`

| 行 | コード | 目的 | 影響 |
|----|--------|------|------|
| 59 | `target_mhp = context.get("creature_mhp", 100)` | MHP以下条件 | 強打条件持ちクリーチャー |
| 60 | `return target_mhp <= cond_value` | MHP以下判定 | フロギストン等 |
| 63 | `target_mhp = context.get("creature_mhp", 0)` | MHP以上条件 | 強打条件持ちクリーチャー |
| 64 | `return target_mhp >= cond_value` | MHP以上判定 | ウォーリアー系等 |

**使用クリーチャー**:
- **フロギストン (ID: 42)**: MHP40以下で強打
- **ウォーリアー系**: MHP50以上で強打

**問題**: `context.get("creature_mhp")`が正しく設定されているか要確認

**必要性**: 🔥🔥 **必要** - 強打条件に必須

---

#### 3.2 敵MHP条件チェック（4箇所）

**ファイル**: `condition_checker.gd`

| 行 | コード | 目的 | 影響 |
|----|--------|------|------|
| 191 | `enemy_mhp = context.get("enemy_mhp", 0)` | 敵MHP取得 | 敵MHP条件持ち |
| 195 | `"<=": return enemy_mhp <= value` | 敵MHP以下判定 | 強打条件 |
| 196 | `">=": return enemy_mhp >= value` | 敵MHP以上判定 | 強打条件 |
| 199 | `"==": return enemy_mhp == value` | 敵MHP一致判定 | 強打条件 |

**使用クリーチャー**: 敵MHP条件を持つ強打クリーチャー

**問題**: `context.get("enemy_mhp")`が正しく設定されているか要確認

**必要性**: 🔥🔥 **必要** - 敵MHP条件に必須

---

### 4. 🐛 バグ発見！無効化判定（2箇所）

#### 4.1 MHP無効化判定のバグ

**ファイル**: `battle_special_effects.gd`

| 行 | コード | 問題 |
|----|--------|------|
| 103 | `attacker_max_hp = attacker.creature_data.get("hp", 0)` | ❌ **base_up_hpを足していない** |
| 109 | `attacker_max_hp = attacker.creature_data.get("hp", 0)` | ❌ **base_up_hpを足していない** |

**現在のコード（バグあり）**:
```gdscript
## MHP以上無効化判定
func _check_nullify_mhp_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	var attacker_max_hp = attacker.creature_data.get("hp", 0)  # ❌ これは元のHPだけ
	return attacker_max_hp >= threshold

## MHP以下無効化判定
func _check_nullify_mhp_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	var attacker_max_hp = attacker.creature_data.get("hp", 0)  # ❌ これは元のHPだけ
	return attacker_max_hp <= threshold
```

**正しいコード**:
```gdscript
## MHP以上無効化判定
func _check_nullify_mhp_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	var attacker_max_hp = attacker.creature_data.get("hp", 0) + attacker.creature_data.get("base_up_hp", 0)
	return attacker_max_hp >= threshold

## MHP以下無効化判定
func _check_nullify_mhp_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	var attacker_max_hp = attacker.creature_data.get("hp", 0) + attacker.creature_data.get("base_up_hp", 0)
	return attacker_max_hp <= threshold
```

**影響**: MHP条件で無効化を持つクリーチャー（現在未実装？）

**必要性**: 🔥🔥🔥 **バグ修正必須**

---

### 5. その他のMHP関連（6箇所）

#### 5.1 スキル効果計算（2箇所）

**ファイル**: `battle_skill_processor.gd`

| 行 | コード | 目的 |
|----|--------|------|
| 292 | `participant.current_hp = participant.base_hp + participant.base_up_hp` | ローンビーストのHP計算 |
| 293 | `participant.temporary_bonus_hp = bonus - (participant.base_hp + participant.base_up_hp)` | ローンビーストのボーナス計算 |

**処理内容**: ローンビースト（ID: 49）「HP+基礎ST」

**必要性**: 🔥 **必要** - ローンビーストに必須

---

#### 5.2 skill_effect_base.gd（2箇所）

**ファイル**: `skills/skill_effect_base.gd`

| 行 | コード | 目的 |
|----|--------|------|
| 169 | `return context.get("mhp", 100) <= cond_value` | MHP以下判定 |
| 171 | `return context.get("mhp", 0) >= cond_value` | MHP以上判定 |

**使用箇所**: スキル効果システム（旧式？）

**必要性**: 🔥 **確認必要** - 使用されているか不明

---

#### 5.3 effect_combat.gd（2箇所）

**ファイル**: `skills/effect_combat.gd`

| 行 | コード | 目的 |
|----|--------|------|
| 128 | `max_hp = creature.get("mhp", 0)` | 再生処理のMHP取得 |
| 227-229 | MHP条件テキスト生成 | ログ表示用 |

**使用箇所**: 再生スキル、ログ表示

**必要性**: 🔥 **確認必要** - 再生スキルで使用

---

## 📊 まとめ

### MHP計算が必要な箇所（優先度別）

#### 🔥🔥🔥 最優先（絶対必須）8箇所

1. バトル準備時のMHP計算（4箇所）- **全クリーチャー**
2. バトル後のHP保存（1箇所）- **全クリーチャー**
3. HP回復処理（2箇所）- **全クリーチャー**
4. BattleParticipantのcurrent_hp（1箇所）- **全クリーチャー**

#### 🔥🔥 高優先（特定クリーチャー必須）8箇所

5. ブラッドプリン専用（2箇所）- **ID: 137**
6. ジェネラルカン専用（2箇所）- **ID: 15**
7. 周回ボーナス（2箇所）- **ID: 41 モスタイタン**
8. 🐛 バグ修正：無効化判定（2箇所）- **MHP条件無効化持ち**

#### 🔥 中優先（スキル条件）12箇所

9. スペクター専用（2箇所）- **ID: 321**
10. MHP条件チェック（4箇所）- **強打条件持ち**
11. 敵MHP条件チェック（4箇所）- **敵MHP条件持ち**
12. ローンビースト（2箇所）- **ID: 49**

#### 🤔 確認必要 4箇所

13. skill_effect_base.gd（2箇所）- **使用状況不明**
14. effect_combat.gd（2箇所）- **再生スキル等**

---

## 🎯 MHPが本当に必要なクリーチャー

### 特殊処理が必要（4体）

| ID | 名前 | 理由 |
|----|------|------|
| **137** | ブラッドプリン | 援護MHP吸収 |
| **15** | ジェネラルカン | MHP50以上カウント |
| **41** | モスタイタン | 周回ボーナスMHP+10 |
| **321** | スペクター | ランダムMHP設定 |

### MHP条件判定が必要（推定5-10体）

| ID | 名前 | 条件 |
|----|------|------|
| **42** | フロギストン | MHP40以下で強打 |
| **49** | ローンビースト | HP+基礎ST |
| - | ウォーリアー系 | MHP50以上で強打 |
| - | 無効化持ち | MHP条件で無効化 |

### 全クリーチャー共通（38体全て）

- バトル準備時のMHP計算
- バトル後のHP保存
- HP回復処理

---

## ✅ 結論

### MHP統一化の真の影響範囲

1. **絶対必須の修正**: 8箇所（全クリーチャー共通処理）
2. **特定クリーチャー必須**: 8箇所（4-5体のクリーチャー）
3. **条件判定必須**: 12箇所（5-10体のクリーチャー）
4. **🐛 バグ修正**: 2箇所（無効化判定）

**合計**: 約30箇所（前回の97箇所から大幅削減）

**影響クリーチャー**:
- 特殊処理: 4体
- 条件判定: 5-10体
- 全体影響: 38体全て（バトル準備・HP保存・HP回復）

---

**最終更新**: 2025年10月30日
