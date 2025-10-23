# 感応スキル

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.5  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [概要](#概要)
2. [発動条件](#発動条件)
3. [効果パターン](#効果パターン)
4. [実装済みクリーチャー](#実装済みクリーチャー)
5. [HPの扱い](#hpの扱い)
6. [強打との相乗効果](#強打との相乗効果)
7. [適用タイミング](#適用タイミング)
8. [実装コード例](#実装コード例)

---

## 概要

特定属性の土地を1つでも所有していれば、APやHPが上昇するパッシブスキル。

---

## 発動条件

- 指定された属性の土地を **1つ以上所有**
- 土地のレベルや数は不問（無条件発動）
- バトル発生時に自動判定

---

## 効果パターン

### パターン1: ST&HP+X

APとHPが同時上昇する

```json
{
  "感応": {
	"element": "fire",
	"stat_bonus": {
	  "ap": 20,
	  "hp": 20
	}
  }
}
```

### パターン2: ST+X、HP+Y

APとHPが個別に上昇する

```json
{
  "感応": {
	"element": "water",
	"stat_bonus": {
	  "ap": 10,
	  "hp": 20
	}
  }
}
```

---

## 実装済みクリーチャー

感応スキルを持つクリーチャーは全部で **9体** います。

| クリーチャー名 | 属性 | 必要土地 | 効果 |
|--------------|------|---------|------|
| アモン | 火 | [地] | ST&HP+20 |
| ムシュフシュ | 火 | [地] | ST+20、HP+10 |
| オドントティラヌス | 水 | [風] | ST+20、HP+10 |
| ゴーストシップ | 水 | [風] | HP+30 |
| キリン | 風 | [水] | ST&HP+20 |
| クー・シー | 風 | [水] | ST+10、HP+20 |
| クフ | 風 | [水] | ST+30 |
| グロウホーン | 地 | [火] | ST&HP+20 |
| モルモ | 地 | [火] | ST+30 |

---

## HPの扱い

### 格納場所

感応ボーナスHPは `BattleParticipant.resonance_bonus_hp` に格納されます。

```gdscript
# 感応ボーナス適用
participant.resonance_bonus_hp += 30
participant.update_current_hp()

# 表示HP = 基本HP + 感応HP + 土地HP + ...
# 例: 30 + 30 + 20 = 80
```

### ダメージ消費順序

感応ボーナスHPは **最優先で消費** されます。

詳細は[BattleParticipantとHP管理](../skills_design.md#battleparticipantとhp管理)を参照してください。

---

## 強打との相乗効果

感応でAPが上昇した後、強打スキルが適用されるため、相乗効果が得られます。

```
基本AP: 20
  ↓ 感応[火]+30
AP: 50
  ↓ 強打×1.5
AP: 75
```

これにより、感応と強打の両方を持つクリーチャーは大幅な火力強化が可能です。

---

## 適用タイミング

- **関数**: `BattleSystem._apply_resonance_skill()`
- **タイミング**: バトル準備段階（`_apply_pre_battle_skills()`内）
- **判定**: プレイヤーの土地所有状況を`board_system.get_player_lands_by_element()`で取得

### 適用順序

感応スキルは以下の順序でバトルフローに組み込まれます：

```
1. 応援スキル適用
2. 巻物攻撃判定
3. 感応スキル適用 ← ここ
4. 土地数比例効果
5. 強打スキル（感応適用後のAPを基準に計算）
6. 2回攻撃判定
7. 攻撃シーケンス実行
```

---

## 実装コード例

```gdscript
func _apply_resonance_skill(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "感応" in keywords:
		return
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var resonance_condition = keyword_conditions.get("感応", {})
	
	var required_element = resonance_condition.get("element", "")
	var player_lands = context.get("player_lands", {})
	var owned_count = player_lands.get(required_element, 0)
	
	if owned_count > 0:
		var stat_bonus = resonance_condition.get("stat_bonus", {})
		var ap_bonus = stat_bonus.get("ap", 0)
		var hp_bonus = stat_bonus.get("hp", 0)
		
		if ap_bonus > 0:
			participant.current_ap += ap_bonus
		
		if hp_bonus > 0:
			participant.resonance_bonus_hp += hp_bonus
			participant.update_current_hp()
```

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.5 | 2025/10/24 | 個別ドキュメントとして分離 |
