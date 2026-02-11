# Card Battle Game - Project Overview

## Basic Info
- Engine: Godot 4.4.1 (GDScript)
- Type: Board game + card battle hybrid (Culdcept-style)

## Core Systems
- **GameSystemManager**: 6-phase init, system orchestration
- **GameFlowManager**: Turn/phase control
- **BoardSystem3D**: 20-tile diamond map, tile ownership
- **CreatureManager**: Centralized creature data
- **CardSystem**: Deck(max50), hand(max6), draw/discard
- **BattleSystem**: First-strike combat, bonuses, skills
- **PlayerSystem**: 4 players, magic points, land tracking
- **ItemSystem**: Battle prep, item effects (75/75 complete)
- **UIManager**: 8 components
- **CPU AI**: 28 files (battle/spell/dominio/movement decisions)

## Architecture Patterns
- **Signal-driven**: Decoupled system communication
- **Single responsibility**: Each system owns one domain
- **Data centralization**: CreatureManager owns all creature data

## CreatureManager

Creature data is managed by CreatureManager, NOT tiles.
```
tile.creature_data (property)
  -> get/set redirect
CreatureManager.get_data_ref(tile_index)
  -> creatures[tile_index]  // actual data store
```
- `get_data_ref()`: returns reference (not copy)
- `set_data()`: set/delete
- `has_creature()`: existence check
- `find_by_player()` / `find_by_element()`: search
- Init: automatic in BoardSystem3D._ready()

## Battle Flow
```
1. Card selection & cost payment
2. Attacker item phase (optional, up to 2)
3. Defender item phase (optional, up to 2)
4. Item effects applied
5. Attacker land bonus (element match)
6. Skill condition check
7. First strike: Attacker AP vs Defender HP
8. Counter: Defender AP vs Attacker HP (if alive)
9. Result determination
10. Item return processing
```

## Land Command - Turn End Flow
```
Action Complete -> complete_action() -> signal -> end_turn()
  |- is_ending_turn = true (MUST be first)
  |- close_dominio_order()
  |- hide UI
  -> next phase
```
**Constraint**: `is_ending_turn` flag MUST be set before `close_dominio_order()`.
Actions only call `complete_action()`, never `close_dominio_order()` directly.

## Land Bonus
- HP + (land_level x 10), element match only
- Stored in `land_bonus_hp` field
- Negated by "Penetration" skill

## Element Chain
```
Chain  Toll Mult  HP Bonus
1      1.0x      +10
2      1.5x      +20
3      2.5x      +30
4+     4.0x      +40 (max)
```

## Subsystems
- **TileNeighborSystem**: Adjacent tile detection (XZ distance, cached)
- **Race System**: Optional race field, support skill bonuses
- **EffectSystem**: Temporary/permanent/battle-only effects, land-count multiplier
- **Down State**: Lands go down after actions, cleared at start tile
- **LapSystem**: Lap bonuses, checkpoint tracking

## Debug Commands
- D: Toggle CPU hand / 1-6: Fix dice / 0: Unfix
- 7: Move to enemy land / 8: Move to empty land
- 9: +1000G magic / U: Clear down state

## Key Docs
- `docs/README.md` - Doc index
- `docs/specs/cpu_battle_ai_spec.md` - Battle AI spec
- `docs/specs/cpu_spell_ai_spec.md` - Spell AI spec
- `docs/design/cpu_ai/cpu_card_rate_system.md` - Rate evaluation
- `docs/design/tile_creature_separation_plan.md` - CreatureManager design
- `docs/design/skills_design.md` - Skill details
- `docs/design/land_system.md` - Dominio command details
- `docs/issues/issues.md` - Known bugs
