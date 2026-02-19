# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ✅ 最近完了した作業（2026-02-18）

**Phase 0-8A: アーキテクチャ移行 + UI層分離 + UIManager依存正規化（進行中）**

- ✅ **Phase 0**: ツリー構造定義（TREE_STRUCTURE.md, dependency_map.md 作成）
- ✅ **Phase 1**: SpellSystemManager 導入（10+2個のスペルシステムを一元管理）
- ✅ **Phase 2**: シグナルリレー整備（横断的シグナル接続 12箇所 → 2箇所、83%削減）
- ✅ **Phase 3-B**: BoardSystem3D SSoT 化（creature_updated シグナルチェーン、UI 自動更新）
- ✅ **Phase 3-A**: SpellPhaseHandler Strategy パターン化（22 Strategies, 109 effect_types 実装、SpellEffectExecutor 56%削減）
- ✅ **Phase 4**: SpellPhaseHandler 責務分離（5サブフェーズ、合計~280行削減）
  - **4A**: 待機ロジック削除（60行削減）
  - **4B**: CPU AI ロジック完全委譲（28行削減）
  - **4-P0**: CPU AI コンテキスト管理一元化（40行削減）
  - **4-P1**: is_cpu_player() メソッド統一（146行削減、19個の重複実装を削除）
  - **4-P2**: CPUSpellPhaseHandler 正式初期化（6行削減、GameSystemManager に一元化）
- ✅ **Phase 5**: 段階的最適化（2026-02-16）✅ **完了**
  - **5-1**: SpellUIManager 新規作成（274行、14メソッド）✅
  - **5-2**: CPUSpellAIContainer 新規作成（79行、4メソッド）✅
  - **5-3**: グループ3重複参照削除（25行削減）✅
  - **5-5**: GameSystemManager 最適化（35行削減）✅
- ✅ **Phase 6**: 完全UI層分離 - Signal駆動化（2026-02-17）✅ **完全完了**
  - **6-A**: SpellPhaseHandler UI Signal 分離（16 Signals）
    - SpellFlowHandler: 11 UI Signals、`_ui_manager` 削除
    - MysticArtsHandler: 5 UI Signals、`_ui_manager` 削除
    - MysticArts委譲メソッド8個削除
  - **6-B**: DicePhaseHandler UI分離（8 Signals）
    - ダイス結果表示・フェーズテキスト・コメント等のSignal駆動化
  - **6-C**: Toll + Discard + Bankruptcy UI分離（9 Signals）
    - TollPaymentHandler: 2 Signals
    - DiscardHandler: 2 Signals
    - BankruptcyHandler: 5 Signals（パネル生成は部分的に直接参照を保持）
  - **合計**: 33個のSignal追加、5/6ハンドラーで`_ui_manager`完全削除
  - GameSystemManager: 6つのSignal接続メソッド追加
- **成果物**: コード削減約700行（全フェーズ累計）、38個のUI Signal定義、7/8ハンドラーのUI層完全分離、4 UIサービス新規作成、UIManagerランタイム双方向参照ゼロ
- ✅ **Phase 7-A**: CPU AI パススルー除去（2026-02-17）✅ **完了**
  - SPH からの CPU AI 参照設定を廃止、CPUSpellPhaseHandler/CPUSpecialTileAI/DiscardHandler へ直接注入
  - チェーンアクセス（GFM→SPH→CPU AI）を直接参照に統一
  - 初期化フロー明確化、null参照チェック強化（5ファイル修正）
- ✅ **Phase 7-B**: SPH UI依存逆転（2026-02-17）✅ **完了**
  - Signal駆動化によりspell_ui_manager直接呼び出しゼロ
- ✅ **Phase 8（進行中）**: UIManager 依存方向の正規化（2026-02-18〜）
  - **8-F**: UIManager 内部4サービス分割（NavigationService, MessageService, CardSelectionService, InfoPanelService）✅
  - **8-G**: ヘルパーファイル サービス直接注入（target_selection_helper完全移行、tile_summon/battle_executor部分移行）✅
  - **8-A**: ItemPhaseHandler Signal化（4 Signals、ui_manager完全削除）✅
  - **合計**: 37個のUI Signal、7/8ハンドラーUI完全分離
- ✅ **Phase 9**: 状態ルーター解体（2026-02-19）✅ **完了**
  - restore_current_phase フォールバック5分岐削除（58行→1行）
  - spell_phase_handler_ref 完全削除（後方参照1件解消）
