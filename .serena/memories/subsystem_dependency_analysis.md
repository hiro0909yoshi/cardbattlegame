# メインシステム以外（兄弟システム）の依存状況

## 相互参照の状況

### player_system
- 参照先：board_system_ref, magic_stone_system_ref
- チェーンアクセス：**2箇所**
  - `board_system_ref.tile_data_manager.calculate_land_value()`
  - 他システムへの参照は最小限（健全）

### card_system
- 参照先：なし（独立している）
- チェーンアクセス：**0**
- **最も健全なシステム** ✅

### battle_system
- 参照先：board_system_ref, card_system_ref, player_system_ref, game_flow_manager_ref
- チェーンアクセス：**12箇所**
  - `game_flow_manager_ref.spell_container.spell_draw` (4箇所)
  - `game_flow_manager_ref.spell_container.spell_magic` (4箇所)
  - `game_flow_manager_ref.spell_container.spell_world_curse` (1箇所)
  - `game_flow_manager_ref.ui_manager.show_comment_and_wait()` (1箇所)
  - `game_flow_manager_ref.ui_manager.global_comment_ui` (1箇所)
  - `board_system_ref.tile_nodes` (複数)
- **要改善** ⚠️

### special_tile_system
- 参照先：board_system, player_system, game_flow_manager等
- チェーンアクセス：**4箇所**
  - `board_system.tile_action_processor.reset_action_processing()`
  - `board_system.tile_action_processor.process_tile_landing()`
  - `board_system.tile_nodes.has()`
  - `player_system.players.size()`
- **軽微だが改善可能** 🟡

### lap_system
- 参照先：board_system_3d, game_flow_manager等
- チェーンアクセス：**2箇所**
  - `board_system_3d.tile_nodes.keys()`
  - `tile.checkpoint_passed.is_connected()`
  - `tile.creature_data.is_empty()`
- **軽微** 🟢

## 問題パターン

1. **game_flow_manager経由のチェーン**
   - battle_system が spell_container, ui_manager にアクセス
   - 本来なら battle_system は spell_container を直接知るべきではない

2. **board_system.tile_action_processor への直接参照**
   - special_tile_system が直接アクセス
   - ファサード化して隠蔽すべき

3. **相互参照の複雑さ**
   - battle_system → game_flow_manager → spell_container
   - 誰が何に依存するか不明確

## 改善優先度

1. **battle_system の spell 参照を整理** ⚠️
   - setup時に spell_draw, spell_magic, spell_world_curse を直接参照
   - spell_container 経由ではなく setter 経由に変更

2. **special_tile_system の tile_action_processor チェーン**
   - `board_system.process_tile_action()` みたいなファサード化

3. **board_system.tile_nodes への直接アクセス**
   - 多くのシステムが直接参照
   - `get_tile(index)` メソッド化

## 健全度ランキング

✅ card_system（チェーン0）
✅ player_system（チェーン2）
🟢 lap_system（チェーン2）
🟡 special_tile_system（チェーン4）
🔴 battle_system（チェーン12）
