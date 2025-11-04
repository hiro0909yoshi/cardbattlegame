# タイルとクリーチャーの分離設計計画

## 1. 現状分析

### 1.1 現在の実装
- **クリーチャーデータの格納場所**: `BaseTile.creature_data` (Dictionary型)
- **視覚表現**: なし（現在はクリーチャーの3D表示が未実装）
- **アクセス方法**: `tile.creature_data` で直接アクセス

### 1.2 影響範囲の調査結果

#### 広範な使用箇所（約800+箇所）
```
主な使用ファイル:
- scripts/battle/ (バトルシステム全体)
  - battle_execution.gd (47箇所)
  - battle_preparation.gd (121箇所)
  - battle_special_effects.gd (48箇所)
  - battle_skill_processor.gd (81箇所)
  - battle_participant.gd (16箇所)
  
- scripts/battle/skills/ (スキルシステム全体、15ファイル)
  - 各スキルで creature_data を参照・操作
  
- scripts/game_flow/ (ゲームフロー)
  - land_action_helper.gd (42箇所)
  - movement_helper.gd (23箇所)
  - spell_phase_handler.gd (3箇所)
  - item_phase_handler.gd (12箇所)
  
- scripts/ (コアシステム)
  - board_system_3d.gd (45箇所)
  - battle_system.gd (88箇所)
  - tile_action_processor.gd (8箇所)
  - movement_controller.gd (21箇所)
  - game_flow_manager.gd (31箇所)
```

## 2. 目標とする設計

### 2.1 分離後の構造

#### 新しいCreatureManagerシステム
```gdscript
class_name CreatureManager
extends Node

# クリーチャーインスタンスの管理
var creatures: Dictionary = {}  # {tile_index: CreatureInstance}

class CreatureInstance:
    var data: Dictionary        # クリーチャーの基本データ
    var node_3d: Node3D        # 3D表示ノード
    var tile_index: int        # 配置タイル
```

#### タイルの役割
- 土地所有権、レベル、属性などの情報のみ保持
- クリーチャーの有無は `CreatureManager.has_creature(tile_index)` で確認

### 2.2 3Dクリーチャー表示の実装方法

#### 方法1: Sprite3D（推奨）
```gdscript
# 各タイル上にSprite3Dノードを配置
var creature_sprite = Sprite3D.new()
creature_sprite.texture = load("res://assets/creatures/creature_001.png")
creature_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # カメラに向く
creature_sprite.position = Vector3(0, 1.0, 0)  # タイルの上
creature_sprite.pixel_size = 0.01  # サイズ調整
```

**メリット**:
- 2D画像を3D空間に簡単に配置
- 常にカメラを向く（見やすい）
- 軽量で多数表示可能
- ステータスアイコンも同じ方法で追加可能

**実装例**:
```gdscript
# CreatureVisual.gd
extends Node3D
class_name CreatureVisual

@onready var sprite: Sprite3D = $Sprite3D
@onready var status_icons: Node3D = $StatusIcons

func set_creature_texture(texture_path: String):
    sprite.texture = load(texture_path)

func add_status_icon(icon_type: String):
    var icon = Sprite3D.new()
    icon.texture = load("res://assets/icons/" + icon_type + ".png")
    icon.position = Vector3(0.5, 0.8, 0)  # クリーチャーの右上
    icon.pixel_size = 0.005
    status_icons.add_child(icon)
```

#### 方法2: 3Dモデル（将来の拡張用）
```gdscript
# より高度な表現が必要な場合
var creature_model = load("res://assets/creatures/creature_001.glb").instantiate()
creature_model.position = Vector3(0, 0.5, 0)
```

#### 方法3: TextureRect（Camera-facing quad）
```gdscript
# MeshInstance3Dにテクスチャを貼る
var mesh = QuadMesh.new()
var material = StandardMaterial3D.new()
material.albedo_texture = load("res://assets/creatures/creature_001.png")
material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
```

## 3. 段階的移行プラン

### Phase 1: CreatureManagerの作成（影響最小）
**目標**: 新システムを構築しながら、既存システムは動作維持

**実装内容**:
1. `CreatureManager` クラスの作成
2. `CreatureInstance` クラスの作成
3. `BaseTile` に `creature_manager_ref` を追加
4. 二重管理期間の開始
   - `tile.creature_data` は残す
   - `CreatureManager` も並行稼働

**影響範囲**: 新規ファイル追加のみ、既存コード変更なし

### Phase 2: 読み取りAPIの統一（低リスク）
**目標**: クリーチャー情報の読み取りを新APIに統一

**実装内容**:
1. ヘルパー関数の作成
```gdscript
# creature_accessor.gd (新規)
class_name CreatureAccessor

static func get_creature_data(tile_or_index) -> Dictionary:
    # 新旧両対応
    if tile_or_index is BaseTile:
        return tile_or_index.creature_data
    else:
        return CreatureManager.get_creature_data(tile_or_index)

static func has_creature(tile_or_index) -> bool:
    # 同様に両対応
```

