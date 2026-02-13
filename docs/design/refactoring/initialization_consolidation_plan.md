# 初期化統合計画（Initialization Consolidation Plan）

**作成日**: 2026-02-13
**ステータス**: 計画中
**優先度**: 高

## 概要

### 背景・動機

現在、プロジェクトの主要システムにおいて初期化メソッドが散在しており、以下の問題が発生している：

1. **初期化メソッドの過剰な分散**：全7システムで合計35個の初期化メソッドが存在
2. **順序依存の複雑さ**：初期化順序を間違えるとnull参照エラーが発生
3. **可視性の低さ**：各システムの初期化要件が不明瞭
4. **保守性の低下**：新規開発者がシステム追加時に混乱しやすい

### 目的

- 初期化メソッドを統合し、システムごとに単一の初期化エントリーポイントを提供
- 初期化順序と依存関係を明確化
- InitializationConfig構造体により型安全な初期化を実現
- 段階的初期化パターンで初期化プロセスを可視化

## 現状分析

### 初期化メソッド数の分布

| システム | 合計 | setup | set | init | create | 問題度 |
|---------|------|-------|-----|------|--------|--------|
| **GameFlowManager** | **9** | 2 | 7 | 0 | 0 | 🔴 重大 |
| **BoardSystem3D** | **11** | 2 | 7 | 2 | 2 | 🔴 重大 |
| BattleSystem | 3 | 1 | 1 | 0 | 1 | 🟡 中 |
| UIManager | 3 | 0 | 0 | 1 | 2 | 🟡 中 |
| PlayerSystem | 4 | 0 | 3 | 1 | 0 | 🟡 中 |
| CardSystem | 3 | 0 | 2 | 1 | 0 | 🟢 低 |
| SpecialTileSystem | 2 | 1 | 1 | 0 | 0 | 🟢 低 |
| **合計** | **35** | **6** | **21** | **5** | **5** | - |

### GameFlowManager の初期化メソッド（9個）

```gdscript
# setup系（2個）
func setup_systems(p_system, c_system, _b_system, s_system, ui_system, bt_system, st_system)
func setup_3d_mode(board_3d, cpu_settings: Array)

# set系（7個）- 散在している
func set_lap_system(system) -> void                              # 95行
func set_battle_screen_manager(manager, overlay) -> void         # 161行
func set_magic_stone_system(system: MagicStoneSystem) -> void    # 168行
func set_cpu_special_tile_ai(ai: CPUSpecialTileAI) -> void       # 175行
func set_spell_container(container: SpellSystemContainer) -> void # 179行
func set_phase1a_handlers(...) -> void                           # 513行
func set_cpu_movement_evaluator(evaluator) -> void               # 603行
```

**問題点**:
- 95行～603行に分散（500行以上の範囲）
- 7個のsetterを正しい順序で呼ぶ必要がある
- 初期化要件がコードから読み取りにくい

### BoardSystem3D の初期化メソッド（11個）

```gdscript
# setup系（2個）
func setup_systems(p_system, c_system, b_system, s_system, st_system, gf_manager)
func setup_cpu_ai_handler()

# set系（7個）
func set_spell_land(system) -> void
func set_tile_action_processor_spells(cost_modifier, world_curse) -> void
func set_tile_action_processor_battle_overlay(overlay) -> void
func set_camera_controller_ref(cam_controller) -> void
func set_spell_player_move(spm) -> void
func set_cpu_movement_evaluator(evaluator) -> void
func set_movement_controller_gfm(gfm) -> void
# + 他にも set_movement_controller_ui_manager() 等

# create系（2個）
func create_creature_manager()
func create_subsystems()
```

**問題点**:
- MovementController関連だけで3個のsetterが存在
- サブシステム作成（_ready()）と参照設定（setup_systems()）が分離
- 一部のsetterが遅延実行を前提としている

### 具体的な問題例

#### 問題1: 順序依存によるnull参照リスク

