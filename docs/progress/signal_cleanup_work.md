# 🔧 シグナル整理 + コーディング規約違反 作業ドキュメント

**作成日**: 2026-02-11
**目的**: シグナル接続の整理に加え、コーディング規約違反を包括的に調査・修正する

---

## ステータス

| フェーズ | ステータス | 箇所数 |
|---------|-----------|--------|
| 1. 全接続・規約違反の調査 | ✅ 完了 | - |
| 2. 修正A-P1: シグナルチェーン参照 | ✅ 修正済み | 10箇所 |
| 2b. info_panel構造改善 Step1+2 | ✅ 修正済み | 統合メソッド化 |
| 2c. info_panel Step3: コールバック統合 | ✅ 修正済み | 8→2コールバック |
| 3. 修正B: privateメソッド外部呼出し | ✅ 修正済み | ~25箇所 |
| 4. 修正C: privateシグナル接続 | ✅ 修正済み | 4箇所 |
| 5a. 修正D-P3: handlerプロパティチェーン | ⬜ 未着手 | ~119箇所 |
| 5b. 修正D-P4: board_system.gfm.spell | ⬜ 未着手 | 11箇所 |
| 5c. 修正D-P5: ui_manager_ref.info_panel等 | ✅ 大幅改善 | 181→35箇所（残りは正当な直接参照） |
| 6. 修正E: 状態フラグ外部直接set | ✅ 修正済み | 4箇所 |
| 7. 修正F: デバッグフラグ未集約 | ✅ 修正済み | 5/6箇所 |
| 8. 修正G: ラムダ接続 | ✅ 修正済み | 3箇所 |
| 9. 修正H: UI座標ハードコード | ⬜ 後回し | ~17箇所 |
| 10. signal_flow_mapスキル作成 | ⬜ 未着手 | - |

---

## 違反カテゴリと優先度

### 概要

| カテゴリ | 規約 | 説明 | 深刻度 |
|---------|------|------|--------|
| A. シグナルチェーン参照 | 規約9 | `a.b.c.signal.connect()` | 🟠 中 |
| B. privateメソッド外部呼出し | 規約7 | `obj._method()` を外部から呼ぶ | 🔴 高 |
| C. privateシグナル接続 | 規約7 | `signal.connect(obj._method)` | 🔴 高 |
| D. 内部プロパティ直接参照 | 規約9 | `a.b.method()` チェーンアクセス | 🟠 中 |
| E. 状態フラグ外部直接set | 規約8 | `obj.is_xxx = value` 外部代入 | 🟠 中 |
| F. デバッグフラグ未集約 | 規約10 | DebugSettings外にデバッグフラグ | 🟡 低 |
| G. ラムダ接続 | シグナル規約 | 切断困難な永続ラムダ接続 | 🟡 低 |
| H. UI座標ハードコード | 規約6 | `Vector2(固定値)` | 🟡 低 |

---

## A. シグナルチェーン参照（10箇所）

### A-1: game_flow_manager.item_phase_handler.item_phase_completed（5箇所）

| # | ファイル | 行 | 接続先 |
|---|---------|-----|--------|
| 1 | dominio_command_handler.gd | 647 | `_on_move_item_phase_completed` (ONE_SHOT) |
| 2 | dominio_command_handler.gd | 1075 | `_on_move_item_phase_completed` (ONE_SHOT) |
| 3 | tile_battle_executor.gd | 160 | `_on_item_phase_completed` (ONE_SHOT) |
| 4 | tile_battle_executor.gd | 236 | `_on_item_phase_completed` (ONE_SHOT) |
| 5 | tile_battle_executor.gd | 281 | `_on_item_phase_completed` (ONE_SHOT) |

**修正方針**: game_flow_managerにitem_phase_completedシグナルをバブルアップ、
または各クラスにitem_phase_handler参照をinitialize時に渡す

### A-2: board_system.battle_system.invasion_completed（3箇所）

