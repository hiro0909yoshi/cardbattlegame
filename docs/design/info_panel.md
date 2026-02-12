# インフォパネルシステム

**バージョン**: 1.1  
**最終更新**: 2025年12月16日

---

## 📋 目次

1. [概要](#概要)
2. [パネル一覧](#パネル一覧)
3. [クリーチャーインフォパネル](#クリーチャーインフォパネル)
4. [スペルインフォパネル](#スペルインフォパネル)
5. [アイテムインフォパネル](#アイテムインフォパネル)
6. [プレイヤーインフォパネル](#プレイヤーインフォパネル)
7. [共通設計パターン](#共通設計パターン)
8. [実装上の注意点](#実装上の注意点)

---

## 概要

インフォパネルは、カードやプレイヤーの詳細情報を表示するUIコンポーネント群。選択確認機能（決定/戻るボタン）を統合し、1クリックで情報表示→決定ボタンで確定という操作フローを実現。

**共通デザイン**:
- 左側: カード画像表示
- 右側: 詳細情報（羊皮紙風背景）
- GlobalActionButtonsと連携（決定/戻るボタン）

---

## パネル一覧

| パネル名 | シーンファイル | スクリプト | 用途 |
|---------|---------------|-----------|------|
| CreatureInfoPanel | `scenes/ui/creature_info_panel.tscn` | `creature_info_panel_ui.gd` | クリーチャー詳細表示・召喚/バトル確認 |
| SpellInfoPanel | `scenes/ui/spell_info_panel.tscn` | `spell_info_panel_ui.gd` | スペル詳細表示・使用確認 |
| ItemInfoPanel | `scenes/ui/item_info_panel.tscn` | `item_info_panel_ui.gd` | アイテム詳細表示・使用確認 |
| PlayerInfoPanel | - (コードで生成) | `player_info_panel.gd` | プレイヤーステータス表示 |

---

## クリーチャーインフォパネル

**詳細設計**: [card_info_panels.md](card_info_panels.md#クリーチャー情報パネル)

### 用途
- **召喚フェーズ**: 召喚するクリーチャーの確認
- **バトルフェーズ**: バトルに出すクリーチャーの確認
- **交換フェーズ**: 交換するクリーチャーの確認
- **アイテムフェーズ**: アイテムクリーチャー/援護クリーチャーの確認
- **閲覧モード**: 盤面上のクリーチャー情報表示（ターゲット選択時など）

### 表示内容
- 名前 + レアリティ
- 属性
- コスト（MP + 必要土地）
- AP / HP
- 能力テキスト

### ファイル
- **シーン**: `scenes/ui/creature_info_panel.tscn`
- **スクリプト**: `scripts/ui_components/creature_info_panel_ui.gd`

### 主要メソッド
```gdscript
# 選択モード（召喚/バトル時）- 決定/戻るボタン付き
show_selection_mode(creature_data: Dictionary, confirmation_text: String)

# 閲覧モード（情報表示のみ）- 戻るボタンのみ
show_view_mode(creature_data: Dictionary, tile_index: int, setup_buttons: bool)

# パネルを閉じる
hide_panel(clear_buttons: bool = true)
```

### シグナル
- `selection_confirmed(card_data)` - 決定時
- `selection_cancelled` - キャンセル時
- `panel_closed` - パネル閉じた時

### 呼び出し元
- `CardSelectionUI._show_creature_info_panel()` - 召喚/バトル用
- `CardSelectionUI._show_creature_info_panel_for_item()` - アイテムフェーズ用
- `SpellTargetSelection` - ターゲット選択時の閲覧用
- `LandActionHelper` - 移動先選択時の閲覧用

---

## スペルインフォパネル

**詳細設計**: [card_info_panels.md](card_info_panels.md#スペル情報パネル)

### 用途
- **スペルフェーズ**: 使用するスペルの確認

### 表示内容
- 名前 + レアリティ
- コスト
- スペルタイプ（対象タイプ）
- 効果テキスト

### ファイル
- **シーン**: `scenes/ui/spell_info_panel.tscn`
- **スクリプト**: `scripts/ui_components/spell_info_panel_ui.gd`

### 主要メソッド
```gdscript
# スペル情報パネルを表示（使用確認モード）
show_spell_info(spell_data: Dictionary, hand_index: int = -1)

# パネルを閉じる
hide_panel(clear_buttons: bool = true)
```

### シグナル
- `selection_confirmed(card_data)` - 決定時
- `selection_cancelled` - キャンセル時
- `panel_closed` - パネル閉じた時

### 呼び出し元
- `CardSelectionUI._show_spell_info_panel()` - スペルフェーズ時

---

## アイテムインフォパネル

**詳細設計**: [card_info_panels.md](card_info_panels.md#アイテム情報パネル)

### 用途
- **アイテムフェーズ**: 使用するアイテムの確認

### 表示内容
- 名前 + レアリティ
- コスト
- アイテムタイプ（武器/防具/道具/巻物/アクセサリ）
- ステータス変化（AP+X, HP+X）
- 効果テキスト

### ファイル
- **シーン**: `scenes/ui/item_info_panel.tscn`
- **スクリプト**: `scripts/ui_components/item_info_panel_ui.gd`

### 主要メソッド
```gdscript
# アイテム情報パネルを表示（使用確認モード）
show_item_info(item_data: Dictionary, hand_index: int = -1)

# パネルを閉じる
hide_panel(clear_buttons: bool = true)
```

### シグナル
- `selection_confirmed(card_data)` - 決定時
- `selection_cancelled` - キャンセル時
- `panel_closed` - パネル閉じた時

### 呼び出し元
- `CardSelectionUI._show_item_info_panel()` - アイテムフェーズ時

### 注意: アイテムフェーズでのクリーチャー表示
アイテムフェーズでは以下のクリーチャーも選択可能：
- **アイテムクリーチャー**: `SkillItemCreature.is_item_creature(card_data)`で判定
- **援護クリーチャー**: バトル参加クリーチャーが援護スキルを持つ場合

これらは**クリーチャーインフォパネル**で表示する（確認テキストが変わる）。

---

## プレイヤーインフォパネル

**詳細設計**: [player_info_panel_redesign.md](player_info_panel_redesign.md)

### 用途
- 画面上部に常時表示
- 各プレイヤーのステータス表示

### 表示内容
- プレイヤー名
- EP（現在値）
- TEP
- 土地数
- クリーチャー数

### ファイル
- **スクリプト**: `scripts/ui_components/player_info_panel.gd`
- シーンファイルなし（コードで動的生成）

### 主要メソッド
```gdscript
# プレイヤー情報を更新
update_player_info(players: Array, player_system)

# 現在のターンプレイヤーを設定（ハイライト表示）
set_current_turn(player_id: int)
```

---

## 共通設計パターン

### UIManager統合
全パネルは`UIManager`で管理される：
```gdscript
# UIManager変数
var creature_info_panel_ui: CreatureInfoPanelUI = null
var spell_info_panel_ui: SpellInfoPanelUI = null
var item_info_panel_ui: ItemInfoPanelUI = null
var player_info_panel = null
```

### シーン構造（カード系パネル共通）
```
Panel (Control)
├── MainContainer (HBoxContainer)
│   ├── LeftPanel (Control) - カード画像表示エリア
│   └── RightPanel (Control)
│       ├── ParchmentBg (TextureRect) - 羊皮紙背景
│       └── ContentMargin (MarginContainer)
│           └── VBoxContainer
│               ├── NameLabel
│               ├── CostLabel
│               ├── TypeLabel (Spell/Item) or ElementLabel (Creature)
│               ├── HSeparator
│               └── EffectContainer
```

### 位置（絶対座標）
- offset_left: 137
- offset_top: 149
- `stretch/mode="viewport"`により自動スケーリング

### ボタン連携
`GlobalActionButtons`と連携：
```gdscript
# 選択モード時
ui_manager_ref.enable_navigation(
	func(): _on_confirm_action(),  # 決定
	func(): _on_back_action()      # 戻る
)

# または register_global_actions（クリーチャーパネル）
ui_manager_ref.register_global_actions(confirm_callback, back_callback, confirm_text, back_text)
```

---

## 実装上の注意点

### 1. カード表示のクリア
パネル切り替え時に古いカードが残る問題を防ぐため、`remove_child()`で即座に削除：
```gdscript
if card_display and is_instance_valid(card_display):
	card_display.get_parent().remove_child(card_display)
	card_display.queue_free()
	card_display = null
```

### 2. パネル切り替え時の相互クローズ
アイテムフェーズでアイテム⇔クリーチャー切り替え時、他方を閉じる：
```gdscript
# アイテムパネル表示時
if ui_manager_ref.creature_info_panel_ui and ui_manager_ref.creature_info_panel_ui.is_visible_panel:
	ui_manager_ref.creature_info_panel_ui.hide_panel(false)
```

### 3. シグナル接続の排他制御
クリーチャーパネルは召喚用とアイテム用で異なるハンドラを使用。切り替え時に一方を切断：
```gdscript
# アイテム用表示時、召喚用のシグナルを切断
if creature_info_panel_connected:
	ui_manager_ref.creature_info_panel_ui.selection_confirmed.disconnect(_on_creature_panel_confirmed)
	creature_info_panel_connected = false
```

### 4. プレイヤーID管理（防衛側対応）
`CardSelectionUI`は`current_selection_player_id`を保存して、防衛側アイテムフェーズでも正しいプレイヤーの手札を参照：
```gdscript
# show_selection()で保存
current_selection_player_id = current_player.id

# _get_card_data_for_index()で使用
var hand_data = card_system_ref.get_all_cards_for_player(current_selection_player_id)
```

### 5. 1クリック決定対応
`card.gd`で情報パネル表示が必要なケースは1クリックで即`on_card_confirmed()`を呼ぶ：
```gdscript
var is_creature_with_panel = card_type == "creature" and GameSettings.use_creature_info_panel
var is_spell_in_spell_phase = card_type == "spell" and _is_spell_phase_active()
var is_item_phase = _is_item_phase_active()

if is_creature_with_panel or is_spell_in_spell_phase or is_item_phase:
	select_card()
	on_card_confirmed()
```

---

## スペル使用後の手札選択時

ポイズンマインド、シャッター、セフト等のスペル使用後に敵手札やデッキからカードを選択する際もインフォパネルを表示する。

### 対象スペル

| スペル | filter_mode | 選択対象 |
|--------|-------------|---------|
| シャッター | `destroy_item_spell` | 敵手札のアイテム/スペル |
| スクイーズ | `destroy_any` | 敵手札の全カード |
| セフト | `destroy_spell` | 敵手札のスペル |
| ポイズンマインド | - | 敵デッキ上部6枚 |
| フォーサイト | - | 自デッキ上部6枚 |
| メタモルフォシス | `item_or_spell` | 敵手札のアイテム/スペル |

### 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/card.gd` | ワンクリック判定（`_is_handler_card_selection_active()`） |
| `scripts/ui_manager.gd` | カード選択ハンドラー経由のルーティング |
| `scripts/spells/card_selection_handler.gd` | インフォパネル表示・確認処理 |

### フロー

1. カードをクリック → `card.gd`が`_is_handler_card_selection_active()`でハンドラー選択中か判定
2. ハンドラー選択中なら`ui_manager._on_card_button_pressed()`が`game_flow_manager.on_card_selected()`経由で処理
3. `card_selection_handler`の`on_enemy_card_selected()`等が呼ばれる
4. `_request_card_confirmation()`でカードタイプに応じたインフォパネル表示
5. 確認ボタン → アクション実行、キャンセル → 選択画面に戻る（戻るボタン再登録）

### 注意点

- 異なるカードを選択した場合、既存パネルを閉じてから新しいパネルを表示（`_hide_all_info_panels(false)`）
- キャンセル時は戻るボタンを再登録して選択画面に戻れるようにする
- パネル内のカード表示は`remove_child()`で即座に削除（`queue_free()`だけでは遅延あり）

### 関連ドキュメント

- [手札操作スペル](spells/手札操作.md) - 詳細な実装パターン

---

## インフォパネル一元化リファクタリング（進行中）

### 完了済み

#### Step 1-4: 参照一元化
- インフォパネル参照: 181箇所 → 35箇所（81%削減）
- ui_managerに統合メソッド追加: `show_card_info`, `show_card_selection`, `hide_all_info_panels`

#### ナビゲーション保存/復元
- `save_navigation_state()` / `restore_navigation_state()` / `clear_navigation_saved_state()`
- 保存対象: 4方向ナビゲーション + special_button + フェーズコメント
- `_hide_all_info_panels_raw()`: saved stateを退避/復元しつつパネルを閉じる

#### 閲覧モードの実装
- カードタップ → `show_card_info(setup_buttons=false)` → ×ボタンで元の状態に復元
- カード選択フェーズ中（スペル/召喚/バトル/アイテム）: 正常動作
- グレイアウトカードの閲覧: `_show_info_panel_only()`経由で対応

#### ドミニオコマンド中の閲覧モード
- 土地選択中: ×で復元OK（`_restore_current_phase` → `dominio.restore_navigation()`）
- アクション選択中: ×で復元OK（`action_menu_ui.restore_navigation()`）
- レベルアップ/移動先/地形/交換: テスト済み

### 未解決の設計課題

#### show_card_info(setup_buttons=false)の二重用途
- **閲覧モード**: ユーザーがカードタップ → ×ボタン/save/フェーズコメント変更が必要
- **表示の一部**: ドミニオのアクション選択時にクリーチャー情報を表示 → 上記は不要
- 現状: dominio_order_uiの`show_action_menu`内でshow_card_info後にフェーズコメントを上書きして対処
- 理想: 「表示のみモード」をshow_card_infoに追加するか、直接パネルのshow_view_modeを呼ぶ

#### 復元方式の混在
- カード選択UI系: `_restore_current_phase` → `card_selection_ui.restore_phase_comment()`
- ドミニオ: `_restore_current_phase` → `dominio.restore_navigation()` + `dominio.restore_phase_comment()`
- サイコロフェーズ等: `restore_navigation_state()`（save/restoreフォールバック）
- 理想: 全フェーズが統一インターフェース（restore_navigation + restore_phase_comment）で復元

#### special_buttonのvisible制御
- `_update_button_states()`で`visible = _special_callback.is_valid()`を追加
- 以前はdisabledのみでvisibleは変更していなかったため、Dボタンが見えたまま残る問題があった

### 関連する変更ファイル一覧
- `scripts/ui_manager.gd`: show_card_info, _hide_all_info_panels_raw, save/restore, _restore_current_phase
- `scripts/ui_components/card_selection_ui.gd`: save追加、キャンセル/確認時にclear
- `scripts/ui_components/global_action_buttons.gd`: special_button.visible制御追加
- `scripts/ui_components/action_menu_ui.gd`: restore_navigation()追加
- `scripts/ui_components/dominio_order_ui.gd`: show_action_menuにフェーズコメント追加、_close_creature_info_panel_if_openでコメントクリア
- `scripts/ui_tap_handler.gd`: _close_info_panel_and_restore, is_card_selection_active判定追加
- `scripts/card.gd`: _show_info_panel_only簡素化、is_active判定追加
- `scripts/game_flow/dominio_command_handler.gd`: restore_phase_comment追加、open時にclear_navigation_saved_state
- `scripts/game_flow/spell_phase_handler.gd`: スペルカード0枚時もshow_selection呼び出し
- `scripts/ui_components/phase_display.gd`: get_current_action_prompt()追加

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/12/14 | 1.0 | 初版作成（アイテムインフォパネル追加に伴い整理） |
| 2025/12/16 | 1.1 | 詳細設計へのリンク追加 |
| 2025/12/17 | 1.2 | スペル使用後の手札選択時のインフォパネル表示を追加 |
| 2026/02/12 | 2.0 | インフォパネル一元化リファクタリング進捗を追加 |