```gdscript
# GameSystemManager.gd の Phase 4-2（684行）
spell_phase_handler.set_game_stats(game_flow_manager.game_stats)

# もし Phase 3 の setup_systems() より前に呼ぶと？
# → game_flow_manager.game_stats が null → エラー
```

#### 問題2: 初期化メソッドの散在

```gdscript
# GameFlowManager.gd
func set_lap_system(system) -> void:           # 95行
    lap_system = system
    # ...

func set_battle_screen_manager(...) -> void:   # 161行（66行離れている）
    battle_screen_manager = manager
    # ...

func set_phase1a_handlers(...) -> void:        # 513行（418行離れている）
    target_selection_helper = helper
    # ...
```

#### 問題3: 複雑な依存関係

```gdscript
# BoardSystem3D.setup_systems()
await get_tree().process_frame  # ui_manager設定を待つ

if ui_manager:
    tile_action_processor.setup(...)  # ui_manager必須
```

## 改善目標

### 定量的目標

| 項目 | 現状 | 目標 |
|------|------|------|
| 初期化メソッド数（GFM） | 9個 | 1個（+ 内部3段階） |
| 初期化メソッド数（BS3D） | 11個 | 1個（+ 内部3段階） |
| 初期化メソッド数（全体） | 35個 | 7個（各システム1個） |
| 初期化コードの散在範囲 | 500行以上 | 50行以内 |

### 定性的目標

- ✅ 初期化順序が自己文書化される
- ✅ 新規システム追加時のパターンが明確
- ✅ 単体テストでモック注入が容易
- ✅ 初期化失敗時のエラーメッセージが明確

## 設計方針

### 1. 統合初期化パターン

各システムに単一の初期化エントリーポイントを提供：

```gdscript
# 各システム共通パターン
func initialize_from_manager(config: InitializationConfig) -> void:
    _phase1_create_subsystems()      # サブシステム作成
    _phase2_setup_references(config) # 外部参照設定
    _phase3_connect_signals()        # シグナル接続
    _validate_initialization()       # 検証
```

### 2. InitializationConfig構造体

型安全な初期化パラメータの受け渡し：

```gdscript
# GameFlowManager用
class GameFlowManagerInitConfig:
    # 必須パラメータ
    var player_system: PlayerSystem
    var card_system: CardSystem
    var board_system_3d: BoardSystem3D
    var player_buff_system: PlayerBuffSystem
    var ui_manager: UIManager
    var battle_system: BattleSystem
    var special_tile_system: SpecialTileSystem
    var player_is_cpu: Array
    var parent_node: Node

    # オプションパラメータ
    var stage_data: Dictionary = {}
    var result_screen = null

    func validate() -> bool:
        return player_system != null and card_system != null # ...
```

### 3. 段階的初期化の明確化

3段階の初期化プロセス：

| Phase | 目的 | 例 |
|-------|------|---|
| Phase 1 | サブシステム作成 | `lap_system = LapSystem.new()` |
| Phase 2 | 外部参照設定 | `lap_system.player_system = config.player_system` |
| Phase 3 | シグナル接続・最終化 | `lap_system.connect_signals()` |

### 4. 既存setterの扱い

既存のsetterメソッドは段階的に移行：

```gdscript
# 移行期間中は両方サポート
func initialize_from_manager(config: InitializationConfig) -> void:
    # 新しい統合メソッド
    _phase1_create_subsystems()
    _phase2_setup_references(config)
    _phase3_connect_signals()

# 既存のsetterは内部実装として残す（外部からは非推奨）
func set_lap_system(system) -> void:
    # 後方互換のため残す
    lap_system = system
```

## 実装計画

### Phase 1: GameFlowManager集約（最優先）

**期間**: 1セッション
**影響範囲**: 最大
**リスク**: 高

#### ステップ

1. **InitializationConfig作成**
   - `GameFlowManagerInitConfig` クラスを定義
   - 必須/オプションパラメータを整理
   - `validate()` メソッドを実装

