# システムツリー構造定義

**最終更新**: 2026-02-20（Phase 0〜E 完了反映）

**目的**: ゲームシステムの実装された階層構造を定義し、保守性・拡張性・テスタビリティを確保する

---

## 📊 全体ツリー構造図（現在の実装）

```
game_3d.gd (シーンルート)
│
└── GameSystemManager ──── 初期化・参照注入の統括
    │
    ├─ [Core Game Systems] ──────────── ゲームロジック層
    │  │
    │  ├── BoardSystem3D ───────────── 3D盤面・プレイヤー移動
    │  │   ├── CreatureManager
    │  │   ├── TileDataManager
    │  │   ├── TileNeighborSystem
    │  │   ├── TileInfoDisplay
    │  │   ├── MovementController3D
    │  │   │   └── MovementHelper
    │  │   ├── TileActionProcessor
    │  │   │   ├── TileSummonExecutor (RefCounted)
    │  │   │   └── TileBattleExecutor (RefCounted)
    │  │   ├── CPUTurnProcessor
    │  │   └── CPUAIHandler
    │  │
    │  ├── PlayerSystem ───────────── プレイヤー状態管理
    │  │   ├── PlayerBuffSystem
    │  │   └── MagicStoneSystem
    │  │
    │  ├── CardSystem ─────────────── カード管理
    │  │
    │  └── BattleSystem ──────────── 戦闘エンジン
    │      ├── BattlePreparation
    │      ├── BattleExecution
    │      ├── BattleSkillProcessor
    │      └── BattleSpecialEffects
    │
    ├─ [Game Flow Control] ────────── 進行制御層
    │  │
    │  └── GameFlowManager ──────── ターン管理・フェーズ制御（739行）
    │      │
    │      ├── [Phase Handlers] ─── フェーズハンドラー群
    │      │   ├── SpellPhaseHandler
    │      │   │   ├── SpellFlowHandler
    │      │   │   ├── SpellStateHandler
    │      │   │   ├── SpellTargetSelectionHandler
    │      │   │   ├── MysticArtsHandler
    │      │   │   ├── SpellEffectExecutor
    │      │   │   ├── SpellUIManager ────────── UI統合管理（Phase 5-1）
    │      │   │   ├── CPUSpellAIContainer ──── CPU AI参照統合（Phase 5-2）
    │      │   │   └── CPUSpellPhaseHandler
    │      │   ├── ItemPhaseHandler
    │      │   ├── DominioCommandHandler
    │      │   ├── DicePhaseHandler
    │      │   ├── TollPaymentHandler
    │      │   ├── DiscardHandler
    │      │   └── BankruptcyHandler
    │      │
    │      ├── [Spell Systems] ─── SpellSystemContainer (RefCounted)
    │      │   ├── SpellDraw
    │      │   ├── SpellMagic
    │      │   ├── SpellLand
    │      │   ├── SpellCurse
    │      │   ├── SpellDice
    │      │   ├── SpellCurseStat (Node)
    │      │   ├── SpellWorldCurse (Node)
    │      │   ├── SpellPlayerMove
    │      │   ├── SpellCurseToll
    │      │   └── SpellCostModifier
    │      │
    │      ├── [State & Support]
    │      │   ├── GameFlowStateMachine
    │      │   ├── LapSystem
    │      │   ├── BattleScreenManager
    │      │   ├── TargetSelectionHelper
    │      │   ├── SpecialTileSystem
    │      │   └── [Callable注入 - Phase 10-D]
    │      │       ├── _ui_set_phase_text_cb
    │      │       ├── _ui_update_panels_cb
    │      │       ├── _ui_show_dominio_btn_cb
    │      │       ├── _ui_hide_dominio_btn_cb
    │      │       ├── _ui_show_surrender_btn_cb
    │      │       ├── _ui_hide_surrender_btn_cb
    │      │       ├── _ui_set_current_turn_cb
    │      │       └── _ui_show_global_comment_cb
    │      │
    │      └── [AI Utilities]
    │          ├── CPUAIContext
    │          ├── CPUBattleAI
    │          ├── CPUMovementEvaluator
    │          ├── CPUSpecialTileAI
    │          └── CPUSpellAIContainer (=SpellPhaseHandler配下)
    │
    ├─ [Presentation] ──────────────── UI層
    │  │
    │  ├── UIEventHub ────────────── UI→ロジック間イベントハブ (3 Signals)
    │  │   ├── hand_card_tapped
    │  │   ├── dominio_cancel_requested
    │  │   └── surrender_requested
    │  │
    │  └── UIManager ───────────── UI統括（ファサード）（922行）
    │      │
    │      ├── [5 Internal Services]
    │      │   ├── MessageService ────────── メッセージ・コメント表示
    │      │   ├── NavigationService ─────── ナビゲーションボタン管理
    │      │   ├── CardSelectionService ─── カード選択UI管理
    │      │   ├── InfoPanelService ─────── 情報パネル管理
    │      │   └── PlayerInfoService ────── プレイヤー情報表示（Phase 10-A）
    │      │
    │      ├── [UI Components]
    │      │   ├── HandDisplay
    │      │   ├── PhaseDisplay
    │      │   ├── CardSelectionUI
    │      │   ├── GlobalActionButtons
    │      │   ├── GlobalCommentUI
    │      │   ├── DominioOrderUI
    │      │   ├── TapTargetManager
    │      │   ├── CreatureInfoPanelUI
    │      │   ├── SpellInfoPanelUI
    │      │   ├── ItemInfoPanelUI
    │      │   ├── PlayerInfoPanel (×4)
    │      │   ├── BattleScreenManager Components
    │      │   ├── DebugPanel
    │      │   └── (その他UI)
    │      │
    │      └── [Callable注入 - Phase 10-C]
    │          ├── _is_input_locked_cb
    │          ├── _has_owned_lands_cb
    │          ├── _update_tile_display_cb
    │          └── (message/navigation/selection service refs)
    │
    ├─ [Support Systems] ──────────── サポート層
    │  ├── CameraController
    │  ├── DebugController
    │  └── SignalRegistry
    │
    └─ [Autoload Singletons] ──────── グローバルシングルトン
       ├── CardLoader
       ├── GameData
       ├── UserCardDB
       ├── CpuDeckData
       ├── DebugSettings
       └── GameConstants
```

