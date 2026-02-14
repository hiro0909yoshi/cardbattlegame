# システム依存関係マップ

**最終更新**: 2026-02-14
**目的**: 現在のシステム依存関係を可視化し、問題のある依存（循環、横断）を特定する

---

## 📊 現在の依存関係（全体図）

### トップレベル（GameSystemManager の子）

```
GameSystemManager
├── SignalRegistry
├── BoardSystem3D ─────┐
├── PlayerSystem       │
├── CardSystem         │
├── BattleSystem ◄─────┼─── TileActionProcessor（孫）が参照
├── PlayerBuffSystem   │
├── SpecialTileSystem  │
├── UIManager ◄────────┼─── BoardSystem3D が参照
├── DebugController    │
└── GameFlowManager ◄──┘     BoardSystem3D が参照
```

### GameFlowManager の依存

```
GameFlowManager
├── 参照（親→兄弟）
│   ├→ BoardSystem3D
│   ├→ BattleSystem
│   ├→ PlayerSystem
│   ├→ CardSystem
│   ├→ UIManager
│   └→ SpecialTileSystem
│
└── 子システム
    ├── SpellContainer（10+個のスペルシステム）
    ├── SpellPhaseHandler
    ├── ItemPhaseHandler
    ├── DominioCommandHandler
    ├── DicePhaseHandler
    ├── TollPaymentHandler
    ├── DiscardHandler
    ├── LapSystem
    ├── BattleScreenManager
    └── (その他)
```

### BoardSystem3D の依存

```
BoardSystem3D
├── 参照（親→兄弟）
│   ├→ PlayerSystem
│   ├→ CardSystem
│   ├→ BattleSystem
│   ├→ PlayerBuffSystem
│   ├→ SpecialTileSystem
│   ├→ UIManager
│   └→ GameFlowManager
│
└── 子システム
    ├── CreatureManager
    ├── TileDataManager
    ├── TileNeighborSystem
    ├── TileInfoDisplay
    ├── MovementController3D
    ├── TileActionProcessor
    └── CPUTurnProcessor
```

---

## 🔴 問題のある依存関係

### 1. 横断的なシグナル接続（12箇所）

#### 問題A: BattleSystem → 各ハンドラー（直接接続）

```
BattleSystem (GameSystemManager の子)
  ├→ DominioCommandHandler (GameFlowManager の子) ❌
  ├→ LandActionHelper (GameFlowManager の子) ❌
  └→ CPUTurnProcessor (BoardSystem3D の子) ❌
```

**問題点**:
- 兄弟システム（BattleSystem）から、別の親の子（ハンドラー）への直接接続
- 実行順序が不定
- デバッグ困難

**該当ファイル**:
- `scripts/game_flow/dominio_command_handler.gd:789`
- `scripts/game_flow/land_action_helper.gd:539`
- `scripts/cpu_ai/cpu_turn_processor.gd:286`

**理想形**:
```
BattleSystem
  └→ TileActionProcessor (子が受信)
      └→ BoardSystem3D (親がリレー)
          └→ GameFlowManager (親の親が受信)
              └→ 各ハンドラー (子が受信)
```

---

#### 問題B: TileActionProcessor → UIManager（直接接続）

```
TileActionProcessor (BoardSystem3D の孫)
  └→ UIManager (GameSystemManager の子) ❌
```

**問題点**:
- 孫システムから、祖父の兄弟システムへの直接接続
- BoardSystem3D、GameFlowManager をスキップ

**該当ファイル**:
- `scripts/tile_action_processor.gd:18` (参照保持)

**理想形**:
```
TileActionProcessor
  └→ BoardSystem3D
      └→ GameFlowManager
          └→ UIManager
```

---

#### 問題C: MovementController → GameFlowManager（直接参照）

```
MovementController3D (BoardSystem3D の子)
  └→ GameFlowManager (BoardSystem3D の兄弟) ❌
```

**問題点**:
- 子システムが親の兄弟を直接参照
- `is_game_ended` 確認のため

