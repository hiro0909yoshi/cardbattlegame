# MHP統一化 影響箇所完全リスト

**作成日**: 2025年10月30日  
**目的**: MHPプロパティ化による影響範囲の完全な洗い出し  
**影響度**: 🔥🔥🔥 **非常に高** - 97箇所の`base_up_hp`使用、38体全クリーチャーに影響

---

## 📋 目次

1. 影響範囲サマリー
2. ファイル別影響箇所
3. クリーチャー別影響箇所
4. スペル・スキル別影響箇所
5. 修正計画とチェックリスト
6. テスト計画

---

## 1. 影響範囲サマリー

### 1.1 統計

| 項目 | 数 |
|------|-----|
| **`base_up_hp`使用箇所** | 97箇所 |
| **MHP計算箇所** | 50箇所以上 |
| **影響ファイル数** | 12ファイル |
| **影響クリーチャー数** | 38体全て |
| **影響スペル数** | 2個（マスグロース、ドミナントグロース）|

### 1.2 影響の大きいファイル TOP 5

| ファイル | base_up_hp使用数 | 影響度 |
|---------|----------------|--------|
| **battle_system.gd** | 24箇所 | 🔥🔥🔥 非常に高 |
| **battle_preparation.gd** | 20箇所 | 🔥🔥🔥 非常に高 |
| **game_flow_manager.gd** | 12箇所 | 🔥🔥 高 |
| **movement_controller.gd** | 9箇所 | 🔥🔥 高 |
| **battle_participant.gd** | 8箇所 | 🔥🔥 高 |

---

## 2. ファイル別影響箇所

### 🔥🔥🔥 最優先修正ファイル

#### 2.1 battle_preparation.gd（20箇所）

**影響内容**: バトル準備時のMHP計算

| 行 | 処理内容 | 影響クリーチャー |
|----|---------|----------------|
| 42 | `attacker_max_hp = attacker_base_hp + attacker.base_up_hp` | 全クリーチャー（侵略側） |
| 44 | `attacker.base_hp = attacker_current_hp - attacker.base_up_hp` | 全クリーチャー（侵略側） |
| 78 | `defender_max_hp = defender_base_hp + defender.base_up_hp` | 全クリーチャー（防御側） |
| 80 | `defender.base_hp = defender_current_hp - defender.base_up_hp` | 全クリーチャー（防御側） |
| 98 | `participant.base_up_hp = creature_data.get("base_up_hp", 0)` | 全クリーチャー |
| 236-255 | ブラッドプリンの援護MHP吸収処理 | **ブラッドプリン (ID: 137)** |
| 258-265 | スペクターのランダムMHP設定 | **スペクター (ID: 321)** |

**修正方針**:
```gdscript
// 修正前
var attacker_max_hp = attacker_base_hp + attacker.base_up_hp

// 修正後
var attacker_max_hp = attacker.max_hp  // プロパティ経由
// または
var attacker_max_hp = StatCalculator.get_max_hp_from_participant(attacker)
```

---

#### 2.2 battle_system.gd（24箇所）

**影響内容**: バトル後の永続バフ処理、スペル効果

| 行 | 処理内容 | 影響スペル・クリーチャー |
|----|---------|---------------------|
| 440-460 | マスグロース処理（MHP+5） | **マスグロース** |
| 465-489 | ドミナントグロース処理 | **ドミナントグロース** |
| 584-615 | バトル後永続バフ適用 | **キメラ (ID: 7)** - 周回ボーナスST+10<br>**モスタイタン (ID: 41)** - 周回ボーナスMHP+10<br>**バルキリー (ID: 35)** - 破壊時ST+10<br>**ダスクドウェラー (ID: 227)** - 破壊時ST&MHP+10<br>**バイロマンサー (ID: 327)** - バトル後ST/MHP変化<br>**ロックタイタン (ID: 211)** - バトル後ST/MHP変化 |
| 616-622 | ブルガサリ処理（敵アイテム使用後MHP+10） | **ブルガサリ (ID: 339)** |
| 651-662 | 永続バフの下限チェック（MHP≥0） | 全クリーチャー |

**修正方針**:
```gdscript
// 修正前
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + bonus_hp
var total_mhp = creature_data.get("hp", 0) + creature_data["base_up_hp"]

// 修正後
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + bonus_hp
var total_mhp = StatCalculator.get_max_hp(creature_data)
```