---

## 🔌 参照方向と通信パターン

### システム間参照の方向性図

```
=== 参照方向凡例 ===
→  = 直接参照保持
⇢  = Callable 注入（ランタイム双方向参照ゼロ）
⚡ = Signal（子→親）
⇄  = 双方向

[GameSystemManager] ──→ 全システム作成・参照注入
                    └─ 初期化時のみ直接参照（ランタイムは参照なし）

[GameFlowManager] ──→ BoardSystem3D, PlayerSystem, CardSystem, BattleSystem, SpecialTileSystem
                 ⇢── UIManager（Callable 8個注入 - Phase 10-D）
                 ──→ SpellSystemContainer（spell_container 保持）
                 ⚡←─ ハンドラー群（spell_phase_completed, dice_rolled等）
                 ⇢── ハンドラー群（_is_cpu_player_cb注入）

[BoardSystem3D] ──→ PlayerSystem, CardSystem, BattleSystem, PlayerBuffSystem, SpecialTileSystem
               ──→ SpellLand（直接注入）
               ⇢── GameFlowManager（_trigger_land_curse_cb, _is_game_ended_cb - Phase 10-C）
               ⇢── UIManager（7個の Callable - Phase 10-C）
               ⚡←─ サブシステム群（tile_action_completed, movement_completed等）

[UIManager] ──→ CardSystem, PlayerSystem, BoardSystem3D（表示データ読み取り）
            ──→ GameFlowManager（game_flow_manager_ref: 17UI子が使用）
            ⇢── GameFlowManager（3個の Callable - Phase 10-C）
            ⚡→─ UIEventHub 経由でロジック層にイベント通知

[Handlers群] ⚡→─ GameFlowManager がリスニング（Signal駆動UIパターン）
             ──→ 必要なシステムへの直接参照（GSM が注入）
             ⇢── GameFlowManager（_is_cpu_player_cb - Phase 10-D）

[SpellPhaseHandler] ──→ SpellSystemContainer（spell_systems 保持）
                    ──→ CardSystem, PlayerSystem, BoardSystem3D
                    ⚡→─ UI Signal 9個（GameFlowManager経由でUIに伝達）

[SpellUIManager] ──→ CardSystem, PlayerSystem（表示データ読み取り）
                 ⇢── GameFlowManager（3個の Callable注入）

[CPUSpellAIContainer] ──→ CPUAIContext, CPUSpellAI, CPUMysticArtsAI等
                      ⇢── GameFlowManager（_is_cpu_player_cb注入）

[UIEventHub] ⚡←─ UI Components（hand_card_tapped.emit()等）
             ⚡→─ GameFlowManager（イベント受信）
```

