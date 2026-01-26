# 入力ロック機能リファクタリング計画

**バージョン**: 1.1  
**作成日**: 2025年12月14日  
**ステータス**: 実装完了

---

## 📋 目次

1. [現状の問題](#現状の問題)
2. [解決策の概要](#解決策の概要)
3. [入力経路の分析](#入力経路の分析)
4. [影響を受けるファイル](#影響を受けるファイル)
5. [実装詳細](#実装詳細)
6. [テスト範囲](#テスト範囲)
7. [リスクと対策](#リスクと対策)
8. [作業工数見積もり](#作業工数見積もり)

---

## 現状の問題

### 症状
- ボタン連打で同じ処理が複数回実行される
- フェーズ遷移中に別の操作が受け付けられ、状態不整合が発生
- 特に手札カードからの入力で異常が多い

### 発生箇所
- 召喚フェーズでカード連打
- アイテムフェーズでカード連打
- スペルフェーズでカード連打
- バトル中のアイテム選択
- ドミニオオーダーの各種操作

### 根本原因
- 入力受付可能な状態の管理が不十分
- 非同期処理（await）中の入力ガードがない
- GlobalActionButtonsと手札入力が別経路で、統一的なロック機構がない

---

## 解決策の概要

### アプローチ
`GameFlowManager`に入力ロック機能を集約し、全ての入力経路でチェックする。

### 基本設計
```
入力発生
  → 入力経路（手札 or ボタン）
	→ ロックチェック（GameFlowManager.is_input_locked()）
	  → ロック中なら無視
	  → 解除中なら処理実行
```

### ロック/アンロックのタイミング
- **ロック**: 処理開始時（カード選択確定、ボタン押下時）
- **アンロック**: 処理完了時（次の入力待ち状態になった時）

---

## 入力経路の分析

### 1. 手札カード入力経路
```
card.gd (_input / クリック検出)
  ↓
card.gd (on_card_confirmed)
  ↓
UIManager._on_card_button_pressed(card_index)    ← ★ロックチェック挿入点
  ↓
CardSelectionUI.on_card_selected(card_index)
  ↓
[情報パネル表示 or emit_signal("card_selected")]
  ↓
UIManager._on_card_ui_selected()
  ↓
UIManager.emit_signal("card_selected")
  ↓
GameFlowManager.on_card_selected(card_index)     ← ★ロックチェック挿入点（二重チェック）
```

### 2. GlobalActionButtons入力経路
```
GlobalActionButtons (ボタンクリック / キー入力)
  ↓
_on_confirm_pressed() / _on_back_pressed() 等    ← ★ロックチェック挿入点
  ↓
コールバック実行
```

### 3. タイル選択入力経路（スペルターゲット等）
```
Tile3D (クリック)
  ↓
BoardSystem3D.on_tile_selected()
  ↓
各Handler（SpellPhaseHandler等）                  ← ★ロックチェック挿入点
```

---

## 影響を受けるファイル

### 必須変更（コア）

| ファイル | 変更内容 | 影響度 |
|---------|---------|-------|
| `scripts/game_flow_manager.gd` | ロック機能追加（lock/unlock/is_locked） | 低 |
| `scripts/ui_manager.gd` | `_on_card_button_pressed`にロックチェック追加 | 低 |
| `scripts/ui_components/global_action_buttons.gd` | 各`_on_*_pressed`にロックチェック追加 | 低 |

### 必須変更（ロック呼び出し箇所）

| ファイル | 変更内容 | 影響度 |
|---------|---------|-------|
| `scripts/ui_components/card_selection_ui.gd` | カード選択確定時にロック | 中 |
| `scripts/game_flow/dominio_order_handler.gd` | コマンド実行時にロック/アンロック | 中 |
| `scripts/game_flow/item_phase_handler.gd` | アイテム使用時にロック/アンロック | 中 |
| `scripts/game_flow/spell_phase_handler.gd` | スペル使用時にロック/アンロック | 中 |
| `scripts/tile_action_processor.gd` | バトル開始時にロック/アンロック | 中 |

### 確認が必要（await使用箇所）

以下のファイルで`await`を使用しており、ロック/アンロックの検討が必要：

| ファイル | await使用数 | 主な用途 |
|---------|------------|---------|
| `spell_phase_handler.gd` | 15箇所 | ターゲット選択待ち、エフェクト実行 |
| `spell_effect_executor.gd` | 20箇所 | スペル効果適用、タイマー |
| `card_selection_handler.gd` | 8箇所 | カード選択待ち |
| `spell_borrow.gd` | 10箇所 | 借用スペル処理 |
| `spell_creature_move.gd` | 8箇所 | 移動先選択待ち |
| `dominio_order_handler.gd` | 3箇所 | バトル実行 |
| `land_action_helper.gd` | 2箇所 | バトル実行 |
| `item_phase_handler.gd` | 2箇所 | UI表示待ち |

---

## 実装詳細

### Phase 1: コア機能実装

#### 1.1 GameFlowManager にロック機能追加
```gdscript
# scripts/game_flow_manager.gd

var _input_locked: bool = false
var _input_lock_reason: String = ""  # デバッグ用

func lock_input(reason: String = ""):
	_input_locked = true
	_input_lock_reason = reason
	if reason:
		print("[InputLock] LOCKED: ", reason)

func unlock_input():
	if _input_locked:
		print("[InputLock] UNLOCKED (was: ", _input_lock_reason, ")")
	_input_locked = false
	_input_lock_reason = ""

func is_input_locked() -> bool:
	return _input_locked

# 安全なアンロック（タイムアウト付き）- オプション
func unlock_input_after(seconds: float):
	await get_tree().create_timer(seconds).timeout
	if _input_locked:
		print("[InputLock] TIMEOUT UNLOCK")
		unlock_input()
```

#### 1.2 UIManager にロックチェック追加
```gdscript
# scripts/ui_manager.gd

func _on_card_button_pressed(card_index: int):
	# ロックチェック
	if game_flow_manager_ref and game_flow_manager_ref.is_input_locked():
		print("[InputLock] Card input ignored (locked)")
		return
	
	if card_selection_ui and card_selection_ui.has_method("on_card_selected"):
		card_selection_ui.on_card_selected(card_index)
```

#### 1.3 GlobalActionButtons にロックチェック追加
```gdscript
# scripts/ui_components/global_action_buttons.gd

var game_flow_manager_ref = null  # 参照追加

func _is_input_locked() -> bool:
	if game_flow_manager_ref and game_flow_manager_ref.has_method("is_input_locked"):
		return game_flow_manager_ref.is_input_locked()
	return false

func _on_confirm_pressed():
	if _is_input_locked():
		return
	if _confirm_callback.is_valid():
		_confirm_callback.call()

func _on_back_pressed():
	if _is_input_locked():
		return
	if _back_callback.is_valid():
		_back_callback.call()

# 他のボタンも同様
```

### Phase 2: ロック呼び出し実装

#### 2.1 CardSelectionUI - カード選択確定時
```gdscript
# カード選択が確定した時（情報パネル経由または直接）
func _emit_card_selected(card_index: int):
	# ロック
	if game_flow_manager_ref:
		game_flow_manager_ref.lock_input("card_selected")
	
	hide_selection()
	emit_signal("card_selected", card_index)
```

#### 2.2 各Handler - 処理完了時のアンロック

**パターンA: 次の入力待ち状態に遷移する時**
```gdscript
# 例: DominioOrderHandler
func _return_to_action_selection():
	current_state = State.SELECTING_ACTION
	_show_action_menu()
	
	# 入力待ち状態になったのでアンロック
	game_flow_manager.unlock_input()
```

**パターンB: フェーズ完了時**
```gdscript
# 例: ItemPhaseHandler
func complete_item_phase():
	current_state = State.INACTIVE
	# ... クリーンアップ処理 ...
	
	game_flow_manager.unlock_input()
	item_phase_completed.emit()
```

---

## テスト範囲

### 手動テストケース

#### TC1: 召喚フェーズ
| # | 操作 | 期待結果 |
|---|-----|---------|
| 1.1 | クリーチャーカードを連打 | 情報パネルが1回だけ表示される |
| 1.2 | 情報パネル表示中に別のカードをクリック | 無視される（or パネル切り替え） |
| 1.3 | 決定ボタンを連打 | 召喚が1回だけ実行される |
| 1.4 | 決定後すぐに戻るボタン | 無視される |

#### TC2: スペルフェーズ
| # | 操作 | 期待結果 |
|---|-----|---------|
| 2.1 | スペルカードを連打 | 情報パネルが1回だけ表示される |
| 2.2 | ターゲット選択中に別のタイルを素早くクリック | 最初のクリックのみ有効 |
| 2.3 | スペル発動中に手札をクリック | 無視される |

#### TC3: アイテムフェーズ
| # | 操作 | 期待結果 |
|---|-----|---------|
| 3.1 | アイテムカードを連打 | 情報パネルが1回だけ表示される |
| 3.2 | アイテム→クリーチャー→アイテムと素早く切り替え | パネルが正しく切り替わる |
| 3.3 | 決定ボタンを連打 | アイテム使用が1回だけ実行される |
| 3.4 | 攻撃側アイテム選択中に防衛側が操作 | 無視される |

#### TC4: ドミニオオーダー
| # | 操作 | 期待結果 |
|---|-----|---------|
| 4.1 | レベルアップボタンを連打 | レベルアップが1回だけ実行される |
| 4.2 | 交換カード選択中に別のコマンド | 無視される |
| 4.3 | 移動先選択中にキャンセルを連打 | 1回だけキャンセルされる |

#### TC5: バトルフェーズ
| # | 操作 | 期待結果 |
|---|-----|---------|
| 5.1 | バトル開始クリック連打 | バトルが1回だけ開始される |
| 5.2 | バトル演出中に操作 | 無視される |

#### TC6: フェーズ遷移
| # | 操作 | 期待結果 |
|---|-----|---------|
| 6.1 | ダイスロール中に手札クリック | 無視される |
| 6.2 | 移動アニメーション中に操作 | 無視される |
| 6.3 | ターン終了処理中に操作 | 無視される |

### 回帰テスト

以下の既存機能が正常に動作することを確認：
- [ ] 通常の召喚フロー
- [ ] 通常のスペル使用フロー（単体/全体/自分対象）
- [ ] 通常のバトルフロー（侵略/防衛）
- [ ] 通常のアイテム使用フロー（攻撃側/防衛側）
- [ ] 援護クリーチャー使用
- [ ] アイテムクリーチャー使用
- [ ] ドミニオオーダー全種（召喚/レベルアップ/交換/移動/地形変化）
- [ ] アルカナアーツ使用
- [ ] パス操作（各フェーズ）

---

## リスクと対策

### リスク1: ロック解除忘れ
**症状**: UIがフリーズし、一切操作できなくなる

**対策**:
1. デバッグログでロック状態を可視化
2. タイムアウト付きロック（5秒後に自動解除）をオプションで用意
3. デバッグキー（例: F12）で強制アンロック

```gdscript
# デバッグ用強制アンロック
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		if OS.is_debug_build():
			print("[DEBUG] Force unlock input")
			unlock_input()
```

### リスク2: ロック範囲が広すぎる
**症状**: 本来操作できるべき場面で操作できない

**対策**:
1. ロック理由を記録し、適切な場所でアンロックされているか確認
2. 段階的にロック箇所を追加（最初は最小限から）

### リスク3: 既存動作への影響
**症状**: 今まで動いていた機能が動かなくなる

**対策**:
1. 回帰テストの徹底
2. 変更は小さな単位でコミット
3. 問題発生時に切り戻しやすい設計

---

## 作業工数見積もり

### Phase 1: コア機能（1-2時間）
- GameFlowManager にロック機能追加: 30分
- UIManager にロックチェック追加: 15分
- GlobalActionButtons にロックチェック追加: 30分
- 基本動作確認: 30分

### Phase 2: ロック呼び出し実装（2-3時間）
- CardSelectionUI: 30分
- DominioOrderHandler: 30分
- ItemPhaseHandler: 30分
- SpellPhaseHandler: 45分
- TileActionProcessor: 30分
- その他のHandler: 30分

### Phase 3: テスト・調整（1-2時間）
- 手動テスト: 1時間
- バグ修正・調整: 30分-1時間

### 合計: 4-7時間

---

## 実装順序

1. **Step 1**: GameFlowManager にロック機能追加（最小限）
2. **Step 2**: UIManager._on_card_button_pressed にロックチェック追加
3. **Step 3**: GlobalActionButtons にロックチェック追加
4. **Step 4**: CardSelectionUI でカード選択確定時にロック追加
5. **Step 5**: 各Handlerの「入力待ち状態」でアンロック追加
6. **Step 6**: テスト・調整

Step 1-3 で基本的な連打防止が機能し、Step 4-5 で完全な状態管理になる。
段階的に実装可能。

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/12/14 | 1.0 | 初版作成 |
| 2025/12/14 | 1.1 | 実装完了 |

---

## 実装結果

### 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `scripts/game_flow_manager.gd` | `_input_locked`, `lock_input()`, `unlock_input()`, `is_input_locked()` ※既存 |
| `scripts/ui_manager.gd` | `_on_card_button_pressed()`にロックチェック、`enable_navigation()`等でアンロック |
| `scripts/ui_components/global_action_buttons.gd` | `_on_confirm/back/special_pressed()`でロック＆チェック |
| `scripts/ui_components/card_selection_ui.gd` | `_confirm_card_selection()`でロック、`show_selection()`でアンロック |
| `scripts/game_flow/dominio_order_handler.gd` | `open_dominio_order()`でアンロック ※既存 |

### ロック/アンロックの流れ

```
[ユーザー操作]
	↓
[ロックチェック] ← ロック中なら無視
	↓
[ロック実行] ← 操作受付時に即ロック
	↓
[処理実行]
	↓
[次の入力待ち状態へ]
	↓
[アンロック] ← UIManager.enable_navigation()等で自動解除
```

### 対象となる操作
- 決定ボタン（Enter）
- 戻るボタン（Escape）
- スペシャルボタン（ドミニオオーダー等）
- 手札カードクリック

### 対象外の操作
- 上下ボタン（連続操作が必要なため）
- 情報パネル表示中のカード切り替え（ロック前の操作）
