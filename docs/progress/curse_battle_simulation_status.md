# 刻印バトルシミュレーション対応状況

**作成日**: 2026-02-27
**目的**: CPU AIバトルシミュレータでの刻印（curse）考慮状況を整理し、未対応項目を明確にする

---

## 対応状況サマリー

| # | 刻印名 | 表示名 | curse_type | シミュレーション | 実戦 | CPU AI | 状態 |
|---|--------|--------|------------|-----------------|------|--------|------|
| 4 | 戦闘後破壊 | 崩壊 | `destroy_after_battle` | **未対応** | OK | **未対応** | P1 |
| 6 | 地形効果無効 | 暗転 | `land_effect_disable` | OK | OK | OK | **完了** |
| 7 | 地形効果付与 | 恩寵 | `land_effect_grant` | OK | OK | OK | **完了** |
| 8 | 戦闘行動不可 | 消沈 | `battle_disable` | **未対応** | OK | **未対応** | P1 |
| 10 | 能力値-20 | 衰月 | `stat_reduce` | OK | OK | OK | **完了** |
| 11 | 能力値+20 | 暁光 | `stat_boost` | OK | OK | OK | **完了** |
| 15 | 金属化 | 硬化 | `metal_form` | 間接対応 | OK | OK | P2 |
| 17 | 衰弱 | 衰弱 | `plague` | **未対応** | OK | **未対応** | P1 |
| 18 | 能力値不定 | 狂星 | `random_stat` | OK(不安定) | OK | 不安定 | P2 |
| 19 | 戦闘能力不可 | 錯乱 | `skill_nullify` | OK | OK | OK | **完了** |

---

## 処理フロー概要

### シミュレーションのデータフロー

```
battle_simulator.gd::simulate_battle()
  ├─ _create_participants()
  │   ├─ BattleParticipant.new()          # 基礎ステータス設定
  │   ├─ apply_effect_arrays(attacker)     # 刻印→temporary_effects反映
  │   └─ apply_effect_arrays(defender)     # 刻印→temporary_effects反映
  ├─ apply_remaining_item_effects()        # アイテム効果適用
  ├─ apply_skills_for_simulation()         # スキル適用（沈黙チェック含む）
  │   ├─ 沈黙チェック（skill_nullify/ディスペルオーブ/ヴォイドスケルトン）
  │   ├─ SupportSkill.apply_to_all()       # 鼓舞
  │   ├─ apply_skills(attacker)            # 攻撃側スキル
  │   ├─ apply_skills(defender)            # 防御側スキル
  │   └─ PenetrationSkill.apply()          # 刺突
  ├─ check_nullify()                       # 無効化スキル判定
  ├─ _get_reflect_info()                   # 反射情報
  └─ _calculate_battle_result()            # 勝敗判定
```

### 刻印がシミュレーションに反映される経路

| 経路 | 対象刻印 | 仕組み |
|------|---------|--------|
| `apply_effect_arrays()` → `temporary_effects` | stat_reduce, stat_boost, random_stat | battle_curse_applier.gd で temporary_effects に変換 → AP/HP に加算 |
| `_calculate_land_bonus()` → `SpellCurseBattle.can_get_land_bonus()` | land_effect_disable, land_effect_grant | 土地ボーナス計算時に刻印チェック |
| `apply_skills_for_simulation()` 沈黙チェック | skill_nullify | `_has_skill_nullify_curse()` でチェック → 全スキルスキップ |
| `apply_effect_arrays()` → ability_parsed 更新 | metal_form | battle_curse_applier.gd で「無効化」をability_parsedに追加 |
| **未対応** | destroy_after_battle, battle_disable, plague | 実戦ではbattle_execution.gdで処理、シミュレーションでは未考慮 |

---

## 対応済み詳細

### land_effect_disable（暗転）/ land_effect_grant（恩寵）

- `SpellCurseBattle.can_get_land_bonus()` で統合判定
- 暗転: 土地ボーナスなし（属性一致でも0）
- 恩寵: `grant_elements` で指定属性（空なら全属性）で土地ボーナス取得可能
- `battle_simulator.gd::_calculate_land_bonus()` → `battle_preparation.gd::calculate_land_bonus()` で反映

### stat_reduce（衰月）/ stat_boost（暁光）

- `battle_curse_applier.gd` で `temporary_effects` に `stat_bonus` タイプで記録
- stat_reduce: AP/HP に負の値（デフォルト -20）
- stat_boost: AP/HP に正の値（デフォルト +20）
- `apply_effect_arrays()` で `temporary_bonus_hp/ap` に加算 → シミュレーションで自動反映

### metal_form（硬化）

