# HP管理構造 仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月27日  
**ステータス**: 設計確定

---

## 📋 概要

クリーチャーのHP管理は、元のHP、永続ボーナス、現在HPの3つの要素で構成される。

---

## 🎯 HP構造の定義

### creature_dataのHPフィールド

```gdscript
{
  "id": 7,
  "name": "キメラ",
  "hp": 50,                    # 元のベースHP（不変）
  "base_up_hp": 10,            # 永続的な基礎HP上昇（マスグロース、合成、周回ボーナス等）
  "current_hp": 45             # 現在HP（バトル後の残りHP）
}
```

### 各フィールドの役割

| フィールド | 役割 | 変更タイミング | 初期値 |
|-----------|------|---------------|--------|
| **`hp`** | 元のベースHP | **変更しない**（カードデータの値） | JSONの値 |
| **`base_up_hp`** | 永続的な基礎HP上昇 | マスグロース、合成、周回ボーナス適用時 | 0 |
| **`current_hp`** | 現在HP（残りHP） | バトル後、HP回復時 | 存在しない場合は満タン |

---

## 🎮 バトル時のHP/APボーナス構造

### BattleParticipantのフィールド（バトル中のみ）

| フィールド | 用途 | 適用例 | バトル後 |
|-----------|------|--------|---------|
| **`base_hp`** | MHP計算用の基本HP値 | `creature_data["current_hp"] - base_up_hp`で計算 | - |
| **`base_up_hp`** | 永続的な基礎HP上昇 | マスグロース+5、周回ボーナス+10 | creature_dataに保存 |
| **`temporary_bonus_hp`** | 一時的なHPボーナス | ブレッシング+10、ターン数ボーナス | 消失 |
| **`resonance_bonus_hp`** | 感応ボーナス | 感応+30 | 消失 |
| **`land_bonus_hp`** | 土地ボーナス | レベル3の土地+30 | 消失 |
| **`item_bonus_hp`** | アイテムボーナス | ホーリーワード+20 | 消失 |
| **`spell_bonus_hp`** | スペルボーナス | （予約） | 消失 |
| **`current_hp`** | 状態値の現在HP | ダメージで直接削られる | creature_dataに保存 |
| | | | |
| **`base_ap`** | 元のAP（ローカル変数） | `creature_data["ap"]`から取得 | - |
| **`base_up_ap`** | 永続的な基礎AP上昇 | 合成+20、周回ボーナス+10 | creature_dataに保存 |
| **`temporary_bonus_ap`** | 一時的なAPボーナス | 効果配列から計算 | 消失 |
| **`item_bonus_ap`** | アイテムボーナスAP | アイテム効果 | 消失 |
| **`current_ap`** | 計算後の現在AP | 全ボーナス + 感応 + 条件効果 | - |

#### 実装上の注意 (2025年11月5日更新)

> **重要**: `base_up_hp`と`base_up_ap`は**CreatureManagerが管理**しています。
> `tile.creature_data`というアクセス方法は残っていますが、実際のデータは`CreatureManager.creatures[tile_index]`に保存されています。
> 詳細は `docs/design/tile_creature_separation_plan.md` を参照してください。

## HP計算式（バトル時）

```gdscript
current_hp = base_hp +            # MHP計算用の基本HP値（ダメージで削られる）
			 base_up_hp +         # 永続ボーナス（マスグロース等、ダメージで削られない）
			 temporary_bonus_hp + # 一時ボーナス（ブレッシング等）
			 resonance_bonus_hp + # 感応ボーナス
			 land_bonus_hp +      # 土地ボーナス
			 item_bonus_hp +      # アイテムボーナス
			 spell_bonus_hp       # スペルボーナス
```

**重要な概念**:
- `base_hp` は **MHP計算に含まれ、ダメージで削られる** 要素
- `base_up_hp` は **MHP計算に含まれるが、ダメージでは削られない** 要素
- ダメージ時は以下の順序で消費される：
  1. 各種一時的ボーナス（land_bonus_hp → resonance_bonus_hp → temporary_bonus_hp → spell_bonus_hp → item_bonus_hp）
  2. その後 `current_hp` から消費
