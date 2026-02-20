# システム依存関係マップ

**最終更新**: 2026-02-20
**状態**: Phase 0～10D 完了 - アーキテクチャ移行完了
**目的**: 現在のシステム依存関係を可視化し、リファクタリング成果を記録する

---

## 📊 現在の依存関係（全体図）

### トップレベル（GameSystemManager の子）

```
GameSystemManager
├── BoardSystem3D
├── PlayerSystem
├── CardSystem
├── BattleSystem
├── PlayerBuffSystem
├── SpecialTileSystem
├── UIManager
├── GameFlowManager
├── BattleScreenManager
└── DebugController
```

---

## 🔄 参照方向の凡例

```
→    直接参照（データ読み取り、ロジック呼び出し）
⇢    Callable注入（コールバック、イベントハンドラ化）
⚡   Signal（イベント通知、疎結合）
```

---

## 📌 GameFlowManager の依存関係

```
GameFlowManager
├── 直接参照（GSM が初期化時に注入）
│   ├→ BoardSystem3D
│   ├→ BattleSystem
│   ├→ PlayerSystem
│   ├→ CardSystem
│   ├→ PlayerBuffSystem
│   ├→ SpecialTileSystem
│   └→ SpellSystemContainer（spell_container）
│
├── Callable注入（GSM._setup_ui_callbacks() で注入）
│   ├⇢ _ui_set_phase_text_cb → UIManager.phase_display
│   ├⇢ _ui_update_panels_cb → UIManager.player_info_service
│   ├⇢ _ui_show_dominio_btn_cb → UIManager
│   ├⇢ _ui_hide_dominio_btn_cb → UIManager
│   ├⇢ _ui_show_card_selection_cb → UIManager
│   ├⇢ _ui_hide_card_selection_cb → UIManager
│   ├⇢ _ui_enable_navigation_cb → UIManager.navigation_service
│   └⇢ _get_tutorial_manager_cb → TutorialManager
│
├── ui_manager（初期化時のクロージャキャプチャのみ）
│   └→ ランタイム直接呼び出し: ゼロ（全て Callable化済み）
│
├── Signal定義（9個）
│   ├⚡ spell_phase_requested
│   ├⚡ item_phase_requested
│   ├⚡ dominio_command_phase_requested
│   ├⚡ dice_phase_started
│   ├⚡ movement_completed
│   ├⚡ tile_action_completed
│   ├⚡ turn_completed
│   ├⚡ game_ended
│   └⚡ phase_changed
│
└── 子システム（自身が作成・保持）
    ├── SpellPhaseHandler
    │   ├── SpellFlowHandler
    │   ├── SpellStateHandler
    │   ├── SpellTargetSelectionHandler
    │   ├── MysticArtsHandler
    │   ├── SpellEffectExecutor
    │   ├── SpellUIManager
    │   └── CPUSpellPhaseHandler
    ├── ItemPhaseHandler
    ├── DominioCommandHandler
    ├── DicePhaseHandler
    ├── TollPaymentHandler
    ├── DiscardHandler
    ├── BankruptcyHandler
    ├── LapSystem
    ├── BattleScreenManager
    ├── TargetSelectionHelper
    ├── GameFlowStateMachine
    └── SpecialTileSystem（2つ目の参照）
```

### 改善内容（Phase 10-D）

- ✅ **15箇所** の `ui_manager` 直接呼び出しを **Callable注入** に変更
- ✅ UI操作 Callable 変数 10個追加（`_ui_set_current_turn_cb` 等）
- ✅ `GSM._setup_ui_callbacks()` で Callable 一括注入
- ✅ back-ref 設定を GFM から GSM に移動（初期化フロー明確化）
- ✅ ランタイム直接参照ゼロ達成

---

## 📌 BoardSystem3D の依存関係

```
BoardSystem3D
├── 直接参照（GSM が初期化時に注入）
│   ├→ PlayerSystem
│   ├→ CardSystem
│   ├→ BattleSystem
│   ├→ PlayerBuffSystem
│   ├→ SpecialTileSystem
│   └→ spell_land: SpellLand（直接注入、GFM経由廃止）
│
├── Callable注入（GFM.setup_board_callbacks() で注入）
│   ├⇢ _trigger_land_curse_cb → GFM
│   ├⇢ _is_game_ended_cb → GFM
│   ├⇢ _show_dominio_btn_cb → UIManager
│   └⇢ _hide_dominio_btn_cb → UIManager
│
├── 残存直接参照（LOW優先）
│   ├→ ui_manager（TAP/CPUTurnProcessor が使用）
│   └→ game_flow_manager（TAP/CPUAIHandler が使用）
│
├── Signal定義（5個）
│   ├⚡ creature_updated
│   ├⚡ tile_action_completed
│   ├⚡ board_state_changed
│   ├⚡ land_curse_triggered
│   └⚡ movement_started
│
└── 子システム（自身が作成・保持）
    ├── CreatureManager
    ├── TileDataManager
    ├── TileNeighborSystem
    ├── TileInfoDisplay
    ├── MovementController3D
    ├── TileActionProcessor
    ├── CPUTurnProcessor
    └── CPUAIHandler
```

