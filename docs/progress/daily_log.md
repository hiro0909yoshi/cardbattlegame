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

## 2026年3月6日（Session: 密命カード裏面 + StateMachine修正）

### 完了した作業

- カード裏面を2Dシェーダー（card_back_2d.gdshader）で実装、Card.tscnにCardBackOverlayとして統合
- 密命（SkillSecret）キーワードを6枚のスペルカードに追加（spell_1.json: 2004, 2031, 2042, 2050 / spell_2.json: 2082, 2131）
- card.gd に show_secret_back() / show_card_front() 実装（子ノード表示切替方式）
- DebugSettings.disable_secret_cards を false に修正
- StateMachine DICE_ROLL->END_TURN エラー: _completion_id ガード追加（tile_action_processor.gd）、フェーズガードにDICE_ROLL追加（game_flow_manager.gd）

### 次の作業: ドロー演出

ユーザーが希望するドロー演出の仕様:
1. カードが画面外から裏面を見せて飛んでくる
2. 画面中央で表にフリップする
3. クリックで手札に加わる
4. スペルによる複数枚ドローの場合、中央から扇状に広がる
5. 2Dアプローチで実装（Card.tscn + CardBackOverlay を活用）

関連ファイル:
- scenes/Card.tscn（CardBackOverlay ノード追加済み）
- scripts/card.gd（show_secret_back / show_card_front 実装済み）
- assets/shaders/card_back_2d.gdshader（2Dシェーダー追加済み）

---

## 2026年2月20日（Session: Phase 11 全完了 + UIEventHub）

### ✅ Phase 11-A: サブコンポーネント直接アクセスのファサード化

- 6ファサードメソッドを UIManager に追加
- land_action_helper.gd（12箇所）、card_selection_handler.gd（12箇所）の3層チェーンアクセスを解消
- コミット: `11fa6ce`

### ✅ UIEventHub 導入

- `scripts/application/ui_event_hub.gd` 新規作成（3 Signals）
  - `hand_card_tapped(card_index)`, `dominio_cancel_requested()`, `surrender_requested()`
- GSM が所有・ルーティング担当、UIManager/UIGameMenuHandler に注入
- Callable直接注入パターンからEventHub駆動に移行
- 全emit箇所で `if _ui_event_hub:` 防御ガード済み
- コミット: `effba0c`

### ✅ バグ修正（7件）

| コミット | 内容 |
|---------|------|
| `e6283c8` | インフォパネル個別hide→統一hide_all_info_panelsに変更 |
| `b5cba80` | インフォパネル遷移時のナビゲーション状態管理を修正 |
| `97d1c61` | GlobalActionButtons にフレームガード追加 |
| `34af218` | GlobalActionButtons のフレームガード → call_deferredガードに置き換え |
| `7305c94` | スペル/アイテム選択中のカード閲覧→×戻りでナビ状態が壊れる問題を修正 |
| `769d5ac` | 空タップ・パネルキャンセル時のボタン消失問題を修正 |
| `917e5f7` | GDScript警告を全て修正（11件） |

### ✅ Phase 11-B: Node メソッド直接利用の整理

- `ui_manager.create_tween()` → パネルNode経由に変更（ui_win_screen 2箇所）
- `ui_manager.get_tree()` → ui_layer経由に変更（ui_win_screen 1箇所）
- `ui_manager.add_child()` → `ui_manager.ui_layer.add_child()` に統一（4箇所: DCH, spell_mystic_arts, spell_ui_manager, lap_system）
- **成果**: `ui_manager` のNode メソッド直接利用 → 0箇所

### ✅ Phase 11-C: Null チェック統一

- 全 `player_info_service.update_panels()` 呼び出しを調査 → 全箇所で既にガード済み
- 修正不要（Phase 8〜10 で適切に対応済みだった）

### ✅ Phase 11-D: 未使用メソッド削除

- GFM `_on_spell_used()` / `_on_item_used()` を完全削除（UIManager に定義なしのデッドコード）
- GSM のSignal接続（spell_used, item_used → GFM）も削除
- **成果**: ~32行削減

