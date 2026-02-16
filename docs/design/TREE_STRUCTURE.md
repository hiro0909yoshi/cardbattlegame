# システムツリー構造定義

**最終更新**: 2026-02-16 (Phase 5-1, 5-2 追加)
**目的**: ゲームシステムの理想的な階層構造を定義し、保守性・拡張性・テスタビリティを向上させる

---

## 📊 理想的なツリー構造（全体図）

```
GameSystemManager (Root: ライフサイクル管理)
│
├─ [Core Game Systems Tier] ← ゲームロジック層
│  │
│  ├── BoardSystem3D (3D盤面・プレイヤー移動)
│  │   ├── CreatureManager
│  │   ├── TileDataManager
│  │   ├── TileNeighborSystem
│  │   ├── TileInfoDisplay
│  │   ├── MovementController3D
│  │   │   └── MovementHelper
│  │   ├── TileActionProcessor
│  │   │   ├── TileSummonExecutor (RefCounted)
│  │   │   └── TileBattleExecutor (RefCounted)
│  │   └── CPUTurnProcessor
│  │
│  ├── PlayerSystem (プレイヤー状態管理)
│  │   ├── PlayerBuffSystem
│  │   └── MagicStoneSystem
│  │
│  ├── CardSystem (カード管理)
│  │   └── [CardLoader - Autoload]
│  │
│  └── BattleSystem (戦闘エンジン)
│      ├── BattlePreparation
│      ├── BattleExecution
│      ├── BattleSkillProcessor
│      └── BattleSpecialEffects
│
├─ [Game Flow Control Tier] ← 進行制御層
│  │
│  └── GameFlowManager (ターン管理・フェーズ制御)
│      │
│      ├── [Game Flow Handlers]
│      │   ├── SpellPhaseHandler
│      │   │   ├── SpellUIManager (Phase 5-1) ← UI統合管理
│      │   │   └── CPUSpellAIContainer (Phase 5-2) ← CPU AI参照統合
│      │   ├── ItemPhaseHandler
│      │   ├── DominioCommandHandler
│      │   ├── DicePhaseHandler
│      │   ├── TollPaymentHandler
│      │   ├── DiscardHandler
│      │   └── TargetSelectionHelper
│      │
│      ├── [Spell System] ← Phase 1 で導入予定
│      │   └── SpellSystemManager (新規)
│      │       └── SpellSystemContainer
│      │           ├── SpellDraw
│      │           ├── SpellMagic
│      │           ├── SpellLand
│      │           ├── SpellCurse
│      │           ├── SpellDice
│      │           ├── SpellCurseStat
│      │           ├── SpellWorldCurse
│      │           ├── SpellPlayerMove
│      │           ├── SpellCurseToll
│      │           └── SpellCostModifier
│      │
│      ├── [Game State Management]
│      │   ├── LapSystem
│      │   ├── BattleScreenManager
│      │   ├── BankruptcyHandler
│      │   └── CPUMovementEvaluator
│      │
│      └── [Special Systems]
│          ├── SpecialTileSystem
│          ├── GameFlowStateMachine
│          └── game_stats (Dictionary)
│
├─ [Presentation Tier] ← UI層
│  │
│  └── UIManager (UI統括)
│      ├── HandDisplay
│      ├── PhaseDisplay
│      ├── CardSelectionUI
│      ├── LevelUpUI
│      ├── DebugPanel
│      ├── PlayerInfoPanel
│      ├── CreatureInfoPanelUI
│      ├── SpellInfoPanelUI
│      ├── ItemInfoPanelUI
│      ├── DominioOrderUI
│      ├── BattleScreen Components (7+)
│      └── (その他UI)
│
├─ [Support Systems] ← サポート層
│  │
│  ├── CameraController
│  ├── DebugController
│  ├── SignalRegistry
│  │
│  └── [CPU AI Systems]
│      ├── CPUAIContext (共有コンテキスト)
│      ├── CPUBattleAI
│      ├── CPUSpellAI
│      ├── CPUMovementEvaluator
│      ├── CPUHandUtils
│      └── CPUSpecialTileAI
│
└─ [Autoload Singletons]
   ├── CardLoader
   ├── GameData
   ├── DebugSettings
   └── GameConstants
```

---

## 🎯 各階層の責務定義

### GameSystemManager (Root)

**責務**:
- 全システムの作成（`new()` 呼び出し）
- 6フェーズ初期化プロセスの統括
- システム間の相互接続（参照注入）
- シーン遷移時のセットアップ

**非責務**:
- ❌ ゲーム進行制御（→ GameFlowManager）
- ❌ UI管理（→ UIManager）
- ❌ 戦闘ロジック（→ BattleSystem）