**該当ファイル**:
- `scripts/movement_controller.gd:481, 509-511`

**現状**: Phase 1-A で一部 Callable 化済み（line 127, 176）
**残存**: 他の参照が残存

---

### 2. 循環参照の可能性

#### 循環A: BoardSystem3D ↔ GameFlowManager

```
BoardSystem3D
  └→ game_flow_manager (参照保持)
      └→ GameFlowManager
          └→ board_system_3d (参照保持) ⚠️
```

**現状**: 参照の相互保持（循環参照ではないが、依存が複雑）

**該当ファイル**:
- `scripts/board_system_3d.gd:135` (game_flow_manager 参照)
- `scripts/game_flow_manager.gd` (board_system_3d 参照)

**対策**: 既に実装済み（setup_systems() での段階的設定）

---

#### 循環B: BattleSystem ↔ BoardSystem3D

```
BattleSystem
  └→ board_system_ref (参照保持)
      └→ BoardSystem3D
          └→ battle_system (参照保持) ⚠️
```

**現状**: 相互参照（setup 時に注入）

**該当ファイル**:
- `scripts/battle_system.gd:22` (board_system_ref)
- `scripts/board_system_3d.gd:132` (battle_system 参照)

**対策**: 既に実装済み（setup_systems() での段階的設定）

---

### 3. 逆参照（子→親）の残存

#### 逆参照A: TileActionProcessor → GameFlowManager

```
TileActionProcessor (BoardSystem3D の子)
  └→ game_flow_manager (参照保持) ⚠️
```

**用途**: spell_cost_modifier, spell_world_curse 参照

**該当ファイル**:
- `scripts/tile_action_processor.gd:18`

**Phase 1-A の改善**: Callable 化済み（spell_cost_modifier, spell_world_curse は直接参照に変更）

**残存問題**: game_flow_manager 変数自体は残存

---

#### 逆参照B: MovementController → GameFlowManager

```
MovementController3D (BoardSystem3D の子)
  └→ game_flow_manager (参照保持) ⚠️
```

**用途**: is_game_ended 確認

**該当ファイル**:
- `scripts/movement_controller.gd:28`

**Phase 1-A の改善**: 一部 Callable 化済み

---

### 4. スペルシステムの参照の複雑性

#### 問題: 多数のシステムが SpellContainer に直接アクセス

```
GameFlowManager.spell_container
  ├← SpellPhaseHandler
  ├← ItemPhaseHandler
  ├← TileActionProcessor (spell_cost_modifier 等)
  ├← BattleSystem (spell_draw, spell_magic)
  ├← DominioCommandHandler
  └← (その他5+箇所)
```

**問題点**:
- SpellContainer の責務が不明確
- GameFlowManager が SpellContainer を直接保持（階層が浅い）

**理想形（Phase 1 で実装予定）**:
```
GameFlowManager
  └→ SpellSystemManager (新規)
      └→ SpellSystemContainer
```

---

## 🟢 適切な依存関係（参考例）

### 例1: PlayerSystem ← 各システム

```
PlayerSystem (独立したコアシステム)
  ←─ GameFlowManager（兄弟システムから参照）✅
  ←─ BoardSystem3D（兄弟システムから参照）✅
  ←─ BattleSystem（兄弟システムから参照）✅
```

**評価**: ✅ 適切
- PlayerSystem は状態管理のみ（副作用なし）
- 他システムが参照するのは自然

---

### 例2: CardSystem ← 各システム

```
CardSystem (独立したコアシステム)
  ←─ GameFlowManager（カードドロー）✅
  ←─ BattleSystem（カード取得）✅
  ←─ TileActionProcessor（召喚時カード選択）✅
```

**評価**: ✅ 適切
- CardSystem は状態管理のみ
- 他システムが参照するのは自然

---

### 例3: TileActionProcessor → 親（BoardSystem3D）

```
TileActionProcessor
  └→ action_completed シグナル
      └→ BoardSystem3D._on_action_completed() ✅
```