- ✅ **Phase 10-A**: PlayerInfoService サービス化（2026-02-19）✅ **完了**
  - PlayerInfoService 新規作成（描画更新のみ）
  - 16ファイル・23箇所の update_player_info_panels() を player_info_service.update_panels() に変更
  - UIManager の5番目のサービスとして統合
- ✅ **Phase 10-C**: UIManager双方向参照の削減（2026-02-19）✅ **完了**
  - dominio_command_handler_ref 完全削除、game_flow_manager_ref/board_system_ref ランタイム使用ゼロ
  - 外部チェーンアクセス13箇所 → Callable直接注入で0箇所に
  - Signal 1追加（dominio_cancel_requested）、Callable 11追加
  - GSM `_setup_ui_callbacks()` メソッド新設
  - 潜在バグ修正: DominioOrderUI DCH null参照

詳細は `docs/progress/refactoring_next_steps_2.md` を参照

---

## 🎯 アーキテクチャ改善方針（2026-02-14 追加）

**最優先事項**: ツリー構造の確立

現在、Phase 0-4 のアーキテクチャ移行を進行中です。

### 原則

1. **ツリー構造の遵守**
   - 各システムは1つの親を持つ
   - シグナルは子→親の方向のみ
   - 横断的な依存・接続を避ける

2. **新機能追加時の確認事項**
   - 適切な配置場所を `TREE_STRUCTURE.md` で確認
   - 親システムへの参照は注入（Dependency Injection）
   - シグナル接続時は `is_connected()` チェック必須

3. **段階的移行**（Phase 0-8 進行中）
   - ✅ Phase 0: ツリー構造定義（完了）
   - ✅ Phase 1: SpellSystemManager 導入（完了）
   - ✅ Phase 2: シグナルリレー整備（完了、横断接続 83%削減）
   - ✅ Phase 3-B: BoardSystem3D SSoT 化（完了）
   - ✅ Phase 3-A: SpellPhaseHandler Strategy パターン化（完了、22 Strategies 実装）
   - ✅ Phase 4: SpellPhaseHandler 責務分離（完了、~280行削減）
   - ✅ Phase 5: 段階的最適化（完了、2026-02-16）
     - ✅ 5-1: SpellUIManager 実装（274行、14メソッド）
     - ✅ 5-2: CPUSpellAIContainer 実装（79行、4メソッド）
     - ✅ 5-3: グループ3重複参照削除（25行削減）
     - ✅ 5-5: GameSystemManager 最適化（35行削減）
   - ✅ Phase 6: 完全UI層分離（完了、2026-02-17）
     - ✅ 6-A: SpellPhaseHandler UI Signal分離（16 Signals、委譲メソッド8個削除）
     - ✅ 6-B: DicePhaseHandler UI分離（8 Signals）
     - ✅ 6-C: Toll + Discard + Bankruptcy UI分離（9 Signals）
     - **合計**: 33 Signals、5/6ハンドラーUI層完全分離
   - ✅ Phase 7-A: CPU AI パススルー除去（完了、2026-02-17）
   - ✅ Phase 7-B: SPH UI依存逆転（完了、2026-02-17）
   - ✅ Phase 8: UIManager依存方向の正規化（完了、2026-02-18）
     - ✅ 8-F: UIManager内部4サービス分割
     - ✅ 8-G: ヘルパーファイル部分移行
     - ✅ 8-A: ItemPhaseHandler Signal化（4 Signals）
   - ✅ Phase 9: 状態ルーター解体（完了、2026-02-19）
   - ✅ Phase 10-A: PlayerInfoService サービス化（完了、2026-02-19）
   - ✅ Phase 10-C: UIManager双方向参照の削減（完了、2026-02-19）

### 参照ドキュメント

- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造
- `docs/design/dependency_map.md` - 現在の依存関係マップ
- `docs/progress/architecture_migration_plan.md` - 移行計画詳細

### アンチパターン防止チェック（Phase 6-7 教訓）

コード修正・新機能追加時に以下を確認すること:

**UI層分離チェック**:
- `scripts/game_flow/` 配下のハンドラーで `ui_manager.` や `spell_ui_manager.` を直接呼んでいないか？
- UI操作は Signal emit → UI層リスニングパターンを使用しているか？
- await が必要なUI操作はリクエスト/完了 Signal ペアを使用しているか？

