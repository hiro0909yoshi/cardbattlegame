# 📅 日次作業ログ

**目的**: チャット間の継続性を保つため、各日の作業内容を簡潔に記録

**ルール**:
- 各作業は1〜3行で簡潔に
- 完了したタスクに ✅
- 次のステップを必ず明記
- 詳細は該当ドキュメントにリンク
- **前日以前のログは削除し、直近の作業のみ記録**
- **⚠️ ログ更新時は必ず残りトークン数を報告すること**

---

## 2026年2月19日（Session: Phase 9 + Phase 10-A + Phase 10-B）

### ✅ バグ修正: ナビゲーションボタン消失 + ドミニオボタンアイテムフェーズ表示

- **ナビゲーションボタン消失バグ**: スペル/アイテムフェーズ中、3Dマップ上のクリーチャータップ後に×ボタンでボタン全消滅
  - 原因: CameraController が tile_tapped → creature_tapped を連続発火、tile_tapped でコールバックがクリアされた空の状態を save_navigation_state() が保存
  - 修正: `navigation_service.gd` の `save_navigation_state()` で全コールバックが空の場合は保存をスキップ
- **ドミニオコマンドボタン誤表示**: アイテムフェーズ開始時に前フェーズのドミニオボタンが残存
  - 修正: `game_system_manager.gd` の `item_selection_ui_show_requested` ハンドラーで `clear_special_button()` を呼び出し
- デバッグログ全削除（navigation_service, global_action_buttons, ui_manager, camera_controller）

### ✅ Phase 9-A: ui_tap_handler is_nav_state_saved() ガード追加

- `_close_info_panel_and_restore()` に `is_nav_state_saved()` チェック追加
- `show_card_info_only()` 経由のパネル閉じ時に `restore_current_phase()` をスキップ
- フォールバック到達ゼロを確認

### ✅ Phase 9-B: restore_current_phase フォールバック5分岐削除

- `restore_current_phase()` を58行→1行に簡素化（`restore_navigation_state()` のみ）
- `spell_phase_handler_ref` を UIManager から完全削除（後方参照1件解消）
- `game_system_manager.gd` の設定行も削除
- **成果**: UIManager から「状態ルーター」責務が消滅、57行削減

### ✅ Phase 10-A: PlayerInfoService サービス化

- `scripts/ui_services/player_info_service.gd` 新規作成（描画更新のみ）
- UIManager に5番目のサービスとして統合（変数・アクセサ・_ready・create_ui）
- 16ファイル・23箇所の `update_player_info_panels()` を `player_info_service.update_panels()` に変更
- BankruptcyHandler Signal接続も PlayerInfoService 経由に変更
- UIManager の `update_player_info_panels()` Facade メソッド削除
- **成果**: UIManagerを経由する最大理由が解消

### ✅ Phase 10-B: card.gd 再帰的親探索廃止

- `find_ui_manager_recursive()` を完全削除（毎マウスイベントでツリー全体を再帰探索するアンチパターン解消）
- Signal 2追加: `card_button_pressed(card_index)`, `card_info_requested(card_data)`
- 3参照変数注入: CardSelectionService, CardSelectionUI, GFM（hand_display が作成時に注入）
- 全13箇所の UIManager 参照を直接参照/Signal emit に置換
- hand_display: Callable コールバックパターンで UIManager を知らないまま Signal 接続
- ui_manager: `_on_card_info_from_hand()` 新メソッド（dialog hide + info panel + dominio button）
- **成果**: card.gd は UIManager を一切知らない最終形を実現

---

## 2026年2月18日（Session: Phase 8 UIManager依存正規化）

### ✅ Phase 8-F: UIManager 内部4サービス分割（前セッション完了分）

- NavigationService（205行）、MessageService（123行）、CardSelectionService（100行）、InfoPanelService（112行）作成
- UIManager 内部で49メソッドをサービス委譲に変換（1,094行 → 998行）
- 14個のナビゲーション状態変数を NavigationService に移動

### ✅ Phase 8-G: ヘルパーファイル サービス直接注入（5/6ファイル完了）