| # | ファイル | 行 | 接続先 |
|---|---------|-----|--------|
| 1 | cpu_turn_processor.gd | 267 | `_on_invasion_completed` (ONE_SHOT) |
| 2 | dominio_command_handler.gd | 689 | callable (ONE_SHOT) |
| 3 | land_action_helper.gd | 539 | callable (ONE_SHOT) |

**修正方針**: board_systemにinvasion_completedをバブルアップ

### A-3: game_flow_manager.lap_system.checkpoint_signal_obtained（2箇所）

| # | ファイル | 行 | 接続先 |
|---|---------|-----|--------|
| 1 | player_info_panel.gd | 64 | `_on_signal_obtained` |
| 2 | tutorial_manager.gd | 200 | `_on_checkpoint_passed` |

**修正方針**: game_flow_managerにcheckpoint_signal_obtainedをバブルアップ

---

## B. privateメソッド外部呼出し（~50箇所）

### B-1: 深刻 - ロジック系のprivateメソッド呼出し

#### spell_phase_handler._* を外部から呼ぶ（~10箇所）
| ファイル | 行 | 呼出し |
|---------|-----|--------|
| spell_mystic_arts.gd | 276, 352, 706 | `spell_phase_handler_ref._return_to_spell_selection()` |
| spell_mystic_arts.gd | 471, 544 | `spell_phase_handler_ref._show_spell_cast_notification()` |
| spell_mystic_arts.gd | 507, 590 | `spell_phase_handler_ref._return_camera_to_player()` |
| spell_mystic_arts.gd | 990, 1012 | `spell_phase_handler_ref._apply_single_effect()` |
| spell_phase_handler.gd | 835 | `spell_mystic_arts._end_mystic_phase()` |
| spell_borrow.gd | 160, 255 | `spell_phase_handler_ref._show_target_selection_ui()` |
| spell_borrow.gd | 171 | `spell_phase_handler_ref._apply_single_effect()` |
| card_selection_ui.gd | 865 | `game_flow_manager_ref.spell_phase_handler._return_to_spell_selection()` |

**修正方針**: 呼ばれるメソッドをpublic化（`_`除去）

#### spell_effect_executor.gd → spell_phase_handler._*（~5箇所）
| ファイル | 行 | 呼出し |
|---------|-----|--------|
| spell_effect_executor.gd | 24 | `handler._show_spell_cast_notification()` |
| spell_effect_executor.gd | 67 | `handler._return_camera_to_player()` |
| spell_effect_executor.gd | 87, 166 | `handler._get_player_ranking()` |
| spell_effect_executor.gd | 334 | `handler._show_spell_cast_notification()` |
| spell_effect_executor.gd | 368 | `handler._return_camera_to_player()` |

**修正方針**: 同上、public化

#### dominio_command_handler._* を外部から呼ぶ
| ファイル | 行 | 呼出し |
|---------|-----|--------|
| land_action_helper.gd | 116,118,119 | `handler._confirm_level_selection()`, `_on_arrow_up/down()` |
| land_action_helper.gd | 189,190,487 | 同上 + `_start_move_battle_sequence()` |
| land_action_helper.gd | 760,761 | `handler._on_arrow_up/down()` |
| land_input_helper.gd | 181,185,189 | `handler._select_previous/next_level()`, `_confirm_level_selection()` |
| ui_tap_handler.gd | 64 | `gfm.dominio_command_handler._restore_navigation()` |

**修正方針**: public化。land_action_helperとland_input_helperはdominio_command_handlerの
分割ヘルパーなので、内部的に密結合は許容し得るが、`_`プレフィックスは外すべき

#### cpu_ai系 → cpu_movement_evaluator._*（~15箇所）
| ファイル | 呼出し例 |
|---------|---------|
| cpu_spell_ai.gd | `_get_player_current_tile()`, `_get_player_direction()`, `_get_tile_info()`, `_can_invade_and_win()`, `_calculate_toll()` |
| cpu_holy_word_evaluator.gd | 同上 + `_can_enemy_invade()` |
| cpu_spell_condition_checker.gd | `_get_checkpoint_type_string()` |

