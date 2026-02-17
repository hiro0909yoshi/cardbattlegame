# リファクタリング次ステップ

**最終更新**: 2026-02-18
**現在のフェーズ**: Phase 8 — UIManager 神オブジェクト解消

---

## ✅ 完了済み Phase（サマリー）

| Phase | 内容 | 実施日 |
|-------|------|--------|
| 7-A | CPU AI パススルー除去（SPH → GSM 直接注入） | 2026-02-17 |
| 7-B | SPH UI 依存逆転（Signal 駆動化、spell_ui_manager 直接呼び出しゼロ） | 2026-02-17 |

---

## Phase 8: UIManager 神オブジェクト解消

### 現状分析

**UIManager**: 1,093行、28個のUIコンポーネント管理、63ファイルが参照する神オブジェクト

| 未対応ハンドラー | 行数 | ui_manager 呼び出し数 | 難易度 |
|----------------|------|---------------------|--------|
| ItemPhaseHandler | 769行 | ~11箇所 | **低** |
| DominioCommandHandler | 1,243行 | **50箇所以上** | **高** |
| BankruptcyHandler | 488行 | 0箇所（Signal済み）、Panel直接生成3箇所 | **低** |

---

### 8-A: ItemPhaseHandler Signal 駆動化

**目的**: ItemPhaseHandler から `ui_manager` 直接参照を削除し、Signal 駆動に移行
**リスク**: 低（呼び出し箇所が少なく、パターンが明確）

#### ui_manager 呼び出し一覧と変換方針

| 分類 | 箇所 | 現在の呼び出し | Signal 変換方針 |
|------|------|---------------|----------------|
| フィルター設定 | L267-299 | `ui_manager.blocked_item_types = ...` | Signal: `item_filter_configured(filter_config)` |
| | | `ui_manager.card_selection_filter = ...` | （上記 Signal にまとめる） |
| | | `ui_manager.assist_target_elements = ...` | （上記 Signal にまとめる） |
| 手札表示更新 | L302-305 | `ui_manager.hand_display.refresh()` | Signal: `item_hand_display_requested(player_id)` |
| | | `ui_manager.update_hand_display(player_id)` | （上記にまとめる） |
| カード選択UI | L308-310 | `ui_manager.card_selection_ui.show_selection(...)` | Signal: `item_selection_ui_shown(hand_data, config)` |
| フィルタークリア | L470-477 | `ui_manager.card_selection_filter = ""` 等 | Signal: `item_filter_cleared()` |
| | | `ui_manager.blocked_item_types = []` | （上記にまとめる） |
| | | `ui_manager.update_hand_display(player_id)` | （上記にまとめる） |

**追加修正**:
- `start_item_phase()` に `board_system.enable_manual_camera()` 追加（カメラ漏れ修正）

**見込み Signal 数**: ~4個
**対象ファイル**:
- `scripts/game_flow/item_phase_handler.gd` — Signal 追加、ui_manager 呼び出し除去
- `scripts/ui_manager.gd` — Signal リスナー追加
- `scripts/system_manager/game_system_manager.gd` — Signal 接続

---

### 8-B: DominioCommandHandler Signal 駆動化

**目的**: DominioCommandHandler から `ui_manager` 直接参照を削除
**リスク**: 高（50箇所以上、状態遷移が複雑）

#### 呼び出し分類と段階的対応

DominioCommandHandler の ui_manager 呼び出しは以下の5グループに分類できる。
グループ単位で段階的に Signal 化する。

**8-B1: ナビゲーション操作（13箇所）**

| 箇所 | 現在の呼び出し | Signal |
|------|---------------|--------|
| L169 | `ui_manager.clear_navigation_saved_state()` | `dominio_navigation_cleared()` |
| L196-201 | `ui_manager.enable_navigation(confirm, back)` | `dominio_navigation_configured(config)` |
| L314 | `ui_manager.disable_navigation()` | `dominio_navigation_disabled()` |
| L471,487,496,505,514 | `ui_manager.enable_navigation(...)` ×5 | （上記 configured を再利用） |

**Signal数**: ~3個

**8-B2: DominioOrderUI 操作（15箇所以上）**

| 箇所 | 現在の呼び出し | Signal |
|------|---------------|--------|
| L190-191 | `ui_manager.show_land_selection_mode(...)` | `dominio_land_selection_shown(lands)` |
| L317-319 | `ui_manager.dominio_order_ui.hide_level_selection()` 等 | `dominio_ui_state_changed(state)` |
| L340-344 | `ui_manager.hide_dominio_order_ui()` | `dominio_ui_closed()` |
| L378-380 | 地形選択→アクション選択切り替え | `dominio_ui_state_changed(state)` |
| L400-441 | `ui_manager.show_action_menu()` 等 | （上記にまとめる） |
| L626-651 | レベルボタンハイライト、選択確定 | `dominio_level_ui_updated(level_data)` |

