# Scripts Directory Structure

## Main System Files (root level)
- `game_constants.gd` - 全ゲーム定数
- `game_flow_manager.gd` - ゲームフロー管理
- `player_system.gd` - プレイヤー管理
- `card_system.gd` - カードシステム
- `battle_system.gd` - バトルシステム
- `skill_system.gd` - スキルシステム
- `ui_manager.gd` - UI管理
- `board_system_3d.gd` - ボード3D管理
- `tile_data_manager.gd` - タイル情報・通行料計算
- `tile_action_processor.gd` - タイルアクション処理
- `effect_manager.gd` - エフェクト管理
- `creature_manager.gd` - クリーチャー管理
- `card_loader.gd` - カード読み込み

## Subdirectories
- `/battle/` - バトル関連
  - battle_participant.gd
  - battle_preparation.gd
  - battle_execution.gd
  - `/skills/` - 16個のスキル実装

- `/spells/` - スペル関連
  - spell_draw.gd
  - spell_magic.gd
  - spell_land_new.gd
  - spell_curse.gd
  - spell_dice.gd
  - spell_curse_stat.gd

- `/tiles/` - タイル関連
  - base_tiles.gd
  - fire_tile.gd, water_tile.gd, wind_tile.gd, earth_tile.gd
  - checkpoint_tile.gd, warp_tile.gd

- `/game_flow/` - ゲームフロー管理
  - land_command_handler.gd
  - land_action_helper.gd
  - spell_phase_handler.gd
  - movement_helper.gd

- `/ui_components/` - UI部品
  - player_info_panel.gd
  - hand_display.gd
  - card_selection_ui.gd

## Key Implementation Points
- 通行料計算: tile_data_manager.gd
- レベルアップコスト: game_constants.gd の LEVEL_VALUES
- 勝利条件・総魔力: player_system.gd
- スペル実装: /spells/ 配下
