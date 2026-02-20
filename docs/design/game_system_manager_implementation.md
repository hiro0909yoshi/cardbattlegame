# GameSystemManager 実装ドキュメント

## 概要

**GameSystemManager** は、ゲーム初期化の複雑なプロセスを **6つのフェーズ** に整理し、すべてのゲームシステムの作成・初期化・連携を一元管理するシステムです。

### 目的

- **初期化の一元化**: ゲーム開始時のシステム作成と初期化を game_3d.gd から分離
- **依存関係の明確化**: システム間の初期化順序を明示的に制御
- **保守性向上**: 初期化ロジックの変更が容易で、トラブルシューティングが簡単
- **スケーラビリティ**: 新規システム追加時に初期化フローを拡張しやすい

**実装ファイル**: `scripts/system_manager/game_system_manager.gd`

---

## game_3d.gd の役割

game_3d.gd は GameSystemManager の呼び出し元であり、以下のみを行う：

```gdscript
func _ready():
    # 1. StageLoader でステージ読み込み
    stage_loader = StageLoader.new()
    add_child(stage_loader)
    var stage_data = stage_loader.load_stage(stage_id)

    # 2. 3Dシーンを事前構築（Tiles/Players/Camera）
    _setup_3d_scene_before_init()

    # 3. GameSystemManager 初期化
    system_manager = GameSystemManager.new()
    add_child(system_manager)
    system_manager.initialize_all(self, player_count, player_is_cpu, debug_manual_control_all)

    # 4. ステージ固有設定
    _apply_stage_settings()

    # 5. チュートリアル初期化（該当時のみ）
    if is_tutorial_mode:
        _setup_tutorial()

    # 6. ゲーム開始
    system_manager.start_game()
```

---

## 6フェーズ初期化

### Phase 1: システム作成 (`phase_1_create_systems`)

**目的**: すべてのゲームシステムのインスタンスを生成し、GameSystemManager の子として追加

**作成対象（10個）**:

| # | システム | クラス名 | 役割 |
|---|---------|---------|------|
| 1 | SignalRegistry | `SignalRegistry` | シグナル管理（最初に作成：他が参照する可能性） |
| 2 | BoardSystem3D | `BoardSystem3D` | 3Dボード管理 |
| 3 | PlayerSystem | `PlayerSystem` | プレイヤー状態管理 |
| 4 | CardSystem | `CardSystem` | デッキ・手札管理 |
| 5 | BattleSystem | `BattleSystem` | バトル実行 |
| 6 | PlayerBuffSystem | `PlayerBuffSystem` | バフ効果管理 |
| 7 | SpecialTileSystem | `SpecialTileSystem` | 特殊マス管理 |
| 8 | UIManager | `UIManager` | UI統括管理 |
| 9 | DebugController | `DebugController` | デバッグ機能 |
| 10 | GameFlowManager | `GameFlowManager` | ゲームフロー管理 |

**注意**: CreatureManager, TileDataManager は BoardSystem3D の `_ready()` 内で自動作成される（Phase 1 には含まない）

---

### Phase 2: 3Dノード収集 (`phase_2_collect_3d_nodes`)

**目的**: game_3d シーン（parent_node）から必要な 3D ノードを取得

```gdscript
tiles_container = parent_node.get_node_or_null("Tiles")
players_container = parent_node.get_node_or_null("Players")
camera_3d = parent_node.get_node_or_null("Camera3D")
# ui_layer は Phase 4-1 の create_ui() で作成される
```

---

### Phase 3: システム基本設定 (`phase_3_setup_basic_config`)

**目的**: 各システムの基本初期化と 3D ノードの紐づけ

**実施内容（順序重要）**:

1. **PlayerSystem 初期化**
   ```gdscript
   player_system.initialize_players(player_count)
   ```

2. **CardSystem 再初期化**
   ```gdscript
   card_system._initialize_decks(player_count)
   ```