---

## 🎯 各階層の責務定義

### GameSystemManager（Root）

**責務**:
- 全システムの作成（順序指定で `new()` 呼び出し）
- 3フェーズ初期化プロセスの統括
- システム間の相互接続（参照注入）

**ファイル**: `/scripts/system_manager/game_system_manager.gd`

---

### Core Game Systems Tier（ゲームロジック層）

#### BoardSystem3D

**責務**:
- 3Dボードの空間管理
- タイル配置・隣接関係
- プレイヤー移動制御
- クリーチャー配置・管理

**子システム**:
- CreatureManager: クリーチャーデータの SSOT
- TileDataManager: タイル状態管理
- MovementController3D: 移動アニメーション・ロジック
- TileActionProcessor: タイル到着時アクション統括
- TileSummonExecutor/TileBattleExecutor: アクション実行

**シグナル（子→親）**:
- `tile_action_completed()`
- `movement_completed(player_id, tile_index)`
- `invasion_completed(success, tile_index)`
- `level_up_completed(tile_index, new_level)`

**ファイル**: `/scripts/board_system_3d.gd` (1,031行)

---

#### BattleSystem

**責務**:
- 戦闘ロジック（ダメージ計算・勝敗判定）
- スキル処理（86.7%実装）
- 戦闘状態管理

**位置づけ**: Core Game System（独立）
- 理由: 戦闘 ≠ 盤面移動（異なるドメイン）、再利用性、テスタビリティ

**子システム**:
- BattlePreparation: 戦闘準備
- BattleExecution: 戦闘実行
- BattleSkillProcessor: スキル処理
- BattleSpecialEffects: 特殊効果

**シグナル**:
- `invasion_completed(success: bool, tile_index: int)` → TileActionProcessor が受信

**ファイル**: `/scripts/battle_system.gd`

---

#### PlayerSystem

**責務**:
- プレイヤーステータス管理（HP, EP, Gold）
- プレイヤーバフ管理

**子システム**:
- PlayerBuffSystem: バフ・デバフ管理
- MagicStoneSystem: 魔石管理

**ファイル**: `/scripts/player_system.gd`

---

#### CardSystem

**責務**:
- デッキ/手札/捨て札管理
- カードドロー・シャッフル

**ファイル**: `/scripts/card_system.gd`

---

### Game Flow Control Tier（進行制御層）

#### GameFlowManager

**責務**:
- ゲームフェーズ管理（Spell → Dice → Move → Action → End）
- ターン順序管理
- スペルシステムの統括
- ゲーム進行の中央制御

**子システム（ハンドラー群）**:
- SpellPhaseHandler: スペルフェーズ UI・判定
- ItemPhaseHandler: アイテムフェーズ
- DominioCommandHandler: 土地コマンド
- DicePhaseHandler: サイコロロール
- TollPaymentHandler: 通行料処理
- DiscardHandler: 手札破棄
- BankruptcyHandler: 破産処理

**子システム（スペル）**:
- SpellSystemContainer: 10個のスペルシステムを集約

**子システム（状態管理）**:
- LapSystem: 周回管理
- BattleScreenManager: バトル画面制御
- SpecialTileSystem: 特殊タイル管理
- TargetSelectionHelper: スペル対象選択ユーティリティ

**Callable注入（Phase 10-D）**:
```
UI操作をロジック層から呼び出すための Callable 8個:
- _ui_set_phase_text_cb         (フェーズテキスト表示)
- _ui_update_panels_cb           (プレイヤーパネル更新)
- _ui_show_dominio_btn_cb        (ドミニオボタン表示)
- _ui_hide_dominio_btn_cb        (ドミニオボタン非表示)
- _ui_show_surrender_btn_cb      (投降ボタン表示)
- _ui_hide_surrender_btn_cb      (投降ボタン非表示)
- _ui_set_current_turn_cb        (現在のターンプレイヤー設定)
- _ui_show_global_comment_cb     (グローバルコメント表示)
```

**ファイル**: `/scripts/game_flow/game_flow_manager.gd` (739行)

