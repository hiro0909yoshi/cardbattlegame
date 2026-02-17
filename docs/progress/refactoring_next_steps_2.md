# Phase 8 残作業 & Phase 9 以降の計画

**作成日**: 2026-02-18
**現在のフェーズ**: Phase 8 — UIManager 依存方向の正規化（継続中）

---

## 現状サマリー

### プロジェクト全体の ui_manager 参照

| カテゴリ | ファイル数 | 参照数 | 説明 |
|---------|----------|-------|------|
| UIManager 内部 / UI層 | 10 | ~336 | 移行不要（UI層は UIManager を参照して正当） |
| インフラ（GSM） | 1 | 125 | 移行不要（システム初期化コーディネーター） |
| Phase 8 完了済み | 15 | ~167 | 残存参照は UIManager 固有操作のため保持 |
| spell_ui_manager 経由 | 3 | 19 | 移行不要（Phase 6 Signal化で ui_manager 直接参照なし） |
| パススルー | 1 | 5 | spell_draw.gd（子ハンドラーへの中継のみ） |
| **Phase 8 残作業対象** | **14** | **~258** | **本ドキュメントのスコープ** |
| **Phase 9 以降** | **6** | **~96** | **UIManager 自体の改修が前提** |

### 利用可能な UIService API

| サービス | 主要メソッド |
|---------|------------|
| **MessageService** | show_comment_and_wait, show_toast, show_action_prompt, hide_action_prompt, set_phase_text |
| **CardSelectionService** | show/hide_card_selection_ui, show_card_selection_ui_mode, card_selection_filter, excluded_card_id, update_hand_display, **signal card_selected** |
| **InfoPanelService** | show_card_info_only, show_card_selection, hide_all_info_panels, get_creature/spell/item_info_panel |
| **NavigationService** | enable/disable_navigation, save/restore_navigation_state, register_confirm/back_action |

### 重要発見: CardSelectionService に card_selected シグナルが存在

```gdscript
# scripts/ui_services/card_selection_service.gd
signal card_selected(card_index: int)
```

現在 `await ui_manager.card_selected` は UIManager のシグナルを待機しているが、CardSelectionService にも同名シグナルが定義済み。**emission chain を統一すれば Group B の全ファイルが移行可能**。

---

## 設計制約（CRITICAL — 全作業で遵守）

### 制約 1: CardSelectionService の責務肥大化防止

card_selected 統一後、CardSelectionService に「選択・フィルタ・モード管理・emit制御」が全て集まる。
**CardSelectionService が「小さな UIManager」になってはならない。**

**ガードレール**:
- CardSelectionService は「カード選択 UI の操作代行」に限定
- フィルタ判定ロジック（「このカードは選択可能か？」）はビジネスロジック側に残す
- モード管理（sacrifice/discard/spell/item）の判定責任は呼び出し元が持つ
- CardSelectionService は「言われたモードで表示する」だけ
- 新メソッド追加時は「これは UI 操作か？ロジック判定か？」を必ず問う

### 制約 2: PlayerInfoService は描画更新のみ

`update_player_info_panels()` は UIManager の「横断的責務」。
単純にサービス化すると PlayerInfoService が新たな中心点になる。

**ガードレール**:
- PlayerInfoService は **描画更新（render）だけ** に限定
- ゲームロジック判定（「誰が勝っているか」「EPは足りるか」等）は **絶対に持たせない**
- 「データを受け取って描画する」のみ。データの生成・加工はビジネスロジック層の責務
- 将来の機能追加時に「PlayerInfoService に判定を足した方が楽」という誘惑に負けない

### 制約 3: Phase 8-M（Signal 統一）は1ファイルずつ動作確認

card_selected の emission chain 変更は非同期 await のタイミングバグを生みやすい。

**作業ルール**:
- **一括置換禁止** — 1ファイルずつ移行 + 動作確認
- 移行順序: spell_borrow（最小）→ card_sacrifice_helper → tile_summon_executor → spell_creature_swap（最大）
- 各ファイル移行後に「カード選択 → 決定」「カード選択 → キャンセル(-1)」の両パスを確認
- emission chain 変更（card_selection_ui.gd）は Group B の最初のファイル移行前に行い、**UIManager リレーで後方互換を保証してから**着手