### 改善内容（Phase 7）

- ✅ CPU AI 参照を SPH から直接に変更（チェーンアクセス廃止）
- ✅ `spell_cost_modifier`, `spell_world_curse` を直接参照に変更

---

## 📌 UIManager の依存関係

```
UIManager
├── システム参照（表示データ読み取り用）
│   ├→ board_system_ref: BoardSystem3D
│   ├→ player_system_ref: PlayerSystem
│   ├→ card_system_ref: CardSystem
│   └→ game_flow_manager_ref: GameFlowManager（17ファイルが使用）
│
├── Callable注入（GFM._setup_ui_callbacks() で注入）
│   ├⇢ _is_input_locked_cb
│   ├⇢ _has_owned_lands_cb
│   └⇢ _update_tile_display_cb
│
├── UIEventHub（GSMが作成・注入）
│   └⚡ UI→ロジック間イベント（hand_card_tapped, card_selection_requested 等）
│
├── 内部サービス（5個）
│   ├── MessageService
│   ├── NavigationService
│   ├── CardSelectionService
│   ├── InfoPanelService
│   └── PlayerInfoService
│
├── Signal定義（38個）
│   └── Phase 6-8で実装（UI層分離のための UI Signal駆動化）
│
└── UIコンポーネント（15+個）
    ├── CardSelectionUI
    ├── HandDisplay
    ├── PhaseDisplay
    ├── CreatureInfoPanel
    ├── PlayerInfoPanel
    ├── (その他)
    └── ...
```

### 改善内容（Phase 6～10-C）

- ✅ **33個** の UI Signal 追加（SpellPhaseHandler, DicePhaseHandler, Toll/Discard/Bankruptcy）
- ✅ ItemPhaseHandler Signal化（4 Signals 追加）
- ✅ **7/8ハンドラー** の UI層完全分離
- ✅ `game_flow_manager_ref` ランタイム使用ゼロ化（13箇所 → Callable注入）
- ✅ `PlayerInfoService` 新規サービス化（16ファイル・23箇所の呼び出し統一）
- ✅ 潜在バグ修正（DominioOrderUI DCH null参照）

---

## 📌 SpellPhaseHandler の依存関係

```
SpellPhaseHandler
├── 直接参照（GSMが注入）
│   ├→ CardSystem
│   ├→ PlayerSystem
│   ├→ BoardSystem3D
│   └→ SpellSubsystemContainer（spell_systems）
│
├── Callable注入（GFM から注入）
│   └⇢ _is_cpu_player_cb → GFM
│
├── Signal定義（16個）
│   ├⚡ spell_phase_started
│   ├⚡ spell_execution_completed
│   ├⚡ spell_ui_selection_requested
│   ├⚡ spell_ui_confirmation_shown
│   ├⚡ spell_ui_messages_updated
│   └── (その他11個)
│
└── サブハンドラー（自身が作成・保持）
    ├── SpellFlowHandler
    ├── SpellStateHandler
    ├── SpellTargetSelectionHandler
    ├── MysticArtsHandler
    ├── SpellEffectExecutor
    ├── SpellUIManager
    └── CPUSpellPhaseHandler
```

### 改善内容（Phase 6-A）

- ✅ UI直接呼び出し削除（`spell_ui_manager` Signal化）
- ✅ 16個の UI Signal追加
- ✅ 委譲メソッド 8個削除

---

## 📌 その他ハンドラーの依存関係

### DicePhaseHandler
```
DicePhaseHandler
├── 直接参照
│   ├→ PlayerSystem
│   └→ BoardSystem3D
├── Signal定義（8個）
│   └⚡ dice_result_shown, phase_text_updated (等)
└── UI Signal駆動化済み（Phase 6-B）
```

### TollPaymentHandler / DiscardHandler / BankruptcyHandler
```
各ハンドラー
├── Signal定義（各2～5個）
│   └⚡ UI操作 Signal 駆動化
└── UI Panel 生成は部分的に直接参照を保持（LOW優先）
```

