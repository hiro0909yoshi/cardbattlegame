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

## ビューポート移行計画（3704×1712 → 1920×1080）

**ステータス**: 実機テスト済み、着手可能
**確認済み**: scaling_3d_scale=1.0で著しく重くなることを実機確認 → ビューポート縮小が必須

### 背景

- 現在のビューポート 3704×1712 はMac Retinaの画面ピクセル数そのまま
- モバイル実機（Huawei Mate 20 Lite）でFPS 10程度 → ゲームプレイ不可能
- scaling_3d_scale=1.0に変更すると更に重くなることを実機確認済み
- ビューポート縮小がモバイル対応の最大のブロッカー

### 方針

1. **project.godot変更** → **GameConstants一括変更** → **各Stepファイル修正** の順
2. 単純な比率計算（×0.52）ではなくUI設計として適切なサイズに再設定
3. ハードコード値 → 可能な限りビューポート比率ベースに変更
4. 各Stepごとにデスクトップで動作確認 → コミット → 全Step完了後に実機テスト
5. SubViewport（カードレンダリング等）は比率維持のためサイズ変更不要なものもある

---

## Step 0: project.godot + GameConstants（基盤変更）

### project.godot

| 設定 | 変更前 | 変更後 |
|------|--------|--------|
| viewport_width | 3704 | 1920 |
| viewport_height | 1712 | 1080 |
| window_width_override | (なし) | 3704 |
| window_height_override | (なし) | 1712 |
| stretch/mode | "viewport" | "canvas_items" |
| stretch/aspect | (なし) | "expand" |
| scaling_3d/scale | 0.5 | 削除（デフォルト1.0） |

**window_width/height_override**: Mac上でウィンドウサイズを維持するため必須（ビューポートは1920×1080だがウィンドウは3704×1712のまま）

### game_constants.gd（フォントサイズ一括変更）

26個のFONT_SIZE定数を約52%に縮小:

| 定数名 | 変更前 | 変更後（目安） |
|--------|--------|---------------|
| FONT_SIZE_XS | 14 | 8 |
| FONT_SIZE_S | 16 | 9 |
| FONT_SIZE_M | 28 | 15 |
| FONT_SIZE_L | 36 | 19 |
| FONT_SIZE_XL | 48 | 25 |
| FONT_SIZE_XXL | 64 | 33 |
| FONT_SIZE_XXXL | 96 | 50 |
| FONT_SIZE_ICON | 120 | 62 |
| FONT_SIZE_BUTTON | 36 | 19 |
| FONT_SIZE_BUTTON_LARGE | 48 | 25 |
| FONT_SIZE_MENU_BUTTON | 96 | 50 |
| FONT_SIZE_TOAST | 60 | 31 |
| FONT_SIZE_COMMENT | 60 | 31 |
| FONT_SIZE_COMMENT_LARGE | 120 | 62 |
| FONT_SIZE_DICE | 64 | 33 |
| FONT_SIZE_ACTION_PROMPT | 64 | 33 |
| FONT_SIZE_RESULT_TITLE | 96 | 50 |
| FONT_SIZE_RESULT_RANK | 72 | 37 |
| FONT_SIZE_RESULT_INFO | 48 | 25 |
| FONT_SIZE_RESULT_REWARD | 40 | 21 |
| FONT_SIZE_RESULT_TOTAL | 52 | 27 |
| FONT_SIZE_RESULT_HINT | 32 | 17 |

※GameConstants参照済みの箇所は自動的に反映されるため、個別ファイルでの修正不要

---

## Step 1: タイトル画面（2ファイル / 約10箇所）

### `scenes/TitleScreen.tscn`（5箇所）
- L32: font_size=96 → 50
- L39: font_size=36 → 19
- L46: Spacer custom_minimum_size Vector2(0, 80) → Vector2(0, 40)
- L50: font_size=42 → 22
- L66: font_size=20 → 11

### `scripts/title_screen.gd`（5箇所）
- L47: ボタン custom_minimum_size Vector2(300, 80) → Vector2(155, 42)
- L48: font_size=36 → 19
- L56: font_size=28 → 15
- L61: 入力欄 custom_minimum_size Vector2(500, 60) → Vector2(260, 32)
- L62: font_size=36 → 19
- L90: popup_centered Vector2i(600, 250) → Vector2i(310, 158)

**確認ポイント**: タイトル表示、名前入力ダイアログ、ボタンタッチ領域

---

## Step 2: メインゲーム画面（14ファイル / 約65箇所）

### `scripts/game_3d.gd`（2箇所）
- L556: FPS位置 Vector2(20, 20) → Vector2(10, 10)
- L557: font_size=48 → 25

