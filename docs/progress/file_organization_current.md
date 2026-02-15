# ファイル構成整理レポート

## 概要

SpellPhaseHandler リファクタリング（Phase 3-A）により、以下のファイルが散在している状況が発生：
- SpellPhaseHandler メインファイル（1,665行）
- SpellPhaseHandler 関連ハンドラー（9個のファイル、1,800行以上）
- Strategy パターン実装（23個のファイル、2,000行以上）
- 呪いシステム補助ファイル（複数）

本ドキュメントは、これらファイルの現状分析と、推奨される再構成案を提示します。

---

## 現在のファイル構成分析

### 📁 scripts/game_flow/ （メインフロー管理）

#### SpellPhaseHandler 関連（9個のメインハンドラー）
| ファイル | 行数 | 責務 | 作成日 |
|---------|------|------|--------|
| spell_phase_handler.gd | 1,665 | スペルフェーズ全体のオーケストレーション | 2026-02-12 |
| spell_state_handler.gd | 241 | スペルフェーズの状態管理（6種類の状態） | 2026-02-13 |
| spell_flow_handler.gd | 685 | スペルフロー制御（選択→確認→実行） | 2026-02-14 |
| spell_effect_executor.gd | 400 | 効果実行エンジン（全effect_typeの処理） | 2026-02-13 |
| spell_initializer.gd | 213 | 初期化マネージャー | 2026-02-15 |
| spell_target_selection_handler.gd | 556 | ターゲット選択UI + 入力処理 | 2026-02-14 |
| spell_confirmation_handler.gd | 80 | スペル確認UI | 2026-02-14 |
| spell_ui_controller.gd | 159 | UI制御 + カメラ制御 | 2026-02-14 |
| spell_navigation_controller.gd | 154 | ナビゲーション管理 | 2026-02-15 |
| **合計** | **4,153** | - | - |

#### その他のハンドラー（既存、5個）
| ファイル | 行数 | 責務 |
|---------|------|------|
| dice_phase_handler.gd | 280+ | ダイスロール管理 |
| toll_payment_handler.gd | 250+ | 通行料支払い |
| discard_handler.gd | 120+ | 手札制限管理 |
| bankruptcy_handler.gd | 100+ | 破産管理 |
| mystic_arts_handler.gd | 200+ | アルカナアーツ処理 |
| **小計** | **950+** | - |

#### **game_flow フォルダ合計: 5,100行以上**

---

### 📁 scripts/spells/ （スペルシステム）

#### Strategy パターン実装（23個 + 基盤）
```
scripts/spells/strategies/
├── spell_strategy.gd                           # 基底クラス（50行）
├── spell_strategy_factory.gd                   # ファクトリー（150行）
└── effect_strategies/                          # 23個の Strategy ファイル
	├── damage_effect_strategy.gd
	├── heal_effect_strategy.gd
	├── creature_move_effect_strategy.gd
	├── land_change_effect_strategy.gd
	├── draw_effect_strategy.gd
	├── dice_effect_strategy.gd
	├── creature_curse_effect_strategy.gd
	├── player_curse_effect_strategy.gd
	├── world_curse_effect_strategy.gd
	├── toll_curse_effect_strategy.gd
	├── stat_boost_effect_strategy.gd
	├── magic_effect_strategy.gd
	├── hand_manipulation_effect_strategy.gd
	├── player_move_effect_strategy.gd
	├── stat_change_effect_strategy.gd
	├── purify_effect_strategy.gd
	├── down_state_effect_strategy.gd
	├── creature_place_effect_strategy.gd
	├── creature_swap_effect_strategy.gd
	├── spell_borrow_effect_strategy.gd
	├── transform_effect_strategy.gd
	├── creature_return_effect_strategy.gd
	├── self_destroy_effect_strategy.gd
	└── （残り12個予定）
```

**合計**: 2,000行以上（基盤150行 + 各Strategy 80-120行）

#### スペル実装システム（12個の Spell**** クラス）
| ファイル | 行数 | システム |
|---------|------|---------|
| spell_draw/ | 800+ | 各種ドロー処理 |
| spell_magic.gd | 500+ | EP・魔力操作 |
| spell_land.gd | 400+ | 土地属性・レベル変更 |
| spell_curse.gd | 600+ | クリーチャー呪い |
| spell_dice.gd | 300+ | ダイス操作 |
| spell_curse_stat.gd | 200+ | ステータス呪い |
| spell_world_curse.gd | 150+ | 世界呪い |
| spell_player_move.gd | 250+ | プレイヤー移動 |
| spell_curse_toll.gd | 180+ | 通行料呪い |
| spell_cost_modifier.gd | 100+ | コスト操作 |
| spell_creature_place.gd | 150+ | クリーチャー配置 |
| spell_creature_swap.gd | 120+ | クリーチャー交換 |
| **小計** | **3,750+** | - |