- `target_selection_helper.gd`: ui_manager → MessageService + NavigationService **完全移行** (前セッション)
- `tile_summon_executor.gd`: show_toast/hide_card_selection_ui等 → MessageService + CardSelectionService **部分移行**（10/17参照、前セッション）
- `tile_battle_executor.gd`: show_toast/hide_card_selection_ui → MessageService + CardSelectionService **部分移行**（6/8参照、前セッション）
- `card_selection_handler.gd`: 4サービス注入（MessageService, NavigationService, CardSelectionService, InfoPanelService）
  - MessageService 23箇所、NavigationService 7箇所、CardSelectionService 12箇所、InfoPanelService 5箇所移行
  - _connect_info_panel_signals: InfoPanelService経由 + is_connected()チェック追加
  - **結果**: ~143参照 → 53参照（63%削減）
- `land_action_helper.gd`: handler._message_service等経由（DCH Phase 8-B変数活用）
  - MessageService 16箇所、NavigationService 5箇所、CardSelectionService 2箇所、InfoPanelService 2箇所移行
  - **結果**: ~75参照 → 25参照（67%削減）
- `card_sacrifice_helper.gd`: signal awaitパターンのため保留（12参照、移行リスク高）

### ✅ Phase 8-A: ItemPhaseHandler Signal化（完全完了）

- 4 UI Signal 追加: item_filter_configured, item_filter_cleared, item_hand_display_update_requested, item_selection_ui_show_requested
- `var ui_manager = null` 完全削除、`initialize()` パラメータからも除去
- GameSystemManager に `_connect_item_phase_signals()` 接続メソッド追加
- **結果**: 7/8ハンドラーがUI完全分離、累計37 UI Signals

### ✅ Phase 8-I: タイル系 ui_manager → サービス移行

- `special_tile_system.gd`: `_create_tile_context()` にサービス4種（message_service, navigation_service, card_selection_service, ui_layer）追加
- タイル6ファイル移行:
  - `special_base_tile.gd`: _ui_manager → _message_service **完全移行**
  - `magic_tile.gd`: _ui_manager → _message_service + _ui_layer **完全移行**
  - `magic_stone_tile.gd`: _message_service + _ui_layer 追加（update_player_info_panels 2箇所は _ui_manager 暫定残し）
  - `card_buy_tile.gd`: _message_service + _ui_layer + _card_selection_service 追加（update_player_info_panels 1箇所は暫定残し）
  - `card_give_tile.gd`: _ui_manager → 3サービス **完全移行**
  - `branch_tile.gd`: _ui_manager → _message_service + _navigation_service **完全移行**

### ✅ Phase 8-K: 移動系 ui_manager → サービス移行

- `movement_direction_selector.gd`: ui_manager → _message_service + _navigation_service **完全移行**
- `movement_branch_selector.gd`: 同パターン **完全移行**
- `movement_controller.gd`: `var ui_manager = null` 完全削除、`set_services()` に変更
- `board_system_3d.gd`: `set_movement_controller_ui_manager()` → `set_movement_controller_services()` に変更
- `game_flow_manager.gd`: 呼び出し元を`ui_manager.message_service, ui_manager.navigation_service` に変更

### ✅ Phase 8-B: DominioCommandHandler サービス注入（完全完了）

- initialize()で4サービス解決（MessageService, NavigationService, CardSelectionService, InfoPanelService）
- MessageService移行: show_toast×2, show_action_prompt×5, hide_action_prompt×1, show_comment_and_wait×1
- NavigationService移行: enable_navigation×7, disable_navigation×1, clear_navigation_saved_state×1, clear_back_action×1
- CardSelectionService移行: hide_card_selection_ui×2、InfoPanelService移行: hide_all_info_panels×1
- **結果**: 90参照 → 49参照（46%削減）、8/8ハンドラー移行完了

### ✅ Phase 8-E: 兄弟システム サービス注入（完了）

- tile_action_processor: 34→9 refs (74%削減) - _message_service, _card_selection_service
- special_tile_system: 27→15 refs (44%削減) - _message_service, _navigation_service, _card_selection_service
- board_system_3d: 12→10 refs (17%削減) - _message_service
- battle_system: 4→0 refs (100%削減) - _message_service（ui_manager完全排除）
- GSM: board_system_3d/battle_systemへのサービス注入追加

### ✅ Phase 8-J: Spell系ファイル サービス注入（完了）

