# GameSystemManager 実装前の分析（2025-11-22）

## 1. システム作成方法の現状

### game_3d.gd での作成方法
- **基本**: `System.new()` → `add_child(system)` で直接作成
- **例外**: BoardSystem3D は `load("res://scripts/board_system_3d.gd")` で動的ロード
- **パターン**:
  ```gdscript
  var signal_registry = SignalRegistry.new()
  add_child(signal_registry)
  
  var board_system_3d = BoardSystem3DClass.new()
  add_child(board_system_3d)
  ```

### GameFlowManager での作成方法
- **_ready() 内**: CPUAIHandler を `new()` で作成
  ```gdscript
  cpu_ai_handler = CPUAIHandler.new()
  add_child(cpu_ai_handler)
  ```
- **_setup_spell_systems() 内**: SpellDraw, SpellMagic, SpellLand, SpellCurse, SpellDice, SpellCurseStat を作成
  ```gdscript
  spell_draw = SpellDraw.new()
  spell_draw.setup(card_system)
  ```

### BoardSystem3D での作成方法
- **_ready() 内**:
  - `create_creature_manager()` で CreatureManager を作成
  - `create_subsystems()` で TileInfoDisplay, MovementController3D, TileDataManager, TileNeighborSystem, TileActionProcessor, CPUTurnProcessor を作成
- **CPUTurnProcessor**: 動的ロード
  ```gdscript
  var CPUTurnProcessorClass = load("res://scripts/flow_handlers/cpu_turn_processor.gd")
  cpu_turn_processor = CPUTurnProcessorClass.new()
  add_child(cpu_turn_processor)
  ```

## 2. CreatureManager と TileDataManager の位置関係

### CreatureManager
- **作成場所**: BoardSystem3D._ready() → create_creature_manager()
- **管理**: BoardSystem3D の子ノード（`add_child()` で追加）
- **アクセス方法**: 
  - BaseTile.creature_manager（静的参照）
  - board_system.get_node_or_null("CreatureManager")
- **タイミング**: BoardSystem3D._ready() の最初で作成（他のサブシステム前）
- **使用箇所**: 
  - GameFlowManager._setup_spell_systems() 内で SpellLand, SpellCurse が参照
  - ```gdscript
    var creature_manager = board_system.get_node_or_null("CreatureManager")
    ```

### TileDataManager
- **作成場所**: BoardSystem3D._ready() → create_subsystems() 内で作成
- **管理**: BoardSystem3D の子ノード
- **初期化**: 動的に自動初期化される（setup() 等の明示的な呼び出しなし）
- **アクセス**: tile_data_manager インスタンス変数経由

## 3. 初期化の依存関係

### Phase 順序の必須条件

**Tier 1: game_3d 作成時点で必須**
```
1. SignalRegistry
2. BoardSystem3D ← 内部で CreatureManager, TileDataManager 等を自動作成
3. PlayerSystem
4. CardSystem
5. BattleSystem
6. PlayerBuffSystem
7. SpecialTileSystem
8. UIManager
9. DebugController
10. GameFlowManager ← 内部で CPUAIHandler, SpellSystems 等を自動作成
```

### GameFlowManager の内部初期化（setup_systems 内）

**_setup_spell_systems() が自動実行される**（setup_systems 呼び出し時）:
- SpellDraw → card_system 必須
- SpellMagic → player_system 必須
- SpellLand → board_system, creature_manager, player_system, card_system 必須
- SpellCurse → board_system, creature_manager, player_system 必須
- SpellDice → player_system, spell_curse 必須
- SpellCurseStat → spell_curse, creature_manager 必須

**initialize_phase1a_systems() が別途実行される**:
- PhaseManager 作成
- LandCommandHandler 作成・初期化
- SpellPhaseHandler 作成・初期化
- ItemPhaseHandler 作成・初期化

### BoardSystem3D の内部初期化

**_ready() で自動実行**:
1. create_creature_manager() → CreatureManager 作成
2. create_subsystems():
   - TileInfoDisplay
   - MovementController3D
   - TileDataManager
   - TileNeighborSystem
   - TileActionProcessor
   - CPUTurnProcessor

**setup_systems() で参照設定**:
- setup_cpu_ai_handler()
- tile_action_processor.setup()
- cpu_turn_processor.setup()（推定）

## 4. GameSystemManager の設計への影響

### 重要な発見

1. **BoardSystem3D と GameFlowManager は _ready() で自動初期化する**
   - これらを new() して add_child() するだけで、子システムが自動で生成される
   - GameSystemManager は「参照設定」に専念すれば良い

2. **create_creature_manager() は BoardSystem3D._ready() の最初で実行**
   - CreatureManager は board_system._ready() の時点で既に存在
   - GameFlowManager._setup_spell_systems() が実行される時には、既に creature_manager は利用可能

3. **add_child() のタイミングが重要**
   - add_child() 直後に _ready() が呼ばれる
   - GameSystemManager が system.new() してから add_child() すると、_ready() が自動実行される

4. **setup_systems() は _ready() 後に呼ぶ必要がある**
   - BoardSystem3D._ready() で子システムが作成される
   - setup_systems() で参照を設定する

## 5. GameSystemManager の実装戦略

### 推奨パターン

```
Phase 1: システム作成
  → new() して add_child() する
  → _ready() が自動実行される
  → 子システムも自動作成される

Phase 2: 3D ノード収集
  → ゲームシーンのノードを収集

Phase 3: システム基本設定
  → 単純なプロパティ設定（player_count など）
  → collect_tiles(), initialize_players() など

Phase 4: システム間連携設定
  → setup_systems() を呼ぶ
  → 参照を相互に設定

Phase 5: シグナル接続
  → シグナル接続

Phase 6: ゲーム開始準備
  → 初期手札配布など
```

## 6. 質問への回答

### Q1: add_child() の必要性
**推奨**: add_child() する
- 理由:
  - _ready() が自動実行され、子システムが初期化される
  - シーンツリーに登録されるため、デバッグが容易
  - Godot の標準パターン

### Q2: ファイルパス確認の必要性
**確認済み**: 不要（ほぼ完成している）
- SignalRegistry: クラス名で load() 可能（推定）
- BoardSystem3D: `load("res://scripts/board_system_3d.gd")` で確認済み
- 他システム: クラス名で new() 可能（既にコード内で使用されている）

### Q3: CreatureManager, TileDataManager
**確認結果**:
- 両者とも BoardSystem3D の内部で _ready() 時に自動作成される
- GameSystemManager は直接操作しない
- 参照は board_system.get_node_or_null("CreatureManager") で取得可能

### Q4: ゲーム起動テスト
**確認対象**:
1. ログ出力で全フェーズ実行確認（[GameSystemManager] Phase X: ...)
2. ゲーム画面が表示される
3. ダイスボタンが有効
4. CPU AI が正常に動作