**spells フォルダ合計: 5,750行以上**

---

### 📁 その他の関連ファイル

| パス | 行数 | 責務 |
|------|------|------|
| scripts/game_flow/spell_system_container.gd | 60 | 10+2個のSpell****管理 |
| scripts/cpu_ai/cpu_spell_phase_handler.gd | 350 | CPU AI スペル処理 |
| scripts/cpu_ai/cpu_spell_ai.gd | 280 | CPU スペル判断 AI |
| scripts/helpers/spell_protection.gd | 150 | 呪い判定ヘルパー |

**合計**: 840行

---

## 問題点の分析

### 1. ファイル数が増大（Phase 3-A 完了時点）

| カテゴリ | ファイル数 | 行数 |
|---------|----------|------|
| SpellPhaseHandler 関連 | 9個 | 4,153行 |
| Strategy 実装 | 25個 | 2,000行+ |
| スペル実装 | 15個 | 3,750行+ |
| CPU AI | 2個 | 630行 |
| その他 | 4個 | 840行 |
| **合計** | **55個** | **11,373行** |

### 2. 検索・ナビゲーション効率の低下

- SpellPhaseHandler 関連の9個ハンドラーが game_flow フォルダ直下に混在
- Strategy パターンの23個ファイルが effect_strategies サブフォルダに分散
- 関連ファイルの発見に時間がかかる（フォルダ構造が明確でない）

### 3. 責務の境界が不明確

- spell_flow_handler vs spell_effect_executor の責務分離が不明確
- spell_target_selection_handler と spell_ui_controller の関連性が薄い記載
- spell_state_handler の状態定義が複数の責務を担当

---

## 推奨される再構成案

### 案A: 責務別フォルダ分割（推奨）

**考え方**: SpellPhaseHandler の責務を明確に分割し、各責務ごとにサブフォルダを作成

```
scripts/game_flow/
│
├── spell_phase_handler.gd              ← メイン（オーケストレーション のみ）
├── spell_state_handler.gd              ← 状態管理（独立）
├── spell_initializer.gd                ← 初期化（独立）
│
├── spell_flow/                         ← スペルフロー制御
│   ├── spell_flow_handler.gd           ← フロー制御メイン
│   ├── spell_effect_executor.gd        ← 効果実行エンジン
│   └── spell_borrow.gd                 ← 借りるスペル処理
│
├── spell_selection/                    ← スペル選択UI
│   ├── spell_target_selection_handler.gd
│   ├── spell_confirmation_handler.gd
│   └── spell_ui_controller.gd
│
├── spell_navigation/                   ← ナビゲーション管理
│   └── spell_navigation_controller.gd
│
├── phase_handlers/                     ← ゲーム全体のハンドラー
│   ├── dice_phase_handler.gd
│   ├── toll_payment_handler.gd
│   ├── discard_handler.gd
│   ├── bankruptcy_handler.gd
│   └── mystic_arts_handler.gd
│
└── spell_system_container.gd           ← 10+2個Spell****管理
```

**利点**:
- ✅ 責務が明確（フロー vs 選択UI vs ナビゲーション）
- ✅ 関連ファイルが同一フォルダに集約
- ✅ 検索効率が向上（フォルダ名で目的ファイルを絞り込み可能）
- ✅ 新規機能追加時の配置が明確

**欠点**:
- ファイル移動により git history が複雑化
- Phase 3-A 完了後、追加の一手間が必要

---

### 案B: 責務グループ化（現在地に近い）

**考え方**: スペルフェーズ関連ファイルを1つのサブフォルダに集約

```
scripts/game_flow/
│
├── spell_phase/                        ← スペルフェーズ関連（9個）
│   ├── spell_phase_handler.gd
│   ├── spell_state_handler.gd
│   ├── spell_initializer.gd
│   ├── spell_flow_handler.gd
│   ├── spell_effect_executor.gd
│   ├── spell_target_selection_handler.gd
│   ├── spell_confirmation_handler.gd
│   ├── spell_ui_controller.gd
│   ├── spell_navigation_controller.gd
│   └── spell_borrow.gd
│
├── handlers/                           ← ゲーム全体のハンドラー（5個）
│   ├── dice_phase_handler.gd
│   ├── toll_payment_handler.gd
│   ├── discard_handler.gd
│   ├── bankruptcy_handler.gd
│   └── mystic_arts_handler.gd
│
├── spell_system_container.gd
└── game_flow_manager.gd
```

