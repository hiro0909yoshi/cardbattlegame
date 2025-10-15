# Phase 1-A 進捗管理

**最終更新**: 2025年10月15日

---

## 📊 全体進捗

### Phase 1-A: 基盤整備（5日間）

| Day | 項目 | ステータス | 完了日 |
|-----|------|-----------|--------|
| 1-2 | フェーズ管理構造 | 🔄 進行中 | - |
| 3-4 | 領地コマンドUI基盤 | ✅ 完了 | 2025-01 |
| 5   | 既存システム統合 | 🔄 進行中 | 2025-10-15 |

**進捗率**: Day 5進行中 (95%) - 表示タイミング修正完了、レベルアップ処理完了（動作確認済み）、移動・交換は未実装

---

## ✅ 完了タスク

### 2025年10月15日: Phase 1-A Day 5 開始

#### UIパネル配置修正
- [x] アクションメニュー・レベル選択パネルを画面中央に移動
- [x] 全画面対応の配置計算（相対座標）
- [x] design.mdに全画面対応の指針を追記

**修正ファイル**:
- `scripts/ui_manager.gd`
  - `create_action_menu_panel()` - 中央配置に修正
  - `create_level_selection_panel()` - 中央配置に修正
- `docs/design/design.md`
  - UI配置の基本方針セクション追加

**修正内容**:
```gdscript
// 修正前（上部配置）
var panel_y = 20

// 修正後（画面中央）
var panel_y = (viewport_size.y - panel_height) / 2
```

---

#### レベルアップ機能完全実装
- [x] アクションメニューパネルUI作成（右側中央配置）
  - レベルアップ、移動、交換、戻るボタン
- [x] レベル選択パネルUI作成
  - Lv2-5選択ボタン
  - 累計コスト表示
  - 魔力による有効/無効判定
- [x] `land_command_handler.gd`修正
  - `board_system.get_tile()`エラー修正 → `tile_nodes[]`使用
  - `execute_level_up_with_level()`実装
  - レベルアップ後のダウン状態設定
  - ターン終了処理統合
- [x] UIManagerとLandCommandHandlerの連携
  - `level_up_selected`シグナル接続

**修正ファイル**:
- `scripts/ui_manager.gd` (約150行追加)
- `scripts/game_flow/land_command_handler.gd` (約50行修正・追加)

**結果**: 完全なレベルアップフローが実装された

---

#### 領地コマンドボタンの表示タイミング修正
- [x] `GameFlowManager.start_turn()`からボタン表示処理を削除
- [x] `BoardSystem3D._on_movement_completed()`にボタン表示処理を追加
- [x] 人間プレイヤーのみ表示（CPU判定を含む）

**修正ファイル**:
- `scripts/game_flow_manager.gd` (100-105行目削除)
- `scripts/board_system_3d.gd` (211-217行目追加)

**結果**: 移動完了後に領地コマンドボタンが表示されるようになった

---

### 2025年10月15日: コード品質改善

#### 警告修正（4件）
- [x] `is_down`のシャドウイング修正（base_tiles.gd:148）
  - パラメータ名を`should_be_down`に変更
- [x] 未使用パラメータ修正（battle_system.gd:221）
  - `tile_info` → `_tile_info`
- [x] 到達不能コード削除（battle_system.gd:278）
  - 不要な`return false`を削除
- [x] 整数除算警告修正（player_info_panel.gd:56）
  - `margin / 2` → `int(margin / 2.0)`

**修正ファイル**:
- `scripts/tiles/base_tiles.gd`
- `scripts/battle_system.gd`
- `scripts/ui_components/player_info_panel.gd`

**結果**: Godotの警告が解消され、コード品質が向上

#### ドキュメント構造整理
- [x] `docs/`ディレクトリの構造化
  - `docs/design/` - 設計ドキュメント（読み取り専用）
  - `docs/progress/` - 進捗管理（適時更新）
  - `docs/issues/` - 課題管理（適時更新）
- [x] ルートファイルの移動
  - `design.md` → `docs/design/`
  - `skills_design.md` → `docs/design/`
  - `turn_end_flow.md` → `docs/design/`
  - `issues.md` → `docs/issues/`
  - `tasks.md` → `docs/issues/`
  - `TURN_END_QUICK_FIX.md` → `docs/issues/`
- [x] ドキュメント作成
  - `README.md` - プロジェクト概要
  - `docs/README.md` - ドキュメントインデックス