**ファイル**: `scripts/system_manager/game_system_manager.gd`

---

### Core Game Systems Tier

#### BoardSystem3D

**責務**:
- 3Dボードの空間管理
- タイル配置・隣接関係
- プレイヤー移動制御
- クリーチャー配置管理

**子システム**:
- CreatureManager: クリーチャーデータの SSOT
- TileDataManager: タイルデータ管理
- MovementController3D: 移動ロジック
- TileActionProcessor: タイル到着時アクション

**シグナル（子→親）**:
```gdscript
# 子システムのシグナルをリレー
signal tile_action_completed()
signal movement_completed(player_id, tile_index)
signal invasion_completed(success, tile_index)  # Phase 2-A で追加
signal level_up_completed(tile_index, new_level)
```

**ファイル**: `scripts/board_system_3d.gd` (1,031行)

---

#### BattleSystem

**責務**:
- 戦闘ロジック（誰が勝つか）
- スキル処理（86.7%実装済み）
- ダメージ計算
- 戦闘結果の判定

**位置づけ**: **独立したCore Game System**（BoardSystem3D の子ではない）

**理由**:
1. 責務の明確性: 戦闘 ≠ 盤面移動（異なるドメイン）
2. 再利用性: BattleSystem 単独でテスト可能（バトルテストツール等）
3. テスタビリティ: BoardSystem3D の複雑性に左右されない
4. 循環依存の回避: TileActionProcessor → BattleSystem（一方向）

**子システム**:
- BattlePreparation: 戦闘準備
- BattleExecution: 戦闘実行
- BattleSkillProcessor: スキル処理
- BattleSpecialEffects: 特殊効果

**シグナル（自身→外部）**:
```gdscript
signal invasion_completed(success: bool, tile_index: int)
# → TileActionProcessor が受信
# → BoardSystem3D がリレー（Phase 2-A）
# → GameFlowManager が受信
```

**ファイル**: `scripts/battle_system.gd`

---

#### PlayerSystem

**責務**:
- プレイヤーステータス管理（HP, EP, G）
- プレイヤーバフ管理
- 破産判定

**子システム**:
- PlayerBuffSystem: バフ・デバフ管理
- MagicStoneSystem: 魔石管理（将来）

**ファイル**: `scripts/player_system.gd`

---

#### CardSystem

**責務**:
- デッキ/手札/捨て札管理
- カードドロー
- カードシャッフル

**依存**: CardLoader (Autoload)

**ファイル**: `scripts/card_system.gd`

---

### Game Flow Control Tier

#### GameFlowManager

**責務**:
- ゲームフェーズ管理（Spell → Dice → Move → Action → End）
- ターン順序管理
- スペルシステムの統括（SpellSystemManager への参照）
- ゲーム進行の中央制御

**子システム（ハンドラー群）**:
- SpellPhaseHandler: スペルフェーズUI・判定
- ItemPhaseHandler: アイテムフェーズ
- DominioCommandHandler: 土地コマンド（レベルアップ等）
- DicePhaseHandler: サイコロロール
- TollPaymentHandler: 通行料処理
- DiscardHandler: 手札破棄

**子システム（スペル）**:
- SpellSystemManager: スペルシステム統括（Phase 1 で導入予定）
  - SpellSystemContainer: 10+個のスペルシステムを集約

**子システム（状態管理）**:
- LapSystem: 周回管理
- BattleScreenManager: バトル画面制御
- BankruptcyHandler: 破産処理

**非責務**:
- ❌ UI構築（→ UIManager）
- ❌ スペル実行詳細（→ SpellPhaseHandler）
- ❌ 戦闘ロジック（→ BattleSystem）

**ファイル**: `scripts/game_flow_manager.gd` (739行)

---

### Presentation Tier

#### UIManager

**責務**:
- UI統括・レイアウト管理
- UI表示/非表示の制御
- UIコンポーネント間の調整

**子システム（7+個）**:
- HandDisplay: 手札表示
- PhaseDisplay: フェーズ表示
- CardSelectionUI: カード選択
- LevelUpUI: レベルアップUI
- DebugPanel: デバッグパネル
- PlayerInfoPanel: プレイヤー情報
- BattleScreen Components: バトル画面

**将来の改善（Phase 3）**:
```gdscript
# 責務分離後の構造
UIManager (300行に削減)
├── HandUIController
├── BattleUIController
└── DominioUIController
```

**ファイル**: `scripts/ui_manager.gd` (1,069行 → Phase 3 で 300行に削減予定)

---

## 📐 シグナルフローの設計原則

