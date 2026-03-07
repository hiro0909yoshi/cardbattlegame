# 背景環境設計書

クエストモードの3D背景環境（城壁・地面・植生・ライティング・門）の設計と実装詳細。

---

## 概要

マップタイルを囲む中世城壁環境を全てプロシージャル生成する。
タイルコンテナのバウンディングボックスから動的にサイズを計算し、城壁・地面・塔・門・植生を配置する。

### 構成ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/quest/castle_environment.gd` | 城壁・地面・塔・門・蔦・草の生成 |
| `scripts/quest/quest_game.gd` | ライティング・空・カメラの設定 |
| `assets/shaders/brick_wall.gdshader` | レンガ壁シェーダー |
| `assets/shaders/stone_cap.gdshader` | 笠石シェーダー |
| `assets/building_parts/floor3.glb` | 地面タイリング用モデル |
| `assets/building_parts/floor3_stone_ground_05_color.jpg` | 笠石テクスチャ |
| `assets/models/gate_door.glb` | 門扉GLBモデル（Meshy AI生成、最適化済み） |

---

## シーン構築順序

`quest_game.gd._setup_3d_scene_before_init()` で以下の順に構築:

1. Camera3D 作成（俯瞰45度）
2. 既存 WorldEnvironment 除去
3. DirectionalLight3D（太陽光）追加
4. WorldEnvironment + ProceduralSkyMaterial 追加
5. タイルコンテナ作成 + StageLoader でマップ生成
6. CastleEnvironment 作成（45度回転）→ `setup_from_tiles()` で動的構築

### CastleEnvironment 構築順序（`_build()`）

```
_create_brick_material()  → レンガシェーダー準備
_create_ground()          → 地面タイリング
_create_walls()           → 四方の壁 + 笠石 + 門 + 胸壁
_create_corner_towers()   → 四隅の塔
_create_ivy()             → 壁面の蔦（MultiMesh）
_create_grass_patches()   → 地面の草（MultiMesh）
```

---

## ライティング・環境（quest_game.gd）

### 太陽光（DirectionalLight3D）

| パラメータ | 値 |
|-----------|-----|
| rotation_degrees | (-45, 30, 0) |
| light_energy | 1.0 |
| light_color | Color(1.0, 0.95, 0.9) |
| shadow_enabled | true |
| directional_shadow_max_distance | 60.0 |

### 空（ProceduralSkyMaterial）

| パラメータ | 値 |
|-----------|-----|
| sky_top_color | Color(0.35, 0.55, 0.85) |
| sky_horizon_color | Color(0.65, 0.75, 0.88) |
| ground_bottom_color | Color(0.25, 0.22, 0.18) |
| ground_horizon_color | Color(0.55, 0.55, 0.50) |

### 環境光

| パラメータ | 値 |
|-----------|-----|
| background_mode | BG_SKY |
| ambient_light_source | AMBIENT_SOURCE_SKY |
| ambient_light_energy | 0.4 |

---

## 城壁パラメータ（castle_environment.gd）

### 定数一覧

| 定数 | 値 | 説明 |
|------|-----|------|
| WALL_MARGIN | 11.0 | マップ端から壁までの余白 |
| WALL_HEIGHT | 6.0 | 壁の高さ |
| WALL_THICKNESS | 1.2 | 壁の厚み |
| BATTLEMENT_HEIGHT | 0.8 | 胸壁の高さ |
| BATTLEMENT_WIDTH | 1.5 | 胸壁の幅 |
| BATTLEMENT_GAP | 1.2 | 胸壁の隙間 |
| TOWER_RADIUS | 2.0 | 塔の半径 |
| TOWER_HEIGHT | 8.0 | 塔の高さ |
| TOWER_SIDES | 12 | 塔の多角形分割数 |
| GATE_WIDTH | 4.0 | 門の幅 |
| GATE_HEIGHT | 4.5 | 門の高さ |
| GATE_THICKNESS | 0.3 | 扉の厚み |
| GROUND_MARGIN | 8.0 | 城壁外側の地面余白 |
| GROUND_Y | -0.3 | 地面Y座標 |
| IVY_COUNT_PER_WALL | 5 | 壁1面あたりの蔦の数 |
| GRASS_PATCH_COUNT | 120 | 草パッチの数 |

### 動的サイズ計算

```gdscript
# タイルコンテナからバウンディングボックスを計算
_map_center = (min_pos + max_pos) / 2.0
_map_half_size = max(幅, 奥行) / 2.0 + 1.5

# 壁の配置距離
half = _map_half_size + WALL_MARGIN
```

