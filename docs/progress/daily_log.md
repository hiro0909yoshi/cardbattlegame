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

## 2026年4月8-9日（Session: ゲーム中ステートセーブ/復帰機能実装）

### 完了した作業

#### ゲーム中ステートセーブ/復帰システム
- ✅ `scripts/save_data/game_state_saver.gd` 新規作成 — セーブ/復元の中核（build_save_data, apply_save_data, tmp→renameアトミック書き込み）
- ✅ `scripts/game_data.gd` — `in_game` フラグ追加（クラッシュ検知用）
- ✅ `scripts/game_flow_manager.gd` — `start_game()` で in_game=true、`start_turn()` 冒頭でセーブ、`restore_game()` 復帰メソッド追加、`current_stage_id` / `current_game_mode` 追加
- ✅ `scripts/game_flow/game_result_handler.gd` — 勝利/敗北時にセーブクリア + in_game=false
- ✅ `scripts/system_manager/game_system_manager.gd` — `restore_game()` 委譲メソッド追加
- ✅ `scripts/game_3d.gd` / `scripts/quest/quest_game.gd` — `restore_game` メタチェックで復帰フロー分岐
- ✅ `scripts/main_menu.gd` — クラッシュ復帰ダイアログ表示（game_modeベースでシーン判定）

#### 5段階セーブポイント拡張（2026-04-09）
- ✅ `save_phase` フィールド追加 — progress内に保存、復帰時のフェーズスキップ制御に使用
- ✅ Save①`turn_start` — ターン開始時（既存）
- ✅ Save②`after_dice` — ダイス確定後（`_on_dice_confirmed` コールバック）
- ✅ Save③`after_movement` — 移動完了後（`_on_movement_completed_from_board`）
- ✅ Save④`after_tile_action` — タイルアクション完了後（`_on_tile_action_completed_3d`）
- ✅ Save⑤`after_battle` — バトル結果確定後（`_on_invasion_completed_from_board`、バトル画面クラッシュループ防止）
- ✅ 復帰時 `_restore_phase` によるフェーズ別スキップ（start_turn内で分岐）
- ✅ 復帰モード時のダイス結果リセット/セーブスキップ修正

#### バグ修正（実装中に発見）
- ✅ 駒位置: `player_system.current_tile` ではなく `board_system_3d.get_player_tile()` から取得するよう修正（movement_controller管理のため）
- ✅ シーン遷移: stage_id推測ではなく `game_mode` フィールドで明示的にクエスト/ソロを判定
- ✅ セーブファイル破損対策: tmp→rename方式に変更
- ✅ 復帰後UI更新: `hand_updated.emit()` + `_ui_update_panels_cb` 呼び出し追加
- ✅ `start_turn()` 復帰時のダイス結果リセットバグ修正（`_restore_phase` チェックで回避）

#### iOS GPU フリーズ対策
- ✅ `scripts/ui_manager.gd` — `show_card_info()` にフレーム分散（`await process_frame`）追加
- ✅ `.gitignore` — `ios_build/` 追加（libgodot.a 100MB+防止）

### 次のステップ
- 復帰後の3Dクリーチャーカード表示の再描画確認
- SubViewport生成抑制（iPhone SE安定化）
- PvP実装時にネットワーク同期フィールド追加

---

## 2026年4月2日（Session 1: 城壁GLBベイク完了 + モバイル適用 + iOS開発環境構築）

### 完了した作業

#### Blender城壁GLBベイク（モバイル用）
- ✅ MAP_HALF_SIZE=35基準で城壁全体をBlenderで再構築（half_n=48, half_s=57）
- ✅ 胸壁をGDScript仕様に合致（レンガ本体 depth=WALL_THICKNESS+0.3 + サンドストーンキャップ 0.1）
- ✅ 扉をgate_door.glbから新規インポートして再構築（テクスチャ修正）
- ✅ 胸壁900面のマテリアル未割当（None）→ Brickマテリアルに修正
- ✅ 北南方向修正（Blender Y軸180°回転でGodot座標系と一致）
- ✅ 屋根テクスチャ=赤茶色、塔=暗色、床=cube_size=6.0（引き伸ばし）
- ✅ アーチフレーム追加（radius=5.0）

#### GLB最適化
- ✅ gltf-transform: テクスチャリサイズ（1024px）+ WebP圧縮 → 11.2MB → **2.8MB**
- ⚠️ Draco圧縮はGodot 4.5で読み込み不可（`Failed loading resource`）→ 不使用
- ⚠️ WebP圧縮後に`.import`ファイルの`valid=false`問題 → `.import`ファイル削除+エディタ再起動で解決

#### OS分岐適用
- ✅ castle_environment.gd — `if true:` → `OS.has_feature("android")` に変更
  - Android: GLB版（2.8MB、壁・塔・門・アーチ・胸壁・床を含む）
  - PC: プロシージャル版（フル城+蔦+草）

#### iOS開発環境構築
- ✅ Xcode 16.3インストール済み（Command Line Tools含む）
- ✅ Apple Developer無料アカウント設定（Team ID: SQ8HJZALD6、Personal Team）
- ✅ Godot iOS エクスポートプリセット作成（Bundle: com.katsurastudio.arcanaconquest）
- ✅ Godotから「Export Project Only」でXcodeプロジェクト生成（`ios_build/arcana_conquest/`）
- ✅ Xcodeビルド成功（シミュレータターゲット）
- ✅ EXCLUDED_ARCHS設定修正: `[sdk=*]` → `[sdk=iphonesimulator*]`（Apple Silicon対応）
- ⚠️ 実機接続未完了: USB-A to Lightningケーブルがデータ転送非対応の可能性 → USB-C to Lightningケーブルを別途用意

#### iOS無料プロビジョニング制約
- 証明書は7日で期限切れ（再署名で対応可能）
- TestFlightは使用不可（Apple Developer Program $99/年 が必要）
- App IDは10個まで/7日間

