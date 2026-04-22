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

## 2026年4月22日（Session: ネット対戦 Phase 2 進展 — カメラ/召喚UI/P2反映）

### 完了した作業

#### GUT アドオン null ガード
- ✅ `addons/gut/editor_caret_context_notifier.gd:is_test_script` に null チェック追加
- 原因: スクリプトエディタで .md/.json タブに切替時、`editor_script_changed` が null を emit して
  `is_test_script(null).get_base_script()` で連発エラー（upstream #754）

#### NetConfig autoload 導入（DHCP IP変更対策）
- ✅ `scripts/autoload/net_config.gd` 新規: `user://net_config.json` から IP/port 読込、未存在ならDEFAULT
- ✅ `project.godot` 登録、`ApiClient._base_url` 初期化で参照
- ✅ `net_battle_lobby.gd` トップバーに ⚙ ボタン + サーバー設定ダイアログ追加
- これで iOSビルドを再エクスポートせずとも iPhone 側でIP書き換え可能に

#### ネット対戦 カメラ追従修正
- ✅ `_update_camera_mode` を統一化: active プレイヤーに必ず `focus_camera_on_player_pos` で実移動
  - ネット対戦時は自/相手ターン問わず active の位置に寄せる（これまで mode 設定のみで移動なし）
  - ターン交代時 P1→P2 でも相手プレイヤーにカメラ追従
- ✅ `on_server_action_broadcast` move_complete: 瞬間配置後にカメラを移動プレイヤーへ追従

#### 召喚UIリセットバグ修正（根本原因特定）
- 症状: P1側でタイル着地→手札タップしても on_card_selected が発火せず召喚不可
- 原因: `show_summon_ui` 直後に `turn_start` がフェーズ変更のたびに届き、
  `update_hand_display` が全カード破棄再生成 → card_index=-1 に戻り、
  `on_card_confirmed` の `card_index >= 0` チェックで失敗
- ✅ `NetworkBridge._handle_turn_start/_handle_your_hand`: 手札が変更なしなら UI 再描画スキップ
- ✅ `GSM._on_turn_started`: ネット対戦時は `update_hand_display` 呼出をスキップ
  （NetworkBridge 側が手札管理するため）

#### P2 側での召喚結果反映（Phase 2 未実装分を実装）
- ✅ `on_server_action_broadcast` の `summon` ケース: payload から card_id/tile 取得、
  CardLoader で creature_data 解決、set_tile_owner + place_creature で配置。
  player.magic_power からコスト減算、手札から card_id 検索で remove_card_from_hand。

#### `board_system_3d.current_player_index` 同期
- ✅ `on_server_turn_started` で `board_system_3d.current_player_index = active_slot` も設定
- 原因: これをしないと P2 ターンでも process_tile_landing に player=0 が渡され、
  `_check_lands_required/_cannot_summon` が P1 基準で判定される（0/6 selectable の原因）

#### 診断ログ追加（今後のデバッグ用）
- ✅ `TileAction`: process_tile_landing 呼出、tile情報、is_cpu判定、UI表示結果
- ✅ `CardSel`: enable_card_selection の hand_nodes/selectable 数、on_card_selected、info panel表示
- ✅ `Card`: クリック検知時の mouse_over/selectable/grayed 状態、入力ロック時の無視ログ
- ✅ `HandDisplay`: _on_hand_updated シグナル受信、update_hand_display 呼出
- ✅ `Camera`: _update_camera_mode / on_server_action_broadcast 内の追従呼出

### 動作確認済み
- ✅ P1 (Mac/slot=0) の召喚が成功（カードタップ→インフォパネル→確定→サーバー送信→手札減少/EP減算）
- ✅ P2 (iPhone/slot=1) 画面で P1 の召喚結果が反映（クリーチャー配置・所有権）
- ✅ 両プレイヤー画面でターン交代時にカメラが次の active プレイヤーへ移動

### 未テスト / 次回確認
- ⚠️ P2 自ターンでの召喚（current_player_index 同期修正の検証）
- ⚠️ info panel の確定タップが iPhone touch で意図せず pass になる問題
- ⚠️ action_error メッセージの未ハンドラ警告（`Unknown WS msg type: action_error`）

### 次のステップ
- P2 自ターン召喚の検証（current_player_index 修正の効果確認）
- 他プレイヤーの駒移動アニメ補間（瞬間移動→アニメ化）
- 召喚アニメの他プレイヤー画面再生
- dominio_action ケース実装（レベルアップ連鎖反映）
- バトル発生時の結果送受信（`battle_result_report` 定義）

