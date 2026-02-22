# タイルシステム設計書

## 概要

カードバトルゲームにおけるタイルの仕様、判定ロジック、操作APIをまとめたリファレンスドキュメント。

---

## タイルの基本構造

### タイルが持つプロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `tile_type` | String | タイル種別（fire, water, earth, wind, neutral, checkpoint, warp等） |
| `owner_id` | int | 所有者プレイヤーID（-1 = 空き地） |
| `level` | int | タイルレベル（1〜5） |
| `creature_data` | Dictionary | 配置されているクリーチャーのデータ（空 = クリーチャーなし） |
| `is_down` | bool | ダウン状態か |

### プロパティの取得例

```gdscript
var tile = board_system.tile_nodes[tile_index]
var tile_type = tile.tile_type        # "fire", "water"等
var owner = tile.owner_id             # 0, 1, -1等
var level = tile.level                # 1〜5
var creature = tile.creature_data     # Dictionary
var is_empty = creature.is_empty()    # クリーチャーがいないか
```

---

## 自動同期システム

タイルのプロパティを変更すると、関連する表示が自動的に同期される。

### 同期対象

| プロパティ | 3Dカード表示 | 通行料ラベル |
|-----------|-------------|-------------|
| `creature_data` | ✅ 自動同期 | ✅ 自動同期 |
| `owner_id` | - | ✅ 自動同期 |
| `level` | - | ✅ 自動同期 |

### 仕組み

各プロパティはsetterで監視されており、値が変更されると自動的に表示が更新される。

```gdscript
# 例: creature_dataを変更すると3Dカードと通行料ラベルが自動更新
tile.creature_data = new_data  # → 3Dカード作成/更新 + 通行料ラベル更新

# 例: owner_idを変更すると通行料ラベルが自動更新
tile.owner_id = -1  # → 通行料ラベル非表示

# 例: levelを変更すると通行料ラベルが自動更新
tile.level = 3  # → 通行料金額が更新
```

### 静的参照

BaseTileクラスは以下の静的参照を持つ（全タイルで共有）：

| 参照 | 型 | 用途 |
|------|-----|------|
| `creature_manager` | CreatureManager | クリーチャーデータの一元管理 |
| `tile_info_display` | TileInfoDisplay | 通行料ラベルの表示更新 |

### place_creature / remove_creature

配置・削除メソッドを使用しても、内部でsetterを経由するため自動同期される。

```gdscript
# どちらの方法でも自動同期される
tile.place_creature(data)      # 推奨
tile.creature_data = data      # 同様に動作

tile.remove_creature()         # 推奨
tile.creature_data = {}        # 同様に動作
```

---

## CreatureManager統合

### 概要

クリーチャーデータはタイルから分離され、`CreatureManager`で一元管理される。
`tile.creature_data`へのアクセスは透過的に`CreatureManager`へリダイレクトされる。

**詳細設計は [tile_creature_separation_plan.md](tile_creature_separation_plan.md) を参照。**

### 仕組み

```gdscript
# BaseTile のプロパティ定義
var creature_data: Dictionary:
	get:
		return creature_manager.get_data_ref(tile_index)
	set(value):
		creature_manager.set_data(tile_index, value)
		_sync_creature_card_3d(value)  # 3Dカード同期
```

### 静的参照

| 参照 | 型 | 用途 |
|------|-----|------|
| `creature_manager` | CreatureManager | クリーチャーデータの一元管理 |
| `tile_info_display` | TileInfoDisplay | 通行料ラベルの表示更新 |

### メリット

- 既存コード800箇所を変更せずにデータ一元管理を実現
- デバッグが容易（`CreatureManager.debug_print()`で一覧表示）
- セーブ/ロードの簡素化

---

## タイルタイプ一覧

### 配置可能タイル（6種）

クリーチャーを配置できるタイル。

| tile_type | 配置可 | 停止可 | 地形変化可 | 地形効果 | 備考 |
|-----------|--------|--------|------------|----------|------|
| fire | ✅ | ✅ | ✅ | ✅ | 火属性タイル |
| water | ✅ | ✅ | ✅ | ✅ | 水属性タイル |
| earth | ✅ | ✅ | ✅ | ✅ | 地属性タイル |
| wind | ✅ | ✅ | ✅ | ✅ | 風属性タイル |
| neutral | ✅ | ✅ | ✅ | ✅ | 無属性（全クリーチャーに地形効果） |
| blank | ✅ | ✅ | - | - | 配置時にクリーチャー属性に変化 |