### 既知の問題
- PC版プロシージャル城の扉が表示されない（以前からの可能性あり、要調査）
- iPhone実機テスト未完了（データ転送対応ケーブル待ち）

### 次のステップ
- USB-C to Lightningケーブル入手後、iPhone実機テスト
- iPhoneのデベロッパモード有効化
- デバッグprint文の削除
- Android実機でのFPS再計測（GLB城壁の効果確認）

---

## 2026年4月1日（Session 1: Android最適化クリーンアップ + PC/Android分岐）

### 完了した作業

#### テストフラグ修正・OS分岐化
- ✅ debug_settings.gd — `disable_all_process = true` → `false` に戻し（タイル点滅・ターゲット回転が停止していた原因）
- ✅ quest_game.gd — `if true:` テストフラグ → `OS.has_feature("android")` に変更
  - Android: `scaling_3d_scale = 0.6`、影オフ、単色背景、環境光COLOR 0.6
  - PC: 元の設定復元（ProceduralSky カスタム色、影オン+max_distance=60、AMBIENT_SOURCE_SKY 0.4）
- ✅ castle_environment.gd — `OS.has_feature("android")` で城の分岐
  - Android: 壁4枚+単色地面（軽量版）
  - PC: フル版（塔・胸壁・門・蔦・草）

#### 松明コード削除
- ✅ castle_environment.gd — 松明関連を全削除（変数3つ、`_process()`、`_create_torches()`、`_create_single_torch()`）
- ✅ OmniLight3Dが全廃、ゲーム画面のライトはSunLight（DirectionalLight3D）1つのみに

#### project.godot 修正
- ✅ ビューポート移行設定を再適用（1920×1080、canvas_items、expand）
- ✅ レンダラーは `forward_plus` を維持（⚠️ `gl_compatibility` にすると地面が白飛びする）
- ✅ `scaling_3d/scale=0.5` を削除（Android分岐でコード側制御に移行）

#### レッドゴブリン修正
- ✅ quest_game.gd `_share_material()` — ShaderMaterialが既に設定済みのサーフェスはスキップ（red_tint.gdのシェーダーが上書きされていた問題）

#### インフォパネル位置調整
- ✅ creature_info_panel_ui.gd / spell_info_panel_ui.gd / item_info_panel_ui.gd — ゲーム画面のパネル位置を+40px右に移動（135→175）。プレイヤーインフォパネル拡大に伴う重なり回避。アルバム側は影響なし

### 未完了（次回）
- デバッグprint文の削除

---

## 2026年3月31日（Session 3: Androidパフォーマンス最適化）

### 完了した作業

#### ボトルネック特定
- ✅ fillrate が主因と確定（`scaling_3d_scale=0.45` で 9→40 FPS）
- ✅ 城背景が二番目の原因（消すと +10-15 FPS）
- ✅ 影が三番目（`shadow_enabled=false` で +5 FPS）
- ✅ ProceduralSky、キャラ、タイル、CPU _process() は原因ではないと確定

#### マップ画面最適化（9→~40 FPS）
- ✅ quest_game.gd — `scaling_3d_scale = 0.45`（モバイル用3D解像度削減）
- ✅ castle_environment.gd — モバイル軽量城（壁4枚+単色BoxMesh地面）
- ✅ quest_game.gd — `shadow_enabled = false`、ProceduralSky → 単色背景

#### バトル画面最適化（23→~51 FPS）
- ✅ battle_screen_manager.gd — バトル中に裏の3Dノードを非表示（`_set_3d_scene_visible`）
- ✅ battle_creature_display.gd — CardTextureCacheから軽量モード適用（47子ノード→テクスチャ1枚）
- ⚠️ CanvasLayer非表示はゲーム進行を止めるためNode3Dのみ対象

#### セットアップ画面最適化
- ✅ solo_battle_setup.gd — SubViewport UPDATE_ALWAYS → UPDATE_ONCE
- ✅ net_battle_setup.gd — 同上
- ✅ 戻るボタン拡大（93x42 → 240x70、フォント22→32）

### 未完了（次回）
- `if true:` テストフラグ → `OS.has_feature("android")` に変更
- PC版設定復元（ProceduralSky、フル城、影オン）
- `disable_all_process = true` → `false` に戻す
- デバッグprint文の削除

---

## 2026年3月31日（Session 2: UI統一 - グローバルコメント・インフォパネル・チュートリアル）

### 完了した作業

#### グローバルコメントUI改善
- ✅ global_comment_ui.gd — BBCodeカラータグ除去（白背景に黒文字統一）
- ✅ 「クリックで次へ」→「click >>>」に変更、色を`#555555`に
- ✅ コメント下の空行除去（`\n\n` → `\n`）

#### BBCodeカラータグ除去（コメント表示箇所）
- ✅ spell_cast_notification_ui.gd — yellow除去
- ✅ lap_system.gd — yellow, cyan, lime除去
- ✅ spell_magic.gd — yellow除去（4箇所）
- ✅ branch_tile.gd — yellow除去

#### アイテム/スペルインフォパネル: ゲーム画面レイアウト統一
- ✅ item_info_panel_ui.gd — `_apply_game_layout()` 追加（クリーチャーパネルと同じ位置・サイズに統一）
- ✅ spell_info_panel_ui.gd — 同様に`_apply_game_layout()` 追加