---

## 2026年4月21日（Session: ネット対戦 GFM連携化 + ターン進行フロー構築）

### 完了した作業

#### GameFlowManager の薄型リレーモード化
- ✅ `is_net_battle: bool` フラグ追加、`net_local_slot` 追加、`net_action_requested` シグナル追加
- ✅ `set_is_net_battle(enabled, local_slot)`, `on_server_turn_started(data)`, `on_server_dice_result(data)`, `on_server_action_broadcast(data)`, `on_server_game_over(data)` API 追加
- ✅ `start_game()`: ネット対戦時は state_machine 初期化のみで change_phase/start_turn をスキップ
- ✅ `start_turn()`: ネット対戦時は turn_started emit 後に即 return（自律動作抑制）
- ✅ `roll_dice()`: ネット対戦時は `net_action_requested.emit("dice_roll")` でサーバー送信
- ✅ `end_turn()`: 現在フェーズに応じて `pass` or `end_turn` をサーバーに送信（PhaseEndTurn検証対応）
- ✅ `is_cpu_player()`: ネット対戦時は全員 false を返す（CPU AI 抑制）
- ✅ `_on_movement_completed_from_board`: 自分のスロットの時だけ `move_complete`（`direction=final_tile`）送信
- ✅ `on_server_turn_started()`: フェーズ別UI起動（`_setup_net_phase_ui`）
  - spell: 暫定 auto-pass
  - dice: 既存ダイスナビゲーション起動
  - tile_action: `process_tile_landing(current_tile)` で既存の召喚UI起動
  - end_turn: end_turn 自動送信
- ✅ `on_server_dice_result()`: 自分のターン時のみ `move_player_3d()` で移動実行、相手ターンは待機
- ✅ `on_server_action_broadcast()`: 他プレイヤーの move_complete 受信時 `place_player_at_tile` で3Dモデル位置更新（瞬間移動、Phase 2でアニメ補間予定）

#### NetworkBridge の全面書き換え
- ✅ 独自UI（`_create_action_overlay`, `_show_action_buttons`）削除
- ✅ `setup()` で GFM に `set_is_net_battle(true, slot)` + `net_action_requested` シグナル接続
- ✅ 受信: `_handle_action_result` で GFM の `on_server_action_broadcast` を呼ぶ
- ✅ `_emit_initial_turn_start_from_state`: meta game_state から初期 turn_start 擬似発火（NetSetup で捨てられる turn_start の代替）

#### サーバー側の薄型化＋フェーズ通知
- ✅ `spell_pass`: 自動 dice_roll を廃止、`broadcastTurnStart()` で phase=dice 通知
- ✅ `dice_roll` ハンドラ追加（クライアントからの明示要求でダイスを振る）
- ✅ `move_complete` 後に `broadcastTurnStart()` で phase=tile_action 通知
- ✅ `pass` 後に `broadcastTurnStart()` で phase=end_turn 通知
- ✅ `summon` 後に `broadcastTurnStart()` 追加
- ✅ `dominio_action` 後に `broadcastTurnStart()` 追加

#### マップ設定同期（create_roomでmap_id未送信問題の修正）
- ✅ サーバー `handleUpdateConfig` メッセージハンドラ追加
- ✅ `Room.UpdateConfigAndBroadcast(patch)` 追加（config更新＋room_state再配信）
- ✅ クライアント `net_battle_setup.gd`: `_on_map_selected` + `_ready` 末尾（ホスト）で `_send_config_update()` を自動送信
- ✅ 動作確認済み: ホストのマップ選択がゲスト側に反映される

#### 召喚のサーバー送信
- ✅ `tile_action_processor.on_card_selected`: 召喚処理時にネット対戦なら `net_action_requested.emit("summon", {"card_id": X})` 送信

### 動作確認済み
- ✅ ゲーム開始 → spell auto-pass → ダイス振るUI表示
- ✅ ダイス振る → ダイス演出 → 駒移動 → タイル着地
- ✅ 分岐のあるマップでの移動方向同期（`direction=final_tile` で伝達）
- ✅ P2側で P1 の駒が最終タイルに表示される（瞬間移動）
- ✅ P1 側で tile_action フェーズ時に既存の召喚UIが出る（process_tile_landing経由）
- ✅ マップ設定の同期

