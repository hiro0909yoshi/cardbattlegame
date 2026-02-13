# 🔧 シグナル整理 + コーディング規約違反 作業ドキュメント

**作成日**: 2026-02-11
**最終更新**: 2026-02-13
**目的**: シグナル接続の整理に加え、コーディング規約違反を包括的に調査・修正する

---

## ステータス

| フェーズ | ステータス | 備考 |
|---------|-----------|------|
| A. シグナルチェーン参照 | ✅ 完了 | 10箇所修正 |
| B. privateメソッド外部呼出し | ✅ 完了 | ~50箇所 public化 |
| C. privateシグナル接続 | ✅ 完了 | 4箇所修正 |
| D-P3. ui_manager委譲（phase_display/comment/hand） | ✅ 完了 | ~85箇所置換 |
| D-P4. board_system委譲（tile_action/neighbor/spell_land） | ✅ 完了 | ~44箇所置換 |
| D-P5. info_panel構造改善 | ✅ 完了 | 181→35箇所（81%削減） |
| E. 状態フラグ外部直接set | ✅ 完了 | 4箇所メソッド化 |
| F. デバッグフラグ集約 | ✅ 完了 | 5/6箇所集約済み |
| G. ラムダ接続 | ✅ 完了 | 3箇所名前付きメソッド化 |
| 規約7 privateプロパティ外部参照 | ✅ 完了 | 全件public化/getter追加 |
| board_system委譲: mc/cc/tap系 | ✅ 完了 | 57箇所置換（タスク3） |
| board_system委譲: サブシステム直接参照 | ✅ 完了 | 12箇所、委譲メソッド5つ追加（タスクA〜E） |
| preload定数化（循環参照対策） | ✅ 完了 | gsm/gfm/quest_game |
| gfm内部チェーン解消（直接参照パターン） | ✅ 完了 | lap_system, spell_cost_modifier, battle_status_overlay等 |
| H. UI座標ハードコード | ⬜ 後回し | ~20箇所 |
| debug_manual_control_all集約 | ⬜ 後回し | 影響範囲大 |
| signal_flow_mapスキル作成 | ⬜ 未着手 | — |

---

## 全規約の最終確認結果（2026-02-12時点）

| 規約 | 状態 | 詳細 |
|------|------|------|
| 1. Nodeにhas() | ✅ 違反なし | |
| 2. TextureRectにcolor | ✅ 違反なし | |
| 3. 予約語変数名 | ⚠️ 軽微5箇所 | ローカル変数name×3, position×1, size×1。実害なし |
| 4. シャドウイング | ⚠️ 軽微3箇所 | battle系ローカルboard_system×3。意図的な可能性 |
| 5. end_turn直接呼出し | ✅ 違反なし | game_flow_manager自身のみ（正常） |
| 6. UI座標ハードコード | ❌ ~20箇所 | 後回し（大工事） |
| 7. privateメソッド外部呼出し | ✅ 違反0件 | 全件public化済み |
| 8. 状態フラグ外部直接set | ✅ 違反0件 | メソッド化済み |
| 9. 内部プロパティ外部参照 | ✅ 違反0件 | public化/getter追加済み |
| 10. デバッグフラグ未集約 | ⚠️ 1件残り | debug_manual_control_all（影響範囲大で保留） |
| シグナル方向 | ✅ 違反なし | 親→子のシグナル接続0件 |
| ラムダ接続 | ⚠️ 軽微 | global_comment_ui 2箇所（動的ボタン）、battle_test多数（テスト用） |

---

## 残存する密結合パターン

### 1. board_system内部チェーンアクセス — ✅ 完了

タスク3（mc/cc/tap系 57箇所）+ タスクA〜E（サブシステム直接参照 12箇所）で解消済み。

**委譲メソッド追加一覧**:
- カメラ: enable_manual_camera, enable_follow_camera, set_camera_player, return_camera_to_player, focus_camera_on_player_pos, focus_camera_slow, focus_camera_on_tile_slow, is_direction_camera_active, cancel_direction_tween
- 移動: get_player_tile, set_player_tile, place_player_at_tile, clear_all_down_states_for_player, execute_warp, heal_all_creatures_for_player, focus_camera_on_player_mc, clear_down_state_for_player, set_down_state_for_tile, on_movement_reverse_curse_removed, swap_came_from_for_reverse, is_movement_selection_active, restore_movement_selector_navigation
- タイル表示: switch_tile_display_mode, get_tile_display_mode_name, update_tile_display, get_tile_label
- タイルデータ: set_tile_level, calculate_level_up_cost, calculate_toll_with_curse
- 特殊タイル: get_warp_pairs, get_warp_pair
- バトル: get_battle_screen_manager
- setter/getter: set_camera_controller_ref, set_spell_player_move, set_cpu_movement_evaluator, get_cpu_movement_evaluator, get_spell_movement, set_movement_controller_gfm, get_camera_controller_ref, get_movement_controller_ref

