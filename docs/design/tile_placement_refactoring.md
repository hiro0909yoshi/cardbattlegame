# タイル配置・移動判定リファクタリング設計書

## 概要

クリーチャー配置可能/移動可能なタイルの判定ロジックが複数箇所に分散・重複している。
統一的なヘルパーメソッドを作成し、保守性を向上させる。

## 現状の問題点

### 1. 判定ロジックの分散（約20箇所、11ファイル）

| ファイル | 箇所数 | 使用リスト |
|---|---|---|
| special_tile_system.gd | 1 | `["start", "checkpoint", "warp", "card", "neutral"]` |
| tile_action_processor.gd | 1 | `["warp", "card", "checkpoint", "neutral", "start"]` |
| tile_data_manager.gd | 4 | 特殊: `["warp", "card", "checkpoint", "neutral", "start"]`、属性: `["fire", "water", "wind", "earth"]` |
| movement_helper.gd | 5 | `["checkpoint", "warp"]` |
| target_selection_helper.gd | 2 | `["warp", "card", "checkpoint", "start"]` + `"warp"のみ`（マジカルリープ）|
| spell_creature_move.gd | 3 | `["checkpoint", "warp"]` |
| spell_creature_place.gd | 3 | `["warp", "card", "checkpoint", "start"]` |
| spell_player_move.gd | 2 | `["checkpoint", "warp", "card", "start"]` |
| spell_curse_battle.gd | 2 | 属性: `["fire", "water", "earth", "wind"]` |
| base_tiles.gd | 2 | `["checkpoint", "warp", "neutral", "start", "card"]` |
| board_system_3d.gd | 1 | `[0, 5, 10, 15]` ハードコード |
| skill_creature_spawn.gd | 1 | `[0, 5, 10, 15]` ハードコード |

### 2. リストの不一致

用途によってチェックするタイルタイプが異なる：

- **移動系**: `["checkpoint", "warp"]`
- **配置系**: `["warp", "card", "checkpoint", "start"]`
- **地形変化系**: `["checkpoint", "warp", "neutral", "start", "card"]`

### 3. 判定方式の混在

- `tile.tile_type in [...]` 方式
- `tile_index in [0, 5, 10, 15]` ハードコード方式

---

## タイルタイプ一覧

### 配置可能タイル

| tile_type | 配置可 | 停止可 | 地形変化可 | 地形効果 | 備考 |
|-----------|--------|--------|------------|----------|------|
| fire | ✅ | ✅ | ✅ | ✅ | 属性タイル |
| water | ✅ | ✅ | ✅ | ✅ | 属性タイル |
| earth | ✅ | ✅ | ✅ | ✅ | 属性タイル |
| wind | ✅ | ✅ | ✅ | ✅ | 属性タイル |
| neutral | ✅ | ✅ | ✅ | ✅ | 無属性（全クリーチャーに地形効果） |
| blank | ✅ | ✅ | - | - | 配置時にクリーチャー属性に変化 |

※ blankは配置した瞬間に属性タイルに変化するため、blank状態でクリーチャーがいることはない

### 特殊タイル（配置不可）

| tile_type | 停止可 | 備考 |
|-----------|--------|------|
| checkpoint | ✅ | ゲート |
| warp | ❌ | 通過型ワープ（現在） |
| warp_stop | ✅ | 停止型ワープ（将来追加） |
| card | ✅ | 購入型カード（現在） |
| card_buy | ✅ | 購入型カード（将来分離） |
| card_give | ✅ | 譲渡型カード（将来追加） |
| magic | ✅ | 魔法タイル |
| magic_stone | ✅ | 魔法石タイル |
| switch | ✅ | 分岐器タイル |
| base | ✅ | 拠点タイル |
| start | ✅ | スタート地点 |

---

## 提案する実装

### 配置先: scripts/tile_helper.gd（新規）

