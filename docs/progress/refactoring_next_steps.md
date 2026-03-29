# マルチデバイス対応リファクタリング（ビューポート移行）

**最終更新**: 2026-03-30
**ステータス**: レンダリング最適化完了 / ビューポート移行は計画段階
**優先度**: 高（モバイル実機テストのブロッカー）

---

## レンダリング最適化（2026-03-30 完了）

### 成果

| 状態 | OBJ | DRAW | 備考 |
|------|-----|------|------|
| 最適化前 | 2204 | 942 | 初期計測値 |
| MultiMesh化後 | 832 | 560 | 城壁＋床タイル統合 |
| 手札軽量モード適用後 | 490 | 310 | 最終結果 |

**OBJ: -77.8%、DRAW: -67.1%** を達成。FPS 60維持、挙動異常なし。

### 実施内容

#### 1. 城壁（battlements）のMultiMesh化
- **ファイル**: `scripts/quest/castle_environment.gd`
- 個別MeshInstance3D約296個 → MultiMeshInstance3D 4個（NS壁/キャップ、EW壁/キャップ）
- 見た目の変更なし

#### 2. 床タイル（floor）のMultiMesh化
- **ファイル**: `scripts/quest/base_environment.gd`
- floor3.glbの個別instantiation → MultiMeshInstance3D 1個
- メッシュAABBからスケール比を正確に算出して配置
- 影の破綻も同時に解消

#### 3. 3Dカード（creature_card_3d_quad）のテクスチャキャッシュ化
- **ファイル**: `scripts/creatures/creature_card_3d_quad.gd`, `scripts/autoload/card_texture_cache.gd`（新規）
- 各カードにSubViewportを内蔵 → CardTextureCacheシングルトンで一元管理
- Card.tscnをSubViewportでオフスクリーンレンダリング → ImageTexture化 → QuadMeshに適用

#### 4. 手札カードの軽量モード（card.gd内部最適化）
- **ファイル**: `scripts/card.gd`, `scripts/ui_components/hand_display.gd`
- Card.tscn（47ノード/枚）× 6枚 = 282ノード → TextureRect 6枚に削減
- **方式**: card.gdに`enable_lightweight_mode(texture)`を追加
  - 全子ノードを`visible = false` + `process_mode = PROCESS_MODE_DISABLED`で完全停止
  - キャッシュテクスチャをTextureRect 1枚で描画
  - 制限マーク（RestrictionEContainer等）はz_index=10/11で上に再表示
  - 密命カード（`show_secret_back()`/`show_card_front()`）も軽量モード対応
- **入力処理**: card.gdの`_input()`はグローバルイベント＋`mouse_over`判定のため、子ノード停止の影響なし
- **失敗した方式**: CardHandView（card.gdの代替クラス）→ 入力処理の複雑さにより断念し、card.gd内部修正に方針転換

### 今後の追加最適化候補（優先度低）
- ゴーストトレイル削減（TRAIL_GHOST_COUNT 30→5）— スペルターゲット選択時のみ発生
- AtlasTexture方式（手札6枚のDRAWを6→1に統合）— 効果は5 draw calls分のみ

---

## ビューポート移行計画

### 背景

- 現在のビューポート 3704×1712 はMac Retinaの画面ピクセル数そのまま
- モバイル実機（Huawei Mate 20 Lite等）で描画負荷が高すぎてカクカクする原因の可能性
- iPhone/Android/iPad等のマルチデバイス対応に必須
- stretch mode "viewport" → "canvas_items" + "expand" への変更が必要

### 実施判断

**前提条件**: 実機でFPS計測を行い、ビューポート解像度がボトルネックと確認できた場合に着手する。レンダリング最適化は完了済みのため、次のボトルネックがビューポートなら着手。

## 変更概要

**project.godot 変更内容**:

| 設定 | 変更前 | 変更後 |
|------|--------|--------|
| viewport_width | 3704 | 1920 |
| viewport_height | 1712 | 1080 |
| window_width_override | (なし) | 3704 |
| window_height_override | (なし) | 1712 |
| stretch/mode | "viewport" | "canvas_items" |
| stretch/aspect | (なし) | "expand" |
| scaling_3d/scale | 0.5 | 削除（デフォルト1.0） |

**スケール比**: X=0.518（約52%）、Y=0.631（約63%）

## 修正対象の全リスト

### Step 1: タイトル画面
- [ ] `scenes/TitleScreen.tscn` — フォントサイズ(96,36,42,20)、Spacer(80)、offset値
- [ ] `scripts/title_screen.gd` — ダイアログサイズ(600,250)、ボタン(300,80)、フォント(28,36)、入力欄(500,60)