---

## Phase 8 残作業: グループ分類

### Group A: サービス注入で大幅削減（パターン確立済み）

既存のサービス注入パターンで移行可能。最もコスパが良い。

#### 1. spell_mystic_arts.gd（46 refs → 推定 ~20 残存）

| 操作 | 箇所 | 移行先 | 難易度 |
|------|------|--------|--------|
| `show_action_prompt(message)` | 2 | MessageService | 低 |
| `show_toast(...)` | (phase_display ガード) | MessageService | 低 |
| `show_card_info(creature_data, tile_index, false)` | 2 | InfoPanelService.show_card_info_only | 低 |
| `hide_all_info_panels(false)` | 1 | InfoPanelService | 低 |
| `enable_navigation(...)` | 1 | NavigationService | 低 |
| `disable_navigation()` | 1 | NavigationService | 低 |
| `tap_target_manager` | 4 | **UIManager 固有** — 残す | — |
| `add_child(action_menu)` | 1 | **UIManager 固有** — 残す | — |
| `_get_ui_manager()` 定義 + ガード | ~10 | 変換不要（ヘルパー関数内） | — |
| spell_ui_manager 参照 | ~4 | 移行対象外 | — |

**作業方法**: `_get_ui_manager()` に加えて `_get_message_service()`, `_get_navigation_service()`, `_get_info_panel_service()` ヘルパーを追加。各メソッド内でローカル変数に解決後使用。

**見積り**: 中（ヘルパー関数追加 + 10箇所の機械的置換）

#### 2. spell_target_selection_handler.gd（28 refs → 推定 ~10 残存）

| 操作 | 箇所 | 移行先 | 難易度 |
|------|------|--------|--------|
| `disable_navigation()` | 1 | NavigationService | 低 |
| `show_toast(...)` | 1 | MessageService | 低 |
| `show_action_prompt(text)` | 2 | MessageService | 低 |
| `tap_target_manager` | 1 | **UIManager 固有** — 残す | — |
| `phase_label` / `phase_display` ガード | ~5 | MessageService チェックに変換 | 低 |
| 変数宣言 / initialize | ~3 | 構造保持 | — |

**作業方法**: `initialize()` でサービス解決。`_ui_manager` と並行して `_message_service`, `_navigation_service` 追加。

**見積り**: 低（機械的置換）

#### 3. debug_controller.gd（31 refs → 推定 ~10 残存）

| 操作 | 箇所 | 移行先 | 難易度 |
|------|------|--------|--------|
| `card_selection_filter` 読み書き | 3 | CardSelectionService | 低 |
| `clear_card_selection_filter()` | 1 | CardSelectionService | 低 |
| `update_hand_display()` | 1 | CardSelectionService | 低 |
| `hide_card_selection_ui()` | 1 | CardSelectionService | 低 |
| `show_card_selection_ui_mode()` | 1 | CardSelectionService | 低 |
| `show_card_selection_ui()` | 1 | CardSelectionService | 低 |
| `set_phase_text()` / `get_phase_text()` | 2 | MessageService | 低 |
| `update_player_info_panels()` | 2 | **UIManager 固有** — 残す | — |
| `toggle_debug_mode()` | 2 | **UIManager 固有** — 残す | — |
| `hand_display` 直接参照 | 1 | **UIManager 固有** — 残す | — |

**作業方法**: `setup()` でサービス解決。CardSelectionService が主な移行先。

**見積り**: 低（機械的置換）

#### 4. land_selection_helper.gd（9 refs → 推定 ~3 残存）

| 操作 | 箇所 | 移行先 | 難易度 |
|------|------|--------|--------|
| `show_card_info_only(creature, tile_index)` | 1 | InfoPanelService | 低 |
| `show_toast(...)` | 1 | MessageService | 低 |
| `show_action_prompt(text)` | 1 | MessageService | 低 |
| `show_action_menu()` | 1 | **UIManager 固有** — 残す | — |
| null チェック / ガード | 4 | サービスチェックに変換 | 低 |

**作業方法**: handler._message_service / handler._info_panel_service パターン（DCH の land_action_helper と同じ）。

**見積り**: 低（6箇所の機械的置換）

