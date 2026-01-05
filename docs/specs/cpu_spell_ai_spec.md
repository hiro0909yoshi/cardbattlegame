# CPU スペル/ミスティックアーツ AI 仕様書

**作成日**: 2025-12-31
**ステータス**: 設計中

---

## 概要

CPUがスペルフェーズでスペルカードまたはミスティックアーツを使用するかを判断し、適切なターゲットを選択するシステム。

### 基本制約

- **排他的使用**: 1ターンにスペルカードまたはミスティックアーツのどちらか1つのみ使用可能
- **UI使用**: 既存のターゲット選択UIを使用（プレイヤーと同じ見た目）
- **コスト**: 魔力を消費

---

## ファイル構成

### CPU AIコアファイル（scripts/cpu_ai/）

| ファイル | 役割 | 行数 |
|---------|------|------|
| `cpu_spell_ai.gd` | スペル使用判断、評価パターン分岐 | 505 |
| `cpu_spell_target_selector.gd` | 最適ターゲット選択ロジック | 663 |
| `cpu_spell_utils.gd` | 距離計算、利益計算、コンテキスト構築 | 444 |
| `cpu_spell_condition_checker.gd` | スペル使用条件判定 | 500 |
| `cpu_target_resolver.gd` | ターゲット条件解決、候補リスト取得 | 702 |
| `cpu_board_analyzer.gd` | 盤面分析ヘルパー（土地/クリーチャー情報取得） | 402 |
| `cpu_mystic_arts_ai.gd` | ミスティックアーツ使用判断 | 533 |

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/game_flow/spell_phase_handler.gd` | スペルフェーズ制御、CPU判断呼び出し |

### ファイル責務

**cpu_spell_ai.gd**
- `decide_spell()` - スペル使用可否とターゲット決定
- `_evaluate_spell()` - 各スペルのスコア評価
- パターン別評価（immediate/has_target/condition/profit_calc/strategic）

**cpu_spell_target_selector.gd**
- `_get_best_exchange_target()` - クリーチャー交換ターゲット選択
- `_get_best_move_invasion_target()` - 移動侵略ターゲット選択
- `_get_best_element_shift_target()` - 属性変更ターゲット選択
- `_select_best_target()` - 汎用ターゲット選択

**cpu_spell_utils.gd**
- `_calculate_tile_distance()` - タイル間距離計算
- `_calculate_profit()` - 魔力損益計算
- `_build_context()` - AI判断用コンテキスト構築
- ゲート/チェックポイント関連ユーティリティ

**cpu_spell_condition_checker.gd**
- `check_condition()` - スペル使用条件（condition）判定
- 各種条件チェック関数（element_mismatch, enemy_high_level等）

**cpu_target_resolver.gd**
- `check_target_condition()` - ターゲット条件（target_condition）解決
- ターゲット候補リスト取得（enemy_creature, own_creature等）

**cpu_board_analyzer.gd**
- `_get_own_creatures()` - 自クリーチャー一覧取得
- `_get_enemy_lands_by_level()` - 敵土地取得（レベル指定）
- `_get_mismatched_own_lands()` - 属性不一致土地取得
- その他盤面分析ヘルパー

**cpu_mystic_arts_ai.gd**
- `decide_mystic_art()` - 秘術使用判断
- `_evaluate_mystic_art()` - 秘術スコア評価
- クリーチャー固有秘術の評価

### クラス責務（概要）

| クラス | 責務 |
|--------|------|
| `CPUSpellAI` | 手札のスペルカードを評価し、使用すべきか判断 |
| `CPUSpellTargetSelector` | 各スペルタイプに応じた最適ターゲット選択 |
| `CPUSpellUtils` | 距離・利益計算等の共通ユーティリティ |
| `CPUSpellConditionChecker` | スペル使用条件（condition）の判定 |
| `CPUTargetResolver` | ターゲット条件の解決と候補リスト取得 |
| `CPUBoardAnalyzer` | 盤面状況の分析と情報取得 |
| `CPUMysticArtsAI` | 配置済みクリーチャーの秘術を評価し、使用すべきか判断 |

---

## 判断フロー

```
スペルフェーズ開始
	│
	├─ 1. スペル使用可能かチェック
	│      └─ 手札にスペルがあるか、コスト支払えるか
	│
	├─ 2. ミスティックアーツ使用可能かチェック
	│      └─ 配置クリーチャーが秘術を持っているか、コスト支払えるか
	│
	├─ 3. 両方使用可能な場合の選択
	│      ├─ 手札が逼迫（6枚以上）→ スペル優先
	│      ├─ 魔力が少ない → コストが低い方を優先
	│      └─ 効果の有用性で判断
	│
	├─ 4. 使用するスペル/秘術の選択
	│      └─ 効果カテゴリ別に優先度評価
	│
	├─ 5. ターゲット選択
	│      └─ 既存UIを使用、CPU自動選択
	│
	└─ 6. 実行または見送り