- `battle_curse_applier.gd` で `ability_parsed.keywords` に「無効化」を追加
- `ability_parsed.effects` に `nullify` エフェクトを追加
- `BattleSpecialEffects.check_nullify()` で判定 → シミュレーションで間接的に反映
- 明示的チェックはないが、ability_parsed経由で機能する

### random_stat（狂星）

- `battle_curse_applier.gd` で `randi()` によりAP/HPをランダム化
- シミュレーション実行ごとに異なる値 → 結果が不安定
- CPU AIの判断が毎回変わる可能性あり（P2で改善検討）

### skill_nullify（錯乱）— 2026-02-27 対応

- `apply_skills_for_simulation()` に沈黙チェックを追加
- `_has_skill_nullify_curse()` + `_has_warlock_disk()` + `_has_nullify_creature_ability()` の3条件
- 該当時: `apply_nullify_enemy_abilities()` で双方の敵スキル無効化 → 全スキル処理スキップ

---

## 未対応詳細（P1）

### destroy_after_battle（崩壊）

**現状**: `battle_execution.gd` の `_check_destroy_after_battle()` で戦闘終了後に処理。シミュレータでは未考慮。

**問題シナリオ**:
- 防御側が崩壊刻印持ちで生き残った場合、シミュレータは「防御成功」と判定するが、実際は戦闘後に破壊される
- CPU防御AI: 崩壊刻印を持つクリーチャーの防御でアイテムを使っても結局破壊される → アイテム温存すべき

**必要な修正**:
- `battle_simulator.gd`: 結果判定後に崩壊チェック追加
- CPU防御AI: 崩壊刻印持ちクリーチャーの防御をスキップ（または低優先度化）

### battle_disable（消沈）

**現状**: `battle_execution.gd` で消沈チェック → 攻撃スキップ。シミュレータでは未考慮。

**問題シナリオ**:
- 敵が消沈状態でAP=50の場合、シミュレータは「敵AP50で攻撃」と計算するが、実際は攻撃できない
- CPU攻撃AI: 消沈状態の敵を「強い」と誤判定して攻撃を避ける
- CPU防御AI: 自分が消沈状態でも防御可能と判定してアイテムを無駄に使う

**必要な修正**:
- `battle_simulator.gd`: 消沈チェック → 消沈側のAPを0として計算
- CPU攻撃AI: 敵の消沈状態を考慮して侵略判断

### plague（衰弱）

**現状**: `battle_execution.gd` で戦闘終了後にMHP/2ダメージ。シミュレータでは未考慮。

**問題シナリオ**:
- 衰弱クリーチャー（MHP=100）が戦闘後HP=30で生き残り → 衰弱ダメージ50 → 実際はHP-20で破壊
- シミュレータは「生き残り=防御成功」と判定

**必要な修正**:
- `battle_simulator.gd`: `_calculate_battle_result()` 後に衰弱ダメージを適用して最終結果を再判定

---

## 未対応詳細（P2）

### metal_form（硬化）— 間接対応

- ability_parsed経由で無効化スキルとして機能するため、戦闘結果自体は正しい
- ただしCPU AIが「硬化刻印持ち → 無効化スキル持ち」を明示的に認識していない
- 改善: CPU AIで刻印チェック時に明示的にmetal_formを考慮

### random_stat（狂星）— 不安定

- シミュレーション実行ごとにrandi()で異なる値が生成される
- 同じ状況でCPU AIの判断が変わる可能性
- 改善案: 期待値（平均値）でシミュレーション、またはワーストケース（最低値）で固定

---

## 実装優先度

### P1（即座に対応）
1. **battle_disable（消沈）**: 戦闘結果への影響大、誤判定が頻発しうる
2. **plague（衰弱）**: 戦闘後破壊の見落としでアイテム浪費
3. **destroy_after_battle（崩壊）**: 防御判断の誤り

### P2（安定性向上）
4. **random_stat（狂星）**: ランダム性による判断不安定
5. **metal_form（硬化）**: 間接対応で機能するが明示性不足

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/cpu_ai/battle_simulator.gd` | CPUバトルシミュレータ本体 |
| `scripts/battle/battle_skill_processor.gd` | スキル適用（`apply_skills_for_simulation`含む） |
| `scripts/battle/battle_preparation.gd` | バトル準備（`apply_effect_arrays`含む） |
| `scripts/battle/battle_curse_applier.gd` | 刻印→BattleParticipant変換 |
| `scripts/battle/battle_execution.gd` | 実戦バトル処理（未対応刻印はここで処理） |
| `scripts/spells/spell_curse_battle.gd` | 刻印チェック・付与メソッド群 |
| `scripts/cpu_ai/cpu_battle_ai.gd` | CPU攻撃AI |
| `scripts/cpu_ai/cpu_defense_ai.gd` | CPU防御AI |
| `scripts/cpu_ai/cpu_battle_defense_evaluator.gd` | ワーストケース評価 |