### 原則1: シグナルは子→親の方向へ

```
子システム (イベント発生)
  ↓ signal.emit()
親システム (受信・処理)
  ↓ 自身のシグナルを emit (リレー)
親の親システム (受信)
```

### 原則2: 横断的な接続を避ける

```
❌ 悪い例（横断的）
BattleSystem (兄弟)
  └→ DominioCommandHandler (別の親の子)

✅ 良い例（親子チェーン）
BattleSystem
  └→ TileActionProcessor (子が受信)
	  └→ BoardSystem3D (親がリレー)
		  └→ GameFlowManager (親の親が受信)
			  └→ DominioCommandHandler (子が受信)
```

### 原則3: 一本のシグナルチェーン

```
理想的な invasion_completed のフロー:

BattleSystem.invasion_completed.emit(success, tile_index)
  ↓
TileActionProcessor._on_invasion_completed(success, tile_index)
  [処理: タイル状態更新]
  action_completed.emit()  # 自身のシグナル
  ↓
BoardSystem3D._on_action_completed()
  [処理: ボード状態更新]
  tile_action_completed.emit()  # 自身のシグナル
  ↓
GameFlowManager._on_tile_action_completed_3d()
  [処理: ターン終了判定]
  end_turn() → turn_ended.emit()
  ↓
UIManager.on_turn_ended()
  [処理: UI更新]
```

---

## 🔄 依存関係の原則

### 原則1: 依存は親→子のみ

```gdscript
# ✅ 良い例（親が子を所有・参照）
class GameFlowManager:
	var spell_system_manager: SpellSystemManager  # 子への参照

# ❌ 悪い例（子が親を参照）
class SpellSystemManager:
	var game_flow_manager: GameFlowManager  # 逆依存
```

### 原則2: 兄弟システム間は間接的に参照

```gdscript
# ✅ 良い例（親経由で参照）
class TileActionProcessor:
	var battle_system: BattleSystem  # 親が注入

# setup時
tile_action_processor.setup(battle_system, ...)  # 親が設定

# ❌ 悪い例（直接取得）
var battle_system = get_node("/root/GameSystemManager/BattleSystem")
```

### 原則3: 参照注入（Dependency Injection）

```gdscript
# ✅ 推奨パターン
func setup_systems(p_system, c_system, b_system):
	player_system = p_system
	card_system = c_system
	battle_system = b_system

# ❌ 非推奨（get_parent 等）
var parent = get_parent()
var battle_system = parent.battle_system  # 脆い
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

**凡例**:
- GSM: GameSystemManager
- GFM: GameFlowManager
- BS3D: BoardSystem3D
- BS: BattleSystem
- PS: PlayerSystem
- CS: CardSystem
- UIM: UIManager

---

## 🚀 段階的移行計画（サマリー）

| Phase | 内容 | 工数 | リスク | 状態 |
|-------|------|------|--------|------|
| **Phase 0** | ツリー構造定義 | 1日 | 低 | 🔵 進行中 |
| **Phase 1** | SpellSystemManager 導入 | 2日 | 中 | ⚪ 未着手 |
| **Phase 2** | シグナルリレー整備 | 3日 | 中 | ⚪ 未着手 |
| **Phase 3** | UIManager 責務分離 | 4-5日 | 高 | ⚪ 未着手 |
| **Phase 4** | テスト・ドキュメント | 2日 | 低 | ⚪ 未着手 |

詳細は `docs/progress/architecture_migration_plan.md` を参照

---

## 🎯 成功指標

### 定量的指標

- [ ] 最大ファイル行数: 1,764行 → 400行以下
- [ ] 神オブジェクト数: 3個 → 0個
- [ ] 横断的シグナル接続: 12箇所 → 0箇所
- [ ] 循環依存: 検出なし

### 定性的指標

- [ ] 新システム追加時に「どこに配置すべきか」が自明
- [ ] シグナルフローが一本の親子チェーンで表現可能
- [ ] 子システムが親のモックだけでテスト可能
- [ ] ツリー図を見れば全体像が理解できる

---

## 📚 関連ドキュメント

- `docs/design/dependency_map.md` - システム依存関係マップ（Phase 0 で作成予定）
- `docs/progress/architecture_migration_plan.md` - 移行計画詳細（Phase 0 で作成予定）
- `docs/progress/signal_cleanup_work.md` - シグナル改善計画
- `docs/design/god_object_quick_reference.md` - 神オブジェクト分析
- `CLAUDE.md` - プロジェクト全体ガイド

---

**最終更新**: 2026-02-14
**次のアクション**: Phase 0 完了後、Phase 1（SpellSystemManager 導入）に着手