- `current_hp` は状態値のため、ボーナス要素から消費した後で直接削られる

### ダメージ消費順序

ダメージを受けた時、以下の順序でHPが消費される：

**重要**: `base_up_hp`（永続的な基礎HP上昇）は消費されません。これはMHP計算に使用される値です。

```
1. land_bonus_hp（土地ボーナス）← 最初に消費
2. resonance_bonus_hp（感応ボーナス）
3. temporary_bonus_hp（一時ボーナス）
4. spell_bonus_hp（スペルボーナス）
5. item_bonus_hp（アイテムボーナス）
6. current_hp（最後に消費）
```

※ `current_hp` は状態値のため、ボーナス要素から消費した後に直接削られます。

#### base_up_hp が消費されない理由

- `base_up_hp` はマスグロース、周回ボーナス、合成などで得た **永続的なMHP増加**で、ダメージでは削られない
- これらは戦闘終了後も保持される
- ダメージは最初に土地ボーナスから消費され、最後にcurrent_hpから消費される

---

## 📊 MHP（最大HP）の計算

### 計算式

```gdscript
MHP = creature_data["hp"] + creature_data.get("base_up_hp", 0)
```

### 例

#### ガスクラウド（通常状態）
```gdscript
{
  "hp": 20,           # 元のHP
  "base_up_hp": 0,    # ボーナスなし
  "current_hp": 20    # 満タン
}
MHP = 20 + 0 = 20
現在HP = 20
```

#### ガスクラウド（バトルでダメージ）
```gdscript
{
  "hp": 20,           # 元のHP（不変）
  "base_up_hp": 0,    # ボーナスなし
  "current_hp": 12    # バトルで8ダメージ
}
MHP = 20 + 0 = 20
現在HP = 12
```

#### ガスクラウド（マスグロース+5後）
```gdscript
{
  "hp": 20,           # 元のHP（不変）
  "base_up_hp": 5,    # マスグロースで+5
  "current_hp": 25    # 満タン
}
MHP = 20 + 5 = 25
現在HP = 25
```

#### ガスクラウド（マスグロース+5、バトルで10ダメージ）
```gdscript
{
  "hp": 20,           # 元のHP（不変）
  "base_up_hp": 5,    # マスグロースで+5
  "current_hp": 15    # バトルで10ダメージ
}
MHP = 20 + 5 = 25
現在HP = 15
```

---

## 🔧 実装パターン

### 1. バトル準備時（creature_data → BattleParticipant）

```gdscript
# battle_preparation.gd
func prepare_participants(...):
	var defender_creature = tile_info.get("creature", {})
	
	# creature_dataから情報取得
	var original_base_hp = defender_creature.get("hp", 0)  # 元のHP（不変）
	var base_up_hp = defender_creature.get("base_up_hp", 0)  # 永続ボーナス
	var max_hp = original_base_hp + base_up_hp  # MHP
	
	# 現在HPを取得（ない場合は満タン）
	var current_hp = defender_creature.get("current_hp", max_hp)
	
	# BattleParticipantを作成
	var defender = BattleParticipant.new(
		defender_creature,
		original_base_hp,  # コンストラクタには元のHPを渡す
		defender_land_bonus,
		defender_ap,
		false,
		defender_owner
	)
	
	# base_up_hpを設定
	defender.base_up_hp = base_up_hp
	
	# current_hpを設定（状態値として直接設定）
	defender.current_hp = current_hp
	# 注: base_hp はコンストラクタで original_base_hp から設定される
```

**重要な概念**：
- `creature_data["hp"]` = 元のHP（不変、カードの値）
- `creature_data["current_hp"]` = 現在の残りHP（base_hp + base_up_hpの現在値）
- `BattleParticipant.base_hp` = 基本HPの現在値（ダメージで削られる）
- `BattleParticipant.base_up_hp` = 永続ボーナスの値（ダメージで削られない）
- `BattleParticipant.current_hp` = 状態値のHP（各要素から消費した後に直接削られる）
  - 計算式: `base_hp + base_up_hp + temporary_bonus_hp + resonance_bonus_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp`

