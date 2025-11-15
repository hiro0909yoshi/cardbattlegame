# アイテム破壊・盗みスキル設計書

**バージョン**: 1.0  
**作成日**: 2025年10月25日  
**最終更新**: 2025年10月25日

---

## 📋 目次

1. [概要](#概要)
2. [実装状況](#実装状況)
3. [発動タイミング](#発動タイミング)
4. [アイテム破壊スキル](#アイテム破壊スキル)
5. [アイテム盗みスキル](#アイテム盗みスキル)
6. [アイテム破壊・盗み無効スキル](#アイテム破壊盗み無効スキル)
7. [処理フロー](#処理フロー)
8. [戦略的価値](#戦略的価値)
9. [実装時の注意点](#実装時の注意点)

---

## 概要

戦闘開始前に相手のアイテムを破壊または奪うスキル。アイテムに依存する戦略を無効化できる強力な妨害スキル。

**特徴:**
- 戦闘ダメージ計算の前に発動
- アイテム依存戦略への強力なカウンター
- 破壊・盗み・無効化の3種類が存在


**前提条件:**
- アイテムシステムの実装
- 援護スキルシステムの実装（援護クリーチャー破壊のため）

---

## 発動タイミング

### タイミング
**戦闘開始前** - ダメージ計算の前

### 行動順の決定
- 先制攻撃の順序判定に従って発動順を決定
- 両者がアイテム破壊/盗みを持つ場合、**先に動く側が優先**

---

## アイテム破壊スキル

### 概要
相手のアイテムを破壊（消滅）させる。相手は今回の戦闘でアイテムなしで戦う。

### 破壊対象の種類

| 表記 | 破壊対象 |
|------|---------|
| アイテム破壊[道具] | 道具タイプのアイテムのみ |
| アイテム破壊[道具か巻物か援護クリーチャー] | 道具、巻物、援護クリーチャーのいずれか |

**注意**: 援護クリーチャーは援護スキルで装備されたクリーチャー

### 実装クリーチャー（3体）

| ID | 名前 | 属性 | AP/HP | スキル | 破壊対象 |
|----|------|------|-------|--------|---------|
| 313 | グレムリン | 風 | 20/30 | アイテム破壊[道具] | 道具のみ |
| 116 | カイザーペンギン | 水 | 30/50 | アイテム破壊[道具か巻物か援護クリーチャー] | 道具・巻物・援護 |
| 220 | シルバンダッチェス | 地 | 50/50 | 援護[地]；アイテム破壊[道具か巻物か援護クリーチャー]；再生 | 道具・巻物・援護 |

### データ構造

#### アイテム破壊[道具]

```json
{
  "id": 313,
  "name": "グレムリン",
  "ability": "アイテム破壊",
  "ability_detail": "アイテム破壊[道具]",
  "ability_parsed": {
	"keywords": ["アイテム破壊"],
	"effects": [
	  {
		"effect_type": "destroy_item",
		"target_types": ["道具"],
		"triggers": ["before_battle"]
	  }
	]
  }
}
```

#### アイテム破壊[道具か巻物か援護クリーチャー]

```json
{
  "id": 116,
  "name": "カイザーペンギン",
  "ability": "アイテム破壊",
  "ability_detail": "アイテム破壊[道具か巻物か援護クリーチャー]",
  "ability_parsed": {
	"keywords": ["アイテム破壊"],
	"effects": [
	  {
		"effect_type": "destroy_item",
		"target_types": ["道具", "巻物", "援護クリーチャー"],
		"triggers": ["before_battle"]
	  }
	]
  }
}
```

### 効果

1. 相手のアイテムタイプをチェック
2. 破壊対象に一致するか確認
3. 一致する場合、相手のアイテムを破壊（消滅）
4. 相手のアイテム効果を無効化

---

## アイテム盗みスキル

### 概要
相手のアイテムを奪って自分が使用する。**自分がアイテムを使用していない場合のみ発動可能**。

### 発動条件

1. ✅ 自分がアイテムを使用していない
2. ✅ 相手がアイテムを使用している

### 効果

- 相手のアイテムを奪う
- 奪ったアイテムの効果を自分が得る（ST/HPボーナス、スキルなど）
- 相手はアイテムなしで戦う

### 実装クリーチャー（1体）

| ID | 名前 | 属性 | AP/HP | スキル |
|----|------|------|-------|--------|
| 416 | シーフ | 無 | 20/40 | アイテム盗み |

### データ構造

```json
{
  "id": 416,
  "name": "シーフ",
  "ability": "アイテム盗み",
  "ability_detail": "アイテム盗み",
  "ability_parsed": {
	"keywords": ["アイテム盗み"],
	"effects": [
	  {
		"effect_type": "steal_item",
		"triggers": ["before_battle"],
		"conditions": [
		  {
			"condition_type": "self_no_item"
		  }
		]
	  }
	]
  }
}
```

---

## アイテム破壊・盗み無効スキル

### 概要
相手のアイテム破壊・盗みスキルを無効化する。

### 実装クリーチャー（1体）

| ID | 名前 | 属性 | AP/HP | スキル |
|----|------|------|-------|--------|
| 226 | セージ | 地 | 20/30 | 援護；アイテム破壊・盗み無効；巻物強打 |

### データ構造

```json
{
  "id": 226,
  "name": "セージ",
  "ability": "アイテム破壊・盗み無効",
  "ability_detail": "援護；アイテム破壊・盗み無効；巻物強打",
  "ability_parsed": {
	"keywords": ["援護", "巻物強打"],
	"effects": [
	  {
		"effect_type": "nullify_item_manipulation",
		"triggers": ["before_battle"]
	  }
	],
	"keyword_conditions": {
	  "巻物強打": {
		"scroll_type": "base_ap"
	  }
	}
  }
}
```

---

## 処理フロー

```
1. 戦闘開始前処理
   │
2. 先制攻撃の順序で行動順を決定
   │
3. 先に動く側のアイテム破壊・盗みチェック
   ├─ 相手が「アイテム破壊・盗み無効」を持つ → スキップ
   ├─ アイテム破壊の場合 → 4-Aへ
   └─ アイテム盗みの場合 → 4-Bへ
   │
4-A. アイテム破壊処理
   ├─ 相手のアイテムタイプをチェック
   ├─ 破壊対象に一致するか確認
   ├─ 一致する場合、相手のアイテムを破壊（消滅）
   └─ 相手のアイテム効果を無効化
   │
4-B. アイテム盗み処理
   ├─ 自分がアイテムを使用していないか確認
   │  └─ 使用している → スキップ
   ├─ 相手のアイテムを奪う
   ├─ 奪ったアイテムの効果を自分に適用
   └─ 相手のアイテム効果を無効化
   │
5. 後に動く側のアイテム破壊・盗みチェック（同様）
   │
6. ダメージ計算開始
```

### 実装イメージ

```gdscript
# 戦闘開始前処理
func _handle_pre_battle_skills(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	# 行動順を決定（先制スキルなどを考慮）
	var first_mover = _determine_first_mover(attacker, defender)
	var second_mover = attacker if first_mover == defender else defender
	
	# 先に動く側の処理
	_process_item_manipulation(first_mover, second_mover)
	
	# 後に動く側の処理
	_process_item_manipulation(second_mover, first_mover)

func _process_item_manipulation(actor: BattleParticipant, target: BattleParticipant) -> void:
	var ability_parsed = actor.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 相手が無効化を持つかチェック
	if _has_item_manipulation_nullify(target):
		print("【アイテム破壊・盗み無効】", target.creature_data.get("name"))
		return
	
	# アイテム破壊
	if "アイテム破壊" in keywords:
		_handle_item_destruction(actor, target)
	
	# アイテム盗み
	if "アイテム盗み" in keywords:
		_handle_item_theft(actor, target)

func _handle_item_destruction(actor: BattleParticipant, target: BattleParticipant) -> void:
	var effects = actor.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_item":
			var target_types = effect.get("target_types", [])
			var target_item = target.get_equipped_item()
			
			if target_item and target_item.get("type") in target_types:
				print("【アイテム破壊】", actor.creature_data.get("name"), 
					  " → ", target_item.get("name"), " を破壊")
				target.remove_item()

func _handle_item_theft(actor: BattleParticipant, target: BattleParticipant) -> void:
	# 自分がアイテムを持っている場合はスキップ
	if actor.has_item():
		return
	
	var target_item = target.get_equipped_item()
	if target_item:
		print("【アイテム盗み】", actor.creature_data.get("name"), 
			  " → ", target_item.get("name"), " を奪った")
		
		# アイテムを移動
		target.remove_item()
		actor.equip_item(target_item)

func _has_item_manipulation_nullify(participant: BattleParticipant) -> bool:
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "nullify_item_manipulation":
			return true
	
	return false
```

---

## 戦略的価値

### 破壊スキルの強み

1. **アイテム依存戦略の破壊**
   - スパイクシールド、メイガスミラーなどの強力アイテムを無効化
   - アイテムコンボ戦略を崩せる

2. **コスト効率**
   - 低コストクリーチャー（グレムリン20/30、シーフ20/40）で高価なアイテムを無効化できる
   - コスト200のアイテムを20コストで無効化可能

### 盗みスキルの強み

1. **二重効果**
   - 相手のアイテムを奪って自分が使うため、戦力差が大きく開く
   - 例：相手のHP+30アイテムを奪う → 実質HP差60

2. **条件付き発動**
   - 自分がアイテムなしの場合のみ発動
   - リスク管理が重要

### メタ対策

- **セージによる無効化**: 破壊・盗み戦略を完全に封じる
- 援護スキルとの組み合わせで防御力も確保

---

## 実装時の注意点

### 1. 援護クリーチャーの扱い

**前提**: 援護スキル実装後に対応

```json
{
  "target_types": ["道具", "巻物", "援護クリーチャー"]
}
```

援護クリーチャーが装備扱いになる場合、アイテム破壊の対象に含める。

### 2. 複数アイテムの扱い

**現状**: プレイヤーは1個のみアイテムを持つ仕様

**将来拡張の考慮**:
- 複数アイテム対応時は、破壊対象の選択ロジックが必要
- ランダム破壊 or 優先度付き破壊

### 3. 盗んだアイテムの管理

**BattleParticipantのitem配列操作**:

```gdscript
# アイテムを移動
target.remove_item()
actor.equip_item(target_item)
```

アイテム効果（ST/HPボーナス、スキルなど）も一緒に移動する。

### 4. 無効化の優先順位

**before_battleフェーズでの処理**:
1. 行動順決定
2. 先攻側の破壊・盗み処理
3. 後攻側の破壊・盗み処理
4. ダメージ計算開始

反射無効と同様、戦闘前に完全に処理を終える。

### 5. ログ表示

```
【アイテム破壊】グレムリン → スパイクシールド を破壊
【アイテム盗み】シーフ → メイガスミラー を奪った
【アイテム破壊・盗み無効】セージがアイテム操作を防いだ
```

ユーザーに分かりやすいログを表示。

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/25 | 1.0 | 初版作成 - skills_design.mdから分離 |

---

**関連ドキュメント**:
- [`docs/design/skills_design.md`](../skills_design.md) - スキル全体設計
- [`docs/design/skills/nullify_skill.md`](nullify_skill.md) - 無効化スキル
- [`docs/design/skills/support_skill.md`](support_skill.md) - 援護スキル（未作成）

---

**最終更新**: 2025年10月25日（v1.0）