**残存する許容済みパターン**:
- tile_nodes直接参照（200箇所+）: 公開プロパティとして維持。全ファイルが読み取り専用で使用、構造変更の可能性なし
- board_system.camera直接参照（~10箇所）: 実害低
- battle_system初期化キャッシュ（2箇所）: initialize時の1回限り
- MC内部ヘルパー（warp_handler, special_handler等）のcontroller.*参照: 内部分割のため許容

### 2. game_flow_manager内部コンポーネントへの2段チェーン — ✅ 完了

直接参照パターンを導入してチェーンアクセスを解消。詳細は `docs/implementation/delegation_method_catalog.md` を参照。

| パターン | 対応内容 |
|---------|---------|
| `gfm.lap_system.*` | lap_systemを各クラスに直接注入（15+ファイル） |
| `gfm.spell_cost_modifier.*` | spell_cost_modifierを各クラスに直接注入（6ファイル） |
| `gfm.battle_status_overlay.*` | battle_status_overlayを各クラスに直接注入（5ファイル） |
| `gfm.spell_phase_handler.*` | spell_phase_handlerを必要なクラスに直接注入（2ファイル） |
| その他 | player_system, ui_manager, spell_curse_stat等も直接注入パターン適用 |

### 3. controller内部コンポーネントへの2段チェーン（~6箇所）

| パターン | 箇所数 | 備考 |
|---------|--------|------|
| `controller.special_tile_system.*` | 4 | movement_warp_handler, destination_predictor |
| `controller.spell_movement.*` | 1 | movement_warp_handler |

**優先度**: 低。分割ヘルパーからの参照であり許容寄り。

### 4. ui_manager内部チェーン残り（~65箇所）

#### 4a. card_selection_ui（~21箇所、7ファイル）
| 呼び出し元 | 箇所数 | アクセス内容 |
|-----------|--------|-------------|
| card.gd | 4 | is_active, selection_mode参照 |
| spell_phase_handler.gd | 5 | show_selection, deactivate, pending_card_index, is_active, selection_mode |
| item_phase_handler.gd | 2 | show_selection |
| dominio_command_handler.gd | 2 | deactivate, hide_selection |
| card_selection_handler.gd | 4 | enable_card_selection |
| ui_tap_handler.gd | 1 | is_active参照 |
| movement_destination_predictor.gd | 1 | update_restriction_for_destinations |
| tutorial_manager.gd | 1 | is_active参照 |
| game_system_manager.gd | 1 | game_flow_manager_ref代入（初期化） |

**分析**: show_selection / deactivate / is_active は委譲可能だが、selection_mode参照・enable_card_selectionなどの複雑なインタラクションは委譲しにくい。

#### 4b. dominio_order_ui（~19箇所、2ファイル）
| 呼び出し元 | 箇所数 | アクセス内容 |
|-----------|--------|-------------|
| dominio_command_handler.gd | 10 | show_action_menu, hide_level/terrain_selection, highlight_level_button, on_level_selected |
| land_action_helper.gd | 9 | hide_action_menu, show/hide_terrain_selection, highlight_terrain_button, show_action_menu |

**分析**: dominio_command_handler / land_action_helperからのみ参照。この2つはドミニオ操作専用のコンポーネントであり、dominio_order_uiとの密結合は機能的に不可避。

#### 4c. phase_display（4箇所、1ファイル）
| 呼び出し元 | アクセス内容 |
|-----------|-------------|
| game_flow_manager.gd | show_big_dice_result, show_dice_result_range/triple/double |

**分析**: game_flow_managerのみ。委譲メソッド追加は容易だが効果薄。

#### 4d. player_info_panel（3箇所、3ファイル）
| 呼び出し元 | アクセス内容 |
|-----------|-------------|
| game_flow_manager.gd | set_current_turn |
| spell_phase_handler.gd | get_player_ranking |
| spell_world_curse.gd | update_all_panels |