### 未テスト（次回確認）
- ⚠️ **召喚実行→サーバー送信→ターンエンドのフル動作**（session.go の summon 処理＋`broadcastTurnStart` 追加後の実機テストは未完了）
- ⚠️ **パスボタン→ターンエンドのフル動作**（`pass→end_turn` 2段階送信への修正後の実機テストは未完了）
- ⚠️ P2側での召喚結果反映（`on_server_action_broadcast` の `summon` ケースはPhase2未実装）
- ⚠️ 相手のターン時の駒移動アニメーション（現状は瞬間移動）

### 次のステップ
- 召喚→ターンエンドのフル動作確認（サーバー／クライアント両方再起動してテスト）
- P2側での召喚結果反映（action_result broadcast の summon ケース実装）
- 他プレイヤーの駒移動アニメ補間（瞬間移動→アニメに置き換え）
- UI調整: ネット対戦準備画面のマッププレビュー位置（TaskCreate #16 として記録済み）

---

## 2026年4月20日（Session: ネット対戦 薄型リレー化 + 手札表示 + デッキDB保存）

### 完了した作業

#### Phase 0: 設計方針の再整理
- ✅ `docs/design/network_design.md` §0 に「薄型リレー+要所検証モデル」を明文化（旧サーバー権威モデルは参考情報として残存）
- ✅ backend_design.md §案B（リレーサーバー+要所検証）に準拠する方針に確定

#### 手札表示・同期修正
- ✅ `NetworkBridge._apply_game_state`: `{"state": {...}}` ネストを正しく unwrap し、`players[active_player].hand` を抽出
- ✅ `_clear_opponent_hands()` 削除 → `_clear_all_local_hands()` に変更（ローカル乱数手札全クリア → サーバー配信を信頼）
- ✅ `turn_start` / `game_state` どちらでも active_player の手札を `update_hand_display(active_player_slot)` で両プレイヤー画面に表示（カルドセプト方式）

#### デッキサーバー保存フロー
- ✅ `ApiClient.save_deck(access_token, slot_index, deck_name, cards)` 追加（PUT /api/player/decks）
- ✅ `net_battle_lobby.gd`: 認証成功直後に `_upload_current_deck()` → GameData.get_current_deck() を `{card_id: count}` → `[id, id, ...]` 配列変換して送信
- ✅ DB未保存ユーザーでもネット対戦開始時にデッキが配布される

#### 手札枚数の config 化（InitialCards）
- ✅ `RoomConfig.InitialCards` 追加、`handleCreateRoom` にバリデーション（1〜10、デフォルト5）
- ✅ `Session.Start()` にゲーム開始時1枚ドロー追加（クライアント `start_turn()` の1枚ドローと対称）→ 5+1=6枚でローカル対戦と一致
- ✅ `net_battle_lobby.gd` の `create_room` ペイロードに `initial_cards: GameConstants.INITIAL_HAND_SIZE` を含める

#### Phase 1: サーバー薄型化
- ✅ `state.go:TransitionAfterLanding` を常に PhaseTileAction に遷移（バトルフェーズ発生なし）
- ✅ `session.go` の PhaseBattle ハンドラ削除、`battle_item` は deprecated エラー返却
- ✅ `action.go:Summon` からHP初期化・奮闘判定・タイル状態設定削除（検証+手札消費+Phase遷移のみ）
- ✅ `action.go:levelUp/moveCreature/swapCreature` から計算・状態変更削除（検証のみ）
- ✅ `battle.go:ResolveBattle` 等は dead code 化（将来クライアント結果受信時に再利用可能性があるため残存）
- ✅ `ws/room.go`: `RoomConfig.MapTiles` 追加、タイル自動生成ハードコード（`tileCount:=20`, elements配列）削除、`UpdateConfig()` メソッド追加
- ✅ `ws/hub.go:handleStartGame(c, data)` に変更、ホストからの config patch を受信
- ✅ `net_battle_setup.gd:_on_start_game_pressed` で選択マップの JSON を読み込み、タイル属性配列を `start_game` メッセージに含める

### 決定事項
- サーバーは「リレー+検証」のみ、ゲームロジックはクライアント（GDScript）が権威
- 永続データ（gold/gem/user_cards/decks/レート）は引き続きサーバーDB権威（変更なし）
- 計算結果不一致時はターン保持者（アクション実行者）を楽観採用

### 次のステップ（Phase 2 未着手）
- クライアント→サーバーの結果報告メッセージ定義・実装
  - `battle_result_report`, `action_result_report`, `spell_result_report`
- NetworkBridge の送信フック追加（BattleSystem / DominioCommandHandler 等の完了シグナル受信時）
- サーバー側 session.go に受信ハンドラ実装、GameState 上書き
- `viewer_id = 0` ハードコード問題の修正（player_status_dialog.gd:197）

---

