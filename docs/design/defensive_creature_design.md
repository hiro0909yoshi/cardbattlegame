# 防御型クリーチャー設計書

**Project**: Culdcept-style Card Battle Game  
**Version**: 1.1  
**Last Updated**: October 25, 2025

---

## Overview

Defensive creatures have higher base stats but come with action restrictions.

## Features

### Benefits
- High base HP
- Can counterattack normally when defending
- Can be leveled up
- Can use exchange command

### Restrictions
1. **Cannot invade** - Cannot be used as battle cards
2. **Cannot move** - Movement command disabled in land menu
3. **Can only be summoned on empty lands** - Cannot be placed on owned or enemy lands

---

## Data Structure

### JSON Definition

```json
{
  "id": 102,
  "name": "アクアナイト",
  "type": "creature",
  "creature_type": "defensive",
  "ap": 0,
  "hp": 40,
  "ability": "防御型"
}
```

### Field Description

| Field | Type | Description |
|-------|------|-------------|
| `creature_type` | String | `"defensive"` for defensive type |
| | | `"normal"` (default) for regular creatures |

---

## Implementation Summary

### 1. Summon Restriction

**Implementation File**: `scripts/tile_action_processor.gd` → `execute_summon()`

**Constraint**:
- Can only summon on `tile_info["owner"] == -1` (empty land)
- Cannot summon on own or enemy lands
- Error message on violation: "防御型は空き地にのみ召喚可能です"

**Implementation Point**:
```gdscript
var creature_type = card_data.get("creature_type", "normal")
if creature_type == "defensive":
	if tile_info["owner"] != -1:
		# Cannot summon
```

### 2. Movement Restriction

**Implementation File**: `scripts/ui_components/dominio_order_ui.gd` → `show_action_menu()`

**UI Display**:
- Move button is grayed out (disabled)
- Button text: "🚶 [M] 移動 (防御型)"

**Implementation Point**:
```gdscript
var creature_type = creature.get("creature_type", "normal")
if creature_type == "defensive":
	action_menu_buttons["move"].disabled = true
```

### 3. Invasion Restriction (Cannot Use in Battle)

**Implementation Files**: 
- `scripts/ui_components/hand_display.gd` → `create_card_node()`
- `scripts/ui_components/card_selection_ui.gd` → `enable_card_selection()`

**UI Display**:
- Defensive cards are grayed out during battle
- Cards are not selectable (`is_selectable = false`)

**Implementation Points**:
```gdscript
# hand_display.gd
if filter_mode == "battle":
	var creature_type = card_data.get("creature_type", "normal")
	if creature_type == "defensive":
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)

# card_selection_ui.gd
if filter_mode == "battle":
	var creature_type = card_data.get("creature_type", "normal")
	is_selectable = card_type == "creature" and creature_type != "defensive"
```

---

## Defensive Creatures List

**Implemented (21 total)**

| ID | Name | Element |
|----|------|---------|
| 5 | オールドウィロウ | 🔥 Fire |
| 10 | クリーピングフレイム | 🔥 Fire |
| 29 | バーナックル | 🔥 Fire |
| 102 | アイスウォール | 💧 Water |
| 123 | シーボンズ | 💧 Water |
| 126 | スワンプスボーン | 💧 Water |
| 127 | ゼラチンウォール | 💧 Water |
| 141 | マカラ | 💧 Water |
| 205 | カクタスウォール | 🌍 Earth |
| 221 | スクリーマー | 🌍 Earth |
| 223 | ストーンウォール | 🌍 Earth |
| 240 | マミー | 🌍 Earth |
| 244 | ランドアーチン | 🌍 Earth |
| 246 | レーシィ | 🌍 Earth |
| 330 | トルネード | 💨 Wind |
| 411 | グレートフォシル | ⬜ Neutral |
| 413 | ゴールドトーテム | ⬜ Neutral |
| 421 | スタチュー | ⬜ Neutral |
| 423 | ストーンジゾウ | ⬜ Neutral |
| 444 | レジェンドファロス | ⬜ Neutral |
| 447 | ワンダーウォール | ⬜ Neutral |

---

## Battle Flow

### Behavior When Defending

Defensive creatures counterattack normally when defending, just like regular creatures:

```
1. Enemy creature invades defensive creature's land
   ↓
2. Skill application (land bonus, resonance, etc.)
   ↓
3. Attack order determination (first strike check)
   ↓
4. Battle execution
   - Invader's attack
   - Defensive creature's counterattack (if alive)
   ↓
5. Result determination
```

**Important**: Defensive creatures "cannot invade" but they CAN attack when defending.

## Design Philosophy

### Why use `creature_type`?

1. **Separation from Skills**
   - Skills = Battle abilities
   - Type = Game flow properties

2. **Clear Determination Points**
   - Skill check: `ability_parsed.keywords`
   - Type check: `creature_type`

3. **Extensibility**
   - Easy to add new creature types
   - Minimal impact on existing code

---

## Related Files

### Implementation Files

| File | Role |
|------|------|
| `scripts/tile_action_processor.gd` | Summon restriction |
| `scripts/ui_components/dominio_order_ui.gd` | Movement restriction UI |
| `scripts/ui_components/hand_display.gd` | Invasion restriction UI (grayout) |
| `scripts/ui_components/card_selection_ui.gd` | Invasion restriction (not selectable) |

### Data Files

- `data/water_1.json` - アイスウォール (ID:102)
- `data/earth_1.json` - カクタスウォール (ID:205)
- Other element JSON files

---

## Change History

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-23 | 1.0 | Implemented `creature_type: "defensive"` for all 21 defensive creatures |
| 2025-10-25 | 1.1 | Simplified documentation: Removed test methods, future plans, simplified creature list |

---

**Last Updated**: October 25, 2025 (v1.1)