---

#### 2.3 game_flow_manager.gd（12箇所）

**影響内容**: 周回ボーナス処理

| 行 | 処理内容 | 影響クリーチャー |
|----|---------|----------------|
| 665-698 | 周回ボーナス適用（_apply_per_lap_bonus） | **キメラ (ID: 7)** - ST+10（周回ごと）<br>**モスタイタン (ID: 41)** - MHP+10（周回ごと）|

**修正方針**:
```gdscript
// 修正前
var max_hp = base_hp + base_up_hp

// 修正後
var max_hp = StatCalculator.get_max_hp(creature_data)
```

---

#### 2.4 movement_controller.gd（9箇所）

**影響内容**: HP回復処理、ダイスバフ処理

| 行 | 処理内容 | 影響 |
|----|---------|------|
| 297-307 | スタート通過時のHP回復 | 全クリーチャー |
| 410-420 | ダイスバフのMHP上昇 | ダイス条件持ちクリーチャー |

**修正方針**:
```gdscript
// 修正前
var max_hp = base_hp + base_up_hp

// 修正後
var max_hp = StatCalculator.get_max_hp(creature_data)
```

---

#### 2.5 battle_participant.gd（8箇所）

**影響内容**: BattleParticipant本体

| 行 | 処理内容 | 影響 |
|----|---------|------|
| 7 | `var base_up_hp: int = 0` 宣言 | 全クリーチャー |
| 82 | `current_hp = base_hp + base_up_hp + ...` | 全クリーチャー |
| 126-131 | ダメージ消費順序での`base_up_hp`消費 | 全クリーチャー |

**修正方針**:
```gdscript
// 追加
var original_hp: int          # 元のHP（creature_data["hp"]）

var max_hp: int:
	get:
		return original_hp + base_up_hp
```

---

### 🔥🔥 高優先修正ファイル

#### 2.6 battle_special_effects.gd（6箇所）

**影響内容**: バトル後HP保存、無効化判定

| 行 | 処理内容 | 影響 |
|----|---------|------|
| 100-110 | MHP条件での無効化判定 | 無効化持ちクリーチャー全般 |
| 269 | バトル後current_hp保存 | 全クリーチャー |

---

#### 2.7 battle_skill_processor.gd（5箇所）

**影響内容**: スキル効果計算

| 行 | 処理内容 | 影響クリーチャー |
|----|---------|----------------|
| 1084-1087 | ジェネラルカンのMHP50以上カウント | **ジェネラルカン (ID: 15)** |
| 1318 | スペクターのランダムMHP計算 | **スペクター (ID: 321)** |

---

#### 2.8 land_action_helper.gd（4箇所）

**影響内容**: 土地イベント処理

| 行 | 処理内容 | 影響クリーチャー |
|----|---------|----------------|
| 405-408 | アースズピリットのレベルアップMHP+10 | **アースズピリット (ID: 200)** |
| 410-413 | デュータイタンのレベルアップMHP-10 | **デュータイタン (ID: 328)** |

---

#### 2.9 board_system_3d.gd（4箇所）

**影響内容**: 地形変化イベント処理

| 行 | 処理内容 | 影響クリーチャー |
|----|---------|----------------|
| 407-410 | アースズピリットの地形変化MHP+10 | **アースズピリット (ID: 200)** |
| 412-415 | デュータイタンの地形変化MHP-10 | **デュータイタン (ID: 328)** |

---

### 🔥 中優先修正ファイル

#### 2.10 effect_manager.gd（5箇所）

**影響内容**: マスグロース、ドミナントグロース処理

| 行 | 処理内容 | 影響 |
|----|---------|------|
| 54-66 | マスグロース処理（MHP+5） | 全クリーチャー |
| 68-81 | ドミナントグロース処理 | 全クリーチャー |

---

#### 2.11 condition_checker.gd（5箇所）

**影響内容**: MHP条件判定

| 行 | 処理内容 | 影響 |
|----|---------|------|
| 57-63 | MHP_BELOW, MHP_ABOVE条件判定 | 強打条件持ちクリーチャー全般 |
| 191 | 敵MHP取得 | 強打条件持ちクリーチャー全般 |

---

#### 2.12 tiles/base_tiles.gd（2箇所）

**影響内容**: タイルのcreature_data初期化

| 行 | 処理内容 | 影響 |
|----|---------|------|
| - | `base_up_hp`のデフォルト値設定 | 全クリーチャー |

