# 死者復活効果 設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**作成日**: 2025年10月24日  
**ステータス**: 設計中

---

## 📋 目次

1. [概要](#概要)
2. [復活の種類とパターン](#復活の種類とパターン)
3. [初期実装対象](#初期実装対象)
4. [データ構造設計](#データ構造設計)
5. [墓地システムとの連携](#墓地システムとの連携)
6. [実装フロー](#実装フロー)
7. [今後の実装予定](#今後の実装予定)

---

## 概要

### 目的
墓地から特定のクリーチャーを復活させる効果を実装する。死者復活はクリーチャースキル、アイテム、スペルで使用される。

### 基本仕様
- **復活の本質**: 墓地にあるクリーチャーを指定タイルに配置
- **復活時の状態**: 元の基礎HP/APで復活（効果はリセット）
- **墓地の状態**: 復活したクリーチャーは墓地から削除
- **条件**: 墓地に対象クリーチャーが存在する必要がある

---

## 復活の種類とパターン

### 1. 特定クリーチャーの復活
**例**: ヘルグラマイト（ID: 139）→ サーペントフライ復活

```json
{
  "ability": "死者復活[サーペントフライ]",
  "ability_detail": "死者復活[サーペントフライ]"
}
```

**仕様**:
- 召喚時に自動発動
- 墓地にサーペントフライがあれば復活
- ない場合は何も起きない
- 復活先タイルは自動選択（空いている自領地）

---

### 2. 高コストクリーチャーの復活
**例**: グレートフォシル（ID: 411）→ ティラノサウルス復活

```json
{
  "ability": "防御型・通行料変化・死者復活",
  "ability_detail": "防御型；通行料変化[G0]；死者復活[ティラノサウルス]"
}
```

**仕様**:
- 召喚時に自動発動
- 墓地にティラノサウルスがあれば復活
- 防御型・通行料変化と組み合わせ
- 特殊な召喚コスト（MP30 + カード1枚生贄）

---

### 3. グループからの復活
**例**: （将来実装予定）

```json
{
  "effect": "死者復活[スケルトン系]"
}
```

**仕様**:
- 墓地から特定グループ（例：スケルトン系）を選択
- プレイヤーが選択
- スペルやアイテムで実装予定

---

### 4. 任意クリーチャーの復活
**例**: （将来実装予定）復活スペル

```json
{
  "effect": "死者復活[選択]"
}
```

**仕様**:
- 墓地から任意のクリーチャーを選択
- プレイヤーが選択
- 高コストスペルで実装予定

---

## 初期実装対象

### Phase 1: 基本実装（2体）

| ID | 名前 | 復活対象 | 実装理由 |
|---|---|---|---|
| **139** | ヘルグラマイト | サーペントフライ | 基本的な復活メカニズムの確立 |
| **411** | グレートフォシル | ティラノサウルス | 高コストクリーチャー復活 |

**実装内容**:
1. 墓地システムとの連携
2. 特定クリーチャーの復活処理
3. 召喚時の自動発動処理
4. 復活先タイルの自動選択

---

## データ構造設計

### ability_parsedの構造

```gdscript
{
  "keywords": ["死者復活"],
  "effects": [
    {
      "effect_type": "revive",
      "trigger": "on_summon",              # 発動タイミング
      "revive_type": "specific",           # 復活タイプ
      "target_creature_id": 316,           # サーペントフライのID
      "target_creature_name": "サーペントフライ",
      "placement_type": "auto",            # 配置方法
      "placement_target": "own_empty_land", # 配置先
      "conditions": [
        {
          "condition_type": "graveyard_has_creature",
          "creature_id": 316
        }
      ]
    }
  ]
}
```

### 復活タイプ（revive_type）

| タイプ | 説明 | 例 |
|---|---|---|
| `specific` | 特定IDのクリーチャー | ヘルグラマイト |
| `group` | グループから選択 | スケルトン系 |
| `select` | プレイヤーが選択 | 復活スペル |
| `last_destroyed` | 最後に破壊されたクリーチャー | （将来実装） |

### 配置タイプ（placement_type）

| タイプ | 説明 |
|---|---|
| `auto` | 自動選択（空いている自領地） |
| `select` | プレイヤーが選択 |
| `specific_tile` | 特定のタイル |

---

## 墓地システムとの連携

### 墓地の構造

```gdscript
# プレイヤーごとの墓地
var graveyard: Dictionary = {
	"player_1": [
		{
			"creature_id": 316,
			"name": "サーペントフライ",
			"destroyed_turn": 5,
			"destroyed_by": "battle"
		},
		{
			"creature_id": 228,
			"name": "ドラゴンゾンビ",
			"destroyed_turn": 7,
			"destroyed_by": "spell"
		}
	],
	"player_2": [...]
}
```

### 墓地への追加

```gdscript
func add_to_graveyard(player_id: String, creature_data: Dictionary) -> void:
	if not graveyard.has(player_id):
		graveyard[player_id] = []
	
	graveyard[player_id].append({
		"creature_id": creature_data["id"],
		"name": creature_data["name"],
		"destroyed_turn": current_turn,
		"destroyed_by": "battle"  # or "spell", "effect"
	})
```

### 墓地からの復活

```gdscript
func revive_from_graveyard(player_id: String, creature_id: int) -> Dictionary:
	if not graveyard.has(player_id):
		return {}
	
	# 墓地から該当クリーチャーを検索
	for i in range(graveyard[player_id].size()):
		if graveyard[player_id][i]["creature_id"] == creature_id:
			# 墓地から削除
			var creature_info = graveyard[player_id][i]
			graveyard[player_id].remove_at(i)
			
			# クリーチャーデータを取得
			return CardDatabase.get_creature(creature_id)
	
	return {}
```

---

## 実装フロー

### 1. 召喚時の自動復活（ヘルグラマイト）

```
1. ヘルグラマイトを召喚
   ↓
2. ability_parsedをチェック
   ↓
3. effect_type == "revive" && trigger == "on_summon"
   ↓
4. 条件チェック
   ├─ 墓地にサーペントフライが存在するか？
   └─ YES: 復活処理へ / NO: 何もしない
   ↓
5. 復活処理を実行
   ├─ 墓地からサーペントフライを取得
   ├─ 墓地から削除
   ├─ 空いている自領地を検索
   ├─ サーペントフライを配置
   └─ UIを更新
   ↓
6. 復活完了
```

### 2. 復活先タイルの選択ロジック

```gdscript
func find_empty_own_land(player_id: String) -> Tile:
	var own_lands = board_system.get_player_tiles(player_id)
	
	# 空いている自領地を検索
	for tile in own_lands:
		if tile.creature_data == null:
			return tile
	
	# 空き地がない場合
	return null
```

### 3. 完全な復活処理

```gdscript
func execute_revive_effect(
	player_id: String,
	creature_id: int,
	placement_type: String
) -> bool:
	# 1. 墓地から復活
	var creature_data = revive_from_graveyard(player_id, creature_id)
	if creature_data.is_empty():
		print("墓地に対象クリーチャーが存在しません")
		return false
	
	# 2. 配置先を決定
	var target_tile = null
	if placement_type == "auto":
		target_tile = find_empty_own_land(player_id)
	elif placement_type == "select":
		# プレイヤーに選択させる（UI実装時）
		target_tile = await select_tile_from_player(player_id)
	
	if target_tile == null:
		print("配置できるタイルがありません")
		# 墓地に戻す
		add_to_graveyard(player_id, creature_data)
		return false
	
	# 3. クリーチャーを配置
	creature_data["owner_id"] = player_id
	creature_data["permanent_effects"] = []
	creature_data["temporary_effects"] = []
	target_tile.creature_data = creature_data
	
	# 4. UI更新
	update_creature_visual(target_tile)
	
	print("%s が復活しました！" % creature_data["name"])
	return true
```

---

## 今後の実装予定

### Phase 2: アイテムによる復活
- ネクロスカラベ（ID: 1046）→ スケルトン復活
- その他アイテム

**追加実装**:
- アイテム使用時の復活処理
- プレイヤーによる配置先選択

### Phase 3: スペルによる復活
- 復活スペル（将来実装）
- グループ選択復活
- 任意選択復活

**追加実装**:
- 墓地からの選択UI
- 複数復活処理

### Phase 4: 条件付き復活
- 特定条件での自動復活
- ターン経過後の復活
- その他特殊復活

---

## 検討事項

### 未決定事項

1. **復活時のアイテム**
   - 破壊時に装備していたアイテムの扱い
   - 復活時に再装備するか
   - → アイテムは失われる（要確認）

2. **復活時のHP**
   - 元のHPで復活するか
   - 破壊時のHPで復活するか
   - → 元のHP（基礎HP）で復活

3. **墓地の上限**
   - 墓地に保存するクリーチャー数の上限
   - 古いものから削除するか
   - → 次回チャットで決定

4. **復活の優先順位**
   - 同じクリーチャーが複数墓地にある場合
   - 最新 or 最古
   - → 最新を復活（要確認）

5. **復活失敗時の処理**
   - 配置先がない場合
   - 墓地にいない場合
   - → 何もしない（サイレント失敗）

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/24 | 1.0 | 初版作成 - 死者復活効果の基本設計 |

---

**最終更新**: 2025年10月24日（v1.0）
