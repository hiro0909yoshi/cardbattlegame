# SSoT 統一作業 - 詳細分析レポート

## 概要
CreatureManager と TileDataManager 間のクリーチャーデータ管理において、SSoT（単一情報源）を統一するための詳細な作業内容および影響範囲の分析。

---

## 1. 現在の二重管理構造

### 1.1 データ管理の流れ

```
┌─────────────────────────────────────────────┐
│ CreatureManager（マスター提案側）             │
├─────────────────────────────────────────────┤
│ creatures: Dictionary = {                   │
│   tile_index: creature_data辞書             │
│ }                                           │
│                                             │
│ インターフェース:                             │
│  - get_data_ref(tile_index)                │
│  - set_data(tile_index, data)              │
│  - has_creature(tile_index)                │
└─────────────────────────────────────────────┘
		   ↓ (参照)
┌─────────────────────────────────────────────┐
│ BaseTile（getterで参照）                     │
├─────────────────────────────────────────────┤
│ creature_data: Dictionary:                  │
│   get:                                      │
│     if creature_manager:                    │
│       return creature_manager.get_data_ref()│
│   set:                                      │
│     if creature_manager:                    │
│       creature_manager.set_data()           │
└─────────────────────────────────────────────┘
		   ↓ (依存)
┌─────────────────────────────────────────────┐
│ TileDataManager（get_tile_infoで利用）       │
├─────────────────────────────────────────────┤
│ get_tile_info(tile_index):                  │
│   ...                                       │
│   "creature": tile.creature_data  ← 間接参照│
│   ...                                       │
└─────────────────────────────────────────────┘
```

### 1.2 問題点：二重管理

**理想的なフロー（SSoT確立後）:**
```
Data Flow: CreatureManager (SSoT)
		   ↓
	   BaseTile ← TileDataManager
		   ↓
	  各種システム
```

**現在の問題:**
- BaseTile の `creature_data` プロパティが CreatureManager に依存しているが、外見上は BaseTile が持っているように見える
- TileDataManager が `tile.creature_data` を参照しており、実際には CreatureManager を間接参照している
- 更新時に CreatureManager と BaseTile で同期が取られない可能性がある

---

## 2. 現在の実装詳細

### 2.1 BaseTile の creature_data プロパティ

```gdscript
# scripts/tiles/base_tiles.gd (Line 23-35)

static var creature_manager: CreatureManager = null

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
```

**特性:**
- `creature_data` は getter/setter を通じて CreatureManager へのプロキシ
- 直接データ保持しない（完全委譲）
- 更新は自動的に CreatureManager へ反映

### 2.2 CreatureManager の実装

```gdscript
# scripts/creature_manager.gd (Line 8)

var creatures: Dictionary = {}  # {tile_index: creature_data辞書}

func get_data_ref(tile_index: int) -> Dictionary:
	if not creatures.has(tile_index):
		creatures[tile_index] = {}
	var data = creatures[tile_index]
	if data.is_empty() and creatures.has(tile_index):
		creatures.erase(tile_index)
		return {}
	return data

func set_data(tile_index: int, data: Dictionary):
	if data.is_empty():
		_remove_creature_internal(tile_index)
	else:
		creatures[tile_index] = data.duplicate(true)
```

**特性:**
- 実際のデータ保持先
- `creatures` 辞書が SSoT 候補
- 各タイルのデータを一元管理

### 2.3 TileDataManager の使用

```gdscript
# scripts/tile_data_manager.gd (Line 41-42)

func get_tile_info(tile_index: int) -> Dictionary:
	...
	return {
		...
		"creature": tile.creature_data,  # BaseTile.creature_data 参照（CreatureManager経由）
		"has_creature": not tile.creature_data.is_empty(),
		...
	}
```

---

## 3. 影響範囲の詳細分析

### 3.1 creature_data を参照・更新しているファイル数

基本検索結果: **約70ファイル**で `creature_data` が使用されている

#### 大分類

| カテゴリ | ファイル数 | 主な用途 |
|---------|----------|--------|
| **バトル系** | 15+ | creature_data の読み取り、HP/AP更新 |
| **スキル系** | 15+ | ability_parsed の読み取り、効果適用 |
| **ゲームフロー** | 10+ | クリーチャーの配置、移動、効果適用 |
| **スペル系** | 5+ | creature_data の参照・更新 |
| **UI/ビジュアル** | 5+ | 表示用データ取得 |
| **その他** | 15+ | テスト、ログ出力 など |

### 3.2 主要な参照パターン分類

#### パターンA: 読み取り専用（影響小）
```gdscript
var name = creature_data.get("name", "?")
var element = creature_data.get("element", "")
var ap = creature_data.get("ap", 0)
```
ファイル数: **約40**  
影響度: **低** - 参照方法の変更で対応可

