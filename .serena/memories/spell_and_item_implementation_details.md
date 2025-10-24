# Spell Phase & Item System Implementation

## Spell Phase (Implemented Jan 2025)

### Core System: SpellPhaseHandler
- **Location**: scripts/game_flow/spell_phase_handler.gd
- **Timing**: Before dice roll each turn
- **Limit**: 1 spell per turn
- **States**: INACTIVE → WAITING_FOR_INPUT → SELECTING_TARGET → EXECUTING_EFFECT

### Flow
```
Turn Start
  ↓
Spell Phase
  ├─ Filter: Gray out non-spell cards
  ├─ Human: Card selection UI
  ├─ CPU: 30% chance to cast
  └─ Skip: Click dice button
  ↓
Spell Selected
  ├─ Pay cost (MP)
  ├─ Target selection (if required)
  │   ├─ Creature: Enemy creatures list
  │   └─ Player: Enemy players list
  └─ Execute effect
  ↓
Card → Discard
  ↓
End Spell Phase → Dice Roll
```

### Implemented Effects
```gdscript
// damage: HP reduction to creature
{
  "effect_type": "damage",
  "value": 20
}

// drain_magic: MP drain from player
{
  "effect_type": "drain_magic",
  "value": 30,
  "value_type": "percentage"  // or "fixed"
}
```

### Target Selection UI
- **Controls**: ↑↓ to select, Enter to confirm, Esc to cancel
- **Display**: Name, position, HP/MP
- **Camera**: Auto-focus on selected target

### Card Filtering
```gdscript
// UIManager.card_selection_filter
"spell"  // Spell phase: Only spells selectable
""       // Summon phase: Only creatures selectable

// HandDisplay: Visual gray-out
if filter_mode == "spell":
    if not is_spell_card:
        card.modulate = Color(0.5, 0.5, 0.5)
```

### Test Cards (data/spell_test.json)
- ID 2106: Magic Bolt (50MP, 20 damage)
- ID 2063: Drain Magic (80MP, 30% drain)

## Cost Handling (Unified)
```gdscript
// Handle both dict and int formats
var cost_data = card_data.get("cost", 1)
var cost = 0
if typeof(cost_data) == TYPE_DICTIONARY:
    cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
else:
    cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
```

### Files Modified
- card_selection_ui.gd
- tile_action_processor.gd
- battle_system.gd
- debug_panel.gd
- cpu_ai_handler.gd
- cpu_turn_processor.gd

## Item System (Preparation Only)

### Current State
- Data structure defined (data/item.json)
- Card type "item" recognized
- **Not implemented**: Battle prep phase, effect application

### Planned Implementation

**Phase 1: Battle Prep**
- Pre-battle item selection UI
- Apply effects during battle
- Clear after battle ends

**Phase 2: Item Effects**
- buff_ap: ST increase
- buff_hp: HP increase (item_bonus_hp field)
- grant_skill: Add skills (First Strike, Power Strike)
- debuff_ap: ST decrease

**Phase 3: Scroll System**
- Usable during battle
- Instant effects (heal, damage)

## Spell vs Skill Distinction

| Feature | Skill | Spell |
|---------|-------|-------|
| System | SkillSystem | SpellPhaseHandler |
| Timing | During battle | Spell phase (pre-dice) |
| Target | Battle participants only | Any valid target |
| Scope | Battle result modification | Wide (damage, MP, etc) |

## Implementation Files
### New
- scripts/game_flow/spell_phase_handler.gd
- scripts/ui_components/target_selection_ui.gd
- data/spell_test.json

### Modified
- scripts/game_flow_manager.gd (phase integration)
- scripts/ui_manager.gd (card filter)
- scripts/ui_components/hand_display.gd (gray-out)
- scripts/card_system.gd (test cards)
- scripts/board_system_3d.gd (remove_creature)

## Next Steps
1. Test spell phase operations
2. Verify Magic Bolt damage
3. Verify Drain Magic MP drain
4. Implement battle prep phase for items
5. Add world spell system (persistent effects)

Last updated: 2025-10-25
