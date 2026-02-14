# シグナルカタログ

**目的**: プロジェクト内のシグナル定義と接続パターンの一覧

**最終更新**: 2026-02-13

**総シグナル数**: 192

---

## 1. コアシステム

### GameFlowManager
ファイル: `scripts/game_flow_manager.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `phase_changed` | `new_phase: int` | ゲームフェーズ変更通知 |
| `turn_started` | `player_id: int` | ターン開始通知 |
| `turn_ended` | `player_id: int` | ターン終了通知 |
| `dice_rolled` | `value: int` | ダイス結果通知（旧版互換） |
| `lap_completed` | `player_id: int` | 周回完了通知 |

### BoardSystem3D
ファイル: `scripts/board_system_3d.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `tile_action_completed` | なし | タイルアクション完了（ターン終了トリガー） |
| `terrain_changed` | `tile_index: int, old_element: String, new_element: String` | 地形変更通知 |
| `level_up_completed` | `tile_index: int, new_level: int` | レベルアップ完了 |
| `movement_completed` | `player_id: int, final_tile: int` | 移動完了通知 |
| `invasion_completed` | `success: bool, tile_index: int` | 侵略完了通知（Phase 2 リレーチェーン） |

### BattleSystem
ファイル: `scripts/battle_system.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `invasion_completed` | `success: bool, tile_index: int` | 侵略完了通知 |

### UIManager
ファイル: `scripts/ui_manager.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `pass_button_pressed` | なし | パスボタン押下 |
| `card_selected` | `card_index: int` | カード選択通知 |
| `level_up_selected` | `target_level: int, cost: int` | レベルアップ選択 |
| `dominio_order_button_pressed` | なし | ドミニオコマンドボタン押下 |

### PlayerSystem
ファイル: `scripts/player_system.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `dice_rolled` | `value: int` | ダイス結果通知 |
| `dice_rolled_double` | `value1: int, value2: int, total: int` | 2ダイス結果通知 |
| `magic_changed` | `player_id: int, new_value: int` | 魔力変更通知 |
| `player_won` | `player_id: int` | 勝利判定通知 |

### CardSystem
ファイル: `scripts/card_system.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `card_drawn` | `card_data: Dictionary` | カードドロー通知 |
| `card_used` | `card_data: Dictionary` | カード使用通知 |
| `hand_updated` | なし | 手札更新通知 |

### PlayerBuffSystem
ファイル: `scripts/player_buff_system.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `buff_applied` | `target: String, buff_type: String, value: int` | バフ適用通知 |
| `debuff_applied` | `target: String, debuff_type: String, value: int` | デバフ適用通知 |

---

## 2. ゲームフローサブシステム

### SpellPhaseHandler
ファイル: `scripts/game_flow/spell_phase_handler.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `spell_phase_started` | なし | スペルフェーズ開始 |
| `spell_phase_completed` | なし | スペルフェーズ完了 |
| `spell_passed` | なし | スペルパス |
| `spell_used` | `spell_card: Dictionary` | スペル使用 |
| `target_selection_required` | `spell_card: Dictionary, target_type: String` | ターゲット選択要求 |
| `target_confirmed` | `target_data: Dictionary` | ターゲット確定 |
| `external_spell_finished` | なし | 外部スペル完了 |

### ItemPhaseHandler
ファイル: `scripts/game_flow/item_phase_handler.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `item_phase_started` | なし | アイテムフェーズ開始 |
| `item_phase_completed` | なし | アイテムフェーズ完了 |
| `item_passed` | なし | アイテムパス |
| `item_used` | `item_card: Dictionary` | アイテム使用 |
| `creature_merged` | `merged_data: Dictionary` | クリーチャー合成 |

### DominioCommandHandler
ファイル: `scripts/game_flow/dominio_command_handler.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `dominio_command_opened` | なし | ドミニオコマンド開始 |
| `dominio_command_closed` | なし | ドミニオコマンド終了 |
| `land_selected` | `tile_index: int` | 土地選択 |
| `action_selected` | `action_type: String` | アクション選択 |

### LapSystem
ファイル: `scripts/game_flow/lap_system.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `lap_completed` | `player_id: int` | 周回完了 |
| `checkpoint_signal_obtained` | `player_id: int, checkpoint_type: String` | チェックポイント通過 |
| `checkpoint_processing_completed` | なし | チェックポイント処理完了 |

### BankruptcyHandler
ファイル: `scripts/game_flow/bankruptcy_handler.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `bankruptcy_completed` | `player_id: int, was_reset: bool` | 破産処理完了 |
| `land_sold` | `player_id: int, tile_index: int, value: int` | 土地売却 |

### TargetSelectionHelper
ファイル: `scripts/game_flow/target_selection_helper.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `tile_selection_completed` | `tile_index: int` | タイル選択完了 |
| `tile_selection_changed` | `tile_index: int` | タイル選択変更 |

### TileActionProcessor
ファイル: `scripts/tile_action_processor.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `action_completed` | なし | アクション完了 |
| `invasion_completed` | `success: bool, tile_index: int` | 侵略完了（Phase 2: BoardSystem3Dへリレー） |

