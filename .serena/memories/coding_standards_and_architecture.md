# Coding Standards & Critical Constraints

## Must-Read Before Coding
Check `docs/README.md` for complete documentation index.

## Reserved Words to Avoid
```gdscript
// ❌ BAD: Godot reserved words
var owner: int           // Use: tile_owner_id
func is_processing()     // Use: is_battle_active()

// ✅ GOOD
var tile_owner_id: int
func is_battle_active() -> bool
```

## TextureRect Constraint
```gdscript
// ❌ BAD: color property doesn't work
texture_rect.color = Color.RED

// ✅ GOOD: Use modulate instead
texture_rect.modulate = Color.RED
```

## Core Architecture

### Main Systems
- GameFlowManager: Turn/phase control
- BoardSystem3D: 3D map, tile ownership
- CardSystem: Deck/hand management
- BattleSystem: Combat resolution
- PlayerSystem: Player state, magic points
- SkillSystem: Condition checks, effect application
- UIManager: 7 UI components

### Signal-Driven Communication
Systems communicate via signals (decoupled):
```gdscript
signal tile_action_completed()
signal battle_ended(winner, result)
signal phase_changed(new_phase)
```

## Critical Patterns

### Phase Management
```gdscript
// Prevent duplicate execution
if current_phase == GamePhase.END_TURN:
    return
```

### Signal Connection
```gdscript
// Prevent multiple connections
signal.connect(callback, CONNECT_ONE_SHOT)
```

### Node Validity
```gdscript
// Always check before access
if card_node and is_instance_valid(card_node):
    card_node.queue_free()
```

### Await Usage
```gdscript
// Always wait before phase transitions
await get_tree().create_timer(1.0).timeout
```

### Variable Shadowing
```gdscript
// ❌ BAD: Same name as class member
var player_system = ...

// ✅ GOOD: Different name
var p_system = ...
```

### Action Processing Flag Management
**Problem**: Duplicate flag management across systems
- BoardSystem3D.is_waiting_for_action
- TileActionProcessor.is_action_processing

**Solution (TECH-002 completed)**:
- Unified in TileActionProcessor
- BoardSystem3D only forwards signals
- LandCommandHandler notifies via complete_action()

**Critical**: Never add additional action flags outside TileActionProcessor

### Turn End Flow Management
**Responsible Class**: GameFlowManager (scripts/game_flow_manager.gd)

**Correct Call Chain**:
```
TileActionProcessor (_complete_action)
  └─ emit_signal("action_completed")
     │
     ↓
BoardSystem3D (_on_action_completed)
  └─ emit_signal("tile_action_completed")
     │
     ↓
GameFlowManager (_on_tile_action_completed_3d)
  └─ end_turn()
     └─ emit_signal("turn_ended")
```

**3-Layer Duplicate Prevention**:
1. BoardSystem3D: Check is_waiting_for_action flag
2. GameFlowManager: Phase check (ignore if END_TURN/SETUP)
3. end_turn(): Re-entry prevention check

**Critical Mistakes to Avoid**:
- ❌ Calling end_turn() directly from multiple places
- ❌ Inconsistent flag management → infinite loops
- ✅ Always go through the signal chain above

## UI Positioning (Full-Screen Support)
```gdscript
// ❌ BAD: Hardcoded coordinates
panel.position = Vector2(1200, 100)

// ✅ GOOD: Viewport-relative
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20    // Right edge
var panel_y = (viewport_size.y - panel_height) / 2  // Center
```

## System Initialization Order
**Critical: Must follow this exact order in game_3d.gd**

```gdscript
func _ready():
    // 1. Create systems
    
    // 2. Setup UIManager references
    ui_manager.board_system_ref = board_system_3d
    ui_manager.create_ui(self)
    
    // 3. Initialize hand container
    ui_manager.initialize_hand_container(ui_layer)
    
    // 4. Set debug flags BEFORE setup_systems (critical!)
    game_flow_manager.debug_manual_control_all = debug_manual_control_all
    
    // 5. Setup GameFlowManager
    game_flow_manager.setup_systems(...)
    game_flow_manager.setup_3d_mode(...)
    
    // 6. Re-set references to child components (critical!)
    // GameFlowManager ref doesn't exist at create_ui() time
    if ui_manager.card_selection_ui:
        ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager
```

**Why step 6 is needed**:
- create_ui() happens before GameFlowManager has references
- setup_systems() sets UIManager references
- Child components need explicit re-assignment afterward

## Data Structures

### ability_parsed Format
```json
{
  "effects": [{
    "effect_type": "power_strike|instant_death",
    "target": "self|enemy",
    "conditions": [{
      "condition_type": "adjacent_ally_land|mhp_below",
      "value": 40
    }],
    "stat": "AP|HP",
    "operation": "add|multiply",
    "value": 20
  }],
  "keywords": ["強打", "先制"]
}
```

### Card Data
```json
{
  "id": 1,
  "type": "creature|spell|item",
  "element": "fire|water|earth|wind|neutral",
  "cost": {"mp": 50, "lands_required": ["fire"]},
  "ap": 30,
  "hp": 40,
  "ability_parsed": {...}
}
```

## Battle System

### First Strike Flow
```
1. Attacker first strike: AP >= Defender HP? → Win
2. Defender counter: ST >= Attacker HP? → Win
3. Both survive → Attacker wins (land capture)
```

### Bonus Calculation
```gdscript
{
  "st_bonus": +20 (element affinity - deprecated),
  "hp_bonus": +10~40 (terrain) + chain bonus
}
```

### Land Bonus
```
Formula: HP + (land_level × 10)
Applied when: creature.element == tile.element
Stored in: land_bonus_hp (separate field)
```

## Element Chain
```
Chain  Toll    HP Bonus
1      1.0x    +10
2      1.5x    +20
3      2.5x    +30
4+     4.0x    +40 (max)
```

## Pre-Implementation Checklist
- [ ] Check `docs/README.md` for documentation index
- [ ] Review relevant design documents in `docs/design/`
- [ ] Check for reserved words
- [ ] Verify data structures (especially ability_parsed)
- [ ] Understand turn end flow (never call end_turn directly)
- [ ] Verify system initialization order
- [ ] Use signal-driven communication
- [ ] Add node validity checks
- [ ] Prevent phase duplication
- [ ] Use viewport-relative positioning

Last updated: 2025-10-25
