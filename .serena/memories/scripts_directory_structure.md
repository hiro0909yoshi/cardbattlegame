# Scripts Directory Structure (Updated: 2026-02-11, game_flow_manager split)

## Root (`scripts/`)

### Main Systems
- `game_flow_manager.gd` - Turn/phase control
- `board_system_3d.gd` - 3D board, tile ownership
- `player_system.gd` - Player state, magic
- `card_system.gd` - Deck/hand management
- `battle_system.gd` - Battle processing
- `creature_manager.gd` - Centralized creature data
- `ui_manager.gd` - UI orchestration
- `tile_action_processor.gd` - Tile action processing (core, delegates to summon/battle executors)
- `debug_settings.gd` - Debug settings (static flags)
- `tile_data_manager.gd` - Tile info, toll calculation
- `movement_controller.gd` - Player movement (core, delegates to 5 sub-systems)
- `movement_direction_selector.gd` - Direction selection UI (+1/-1)
- `movement_branch_selector.gd` - Branch tile selection UI
- `movement_destination_predictor.gd` - Destination prediction & highlight
- `movement_warp_handler.gd` - Warp, pass-through events, forced stop
- `movement_special_handler.gd` - Checkpoint, heal, down clear, dice buff, camera
- `effect_manager.gd` - Effect management
- `special_tile_system.gd` - Special tile processing
- `player_buff_system.gd` - Player buff management

### Card & Player
- `card.gd` - Card node script
- `card_loader.gd` - Card JSON loader
- `player_card_manager.gd` - Player card management
- `player_movement.gd` - Player movement
- `user_card_db.gd` - User card database

### Utilities
- `game_constants.gd` - All game constants
- `signal_registry.gd` - Signal registry
- `tile_neighbor_system.gd` - Adjacent tile detection
- `tile_helper.gd` - Tile utilities
- `tile_info_display.gd` - Tile info display
- `game_data.gd` - Save/load
- `game_settings.gd` - Settings management
- `settings.gd` - Settings screen
- `special_tile_descriptions.gd` - Special tile descriptions

### Scene Scripts
- `game_3d.gd` - Main game scene
- `main_menu.gd` - Main menu
- `album.gd` - Album screen
- `deck_select.gd` / `deck_editor.gd` - Deck select/edit
- `cpu_deck_select.gd` / `cpu_deck_editor.gd` / `cpu_deck_data.gd` - CPU deck
- `camera_controller.gd` - Camera control
- `debug_controller.gd` - Debug features
- `shop.gd` - Shop
- `gacha_system.gd` - Gacha
- `tutorial_select.gd` - Tutorial select

### Help Pages
- `help.gd`, `help_skill.gd`, `help_down_state.gd`, `help_dominion_command.gd`
- `help_arcana_arts.gd`, `help_special_tile.gd`, `help_info_panel.gd`, `help_card_symbol.gd`

---

## `/system_manager/`
- `game_system_manager.gd` - 6-phase init, system orchestration

---

## `/cpu_ai/` (28 files)

### Core
- `cpu_ai_handler.gd` - Unified handler (phase dispatch)
- `cpu_ai_context.gd` - Shared context (system refs)
- `cpu_ai_constants.gd` - AI constants

### Turn Processing
- `cpu_turn_processor.gd` - Turn processing (summon, level up, etc.)
- `cpu_tile_action_executor.gd` - Tile action execution
- `cpu_movement_evaluator.gd` - Movement/direction evaluation
- `checkpoint_distance_calculator.gd` - Checkpoint distance calc

### Battle AI
- `cpu_battle_ai.gd` - Battle decisions
- `cpu_battle_policy.gd` - Battle policy
- `cpu_defense_ai.gd` - Defense decisions
- `cpu_battle_defense_evaluator.gd` - Defense evaluation
- `cpu_merge_evaluator.gd` - Merge evaluation
- `cpu_instant_death_evaluator.gd` - Instant death evaluation
- `cpu_holy_word_evaluator.gd` - Holy Word evaluation
- `battle_simulator.gd` - Battle result simulation

