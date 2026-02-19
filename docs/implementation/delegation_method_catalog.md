# 委譲メソッドカタログ

**目的**: チェーンアクセス禁止ルール（規約9）を守るための参照ガイド

**最終更新**: 2026-02-19 (Phase 10-B card.gd Signal駆動化、Phase 8 UIサービス分割反映)

---

## ui_manager 経由でアクセス

### phase_display 委譲
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `set_phase_text(text)` | phase_display.phase_label | フェーズテキスト設定 |
| `get_phase_text()` | phase_display.phase_label | フェーズテキスト取得 |
| `show_toast(msg, duration)` | phase_display | トースト通知表示 |
| `show_action_prompt(msg)` | phase_display | アクション指示表示 |
| `hide_action_prompt()` | phase_display | アクション指示非表示 |
| `show_big_dice_result(value, duration)` | phase_display | ダイス結果大表示 |
| `show_dice_result_double(dice1, dice2, total)` | phase_display | 2ダイス結果表示 |
| `show_dice_result_triple(dice1, dice2, dice3, total)` | phase_display | 3ダイス結果表示 |
| `show_dice_result_range(curse_name, value)` | phase_display | ダイス範囲結果表示 |

### player_info_panel 委譲
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `set_current_turn(player_id)` | player_info_panel | 現在ターンプレイヤー設定 |
| `get_player_ranking(player_id)` | player_info_panel | プレイヤー順位取得 |

### global_comment_ui 委譲
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `show_comment_and_wait(msg, pid, force)` | global_comment_ui | クリック待ちコメント |
| `show_choice_and_wait(msg, pid, yes, no)` | global_comment_ui | Yes/No選択 |
| `show_comment_message(msg)` | global_comment_ui | メッセージ表示 |
| `hide_comment_message()` | global_comment_ui | メッセージ非表示 |

### hand_display 委譲
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `update_hand_display(player_id)` | hand_display | 手札表示更新 |

### info_panel 統合メソッド
| メソッド | 用途 |
|---------|------|
| `hide_all_info_panels(clear_buttons)` | 全パネル一括非表示 |
| `is_any_info_panel_visible()` | いずれかが表示中か |
| `show_card_info(card_data, tile_index, setup_buttons)` | 種別自動判定で閲覧表示 |
| `show_card_selection(card_data, hand_index, ...)` | 種別自動判定で選択表示 |

### ナビゲーション
| メソッド | 用途 |
|---------|------|
| `enable_navigation(confirm, back, up, down)` | グローバルボタン設定 |
| `disable_navigation()` | グローバルボタン無効化 |
| `clear_back_action()` | 戻るボタンクリア |

### UIサービス参照（Phase 8-F 追加）

UIManager は5つのサービスを公開プロパティとして提供:

| プロパティ | 型 | 用途 |
|-----------|------|------|
| `message_service` | MessageService | トースト・コメント・フェーズ表示 |
| `navigation_service` | NavigationService | グローバルボタン制御・状態保存復元 |
| `card_selection_service` | CardSelectionService | カード選択UI・フィルター・手札表示 |
| `info_panel_service` | InfoPanelService | クリーチャー/スペル/アイテム情報パネル |
| `player_info_service` | PlayerInfoService | プレイヤー情報パネル更新（Phase 10-A） |

---

## board_system_3d 経由でアクセス

### カメラ制御（camera_controller 委譲）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `enable_manual_camera()` | camera_controller | 手動カメラモード |
| `enable_follow_camera()` | camera_controller | 追従カメラモード |
| `set_camera_player(player_id)` | camera_controller | カメラ対象設定 |
| `return_camera_to_player()` | camera_controller | プレイヤーにカメラ戻す |
| `focus_camera_on_player_pos(player_id)` | camera_controller | プレイヤー位置にフォーカス |
| `focus_camera_slow(target_pos)` | camera_controller | スローフォーカス |
| `focus_camera_on_tile_slow(tile_index)` | camera_controller | タイルにスローフォーカス |
| `is_direction_camera_active()` | camera_controller | 方向カメラ有効か |
| `cancel_direction_tween()` | camera_controller | 方向Tweenキャンセル |