**分析**: 委譲メソッド追加は容易。

#### 4e. info_panel系シグナル接続（9箇所、1ファイル）
| 呼び出し元 | アクセス内容 |
|-----------|-------------|
| card_selection_handler.gd | creature/spell/item_info_panel_ui.selection_confirmed/cancelled.connect |

**分析**: info_panel参照のinitialize時注入で解消可能だが、Step3で181→35に削減済みで効果薄い。

#### 4f. spell_cast_notification_ui（1箇所）
| 呼び出し元 | アクセス内容 |
|-----------|-------------|
| land_action_helper.gd | spell_phase_handler.spell_cast_notification_ui（3段チェーン） |

**分析**: 3段チェーンで最も問題。initialize時に参照を渡すべき。

**総合評価**: 4b（dominio系）は機能的に密結合が不可避。4a（card_selection_ui）は主要メソッドの委譲で改善可能だが効果は中程度。4f（3段チェーン1箇所）のみ明確な改善対象。

**優先度**: 低。委譲メソッド化でui_managerが肥大化するリスクがあり、現状維持が妥当。4fのみ要修正。

### 5. tile_data_manager → game_system_manager逆参照（1箇所）

```
tile_data_manager → game_system_manager.board_system_3d.spell_curse_toll
```

**優先度**: 低。1箇所のみだが設計的に良くない。spell_curse_tollの参照をinitialize時に渡すべき。

---

---

## 依存方向の分析（2026-02-12時点）

### 現状の参照関係

```
game_system_manager（最上位・初期化担当）
  ↓ 参照を注入
  ├── game_flow_manager ←→ board_system  ❌ 相互参照
  │     ↓                    ↓
  │     ├── spell_phase_handler   ├── tile_action_processor → game_flow_manager ❌
  │     ├── dominio_cmd_handler → ui_manager, board_system
  │     ├── item_phase_handler
  │     └── lap_system
  │
  ├── ui_manager → player_system（表示用、OK）
  │     ↓
  │     ├── card_selection_ui → game_flow_manager ❌ 下位→上位の逆参照
  │     └── player_info_panel → player_system（表示用、OK）
  │
  ├── player_system → board_system（資産計算用）
  │
  └── board_system
		├── tile_data_manager → game_system_manager ❌ 最下位→最上位
		└── tile_action_processor → game_flow_manager ❌
```

### 問題のある依存方向

| # | from → to | 問題 | 深刻度 | 修正方針 |
|---|-----------|------|--------|---------|
| 1 | game_flow_manager ↔ board_system | 相互参照 | ⚠️ 中 | 設計上不可避に近い。Mediator化は大工事。現状許容 |
| 2 | tile_data_manager → game_system_manager | 最下位→最上位。get_tree().root経由 | 🔴 高 | spell_curse_tollの参照をinitialize時に注入 |
| 3 | tile_action_processor → game_flow_manager | 子→親の親への参照 | ⚠️ 中 | initialize時注入パターン。GDScriptでは一般的。実害低 |
| 4 | card_selection_ui → game_flow_manager | UI→ロジック上位への逆参照 | ⚠️ 中 | 同上。debug_manual_control_allの参照が主因 |
| 5 | player_system → board_system | 横方向参照（資産計算用） | 🟡 低 | 実用上問題なし。コールバック化も可能だが過剰 |

### 3段チェーン（1箇所）

```
land_action_helper → handler.game_flow_manager.spell_phase_handler.spell_cast_notification_ui
```

**修正方針**: dominio_command_handlerのinitialize時にspell_cast_notification_uiの参照を渡す。

### 循環参照の全一覧

GDScriptはGC付きのためメモリリークにはならないが、設計の見通しに影響する。

#### トップレベル相互参照（2件）

| ペア | 方向 | 深刻度 | 備考 |
|------|------|--------|------|
| game_flow_manager ↔ board_system | 双方向 | ⚠️ 中 | gfm→bs:移動/タイル操作、bs→gfm:ターン制御。設計上不可避に近い |
| game_flow_manager ↔ ui_manager | 双方向 | ⚠️ 中 | gfm→ui:表示更新、ui→gfm:入力伝達。UI分離の定番パターン |

#### 親→子→親の逆参照（5件）

