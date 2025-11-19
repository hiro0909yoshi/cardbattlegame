# Project Structure & Documentation Guide

## Directory Structure

```
cardbattlegame/
├── docs/
│   ├── design/
│   │   ├── hp_structure.md                    # ⭐ HP MASTER (single source of truth)
│   │   ├── skills/
│   │   │   ├── assist_skill.md
│   │   │   ├── resonance_skill.md
│   │   │   ├── transform_skill.md
│   │   │   ├── regeneration_skill.md
│   │   │   └── ... (16 skill types)
│   │   ├── spells/
│   │   │   ├── 領地変更.md
│   │   │   ├── ステータス増減.md
│   │   │   ├── 魔力増減.md
│   │   │   ├── ダイス操作.md
│   │   │   └── 呪い効果.md
│   │   ├── battle_system.md
│   │   ├── map_system.md
│   │   ├── land_system.md
│   │   ├── condition_patterns_catalog.md      # 条件分岐 master
│   │   ├── effect_system_design.md            # エフェクトシステム
│   │   └── ... (other design docs)
│   ├── progress/
│   ├── issues/
│   └── implementation/
│
├── scripts/
│   ├── battle/
│   │   ├── battle_participant.gd              # HP/AP state during battle
│   │   ├── battle_preparation.gd              # Battle setup
│   │   ├── battle_execution.gd                # Attack sequence
│   │   ├── battle_system.gd                   # Main battle flow
│   │   ├── battle_special_effects.gd          # Regeneration, post-battle
│   │   ├── battle_item_applier.gd
│   │   ├── battle_skill_processor.gd
│   │   ├── battle_curse_applier.gd
│   │   └── skills/
│   │       ├── skill_assist.gd                # 援護
│   │       ├── skill_resonance.gd             # 感応
│   │       ├── skill_transform.gd             # 変身・復活
│   │       ├── skill_support.gd               # 応援
│   │       ├── skill_special_creature.gd      # 特殊クリーチャー
│   │       ├── skill_legacy.gd                # 遺産
│   │       └── ... (16 skill types total)
│   │
│   ├── spells/
│   │   ├── spell_land_new.gd                  # 地形操作スペル
│   │   ├── spell_status_change.gd             # ステータス増減
│   │   ├── spell_magic_change.gd              # 魔力増減
│   │   ├── spell_dice_manipulation.gd         # ダイス操作
│   │   └── ... (spell types)
│   │
│   ├── game_flow/
│   │   ├── land_command_handler.gd
│   │   ├── land_action_helper.gd              # Land actions (level up, etc)
│   │   ├── spell_phase_handler.gd
│   │   ├── battle_system.gd                   # LAP system, battle flow
│   │   └── movement_controller.gd
│   │
│   ├── tiles/
│   │   ├── base_tiles.gd
│   │   ├── land_level_system.gd
│   │   └── ... (tile types)
│   │
│   ├── effects/
│   │   ├── effect_manager.gd                  # Apply effects (permanent, temporary)
│   │   └── ... (effect types)
│   │
│   └── ui_components/
│       └── ... (7 UI components)
│
├── data/
│   └── cards.json / creatures.json
│
└── assets/
```

---

## Core Design Documents (Reference)

### 🔥 HP System (MASTER)
**File:** `docs/design/hp_structure.md`
**Status:** ✅ Complete & Current
- State value architecture
- creature_data vs BattleParticipant
- Damage consumption order
- MHP calculation
- Key: base_up_hp is NEVER consumed

### 🎯 Skills (16 Types)
**Folder:** `docs/design/skills/`
**Main Files:**
- assist_skill.md - 援護（手札使用）
- resonance_skill.md - 感応（土地属性条件）
- transform_skill.md - 変身・復活
- regeneration_skill.md - 再生（バトル後HP回復）
- support_skill.md - 応援（盤面ボーナス）
- 他13種類