---

## 3. クリーチャー別影響箇所

### 3.1 MHPを直接使用するクリーチャー（高影響）

#### 🔥🔥🔥 最優先（特殊処理あり）

| ID | 名前 | 処理内容 | ファイル | 行数 |
|----|------|---------|---------|------|
| **137** | ブラッドプリン | 援護MHP吸収（永続） | battle_preparation.gd | 236-255 |
| **321** | スペクター | ランダムMHP設定 | battle_preparation.gd | 258-265 |
| **321** | スペクター | ランダムMHP設定 | battle_skill_processor.gd | 1318 |
| **15** | ジェネラルカン | MHP50以上カウント | battle_skill_processor.gd | 1084-1107 |

#### 🔥🔥 高優先（永続MHP変化あり）

| ID | 名前 | 処理内容 | ファイル | 行数 |
|----|------|---------|---------|------|
| **7** | キメラ | 周回ボーナスST+10（HP変化なし） | game_flow_manager.gd | 665-698 |
| **41** | モスタイタン | 周回ボーナスMHP+10 | game_flow_manager.gd | 665-698 |
| **35** | バルキリー | 破壊時ST+10（永続） | battle_system.gd | 584-615 |
| **227** | ダスクドウェラー | 破壊時ST&MHP+10（永続） | battle_system.gd | 584-615 |
| **327** | バイロマンサー | バトル後ST/MHP変化 | battle_system.gd | 598-615 |
| **211** | ロックタイタン | バトル後ST/MHP変化 | battle_system.gd | 598-615 |
| **200** | アースズピリット | レベルアップでMHP+10 | land_action_helper.gd<br>board_system_3d.gd | 405-408<br>407-410 |
| **328** | デュータイタン | レベルアップでMHP-10 | land_action_helper.gd<br>board_system_3d.gd | 410-413<br>412-415 |
| **339** | ブルガサリ | 敵アイテム使用後MHP+10 | battle_system.gd | 616-622 |

#### 🔥 中優先（MHP条件判定あり）

| ID | 名前 | 処理内容 | ファイル |
|----|------|---------|---------|
| **42** | フロギストン | MHP40以下で強打 | condition_checker.gd |
| - | ウォーリアー系 | MHP50以上で強打 | condition_checker.gd |
| - | 無効化持ち全般 | MHP条件で無効化 | battle_special_effects.gd |

### 3.2 全クリーチャー共通（38体全て）

以下の処理は**全38体のクリーチャー**に影響します：

| 処理 | ファイル | 影響度 |
|------|---------|--------|
| バトル準備時のMHP計算 | battle_preparation.gd | 🔥🔥🔥 |
| バトル後のHP保存 | battle_special_effects.gd | 🔥🔥🔥 |
| HP回復処理 | movement_controller.gd | 🔥🔥 |
| ダメージ消費順序 | battle_participant.gd | 🔥🔥 |
| マスグロース効果 | battle_system.gd, effect_manager.gd | 🔥🔥 |

---

## 4. スペル・スキル別影響箇所

### 4.1 スペル

| スペル名 | 効果 | ファイル | 影響度 |
|---------|------|---------|--------|
| **マスグロース** | 全自クリーチャーMHP+5 | battle_system.gd (440-460)<br>effect_manager.gd (54-66) | 🔥🔥🔥 |
| **ドミナントグロース** | 特定属性MHP上昇 | battle_system.gd (465-489)<br>effect_manager.gd (68-81) | 🔥🔥 |

### 4.2 アイテム

| アイテム | 効果 | ファイル | 影響度 |
|---------|------|---------|--------|
| **援護アイテム全般** | ブラッドプリンのMHP吸収 | battle_preparation.gd (236-255) | 🔥🔥 |

### 4.3 土地イベント

| イベント | 効果 | 対象クリーチャー | ファイル | 影響度 |
|---------|------|----------------|---------|--------|
| **レベルアップ** | MHP+10/-10 | アースズピリット、デュータイタン | land_action_helper.gd | 🔥🔥 |
| **地形変化** | MHP+10/-10 | アースズピリット、デュータイタン | board_system_3d.gd | 🔥🔥 |

---

## 5. 修正計画とチェックリスト

### フェーズ1: 基盤整備（1日目）

#### ✅ 新クラス作成