**修正方針**: 全てpublic化（`_`除去）。AI系は内部ユーティリティとして広く参照されている

#### condition_checker._evaluate_single_condition を外部から呼ぶ（5箇所）
| ファイル | 呼出し |
|---------|--------|
| battle_item_applier.gd | `checker._evaluate_single_condition()` |
| battle_special_effects.gd | 同上 |
| battle_skill_granter.gd | 同上 |
| skill_power_strike.gd | 同上 |
| skill_stat_modifiers.gd | 同上 (×2) |

**修正方針**: public化

#### その他のprivate呼出し
| ファイル | 行 | 呼出し | 方針 |
|---------|-----|--------|------|
| card_system._load_card_data | debug_controller 203,329 | デバッグ用 | public化 |
| card_system._get_clean_card_data | spell系 103,111,123,255 | public化 |
| ui_manager._on_card_button_pressed | card.gd 584 | public化 or ラップ |
| ui_manager._restore_spell_phase_buttons | ui_tap_handler 75,96,108 | public化 |
| card_selection_ui._register_back_button | card.gd 653 | public化 |
| dominio_order_ui._on_level_selected | dominio_command_handler 551 | public化 |
| movement_controller._set_player_current_direction | branch_selector 246 | public化 |
| lap_system._setup_ui | game_system_manager 468, game_flow_manager 141 | public化 |
| lap_system._check_lap_complete | spell_player_move 219 | public化 |
| global_action_buttons._update_button_states | tutorial_overlay 262 | public化 |
| spell_damage._destroy_creature | spell_magic 765, spell_curse_stat 360 | public化 |
| spell_mystic_arts._get_all_mystic_arts | spell_borrow 211 | public化 |
| stage_loader._get_enemies | game_3d/quest_game 複数 | public化 |
| card._show_card_front/_show_secret_back | skill_secret 36-49 | public化 |
| card._update_secret_display | hand_display 229 | public化 |
| card._adjust_children_size | creature_card_3d_quad 51 | public化 |
| mc.direction_selector._setup_navigation | card.gd 693 | public化 |
| mc.branch_selector._setup_navigation | card.gd 695 | public化 |
| cpu_battle_ai → _defense_evaluator._simulate/is_worse | 597,603 | public化 |
| cpu_ai_handler → hand_utils._check_lands_required | 555 | public化 |
| cpu_spell_condition_checker → _get_own_creatures | 675 | public化 |
| cpu_spell_condition_checker → _get_reachable_enemy | 693 | public化 |
| cpu_spell_condition_checker → _check_worst_case_win | 723 | public化 |
| tutorial_popup._apply_position | explanation_mode 140 | public化 |
| target_marker_system._create_marker_mesh | target_selection_helper 171 | public化（static） |
| spell_draw → steal_handler._move_caster | 305 | public化 |

### B-2: 許容 - super._ready() / super._on_area_entered()
tiles系のsuper呼び出しは継承パターンで正常。修正不要。

---

## C. privateシグナル接続（4箇所）— ✅ 修正済み

tap_handler のメソッドが `on_tap_target_selected` / `on_tap_target_cancelled` にpublic化済み。

---|---------|-----|------|
| 1 | ui_manager.gd | 260 | `tap_target_manager.target_selected` → `tap_handler._on_tap_target_selected` |
| 2 | ui_manager.gd | 261 | `tap_target_manager.selection_cancelled` → `tap_handler._on_tap_target_cancelled` |
| 3 | ui_manager.gd | 744 | 同上（再接続） |
| 4 | ui_manager.gd | 746 | 同上（再接続） |

**修正方針**: tap_handlerのメソッドをpublic化

---

## D. 内部プロパティ直接参照（チェーンアクセス）

### D-1: game_flow_manager.item_phase_handler.* メソッド呼出し
dominio_command_handler.gd と tile_battle_executor.gd から大量にアクセス。

