# グローバルナビゲーションボタン設計ガイド

## 概要

グローバルナビゲーションボタンは、ゲーム全体で統一されたユーザー入力を提供するUIコンポーネントです。画面右下に固定配置され、各フェーズで必要なボタンのみが表示されます。

## ボタン構成

### 右下ボタン群（縦並び）
| ボタン | アイコン | 色 | キーボード | 用途 |
|--------|----------|-----|------------|------|
| 上 | ▲ | 青 | ↑ | 選択肢を上へ移動 |
| 下 | ▼ | 青 | ↓ | 選択肢を下へ移動 |
| 決定 | ✓ | 緑 | Enter | 選択確定、実行 |
| 戻る | ✕ | 赤 | ESC | キャンセル、前の状態へ |

### 左下特殊ボタン
| ボタン | 色 | 用途 |
|--------|-----|------|
| 特殊 | 紫（ゴールド縁） | アルカナアーツ / ドミニオコマンド |

**特殊ボタンの特徴**:
- テキストは動的に変更（「アルカナアーツ」「ドミニオコマンド」等）
- コールバックが無効な場合は非表示
- `setup_special(text, callback)` で設定、`clear_special()` でクリア

## アーキテクチャ

```
[各システム/ハンドラー]
		↓
   [UIManager]  ← 統一的なAPI
		↓
[GlobalActionButtons]  ← 実際のUI表示
```

## 基本API

### 推奨API（新規実装用）

```gdscript
# ナビゲーション設定
ui_manager.enable_navigation(
	confirm_callback,  # Callable - 決定ボタン
	back_callback,     # Callable - 戻るボタン
	up_callback,       # Callable - 上ボタン
	down_callback      # Callable - 下ボタン
)

# 全ボタン無効化
ui_manager.disable_navigation()

# 特殊ボタン設定（アルカナアーツ/ドミニオコマンド）
ui_manager.setup_special_button("アルカナアーツ", func(): open_arcana_arts())
ui_manager.clear_special_button()
```

### Callableの指定方法

```gdscript
# 有効なCallable → ボタン表示
func(): do_something()

# 無効なCallable → ボタン非表示
Callable()
```

### 使用例

```gdscript
# 全ボタン表示（選択系フェーズ）
ui_manager.enable_navigation(
	func(): confirm_selection(),
	func(): cancel(),
	func(): select_previous(),
	func(): select_next()
)

# 戻るボタンのみ（メニュー表示中）
ui_manager.enable_navigation(
	Callable(),        # 決定なし
	func(): close_menu()  # 戻るのみ
)

# 決定と戻るのみ（確認ダイアログ）
ui_manager.enable_navigation(
	func(): execute_action(),
	func(): cancel_action()
)

# 終了時にクリア
ui_manager.disable_navigation()
```

## 設計パターン

### パターン1: フェーズ遷移時に設定

各フェーズに入る時点でナビゲーションを設定します。

```gdscript
func enter_selection_phase():
	# 状態を変更
	current_state = State.SELECTING
	
	# UIを表示
	show_selection_ui()
	
	# ナビゲーション設定（最後に実行）
	ui_manager.enable_navigation(
		func(): confirm(),
		func(): cancel(),
		func(): move_up(),
		func(): move_down()
	)
```

### パターン2: 状態管理関数で一元化

```gdscript
func set_state(new_state: State):
	current_state = new_state
	_update_navigation_for_state()

func _update_navigation_for_state():
	match current_state:
		State.IDLE:
			ui_manager.disable_navigation()
		State.SELECTING:
			ui_manager.enable_navigation(
				func(): confirm(), func(): cancel(),
				func(): move_up(), func(): move_down()
			)
		State.CONFIRMING:
			ui_manager.enable_navigation(
				func(): execute(), func(): cancel()
			)
```

## 入力ロック機能

ボタン連打防止のため、GameFlowManagerと連携した入力ロック機能を持つ。

### 動作
- 決定/戻る/特殊ボタン押下時に `game_flow_manager.lock_input()` を呼び出し
- 入力ロック中は全ボタンが無効化
- `game_flow_manager.unlock_input()` で解除

### 説明モード対応
チュートリアル等の説明モード中は入力ロックを無視する。

```gdscript
# 説明モード中はロックを無視
global_action_buttons.explanation_mode_active = true
```

---

## 重要な注意点

### 1. 処理順序

**UIを更新してから最後にナビゲーション設定**

一部のUI非表示処理（hide_selection()等）は内部でボタンをクリアします。
ナビゲーション設定は必ず最後に行ってください。

```gdscript
# ❌ 悪い例
ui_manager.enable_navigation(...)  # 先に設定
card_selection_ui.hide_selection()  # ここでクリアされる！

# ✓ 良い例
card_selection_ui.hide_selection()  # 先にUIをクリア
ui_manager.enable_navigation(...)  # 最後に設定
```

