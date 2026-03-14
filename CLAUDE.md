# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ✅ アーキテクチャ移行完了（Phase 0-10D）

全Phase完了済み。成果: コード約700行削減、38個のUI Signal、7/8ハンドラーUI層完全分離、UIManagerランタイム双方向参照ゼロ。
詳細は `docs/progress/refactoring_next_steps.md` を参照。

---

## 🎯 アーキテクチャ原則

1. **ツリー構造の遵守** - 各システムは1つの親、シグナルは子→親、横断的依存を避ける
2. **新機能追加時** - `TREE_STRUCTURE.md` で配置確認、DI で参照注入、`is_connected()` チェック必須
3. **参照ドキュメント**: `docs/design/TREE_STRUCTURE.md`, `docs/design/dependency_map.md`

### アンチパターン防止チェック

**UI層分離**: ハンドラーで `ui_manager.` 直接呼び出し禁止 → Signal emit パターンを使用
**カメラモード**: 操作フェーズで `enable_manual_camera()`、終了時に `enable_follow_camera()`
**リファクタリング安全**: 削除前に `grep -r` で呼び出し元ゼロ確認、副作用の代替確認

---

## Project Overview

**カルドセプト風カードバトルゲーム** - A 3D tactical card battle game inspired by Culdcept, built with Godot 4.5.

- **Engine**: Godot 4.5 (3D, Forward+ rendering)
- **Language**: GDScript exclusively
- **Platform**: macOS (M4 MacBook Air), cross-platform design
- **Genre**: Hybrid board game + card game + strategy RPG
- **Documentation**: Extensively documented in Japanese in `docs/` directory

## Architecture Overview

### Core Systems

```
GameFlowManager (Central state machine)
├── BoardSystem3D (3D board management)
│   ├── TileNeighborSystem, MovementController3D, TileDataManager, TileActionProcessor
├── CardSystem (deck/hand/discard management)
├── BattleSystem (combat resolution)
│   ├── BattlePreparation, BattleExecution, BattleSkillProcessor, ConditionChecker
├── PlayerSystem, PlayerBuffSystem, SkillSystem, SpecialTileSystem, LapSystem
├── UIManager (5 services: Navigation, Message, CardSelection, InfoPanel, PlayerInfo)
├── BattleScreenManager (battle animations)
└── SpellSystemContainer (10 spell systems + SpellUIManager + CPUSpellAIContainer)
```

### Initialization System

**GameSystemManager** (`scripts/system_manager/game_system_manager.gd`):
- 3-phase initialization: Core systems → Handlers/Spells → UI/Reference injection
- Critical sequence in game_3d.gd: GSM作成 → UIManager設定 → setup_systems() → setup_3d_mode()

### Game Flow

```
Turn Start → Draw Card → Spell Phase → Dice Roll → Movement → Tile Landing
	→ (Empty Tile: Summon) OR (Enemy Tile: Battle)
	→ Land Commands (Level Up / Move Creature / Swap)
	→ Turn End → Next Player
```

### Key Architectural Patterns

1. **Signal-Based Communication** - `is_connected()` チェック必須（BUG-000 教訓）
2. **Subsystem Delegation** - BoardSystem3D, GFM 等が専門サブシステムに委譲
3. **Data-Driven Design** - JSON files: creatures(5元素×2), spells(×2), items
4. **BattleParticipant Pattern** - 一時的修正をベースステータスと分離管理
5. **Autoload Singletons** - DebugSettings, CardLoader, UserCardDB, GameData, CpuDeckData
6. **Direct Reference + Container Pattern** - SpellSystemContainer で10システム集約、DI で参照注入

## Critical Implementation Details

### Down State System
- Tiles become "down" after actions (summon, level up, move, swap)
- **Exception**: "Indomitable" (奮闘) skill creatures never go down

### Land Bonus System
```gdscript
land_bonus_hp = land_level × 10
total_hp = base_hp + land_bonus_hp
```

### Skill System
- 11 implemented skills, detailed specs in `docs/design/skills_design.md`
- Order: Resonance → Power Strike → Double Attack → Attack → Instant Death → Regeneration

### Effect System
1. **Battle-only**: Items (AP+30, HP+40) - removed after battle
2. **Temporary**: Spells (HP+10) - removed on movement
3. **Permanent**: Mass Growth effects - persist until swap