```

---

## 効果タイプ一覧（effect_type）

### ダメージ/回復系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `damage` | HP減少 | 敵を倒せるか |
| `heal` | HP回復 | 味方がダメージを受けているか |
| `full_heal` | HP全回復 | 味方がダメージを受けているか |

### ドロー系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `draw` / `draw_cards` | カードを引く | 手札が少ない |
| `draw_by_rank` | 順位に応じて引く | 手札が少ない |
| `draw_by_type` | タイプ指定で引く | 欲しいタイプがある |
| `draw_until` | 指定枚数まで引く | 手札が少ない |
| `draw_from_deck_selection` | デッキから選んで引く | 特定カードが欲しい |
| `draw_and_place` | 引いて配置 | 空地がある |
| `check_hand_elements` | 手札属性チェック | 条件達成可能か |
| `check_hand_synthesis` | 合成チェック | 条件達成可能か |
| `discard_and_draw_plus` | 捨てて引く | 手札刷新したい |

### 魔力系
| effect_type | 説明 | 損益分岐点 |
|-------------|------|-----------|
| `gain_magic` | 魔力獲得（固定値） | コスト < 獲得量 |
| `gain_magic_by_rank` | 順位×倍率 | コスト < 順位×倍率 |
| `gain_magic_by_lap` | 周回数×倍率 | コスト < 周回数×倍率 |
| `gain_magic_from_destroyed_count` | 破壊数×倍率 | コスト < 破壊数×倍率 |
| `gain_magic_from_spell_cost` | 敵スペルコスト参照 | 敵がスペル多数所持 |
| `gain_magic_from_land_chain` | 連鎖ボーナス | 連鎖達成可能 |
| `drain_magic` | 魔力奪取（%） | コスト < 敵魔力×% |
| `drain_magic_by_lap_diff` | 周回差×倍率 | コスト < 差×倍率 |
| `drain_magic_by_land_count` | 敵領地数×倍率 | コスト < 領地×倍率 |
| `balance_all_magic` | 魔力平均化 | 自分が最下位魔力 |

### 土地操作系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `change_element` | 属性変更 | 連鎖強化可能 |
| `change_element_to_dominant` | 最多属性に変更 | 連鎖強化可能 |
| `change_element_bidirectional` | 双方向変更 | 有利な変更可能 |
| `change_level` | レベル増減 | 敵レベル下げ/自レベル上げ |
| `set_level` | レベル固定 | 敵高レベル土地ある |
| `conditional_level_change` | 条件付きレベル変更 | 条件達成可能 |
| `abandon_land` | 土地放棄 | 価値の70%回収が有利 |

### クリーチャー操作系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `move_to_adjacent_enemy` | 隣接敵地へ移動 | 敵クリーチャーを倒せる |
| `move_steps` | マス移動 | 有利な位置へ移動可能 |
| `place_creature` | クリーチャー配置 | 空地がある |
| `swap_with_hand` | 手札と交換 | 強いカードが手札にある |
| `swap_board_creatures` | 盤面交換 | 有利な配置になる |
| `return_to_hand` | 手札に戻す | 敵を弱体化 |

### プレイヤー移動系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `warp_to_nearest_vacant` | 最寄り空地へ | 危険回避 |
| `warp_to_nearest_gate` | 最寄りゲートへ | 周回促進 |
| `warp_to_target` | 指定地へ | 目的地がある |
| `gate_pass` | ゲート通過扱い | 周回促進 |

### ダイス操作系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `dice_fixed` | ダイス固定 | 特定マスに止まりたい |
| `dice_range` | ダイス範囲指定 | 範囲内に目的地 |
| `dice_range_magic` | 範囲+魔力獲得 | 複合メリット |
| `dice_multi` | ダイス複数回 | 長距離移動したい |

### クリーチャー呪い系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `creature_curse` | 汎用呪い | 敵弱体化/自強化 |
| `battle_disable` | 戦闘行動不可 | 敵の強クリーチャー |
| `skill_nullify` | 能力無効 | 敵の能力が厄介 |
| `stat_boost` | 能力+20 | 自クリーチャー強化 |
| `stat_reduce` | 能力-20 | 敵クリーチャー弱体化 |
| `ap_nullify` | AP=0 | 敵の攻撃無力化 |
| `indomitable` | 不屈付与 | 重要クリーチャー保護 |
| `peace` | 平和（侵略不可/通行料0） | 防御重視 |
| `toll_multiplier` | 通行料倍率 | 高レベル土地 |
| `land_effect_disable` | 地形効果無効 | 敵の地形ボーナス潰し |
| `plague_curse` | 衰弱 | 敵全体弱体化 |
| `bounty_curse` | 賞金首 | 敵を倒すインセンティブ |

### プレイヤー呪い系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `player_curse` | 汎用呪い | 敵妨害 |
| `curse_movement_reverse` | 歩行逆転 | 敵妨害 |
| `toll_disable` | 通行料無効 | 敵収入妨害 |
| `toll_fixed` | 通行料固定 | 敵高額通行料抑制 |
| `toll_share` | 通行料促進 | 自収入増加 |
| `life_force_curse` | 生命力 | コスト0化 |

### 世界呪い系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `world_curse` | 世界全体効果 | 自分に有利な状況 |

### 手札操作系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `destroy_selected_card` | カード破壊 | 敵の厄介カード除去 |
| `destroy_duplicate_cards` | 重複破壊 | 敵が重複カード所持 |
| `steal_item_conditional` | アイテム奪取 | 敵がアイテム2枚以上 |
| `steal_selected_card` | カード奪取 | 欲しいカードがある |

### 変身系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `transform` | 変身 | 有利な変身先 |
| `discord_transform` | 最多種をゴブリン化 | 敵の最多種を潰す |

### 秘術付与系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `grant_mystic_arts` | 秘術付与 | 有用な秘術 |
| `use_target_mystic_art` | 対象の秘術使用 | 敵の秘術が有用 |

### ステータス変更系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `permanent_hp_change` | MHP永続変更 | 自強化/敵弱体化 |
| `permanent_ap_change` | AP永続変更 | 自強化/敵弱体化 |

### 特殊系
| effect_type | 説明 | 判断基準 |
|-------------|------|----------|
| `clear_down` / `down_clear` | ダウン解除 | 味方がダウン中 |
| `set_down` | ダウン付与 | 敵を行動不能に |
| `purify_all` | 全呪い解除 | 呪いが多い |
| `reset_deck` | デッキ初期化 | デッキが枯渇 |

---

## 効果カテゴリと優先度

### Phase 1: 基本実装（即時効果）

| 優先度 | カテゴリ | 判断基準 |
|--------|----------|----------|
| 1 | **ダメージ系** | 敵クリーチャーを倒せる |
| 2 | **回復系** | 自クリーチャーがダメージを受けている |
| 3 | **ドロー系** | 手札が3枚以下 |
| 4 | **呪い系（戦闘不可）** | 敵の強クリーチャーがいる |
| 5 | **ステータス変更** | 有効なターゲットがいる |

### Phase 2: 魔力系（損益分岐点計算）

| 効果 | 損益分岐点計算 |
|------|---------------|
| `gain_magic` | 使用コスト < 獲得魔力 |
| `gain_magic_by_rank` | 使用コスト < 順位 × 倍率 |
| `gain_magic_by_lap` | 使用コスト < 周回数 × 倍率 |
| `drain_magic` | 使用コスト < 敵魔力 × 割合 |
| その他 | 各効果の計算式に基づく |

### Phase 3: 戦略系（長期的判断）

| カテゴリ | 判断要素 |
|----------|----------|
| ダイス操作 | 目的地との距離、ゲート/通行料回避 |
| 土地操作 | 連鎖ボーナス、敵土地価値 |
| 移動系 | 現在位置の危険度、目的地の価値 |
| 世界呪い | 現在の盤面状況、有利/不利 |

---

## ターゲット選択

### UI連携フロー

```
CPUSpellAI.decide_spell()
	│
	├─ 使用するスペル決定
	├─ 最適ターゲット決定
	│
	└─ SpellPhaseHandler に通知
		   │
		   ├─ ターゲット選択UI表示
		   ├─ CPU自動選択（ディレイ付き）
		   └─ 確定・実行