- [x] 更新ルール明記
  - design/は読み取り専用（ユーザー指示のみ更新可）
  - issues/は適時更新（バグ発見・修正時に即座に更新）
  - progress/は適時更新（タスク完了時に更新）

**実装ファイル**:
- プロジェクトルート: `README.md`
- `docs/README.md`
- メモリ: `project_structure_and_docs`

**目的**: 
- プロジェクトの情報を一元管理
- チャット開始時の必須確認事項を明確化
- ドキュメント更新の運用ルール確立

---

### Day 3-4: 領地コマンドUI基盤

#### 領地コマンドボタン
- [x] ボタン作成（左上配置、z_index=100）
- [x] キャンセルボタン作成（閉じるボタン）
- [x] 表示/非表示切り替え
- [x] hand_containerのmouse_filter設定（クリック可能に）

**実装ファイル**:
- `scripts/ui_manager.gd`
  - `create_land_command_button()`
  - `create_cancel_land_command_button()`
  - `show_land_command_button()`
  - `hide_land_command_button()`

#### 土地選択モード
- [x] キーボード入力処理（数字キー1-0）
- [x] 所有地リスト取得
- [x] ダウン状態の土地を除外
- [x] UIにコマンド説明表示

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `_input()` - キーボード処理
  - `handle_land_selection_input()` - 土地選択
  - `get_player_owned_lands()` - ダウン状態除外

#### アクション選択画面
- [x] アクション選択UI表示（L/M/S/C）
- [x] キーボード入力処理
- [x] キャンセル機能（土地選択に戻る）

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `handle_action_selection_input()` - アクション選択
  - `cancel()` - キャンセル処理

#### ダウン状態システム
- [x] 召喚後のダウン状態設定
- [x] スタート通過時のダウン解除
- [x] ダウン状態チェック（選択時）
- [x] Uキーでダウン解除（デバッグ）

**実装ファイル**:
- `scripts/tile_action_processor.gd`
  - 召喚後にダウン設定
- `scripts/movement_controller.gd`
  - `clear_all_down_states_for_player()`
- `scripts/debug_controller.gd`
  - `clear_current_player_down_states()`

---

## 🔲 未完了タスク

### ~~優先度1: 表示タイミング修正~~（✅ 完了: 2025/10/15）

#### 領地コマンドボタンの表示タイミング
- [x] ターン開始時ではなく、移動完了後に表示
- [x] `GameFlowManager.start_turn()`から削除
- [x] 移動完了後のタイミングで表示（`BoardSystem3D._on_movement_completed()`）

**修正したファイル**:
- `scripts/game_flow_manager.gd`
  - `start_turn()` - ボタン表示処理を削除（100-105行目）
- `scripts/board_system_3d.gd`
  - `_on_movement_completed()` - ボタン表示処理を追加

**実装内容**:
```gdscript
// board_system_3d.gd: _on_movement_completed()
var is_cpu = current_player_index < player_is_cpu.size() and player_is_cpu[current_player_index] and not debug_manual_control_all
if not is_cpu and ui_manager:
	ui_manager.show_land_command_button()
elif ui_manager:
	ui_manager.hide_land_command_button()
```

**実現した動作**:
```
ターン開始
  ↓
カードドロー
  ↓
サイコロを振る
  ↓
移動完了 ← ✅ ここで領地コマンドボタン表示
  ↓
召喚フェーズ
```

---

### ~~優先度2: レベルアップ処理~~（✅ 完了: 2025/10/15）

#### エラー修正
- [x] `board_system.get_tile()`エラーの修正
  - 修正: `board_system.tile_nodes[selected_tile_index]`に変更

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_level_up()` 内の`get_tile()`呼び出し修正

#### レベルアップUI
- [x] レベル選択画面の実装
- [x] 累計コスト表示
- [x] 目標レベル選択（Lv2, 3, 4, 5）
- [x] アクションメニューパネル実装（右側配置）

**実装ファイル**:
- `scripts/ui_manager.gd`
  - `action_menu_panel` - アクションメニューパネル（L/M/S/C）
  - `level_selection_panel` - レベル選択パネル（Lv2-5 + コスト表示）
  - `create_action_menu_panel()` - アクションメニュー作成
  - `create_level_selection_panel()` - レベル選択パネル作成
  - `show_action_menu()` / `hide_action_menu()` - 表示制御
  - `show_level_selection()` / `hide_level_selection()` - 表示制御

#### レベルアップ実行
- [x] コスト計算（累計方式）
- [x] 魔力消費処理
- [x] タイルのレベル更新
- [x] レベルアップ後のダウン状態設定
- [x] UI更新
- [x] ターン終了処理

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_level_up_with_level()` - レベルアップ実行
  - `_on_level_up_selected()` - シグナルハンドラ