```gdscript
class_name TileHelper

# ===========================================
# タイルタイプ定数
# ===========================================

## 配置可能タイル（クリーチャーを置ける）
const PLACEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank"]

## 属性タイル（4属性）
const ELEMENT_TILES = ["fire", "water", "earth", "wind"]

## 停止不可タイル
const NO_STOP_TILES = ["warp"]  # 現在のwarpは通過型

## 特殊タイル（配置不可）
const SPECIAL_TILES = [
	"checkpoint", "warp", "warp_stop",  # warpは通過型、warp_stopは将来追加
	"card_buy", "card_give", "card",    # cardは現在の購入型
	"magic", "magic_stone", 
	"switch", "base", "start"
]

## 地形変化可能タイル
const TERRAIN_CHANGEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank"]


# ===========================================
# 判定メソッド
# ===========================================

## 配置可能なタイルか（6種: fire/water/earth/wind/neutral/blank）
static func is_placeable_tile(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in PLACEABLE_TILES


## 特殊タイルか（配置不可）
static func is_special_tile(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in SPECIAL_TILES


## クリーチャー配置可能か（タイル種別＋空きチェック）
static func can_place_creature(tile) -> bool:
	if not is_placeable_tile(tile):
		return false
	# クリーチャーがいない
	if tile.creature_data != null and not tile.creature_data.is_empty():
		return false
	return true


## 空き地か（所有者がいない配置可能タイル）
static func is_empty_land(tile) -> bool:
	if not can_place_creature(tile):
		return false
	return tile.owner_id == -1


## 移動先として停止可能か
static func can_stop_at(tile) -> bool:
	if not tile:
		return false
	# warpは通過型なので停止不可
	return tile.tile_type not in NO_STOP_TILES


## 地形変化可能か
static func can_change_terrain(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in TERRAIN_CHANGEABLE_TILES


## 地形効果があるタイルか（属性タイル + neutral）
static func has_land_effect(tile) -> bool:
	if not tile:
		return false
	# 属性タイル + neutralは地形効果あり（blankは配置時に変化するので含まない）
	return tile.tile_type in ELEMENT_TILES or tile.tile_type == "neutral"


## 属性タイルか（4属性: fire/water/earth/wind）
static func is_element_tile(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in ELEMENT_TILES
```

---

## 修正対象ファイル一覧

### Phase 1: TileHelper作成

- [ ] `scripts/tile_helper.gd` - 新規作成

### Phase 2: コアシステム

- [ ] `scripts/tile_data_manager.gd` - 4箇所（is_special_tile_type等）
- [ ] `scripts/board_system_3d.gd` - 1箇所（ハードコード除去）

### Phase 3: 移動系

- [ ] `scripts/game_flow/movement_helper.gd` - 5箇所
- [ ] `scripts/spells/spell_creature_move.gd` - 3箇所
- [ ] `scripts/spells/spell_player_move.gd` - 2箇所

### Phase 4: 配置系

- [ ] `scripts/spells/spell_creature_place.gd` - 3箇所
- [ ] `scripts/battle/skills/skill_creature_spawn.gd` - 1箇所（ハードコード除去）

### Phase 5: その他

- [ ] `scripts/tile_action_processor.gd` - 1箇所
- [ ] `scripts/special_tile_system.gd` - 1箇所
- [ ] `scripts/game_flow/target_selection_helper.gd` - 2箇所
- [ ] `scripts/tiles/base_tiles.gd` - 2箇所
- [ ] `scripts/spells/spell_curse_battle.gd` - 2箇所（属性判定）

---

## 実装状況

- [x] 調査完了
- [x] ドキュメント作成
- [ ] TileHelper作成
- [ ] Phase 1: コアシステム修正
- [ ] Phase 2: 移動系修正
- [ ] Phase 3: 配置系修正
- [ ] Phase 4: その他修正
- [ ] テスト

---

## タイル追加手順

### ケース1: 配置可能タイルを追加する場合

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

### ケース2: 特殊タイル（配置不可）を追加する場合

例: `shop`タイルを追加

**修正ファイル: `scripts/tile_helper.gd` のみ**

```gdscript
# 1. SPECIAL_TILESに追加（必須）
const SPECIAL_TILES = [
    "checkpoint", "warp", "warp_stop",
    "card_buy", "card_give", "card",
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

### 修正箇所の比較

| | 現状 | リファクタリング後 |
|---|---|---|
| 修正ファイル数 | 12ファイル | 1ファイル |
| 修正箇所数 | 約27箇所 | 該当定数のみ |
| 修正漏れリスク | 高い | 低い |

---

## 関連ドキュメント（タイル追加時に更新が必要）

| ファイル | 内容 | 修正点 |
|---|---|---|
| `docs/design/map_system.md` | 特殊タイルの種類（29行目〜） | 新タイル追加時に更新 |
| `docs/design/spells/クリーチャー操作.md` | 停止不可タイルの記載（230行目） | warp_stop追加時に更新 |
| `docs/design/player_info_panel_redesign.md` | ELEMENT_MAP定義（184行目） | 新タイル追加時に更新 |

---

## 備考

- blankタイルは配置した瞬間にクリーチャーの属性に変化する
- 今後新しいタイルタイプが追加された場合、TileHelperの定数を更新するだけで対応可能
- 現在の`warp`は通過型。将来`warp_stop`（停止型）を追加予定
- cardタイルは現在未実装。将来`card`（購入型）と`card_give`（譲渡型）を追加予定
