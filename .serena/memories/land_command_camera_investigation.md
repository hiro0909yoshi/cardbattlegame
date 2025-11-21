# 領地コマンド（LandCommand）のカメラワーク実装確認

## カメラワークの呼び出し位置（確認済み）

### 1. **タイル選択時のカメラ操作**
- ファイル: `scripts/game_flow/land_command_handler.gd`
- 関数: `focus_camera_on_tile(tile_index: int)` - 326行目
- 実装: `LandSelectionHelper.focus_camera_on_tile(self, tile_index)` へ委譲
- さらに: `TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)` へ委譲

### 2. **領地コマンド終了時のカメラ復帰**
- ファイル: `scripts/game_flow/land_command_handler.gd`
- 関数: `close_land_command()` - 175～210行目
- **実装内容** (187～202行目):
  ```gdscript
  # カメラを現在のプレイヤーに戻す
  if board_system and player_system and board_system.movement_controller:
      var player_id = player_system.current_player_index
      var player_tile_index = board_system.movement_controller.get_player_tile(player_id)
      
      if board_system.camera and board_system.tile_nodes.has(player_tile_index):
          var tile_pos = board_system.tile_nodes[player_tile_index].global_position
          
          const CAMERA_OFFSET = Vector3(19, 19, 19)
          var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + CAMERA_OFFSET
          
          board_system.camera.position = new_camera_pos
          board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)
  ```

## 現在の状況

**領地コマンド内のカメラワーク**: ✅ 正常に機能している
- タイル選択時 → focus_camera_on_tile()でカメラが移動
- コマンド終了時 → close_land_command()でカメラが復帰
- CAMERA_OFFSET = Vector3(19, 19, 19) を使用

**マップ移動時のカメラワーク**: ❌ 機能していない
- MovementController.move_to_tile() 内で条件チェック実施
- ただし条件が満たされていない可能性がある

## マップ移動時のカメラ問題の根本原因

**予想される原因**:

1. **MovementController.camera が null**
   - board_system_3d.camera から正しく設定されていない
   - または初期化順序の問題

2. **player_system.current_player_index が不正**
   - move_to_tile()内で player_id != current_player_index の判定がある
   - CPU移動時は player_id != current_player_index となるため追従しない設計

3. **GameSystemManager Phase 3 でのカメラ設定タイミング**
   - Phase 3で camera.position = Vector3(19, 19, 19) を設定
   - しかし、その後の初期化で上書きされる可能性
   - または、camera参照がMovementControllerに渡される時点で既に位置がズレている

## 領地コマンド独立化への設計案

カメラワークを独立させる場合の構造:

```
CameraController（新規作成）
├── カメラ位置管理
│   ├── 現在位置
│   ├── 目標位置
│   └── CAMERA_OFFSETの統一管理
├── カメラ追従ロジック
│   ├── プレイヤー追従
│   ├── タイル注視
│   └── スムーズなトランジション
└── 他システムからの呼び出しインターフェース
    ├── focus_on_player(player_id)
    ├── focus_on_tile(tile_index)
    └── reset_to_default()
```

利点:
- カメラロジックの一元管理
- MovementControllerとLandCommandHandlerの依存性削減
- GameSystemManagerで統一的に初期化可能

## 次のステップ

1. **診断ログの実行** → カメラの初期化状態を確認
2. **原因特定** → Phase 3 or MovementController.initialize() のどちらで問題が発生しているか
3. **修正方法の選択**:
   - Option A: 簡易修正 - game_3d.gd でカメラ位置を再設定
   - Option B: CameraController で独立化