---

### Group B: card_selected signal await パターン

**共通の壁**: `await ui_manager.card_selected` — UIManager のシグナルを直接 await している。

**前提作業（Phase 8-M）**: CardSelectionService の `card_selected` emission chain 統一
- 現在: card_selection_ui.gd → UIManager.card_selected を emit
- 目標: card_selection_ui.gd → CardSelectionService.card_selected を emit
- UIManager.card_selected は CardSelectionService からリレー（後方互換性）

**前提作業完了後の移行**:

#### 5. spell_creature_swap.gd（30 refs → 推定 ~5 残存）

| 操作 | 箇所 | 移行先 |
|------|------|--------|
| `card_selection_filter = ""` | 2 | CardSelectionService |
| `show_card_selection_ui_mode()` | 2 | CardSelectionService |
| `await ui_manager.card_selected` | 2 | `await _card_selection_service.card_selected` |
| `hide_card_selection_ui()` | 2 | CardSelectionService |
| `excluded_card_id` | 2 | CardSelectionService（**プロパティ存在確認済み**） |
| `enable_navigation(...)` | 2 | NavigationService |
| `emit_signal("card_selected", -1)` | 2 | CardSelectionService |
| `show_action_prompt()` | 1 | MessageService |
| `show_toast()` | 1 | MessageService |
| `set_message()` | 1 | **UIManager 固有**（MessageService に未実装） |
| `_get_ui_manager()` + ガード | ~8 | ヘルパー変換 |

**見積り**: 中（前提作業 8-M 完了後は機械的）

#### 6. tile_summon_executor.gd（13 refs → 推定 ~3 残存）

| 操作 | 箇所 | 移行先 |
|------|------|--------|
| `card_selection_filter = ""` | 1 | CardSelectionService |
| `excluded_card_index` | 2 | CardSelectionService |
| `await ui_manager.card_selected` | 1 | `await _card_selection_service.card_selected` |
| `update_player_info_panels()` | 2 | **UIManager 固有** — 残す |
| CardSacrificeHelper 生成時の ui_manager | 1 | **UIManager 渡し** — 残す |

**見積り**: 低（前提作業 8-M 完了後）

#### 7. spell_borrow.gd（13 refs → 推定 ~3 残存）

| 操作 | 箇所 | 移行先 |
|------|------|--------|
| `card_selection_filter` | 2 | CardSelectionService |
| `show_card_selection_ui_mode()` | 1 | CardSelectionService |
| `await ui_manager.card_selected` | 1 | `await _card_selection_service.card_selected` |
| `hide_card_selection_ui()` | 1 | CardSelectionService |
| `set_message()` | 1 | **UIManager 固有** — 残す |
| `_get_ui_manager()` + ガード | ~4 | ヘルパー変換 |

**見積り**: 低（前提作業 8-M 完了後）

#### 8. card_sacrifice_helper.gd（12 refs → 推定 ~3 残存）

| 操作 | 箇所 | 移行先 |
|------|------|--------|
| `card_selection_filter = ""` | 1 | CardSelectionService |
| `show_card_selection_ui_mode()` | 1 | CardSelectionService |
| `await ui_manager_ref.card_selected` | 1 | `await _card_selection_service.card_selected` |
| `hide_card_selection_ui()` | 1 | CardSelectionService |
| `set_message()` | 1 | **UIManager 固有** — 残す |
| 変数宣言 / _init / set_ui_manager | ~4 | 構造保持 |

**見積り**: 低（前提作業 8-M 完了後）

---

### Group C: UIManager 固有操作のみ（Phase 8 スコープ外）

これらのファイルはサービスに存在しないメソッドを使用しており、**新しいサービスの作成**が前提。

#### 9. card.gd（32 refs）— Phase 9 対象

**問題**: `find_ui_manager_recursive(get_tree().get_root())` でツリー探索。Node として UIManager のツリー外に存在するため、直接参照注入が困難。

| 操作 | 使用目的 |
|------|---------|
| `card_selection_filter` | カード表示の切り替え判定（spell/item/sacrifice/discard） |
| `card_selection_ui.selection_mode` | 犠牲/捨て札モード判定 |
| `on_card_button_pressed()` | カードボタン押下ハンドラー |
| `game_flow_manager_ref` | GFM 経由の game 状態取得 |