**BattleParticipantの主要メソッド**：
- `add_base_up_hp(value)` = base_up_hpを増加し、current_hpとcreature_dataも同時に更新
- `update_current_ap()` = 全フィールドからcurrent_apを再計算
- `get_max_hp()` = 真のMHP（base_hp + base_up_hp）を取得

---

### 2. バトル後のHP保存（BattleParticipant → creature_data）

```gdscript
# battle_special_effects.gd
func update_defender_hp(tile_info: Dictionary, defender: BattleParticipant) -> void:
	var tile_index = tile_info["index"]
	var creature_data = tile_info.get("creature", {}).duplicate()
	
	# 元のHPは触らない
	# creature_data["hp"] = そのまま（不変）
	
	# 永続ボーナスも触らない（既に入っている）
	# creature_data["base_up_hp"] = そのまま
	
	# 現在HPを保存（状態値として直接保存）
	creature_data["current_hp"] = defender.current_hp
	
	# タイルのクリーチャーデータを更新
	board_system_ref.tile_data_manager.tile_nodes[tile_index].creature_data = creature_data
	
	print("[HP保存] ", creature_data.get("name", ""), 
		  " 現在HP:", creature_data["current_hp"], 
		  " / MHP:", creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0))
```

```gdscript
# battle_system.gd
func _apply_post_battle_effects(...):
	# 侵略成功時
	var place_creature_data = attacker.creature_data.duplicate(true)
	
	# 永続バフを反映
	place_creature_data["base_up_hp"] = attacker.base_up_hp
	place_creature_data["base_up_ap"] = attacker.base_up_ap
	
	# 現在HPを保存（状態値として直接保存）
	place_creature_data["current_hp"] = attacker.current_hp
	
	board_system_ref.place_creature(tile_index, place_creature_data)
	
	print("[HP保存] ", place_creature_data.get("name", ""), 
		  " 現在HP:", place_creature_data["current_hp"], 
		  " / MHP:", place_creature_data.get("hp", 0) + place_creature_data.get("base_up_hp", 0))
```

**重要**：
- `creature_data["hp"]` = 絶対に変更しない
- `creature_data["base_up_hp"]` = 絶対に変更しない（マスグロース等でのみ変更）
- `creature_data["current_hp"]` = バトル後の残りHPを保存（base_hp + base_up_hp）

---

### 3. HP回復（スタート通過時）

```gdscript
# movement_controller.gd
func heal_all_creatures_for_player(player_id: int, heal_amount: int):
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.creature_data:
			var creature = tile.creature_data
			
			# MHP計算
			var base_hp = creature.get("hp", 0)  # 元のHP
			var base_up_hp = creature.get("base_up_hp", 0)  # 永続ボーナス
			var max_hp = base_hp + base_up_hp
			
			# 現在HP取得（ない場合は満タン）
			var current_hp = creature.get("current_hp", max_hp)
			
			# HP回復（MHPを超えない）
			var new_hp = min(current_hp + heal_amount, max_hp)
			creature["current_hp"] = new_hp
			
			print("[HP回復] ", creature.get("name", ""), 
				  " (", current_hp, " → ", new_hp, " / ", max_hp, ")")
```

---

### 4. マスグロース（MHP上昇＋現在HP上昇）

```gdscript
# effect_manager.gd
static func apply_mass_growth(tile_nodes: Dictionary, player_id: int, hp_bonus: int = 5) -> void:
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and not tile.creature_data.is_empty():
			# base_up_hpを増やす（MHP上昇）
			tile.creature_data["base_up_hp"] = tile.creature_data.get("base_up_hp", 0) + hp_bonus
			# current_hpも同じ分だけ増やす
			var current_hp = tile.creature_data.get("current_hp", tile.creature_data.get("hp", 0))
			tile.creature_data["current_hp"] = current_hp + hp_bonus
			print("  ", tile.creature_data.get("name", "?"), " MHP +", hp_bonus, " HP +", hp_bonus)
```