**実装されたフロー**:
```
土地選択（数字キー1-0）
  ↓
アクションメニュー表示（右側パネル）
  - [L] レベルアップ
  - [M] 移動
  - [S] 交換
  - [C] 戻る
  ↓
レベル選択画面（Lキー押下）
  - 現在レベル表示
  - Lv2-5ボタン（魔力で到達可能なレベルのみ有効）
  - 各レベルのコスト表示
  - [C] 前の画面に戻る
  ↓
レベルアップ実行
  - 魔力消費
  - レベル更新
  - ダウン状態設定
  ↓
ターン終了
```

**コスト計算式（実装済み）**:
```gdscript
var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}
var cost = level_costs[target_level] - level_costs[current_level]
```

---

### 優先度3: クリーチャー移動

- [ ] 移動元選択（全自領地、ダウン除外）
- [ ] 移動先選択（1マス先）
- [ ] 移動処理実装
- [ ] 移動元を空き地化
- [ ] 移動先にクリーチャー配置 + ダウン
- [ ] 空き地移動: 土地獲得 + ターン終了
- [ ] 敵地移動: バトル発生

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_move_creature()` - 現在はプレースホルダー

---

### 優先度4: クリーチャー交換

- [ ] 交換対象土地選択（全自領地、ダウン除外）
- [ ] 既存クリーチャーを手札に戻す
- [ ] 新クリーチャー選択（カード選択画面）
- [ ] 召喚コスト支払い
- [ ] 新クリーチャー配置
- [ ] 土地ボーナス適用
- [ ] 土地レベル継承
- [ ] ダウン状態設定

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_swap_creature()` - 現在はプレースホルダー

---

## ⚠️ 既知の問題

### 修正が必要なエラー

#### 1. `board_system.get_tile()`が存在しない
**発生箇所**: `land_command_handler.gd:113`
```gdscript
var tile = board_system.get_tile(selected_tile_index)
```

**エラーメッセージ**:
```
Invalid call. Nonexistent function 'get_tile' in base 'Node (BoardSystem3D)'.
```

**修正方法**:
```gdscript
# 修正前
var tile = board_system.get_tile(selected_tile_index)

# 修正後
if board_system.tile_nodes.has(selected_tile_index):
	var tile = board_system.tile_nodes[selected_tile_index]
```

---

## 📝 設計メモ

### ダウン状態の仕様
- **ダウン状態の土地は選択できない**
- 選択できない = レベルアップ、移動、交換の全てができない
- `get_player_owned_lands()`でダウン状態を除外
- `select_land()`でも二重チェック

### デバッグコマンド
- **Uキー**: 現在プレイヤーの全土地のダウン解除
- あくまで現在プレイヤーのみ（全プレイヤーではない）

### 領地コマンドの制約
- **1ターンに1回のみ**
- 召喚と領地コマンドは排他的
- どちらか実行したらターン終了

---

## 🎯 次のステップ

### 今すぐ実装すべきこと
1. **領地コマンドボタンの表示タイミング修正**
   - GameFlowManagerの修正
   - 移動完了後に表示

2. **レベルアップのエラー修正**
   - `get_tile()`を`tile_nodes[]`に修正

### その後の実装順序
1. レベルアップUI・処理の完成
2. クリーチャー移動の実装
3. クリーチャー交換の実装

---

## 📂 関連ファイル一覧

### 実装済み
- `scripts/game_flow/land_command_handler.gd` - 領地コマンドのメインロジック
- `scripts/ui_manager.gd` - UI管理、ボタン作成
- `scripts/debug_controller.gd` - デバッグ機能（Uキー）
- `scripts/game_flow_manager.gd` - ゲームフロー管理
- `scripts/tile_action_processor.gd` - タイルアクション処理
- `scripts/movement_controller.gd` - 移動処理

### 今後修正が必要
- `scripts/game_flow_manager.gd` - 表示タイミング修正

---

## 📚 参考資料

- [Phase 1-A 完全仕様書](./phase1a_spec.md) - 元の仕様書（提供されたファイル）
- [ゲームデザイン](../design.md) - 全体設計
- [スキル設計](../skills_design.md) - スキルシステム

---

**作成日**: 2025年1月  
**管理者**: AI Assistant  
**ステータス**: Phase 1-A Day 5 進行中（表示タイミング修正完了）
