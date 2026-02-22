# 2回攻撃スキル

**バージョン**: 1.0  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [概要](#概要)
2. [発動条件](#発動条件)
3. [効果](#効果)
4. [攻撃順序](#攻撃順序)
5. [実装クリーチャー](#実装クリーチャー)
6. [データ構造](#データ構造)
7. [実装詳細](#実装詳細)
8. [使用例](#使用例)
9. [設計思想](#設計思想)
10. [相乗効果](#相乗効果)

---

## 概要

1回のバトルで2回連続攻撃を行うパッシブスキル。

---

## 発動条件

- 無条件発動（生き残っていれば2回攻撃）
- 各攻撃後に相手の生存確認（倒されていたら次の攻撃はなし）

---

## 効果

- 同じ相手に対して2回連続攻撃
- 各攻撃で最終計算後のAPを使用（共鳴・強化・アイテム・スペル等すべて適用後）
- 相手の反撃は2回攻撃が完了してから

---

## 攻撃順序

### 通常の場合
```
1. 攻撃側の1回目の攻撃
2. 攻撃側の2回目の攻撃（相手が生存していれば）
3. 防御側の反撃
```

### 先制+2回攻撃の場合
```
1. 先制攻撃側の1回目の攻撃
2. 先制攻撃側の2回目の攻撃
3. 相手の反撃
```

---

## 実装クリーチャー

### 実装済み（1体）

| ID | 名前 | 属性 | AP | HP |
|----|------|------|----|----|
| 325 | テトラーム | 風 | 20 | 30 |

---

## データ構造

```json
{
  "ability_parsed": {
	"keywords": ["2回攻撃"]
  }
}
```

---

## 実装詳細

### BattleParticipantクラス
```gdscript
var attack_count: int = 1  # デフォルト1回、2回攻撃なら2
```

### スキル判定
```gdscript
func _check_double_attack(participant: BattleParticipant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "2回攻撃" in keywords:
		participant.attack_count = 2
		print("【2回攻撃】", participant.creature_data.get("name", "?"), " 攻撃回数: 2回")
```

### 攻撃シーケンス
```gdscript
func _execute_attack_sequence(attack_order: Array) -> void:
	for i in range(attack_order.size()):
		var attacker_p = attack_order[i]
		var defender_p = attack_order[(i + 1) % 2]
		
		if not attacker_p.is_alive():
			continue
		
		# 攻撃回数分ループ
		for attack_num in range(attacker_p.attack_count):
			# 既に倒されていたら攻撃しない
			if not defender_p.is_alive():
				break
			
			# ダメージ処理
			defender_p.take_damage(attacker_p.current_ap)
```

---

## 使用例

### バトルフロー
```
侵略側: テトラーム AP:20 HP:30 (2回攻撃)
防御側: フェニックス AP:40 HP:30

【第1攻撃 - 1回目】侵略側の攻撃
  テトラーム AP:20 → フェニックス
  ダメージ処理:
	- 基本HP: 20 消費
  → 残HP: 10 (基本HP:10)

【第1攻撃 - 2回目】侵略側の攻撃
  テトラーム AP:20 → フェニックス
  ダメージ処理:
	- 基本HP: 10 消費
  → 残HP: 0 (基本HP:0)
  → フェニックス 撃破！

【結果】侵略成功（フェニックスは反撃できず）
```

---

## 設計思想

- **拡張性**: `attack_count`を使用することで、将来的に3回攻撃以上も対応可能
- **アイテム/スペル対応**: アイテムやスペルで`attack_count`を増やす実装が容易
- **効率的な実装**: ループ構造により、攻撃回数に関わらず同じコードで対応
- **早期終了**: 相手が倒されたら即座に攻撃を中止し、無駄な処理を省く

---

## 相乗効果

### 共鳴+2回攻撃
```
基本AP: 20
  ↓ 共鳴[火]+30
AP: 50
  ↓ 2回攻撃
合計ダメージ: 50 × 2 = 100
```

### 共鳴+強化+2回攻撃
```
基本AP: 20
  ↓ 共鳴[火]+30
AP: 50
  ↓ 強化×1.5
AP: 75
  ↓ 2回攻撃
合計ダメージ: 75 × 2 = 150
```

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/24 | 1.0 | 個別ドキュメントとして分離 |