### ✨ Spells
**Folder:** `docs/design/spells/`
**Main Types:**
- 領地変更.md - Land manipulation
- ステータス増減.md - Status changes
- 魔力増減.md - Magic change
- ダイス操作.md - Dice manipulation
- 呪い効果.md - Curse effects

### ⚔️ Battle System
**File:** `docs/design/battle_system.md`
**Key Topics:**
- Battle flow (preparation → execution → post-battle)
- Participant structure
- Damage calculation
- LAP system (mass growth, dominant growth)

### 🗺️ Map System
**File:** `docs/design/map_system.md`
**Key Topics:**
- Tile structure
- Land bonuses
- Creature placement
- Movement system

### 🏔️ Land System
**File:** `docs/design/land_system.md`
**Key Topics:**
- Land levels (1-4)
- Land bonuses (HP/AP)
- Land elements
- Land commands (level up, etc)

### 🔀 Condition Patterns (分岐条件)
**File:** `docs/design/condition_patterns_catalog.md`
**Coverage:**
- Element-based conditions
- Level-based conditions
- Owner-based conditions
- Time-based conditions (turn, lap)
- Count-based conditions (land count, destroy count)

### 💥 Effect System
**File:** `docs/design/effect_system_design.md`
**Key Topics:**
- Permanent effects (不屈、呪い etc)
- Temporary effects
- Effect application timing
- Effect removal/cancellation

### 🧙 Curse System
**File:** `docs/design/spells/呪い効果.md`
**Key Topics:**
- Curse types
- Curse stat modifications
- Curse application conditions

---

## Main Script Files (Quick Reference)

### Battle Core
- `battle_participant.gd` - HP/AP state (during battle)
- `battle_preparation.gd` - Setup phase
- `battle_execution.gd` - Attack sequence
- `battle_system.gd` - Main flow + LAP system
- `battle_special_effects.gd` - Regeneration, post-battle

### Skills
- `skills/` folder - 16 skill implementations
- Key fix: skill_assist.gd, skill_resonance.gd, skill_special_creature.gd, skill_transform.gd
- All have current_hp synchronization

### Spells & Effects
- `spells/spell_land_new.gd` - Land manipulation
- `spells/spell_*.gd` - Other spell types
- `effects/effect_manager.gd` - Effect application

### Game Flow
- `game_flow/battle_system.gd` - LAP bonuses, battle integration
- `game_flow/land_action_helper.gd` - Land commands
- `game_flow/spell_phase_handler.gd` - Spell execution

---

## Current Development Status (Nov 2025)

### ✅ Completed
- Skills: 16 types fully implemented
- HP Refactoring: COMPLETE (2025-11-20)
- Spell System: Land manipulation, status changes, curse effects
- Battle System: Full flow with LAP system
- Documentation: Comprehensive design docs

### 🔑 Key Implementation Notes

**HP (CRITICAL):**
- current_hp is STATE VALUE (not calculated)
- base_up_hp is NEVER consumed by damage
- Always sync: bonus_hp += value → current_hp += value

**Skills:**
- All 16 skills implemented with proper HP sync
- Last 4 fixed: assist, resonance, special_creature, transform

**Spells:**
- Land manipulation, status changes, dice ops, curse effects
- Applied via spell_phase_handler

**Conditions:**
- Check condition_patterns_catalog.md for all condition types
- Element, level, owner, turn, count based

---

## Workflow Reminders

1. **Start of Chat:**
   - Check docs/README.md for complete index
   - Check progress/daily_log.md for recent work
   - Check issues/issues.md for blockers

2. **For Any System:**
   - Refer to corresponding design doc in docs/design/
   - HP → hp_structure.md (single source of truth)
   - Skills → docs/design/skills/
   - Spells → docs/design/spells/
   - Battle → battle_system.md
   - Map → map_system.md
   - Land → land_system.md
   - Conditions → condition_patterns_catalog.md
   - Effects → effect_system_design.md

3. **After Implementation:**
   - Update progress/daily_log.md
   - Move resolved issues to resolved_issues.md
   - Never modify design/ without approval

---

Last updated: 2025-11-20 (Complete structure & documentation guide)