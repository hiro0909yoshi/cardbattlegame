# Culdcept-style Card Battle Game - Project Overview

## Basic Info
- Engine: Godot 4.4.1 (GDScript)
- Status: Prototype 80% complete
- Type: Board game + card battle hybrid

## Core Systems
- **GameFlowManager**: Turn/phase control
- **BoardSystem3D**: 20-tile diamond map, tile ownership, creature placement
- **CardSystem**: Deck (max 50), hand (max 6), draw/discard
- **BattleSystem**: First-strike combat, bonuses, skill application
- **PlayerSystem**: 4 players, magic points, land tracking
- **SkillSystem**: Condition checking, effect application
- **ItemSystem**: Battle preparation, effect application (55/75 items complete)
- **UIManager**: 8 components (PlayerInfo, CardSelection, LevelUp, Debug, LandCommand, Hand, Phase, BattleItemSelection)

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

### Land Command System (Nov 2025)
- **Turn End Centralization**: All actions unified through `end_turn()`
- **Actions**: Level up, creature move, exchange, terrain change
- **Constraints**: 1 action per turn, mutually exclusive with summon
- **UI Management**: `is_ending_turn` flag prevents premature reinitialization

#### Turn End Flow
```
Action Complete
  ↓
complete_action() / _complete_action()
  ↓
tile_action_completed / action_completed signal
  ↓
end_turn()
  ├─ Set is_ending_turn = true (FIRST - most critical)
  ├─ close_land_command()
  ├─ hide UI
  └─ _on_land_command_closed() checks flag, skips reinit
  ↓
Next Phase
```

**Critical Implementation Details:**
- `is_ending_turn` flag MUST be set before `close_land_command()` call
- All actions (level/move/swap/terrain) only call `complete_action()`
- NO action should call `close_land_command()` directly
- This prevents "召喚しない" button from remaining visible after actions

### Item System (55/75 Complete - 73%)
- **Battle Prep Phase**: Pre-battle item selection (up to 2 items)
- **Effect Types**: buff_ap, buff_hp, grant_skill, revive, transform, nullify_enemy_skills, **item_return**
- **Transformation**: Preserves base_up_hp and items, resets HP to max
- **Categories**: Weapons (100%), Armor (88%), Scrolls (42%)
- **Recent Additions** (Nov 2): 3 items with item_return effect

### Item Return Skill (Nov 2025)
- **Implementation**: `scripts/battle/skills/skill_item_return.gd`
- **Trigger**: After item use in battle
- **Types**: 
  - return_to_deck: Returns to top of deck
  - return_to_hand: Returns to hand immediately (can exceed hand limit)
- **Priority Rule**: Item's own return effect > Creature's all-items return
- **Implemented**: 3 items + 1 creature
  - エターナルメイル (1005): HP+40, return to deck
  - ソウルレイ (1030): Scroll attack ST30, return to hand
  - ブーメラン (1054): ST+20/HP+10, return to hand
  - ケンタウロス (314): First strike, all items return to deck (補完的)
- **Integration**: Called in `_apply_post_battle_effects()` after battle resolution

## Battle Flow
```
1. Card selection & cost payment
2. Attacker item phase (optional, up to 2 items)
3. Defender item phase (optional, up to 2 items)
4. Item effects applied
5. Attacker land bonus (if element matches)
6. Skill conditions checked (adjacent_ally_land, etc)
7. First strike: Attacker AP vs Defender HP
8. Counter: Defender ST vs Attacker HP (if alive)
9. Result determination
10. Item return processing (new - Nov 2025)
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
- Signal connections: Use CONNECT_ONE_SHOT to prevent duplicates
- Phase management: Check current_phase before state changes
- Node validity: Always check is_instance_valid() before access

## ability_parsed Structure
```json
{
  "effects": [{
    "effect_type": "power_strike|instant_death|item_return|...",
    "target": "self|enemy|all_enemies|all_items",
    "conditions": [{
      "condition_type": "adjacent_ally_land|mhp_below|...",
      "value": 40
    }],
    "stat": "AP|HP",
    "operation": "add|multiply",
    "value": 20,
    "trigger": "after_item_use",
    "return_type": "return_to_deck|return_to_hand"
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
- Vacant Move: Move to empty tiles without battle
- Enemy Land Move: Can move to enemy lands
- **Item Return** (NEW): Return used items to deck/hand

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
- Complete remaining 20 items (27%)
- Balance tuning
- CPU infinite loop fix

### Medium (1 month)
- World spell system (persistent effects)
- UI improvements
- Additional creature cards

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
│   ├── land_action_helper.gd (500L+)
│   ├── spell_phase_handler.gd
│   └── ...
├── tile_action_processor.gd (520L+)
├── battle/
│   ├── battle_preparation.gd (item phase)
│   └── skills/
│       ├── skill_transform.gd
│       ├── skill_item_return.gd (NEW - Nov 2025)
│       └── ...
├── skills/ (condition_checker, effect_combat)
├── ui_components/ (8 components)
└── tiles/
```

## Important Notes
- Check `docs/README.md` for complete documentation index
- Refer to `docs/design/skills_design.md` for skill details
- Refer to `docs/design/skills/item_return_skill.md` for item return details
- Refer to `docs/design/land_system.md` for land command details
- Check `docs/issues/issues.md` for current bugs
- UI positioning: Use viewport_size for responsiveness

## Recent Major Fixes (Nov 2025)
- **Item Return Skill (Nov 2)**: Implemented item return to deck/hand system
  - 3 items + 1 creature with return effects
  - Priority: Item's own effect > Creature's all-items effect
  - Prevents duplicate returns with smart conflict resolution
  - Integrated into post-battle flow
  - **Progress Update**: 52/75 → 55/75 items (69% → 73%)
- **Turn End Centralization (Nov 2)**: Unified all land command actions to use `end_turn()`
  - Fixed: "召喚しない" button remaining visible after land actions
  - Key: `is_ending_turn` flag set BEFORE `close_land_command()` call
  - All actions now only call `complete_action()`, never `close_land_command()`
- **UI Flag Management**: `is_ending_turn` prevents premature card selection reinitialization
- **Item System**: 55/75 items implemented with transformation and item_return support

Last updated: 2025-11-02