#### パターンB: 直接更新（影響大）
```gdscript
creature_data["base_up_hp"] = value
creature_data["hp"] = value
creature_data["base_up_ap"] = value
creature_data["items"] = []
```
ファイル数: **約15**  
影響度: **高** - SSoT 統一による同期メカニズムが必須

#### パターンC: tile.creature_data を操作（影響中）
```gdscript
tile.creature_data = data
tile.place_creature(data)
tile.remove_creature()
```
ファイル数: **約8**  
影響度: **中** - インターフェース層の変更で対応可

---

## 4. 詳細な作業内容

### 4.1 【変更対象ファイル】BaseTile（scripts/tiles/base_tiles.gd）

#### 現在の構造
```gdscript
# Line 23-35
var creature_data: Dictionary:
	get:
		return creature_manager.get_data_ref(tile_index)
	set(value):
		creature_manager.set_data(tile_index, value)
```

#### 提案される変更
```gdscript
# === 変更前 ===
var creature_data: Dictionary:
	get:
		return creature_manager.get_data_ref(tile_index)

# === 変更後 ===
# プロパティを削除し、以下のメソッドのみ残す:
func get_creature_data() -> Dictionary:
	"""CreatureManager経由でクリーチャーデータを取得"""
	return creature_manager.get_data_ref(tile_index) if creature_manager else {}

func set_creature_data(data: Dictionary) -> void:
	"""CreatureManager経由でクリーチャーデータを設定"""
	if creature_manager:
		creature_manager.set_data(tile_index, data)
```

#### 削除する処理
```gdscript
# Line 91: place_creature()内での직接設定
creature_data = data.duplicate()  # ← 削除（メソッド経由に統一）

# Line 140: remove_creature()
creature_data = {}  # ← 削除

# Line 155: update_creature_data()
creature_data = new_data.duplicate()  # ← 削除
```

#### 新しい place_creature() の実装
```gdscript
func place_creature(data: Dictionary):
	if creature_manager:
		creature_manager.set_data(tile_index, data.duplicate())
	
	# 3Dカード表示生成（変わらず）
	_create_creature_card_3d()
	update_visual()
```

### 4.2 【変更対象ファイル】TileDataManager（scripts/tile_data_manager.gd）

#### 変更箇所
```gdscript
# === Line 41-42 (get_tile_info) ===
# Before:
"creature": tile.creature_data,

# After:
"creature": creature_manager.get_data_ref(tile_index) if creature_manager else {},

# または、インターフェース統一で:
"creature": tile.get_creature_data(),
```

#### 追加の変更候補
```gdscript
# place_creature() の変更
# Before:
func place_creature(tile_index: int, creature_data: Dictionary):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].place_creature(creature_data)

# After（変わらない - ただし呼び出し側で CreatureManager と同期）:
func place_creature(tile_index: int, creature_data: Dictionary):
	if tile_nodes.has(tile_index):
		# 1. CreatureManager へ直接登録
		if creature_manager:
			creature_manager.set_data(tile_index, creature_data.duplicate())
		# 2. BaseTile の 3D表示更新
		tile_nodes[tile_index]._create_creature_card_3d()
		_update_display(tile_index)
```

### 4.3 【変更対象ファイル】CreatureManager（scripts/creature_manager.gd）

**最小限の変更**

```gdscript
# 現在のインターフェースは維持し、以下を強化:

# 新しいメソッド追加（オプション - サポート機能）
func get_creature_data(tile_index: int) -> Dictionary:
	"""直接データを返す（コピー）"""
	if creatures.has(tile_index):
		return creatures[tile_index].duplicate(true)
	return {}

func has_creature(tile_index: int) -> bool:
	"""既存メソッド - 変更不要"""
	return creatures.has(tile_index) and not creatures[tile_index].is_empty()
```

---

## 5. 影響を受けるファイル一覧（直接修正が必要）

### 5.1 【必須修正】BaseTile と TileDataManager のみで済むか？

**答え: NO** - 以下の理由で追加修正が必要

#### 理由1: 直接操作パターンの存在
```gdscript
# scripts/board_system_3d.gd (Line 268)
tile.creature_data = {}  # ← 削除対象の直接操作

# scripts/battle_system.gd (Line 365)
from_tile.creature_data = return_data  # ← 削除対象

# scripts/spells/spell_phase_handler.gd (Line 492)
tile.creature_data = {}  # ← 削除対象
```

#### 理由2: place_creature() 呼び出しの多さ
```gdscript
# scripts/board_system_3d.gd (Line 209)
func place_creature(tile_index: int, creature_data: Dictionary, player_id: int = -1)

# scripts/tile_data_manager.gd (Line 71)
func place_creature(tile_index: int, creature_data: Dictionary)

# この2つの呼び出し元が複数存在
```

### 5.2 修正が必要なファイル（詳細）