### `scripts/ui_components/hand_display.gd`（3箇所）
- L17: CARD_WIDTH=220 → 114
- L18: CARD_HEIGHT=293 → 152
- L19: CARD_SPACING=30 → 16

### `scripts/autoload/card_texture_cache.gd`（2箇所）
- L13: CARDFRAME_WIDTH=220 → 114
- L14: CARDFRAME_HEIGHT=293 → 152

### `scripts/ui_components/game_menu_button.gd`（3箇所）
- L14: BUTTON_SIZE=180 → 93
- L15: MARGIN_RIGHT=30 → 16
- L16: MARGIN_TOP=30 → 16

### `scripts/ui_components/game_menu.gd`（8箇所）
- L20: PANEL_WIDTH=1200 → 620
- L21: PANEL_HEIGHT=1100 → 694
- L55: separation=60 → 31
- L56: position Vector2(80, 80) → Vector2(41, 50)
- L71: custom_minimum_size Vector2(1040, 240) → Vector2(538, 151)
- L80: custom_minimum_size Vector2(1040, 40) → Vector2(538, 25)
- L97: Y offset -200 → -126

### `scripts/ui_components/phase_display.gd`（12箇所）
- L38: font_size=85 → 44
- L44: offset_top=150 → 95
- L45: offset_bottom=250 → 158
- L85: font_size=67 → 35
- L86: position Vector2(530, 90) → Vector2(275, 57)
- L109: font_size=200 → 104
- L156: font_size=60 → 31
- L161: offset_top=80 → 50
- L162: offset_bottom=160 → 101
- L206: font_size=55 → 29
- L211: offset_top=80 → 50
- L212: offset_bottom=160 → 101

### `scripts/ui_components/debug_panel.gd`（5箇所）
- L50: position Vector2(910, 280) → Vector2(471, 177)
- L51: size Vector2(280, 420) → Vector2(145, 265)
- L76: position Vector2(14, 14) → Vector2(7, 9)
- L77: size Vector2(252, 392) → Vector2(130, 247)
- L79: font_size=17 → 9

### `scripts/ui_components/level_up_ui.gd`（12箇所）
- L66: position Vector2(200, 280) → Vector2(104, 177)
- L67: size Vector2(500, 380) → Vector2(259, 240)
- L87: position Vector2(20, 20) → Vector2(10, 13)
- L87: font_size=22 → 12
- L94: position Vector2(20, 60) → Vector2(10, 38)
- L95: font_size=16 → 9
- L102: position Vector2(300, 60) → Vector2(155, 38)
- L103: font_size=16 → 9
- L118: position Vector2(20, 85) → Vector2(10, 54)
- L119: font_size=14 → 8
- L141: button_y += 55 → 35
- L154: size Vector2(460, 45) → Vector2(238, 28)

### `scripts/ui_components/surrender_dialog.gd`（12箇所）
- L13: PANEL_WIDTH=900 → 466
- L14: PANEL_HEIGHT=500 → 315
- L48: separation=50 → 32
- L50: position Vector2(60, 60) → Vector2(31, 38)
- L57: font_size=72 → 37
- L58: custom_minimum_size Vector2(780, 0) → Vector2(404, 0)
- L65: font_size=48 → 25
- L67: custom_minimum_size Vector2(780, 0) → Vector2(404, 0)
- L73: separation=80 → 50
- L79: custom_minimum_size Vector2(320, 120) → Vector2(166, 76)
- L80: font_size=48 → 25
- L87-88: 同上（降参ボタン）
- L109: Y offset -100 → -63

### `scripts/ui_components/dominio_order_ui.gd` — 要確認（動的レイアウト多い）
### `scripts/ui_components/magic_tile_ui.gd` — 要確認
### `scripts/ui_components/base_tile_ui.gd` — 要確認
### `scripts/ui_components/card_buy_ui.gd` — 要確認
### `scripts/ui_components/card_give_ui.gd` — 要確認

**確認ポイント**: 手札表示、メニュー開閉、フェーズ表示、レベルアップUI、降参ダイアログ

---

## Step 3: バトル画面（3ファイル / 約20箇所）

### `scripts/ui/battle_status_overlay.gd`（8箇所）
- L32: PANEL_WIDTH=1100 → 570
- L33: PANEL_HEIGHT=1100 → 694
- L34: PANEL_MARGIN=40 → 21
- L72: position Vector2(45, 520) → Vector2(23, 328)
- L73: size Vector2(PANEL_WIDTH-90, 4) → 比率維持
- L85-104: ラベル位置・フォントサイズ群（約6箇所）
- L127: position計算 +200 → +104