### 2. 後方互換APIとの競合

後方互換API（register_back_action等）は内部で同じボタンを操作します。
新規実装では`enable_navigation()`のみを使用してください。

```gdscript
# 後方互換API（既存コード用、新規使用非推奨）
ui_manager.register_back_action(callback, text)
ui_manager.register_confirm_action(callback, text)
ui_manager.clear_back_action()
ui_manager.clear_global_actions()
```

### 3. コールバック内でのself参照

ラムダ内でselfを参照する場合、オブジェクトが有効か確認してください。

```gdscript
# 安全な書き方
ui_manager.enable_navigation(
	func(): 
		if is_instance_valid(self):
			confirm()
)
```

### 4. フェーズ終了時のクリア

システムを完全に閉じる時は`disable_navigation()`を呼んでください。

```gdscript
func close_system():
	# 状態をリセット
	current_state = State.IDLE
	
	# UIを非表示
	hide_all_ui()
	
	# ナビゲーションをクリア
	ui_manager.disable_navigation()
```

## 典型的なフェーズ構成

### 選択系フェーズ

リストや選択肢から選ぶ場合：

| ボタン | 動作 |
|--------|------|
| 決定 | 選択確定 |
| 戻る | 前の状態へ/キャンセル |
| 上下 | 選択肢を移動 |

### メニュー表示フェーズ

メニューやダイアログ表示中：

| ボタン | 動作 |
|--------|------|
| 戻る | メニューを閉じる |

### 確認フェーズ

アクション実行前の確認：

| ボタン | 動作 |
|--------|------|
| 決定 | 実行 |
| 戻る | キャンセル |

## 実装チェックリスト

新しいシステムでナビゲーションを使う際：

- [ ] フェーズ遷移時に`enable_navigation()`を呼んでいるか
- [ ] UI更新の後にナビゲーション設定しているか
- [ ] システム終了時に`disable_navigation()`を呼んでいるか
- [ ] 後方互換APIを混在させていないか
- [ ] 各ボタンのコールバックが正しいか

---

## 通知ポップアップ（GlobalCommentUI）

グローバルなメッセージ表示UI。スペル効果、周回ボーナス等で使用。

### 基本API

```gdscript
# クリック待ち表示（スペル効果、周回完了等）
await ui_manager.global_comment_ui.show_and_wait("メッセージ")
await ui_manager.global_comment_ui.click_confirmed

# 自動フェード表示（即時通知等）
ui_manager.global_comment_ui.show_auto_fade("メッセージ", 2.0, "bottom")
```

### 特徴

- 専用CanvasLayer（layer=100）で最前面に表示
- クリック待ち中は他のUI入力をブロック
- BBCode対応（`[color=yellow]テキスト[/color]`等）

### 使用例

```gdscript
# 周回完了時の4段階表示
await ui_manager.global_comment_ui.show_and_wait("[color=yellow]1周完了[/color]")
await ui_manager.global_comment_ui.click_confirmed
await ui_manager.global_comment_ui.show_and_wait("[color=cyan]周回ボーナス 336G[/color]")
await ui_manager.global_comment_ui.click_confirmed
```

---

## ナビゲーション状態の保存/復元（NavigationService）

クリーチャー情報パネルなどを「閲覧モード」で開く際、現在のナビゲーション状態を一時保存し、パネルを閉じた時に自動復元する仕組みがあります。

### 仕組み

```
[土地選択中: ○×▲▼ボタンあり]
    ↓ クリーチャーをタップ
[save_navigation_state()] ← 今のボタン状態を記憶
    ↓
[情報パネル表示: ×ボタンのみ（閉じる）]
    ↓ ×を押す
[restore_navigation_state()] ← 記憶した状態を復元
    ↓
[土地選択中: ○×▲▼ボタン復帰]
```

### 主要メソッド（NavigationService）

| メソッド | 役割 |
|---------|------|
| `save_navigation_state()` | 現在のコールバック4つ+特殊ボタンを保存。既に保存済みなら上書きしない |
| `restore_navigation_state()` | 保存した状態を復元し、保存フラグをクリア |
| `clear_navigation_saved_state()` | 保存状態を破棄（フェーズ完全終了時に使用） |
| `is_nav_state_saved()` | 保存状態があるかチェック |

### info_panel_back_locked（×ボタン保護）

情報パネルの「閉じる」ボタンが設定された後、他のコードが `enable_navigation()` / `disable_navigation()` で上書きするのを防ぐロック機構。

```gdscript
lock_info_panel_back()    # ロック開始（パネル表示後）
unlock_info_panel_back()  # ロック解除（パネル非表示時）
```

ロック中は `enable_navigation()` / `disable_navigation()` がスキップされます。

### restore_current_phase() のフォールバック

`restore_navigation_state()` で復元できない場合（保存がない場合）、UIManagerの `restore_current_phase()` がフォールバック処理を行います。

