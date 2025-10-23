# 強打スキル

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.5  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [概要](#概要)
2. [効果](#効果)
3. [主な条件タイプ](#主な条件タイプ)
4. [適用タイミング](#適用タイミング)
5. [感応との相乗効果](#感応との相乗効果)
6. [アイテムによる強打付与](#アイテムによる強打付与)
7. [実装コード例](#実装コード例)
8. [使用例](#使用例)

---

## 概要

特定条件下でAPを増幅するパッシブスキル。

---

## 効果

APに乗数をかけて増幅します。

- **一般的な乗数**: ×1.5
- **強力な乗数**: ×2.0

---

## 主な条件タイプ

強打スキルは様々な条件で発動します。

### 1. 隣接自領地条件 (adjacent_ally_land)

バトル発生タイルの隣接に自分の土地がある場合に発動。

```json
{
  "effects": [{
	"effect_type": "power_strike",
	"multiplier": 1.5,
	"conditions": [
	  {"condition_type": "adjacent_ally_land"}
	]
  }]
}
```

**実装例**:
- **ローンビースト** (ID: 49) - 隣接自領地で強打×1.5

---

### 2. 土地属性条件 (on_element_land)

特定属性の土地でバトルする場合に発動。

```json
{
  "effects": [{
	"effect_type": "power_strike",
	"multiplier": 2.0,
	"conditions": [
	  {
		"condition_type": "on_element_land",
		"element": "fire"
	  }
	]
  }]
}
```

**使用例**:
- 火属性の土地でバトル → 強打×2.0発動

---

### 3. 土地レベル条件 (land_level_check)

土地レベルが特定値以上/以下で発動。

```json
{
  "effects": [{
	"effect_type": "power_strike",
	"multiplier": 1.5,
	"conditions": [
	  {
		"condition_type": "land_level_check",
		"operator": ">=",
		"value": 3
	  }
	]
  }]
}
```

**対応演算子**:
- `>=`: 以上
- `>`: より大きい
- `<=`: 以下
- `<`: より小さい
- `==`: 等しい

---

## 適用タイミング

- **関数**: `EffectCombat.apply_power_strike()`
- **タイミング**: 感応スキル適用後（`_apply_skills()`内）
- **重要**: **感応で上昇したAPを基準に計算される**

### 適用順序

```
1. 応援スキル適用
2. 巻物攻撃判定
3. 感応スキル適用
4. 土地数比例効果
5. 強打スキル適用 ← ここ（感応後のAPを基準）
6. 2回攻撃判定
7. 攻撃シーケンス実行
```

---

## 感応との相乗効果

強打スキルは感応の**後**に適用されるため、相乗効果が得られます。

### 計算例

```gdscript
# 元のAP
var base_ap = 20

# 1. 感応適用
base_ap += 30  # → 50

# 2. 強打適用（感応後のAPが基準）
base_ap *= 1.5  # → 75
```

### 実例: モルモ（仮定）

```
基本AP: 20
感応[火]: +30
強打: ×1.5（隣接自領地条件）

条件:
- 火土地を1個所有
- バトルタイルの隣接に自領地あり

計算:
1. 基本AP: 20
2. 感応発動: 20 + 30 = 50
3. 強打発動: 50 × 1.5 = 75

→ 最終AP: 75
```

このように、感応と強打を組み合わせることで大幅な火力増強が可能です。

---

## アイテムによる強打付与

🆕 **Phase 1-A実装**: アイテムで一時的に強打スキルを付与可能

### 付与条件と発動条件の違い

```json
{
  "effect_type": "grant_skill",
  "skill": "強打",
  "condition": {
	"condition_type": "user_element",
	"elements": ["fire"]
  }
}
```

- **付与条件** (`condition`): 火属性クリーチャーが使用した場合のみスキル付与
- **発動条件**: 付与された強打は**無条件で発動**（バトル時の条件チェックなし）

### 実装例: マグマハンマー (ID: 1062)

```json
{
  "id": 1062,
  "name": "マグマハンマー",
  "type": "item",
  "cost": {"mp": 20},
  "effect": "ST+20；💧🌱使用時、強打",
  "ability_parsed": {
	"effects": [
	  {"effect_type": "buff_ap", "value": 20},
	  {
		"effect_type": "grant_skill",
		"skill": "強打",
		"condition": {
		  "condition_type": "user_element",
		  "elements": ["fire"]
		}
	  }
	]
  }
}
```

### 処理フロー

```
1. アイテムフェーズでマグマハンマー選択
   ↓
2. 条件チェック（user_element: fire）
   ├─ 火属性クリーチャー → 付与
   └─ その他属性 → スキップ
   ↓
3. スキル付与
   ├─ keywords配列に「強打」追加
   └─ effects配列に強打効果追加
	   {
		 "effect_type": "power_strike",
		 "multiplier": 1.5,
		 "conditions": []  // 無条件で発動
	   }
   ↓
4. バトル時に強打発動
   AP × 1.5
```

### 実装クラス

- `BattleSystem._apply_item_effects()` - アイテム効果適用
- `BattleSystem._grant_skill_to_participant()` - スキル付与
- `BattleSystem._check_skill_grant_condition()` - 付与条件チェック

---

## 実装コード例

```gdscript
func apply_power_strike(creature_data: Dictionary, context: Dictionary) -> Dictionary:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	var modified_data = creature_data.duplicate()
	var current_ap = modified_data.get("ap", 0)
	
	for effect in effects:
		if effect.get("effect_type") == "power_strike":
			var conditions = effect.get("conditions", [])
			
			# 条件チェック
			var all_conditions_met = true
			for condition in conditions:
				if not evaluate_condition(condition, context):
					all_conditions_met = false
					break
			
			# 条件を満たしていればAP増幅
			if all_conditions_met:
				var multiplier = effect.get("multiplier", 1.0)
				current_ap = int(current_ap * multiplier)
	
	modified_data["ap"] = current_ap
	return modified_data
```

---

## 使用例

### シナリオ1: 隣接自領地条件

```
攻撃側: ローンビースト（AP:30、強打×1.5[隣接自領地]）
バトルタイル: 45番
隣接タイル: [38, 44, 46, 52, 53, 54]

自領地状況:
- 38番: 攻撃側プレイヤー ✓
- 44番: 空き地
- 46番: 相手プレイヤー
- 52番: 空き地
- 53番: 空き地
- 54番: 相手プレイヤー

結果:
- 隣接に自領地あり → 強打発動
- AP: 30 × 1.5 = 45
```

### シナリオ2: 感応+強打の組み合わせ

```
攻撃側: モルモ（AP:20、感応[火]+30、強打×1.5）
条件:
- 火土地を1個所有
- バトルタイルの隣接に自領地あり

計算:
1. 基本AP: 20
2. 感応発動: 20 + 30 = 50
3. 強打発動: 50 × 1.5 = 75

→ 最終AP: 75
```

### シナリオ3: アイテムによる強打付与

```
攻撃側: グレムリン（火属性、AP:20）
アイテム: マグマハンマー（ST+20、火属性使用時強打）

1. アイテムフェーズ
   - グレムリンは火属性 → 条件満たす
   - マグマハンマー使用
   
2. 効果適用
   - AP+20: 20 → 40
   - 強打付与（×1.5、無条件）
   
3. バトル
   - 強打発動: 40 × 1.5 = 60
   
→ 最終AP: 60
```

---

## 戦略的価値

### メリット
1. **高火力**: 条件を満たせば大幅な攻撃力増強
2. **相乗効果**: 感応と組み合わせることでさらに強力に
3. **柔軟性**: 様々な条件で発動可能

### デメリット
1. **条件依存**: 条件を満たさないと発動しない
2. **配置戦略**: 隣接自領地条件の場合、配置場所が重要
3. **対策されやすい**: 相手に条件を読まれると回避される

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.5 | 2025/10/24 | 個別ドキュメントとして分離 |
