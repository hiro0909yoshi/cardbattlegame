# スキル表示移行タスク

`battle_skill_processor.gd`内のハードコードされたスキル名を`SkillDisplayConfig`経由に移行する。

## 完了済み

- [x] ブルガサリ → stat_change（ステータス変化）
- [x] 刺突（penetration）
- [x] 強化（power_strike）
- [x] 先制（first_strike）
- [x] 後手（last_strike）
- [x] 再生（regeneration）※battle_special_effects.gd

## 「ステータス変化」に統一するもの

以下は全て `stat_change` を使用する。

| 現在のハードコード | 行番号 | 対応状況 |
|-------------------|--------|---------|
| 戦闘開始時効果 | 83-84 | [x] |
| レリック | 179 | [x] |
| リビングクローブ | 183 | [x] |
| オーガロード | 191 | [x] |
| ターン数ボーナス | 196 | [x] |
| 土地数効果 | 206 | [x] |
| 破壊数効果 | 211 | [x] |
| 手札数効果 | 217 | [x] |
| 常時補正 | 222 | [x] |
| 戦闘地効果 | 227 | [x] |
| {creature_name}の能力 | 232, 237 | [x] |

## 固有名を維持するもの

| スキル | 行番号 | effect_type | 対応状況 |
|--------|--------|-------------|---------|
| 共鳴 | 201 | resonance | [x] |
| ランダムステータス | 76-77 | random_stat | [x] |
| 鼓舞 | 100-101 | support | [x] |
| 術攻撃 | 157, 260 | scroll_attack | [x] |

## Phase 2: 攻撃成功時スキル

battle_execution.gd / battle_skill_processor.gdで処理されるもの。

| スキル | effect_type | 対応状況 |
|--------|-------------|---------|
| アイテム破壊 | destroy_item | [x] |
| アイテム盗み | steal_item | [x] |
| 蓄魔 | magic_gain | [x] |
| APドレイン | ap_drain | [x] |
| 変身 | transform | [ ] |
| 刻印付与 | apply_curse | [x] |

## Phase 3: 戦闘終了時スキル

| スキル | effect_type | 対応状況 |
|--------|-------------|---------|
| AP⇔MHP交換 | swap_ap_mhp | [x] |
| MHP減少 | reduce_enemy_mhp | [x] |
| 土地レベルアップ | level_up_battle_land | [x] |
| 帰還 | item_return | [ ] |
| 崩壊（呪い発動） | self_destruct | [x] |

## Phase 4: 死亡時スキル

| スキル | effect_type | 対応状況 |
|--------|-------------|---------|
| 形見（EP） | legacy_magic | [ ] |
| 形見（カード） | legacy_card | [ ] |
| 蘇生 | revive | [x] |
| 手札復活 | revive_to_hand | [x] |
| 相討 | death_revenge | [x] |
| 自滅 | self_destruct | [x] |
| 殲滅 | annihilate | [ ] |
| 報復 | revenge_mhp_damage | [x] |

## 実装手順

1. `skill_display_config.gd`にエントリを追加
2. 該当箇所で`SkillDisplayConfig.get_skill_name()`を呼び出し
3. テスト
4. このドキュメントのチェックボックスを更新

## 注意事項

- 「ステータス変化」に統一するものは、SkillDisplayConfigを使わず直接 `stat_change_name` を使う（変数を使い回す）
- 固有名を維持するものは個別にSkillDisplayConfigから取得
- 呪い関連は後回し（別タスク）
