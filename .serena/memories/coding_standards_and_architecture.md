# Data Structures & Reference

Coding conventions: see `/mnt/skills/user/gdscript-coding/SKILL.md`
Initialization order: see `/mnt/skills/user/gdscript-initialization/SKILL.md`
UI flow rules: see `/mnt/skills/user/gdscript-ui-flow/SKILL.md`

## Card Data Structures (JSON)

### Creature
id, name, rarity, type, element, cost{ep, lands_required}, ap, hp, ability, ability_detail, ability_parsed

### Item
id, name, rarity, type, item_type, cost{ep}, effect, effect_parsed

### Spell
id, name, rarity, type, spell_type, cost{ep}, effect, effect_parsed, cpu_rule

## ability_parsed Structure
```json
{
  "keywords": ["強打", "先制", "感応"],
  "keyword_conditions": { "keyword_name": { ... } },
  "effects": [{
    "effect_type": "power_strike|instant_death|item_return|...",
    "trigger": "after_item_use|battle_start|...",
    "target": "self|enemy|all_enemies|all_items",
    "stat": "AP|HP",
    "operation": "add|multiply",
    "value": 20,
    "multiplier": { ... },
    "elements": [...],
    "conditions": [{
      "condition_type": "adjacent_ally_land|mhp_below|...",
      "value": 40
    }],
    "return_type": "return_to_deck|return_to_hand"
  }],
  "mystic_arts": [{ "id": int, "name": str, "description": str, "spell_id": int, "cost": int }]
}
```

## Runtime creature_data Fields
- `base_up_hp`, `base_up_ap`: permanent stat boosts (mass growth, synthesis, lap bonus)
- `current_hp`: HP after battle
- `curse`: curse Dictionary
- `items`: equipped items (battle only)
- `permanent_effects`, `temporary_effects`: effect arrays

## GamePhase Enum
```gdscript
enum GamePhase { SETUP, DICE_ROLL, MOVING, TILE_ACTION, BATTLE, END_TURN }
```