### 移動制御（movement_controller 委譲）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `get_player_tile(player_id)` | movement_controller | プレイヤー位置取得 |
| `set_player_tile(player_id, tile_index)` | movement_controller | プレイヤー位置設定 |
| `place_player_at_tile(player_id, tile_index)` | movement_controller | プレイヤー配置 |
| `clear_all_down_states_for_player(player_id)` | movement_controller | ダウン状態全解除 |
| `clear_down_state_for_player(player_id)` | movement_controller | ダウン状態解除 |
| `set_down_state_for_tile(tile_index, state)` | movement_controller | ダウン状態設定 |
| `execute_warp(player_id, dest_tile)` | movement_controller | ワープ実行 |
| `heal_all_creatures_for_player(player_id)` | movement_controller | 全クリーチャー回復 |
| `is_movement_selection_active()` | movement_controller | 移動選択中か |
| `restore_movement_selector_navigation()` | movement_controller | 移動選択ナビ復元 |
| `swap_came_from_for_reverse()` | movement_controller | 逆走用came_from交換 |
| `on_movement_reverse_curse_removed()` | movement_controller | 逆走呪い解除時 |

### タイル表示（tile_info_display 委譲）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `switch_tile_display_mode()` | tile_info_display | 表示モード切替 |
| `get_tile_display_mode_name()` | tile_info_display | 表示モード名取得 |
| `update_tile_display()` | tile_info_display | タイル表示更新 |
| `get_tile_label(tile_index)` | tile_info_display | タイルラベル取得 |

### タイルデータ（tile_data_manager 委譲）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `set_tile_level(tile_index, level)` | tile_data_manager | レベル設定 |
| `calculate_level_up_cost(current, target)` | tile_data_manager | レベルアップコスト計算 |
| `calculate_toll_with_curse(tile_index)` | tile_data_manager | 呪い込み通行料計算 |

### 特殊タイル（special_tile_system 委譲）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `get_warp_pairs()` | special_tile_system | ワープペア一覧 |
| `get_warp_pair(tile_index)` | special_tile_system | ワープペア取得 |

### バトル（battle_system 委譲）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `get_battle_screen_manager()` | battle_system | バトル画面マネージャ取得 |

### アクション処理（tile_action_processor 委譲）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `begin_action_processing()` | tile_action_processor | アクション処理開始 |
| `reset_action_processing()` | tile_action_processor | アクション処理リセット |
| `complete_action()` | tile_action_processor | アクション完了 |
| `execute_swap_action(tile, card_idx, old_creature)` | tile_action_processor | 交換実行 |

### 参照取得・設定（initialize時のみ使用）
| メソッド | 用途 |
|---------|------|
| `get_camera_controller_ref()` | カメラコントローラ参照取得 |
| `get_movement_controller_ref()` | 移動コントローラ参照取得 |
| `set_camera_controller_ref(ref)` | カメラコントローラ参照設定 |
| `set_movement_controller_gfm(gfm)` | 移動コントローラにGFM設定 |
| `set_movement_controller_services(msg_svc, nav_svc)` | 移動コントローラにサービス注入（Phase 8-K） |
| `set_spell_player_move(spm)` | スペル移動参照設定 |
| `set_spell_land(system)` | spell_land直接参照設定 |
| `set_cpu_movement_evaluator(eval)` | CPU移動評価設定 |
| `get_cpu_movement_evaluator()` | CPU移動評価取得 |
| `get_spell_movement()` | スペル移動取得 |

---

## UIサービス委譲メソッド（Phase 8-F〜10-A 追加）

### MessageService
ファイル: `scripts/ui_services/message_service.gd`

| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `show_toast(message, duration)` | phase_display | トースト表示 |
| `show_action_prompt(message, position)` | phase_display | アクション指示表示 |
| `hide_action_prompt()` | phase_display | アクション指示非表示 |
| `set_phase_text(text)` | phase_display | フェーズテキスト設定 |
| `show_comment_and_wait(message, pid, force)` | global_comment_ui | クリック待ちコメント |
| `show_choice_and_wait(message, pid, yes, no)` | global_comment_ui | Yes/No選択 |
| `show_big_dice_result(value, duration)` | phase_display | ダイス結果大表示 |

