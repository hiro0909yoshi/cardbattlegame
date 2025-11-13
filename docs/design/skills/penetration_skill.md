# 貫通スキル

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.6  
**最終更新**: 2025年10月31日

---

## 📋 目次

1. [概要](#概要)
2. [発動条件](#発動条件)
3. [無効化対象](#無効化対象)
4. [条件タイプ](#条件タイプ)
5. [適用タイミング](#適用タイミング)
6. [実装コード例](#実装コード例)
7. [将来実装](#将来実装)

---

## 概要

防御側の土地ボーナスを無効化する侵略専用スキル。

---

## 発動条件

- **侵略側（攻撃側）のみ有効**
- 防御側が持っていても効果なし

---

## 無効化対象

貫通スキルは防御側の土地ボーナスHPのみを無効化します。

| 対象 | 無効化 |
|------|--------|
| ✅ 土地ボーナスHP (`land_bonus_hp`) | する |
| ❌ クリーチャー基本HP (`hp`) | しない |
| ❌ 感応ボーナスHP (`resonance_bonus_hp`) | しない |
| ❌ アイテムボーナスHP（将来実装） | しない |
| ❌ スペルボーナスHP（将来実装） | しない |

### 重要なポイント

貫通スキルは**土地によるHP上昇のみ**を無効化します。クリーチャー自身のHPや、感応スキルで得たHPには影響しません。

---

## 条件タイプ

貫通スキルには3種類の条件タイプがあります。

### 1. 無条件貫通

常に貫通が発動します。

```json
{
  "ability_parsed": {
	"keywords": ["貫通"]
  }
}
```

**実装例**:
- **ナイトメア** (ID: 180)
- **トロージャンホース** (ID: 220)

---

### 2. 敵属性条件

敵が特定の属性の場合のみ貫通が発動します。

```json
{
  "ability_parsed": {
	"keywords": ["貫通"],
	"keyword_conditions": {
	  "貫通": {
		"condition_type": "enemy_is_element",
		"elements": "water"
	  }
	}
  }
}
```

**実装例**:
- **ファイアービーク** (ID: 38) - 敵が水属性の場合のみ貫通

---

### 3. 攻撃力条件

**敵のAP**が特定値以上の場合のみ貫通が発動します。

```json
{
  "ability_parsed": {
	"keywords": ["貫通"],
	"keyword_conditions": {
	  "貫通": {
		"condition_type": "defender_ap_check",
		"operator": ">=",
		"value": 40
	  }
	}
  }
}
```

**対応演算子**:
- `>=`: 以上
- `>`: より大きい
- `==`: 等しい

**実装例**:
- **ピュトン** (ID: 36) - 敵AP40以上で貫通

---

## 適用タイミング

- **関数**: `BattleSystem._check_penetration_skill()`
- **タイミング**: BattleParticipant作成時（`_prepare_participants()`内）
- **効果**: 防御側の`land_bonus_hp`を0に設定

### 処理フロー

```
1. BattleParticipant作成
   ↓
2. 攻撃側の貫通スキルチェック
   ↓
3. 条件評価
   - 無条件 → 常にtrue
   - 敵属性条件 → 防御側の属性をチェック
   - 攻撃力条件 → 攻撃側のAPをチェック
   ↓
4. 貫通発動の場合
   → 防御側のland_bonus_hp = 0に設定
   ↓
5. バトル実行
```

---

## 実装コード例

### スキルモジュール

**場所**: `scripts/battle/skills/skill_penetration.gd`

```gdscript
class_name SkillPenetration

## 貫通スキルのチェック
static func check_and_notify(attacker) -> bool:
	# 防御側の貫通スキルは効果なし
	if not attacker.is_attacker:
		var keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
		if "貫通" in keywords:
			print("  【貫通】防御側のため効果なし")
			return false
	
	return true

## 貫通スキルを持っているかチェック
static func has_penetration(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "貫通" in keywords

## 侵略側が貫通を持っているかチェック
static func is_active(attacker) -> bool:
	if not attacker.is_attacker:
		return false
	
	return has_penetration(attacker.creature_data)

## 貫通スキルを適用（土地ボーナスHPを無効化）
static func apply_penetration(attacker, defender) -> void:
	if not is_active(attacker):
		return
	
	if defender.land_bonus_hp > 0:
		print("  【貫通】防御側の土地ボーナスHP ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		defender.update_current_hp()
```

### 旧実装（参考）

```gdscript
func _check_penetration_skill(attacker_data: Dictionary, defender_data: Dictionary, tile_info: Dictionary) -> bool:
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "貫通" in keywords:
		return false
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var penetrate_condition = keyword_conditions.get("貫通", {})
	
	# 無条件の場合
	if penetrate_condition.is_empty():
		return true
	
	# 条件付きの場合
	var condition_type = penetrate_condition.get("condition_type", "")
	
	match condition_type:
		"enemy_is_element":
			var required = penetrate_condition.get("elements", "")
			return defender_data.get("element", "") == required
		
		"attacker_st_check":
			var operator = penetrate_condition.get("operator", ">=")
			var value = penetrate_condition.get("value", 0)
			var attacker_st = attacker_data.get("ap", 0)
			
			match operator:
				">=": return attacker_st >= value
				">": return attacker_st > value
				"==": return attacker_st == value
	
	return false
```

---

## 実装済みクリーチャー一覧

### 無条件貫通

| ID | 名前 | 属性 | AP | HP |
|----|------|------|----|----|
| 38 | ファイアービーク | 火 | 30 | 40 |
| 334 | ナイトメア | 風 | 30 | 30 |
| 441 | トロージャンホース | 無 | 30 | 50 |

### 条件付き貫通

#### 攻撃力条件（AP40以上）

| ID | 名前 | 属性 | AP | HP | 条件 |
|----|------|------|----|----|------|
| 36 | ピュトン | 火 | 40 | 50 | 敵AP≥40で貫通 |

#### 敵属性条件

| ID | 名前 | 属性 | AP | HP | 条件 |
|----|------|------|----|----|------|
| 38 | ファイアービーク | 火 | 30 | 40 | 敵が水属性で貫通 |

### 実装統計

- **合計**: 4体（ファイアービークは2つの条件を持つ）
- **属性別**: 火2、風1、無1
- **条件タイプ**: 無条件3体、AP条件1体、敵属性条件1体

---

## 使用例

### シナリオ1: 無条件貫通（ナイトメア）

```
攻撃側: ナイトメア（AP:50、貫通）
防御側: フェニックス（HP:30、土地ボーナス+20）

通常の場合:
- 防御側の総HP = 30 + 20 = 50

貫通発動:
- 防御側の土地ボーナスが無効化
- 防御側の総HP = 30
- ナイトメアの攻撃でフェニックス撃破！
```

### シナリオ2: 条件付き貫通（ファイアービーク）

```
攻撃側: ファイアービーク（AP:30、貫通[水属性]）
防御側A: オドントティラヌス（水属性、HP:40 + 土地20）
防御側B: グレムリン（火属性、HP:30 + 土地20）

オドントティラヌスへの攻撃:
- 水属性なので貫通発動
- 総HP = 40（土地ボーナス無効）

グレムリンへの攻撃:
- 火属性なので貫通不発
- 総HP = 50（土地ボーナス有効）
```

### シナリオ3: 攻撃力条件（ピュトン）

```
攻撃側: ピュトン（基本AP:40、貫通[敵AP≥40]）
防御側A: バハムート（AP:50）
防御側B: グレムリン（AP:30）

対バハムート:
- 敵AP = 50
- 敵AP≥40なので貫通発動！

対グレムリン:
- 敵AP = 30
- 敵AP<40なので貫通不発
```

---

## 戦略的価値

### メリット
1. **防御無視**: 高レベル土地の防御を突破可能
2. **侵略成功率UP**: 土地ボーナスが大きい場合ほど有効
3. **コスト効率**: 低APでも土地を奪える

### 対策
1. **基本HPの高いクリーチャー配置**
2. **感応スキル持ちで防御強化**
3. **先制スキルで先手を取る**

---

## 将来実装

- **巻物攻撃**: 貫通と同様に土地ボーナスを無効化するスキル

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.6 | 2025/10/31 | スキルモジュール化：`skill_penetration.gd`として分離、実装コード更新 |
| 1.5 | 2025/10/24 | 個別ドキュメントとして分離 |

---

## 実装詳細（v1.6）

### モジュール構成

**スキルファイル**: `scripts/battle/skills/skill_penetration.gd`

**使用箇所**:
1. `BattleExecution.execute_attack_sequence()` - 防御側チェック
2. `BattleSkillProcessor.apply_pre_battle_skills()` - 土地ボーナス無効化

### 実装された機能

| 関数 | 用途 |
|------|------|
| `check_and_notify()` | 防御側の貫通チェック（メッセージのみ） |
| `has_penetration()` | 貫通スキル保持チェック |
| `is_active()` | 侵略側かつ貫通保持チェック |
| `apply_penetration()` | 土地ボーナスHP無効化 |

### 処理タイミング

**バトル前処理**（`apply_pre_battle_skills()`）:
```gdscript
# 貫通スキルによる土地ボーナスHP無効化
PenetrationSkill.apply_penetration(attacker, defender)
```

**攻撃ループ内**（`execute_attack_sequence()`）:
```gdscript
# 貫通スキルチェック（防御側の貫通は無効）
PenetrationSkill.check_and_notify(attacker_p)
```