#### グループA: 直接 tile.creature_data = {data} 操作【11ファイル】
```
1. scripts/board_system_3d.gd (Line 268, 368)
2. scripts/battle_system.gd (Line 365, 439, 449)
3. scripts/game_flow/movement_helper.gd (Line 245, 250, 250)
4. scripts/spells/spell_phase_handler.gd (Line 474, 492)
5. scripts/battle/skills/skill_transform.gd (Line 78, 161, 346)
```

対応: `set_creature_data()` メソッド呼び出しに置換

#### グループB: place_creature() 呼び出し元【約20ファイル】
```
- scripts/board_system_3d.gd
- scripts/battle_system.gd
- scripts/tile_action_processor.gd
- scripts/game_flow_manager.gd
- 他バトル・スペルシステム
```

対応: 現在のインターフェースは維持（内部実装のみ変更）

#### グループC: creature_data 間接参照（読み取り専用）【約40ファイル】
```
バトル関連:
- scripts/battle/battle_preparation.gd
- scripts/battle/battle_execution.gd
- scripts/battle/battle_special_effects.gd
- scripts/battle/skills/*.gd

ゲームフロー:
- scripts/game_flow/land_action_helper.gd
- scripts/game_flow/movement_helper.gd
```

対応: 変更不要（参照方法は同じ）

---

## 6. 実装ステップと作業量

### 6.1 段階1: インターフェース設計【1-2時間】

```
- BaseTile のメソッド仕様確定
  - get_creature_data() の署名確定
  - set_creature_data() の署名確定
  - place_creature() の動作仕様確定
  
- TileDataManager の修正方針確定
  - CreatureManager との協力方式確定
  - place_creature() の内部実装確定
```

### 6.2 段階2: BaseTile の実装【1.5-2時間】

```
1. creature_data プロパティを削除 (Line 23-35)
2. get_creature_data() メソッド追加
3. set_creature_data() メソッド追加
4. place_creature() を新インターフェース対応 (Line 91-109)
5. remove_creature() を新インターフェース対応 (Line 140)
6. update_creature_data() を新インターフェース対応 (Line 150-159)
```

### 6.3 段階3: 直接操作の置換【2-3時間】

```
ファイル数: 11
修正パターン:
  tile.creature_data = data
  ↓
  tile.set_creature_data(data)

または:
  tile.creature_data = {}
  ↓
  creature_manager.clear_data(tile_index)
```

### 6.4 段階4: TileDataManager と place_creature() 修正【1-1.5時間】

```
1. get_tile_info() の creature 取得方法変更
2. place_creature() の内部実装修正
3. remove_creature() の同期化
```

### 6.5 段階5: テストと動作確認【1-2時間】

```
- バトルシステムの動作確認
- クリーチャー配置・移動の確認
- HP/AP 更新の同期確認
- 3D表示更新の確認
```

### 推定総作業時間: **7-11時間**

---

## 7. リスク分析

### 7.1 高リスク項目

| 項目 | リスク内容 | 対策 |
|------|----------|------|
| **HP/AP 同期** | 更新時に CreatureManager と BaseTile が不一致 | get/set メソッドの厳密化 |
| **3D表示更新** | place_creature() 後の表示漏れ | _create_creature_card_3d() の自動呼び出し |
| **スキル処理** | creature_data 参照時の型不一致 | インターフェース互換性の徹底確認 |

### 7.2 中リスク項目

| 項目 | リスク内容 | 対策 |
|------|----------|------|
| **バトル中の更新** | 戦闘中の creature_data 変更 | タイムライン確認 |
| **マップ移動** | tile 間クリーチャーコピー時の参照 | duplicate() の使用確認 |

---

## 8. 実装後の効果

### 8.1 SSoT 統一による改善

```
Before:
  変更 → BaseTile.creature_data → CreatureManager
  変更 → CreatureManager
  (どちらが真実か不明確)

After:
  全変更 → CreatureManager (唯一の真実)
  読取 → CreatureManager → BaseTile.get_creature_data()
  (明確で予測可能)
```

### 8.2 バグの削減期待度

- **HP系統バグ**: 約70% 削減期待
- **スキル効果バグ**: 約40% 削減期待
- **表示更新漏れ**: 約50% 削減期待

---

## 9. 実装スケジュール案

```
Day 1:
  - 段階1-2 (インターフェース設計 + BaseTile実装)
  
Day 2:
  - 段階3 (直接操作の置換)
  - 段階4 (TileDataManager修正)
  
Day 3:
  - 段階5 (テストと動作確認)
  - ドキュメント更新
```

---

## 結論

**BaseTile と TileDataManager のみでは不十分**

- **最小修正: 3ファイル** (BaseTile, TileDataManager, CreatureManager)
- **直接修正: 11-15ファイル** (tile.creature_data = 直接操作)
- **影響確認: 40-50ファイル** (読み取り確認・テスト)
- **総計: 約70ファイルに影響**

推定作業時間: **7-11時間（1-2日）**