**動作**: MHPが上昇すると、current_hpも同じ値だけ上昇する（回復ではなく同時上昇）。

**例**: ガスクラウド（HP20、現在12）にマスグロース+5
- 適用前: MHP=20, 現在HP=12
- 適用後: MHP=25(+5), 現在HP=17(+5)

---

### 5. スタート通過（HP回復のみ、MHP不変）

```gdscript
# movement_controller.gd
func heal_all_creatures_for_player(player_id: int, heal_amount: int):
	for tile in tiles:
		if tile.owner_id == player_id and tile.creature_data:
			var creature = tile.creature_data
			
			# MHP計算
			var base_hp = creature.get("hp", 0)
			var base_up_hp = creature.get("base_up_hp", 0)
			var max_hp = base_hp + base_up_hp
			
			# 現在HP取得（ない場合は満タン）
			var current_hp = creature.get("current_hp", max_hp)
			
			# HP回復（MHPを超えない）
			var new_hp = min(current_hp + heal_amount, max_hp)
			creature["current_hp"] = new_hp
			
			print("[スタート通過] ", creature.get("name", ""), 
				  " HP+", heal_amount,
				  " (", current_hp, " → ", new_hp, " / ", max_hp, ")")
```

**例**: ガスクラウド（MHP25、現在17）がスタート通過
- 適用前: MHP=25, 現在HP=17
- 適用後: MHP=25(不変), 現在HP=25(+8、上限)

**重要な違い**：
- **マスグロース**: `base_up_hp`を増やす（MHP上昇） + `current_hp`回復
- **スタート通過**: `current_hp`のみ回復（MHP不変）

---

### 6. 周回ボーナス（特殊）

#### キメラ（AP+10のみ）
```gdscript
# lap_system.gd
func _apply_per_lap_bonus(creature_data: Dictionary, effect: Dictionary):
	var stat = effect.get("stat", "ap")
	var value = effect.get("value", 10)
	
	if stat == "ap":
		# STを増やす
		creature_data["base_up_ap"] = creature_data.get("base_up_ap", 0) + value
```

#### モスタイタン（MHP+10、HP+10回復）
```gdscript
# lap_system.gd
func _apply_per_lap_bonus(creature_data: Dictionary, effect: Dictionary):
	var stat = effect.get("stat", "max_hp")
	var value = effect.get("value", 10)
	
	if stat == "max_hp":
		# 1. MHPを増やす（base_up_hpを増やす）
		creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + value
		
		# 2. 現在HPも回復（増えたMHP分だけ）
		var base_hp = creature_data.get("hp", 0)
		var base_up_hp = creature_data["base_up_hp"]
		var max_hp = base_hp + base_up_hp
		var current_hp = creature_data.get("current_hp", max_hp)
		
		# HP回復（MHPを超えない）
		var new_hp = min(current_hp + value, max_hp)
		creature_data["current_hp"] = new_hp
		
		print("[Lap Bonus] ", creature_data.get("name", ""), 
			  " MHP+", value, " HP+", value,
			  " (周回", creature_data["map_lap_count"], "回目)",
			  " HP:", current_hp, "→", new_hp, " / MHP:", max_hp)
```

**重要**：
- モスタイタンは`base_up_hp`が増える（MHP上昇）
- 同時に`current_hp`も回復する（HP回復）
- キメラはSTのみ増える（HPは変わらない）

---

## 🔄 特殊なHP計算（HP=条件で計算するクリーチャー）

一部のクリーチャーやアイテムは、戦闘中にHPを条件に基づいて計算（置換）します。

### 対象クリーチャー/アイテム

| 名前 | ID | effect_type | 効果 |
|------|-----|-------------|------|
| レッドキャップ | 445 | `race_creature_stat_replace` | AP&HP=ゴブリン配置数×20 |
| アンダイン | 109 | `land_count_multiplier` (set) | HP=水自ドミニオ数×20 |
| ガルーダ | 307 | `land_count_multiplier` (set) | AP&HP=風配置数×10 |
| リビングクローブ | 440 | `other_element_count` | AP&HP=他属性の配置数×5 |
| ペトリフストーン | 1059 | `fixed_stat` (set) | AP=0；HP=80 |