**解決策候補**:
- A) Card に CardSelectionService を注入（Hand表示時に set）
- B) Card からの UIManager 呼び出しを Signal 化（card_pressed signal → 上位でハンドル）
- C) CardSelectionService に is_spell_mode() 等の判定メソッド追加

**見積り**: 高（アーキテクチャ変更が必要）

#### 10. tutorial_manager.gd（22 refs）— Phase 9 対象

| 操作 | 使用目的 |
|------|---------|
| `global_action_buttons` 直接参照 | チュートリアルオーバーレイ設定 |
| `card_selection_ui` 直接参照 | カード選択監視 |
| `level_up_selected` signal | レベルアップ監視 |
| `show_dominio_order_button()` | ドミニオボタン表示 |

**解決策候補**: TutorialService を新設、または UIManager にチュートリアル用 API を追加。

#### 11. explanation_mode.gd（22 refs）— Phase 9 対象

tutorial_manager.gd と同じパターン。`global_action_buttons.explanation_mode_active` の直接操作が中心。

#### 12. game_result_handler.gd（10 refs）— Phase 9 対象

| 操作 | 使用目的 |
|------|---------|
| `show_win_screen()` | 勝利画面表示 |
| `show_win_screen_async()` | 勝利画面表示（await） |
| `show_lose_screen_async()` | 敗北画面表示（await） |

**解決策候補**: GameResultService を新設、または Signal 化。

#### 13. spell_world_curse.gd（6 refs）— Phase 9 対象

`update_player_info_panels()` 1回のみ。PlayerInfoService 新設後に移行。

#### 14. tile_battle_executor.gd（4 refs）— Phase 9 対象

`update_player_info_panels()` 1回のみ。spell_world_curse と同じ。

---

## 推奨実行順序

### Phase 8 継続（サービス注入パターン）

| 順序 | サブフェーズ | 対象 | refs | 作業量 | 前提 |
|------|-----------|------|------|--------|------|
| 1 | **8-N** | spell_target_selection_handler | 28 | 低 | なし |
| 2 | **8-N** | land_selection_helper | 9 | 低 | なし |
| 3 | **8-O** | spell_mystic_arts | 46 | 中 | なし |
| 4 | **8-O** | debug_controller | 31 | 低 | なし |
| | | **Group A 合計** | **114** | | |

### Phase 8-M: card_selected emission chain 統一（前提作業）

**制約 3 適用**: 一括置換禁止。1ファイルずつ動作確認。

| 順序 | 内容 | 作業量 | 検証 |
|------|------|--------|------|
| 5a | card_selection_ui.gd: emit 先を CardSelectionService に変更 | 中 | カード選択基本動作 |
| 5b | UIManager.card_selected を CardSelectionService からリレー（後方互換） | 低 | 既存の await が壊れないことを確認 |
| 5c | UIManager.on_card_button_pressed の emit 先変更 | 低 | カードボタン押下動作 |

**検証チェックリスト（5a-5c 完了後）**:
- [ ] スペルフェーズでカード選択 → 決定
- [ ] スペルフェーズでカード選択 → キャンセル
- [ ] 召喚時のカード選択
- [ ] 犠牲カード選択
- [ ] ドミニオコマンドのレベルアップ

### Phase 8-M → 8-P: 1ファイルずつ移行（制約 3）

| 順序 | サブフェーズ | 対象 | refs | 作業量 |
|------|-----------|------|------|--------|
| 6 | **8-P** | spell_borrow | 13 | 低 |
| 7 | **8-P** | card_sacrifice_helper | 12 | 低 |
| 8 | **8-P** | tile_summon_executor | 13 | 低 |
| 9 | **8-P** | spell_creature_swap | 30 | 中 |
| | | **Group B 合計** | **68** | |

### Phase 8 区切りライン

**Phase 8 完了時の状態予測**:
- 移行済み refs: ~180（Group A 114 + Group B 68 のうちサービス化分）
- 残存 ui_manager refs: Group C の 96 refs + 各ファイルの UIManager 固有操作
- 全ファイル中 ui_manager 完全排除: battle_system（Phase 8-E で達成済み）