| 親 | 子 | 子→親の参照 | 深刻度 | 備考 |
|----|-----|-------------|--------|------|
| board_system | tile_action_processor | → game_flow_manager | ⚠️ 中 | spell_cost_modifier, spell_world_curse参照のため |
| board_system | tile_data_manager | → game_flow_manager | ⚠️ 中 | game_stats参照のため |
| board_system | movement_controller | → game_flow_manager | 🟡 低 | is_game_ended参照のみ |
| board_system | special_tile_system | → game_flow_manager | ⚠️ 中 | 特殊タイル処理で広く参照 |
| ui_manager | card_selection_ui | → game_flow_manager | 🟡 低 | debug_manual_control_all参照が主因 |

#### game_flow_manager子コンポーネントの外部参照

game_flow_managerの子ハンドラ（spell_phase_handler, dominio_command_handler, item_phase_handler等）は
全てgfm, board_system, ui_manager, player_system, card_systemの5つを参照。
これはinitialize時に注入されるパターンで循環ではなく「ハブ型依存」。

```
game_flow_manager
  └── spell_phase_handler ──→ board_system, ui_manager, player_system, card_system
  └── dominio_cmd_handler ──→ board_system, ui_manager, player_system, card_system, battle_system
  └── item_phase_handler  ──→ board_system, ui_manager, player_system, card_system, battle_system
  └── tile_battle_executor──→ board_system, ui_manager, player_system, card_system, battle_system
  └── tile_summon_executor──→ board_system, ui_manager, player_system, card_system
  └── lap_system          ──→ board_system, ui_manager, player_system
```

これ自体は問題ないが、5つ全てに依存するコンポーネントが多い点は注意。
将来的にContext/ServiceLocatorパターンで整理する余地あり。

#### battle系の参照

| コンポーネント | 参照先 | 備考 |
|---------------|--------|------|
| battle_system | board_system, player_system, card_system, game_flow_manager | gfm参照は通知用 |
| battle_special_effects | board_system, card_system, game_flow_manager | lap_count/spell参照のため |

battle_systemはboard_systemの子だが、game_flow_managerも参照している（親の親参照）。

#### 横方向参照（1件）

| from | to | 用途 |
|------|----|------|
| player_system → board_system | 資産計算（calculate_land_value） | 実害なし |

#### 総合評価

- **真の循環**: gfm ↔ board_system、gfm ↔ ui_manager の2ペアのみ
- **逆参照**: board_system子 → gfm が5件（tile_action_processor, tile_data_manager, movement_controller, special_tile_system, battle_system）
- **改善余地**: tile_data_manager/movement_controllerの逆参照は必要最小限の情報をinitialize時に渡すことで解消可能。完全解消にはMediator/EventBusが必要だが現規模では過剰

---

## 推奨する今後の作業順

~~1. tile_data_manager逆参照解消（依存#2, 1箇所）~~ — ✅ 完了
~~2. 3段チェーン解消（land_action_helper, 1箇所）~~ — ✅ 完了
~~3. board_system委譲メソッド追加（密結合#1, ~69箇所）~~ — ✅ 完了（タスク3 + A〜E）
~~4. game_flow_manager委譲（密結合#2, 49箇所）~~ — ✅ 完了（直接参照パターン導入）
5. **UI座標ハードコード**（規約6, ~20箇所）— 大工事、後回し
6. **debug_manual_control_all集約**（規約10残り）— 影響範囲大
7. **signal_flow_mapスキル作成** — 未着手

---

## 作業ログ

### セッション1（2026-02-11）
- ✅ 全.connect()呼び出しの調査完了（~250箇所）
- ✅ privateメソッド外部呼出しの調査完了（~50箇所）
- ✅ チェーンアクセスの調査完了
- ✅ 分類・優先度設定完了
- ✅ 修正C完了（privateシグナル接続 → tap_handler public化）

### セッション2（2026-02-11 続き）
- ✅ 追加調査: E（状態フラグ）、F（デバッグフラグ）、G（ラムダ）、H（UI座標）
- ✅ ドキュメント追記完了

### セッション3（2026-02-11 続き）
- ✅ land_action_helper.gd / stage_loader.gd のエラー修正
- ✅ 修正B完了: privateメソッド外部呼出し全件public化（~25箇所）
- ✅ バグ修正: battle_simulatorで呪いのtemporary_effectsが未反映