**Signal数**: ~4個

**8-B3: その他 UI 操作（10箇所以上）**

| 箇所 | 現在の呼び出し | Signal |
|------|---------------|--------|
| L154-155 | `ui_manager.phase_display.show_toast(...)` | `dominio_toast_shown(msg)` |
| L159-165 | ドミニオ開始時 UI 無効化 | `dominio_opened()` |
| L432-433 | `ui_manager.card_selection_ui.hide_selection()` | `dominio_card_selection_hidden()` |
| L437 | `ui_manager.hide_all_info_panels()` | `dominio_info_panels_hidden()` |
| L527-540 | `phase_display.show_action_prompt()` 等 | `dominio_action_prompt_shown(msg)` |
| L1075 | `ui_manager.update_player_info_panels()` | `dominio_player_info_updated()` |
| L1088-1115 | `ui_manager.tap_target_manager` | 直接参照注入に変更 |
| L1207-1218 | `ui_manager.show_comment_and_wait()` | request/completed Signal ペア |

**Signal数**: ~7個

**追加修正**:
- `open_dominio_order()` に `board_system.enable_manual_camera()` 追加（カメラ漏れ修正）

**見込み Signal 総数**: ~14個
**対象ファイル**:
- `scripts/game_flow/dominio_command_handler.gd` — Signal 追加、ui_manager 呼び出し除去
- `scripts/ui_manager.gd` — Signal リスナー追加
- `scripts/system_manager/game_system_manager.gd` — Signal 接続

---

### 8-C: BankruptcyHandler パネル直接生成の分離

**目的**: `Panel.new()`, `Label.new()` の直接生成をUIコンポーネント側に移動
**リスク**: 低（Signal 駆動は Phase 6-C で完了済み、パネル生成のみ）

#### 直接生成箇所

| 行番号 | 生成コード | 用途 |
|--------|-----------|------|
| L119 | `Panel.new()` | 破産情報パネル |
| L150 | `Label.new()` | 現在のEPラベル |
| L162 | `Label.new()` | 売却後のEPラベル |

**方針**:
1. `BankruptcyInfoPanel` UIコンポーネント（新規）を作成
2. パネル構築ロジックを移動
3. BankruptcyHandler は Signal で表示/更新を依頼

**対象ファイル**:
- `scripts/ui_components/bankruptcy_info_panel.gd` — 新規作成
- `scripts/game_flow/bankruptcy_handler.gd` — パネル生成コード除去、Signal 追加
- `scripts/system_manager/game_system_manager.gd` — 初期化追加

---

### 8-E: 兄弟システム → UIManager 直接参照の解消

**目的**: UIManager と同レベル（兄弟関係）のシステムが UIManager を直接参照している問題を解消
**リスク**: 中〜高（広範囲に影響、各システムの用途が異なる）

#### 問題の構図

```
GameFlowManager（親）
  ├── BoardSystem3D ──❌直接参照──→ UIManager
  ├── BattleSystem ───❌直接参照──→ UIManager
  ├── SpecialTileSystem ─❌直接参照→ UIManager
  ├── TileActionProcessor ❌直接参照→ UIManager
  └── UIManager（本来ここだけがUIを管理）

SpellMysticArts ──❌チェーン参照──→ spell_ui_manager._ui_manager
```

正しい構造: 兄弟システムは Signal を emit → GFM または UIManager がリスニング

#### 違反箇所の詳細

**1. BoardSystem3D** — フェーズテキスト・ドミニオボタン操作

| 用途 | 現在の呼び出し | Signal 変換 |
|------|---------------|-------------|
| 移動通知 | `ui_manager.set_phase_text("移動中...")` | `board_phase_text_requested(text)` |
| ドミニオボタン | `ui_manager.show_dominio_order_button()` | `dominio_button_visibility_changed(visible)` |

**2. BattleSystem** — バトル結果通知

| 用途 | 現在の呼び出し | Signal 変換 |
|------|---------------|-------------|
| 結果コメント | `ui_manager.show_comment_and_wait(msg)` | request/completed Signal ペア |
| グローバルコメント | `global_comment_ui` 直接参照 | Signal 経由に変更 |

**3. TileActionProcessor** — タイルアクション UI

| 用途 | 現在の呼び出し | Signal 変換 |
|------|---------------|-------------|
| アクション指示 | `ui_manager.show_action_prompt(msg)` | `tile_action_prompt_requested(msg)` |
| カード選択UI | `ui_manager.show_card_selection_ui()` | `tile_card_selection_requested(config)` |