### 📊 本日の成果

| 指標 | 値 |
|------|-----|
| コミット数 | 10（予定） |
| Phase 11 全完了 | 11-A〜D + UIEventHub |
| ファサードメソッド追加 | 6 |
| 3層チェーンアクセス解消 | 24箇所 |
| Node メソッド直接利用解消 | 7箇所 |
| UIEventHub Signals | 3 |
| デッドコード削除 | ~32行 |
| バグ修正 | 7件 |

### 📋 次のステップ

- Phase 11 完了。技術的負債のみ残存（優先度低）
- 次の方向性をユーザーと相談

---

## 2026年2月19日（Session: Phase 9 + Phase 10-A/B/C + バグ修正）

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

### ✅ バグ修正: cpu_defense_ai 初期化不良 + invasion_completed / action_completed 二重発火

- **cpu_defense_ai null**: `item_phase_handler.gd` の `is_class("GameSystemManager")` → `is GameSystemManager` に修正（Godot 4 の is_class() は GDScript class_name 非対応）
- **invasion_completed 二重発火（2件）**:
  - DCH 永続接続削除 → `_execute_move_battle()` で ONE_SHOT 接続に変更
  - GFM `_on_invasion_completed_from_board` から CPUTurnProcessor 通知を削除（DCH が完了処理を一元管理）
- **cpu_action_completed 二重発火**: BoardSystem3D の cpu_action_completed 直接接続を削除（TileActionProcessor 経由の正規パスのみに統一）
- **成果**: `Warning: tile_action_completed ignored` 完全解消

### ✅ Phase 10-C: UIManager 双方向参照の削減

- `dominio_command_handler_ref` 完全削除（UIManager からゲームロジック参照を1つ除去）
- `game_flow_manager_ref` ランタイム使用3箇所 → Callable注入で0箇所に（初期化のみ許容）
- `board_system_ref` ランタイム使用3箇所 → Callable注入で0箇所に（初期化のみ許容）
- 外部チェーンアクセス13箇所 → Callable直接注入で0箇所に
  - CardSelectionHandler: unlock_input×4 + camera×1
  - UIGameMenuHandler: surrender×1
  - UITapHandler: GFM状態チェック×2 + camera×1
- Signal 1追加（`dominio_cancel_requested`）、Callable 11追加
- GSM に `_setup_ui_callbacks()` メソッド新設（一括注入管理）
- **潜在バグ修正**: DominioOrderUI の DCH 参照が初期化順序の問題で null だったのを修正
- **成果**: UIManager のランタイム双方向参照ゼロ、外部チェーンアクセスゼロ達成

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

---

## 2026年2月19日（Session 2: Phase 10-D）

### ✅ Phase 10-D: UIManager デッドコード削除

**削除メソッド（12個、約115行削減）**:

UIManager（7メソッド）:
1. `update_cpu_hand_display()` — 呼び出し元ゼロ
2. `restore_spell_phase_buttons()` — 呼び出し元ゼロ（ラッパー）
3. `set_card_selection_filter()` — 呼び出し元ゼロ（プロパティ直接設定に移行済み）
4. `clear_card_selection_filter()` — 呼び出し元ゼロ（debug_controllerはサービス版を使用）
5. `show_land_selection_mode()` — 呼び出し元ゼロ
6. `show_action_selection_ui()` — 呼び出し元ゼロ（`show_action_menu`ラッパー）
7. `hide_dominio_order_ui()` — 呼び出し元ゼロ

連鎖デッドコード（5メソッド）:
8. `dominio_order_ui.show_land_selection_mode()`
9. `dominio_order_ui.show_action_selection_ui()`
10. `dominio_order_ui.hide_dominio_order_ui()`
11. `navigation_service.restore_spell_phase_buttons()`
12. `card_selection_service.set_card_selection_filter()`

**成果**: UIManager: 1030行 → 965行（65行削減）

### 📋 次のステップ

- Phase 10-E: その他デッドコード調査（小規模メソッド、未使用Signal）
