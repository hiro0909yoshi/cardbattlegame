# 刻印バトルシミュレーション対応状況

**作成日**: 2026-02-27
**最終更新**: 2026-02-27（P1 3件対応完了）
**目的**: CPU AIバトルシミュレータでの刻印（curse）考慮状況を整理し、未対応項目を明確にする

---

## 対応状況サマリー

| # | 刻印名 | 表示名 | curse_type | シミュレーション | 実戦 | CPU AI | 状態 |
|---|--------|--------|------------|-----------------|------|--------|------|
| 2 | EP結界 | 祭壇 | `magic_barrier` | 間接対応 | OK | OK | **完了** (EP移動は未考慮) |
| 4 | 戦闘後破壊 | 崩壊 | `destroy_after_battle` | OK | OK | OK | **完了** |
| 6 | 地形効果無効 | 暗転 | `land_effect_disable` | OK | OK | OK | **完了** |
| 7 | 地形効果付与 | 恩寵 | `land_effect_grant` | OK | OK | OK | **完了** |
| 8 | 戦闘行動不可 | 消沈 | `battle_disable` | OK | OK | OK | **完了** |
| 10 | 能力値-20 | 衰月 | `stat_reduce` | OK | OK | OK | **完了** |
| 11 | 能力値+20 | 暁光 | `stat_boost` | OK | OK | OK | **完了** |
| 15 | 金属化 | 硬化 | `metal_form` | 間接対応 | OK | OK | **完了** |
| 17 | 衰弱 | 衰弱 | `plague` | OK | OK | OK | **完了** |
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
  ├─ 消沈チェック → AP=0化               # ★ 2026-02-27追加
  ├─ check_nullify()                       # 無効化スキル判定
  ├─ _get_reflect_info()                   # 反射情報
  ├─ _calculate_battle_result()            # 勝敗判定
  ├─ _apply_attacker_death_effects()       # 死亡時効果
  └─ _apply_post_battle_curse_effects()    # ★ 崩壊・衰弱の戦闘後効果
```

### 刻印がシミュレーションに反映される経路

| 経路 | 対象刻印 | 仕組み |
|------|---------|--------|
| `apply_effect_arrays()` → `temporary_effects` | stat_reduce, stat_boost, random_stat | battle_curse_applier.gd で temporary_effects に変換 → AP/HP に加算 |
| `_calculate_land_bonus()` → `SpellCurseBattle.can_get_land_bonus()` | land_effect_disable, land_effect_grant | 土地ボーナス計算時に刻印チェック |
| `apply_skills_for_simulation()` 沈黙チェック | skill_nullify | `_has_skill_nullify_curse()` でチェック → 全スキルスキップ |
| `apply_effect_arrays()` → ability_parsed 更新 | metal_form | battle_curse_applier.gd で「無効化」をability_parsedに追加 |
| ステップ5.5: AP=0化 | battle_disable | `SpellCurseBattle.has_battle_disable()` → 消沈側のAPを0に |
| ステップ11: `_apply_post_battle_curse_effects()` | destroy_after_battle, plague | 生存者の崩壊→破壊、衰弱→MHP/2ダメージで結果再判定 |

---

## 対応済み詳細

### battle_disable（消沈）— 2026-02-27 対応

- `simulate_battle()` ステップ5.5 で `SpellCurseBattle.has_battle_disable()` チェック
- 消沈側の最終APを0に設定 → `_calculate_battle_result()` に0で渡される
- 攻撃側が消沈 → 攻撃ダメージ0、防御側が消沈 → 反撃ダメージ0
- CPU攻撃AI: 消沈状態の敵を正しく「攻撃力なし」と評価 → 侵略しやすくなる
- CPU防御AI: 自分が消沈状態のシミュレーション結果が正確になる

### destroy_after_battle（崩壊）— 2026-02-27 対応

- `_apply_post_battle_curse_effects()` で戦闘結果判定後にチェック
- 生存者が崩壊刻印持ち → 破壊扱いで結果を再判定
- 結果変換:
  - DEFENDER_WIN + 防御側崩壊 → BOTH_DEFEATED
  - ATTACKER_SURVIVED + 防御側崩壊 → ATTACKER_WIN
  - ATTACKER_WIN + 攻撃側崩壊 → BOTH_DEFEATED（移動侵略時）
- CPU攻撃AI: 崩壊持ちの敵に対して「生き残ればよい」と正しく判断 → 防具優先
- CPU防御AI: シミュレーション結果が常に敗北 → アイテムを自然に温存

### plague（衰弱）— 2026-02-27 対応

- `_apply_post_battle_curse_effects()` で崩壊チェックの後に処理
- 生存者が衰弱刻印持ち → MHP/2ダメージを計算し、残HP≤0なら破壊扱い
- MHP計算: 攻撃側=`base_hp + base_up_hp`、防御側=`base_hp + base_up_hp + land_bonus_hp`
- CPU AI: 衰弱持ちクリーチャーが戦闘後に死ぬケースを正確にシミュレーション

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

## 未対応詳細（P2）

### random_stat（狂星）— 不安定

- シミュレーション実行ごとにrandi()で異なる値が生成される
- 同じ状況でCPU AIの判断が変わる可能性
- 改善案: 期待値（平均値）でシミュレーション、またはワーストケース（最低値）で固定

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/cpu_ai/battle_simulator.gd` | CPUバトルシミュレータ本体 |
| `scripts/battle/battle_skill_processor.gd` | スキル適用（`apply_skills_for_simulation`含む） |
| `scripts/battle/battle_preparation.gd` | バトル準備（`apply_effect_arrays`含む） |
| `scripts/battle/battle_curse_applier.gd` | 刻印→BattleParticipant変換 |
| `scripts/battle/battle_execution.gd` | 実戦バトル処理 |
| `scripts/spells/spell_curse_battle.gd` | 刻印チェック・付与メソッド群 |
| `scripts/cpu_ai/cpu_battle_ai.gd` | CPU攻撃AI |
| `scripts/cpu_ai/cpu_defense_ai.gd` | CPU防御AI |
| `scripts/cpu_ai/cpu_battle_defense_evaluator.gd` | ワーストケース評価 |
