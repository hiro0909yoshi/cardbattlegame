# Coding Standards & Critical Constraints

## Must-Read Before Coding
Check `docs/README.md` for complete documentation index.

## Reserved Words & Forbidden Methods

### Reserved Words to Avoid
```gdscript
// ❌ BAD: Godot reserved words
var owner: int           // Use: tile_owner_id
func is_processing()     // Use: is_battle_active()

// ✅ GOOD
var tile_owner_id: int
func is_battle_active() -> bool
```

### Forbidden Methods on Nodes
```gdscript
// ❌ BAD: has() doesn't exist on Node objects
if tile.has("property"):  // Error: Nonexistent function 'has'

// ✅ GOOD: Direct property access
if tile.property:         // Works for @export vars
var value = tile.property

// ✅ GOOD: Use get() only for Dictionary
if dict.has("key"):       // OK for Dictionary
var value = dict.get("key", default)
```

**CRITICAL**: `has()` is a Dictionary method, NOT a Node method. Never use `node.has("property")`.

### TextureRect Constraint
```gdscript
// ❌ BAD: color property doesn't work
texture_rect.color = Color.RED

// ✅ GOOD: Use modulate instead
texture_rect.modulate = Color.RED
```

## MHP/ST Calculation Standards (2025-10-30)

### MHP (Maximum HP) Calculation
**CRITICAL**: Always use `BattleParticipant.get_max_hp()` when available

```gdscript
// ❌ BAD: Direct calculation (risk of missing base_up_hp)
var mhp = creature_data.get("hp", 0)

// ❌ BAD: Incomplete calculation
var mhp = attacker.creature_data.get("hp", 0)  // Missing base_up_hp!

// ✅ GOOD: Use BattleParticipant method
var mhp = participant.get_max_hp()  // Returns: base_hp + base_up_hp

// ✅ GOOD: JSON data only (no BattleParticipant available)
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
```

**Formula**: `MHP = base_hp + base_up_hp` (永続的な基礎HP、戦闘ボーナスは含まない)

### ST (Strength/Attack Power) Calculation
```gdscript
// ✅ GOOD: Base ST calculation
var base_st = creature_data.get("ap", 0) + creature_data.get("base_up_ap", 0)
```

### Context Key Names - UNIFIED STANDARD
**土地レベル**: Always use `"tile_level"` (NOT `"current_land_level"`)

```gdscript
// ❌ BAD: Old key name (deprecated 2025-10-30)
var level = context.get("current_land_level", 1)

// ✅ GOOD: Unified key name
var level = context.get("tile_level", 1)
```

**Modified files (2025-10-30)**:
- `scripts/battle/battle_execution.gd`
- `scripts/skills/skill_effect_base.gd`

### BattleParticipant Helper Methods
Available in `scripts/battle_participant.gd`:

```gdscript
// MHP取得
participant.get_max_hp() -> int  // base_hp + base_up_hp

// ダメージ判定
participant.is_damaged() -> bool  // current_hp < MHP

// HP割合
participant.get_hp_ratio() -> float  // 0.0 ~ 1.0

// MHP条件チェック（汎用）
participant.check_mhp_condition(operator: String, threshold: int) -> bool
// operator: "<", "<=", ">", ">=", "=="

// MHP条件チェック（簡易版）
participant.is_mhp_below_or_equal(threshold: int) -> bool
participant.is_mhp_above_or_equal(threshold: int) -> bool
participant.is_mhp_in_range(min: int, max: int) -> bool

```

**Usage Example**:
```gdscript
// 無効化判定（battle_special_effects.gd）
func _check_nullify_mhp_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
    var threshold = condition.get("value", 0)
    return attacker.get_max_hp() >= threshold  // ✅ Unified method

// ジェネラルカンのMHP50以上カウント（battle_skill_processor.gd）
var creature_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
if creature_mhp >= 50:  // ✅ Correct calculation
    qualified_count += 1
```

## Naming Conventions (2026-01-16)

### Initialization Methods
メソッドの処理内容に応じて使い分ける：

| メソッド名 | 用途 | 処理内容 |
|-----------|------|---------|
| `_init()` | コンストラクタ | 外部依存なし |
| `initialize()` | 初期化 | 外部システム参照を受け取り、内部で`new()`で子オブジェクトも生成 |
| `setup()` / `setup_systems()` | 初期化 | `initialize()`と同義、複数システムを受け取る場合に使用 |
| `setup_with_context()` | context初期化 | contextを受け取り、内部で子オブジェクトも生成 |
| `set_xxx()` | 単一値設定 | 1つのプロパティをセット、後から変更可能 |
| `set_context()` | context設定 | contextオブジェクトを保存するだけ（子オブジェクト生成なし） |

**判定基準**:
- `new()`で子オブジェクト生成あり → `initialize()` または `setup_with_context()`
- context保存のみ → `set_context()` でOK
- 子への伝播のみ → `set_context()` でOK

```gdscript
// ❌ BAD: 名前と処理が不一致
func set_context(context):
    _context = context
    target_resolver = CPUTargetResolver.new()  # new()があるのにset_context

// ✅ GOOD: 処理に合った名前
func initialize(context):
    _context = context
    target_resolver = CPUTargetResolver.new()  # 初期化処理なのでinitialize
```

### Reference Variable Naming (`_ref` suffix)
現状、プロジェクト内で混在している（統一されていない）：
- battle系: `board_system_ref`, `card_system_ref` (`_ref`あり)
- その他: `board_system`, `card_system` (`_ref`なし)

**現状維持**: 動作に影響なし。新規コードでは既存ファイルのスタイルに合わせる。

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

## UI Positioning - ABSOLUTE RULE

**CRITICAL: ALL UI elements must use viewport-relative positioning**

### The Golden Rule
```gdscript
// ❌ NEVER DO THIS: Hardcoded coordinates
panel.position = Vector2(1200, 100)  // Breaks on different screen sizes

// ✅ ALWAYS DO THIS: Viewport-relative
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20    // 20px from right edge
var panel_y = (viewport_size.y - panel_height) / 2  // Vertically centered
panel.position = Vector2(panel_x, panel_y)
```

### Positioning Formulas

**Horizontal (X-axis)**:
- Left align: `margin`
- Center: `(viewport_size.x - width) / 2`
- Right align: `viewport_size.x - width - margin`

**Vertical (Y-axis)**:
- Top align: `margin`
- Center: `(viewport_size.y - height) / 2`
- Bottom align: `viewport_size.y - height - margin`

### Standard Margins
- Screen edge: 10-20px
- Between UI elements: 5-10px

### Example: Bottom-right panel
```gdscript
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - 300 - 20  // 300px wide, 20px margin
var panel_y = viewport_size.y - 200 - 20  // 200px tall, 20px margin
panel.position = Vector2(panel_x, panel_y)
```

**WHY THIS MATTERS**: Game runs on multiple resolutions. Hardcoded positions break instantly.

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
Applied when: creature.element == tile.tile_type
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
- [ ] Never use node.has() - use direct property access
- [ ] **Use BattleParticipant.get_max_hp() for MHP calculations**
- [ ] **Use unified key name "tile_level" (not "current_land_level")**
- [ ] Verify data structures (especially ability_parsed)
- [ ] Understand turn end flow (never call end_turn directly)
- [ ] Verify system initialization order
- [ ] Use signal-driven communication
- [ ] Add node validity checks
- [ ] Prevent phase duplication
- [ ] **Use viewport-relative positioning (NEVER hardcode coordinates)**

Last updated: 2026-01-16