2. 既存コードを段階的に移行
   - 最初は `tile.creature_data` の代わりに `CreatureAccessor.get_creature_data(tile)` を使用
   - 内部では依然として `tile.creature_data` を参照

**影響範囲**: 全ファイル（ただし、機械的置換が可能）

### Phase 3: 書き込みAPIの統一（中リスク）
**目標**: クリーチャー情報の変更を新APIに統一

**実装内容**:
1. 変更用APIの作成
```gdscript
class_name CreatureModifier

static func place_creature(tile_index: int, creature_data: Dictionary):
    # 旧システム更新
    tile.creature_data = creature_data.duplicate()
    # 新システム更新
    CreatureManager.place_creature(tile_index, creature_data)

static func remove_creature(tile_index: int):
    # 両システムから削除

static func modify_creature_data(tile_index: int, key: String, value):
    # 両システムで変更
```

**影響範囲**: 書き込み箇所約200箇所

### Phase 4: 3D表示の実装（新機能）
**目標**: クリーチャーの視覚化

**実装内容**:
1. `CreatureVisual.tscn` シーンの作成
   - Sprite3Dベースの表示
   - ステータスアイコン用のコンテナ

2. `CreatureManager` に表示管理を追加
```gdscript
func create_visual(tile_index: int):
    var visual = CREATURE_VISUAL_SCENE.instantiate()
    var creature = creatures[tile_index]
    
    # テクスチャ設定
    var texture_path = "res://assets/creatures/%d.png" % creature.data.get("id")
    visual.set_creature_texture(texture_path)
    
    # タイル上に配置
    var tile = board_system.get_tile(tile_index)
    tile.add_child(visual)
    creature.node_3d = visual
```

**影響範囲**: 新規実装、既存システムへの影響なし

### Phase 5: 旧システムの削除（高リスク）
**目標**: `tile.creature_data` の完全削除

**実装内容**:
1. `CreatureAccessor` の実装を新システムのみに変更
2. `BaseTile.creature_data` の削除
3. 全テストの実行と検証

**影響範囲**: 全システム（ただし、APIレベルでは既に移行済み）

## 4. 技術的な課題と解決策

### 4.1 パフォーマンス
**課題**: 辞書検索のオーバーヘッド
**解決策**: 
- タイルに `creature_index` を持たせる
- LRUキャッシュの導入

### 4.2 データ整合性
**課題**: 二重管理期間のデータ同期
**解決策**:
- すべての変更を `CreatureModifier` 経由に強制
- デバッグモードで同期チェック

### 4.3 セーブ/ロード
**課題**: セーブデータ形式の変更
**解決策**:
- Phase 3まではセーブ形式を変更しない
- Phase 5でマイグレーション機能を実装

### 4.4 バトルシステム
**課題**: `BattleParticipant.creature_data` の大量使用
**解決策**:
- `BattleParticipant` は引き続き `creature_data` を保持
- バトル開始時に `CreatureManager` からコピー
- バトル終了時に書き戻し

## 5. 推定工数

| Phase | タスク | 推定工数 | リスク |
|-------|--------|----------|--------|
| 1 | CreatureManager実装 | 3-5時間 | 低 |
| 2 | 読み取りAPI統一 | 8-12時間 | 低 |
| 3 | 書き込みAPI統一 | 10-15時間 | 中 |
| 4 | 3D表示実装 | 5-8時間 | 低 |
| 5 | 旧システム削除 | 3-5時間 | 高 |
| **合計** | | **29-45時間** | |

## 6. 代替案: 最小限のアプローチ

もし完全な分離が困難な場合、最小限の変更で3D表示を実現する方法:

```gdscript
# BaseTileに追加
var creature_visual: CreatureVisual = null

func place_creature(data: Dictionary):
    creature_data = data.duplicate()
    _create_creature_visual()
    update_visual()

func _create_creature_visual():
    if creature_visual:
        creature_visual.queue_free()
    
    if creature_data.is_empty():
        return
    
    creature_visual = CREATURE_VISUAL_SCENE.instantiate()
    add_child(creature_visual)
    
    var texture_path = "res://assets/creatures/%d.png" % creature_data.get("id")
    creature_visual.set_creature_texture(texture_path)
```

**メリット**:
- 既存のコードへの影響が最小限
- 工数: 5-8時間程度

**デメリット**:
- システム的に「正しくない」設計
- 将来の拡張性が低い

## 7. 推奨アプローチ

**短期的**: 代替案で3D表示を先に実現
**中長期的**: Phase 1-5の完全な分離を計画的に実施

理由:
1. ユーザーへの価値（3D表示）を早期に提供できる
2. 完全な分離は大規模なリファクタリングが必要
3. 呪文システムなど、優先度の高い他の機能開発がある
4. 将来的に必要になった時点で段階的に移行可能

## 8. 次のステップ

ユーザーの選択:
- [ ] **Option A**: 代替案で先に3D表示を実装（推奨）
- [ ] **Option B**: Phase 1から段階的に完全分離を開始
- [ ] **Option C**: 現状維持（3D表示は後回し）

どのオプションを選択されますか？