- [ ] **StatCalculator作成** (`scripts/utils/stat_calculator.gd`)
  ```gdscript
  class_name StatCalculator
  
  static func get_max_hp(creature_data: Dictionary) -> int:
	  return creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
  
  static func get_current_hp(creature_data: Dictionary) -> int:
	  var max_hp = get_max_hp(creature_data)
	  return creature_data.get("current_hp", max_hp)
  
  static func get_max_hp_from_participant(participant: BattleParticipant) -> int:
	  return participant.max_hp
  ```

- [ ] **BattleParticipantにmax_hpプロパティ追加**
  ```gdscript
  var original_hp: int  # 元のHP
  
  var max_hp: int:
	  get:
		  return original_hp + base_up_hp
  ```

- [ ] **ユニットテスト作成**
  - StatCalculator用テスト
  - BattleParticipant.max_hp用テスト

---

### フェーズ2: 最優先ファイル修正（2日目）

#### ✅ battle_preparation.gd（20箇所）

**テスト対象クリーチャー**:
- [ ] ブラッドプリン (ID: 137) - 援護MHP吸収
- [ ] スペクター (ID: 321) - ランダムMHP
- [ ] 通常クリーチャー - MHP計算

**修正チェックリスト**:
- [ ] 行42: `attacker_max_hp`計算
- [ ] 行44: `attacker.base_hp`計算
- [ ] 行78: `defender_max_hp`計算
- [ ] 行80: `defender.base_hp`計算
- [ ] 行98: `participant.base_up_hp`設定
- [ ] 行236-255: ブラッドプリン処理
- [ ] 行258-265: スペクター処理

---

#### ✅ battle_participant.gd（8箇所）

**テスト対象**:
- [ ] max_hpプロパティの動作確認
- [ ] current_hp計算
- [ ] ダメージ消費順序

**修正チェックリスト**:
- [ ] `original_hp`フィールド追加
- [ ] `max_hp`プロパティ追加
- [ ] コンストラクタ修正
- [ ] update_current_hp()修正

---

### フェーズ3: 高優先ファイル修正（3日目）

#### ✅ battle_system.gd（24箇所）

**テスト対象クリーチャー**:
- [ ] キメラ (ID: 7) - 周回ボーナスST+10
- [ ] モスタイタン (ID: 41) - 周回ボーナスMHP+10
- [ ] バルキリー (ID: 35) - 破壊時ST+10
- [ ] ダスクドウェラー (ID: 227) - 破壊時ST&MHP+10
- [ ] バイロマンサー (ID: 327) - バトル後変化
- [ ] ロックタイタン (ID: 211) - バトル後変化
- [ ] ブルガサリ (ID: 339) - 敵アイテム使用後MHP+10

**テスト対象スペル**:
- [ ] マスグロース - MHP+5
- [ ] ドミナントグロース - MHP上昇

**修正チェックリスト**:
- [ ] 行440-460: マスグロース
- [ ] 行465-489: ドミナントグロース
- [ ] 行584-615: 永続バフ適用
- [ ] 行616-622: ブルガサリ
- [ ] 行651-662: 下限チェック

---

#### ✅ game_flow_manager.gd（12箇所）

**テスト対象クリーチャー**:
- [ ] キメラ (ID: 7) - 周回ボーナス
- [ ] モスタイタン (ID: 41) - 周回ボーナス

**修正チェックリスト**:
- [ ] 行665-698: 周回ボーナス処理

---

#### ✅ movement_controller.gd（9箇所）

**テスト内容**:
- [ ] スタート通過でのHP回復
- [ ] ダイスバフのMHP上昇

**修正チェックリスト**:
- [ ] 行297-307: HP回復処理
- [ ] 行410-420: ダイスバフ処理

---

### フェーズ4: 中優先ファイル修正（4日目）

#### ✅ その他ファイル

- [ ] battle_special_effects.gd（6箇所）
- [ ] battle_skill_processor.gd（5箇所）
- [ ] land_action_helper.gd（4箇所）
- [ ] board_system_3d.gd（4箇所）
- [ ] effect_manager.gd（5箇所）
- [ ] condition_checker.gd（5箇所）
- [ ] tiles/base_tiles.gd（2箇所）

**テスト対象クリーチャー**:
- [ ] ジェネラルカン (ID: 15) - MHP50以上カウント
- [ ] アースズピリット (ID: 200) - レベルアップMHP+10
- [ ] デュータイタン (ID: 328) - レベルアップMHP-10
- [ ] フロギストン (ID: 42) - MHP40以下強打

