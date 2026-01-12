# CPU呪い判別システム

**作成日**: 2025年1月12日  
**実装ファイル**: `scripts/cpu_ai/cpu_curse_evaluator.gd`

---

## 概要

CPU AIが呪いスペル/秘術を使用する際に、呪いの有利/不利を判別して適切なターゲット選択や上書き判断を行うためのシステム。

---

## 背景

呪いは1つの対象に1つしか存在できない（上書き方式）。そのため、CPUが呪いスペルを使う際に：

- 自クリーチャーの有利な呪いを上書きしてしまう
- 敵クリーチャーの不利な呪いを上書きしてしまう

という問題が発生しうる。これを防ぐために呪いの有利/不利判別が必要。

---

## 分類基準

**「CPUにとって」の視点で判定**

| 状況 | 判定 |
|-----|------|
| 自クリーチャーに有利な呪い | 望ましい → 上書きしない |
| 自クリーチャーに不利な呪い | 望ましくない → 上書きOK |
| 敵クリーチャーに有利な呪い | 望ましくない → 上書きOK |
| 敵クリーチャーに不利な呪い | 望ましい → 上書きしない |

---

## 呪い分類一覧

### クリーチャー呪い

#### 有利 (所有者視点)
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `stat_boost` | 能力値+20 | AP&HP+20 |
| `mystic_grant` | 秘術付与 | 秘術を付与 |
| `command_growth` | コマンド成長 | LvUP/地形変化でMHP+20 |
| `forced_stop` | 強制停止 | 移動中のプレイヤーを足どめ |
| `indomitable` | 不屈 | ダウン状態にならない |
| `land_effect_disable` | 地形効果無効 | 地形効果を無効化 |
| `land_effect_grant` | 地形効果付与 | 指定属性の地形効果を付与 |
| `metal_form` | メタルフォーム | 巻物無効化 |
| `magic_barrier` | マジックバリア | スペル対象にならない |
| `toll_multiplier` | 通行料倍率 | 通行料×倍率 |
| `remote_move` | 遠隔移動 | 離れた空地にも移動できる |
| `spell_protection` | 防魔 | スペル・秘術の対象にならない |
| `protection_wall` | 防魔壁 | 防魔と防御型を持つ |
| `hp_effect_immune` | HP効果無効 | HP変動効果を無効化 |
| `blast_trap` | 爆発罠 | 敵停止時に魔力40%減&HP-20 |

#### 不利 (所有者視点)
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `stat_reduce` | 能力値-20 | AP&HP-20 |
| `skill_nullify` | 戦闘能力不可 | スキル無効化 |
| `battle_disable` | 戦闘行動不可 | 戦闘不可 |
| `ap_nullify` | AP=0 | APを0にする |
| `random_stat` | 能力値不定 | AP&HPランダム化 |
| `plague` | 衰弱 | 戦闘終了時HP -= MHP/2 |
| `bounty` | 賞金首 | 武器破壊時に術者がG獲得 |
| `destroy_after_battle` | 戦闘後破壊 | 戦闘後に自壊 |
| `peace` | 平和 | 侵略不可+通行料0 |
| `move_disable` | 移動不可 | 移動できない |
| `creature_toll_disable` | クリーチャー通行料無効 | そのクリーチャーの通行料が0 |

### プレイヤー呪い

#### 有利
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `dice_fixed` | ダイス固定 | ダイスを固定値にする |
| `dice_range` | ダイス範囲 | ダイスを範囲内にする |
| `protection` | 防魔 | スペルの対象にならない |
| `life_force` | 生命力 | クリーチャーとアイテムG0、スペル無効化で呪い消滅 |
| `toll_share` | 通行料共有 | 他セプターの通行料の50%を得る |

#### 不利
| curse_type | 名前 | 効果 |
|-----------|------|------|
| `dice_range_magic` | 範囲+魔力 | ダイス範囲+魔力獲得（制限付き） |
| `toll_disable` | 通行料無効 | 通行料を取れない |
| `toll_fixed` | 通行料固定 | 通行料が固定値になる |
| `spell_disable` | スペル不可 | スペルを使用できない |
| `movement_reverse` | 歩行逆転 | 移動方向が逆になる |

### 世界呪

世界呪は全プレイヤーに影響するため、有利/不利の判別は行わない。

---

## API

### 主要関数

```gdscript
# クリーチャーの呪いが所有者にとって有利かどうか
# 戻り値: 1=有利, -1=不利, 0=呪いなし/不明
CpuCurseEvaluator.get_creature_curse_benefit(creature: Dictionary) -> int

# CPUにとって望ましい状態か（上書きすべきでないか）
CpuCurseEvaluator.is_curse_state_desirable_for_cpu(cpu_id: int, creature_owner_id: int, creature: Dictionary) -> bool

# 不利な呪いスペルのターゲットとして適切か
CpuCurseEvaluator.is_valid_harmful_curse_target(cpu_id: int, creature_owner_id: int, creature: Dictionary) -> bool

# 有利な呪いスペルのターゲットとして適切か
CpuCurseEvaluator.is_valid_beneficial_curse_target(cpu_id: int, creature_owner_id: int, creature: Dictionary) -> bool

# プレイヤー呪いの有利/不利判定
CpuCurseEvaluator.get_player_curse_benefit(player_curse: Dictionary) -> int

# 呪い解除スペル使用判断用
CpuCurseEvaluator.has_harmful_curse_on_own_creatures(cpu_id: int, creatures: Array) -> bool
CpuCurseEvaluator.has_harmful_curse_on_self(player_curse: Dictionary) -> bool
```

---

## 使用箇所

| ファイル | 用途 |
|---------|------|
| `cpu_target_resolver.gd` | 呪いスペルのターゲット選択時にフィルタ |
| `cpu_spell_condition_checker.gd` | 呪い解除スペルの使用判断 |
| `cpu_mystic_arts_ai.gd` | 呪い付与秘術の使用判断 |

---

## 関連ドキュメント

- [呪い効果](../spells/呪い効果.md) - 呪いシステム全体の仕様
- [呪い効果の有利/不利分類](../spells/curse_benefit_classification.md) - 分類の詳細