---

## 3. 移動システム

### MovementController3D
ファイル: `scripts/movement_controller.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `movement_started` | `player_id: int` | 移動開始 |
| `movement_step_completed` | `player_id: int, tile_index: int` | 1歩移動完了 |
| `movement_completed` | `player_id: int, final_tile: int` | 移動完了 |
| `warp_executed` | `player_id: int, from_tile: int, to_tile: int` | ワープ実行 |
| `start_passed` | `player_id: int` | スタート通過 |

### MovementDirectionSelector
ファイル: `scripts/movement_direction_selector.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `direction_selected` | `direction: int` | 方向選択完了 |

### MovementBranchSelector
ファイル: `scripts/movement_branch_selector.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `branch_selected` | `tile_index: int` | 分岐選択完了 |

---

## 4. バトルスクリーン

### BattleScreen
ファイル: `scripts/battle_screen/battle_screen.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `battle_intro_completed` | なし | イントロ完了 |
| `phase_completed` | `phase_name: String` | フェーズ完了 |
| `battle_ended` | `result: int` | バトル終了 |
| `click_received` | なし | クリック受信 |

### BattleScreenManager
ファイル: `scripts/battle_screen/battle_screen_manager.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `intro_completed` | なし | イントロ完了 |
| `skill_animation_completed` | なし | スキルアニメ完了 |
| `attack_animation_completed` | なし | 攻撃アニメ完了 |
| `battle_screen_opened` | なし | バトル画面開始 |
| `battle_screen_closed` | なし | バトル画面終了 |

### BattleCreatureDisplay
ファイル: `scripts/battle_screen/battle_creature_display.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `attack_animation_completed` | なし | 攻撃アニメ完了 |
| `damage_animation_completed` | なし | ダメージアニメ完了 |

### TransitionLayer
ファイル: `scripts/battle_screen/transition_layer.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `fade_out_completed` | なし | フェードアウト完了 |
| `fade_in_completed` | なし | フェードイン完了 |

---

## 5. UIコンポーネント（主要）

### CardSelectionUI
ファイル: `scripts/ui_components/card_selection_ui.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `card_selected` | `card_index: int` | カード選択 |
| `selection_cancelled` | なし | 選択キャンセル |
| `card_info_shown` | `card_index: int` | カード情報表示 |

### GlobalCommentUI
ファイル: `scripts/ui_components/global_comment_ui.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `click_confirmed` | なし | クリック確認 |
| `choice_made` | `result: bool` | Yes/No選択結果 |

### HandDisplay
ファイル: `scripts/ui_components/hand_display.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `card_drawn` | `card_data: Dictionary` | カードドロー |
| `card_used` | `card_data: Dictionary` | カード使用 |
| `hand_updated` | なし | 手札更新 |

### LevelUpUI
ファイル: `scripts/ui_components/level_up_ui.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `level_selected` | `target_level: int, cost: int` | レベル選択 |
| `selection_cancelled` | なし | 選択キャンセル |

### CreatureInfoPanelUI / ItemInfoPanelUI / SpellInfoPanelUI
共通シグナル:

| シグナル | 引数 | 用途 |
|---------|------|------|
| `selection_confirmed` | `card_data: Dictionary` | 選択確定 |
| `selection_cancelled` | なし | 選択キャンセル |
| `panel_closed` | なし | パネル閉じ |

### PlayerInfoPanel
ファイル: `scripts/ui_components/player_info_panel.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `player_panel_clicked` | `player_id: int` | プレイヤーパネルクリック |

### TapTargetManager
ファイル: `scripts/ui_components/tap_target_manager.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `target_selected` | `tile_index: int, creature_data: Dictionary` | ターゲット選択 |
| `selection_cancelled` | なし | 選択キャンセル |

---

## 6. タイルシステム

### BaseTile
ファイル: `scripts/tiles/base_tiles.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `player_landed` | `player_body` | プレイヤー着地 |
| `player_passed` | `player_body` | プレイヤー通過 |

### CheckpointTile
ファイル: `scripts/tiles/checkpoint_tile.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `checkpoint_passed` | `player_id: int, checkpoint_type: String` | チェックポイント通過 |

### BranchTile
ファイル: `scripts/tiles/branch_tile.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `direction_change_selected` | `change: bool` | 方向変更選択 |

---

## 7. カメラ・入力

### CameraController
ファイル: `scripts/camera_controller.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `tile_tapped` | `tile_index: int, tile_data: Dictionary` | タイルタップ |
| `creature_tapped` | `tile_index: int, creature_data: Dictionary` | クリーチャータップ |
| `empty_tapped` | なし | 空タップ |

---

## 8. CPU AI

### CPUAIHandler
ファイル: `scripts/cpu_ai/cpu_ai_handler.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `summon_decided` | `card_index: int` | 召喚決定 |
| `battle_decided` | `creature_index: int, item_index: int` | バトル決定 |
| `level_up_decided` | `do_upgrade: bool` | レベルアップ決定 |
| `territory_command_decided` | `command: Dictionary` | 領地コマンド決定 |

