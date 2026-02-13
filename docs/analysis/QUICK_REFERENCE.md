# 神オブジェクト分析 クイックリファレンス

## 🔴 重度な神オブジェクト（即座の対応が必要）

### 1. SpellPhaseHandler - **最優先**
```
行数:      1,764行（最大）
責務:      11個以上
被依存:    60+箇所
メソッド:  80個
スコア:    64点
```

**問題点**:
- スペル処理の一極集中
- スペル追加時にこのファイルを毎回修正
- テストが困難（30+の外部依存）

**改善案**:
```gdscript
// 現在の構造
if spell_type == "fireball":
  execute_fireball()
elif spell_type == "freeze":
  execute_freeze()
// ...50+ lines of if/elif

// 理想形（Strategy パターン）
var strategy = SpellStrategyFactory.create(spell_type)
return strategy.execute(context)

// ファイル構成
spell_strategy.gd          // Interface
fireball_strategy.gd       // Concrete
freeze_strategy.gd         // Concrete
spell_strategy_factory.gd  // Factory
spell_phase_handler.gd     // Simplified dispatcher
```

**期待効果**:
- SpellPhaseHandler: 1,764 → 400行（77%削減）
- スペル追加: SpellPhaseHandler 不要（新Strategy のみ）
- ユニットテスト: 各Strategy を独立テスト可能

**実装時間**: 4-5日

---

### 2. UIManager
```
行数:      1,069行
責務:      10+個
被依存:    89箇所（最多）
メソッド:  93個（最多）
スコア:    66点
```

**問題点**:
- UI全体の中央管理化
- 新UI追加時に UIManager も修正（結合度高）
- ナビゲーション状態管理が複雑

**改善案**:
```gdscript
// 現在：全UI管理が UIManager に集約
class UIManager:
  func show_hand_display()
  func show_battle_screen()
  func show_dominio_ui()
  // ...93メソッド

// 理想形：各UI領域を独立Controller化
class HandUIController:
  func show(): ...
  func update(): ...

class BattleUIController:
  func show_screen(): ...
  func update_hp(): ...

class UIManager:
  var hand_ui: HandUIController
  var battle_ui: BattleUIController
  // Controllers を登録・管理するのみ
```

**期待効果**:
- UIManager: 1,069 → 300行（72%削減）
- UI追加時: UIManager 変更不要（新Controller追加のみ）
- 責務明確化: 各UI領域の変更が隔離

**実装時間**: 3-4日

---

### 3. BoardSystem3D
```
行数:      1,031行
責務:      12+個
被依存:    82箇所
メソッド:  111個（最多）
スコア:    63点
```

**問題点**:
- `creature_data` が3箇所に存在
  - CreatureManager.creatures[tile_index]
  - BaseTile.creature_data
  - TileDataManager.tile_data[tile_index]
- メソッド数が多い（111個中60+が委譲メソッド）
- 委譲パターンと直接参照が混在

**改善案**:

```gdscript
// 現在：データが複数箇所に分散
class BaseTile:
  var creature_data: Dictionary

class TileDataManager:
  var tile_data: Dictionary  // tile_index -> {creature_data, ...}

class CreatureManager:
  var creatures: Dictionary  // tile_index -> creature_data

// 理想形：Single Source of Truth
class CreatureManager:
  var creatures: Dictionary = {}  // 唯一の source

class BaseTile:
  var creature_manager: CreatureManager

  var creature_data: Dictionary:
    get: return creature_manager.get_creature(tile_index)  // Read-only
    set(value):
      creature_manager.set_creature(tile_index, value)

// 変更通知をシグナル化
func _on_creature_changed(tile_index, new_data):
  # TileDataManager, UI が自動更新
  tile_data_manager.on_creature_changed(tile_index)
```

**期待効果**:
- データ整合性バグ根絶
- 同期処理の自動化（シグナル経由）
- デバッグ時間短縮（source が1つ）

**実装時間**: 2-3日

---

## 🟡 中度な神オブジェクト（短期対応）

### 4. DominioCommandHandler
```
行数:      1,227行
責務:      9個
被依存:    50+箇所
メソッド:  73個
スコア:    58点
```

**問題点**:
- 7つの State enum で複雑性が高い
- 各State で処理が大きく異なる
- アクション実行とUI制御が混在

**改善案**: Command/Strategy パターン
```gdscript
// 各アクションを独立Command化
class LevelUpCommand:
  func execute(board_state): ...

class MoveCommand:
  func execute(board_state): ...

class SwapCommand:
  func execute(board_state): ...

class DominioCommandHandler:
  var commands = {
    "level_up": LevelUpCommand.new(),
    "move": MoveCommand.new(),
    "swap": SwapCommand.new()
  }

  func execute_action(action_type):
    return commands[action_type].execute(board_state)
```