**カメラモードチェック**:
- プレイヤーが操作するフェーズ（スペル、アイテム、ドミニオコマンド等）で `board_system.enable_manual_camera()` を呼んでいるか？
- フェーズ終了時に `enable_follow_camera()` で復帰しているか？

**リファクタリング安全チェック**:
- メソッド削除前に `grep -r` で呼び出し元ゼロを確認したか？
- 削除するメソッド内の暗黙の副作用（カメラモード変更、フラグリセット等）を他で代替しているか？
- マージコンフリクトが残っていないか？（`grep -r '<<<<<<' scripts/`）

---

## Project Overview

**カルドセプト風カードバトルゲーム** - A 3D tactical card battle game inspired by Culdcept, built with Godot 4.5.

- **Engine**: Godot 4.5 (3D, Forward+ rendering)
- **Language**: GDScript exclusively
- **Platform**: macOS (M4 MacBook Air), cross-platform design
- **Genre**: Hybrid board game + card game + strategy RPG
- **Documentation**: Extensively documented in Japanese in `docs/` directory

## Essential Commands

### Running the Game
```bash
# Open in Godot editor
godot project.godot

# Run the game (press F5 in editor)
```

### Data Validation
```bash
# Validate JSON files
python3 << 'EOF'
import json
with open('data/fire_1.json', 'r', encoding='utf-8') as f:
	data = json.load(f)
print("✅ JSON is valid")
EOF
```

## Architecture Overview

### Core Systems

The game uses a **modular subsystem architecture** with clear separation of concerns:

```
GameFlowManager (Central state machine)
├── BoardSystem3D (3D board management)
│   ├── TileNeighborSystem (spatial adjacency)
│   ├── MovementController3D (player movement)
│   ├── TileDataManager (tile state)
│   └── TileActionProcessor (action handling)
├── CardSystem (deck/hand/discard management)
├── BattleSystem (combat resolution)
│   ├── BattlePreparation (setup)
│   ├── BattleExecution (resolution)
│   ├── BattleSkillProcessor (skill effects)
│   └── ConditionChecker (condition validation)
├── PlayerSystem (player state and resources)
├── PlayerBuffSystem (player-level buffs and curses)
├── SkillSystem (skill effect management)
├── SpecialTileSystem (warp tiles, magic stones)
├── LapSystem (lap counting and checkpoint bonuses)
├── UIManager (UI coordination)
│   ├── CardSelectionUI
│   ├── HandDisplay
│   ├── PhaseDisplay
│   └── 15+ other UI components
├── BattleScreenManager (battle animations and visual effects)
└── Spell Systems (via SpellSystemContainer)
	├── DicePhaseHandler (dice roll management)
	├── TollPaymentHandler (toll payment processing)
	├── DiscardHandler (hand size management)
	└── BankruptcyHandler (bankruptcy processing)
```

### Initialization System

**GameSystemManager** (`scripts/system_manager/game_system_manager.gd`):
- Central initialization coordinator created by game_3d.gd
- Creates all subsystems in proper dependency order
- Injects references between systems
- Manages the 3-phase initialization process:
  1. **Phase 0**: Core system creation (GFM, BoardSystem3D, CardSystem, etc.)
  2. **Phase 1**: Handler and spell system setup (SpellSystemContainer, handlers)
  3. **Phase 2**: Final UI and reference injection

Critical initialization sequence in game_3d.gd `_ready()`:
1. Create GameSystemManager
2. Set UIManager references
3. Initialize hand container
4. Set `debug_manual_control_all` flag (before `setup_systems()`)
5. Call `GameSystemManager.setup_systems()`
6. Call `GameFlowManager.setup_3d_mode()`
7. Re-set CardSelectionUI references (required due to timing)

### Game Flow

```
Turn Start → Spell Phase → Dice Roll → Movement → Tile Landing
	→ (Empty Tile: Summon) OR (Enemy Tile: Battle)
	→ Land Commands (Level Up / Move Creature / Swap)
	→ Draw Card → Turn End → Next Player
```

### Key Architectural Patterns

1. **Signal-Based Communication**: Heavy use of Godot signals for loose coupling
   - `tile_action_completed` → triggers turn end
   - `hand_updated` → refreshes UI
   - `phase_changed` → coordinates game flow
   - **CRITICAL**: All signal connections use `is_connected()` checks to prevent duplicates

