# Culdcept-style Card Battle Game - Project Overview

## Basic Info
- Engine: Godot 4.4.1 (GDScript)
- Status: Prototype 75% complete
- Type: Board game + card battle hybrid

## Core Systems
- **GameFlowManager**: Turn/phase control
- **BoardSystem3D**: 20-tile diamond map, tile ownership, creature placement
- **CardSystem**: Deck (max 50), hand (max 6), draw/discard
- **BattleSystem**: First-strike combat, bonuses, skill application
- **PlayerSystem**: 4 players, magic points, land tracking
- **SkillSystem**: Condition checking, effect application
- **UIManager**: 7 components (PlayerInfo, CardSelection, LevelUp, Debug, LandCommand, Hand, Phase)

## Key Architecture Patterns
- **Signal-driven**: Systems communicate via signals (decoupled)
- **System separation**: Each system has single responsibility
- **3D-only**: BoardSystem3D manages 3D space, camera, movement

## New Systems (Jan 2025)
### TileNeighborSystem
- Spatial adjacency detection (XZ-plane distance)
- Cached results (O(1) lookup after O(N²) init)
- Used for "adjacent ally land" skill conditions

### Race System
- Creatures have optional `race` field
- First implementation: Goblin race (2 creatures)
- Used by Support skill for race-based bonuses

### EffectSystem
- Temporary effects: Lost on movement
- Permanent effects: Persist until exchange/game end
- Battle-only effects: Applied during battle, cleared after
- Land-count multiplier: AP/HP based on owned lands by element

### Down State System
- Lands become "down" after actions (summon/level/move/exchange)
- Cannot select down lands for land commands
- Cleared when player passes start tile
- Exception: "Indomitable" skill prevents down state

### Land Command Constraints
- 1 action per turn (level/move/exchange)
- Mutually exclusive with summon
- Can only select non-down lands

## Battle Flow
```
1. Card selection & cost payment
2. Attacker item phase (optional)
3. Defender item phase (optional)
4. Item effects applied
5. Attacker land bonus (if element matches)
6. Skill conditions checked (adjacent_ally_land, etc)
7. First strike: Attacker AP vs Defender HP
8. Counter: Defender ST vs Attacker HP (if alive)
9. Result determination
```

## Land Bonus System
- Formula: HP + (land_level × 10)
- Applied when creature element = tile element
- Stored separately in `land_bonus_hp` field
- Can be negated by "Penetration" skill

## Element Chain
```
Chain  Toll Multiplier  HP Bonus
1      1.0x            +10
2      1.5x            +20
3      2.5x            +30
4+     4.0x            +40 (max)
```

## Spell Phase (Oct 2025)
- Happens before dice roll each turn
- 1 spell per turn limit
- SpellPhaseHandler manages state
- TargetSelectionUI for target selection
- Implemented: damage, drain_magic
- Card filtering: Spells only selectable in spell phase

## Technical Constraints
- Avoid reserved words: `owner` → `tile_owner`
- TextureRect: Use `modulate` not `color`
- Cost normalization: Handle dict format `{mp: 50}`
- Camera offset: Use MovementController's CAMERA_OFFSET

## ability_parsed Structure
```json
{
  "effects": [{
    "effect_type": "power_strike|instant_death|...",
    "target": "self|enemy|all_enemies",
    "conditions": [{
      "condition_type": "adjacent_ally_land|mhp_below|...",
      "value": 40
    }],
    "stat": "AP|HP",
    "operation": "add|multiply",
    "value": 20
  }],
  "keywords": ["強打", "先制"]
}
```

## Implemented Skills
- Resonance (affinity): AP/HP bonus on specific element lands
- Penetration: Ignore defender land bonus
- Power Strike: AP multiplier under conditions
- First Strike: Attack first
- Indomitable: No down state after actions
- Regeneration: Full HP after battle
- Double Attack: Attack twice
- Instant Death: Chance to kill after attack
- Nullify: Cancel attacks
- Reflect: Damage reflection
- Support/Assist: Bonus to other creatures

## Debug Commands
- D: Toggle CPU hand visibility
- 1-6: Fix dice roll
- 0: Unfix dice
- 7: Move to enemy land
- 8: Move to empty land
- 9: +1000G magic
- U: Clear down state

## Dev Priorities
### High (2 weeks)
- Creature exchange
- Spell cards
- CPU infinite loop fix

### Medium (1 month)
- Item system
- Balance tuning
- UI improvements

### Low (3 months)
- Code splitting
- Test coverage
- Multiplayer

## File Structure
```
scripts/
├── game_flow/
│   ├── land_command_handler.gd (352L)
│   ├── land_selection_helper.gd (177L)
│   ├── land_action_helper.gd (333L)
│   ├── tile_action_processor.gd (404L)
│   ├── spell_phase_handler.gd
│   └── ...
├── skills/ (condition_checker, effect_combat)
├── ui_components/ (7 components)
└── tiles/
```

## Important Notes
- Check `docs/README.md` for complete documentation index
- Refer to `docs/design/skills_design.md` for skill details
- Check `docs/issues/issues.md` for current bugs
- UI positioning: Use viewport_size for responsiveness
- Signal connections: Use CONNECT_ONE_SHOT to prevent duplicates
- Phase management: Check current_phase before state changes
- Node validity: Always check is_instance_valid() before access

Last updated: 2025-10-25