### NavigationService
ファイル: `scripts/ui_services/navigation_service.gd`

| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `enable_navigation(confirm, back, up, down)` | global_action_buttons | ナビゲーション有効化 |
| `disable_navigation()` | global_action_buttons | ナビゲーション無効化 |
| `save_navigation_state()` | 内部状態保存 | ボタン状態保存 |
| `restore_navigation_state()` | global_action_buttons | ボタン状態復元 |
| `register_confirm_action(callback, text)` | global_action_buttons | 決定ボタン登録 |
| `register_back_action(callback, text)` | global_action_buttons | 戻るボタン登録 |
| `clear_back_action()` | global_action_buttons | 戻るボタンクリア |
| `set_special_button(text, callback)` | global_action_buttons | 特殊ボタン設定 |
| `clear_special_button()` | global_action_buttons | 特殊ボタンクリア |

### CardSelectionService
ファイル: `scripts/ui_services/card_selection_service.gd`

| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `show_card_selection_ui(player)` | card_selection_ui | カード選択UI表示 |
| `show_card_selection_ui_mode(player, mode)` | card_selection_ui | モード指定カード選択UI表示 |
| `hide_card_selection_ui()` | card_selection_ui | カード選択UI非表示 |
| `set_card_selection_filter(filter)` | 内部プロパティ | フィルター設定 |
| `clear_card_selection_filter()` | 内部プロパティ | フィルタークリア |
| `update_hand_display(player_id)` | hand_display | 手札表示更新 |
| `initialize_hand_container(container)` | hand_display | 手札コンテナ初期化 |
| `connect_card_system_signals()` | card_system | カードシステムSignal接続 |

### InfoPanelService
ファイル: `scripts/ui_services/info_panel_service.gd`

| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `show_card_info_only(card_data, tile_index)` | 各パネル | 閲覧モードカード情報表示 |
| `show_card_selection(card_data, hand_index, ...)` | 各パネル | 選択モードカード情報表示 |
| `hide_all_info_panels(clear_buttons)` | 各パネル | 全パネル非表示 |
| `is_any_info_panel_visible()` | 各パネル | パネル表示状態確認 |
| `update_display(creature_data)` | creature_panel | クリーチャー表示更新 |

### PlayerInfoService
ファイル: `scripts/ui_services/player_info_service.gd`

| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `update_panels()` | player_info_panel | プレイヤー情報パネル全更新（Phase 10-A） |

---

## 直接参照パターン（GFM経由廃止）

スペルシステムなど、GameFlowManager経由でアクセスしていた参照を各クラスに直接注入するパターン。

### SpellEffectExecutor
```gdscript
# setterメソッド
func set_spell_systems(systems: Dictionary) -> void

# 直接参照（10システム）
var spell_magic, spell_dice, spell_curse_stat, spell_curse
var spell_curse_toll, spell_cost_modifier, spell_draw
var spell_land, spell_player_move, spell_world_curse
```

### BoardSystem3D
```gdscript
# setterメソッド
func set_spell_land(system) -> void

# 直接参照
var spell_land  # 土地操作スペル
```

---

## 直接アクセスが許容されるもの

### 公開プロパティ（読み取り専用）
| プロパティ | 所属 | 備考 |
|-----------|------|------|
| `tile_nodes` | board_system_3d | 200箇所+で使用、構造変更なし |
| `camera` | board_system_3d | カメラ直接参照 |
| `current_player_index` | board_system_3d | 現在プレイヤー |

### 内部分割ヘルパー間
MovementController内部のヘルパー（warp_handler, special_handler等）からの`controller.*`参照は許容。

---

## 直接参照パターン（GFM経由を廃止）

チェーンアクセス解消のため、GameFlowManager経由ではなく各クラスに直接参照を注入する。

### GameSystemManager 委譲メソッド
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `set_stage_data(stage_data)` | game_flow_manager → quest_game | ステージデータ設定 |
| `set_result_screen(result_screen)` | game_flow_manager → quest_game | リザルト画面設定 |
| `apply_map_settings_to_lap_system(map_data)` | game_flow_manager.lap_system | マップ周回設定適用 |