| ファイル | アクセスされるメソッド |
|---------|---------------------|
| dominio_command_handler.gd | `get_selected_item()`, `start_item_phase()`, `set_preselected_attacker_item()` |
| tile_battle_executor.gd | `start_item_phase()`, `set_preselected_attacker_item()`, `was_merged()`, `get_merged_creature()`, `get_selected_item()`, `set_opponent_creature()`, `set_defense_tile_info()` |

**修正方針**: item_phase_handler参照をinitialize時に直接渡す

### D-2: game_flow_manager.spell_phase_handler.* メソッド/プロパティ参照
| ファイル | アクセス |
|---------|---------|
| debug_controller.gd | `update_mystic_button_visibility()` |
| land_action_helper.gd | `spell_cast_notification_ui` |
| spell_world_curse.gd | `spell_cast_notification_ui` |
| spell_curse.gd | `is_magic_tile_mode` |

### D-3: game_flow_manager.dominio_command_handler.* 参照
| ファイル | アクセス |
|---------|---------|
| game_system_manager.gd (初期化) | `.board_system_3d`, `.player_system`, `.ui_manager` の代入 |
| tutorial_manager.gd | `.open_dominio_order()` |

### D-4: board_system.tile_neighbor_system.*
| ファイル | アクセス |
|---------|---------|
| movement_helper.gd (×6) | `get_spatial_neighbors()` |
| land_action_helper.gd | `get_spatial_neighbors()` |
| spell_creature_place.gd | `get_spatial_neighbors()` |
| condition_checker.gd | `has_adjacent_ally_land()` |
| skill_support.gd | `get_spatial_neighbors()` |

**修正方針**: board_systemに委譲メソッド（get_spatial_neighbors等）を追加

### D-5: board_system.battle_system.* メソッド呼出し
| ファイル | アクセス |
|---------|---------|
| dominio_command_handler.gd | `execute_3d_battle_with_data()` |
| land_action_helper.gd | `execute_3d_battle_with_data()` |
| cpu_turn_processor.gd | `execute_3d_battle_with_data()` |

**修正方針**: board_systemに委譲メソッド追加

### D-6: board_system.special_tile_system.*
| ファイル | アクセス |
|---------|---------|
| cpu_movement_evaluator.gd | `warp_pairs`, `get_warp_pair()` |

### D-7: ui_manager.*_ui.* / hand_display.* 大量チェーンアクセス
多数のファイルからui_managerの子コンポーネントに直接アクセスしている。
card.gd, card_selection_handler.gd, spell_phase_handler.gd, item_phase_handler.gd,
dominio_command_handler.gd, land_action_helper.gd 等。

**修正方針**: これは量が多く、ui_managerに全委譲メソッドを追加すると肥大化する。
→ 現実的には以下の方針:
1. `global_comment_ui.show_and_wait()` は `await ui_manager.show_comment()` に委譲
2. `hand_display.update_hand_display()` は `ui_manager.update_hand()` に委譲
3. info_panel系は使用頻度が高いので、initialize時に直接参照を渡すことを検討
4. card_selection_ui は既にgame_flow_manager_refを持つなど密結合 → 段階的に整理

---

## E. 状態フラグ外部直接set（規約8違反）

外部から `is_xxx = value` で直接代入している箇所。
`begin_xxx()` / `reset_xxx()` 等のメソッド経由にすべき。

| # | ファイル | 行 | コード |
|---|---------|-----|--------|
| 1 | dominio_command_handler.gd | 113 | `ui_manager.card_selection_ui.is_active = false` |
| 2 | land_action_helper.gd | 484 | `handler.is_waiting_for_move_defender_item = false` |
| 3 | land_action_helper.gd | 558 | `handler.is_waiting_for_move_defender_item = false` |
| 4 | land_action_helper.gd | 559 | `handler.is_boulder_eater_move = false` |

