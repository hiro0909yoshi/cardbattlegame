# グローバルナビゲーションボタン設計ガイド

## 概要

グローバルナビゲーションボタンは、ゲーム全体で統一されたユーザー入力を提供するUIコンポーネントです。画面右下に固定配置され、各フェーズで必要なボタンのみが表示されます。

## ボタン構成

| ボタン | アイコン | 色 | キーボード | 用途 |
|--------|----------|-----|------------|------|
| 決定 | ✓ | 緑 | Enter | 選択確定、実行 |
| 戻る | ✕ | 赤 | ESC | キャンセル、前の状態へ |
| 上 | ▲ | 青 | ↑ | 選択肢を上へ移動 |
| 下 | ▼ | 青 | ↓ | 選択肢を下へ移動 |

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

## 関連ファイル

- `scripts/ui_components/global_action_buttons.gd` - ボタンUI実装
- `scripts/ui_manager.gd` - API提供（enable_navigation等）
- `scripts/game_flow/land_command_handler.gd` - 使用例（領地コマンド）