- purify_effect_strategy: handler.spell_ui_manager._message_service経由
- basic_draw_handler: 17→10 refs - _message_service, _card_selection_service
- condition_handler: 5→5 refs（構造改善）- _card_selection_service

### ✅ Phase 8-L: 小規模ファイル サービス注入（完了）

- lap_system: 10→11 refs（構造改善）- _message_service
- cpu_turn_processor: 8→6 refs - _message_service, _card_selection_service
- target_ui_helper: 10→9 refs - _get_info_panel_service()静的ヘルパー追加

### 📊 本日の成果

| 指標 | 値 |
|------|-----|
| コミット数 | 9 |
| 新規 Signal | 4（累計 37） |
| ハンドラー UI分離 | 8/8 完了 |
| タイル系ファイル移行 | 6/6 完了 |
| 移動系ファイル移行 | 3/3 完了 |
| UIManager完全削除 | 9/54ファイル |

### ✅ Phase 8-N: STSH + LSH サービス注入（完了）

- spell_target_selection_handler: 28→18 refs (36%削減) - _message_service, _navigation_service
- land_selection_helper: 9→2 refs (78%削減) - handler._message_service, handler._info_panel_service

### ✅ Phase 8-O: spell_mystic_arts + debug_controller サービス注入（完了）

- spell_mystic_arts: 46→29 refs (37%削減) - _get_message_service(), _get_navigation_service(), _get_info_panel_service() ヘルパー
- debug_controller: 31→11 refs (65%削減) - _message_service, _card_selection_service

### ✅ Phase 8-M: CardSelectionService SSoT化（完了）

- CardSelectionUI → CardSelectionService 直接参照に切替（~25箇所）
- hand_display.gd の get_parent() アンチパターン解消
- card_selected シグナルチェーン統一（CardSelectionUI → CardSelectionService 直接接続）
- UIManager の5プロパティを getter/setter 委譲に変換（card_selection_filter, excluded_card_index, excluded_card_id, assist_target_elements, blocked_item_types）
- game_system_manager.gd の card_selected 接続先を CardSelectionService に変更

### ✅ Phase 8-P: Spell系 3段チェーン解消（完了）

- spell_borrow.gd: getter チェーン廃止、set_services() 直接注入
- spell_creature_swap.gd: 4 getter 廃止、set_services() 直接注入
- card_sacrifice_helper.gd: _init を CardSelectionService 受取に変更、_resolve_services() 削除
- tile_summon_executor.gd: ui_manager.card_selection_filter → _card_selection_service
- set_message() バグ呼び出し3箇所を削除（存在しないメソッド）
- **結果**: +73/-116行（43行純減）

### ✅ Phase 8-D2: spell_ui_manager._ui_manager private アクセス解消（完了）

- spell_ui_manager.gd: 5つの public getter 追加（message_service, navigation_service, info_panel_service, tap_target_manager, ui_manager）
- spell_mystic_arts.gd: _get_ui_manager() 廃止 → _get_spell_ui_manager() + 4サービス getter に置換
- target_ui_helper.gd: handler.spell_ui_manager._ui_manager → spell_ui_manager public getter 経由に修正
- purify_effect_strategy.gd: handler.spell_ui_manager._ui_manager → handler.spell_ui_manager.message_service に修正
- **結果**: _ui_manager への外部 private アクセス 0件

### コーディング規約更新

- チェーンアクセス: 2段まで許容（3段以上禁止）に緩和
- 兄弟参照: 表示系・読取り専用は許容（循環・相互依存は禁止）
- ドメイン機能群: battle/dominio の密結合許容（UI操作は分離必須）

### 📊 本日の成果

| 指標 | 値 |
|------|-----|
| コミット数 | 13 |
| 新規 Signal | 4（累計 37） |
| ハンドラー UI分離 | 8/8 完了 |
| タイル系ファイル移行 | 6/6 完了 |
| 移動系ファイル移行 | 3/3 完了 |
| UIManager完全削除 | 9/54ファイル |
| CardSelectionService SSoT化 | ✅ 完了（プロパティ重複解消） |
| _ui_manager 外部 private アクセス | 0件（完全解消） |

### 📋 次のステップ

- Phase 10-C: 双方向参照の削減（10-Bの副産物として部分的に解消済み、再評価予定）
- Phase 10-D: 純粋Facade化（保留、10-A/B完了後に残存ファサードを再評価）