---

### フェーズ5: 統合テストと回帰テスト（5日目）

#### ✅ 統合テスト

**優先度1: 特殊処理クリーチャー（4体）**
- [ ] ブラッドプリン (ID: 137)
  - [ ] 援護MHP吸収が正しく動作
  - [ ] MHP上限100チェック
  - [ ] 永続MHP保存
- [ ] スペクター (ID: 321)
  - [ ] ランダムMHP設定（10-70）
  - [ ] バトル後リセット
- [ ] ジェネラルカン (ID: 15)
  - [ ] MHP50以上カウント
  - [ ] ST計算
- [ ] ブルガサリ (ID: 339)
  - [ ] 敵アイテム使用後MHP+10
  - [ ] 永続保存

**優先度2: 永続MHP変化クリーチャー（8体）**
- [ ] キメラ (ID: 7) - 周回ボーナス
- [ ] モスタイタン (ID: 41) - 周回ボーナス
- [ ] バルキリー (ID: 35) - 破壊時ST+10
- [ ] ダスクドウェラー (ID: 227) - 破壊時ST&MHP+10
- [ ] バイロマンサー (ID: 327) - バトル後変化
- [ ] ロックタイタン (ID: 211) - バトル後変化
- [ ] アースズピリット (ID: 200) - レベルアップMHP+10
- [ ] デュータイタン (ID: 328) - レベルアップMHP-10

**優先度3: スペル効果（2個）**
- [ ] マスグロース - 全自クリーチャーMHP+5
- [ ] ドミナントグロース - 特定属性MHP上昇

**優先度4: 一般的な処理（全クリーチャー）**
- [ ] バトル準備時のMHP計算
- [ ] バトル後のHP保存
- [ ] スタート通過でのHP回復
- [ ] ダメージ消費順序

---

#### ✅ 回帰テスト

**全クリーチャー（38体）の基本動作確認**:
- [ ] バトル開始時のステータス表示
- [ ] MHP計算の正確性
- [ ] バトル後のHP保存
- [ ] HP回復の正確性
- [ ] ダメージ計算

**テストケース数**: 最低100ケース
- 特殊処理: 4体 × 5ケース = 20
- 永続変化: 8体 × 3ケース = 24
- スペル: 2個 × 3ケース = 6
- 一般処理: 20体 × 2ケース = 40
- エッジケース: 10ケース

---

## 6. テスト計画

### 6.1 ユニットテスト

#### StatCalculatorテスト（10ケース）

```gdscript
extends GutTest

func test_get_max_hp_normal():
	var data = {"hp": 50, "base_up_hp": 10}
	assert_eq(StatCalculator.get_max_hp(data), 60)

func test_get_max_hp_zero_bonus():
	var data = {"hp": 50, "base_up_hp": 0}
	assert_eq(StatCalculator.get_max_hp(data), 50)

func test_get_max_hp_missing_bonus():
	var data = {"hp": 50}
	assert_eq(StatCalculator.get_max_hp(data), 50)

func test_get_max_hp_negative_bonus():
	# デュータイタンのケース
	var data = {"hp": 50, "base_up_hp": -30}
	assert_eq(StatCalculator.get_max_hp(data), 20)

func test_get_current_hp_default_to_max():
	var data = {"hp": 50, "base_up_hp": 10}
	assert_eq(StatCalculator.get_current_hp(data), 60)

func test_get_current_hp_after_damage():
	var data = {"hp": 50, "base_up_hp": 10, "current_hp": 45}
	assert_eq(StatCalculator.get_current_hp(data), 45)
```

---

#### BattleParticipant.max_hpテスト（10ケース）

```gdscript
extends GutTest

var participant: BattleParticipant

func test_max_hp_normal():
	var data = {"hp": 50, "base_up_hp": 10}
	participant = BattleParticipant.new(data, 50, 0, 30, true, 0)
	participant.base_up_hp = 10
	assert_eq(participant.max_hp, 60)

func test_max_hp_after_mass_growth():
	var data = {"hp": 50, "base_up_hp": 5}
	participant = BattleParticipant.new(data, 50, 0, 30, true, 0)
	participant.base_up_hp = 5
	assert_eq(participant.max_hp, 55)
	
	# マスグロース+5
	participant.base_up_hp += 5
	assert_eq(participant.max_hp, 60)
```

