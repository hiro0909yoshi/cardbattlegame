# GameSystemManager 実装ドキュメント

## 概要

**GameSystemManager** は、ゲーム初期化の複雑なプロセスを **6つのフェーズ** に整理し、すべてのゲームシステムの作成・初期化・連携を一元管理するシステムです。

### 目的

- **初期化の一元化**: ゲーム開始時のシステム作成と初期化を game_3d.gd から分離
- **依存関係の明確化**: システム間の初期化順序を明示的に制御
- **保守性向上**: 初期化ロジックの変更が容易で、トラブルシューティングが簡単
- **スケーラビリティ**: 新規システム追加時に初期化フローを拡張しやすい

---

## 6フェーズ初期化

### Phase 1: システム作成

**目的**: すべてのゲームシステムのインスタンスを生成

**作成対象** (11個):
1. `SignalRegistry` - シグナル管理
2. `BoardSystem3D` - 3Dボード管理
3. `PlayerSystem` - プレイヤー状態管理
4. `CardSystem` - デッキ・手札管理
5. `BattleSystem` - バトル実行
6. `PlayerBuffSystem` - バフ効果管理
7. `SpecialTileSystem` - 特殊マス管理
8. `UIManager` - UI統括管理
9. `DebugController` - デバッグ機能
10. `GameFlowManager` - ゲームフロー管理
11. `CreatureManager` - クリーチャー管理（BoardSystem3D 内部）

**実装位置**: `scripts/system_manager/game_system_manager.gd` - `phase_1_create_systems()`

```gdscript
# 例: BoardSystem3D の作成
var BoardSystem3DClass = load("res://scripts/board_system_3d.gd")
board_system_3d = BoardSystem3DClass.new()
board_system_3d.name = "BoardSystem3D"
add_child(board_system_3d)
systems["BoardSystem3D"] = board_system_3d
```

---

### Phase 2: 3D ノード収集

**目的**: シーンから必要な 3D ノード（タイル、プレイヤー、カメラ）を取得

**収集対象**:
- `Tiles` コンテナ → タイルノード群
- `Players` コンテナ → プレイヤー駒ノード群
- `Camera3D` → ゲームカメラ

**実装位置**: `scripts/system_manager/game_system_manager.gd` - `phase_2_collect_3d_nodes()`

```gdscript
tiles_container = parent_node.get_node_or_null("Tiles")
players_container = parent_node.get_node_or_null("Players")
camera_3d = parent_node.get_node_or_null("Camera3D")
```

---

### Phase 3: システム基本設定

**目的**: システムの基本初期化と 3D ノードの紐づけ

**実施内容**:

1. **PlayerSystem 初期化**
   ```gdscript
   player_system.initialize_players(player_count)
   ```

2. **カメラ初期位置設定**
   ```gdscript
   camera_3d.position = GameConstants.CAMERA_OFFSET  # Vector3(19, 19, 19)
   ```

3. **BoardSystem3D への参照設定**
   ```gdscript
   board_system_3d.camera = camera_3d
   board_system_3d.player_count = player_count
   board_system_3d.player_is_cpu = player_is_cpu
   board_system_3d.current_player_index = 0
   ```

4. **3D ノード収集**
   ```gdscript
   board_system_3d.collect_tiles(tiles_container)
   board_system_3d.collect_players(players_container)
   ```

5. **初期カメラ向き設定**
   ```gdscript
   # プレイヤー0（現在のプレイヤー）に向かせる
   var current_player_node = board_system_3d.player_nodes[0]
   var player_look_target = current_player_node.global_position
   player_look_target.y += 1.0  # 頭方向
   camera_3d.look_at(player_look_target, Vector3.UP)
   ```

**実装位置**: `scripts/system_manager/game_system_manager.gd` - `phase_3_setup_basic_config()`

---

### Phase 4: システム間連携設定

**目的**: システム間の参照を設定し、相互通信を可能にする

**実施内容** (4セクション):

#### 4-1: 基本システム参照設定
- GameFlowManager にすべてのシステムを設定
- BoardSystem3D にすべてのシステムを設定

#### 4-2: SpecialTileSystem 初期化
- 特殊マス効果を設定

#### 4-3: GameFlowManager のスペル・ハンドラー初期化
- spell_draw, spell_magic, spell_land, spell_curse, spell_dice 等を初期化

#### 4-4: BoardSystem3D のサブシステム初期化
- movement_controller に参照を設定

**実装位置**: `scripts/system_manager/game_system_manager.gd` - `phase_4_setup_system_interconnections()`

---

### Phase 5: シグナル接続

**目的**: システム間のシグナル通信を確立

**実施内容**:
- `tile_action_completed` → GameFlowManager への接続
- `hand_updated` → UIManager への接続
- その他システム間シグナルの接続

**実装位置**: `scripts/system_manager/game_system_manager.gd` - `phase_5_connect_signals()`

---

### Phase 6: ゲーム開始準備

**目的**: ゲーム開始前の最終準備

**実施内容**:
```gdscript
# プレイヤー情報パネルの更新
ui_manager.update_player_info_panels()

# ゲーム開始フラグの設定
is_initialized = true
```

**実装位置**: `scripts/system_manager/game_system_manager.gd` - `phase_6_prepare_game_start()`

---

## システム間の依存関係

```
GameSystemManager (統括)
├── Phase 1: 各システムインスタンス作成
├── Phase 2: 3D ノード収集
├── Phase 3: 基本初期化 + カメラ設定
│   └── BoardSystem3D.collect_players()
│       └── MovementController3D.initialize()
└── Phase 4: システム間連携
	├── GameFlowManager.setup_systems(...)
	├── BoardSystem3D.setup_systems(...)
	└── その他システム.setup_systems(...)
```

