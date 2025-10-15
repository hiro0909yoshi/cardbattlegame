# Phase 1-A 進捗管理

**最終更新**: 2025年1月

---

## 📊 全体進捗

### Phase 1-A: 基盤整備（5日間）

| Day | 項目 | ステータス | 完了日 |
|-----|------|-----------|--------|
| 1-2 | フェーズ管理構造 | 🔄 進行中 | - |
| 3-4 | 領地コマンドUI基盤 | ✅ 完了 | 2025-01 |
| 5   | 既存システム統合 | 🔲 未着手 | - |

**進捗率**: Day 4完了時点 (80%)

---

## ✅ 完了タスク

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

### 優先度1: 表示タイミング修正

#### 領地コマンドボタンの表示タイミング
- [ ] ターン開始時ではなく、移動完了後に表示
- [ ] `GameFlowManager.start_turn()`から削除
- [ ] 移動完了後のタイミングで表示

**修正が必要なファイル**:
- `scripts/game_flow_manager.gd`
  - `start_turn()` - ボタン表示処理を削除
  - `_on_movement_completed()` または召喚フェーズ開始時に追加

**期待される動作**:
```
ターン開始
  ↓
カードドロー
  ↓
サイコロを振る
  ↓
移動完了 ← ここで領地コマンドボタン表示
  ↓
召喚フェーズ
```

---

### 優先度2: レベルアップ処理

#### エラー修正
- [ ] `board_system.get_tile()`エラーの修正
  - 現状: `board_system.get_tile(selected_tile_index)`が存在しない
  - 修正: `board_system.tile_nodes[selected_tile_index]`に変更

**修正が必要なファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_level_up()` 内の`get_tile()`呼び出し

#### レベルアップUI
- [ ] レベル選択画面の実装
- [ ] 累計コスト表示
- [ ] 目標レベル選択（Lv2, 3, 4, 5）

**新規実装が必要**:
- UIManagerにレベル選択UI追加
- コスト計算式実装

#### レベルアップ実行
- [ ] コスト計算（累計方式）
- [ ] 魔力消費処理
- [ ] タイルのレベル更新
- [ ] レベルアップ後のダウン状態設定
- [ ] UI更新

**コスト計算式**:
```gdscript
const LEVEL_COSTS = {
    0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200
}

func calculate_level_up_cost(current: int, target: int) -> int:
    return LEVEL_COSTS[target] - LEVEL_COSTS[current]
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
**ステータス**: Phase 1-A Day 4 完了
