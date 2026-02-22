# CPU刻印判別システム

**作成日**: 2025年1月12日  
**実装ファイル**: `scripts/cpu_ai/cpu_curse_evaluator.gd`

---

## 概要

CPU AIが刻印スペル/アルカナアーツを使用する際に、刻印の有利/不利を判別して適切なターゲット選択や上書き判断を行うためのシステム。

---

## 背景

刻印は1つの対象に1つしか存在できない（上書き方式）。そのため、CPUが刻印スペルを使う際に：

- 自クリーチャーの有利な刻印を上書きしてしまう
- 敵クリーチャーの不利な刻印を上書きしてしまう

という問題が発生しうる。これを防ぐために刻印の有利/不利判別が必要。

---

## 分類基準

**「CPUにとって」の視点で判定**

| 状況 | 判定 |
|-----|------|
| 自クリーチャーに有利な刻印 | 望ましい → 上書きしない |
| 自クリーチャーに不利な刻印 | 望ましくない → 上書きOK |
| 敵クリーチャーに有利な刻印 | 望ましくない → 上書きOK |
| 敵クリーチャーに不利な刻印 | 望ましい → 上書きしない |

---

## 刻印分類一覧

### クリーチャー刻印

#### 有利 (所有者視点)
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `stat_boost` | 暁光 | AP&HP+20 |
| `mystic_grant` | アルカナアーツ付与 | アルカナアーツを付与 |
| `command_growth` | 昇華 | LvUP/地形変化でMHP+20 |
| `forced_stop` | 停滞 | 移動中のプレイヤーを拘束 |
| `indomitable` | 奮闘 | ダウン状態にならない |
| `land_effect_disable` | 暗転 | 地形効果を無効化 |
| `land_effect_grant` | 恩寵 | 指定属性の地形効果を付与 |
| `metal_form` | メタルフォーム | 巻物無効化 |
| `magic_barrier` | マジックバリア | スペル対象にならない |
| `toll_multiplier` | 通行料倍率 | 通行料×倍率 |
| `remote_move` | 天駆 | 離れた空地にも移動できる |
| `spell_protection` | 結界 | スペル・アルカナアーツの対象にならない |
| `protection_wall` | 重結界 | 結界と堅守を持つ |
| `hp_effect_immune` | 堅牢 | HP変動効果を無効化 |
| `blast_trap` | 焦土 | 敵停止時にEP40%減&HP-20 |

#### 不利 (所有者視点)
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `stat_reduce` | 衰月 | AP&HP-20 |
| `skill_nullify` | 錯乱 | スキル無効化 |
| `battle_disable` | 消沈 | 戦闘不可 |
| `ap_nullify` | AP=0 | APを0にする |
| `random_stat` | 狂星 | AP&HPランダム化 |
| `plague` | 衰弱 | 戦闘終了時HP -= MHP/2 |
| `bounty` | 賞金 | 武器破壊時に術者がG獲得 |
| `destroy_after_battle` | 崩壊 | 戦闘後に自滅 |
| `peace` | 安寧 | 休戦+通行料0 |
| `move_disable` | 枷 | 移動できない |
| `creature_toll_disable` | クリーチャー免罪 | そのクリーチャーの通行料が0 |

### プレイヤー刻印

#### 有利
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `dice_fixed` | ダイス固定 | ダイスを固定値にする |
| `dice_range` | ダイス範囲 | ダイスを範囲内にする |
| `protection` | 結界 | スペルの対象にならない |
| `life_force` | 天使 | クリーチャーとアイテム0EP、スペル無効化で刻印消滅 |
| `toll_share` | 通行料共有 | 他セプターの通行料の50%を得る |

#### 不利
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `dice_range_magic` | 範囲+EP | ダイス範囲+蓄魔（制限付き） |
| `toll_disable` | 免罪 | 通行料を取れない |
| `toll_fixed` | 通行料固定 | 通行料が固定値になる |
| `spell_disable` | 禁呪 | スペルを使用できない |
| `movement_reverse` | 反転 | 移動方向が逆になる |

### 世界呪

世界呪は全プレイヤーに影響するため、有利/不利の判別は行わない。

---

## API

### 主要関数

```gdscript
# クリーチャーの刻印が所有者にとって有利かどうか
# 戻り値: 1=有利, -1=不利, 0=刻印なし/不明
CpuCurseEvaluator.get_creature_curse_benefit(creature: Dictionary) -> int

# CPUにとって望ましい状態か（上書きすべきでないか）
CpuCurseEvaluator.is_curse_state_desirable_for_cpu(cpu_id: int, creature_owner_id: int, creature: Dictionary) -> bool

# 不利な刻印スペルのターゲットとして適切か
CpuCurseEvaluator.is_valid_harmful_curse_target(cpu_id: int, creature_owner_id: int, creature: Dictionary) -> bool

# 有利な刻印スペルのターゲットとして適切か
CpuCurseEvaluator.is_valid_beneficial_curse_target(cpu_id: int, creature_owner_id: int, creature: Dictionary) -> bool

# プレイヤー刻印の有利/不利判定
CpuCurseEvaluator.get_player_curse_benefit(player_curse: Dictionary) -> int

# 刻印解除スペル使用判断用
CpuCurseEvaluator.has_harmful_curse_on_own_creatures(cpu_id: int, creatures: Array) -> bool
CpuCurseEvaluator.has_harmful_curse_on_self(player_curse: Dictionary) -> bool
```

---

## 使用箇所

| ファイル | 用途 |
|---------|------|
| `cpu_target_resolver.gd` | 刻印スペルのターゲット選択時にフィルタ |
| `cpu_spell_condition_checker.gd` | 刻印解除スペルの使用判断 |
| `cpu_mystic_arts_ai.gd` | 刻印付与アルカナアーツの使用判断 |

---

## 関連ドキュメント

- [刻印効果](../spells/刻印効果.md) - 刻印システム全体の仕様
- [刻印効果の有利/不利分類](../spells/curse_benefit_classification.md) - 分類の詳細
