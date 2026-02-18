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
| card.gd の再帰的親探索 | 13箇所、find_ui_manager_recursive | 構造的アンチパターン | 🔄 Phase 10-B（未着手） |
| Facade 47委譲メソッド | 47メソッド | UIManager肥大の主因 | 🔄 Phase 10-D で再評価予定 |
| 双方向参照 | GFM, BoardSystem | 依存方向の違反 | 🔄 Phase 10-C（未着手） |

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

### Phase 10-B: card.gd の再帰的親探索廃止

**難易度**: 中〜高
**効果**: 高（構造的アンチパターンの解消）

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

### Phase 10-C: 双方向参照の削減

**難易度**: 中
**効果**: 中（依存方向の正規化）

**現状の双方向参照（2件）**:

| 参照 | UIManager側の用途 | 排除方針 |
|------|-----------------|---------|
| game_flow_manager_ref | on_card_button_pressed の入力ロック、UIコンポーネント初期化 | card.gd Signal化（10-B）で入力ロック不要に。初期化は初期化時のみなので許容 |
| board_system_ref | UIコンポーネント初期化（6箇所以上） | 初期化時参照は許容。ランタイム参照の有無を確認 |

**dominio_command_handler_ref**: dominio_order_ui 初期化のみ。初期化時に引数渡しに変更可能（低難易度）

**タイミング**: Phase 10-B（card.gd Signal化）の副産物として game_flow_manager_ref のランタイム参照が消える可能性が高い。10-B 完了後に再評価。

---

### Phase 10-D: UIManager 純粋Facade化（保留）

**難易度**: 高（47ファイル変更）
**効果**: 中（UIManager 行数削減、構造的クリーンアップ）

**現状**: 47委譲メソッドが残存。外部から `ui_manager.show_toast()` を呼ぶコードが多数。

**方針**: Phase 10-A, 10-B 完了後に残存ファサードを再評価。本当に使われているメソッドだけを洗い出し、コスト対効果で判断する。

**今すぐやらない理由**:
- 47ファイル変更のリグレッションリスク
- 効果は「関数呼び出しが1段減るだけ」
- 10-A, 10-B で自然に減る部分がある

---

## 推奨実行順序

| 順番 | Phase | 内容 | 理由 |
|------|-------|------|------|
| 1 | **10-A** | update_player_info_panels サービス化 | 効果大・難易度低、即座に着手可能 |
| 2 | **10-B** | card.gd 再帰探索廃止 | 構造的価値高、10-A完了後に着手 |
| 3 | **10-C** | 双方向参照の削減 | 10-Bの副産物として部分的に解消 |
| 保留 | **10-D** | 純粋Facade化 | 10-A/B完了後に残存ファサードを再評価してから判断 |

---

## 未対応の技術的負債（優先度低）

| 項目 | 内容 | 備考 |
|------|------|------|
| 8-H | UIコンポーネント逆参照除去 | 規約変更で大部分不要 |
| 8-C | BankruptcyHandler パネル分離 | 56行、機能問題なし |
| tutorial系 | tutorial_manager, explanation_mode の UIManager 直接参照 | チュートリアル再設計が前提 |
| set_message() | spell_borrow, card_sacrifice_helper, spell_creature_swap で使用 | MessageService 拡張で対応可能 |
| tap_target_manager | spell_mystic_arts, spell_target_selection_handler で参照 | TapTargetService 新設候補 |
