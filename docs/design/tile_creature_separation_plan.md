# タイルとクリーチャーの分離設計計画

**バージョン**: 2.0  
**最終更新**: 2025年12月16日  
**ステータス**: ✅ 実装完了

## 1. 現状分析

> **⚠️ 注意**: セクション1-7は実装前の初期設計案（アーカイブ）です。
> **実際の実装は「10. 新設計: 参照方式による最小限変更」を参照してください。**

### 1.1 旧実装（Phase 3完了前）
- **クリーチャーデータの格納場所**: `BaseTile.creature_data` (Dictionary型)
- **視覚表現**: QuadMesh方式の3D表示（実装済み）
- **アクセス方法**: `tile.creature_data` で直接アクセス（実体はタイルに保存）

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

## 8. 実装状況 (2025年12月16日更新)

### ✅ 全Phase完了 🎉

- **Phase 1: CreatureManager実装** ✅
  - `scripts/creature_manager.gd` 完成
  - 基本機能: get_data_ref, set_data, has_creature, clear_data
  - 拡張機能: find_by_player, find_by_element, validate_integrity
  - セーブ/ロード機能実装

- **Phase 2: BaseTile統合** ✅
  - `BaseTile.creature_data` をプロパティ化（get/set）
  - CreatureManagerへの透過的なリダイレクト実装
  - `BoardSystem3D` での初期化実装

- **Phase 3: 完全移行** ✅
  - フォールバック機構（_local_creature_data）を削除
  - CreatureManagerへの完全依存に移行
  - 実ゲームでの動作確認完了

- **Phase 4: 3D表示機能** ✅
  - creature_card_3d_quad.gd: QuadMesh方式の3Dカード表示
  - base_tiles.gd: place_creature/remove_creature時の自動3D生成
  - _sync_creature_card_3d(): setter連動の自動同期
  - 動的データ更新機能（ステータス変化の即時反映）

- **旧Phase 2-3（API統一）**: 不要になりスキップ
  - 参照方式により既存コード800箇所の変更が不要に

### 🎉 完全移行完了！

**達成事項**:
- ✅ 既存コード800箇所を変更せずにデータ一元管理を実現
- ✅ すべてのクリーチャーデータがCreatureManagerに集約
- ✅ タイルからクリーチャーデータを完全分離
- ✅ 3Dカード表示の自動同期
- ✅ ゲーム内で不具合なく動作確認完了

### 選択した方針
**Phase 1から段階的に完全分離を開始**

理由:
- 呪文システム実装前にクリーチャー管理の正しい構造が必要
- 既に3D表示は動作しているため、Phase 1-3に集中できる
- 段階的移行により、リスクを最小化

## 9. Phase 1 実装計画

### タスクリスト
1. CreatureManager クラスの作成
2. CreatureInstance クラスの作成  
3. BoardSystem3D に CreatureManager を統合
4. 二重管理の実装（tile.creature_data と CreatureManager の並行稼働）
5. テスト: 既存機能が正常動作することを確認

## 10. 新設計: 参照方式による最小限変更 (2025年11月5日 - 決定版)

### 10.1 設計変更の経緯

#### 調査で判明した重要な事実

1. **creature_dataの性質**
   - 完全に独立したDictionary型のデータ
   - タイルは単なる「入れ物」に過ぎない
   - データ自体はコピー可能で、タイル間を移動できる

2. **実際の使用パターン**
   ```gdscript
   # 移動時: データをコピーして別タイルへ
   var creature_data = source_tile.creature_data.duplicate()
   source_tile.remove_creature()
   dest_tile.place_creature(creature_data)
   
   # バトル時: 辞書への参照を直接変更
   participant.creature_data["base_up_hp"] += 10
   creature_data["items"].append(item)
   ```

3. **既存コードの制約**
   - **約800箇所**で `creature_data["key"]` 形式の直接変更
   - `BattleParticipant` がバトル中に辞書への参照を保持
   - `get_tile_info()["creature"]` が辞書への参照を返す
   - これらを全て書き換えるのは非現実的

#### Phase 1-5の問題点

当初計画のPhase 2-3（API統一）では、800箇所のコード変更が必要で：
- 膨大な工数（20-25時間）
- 高いバグ混入リスク
- 既存システムとの互換性問題

### 10.2 新設計: 参照透過方式

#### 設計コンセプト

**「既存コードを一切変更せず、データの保存場所だけを変える」**

Godotのプロパティget/set機能を活用し、`tile.creature_data` へのアクセスを透過的にCreatureManagerへリダイレクトします。

#### 実装詳細

##### CreatureManager (scripts/creature_manager.gd)

