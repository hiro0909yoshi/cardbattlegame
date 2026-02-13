# 📋 次のリファクタリング作業

**最終更新**: 2026-02-14
**目的**: セッション間で作業計画が失われないよう、次にやることを明確に記録

---

## ✅ 完了: TileDataManager 逆参照解消（2026-02-14）

**優先度**: P0（最下位→最上位の逆参照）
**実装時間**: 0.5日
**担当**: Haiku

### 実施内容

#### 削除された逆参照
- `scripts/tile_data_manager.gd` Line 14: `var game_flow_manager = null` 削除
- `scripts/tile_data_manager.gd` Line 31-33: `set_game_flow_manager()` メソッド削除
- `scripts/board_system_3d.gd` Line 151: `tile_data_manager.set_game_flow_manager()` 呼び出し削除

#### 統一された参照パターン
- `get_element_chain_count()` 内で `game_stats` を直接参照
- `if not game_stats: game_stats = {}` でnullガード追加
- SpellWorldCurse.is_same_chain_group() への引数を `game_stats` に統一

### 効果
- 最下位（TileDataManager）→最上位（GameFlowManager）の逆参照を完全解消
- 直接参照パターンへの統一により、コード可読性向上
- 循環参照リスクの低減

---

## ✅ 完了: Phase 1-A 残りタスク（MovementController, LapSystem）（2026-02-14）

**優先度**: P1
**実装時間**: 1.5時間
**担当**: Haiku

### 実施内容

#### 削除・解消された逆参照
- **lap_system.gd**: `var game_flow_manager = null` を完全削除 → Callable化
- **movement_controller.gd**: `is_game_ended` 参照を Callable化（Line 481, 509-511 の他の参照は残存）

#### 統一された参照パターン
- `is_game_ended_checker: Callable = func() -> bool: return false` による遅延評価
- BoardSystem3D.setup_systems() で movement_controller に Callable 注入
- GameFlowManager.setup_systems() で lap_system に Callable 注入

#### 修正ファイル
- `scripts/movement_controller.gd`: Line 34-35, 86-88, 133, 182
- `scripts/game_flow/lap_system.gd`: Line 24, 43, 46-48, 180
- `scripts/board_system_3d.gd`: Line 148-150
- `scripts/game_flow_manager.gd`: Line 159-161

### 効果
- 下位→上位の逆参照（is_game_ended 確認）を完全解消
- Callable パターンによる層の責任分離
- null 参照エラーの防止（デフォルト false）

---

## 🟢 Phase 1-A 完全完了

**総作業時間**: 2日（TileDataManager 0.5日 + MovementController/LapSystem 1.5時間）

### 完了したタスク
1. ✅ TileDataManager 逆参照解消（最下位→最上位）
2. ✅ MovementController 逆参照解消（is_game_ended）
3. ✅ LapSystem 逆参照解消（is_game_ended）
4. ✅ tile_action_processor - 既に対応済み確認
5. ✅ special_tile_system - context パターン確認
6. ✅ card_selection_ui - DebugSettings 移行確認
7. ✅ player_info_panel - setter パターン確認

### 次のフェーズ: Phase 1-B または Phase 2-A

詳細は `docs/progress/signal_cleanup_work.md` を参照

---

## 📋 アーカイブ: 対象ファイル確定

### 修正が必要（2ファイル）

| # | ファイル | 逆参照の種類 | 深刻度 | 対応方法 | 見積 |
|---|---------|------------|--------|---------|------|
| 1 | **movement_controller.gd** | is_game_ended 確認 | 🟡 低 | Callable注入 | 30分 |
| 2 | **lap_system.gd** | is_game_ended 確認 | 🟡 低 | Callable注入 | 30分 |

### 修正不要（既に対応済み）

- ✅ **tile_action_processor.gd** - 既に setter で spell_cost_modifier, spell_world_curse を注入済み
- ✅ **special_tile_system.gd** - context パラメータで GFM を受け取る（依存性注入パターン）
- ✅ **card_selection_ui.gd** - DebugSettings 移行済み
- ✅ **player_info_panel.gd** - 既に setter パターンで正しく実装

---

## 2. 詳細修正内容

### ファイル1: movement_controller.gd

#### 現状分析

**Line 34**: `var game_flow_manager = null`

**使用箇所**:
- **Line 127**: `if game_flow_manager and game_flow_manager.is_game_ended:` - 移動開始前のゲーム終了チェック
- **Line 176**: `if game_flow_manager and game_flow_manager.is_game_ended:` - 移動ループ中のゲーム終了チェック

#### 修正方針

**パターン**: Callable注入で「ゲーム終了チェック」を提供

#### 修正内容

**修正前（Line 34, 127）**:
```gdscript
# Line 34
var game_flow_manager = null

# Line 127-129
if game_flow_manager and game_flow_manager.is_game_ended:
	print("[MovementController] ゲーム終了済み、移動スキップ")
	return
```

**修正後**:
```gdscript
# Line 34
var is_game_ended_checker: Callable = func() -> bool: return false

# 新しい setter メソッド追加（setup_systems()の後）
func set_game_ended_checker(checker: Callable) -> void:
	is_game_ended_checker = checker

# Line 127-129
if is_game_ended_checker.call():
	print("[MovementController] ゲーム終了済み、移動スキップ")
	return

# Line 176 も同様に修正
if is_game_ended_checker.call():
	print("[MovementController] ゲーム終了済み、移動中断")
	break
```