### Spell/Mystic AI
- `cpu_spell_ai.gd` - Spell usage decisions
- `cpu_spell_phase_handler.gd` - Spell phase processing
- `cpu_mystic_arts_ai.gd` - Arcana Arts decisions
- `cpu_spell_condition_checker.gd` - Spell condition check
- `cpu_spell_target_selector.gd` - Spell target selection
- `cpu_target_resolver.gd` - Target resolution
- `cpu_spell_utils.gd` - Spell utilities

### Territory AI
- `cpu_territory_ai.gd` - Dominio order decisions
- `cpu_sacrifice_selector.gd` - Sacrifice card selection
- `cpu_special_tile_ai.gd` - Special tile decisions

### Utilities
- `cpu_hand_utils.gd` - Hand management utilities
- `cpu_board_analyzer.gd` - Board analysis
- `cpu_curse_evaluator.gd` - Curse evaluation
- `card_rate_evaluator.gd` - Card rate evaluation

---

## `/game_flow/` (15 files)

- `spell_phase_handler.gd` - Spell phase management
- `spell_effect_executor.gd` - Spell effect execution
- `item_phase_handler.gd` - Item phase management
- `lap_system.gd` - Lap system
- `bankruptcy_handler.gd` - Bankruptcy handling
- `movement_helper.gd` - Movement processing
- `debug_command_handler.gd` - Debug commands
- `tile_summon_executor.gd` - Summon execution (split from tile_action_processor)
- `tile_battle_executor.gd` - Battle execution (split from tile_action_processor)
- `game_result_handler.gd` - Game result processing (split from game_flow_manager)

### Land Command
- `dominio_command_handler.gd` - Dominio command management
- `land_action_helper.gd` - Dominio action execution
- `land_selection_helper.gd` - Dominio selection
- `land_input_helper.gd` - Dominio input processing

### Target Selection
- `target_selection_helper.gd` - Target selection helper
- `target_finder.gd` - Target search
- `target_ui_helper.gd` - Target UI management
- `target_marker_system.gd` - Target marker display

---

## `/battle/` (8 files + skills/)

- `battle_participant.gd` - Battle participant class
- `battle_preparation.gd` - Battle prep (item selection)
- `battle_execution.gd` - Battle execution
- `battle_skill_processor.gd` - Skill processing
- `battle_special_effects.gd` - Special effects
- `battle_item_applier.gd` - Item effect application
- `battle_curse_applier.gd` - Curse effect application
- `battle_skill_granter.gd` - Skill granting

### `/battle/skills/` (24 files)
- `skill_first_strike.gd`, `skill_double_attack.gd`, `skill_power_strike.gd`
- `skill_penetration.gd`, `skill_reflect.gd`, `skill_resonance.gd`
- `skill_support.gd` / `skill_assist.gd`, `skill_merge.gd`, `skill_transform.gd`
- `skill_scroll_attack.gd`, `skill_land_effects.gd`, `skill_stat_modifiers.gd`
- `skill_item_return.gd`, `skill_item_creature.gd`, `skill_item_manipulation.gd`
- `skill_creature_spawn.gd`, `skill_magic_steal.gd` / `skill_magic_gain.gd`
- `skill_special_creature.gd`, `skill_battle_start_conditions.gd`
- `skill_battle_end_effects.gd`, `skill_permanent_buff.gd`, `skill_legacy.gd`

---

## `/skills/` (6 files)
- `condition_checker.gd` - Condition checking
- `skill_effect_base.gd` - Effect base class
- `skill_log_system.gd` - Skill log
- `skill_secret.gd` - Arcana Arts
- `skill_toll_change.gd` - Toll change
- `creature_synthesis.gd` - Creature synthesis

---

## `/spells/` (26 files + spell_draw/)

### Core
- `spell_draw.gd` - Draw entry point
- `spell_magic.gd` - Magic manipulation
- `spell_curse.gd` - Curse management
- `spell_dice.gd` - Dice manipulation
- `spell_damage.gd` - Damage processing

