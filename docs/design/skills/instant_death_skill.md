# 即死スキル

**バージョン**: 1.0  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [概要](#概要)
2. [発動タイミング](#発動タイミング)
3. [発動条件](#発動条件)
4. [効果](#効果)
5. [条件タイプ](#条件タイプ)
6. [実装クリーチャー](#実装クリーチャー)
7. [適用タイミング](#適用タイミング)
8. [他スキルとの相互作用](#他スキルとの相互作用)
9. [実装コード](#実装コード)
10. [使用例](#使用例)
11. [設計思想](#設計思想)

---

## 概要

攻撃後、一定確率で相手を即死させるアクティブスキル。

---

## 発動タイミング

- **攻撃後、ダメージ適用後**に即死判定
- 攻撃が無効化された場合は発動しない
- 各攻撃ごとに判定（2回攻撃なら2回判定）

---

## 発動条件

- 即死スキル保持
- 条件を満たす（属性、ST、立場など）
- 確率判定成功

---

## 効果

- 即死成功時、相手の`instant_death_flag = true`
- 相手のHPを0にする
- **再生・復活・変身スキルは発動不可**

---

## 条件タイプ

### 1. 無条件即死

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "none",
		"probability": 70
	  }
	}
  }
}
```

**実装例**:
- アネイマブル (ID: 201) - 後手；即死[70%]

---

### 2. 敵属性条件

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "enemy_is_element",
		"elements": "fire",
		"probability": 60
	  }
	}
  }
}
```

**実装例**:
- イエティ (ID: 111) - 即死[火・60%]
- ダンピール (ID: 325) - 即死[地・60%]
- セイント (ID: 424) - 即死[無・100%]

**特殊ケース**:
- `elements: "全"` - すべての属性に有効
- キロネックス (ID: 118) - 防御側なら即死[全・80%]

---

### 3. 防御側ST条件

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "defender_st_check",
		"operator": ">=",
		"value": 50,
		"probability": 60
	  }
	}
  }
}
```

**実装例**:
- シグルド (ID: 16) - 即死[ST50以上・60%]

**説明**: 相手（防御側）の基本STが50以上の場合に即死判定

---

### 4. 使用者が防御側条件

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "defender_role",
		"elements": "全",
		"probability": 80
	  }
	}
  }
}
```

**実装例**:
- キロネックス (ID: 118) - 防御側なら即死[全・80%]

**説明**: キロネックスが防御側の時のみ、反撃時に即死判定

---

## 実装クリーチャー

### 実装済み（6体）

| ID | 名前 | 属性 | 条件 | 確率 |
|----|------|------|------|-----|
| 16 | シグルド | 火 | 防御側ST≥50 | 60% |
| 111 | イエティ | 水 | 敵が火属性 | 60% |
| 118 | キロネックス | 水 | 防御側なら | 80% |
| 201 | アネイマブル | 地 | 無条件（後手） | 70% |
| 325 | ダンピール | 風 | 敵が地属性 | 60% |
| 424 | セイント | 無 | 敵が無属性 | 100% |

---

## 適用タイミング

- **関数**: `BattleSystem._check_instant_death()`
- **タイミング**: 攻撃後、ダメージ適用後、死亡チェック前
- **判定**: 基本STで条件判定（計算後のSTではない）

---

## 他スキルとの相互作用

| スキル | 関係 |
|--------|------|
| 無効化 | 即死を無効化できる（将来実装） |
| 再生 | 即死されたら再生不可 |
| 復活 | 即死されたら復活不可（将来実装） |
| 変身 | 即死されたら変身不可（将来実装） |
| 先制 | 先制持ちが即死を持つ場合、先制攻撃時に即死判定 |
| 2回攻撃 | 各攻撃ごとに即死判定 |

---

## 実装コード

```gdscript
func _check_instant_death(attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	# 即死スキルを持つかチェック
	var ability_parsed = attacker.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "即死" in keywords:
		return false
	
	# 即死条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	# 条件チェック
	if not _check_instant_death_condition(instant_death_condition, attacker, defender):
		return false
	
	# 確率判定
	var probability = instant_death_condition.get("probability", 0)
	var random_value = randf() * 100.0
	
	if random_value <= probability:
		print("【即死発動】", attacker.creature_data.get("name", "?"), 
			  " → ", defender.creature_data.get("name", "?"), 
			  " (", probability, "% 判定成功)")
		defender.instant_death_flag = true
		defender.base_hp = 0
		defender.update_current_hp()
		return true
	else:
		print("【即死失敗】確率:", probability, "% 判定値:", int(random_value), "%")
		return false
```

---

## 使用例

### バトルフロー（イエティ vs ファイアードレイク）

```
侵略側: イエティ AP:40 HP:40 (即死[火・60%])
防御側: ファイアードレイク AP:30 HP:50 (火属性)

【第1攻撃】侵略側の攻撃
  イエティ AP:40 → ファイアードレイク
  ダメージ処理:
	- 土地ボーナス: 10 消費
	- 基本HP: 30 消費
  → 残HP: 10 (基本HP:10)

【即死判定開始】イエティ → ファイアードレイク
【即死条件】敵がfire属性 → 条件満たす
【即死発動】イエティ → ファイアードレイク (60% 判定成功)
  → ファイアードレイク 撃破！

【結果】侵略成功（ファイアードレイクは反撃できず）
```

---

## 設計思想

- **ハイリスク・ハイリターン**: 確率発動だが、成功すれば一撃必殺
- **条件付き発動**: 無条件即死は少なく、ほとんどが条件付き
- **将来の拡張性**: `instant_death_flag`により、即死回避スキル実装が容易
- **バランス調整**: 確率と条件により、強力すぎないように調整

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/24 | 1.0 | 個別ドキュメントとして分離 |