---

### 6.2 統合テスト

#### ブラッドプリンテスト（5ケース）

```gdscript
extends GutTest

func test_blood_purin_absorb_assist_mhp():
	# 援護MHP吸収のテスト
	var blood_purin = {"id": 137, "hp": 40, "base_up_hp": 0}
	var assist = {"hp": 30, "base_up_hp": 0}
	
	# 援護を使用
	# ...吸収処理...
	
	assert_eq(blood_purin["base_up_hp"], 30)
	assert_eq(StatCalculator.get_max_hp(blood_purin), 70)

func test_blood_purin_mhp_cap_100():
	# MHP上限100のテスト
	var blood_purin = {"id": 137, "hp": 40, "base_up_hp": 50}
	var assist = {"hp": 30, "base_up_hp": 0}
	
	# 援護を使用（MHP=90→100が上限）
	# ...吸収処理...
	
	assert_eq(blood_purin["base_up_hp"], 60)  # 50+10（上限まで）
	assert_eq(StatCalculator.get_max_hp(blood_purin), 100)
```

---

#### スペクターテスト（3ケース）

```gdscript
func test_specter_random_mhp():
	var specter = {"id": 321, "hp": 50, "base_up_hp": 0}
	
	# ランダムMHP設定（10-70）
	# ...処理...
	
	var mhp = StatCalculator.get_max_hp(specter)
	assert_between(mhp, 10, 70)

func test_specter_reset_after_battle():
	var specter = {"id": 321, "hp": 50, "base_up_hp": 20}
	
	# バトル後リセット
	specter["base_up_hp"] = 0
	
	assert_eq(StatCalculator.get_max_hp(specter), 50)
```

---

### 6.3 回帰テストシナリオ

#### シナリオ1: 通常バトル（全クリーチャー共通）

1. クリーチャーを配置
2. バトル開始
3. MHP計算を確認
4. ダメージを与える
5. バトル終了
6. current_hp保存を確認
7. スタート通過でHP回復
8. 回復後HPを確認

**期待結果**: 修正前後でHP計算が一致

---

#### シナリオ2: マスグロース使用

1. クリーチャーを3体配置
2. マスグロース使用
3. 各クリーチャーのMHP+5を確認
4. バトルでダメージ
5. スタート通過でHP回復
6. MHPを超えないことを確認

**期待結果**: MHP+5が正しく適用

---

#### シナリオ3: 周回ボーナス（キメラ・モスタイタン）

1. キメラを配置
2. 周回完了
3. ST+10を確認（MHP不変）
4. モスタイタンを配置
5. 周回完了
6. MHP+10を確認
7. current_hp回復を確認

**期待結果**: 周回ボーナスが正しく適用

---

## 7. リスク管理

### 7.1 高リスク項目

| リスク | 影響度 | 発生確率 | 対策 |
|--------|--------|---------|------|
| MHP計算ロジックの差異 | 🔥🔥🔥 | 高 | 詳細なユニットテスト |
| BattleParticipantとの統合バグ | 🔥🔥🔥 | 中 | 段階的実装とテスト |
| 特殊クリーチャーの処理漏れ | 🔥🔥 | 中 | クリーチャー別チェックリスト |
| スペル効果の不具合 | 🔥🔥 | 低 | マスグロース/ドミナントグロースの重点テスト |
| 回帰バグ（一般処理） | 🔥 | 中 | 全クリーチャー回帰テスト |

### 7.2 ロールバック計画

1. **Git ブランチで作業**: `feature/mhp-unification`
2. **フェーズごとにコミット**
3. **問題発生時**: 前のコミットに戻す
4. **最終確認**: masterへのマージ前に全テスト実行

---

## 8. 成果指標

### 8.1 コード品質

- [ ] MHP計算の統一率: **100%**（97箇所 → StatCalculator経由）
- [ ] テストカバレッジ: **90%以上**
- [ ] 重複コード削減: **80行削減目標**

### 8.2 保守性

- [ ] MHP計算の修正箇所: **97箇所 → 1箇所（StatCalculator）**
- [ ] 新規MHP関連機能の追加工数: **60%削減**

---

**最終更新**: 2025年10月30日  
**総修正箇所**: 97箇所  
**影響クリーチャー数**: 38体全て  
**推定作業日数**: 5日間