2. **統合初期化メソッド作成**
   - `initialize_from_manager(config)` を実装
   - 内部で既存のsetterを呼ぶ（段階的移行）

3. **GameSystemManager変更**
   - Phase 4 を簡素化
   - 新しい `initialize_from_manager()` を呼ぶように変更

4. **テスト**
   - ゲーム起動テスト
   - 全モード動作確認（通常/クエスト/チュートリアル）

5. **既存setter整理**
   - 内部メソッド化（`_set_xxx()` にリネーム）
   - 外部からの呼び出しを削除

#### 変更ファイル

- `scripts/game_flow_manager.gd` - 統合初期化メソッド追加
- `scripts/system_manager/game_system_manager.gd` - Phase 4簡素化

#### 成果物

- 初期化メソッド: 9個 → 1個（+ 内部3段階）
- コード削減: 約50行
- 初期化の可視性: 大幅向上

---

### Phase 2: BoardSystem3D集約

**期間**: 1セッション
**依存**: Phase 1完了後
**リスク**: 中

#### ステップ

1. **InitializationConfig作成**
   - `BoardSystem3DInitConfig` クラスを定義

2. **MovementController系setter統合**
   - 3個のsetterを1つに統合
   - `set_movement_controller_config()` メソッド作成

3. **統合初期化メソッド作成**
   - `initialize_from_manager(config)` を実装

4. **GameSystemManager変更**
   - Phase 4 を簡素化

5. **テスト**

#### 変更ファイル

- `scripts/board_system_3d.gd` - 統合初期化メソッド追加
- `scripts/system_manager/game_system_manager.gd` - Phase 4簡素化

#### 成果物

- 初期化メソッド: 11個 → 1個（+ 内部3段階）
- コード削減: 約40行

---

### Phase 3: 他システム集約

**期間**: 1セッション
**依存**: Phase 1-2完了後
**リスク**: 低

#### 対象システム

- BattleSystem（3個 → 1個）
- UIManager（3個 → 1個）
- PlayerSystem（4個 → 1個）
- CardSystem（3個 → 1個）
- SpecialTileSystem（2個 → 1個）

#### ステップ

各システムに対して：
1. InitializationConfig作成
2. `initialize_from_manager()` 実装
3. GameSystemManager変更
4. テスト

#### 成果物

- 初期化メソッド: 16個 → 5個

---

## 詳細設計

### GameFlowManager統合初期化の実装例