```gdscript
extends Node
class_name CreatureManager

# すべてのクリーチャーデータを一元管理
var creatures: Dictionary = {}  # {tile_index: creature_data辞書}

# BoardSystemへの参照
var board_system: Node = null

# データへの参照を返す（重要: コピーではなく参照！）
func get_data_ref(tile_index: int) -> Dictionary:
	if not creatures.has(tile_index):
		creatures[tile_index] = {}
	return creatures[tile_index]

# データ全体を設定
func set_data(tile_index: int, data: Dictionary):
	if data.is_empty():
		# 空の辞書が渡された = 削除
		creatures.erase(tile_index)
	else:
		creatures[tile_index] = data.duplicate(true)

# デバッグ出力
func debug_print():
	print("[CreatureManager] 管理中: ", creatures.size(), "体")
	for idx in creatures.keys():
		var d = creatures[idx]
		if not d.is_empty():
			print("  タイル", idx, ": ", d.get("name", "???"))
```

##### BaseTile の変更 (scripts/tiles/base_tiles.gd)

```gdscript
extends Node3D
class_name BaseTile

# CreatureManagerへの静的参照
static var creature_manager: CreatureManager = null

# creature_data をプロパティに変更（フォールバックなし - 完全移行済み）
var creature_data: Dictionary:
	get:
		if creature_manager:
			return creature_manager.get_data_ref(tile_index)
		else:
			push_error("[BaseTile] CreatureManager が初期化されていません！")
			return {}
	set(value):
		if creature_manager:
			creature_manager.set_data(tile_index, value)
		else:
			push_error("[BaseTile] CreatureManager が初期化されていません！")
		# 3Dカードの同期（自動）
		_sync_creature_card_3d(value)

# 3Dカード同期（setterから呼ばれる）
func _sync_creature_card_3d(data: Dictionary):
	if data.is_empty():
		# データが空 → 3Dカード削除
		if creature_card_3d:
			creature_card_3d.queue_free()
			creature_card_3d = null
	else:
		# データあり → 更新または新規作成
		if creature_card_3d:
			if creature_card_3d.has_method("set_creature_data"):
				creature_card_3d.set_creature_data(data)
		else:
			_create_creature_card_3d()
	# 通行料ラベルの同期
	_sync_tile_info_display()

# 既存メソッドは変更不要！
func place_creature(data: Dictionary):
	creature_data = data.duplicate()  # setterが自動的に呼ばれる
	# ... 以下同じ ...

func remove_creature():
	creature_data = {}  # setterが自動的に呼ばれる
	# ... 以下同じ ...
```

##### BoardSystem3D での初期化

```gdscript
# board_system_3d.gd の _ready() に追加
func _ready():
	# CreatureManagerを作成
	var cm = CreatureManager.new()
	cm.board_system = self
	add_child(cm)
	
	# BaseTileの静的参照を設定
	BaseTile.creature_manager = cm
	
	print("[BoardSystem3D] CreatureManager統合完了")
```

### 10.3 この設計の利点

#### ✅ 既存コード800箇所を変更不要

```gdscript
# これらが全てそのまま動く！
tile.creature_data["base_up_hp"] = 10
var name = tile.creature_data.get("name", "")
participant.creature_data["items"].append(item)
creature_data["temporary_effects"] = []
```

#### ✅ データはCreatureManagerに集約

- すべてのクリーチャーデータが`CreatureManager.creatures`に保存
- デバッグが容易（`CreatureManager.debug_print()`で一覧表示）
- セーブ/ロードの簡素化（一箇所からデータ取得）

#### ✅ 段階的な移行が可能

1. CreatureManager実装（フォールバック付き）
2. BoardSystemに統合
3. 動作確認
4. フォールバック削除（オプション）

#### ✅ 3D表示管理の統合が容易

```gdscript
# CreatureManagerに追加可能
var visual_nodes: Dictionary = {}  # {tile_index: Node3D}

func set_visual_node(tile_index: int, node: Node3D):
	visual_nodes[tile_index] = node
```

### 10.4 削除処理の3つのシナリオ

#### シナリオA: 移動時の削除

```gdscript
# データはコピーされて移動
var data = source_tile.creature_data.duplicate()  
# → CreatureManager.get_data_ref(source_index) からコピー取得

source_tile.remove_creature()  
# → creature_data = {} → CreatureManager.set_data(source_index, {})
# → CreatureManager.creatures から source_index が削除される

dest_tile.place_creature(data)  
# → creature_data = data → CreatureManager.set_data(dest_index, data)
# → CreatureManager.creatures[dest_index] に新規追加
```

#### シナリオB: 倒された時（手札復帰）

```gdscript
# タイルから削除、CardSystemに移動
var data = tile.creature_data.duplicate()
# → CreatureManagerからコピー取得

tile.remove_creature()
# → CreatureManagerから削除

card_system.return_card_to_hand(player_id, data)
# → 手札システムへ
```

#### シナリオC: 完全削除（破壊など）