**注記**: cpu_ai系の `result.is_xxx = true` はローカルDictionary/オブジェクト構築なので許容。
card_selection_ui の `card_node.is_grayed_out` / hand_display の `card.is_selectable` は
UIプロパティの設定であり、状態フラグとは異なるので許容。
battle系の `participant.is_using_scroll` も戦闘専用の一時フラグで許容。

**修正方針**: dominio_command_handlerとland_action_helperの4箇所のみ。
メソッド化するか、フラグリセットをhandler側に委譲。

---

## F. デバッグフラグ未集約（規約10違反）

DebugSettingsに集約されていないデバッグフラグ。

| # | ファイル | 変数 | 用途 |
|---|---------|------|------|
| 1 | spell_phase_handler.gd | `debug_disable_secret_cards` | 秘密カード無効化 |
| 2 | game_3d.gd | `debug_manual_control_all` | 全プレイヤー手動操作 |
| 3 | quest_game.gd | `debug_manual_control_all` | 同上（クエスト用） |
| 4 | creature_manager.gd | `debug_mode` | デバッグ表示 |
| 5 | ui_manager.gd | `debug_mode` | デバッグ表示 |
| 6 | signal_registry.gd | `debug_mode` | シグナルデバッグ |

**修正方針**: 全てDebugSettingsのstatic変数に移行。
`debug_manual_control_all` は game_3d / quest_game で重複しており、統一必須。

---

## G. ラムダ接続（切断困難）

規約「ラムダ接続を多用しない（切断が困難になる）」に該当。
永続接続のラムダは特に問題（切断不能）。ONE_SHOTや動的生成UIのラムダは許容寄り。

### G-1: 永続接続ラムダ（要修正）

| # | ファイル | 行 | 内容 |
|---|---------|-----|------|
| 1 | tile_action_processor.gd | 88 | `battle_executor.invasion_completed.connect(func(...): emit_signal(...))` |
| 2 | game_flow_manager.gd | 92 | `lap_system.lap_completed.connect(func(player_id): lap_completed.emit(player_id))` |
| 3 | action_menu_ui.gd | 316 | `btn.pressed.connect(func(): _on_button_pressed(index))` |

**修正方針**: 
- #1, #2: シグナル中継用。名前付きメソッドに変更するか、シグナルバブルアップに統一
- #3: bind()で代替可能 → `btn.pressed.connect(_on_button_pressed.bind(index))`

### G-2: 許容（ONE_SHOTまたは動的UI生成時）

| ファイル | 行 | 備考 |
|---------|-----|------|
| global_comment_ui.gd | 353, 359 | 動的生成ボタン、ラムダで問題なし |
| debug_controller.gd | 287 | ONE_SHOT |
| quest/world_stage_select.gd | 583, 662, 667 | 動的UI生成 |
| cpu_deck_editor.gd | 458 | ONE_SHOT |

---

## H. UI座標ハードコード（規約6違反）

`position = Vector2(固定値)` でビューポート相対になっていない箇所。
量が多く影響範囲も大きいため、優先度は最低。

### 主な該当ファイル
| ファイル | 箇所数 | 内容 |
|---------|--------|------|
| level_up_ui.gd | 5 | パネル・ラベル位置 |
| dominio_order_ui.gd | 6 | レベル選択・地形選択パネル |
| surrender_dialog.gd | 2 | ダイアログ内部レイアウト |
| debug_panel.gd | 2 | デバッグパネル位置 |
| battle_status_overlay.gd | 1 | セパレータ位置 |
| card.gd | 1 | シンボルラベル位置 |

**修正方針**: 全面的な修正は大工事。以下の段階で対応:
1. 画面端に配置するUI（debug_panel等）→ viewport相対に修正
2. パネル内部の相対配置 → VBoxContainer/HBoxContainer化を検討
3. カード内部等の小さい固定値 → 後回し

---

## 修正の優先順位（推奨）

