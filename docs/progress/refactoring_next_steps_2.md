# リファクタリング今後の作業計画

**最終更新**: 2026-02-19
**前提**: Phase 0〜10 完了済み

---

## 現状サマリー

### UIManager の状態（Phase 10 完了後）

- **行数**: 965行
- **5サービス分割済み**: NavigationService, MessageService, CardSelectionService, InfoPanelService, PlayerInfoService
- **後方参照**: ランタイム使用ゼロ（Callable注入済み）。初期化時参照のみ残存
- **デッドコード**: 12メソッド削除済み

### 適正運用分析（2026-02-19実施）

UIManager の外部参照401箇所を総点検した結果、以下の問題を特定：

| 問題分類 | 件数 | 重要度 |
|---------|------|--------|
| サブコンポーネント直接アクセス（ファサード未経由） | ~97箇所 | MEDIUM |
| Null チェック不整合 | ~10箇所 | MEDIUM |
| Node メソッド直接利用（create_tween, add_child等） | 3箇所 | LOW |
| 未使用メソッド候補 | 2箇所 | LOW |

---

## Phase 11: UIManager 適正化

### Phase 11-A: サブコンポーネント直接アクセスのファサード化

**目的**: `ui_manager.dominio_order_ui.method()` 等の3層チェーンアクセスを `ui_manager.method()` ファサードに統一

**対象**:

| コンポーネント | 直接アクセス箇所 | 主な呼び出し元 |
|--------------|----------------|---------------|
| dominio_order_ui | 12箇所 | land_action_helper.gd |
| card_selection_ui | 5箇所 | card_selection_handler.gd |
| hand_display | 6箇所 | card_selection_handler.gd |
| global_action_buttons | 4箇所 | tutorial_manager.gd 等 |

**具体的な修正パターン**:

```gdscript
# Before（3層チェーンアクセス）
handler.ui_manager.dominio_order_ui.hide_action_menu(false)
handler.ui_manager.dominio_order_ui.show_terrain_selection(...)
ui_manager.hand_display.is_enemy_card_selection_active = true
ui_manager.card_selection_ui.enable_card_selection(...)

# After（ファサード経由）
handler.ui_manager.hide_action_menu(false)
handler.ui_manager.show_terrain_selection(...)
ui_manager.set_enemy_card_selection_active(true)
ui_manager.enable_card_selection(...)
```

**ステータス**: 保留

---

### Phase 11-B: Node メソッド直接利用の整理

**目的**: UIManager の Godot Node メソッド（create_tween, get_tree, add_child）の直接利用を整理

**対象（3箇所）**:

| ファイル | コード | 問題 |
|---------|-------|------|
| ui_win_screen.gd:61 | `ui_manager.create_tween()` | UIManager を tween 親として利用 |
| ui_win_screen.gd:75 | `ui_manager.get_tree().create_timer(2.0)` | SceneTree 取得のためだけに参照 |
| dominio_command_handler.gd:217 | `ui_manager.add_child(panel)` | UIManager に子ノード追加 |

**方針**: 各呼び出し元で自身の `create_tween()` / `get_tree()` を使用するか、ui_layer への add_child に変更

**ステータス**: 保留

---

### Phase 11-C: Null チェック統一

**目的**: サービスアクセス時の null チェックパターンを統一

**対象（~10箇所）**:

```gdscript
# Before（外側チェックなし）
ui_manager.player_info_service.update_panels()

# After
if ui_manager and ui_manager.player_info_service:
	ui_manager.player_info_service.update_panels()
```

**ステータス**: 保留

---

### Phase 11-D: 未使用メソッド削除（残存分）

**目的**: Phase 10-D で見つけられなかった追加デッドコードの調査・削除

**候補**:
- `on_spell_used()` / `on_item_used()` — GFM から `has_method()` ガード付きで呼ばれているが UIManager に定義なし（呼び出し自体がデッド）
- その他の残存ファサードメソッドの再評価

**ステータス**: 保留

---

## 推奨実行順序

| 順番 | Phase | 内容 | 効果 | 規模 |
|------|-------|------|------|------|
| 1 | **11-A** | サブコンポーネント直接アクセスのファサード化 | チェーンアクセス97箇所削減 | 中 |
| 2 | **11-B** | Node メソッド直接利用の整理 | 構造的問題3箇所修正 | 小 |
| 3 | **11-C** | Null チェック統一 | 安定性向上 | 小 |
| 4 | **11-D** | 未使用メソッド削除（残存分） | コード削減 | 小 |

---

## 未対応の技術的負債（優先度低）

| 項目 | 内容 | 備考 |
|------|------|------|
| 8-C | BankruptcyHandler パネル分離 | 56行、機能問題なし |
| tutorial系 | tutorial_manager の UIManager 直接参照 | チュートリアル再設計が前提 |
| tap_target_manager | spell系ファイルから UIManager 経由参照 | TapTargetService 新設候補 |

---

## 完了済み Phase 一覧

| Phase | 内容 | 完了日 |
|-------|------|--------|
| 0〜9 | アーキテクチャ移行・UI層分離・状態ルーター解体 | 〜2026-02-19 |
| 10-A | PlayerInfoService サービス化 | 2026-02-19 |
| 10-B | card.gd 再帰的親探索廃止 | 2026-02-19 |
| 10-C | 双方向参照の削減（Callable注入） | 2026-02-19 |
| 10-D | UIManager デッドコード削除（12メソッド） | 2026-02-19 |
