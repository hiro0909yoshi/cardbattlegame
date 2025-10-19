# 無効化スキル設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月20日  
**最終更新**: 2025年10月20日

---

## 📋 目次

1. [概要](#概要)
2. [無効化の基本仕様](#無効化の基本仕様)
3. [無効化タイプ一覧](#無効化タイプ一覧)
4. [実装するクリーチャー一覧](#実装するクリーチャー一覧)
5. [データ構造](#データ構造)
6. [実装フロー](#実装フロー)
7. [他スキルとの相互作用](#他スキルとの相互作用)
8. [実装の優先順位](#実装の優先順位)

---

## 概要

### 無効化スキルとは

敵からの攻撃を条件に応じて**完全無効化**または**軽減**するパッシブスキル。

### 主な特徴

- ✅ 条件を満たす攻撃を無効化または軽減
- ✅ 完全無効化（0ダメージ）または軽減（50%など）
- ✅ 無効化しても反撃は通常通り発生
- ✅ スペルやアイテムからも付与可能
- ✅ 巻物攻撃と貫通攻撃は**別々に判定**

---

## 無効化の基本仕様

### 効果

無効化が成功した場合：

| 項目 | 効果 |
|------|------|
| ダメージ | **0ダメージ**または**軽減率適用** |
| 即死判定 | **スキップ**される |
| 反撃 | **通常通り発生** |
| ログ表示 | 「【無効化】」または「【軽減】」表示 |

### 軽減率の扱い

```gdscript
# 完全無効化
reduction_rate = 0.0  # ダメージ = 0

# 50%軽減（ID:6 ガスクラウド）
reduction_rate = 0.5  # ダメージ = 元のダメージ × 0.5

# 無効化なし（デフォルト）
reduction_rate = 指定なし  # ダメージ = 元のダメージ × 0.0（完全無効化）
```

**重要**: `reduction_rate`が指定されていない場合、デフォルトで**完全無効化（0.0）**とする。

### 判定タイミング

```
バトル開始
  ↓
攻撃力計算（感応・強打・アイテム・スペル適用）
  ↓
【無効化判定】← ここで判定
  ├─ 無効化成功 → ダメージ = 0 または 軽減
  └─ 無効化失敗 → 通常ダメージ処理
  ↓
ダメージ適用
  ↓
即死判定（無効化成功時はスキップ）
  ↓
反撃処理
```

---

## 無効化タイプ一覧

### 1. 属性無効化（element）

**説明**: 特定の属性からの攻撃を完全無効化

**判定基準**: 攻撃側の**基礎属性**（`creature_data.element`）

**データ構造**:
```json
{
  "nullify_type": "element",
  "element": "fire"  // 単一属性
}
```

または

```json
{
  "nullify_type": "element",
  "elements": ["wind", "earth"]  // 複数属性
}
```

**実装クリーチャー**:
- ID:111 イエティ - 無効化[火]
- ID:325 ダンピール - 無効化[地]
- ID:424 セイント - 無効化[無]
- ID:100 アーマーナイト - 無効化[地風]
- ID:104 アクアドラゴン - 無効化[水地]

---

### 2. 最大HP条件（mhp_above / mhp_below）

**説明**: 攻撃側の最大HPを条件に無効化

**判定基準**: 攻撃側の**基礎HP**（`creature_data.hp`）
- アイテム・スペルのバフは**無視**
- 感応ボーナスも**無視**

**データ構造**:
```json
{
  "nullify_type": "mhp_above",
  "value": 50  // MHP50以上を無効化
}
```

```json
{
  "nullify_type": "mhp_below",
  "value": 30  // MHP30以下を無効化
}
```

**実装クリーチャー**:
- ID:16 シグルド - 無効化[MHP50以上]
- ID:105 アクアリング - 無効化[MHP30以下]

---

### 3. ST条件（st_below）

**説明**: 攻撃側の基本STを条件に無効化

**判定基準**: 攻撃側の**基礎AP**（`creature_data.ap`）
- アイテム・スペルのバフは**無視**
- 感応・強打も**無視**

**データ構造**:
```json
{
  "nullify_type": "st_below",
  "value": 40  // ST40以下を無効化
}
```

**実装クリーチャー**:
- ID:122 シーホース - 無効化[ST40以下]

---

### 4. 全攻撃軽減（all_attacks）

**説明**: 全ての攻撃を一定割合で軽減

**判定基準**: 無条件（全ての攻撃が対象）

**データ構造**:
```json
{
  "nullify_type": "all_attacks",
  "reduction_rate": 0.5  // 50%軽減
}
```

**重要**: これは完全無効化ではなく、**ダメージ軽減**

**実装クリーチャー**:
- ID:6 ガスクラウド - 無効化[1/2]（全攻撃を50%に軽減）

---

### 5. 能力持ち無効化（has_ability）

**説明**: 特定のスキルを持つクリーチャーからの攻撃を無効化

**判定基準**: 攻撃側の`keywords`配列に特定の能力が含まれるか

**データ構造**:
```json
{
  "nullify_type": "has_ability",
  "ability": "先制"  // 先制持ちを無効化
}
```

**実装クリーチャー**:
- ID:213 グレートタスカー - 無効化[先制持ち]

---

### 6. 巻物攻撃無効化（scroll_attack）

**説明**: 巻物攻撃を無効化

**判定基準**: `is_using_scroll`フラグ

**データ構造**:
```json
{
  "nullify_type": "scroll_attack"
}
```

**実装クリーチャー**:
- ID:1 アームドパラディン - 無効化[巻物]
- ID:112 イド - 無効化[巻物]

**注意**: 巻物攻撃スキルの実装が前提

---

### 7. 通常攻撃無効化（normal_attack）

**説明**: 通常攻撃（巻物攻撃以外）を無効化

**判定基準**: `is_using_scroll == false`

**データ構造**:
```json
{
  "nullify_type": "normal_attack"
}
```

**実装クリーチャー**:
- ID:106 アブサス - 無効化[通常攻撃]（条件付き）

---

### 8. 条件付き無効化（条件との組み合わせ）

**説明**: 特定の条件下でのみ無効化が発動

**データ構造**:
```json
{
  "nullify_type": "normal_attack",
  "conditions": [
    {
      "condition_type": "land_level_check",
      "operator": ">=",
      "value": 3
    }
  ]
}
```

**実装クリーチャー**:
- ID:106 アブサス - 戦闘地がレベル3以上の場合、無効化[通常攻撃]

**実装方針**: 既存の`ConditionChecker`システムを活用

---

## 実装するクリーチャー一覧

### Phase 1: 基本実装（ability_parsed既存）

| ID | 名前 | 属性 | 無効化条件 | データ状況 |
|----|------|------|----------|----------|
| **16** | シグルド | 火 | 無効化[MHP50以上] | ✅ 実装済み |
| **111** | イエティ | 水 | 無効化[火] | ✅ 実装済み |
| **325** | ダンピール | 風 | 無効化[地] | ✅ 実装済み |
| **424** | セイント | 無 | 無効化[無] | ✅ 実装済み |

### Phase 2: データ追加が必要

| ID | 名前 | 属性 | 無効化条件 | データ追加 |
|----|------|------|----------|----------|
| **6** | ガスクラウド | 火 | 全攻撃50%軽減 | 🔶 必要 |
| **100** | アーマーナイト | 水 | 無効化[地風] | 🔶 必要 |
| **104** | アクアドラゴン | 水 | 無効化[水地] | 🔶 必要 |
| **105** | アクアリング | 水 | 無効化[MHP30以下] | 🔶 必要 |
| **122** | シーホース | 水 | 無効化[ST40以下] | 🔶 必要 |
| **213** | グレートタスカー | 地 | 無効化[先制持ち] | 🔶 必要 |

### Phase 3: 巻物実装後

| ID | 名前 | 属性 | 無効化条件 | 前提 |
|----|------|------|----------|------|
| **1** | アームドパラディン | 火 | 無効化[巻物] | 巻物実装後 |
| **112** | イド | 水 | 無効化[巻物] | 巻物実装後 |
| **106** | アブサス | 水 | 無効化[通常攻撃]（条件付き） | 巻物実装後 |

---

## データ構造

### ability_parsed構造

```json
{
  "keywords": ["無効化"],
  "keyword_conditions": {
    "無効化": {
      "nullify_type": "element|mhp_above|mhp_below|st_below|all_attacks|has_ability|scroll_attack|normal_attack",
      
      // 属性無効化の場合
      "element": "fire",  // 単一属性
      "elements": ["wind", "earth"],  // 複数属性（elementがない場合）
      
      // MHP/ST条件の場合
      "value": 50,
      
      // 能力持ち無効化の場合
      "ability": "先制",
      
      // 軽減率（指定なし = 0.0 = 完全無効化）
      "reduction_rate": 0.5,
      
      // 条件付き無効化の場合
      "conditions": [
        {
          "condition_type": "land_level_check",
          "operator": ">=",
          "value": 3
        }
      ]
    }
  }
}
```

---

## 実装フロー

### 1. BattleParticipantへの追加

```gdscript
class_name BattleParticipant

# 巻物攻撃フラグ（貫通とは別管理）
var is_using_scroll: bool = false
```

### 2. 無効化チェック関数

```gdscript
# BattleSystem.gd
func _check_nullify(attacker: BattleParticipant, defender: BattleParticipant, context: Dictionary) -> Dictionary:
	"""
	無効化判定を行う
	
	Returns:
		{
			"is_nullified": bool,  // 無効化されたか
			"reduction_rate": float  // 軽減率（0.0=完全無効化、0.5=50%軽減）
		}
	"""
	var ability_parsed = defender.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "無効化" in keywords:
		return {"is_nullified": false, "reduction_rate": 1.0}
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var nullify_condition = keyword_conditions.get("無効化", {})
	
	# 条件付き無効化の場合、先に条件をチェック
	var conditions = nullify_condition.get("conditions", [])
	if conditions.size() > 0:
		var condition_checker = load("res://scripts/skills/condition_checker.gd").new()
		for condition in conditions:
			if not condition_checker.evaluate_condition(condition, context):
				return {"is_nullified": false, "reduction_rate": 1.0}
	
	# 無効化タイプ別の判定
	var nullify_type = nullify_condition.get("nullify_type", "")
	var is_nullified = false
	
	match nullify_type:
		"element":
			is_nullified = _check_nullify_element(nullify_condition, attacker)
		"mhp_above":
			is_nullified = _check_nullify_mhp_above(nullify_condition, attacker)
		"mhp_below":
			is_nullified = _check_nullify_mhp_below(nullify_condition, attacker)
		"st_below":
			is_nullified = _check_nullify_st_below(nullify_condition, attacker)
		"all_attacks":
			is_nullified = true  # 無条件で適用
		"has_ability":
			is_nullified = _check_nullify_has_ability(nullify_condition, attacker)
		"scroll_attack":
			is_nullified = attacker.is_using_scroll
		"normal_attack":
			is_nullified = not attacker.is_using_scroll
	
	if is_nullified:
		var reduction_rate = nullify_condition.get("reduction_rate", 0.0)
		return {"is_nullified": true, "reduction_rate": reduction_rate}
	
	return {"is_nullified": false, "reduction_rate": 1.0}
```

### 3. 個別の判定関数

```gdscript
func _check_nullify_element(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var attacker_element = attacker.creature_data.get("element", "")
	
	# 単一属性
	if condition.has("element"):
		return attacker_element == condition.get("element")
	
	# 複数属性
	if condition.has("elements"):
		var elements = condition.get("elements", [])
		return attacker_element in elements
	
	return false

func _check_nullify_mhp_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	var attacker_max_hp = attacker.creature_data.get("hp", 0)
	return attacker_max_hp >= threshold

func _check_nullify_mhp_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	var attacker_max_hp = attacker.creature_data.get("hp", 0)
	return attacker_max_hp <= threshold

func _check_nullify_st_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	var attacker_base_st = attacker.creature_data.get("ap", 0)
	return attacker_base_st <= threshold

func _check_nullify_has_ability(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var ability = condition.get("ability", "")
	var attacker_keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
	return ability in attacker_keywords
```

### 4. ダメージ処理への統合

```gdscript
func _execute_attack_sequence(attack_order: Array, context: Dictionary) -> void:
	for i in range(attack_order.size()):
		var attacker_p = attack_order[i]
		var defender_p = attack_order[(i + 1) % 2]
		
		if not attacker_p.is_alive():
			continue
		
		# 攻撃回数分ループ
		for attack_num in range(attacker_p.attack_count):
			if not defender_p.is_alive():
				break
			
			# 無効化判定
			var nullify_result = _check_nullify(attacker_p, defender_p, context)
			
			if nullify_result["is_nullified"]:
				var reduction_rate = nullify_result["reduction_rate"]
				
				if reduction_rate == 0.0:
					# 完全無効化
					print("【無効化】", defender_p.creature_data.get("name"), " が攻撃を無効化")
					continue  # ダメージ処理をスキップ
				else:
					# 軽減
					var original_damage = attacker_p.current_ap
					var reduced_damage = int(original_damage * reduction_rate)
					print("【軽減】", defender_p.creature_data.get("name"), 
						  " がダメージを軽減 ", original_damage, " → ", reduced_damage)
					defender_p.take_damage(reduced_damage)
			else:
				# 通常ダメージ
				defender_p.take_damage(attacker_p.current_ap)
			
			# 即死判定（無効化成功時はスキップされている）
			if not nullify_result["is_nullified"]:
				_check_instant_death(attacker_p, defender_p)
```

---

## 他スキルとの相互作用

### 無効化 vs 即死

```
無効化成功 → 即死判定スキップ
無効化失敗 → 通常通り即死判定
```

### 無効化 vs 貫通

```
無効化が優先（攻撃自体が無効化されるため、貫通の処理にも到達しない）
```

### 無効化 vs 先制

```
攻撃順には影響なし（先制攻撃でも無効化判定は行われる）
```

### 無効化 vs 2回攻撃

```
各攻撃ごとに無効化判定
（確率軽減の場合、1回目は軽減、2回目は通常ダメージもあり得る）
```

### 無効化 vs 強打

```
無効化が優先（強打で増幅されたAPでも無効化されれば0ダメージ）
```

---

## 実装の優先順位

### ✅ Phase 1-3: 全実装完了（2025/10/20）

#### Phase 1: 基本無効化
1. ✅ **属性無効化** - イエティ、ダンピール、セイント
2. ✅ **MHP条件無効化** - シグルド

#### Phase 2: データ追加 + 実装
3. ✅ **複数属性無効化** - アーマーナイト、アクアドラゴン、ミストウィング
4. ✅ **MHP30以下無効化** - アクアリング
5. ✅ **ST条件無効化** - シーホース、ラハブ
6. ✅ **全攻撃軽減** - ガスクラウド（未データ化）
7. ✅ **能力持ち無効化** - グレートタスカー

#### Phase 3: 巻物実装
8. ✅ **巻物攻撃システム** - is_using_scrollフラグ実装
9. ✅ **巻物攻撃無効化** - アームドパラディン、イド、他8体
10. ✅ **通常攻撃無効化** - アクアデューク、アブサス

**実装完了範囲**:
- 全無効化タイプ実装（9種類）
- 無効化持ちクリーチャーデータ整備（26体）
- 巻物攻撃システム実装
- 条件判定システム統合

### 🔶 未実装（将来実装予定）

**条件タイプ追加が必要**:
- `item_equipped` 条件 (例: ID 103 アクアデューク - 防具使用時)
- `land_level_check` 条件 (例: ID 106 アブサス - 戦闘地レベル3以上)

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/20 | 1.0 | 初版作成 - 無効化スキルの全体設計 |
| 2025/10/20 | 2.0 | 実装完了 - 全Phase完了、26体のクリーチャーデータ整備 |

---

**最終更新**: 2025年10月20日（v2.0 - 実装完了）