1. **B. privateメソッドpublic化** — 最も簡単で安全。`_`を外すだけ。リスク低（~50箇所）
2. **C. privateシグナル接続** — Bと同時に修正可能（4箇所、修正済みの可能性あり）
3. **A. シグナルチェーン参照** — バブルアップまたは参照注入。中程度の作業量（10箇所）
4. **E. 状態フラグ外部直接set** — メソッド化（4箇所）
5. **F. デバッグフラグ集約** — DebugSettingsに移行（6箇所）
6. **G. ラムダ接続** — 名前付きメソッドに変更（3箇所）
7. **D. 内部プロパティ参照** — 量が多い。段階的に対応。board_system委譲から開始
8. **H. UI座標ハードコード** — 大規模。後回し

---

## 作業ログ

### セッション1（2026-02-11）
- ✅ 全.connect()呼び出しの調査完了（~250箇所）
- ✅ privateメソッド外部呼出しの調査完了（~50箇所）
- ✅ チェーンアクセスの調査完了（多数）
- ✅ 分類・優先度設定完了
- ✅ 修正C完了（privateシグナル接続 → tap_handler public化済み）
- ⬜ 次: 修正B（privateメソッドpublic化）から着手

### セッション2（2026-02-11 続き）
- ✅ 追加調査: 状態フラグ外部直接set（E）、デバッグフラグ未集約（F）、ラムダ接続（G）、UI座標ハードコード（H）
- ✅ ドキュメント追記完了（E〜H セクション追加、ステータステーブル更新）

### セッション3（2026-02-11 続き）
- ✅ 消失チャットで壊れたland_action_helper.gdのエラー修正（6箇所）
- ✅ 消失チャットで壊れたstage_loader.gdのエラー修正（_get_enemies内部呼び出し8箇所）
- ✅ 修正B完了: privateメソッド外部呼び出し全件public化（残り0件）
  - _setup_navigation (direction_selector, branch_selector)
  - _setup_ui (lap_system, magic_tile_ui, magic_stone_ui, card_buy_ui, card_give_ui)
  - _set_player_current_direction (movement_controller)
  - _on_cancel_dominio_order_button_pressed (ui_manager)
  - _update_secret_display (card)
  - _create_marker_mesh (target_marker_system)
  - _detect_move_type (movement_helper)
  - _process_card_sacrifice (tile_summon_executor)
  - _has_owned_lands (board_system_3d)
  - _destroy_creature (spell_damage)
  - _move_caster_to_enemy_hand (steal_handler)
  - _check_lap_complete (lap_system)
  - _show_card_front / _show_secret_back / _adjust_children_size (card)
- ✅ バグ修正: battle_simulatorで呪いのtemporary_effectsが未反映（apply_effect_arrays追加）
### セッション4（2026-02-12）
- ✅ 修正F完了（5/6箇所）: デバッグフラグをDebugSettingsに集約
  - disable_secret_cards (spell_phase_handler → DebugSettings)
  - creature_manager_debug (creature_manager → DebugSettings)
  - ui_debug_mode (ui_manager → DebugSettings)
  - signal_registry_debug (signal_registry → DebugSettings)
  - debug_manual_control_allは影響範囲大のため保留
- ✅ 修正E完了（4箇所）: 状態フラグ外部直接setをメソッド化
  - card_selection_ui.is_active = false → deactivate()
  - handler.is_waiting/is_boulder → reset_move_battle_flags() / set_boulder_eater_move()
- ✅ 修正G完了（3箇所）: ラムダ接続を名前付きメソッドに変更
  - tile_action_processor: invasion_completed中継 → _on_invasion_completed
  - game_flow_manager: lap_completed中継 → _on_lap_completed
  - action_menu_ui: func() → bind(index)
- ✅ 修正A完了（P1: シグナルチェーン接続10箇所）
  - A-1: gfm.item_phase_handler → dominio_command_handler, tile_battle_executorにiph参照キャッシュ
  - A-2: board_system.battle_system → dominio_command_handler, cpu_turn_processorにbs参照キャッシュ
  - A-3: gfm.lap_system.signal → player_info_panel.set_game_flow_managerにlap_system引数追加
  - A-4: ui_manager.hand_display.signal → spell_phase_handlerにhand_display参照キャッシュ
