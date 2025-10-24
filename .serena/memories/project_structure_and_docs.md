# Project Structure & Documentation Guide

## Critical Rule: docs/ Management

**ALWAYS check these on chat start:**
```bash
cat docs/README.md           # Complete doc index
cat docs/progress/daily_log.md  # Recent work
cat docs/issues/issues.md    # Active issues only
```

## Directory Structure
```
cardbattlegame/
├── docs/
│   ├── README.md        # Complete doc index (START HERE)
│   ├── quick_start/     # Chat start guide
│   ├── design/          # ⚠️ READ-ONLY (user must approve changes)
│   ├── progress/        # ✅ UPDATE freely
│   ├── issues/          # ✅ UPDATE actively
│   │   ├── issues.md           # Current issues only
│   │   └── resolved_issues.md  # Archive
│   └── implementation/  # Implementation patterns
├── scripts/
│   ├── game_flow/       # Flow handlers (land_command, tile_action, spell_phase)
│   ├── skills/          # Skill system
│   ├── tiles/           # Tile classes
│   └── ui_components/   # 7 UI components
├── data/                # JSON card definitions
└── assets/              # Images, models
```

## Code Refactoring Patterns

### Success Case: Large File Splitting
**TileActionProcessor** (1284L → 5 files, +0% overhead)
**LandCommandHandler** (881L → 4 files, +12% overhead)

**Key principles:**
1. Static helper functions (no instances needed)
2. No new signal connections
3. Single source of truth for state
4. Minimal wrapper methods
5. Zero backward-compat bloat

## Documentation Update Rules

### design/ - READ ONLY
- Never modify without explicit user approval
- Used as reference during implementation
- Contains core architecture & specs
- Full index available in `docs/README.md`

### issues/ - UPDATE ACTIVELY
**When to update:**
- Bug found: Add BUG-XXX to issues.md (concise)
- Bug fixed: Move to resolved_issues.md (detailed)
- Task done: Check off in tasks.md
- New finding: Add note to issues.md

**Format:**
- Priority: Critical/High/Medium/Low
- Status: 🚧Investigating / ⚠️Need fix / ✅Resolved
- Keep issues.md simple (1-2 lines per issue)
- Put details in resolved_issues.md

### progress/ - UPDATE ON COMPLETION
- Check off completed tasks in daily_log.md
- Note implementation details
- Link to issues if problems found
- Remove old logs (keep recent only)

## Workflow

### Start of Chat
1. Activate project
2. Read `docs/quick_start/new_chat_guide.md` for quick reference
3. Check `docs/progress/daily_log.md` for recent work
4. Check `docs/issues/issues.md` for blockers
5. Use `docs/README.md` to find relevant design docs

### During Implementation
- Bug found → Add to issues.md immediately
- New insight → Add note to issues.md

### After Implementation
- Update progress/daily_log.md
- Move resolved issues to resolved_issues.md
- DO NOT modify design/ (unless told to)

## Important Documents

| File | Purpose | Update Rights |
|------|---------|--------------|
| docs/README.md | Complete doc index | Read only |
| docs/quick_start/new_chat_guide.md | Chat start guide | Read only |
| docs/progress/daily_log.md | Recent work | Update actively |
| docs/issues/issues.md | Active issues | Update actively |
| docs/issues/resolved_issues.md | Archive | Add on resolve |
| docs/design/* | Detailed specs | Read only |

## Current Development Status (Oct 2025)
- ✅ Skills: 16 types implemented
- ✅ Effect System: Phase 1-3 complete
- ✅ Defense Creatures: 21 implemented
- ✅ Battle Test Tool: Complete
- ✅ Documentation: Restructured with complete index
- 📋 Next: Additional skills implementation

## Key Reminders
1. Start with `docs/README.md` for complete index
2. Check `docs/quick_start/new_chat_guide.md` on every chat start
3. Read design/ for specs (don't modify)
4. Add bugs to issues.md immediately (concise)
5. Update progress/daily_log.md after tasks
6. Never change design/ without user approval

Last updated: 2025-10-25