### spell_draw/ (5 sub-handlers)
- `basic_draw_handler.gd`, `condition_handler.gd`, `deck_handler.gd`
- `steal_handler.gd`, `destroy_handler.gd`

### Curse Types
- `spell_curse_stat.gd` - Stat curse
- `spell_curse_toll.gd` - Toll curse
- `spell_curse_battle.gd` - Battle restriction curse
- `spell_world_curse.gd` - World curse

### Land/Creature
- `spell_land_new.gd` - Land manipulation
- `spell_creature_place.gd` - Creature placement
- `spell_creature_move.gd` - Creature move
- `spell_creature_swap.gd` - Creature swap
- `spell_creature_return.gd` - Creature return
- `spell_transform.gd` - Transform

### Player
- `spell_player_move.gd` - Player move
- `spell_movement.gd` - Movement control
- `spell_borrow.gd` - Borrow

### Utilities
- `spell_protection.gd` - Protection
- `spell_restriction.gd` - Restriction
- `spell_purify.gd` - Purify
- `spell_hp_immune.gd` - HP change immunity
- `spell_cost_modifier.gd` - Cost modifier
- `spell_synthesis.gd` - Spell synthesis
- `spell_mystic_arts.gd` - Arcana Arts
- `card_selection_handler.gd` - Card selection handling

---

## `/tiles/` (16 files)
- `base_tiles.gd` - Base class (creature_data property)
- `special_base_tile.gd` - Special tile base
- `fire_tile.gd`, `water_tile.gd`, `earth_tile.gd`, `wind_tile.gd`, `neutral_tile.gd`
- `checkpoint_tile.gd`, `warp_tile.gd` / `warp_stop_tile.gd`, `branch_tile.gd`
- `magic_tile.gd`, `magic_stone_tile.gd` / `magic_stone_system.gd`
- `card_buy_tile.gd`, `card_give_tile.gd`

---

## `/ui_components/` (33 files)

### Core
- `player_info_panel.gd`, `player_status_dialog.gd`, `hand_display.gd`
- `card_selection_ui.gd`, `phase_display.gd`

### Navigation & Global
- `global_action_buttons.gd` - Global buttons (▲▼✓× + special)
- `global_comment_ui.gd`, `game_menu.gd` / `game_menu_button.gd`, `surrender_dialog.gd`

### Land/Tile
- `dominio_order_ui.gd`, `level_up_ui.gd`, `base_tile_ui.gd`
- `magic_tile_ui.gd`, `magic_stone_ui.gd`, `card_buy_ui.gd`, `card_give_ui.gd`
- `action_menu_ui.gd`

### Spell
- `spell_phase_ui_manager.gd`, `spell_and_mystic_ui.gd`
- `spell_info_panel_ui.gd`, `spell_cast_notification_ui.gd`

### Info Panels
- `creature_info_panel_ui.gd`, `item_info_panel_ui.gd`
- `special_tile_info_dialog.gd`, `map_preview_dialog.gd`

### Target
- `tap_target_manager.gd`, `annotation_overlay.gd`

### Utilities
- `card_ui_helper.gd`, `debug_panel.gd`, `battle_log_ui.gd`

---

## `/battle_screen/` (8 files)
- `battle_screen_manager.gd`, `battle_screen.gd`, `battle_creature_display.gd`
- `hp_ap_bar.gd`, `damage_popup.gd`, `skill_label.gd`
- `skill_display_config.gd`, `transition_layer.gd`

---

## `/tutorial/` (4 files)
- `tutorial_manager.gd`, `tutorial_popup.gd`, `tutorial_overlay.gd`, `explanation_mode.gd`

## `/quest/` (5 files)
- `quest_game.gd`, `quest_select.gd`, `book_select.gd`, `world_stage_select.gd`, `stage_loader.gd`

## `/game_result/` (3 files)
- `result_screen.gd`, `reward_calculator.gd`, `rank_calculator.gd`

## `/save_data/` (1 file)
- `stage_record_manager.gd`

## `/utils/` (1 file)
- `summon_condition_checker.gd`

## `/helpers/` (2 files)
- `card_sacrifice_helper.gd`, `item_use_restriction.gd`
