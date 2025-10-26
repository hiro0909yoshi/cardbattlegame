# 周回システム実装仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月27日  
**ステータス**: ✅ 実装完了

---

## 📋 概要

プレイヤーがマップを1周するごとに、特定のクリーチャーにボーナスを付与するシステム。

---

## 🎯 実装内容

### 1. チェックポイントシステム

#### CheckpointTile
- **場所**: `scripts/tiles/checkpoint_tile.gd`
- **タイプ**: N（北）/ S（南）の2種類
- **配置**: マップに2箇所（タイル0とタイル10）

```gdscript
enum CheckpointType { N, S }
@export var checkpoint_type: CheckpointType = CheckpointType.N

signal checkpoint_passed(player_id: int, checkpoint_type: String)

func on_player_passed(player_id: int):
	var type_str = "N" if checkpoint_type == CheckpointType.N else "S"
	emit_signal("checkpoint_passed", player_id, type_str)
```

### 2. 周回状態管理

#### GameFlowManager
- **周回状態**: `player_lap_state[player_id]`
- **フラグ**: N, S の2つ
- **周回完了条件**: N=true かつ S=true

```gdscript
var player_lap_state = {}  # {player_id: {N: bool, S: bool}}

func _initialize_lap_state(player_count: int):
	for i in range(player_count):
		player_lap_state[i] = {"N": false, "S": false}

func _on_checkpoint_passed(player_id: int, checkpoint_type: String):
	player_lap_state[player_id][checkpoint_type] = true
	
	if player_lap_state[player_id]["N"] and player_lap_state[player_id]["S"]:
		_complete_lap(player_id)
```

### 3. 周回ボーナス適用

#### 対象クリーチャー
| ID | 名前 | 効果 |
|----|------|------|
| 7 | キメラ | 周回ごとにST+10（上限なし） |
| 240 | モスタイタン | 周回ごとにMHP+10（MHP≧80でMHP=30にリセット） |

#### ボーナス適用処理
```gdscript
func _complete_lap(player_id: int):
	# フラグをリセット
	player_lap_state[player_id]["N"] = false
	player_lap_state[player_id]["S"] = false
	
	# 全クリーチャーにボーナス適用
	var tiles = board_system_3d.get_player_tiles(player_id)
	for tile in tiles:
		if tile.creature_data:
			_apply_lap_bonus_to_creature(tile.creature_data)

func _apply_per_lap_bonus(creature_data: Dictionary, effect: Dictionary):
	var stat = effect.get("stat", "ap")
	var value = effect.get("value", 10)
	
	# 周回カウント
	if not creature_data.has("map_lap_count"):
		creature_data["map_lap_count"] = 0
	creature_data["map_lap_count"] += 1
	
	# base_up_hp/ap に加算
	if stat == "ap":
		creature_data["base_up_ap"] += value
	elif stat == "max_hp":
		# リセット条件チェック（モスタイタン用）
		# ...
		creature_data["base_up_hp"] += value
```

---

## 📊 データ構造

### ability_parsed例

#### キメラ (ID 7)
```json
{
  "ability_parsed": {
	"keywords": ["先制"],
	"effects": [
	  {
		"effect_type": "first_strike"
	  },
	  {
		"effect_type": "per_lap_permanent_bonus",
		"stat": "ap",
		"value": 10
	  }
	]
  }
}
```

#### モスタイタン (ID 240)
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "per_lap_permanent_bonus",
		"stat": "max_hp",
		"value": 10,
		"reset_condition": {
		  "max_hp_check": {
			"operator": ">=",
			"value": 80,
			"reset_to": 30
		  }
		}
	  }
	]
  }
}
```

### creature_dataに追加されるフィールド
```gdscript
{
  "map_lap_count": 2,       # 周回数
  "base_up_ap": 20,         # STボーナス（キメラの場合）
  "base_up_hp": 20          # MHPボーナス（モスタイタンの場合）
}
```

---

## 🔧 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/tiles/checkpoint_tile.gd` | チェックポイントタイル |
| `scripts/game_flow_manager.gd` | 周回状態管理・ボーナス適用 |
| `scripts/board_system_3d.gd` | `get_player_tiles()`追加 |
| `scripts/movement_controller.gd` | チェックポイント通過検出 |
| `scenes/Tiles/CheckpointTile.tscn` | チェックポイントタイルシーン |
| `scenes/Main.tscn` | タイル0,10をCheckpointTileに設定 |
| `data/fire_1.json` | キメラのability_parsed |
| `data/earth_2.json` | モスタイタンのability_parsed |

---

## ✅ テスト確認項目

- [x] N→S通過で周回完了
- [x] S→N通過でも周回完了
- [x] キメラのST上昇（周回ごとに+10）
- [x] モスタイタンのMHP上昇とリセット（MHP≧80で30に戻る）
- [x] 周回カウンター正常動作
- [x] 複数プレイヤーの周回状態が独立

---

## 🐛 解決した問題

### 問題1: ワープ時のエラー
**症状**: `core/math/basis.cpp:47 @ invert()` エラー  
**原因**: `player.scale = Vector3.ZERO`で行列式がゼロになる  
**解決**: `Vector3(0.001, 0.001, 0.001)`を使用

### 問題2: game_startedフラグ問題
**症状**: 2周目以降も「初回」扱いされる  
**原因**: 初期化時に`game_started=false`のまま  
**解決**: `game_started`フラグを削除し、シンプルなN/Sフラグのみに

### 問題3: get_player_tiles未実装
**症状**: `Nonexistent function 'get_player_tiles'`エラー  
**原因**: BoardSystem3Dに関数が存在しない  
**解決**: `get_player_tiles(player_id)`関数を追加

---

## 📝 今後の拡張

- [ ] チェックポイント数を可変に（現在は2固定）
- [ ] 周回ボーナス対象クリーチャーを追加
- [ ] 周回数UIの表示
- [ ] 周回数に応じた特殊イベント

---

**最終更新**: 2025年10月27日