### BoardSystem3D 委譲メソッド（新規）
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `set_movement_controller_game_3d_ref(game_3d_ref)` | movement_controller | game_3d参照注入 |
| `set_movement_controller_card_selection_ui(ui)` | movement_controller | CardSelectionUI参照注入 |
| `set_movement_controller_ui_manager(ui_manager)` | movement_controller | UIManager参照注入 |
| `toggle_all_branch_tiles(enabled)` | tile_data_manager | 分岐タイル切替 |

### battle_status_overlay 直接参照
| 設定先クラス | セッターメソッド | 注入元 |
|-------------|-----------------|--------|
| TileBattleExecutor | `set_battle_status_overlay(overlay)` | game_system_manager |
| DominioCommandHandler | `set_battle_status_overlay(overlay)` | game_system_manager |
| CPUTurnProcessor | `set_battle_status_overlay(overlay)` | game_system_manager |
| SpellPhaseHandler | `set_battle_status_overlay(overlay)` | game_system_manager |
| SpellCreatureMove | `set_battle_status_overlay(overlay)` | spell_phase_handler |

### lap_system 直接参照
| 設定先クラス | セッターメソッド | 注入元 |
|-------------|-----------------|--------|
| SpellPlayerMove | setup時に自動設定 | game_flow_manager |
| BattleSpecialEffects | `set_lap_system(system)` | battle_system |
| SkillLegacy | 関数パラメータで渡す | BattleSpecialEffects |
| TutorialManager | initialize_with_systems時に設定 | game_flow_manager |
| BattleSystem | setup_systems時に自動設定 | game_flow_manager |
| SpellMagic | setup時に自動設定 | game_flow_manager |
| PlayerStatusDialog | initialize時に自動設定 | game_flow_manager |
| SkillStatModifiers | 関数パラメータで渡す | BattleSkillProcessor |
| BattleSkillProcessor | setup_systems時に自動設定 | game_flow_manager |
| DebugPanel | initialize時に自動設定 | game_flow_manager |

### game_system_manager 委譲メソッド
| メソッド | 委譲先 | 用途 |
|---------|--------|------|
| `apply_map_settings_to_lap_system(map_data)` | game_flow_manager.lap_system | マップ周回設定適用 |

### spell_cost_modifier 直接参照
| 設定先クラス | セッターメソッド | 注入元 |
|-------------|-----------------|--------|
| SpellPhaseHandler | `set_spell_systems_direct(cost_modifier, draw)` | game_system_manager |
| ItemPhaseHandler | `set_spell_cost_modifier(cost_modifier)` | game_system_manager |
| TileActionProcessor | `set_spell_systems_direct(cost_modifier, world_curse)` | board_system_3d |
| TileSummonExecutor | `set_spell_cost_modifier(cost_modifier)` | tile_action_processor |
| TileBattleExecutor | `set_spell_cost_modifier(cost_modifier)` | tile_action_processor |
| SpellCostModifier | `set_spell_world_curse(world_curse)` | game_system_manager |

### spell_phase_handler 直接参照
| 設定先クラス | プロパティ名 | 注入元 |
|-------------|-------------|--------|
| SpellCurse | `spell_phase_handler` | game_system_manager |
| CPUSpecialTileAI | `spell_phase_handler` | game_system_manager |

### player_system 直接参照
| 設定先クラス | 設定方法 | 注入元 |
|-------------|---------|--------|
| TutorialManager | initialize_with_systems時に設定 | game_flow_manager |
| ExplanationMode | setup時に設定 | board_system_3d.game_flow_manager |

### dominio_command_handler 直接参照
| 設定先クラス | 設定方法 | 注入元 |
|-------------|---------|--------|
| TutorialManager | initialize_with_systems時に設定 | game_flow_manager |

### board_system_3d 直接参照
| 設定先クラス | 設定方法 | 注入元 |
|-------------|---------|--------|
| ItemPhaseHandler | initialize時に設定 | game_flow_manager |

