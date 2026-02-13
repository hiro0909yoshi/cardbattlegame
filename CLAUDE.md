# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ✅ 最近完了した作業（2026-02-13）

**GDScript パターン監査 P0/P1 タスク完了**

- ✅ P0タスク（3個）: 型指定なし配列修正、spell_container null チェック、Optional型注釈追加
- ✅ P1タスク（2個）: プライベート変数命名規則統一、Signal 接続重複チェック完全化
- **コミット**: 5個作成（Task #1-5）
- **詳細**: `docs/analysis/action_items.md`, `docs/progress/daily_log.md`

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

**8 core + 2 derived = 10 spell subsystems** managed via `SpellSystemContainer`:

**Core Systems (8)**:
```
spell_draw          # Card draw effects
spell_magic         # EP manipulation, land curse
spell_land          # Land element/level changes
spell_curse         # Creature/player curses
spell_dice          # Dice modification effects
spell_curse_stat    # Stat modification curses
spell_world_curse   # Global world curses
spell_player_move   # Warp/movement effects
```

**Derived Systems (2)**:
```
spell_curse_toll    # Toll modification curses
spell_cost_modifier # Cost modification effects
```

**Container Pattern** (Implemented 2026-02-13):
- All spell systems centralized in `SpellSystemContainer` (RefCounted)
- `GameFlowManager` holds `spell_container` reference
- All access via `game_flow_manager.spell_container.spell_*`
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
│   ├── dominio_command_handler.gd
│   ├── spell_phase_handler.gd
│   ├── item_phase_handler.gd
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
- `SpellSystemContainer`: Unified 10+2 spell systems (eliminated 3 conversion chains)
- `DebugSettings` Autoload: Centralized debug flag management
- Signal Connection Safety: Added `is_connected()` checks project-wide (BUG-000 fix)

## Development Workflow

### Agent Workflow (CRITICAL - ALWAYS FOLLOW)

**エージェント役割分担**: 作業の性質に応じて、適切なモデルを自動的に使い分ける

#### 1. 受け答え・調整 → **Sonnet（私）**
- ユーザーとの対話
- 質問への回答
- 作業結果の報告
- ドキュメント更新

#### 2. 企画・計画立案 → **Opus（Plan agent）**
- 複雑な設計の立案
- リファクタリング計画の策定
- アーキテクチャ設計
- リスク分析

**使用方法**:
```python
Task(
  subagent_type="Plan",
  model="opus",
  prompt="詳細な実装計画を策定してください..."
)
```

#### 3. 実装・コード記述 → **Haiku（Task tool）**
- 実際のコード修正
- null参照チェック追加
- シグナル接続修正
- テストコード記述

**使用方法**:
```python
Task(
  subagent_type="general-purpose",
  model="haiku",  # 環境変数 CLAUDE_CODE_SUBAGENT_MODEL でデフォルト設定済み
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

#### 自動判断基準

**Opusを使用する場合**:
- リファクタリング計画が必要
- 複雑な設計判断が必要
- 複数の実装アプローチを比較検討する必要がある

**Haikuを使用する場合**:
- 明確な修正パターンがある
- コード記述が主な作業
- 繰り返し作業（複数ファイルの同じパターン修正）

**Sonnet（私）を使用する場合**:
- ユーザーとの対話
- 簡単な質問への回答
- ドキュメント更新
- 作業結果の統合・報告

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
- 作業計画を詰めた場合は **必ず** `docs/progress/refactoring_next_steps.md` に記録すること
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
  - See `docs/progress/refactoring_next_steps.md` for details

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
- `docs/progress/refactoring_next_steps.md` - Current and planned refactoring work

### Issue Management
- `docs/issues/issues.md` - Active bugs and tasks
- `docs/issues/resolved_issues.md` - Historical fixes

---

**Last Updated**: 2026-02-13