```gdscript
# データごと消滅
tile.remove_creature()
# → CreatureManagerから削除
# → データはGCで自動回収
```

### 10.5 技術的な詳細

#### プロパティget/setの動作

```gdscript
# 読み取り時
var name = tile.creature_data.get("name", "")
↓
var name = CreatureManager.get_data_ref(tile_index).get("name", "")

# 書き込み時（辞書全体）
tile.creature_data = new_data
↓
CreatureManager.set_data(tile_index, new_data)

# 書き込み時（キーへの代入）
tile.creature_data["base_up_hp"] = 10
↓
CreatureManager.get_data_ref(tile_index)["base_up_hp"] = 10
```

#### 参照の重要性

**重要**: `get_data_ref()` は参照を返すため、既存コードの`creature_data["key"] = value`がそのまま動作します。

```gdscript
# これが動く理由
var ref = tile.creature_data  # → CreatureManager内の辞書への参照
ref["base_up_hp"] = 10  # → CreatureManager内のデータが直接変更される
```

### 10.6 実装ステップ（全完了）

#### Step 1: CreatureManager作成 ✅
- `scripts/creature_manager.gd` 作成済み
- 基本的なデータ保管機能実装済み
- 拡張機能（検索・集計）実装済み

#### Step 2: BaseTileへのプロパティ追加 ✅
- creature_dataプロパティをget/set化
- フォールバック機構を削除（完全移行）
- 3Dカード同期（_sync_creature_card_3d）を追加

#### Step 3: BoardSystemでの初期化 ✅
```gdscript
# board_system_3d.gd の _ready() で実行済み
var cm = CreatureManager.new()
cm.board_system = self
add_child(cm)
BaseTile.creature_manager = cm
```

#### Step 4: 動作確認 ✅
- 既存の全機能が正常動作することを確認済み
- `CreatureManager.debug_print()` でデータ集約を確認済み
- バトル、移動、手札復帰などのテスト完了

### 10.7 Phase 2以降の計画変更

#### 旧計画
- Phase 2: 読み取りAPI統一（8-12時間）
- Phase 3: 書き込みAPI統一（10-15時間）
- 合計: 18-27時間

#### 新計画
**Phase 2-3は不要！**

参照方式により、既存コードの書き換えが不要になったため、18-27時間の工数を削減。

直接、機能拡張（3D表示管理、クリーチャー検索など）へ進める。

### 10.8 リスク評価

| リスク | 影響度 | 確率 | 対策 |
|--------|--------|------|------|
| プロパティget/setの性能オーバーヘッド | 低 | - | Godotのプロパティは最適化済み |
| 参照の不整合 | 低 | 低 | フォールバック機構で安全 |
| 静的変数の初期化タイミング | 中 | 低 | BoardSystemの_ready()で明示的に設定 |
| セーブ/ロードの互換性 | 中 | 中 | 移行期は両方式をサポート |

### 10.9 成功基準（全達成）

- ✅ すべての既存機能が正常動作 → **確認済み**
- ✅ `CreatureManager.debug_print()` でデータが集約されている → **確認済み**
- ✅ バトル、移動、手札復帰が正常動作 → **確認済み**
- ✅ 3D表示が正常に更新される → **確認済み**
- ✅ 3Dカードがsetterで自動同期される → **確認済み**

### 10.10 今後の拡張

#### 3D表示ノード管理
```gdscript
# CreatureManagerに追加
var visual_nodes: Dictionary = {}

func set_visual_node(tile_index: int, node: Node3D):
	visual_nodes[tile_index] = node

func update_all_visuals():
	for tile_index in creatures.keys():
		if visual_nodes.has(tile_index):
			visual_nodes[tile_index].update_creature_data(creatures[tile_index])
```

#### クリーチャー検索
```gdscript
func find_by_player(player_id: int) -> Array:
	var result = []
	for idx in creatures.keys():
		var tile_info = board_system.get_tile_info(idx)
		if tile_info.get("owner") == player_id:
			result.append({"tile_index": idx, "data": creatures[idx]})
	return result

func find_by_element(element: String) -> Array:
	var result = []
	for idx in creatures.keys():
		if creatures[idx].get("element") == element:
			result.append({"tile_index": idx, "data": creatures[idx]})
	return result
```

### 10.11 まとめ

**この設計により達成したこと:**
- ✅ 既存コード800箇所の変更が不要に
- ✅ 工数を18-27時間削減
- ✅ データの一元管理を実現
- ✅ リスクを最小化
- ✅ 3Dカード表示の自動同期

**実装完了日**: 2025年11月5日（Phase 1-3）、2025年12月（3D同期強化）

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025/10 | 初版作成（設計案） |
| 2025/11/05 | Phase 1-3 実装完了 |
| 2025/12/16 | v2.0 - 3D同期強化、ドキュメント整理、フォールバック削除を反映 |

---