### セッション4（2026-02-12）
- ✅ 修正F完了（5/6箇所）: DebugSettings集約
- ✅ 修正E完了（4箇所）: 状態フラグメソッド化
- ✅ 修正G完了（3箇所）: ラムダ→名前付きメソッド
- ✅ 修正A完了（10箇所）: シグナルチェーン→参照キャッシュ/バブルアップ
- ✅ info_panel構造改善完了: 統合メソッド化、コールバック8→2、外部参照181→35（81%削減）

### セッション5（2026-02-12 続き）
- ✅ D-P3 ui_manager委譲完了: phase_display/global_comment_ui/hand_display（~85箇所置換）
- ✅ D-P4 board_system委譲完了: tile_action_processor/tile_neighbor_system/spell_land（~44箇所置換）
- ✅ execute_swap_action引数エラー修正

### セッション6（2026-02-12 続き）
- ✅ 規約7 privateメソッド外部呼出し 残り5箇所修正
  - tutorial_popup.apply_position, global_action_buttons.update_button_states,
	card_system.initialize_decks, dominio_command_handler.set_action_selection_navigation,
	ui_manager.restore_current_phase
- ✅ 規約7+8+9 privateプロパティ外部参照 全件修正
  - movement_controller.current_remaining_steps（public化）
  - game_flow_manager.is_game_ended（getterプロパティ名変更）
  - ui_manager.is_nav_state_saved()（getter追加）
  - dominio_command_handler.swap_mode/swap_old_creature/swap_tile_index（public化）
  - explanation_mode.popup（public化）
  - global_action_buttons.confirm/back/up/down_callback（public化）
  - global_action_buttons.special_callback/special_text（public化）
  - battle_creature_display.original_position（public化）
- ✅ 全規約の網羅的最終確認実施
- ✅ シグナル方向の規約違反確認（306接続、違反0件）
- ✅ 密結合パターンの残存調査完了（上記「残存する密結合パターン」参照）

### セッション7（2026-02-12 続き）
- ✅ board_system委譲タスク3完了: mc/cc/tap系 57箇所置換
  - get_player_tile委譲（15箇所）
  - camera_controller系委譲（18箇所）
  - movement_controller系委譲（24箇所）
  - → 全サブシステムへの外部直接参照ゼロ達成

### セッション8（2026-02-12 続き）
- ✅ board_system委譲タスクA〜E完了: サブシステム直接参照12箇所置換
  - A: tile_info_display → 委譲メソッド経由（5箇所、get_tile_label新規）
  - B: special_tile_system → 委譲メソッド経由（2箇所、get_warp_pairs/get_warp_pair新規）
  - C: battle_system 3段チェーン → 委譲メソッド経由（1箇所、get_battle_screen_manager新規）
  - D: player_tiles → get_player_tile使用（2箇所）
  - E: tile_data_manager → 委譲メソッド経由（2箇所、calculate_toll_with_curse新規）
- ✅ preload定数化: game_system_manager/game_flow_manager/quest_game（循環参照対策）
- ✅ game_flow_manager _update_camera_mode重複コード削除
- 🔧 debug_controller.gd インデントエラー修正（Haiku修正のフォローアップ）

### セッション9（2026-02-13）
- ✅ game_flow_manager内部チェーンアクセス解消 — 直接参照パターン導入
  - **battle_status_overlay**: 5ファイル（TileBattleExecutor, DominioCommandHandler, CPUTurnProcessor, SpellPhaseHandler, SpellCreatureMove）
  - **lap_system**: 15+ファイル（SpellPlayerMove, BattleSpecialEffects, SkillLegacy, BattleSystem, SpellMagic, PlayerStatusDialog, SkillStatModifiers, BattleSkillProcessor, DebugPanel, TutorialManager等）
  - **spell_cost_modifier**: 6ファイル（SpellPhaseHandler, ItemPhaseHandler, TileActionProcessor, TileSummonExecutor, TileBattleExecutor, SpellCostModifier）
  - **player_system**: 3ファイル（TutorialManager, ExplanationMode, SummonConditionChecker）
  - **spell_phase_handler**: 2ファイル（SpellCurse, CPUSpecialTileAI）
  - **その他**: board_system_3d, target_selection_helper, ui_manager, spell_curse_stat, dominio_command_handler
- ✅ GameSystemManager委譲メソッド追加: apply_map_settings_to_lap_system()
- ✅ docs/implementation/delegation_method_catalog.md 更新（全直接参照パターンを網羅）
- ✅ docs/implementation/signal_catalog.md 作成（192シグナル/24カテゴリ）
