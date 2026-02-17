# リファクタリング次ステップ

**最終更新**: 2026-02-17
**現在のフェーズ**: Phase 6 完了 → 構造改善フェーズへ

---

## Phase 7: 構造改善（CPU抽象化 + UI依存逆転）

### 7-A: CPU AI パススルー除去（SPH）

**目的**: SpellPhaseHandler が CPU AI の内部構造を知らない状態にする

**現状の問題**:
- SPH が 4つの CPU AI 変数を保持（cpu_spell_ai, cpu_mystic_arts_ai, cpu_hand_utils, cpu_movement_evaluator）
- SPH 自身はこれらを使わず、CPUSpellPhaseHandler に読ませるためだけに保持
- SPH が「AI の内部構造」を知っている（抽象度の問題）

**修正計画**:
1. CPUSpellPhaseHandler が CPUSpellAIContainer を直接保持するように変更
2. GSM が CPUSpellAIContainer を CPUSpellPhaseHandler に直接注入
3. SPH から 4 CPU AI 変数 + 4 setter メソッドを削除
4. MysticArtsHandler・DiscardHandler の CPU 参照も CPUSpellPhaseHandler 経由に統一

**変更前**:
```
GSM → SPH(保持) → CPUSpellPhaseHandler(読み取り)
```

**変更後**:
```
GSM → CPUSpellPhaseHandler(直接保持)
SPH → cpu_spell_phase_handler.execute_cpu_spell_turn(player_id)
```

**対象ファイル**:
- `scripts/game_flow/spell_phase_handler.gd` — 4変数 + 4 setter 削除
- `scripts/cpu_ai/cpu_spell_phase_handler.gd` — CPUSpellAIContainer 直接保持
- `scripts/system_manager/game_system_manager.gd` — 注入先変更
- `scripts/game_flow/mystic_arts_handler.gd` — CPU参照の取得元変更
- `scripts/game_flow/discard_handler.gd` — cpu_hand_utils の取得元変更

**リスク**: 低（参照の付け替えのみ）

---

### 7-B: SPH UI 依存逆転（残り3箇所）

**目的**: SPH → SpellUIManager の直接呼び出しを Signal 駆動に変更

**現状の問題**:
- SPH が SpellUIManager のメソッドを直接呼び出している（依存方向が逆）
- SpellFlowHandler / MysticArtsHandler は Signal 駆動化済み（Phase 6-A）だが、SPH 自身は未対応

**残存する直接呼び出し**:
1. `_initialize_human_player_ui()` — spell_ui_manager.initialize_spell_phase_ui() 等を直接呼び出し
2. `show_spell_cast_notification()` — spell_ui_manager.show_spell_cast_notification() を await で直接呼び出し
3. `_initialize_spell_cast_notification_ui()` — spell_ui_manager の初期化を直接呼び出し

**修正計画**:
1. SPH に Signal 追加: `human_spell_phase_started(player_id, hand_data, magic_power)`
2. SpellUIManager が Signal を listen して自分で UI 初期化
3. `show_spell_cast_notification` は request/completed Signal パターンに変更
4. 初期化系は GSM 側で直接呼び出し（SPH を経由しない）

**対象ファイル**:
- `scripts/game_flow/spell_phase_handler.gd` — Signal 追加、直接呼び出し除去
- `scripts/game_flow/spell_ui_manager.gd` — Signal listener 追加
- `scripts/system_manager/game_system_manager.gd` — 初期化の接続変更

**リスク**: 中（await パターンの Signal 変換は設計が必要）

---

## Phase 8: UIManager 神オブジェクト解消

### 概要

**目的**: UIManager を分割し、各 UI コンポーネントの責務を明確化。同時に未 Signal 化のハンドラーを Signal 駆動に移行。

**現状の UIManager**:
- 神オブジェクト化（大量のメソッド・プロパティ）
- 複数のハンドラーが直接参照・直接操作

### 8-A: ItemPhaseHandler Signal 駆動化

**現状**: `ui_manager` を直接参照し、手札表示・カードフィルター・カード選択UIを直接操作
**目標**: DicePhaseHandler/TollPaymentHandler と同様の Signal 駆動パターンに移行

### 8-B: DominioCommandHandler Signal 駆動化

**現状**: `ui_manager` を直接参照し、ナビゲーション・土地選択・アクションメニューを直接操作
**目標**: Signal 駆動パターンに移行（最大規模の UI 直接参照）

### 8-C: BankruptcyHandler パネル直接生成の分離

**現状**: 破産情報パネルをハンドラー内で直接生成（Panel.new()、Label.new()等）
**目標**: パネル生成を UI コンポーネント側に移動

### 8-D: UIManager 分割

**現状の UIManager を分割する候補**:
- PhaseDisplayManager（フェーズテキスト・トースト・アクションプロンプト）
- CardSelectionManager（カード選択UI・フィルター・情報パネル）
- NavigationManager（グローバルボタン・ナビゲーション状態）
- InfoPanelManager（クリーチャー/スペル/アイテム情報パネル）

**注意**: 8-A/B/C の Signal 駆動化と同時に進行するのが最も効率的

---

## UI層分離の全体状況

| ハンドラー | Signal駆動 | 状態 | 対象Phase |
|-----------|-----------|------|----------|
| SpellFlowHandler | ✅ 11 Signals | 完了（Phase 6-A） | — |
| MysticArtsHandler | ✅ 5 Signals | 完了（Phase 6-A） | — |
| DicePhaseHandler | ✅ 8 Signals | 完了（Phase 6-B） | — |
| TollPaymentHandler | ✅ 2 Signals | 完了（Phase 6-C） | — |
| DiscardHandler | ✅ 2 Signals | 完了（Phase 6-C） | — |
| SpellPhaseHandler | ⚠️ 部分的 | spell_ui_manager 直接呼び出し残存 | **Phase 7-B** |
| BankruptcyHandler | ⚠️ 部分的 | パネル直接生成 | Phase 8-C |
| ItemPhaseHandler | ❌ なし | ui_manager 直接操作多数 | Phase 8-A |
| DominioCommandHandler | ❌ 最小限 | ui_manager 直接操作多数 | Phase 8-B |

---

## CPU AI 参照の全体状況

| ハンドラー | CPU参照数 | 方式 | 対象Phase |
|-----------|----------|------|----------|
| SpellPhaseHandler | 5個 | パススルー保持 | **Phase 7-A** |
| ItemPhaseHandler | 3個 | GSM直接注入済み | 対処済み |
| MysticArtsHandler | 1個 | SPH経由 | Phase 7-A で連動 |
| DiscardHandler | 1個 | SPH経由 | Phase 7-A で連動 |
| その他 | 0個 | — | 対処不要 |

---

## 実施順序

| 順番 | Phase | 内容 | リスク |
|-----|-------|------|-------|
| 1 | **7-A** | CPU AI パススルー除去（SPH） | 低 |
| 2 | **7-B** | SPH UI 依存逆転 | 中 |
| 3 | **8-A/B** | ItemPhaseHandler / DominioCommandHandler Signal 駆動化 | 中 |
| 4 | **8-C/D** | BankruptcyHandler パネル分離 + UIManager 分割 | 高 |
