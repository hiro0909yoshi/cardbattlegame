# CPU AI システム概要

## ファイル構成

### コアファイル（scripts/cpu_ai/）

| ファイル | 役割 |
|---------|------|
| `cpu_ai_handler.gd` | CPU判断のエントリーポイント |
| `cpu_turn_processor.gd` | CPUターン処理フロー制御 |

### バトル関連

| ファイル | 役割 |
|---------|------|
| `cpu_battle_ai.gd` | バトル評価、アイテム選択 |
| `cpu_merge_evaluator.gd` | 合体判断 |
| `battle_simulator.gd` | バトル結果シミュレーション |
| `cpu_hand_utils.gd` | 手札アクセスユーティリティ |

### スペル関連

| ファイル | 役割 |
|---------|------|
| `cpu_spell_ai.gd` | スペル使用判断 |
| `cpu_spell_target_selector.gd` | ターゲット選択 |
| `cpu_spell_utils.gd` | 距離・利益計算 |
| `cpu_spell_condition_checker.gd` | 使用条件判定 |
| `cpu_target_resolver.gd` | ターゲット候補取得 |
| `cpu_board_analyzer.gd` | 盤面分析 |
| `cpu_mystic_arts_ai.gd` | ミスティックアーツ判断 |

### 移動関連

| ファイル | 役割 |
|---------|------|
| `cpu_movement_evaluator.gd` | 移動経路評価、方向決定、分岐選択 |

### 領地コマンド関連

| ファイル | 役割 |
|---------|------|
| `cpu_territory_ai.gd` | 領地コマンド判断（レベルアップ、交換等） |

---

## 処理フロー

```
ターン開始
│
├─ スペルフェーズ
│   └─ cpu_spell_ai / cpu_mystic_arts_ai
│
├─ 移動フェーズ
│   ├─ 方向選択 → cpu_movement_evaluator.decide_direction()
│   ├─ 分岐選択 → cpu_movement_evaluator.decide_branch_choice()
│   └─ ホーリーワード判断 → cpu_spell_ai._evaluate_holy_word_spell()
│
├─ 停止タイル処理
│   ├─ 敵領地 → cpu_battle_ai（侵略判断）
│   ├─ 空き地 → 召喚判断
│   └─ 自領地/特殊 → cpu_territory_ai（領地コマンド）
│
└─ 防御時
    └─ cpu_battle_ai（アイテム/援護/合体判断）
```

---

## 詳細仕様書

| ドキュメント | 内容 |
|-------------|------|
| [cpu_movement_ai_spec.md](cpu_movement_ai_spec.md) | 移動判断、経路シミュレーション、ホーリーワード |
| [cpu_battle_ai_spec.md](cpu_battle_ai_spec.md) | バトル判断、合体、即死、ワーストケース |
| [cpu_spell_ai_spec.md](cpu_spell_ai_spec.md) | スペル使用判断、パターン分類 |
| [cpu_territory_command_spec.md](cpu_territory_command_spec.md) | 領地コマンド、利益スコア計算 |

---

## 設計ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [cpu_ai_design.md](../design/cpu_ai_design.md) | CPU AI全体設計 |
| [cpu_ai_understanding.md](../design/cpu_ai_understanding.md) | 既存実装の理解 |
| [cpu_spell_pattern_assignments.md](../design/cpu_spell_pattern_assignments.md) | スペルパターン割り当て |
| [cpu_deck_system.md](../design/cpu_deck_system.md) | CPUデッキシステム |