### Item Skill System
- Items use `effect_parsed` (not `ability_parsed`)
- Two-stage: `stat_bonus` in preparation, `effects` in execution

### Spell Core Systems (10)
```
spell_draw, spell_magic, spell_land, spell_curse, spell_dice,
spell_curse_stat, spell_world_curse, spell_player_move, spell_curse_toll, spell_cost_modifier
```

## File Organization

### Key Directories
```
scripts/
├── autoload/           # DebugSettings etc.
├── system_manager/     # GameSystemManager
├── game_flow/          # GFM + 7 handlers + SpellUIManager
├── battle/             # BattleSystem + 4 subsystems
├── skills/             # effect_combat.gd
├── spells/             # SpellSystemContainer + 25+ files
├── ui_components/      # 15+ UI components
├── cpu_ai/             # CPU AI + CPUSpellAIContainer
├── battle_screen/      # Battle animations
├── tiles/, creatures/, quest/, tutorial/, helpers/, utils/
├── save_data/          # Save/load system
└── network/            # Network functionality

data/
├── {fire,water,earth,wind,neutral}_{1,2}.json  # Creatures
├── spell_{1,2}.json                             # Spells
└── item.json                                    # Items
```

## Development Workflow

### Agent Workflow

**Opus**: 対話・企画・計画・設計判断 | **Haiku**: 実装・コード記述 | **Sonnet**: 廃止

### Before Making Changes
1. Check `docs/README.md` first
2. Review `docs/progress/daily_log.md`
3. Consult `docs/implementation/implementation_patterns.md`

### Coding Standards
- GDScript規約: `gdscript-coding` skill に従う
- 詳細: `docs/development/coding_standards.md`

### Documentation Rules
- `docs/design/` はユーザー指示なしに変更禁止
- 作業完了後は `docs/progress/daily_log.md` を更新
- 作業計画は `docs/progress/refactoring_next_steps.md` に記録

### Mandatory Update Rules
- シグナル追加 → `docs/implementation/signal_catalog.md`
- 委譲メソッド追加 → `docs/implementation/delegation_method_catalog.md`
- 新規ドキュメント作成前にユーザー確認必須

### Common Tasks

**New Creature**: JSON file → `implementation_patterns.md` テンプレート → validate → document
**New Skill**: `ability_parsed` 定義 → `BattleSkillProcessor` 実装 → `ConditionChecker` → document
**Item Skill**: `effect_parsed` 定義 → `BattlePreparation` → `BattleSkillProcessor` → document

## Known Issues and Constraints

- **BUG-000**: ✅ RESOLVED - `is_connected()` チェックで解決済み
- **P0**: null参照チェック追加（進行中）→ `refactoring_next_steps.md`
- **Deprecated**: 属性相性システム、game.tscn (2D版)
- **Design**: 3D-only, Diamond board (20 tiles), Turn-based, Current player hand only

## Important Notes

- JSON: Creatures=`ability_parsed`, Items=`effect_parsed`, `duplicate(true)` 必須
- UI: viewport-relative positioning のみ
- GDScript: `owner` → `tile_owner`, null許容型の戻り値宣言に注意
- Signal: 必ず `is_connected()` チェック後に接続

## Quick Reference

- `docs/design/design.md` - Master architecture
- `docs/design/skills_design.md` - Skill specs
- `docs/implementation/implementation_patterns.md` - Code templates
- `docs/progress/daily_log.md` - Recent work
- `docs/progress/refactoring_next_steps.md` - Current/planned work

## エージェント行動ガイドライン

### 確認不要（直接実行）
- ファイル作成・編集・削除、テスト実行、git commit
- ドキュメント: CLAUDE.md, docs/ 配下の更新

### 絶対禁止
- `git init` などリポジトリ初期化操作は一切行わない

### 確認必須（チャットで直接確認）
以下の操作は **AskUserQuestion ツールを使わず**、通常のテキスト出力で確認すること。
例:「`git push origin main` を実行しますがよろしいですか？」→ ユーザーがチャットに直接入力で返答を待つ。
- git push, git push --force
- git reset --hard, git revert（コミット済みコードのロールバック）
- GitHub PR/Issue 操作
- セーブデータ削除

---

**Last Updated**: 2026-03-01 | Opus + Haiku