---

#### Spell Phase Handler

**責務**:
- スペルフェーズのロジック制御
- スペル効果の実行
- スペルUI操作（Phase 6～E で Signal化）
- CPU AIの統合（Phase 5-2）

**UISignal化（Phase 6～E）**:
- SpellFlowHandler: 11個のUI Signal
- MysticArtsHandler: 5個のUI Signal
- 計16個のUI Signal → GameFlowManager が接続 → UIManager に伝達

**UI統合管理**:
- SpellUIManager（274行）: スペルUI操作の一元化（Phase 5-1）

**CPU AI統合**:
- CPUSpellAIContainer（79行）: CPU AI参照管理（Phase 5-2）
- CPUSpellPhaseHandler: CPU専用フェーズハンドラー

**ファイル**: `/scripts/game_flow/spell_phase_handler.gd` 他

---

#### 他のフェーズハンドラー

**ItemPhaseHandler**:
- アイテム使用判定
- UI Signal 4個（Phase 8-A）

**DicePhaseHandler**:
- サイコロロール
- UI Signal 8個（Phase 6-B）

**TollPaymentHandler, DiscardHandler, BankruptcyHandler**:
- UI Signal 合計9個（Phase 6-C）
- ほぼ完全な Signal駆動化

---

### Presentation Tier（UI層）

#### UIEventHub

**責務**:
- UI イベント（ユーザーアクション）の中央ハブ
- UI → ロジック層への単方向通信

**Signal（UI → ロジック）**:
- `hand_card_tapped(player_id, card_id)`
- `dominio_cancel_requested()`
- `surrender_requested()`

**ファイル**: `/scripts/ui_components/ui_event_hub.gd`

---

#### UIManager

**責務**:
- UI統括・レイアウト管理
- UI表示/非表示の制御
- UIコンポーネント間の調整

**5つの内部サービス（Phase 8-F）**:
1. **MessageService**: メッセージ・コメント表示
2. **NavigationService**: ナビゲーションボタン管理
3. **CardSelectionService**: カード選択UI管理
4. **InfoPanelService**: 情報パネル（生物・スペル・アイテム）管理
5. **PlayerInfoService**: プレイヤー情報パネル更新（Phase 10-A）

**UI子コンポーネント（15+個）**:
- HandDisplay, PhaseDisplay, CardSelectionUI
- GlobalActionButtons, GlobalCommentUI, DominioOrderUI
- TapTargetManager
- CreatureInfoPanelUI, SpellInfoPanelUI, ItemInfoPanelUI
- PlayerInfoPanel (×4)
- DebugPanel
- BattleScreenManager Components

**Callable注入（Phase 10-C）**:
```
ロジック層 → UI層の操作（UIManager に注入）
- _is_input_locked_cb(player_id)       (入力ロック状態)
- _has_owned_lands_cb()                (所有土地判定)
- _update_tile_display_cb(tile_index)  (タイル表示更新)
```

**参照保持**:
- GameFlowManager（game_flow_manager_ref）: 17個のUI子が参照
- 各 Service 参照

**ファイル**: `/scripts/ui_manager.gd` (922行)

---

## 📐 通信パターンの設計原則

### 原則1: Signal は子→親の方向のみ

```gdscript
# 子システムがイベント発生
signal tile_action_completed()

# 親が受信・処理
func _on_tile_action_completed():
    # 処理
    own_signal.emit()  # 自身の Signal をリレー
```

---

### 原則2: 横断的な接続を避ける（親子チェーン重視）

```gdscript
# ❌ 悪い例（兄弟間の横断接続）
class SpellPhaseHandler:
    var ui_manager: UIManager  # 親の親を直接参照

# ✅ 良い例（親経由のリレー）
class SpellPhaseHandler:
    signal spell_ui_requested()  # Signal emit

# GameFlowManager が接続
spell_phase_handler.spell_ui_requested.connect(ui_manager._on_spell_ui)
```

---

### 原則3: UI操作は Callable 注入（Phase 10-C, 10-D）

```gdscript
# ❌ 古いパターン（直接参照）
class GameFlowManager:
    var ui_manager: UIManager

    func set_phase_text(text):
        ui_manager.set_phase_text(text)  # 直接呼び出し

# ✅ 新パターン（Callable注入）
class GameFlowManager:
    var _ui_set_phase_text_cb: Callable

    func _setup_ui_callbacks():
        _ui_set_phase_text_cb = ui_manager.set_phase_text

    func set_phase_text(text):
        if _ui_set_phase_text_cb:
            _ui_set_phase_text_cb.call(text)  # Callable経由
```