3. **BoardSystem3D 基本設定**
   ```gdscript
   # ★重要: カメラ参照を最初に設定（collect_players()内でMovementControllerが使用）
   board_system_3d.camera = camera_3d
   board_system_3d.player_count = player_count
   board_system_3d.player_is_cpu = player_is_cpu
   board_system_3d.current_player_index = 0

   # タイル・プレイヤー収集（カメラ設定後に実行すること）
   board_system_3d.collect_tiles(tiles_container)
   board_system_3d.collect_players(players_container)
   await get_tree().process_frame  # プレイヤー配置反映待ち
   ```

4. **カメラ初期位置設定（タイル位置基準）**
   ```gdscript
   if board_system_3d.tile_nodes.has(0):
       var tile_pos = board_system_3d.tile_nodes[0].global_position
       tile_pos.y += 1.0  # MOVE_HEIGHT
       var look_target = tile_pos + Vector3(0, 1.0, 0)
       var cam_pos = tile_pos + GameConstants.CAMERA_OFFSET
       camera_3d.global_position = cam_pos
       camera_3d.look_at(look_target + Vector3(0, GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)
   ```

5. **CameraController 作成**
   ```gdscript
   camera_controller = CameraController.new()
   parent_node.add_child(camera_controller)
   camera_controller.setup(camera_3d, board_system_3d, player_system)
   board_system_3d.camera_controller = camera_controller
   board_system_3d.movement_controller.camera_controller = camera_controller
   ```

**⚠️ 順序依存**: `board_system_3d.camera = camera_3d` は `collect_players()` より前に設定すること。`collect_players()` 内で `movement_controller.initialize(camera)` が呼ばれる。

---

### Phase 4: システム間連携設定 (`phase_4_setup_system_interconnections`)

Phase 4 は4つのサブフェーズに分かれる。

#### Phase 4-1: 基本システム参照設定

**⚠️ BattleScreenManager を最初に初期化**（battle_system.setup_systems() が参照するため）:
```gdscript
_setup_battle_screen_manager()  # BattleScreenManager + BattleStatusOverlay
```

**Step 1**: GameFlowManager に全システムを設定
```gdscript
game_flow_manager.setup_systems(
    player_system, card_system, board_system_3d, player_buff_system,
    ui_manager, battle_system, special_tile_system
)
```

**Step 2**: BoardSystem3D に全システムを設定
```gdscript
board_system_3d.setup_systems(
    player_system, card_system, battle_system, player_buff_system,
    special_tile_system, game_flow_manager
)
board_system_3d.ui_manager = ui_manager
```

**Step 3**: SpecialTileSystem
```gdscript
special_tile_system.setup_systems(
    board_system_3d, card_system, player_system, ui_manager, game_flow_manager
)
```

**Step 4**: DebugController
```gdscript
debug_controller.setup_systems(
    player_system, board_system_3d, card_system, ui_manager, game_flow_manager
)
player_system.set_debug_controller(debug_controller)
```

**Step 5**: UIManager に参照設定
```gdscript
ui_manager.board_system_ref = board_system_3d
ui_manager.player_system_ref = player_system
ui_manager.card_system_ref = card_system
ui_manager.game_flow_manager_ref = game_flow_manager
```

**Step 10**: UIManager.create_ui() 実行（**全参照設定後**）
```gdscript
ui_manager.create_ui(parent_node)
ui_layer = parent_node.get_node_or_null("UILayer")
_connect_camera_signals_deferred()  # カメラシグナルは遅延接続
```

その後: CardSelectionUI, BattleSystem, GameFlowManager の追加参照設定

**Step 9**: GameFlowManager の 3D 設定
```gdscript
game_flow_manager.debug_manual_control_all = debug_manual_control_all
game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)
```

#### Phase 4-2: GameFlowManager 子システム初期化

GameSystemManager のヘルパー関数で各子システムを初期化:

| ヘルパー関数 | 初期化対象 | 依存 |
|-------------|-----------|------|
| `_setup_lap_system()` | LapSystem | player_system, ui_manager, game_flow_manager, board_system_3d |
| `_setup_spell_systems()` | SpellDraw, SpellMagic, SpellLand, SpellCurse, SpellDice, SpellCurseStat, SpellWorldCurse, SpellPlayerMove, BankruptcyHandler | 多数（下記参照） |
| `_setup_battle_screen_manager()` | ※Phase 4-1冒頭で実行済み | game_flow_manager |
| `_setup_magic_stone_system()` | MagicStoneSystem | board_system_3d, player_system |
| `_setup_cpu_special_tile_ai()` | CPUSpecialTileAI | card_system, player_system, board_system_3d, game_flow_manager |

**SpellCurse の初期化順序（重要）**:
SpellCurse は複数の子システムから依存されるため、最初に初期化する:
```
1. SpellDraw    → setup(card_system, player_system)
2. SpellMagic   → setup(player_system, board_system_3d, game_flow_manager, null)
3. SpellLand    → setup(board_system_3d, creature_manager, player_system, card_system)
4. SpellCurse   → setup(board_system_3d, creature_manager, player_system, game_flow_manager)
5. SpellDice    → setup(player_system, spell_curse)  ← SpellCurse に依存
6. SpellCurseStat → setup(spell_curse, creature_manager)  ← SpellCurse に依存
7. SpellWorldCurse → setup(spell_curse, game_flow_manager)
8. SpellPlayerMove → setup(board_system_3d, player_system, game_flow_manager, spell_curse)
9. BankruptcyHandler → setup(player_system, board_system_3d, creature_manager, spell_curse, ui_manager, null)
```

**追加初期化**:
- SpellCurseToll: spell_curse + skill_toll_change + creature_manager
- SpellCostModifier: spell_curse + player_system + game_flow_manager
- DominioCommandHandler, ItemPhaseHandler への参照設定

#### Phase 4-3: BoardSystem3D 子システム

BoardSystem3D の子システム（TileActionProcessor, CPUTurnProcessor, MovementController, CreatureManager, TileDataManager）は `_ready()` で自動初期化済み。**追加設定不要**。

#### Phase 4-4: 特別な初期化

| 処理 | 内容 |
|------|------|
| `_initialize_phase1a_handlers()` | TargetSelectionHelper, DominioCommandHandler, SpellPhaseHandler, ItemPhaseHandler を GameFlowManager の子として作成・初期化 |
| `_initialize_cpu_movement_evaluator()` | CPUAIContext 作成 → CPUBattleAI → CPUMovementEvaluator を初期化 |
| 手札UI初期化 | `ui_manager.initialize_hand_container(ui_layer)` + `connect_card_system_signals()` |

---

### Phase 5: シグナル接続 (`phase_5_connect_signals`)

```gdscript
# GameFlowManager → GameSystemManager
game_flow_manager.dice_rolled.connect(_on_dice_rolled)
game_flow_manager.turn_started.connect(_on_turn_started)
game_flow_manager.turn_ended.connect(_on_turn_ended)
game_flow_manager.phase_changed.connect(_on_phase_changed)

# PlayerSystem → GameFlowManager
player_system.player_won.connect(game_flow_manager.on_player_won)

# UIManager → GameFlowManager
ui_manager.card_selected.connect(game_flow_manager.on_card_selected)
ui_manager.pass_button_pressed.connect(game_flow_manager.on_pass_button_pressed)
ui_manager.level_up_selected.connect(game_flow_manager.on_level_up_selected)
ui_manager.dominio_order_button_pressed.connect(game_flow_manager.open_dominio_order)
```

---

### Phase 6: ゲーム開始準備 (`phase_6_prepare_game_start`)