#### チュートリアルUI修正
- ✅ tutorial_popup.gd — フォントサイズ 100→60px（グローバルコメントと統一）
- ✅ tutorial_popup.gd — 「タップで次へ」→「click >>>」(36px, #555555)
- ✅ tutorial_overlay.gd — ハイライト定数をGlobalActionButtonsと統一（SIZE 280→175, SPACING 42→27, MARGIN 70→44）

#### グローバルFPS表示
- ✅ debug_settings.gd — 全シーン共通FPS表示追加（Autoload、左上、show_fpsフラグで切替）

#### Android実機パフォーマンス調査（Huawei Mate 20）
- ❌ レンダラー `mobile` に変更 → 改善なし
- ❌ ビューポート 1920×1080 → 1280×720 → 改善なし
- → DRAW 240 / OBJ 131で5-8FPS。GPU負荷ではなくCPU（GDScript処理）が原因の可能性大
- → レンダラーは `forward_plus` に戻し済み、解像度も `1920×1080` に戻し済み

### 次のステップ
- **Android性能**: 全画面FPS表示で各シーンのFPS計測 → タイトル画面でも低いならCPU全体、マップだけならゲーム画面固有
- Step 2残り: game_menu.gd, debug_panel.gd, level_up_ui.gd, surrender_dialog.gd, magic_tile_ui.gd, base_tile_ui.gd, card_buy_ui.gd, card_give_ui.gd
- Step 3: バトル画面
- Step 5残り: special_tile_info_dialog, map_preview_dialog, result_screen

---

## 2026年3月31日（Session 1: ビューポート移行 - インフォパネル・プレイヤーステータス）

### 完了した作業

#### インフォパネル3種: 名前固定+スクロール化
- ✅ creature_info_panel.tscn — OuterVBox挿入: NameContainer+スペーサーをScrollContainer外に固定配置
- ✅ spell_info_panel.tscn — 同様のOuterVBox構造に変更
- ✅ item_info_panel.tscn — 同様のOuterVBox構造に変更
- ✅ 3つのUI GDScript（creature/spell/item_info_panel_ui.gd）— @onreadyパス更新（OuterVBox挿入に対応）

#### プレイヤーステータスダイアログ（player_status_dialog）
- ✅ player_status_dialog.tscn — MainPanel 1691×1129→1000×680に縮小、画面中央配置
- ✅ BackgroundRect offset除去（画面全体を隙間なく覆うように）
- ✅ ParchmentBg/ContentMargin左右対称化、位置微調整
- ✅ フォント縮小: Title 60→38、StatusLabel 40/44→32/35、手札 55→38
- ✅ player_status_dialog.gd — 手札font_size 55→38

### 次のステップ
- Step 2残り: game_menu.gd, debug_panel.gd, level_up_ui.gd, surrender_dialog.gd, magic_tile_ui.gd, base_tile_ui.gd, card_buy_ui.gd, card_give_ui.gd
- Step 3: バトル画面
- Step 5残り: special_tile_info_dialog, map_preview_dialog, result_screen
- Step 6: チュートリアル

---

## 2026年3月30日（Session 3: ビューポート移行 - ゲーム画面・ステータス・クエスト）

### 完了した作業

#### Step 4（追加）: ソロバトル・ネット対戦画面
- ✅ solo_battle_setup.gd — 全フォント・サイズ比率変換、対戦開始ボタン350×80/font36
- ✅ ルール設定拡大（ラベル34、スピンボタン44、矢印26）
- ✅ CPU枠をHBoxContainer/slot方式に再構造化（ネット対戦と統一、行ずれ解消）
- ✅ マップ選択をダイヤルボックス形式（ScrollContainer+スワイプ、ボタン60px/font30）に変更
- ✅ net_battle_setup.gd — 同様の比率変換＋右パネル拡大＋対戦ボタン拡大

#### Step 4（追加）: ステータス画面
- ✅ StatusScreen.tscn — TopBar 42px、CharacterPreview 310×362、全フォント拡大調整
- ✅ status_screen.gd — ダイアログサイズ変換、ボタン高さ55/65、VBox separation 18
- ✅ character_preview.gd — SubViewport 276×310

#### Step 4（追加）: クエスト画面
- ✅ WorldStageSelect.tscn — マージン21、DetailPanel内ScrollContainer挿入
- ✅ world_stage_select.gd — STAGE_BUTTON_SIZE 85、ワールドボタン155×42/font17
- ✅ ブック選択: 固定高さ→SIZE_EXPAND_FILL（切れ防止）、ブックボタン207×78

#### Step 2（一部）: メインゲーム画面
- ✅ global_action_buttons.gd — BUTTON_SIZE 280→145、フォント100→52/120→62、マージン・ボーダー全変換
- ✅ player_info_panel.gd — 75%縮小（panel 195×143、font 21、spacing 11）
- ✅ phase_display.gd — アクション指示をCenterContainer方式に変更（手動配置→自動中央配置）
- ✅ FONT_SIZE_ACTION_PROMPT — 33→40に拡大（ユーザー指示）
- ✅ card.gd — GAME_CARD_WIDTH 290→150、GAME_CARD_HEIGHT 390→202
- ✅ hand_display.gd — CARD_WIDTH 150、CARD_HEIGHT 200、CARD_SPACING 20、viewport size取得をcontent_scale_size対応
- ✅ card_ui_helper.gd — 定数をhand_displayに統一（150×200、BASE_SCALE=1.0）
- ✅ card_texture_cache.gd — レンダリングサイズを220×293に戻す（CardFrame設計サイズで高品質維持）

### 次のステップ
- Step 2残り: game_menu.gd, debug_panel.gd, level_up_ui.gd, surrender_dialog.gd, dominio_order_ui.gd, magic_tile_ui.gd, base_tile_ui.gd, card_buy_ui.gd, card_give_ui.gd
- Step 3: バトル画面（battle_status_overlay.gd, card.gd battle view, ui_win_screen.gd）
- Step 5残り: special_tile_info_dialog, map_preview_dialog, result_screen, player_status_dialog
- Step 6: チュートリアル

---

## 2026年3月30日（Session 2: ビューポート移行 - アルバム・デッキエディタ・インフォパネル）

### 完了した作業

#### Step 4（一部）: Album画面のビューポート移行
- ✅ Album.tscn — ボタン高さ400→268、VBox separation 29→19、GridContainer h_sep 100→67 / v_sep 20→13
- ✅ album.gd — ステータスパネル660×240 SIZE_EXPAND_FILL、カードサムネイル161×235（画像160×160）、10列グリッド
- ✅ ブック選択 — ダイヤルボックス形式（1列ScrollContainer + スワイプ入力対応）に変更、将来のブック数増加に対応

#### Step 4（一部）: DeckEditor画面のビューポート移行
- ✅ DeckEditor.tscn — タブボタン高さ85・フォント22、右パネルアンカーベースレイアウト化、Spacer+底部ボタン配置
- ✅ deck_editor.gd — カード263×420（画像190×190・フォント24）、枚数ボタン80×70、カードタイプカウントBBCode font_size=50
- ✅ InfoPanelContainer — offset_left=200, offset_right=-15 でカード表示と重複解消

#### Step 5（一部）: インフォパネル3種のビューポート移行
- ✅ creature/item/spell_info_panel.tscn — フォントサイズ統一（Name=48, Rarity=36, Headers=28, Content=48）
- ✅ 位置調整 — ContentMargin offset 55/120/500/520、ParchmentBg offset -70/70/450/530
- ✅ テキストはみ出し対策 — ContentMargin内にScrollContainer挿入（全3パネル＋スクリプトパス更新）

---

## 2026年3月30日（Session 1: レンダリング最適化実施）

### 完了した作業

#### レンダリング最適化（OBJ: 2204→490, DRAW: 942→310）
- ✅ 城壁MultiMesh化 — 296個のMeshInstance3D → 4個のMultiMeshInstance3D
- ✅ 床タイルMultiMesh化 — 個別instantiation → MultiMeshInstance3D 1個（影破綻も解消）
- ✅ CardTextureCache新規作成 — Card.tscnをSubViewportでオフスクリーンレンダリング→ImageTexture化
- ✅ creature_card_3d_quad.gd — 内蔵SubViewport廃止、CardTextureCache使用に変更
- ✅ card.gd 軽量モード — `enable_lightweight_mode()` 追加、47子ノードを停止+TextureRect 1枚で描画
- ✅ hand_display.gd — キャッシュテクスチャ取得→軽量モード自動適用
- ✅ 密命カード対応（show_secret_back/show_card_front の軽量モード分岐）

#### デバッグ・計測
- ✅ quest_game.gd にFPSカウンター移設（game_3d.gdから。CanvasLayer layer=100、画面中央、font_size=96）

#### 失敗・リバート
- ❌ CardHandView方式（card.gd代替クラス）→ 入力処理の複雑さでフリーズ発生、方針転換

### 次のステップ
- Huawei Mate 20 Lite 実機でFPS計測（APKインストール）
- 実機結果に基づきビューポート移行の要否判断

---

## 2026年3月29日（Session: Androidパフォーマンス最適化）

### 完了した作業

#### モバイル最適化
- ✅ ワープタイル（warp_tile, warp_stop_tile）パーティクル数 12→6、_process 2フレームスキップ
- ✅ BaseTile ブリンク処理 3フレームスキップ
- ✅ brick_wall.gdshader 大幅簡略化（fbm削除、トライプラナー3→2方向、法線バンプ削除）
- ✅ castle_environment 草パッチ 120→30、モバイルでは城環境ごと無効化
- ✅ Tweenリーク修正（target_marker_system, lap_system）

#### デバッグ・計測
- ✅ game_3d.gd にFPSカウンター追加（画面表示 + logcat出力、1秒間隔）
- ✅ android_export_guide.md にUSB実機デバッグ手順・パフォーマンス判断基準を追記

#### Git
- ✅ .gitignore に `android/build/` 追加（100MB+ビルド成果物除外）

---

## 2026年3月26日（Session: タイトル画面 + プレイヤーデータ整備）

### 完了した作業

#### タイトル画面
- ✅ `TitleScreen.tscn` / `title_screen.gd` 新規作成 — ロゴ + Tap to Start + バージョン表記
- ✅ 初回起動時に名前入力ダイアログ表示（`has_initialized`フラグで判定）
- ✅ project.godot 起動シーンをTitleScreenに変更

#### UUID自動生成
- ✅ GameData._ensure_user_id() — 起動時にUUID v4を即生成+保存（UI無関係）
- ✅ UserCardDB.update_user_id() — UUID確定直後にDBのuser_idも統一
- ✅ `has_initialized`フラグ導入（IDと状態の分離）

#### セーブデータリセット機能
- ✅ 設定画面に赤い「セーブデータリセット」ボタン追加（プレイヤー名入力で誤操作防止）
- ✅ GameData.reset_all_data() — 全データ初期化+UUID再生成+UnlockManager再同期
- ✅ リセット後はタイトル画面に遷移（名前入力からやり直し）

#### 名前変更チケット
- ✅ ステータス画面に名前変更ボタン（チケット消費で変更、初回1枚付与）

#### 称号システム
- ✅ GameDataにequipped_title + TITLESマスターデータ(6種)追加
- ✅ ステータス画面に称号変更ダイアログ（解放済み選択/未解放ロック表示）
- ✅ メイン画面・ステータス画面のハードコード称号をデータ駆動に変更

#### ネット対戦修正
- ✅ 自分のキャラ表示をGameData.get_selected_character_model_path()から取得

#### ドキュメント
- ✅ player_account_design.md — 初回起動フロー設計追加、データ構造を現状に更新
- ✅ default_save.json — 現行データ構造に完全整備

### feature/player-system → main マージ済み

### 未対応（後回し）
- 未設定キャラの解放条件: clown, old_sage, witch, golem, elf
- ネット対戦のキャラ選択UI
- 名前変更チケットの追加入手経路
- タイトル画面の動作確認（次セッション）

### 次のステップ
- タイトル画面の動作確認・調整
- feature/title-screen → main マージ
- バックエンド設計・実装（ネットワーク対戦の前提）

---

## 2026年3月25日（Session: 統一アンロックシステム実装）

### 完了した作業

#### UnlockManager実装
- ✅ `scripts/autoload/unlock_manager.gd` 新規作成 — キーベース・イベント駆動の統一アンロック管理
- ✅ `data/master/unlock_conditions.json` 新規作成 — 12条件（always/stage_clear/purchase）
- ✅ project.godot にAutoload登録

#### 既存システム移行
- ✅ `game_data.gd`: character.unlocked廃止 → unlocks.keys移行 + _validate_save_dataマイグレーション
- ✅ `gacha_system.gd`: UNLOCK_CONDITIONS廃止 → UnlockManager委譲
- ✅ `shop.gd`: ガチャボタンのロック表示をUnlockManager対応
- ✅ `world_stage_select.gd`: ワールド解放をUnlockManager対応
- ✅ `game_result_handler.gd`: 勝敗時にUnlockManager通知追加
- ✅ `result_screen.gd`: 統一アンロック通知表示

#### マップ・キャラフィルタ
- ✅ ソロバトル/ネット対戦/設定マッププレビュー — 解放済みマップのみ表示
- ✅ ソロバトルキャラ選択 — 解放済みキャラのみ表示
- ✅ ステータス画面 — 所持マップ数表示追加、キャラ変更ダイアログのロック表示

#### キャラクターデータ整備
- ✅ characters.json にプレイアブルキャラ5体（hero, undead_monk, elf, fighter, necromancer）をCPU対戦相手として追加
- ✅ undead_monk表示名を「クレリック」に変更（game_data/characters.json/unlock_conditions）

### 未対応（後回し）
- 未設定キャラの解放条件: clown, old_sage, witch, golem, elf
- ネット対戦のキャラ選択UI（そもそも未実装）
- セーブデータリセット機能（次タスク）

---

## 2026年3月25日（Session: キャラクター3Dプレビュー）

### 完了した作業

#### キャラクター3Dプレビュー表示
- ✅ `character_preview.gd` 作成 — SubViewport + Camera3Dで3Dモデルを2D UIに静止画表示
- ✅ MainMenu / StatusScreen の TextureRect → SubViewportContainer に置換
- ✅ モバイル負荷対策: UPDATE_DISABLED + 数フレームだけ描画してキャプチャ
- ✅ メイン画面に仮グラデーション背景追加（透過確認済み）

---

## 2026年3月25日（Session: プレイヤーアカウント設計）

### 完了した作業

#### CPU AIポリシー統一
- ✅ `game_flow_manager.gd` に `_apply_default_cpu_policy()` 追加（切断時balancedポリシー自動適用）
- ✅ `network_design.md` に実装済み基盤の記載追加

#### プレイヤーアカウント設計（`docs/design/player_account_design.md`）
- ✅ プレイヤーデータ3層分類（Core/Sub/Local）
- ✅ アカウント認証設計（ゲスト→登録フロー、DB 7テーブル、API設計）
- ✅ 外部フィードバック5項目適用:
  - 楽観ロック（versionフィールド）
  - match_history肥大化対策（100件制限+ページング）
  - 一括同期方針（bulk save + 通貨操作のみ個別API）
  - JWTデュアルトークン（access 30分 + refresh 14日）
  - device_id利用ルール（識別専用、認証に使わない）
- ✅ セキュリティ詳細追加:
  - ログイン時トークン発行フロー（5ステップ）
  - APIリクエスト検証フロー
  - 不正状態ハンドリング（5ケース対応表 + クライアント401処理）
  - 1端末同時ログインポリシー
  - 将来拡張性（複数端末・セッション一覧・強制ログアウト）

#### キャラクター選択・カスタマイズ設計
- ✅ 解放方式3種（初期/クエストクリア/購入）
- ✅ マスターデータ拡張方針（characters.jsonにplayable_characters追加）
- ✅ GameData拡張（character.selected_id + character.unlocked）
- ✅ backend_design.mdの既存テーブル（user_unlocked_characters）と統合
- ✅ 全16体の3Dモデル一覧記録

### 次のステップ
- サーバー実装（Go リレーサーバー + 認証API）
- クライアント実装（AuthManager, DataSyncManager）
- GameData リファクタ（core/sub/local 分離）
- キャラクター選択UI実装

#### バグ修正: skill_conditions内のuser_rarity条件が付与時チェックされない
- ✅ 原因: `battle_item_applier._apply_grant_skill()` が `condition`（辞書）のみチェックし `skill_conditions`（配列）を無視
- ✅ 修正: `user_rarity` 条件を付与時にチェックするロジック追加（他の条件は発動時チェックのため除外）
- ✅ 全222テスト、1276アサート全パス

#### Phase 2後半: 残りアイテムテスト完了（195テスト、877アサート全パス）
- ✅ トールカーサー(124): on_battle_end刻印がサイレントローブで防げないことを検証
- ✅ コピースパイク(1036): 変質（forced_copy_attacker）肯定・否定・敵生存テスト
- ✅ グランドハンマー(1012): 蓄魔[200EP] 肯定・否定テスト
- ✅ デスペラード(1048): on_death即死 肯定・否定テスト
- ✅ バーニングコア(1044): on_death報復MHP-40 肯定・否定テスト
- ✅ フォートレスブレイカー(1051): 即死[堅守] vs 堅守/重結界刻印/非堅守テスト
- ✅ バグ修正: `battle_special_effects.gd` 即死[堅守]条件が刻印`defensive_form`を未チェック → 追加
- ✅ バトル効果検出リファクタ: `_snapshot_battle_state()`/`_diff_battle_state()`でEP/刻印/変質/APドレインを状態差分検出（本番コード汚染なし）
- ✅ `BattleTestResult`に`attacker_battle_effects`/`defender_battle_effects`追加

#### ディスペルオーブ(1004): 沈黙テスト網羅（23テスト追加）
- ✅ 全22スキル持ちクリーチャーの無効化テスト（先制/強化/共鳴/2回攻撃/再生/反射/反射[1/2]/相討/変身/アイテム破壊/アイテム盗み/吸魔/蓄魔/即死/刺突/術攻撃/加勢/強化術/強化/形見/蘇生）
- ✅ 攻撃側/防御側の適切な配置: 後手・鼓舞は攻撃側スキル持ち+防御側ディスペル
- ✅ 鼓舞テスト: ボード上のアークデーモンから戦闘クリーチャーへのボーナス阻止を検証
- ✅ 共鳴テスト: 地タイル追加で共鳴環境を整備した上で無効化を検証
- ✅ 沈黙相互作用: カースウィップ(1050)のstat_bonus(AP+30)は残り、刻印[消沈]は無効化されることを検証

#### Phase 3k: 刺突テスト（8テスト追加、323テスト全パス）
- ✅ 無条件刺突（ナイトメア334）: land_bonus無効化確認
- ✅ 条件付き刺突（レイドワイバーン36, 敵AP≧40）: 発動/不発/蓄魔[100EP]検出
- ✅ 防御側の刺突は無効: land_bonus維持の証拠
- ✅ 属性条件刺突（インフェルノイーグル38, 水風）: 発動（+強化+先制複合）/ 不発
- ✅ 蓄魔は侵略側のみ: レイドワイバーン防御側→蓄魔なし
- ✅ 鼓舞AP上昇と刺突条件: current_ap上昇でもベースAPで判定→不発を確認
- ✅ Executor修正: EPスナップショットをpre_battle_skills前に取得（蓄魔の差分検出対応）

#### Phase 3p: 個別クリーチャーテスト（16テスト追加、113テスト全パス）
- ✅ `test_creature_individual.gd` 新規作成（スキルテストから個別クリーチャーテストを分離）
- ✅ フレイムパラディン(1): AP変動[火地×10]基本/ゼロAP/無効化[巻物]/強化アイテム併用 (4件)
- ✅ ウリエル(4): 強化[刻印有]発動/不発/ガイアハンマー2重防止 (3件)
- ✅ ボムスライム(13): 死亡時HP-40（攻撃側/相討ち/生存不発/防御側/刻印弱体） (5件)
- ✅ マルコシアス(15): AP+MHP50以上配置数×5（混合配置テスト） (1件)
- ✅ ショックブリンガー(18): 攻撃成功時ダウン/奮闘でブロック/サイレントローブで無効化 (3件)
- ✅ ダウン状態テスト基盤: MockTileにset_down_state/is_down追加、BattleTestResultにdefender_tile_down追加
- ✅ battle_execution.gd: タイル参照をtile_data_manager経由に修正（テスト環境でも動作）
- ✅ skill_land_effects.gd: 型パラメータをNode→Variant化（MockTile互換性）
- ✅ board_system_3d.gd: get_player_tiles()をtile_data_manager経由に修正

---

## 2026年3月25日（Session: control_type基盤導入 + CPU切り替え機構）

### 完了した作業

#### player_control_types 基盤導入
- ✅ GFM: `player_is_cpu: Array[bool]` → `_player_control_types: Array[String]`（"local"/"cpu"、将来"remote"）
- ✅ 互換プロパティ: 外部11ファイルからの `player_is_cpu` 参照を維持（getter/setter変換）
- ✅ `get_control_type(player_id)` 追加: 制御タイプを文字列で取得
- ✅ `is_cpu_player()` を `get_control_type()` ベースに書き換え（既存互換維持）
- ✅ GFM内のインライン判定3箇所を `is_cpu_player()` に統一

#### CPU切り替え機構
- ✅ `convert_to_cpu(player_id)` / `convert_to_local(player_id)`: フラグ変更のみ、即実行しない
- ✅ 次のターン/フェーズ開始時に反映される安全設計

#### テスト導線
- ✅ `DebugSettings.test_cpu_takeover` トグル追加
  - true時: ソロバトル/クエストでP2をローカル操作で開始
- ✅ `game_3d.gd` / `quest_game.gd`: test_cpu_takeover時にplayer_is_cpu[1]=falseに上書き
- ✅ DebugController: `C`キーでP2のcontrol_typeをトグル（cpu↔local、次フェーズから反映）

#### CPU判定のGFM統一化
- ✅ `tile_action_processor.gd`: インライン判定 → `game_flow_manager.is_cpu_player()` に統一
- ✅ `board_system_3d.gd`: 同上（ドミニオボタン表示判定）
- ✅ `discard_handler.gd`: GFM参照追加 + `is_cpu_player()` 統一
- ✅ `_sync_board_cpu_flags()`: convert時にboard_system_3d/discard_handlerのコピーを同期
- ✅ `_control_type_overridden`: 明示的convert呼び出しはmanual_control_allより優先

#### 対戦モード通知自動進行
- ✅ `GlobalCommentUI.battle_auto_advance`: 対戦モードで全コメント3秒自動進行
- ✅ `SpellCastNotificationUI.battle_auto_advance`: スペル通知も同様に3秒自動進行
- ✅ ソロバトル開始時に両UIに `battle_auto_advance = true` を設定
- ✅ クエストモードは従来通り（クリック待ち + 7秒タイムアウト）
- ✅ `force_click_wait` は対戦モードでは無視される設計

#### バグ修正
- ✅ `test_spell_player_move.gd`: PlayerData.buffs → direction_choice_pending 直接アクセスに修正（4箇所）

#### CPU引き継ぎ時のデフォルトポリシー統一
- ✅ `convert_to_cpu()` 時に `_apply_default_cpu_policy()` で "balanced" ポリシーを自動適用
- ✅ プレイヤーキャラにはCPU設定がないため、統一デフォルトで対応
- ✅ ネット対戦は全員人間スタート→切断者1人のみCPU化→ポリシー1つで十分
- ✅ `docs/design/network_design.md` Phase 4 更新（実装済みマーク）

### 設計判断
- `player_is_remote` 配列は今回追加しない（ネットワーク入力待ちはサーバー実装時に作る）
- 時間制限タイマーもネット対戦実装時に追加（convert_to_cpuが受け口になる）
- 入力入口の1本化は将来のリファクタ対象
- CPU引き継ぎポリシーは統一（"balanced"）: プレイヤーキャラにはCPU AI設定がないため

### 📋 次のステップ
- ネット対戦: Goリレーサーバー雛形 or NetworkService抽象レイヤー

---

## 2026年3月24日（Session 2: GameLoggerログ拡充 + PlayerData手入れ + MatchSnapshotBuilder）

### 完了した作業

#### GameLoggerログ拡充（STEP 1完了）
- ✅ スペル使用時にスペル名・ID記録（選択確定はGameLog、選択開始はDebugLog）
- ✅ バトル開始/結果にクリーチャー名・ID・アイテム名を記録
- ✅ アイテム使用・合体をバトルログに記録
- ✅ アルカナアーツ使用を記録（spell_idで識別、id:-1問題修正）
- ✅ カードドロー名・IDを記録（STEP 2から前倒し）
- ✅ ドミニオコマンドにレベル情報追加
- ✅ ゲーム終了ログ追加（勝利/敗北+ラウンド数 — STEP 1最後の欠落）
- ✅ GameLog/DebugLog分離方針をlogger_system.mdに記載
- ✅ 構造化ログ・turn・action_idはSTEP 6（ネットワーク対戦時）で対応する方針を記載

#### PlayerData周辺の手入れ（設計書の既知問題3件修正）
- ✅ `destroyed_count` 削除: PlayerDataでは未使用、LapSystem.destroy_countが正
- ✅ `magic_power`/`target_magic` デフォルト値を0に変更（initialize_players()で上書きされるため）
- ✅ `buffs: Dictionary` → `direction_choice_pending: bool` に変更（10箇所書き換え）
  - PlayerData.buffsは"direction_choice_pending"フラグ専用だった
  - PlayerBuffSystem.player_buffsとは用途が完全に異なることを確認

#### MatchSnapshotBuilder 作成
- ✅ `scripts/system_manager/match_snapshot_builder.gd` 新規作成
  - `get_player_snapshot(player_id)`: PlayerSystem + LapSystem + BuffSystem + SpellState + CardSystem から集約
  - `get_match_snapshot()`: 全プレイヤー + ボード + ターン + 世界刻印 + 破壊カウント
  - 各システムからデータを「集めるだけ」。状態変更は一切行わない
- ✅ GameSystemManager に組み込み（Phase 6後に_setup_snapshot_builder()実行）
- ✅ player_data_design.md にAPI・データソースマッピング・将来用途を記載

### 📋 次のステップ

- エフェクト作成ブランチの本来タスクへ
- 残りスペルテスト3件（スペル借用系2、ミリティア1）

---

## 2026年3月24日（Session 1: ナビゲーター方向選択UI修正 + テスト警告全解消）

### 完了した作業

#### ナビゲーター方向選択UI修正
- ✅ `movement_controller.gd`: `_select_first_tile()` に `has_direction_choice` パラメータ追加
  - `direction_choice_pending` 時は `came_from` フィルタリングをスキップ → 両方向が選択肢に残る
  - これにより `MovementBranchSelector` が起動し、黄色マーカー + 到着予測マーカーが正常表示
- ✅ `spell_player_move.gd`: `direction_choice` → `direction_choice_pending` キー名修正（`get_available_directions`, `consume_direction_choice`）

#### 3チェーンアクセス違反修正（コーディング規約準拠）
- ✅ `MovementController3D` に `board_system: BoardSystem3D` 直接参照を追加
- ✅ `board_system_3d.gd`: `set_movement_controller_gfm()` で `board_system = self` を注入
- ✅ `movement_direction_selector.gd`: `controller.game_flow_manager.board_system_3d` → `controller.board_system`（全箇所）
- ✅ `movement_branch_selector.gd`: 同様に3チェーン → 2チェーンに修正（`gfm`/`gfm2` ローカル変数削除）

#### GUT自動テスト警告全解消（39警告 → 0警告）
- ✅ Float/Int比較警告修正（22箇所）: JSON値を `int()` でキャスト（GodotのJSONパーサーが数値をfloatで返すため）
- ✅ unfreed children警告修正（15ファイル）: `queue_free()` → `free()` に変更（即時解放で蓄積防止）
- ✅ `test_spell_player_move.gd`: `get_children()` ループ → 明示的な変数名指定の `free()` に変更（GUT内部の `_awaiter` ノード誤解放防止）
- ✅ `test_spell_purify.gd`: 欠落していた `after_each()` を追加
- ✅ 最終結果: **962テスト、0警告、全パス**

### 📋 次のステップ

- 残りスペルテスト3件（スペル借用系2、ミリティア1）→ 進捗 195/198 (98%)
- エフェクト作成ブランチの本来タスクへ

---

## 2026年3月22日（Session: クリーチャー自動テスト完了）

### 完了した作業

#### Phase 3p続行: 個別クリーチャーテスト追加
- ✅ ストームブリンガー(18): 攻撃成功時ダウン関連テスト追加
- ✅ ドラゴニュート: 変身系テスト
- ✅ オーガロード(407): オーガ数依存AP/HP強化 + 強化術自動発動の相互作用テスト (4件)
  - 強化術は巻物不要で自動発動（APバフ未検出時に発動）
  - temporary_bonus_hpはcurrent_hpとは別プール
- ✅ ゴブリンシャーマン(445): ゴブリン族ボード配置依存AP/HP強化テスト (2件)
- ✅ ライフリンク関連テスト

#### 合体(Merge)テスト基盤構築 + テスト2件
- ✅ `BattleTestConfig` に `attacker_merge_partner_id` / `defender_merge_partner_id` 追加
- ✅ `BattleTestExecutor` に `_apply_merge()` ヘルパー追加（手札操作・EP確保・SkillMerge呼出）
- ✅ グランギア(409)+スカイギア(419)→アンドロギア(406) 合体テスト
- ✅ アンドロギア(406)+ビーストギア(434)→ギアリオン(408) 合体テスト

#### skill_merge.gd バグ修正3件（テストで発見）
- ✅ `participant.tile_index` → 安全アクセスパターンに修正（BattleParticipantにtile_indexプロパティなし）
- ✅ `participant.base_ap` 代入削除（BattleParticipantにbase_apインスタンス変数なし）
- ✅ print文の `participant.base_ap` → `participant.current_ap` に修正

#### クリーチャー自動テスト完了
- ✅ **639テスト / 2201アサート 全パス**
- ✅ `docs/specs/gut_test_spec.md` に完了マーカー記載

### 📋 次のステップ

- Phase 4: スペルテスト
- エフェクト作成ブランチの本来タスクへ

---

## 2026年3月20日（Session: GUT自動テスト導入 - バトルアイテムテスト）

### 完了した作業（省略 - 詳細は git log 参照）
- ✅ GUT環境セットアップ、Phase 1-2 バトルアイテムテスト完了
- ✅ MockBoard設計、Phase 3k 刺突テスト、Phase 3p 個別クリーチャーテスト開始
- ✅ 323テスト全パス

### 📋 次のステップ

- Phase 3p続行 → 完了済み（3/22）

---

## 2026年3月19日（Session: GameLoggerシステム導入）

### 完了した作業

#### GameLogger Autoload 導入（STEP 1）
- ✅ `scripts/autoload/logger.gd` 作成（ファイル書き込み + コンソール出力、毎行flush）
- ✅ `project.godot` に GameLogger Autoload 登録（`Logger` は Godot 4.5 組み込みクラス名と衝突するため `GameLogger` に変更）
- ✅ 13ファイル31箇所にログ埋め込み
  - フェーズ遷移（SM）、ターン開始/終了（GFM）、ダイス結果（Dice）
  - 移動完了（Move）、スペルフェーズ開始/完了（Spell）、効果実行（Spell）
  - アーツ実行（Spell）、バトルUI開始/終了/異常（BattleUI）
  - 召喚成功/失敗（Summon）、ドミニオコマンド/移動侵略（Dominio）
  - 通行料（Toll）、チェックポイント/周回完了/勝利（Lap/Game）、破産（Game）
- ✅ 設計ドキュメント `docs/design/logger_system.md` 更新（GameLogger名前変更反映）
- ✅ 動作確認済み: ログファイル `user://logs/game_YYYYMMDD_HHMMSS.log` に正常出力

#### 移動詳細ログ追加（STEP 1.5）
- ✅ `movement_controller.gd` 2箇所: 強制停止ログ（理由付き）
- ✅ `special_tile_system.gd` 2箇所: 停止型ワープログ（発動/ペアなし）
- ✅ `special_tile_system.gd` 1箇所: CPU遠隔召喚ログ
- ✅ `movement_warp_handler.gd` 1箇所: 通過型ワープログ（STEP 1で追加済み）
- ✅ 動作確認済み: ワープ発動時にログ正常出力（停止型ワープ + ワープアニメーション）

#### push_error/push_warning → GameLogger 変換（STEP 2）
- ✅ `logger.gd` 改修: error→push_error, warn→push_warning でエディタErrors タブ連携
- ✅ 67ファイル271箇所を GameLogger.error() / GameLogger.warn() に変換
  - 全件カテゴリ付き（Init, Spell, Battle, Board, Card, CPU 等15カテゴリ）
  - ERROR は状況付き必須ルール（player_id, tile_idx, spell_id 等）
- ✅ 抽象メソッド3件は push_error 維持（spell_strategy.gd, skill_effect_base.gd）
- ✅ 6コミットに機能単位で分割
- 📋 詳細: `docs/progress/push_error_migration.md`

#### null参照ガード強化（スペル系完了）
- ✅ スペル系の調査完了: 49箇所のリスク特定（Critical 31 + Moderate 18）
- ✅ spell_effect_executor: 早期return時の完了シグナル保証（spell_used + complete_spell_phase）
- ✅ spell_flow_handler: current_player null チェック追加
- ✅ spell_land_new.gd: tile_nodes アクセス全箇所確認（_validate_tile_index / .has() / keys()ループで保護済み）
- ✅ spell_mystic_arts.gd: 4箇所修正（board_system_ref, spell_ui_manager, _set_caster_down_state）
- ✅ mystic_arts_handler.gd: 4箇所修正（spell_state チェーンアクセスガード）
- ✅ spell_target_selection_handler.gd: 4箇所修正（spell_state null ガード）
- ✅ spell_creature_move.gd: 3箇所修正（board_system_ref null ガード）
- ✅ spell_flow_handler.gd: 確認済み（ternary で保護済み、追加修正不要）
- ✅ spell_effect_executor.gd: 確認済み（前セッションで修正 + ternary保護済み）
- ✅ spell_magic.gd: 確認済み（ループ内アクセスは安全、追加修正不要）
- 🔄 残り: ドミニオ → バトル → 召喚

### 📋 次のステップ

- null参照ガード: ドミニオシステム（move_source_tile, selected_tile, state不整合）
- null参照ガード: バトルシステム（attacker/defender null, battle_data null）
- null参照ガード: 召喚システム（tile null, creature_data null）
- 自動テスト（GUT フレームワーク導入）