---

## 📋 責務分担マトリックス

| 責務 | GSM | GFM | BS3D | BS | PS | CS | UIM |
|-----|-----|-----|------|-----|-----|-----|-----|
| システム作成 | ✅ | - | - | - | - | - | - |
| 初期化統括 | ✅ | - | - | - | - | - | - |
| フェーズ管理 | - | ✅ | - | - | - | - | - |
| ターン管理 | - | ✅ | - | - | - | - | - |
| スペル統括 | - | ✅ | - | - | - | - | - |
| ボード管理 | - | - | ✅ | - | - | - | - |
| 移動制御 | - | - | ✅ | - | - | - | - |
| タイルアクション | - | - | ✅ | - | - | - | - |
| 戦闘ロジック | - | - | - | ✅ | - | - | - |
| スキル処理 | - | - | - | ✅ | - | - | - |
| プレイヤー状態 | - | - | - | - | ✅ | - | - |
| バフ管理 | - | - | - | - | ✅ | - | - |
| カード管理 | - | - | - | - | - | ✅ | - |
| UI構築・表示 | - | - | - | - | - | - | ✅ |

**凡例**: GSM=GameSystemManager, GFM=GameFlowManager, BS3D=BoardSystem3D, BS=BattleSystem, PS=PlayerSystem, CS=CardSystem, UIM=UIManager

---

## ✅ 完了した改善（Phase 0〜E）

**期間**: 2026-02-13〜2026-02-20

**主要成果**:
- 横断的シグナル接続: 12箇所 → 2箇所（**83%削減**）
- 最大ファイル行数: 1,764行 → ~600行（大幅改善）
- UI Signal 定義: **38個**（Phase 6-8）
- ハンドラーのUI層分離: 7/8完全分離（BankruptcyHandler は部分的）
- UIManager 内部: **5つのサービス**に分割（Phase 8-F）
- ランタイム双方向参照: **ゼロ**（Callable注入により実現）

**Phase別完了項目**:
- Phase 0: ツリー構造定義
- Phase 1: SpellSystemManager 導入（10+2 spell systems 一元化）
- Phase 2: シグナルリレー整備（横断接続 83%削減）
- Phase 3-B: BoardSystem3D SSoT 化
- Phase 3-A: SpellPhaseHandler Strategy パターン化
- Phase 4: SpellPhaseHandler 責務分離
- Phase 5: 段階的最適化（5-1: SpellUIManager 274行、5-2: CPUSpellAIContainer 79行）
- Phase 6: 完全UI層分離（38個の Signal定義）
- Phase 7-A/B: CPU AI パススルー除去 + UI依存逆転
- Phase 8: UIManager 依存方向正規化（5サービス分割）
- Phase 9: 状態ルーター解体
- Phase 10: UIManager 双方向参照削減（Callable注入、Signal追加）

---

## 🎯 成功指標（達成状況）

### 定量的指標

- [x] 最大ファイル行数: 1,764行 → ~600行（改善率: 65%）
- [x] 神オブジェクト数: 3個 → 0個
- [x] 横断的シグナル接続: 12箇所 → 2箇所（削減率: 83%）
- [x] 循環参照: 検出なし
- [x] ランタイム双方向参照: ゼロ（Callable注入で実現）

### 定性的指標

- [x] 新システム追加時に「どこに配置すべきか」が自明
- [x] シグナルフローが親子チェーンで表現可能
- [x] 子システムが親のモックだけでテスト可能
- [x] ツリー図を見れば全体像が理解できる
- [x] UI層が Signal 駆動（直接参照なし）

---

## 📚 関連ドキュメント

- `docs/design/dependency_map.md` - システム依存関係マップ
- `docs/design/CLAUDE.md` - プロジェクト全体ガイド
- `docs/progress/daily_log.md` - 日次作業ログ
- `docs/progress/refactoring_next_steps.md` - 次のアクション計画
- `docs/implementation/signal_catalog.md` - Signal 一覧
- `docs/implementation/delegation_method_catalog.md` - 委譲メソッド一覧

---

**最終更新**: 2026-02-20（Phase 0〜E 完了反映）