※ blankは配置した瞬間に属性タイルに変化するため、blank状態でクリーチャーがいることはない

### 特殊タイル（配置不可）

| tile_type | 停止可 | 備考 |
|-----------|--------|------|
| checkpoint | ✅ | ゲート（周回判定用） |
| warp | ❌ | 通過型ワープ |
| warp_stop | ✅ | 停止型ワープ |
| card_buy | ✅ | カード購入（未実装） |
| card_give | ✅ | カード譲渡（未実装） |
| magic | ✅ | 魔法タイル（未実装） |
| magic_stone | ✅ | 魔法石タイル（未実装） |
| switch | ✅ | 分岐器タイル（未実装） |
| base | ✅ | 拠点タイル（未実装） |

**各特殊タイルの詳細仕様・実装方法は [special_tiles.md](special_tiles.md) を参照。**
**マップ上の配置（ワープ先、周回判定など）は [map_system.md](map_system.md) を参照。**

---

## TileHelperクラス

タイル判定を一元管理するヘルパークラス。

### ファイル場所

`scripts/tile_helper.gd`

### 定数

```gdscript
## 配置可能タイル（クリーチャーを置ける）6種
const PLACEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank"]

## 属性タイル（4属性）
const ELEMENT_TILES = ["fire", "water", "earth", "wind"]

## 停止不可タイル（通過型）
const NO_STOP_TILES = ["warp"]

## 特殊タイル（配置不可）
const SPECIAL_TILES = [
	"checkpoint", "warp", "warp_stop",
	"card", "card_buy", "card_give",
	"magic", "magic_stone",
	"switch", "base", "start"
]

## 地形変化可能タイル
const TERRAIN_CHANGEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank"]
```

### 判定メソッド（tileオブジェクト版）

| メソッド | 戻り値 | 説明 |
|----------|--------|------|
| `is_placeable_tile(tile)` | bool | 配置可能タイルか（6種） |
| `is_special_tile(tile)` | bool | 特殊タイルか（配置不可） |
| `is_element_tile(tile)` | bool | 属性タイルか（4種） |
| `can_place_creature(tile)` | bool | クリーチャー配置可能か（タイル種別＋空きチェック） |
| `is_empty_land(tile)` | bool | 空き地か（所有者がいない配置可能タイル） |
| `can_stop_at(tile)` | bool | 移動先として停止可能か |
| `can_change_terrain(tile)` | bool | 地形変化可能か |
| `has_land_effect(tile)` | bool | 地形効果があるか（属性タイル + neutral） |

### 判定メソッド（tile_type文字列版）

| メソッド | 戻り値 | 説明 |
|----------|--------|------|
| `is_placeable_type(tile_type)` | bool | 配置可能タイルか |
| `is_special_type(tile_type)` | bool | 特殊タイルか |
| `is_element_type(tile_type)` | bool | 属性タイルか |
| `can_stop_at_type(tile_type)` | bool | 停止可能か |
| `can_change_terrain_type(tile_type)` | bool | 地形変化可能か |
| `has_land_effect_type(tile_type)` | bool | 地形効果があるか |

### 使用例

```gdscript
# クリーチャー移動先の判定
if TileHelper.is_placeable_tile(tile):
	# 移動可能

# 空き地の検索
if TileHelper.is_empty_land(tile):
	# クリーチャー配置可能な空き地

# 地形変化可能かチェック
if TileHelper.can_change_terrain(tile):
	# 地形変化を実行
```

---

## タイルレベルシステム

### レベル範囲

- 最小: 1
- 最大: 5（GameConstants.MAX_LEVEL）

### 通行料・レベルアップコスト

**詳細は [toll_system.md](toll_system.md) を参照。**

| 項目 | 参照先 |
|------|--------|
| 通行料計算式 | toll_system.md |
| レベル倍率 | GameConstants.TOLL_LEVEL_MULTIPLIER |
| 連鎖ボーナス | GameConstants.CHAIN_BONUS_* |
| レベルアップコスト | GameConstants.LEVEL_VALUES |

---

## 地形効果システム

### 基本仕様

クリーチャーが属性一致するタイルにいる場合、戦闘時にHPボーナスを得る。

```
HP += レベル × 10
```

### 地形効果が発動する条件

1. **属性タイル + クリーチャー属性一致**
   - fireタイルに火属性クリーチャー
   - waterタイルに水属性クリーチャー
   - earthタイルに地属性クリーチャー
   - windタイルに風属性クリーチャー