**期待効果**:
- DominioCommandHandler: 1,227 → 500行（60%削減）
- アクション追加: 新Command作成のみ

**実装時間**: 3-4日

---

### 5. GameFlowManager
```
行数:      739行
責務:      8個
被依存:    80箇所（最多）
メソッド:  43個
スコア:    56点
```

**問題点**:
- 参照ハブ化（80箇所から参照）
- `game_flow_manager.board_system_3d.tile_action_processor` のようなチェーンアクセス
- State Machine と current_phase の二重管理

**改善案**:
```gdscript
// 直接参照を増やし、チェーンを減らす
class GameFlowManager:
  # 必要な参照のみ保持
  var tile_action_processor: TileActionProcessor
  var spell_phase_handler: SpellPhaseHandler

  # 委譲メソッドで簡潔化
  func on_level_up_selected(target_level, cost):
    tile_action_processor.process_level_up(target_level, cost)
```

**期待効果**:
- チェーンアクセスの廃止
- 呼び出し側のコード簡潔化

**実装時間**: 2日

---

## 📊 改善による変化

### Before: 神オブジェクト構造
```
[User Code]
    ↓
[GameFlowManager] ← central hub (80 依存元)
    ├─→ [UIManager] (93メソッド)
    ├─→ [BoardSystem3D] (111メソッド)
    ├─→ [SpellPhaseHandler] (80メソッド)
    ├─→ [DominioCommandHandler] (73メソッド)
    └─→ ...
```

### After: 責務分離構造
```
[User Code]
    ├─→ [UIState Controller]
    │   ├─→ [HandUIController]
    │   ├─→ [BattleUIController]
    │   └─→ [DominioUIController]
    │
    ├─→ [SpellExecutor]
    │   ├─→ [FireballStrategy]
    │   ├─→ [FreezeStrategy]
    │   └─→ [SpellStrategyFactory]
    │
    ├─→ [GameBoard]
    │   ├─→ [TileGrid]
    │   ├─→ [CreatureLayer]
    │   └─→ [MovementSystem]
    │
    └─→ [GameFlowManager] (simplified)
```

---

## 🚀 実装ロードマップ

### Week 1: SpellPhaseHandler Strategy パターン
```
Mon-Tue:  SpellStrategy インターフェース & Factory
Wed-Thu:  既存スペルを Strategy に移行（Fireball, Freeze, ...）
Fri:      テスト・デバッグ
```

### Week 2: UIManager 責務分離
```
Mon-Tue:  各UIController 実装
Wed:      既存参照を Controller に置き換え
Thu-Fri:  テスト・デバッグ
```

### Week 3: BoardSystem3D SSoT 確立
```
Mon:      CreatureManager を source に統一
Tue-Wed:  シグナルチェーン構築
Thu-Fri:  同期テスト
```

### Week 4: 統合テスト・リファクタリング
```
Mon-Fri:  全体統合テスト・微調整
```

---

## ✅ 成功指標

### コード品質
- [ ] 神オブジェクト数: 3個 → 0個
- [ ] 最大ファイル行数: 1,764 → 400行以下
- [ ] 平均メソッド数/ファイル: 20-30個以下

### 開発効率
- [ ] スペル追加時間: 3-5日 → 1-2日
- [ ] バグ特定時間: 1週間 → 1-2日
- [ ] UI修正時間: 2-3日 → 1日

### テスト
- [ ] ユニットテスト実装: 20% → 60%
- [ ] テスト実行時間: < 5分
- [ ] カバレッジ: 各責務ごとに 80%以上

---

## 🔗 関連リソース

- **詳細分析**: `docs/analysis/god_object_analysis.md`
- **改善ロードマップ**: `docs/analysis/IMPROVEMENT_ROADMAP.md`
- **実装パターン**: `docs/implementation/implementation_patterns.md`
- **設計ドキュメント**: `docs/design/design.md`

---

## 💡 Key Takeaway

**神オブジェクト問題は、段階的なコンポーネント化で解決可能**

1. **最優先（4-5日）**: SpellPhaseHandler を Strategy パターン化
   - 即座に開発効率が向上
   - スペル追加が容易化

2. **短期（3-4日）**: UIManager を責務分離
   - UI追加が容易化
   - 変更範囲が限定化

3. **中期（2-3日）**: BoardSystem3D を SSoT 化
   - データ整合性バグ根絶
   - テスト改善

**総工期**: 1-2週間で大幅改善が可能