2. **Subsystem Delegation**: Major systems delegate to specialized subsystems
   - Example: `BoardSystem3D` delegates to `TileNeighborSystem`, `MovementController3D`, etc.
   - Example: `GameFlowManager` delegates to `DicePhaseHandler`, `TollPaymentHandler`, etc.

3. **Data-Driven Design**: All game content in JSON files with parsed ability systems
   - Creatures: 5 elements × 2 files each (fire_1.json, fire_2.json, etc.)
   - Spells: spell_1.json, spell_2.json
   - Items: item.json

4. **BattleParticipant Pattern**: Wraps creature data for battle, tracking temporary modifications separately from base stats

5. **Autoload Singletons**:
   - `DebugSettings`: Global debug flag management (debug_manual_control_all, etc.)
   - `CardLoader`: Global card database
   - `UserCardDB`: User-owned card collection and gacha system
   - `GameData`: Persistent game state (gold, quest progress, etc.)
   - `CpuDeckData`: CPU player deck configurations

6. **Direct Reference Pattern** (Spell Systems):
   - `SpellEffectExecutor` holds direct references to spell systems (not via GFM)
   - Eliminates chain access like `handler.game_flow_manager.spell_magic`
   - References injected via `set_spell_container()` during initialization

7. **Container Pattern** (SpellSystemContainer):
   - All spell systems centralized in a single RefCounted container
   - Eliminates dictionary ⇔ individual variable conversion chains
   - Pattern based on `CPUAIContext` design

## Critical Implementation Details

### Down State System
- Tiles become "down" after actions (summon, level up, move, swap)
- Prevents reuse until next lap around board
- **Exception**: "Indomitable" (不屈) skill creatures never go down

### Land Bonus System
```gdscript
# Creature attribute matches tile attribute → +10 HP per land level
land_bonus_hp = land_level × 10
total_hp = base_hp + land_bonus_hp
```

### Skill System (86.7% complete)
- 11 fully implemented skills: Resonance, Penetration, Power Strike, First Strike, Regeneration, Double Attack, Instant Death, Reflect, Nullify, Support, Assist
- Skill application order: Resonance → Power Strike → Double Attack → Attack → Instant Death → Regeneration
- Detailed specs in `docs/design/skills_design.md`

### Effect System
Three types of effects:
1. **Battle-only**: Items (AP+30, HP+40) - removed after battle
2. **Temporary**: Spells (HP+10) - removed on movement
3. **Permanent**: Mass Growth effects - persist until swap