フォールバックの優先順位：
1. ドミニオコマンド中 → `dominio_command_handler.restore_navigation()`
2. カード選択UI中 → `card_selection_ui.restore_navigation()`
3. スペルターゲット選択中 → ターゲット選択UIを復元

---

## ドミニオコマンドでのナビゲーション

### 状態遷移とボタン設定

```
CLOSED → SELECTING_LAND → SELECTING_ACTION → (各アクション状態)
```

| 状態 | ボタン構成 | 設定元 |
|------|-----------|--------|
| SELECTING_LAND | ○×▲▼（決定/戻る/前の土地/次の土地） | `_set_land_selection_navigation()` |
| SELECTING_ACTION | アクションメニューが管理 | `ActionMenuUI.show_menu()` |
| SELECTING_LEVEL | ×▲▼（戻る/前レベル/次レベル） | `restore_navigation()` |
| SELECTING_MOVE_DEST | ○×▲▼（決定/戻る/前/次） | `restore_navigation()` |
| SELECTING_TERRAIN | ○×▲▼（決定/戻る/前/次） | `restore_navigation()` |
| SELECTING_SWAP | ×のみ（戻る） | `restore_navigation()` |

### 重要な実装ルール

#### 1. アクションメニュー表示時のクリーチャー情報は `show_card_info_only` を使う

アクションメニュー（`dominio_order_ui.show_action_menu()`）では、選択中の土地のクリーチャー情報を表示しますが、ナビゲーションはアクションメニュー自身が管理します。

```gdscript
# ✓ 正しい — ナビに触らない表示のみ
ui_manager_ref.show_card_info_only(creature, tile_index)

# ❌ 間違い — ナビ保存+awaitが発生し、メニューのenable_navigationと競合
ui_manager_ref.show_card_info(creature, tile_index, false)
```

`show_card_info()` は内部に `await get_tree().process_frame`（iOS Metal対策の1フレーム待ち）があり、その待ち時間中に `show_menu()` の `enable_navigation()` が割り込み実行されます。この順序衝突が「ボタンが消える」バグの原因でした。

#### 2. アクション失敗時はメニューを再表示する

`execute_action()` が失敗した場合（移動先なし、最大レベル等）、アクションメニューを再表示して選び直せるようにします。

```gdscript
# ✓ 正しい — メニューUIとナビゲーションが両方復帰
if not success:
    _dominio_order_ui.show_action_menu(selected_tile_index)

# ❌ 間違い — ナビだけ設定してメニューUIが出ない
if not success:
    set_action_selection_navigation()
```

#### 3. キャンセル時の流れ

アクションメニューから土地選択に戻る流れ:

```
×ボタン押下
  → ActionMenuUI._cancel_selection()
    → hide_menu() → disable_navigation()
    → item_selected.emit(-1)
  → dominio_order_ui._on_action_menu_item_selected(-1)
    → dominio_cancel_requested.emit()
  → dominio_command_handler.cancel()
    → hide_action_menu(false) → パネル非表示
    → preview_land() → クリーチャー情報再表示
    → _set_land_selection_navigation() → ○×▲▼ボタン復帰
```

### BUG-001: enable_navigation での保存状態破壊（修正済み）

**発生日**: 2026-04-10
**症状**: ドミニオコマンドのアクションメニューから土地選択に戻ると、グローバルボタンが全て消える
**原因**: `enable_navigation()` 内の `_nav_state_saved = false` が、`show_card_info()` の `await` 中に呼ばれることで保存済みナビゲーション状態を破壊していた
**修正**: `enable_navigation()` から `_nav_state_saved = false` を削除。保存状態のクリアは `restore_navigation_state()` と `clear_navigation_saved_state()` のみに限定

---

## 関連ファイル

- `scripts/ui_components/global_action_buttons.gd` - ボタンUI実装
- `scripts/ui_services/navigation_service.gd` - ナビゲーション状態管理（保存/復元/ロック）
- `scripts/ui_components/global_comment_ui.gd` - 通知ポップアップUI実装
- `scripts/ui_manager.gd` - API提供（enable_navigation, restore_current_phase等）
- `scripts/game_flow/dominio_command_handler.gd` - 使用例（ドミニオコマンド）
- `scripts/ui_components/dominio_order_ui.gd` - アクションメニューUI
- `scripts/ui_components/action_menu_ui.gd` - 汎用アクションメニュー
- `scripts/game_flow/lap_system.gd` - 使用例（周回完了通知）

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/12/12 | 1.0 | 初版作成 |
| 2026/02/12 | 1.1 | 特殊ボタン追加、入力ロック機能追加、説明モード対応追加 |
| 2026/04/10 | 1.2 | NavigationService保存/復元機構、ドミニオコマンド注意点、BUG-001記録追加 |

---

**最終更新**: 2026年4月10日（v1.2）
