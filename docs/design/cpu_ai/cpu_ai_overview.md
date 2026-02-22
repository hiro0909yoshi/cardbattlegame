# CPU AI システム概要

## ファイル構成

### コアファイル（scripts/cpu_ai/）

| ファイル | 役割 |
|---------|------|
| `cpu_ai_handler.gd` | CPU判断のエントリーポイント |
| `cpu_turn_processor.gd` | CPUターン処理フロー制御 |
| `cpu_action_executor.gd` | CPU用アクション実行（召喚、バトル、ドミニオオーダー） |
| `cpu_tile_action_executor.gd` | CPU召喚/バトル準備（条件チェック、犠牲、合成） |
| `cpu_ai_context.gd` | 共有コンテキスト（システム参照を一元管理） |
| `cpu_ai_constants.gd` | 共通定数（スコア閾値、重み等） |

### バトル関連

| ファイル | 役割 |
|---------|------|
| `cpu_battle_ai.gd` | 攻撃側バトル判断 |
| `cpu_defense_ai.gd` | 防御側判断（アイテム/加勢/合体） |
| `cpu_item_evaluator.gd` | アイテム評価共通ロジック |
| `cpu_merge_evaluator.gd` | 合体判断 |
| `battle_simulator.gd` | バトル結果シミュレーション |
| `cpu_hand_utils.gd` | 手札アクセスユーティリティ |

### スペル関連

| ファイル | 役割 |
|---------|------|
| `cpu_spell_ai_container.gd` | CPU スペル AI 参照統合コンテナ (Phase 5-2) |
| `cpu_spell_ai.gd` | スペル使用**判断**（どのスペルを使うか） |
| `cpu_spell_phase_handler.gd` | スペルフェーズ**処理**（実行準備、ターゲット構築） |
| `cpu_spell_target_selector.gd` | ターゲット選択 |
| `cpu_spell_utils.gd` | 距離・利益計算 |
| `cpu_spell_condition_checker.gd` | 使用条件判定 |
| `cpu_target_resolver.gd` | ターゲット候補取得 |
| `cpu_board_analyzer.gd` | 盤面分析 |
| `cpu_mystic_arts_ai.gd` | アルカナアーツ判断 |
| `cpu_sacrifice_selector.gd` | カード犠牲選択 |

### 移動関連

| ファイル | 役割 |
|---------|------|
| `cpu_movement_evaluator.gd` | 移動経路評価、方向決定、分岐選択 |

### ドミニオオーダー関連

| ファイル | 役割 |
|---------|------|
| `cpu_territory_ai.gd` | ドミニオオーダー判断（レベルアップ、交換等） |

---

## 設計方針

### AI判断とフェーズ処理の分離

```
┌─────────────────────────────────────────────────────────┐
│ SpellPhaseHandler（ゲームフロー側）                      │
│   - フェーズ状態管理                                    │
│   - UI制御                                             │
│   - プレイヤー/CPU共通の実行処理                        │
└──────────────────┬──────────────────────────────────────┘
                   │ CPUの場合
                   ▼
┌─────────────────────────────────────────────────────────┐
│ CPUSpellPhaseHandler（CPU処理の橋渡し）                  │
│   - decide_action(): スペル/ミスティック判断の呼び出し  │
│   - prepare_spell_execution(): 実行準備（犠牲、合成）   │
│   - build_target_data(): ターゲットデータ構築          │
└──────────────────┬──────────────────────────────────────┘
                   │ 判断委譲
                   ▼
┌─────────────────────────────────────────────────────────┐
│ CPUSpellAI / CPUMysticArtsAI（純粋な判断ロジック）      │
│   - decide_spell(): どのスペルをどのターゲットに使うか  │
│   - スコアリング、条件評価                              │
└─────────────────────────────────────────────────────────┘
```

### メインファイル側の呼び出しパターン

```gdscript
# スペルフェーズでのCPU処理
if is_cpu_player(player_id):
    var action = cpu_spell_phase_handler.decide_action(player_id)
    match action.action:
        "spell":
            var prep = cpu_spell_phase_handler.prepare_spell_execution(action.decision, player_id)
            # 実行...
        "mystic":
            var prep = cpu_spell_phase_handler.prepare_mystic_execution(action.decision, player_id)
            # 実行...
```

---

## 処理フロー

```
ターン開始
│
├─ スペルフェーズ
│   ├─ CPUSpellPhaseHandler.decide_action()
│   │   ├─ CPUSpellAI.decide_spell()
│   │   └─ CPUMysticArtsAI.decide_mystic_arts()
│   ├─ スコア比較してスペル or ミスティック選択
│   └─ prepare_xxx_execution() → 効果実行
│
├─ 移動フェーズ
│   ├─ 方向選択 → cpu_movement_evaluator.decide_direction()
│   ├─ 分岐選択 → cpu_movement_evaluator.decide_branch_choice()
│   └─ ホーリーワード判断 → cpu_spell_ai._evaluate_holy_word_spell()
│
├─ 停止タイル処理
│   ├─ 敵ドミニオ → cpu_battle_ai（侵略判断）
│   ├─ 空き地 → 召喚判断
│   └─ 自ドミニオ/特殊 → cpu_territory_ai（ドミニオオーダー）
│
└─ 防御時
    └─ cpu_defense_ai（アイテム/加勢/合体判断）
```

---

## context方式

### CPUAIContext

各AIクラスは`CPUAIContext`を通じてゲームシステムにアクセス：

```gdscript
# コンテキスト作成（SpellPhaseHandler等で）
var context = CPUAIContext.new()
context.board_system = board_system
context.player_system = player_system
context.card_system = card_system
context.creature_manager = creature_manager
context.lap_system = lap_system

# AIクラスに渡す
cpu_spell_ai.initialize(context)
```

### 初期化の命名規約

| メソッド名 | 役割 |
|-----------|------|
| `set_context(context)` | contextオブジェクトを保存するだけ |
| `initialize(context)` | 外部参照を受け取り、内部で`new()`等も実行 |

---

## 詳細仕様書

| ドキュメント | 内容 |
|-------------|------|
| [cpu_movement_ai_spec.md](cpu_movement_ai_spec.md) | 移動判断、経路シミュレーション、ホーリーワード |
| [cpu_battle_ai_spec.md](cpu_battle_ai_spec.md) | バトル判断（攻撃側/防御側）、合体、即死 |
| [cpu_spell_ai_spec.md](cpu_spell_ai_spec.md) | スペル使用判断、パターン分類 |
| [cpu_territory_command_spec.md](cpu_territory_command_spec.md) | ドミニオオーダー、利益スコア計算 |

---

## 設計ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [cpu_ai_design.md](cpu_ai_design.md) | CPU AI全体設計 |
| [cpu_ai_understanding.md](cpu_ai_understanding.md) | 既存実装の理解 |
| [cpu_spell_pattern_assignments.md](cpu_spell_pattern_assignments.md) | スペルパターン割り当て |
| [cpu_deck_system.md](cpu_deck_system.md) | CPUデッキシステム |

---

## 変更履歴

| 日付 | 変更内容 |
|------|---------|
| 2026/01/16 | CPUSpellPhaseHandler追加、context方式・命名規約を明記 |