### Item Skill System
- Items can now have combat-triggered skills (not just stat bonuses)
- Uses `effect_parsed` (different from creatures' `ability_parsed`)
- Two-stage processing:
  1. `stat_bonus`: Applied during battle preparation
  2. `effects`: Processed during battle execution

### Spell System Architecture

**Spell Core Systems (10)**:
```
spell_draw          # Card draw effects
spell_magic         # EP manipulation, land curse
spell_land          # Land element/level changes
spell_curse         # Creature/player curses
spell_dice          # Dice modification effects
spell_curse_stat    # Stat modification curses
spell_world_curse   # Global world curses
spell_player_move   # Warp/movement effects
spell_curse_toll    # Toll modification curses
spell_cost_modifier # Cost modification effects
```

**Spell UI Management (1)** - Phase 5-1:
```
spell_ui_manager    # UI control integration (274 lines, 14 methods)
                    # Consolidates: spell_phase_ui_manager, spell_confirmation_handler,
                    #              spell_navigation_controller, spell_ui_controller
```

**CPU AI Container (1)** - Phase 5-2:
```
cpu_spell_ai_container  # CPU AI reference management (79 lines, 4 methods, RefCounted)
                        # Consolidates: cpu_spell_ai, cpu_mystic_arts_ai,
                        #              cpu_hand_utils, cpu_movement_evaluator
```

**Container Pattern** (Implemented 2026-02-13, Enhanced 2026-02-16):
- All spell systems centralized in `SpellSystemContainer` (RefCounted)
- UI management centralized in `SpellUIManager` (Node)
- CPU AI management centralized in `CPUSpellAIContainer` (RefCounted)
- `GameFlowManager` holds `spell_container`, `spell_phase_handler.spell_ui_manager`, references
- All access via `game_flow_manager.spell_container.spell_*`, `spell_phase_handler.spell_ui_manager.*()`
- Individual spell variables in GFM removed (no backward compatibility)
- Node-type systems (spell_curse_stat, spell_world_curse) managed by GFM's add_child()
- Eliminates dictionary ⇔ individual variable conversion chains
- Pattern based on `CPUAIContext` design

## File Organization

### Key Directories
```
scripts/
├── autoload/                # Autoload singletons
│   └── debug_settings.gd
├── system_manager/          # Initialization coordinator
│   └── game_system_manager.gd
├── game_flow/               # Game flow management
│   ├── game_flow_manager.gd
│   ├── spell_phase_handler.gd
│   ├── spell_ui_manager.gd           # ← Phase 5-1: UI management
│   ├── item_phase_handler.gd
│   ├── dominio_command_handler.gd
│   ├── dice_phase_handler.gd
│   ├── toll_payment_handler.gd
│   ├── discard_handler.gd
│   └── bankruptcy_handler.gd
├── battle/                  # Battle system
│   ├── battle_system.gd
│   ├── battle_preparation.gd
│   ├── battle_execution.gd
│   ├── battle_skill_processor.gd
│   └── condition_checker.gd
├── skills/                  # Skill implementations
│   └── effect_combat.gd
├── spells/                  # Spell systems (25+ files)
│   ├── spell_system_container.gd
│   └── spell_draw/          # Card draw subsystems
├── ui_components/           # UI components (15+ files)
├── cpu_ai/                  # CPU AI logic (10+ files)
│   ├── cpu_spell_ai_container.gd    # ← Phase 5-2: CPU AI reference management
├── battle_test/             # Battle testing framework
├── battle_screen/           # Battle animations
├── tiles/                   # Tile-related scripts
├── creatures/               # Creature-specific logic
├── quest/                   # Quest system
├── tutorial/                # Tutorial system
├── helpers/                 # Utility helpers
├── utils/                   # Utility functions
├── save_data/               # Save/load system
└── network/                 # Network functionality

data/
├── fire_1.json, fire_2.json    # Fire creatures
├── water_1.json, water_2.json  # Water creatures
├── earth_1.json, earth_2.json  # Earth creatures
├── wind_1.json, wind_2.json    # Wind creatures
├── neutral_1.json, neutral_2.json  # Neutral creatures
├── spell_1.json, spell_2.json  # Spells
└── item.json                   # Items
```

### Recent Major Refactorings
- `TileActionProcessor`: 1,284 lines → 5 files
- `DominioOrderHandler`: 881 lines → 4 files
- `UIManager`: Split into 15+ components
- `GameFlowManager`: 982 → 724 lines (258 lines removed via handler extraction)
- `SpellSystemContainer`: Unified 10 spell systems (eliminated 3 conversion chains)
- `SpellUIManager`: New - 274 lines (Phase 5-1, UI control integration)
- `CPUSpellAIContainer`: New - 79 lines (Phase 5-2, CPU AI reference management)
- `DebugSettings` Autoload: Centralized debug flag management
- Signal Connection Safety: Added `is_connected()` checks project-wide (BUG-000 fix)
- Phase 5 cumulative: ~134 lines deleted, 2 new systems added, references consolidated

## Development Workflow

### Agent Workflow (CRITICAL - ALWAYS FOLLOW)

**エージェント役割分担**: Opus メイン + Haiku 実装専門

#### 1. 受け答え・企画・計画立案 → **Opus（主要）**
- ユーザーとの対話・質問への回答
- 企画・計画立案
- 複雑な設計判断
- リファクタリング計画の策定
- アーキテクチャ設計
- リスク分析
- 作業結果の報告

#### 2. 実装・コード記述 → **Haiku（Task tool・subagent）**
- 実際のコード修正（確実な実装）
- null参照チェック追加
- シグナル接続修正
- テストコード記述

**使用方法**（Haiku に実装を依頼）:
```python
Task(
  subagent_type="general-purpose",
  model="haiku",  # subagent_model が haiku に設定済み
  prompt="""
## タスク: null参照チェック追加

### 対象ファイル
1. scripts/game_flow_manager.gd
   - Line 222: spell_container.spell_draw.draw_one()

### 修正パターン
\`\`\`gdscript
if spell_container and spell_container.spell_draw:
    var drawn = spell_container.spell_draw.draw_one(player_id)
else:
    push_error("[GFM] spell_draw が初期化されていません")
    return
\`\`\`
"""
)
```

#### 廃止されたモデル
- **Sonnet**: 一切使用しない（判断品質への不満により廃止 - 2026-02-17）

### Before Making Changes
1. **ALWAYS check `docs/README.md` first** - This is the project's central documentation index
2. Review `docs/progress/daily_log.md` for recent work
3. Check relevant design documents in `docs/design/`
4. Consult `docs/implementation/implementation_patterns.md` for templates

### Coding Standards
- **GDScript規約**: All GDScript code must follow the `gdscript-coding` skill rules
- **詳細**: `docs/development/coding_standards.md` (also available as `~/.claude/skills/gdscript-coding/SKILL.md`)
- **適用範囲**: GDScriptファイルの作成・編集・リファクタリング全般

### Documentation Rules
- **DO NOT** modify `docs/design/` without explicit user request (design specs are sacred)
- **DO** update `docs/issues/issues.md` when fixing bugs or adding features
- **DO** update `docs/progress/daily_log.md` after completing work
- **DO** use implementation patterns from `docs/implementation/implementation_patterns.md`

### Mandatory Update Rules (重要)

**作業計画・リファクタリング**:
- 作業計画を詰めた場合は **必ず** `docs/progress/refactoring_next_steps_2.md` に記録すること
- 計画変更時も即座に更新（追記ではなく上書き更新）
- セッション終了前に必ず現状を記録

**コード変更時のドキュメント更新**:
- シグナル追加・変更時 → `docs/implementation/signal_catalog.md` を更新
- 委譲メソッド追加時 → `docs/implementation/delegation_method_catalog.md` を更新
- スペル・スキル・アルカナの内容変更時 → 関連設計ドキュメント（`docs/design/skills_design.md` など）を更新
- **原則**: 関連ドキュメントがある場合は随時更新すること

**新規ドキュメント作成**:
- 新しいドキュメントを作成する前に **必ず計画を立案してユーザーに確認** すること
- 既存ドキュメント構造との整合性を確認
- 作成後は `docs/README.md` にリンクを追加

### Common Tasks

#### Adding a New Creature
1. Choose the appropriate JSON file (fire_1.json, water_1.json, etc.)
2. Follow the template in `docs/implementation/implementation_patterns.md`
3. Validate JSON syntax with Python
4. Update documentation if it's a new skill type

#### Adding a New Skill
1. Define JSON structure in `ability_parsed`
2. Implement in `BattleSkillProcessor` (scripts/battle/battle_skill_processor.gd)
3. Add conditions in `ConditionChecker` if needed
4. Document in `docs/design/skills_design.md`
5. Add implementation pattern to `docs/implementation/implementation_patterns.md`

#### Adding Item Skills (Combat-Triggered)
1. Define in item.json using `effect_parsed` (not `ability_parsed`)
2. Add item to `creature_data["items"]` array in `BattlePreparation`
3. Implement skill check in `BattleSkillProcessor` reading from `effect_parsed`
4. Handle `stat_bonus` in preparation, `effects` in execution

## Known Issues and Constraints

### Critical Bugs
- **BUG-000**: Turn skipping due to duplicate signal emissions (✅ **RESOLVED** 2026-02-13)
  - Fixed with `is_connected()` checks in all signal connections
  - 16 locations across 7 files now protected against duplicate handlers

### Active Priorities
- **P0**: Defensive programming layer - add null reference checks to prevent crashes
  - 10+ high-risk locations identified in GameFlowManager, BattleSystem, SpellPhaseHandler
  - See `docs/progress/refactoring_next_steps_2.md` for details

### Deprecated Systems
- **Attribute affinity system** (fire→wind→earth→water cycle) - marked for removal
- **game.tscn** - 2D version (not used)

### Design Decisions
- **3D-only**: No 2D implementation, all board logic uses 3D spatial coordinates
- **Diamond board**: Currently 20 tiles in diamond shape, branching maps planned for future
- **Turn-based**: Strict phase management prevents action conflicts
- **Hand visibility**: Always shows current turn player's hand only

## Testing and Debugging

### Debug Features
- **Debug Panel**: Right side of screen (toggle with specific key)
- **Manual Control All**: `DebugSettings.debug_manual_control_all` flag makes all CPU players manually controllable
- **Battle Test Tool**: Comprehensive testing framework for skill validation (docs/design/battle_test_tool_design.md)
- **U Key**: Instantly clears down state for all player's lands (development only)

## Important Notes

### JSON Data Structure
- Creatures use `ability_parsed` for skills
- Items use `effect_parsed` for effects
- Always use `duplicate(true)` when passing card data from CardLoader to avoid reference pollution

### Viewport-Relative UI Positioning
All UI elements use viewport-relative positioning, never hardcoded coordinates:
```gdscript
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20  # Right side
var panel_y = (viewport_size.y - panel_height) / 2  # Centered
```

### GDScript Constraints
- Avoid reserved words: `owner` → `tile_owner`
- Return type declarations must allow null if function can return null
- TextureRect doesn't have `color` property, use `modulate` instead

### Signal Connection Safety
**CRITICAL**: Always check for existing connections before connecting signals to prevent duplicate handlers:
```gdscript
if not signal_name.is_connected(handler_method):
	signal_name.connect(handler_method)
```

This prevents:
- Turn skipping (BUG-000)
- Memory leaks
- Multiple event handler executions

## Future Plans

- Branching map support (currently diamond-shaped loop only)
- Map editor for custom layouts
- Multiplayer/PVP mode
- Campaign mode
- Additional skills: Transformation (変身), Revive (復活), Teleport (空地移動)

## Quick Reference

### Important Design Documents
- `docs/design/design.md` - Master architecture document
- `docs/design/skills_design.md` - Skill system specifications
- `docs/design/effect_system_design.md` - Effect system architecture
- `docs/design/defensive_creature_design.md` - Defensive creature specs
- `docs/implementation/implementation_patterns.md` - Code templates

### Progress Tracking
- `docs/progress/daily_log.md` - Recent work history
- `docs/progress/skill_implementation_status.md` - Skill completion status
- `docs/progress/refactoring_progress.md` - Code refactoring history
- `docs/progress/refactoring_next_steps_2.md` - Current and planned refactoring work

### Issue Management
- `docs/issues/issues.md` - Active bugs and tasks
- `docs/issues/resolved_issues.md` - Historical fixes

---

---

## 🤖 エージェント行動ガイドライン（2026-02-17 追加）

### ⚠️ CRITICAL: エージェントモデル指定

**Haiku 専用化（ユーザー明示的要望）**:
- ✅ **Haiku のみ**: 全ての対話・実装・計画・報告
- ❌ **Sonnet 廃止**: 一切使用しない（判断品質への不満により廃止）
- ⚠️ **Opus のみ例外**: 複雑な設計分析が必要な時のみ EnterPlanMode で使用

**設定確認**:
```json
~/.claude/settings.json: {"model": "claude-haiku-4-5-20251001"}
```

### ユーザー判断信頼方針

**エージェント判断で実行可能な操作を明記（確認省略）**

### 確認不要（エージェント判断で直接実行）

**ローカル操作**:
- ✅ `git reset --hard` / `git revert` - コミット済みコードのロールバック
- ✅ `git clean -fd` / `rm` - ローカルファイル削除（コミット済みのみ）
- ✅ ファイル作成・編集・削除 - Edit, Write, Glob, Grep による操作
- ✅ ゲーム起動・テスト実行 - Godot エディタでの動作確認

**ドキュメント操作**:
- ✅ CLAUDE.md, refactoring_next_steps.md, daily_log.md の更新
- ✅ docs/ 配下のドキュメント作成・修正

**開発フロー**:
- ✅ コード実装・リファクタリング
- ✅ 段階的なコミット作成（git commit）

### 確認必須（ユーザー許可後に実行）

- ❌ `git push` / `git push --force` - リモートリポジトリへの反映
- ❌ GitHub PR/Issue 操作 - 公開範囲への変更
- ❌ セーブデータ削除 - ユーザーの永続データへの影響

### この方針の背景

- ユーザーが複数の Phase で「修正に修正を重ね」てきた経験から、**エージェント判断を信頼** いただく
- 最悪の場合、`git reset --hard` でいつでも戻可能（ローカル操作のため）
- Opus による事前分析で方向性を確認済みのため、**実装フェーズでの確認は不要**

### Phase 6 リスタート（2026-02-17）

**ロールバック実施**: b81ffd0（Phase 5 案D 完了時点）
- ❌ 削除: Phase 6～8 の失敗した Handler 実装（20個以上のファイル）
- ✅ 保持: SpellUIManager, CPUSpellAIContainer（正しい設計）
- 🔄 再実装: SpellPhaseLogicHandler（ビジネスロジック層）、層の分離

---

**Last Updated**: 2026-02-19（Phase 10-C 完了） | Haiku + Opus