### target_selection_helper 直接参照
| 設定先クラス | 設定方法 | 注入元 |
|-------------|---------|--------|
| SpellPhaseHandler | initialize時に設定 | game_flow_manager |

### ui_manager 直接参照
| 設定先クラス | 設定方法 | 注入元 |
|-------------|---------|--------|
| SpellWorldCurse | setup時に設定 | game_flow_manager |

### spell_curse_stat 直接参照
| 設定先クラス | 設定方法 | 注入元 |
|-------------|---------|--------|
| SpellMysticArts | _init時に設定 | spell_phase_handler.game_flow_manager |

### game_3d_ref 直接参照（新規パターン）
| 設定先クラス | セッターメソッド | 注入元 | 用途 |
|-------------|-----------------|--------|------|
| MovementController | set_movement_controller_game_3d_ref | board_system_3d | UI表示制御 |
| TileActionProcessor | set_game_3d_ref | board_system_3d | アクション後の表示更新 |
| CPUTurnProcessor | set_game_3d_ref | game_system_manager | CPU処理制御 |
| LandSelectionHelper | set_game_3d_ref | game_system_manager | 土地選択UI制御 |

### card_selection_ui 直接参照（新規パターン）
| 設定先クラス | セッターメソッド | 注入元 | 用途 |
|-------------|-----------------|--------|------|
| MovementDestinationPredictor | set_card_selection_ui | board_system_3d | カード選択状態確認 |
| MovementController | set_movement_controller_card_selection_ui | board_system_3d | 移動選択制御 |

### 移動系 サービス直接注入（Phase 8-K）
| 設定先クラス | セッターメソッド | 注入元 | 参照先 |
|-------------|-----------------|--------|--------|
| MovementController | `set_services(msg_svc, nav_svc)` | board_system_3d | MessageService, NavigationService |
| MovementDirectionSelector | `set_services(msg_svc, nav_svc)` | movement_controller | MessageService, NavigationService |
| MovementBranchSelector | `set_services(msg_svc, nav_svc)` | movement_controller | MessageService, NavigationService |

### card.gd 直接参照（Phase 10-B、UIManager 依存排除）
| 設定先クラス | セッターメソッド | 注入元 | 参照先 |
|-------------|-----------------|--------|--------|
| card.gd | `set_references(css, csui, gfm)` | hand_display | CardSelectionService, CardSelectionUI, GameFlowManager |

### hand_display Callable コールバック（Phase 10-B）
| 設定先クラス | セッターメソッド | 注入元 | 用途 |
|-------------|-----------------|--------|------|
| hand_display | `set_card_callbacks(on_confirmed, on_info)` | UIManager | card.gd Signal → UIManager ハンドラー接続 |

### ui_manager 直接参照（新規拡張）
| 設定先クラス | セッターメソッド | 注入元 | 用途 |
|-------------|-----------------|--------|------|
| TileActionProcessor | set_ui_manager | board_system_3d | アクションUI |
| BattleSpecialEffects | set_ui_manager | battle_system | バトルUI更新 |
| CPUTurnProcessor | set_ui_manager | game_system_manager | ターンUI更新 |

### spell系 直接参照（新規パターン）
| 設定先クラス | セッターメソッド | 注入元 | 参照先 |
|-------------|-----------------|--------|------|
| SpellMysticArts | set_game_flow_manager_ref | spell_phase_handler | game_flow_manager |
| SpellCreatureMove | set_game_flow_manager_ref | spell_phase_handler | game_flow_manager |
| MovementBranchSelector | set_spell_systems | board_system_3d | game_flow_manager.spell系 |

### item_phase_handler / dominio_command_handler 直接参照（新規パターン）
| 設定先クラス | セッターメソッド | 注入元 | 用途 |
|-------------|-----------------|--------|------|
| CPUTurnProcessor | set_item_phase_handler | game_system_manager | アイテムフェーズ制御 |
| CPUTurnProcessor | set_dominio_command_handler | game_system_manager | ドミニオコマンド制御 |
| BattleSpecialEffects | set_handlers | battle_system | 戦闘後処理 |