CastleEnvironment 自体は `rotation.y = 45度` で配置されており、タイル座標をローカル座標に変換して計算する。

---

## 壁構造

### 四方の壁

| 壁 | 方向 | 門の有無 |
|----|------|---------|
| 北壁 (Z-) | 横方向 | なし |
| 南壁 (Z+) | 横方向 | なし |
| 西壁 (X-) | 縦方向 | あり（内側面に配置） |
| 東壁 (X+) | 縦方向 | あり（内側面に配置、180度回転） |

各壁の構成:
- 壁本体: BoxMesh + レンガシェーダー
- 笠石（キャップストーン）: BoxMesh + 石テクスチャ
- 胸壁（バトルメント）: BoxMesh + レンガシェーダー + 個別キャップ

### 四隅の塔

各塔の構成:
- 塔本体: CylinderMesh（12角形、半径2.0、高さ8.0）+ 暗めレンガシェーダー
- 上部張り出し: CylinderMesh（半径+0.4、高さ0.6）
- 円錐屋根: CylinderMesh（top_radius=0.01、bottom_radius=2.6、高さ3.0）

---

## 門

### 構成

東西壁の内側面に配置。壁からのオフセット: `WALL_THICKNESS / 2.0 + GATE_THICKNESS / 2.0`

```
gate_root (Node3D)
  +-- DoorModel (GLBモデル) - スケーリング配置
  +-- ArchFrame (ArrayMesh半円リング) - レンガ枠
  +-- GatePillar_-1/1 (BoxMesh) - 門柱
  +-- PillarCap_-1/1 (BoxMesh) - 柱キャップ
  +-- Keystone (BoxMesh) - 楔石
```

### GLBモデル（gate_door.glb）

| 項目 | 値 |
|------|-----|
| 元モデル | Meshy AI 生成「Riveted Iron Door」 |
| 頂点数 | 2,980 |
| 三角形数 | 2,255 |
| テクスチャ解像度 | 512x512（元2048から縮小） |
| テクスチャ枚数 | 3（ベースカラー、ノーマル、メタリック/ラフネス） |
| ファイルサイズ | 200KB |
| モデル原点 | 底辺中央（Bottom Y = 0） |
| モデルサイズ | 3.550 x 4.000 x 0.382 (W x H x D) |

### スケーリング

モデルサイズをGATE定数に合わせてスケーリング:

```gdscript
scale_x = GATE_WIDTH / 3.550    # 幅: 1.127
scale_y = GATE_HEIGHT / 4.0     # 高さ: 1.125
scale_z = GATE_THICKNESS / 0.382 # 奥行: 0.785
```

### 回転

| 門 | is_ew | flip | rotation.y |
|----|-------|------|-----------|
| 西門 (GateWest) | true | false | PI/2 (90度) |
| 東門 (GateEast) | true | true | PI/2 + PI (270度) |

### 門モデル最適化の経緯

1. 元モデル: 9,537頂点 / 8,916三角形 / 5.3MB
2. Blenderで裏面ポリゴン削減: 2,980頂点 / 2,255三角形
3. テクスチャを2048x2048 → 512x512にリサイズ
4. 最終: 200KB（96%削減）

### 門モデル差し替え手順

新しいGLBモデルに差し替える場合:
1. `assets/models/gate_door.glb` を上書き
2. モデルのバウンディングボックスを確認（原点はBottom必須）
3. `_create_gate()` 内のモデルサイズ定数（3.550, 4.0, 0.382）を新モデルの値に更新
4. Godotでインポート確認

---

## マテリアル

### レンガシェーダー（brick_wall.gdshader）

壁本体・胸壁に使用。プロシージャルレンガパターンを生成。

塔用バリエーション（暗め）:
```
brick_color_1: (0.44, 0.43, 0.40)
brick_color_2: (0.50, 0.48, 0.45)
brick_color_3: (0.36, 0.35, 0.32)
brick_width: 0.6, brick_height: 0.25
moss_amount: 0.25
```

### 笠石マテリアル

`floor3_stone_ground_05_color.jpg` テクスチャを使用。
- albedo_color: Color(0.7, 0.68, 0.65) でテクスチャを少し暗く
- uv1_scale: Vector3(2.0, 2.0, 1.0)
- uv1_triplanar: true

---

## 植生

### 蔦（MultiMeshInstance3D x 2）

壁面に生成。葉と茎を別々のMultiMeshで管理。

- 壁1面あたり5本
- 各蔦の幅: 1.5〜3.5、高さ: 0.5〜3.5
- 茎: 蛇行パターン（`grow_lean` + `drift`）
- 葉: ハート型 ArrayMesh（`_create_heart_leaf_mesh()`）、法線 Vector3(0,0,-1)
- 色バリエーション: MultiMesh.use_colors で個別着色（緑系のランダム）
- RNG seed: 葉=99999、茎=54321（再現性のため固定シード）