**利点**:
- ✅ 移行負担が小さい（spell_phase サブフォルダのみ作成）
- ✅ 現在のファイル関係を保持
- ✅ 初期の検索効率向上（spell_phase フォルダを展開）

**欠点**:
- ❌ spell_phase フォルダ内の責務がまだ混在
- ❌ spell_flow vs spell_effect_executor の関連性が不明確
- ❌ 追加のサブフォルダ化が必要（将来的に案A へ進化する可能性）

---

## 実装手順

### Phase 1: ドキュメント化（現在）
- ✅ 本レポート作成（file_organization_current.md）
- ⚪ デザイン決定（案A or 案B をユーザーと協議）

### Phase 2: 短期リファクタリング（優先度 P1）
**推奨案: 案A（責務別フォルダ分割）**

1. **フォルダ構成の作成**（1-2時間）
   ```bash
   mkdir -p scripts/game_flow/spell_flow
   mkdir -p scripts/game_flow/spell_selection
   mkdir -p scripts/game_flow/spell_navigation
   mkdir -p scripts/game_flow/phase_handlers
   ```

2. **ファイル移動**（2-3時間）
   - spell_flow_handler.gd → spell_flow/
   - spell_effect_executor.gd → spell_flow/
   - spell_borrow.gd → spell_flow/
   - spell_target_selection_handler.gd → spell_selection/
   - spell_confirmation_handler.gd → spell_selection/
   - spell_ui_controller.gd → spell_selection/
   - spell_navigation_controller.gd → spell_navigation/
   - 各ハンドラー → phase_handlers/

3. **参照パス更新**（2-3時間）
   - `spell_flow_handler` → `spell_flow/spell_flow_handler` への参照更新
   - その他のサブフォルダ参照も更新
   - preload() パスの確認・修正

4. **テスト・検証**（1時間）
   - 1ターン以上のプレイテスト
   - エラーログ確認

**見積: 6-9時間**

### Phase 3: 中期整理（優先度 P2）
- Strategy パターンの organize_strategy_imports 整理
- CPU AI ファイルの整理検討
- dependency_map.md の更新

### Phase 4: 長期計画（優先度 P3）
- Phase 4（UIManager 責務分離）と並行実施を検討
- アーキテクチャドキュメント（TREE_STRUCTURE.md など）の更新

---

## 影響分析

### Git History への影響
- **移動対象ファイル**: 9個
- **git mv コマンドで対応**することで history 保持可能
- **コミットメッセージ**: "refactor: Reorganize spell_phase_handler related files (案A 採用)"

### 参照更新の複雑さ
- **preload() 参照**: 15-20箇所
- **直接参照**: 50-80箇所
- **自動ツール対応**: grep + sed で一括対応可能

### テスト範囲
- ✅ SpellPhaseHandler のすべてのメソッド動作確認
- ✅ CPU AI スペル処理動作確認
- ✅ UI ナビゲーション動作確認
- ✅ エラーログなし確認

---

## ファイル行数分布（現状）

| カテゴリ | 行数 | 比率 | ファイル数 |
|---------|------|------|----------|
| SpellPhaseHandler 関連 | 4,153 | 36.5% | 9 |
| スペル実装（spells/） | 3,750 | 33.0% | 12 |
| Strategy パターン | 2,000 | 17.6% | 25 |
| その他（CPU AI, helpers等） | 1,470 | 12.9% | 9 |
| **合計** | **11,373** | **100%** | **55** |

---

## 推奨事項

### 短期（2-3週間以内）
1. **案A or 案B を決定**
   - ユーザーとの協議で最終決定
   - 推奨: **案A（責務別フォルダ分割）**

2. **Phase 2 フォルダ構成実装**
   - 6-9時間の作業
   - 並行: SpellPhaseHandler 追加削減タスク

3. **dependency_map.md 更新**
   - 新規フォルダ構成を反映

### 中期（1ヶ月）
1. Strategy パターンの organize 整理
2. CPU AI フォルダの構成検討

### 長期（2-3ヶ月）
1. Phase 4（UIManager 責務分離）と並行実施
2. 全体アーキテクチャドキュメント更新

---

## 参考資料

- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造
- `docs/design/dependency_map.md` - 現在の依存関係マップ
- `docs/progress/refactoring_next_steps.md` - リファクタリング計画詳細

---

**Last Updated**: 2026-02-15
**Status**: 提案ドキュメント（実装待ち）