### Step 2: メインゲーム画面（ボード）
- [ ] `scripts/game_3d.gd` — FPSカウンター位置(20,20)、フォント(48)
- [ ] `scripts/ui_components/hand_display.gd` — CARD_WIDTH(220), CARD_HEIGHT(293)
- [ ] `scripts/ui_components/card_ui_helper.gd` — カードレイアウト計算（動的だが基準値確認）
- [ ] `scripts/ui_components/game_menu_button.gd` — BUTTON_SIZE(180), MARGIN(80), SPACING(20)
- [ ] `scripts/ui_components/game_menu.gd` — PANEL(1200×1100)
- [ ] `scripts/ui_components/phase_display.gd` — offset値(150,250,80,160)
- [ ] `scripts/ui_components/debug_panel.gd` — 位置(910,280)、サイズ(280×420)
- [ ] `scripts/ui_components/level_up_ui.gd` — 位置(200,280)、サイズ(500×380)
- [ ] `scripts/ui_components/surrender_dialog.gd` — PANEL(900×500)
- [ ] `scripts/ui_components/dominio_order_ui.gd` — オフセット確認
- [ ] `scripts/ui_components/magic_tile_ui.gd` — パネルサイズ・オフセット
- [ ] `scripts/ui_components/base_tile_ui.gd` — 各種サイズ
- [ ] `scripts/ui_components/card_buy_ui.gd` — 各種サイズ
- [ ] `scripts/ui_components/card_give_ui.gd` — 各種サイズ

### Step 3: バトル画面
- [ ] `scripts/ui/battle_status_overlay.gd` — PANEL(1100×1100)、separator位置(45,520)
- [ ] `scripts/ui_win_screen.gd` — フォント(150)、オフセット(-200,-150)
- [ ] `scripts/card.gd` — GAME_CARD(290×390)
- [ ] バトルスクリーン関連UI

### Step 4: サブ画面
- [ ] `scripts/album.gd` — custom_minimum_size 11箇所
- [ ] `scripts/solo_battle_setup.gd` — custom_minimum_size 14箇所、ダイアログサイズ
- [ ] `scripts/net_battle_setup.gd` — custom_minimum_size 16箇所、ダイアログサイズ
- [ ] `scripts/quest/world_stage_select.gd` — custom_minimum_size 10箇所
- [ ] `scripts/settings.gd` — ダイアログサイズ(600,350)
- [ ] `scripts/status_screen.gd` — ダイアログサイズ(600,300)

### Step 5: 情報パネル・ダイアログ
- [ ] `scripts/ui_components/special_tile_info_dialog.gd` — サイズ(800×750)
- [ ] `scripts/ui_components/map_preview_dialog.gd` — サイズ(1800×1100)
- [ ] `scripts/ui_components/character_preview.gd` — SubViewport(800×900)
- [ ] `scripts/creatures/creature_card_3d_quad.gd` — VIEWPORT(220×293)
- [ ] `scripts/game_result/result_screen.gd` — オフセット(-300,-250)
- [ ] 各種info_panel.tscn — フォントサイズ(80)

### Step 6: チュートリアル・ヘルプ
- [ ] `scripts/tutorial/tutorial_popup.gd` — 動的レイアウト（確認のみ）
- [ ] `scripts/help_dominion_command.gd` — フォント(64)
- [ ] `scripts/window.gd` — フォント(200)

## 修正量の見積もり

| Step | 対象 | ファイル数 | 修正箇所（概算） |
|------|------|-----------|----------------|
| 1 | タイトル画面 | 2 | 〜10箇所 |
| 2 | メインゲーム画面 | 〜14 | 〜60箇所 |
| 3 | バトル画面 | 〜4 | 〜15箇所 |
| 4 | サブ画面 | 〜5 | 〜55箇所 |
| 5 | 情報パネル・ダイアログ | 〜6 | 〜15箇所 |
| 6 | チュートリアル・ヘルプ | 〜3 | 〜5箇所 |
| **合計** | | **〜34ファイル** | **〜160箇所** |

## 修正方針（着手時）

1. 単純な比率計算（×0.52）ではなくUI設計として適切なサイズに再設定
2. ハードコード値 → 可能な限りビューポート比率ベースに変更
3. 各Stepごとに動作確認してからコミット
4. モバイル適応パフォーマンス（FPSに応じたscaling_3d自動調整）は別途実装

## 未完了タスク（他）

### Phase 11: UI チームカラー表示（後日）
- PlayerInfoPanel にチームカラーインジケータ
- チーム合算TEP表示の視覚的強調