**4. SpecialTileSystem** — 特殊タイル UI

| 用途 | 現在の呼び出し | Signal 変換 |
|------|---------------|-------------|
| カードフィルター | `ui_manager.card_selection_filter = ...` | Signal 経由 |
| フェーズ表示 | `ui_manager.set_phase_text(...)` | Signal 経由 |

**5. SpellMysticArts** — アルカナアーツ UI チェーン参照

| 用途 | 現在の呼び出し | Signal 変換 |
|------|---------------|-------------|
| UI操作 | `spell_phase_handler.spell_ui_manager._ui_manager` | SpellUIManager の Signal 経由 |

**対象ファイル** (5+):
- `scripts/board_system_3d.gd`
- `scripts/battle_system.gd`
- `scripts/tile_action_processor.gd`
- `scripts/special_tile_system.gd`
- `scripts/spells/spell_mystic_arts.gd`
- `scripts/ui_manager.gd` — Signal リスナー追加
- `scripts/system_manager/game_system_manager.gd` — Signal 接続

---

### 8-D: UIManager 整理（8-A〜E 完了後に評価）

**目的**: 8-A〜E 完了後に UIManager の残存責務を評価し、必要なら分割

**8-A〜E 完了後の UIManager の役割**:
- UI コンポーネントのライフサイクル管理（create_ui, 初期化）
- Signal リスナーのハブ（各システム → UIManager → 子コンポーネント）
- グローバル UI 操作（show_card_info, hide_all_info_panels 等）

**判断基準**: 8-A〜E で UIManager への直接呼び出しが十分減少すれば分割不要。
まだ大きい場合は以下の分割候補を検討:
- `NavigationManager` — ボタン・ナビゲーション状態
- `InfoPanelManager` — 情報パネル表示・非表示
- `CardSelectionManager` — カード選択UI・フィルター

**注意**: 分割は 8-A〜E の成果を見てから判断する（過剰設計を避ける）

---

## 実施順序

| 順番 | Phase | 内容 | 難易度 | 見込みSignal数 |
|-----|-------|------|--------|---------------|
| 1 | **8-A** | ItemPhaseHandler Signal 駆動化 | 低 | ~4 |
| 2 | **8-B1** | DominioCommandHandler ナビゲーション | 中 | ~3 |
| 3 | **8-B2** | DominioCommandHandler DominioOrderUI | 中 | ~4 |
| 4 | **8-B3** | DominioCommandHandler その他UI | 中 | ~7 |
| 5 | **8-C** | BankruptcyHandler パネル分離 | 低 | ~2 |
| 6 | **8-E** | 兄弟システム UIManager 直接参照解消 | 中〜高 | ~10 |
| 7 | **8-D** | UIManager 整理（全完了後に評価） | — | — |

---

## Signal 駆動化の全体状況

| ハンドラー | Signal数 | UI直接操作 | 状態 |
|-----------|---------|-----------|------|
| SpellPhaseHandler | 3 Signals | ✅ ゼロ | **完全分離** |
| SpellFlowHandler | 11 Signals | ✅ ゼロ | **完全分離** |
| MysticArtsHandler | 5 Signals | ✅ ゼロ | **完全分離** |
| DicePhaseHandler | 8 Signals | ✅ ゼロ | **完全分離** |
| TollPaymentHandler | 2 Signals | ✅ ゼロ | **完全分離** |
| DiscardHandler | 2 Signals | ✅ ゼロ | **完全分離** |
| BankruptcyHandler | 5 Signals | ⚠️ Panel直接生成 | 部分的 → **Phase 8-C** |
| ItemPhaseHandler | 0 Signals | ❌ 11箇所 | **Phase 8-A** |
| DominioCommandHandler | 0 Signals | ❌ 50箇所以上 | **Phase 8-B** |

### 兄弟システム → UIManager 直接参照

| システム | ui_manager 用途 | 状態 |
|---------|----------------|------|
| BoardSystem3D | フェーズテキスト、ドミニオボタン | ❌ **Phase 8-E** |
| BattleSystem | バトル結果コメント、global_comment_ui | ❌ **Phase 8-E** |
| TileActionProcessor | アクション指示、カード選択UI | ❌ **Phase 8-E** |
| SpecialTileSystem | カードフィルター、フェーズ表示 | ❌ **Phase 8-E** |
| SpellMysticArts | チェーン参照で ui_manager アクセス | ❌ **Phase 8-E** |

---

## カメラモード設定漏れ（Phase 8 で同時修正）

| ファイル | 箇所 | 修正Phase |
|---------|------|----------|
| `item_phase_handler.gd` | `start_item_phase()` | 8-A |
| `dominio_command_handler.gd` | `open_dominio_order()` | 8-B1 |