#### 呼び出し元の修正

**BoardSystem3D.setup_systems()** 内で:
```gdscript
movement_controller.set_game_ended_checker(
	func() -> bool: return game_flow_manager.is_game_ended if game_flow_manager else false
)
```

---

### ファイル2: lap_system.gd

#### 現状分析

**Line 24**: `var game_flow_manager = null  # ゲーム終了判定用`

**使用箇所**:
- **Line 176**: `if game_flow_manager and game_flow_manager.is_game_ended:` - ゲーム終了チェック（周回完了処理のスキップ）

#### 修正方針

**パターン**: movement_controller.gd と同じ Callable注入パターン

#### 修正内容

**修正前（Line 24, 176）**:
```gdscript
# Line 24
var game_flow_manager = null  # ゲーム終了判定用

# Line 176
if game_flow_manager and game_flow_manager.is_game_ended:
	return
```

**修正後**:
```gdscript
# Line 24
var is_game_ended_checker: Callable = func() -> bool: return false

# 新しい setter メソッド追加
func set_game_ended_checker(checker: Callable) -> void:
	is_game_ended_checker = checker

# Line 176
if is_game_ended_checker.call():
	return
```

#### 呼び出し元の修正

**GameFlowManager.setup_systems()** 内で:
```gdscript
lap_system.set_game_ended_checker(
	func() -> bool: return is_game_ended
)
```

---

## 3. 影響範囲調査

### movement_controller.gd の修正

**影響を受けるファイル**:
1. **board_system_3d.gd** - setup_systems() で `set_game_ended_checker()` を呼び出す

**影響を受けるシーン/機能**:
- すべての移動処理（ダイスロール→移動フェーズ）
- ゲーム終了判定後の移動スキップロジック

### lap_system.gd の修正

**影響を受けるファイル**:
1. **game_flow_manager.gd** - setup_systems() で `set_game_ended_checker()` を呼び出す

**影響を受けるシーン/機能**:
- 周回完了判定処理
- チェックポイント通過処理

---

## 4. リスク分析

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| Callable の null 参照 | 🟡 中 | 低 | 初期値を `func() -> bool: return false` で安全化 |
| 既存 GFM 参照の遺漏 | 🔴 高 | 中 | grep で game_flow_manager.is_game_ended を完全検索 |
| 移動ロジックの破損 | 🟡 中 | 低 | 各ステップ後に基本的なゲームプレイ（3ターン）でテスト |

---

## 5. 実装前の確認質問（Haiku向け）

1. **Callable の呼び出し方法**
   - `is_game_ended_checker.call()` と `is_game_ended_checker.call_deferred()` どちらを使うべきか？
   - 答え: 同期的に呼ぶため `.call()` を使用

2. **既存の game_flow_manager 参照の削除時期**
   - すべての is_game_ended チェックを置き換えた後に削除するか？
   - 答え: はい、すべて置き換え後に `var game_flow_manager = null` を削除

3. **他の GFM 参照の確認**
   - movement_controller.gd の Line 481, 511 で他の GFM 参照があるが、これらは今回対象外か？
   - 答え: はい、is_game_ended のみが Phase 1-A の対象

---

## 6. 実装の注意点

### Callable の安全な初期化

```gdscript
# ✅ 推奨：デフォルト実装を提供
var is_game_ended_checker: Callable = func() -> bool: return false
```

このパターンにより、setter が呼ばれない場合でも null 参照エラーを防ぐ。

### 層の責任分離を強化

修正後の構造：
- **MovementController3D**: 移動ロジック管理（子システム）
- **LapSystem**: 周回管理（子システム）
- **GameFlowManager**: ゲーム終了判定を Callable で提供（親システム）
  - MovementController → Callable で is_game_ended を受け取る
  - LapSystem → Callable で is_game_ended を受け取る

---

## 7. 見積もり

- **movement_controller.gd**: 30分
  - Callable 変数追加・setter メソッド追加: 10分
  - Line 127, 176 の置き換え: 10分
  - テスト・確認: 10分

- **lap_system.gd**: 30分
  - Callable 変数追加・setter メソッド追加: 10分
  - Line 176 の置き換え: 5分
  - テスト・確認: 15分

- **呼び出し元修正（GFM, BS3D）**: 30分
  - GameFlowManager.setup_systems() 修正: 15分
  - BoardSystem3D.setup_systems() 修正: 15分

- **総作業時間**: 1.5時間（90分）

---

## 8. 実装完了後の確認事項

- [ ] git status で修正ファイルを確認
- [ ] 修正前後の差分で移動ロジックが保持されているか確認
- [ ] コンパイルエラー/警告なし
- [ ] ゲーム起動・3ターン以上プレイで動作確認
  - ダイスロール正常
  - プレイヤー移動正常
  - ゲーム終了時に移動スキップ
  - 周回完了判定正常
- [ ] CPU プレイヤー 2-4 人の正常動作確認

---

## 📋 関連ドキュメント

- `docs/progress/signal_cleanup_work.md` - Phase 1-A の全体計画
- `docs/design/god_object_analysis.md` - 神オブジェクト詳細分析
- `CLAUDE.md` - 直接参照パターンの説明
