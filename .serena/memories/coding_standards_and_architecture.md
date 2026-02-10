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

## MHP/AP Calculation Standards (2026-02-11)

### MHP (Maximum HP) Calculation
MHP = 元のベースHP(`hp`) + 永続的基礎HP上昇(`base_up_hp`)

**CRITICAL**: Always use `BattleParticipant.get_max_hp()` when available (returns base_hp + base_up_hp)

```gdscript
// ❌ BAD: Incomplete calculation (missing base_up_hp)
var mhp = creature_data.get("hp", 0)

// ✅ GOOD: Use BattleParticipant method (in battle)
var mhp = participant.get_max_hp()  // Returns: base_hp + base_up_hp

// ✅ GOOD: creature_data only (outside battle)
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
```

**CRITICAL Rules**:
- `creature_data["hp"]` = 元のカードデータ値。**絶対に変更しない**
- `creature_data["current_hp"]` = 現在HP（バトル後の残りHP保存先）
- `creature_data["base_up_hp"]` = マスグロース・合成・周回ボーナスでのみ変更

### AP (Attack Power) Calculation
AP = 元のAP(`ap`) + 永続的基礎AP上昇(`base_up_ap`)

**NOTE**: コード内にST（旧称）が残っている箇所があるが、正しい用語は**AP**

```gdscript
// ✅ GOOD: Base AP calculation
var base_ap = creature_data.get("ap", 0) + creature_data.get("base_up_ap", 0)

// ✅ GOOD: In battle, use current_ap (includes all bonuses)
var attack_power = participant.current_ap
```

### Context Key Names - UNIFIED STANDARD

**tile_info vs context で異なるキー名**:
- `tile_info.get("level", 1)` — タイル情報Dictionaryのキーは `"level"`
- `context.get("tile_level", 1)` — バトルコンテキストのキーは `"tile_level"`
- ❌ 旧キー名 `"current_land_level"` は廃止済み

**コスト**: 常に `cost.ep`（Energy Point）。`mp` は旧称で使わない。

### GamePhase Enum & Phase Guard Pattern
```gdscript
enum GamePhase { SETUP, DICE_ROLL, MOVING, TILE_ACTION, BATTLE, END_TURN }

// end_turn() の二段チェック:
if is_ending_turn: return      // Flag guard (fastest)
if current_phase == GamePhase.END_TURN: return  // State guard
is_ending_turn = true          // Set flag ASAP
```

### Card Data Structures (JSON)
- Creature: id, name, rarity, type, element, cost{ep, lands_required}, ap, hp, ability, ability_detail, ability_parsed
- Item: id, name, rarity, type, item_type, cost{ep}, effect, effect_parsed
- Spell: id, name, rarity, type, spell_type, cost{ep}, effect, effect_parsed, cpu_rule

### ability_parsed Structure
- keywords: String array (e.g. ["強打", "先制", "感応"])
- keyword_conditions: Dict keyed by keyword name
- effects: Array of effect dicts (effect_type, trigger, target, stat, multiplier, elements, conditions)
- mystic_arts: Array of {id, name, description, spell_id, cost}

### Runtime creature_data Fields (added during gameplay)
- base_up_hp, base_up_ap: permanent stat boosts
- current_hp: current HP after battle
- curse: curse Dictionary
- items: equipped items (battle only)
- permanent_effects, temporary_effects: effect arrays

### System Initialization
See SKILL.md (`/mnt/skills/user/gdscript-coding/SKILL.md`) for detailed 6-phase initialization order.
SKILL.md is the Single Source of Truth for initialization — docs may be outdated.

Last updated: 2026-02-11
