# MHPとダメージ計算の完全仕様

**最終更新**: 2025年10月30日

---

## 📋 目次

1. [概要](#概要)
2. [MHP（最大HP）の定義](#mhp最大hpの定義)
3. [HPボーナスの設定箇所](#hpボーナスの設定箇所)
4. [BattleParticipantのMHPヘルパーメソッド](#battleparticipantのmhpヘルパーメソッド)
5. [ダメージ計算フロー](#ダメージ計算フロー)
6. [特殊ケース](#特殊ケース)
7. [実装状況](#実装状況)
8. [変更履歴](#変更履歴)
9. [トラブルシューティング](#トラブルシューティング)
10. [次のステップ](#次のステップ)

---

## 概要

### 🎯 目的

このドキュメントは、カードバトルゲームにおけるMHP（最大HP）とダメージ計算の完全な仕様を定義します。

### 🔑 重要な原則

1. **MHPは常に `hp + base_up_hp` で計算される**（真の最大HP）
2. **計算はBattleParticipantクラスに統合される**（HPCalculatorは削除済み）
3. **現在HPは `current_hp` フィールドで管理される**
4. **ダメージを負った状態は `current_hp < MHP` で判定される**
5. **戦闘中のHPは7種類のボーナスの合計である**

---

## MHP（最大HP）の定義

### 📊 完全な計算式

```gdscript
current_hp = base_hp + base_up_hp + temporary_bonus_hp + 
			 resonance_bonus_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp
```

### 🔤 用語定義（完全版）

| 用語 | JSON名 | 説明 | 永続性 | 設定箇所 |
|------|--------|------|--------|----------|
| **base_hp** | `"hp"` | クリーチャーの初期HP（JSONで定義） | 永続 | JSON |
| **base_up_hp** | `"base_up_hp"` | 永続バフによる最大HP増加（合成・マスグロース等） | 永続 | JSON |
| **resonance_bonus_hp** | - | 感応ボーナスHP | 戦闘中のみ | `battle_skill_processor.gd` |
| **land_bonus_hp** | `"land_bonus_hp"` | 土地ボーナスHP（戦闘ごとに復活） | 戦闘中のみ | `board_system_3d.gd` |
| **temporary_bonus_hp** | - | 一時的なHPボーナス（スキル効果等） | 戦闘中のみ | `battle_skill_processor.gd` |
| **item_bonus_hp** | - | アイテムによるHPボーナス | 戦闘中のみ | `battle_preparation.gd` |
| **spell_bonus_hp** | - | スペルによるHPボーナス | 戦闘中のみ | （未実装） |
| **MHP** | - | 最大HP（base_hp + base_up_hp） | - | 計算値 |
| **current_hp** | `"current_hp"` | 現在のHP（ダメージ後の実HP） | 永続 | JSON |

### 🎯 MHP（最大HP）とは

**MHP = base_hp + base_up_hp**

これが**真の最大HP**です。戦闘中の各種ボーナスは含みません。

- JSONに保存されるのは `base_hp` (→`"hp"`) と `base_up_hp` のみ
- `land_bonus_hp`, `item_bonus_hp`, `spell_bonus_hp` は戦闘中の一時的なボーナス
- `current_hp` は実際のダメージ状態を記録（JSONに保存）

### 💥 ダメージ消費順序

ダメージを受けた時、以下の順序でHPが消費されます：

```gdscript
1. resonance_bonus_hp  # 感応ボーナス（最初に消える）
2. land_bonus_hp       # 土地ボーナス
3. temporary_bonus_hp  # 一時ボーナス
4. item_bonus_hp       # アイテムボーナス
5. spell_bonus_hp      # スペルボーナス
6. base_up_hp          # 永続バフ
7. base_hp             # 基本HP（最後に消える）
```

**実装箇所**: `battle_participant.gd` の `take_damage()` メソッド 現在のHP（ダメージ後） |

### 📝 JSONの例

```json
{
	"id": 227,
	"name": "ダスクドウェラー",
	"hp": 40,
	"base_up_hp": 0,
	"current_hp": 35,
	"land_bonus_hp": 10
}
```

この場合：
- **MHP** = 40 + 0 = **40**
- **現在HP** = 35 + 10（土地） = **45**（表示用）
- **ダメージ** = 40 - 35 = **5**（base_hpが5減っている）

---

## HPボーナスの設定箇所

### 🔥 1. resonance_bonus_hp（感応ボーナス）

**設定箇所**: `scripts/battle/battle_skill_processor.gd` - `_process_resonance_skills()`

**設定タイミング**: バトル準備時

**例**:
```gdscript
# フルパワー (48): 感応+20: 配置しているクリーチャー数ごとにHP+1
if creature_count >= 20:
	participant.resonance_bonus_hp += 20
```

**永続性**: 戦闘中のみ（戦闘終了後に消える）

**対象クリーチャー**: フルパワー、その他感応持ち

---

### 🌍 2. land_bonus_hp（土地ボーナス）

**設定箇所**: `scripts/board_system_3d.gd` - タイルデータから取得

**設定タイミング**: バトル準備時

**例**:
```gdscript
# タイルの土地ボーナスを取得
var land_bonus_hp = tile.land_bonus_hp
participant.land_bonus_hp = land_bonus_hp
```

**永続性**: 戦闘ごとに復活（移動しても消えない）

**特徴**: 
- 巻物攻撃で無効化される
- `BattleSkillProcessor._process_scroll_attack()` で処理

---

### ⚡ 3. temporary_bonus_hp（一時ボーナス）

**設定箇所**: 
- `scripts/battle/battle_skill_processor.gd`（スキル効果）
- `scripts/battle/battle_preparation.gd`（特殊効果）

**設定タイミング**: バトル準備時、スキル発動時

**例**:
```gdscript
# オーガロード (407): 水地オーガ配置時HP+20
if water_earth_ogre_count > 0:
	participant.temporary_bonus_hp += 20

# ローンビースト (49): HP+基礎ST
participant.temporary_bonus_hp = bonus - (participant.base_hp + participant.base_up_hp)

# スペクター (321): ランダムHP（10-90）
participant.temporary_bonus_hp = random_hp - (base_hp + base_up_hp)
```

**永続性**: 戦闘中のみ

**用途**: 
- スキルによる一時的なHP増加
- ランダムステータス
- 条件付きボーナス

---

### 🎒 4. item_bonus_hp（アイテムボーナス）

**設定箇所**: `scripts/battle/battle_preparation.gd` - `_apply_item_effects()`

**設定タイミング**: バトル準備時

**例**:
```gdscript
# 援護クリーチャー（item_type == "creature"）
if item_type == "creature":
	var creature_hp = item_data.get("hp", 0)
	if creature_hp > 0:
		participant.item_bonus_hp += creature_hp

# アイテムカード（stat_bonusまたはeffects）
var stat_bonus = effect_parsed.get("stat_bonus", {})
var hp = stat_bonus.get("hp", 0)
if hp > 0:
	participant.item_bonus_hp += hp

# buff_hp効果
if effect_type == "buff_hp":
	participant.item_bonus_hp += value

# debuff_hp効果
if effect_type == "debuff_hp":
	participant.item_bonus_hp -= value
```

**永続性**: 戦闘中のみ

**用途**: 
- 援護クリーチャーのHP（例: ID 25のHP10が加算）
- アイテムカードの HP+20 効果
- デバフアイテムの HP-10 効果

**行番号**:
- 230行目: 援護クリーチャーのHP加算
- 278行目: アイテムのstat_bonus HP加算
- 293行目: buff_hp効果
- 302行目: debuff_hp効果

---

### ✨ 5. spell_bonus_hp（スペルボーナス）

**設定箇所**: （未実装）

**設定タイミング**: スペル使用時

**例**:
```gdscript
# 想定される実装
if spell.effect_type == "buff_hp":
	participant.spell_bonus_hp += spell.value
```

**永続性**: 戦闘中のみ

**注意**: 現在は`BattleParticipant`クラスに定義されているが、実際の使用箇所はまだ実装されていない

**ダメージ消費順序**: item_bonus_hpの後、base_up_hpの前

---

### 🔄 6. base_up_hp（永続バフ）

**設定箇所**: 複数箇所（永続効果）

**設定タイミング**: 
- 合成時
- マスグロース使用時
- ブラッドプリンの吸収効果
- モスタイタンの周回ボーナス

**例**:
```gdscript
# ブラッドプリン (137): 援護クリーチャーのMHP吸収
participant.creature_data["base_up_hp"] = blood_purin_base_up_hp + actual_increase

# モスタイタン (41): 周回MHP+10
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + (lap_count * 10)
```

**永続性**: 永続（JSONに保存される）

**特徴**: 
- JSONに保存される唯一のボーナスHP
- MHPの一部として扱われる
- 戦闘終了後も残る

---

### 📦 7. current_hp（現在HP）

**設定箇所**: 
- `scripts/battle/battle_preparation.gd` - バトル準備時
- `scripts/game_flow/game_flow_manager.gd` - バトル終了時

**設定タイミング**: 
- バトル準備時: 前回のダメージ状態を復元
- バトル終了時: ダメージ状態を保存

**例**:
```gdscript
# バトル準備時: current_hpがあればそれを使用、なければMHP
var current_hp = card_data.get("current_hp", max_hp)

# バトル終了時: ダメージを負っていれば保存
if battle_current_hp < max_hp:
	tile.creature_data["current_hp"] = battle_current_hp
else:
	# 満タンならcurrent_hpフィールドを削除
	tile.creature_data.erase("current_hp")
```

**永続性**: 永続（JSONに保存される）

**特徴**: 
- 満タンの場合はJSONから削除される
- 存在しない場合はMHPとして扱われる

---

## BattleParticipantのMHPヘルパーメソッド

### 📍 ファイル位置

```
scripts/battle_participant.gd
```

### 🔧 主要メソッド

#### 1. 真のMHP取得

```gdscript
func get_max_hp() -> int
```

**用途**: クリーチャーの真の最大HP（MHP = base_hp + base_up_hp）を取得

**戻り値**: MHP（整数）

**計算式**:
```gdscript
return base_hp + base_up_hp
```

**使用例**:
```gdscript
var mhp = participant.get_max_hp()
print("真のMHP: ", mhp)  # 出力: 真のMHP: 40
```

---

#### 2. ダメージ判定

```gdscript
func is_damaged() -> bool
```

**用途**: クリーチャーがダメージを負っているか判定

**戻り値**: ダメージを負っていれば `true`

**ロジック**:
```gdscript
return current_hp < get_max_hp()
```

**使用例**:
```gdscript
if participant.is_damaged():
	print("このクリーチャーは負傷しています")
```

---

#### 3. 残りHP割合

```gdscript
func get_hp_ratio() -> float
```

**用途**: 残りHP割合を0.0～1.0で取得

**戻り値**: 残りHP割合（float）

**使用例**:
```gdscript
var ratio = participant.get_hp_ratio()
if ratio < 0.5:
	print("HPが半分以下です")
```

---

#### 4. MHP条件チェック

```gdscript
# 汎用チェック
func check_mhp_condition(operator: String, threshold: int) -> bool

# MHP以下判定
func is_mhp_below_or_equal(threshold: int) -> bool

# MHP以上判定
func is_mhp_above_or_equal(threshold: int) -> bool

# MHP範囲判定
func is_mhp_in_range(min_threshold: int, max_threshold: int) -> bool
```

**使用例**:
```gdscript
# フロギストン (42): MHP40以下で強打
if attacker.is_mhp_below_or_equal(40):
	apply_power_attack()

# ジェネラルカン (15): MHP50以上をカウント
if participant.is_mhp_above_or_equal(50):
	qualified_count += 1

# 中型クリーチャー判定
if participant.is_mhp_in_range(30, 60):
	print("中型クリーチャーです")
```

---

#### 5. デバッグ文字列

```gdscript
func get_hp_debug_string() -> String
```

**用途**: HP状態を人間が読めるフォーマットで取得

**戻り値**: `"現在HP/MHP (base_hp+base_up_hp)"` 形式の文字列

**使用例**:
```gdscript
var debug_str = participant.get_hp_debug_string()
print(debug_str)  # 出力: "35/40 (40+0)"
```

---

### 📝 JSON操作時のMHP計算

BattleParticipantが存在しない場合（JSON操作時）は、直接計算：

```gdscript
# ✅ JSON操作時のMHP計算
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)

# ✅ 現在HP取得
var current_hp = creature_data.get("current_hp", mhp)

# ✅ ダメージ判定
var is_damaged = creature_data.has("current_hp") and creature_data["current_hp"] < mhp
```

---

#### 2. 現在HP取得

```gdscript
static func calculate_current_hp(data: Dictionary) -> int
```

**用途**: クリーチャーの現在HPを取得

**引数**:
- `data`: クリーチャーデータ

**戻り値**: 現在HP（整数）

**ロジック**:
```gdscript
# current_hpが設定されていればそれを使用、なければMHPを返す
return data.get("current_hp", calculate_max_hp(data))
```

**使用例**:
```gdscript
var current_hp = HPCalculator.calculate_current_hp(creature_data)
print("現在HP: ", current_hp)  # 出力: 現在HP: 35
```

---

#### 3. ダメージ判定

```gdscript
static func is_damaged(data: Dictionary) -> bool
```

**用途**: クリーチャーがダメージを負っているか判定

**戻り値**: ダメージを負っていれば `true`

**ロジック**:
```gdscript
var current_hp = calculate_current_hp(data)
var max_hp = calculate_max_hp(data)
return current_hp < max_hp
```

**使用例**:
```gdscript
if HPCalculator.is_damaged(creature_data):
	print("このクリーチャーは負傷しています")
```

---

#### 4. MHP条件チェック

```gdscript
# MHP以下判定
static func is_mhp_below_or_equal(data: Dictionary, threshold: int) -> bool

# MHP以上判定
static func is_mhp_above_or_equal(data: Dictionary, threshold: int) -> bool

# MHP範囲判定
static func is_mhp_in_range(data: Dictionary, min_value: int, max_value: int) -> bool
```

**使用例**:
```gdscript
# フロギストン (42): MHP40以下で強打
if HPCalculator.is_mhp_below_or_equal(creature_data, 40):
	apply_power_attack()

# ジェネラルカン (15): MHP50以上をカウント
if HPCalculator.is_mhp_above_or_equal(creature_data, 50):
	qualified_count += 1

# 中型クリーチャー判定
if HPCalculator.is_mhp_in_range(creature_data, 30, 60):
	print("中型クリーチャーです")
```

---

#### 5. デバッグ文字列

```gdscript
static func get_hp_debug_string(data: Dictionary) -> String
```

**用途**: HP状態を人間が読めるフォーマットで取得

**戻り値**: `"現在HP/MHP (base_hp+base_up_hp)"` 形式の文字列

**使用例**:
```gdscript
var debug_str = HPCalculator.get_hp_debug_string(creature_data)
print(debug_str)  # 出力: "35/40 (40+0)"
```

---

## ダメージ計算フロー

### 🔄 バトルのライフサイクル

#### 1. バトル準備（battle_preparation.gd）

```gdscript
func _prepare_participant_data(card_data: Dictionary, is_attacker: bool) -> void:
	# 基本HP取得
	var base_hp = card_data.get("hp", 0)
	var base_up_hp = card_data.get("base_up_hp", 0)
	var mhp = base_hp + base_up_hp
	
	# 現在HP取得（ダメージ状態を保持）
	var current_hp = card_data.get("current_hp", mhp)
	
	# BattleParticipantに設定
	participant.base_hp = base_hp
	participant.base_up_hp = base_up_hp
	participant.current_hp = current_hp  # update_current_hp()で再計算される
```

**重要**: 
- `current_hp`が設定されていれば、そのダメージ状態がバトルに引き継がれる
- バトル準備中に各種ボーナスが加算される（land_bonus_hp, item_bonus_hp等）

---

#### 2. バトル実行（battle_system.gd）

```gdscript
func execute_battle(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	# ダメージ計算
	var damage = calculate_damage(attacker, defender)
	
	# HPを減らす
	defender.current_hp -= damage
	
	# 死亡判定
	if defender.current_hp <= 0:
		defender.current_hp = 0
		defender.is_alive = false
```

---

#### 3. バトル終了（game_flow_manager.gd）

```gdscript
func _save_hp_changes_to_board() -> void:
	for tile in board_system.tiles:
		if tile.creature_data == null:
			continue
		
		# MHP計算
		var base_hp = tile.creature_data.get("hp", 0)
		var base_up_hp = tile.creature_data.get("base_up_hp", 0)
		var max_hp = base_hp + base_up_hp
		
		# バトル結果の現在HPを取得
		var battle_current_hp = get_battle_current_hp(tile)
		
		# ボードに保存
		if battle_current_hp < max_hp:
			tile.creature_data["current_hp"] = battle_current_hp
		else:
			# 満タンなら current_hp フィールドを削除
			tile.creature_data.erase("current_hp")
```

**重要**: 満タンの場合は `current_hp` を削除することで、デフォルト動作（MHP = 現在HP）になる

---

#### 4. HP回復（land_action_helper.gd）

```gdscript
func _heal_creature_hp(tile_idx: int, heal_amount: int) -> void:
	var tile = board_system.tiles[tile_idx]
	
	# 現在HPとMHPを取得
	var base_hp = tile.creature_data.get("hp", 0)
	var base_up_hp = tile.creature_data.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	var current_hp = tile.creature_data.get("current_hp", max_hp)
	
	# 回復処理
	var new_hp = min(current_hp + heal_amount, max_hp)
	
	# 保存
	if new_hp >= max_hp:
		tile.creature_data.erase("current_hp")  # 満タンなら削除
	else:
		tile.creature_data["current_hp"] = new_hp
```

---

## 特殊ケース

### 🔥 1. ブラッドプリン（ID: 137）

**スキル**: 援護: ダメージを与えた数だけ、援護クリーチャーの最大HPを吸収

```gdscript
func _process_blood_pudding_skill(attacker: BattleParticipant, defender: BattleParticipant, assist_data: Dictionary) -> void:
	if attacker.creature_id == 137 and not defender.is_alive:
		# 援護クリーチャーのMHPを取得
		var assist_mhp = HPCalculator.calculate_max_hp(assist_data)
		
		# 吸収量 = 与えたダメージ
		var absorbed = assist_mhp
		
		# ブラッドプリンのMHPを増加
		attacker.base_up_hp += absorbed
		
		print("ブラッドプリンは援護クリーチャーのMHP ", absorbed, " を吸収した")
```

---

### 👑 2. ジェネラルカン（ID: 15）

**スキル**: ST+配置しているMHP50以上のクリーチャー数×5

```gdscript
func _count_qualified_creatures() -> int:
	var count = 0
	
	for tile in board_system.tiles:
		if tile.creature_data == null:
			continue
		
		# MHP50以上かチェック
		if HPCalculator.is_mhp_above_or_equal(tile.creature_data, 50):
			count += 1
	
	return count

func _apply_general_kun_bonus(attacker: BattleParticipant) -> void:
	var bonus = _count_qualified_creatures() * 5
	attacker.st += bonus
```

---

### 🔥 3. フロギストン（ID: 42）

**スキル**: MHP40以下: 強打+10

```gdscript
func _check_phlogiston_skill(attacker: BattleParticipant, attacker_data: Dictionary) -> void:
	if attacker.creature_id == 42:
		# MHP40以下かチェック
		if HPCalculator.is_mhp_below_or_equal(attacker_data, 40):
			attacker.attack_bonus += 10
			print("フロギストンの強打発動: +10")
```

---

### 🐛 4. モスタイタン（ID: 41）

**スキル**: 周回: MHP+10

```gdscript
func _apply_lap_bonus(creature_data: Dictionary) -> void:
	if creature_data.get("id") == 41:
		var lap_count = creature_data.get("lap_count", 0)
		
		if lap_count > 0:
			# 永続バフとして加算
			creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + (lap_count * 10)
			
			var new_mhp = HPCalculator.calculate_max_hp(creature_data)
			print("モスタイタンのMHP: ", new_mhp)
```

---

### 👻 5. スペクター（ID: 321）

**スキル**: ボードでランダムMHP（10-90）

```gdscript
func _randomize_specter_hp(creature_data: Dictionary) -> void:
	if creature_data.get("id") == 321:
		# ランダムMHP生成（10-90）
		var random_hp = randi() % 81 + 10
		
		# base_hpを直接変更
		creature_data["hp"] = random_hp
		
		# current_hpも同じ値に設定（満タン状態）
		creature_data["current_hp"] = random_hp
		
		print("スペクターのランダムMHP: ", random_hp)
```

---

### 🔄 6. ローンビースト（ID: 49）

**スキル**: HP+基礎ST

```gdscript
func _apply_lone_beast_skill(participant: BattleParticipant, base_st: int) -> void:
	if participant.creature_id == 49:
		# MHP = base_hp + base_up_hp + base_st
		var mhp = HPCalculator.calculate_max_hp(participant)
		var bonus = base_st
		
		participant.current_hp = mhp + bonus
		participant.temporary_bonus_hp = bonus
		
		print("ローンビーストのHP: ", participant.current_hp, " (MHP ", mhp, " + ST ", bonus, ")")
```

---

## 実装状況

### ✅ 完了した実装

| ファイル | 内容 | 状態 |
|---------|------|------|
| `battle_participant.gd` | MHPヘルパーメソッド実装 | ✅ 完成 |
| `scripts/utils/hp_calculator.gd` | 削除完了 | ✅ 削除 |

### 🎯 BattleParticipantの新しいメソッド

| メソッド | 用途 |
|---------|------|
| `get_max_hp()` | 真のMHP取得 |
| `is_damaged()` | ダメージ判定 |
| `get_hp_ratio()` | 残りHP割合 |
| `check_mhp_condition()` | MHP条件チェック |
| `is_mhp_below_or_equal()` | MHP以下判定 |
| `is_mhp_above_or_equal()` | MHP以上判定 |
| `is_mhp_in_range()` | MHP範囲判定 |
| `get_hp_debug_string()` | デバッグ文字列 |

### 🔄 既存コードの確認が必要な箇所

#### 🔥🔥🔥 最優先（全クリーチャー影響）

| ファイル | 関数 | 行番号 | 対象コード |
|---------|------|--------|-----------|
| `battle_preparation.gd` | `_prepare_participant_data` | 42, 78, 243 | `hp + base_up_hp` |
| `game_flow_manager.gd` | `_save_hp_changes_to_board` | 665 | `hp + base_up_hp` |
| `land_action_helper.gd` | `_heal_creature_hp` | 407 | `hp + base_up_hp` |

#### 🔥🔥 高優先度（特定クリーチャー）

| ファイル | 関数 | 行番号 | 対象 |
|---------|------|--------|------|
| `battle_skill_processor.gd` | `_process_blood_pudding_assist` | 232 | ブラッドプリン |
| `battle_skill_processor.gd` | `_apply_lone_beast_skill` | 292 | ローンビースト |
| `battle_skill_processor.gd` | `_count_general_kun_bonus` | 1087 | ジェネラルカン |

#### 🔥 中優先度（条件判定）

| ファイル | 関数 | 行番号 | 用途 |
|---------|------|--------|------|
| `condition_checker.gd` | `check_mhp_condition` | 多数 | MHP条件スキル |
| `invalidation_processor.gd` | `check_enemy_mhp` | 多数 | 無効化判定 |

---

### 📊 MHP計算の統一状況

```
✅ BattleParticipantクラス: MHPヘルパーメソッド実装完了
✅ HPCalculatorクラス: 削除完了（不要だった）
🔄 既存コード: MHP計算を直接 hp + base_up_hp で実行中

現状: BattleParticipant内では統一完了
次のステップ: 必要に応じて既存コードをリファクタリング
```

---

## トラブルシューティング

### ❓ Q1: MHPが正しく計算されない

**症状**:
```gdscript
print(creature_data.get("hp"))  # 40
print(creature_data.get("base_up_hp"))  # 10
# でもMHPが40のまま
```

**原因**: `base_up_hp`の加算を忘れている

**解決策**:
```gdscript
# ❌ 間違い
var mhp = creature_data.get("hp", 0)

# ✅ 正しい
var mhp = HPCalculator.calculate_max_hp(creature_data)
```

---

### ❓ Q2: ダメージが保存されない

**症状**: バトル後、クリーチャーのHPが満タンに戻る

**原因**: `current_hp`フィールドが保存されていない

**解決策**:
```gdscript
# バトル後に必ず保存
tile.creature_data["current_hp"] = participant.current_hp
```

---

### ❓ Q3: 援護クリーチャーのMHPが取得できない

**症状**: 援護スキルでエラーが発生

**原因**: 援護クリーチャーデータが`item_data`に格納されている

**解決策**:
```gdscript
# ✅ item_dataからMHP取得
var assist_mhp = HPCalculator.calculate_max_hp(item_data)
```

---

### ❓ Q4: 回復後もダメージ状態のまま

**症状**: 満タンまで回復したのに`is_damaged() == true`

**原因**: `current_hp`フィールドが削除されていない

**解決策**:
```gdscript
# 満タンになったらcurrent_hpを削除
if new_hp >= max_hp:
	creature_data.erase("current_hp")
else:
	creature_data["current_hp"] = new_hp
```

---

### ❓ Q5: スペクターのMHPがおかしい

**症状**: スペクターが常に同じMHP

**原因**: ランダム化処理が実行されていない

**解決策**:
```gdscript
# ボード配置時に必ず実行
if creature_data.get("id") == 321:
	_randomize_specter_hp(creature_data)
```

---

## 変更履歴

### 2025年10月30日 - HPCalculator削除とBattleParticipant統合

#### ❌ 削除したもの
- `scripts/utils/hp_calculator.gd` - 不完全な計算式のため削除

**削除理由**:
1. MHP = base_hp + base_up_hp のみで、戦闘中のボーナス（land, item, spell）を含まない
2. BattleParticipantクラスが既に全ての機能を持っている
3. "MHP"という言葉が2つの意味を持ち混乱を招く

#### ✅ 追加したもの
- `BattleParticipant.get_max_hp()` - 真のMHP取得
- `BattleParticipant.is_damaged()` - ダメージ判定
- `BattleParticipant.get_hp_ratio()` - 残りHP割合
- `BattleParticipant.check_mhp_condition()` - MHP条件チェック
- `BattleParticipant.is_mhp_below_or_equal()` - MHP以下判定
- `BattleParticipant.is_mhp_above_or_equal()` - MHP以上判定
- `BattleParticipant.is_mhp_in_range()` - MHP範囲判定
- `BattleParticipant.get_hp_debug_string()` - デバッグ文字列

#### 📝 使い分け

**BattleParticipant存在時（戦闘中）**:
```gdscript
// ✅ 正しい
var mhp = participant.get_max_hp()
var is_damaged = participant.is_damaged()
```

**JSON操作時（ボード・データ管理）**:
```gdscript
// ✅ 正しい
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
var current_hp = creature_data.get("current_hp", mhp)
```

---

## 次のステップ

### 🎯 短期目標

1. **battle_preparation.gdを置き換え**
   - `_prepare_participant_data`でHPCalculatorを使用
   - テスト実行して動作確認

2. **特殊クリーチャーの実装**
   - ブラッドプリン
   - ジェネラルカン
   - フロギストン

3. **condition_checker.gdの統合**
   - MHP条件判定を全てHPCalculatorに移行

### 🎯 中期目標

1. **全ファイルの置き換え完了**
2. **単体テストの作成**
3. **パフォーマンス測定**

### 🎯 長期目標

1. **ドキュメントの完全整備**
2. **エッジケースの網羅的テスト**
3. **最適化とリファクタリング**

---

**このドキュメントは継続的に更新されます**