2. **neutralタイル**
   - 全クリーチャーに地形効果

3. **追加属性スキル**
   - 例: 「地形効果[火水]」を持つクリーチャーは火・水タイルでも地形効果

4. **恩寵呪い**
   - 呪いにより追加の属性から地形効果を得る

### 判定場所

`scripts/spells/spell_curse_battle.gd` の `has_land_effect()`

---

## タイル連鎖システム

### 仕様

同じプレイヤーが所有する同属性タイルの数に応じて、通行料にボーナスが付く。

**詳細は [toll_system.md](toll_system.md) を参照。**

### 判定場所

`scripts/tile_data_manager.gd` の `get_element_chain_count()` / `calculate_chain_bonus()`

---

## タイル関連クラス一覧

| クラス | ファイル | 役割 |
|--------|----------|------|
| TileHelper | `scripts/tile_helper.gd` | タイル判定ヘルパー（静的メソッド） |
| TileDataManager | `scripts/tile_data_manager.gd` | タイルデータ管理、通行料計算 |
| BaseTile | `scripts/tiles/base_tiles.gd` | タイル基底クラス |
| FireTile | `scripts/tiles/fire_tile.gd` | 火属性タイル |
| WaterTile | `scripts/tiles/water_tile.gd` | 水属性タイル |
| EarthTile | `scripts/tiles/earth_tile.gd` | 地属性タイル |
| WindTile | `scripts/tiles/wind_tile.gd` | 風属性タイル |
| NeutralTile | `scripts/tiles/neutral_tile.gd` | 無属性タイル |
| CheckpointTile | `scripts/tiles/checkpoint_tile.gd` | チェックポイントタイル |
| WarpTile | `scripts/tiles/warp_tile.gd` | ワープタイル |
| SpecialTileSystem | `scripts/special_tile_system.gd` | 特殊タイル処理 |

---

## タイル操作API

### クリーチャー配置

```gdscript
# BaseTile.place_creature()
tile.place_creature(creature_data)
```

- creature_dataをコピーして配置
- 3Dカード生成
- base_up_hp/ap等の初期化

### クリーチャー削除

```gdscript
# BoardSystem3D.remove_creature()
board_system.remove_creature(tile_index)
```

- creature_dataをクリア
- 3Dカード削除

### 所有者変更

```gdscript
# TileDataManager.set_tile_owner()
board_system.set_tile_owner(tile_index, player_id)
```

- owner_idを設定
- 色の更新

### 地形変化

```gdscript
# BoardSystem3D.change_tile_terrain()
board_system.change_tile_terrain(tile_index, new_element)
```

- tile_typeを変更
- ビジュアル更新

### レベルアップ

```gdscript
# TileDataManager.level_up_tile()
board_system.tile_data_manager.level_up_tile(tile_index)
```

---

## マップ構造との関係

### tile_nodes

```gdscript
# BoardSystem3D.tile_nodes
# tile_index -> BaseTile のマッピング
var tile = board_system.tile_nodes[tile_index]
```

### タイル隣接関係

```gdscript
# TileNeighborSystem
var neighbors = board_system.tile_neighbor_system.get_spatial_neighbors(tile_index)
# 隣接するタイルインデックスの配列を返す
```

### タイル情報取得

```gdscript
# TileDataManager.get_tile_info()
var info = board_system.get_tile_info(tile_index)
# {
#   "index": tile_index,
#   "element": "fire"等,
#   "owner": player_id,
#   "level": 1-5,
#   "creature": Dictionary,
#   "has_creature": bool,
#   "is_special": bool
# }
```

---

## タイル追加手順

新しいタイルタイプを追加する場合の手順。

### ケース1: 配置可能タイルを追加

例: `crystal`タイルを追加

**修正ファイル: `scripts/tile_helper.gd` のみ**

```gdscript
# 1. PLACEABLE_TILESに追加（必須）
const PLACEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank", "crystal"]

# 2. 地形変化可能なら追加
const TERRAIN_CHANGEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank", "crystal"]

# 3. 4属性に含めるなら追加（通常は不要）
# const ELEMENT_TILES = ["fire", "water", "earth", "wind"]  # 変更なし
```

### ケース2: 特殊タイル（配置不可）を追加

例: `shop`タイルを追加

**修正ファイル: `scripts/tile_helper.gd` のみ**