- ✅ info_panel構造改善 Step 1+2完了
  - ui_managerに統合メソッド追加: hide_all_info_panels, is_any_info_panel_visible, show_card_info, show_card_selection
  - 一括hide/種別分岐showを統合メソッドに置換（card.gd, card_selection_handler, spell_phase_handler, card_selection_ui）
  - is_visible_panel → is_panel_visible() に統一
- ✅ info_panel Step 3完了（コールバック統合）
  - card_selection_uiの8コールバック → _on_info_panel_confirmed/_cancelled の2つに統合
  - _connect_info_panel_signals(panel)ヘルパー追加（is_connectedガードで重複接続防止）
  - 接続管理フラグ廃止（is_connectedチェックのみで十分）
  - info_panel直接参照: 181箇所 → 35箇所に削減（146箇所、81%削減）
  - 残り35箇所はcard_selection_ui(26)/card_selection_handler(9)のみ（選択モード制御で直接参照が必要）
  - 外部ファイル（ui_tap_handler, dominio_order_ui, spell_mystic_arts等）からの直接参照は0に
- ⬜ 次: D-P3（handlerチェーン~119箇所）

### セッション5（2026-02-12 続き）
- ✅ D-P3 phase_display委譲完了: show_toast, show_action_prompt, hide_action_prompt
  - ui_manager.gd に委譲メソッド追加
  - 置換済みファイル: game_flow_manager, tile_action_processor, spell_phase_handler,
	item_phase_handler, tile_battle_executor, tile_summon_executor, target_selection_helper,
	bankruptcy_handler, lap_system, spell_effect_executor, dominio_command_handler,
	land_selection_helper, land_action_helper, card_selection_handler, spell_creature_swap,
	spell_mystic_arts, special_tile_system, debug_controller, movement_direction_selector,
	movement_branch_selector
- ✅ D-P3 global_comment_ui委譲完了: show_comment_and_wait, show_choice_and_wait, show_comment_message, hide_comment_message
  - 置換済みファイル: game_flow_manager, tile_action_processor, dominio_command_handler,
	bankruptcy_handler, lap_system, spell_effect_executor, spell_dice, special_tile_system,
	card_selection_handler, special_base_tile, magic_tile, magic_stone_tile, card_buy_tile,
	card_give_tile, branch_tile
- ✅ D-P3 hand_display委譲完了: update_hand_display
  - 置換済みファイル: item_phase_handler, card_selection_handler, debug_controller,
	card_buy_tile, card_give_tile
- ⏳ D-P4 board_system委譲 途中: tile_action_processor, tile_neighbor_system
  - board_system_3d.gd に委譲メソッド追加済み
  - 置換済み: dominio_command_handler, land_action_helper, movement_helper（一部）
  - 未置換: skill_support(1), special_tile_system(3), spell_phase_handler(2+コメント),
	movement_helper(1残), spell_creature_place(1), condition_checker(1)
- ⬜ D-P3 残り: card_selection_ui, dominio_order_ui, hand_display状態設定, global_action_buttons
  - これらはUI操作系で密結合のため委譲メソッド化が難しく、要検討
- ⬜ D-P3 残り: game_flow_manager内のdice_result系4箇所（game_flow_managerのみ使用、後回し）
- ⬜ D-P4 残り: board_system.game_flow_manager.*（逆方向参照7箇所）
- ❌ エラー発生: 置換途中でビルドエラー → 次セッションで修正

### セッション5続き
- ✅ D-P4 board_system委譲 完了（tile_action_processor, tile_neighbor_system, spell_land）
  - 残り置換完了: skill_support, special_tile_system, movement_helper, spell_creature_place, condition_checker
  - board_system_3d にchange_tile_element/change_tile_level追加
  - skill_land_effects の board_system.game_flow_manager.spell_land チェーン4箇所解消
  - execute_swap_action の引数エラー修正
  - 非CPU系のboard_system内部チェーンは デバッグフラグ2箇所を除き0に