---

## Phase 9: UIManager 自体の改修（将来計画）

### 新サービス作成が必要なもの

| サービス候補 | カバー範囲 | 影響ファイル | 優先度 |
|------------|----------|------------|--------|
| **PlayerInfoService** | update_player_info_panels | spell_world_curse, tile_battle_executor, tile_summon_executor, debug_controller, land_action_helper, card_selection_handler, dominio_command_handler, cpu_turn_processor | 高（最頻出の残存参照）**制約 2 適用: 描画更新のみ、ロジック判定禁止** |
| **TapTargetService** | tap_target_manager 操作 | spell_mystic_arts, spell_target_selection_handler | 中 |
| **GameResultService** | show_win/lose_screen | game_result_handler | 低（1ファイルのみ） |

### アーキテクチャ変更が必要なもの

| 課題 | 対象 | 解決策候補 |
|------|------|----------|
| card.gd の find_ui_manager_recursive | card.gd (32 refs) | Card → Signal 化、CardSelectionService 注入 |
| tutorial/explanation の UIコンポーネント直接参照 | tutorial_manager, explanation_mode (44 refs) | TutorialService 新設 or UIManager API 追加 |
| UIManager.set_message() | spell_borrow, card_sacrifice_helper, spell_creature_swap | MessageService に追加 or 廃止 |
| toggle_debug_mode() | debug_controller | DebugService 新設 or 現状維持 |

---

## UIManager 未サービス化メソッド一覧

Phase 8 で「UIManager 固有」として残したメソッド・プロパティの全量:

| メソッド/プロパティ | 使用ファイル数 | サービス化候補 |
|-------------------|-------------|--------------|
| `update_player_info_panels()` | 8+ | PlayerInfoService |
| `tap_target_manager` | 2 | TapTargetService |
| `show_win_screen()` / `show_win_screen_async()` | 1 | GameResultService |
| `show_lose_screen_async()` | 1 | GameResultService |
| `toggle_debug_mode()` | 1 | DebugService |
| `set_message()` | 3 | MessageService 拡張 |
| `show_action_menu()` | 1 | DominioService |
| `show_dominio_order_button()` / `hide_*` | 3 | DominioService |
| `dominio_order_ui` 直接参照 | 1 (DCH) | DominioService |
| `card_selection_ui.deactivate()` | 1 | CardSelectionService 拡張 |
| `card_selection_ui.selection_mode` | 1 (card.gd) | CardSelectionService |
| `card_selection_ui.enable_card_selection()` | 1 | CardSelectionService 拡張 |
| `on_card_button_pressed()` | 1 (card.gd) | Signal 化 |
| `hand_display` 直接参照 | 2 | CardSelectionService 拡張 |
| `global_action_buttons` 直接参照 | 2 (tutorial) | NavigationService 拡張 or TutorialService |
| `level_up_selected` signal | 1 (tutorial) | Signal リレー |
| `show_level_up_ui()` / `hide_level_up_ui()` | 1 (TAP) | LevelUpService |
| `show_level_selection()` | 1 (LAH) | LevelUpService |
| `ui_layer.add_child()` | 1 (game_menu) | UIManager 内部 |
| `add_child()` (misc) | 2 | UIManager 内部 |
| `game_flow_manager_ref` | 1 (card.gd) | 設計変更 |

---

## Phase 8 完了済みサブフェーズ（参考）

| サブフェーズ | 内容 | 実施日 |
|------------|------|--------|
| 8-F | UIManager 内部4サービス分割 | 2026-02-18 |
| 8-A | ItemPhaseHandler Signal化（ui_manager完全削除） | 2026-02-18 |
| 8-B | DominioCommandHandler サービス注入（90→49） | 2026-02-18 |
| 8-I | タイル系6ファイル context経由サービス注入 | 2026-02-18 |
| 8-K | 移動系3ファイル サービス注入 | 2026-02-18 |
| 8-E | 兄弟システム4ファイル サービス注入 | 2026-02-18 |
| 8-G | CSH + LAH サービス注入 | 2026-02-18 |
| 8-J | Spell系3ファイル サービス注入 | 2026-02-18 |
| 8-L | 小規模3ファイル サービス注入 | 2026-02-18 |