```gdscript
# 1. SPECIAL_TILESに追加（必須）
const SPECIAL_TILES = [
	"checkpoint", "warp", "warp_stop",
	"card", "card_buy", "card_give",
	"magic", "magic_stone",
	"switch", "base", "start",
	"shop"  # 追加
]

# 2. 停止不可（通過型）なら追加
const NO_STOP_TILES = ["warp", "shop"]
```

### 追加時のチェックリスト

| 質問 | Yes → 追加先 |
|------|-------------|
| クリーチャー配置可能？ | `PLACEABLE_TILES` |
| 4属性タイル？ | `ELEMENT_TILES` |
| 地形変化可能？ | `TERRAIN_CHANGEABLE_TILES` |
| 配置不可（特殊）？ | `SPECIAL_TILES` |
| 停止不可（通過型）？ | `NO_STOP_TILES` |
| 地形効果あり？ | `has_land_effect()` メソッド内を確認 |

---

## 関連ドキュメント

| ファイル | 内容 |
|----------|------|
| `docs/design/map_system.md` | マップシステム全体 |
| `docs/design/lap_system.md` | 周回システム（チェックポイント） |
| `docs/design/land_system.md` | ドミニオオーダー |
| `docs/design/toll_system.md` | 通行料システム |
| `docs/design/tile_creature_separation_plan.md` | タイル・クリーチャー分離設計 |
| `docs/design/skills/vacant_move_skill.md` | 瞬移・敵地移動スキル |

---

## クリーチャー選択（タップ判定）

### 概要

マップ上の3Dクリーチャーカードをタップ/クリックして選択する機能。
選択されたクリーチャーの情報パネルを表示する。

### 判定構造

```
CreatureCard3DQuad (Node3D)
├── SubViewport
├── MeshInstance3D (QuadMesh) - 表示用
└── Area3D (タップ判定用)
	└── CollisionShape3D (BoxShape3D)
```

### シグナル

```gdscript
# CreatureCard3DQuad
signal creature_tapped(creature_data: Dictionary, tile_index: int)
```

### タップ判定の有効化

CreatureCard3DQuadの`_setup_tap_detection()`でArea3D + CollisionShape3Dを追加。

```gdscript
# Area3Dの設定
var area = Area3D.new()
area.input_ray_pickable = true  # Raycastでの選択を有効化

# CollisionShapeのサイズ（カードサイズに合わせる）
var box_shape = BoxShape3D.new()
box_shape.size = Vector3(CARD_3D_WIDTH, CARD_3D_HEIGHT, 0.1)
```

### 入力イベント処理

```gdscript
func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	# マウスクリック（PC）
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			creature_tapped.emit(creature_data, tile_index)
	# タッチ（スマホ）
	elif event is InputEventScreenTouch:
		if event.pressed:
			creature_tapped.emit(creature_data, tile_index)
```

### タイルインデックスの取得

クリーチャーがどのタイルに配置されているかを知るため、`tile_index`を保持。

```gdscript
# CreatureCard3DQuadに追加
var tile_index: int = -1

# base_tiles.gdで配置時に設定
func _create_creature_card_3d():
	creature_card_3d = Node3D.new()
	creature_card_3d.set_script(CREATURE_CARD_3D_SCRIPT)
	creature_card_3d.tile_index = tile_index  # タイルインデックスを設定
	add_child(creature_card_3d)
```

### UIManagerとの接続

```gdscript
# UIManager
func _connect_creature_tap_signals():
	# 全タイルのクリーチャーカードにシグナル接続
	for tile in board_system.tile_nodes.values():
		if tile.creature_card_3d:
			if not tile.creature_card_3d.creature_tapped.is_connected(_on_creature_tapped):
				tile.creature_card_3d.creature_tapped.connect(_on_creature_tapped)

func _on_creature_tapped(creature_data: Dictionary, tile_index: int):
	# 情報パネルを表示
	creature_info_panel.show_creature_info(creature_data, tile_index)
```

### 関連ドキュメント

詳細は `docs/design/card_info_panels.md` を参照。

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025/12/08 | 初版作成。TileHelperによるリファクタリング完了 |
| 2025/12/09 | 自動同期システム追加（creature_data, owner_id, level変更時に3Dカード・通行料ラベルを自動更新） |
| 2025/12/11 | クリーチャー選択（タップ判定）セクション追加 |
| 2025/12/16 | CreatureManager統合セクション追加、通行料計算をtoll_system.mdに集約 |
| 2025/12/16 | 特殊タイル動作詳細をmap_system.mdに集約、tile_info["type"]削除 |
| 2025/12/17 | 特殊タイル詳細仕様への参照（special_tiles.md）を追加 |
