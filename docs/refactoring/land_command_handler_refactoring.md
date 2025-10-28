# LandCommandHandler リファクタリング記録

## 概要
- **日付**: 2025年10月21日
- **対象**: `scripts/game_flow/land_command_handler.gd`
- **目的**: 大規模ファイル（881行）を保守性の高い構造に分割

## 分割結果

### 元のファイル
- `land_command_handler.gd`: **881行**

### 分割後のファイル構成
1. **land_command_handler.gd**: 352行（メインファイル）
   - 外部インターフェース
   - 状態管理
   - コンポーネント間の調整

2. **land_selection_helper.gd**: 177行
   - 土地選択ロジック
   - プレビュー機能
   - 選択マーカー管理
   - カメラフォーカス

3. **land_action_helper.gd**: 333行
   - レベルアップ実行
   - クリーチャー移動
   - クリーチャー交換
   - バトル処理

4. **land_input_helper.gd**: 126行
   - キーボード入力処理
   - 状態別入力分岐

**合計**: 988行（元: 881行）
**増加**: わずか107行（**12%増**）

## 成功の要因

### 1. Static関数パターンの採用
すべてのヘルパークラスをstatic関数の集まりとして実装：

```gdscript
# ヘルパークラス（インスタンス不要）
class_name LandSelectionHelper

static func preview_land(handler, tile_index: int) -> bool:
	# handlerを介して状態にアクセス
	handler.selected_tile_index = tile_index
	return true
```

**メリット**:
- インスタンス生成不要（`new()`や`add_child()`なし）
- シグナル接続不要
- メモリオーバーヘッドなし

### 2. 余計なコードの排除
- ❌ 後方互換性メソッド: 0個（前回は15個作ってしまった）
- ❌ 新規シグナル: 0個（前回は2個追加してしまった）
- ❌ シグナル接続コード: 0行（前回は大量に作ってしまった）
- ✅ 必要最小限のラッパー関数のみ

### 3. 状態の一元管理
すべての状態は`handler`（メインファイル）で管理：

```gdscript
# メインファイル
var selected_tile_index: int = -1
var player_owned_lands: Array = []

# ヘルパーから状態にアクセス
static func preview_land(handler, tile_index: int) -> bool:
	handler.selected_tile_index = tile_index  # handlerの状態を更新
```

### 4. 外部インターフェースの完全維持
既存のコードからの呼び出しは一切変更不要：

```gdscript
# 外部からの呼び出し（変更なし）
land_command_handler.preview_land(5)
land_command_handler.execute_action("level_up")

# 内部実装（ヘルパーに委譲）
func preview_land(tile_index: int) -> bool:
	return LandSelectionHelper.preview_land(self, tile_index)
```

## 前回の失敗との比較

| 項目 | 前回（失敗） | 今回（成功） |
|------|------------|------------|
| **増加率** | 57%（約500行） | **12%（107行）** |
| **後方互換メソッド** | 約15個 | **0個** |
| **シグナル接続コード** | 大量（約50行） | **0行** |
| **新規シグナル** | 2個（不要） | **0個** |
| **コンポーネント** | インスタンス化 | **Static関数** |
| **状態管理** | 重複あり | **一元管理** |
| **パースエラー** | あり | **なし** |
| **Godot警告** | 多数 | **0件** |

### 前回の主な問題点
1. コンポーネントをインスタンス化 → シグナル接続コードが増殖
2. 使われない後方互換メソッドを大量作成
3. 新しいシグナルを追加 → 使われないまま警告に
4. 状態が複数箇所で重複管理

### 今回の改善点
1. Static関数パターン → インスタンス不要、接続不要
2. 実際に呼ばれるメソッドのみラップ
3. 既存のシグナルをそのまま使用
4. 状態は`handler`のみで管理

## 増加した107行の内訳

1. **クラス定義**: 3行
   ```gdscript
   # land_selection_helper.gd
   class_name LandSelectionHelper
   
   # land_action_helper.gd
   class_name LandActionHelper
   
   # land_input_helper.gd
   class_name LandInputHelper
   ```

2. **ラッパー関数**: 約100行
   ```gdscript
   func preview_land(tile_index: int) -> bool:
	   return LandSelectionHelper.preview_land(self, tile_index)
   
   func execute_level_up() -> bool:
	   return LandActionHelper.execute_level_up(self)
   
   # ... 約30個のラッパー
   ```

3. **コメント・空行**: 4行

## コードメトリクス

### 保守性の向上
- ✅ 各ファイルが300行前後に収まった
- ✅ 責任が明確に分離された
- ✅ テストしやすい構造になった

### パフォーマンス
- ✅ 実行時のオーバーヘッドなし（static関数呼び出しのみ）
- ✅ メモリ使用量は変わらず

### 可読性
- ✅ ファイル名から機能が明確
- ✅ 各ヘルパーが独立して理解可能

## 適用可能な他のファイル

同じパターンで分割可能なファイル：
- `game_flow_manager.gd`: 大規模ファイルの可能性
- `ui_manager.gd`: UI関連処理
- 他の大規模なシステムファイル

## 教訓

### ✅ やるべきこと
1. **Static関数パターン**: インスタンス不要なヘルパークラス
2. **最小限の追加**: 必要なコードのみ追加
3. **段階的分割**: 一気に全部ではなく、理解しながら
4. **外部参照を確認**: 実際に使われるメソッドのみラップ

### ❌ やってはいけないこと
1. **コンポーネントのインスタンス化**: シグナル接続地獄の原因
2. **後方互換性の過剰実装**: 使われないメソッドの量産
3. **新規シグナルの追加**: 既存のもので十分
4. **状態の重複管理**: 一箇所で管理

## バックアップ

元のファイルは以下に保存：
- `land_command_handler_old.gd.disabled`
- `land_command_handler.gd.backup.disabled`

## まとめ

LandCommandHandlerの分割は完全に成功しました：
- ✅ コード増加はわずか12%
- ✅ 機能は完全に維持
- ✅ 保守性が大幅に向上
- ✅ エラー・警告ゼロ

このStatic関数パターンは、今後の大規模ファイルリファクタリングの標準手法として採用すべきです。