```gdscript
# scripts/game_flow_manager.gd

# === 初期化設定クラス ===
class GameFlowManagerInitConfig:
    # 必須システム参照
    var player_system: PlayerSystem
    var card_system: CardSystem
    var board_system_3d: BoardSystem3D
    var player_buff_system: PlayerBuffSystem
    var ui_manager: UIManager
    var battle_system: BattleSystem
    var special_tile_system: SpecialTileSystem

    # 必須設定
    var player_is_cpu: Array
    var parent_node: Node

    # 子システム（GSMで作成済み）
    var lap_system: LapSystem
    var spell_container: SpellSystemContainer
    var battle_screen_manager: BattleScreenManager
    var battle_status_overlay
    var magic_stone_system: MagicStoneSystem
    var cpu_special_tile_ai: CPUSpecialTileAI

    # Phase 1-A ハンドラー（GSMで作成済み）
    var target_selection_helper
    var dominio_command_handler
    var spell_phase_handler
    var item_phase_handler

    # その他
    var cpu_movement_evaluator: CPUMovementEvaluator
    var dice_phase_handler
    var toll_payment_handler
    var discard_handler

    # オプション
    var stage_data: Dictionary = {}
    var result_screen = null

    func validate() -> bool:
        if not player_system or not card_system or not board_system_3d:
            push_error("[InitConfig] 必須システムが未設定です")
            return false
        if player_is_cpu.size() == 0:
            push_error("[InitConfig] player_is_cpu が空です")
            return false
        return true

# === 統合初期化メソッド ===
func initialize_from_manager(config: GameFlowManagerInitConfig) -> void:
    if not config.validate():
        push_error("[GameFlowManager] 初期化設定が無効です")
        return

    print("[GameFlowManager] 統合初期化開始")

    # Phase 1: システム参照設定
    _phase1_setup_core_systems(config)

    # Phase 2: 子システム設定
    _phase2_setup_child_systems(config)

    # Phase 3: ハンドラー設定
    _phase3_setup_handlers(config)

    # Phase 4: オプション設定
    _phase4_setup_optional(config)

    print("[GameFlowManager] 統合初期化完了")

# === 内部フェーズメソッド ===
func _phase1_setup_core_systems(config: GameFlowManagerInitConfig) -> void:
    """Phase 1: コアシステム参照設定"""
    print("[GameFlowManager] Phase 1: コアシステム設定")

    # 既存のsetup_systems()を内部で呼ぶ
    setup_systems(
        config.player_system,
        config.card_system,
        config.board_system_3d,
        config.player_buff_system,
        config.ui_manager,
        config.battle_system,
        config.special_tile_system
    )

    # 既存のsetup_3d_mode()を内部で呼ぶ
    setup_3d_mode(config.board_system_3d, config.player_is_cpu)

func _phase2_setup_child_systems(config: GameFlowManagerInitConfig) -> void:
    """Phase 2: 子システム設定"""
    print("[GameFlowManager] Phase 2: 子システム設定")

    # 既存のsetterを内部で呼ぶ
    set_lap_system(config.lap_system)
    set_spell_container(config.spell_container)
    set_battle_screen_manager(config.battle_screen_manager, config.battle_status_overlay)
    set_magic_stone_system(config.magic_stone_system)
    set_cpu_special_tile_ai(config.cpu_special_tile_ai)

func _phase3_setup_handlers(config: GameFlowManagerInitConfig) -> void:
    """Phase 3: ハンドラー設定"""
    print("[GameFlowManager] Phase 3: ハンドラー設定")

    set_phase1a_handlers(
        config.target_selection_helper,
        config.dominio_command_handler,
        config.spell_phase_handler,
        config.item_phase_handler
    )

    set_cpu_movement_evaluator(config.cpu_movement_evaluator)

    # 新しいハンドラー
    dice_phase_handler = config.dice_phase_handler
    toll_payment_handler = config.toll_payment_handler
    discard_handler = config.discard_handler

func _phase4_setup_optional(config: GameFlowManagerInitConfig) -> void:
    """Phase 4: オプション設定"""
    print("[GameFlowManager] Phase 4: オプション設定")

    if config.stage_data.size() > 0:
        set_stage_data(config.stage_data)

    if config.result_screen:
        set_result_screen(config.result_screen)
```

### GameSystemManager変更例