### spell_phase_handler.spell_ui_manager 参照（統合済み）
| 設定先クラス | メソッド | 注入元 | 責務 |
|-------------|---------|--------|------|
| SpellPhaseHandler | `spell_ui_manager` | game_system_manager | UI統合制御 |

**統合参照**（3ファイル吸収済み — spell_navigation_controller, spell_ui_controller, spell_confirmation_handler は削除）:
```gdscript
# SpellUIManager の主要参照
var _spell_phase_handler  # SpellPhaseHandler
var _ui_manager           # UIManager
var _board_system         # BoardSystem3D
var _player_system        # PlayerSystem
var _game_3d_ref          # Game3D
var _card_system          # CardSystem
```

**主要メソッド**:
- setup(spell_phase_handler, ui_manager, board_system, player_system, game_3d_ref, card_system)
- initialize_spell_phase_ui() / initialize_spell_cast_notification_ui()
- show_spell_selection_ui(hand_data, magic_power)
- return_camera_to_player()
- show_spell_phase_buttons() / hide_spell_phase_buttons()
- restore_navigation() / restore_navigation_for_state()
- show_spell_cast_notification(caster_name, target_data, spell_or_mystic, is_mystic) — await
- connect_spell_flow_signals(spell_flow) / connect_mystic_arts_signals(mystic_arts_handler)

**使用例**:
```gdscript
# SpellPhaseHandler 内で
if spell_ui_manager:
	spell_ui_manager.show_spell_selection_ui(player_hand, magic_power)
```

### spell_phase_handler.cpu_spell_ai_container 参照 (Phase 5-2)
| 設定先クラス | メソッド | 注入元 | 責務 |
|-------------|---------|--------|------|
| SpellPhaseHandler | `cpu_spell_ai_container` | game_system_manager | CPU AI参照統合 |

**統合参照**:
```gdscript
# CPUSpellAIContainer が管理する参照
var cpu_spell_ai: CPUSpellAI
var cpu_mystic_arts_ai: CPUMysticArtsAI
var cpu_hand_utils: CPUHandUtils
var cpu_movement_evaluator: CPUMovementEvaluator
```

**メソッド一覧** (4):
- setup(spell_ai, mystic_arts_ai, hand_utils, movement_evaluator)
- is_valid()
- debug_print_status()

**使用例**:
```gdscript
# SpellPhaseHandler 内で
if spell_phase_handler.cpu_spell_ai_container and spell_phase_handler.cpu_spell_ai_container.is_valid():
	var decided_spell = spell_phase_handler.cpu_spell_ai_container.cpu_spell_ai.decide_spell(...)
```

---

## 使用例

```gdscript
# ❌ チェーンアクセス（禁止）
ui_manager.phase_display.show_toast("メッセージ")
board_system.tile_action_processor.complete_action()
game_flow_manager.battle_status_overlay.show_battle_status(...)

# ✅ 委譲メソッド経由（推奨）
ui_manager.show_toast("メッセージ")
board_system.complete_action()

# ✅ 直接参照経由（推奨）
battle_status_overlay.show_battle_status(...)  # 注入された参照を使用
```

---

## 更新ルール

- 新しい委譲メソッドを追加したら、このカタログも更新する
- 外部から3箇所以上呼ばれるメソッドは委譲メソッド化を検討

---

## オートロード（Autoload）パターン

### DebugSettings オートロード

**目的**: デバッグ設定のグローバル管理

**ファイル**: scripts/autoload/debug_settings.gd

**登録**: project.godot の [autoload] セクション
```ini
DebugSettings="*res://scripts/autoload/debug_settings.gd"
```

**提供するプロパティ**:
- manual_control_all: bool - 全プレイヤーを手動操作にするフラグ

**使用例**:
```gdscript
# どこからでもアクセス可能
if DebugSettings.manual_control_all:
	# 全プレイヤー手動操作モード
	pass

# 初期化時に設定
func _ready():
	DebugSettings.manual_control_all = true
```

**メリット**:
- グローバルアクセス可能（パラメータチェーン不要）
- シングルソースオブトゥルース
- 将来的な拡張が容易