### 処理方法

**戦闘中**:
```gdscript
# ✅ 正しい方法: base_hpとcurrent_hpのみ変更
participant.base_hp = calculated_value
participant.current_hp = calculated_value

# ❌ やってはいけない: creature_data["hp"]を変更
# participant.creature_data["hp"] = calculated_value  # ダメ！
```

**理由**:
- `creature_data["hp"]` は元のカードデータ値であり、不変
- 戦闘後に元の値に戻すために必要

### 戦闘後の処理

```gdscript
# update_defender_hp() 内
var original_mhp = creature_data.get("hp", 0) + defender.base_up_hp
var final_hp = defender.current_hp

# 戦闘中の計算HPが元のMHPより高い場合は制限
if final_hp > original_mhp:
    final_hp = original_mhp

creature_data["current_hp"] = final_hp
```

### 例: アンダイン（水の土地3つ所有）

```
戦闘前:
  creature_data["hp"] = 30（元の値）
  
戦闘中:
  計算HP = 3 × 20 = 60
  base_hp = 60
  current_hp = 60
  creature_data["hp"] = 30（不変）

戦闘後（ダメージ10を受けた場合）:
  current_hp = 50
  元のMHP = 30
  → current_hp = 30 に制限（元のMHPを超えない）
  creature_data["current_hp"] = 30
```

### 例: レッドキャップ（ゴブリン0体）

```
戦闘中:
  計算HP = 0 × 20 = 0
  base_hp = 0
  current_hp = 0
  → HP=0のため死亡判定
```

---

## ⚠️ 重要な注意事項

### ❌ やってはいけないこと

```gdscript
# ❌ ダメ: 元のHPを上書き
creature_data["hp"] = defender.base_hp

# ❌ ダメ: 元のHPを増やす
creature_data["hp"] += 10
```

### ✅ 正しい方法

```gdscript
# ✅ OK: 現在HPのみ更新
creature_data["current_hp"] = defender.base_hp

# ✅ OK: 永続ボーナスを増やす（MHP上昇）
creature_data["base_up_hp"] += 10
```

---

## 🔄 HP表示フォーマット

### 標準表示

```
現在HP / MHP
例: 30 / 50
```

### ログ表示

```
クリーチャー名 (現在HP → 新HP / MHP)
例: キメラ (30 → 40 / 50)
```

---

## 🐛 よくある問題とデバッグ

### 問題1: MHPが実際より小さい

**症状**: キメラ（元HP=50）なのに MHP=20 と表示される

**原因**: `creature_data["hp"]`がバトル後の残りHP（20）で上書きされている

**解決**: `creature_data["current_hp"]`を使い、`creature_data["hp"]`は触らない

---

### 問題2: HP回復が機能しない

**症状**: スタート通過してもHPが回復しない

**原因**: `current_hp`が存在せず、計算が`creature_data["hp"]`（既に残りHPで上書きされている）を使っている

**解決**: MHP計算を正しく行う
```gdscript
var max_hp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
var current_hp = creature.get("current_hp", max_hp)
```

---

### 問題3: 周回ボーナス後にMHPが変わらない

**症状**: 周回完了後も MHP = 30 のまま

**原因**: `base_up_hp`を増やしていない、または表示計算が間違っている

**解決**: 
```gdscript
creature_data["base_up_hp"] += 10
var max_hp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
```

---

## 📝 関連ドキュメント

- [効果システム設計](effect_system_design.md) - HP/AP管理構造の詳細
- [バトルシステム](battle_system.md) - BattleParticipantの構造
- [周回システム](lap_system.md) - 周回ボーナスでのMHP上昇
- [マップシステム](map_system.md) - スタート通過でのHP回復

---

**最終更新**: 2025年12月24日（HP=条件で計算するクリーチャーの処理を追記）