```gdscript
# scripts/system_manager/game_system_manager.gd

# Phase 4-2を簡素化
func phase_4_setup_system_interconnections() -> void:
    print("[GameSystemManager] Phase 4: システム間連携設定開始")

    # ... 既存の Phase 4-1 は維持 ...

    # ===== 4-2: GameFlowManager 統合初期化 =====
    print("[GameSystemManager] Phase 4-2: GameFlowManager 統合初期化")

    # 初期化設定を作成
    var gfm_config = GameFlowManager.GameFlowManagerInitConfig.new()

    # 必須システム参照
    gfm_config.player_system = player_system
    gfm_config.card_system = card_system
    gfm_config.board_system_3d = board_system_3d
    gfm_config.player_buff_system = player_buff_system
    gfm_config.ui_manager = ui_manager
    gfm_config.battle_system = battle_system
    gfm_config.special_tile_system = special_tile_system
    gfm_config.player_is_cpu = player_is_cpu
    gfm_config.parent_node = parent_node

    # 子システムを作成して設定
    gfm_config.lap_system = _create_lap_system()
    gfm_config.spell_container = _create_spell_container()
    gfm_config.battle_screen_manager = _create_battle_screen_manager()
    gfm_config.battle_status_overlay = get_node_or_null("BattleStatusOverlay")
    gfm_config.magic_stone_system = _create_magic_stone_system()
    gfm_config.cpu_special_tile_ai = _create_cpu_special_tile_ai()

    # ハンドラーを作成して設定
    var handlers = _create_phase1a_handlers()
    gfm_config.target_selection_helper = handlers.target_selection_helper
    gfm_config.dominio_command_handler = handlers.dominio_command_handler
    gfm_config.spell_phase_handler = handlers.spell_phase_handler
    gfm_config.item_phase_handler = handlers.item_phase_handler

    gfm_config.cpu_movement_evaluator = _create_cpu_movement_evaluator()
    gfm_config.dice_phase_handler = _create_dice_phase_handler()
    gfm_config.toll_payment_handler = _create_toll_payment_handler()
    gfm_config.discard_handler = _create_discard_handler()

    # 統合初期化を実行
    game_flow_manager.initialize_from_manager(gfm_config)

    print("[GameSystemManager] Phase 4-2: GameFlowManager 統合初期化完了")

# 既存の _setup_xxx() メソッドを _create_xxx() にリネーム
func _create_lap_system() -> LapSystem:
    var lap_system = LapSystem.new()
    lap_system.name = "LapSystem"
    game_flow_manager.add_child(lap_system)
    # ... 初期化処理 ...
    return lap_system

func _create_spell_container() -> SpellSystemContainer:
    # ... スペルシステム作成 ...
    return spell_container

# ... 他の _create_xxx() メソッド ...
```

## リスクと対策

### リスク1: 初期化順序の変更による不具合

**影響度**: 高
**発生確率**: 中

**対策**:
- 段階的移行（既存setterを内部で呼ぶ）
- 各Phaseごとに動作確認
- 初期化失敗時のエラーログ強化

### リスク2: 大規模変更によるリグレッション

**影響度**: 高
**発生確率**: 中

**対策**:
- Phase 1完了後に全モードテスト
- コミット前にGodotエディタで警告確認
- 変更前後のコード行数を記録

### リスク3: 初期化設定の漏れ

**影響度**: 中
**発生確率**: 低

**対策**:
- `InitializationConfig.validate()` で必須パラメータチェック
- null参照時のエラーメッセージを明確化

## 成功基準

### Phase 1完了時

- ✅ GameFlowManagerの初期化メソッドが1個に統合
- ✅ GameSystemManagerのPhase 4-2が50行以内
- ✅ 全モード（通常/クエスト/チュートリアル）が正常動作
- ✅ Godotエディタで警告ゼロ

### Phase 2完了時

- ✅ BoardSystem3Dの初期化メソッドが1個に統合
- ✅ MovementController系setterが統合

### Phase 3完了時

- ✅ 全システムで統合初期化パターンが適用
- ✅ 初期化メソッド総数が35個→7個に削減
- ✅ 各システムの初期化要件が自己文書化

## 参考資料

### 関連ドキュメント

- `docs/design/refactoring/game_system_manager_design.md` - GameSystemManager設計
- `docs/progress/daily_log.md` - 日次作業ログ（2026-02-13セッション4-5）
- `docs/implementation/delegation_method_catalog.md` - 委譲メソッドカタログ

### 参考パターン

- **SpellSystemContainer**: 既存の統合パターン（10+2システムを1つのコンテナに集約）
- **CPUAIContext**: コンテキストパターン（複数のシステム参照を1つのオブジェクトに集約）
- **Builder Pattern**: 段階的な初期化パターン

### コーディング規約

- `docs/development/coding_standards.md` - GDScriptコーディング規約
- `~/.claude/skills/gdscript-coding/SKILL.md` - GDScriptスキル

---

**更新履歴**:
- 2026-02-13: 初版作成