### 参照流れ

1. **GameFlowManager** ← すべてのシステム参照
2. **BoardSystem3D** ← board/battle/player 関連システム
3. **MovementController3D** ← player_system, special_tile_system

### 循環参照の回避

- **game_flow_manager** が中央のハブ
- 各サブシステムは game_flow_manager を参照するが、逆参照はない
- シグナルで疎結合を実現

---

## カメラシステムの実装

### カメラオフセット定数化

**背景**: 以前は `Vector3(19, 19, 19)` がハードコードされていました。

**改善**:

1. **定数化** (`scripts/game_constants.gd`)
   ```gdscript
   # === カメラ関連 ===
   const CAMERA_OFFSET = Vector3(19, 19, 19)  # カメラオフセット位置
   ```

2. **使用箇所統一**
   - `GameSystemManager` Phase 3
   - `MovementController3D` move_to_tile()
   - `MovementController3D` warp 時のカメラ移動

**利点**:
- バランス調整時に CAMERA_OFFSET を変更するだけで全体に反映
- ハードコード排除による保守性向上

---

### カメラワークの実装

#### ゲーム開始時（Phase 3）

```gdscript
# 1. カメラ位置をオフセット位置に設定
camera_3d.position = GameConstants.CAMERA_OFFSET

# 2. プレイヤー0に向かせる
var current_player_node = board_system_3d.player_nodes[0]
var player_look_target = current_player_node.global_position
player_look_target.y += 1.0
camera_3d.look_at(player_look_target, Vector3.UP)
```

#### プレイヤー移動時

```gdscript
func move_to_tile(player_id: int, tile_index: int) -> void:
	# 1. プレイヤーとカメラを並行して移動
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_node, "global_position", target_pos, MOVE_DURATION)
	
	if camera and player_system and player_id == player_system.current_player_index:
		var cam_target = target_pos + GameConstants.CAMERA_OFFSET
		tween.tween_property(camera, "global_position", cam_target, MOVE_DURATION)
	
	# 2. 移動完了後にカメラをプレイヤーに向ける
	await tween.finished
	camera_3d.look_at(target_pos + Vector3(0, 1.0, 0), Vector3.UP)
```

**重要**: `look_at()` は移動完了後に実行することで、スムーズで自然なカメラワークを実現

---

## 問題解決の履歴

### Issue 1: カメラが初期化時にプレイヤーを向かない

**原因**: ハードコードされたカメラ位置のみ設定し、向きの初期化がなかった

**解決**: Phase 3 の最後に初期カメラ向きを設定

```gdscript
camera_3d.look_at(player_look_target, Vector3.UP)
```

### Issue 2: 移動時にカメラがガクッと動く

**原因**: `look_at()` が移動中に即座に実行され、カメラ位置が変動中に向きが固定される

**解決**: `await tween.finished` で移動完了後に `look_at()` を実行

```gdscript
await tween.finished
camera_3d.look_at(target_pos + Vector3(0, 1.0, 0), Vector3.UP)
```

### Issue 3: カメラ角度が斜めになる

**原因**: オフセットと look_at の目標位置のバランスが取れていなかった

**解決**: 
- `Vector3(19, 19, 19)` をハードコード値として確立
- `look_at()` の目標を `player_position + Vector3(0, 1.0, 0)` に統一
- `Vector3.UP` を常に使用

---

## 使用方法

### ゲーム開始時

```gdscript
# game_3d.gd または main scene
var game_system_manager = GameSystemManager.new()
game_system_manager.name = "GameSystemManager"
add_child(game_system_manager)

# 6フェーズ初期化を実行
game_system_manager.initialize_all(
	self,                    # parent_node
	player_count,            # プレイヤー数
	player_is_cpu,           # CPU フラグ配列
	debug_manual_control_all # デバッグモード
)

# ゲーム開始
game_system_manager.start_game()
```

### システムへのアクセス

```gdscript
# GameSystemManager から各システムを取得
var board = game_system_manager.board_system_3d
var player = game_system_manager.player_system
var card = game_system_manager.card_system
```

---

## トラブルシューティング

### カメラが動かない

**確認事項**:
1. Phase 2 で `camera_3d` が正しく取得されているか
2. `player_system` が設定されているか
3. `player_system.current_player_index` が正しいか

**ログ確認**:
```
[GameSystemManager] Phase 3 カメラ設定前: (0.0, 10.0, 10.0)
[GameSystemManager] Phase 3 カメラ設定直後: (19.0, 19.0, 19.0)
```

### プレイヤーが停止する

**原因**: `await tween.finished` の重複実行

**確認**: `move_to_tile()` に `await tween.finished` が複数回ないか確認

### カメラが斜め

**原因**: 
- CAMERA_OFFSET が不正な値
- `look_at()` の target_pos 計算が不正

**確認**:
```gdscript
print("Camera position: ", camera_3d.position)
print("Camera target: ", target_pos)
```

---

## 今後の改善案

1. **カメラスムージング**: `look_at()` を Tween で滑らかに実行
2. **複数カメラモード**: 俯瞰・追従・固定カメラの切り替え
3. **カメラアニメーション**: ターン開始時の演出カメラ
4. **マルチプレイヤー対応**: プレイヤー切り替え時のスムーズなカメラ遷移

---

## 参考リンク

- `docs/design/design.md` - 全体アーキテクチャ
- `scripts/system_manager/game_system_manager.gd` - 実装コード
- `scripts/game_constants.gd` - 定数定義
- `scripts/movement_controller.gd` - カメラワーク実装

---

**作成日**: 2025-11-22  
**最終更新**: 2025-11-22  
**ステータス**: 実装完了
