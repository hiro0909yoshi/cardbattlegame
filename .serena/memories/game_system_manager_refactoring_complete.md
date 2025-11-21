# GameSystemManager リファクタリング完了（2025-11-22 最終版）

## リファクタリング内容

### 1. GameSystemManager 実装完了

#### 概要
- **ファイル**: `scripts/system_manager/game_system_manager.gd`
- **行数**: 約 560 行
- **役割**: ゲーム初期化の 6フェーズ統括管理

#### 6フェーズ構成

**Phase 1: システム作成（11個）**
- SignalRegistry, BoardSystem3D, PlayerSystem, CardSystem, BattleSystem
- PlayerBuffSystem, SpecialTileSystem, UIManager, DebugController, GameFlowManager
- CreatureManager（BoardSystem3D 内部で自動作成）

**Phase 2: 3D ノード収集**
- Tiles, Players, Camera3D を parent_node から取得

**Phase 3: システム基本設定**
- PlayerSystem.initialize_players(player_count)
- camera_3d.position = GameConstants.CAMERA_OFFSET
- BoardSystem3D への参照設定
- collect_tiles(), collect_players()
- **初期カメラ向き設定**: プレイヤー0に向かせる

**Phase 4: システム間連携設定**
- 4-1: 基本システム参照設定
- 4-2: GameFlowManager 子システム初期化
- 4-3: BoardSystem3D 子システム初期化
- 4-4: 特別な初期化（initialize_phase1a_systems()）

**Phase 5: シグナル接続**
- ゲームシステム間のシグナル接続確立

**Phase 6: ゲーム開始準備**
- UI 更新（update_player_info_panels()）
- 操作準備完了

---

### 2. カメラシステムの改善

#### ハードコード解消

**問題**: `Vector3(19, 19, 19)` がハードコードされていた

**解決**:
1. **定数化** (`scripts/game_constants.gd`)
   ```gdscript
   const CAMERA_OFFSET = Vector3(19, 19, 19)
   ```

2. **使用箇所統一** (全4箇所)
   - GameSystemManager Phase 3: カメラ初期位置設定
   - MovementController.move_to_tile(): 移動時のカメラ追従
   - MovementController (ワープ時): カメラ瞬間移動
   - MovementController (カメラ移動関数): 汎用カメラ移動

#### カメラワークの問題解決

**Issue 1: ゲーム開始時カメラがプレイヤーを向かない**
- **原因**: 初期位置のみ設定し、向きを設定していなかった
- **解決**: Phase 3 で look_at() を追加
  ```gdscript
  camera_3d.look_at(player_look_target, Vector3.UP)
  ```

**Issue 2: 移動時のカメラがガクッと動く**
- **原因**: look_at() が移動中（Tween 実行中）に即座に実行されていた
- **解決**: await tween.finished で移動完了後に look_at() を実行
  ```gdscript
  await tween.finished
  camera_3d.look_at(target_pos + Vector3(0, 1.0, 0), Vector3.UP)
  ```

**Issue 3: 移動時に 1マス進むと停止する**
- **原因**: await tween.finished が重複実行されていた
- **解決**: 診断ログと重複 await を削除

---

### 3. ドキュメント作成

**新規ファイル**: `docs/design/game_system_manager_implementation.md`

内容:
- GameSystemManager の目的と 6フェーズ説明
- システム間依存関係図
- カメラシステムの実装詳細
- 問題解決の履歴
- トラブルシューティング
- 今後の改善案

---

## 修正対象ファイル

### 新規作成
- ✅ `docs/design/game_system_manager_implementation.md`

### 修正済み
- ✅ `scripts/system_manager/game_system_manager.gd` - 全実装完了
- ✅ `scripts/game_constants.gd` - CAMERA_OFFSET 定数追加
- ✅ `scripts/movement_controller.gd` - CAMERA_OFFSET を GameConstants.CAMERA_OFFSET に統一（3箇所）

### 削除/統合なし

---

## 現在の状態

### GameSystemManager
- ✅ 実装完了
- ✅ 6フェーズ初期化動作確認
- ✅ ゲーム起動テスト完了
- ✅ カメラワーク動作確認

### カメラシステム
- ✅ ハードコード解消
- ✅ 定数化完了
- ✅ 初期化時のカメラ向き設定
- ✅ 移動時のスムーズなカメラワーク
- ✅ ワープ時のカメラ処理

### ドキュメント
- ✅ docs/design/game_system_manager_implementation.md 作成
- ⚠️ CLAUDE.md は更新なし（相応の内容なし、今後も参照予定なし）

---

## 次のステップ（予定）

### 優先順位
1. **HP システムリファクタリング** - place_creature() の current_hp 初期化、マップ側 base_up_hp 増加 4箇所対応
2. **Toll システムリファクタリング** - 残存する toll 関連処理の整理
3. **ST-to-AP 用語統一** - 既に完了（325+ 箇所、29ファイル）

### HP リファクタリング詳細
- place_creature() に current_hp 初期化追加
- land_action_helper 376/381 行: base_up_hp 増加処理
- board_system_3d 432/437 行: base_up_hp 増加処理
- battle_system 536/570 行: base_up_hp 増加処理
- spell_land_new: base_up_hp 増加処理
- effect_manager.gd apply_max_hp_effect() 実装検討

---

## メモリの更新内容

### 削除・統合対象
- `game_system_manager_implementation_done` - 古い実装メモ
- `game_system_manager_issues` - 古い問題メモ
- `game_system_manager_implementation_plan` - 古い計画メモ

### 統合済み
- 実装完了メモを本メモリに統合
- カメラワーク問題解決を本メモリに統合
- ドキュメント作成を本メモリに統合

---

**完了日**: 2025-11-22  
**ステータス**: リファクタリング完了、ドキュメント化完了