```

### ターゲットタイプ別処理

| target_type | 選択方法 |
|-------------|----------|
| `creature` | CPUSpellEvaluator で最適クリーチャー選択 |
| `land` | CPUSpellEvaluator で最適土地選択 |
| `player` | 敵プレイヤー or 自分（効果による） |
| `all_creatures` | 自動適用（選択不要） |
| `self` | 自動適用（選択不要） |
| `none` | 選択不要 |

---

## スペル vs ミスティックアーツ 選択基準

| 条件 | 選択 |
|------|------|
| 手札が6枚以上 | スペル優先（手札消費） |
| 手札が3枚以下 | ミスティックアーツ優先 |
| スペルのみ有効 | スペル |
| 秘術のみ有効 | ミスティックアーツ |
| 両方有効 | 効果の有用性スコアで比較 |
| コスト差が大きい | 低コスト優先 |

---

## 実装計画

### Phase 1: 基本実装 ✅
- [x] `cpu_spell_condition_checker.gd` - 条件チェック専用クラス
- [x] `cpu_spell_ai.gd` - スペルカード使用判断
- [x] `cpu_mystic_arts_ai.gd` - ミスティックアーツ使用判断
- [x] 各スペルJSONに`cpu_rule`フィールド追加

### Phase 2: spell_phase_handler連携 ✅
- [x] CPUターン時にスペル/ミスティックアーツ判断を呼び出し
- [x] 判断結果に基づいて直接execute_spell_effectを呼び出し
- [x] ターゲットデータの自動構築（_build_cpu_target_data）

### Phase 3: 効果別実装強化
- [x] ダメージ系評価の精度向上
  - 倒せるターゲット優先（+3.0スコア）
  - 敵クリーチャー優先（+1.0）
  - 土地レベル考慮（level×0.5）
  - 倒せる場合はスペル優先度1.5倍
- [ ] 損益計算の精度向上
- [ ] 戦略的判断の実装

---

## データ構造

### cpu_rule フィールド

各スペル/ミスティックアーツのJSONに`cpu_rule`フィールドを追加:

```json
{
  "id": 2001,
  "name": "アースシフト",
  "cpu_rule": {
	"pattern": "condition",
	"condition": "element_mismatch",
	"priority": "low"
  }
}
```

### パターン一覧

| pattern | 説明 |
|---------|------|
| `immediate` | 手に入り次第使用（ドロー系） |
| `has_target` | 有効なターゲットがいれば使用 |
| `condition` | 特定条件を満たしたら使用 |
| `enemy_hand` | 敵の手札を見て判断 |
| `profit_calc` | 損益計算して判断 |
| `strategic` | 戦略的判断（複雑） |
| `skip` | CPU使用しない |

### 優先度

| priority | 数値 |
|----------|------|
| `high` | 3 |
| `medium_high` | 2.5 |
| `medium` | 2 |
| `low` | 1 |
| `very_low` | 0.5 |

---

## 関連ファイル

### データファイル
- `data/spell_1.json` - スペルカード（2001-2064）+ cpu_rule
- `data/spell_2.json` - スペルカード（2065-2132）+ cpu_rule  
- `data/spell_mystic.json` - ミスティックアーツ（9001-9041）+ cpu_rule

### ゲームフローファイル
- `scripts/game_flow/spell_phase_handler.gd` - スペルフェーズ制御
- `scripts/cpu_ai/cpu_turn_processor.gd` - CPUターン処理フロー制御
- `scripts/spells/spell_mystic_arts.gd` - ミスティックアーツ実行

### ドキュメント
- `docs/design/spells_design.md` - スペルシステム設計書
- `docs/design/cpu_spell_pattern_assignments.md` - スペルパターン割り当て

---

## 変更履歴

| 日付 | 変更内容 |
|------|----------|
| 2025-12-31 | 初版作成 |
| 2026-01-02 | cpu_rule フィールドをスペルJSONに追加（173カード） |
| 2026-01-02 | cpu_spell_condition_checker.gd 作成 |
| 2026-01-02 | cpu_spell_ai.gd 作成 |
| 2026-01-02 | cpu_mystic_arts_ai.gd 作成 |
| 2026-01-02 | spell_phase_handler.gd にCPU AI統合 |
| 2026-01-02 | ダメージ系スペル評価ロジック改善 |
| 2026-01-06 | ファイル構成を分割計画に合わせて更新 |
| 2026-01-06 | cpu_spell_utils.gd分離完了、実際の行数に更新 |