### `scripts/card.gd`（7箇所）
- L46: GAME_CARD_WIDTH=290 → 150
- L47: GAME_CARD_HEIGHT=390 → 246
- L130: size Vector2(150, 150) → Vector2(78, 95)
- L131: position Vector2(-75, -75) → Vector2(-39, -47)
- L141: font_size=150 → 78
- L153-154: overlay size/position（同比率）
- L845/849: symbol font_size=24→13, position Vector2(8,5)→Vector2(4,3)

### `scripts/ui_win_screen.gd` — font_size=150→78、オフセット値

**確認ポイント**: バトルステータス表示、カード拡大表示、勝敗演出

---

## Step 4: サブ画面（6ファイル / 約60箇所）

### `scripts/album.gd`（約15箇所）
- L64: custom_minimum_size Vector2(1000, 400) → Vector2(518, 252)
- L75: font_size=48 → 25
- L94: font_size=42 → 22
- L152: custom_minimum_size Vector2(200, 80) → Vector2(104, 50)
- L179: custom_minimum_size Vector2(1350, 350) → Vector2(699, 221)
- L225: font_size=60 → 31
- L379: custom_minimum_size Vector2(300, 380) → Vector2(155, 240)
- L407: custom_minimum_size Vector2(280, 280) → Vector2(145, 177)
- L419: font_size=26 → 14
- L440: font_size=24 → 13
- 他ボタン・ラベル約5箇所

### `scripts/solo_battle_setup.gd`（約20箇所）
- L73: custom_minimum_size Vector2(0, 100) → Vector2(0, 63)
- L79: custom_minimum_size Vector2(180, 80) → Vector2(93, 50)
- L80: font_size=42 → 22
- L87: font_size=72 → 37
- L149: font_size=48 → 25
- L178: custom_minimum_size Vector2(390, 176) → Vector2(202, 111)
- L186: custom_minimum_size Vector2(400, 0) → Vector2(207, 0)
- L283/289: SubViewport Vector2i(320, 230) → Vector2i(166, 145)
- L419: font_size=60 → 31
- L437/441-442: font_size=54→28, button Vector2(340, 80)→Vector2(176, 50)
- L526: custom_minimum_size Vector2(0, 100) → Vector2(0, 63)
- L531-532: start button Vector2(450, 100)→Vector2(233, 63), font_size=54→28
- L920: SubViewport Vector2i(900, 700) → Vector2i(466, 442)
- 他約5箇所

### `scripts/net_battle_setup.gd`（約20箇所）
- solo_battle_setup.gdと同構造、約20箇所の修正

### `scripts/quest/world_stage_select.gd`（約12箇所）
- L103-104: custom_minimum_size Vector2(300, 80), font_size=32
- L171/173: STAGE_BUTTON_SIZE, font_size=54
- L351/357-358: font_size=36/32, button Vector2(240, 60)
- L411: SubViewport Vector2i(600, 500) → Vector2i(310, 315)
- L655/662/673/681-682: ColorRect 48×48, font_size, button Vector2(200, 60)
- L735/743: font_size=48, scroll Vector2(0, 400)
- L758-759: button Vector2(400, 150)

### `scripts/settings.gd`（6箇所）
- L77/82: custom_minimum_size Vector2(300, 80) → Vector2(155, 50)
- L78/83: font_size=32 → 17
- L90: font_size=28 → 15
- L103: custom_minimum_size Vector2(400, 60) → Vector2(207, 38)
- L119: popup_centered Vector2i(600, 350) → Vector2i(310, 221)

### `scripts/status_screen.gd`（約12箇所）
- L127: custom_minimum_size Vector2(400, 80) → Vector2(207, 50)
- L131: custom_minimum_size Vector2(600, 400) → Vector2(310, 252)
- L186: custom_minimum_size Vector2(400, 100) → Vector2(207, 63)
- L190: custom_minimum_size Vector2(800, 500) → Vector2(414, 315)
- L205: custom_minimum_size Vector2(240, 100) → Vector2(124, 63)
- L261: custom_minimum_size Vector2(300, 80) → Vector2(155, 50)
- L275: custom_minimum_size Vector2(500, 60) → Vector2(259, 38)
- 各font_size約5箇所

**確認ポイント**: 全画面遷移、スクロール、ダイアログ表示

---

## Step 5: 情報パネル・ダイアログ（7ファイル / 約40箇所）

### `scripts/ui_components/special_tile_info_dialog.gd`（5箇所）
- L66: size Vector2i(800, 750) → Vector2i(414, 473)
- L96: font_size=28 → 15
- L125: custom_minimum_size Vector2(40, 40) → Vector2(21, 25)
- L138: font_size=26 → 14
- L144: font_size=20 → 11

