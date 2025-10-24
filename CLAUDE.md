# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**カルドセプト風カードバトルゲーム** - A 3D tactical card battle game inspired by Culdcept, built with Godot 4.4.1.

- **Engine**: Godot 4.4.1 (3D, Forward+ rendering)
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
├── SkillSystem (skill effect management)
└── UIManager (UI coordination)
	├── CardSelectionUI
	├── HandDisplay
	├── PhaseDisplay
	└── 7+ other UI components
```

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

2. **Subsystem Delegation**: Major systems delegate to specialized subsystems
   - Example: `BoardSystem3D` delegates to `TileNeighborSystem`, `MovementController3D`, etc.

3. **Data-Driven Design**: All game content in JSON files with parsed ability systems
   - Creatures: 5 elements × 2 files each (fire_1.json, fire_2.json, etc.)
   - Spells: spell_1.json, spell_2.json
   - Items: item.json

4. **BattleParticipant Pattern**: Wraps creature data for battle, tracking temporary modifications separately from base stats

5. **Autoload Singletons**:
   - `CardLoader`: Global card database
   - `GameData`: Persistent game state

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

### Item Skill System (NEW)
- Items can now have combat-triggered skills (not just stat bonuses)
- Uses `effect_parsed` (different from creatures' `ability_parsed`)
- Two-stage processing:
  1. `stat_bonus`: Applied during battle preparation
  2. `effects`: Processed during battle execution

## File Organization

### Key Directories
```
scripts/
├── game_flow/              # Game flow management
│   ├── game_flow_manager.gd
│   ├── land_command_handler.gd
│   ├── spell_phase_handler.gd
│   └── item_phase_handler.gd
├── battle/                 # Battle system
│   ├── battle_system.gd
│   ├── battle_preparation.gd
│   ├── battle_execution.gd
│   ├── battle_skill_processor.gd
│   └── condition_checker.gd
├── skills/                 # Skill implementations
│   └── effect_combat.gd
├── ui_components/          # UI components (7+ files)
└── tiles/                  # Tile-related scripts

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
- `LandCommandHandler`: 881 lines → 4 files
- `UIManager`: Split into 7+ components

## Development Workflow

### Before Making Changes
1. **ALWAYS check `docs/README.md` first** - This is the project's central documentation index
2. Review `docs/progress/daily_log.md` for recent work
3. Check relevant design documents in `docs/design/`
4. Consult `docs/implementation/implementation_patterns.md` for templates

### Documentation Rules
- **DO NOT** modify `docs/design/` without explicit user request (design specs are sacred)
- **DO** update `docs/issues/issues.md` when fixing bugs or adding features
- **DO** update `docs/progress/daily_log.md` after completing work
- **DO** use implementation patterns from `docs/implementation/implementation_patterns.md`

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
- **BUG-000**: Turn skipping due to duplicate signal emissions (partially mitigated)
  - Related to `tile_action_completed` signal chain
  - Multiple guards in place to prevent duplicate `end_turn()` calls

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
- **Manual Control All**: `debug_manual_control_all` flag in GameFlowManager makes all CPU players manually controllable
- **Battle Test Tool**: Comprehensive testing framework for skill validation (docs/design/battle_test_tool_design.md)
- **U Key**: Instantly clears down state for all player's lands (development only)

### Initialization Order
Critical initialization sequence in game_3d.gd `_ready()`:
1. Create systems
2. Set UIManager references
3. Initialize hand container
4. Set `debug_manual_control_all` flag (before `setup_systems()`)
5. Call `GameFlowManager.setup_systems()`
6. Call `GameFlowManager.setup_3d_mode()`
7. Re-set CardSelectionUI references (required due to timing)

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

### Issue Management
- `docs/issues/issues.md` - Active bugs and tasks
- `docs/issues/resolved_issues.md` - Historical fixes

---

**Last Updated**: 2025-10-24
