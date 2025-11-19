# current_hp 初期化タイミング分析（2025-11-18）

## 現在の状況

### place_creature()での初期化

**ファイル**: `scripts/tiles/base_tiles.gd`（90-104行）

```gdscript
func place_creature(data: Dictionary):
	creature_data = data.duplicate()
	
	# 効果システム用フィールドの初期化
	if not creature_data.has("base_up_hp"):
		creature_data["base_up_hp"] = 0
	if not creature_data.has("base_up_ap"):
		creature_data["base_up_ap"] = 0
	if not creature_data.has("permanent_effects"):
		creature_data["permanent_effects"] = []
	if not creature_data.has("temporary_effects"):
		creature_data["temporary_effects"] = []
	if not creature_data.has("map_lap_count"):
		creature_data["map_lap_count"] = 0
	
	# 土地ボーナスはバトル時に動的計算するため、ここでは保存しない
	
	_create_creature_card_3d()
	update_visual()
```

**現在**: `current_hp`の初期化がない

### 召喚フロー

1. **tile_action_processor.gd**（330行）
   - `board_system.place_creature(current_tile, card_data)` 呼び出し
   - card_dataはここで特に加工されない

2. **board_system_3d.gd**（209行）
   - tile_data_manager.place_creature()へ委譲

3. **tile_data_manager.gd**（71行）
   - tile_nodes[tile_index].place_creature(creature_data) へ委譲

4. **base_tiles.gd**（90行）
   - place_creature()で処理
   - **ここで current_hp 初期化なし**

### バトル後のHP保存

**ファイル**: `scripts/battle_system.gd`（296行）

```gdscript
place_creature_data["current_hp"] = attacker.current_hp
board_system_ref.place_creature(tile_index, place_creature_data)
```

**現在**: バトル勝利時のみcurrent_hpが設定される

## 問題点

リファクタリング後は`current_hp`が状態値になるため、タイル召喚時に初期化が必須：

1. **初回召喚時**: card_data に current_hp がない
   - 初期値 = hp + base_up_hp に設定すべき

2. **バトル後**: place_creature_data に current_hp が入っているはず
   - ここで正しく保存されればOK

3. **レベルアップ後**など他のシナリオ
   - check_for_level_up_effect() など他箇所でも考慮必要

## 修正が必要な箇所

### 1. place_creature() で current_hp 初期化

base_tiles.gd の place_creature() に以下を追加：

```gdscript
# current_hp が設定されていなければ、最大HPで初期化
if not creature_data.has("current_hp"):
	var base_hp = creature_data.get("hp", 0)
	var base_up_hp = creature_data.get("base_up_hp", 0)
	creature_data["current_hp"] = base_hp + base_up_hp
```

### 2. 他の召喚箇所での確認

- tile_action_processor.gd: 通常召喚
- battle_system.gd: バトル後配置（既に対応済み）
- cpu_turn_processor.gd: CPU召喚
- land_action_helper.gd: 移動・交換時

これらはすべて `place_creature()` を経由するため、base_tiles.gd 対応で統一される

## 結論

**リファクタリング実装時に place_creature() でcurrent_hp初期化を追加すること**

バトルシステムと統合されるため、タイル側でも状態値として扱う必要あり