### `scripts/ui_components/map_preview_dialog.gd`（8箇所）
- L45: size Vector2i(1800, 1100) → Vector2i(932, 694)
- L73: custom_minimum_size Vector2(300, 0) → Vector2(155, 0)
- L79: font_size=28 → 15
- L85: font_size=24 → 13
- L98: font_size=24 → 13
- L130: custom_minimum_size Vector2(16, 16) → Vector2(8, 10)
- L136: font_size=18 → 10
- L239: container_size Vector2(900, 700) → Vector2(466, 442)

### `scripts/ui_components/character_preview.gd`（1箇所）
- L20: SubViewport size Vector2i(800, 900) → Vector2i(414, 568)

### `scripts/creatures/creature_card_3d_quad.gd`（変更不要）
- SubViewport 220×293はカードテクスチャレンダリング用 → 出力品質のため維持

### `scripts/game_result/result_screen.gd`（6箇所）
- L47: custom_minimum_size Vector2(600, 500) → Vector2(310, 315)
- L48: position Vector2(-300, -250) → Vector2(-155, -158)
- L79: custom_minimum_size Vector2(500, 2) → Vector2(259, 2)
- L222: custom_minimum_size Vector2(450, 0) → Vector2(233, 0)
- L254: custom_minimum_size Vector2(700, 280) → Vector2(362, 177)
- L278/286/294: font_size=40→21, 48→25, 24→13

### `scenes/ui/creature_info_panel.tscn`（12箇所）
- font_size: 80→41, 60→31, 40→21 の各箇所

### `scenes/ui/spell_info_panel.tscn`（8箇所）
- font_size: 80→41, 60→31, 40→21 の各箇所

### `scenes/ui/item_info_panel.tscn`（10箇所）
- font_size: 80→41, 60→31, 40→21 の各箇所

### `scenes/ui/player_status_dialog.tscn`（3箇所）
- L81: font_size=60 → 31
- L92: normal_font_size=40 → 21
- L93: bold_font_size=44 → 23

**確認ポイント**: 情報パネル表示、マッププレビュー、キャラクタープレビュー

---

## Step 6: チュートリアル・ヘルプ（3ファイル / 約10箇所）

### `scripts/tutorial/tutorial_popup.gd`（約8箇所）
- font_size、custom_minimum_size等（動的レイアウト多いため要個別確認）

### `scripts/help_dominion_command.gd`（2箇所）
- font_size値の修正

### `scripts/window.gd`（確認のみ）
- font_size=200がある場合は修正

**確認ポイント**: チュートリアル全ステップ再生、ヘルプダイアログ

---

## 修正量の見積もり（精査済み）

| Step | 対象 | ファイル数 | 修正箇所 |
|------|------|-----------|---------|
| 0 | 基盤（project.godot + GameConstants） | 2 | 7 + 22 = **29箇所** |
| 1 | タイトル画面 | 2 | **10箇所** |
| 2 | メインゲーム画面 | 14 | **65箇所** |
| 3 | バトル画面 | 3 | **20箇所** |
| 4 | サブ画面 | 6 | **60箇所** |
| 5 | 情報パネル・ダイアログ | 7+4tscn | **40箇所** |
| 6 | チュートリアル・ヘルプ | 3 | **10箇所** |
| **合計** | | **約40ファイル** | **約234箇所** |

## 作業順序

1. **Step 0** を最初に実施（GameConstants変更で多数のファイルが自動的に反映）
2. **Step 1** → タイトル画面だけで動作確認（最小範囲でstretch mode変更の影響を検証）
3. **Step 2** → メインゲーム画面（最も箇所数が多い、コアプレイに直結）
4. **Step 3** → バトル画面
5. **Step 4** → サブ画面
6. **Step 5** → 情報パネル・ダイアログ（.tscn含む）
7. **Step 6** → チュートリアル
8. 全Step完了後、実機テストでFPS改善を確認

## 注意事項

- `canvas_items` モードではUIはビューポート解像度で描画されディスプレイにスケーリングされる
- `scaling_3d_scale`は3Dのみに適用、2D UIには影響しない
- SubViewport（カードレンダリング）は独立解像度のため変更不要な場合がある
- `window_width/height_override` でMac開発時のウィンドウサイズを維持
- 数値は目安 — 実際にはUIデザインとして見栄えが良い丸め値に調整

## 未完了タスク（他）

### Phase 11: UI チームカラー表示（後日）
- PlayerInfoPanel にチームカラーインジケータ
- チーム合算TEP表示の視覚的強調