### ItemPhaseHandler
```
ItemPhaseHandler
├── Signal定義（4個）
│   └⚡ item_ui_selection_requested, item_usage_confirmed (等)
├── `_ui_manager` 完全削除（Phase 8-A）
└── UI Signal駆動化済み
```

---

## 📊 改善済みメトリクス

| メトリクス | Phase 0 開始時 | 現在 | 改善率 |
|-----------|--------------|------|--------|
| **横断的シグナル接続** | 12箇所 | 2箇所 | 83% 削減 |
| **逆参照（子→親）** | 5箇所 | 2箇所（Callable化済み） | 60% 削減 |
| **循環参照** | 0箇所 | 0箇所 | - |
| **最大依存数（1システム）** | 7個 | 7個 | - |
| **GFM最大ファイル行数** | 982行 | ~724行 | 26% 削減 |
| **SPH最大ファイル行数** | 1,764行 | ~600行 | 66% 削減 |
| **UI Signal定義** | 0個 | 38個 | 新規 |
| **UIManager サービス** | 1個 | 5個 | 新規4個 |
| **ハンドラーUI完全分離** | 0/8 | 7/8 | 88% |
| **コード削減合計** | - | ~700行 | - |

---

## 📌 残存する依存（LOW優先）

| 項目 | 現状 | 理由 | 優先度 |
|------|------|------|--------|
| **Board `var ui_manager`** | init時にサブシステムへ渡す | TAP/CPUTurnProcessor が表示更新を使用 | LOW |
| **Board `var game_flow_manager`** | init時にサブシステムへ渡す | TAP/CPUAIHandler が状態確認を使用 | LOW |
| **GFM `var ui_manager`** | 初期化時 + クロージャキャプチャのみ | ランタイム直接呼び出しゼロ | RESOLVED |
| **UIManager `game_flow_manager_ref`** | 参照保持 | 17ファイルが使用（大規模作業） | LOW |
| **BankruptcyHandler UI Panel生成** | 直接呼び出し残存 | Signal化の複雑性により保持 | LOW |

### 残存理由

- **LOW優先**: ビジネスロジック品質に大きな影響がない
- **大規模作業**: UIManager→Logic の逆参照削減は 17ファイル・多数の箇所に影響
- **部分的UI Signal化**: 全Signal化より、現在の混在状態（Signal + 直接呼び出し）で動作安定

---

## 🟢 完成したツリー構造

### 理想的な階層（現在実装）

```
GameSystemManager（初期化の総合調整役）
│
├── Core Systems（直接参照のみ）
│   ├── BoardSystem3D
│   ├── PlayerSystem
│   ├── CardSystem
│   ├── BattleSystem
│   ├── PlayerBuffSystem
│   └── SpecialTileSystem
│
├── Flow Management
│   └── GameFlowManager（ビジネスロジック層）
│       ├── SpellPhaseHandler（Callable化）
│       ├── ItemPhaseHandler（Signal駆動化）
│       ├── DominioCommandHandler
│       ├── DicePhaseHandler（Signal駆動化）
│       ├── TollPaymentHandler（Signal駆動化）
│       ├── DiscardHandler（Signal駆動化）
│       ├── BankruptcyHandler（Signal駆動化）
│       └── SpellSystemContainer（10+個のspellシステム）
│
├── UI Coordination
│   └── UIManager（プレゼンテーション層）
│       ├── MessageService
│       ├── NavigationService
│       ├── CardSelectionService
│       ├── InfoPanelService
│       └── PlayerInfoService
│
└── Visual Effects
    └── BattleScreenManager
```

### 参照方向の確認

✅ **親→兄弟参照**: 明示的、Dependency Injection で注入
✅ **子→親 Signal**: 標準パターン、疎結合
✅ **兄弟→兄弟 参照**: Core Systems（状態管理のみ）のみ
✅ **Callable注入**: コールバック化で動的なアクセス可能
✅ **Signal駆動**: UI層分離の基本パターン

---

## 🔗 関連ドキュメント

- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造（Phase 0 完成版）
- `docs/progress/refactoring_next_steps.md` - 現在の計画・次フェーズ
- `docs/progress/daily_log.md` - 最新作業ログ
- `docs/implementation/signal_catalog.md` - 全Signal定義カタログ
- `docs/implementation/delegation_method_catalog.md` - Callable化一覧

---

**最終更新**: 2026-02-20
**リファクタリング状態**: ✅ Phase 0～10D 完了