### CPUTurnProcessor
ファイル: `scripts/cpu_ai/cpu_turn_processor.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `cpu_action_completed` | なし | CPUアクション完了 |
| `cpu_spell_completed` | `used_spell: bool` | CPUスペル完了 |

---

## 9. スペルシステム

### SpellMysticArts
ファイル: `scripts/spells/spell_mystic_arts.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `mystic_phase_completed` | なし | 秘術フェーズ完了 |
| `mystic_art_used` | なし | 秘術使用 |
| `target_selection_requested` | `targets: Array` | ターゲット選択要求 |
| `ui_message_requested` | `message: String` | UIメッセージ要求 |

### SpellCreatureMove
ファイル: `scripts/spells/spell_creature_move.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `spell_move_battle_completed` | なし | 移動スペルバトル完了 |

---

## 10. その他

### SpecialTileSystem
ファイル: `scripts/special_tile_system.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `special_tile_activated` | `tile_type: String, player_id: int, tile_index: int` | 特殊タイル発動 |
| `checkpoint_passed` | `player_id: int, bonus: int` | チェックポイント通過 |
| `special_action_completed` | なし | 特殊アクション完了 |

### NetworkManager
ファイル: `scripts/network/network_manager.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `connected` | なし | 接続完了 |
| `disconnected` | なし | 切断 |
| `connection_failed` | なし | 接続失敗 |
| `peer_connected` | `peer_id: int` | ピア接続 |
| `peer_disconnected` | `peer_id: int` | ピア切断 |
| `game_action_received` | `action: Dictionary` | アクション受信 |

### TutorialManager
ファイル: `scripts/tutorial/tutorial_manager.gd`

| シグナル | 引数 | 用途 |
|---------|------|------|
| `tutorial_started` | なし | チュートリアル開始 |
| `tutorial_ended` | なし | チュートリアル終了 |
| `step_changed` | `step_id: int` | ステップ変更 |

---

## 重要なシグナル経路

### ターン進行フロー
```
GameFlowManager.turn_started(player_id)
    ↓
SpellPhaseHandler.spell_phase_started
    ↓
SpellPhaseHandler.spell_phase_completed
    ↓
(ダイスロール・移動)
    ↓
MovementController.movement_completed(player_id, final_tile)
    ↓
BoardSystem3D.movement_completed(player_id, final_tile)
    ↓
(タイルアクション)
    ↓
TileActionProcessor.action_completed
    ↓
BoardSystem3D.tile_action_completed
    ↓
GameFlowManager.turn_ended(player_id)
```

### バトルフロー（Phase 2: invasion_completed relay chain）
```
(侵略開始)
    ↓
BattleScreenManager.battle_screen_opened
    ↓
BattleScreenManager.intro_completed
    ↓
BattleScreenManager.skill_animation_completed
    ↓
BattleScreenManager.attack_animation_completed
    ↓
BattleScreen.battle_ended(result)
    ↓
BattleScreenManager.battle_screen_closed
    ↓
BattleSystem.invasion_completed(success, tile_index)
    ↓
TileBattleExecutor._on_battle_completed(success, tile_index)
    ↓
TileBattleExecutor.invasion_completed.emit(success, tile_index)
    ↓
TileActionProcessor._on_invasion_completed(success, tile_index)
    ↓
TileActionProcessor.invasion_completed.emit(success, tile_index)  [Phase 2]
    ↓
BoardSystem3D._on_invasion_completed(success, tile_index)  [Phase 2]
    ↓
BoardSystem3D.invasion_completed.emit(success, tile_index)  [Phase 2]
    ↓
GameFlowManager._on_invasion_completed_from_board(success, tile_index)  [Phase 2]
    ├→ DominioCommandHandler._on_invasion_completed(success, tile_index)
    └→ CPUTurnProcessor._on_invasion_completed(success, tile_index)
```

**Phase 2 改善点**:
- 横断的シグナル接続を解消（BattleSystem → Handler 直接接続を廃止）
- 子→親方向のリレーチェーンに統一
- デバッグ容易性の向上（各段階でログ出力）

### スペルフロー
```
SpellPhaseHandler.spell_phase_started
    ↓
(スペル選択)
    ↓
SpellPhaseHandler.target_selection_required(spell_card, target_type)
    ↓
TargetSelectionHelper.tile_selection_completed(tile_index)
    ↓
SpellPhaseHandler.target_confirmed(target_data)
    ↓
SpellPhaseHandler.spell_used(spell_card)
    ↓
SpellPhaseHandler.spell_phase_completed
```

---

## 更新ルール

- 新しいシグナルを追加したら、このカタログも更新する
- シグナル接続パターンが変更されたら「重要なシグナル経路」も更新
- 3箇所以上で接続されるシグナルは経路図に追加を検討
