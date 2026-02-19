# リファクタリング今後の作業計画

**最終更新**: 2026-02-19
**前提**: Phase 0〜9 完了済み（詳細は `refactoring_next_steps_1.md`）

---

## 現状サマリー

### UIManager の状態（Phase 9 後）

- **行数**: ~970行、93メソッド
- **4サービス分割済み**: NavigationService, MessageService, CardSelectionService, InfoPanelService（計551行）
- **状態ルーター**: ✅ 解体済み（Phase 9）
- **後方参照**: 5件（GFM, BoardSystem, DCH, CardSystem, PlayerSystem）
- **委譲メソッド**: 47個（Facade残存）

### 残存する問題

| 問題 | 規模 | 影響 | 状態 |
|------|------|------|------|
| `update_player_info_panels()` がUIManager経由 | 16ファイル、26箇所 | UIManagerを経由する最大理由 | ✅ 解消（PlayerInfoService化） |
| card.gd の再帰的親探索 | 13箇所、find_ui_manager_recursive | 構造的アンチパターン | ✅ 解消（Signal駆動化） |
| Facade 47委譲メソッド | 47メソッド | UIManager肥大の主因 | 🔄 Phase 10-D で再評価予定 |
| 双方向参照 | GFM, BoardSystem | 依存方向の違反 | ✅ 解消（Callable注入、初期化時のみ許容） |

---

## 改善提案（優先順位順）

### Phase 10-A: update_player_info_panels のサービス化 ✅ 完了

**完了日**: 2026-02-19
**成果**: PlayerInfoService 新規作成、16ファイル・23箇所変更、UIManager Facadeメソッド削除

**実装内容**:
- `PlayerInfoService` 新規作成（scripts/ui_services/player_info_service.gd）
- 描画更新のみの責務でサービス化
- 16ファイルから呼び出し元を `_player_info_service.update_panels()` に統一
- BankruptcyHandler Signal 受信を PlayerInfoService 経由に変更
- UIManager の `update_player_info_panels()` Facade メソッド削除

**設計制約**: PlayerInfoService は**描画更新（render）だけ**に限定。「誰が勝っているか」「EPは足りるか」等の判定は絶対に持たせない。

---

### Phase 10-B: card.gd の再帰的親探索廃止 ✅ 完了

**完了日**: 2026-02-19
**成果**: find_ui_manager_recursive 完全削除、Signal 2追加、3参照変数注入、card.gd UIManager 依存ゼロ

**現状**: `find_ui_manager_recursive(get_tree().get_root())` でシーンツリー全体を毎回再帰探索。card.gd から UIManager を13箇所で参照。

| 用途 | 箇所数 | 参照先 |
|------|--------|--------|
| card_selection_filter 判定 | 4 | UIManager → CardSelectionService |
| on_card_button_pressed() 呼び出し | 1 | UIManager → 入力ディスパッチャー |
| game_flow_manager_ref 取得 | 2 | UIManager → GFM |
| show_card_info() | 1 | UIManager → InfoPanelService |
| card_selection_ui 参照 | 2 | UIManager → CardSelectionUI |
| player_status_dialog | 1 | UIManager → PlayerStatusDialog |
| show_dominio_order_button | 1 | UIManager |

**方針候補**:
- **A) Signal 駆動化（推奨）**: card.gd は `card_confirmed(card_index)` Signal を emit するだけ。CardSelectionService がリスニング
- **B) CardSelectionService 注入**: Hand表示時に各カードに CardSelectionService を set

**注意**: card.gd はシーンからインスタンス化されるため、通常の `setup()` 注入にタイミング問題がある。Signal 駆動が最もクリーン。

**前提**: Phase 10-A が先に完了していること（参照先の整理が必要）

---

### Phase 10-C: 双方向参照の削減 ✅ 完了

**完了日**: 2026-02-19
**成果**: UIManagerランタイム双方向参照ゼロ、外部チェーンアクセス13箇所→0箇所、Signal 1追加、Callable 11追加

**実装内容**:
- `dominio_command_handler_ref` 完全削除
- `game_flow_manager_ref` ランタイム3箇所 → Callable注入（is_input_locked, spell_card_selecting, on_card_selected）
- `board_system_ref` ランタイム3箇所 → Callable注入（has_owned_lands, update_tile_display）
- 外部チェーンアクセス13箇所を Callable 直接注入で除去（CardSelectionHandler, UIGameMenuHandler, UITapHandler）
- Signal `dominio_cancel_requested` → DCH.cancel() 接続
- GSM `_setup_ui_callbacks()` メソッド新設（一括注入管理）
- **潜在バグ修正**: DominioOrderUI DCH null参照（初期化順序問題）

**設計判断**: `game_flow_manager_ref` と `board_system_ref` は初期化時参照として残留（ランタイム使用ゼロ）

---

### Phase 10-D: UIManager デッドコード削除 ✅ 完了

**完了日**: 2026-02-19
**成果**: 12メソッド削除、65行削減、UIManager: 1030行 → 965行

**実装内容**:

UIManager 削除メソッド（7個）:
1. `update_cpu_hand_display()` — 呼び出し元ゼロ
2. `restore_spell_phase_buttons()` — 呼び出し元ゼロ（ラッパー）
3. `set_card_selection_filter()` — 呼び出し元ゼロ（プロパティ直接設定に移行済み）
4. `clear_card_selection_filter()` — 呼び出し元ゼロ（debug_controllerはサービス版を使用）
5. `show_land_selection_mode()` — 呼び出し元ゼロ
6. `show_action_selection_ui()` — 呼び出し元ゼロ（`show_action_menu`ラッパー）
7. `hide_dominio_order_ui()` — 呼び出し元ゼロ

連鎖デッドコード 削除（5個）:
8. `dominio_order_ui.show_land_selection_mode()`
9. `dominio_order_ui.show_action_selection_ui()`
10. `dominio_order_ui.hide_dominio_order_ui()`
11. `navigation_service.restore_spell_phase_buttons()`
12. `card_selection_service.set_card_selection_filter()`

---

## 推奨実行順序

| 順番 | Phase | 内容 | 理由 |
|------|-------|------|------|
| 1 | **10-A** ✅ | update_player_info_panels サービス化 | 効果大・難易度低、即座に着手可能 |
| 2 | **10-B** ✅ | card.gd 再帰探索廃止 | Signal駆動化で完了 |
| 3 | **10-C** ✅ | 双方向参照の削減 | Callable注入で完了 |
| 4 | **10-D** ✅ | UIManager デッドコード削除 | 12メソッド削除、65行削減 |

---

## 未対応の技術的負債（優先度低）

| 項目 | 内容 | 備考 |
|------|------|------|
| 8-H | UIコンポーネント逆参照除去 | 規約変更で大部分不要 |
| 8-C | BankruptcyHandler パネル分離 | 56行、機能問題なし |
| tutorial系 | tutorial_manager, explanation_mode の UIManager 直接参照 | チュートリアル再設計が前提 |
| set_message() | spell_borrow, card_sacrifice_helper, spell_creature_swap で使用 | MessageService 拡張で対応可能 |
| tap_target_manager | spell_mystic_arts, spell_target_selection_handler で参照 | TapTargetService 新設候補 |