### 草（MultiMeshInstance3D x 1）

地面に生成。城壁寄りに密、マップタイル範囲は除外。

- パッチ数: 120
- 葉の形状: 弧状（5セグメント、根元太く先端が垂れる）
- 配置ロジック:
  - マップタイル範囲（`_map_half_size + 1.5`）内はスキップ
  - 壁からの距離が近いほど1パッチあたりの葉が多い（3〜9枚）
- 色バリエーション: MultiMesh.use_colors で個別着色（緑系のランダム）
- RNG seed: 配置=12345、色=77777

---

## 地面

### floor3.glb タイリング

`assets/building_parts/floor3.glb` を格子状にタイリング配置。

- タイリング範囲: `_map_half_size * 2 + (WALL_MARGIN + GROUND_MARGIN) * 2`
- Y座標: GROUND_Y = -0.3（タイルより下）
- フォールバック: GLBが見つからない場合は単色BoxMeshで代替

---

## モバイル最適化

| 対策 | 内容 |
|------|------|
| CSG排除 | 全CSGノード → MeshInstance3D + プリミティブメッシュに置換 |
| 松明無効化 | `_create_torches()` コメントアウト（OmniLight3Dが重い） |
| 霧削除 | flowing_fog.gdshader 含め完全削除 |
| MultiMesh活用 | 蔦（葉+茎）と草をMultiMeshInstance3Dで1ドローコールに集約 |
| GLBテクスチャ縮小 | 門モデルのテクスチャを2048→512に縮小（5.3MB→200KB） |
| 門モデル軽量化 | 裏面ポリゴン削除（9,537→2,980頂点） |

### 松明（現在無効）

松明システムは実装済みだがモバイル負荷対策で無効化中。
有効化する場合は `_build()` 内の `#_create_torches()` のコメントを外す。

- 壁面に等間隔配置（間隔10.0）
- 各松明: 柄(CylinderMesh) + 布巻き(CylinderMesh) + 炎(SphereMesh, emission) + OmniLight3D
- `_process()` で無理数比周波数の揺らめきアニメーション

---

## ArrayMesh 一覧

| メソッド | 用途 | 備考 |
|---------|------|------|
| `_create_semicircle_mesh()` | 半円板（アーチ扉） | clip_half_w でクリップ対応 |
| `_create_arch_frame_mesh()` | 半円リング（アーチ枠） | 前面・後面・外側面の3面 |
| `_create_arched_door_mesh()` | アーチ付き扉（UV付き） | 現在未使用（GLBモデルに置換） |
| `_create_heart_leaf_mesh()` | ハート型の蔦の葉 | 法線 Z- 方向 |
| `_create_grass_blade_mesh()` | 弧状の草の葉 | 5セグメント、先端が垂れる |

---

## ノード階層（実行時）

```
QuestGame (Node3D)
  +-- Camera3D
  +-- SunLight (DirectionalLight3D)
  +-- QuestWorldEnv (WorldEnvironment)
  +-- Tiles (Node3D) - マップタイル
  +-- CastleEnvironment (Node3D, rotation.y=45deg)
  |     +-- Ground (Node3D) - floor3.glb タイリング
  |     +-- WallNorth/South/West/East (MeshInstance3D)
  |     +-- WallCapNorth/South/West/East (MeshInstance3D)
  |     +-- GateWest (Node3D)
  |     |     +-- DoorModel (GLBインスタンス)
  |     |     +-- ArchFrame, GatePillar, PillarCap, Keystone
  |     +-- GateEast (Node3D)
  |     |     +-- DoorModel (GLBインスタンス, +180deg)
  |     |     +-- ArchFrame, GatePillar, PillarCap, Keystone
  |     +-- BattlementNS_*/EW_* (MeshInstance3D) - 胸壁
  |     +-- BattCapNS_*/EW_* (MeshInstance3D) - 胸壁キャップ
  |     +-- Tower_0~3 (MeshInstance3D) - 塔本体
  |     +-- TowerTop_0~3 (MeshInstance3D) - 塔上部
  |     +-- TowerRoof_0~3 (MeshInstance3D) - 塔屋根
  |     +-- IvyLeaves (MultiMeshInstance3D)
  |     +-- IvyStems (MultiMeshInstance3D)
  |     +-- GrassPatches (MultiMeshInstance3D)
  +-- Players (Node3D)
```

---

Last Updated: 2026-03-06