**評価**: ✅ 適切
- 子→親のシグナル接続（標準パターン）

---

## 📈 依存関係の分類

### 適切な依存（維持すべき）

| 依存元 | 依存先 | 種類 | 評価 |
|--------|--------|------|------|
| GameFlowManager | PlayerSystem | 参照 | ✅ |
| GameFlowManager | CardSystem | 参照 | ✅ |
| GameFlowManager | BoardSystem3D | 参照 | ✅ |
| BoardSystem3D | PlayerSystem | 参照 | ✅ |
| BattleSystem | PlayerSystem | 参照 | ✅ |
| TileActionProcessor | BoardSystem3D | シグナル（子→親）| ✅ |
| MovementController | BoardSystem3D | シグナル（子→親）| ✅ |

---

### 問題のある依存（改善すべき）

| 依存元 | 依存先 | 種類 | 問題 | Phase |
|--------|--------|------|------|-------|
| BattleSystem | DominioCommandHandler | シグナル | 横断的接続 | Phase 2 |
| BattleSystem | CPUTurnProcessor | シグナル | 横断的接続 | Phase 2 |
| TileActionProcessor | UIManager | 参照 | スキップ接続 | Phase 2 |
| TileActionProcessor | GameFlowManager | 参照 | 逆参照（残存）| Phase 1 |
| MovementController | GameFlowManager | 参照 | 逆参照（残存）| Phase 1 |
| SpellPhaseHandler | 5+システム | 参照 | 多重依存 | Phase 1 |

---

## 🎯 改善の優先順位

### P0（最優先）: Phase 1

**目的**: スペルシステムの階層化

**対象**:
- SpellSystemManager 導入
- GameFlowManager の子として配置
- SpellContainer の責務明確化

**効果**:
- スペルシステムの参照が明確化
- 10+個のスペルシステムが統一的に管理される

---

### P1（高優先）: Phase 2

**目的**: シグナルリレーの確立

**対象**:
- BattleSystem → TileActionProcessor → BoardSystem3D のリレー
- TileActionProcessor → BoardSystem3D → GameFlowManager のリレー
- 横断的シグナル接続の削減（12箇所 → 0箇所）

**効果**:
- シグナルフローが一本の親子チェーンに統一
- デバッグ容易性の向上

---

### P2（中優先）: Phase 3

**目的**: UIManager 責務分離

**対象**:
- HandUIController, BattleUIController, DominioUIController への分離
- UIManager: 1,069行 → 300行

**効果**:
- UI変更時の影響範囲限定
- テスト容易性の向上

---

## 📊 依存関係メトリクス

### 現状

| メトリクス | 値 | 評価 |
|-----------|-----|------|
| 横断的シグナル接続 | 12箇所 | 🔴 高 |
| 逆参照（子→親） | 5箇所（一部改善済み）| 🟡 中 |
| 循環参照 | 0箇所 | 🟢 低 |
| 最大依存数（1システムあたり） | 7個（GameFlowManager）| 🟡 中 |
| 最大ファイル行数 | 1,764行（SpellPhaseHandler）| 🔴 高 |

### 目標（Phase 1-3 完了後）

| メトリクス | 目標値 | 改善率 |
|-----------|--------|--------|
| 横断的シグナル接続 | 0箇所 | 100% |
| 逆参照（子→親） | 0箇所 | 100% |
| 循環参照 | 0箇所 | - |
| 最大依存数 | 5個以下 | 29% |
| 最大ファイル行数 | 400行以下 | 77% |

---

## 🔗 関連ドキュメント

- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造
- `docs/progress/architecture_migration_plan.md` - 移行計画詳細
- `docs/progress/signal_cleanup_work.md` - シグナル改善計画
- `docs/design/god_object_quick_reference.md` - 神オブジェクト分析

---

**最終更新**: 2026-02-14
**次のアクション**: architecture_migration_plan.md を作成し、Phase 1 の詳細計画を立案