```gdscript
# 初期手札配布
card_system.deal_initial_hands_all_players(player_count)

# UI更新（0.1秒待機後）
await get_tree().create_timer(0.1).timeout
ui_manager.update_player_info_panels()
```

---

## カメラシグナル遅延接続

Phase 3 の await 完了を待つため、カメラシグナル接続は遅延実行する:

```gdscript
func _connect_camera_signals_deferred():
    await get_tree().process_frame
    await get_tree().process_frame  # 2フレーム待つ
    if ui_manager and board_system_3d:
        ui_manager.board_system_ref = board_system_3d
        ui_manager.connect_camera_signals()
```

---

## 重要な順序制約まとめ

| 制約 | 理由 |
|------|------|
| BattleScreenManager は Phase 4-1 の最初 | battle_system.setup_systems() が参照するため |
| camera 設定 → collect_players() | MovementController.initialize(camera) が呼ばれるため |
| UIManager 全参照設定 → create_ui() | create_ui() 内で参照を使ってUI初期化するため |
| SpellCurse → SpellDice/SpellCurseStat | setup() 引数に spell_curse が必要 |
| カメラシグナル接続は遅延実行 | Phase 3 の await 完了待ち |

---

## 新しいシステムを追加する場合

1. **Phase 1**: `phase_1_create_systems()` で `new()` → `add_child()`
2. **Phase 4**: 適切なサブフェーズでヘルパー関数を追加し、参照設定・初期化
3. **Phase 5**: 必要なシグナル接続を追加
4. **game_3d.gd は変更不要**

---

## Phase 5〜E で追加された初期化（2026-02-16〜2026-02-20）

### SpellUIManager 初期化（Phase 5-1）
SpellPhaseHandler の初期化時に SpellUIManager を内部で作成。UI統合管理（274行、14メソッド）。

### CPUSpellAIContainer 初期化（Phase 5-2）
GSM が CPUSpellAIContainer (RefCounted) を作成し、以下4つの参照を集約:
- CPUSpellAI
- CPUMysticArtsAI
- CPUHandUtils
- CPUMovementEvaluator

### UIEventHub 初期化（Phase UIEventHub）
GSM が UIEventHub を作成し、UIManager と各UIコンポーネントに注入:
```gdscript
ui_event_hub = UIEventHub.new()
add_child(ui_event_hub)
```

### UI Callable 注入（Phase 10-D）
GSM の `inject_ui_callbacks()` で GFM に UI 操作 Callable を一括注入:
- `_ui_set_phase_text_cb` → UIManager.phase_display
- `_ui_update_panels_cb` → UIManager.player_info_service
- `_ui_show_dominio_btn_cb` / `_ui_hide_dominio_btn_cb`
- `_ui_show_card_selection_cb` / `_ui_hide_card_selection_cb`
- `_ui_enable_navigation_cb` → UIManager.navigation_service

### UIManager 5サービス初期化（Phase 8-F）
UIManager.create_ui() 内で5つの内部サービスを作成:
- MessageService
- NavigationService
- CardSelectionService
- InfoPanelService
- PlayerInfoService

### Handler UI Signal 接続（Phase 6）
GSM がハンドラーの UI Signal をリスニングし、UIManager のサービスに伝達:
- SpellPhaseHandler: 9 UI Signals
- DicePhaseHandler: 8 UI Signals
- TollPaymentHandler: 2 UI Signals
- DiscardHandler: 2 UI Signals
- BankruptcyHandler: 7 UI Signals
- ItemPhaseHandler: 4 UI Signals
- **合計**: 32+ UI Signals

---

## 関連ファイル

- `scripts/system_manager/game_system_manager.gd` - 実装コード
- `scripts/game_3d.gd` - 呼び出し元
- `scripts/game_constants.gd` - 定数定義（CAMERA_OFFSET 等）

---

**作成日**: 2025-11-22
**最終更新**: 2026-02-20
**ステータス**: 実装完了・ドキュメント更新済み