**適用箇所**: 14ファイル（game_flow_manager, board_system_3d, tile_action_processor, discard_handler, game_3d, quest_game, game_system_manager, movement_controller, special_tile_system, tile_summon_executor, card_selection_ui, tile_battle_executor, item_phase_handler, spell_phase_handler）

---

## Phase 6-A: MysticArts 委譲メソッド削除 + デッドコード削除（2026-02-17）

### MysticArts 委譲メソッド削除（8個）

| メソッド | 削除理由 | 代替方法 |
|---------|--------|--------|
| `start_mystic_arts_phase()` | MysticArtsHandler が直接シグナル接続済み | `spell_phase_handler.mystic_arts_handler.start_mystic_arts_phase()` |
| `has_available_mystic_arts(player_id)` | MysticArtsHandler に統一 | `spell_phase_handler.mystic_arts_handler.has_available_mystic_arts(player_id)` |
| `has_spell_mystic_arts()` | 呼び出し箇所なし | `spell_phase_handler.mystic_arts_handler._has_spell_mystic_arts()` |
| `update_mystic_button_visibility()` | MysticArtsHandler に統一 | `spell_phase_handler.mystic_arts_handler.update_mystic_button_visibility()` |
| `_on_mystic_art_used()` | デッドコード（内部シグナルハンドラ） | - |
| `_on_mystic_phase_completed()` | デッドコード（内部シグナルハンドラ） | - |
| `_on_mystic_target_selection_requested()` | デッドコード（内部シグナルハンドラ） | - |
| `_on_mystic_ui_message_requested()` | デッドコード（内部シグナルハンドラ） | - |

### SPH デッドコード削除（10個）
| メソッド | 削除理由 |
|---------|--------|
| `cancel_spell()` | 呼び出し元ゼロ（直接参照に移行済み） |
| `_confirm_spell_effect()` | 呼び出し元ゼロ |
| `_cancel_confirmation()` | 呼び出し元ゼロ |
| `_update_spell_phase_ui()` | 呼び出し元ゼロ |
| `_show_spell_selection_ui()` | 呼び出し元ゼロ |
| `_start_spell_tap_target_selection()` | 呼び出し元ゼロ |
| `_end_spell_tap_target_selection()` | 呼び出し元ゼロ |
| `_on_spell_tap_target_selected()` | 呼び出し元ゼロ |
| `_check_tutorial_target_allowed()` | 呼び出し元ゼロ |
| `_check_tutorial_player_target_allowed()` | 呼び出し元ゼロ |

### SPH 直接参照化（5個 — 呼び出し元を直接参照に変更して SPH から削除）
| メソッド | 呼び出し元の変更 |
|---------|-------------|
| `pass_spell()` | → `spell_phase_handler.spell_flow.pass_spell()` |
| `execute_spell_effect()` | → `spell_phase_handler.spell_flow.execute_spell_effect()` |
| `_execute_spell_on_all_creatures()` | → `spell_phase_handler.spell_flow._execute_spell_on_all_creatures()` |
| `return_camera_to_player()` | → `spell_phase_handler.spell_ui_manager.return_camera_to_player()` |
| `_start_mystic_tap_target_selection()` | → `spell_phase_handler.spell_target_selection_handler._start_mystic_tap_target_selection()` |

### ファイル統合（3ファイル削除）
| 削除ファイル | 統合先 |
|------------|--------|
| `spell_navigation_controller.gd` (166行) | SpellUIManager に吸収 |
| `spell_ui_controller.gd` (150行) | SpellUIManager に吸収 |
| `spell_confirmation_handler.gd` (81行) | SpellUIManager に吸収 |

### 廃止ファイル削除
| 削除ファイル | 理由 |
|------------|------|
| `spell_system_manager.gd` (86行) | 全アクセサ呼び出しゼロ（デッドコード） |
| `spell_hp_immune.gd` (72行) | SpellProtection に統合 |

**改善効果**:
- 責務の明確化: MysticArts 処理は MysticArtsHandler に完全統一
- SPH 行数削減: 505行 → 417行（~88行削減）
- ファイル数: 5ファイル削除（合計 ~555行）
