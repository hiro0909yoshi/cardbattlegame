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

### 実装アイテム（1個）

| ID | 名前 | タイプ | コスト | 効果 |
|----|------|--------|--------|------|
| 1001 | エンジェルケープ | 防具 | 40 | HP+20；アイテム破壊・盗み無効 |

### データ構造

#### クリーチャー（セージ）

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

#### アイテム（エンジェルケープ）

```json
{
  "id": 1001,
  "name": "エンジェルケープ",
  "type": "item",
  "item_type": "防具",
  "cost": { "mp": 40 },
  "effect": "HP+20；アイテム破壊・盗み無効",
  "effect_parsed": {
    "stat_bonus": { "hp": 20 },
    "effects": [
      {
        "effect_type": "nullify_item_manipulation"
      }
    ]
  }
}
```

### 判定処理

アイテム破壊・盗み無効の判定は、**クリーチャー能力とアイテム両方**をチェックする：

```gdscript
static func _has_nullify_item_manipulation(participant) -> bool:
    # クリーチャー能力をチェック
    var ability_parsed = participant.creature_data.get("ability_parsed", {})
    var effects = ability_parsed.get("effects", [])
    for effect in effects:
        if effect.get("effect_type") == "nullify_item_manipulation":
            return true
    
    # アイテム効果をチェック（エンジェルケープ等）
    var items = participant.creature_data.get("items", [])
    for item in items:
        var item_effect_parsed = item.get("effect_parsed", {})
        var item_effects = item_effect_parsed.get("effects", [])
        for item_effect in item_effects:
            if item_effect.get("effect_type") == "nullify_item_manipulation":
                return true
    
    return false
```

**重要**: アイテム効果は通常Phase 0-Sで適用されるが、`nullify_item_manipulation`は**アイテム破壊・盗み処理時に直接`items`配列からチェック**する。これにより、エンジェルケープ装備時にアイテム破壊を防げる。

---

## 処理フロー

```
1. バトル準備（prepare_participants）
   ├─ BattleParticipant作成
   ├─ アイテムをitemsに追加（効果はまだ適用しない）
   └─ 呪いはapply_pre_battle_skillsで適用
   │
2. バトル画面セットアップ（start_battle）
   │
3. バトル前スキル処理（apply_pre_battle_skills）開始
   │
4. 【Phase 0-C】呪い適用
   └─ ステータス変更系呪いをエフェクト表示付きで適用
   │
5. 【Phase 0-N】能力無効化チェック
   ├─ ウォーロックディスク → 「アイテム名 を使用」表示
   ├─ skill_nullify呪い/クリーチャー能力 → 「戦闘中能力無効」表示
   ├─ 無効化あり → アイテムステータスのみ適用してreturn
   └─ 無効化なし → 続行
   │
6. 【Phase 0-D】アイテム破壊・盗み
   ├─ 素の先制（クリーチャー能力のみ）で行動順を決定
   ├─ 先に動く側のアイテム破壊・盗みチェック
   │   ├─ 相手が「アイテム破壊・盗み無効」を持つ → スキップ
   │   │   └─ クリーチャー能力とアイテム（エンジェルケープ等）両方をチェック
   │   ├─ アイテム破壊の場合 → 対象アイテムを削除
   │   └─ アイテム盗みの場合 → アイテムを移動
   └─ 後に動く側のアイテム破壊・盗みチェック（同様）
   │
7. 【Phase 0-T】変身スキル適用（クリーチャー能力）
   │
8. 【Phase 0-S】アイテム効果適用（破壊後に残ったアイテムのみ）
   ├─ ステータスボーナス（AP/HP）を適用
   ├─ スキル付与（先制など）を適用
   └─ バトル画面にアイテム名とステータス変化を表示
   │
9. 【Phase 0-T2】アイテムによる変身スキル適用（ドラゴンオーブ等）
   │
10. 各種スキル処理（ブルガサリ、感応、強打、先制判定など）
    │
11. ダメージ計算開始
```

### 重要な処理順序のポイント

1. **能力無効化は最優先**: ウォーロックディスク等が発動すると、アイテム破壊スキルも無効化される
2. **アイテム破壊・盗みは変身前**: 破壊後に残ったアイテムのみ効果適用
3. **アイテム破壊・盗み無効の判定**: クリーチャー能力だけでなく、アイテム（エンジェルケープ等）からも直接チェック

### 実装イメージ

```gdscript
# バトル準備（battle_preparation.gd）
func prepare_participants(...) -> Dictionary:
	# ...BattleParticipant作成...
	
	# アイテムをitemsに追加（効果はまだ適用しない）
	if not attacker_item.is_empty():
		attacker.creature_data["items"] = [attacker_item]
	if not defender_item.is_empty():
		defender.creature_data["items"] = [defender_item]
	
	return { "attacker": attacker, "defender": defender, ... }

# アイテム効果適用（アイテム破壊・盗み後に呼び出す）
func apply_remaining_item_effects(attacker, defender, battle_tile_index) -> void:
	var attacker_items = attacker.creature_data.get("items", [])
	if not attacker_items.is_empty():
		item_applier.apply_item_effects(attacker, attacker_items[0], defender, battle_tile_index)
	
	var defender_items = defender.creature_data.get("items", [])
	if not defender_items.is_empty():
		item_applier.apply_item_effects(defender, defender_items[0], attacker, battle_tile_index)


# バトル前スキル処理（battle_skill_processor.gd）
func apply_pre_battle_skills(participants, tile_info, attacker_index) -> Dictionary:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# 【Phase 0-C】呪い適用
	await _apply_curse_effects(attacker, defender, battle_tile_index)
	
	# 【Phase 0-N】能力無効化チェック
	var has_nullify = _has_warlock_disk(attacker) or _has_warlock_disk(defender) \
		or _has_skill_nullify_curse(attacker) or _has_skill_nullify_curse(defender) \
		or _has_nullify_creature_ability(attacker) or _has_nullify_creature_ability(defender)
	
	if has_nullify:
		# ウォーロックディスクは「アイテム名 を使用」表示
		# それ以外は「戦闘中能力無効」表示
		# アイテムステータスのみ適用してreturn
		battle_preparation_ref.apply_remaining_item_effects(attacker, defender, battle_tile_index, true)
		return result
	
	# 【Phase 0-D】素の先制（クリーチャー能力のみ）で順序決定
	var first = attacker
	var second = defender
	if _has_raw_first_strike(defender) and not _has_raw_first_strike(attacker):
		first = defender
		second = attacker
	
	# アイテム破壊・盗み実行
	await apply_item_manipulation(first, second)
	
	# 【Phase 0-T】変身スキル適用
	result["transform_result"] = TransformSkill.process_transform_effects(...)
	
	# 【Phase 0-S】アイテム効果適用（破壊後に残ったアイテムのみ、ステータス＋スキル両方）
	battle_preparation_ref.apply_remaining_item_effects(attacker, defender, battle_tile_index)
	
	# バトル画面にアイテム効果を表示
	await _show_item_effect_if_any(attacker, attacker_before_item, "attacker")
	await _show_item_effect_if_any(defender, defender_before_item, "defender")
	
	# 【Phase 0-T2】アイテムによる変身スキル適用
	# 以下、各種スキル処理...


# アイテム破壊・盗み処理（skill_item_manipulation.gd）
static func _execute_destroy_item(actor, target, effect: Dictionary) -> bool:
	# ...対象チェック...
	
	# アイテムを削除（効果はまだ適用されていないので、削除するだけでOK）
	target.creature_data["items"] = []
	return true

static func _execute_steal_item(actor, target, _effect: Dictionary) -> bool:
	# ...条件チェック...
	
	# 対象からアイテムを削除（効果はまだ適用されていない）
	target.creature_data["items"] = []
	
	# 自分にアイテムを追加（効果の適用はapply_remaining_item_effectsで行う）
	actor.creature_data["items"] = [stolen_item]
	return true
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
| 2025/12/23 | 1.1 | 処理フロー更新 - アイテム効果適用をアイテム破壊後に変更 |
| 2025/12/25 | 2.0 | 処理フロー大幅更新 - 呪い適用→能力無効化→アイテム破壊・盗み→変身→アイテム効果適用の順序に変更 |
|            |     | エンジェルケープ追加 - アイテムからの直接判定を実装 |
|            |     | ウォーロックディスクの表示を「アイテム名 を使用」に変更 |

---

**関連ドキュメント**:
- [`docs/design/skills_design.md`](../skills_design.md) - スキル全体設計
- [`docs/design/skills/nullify_skill.md`](nullify_skill.md) - 無効化スキル
- [`docs/design/skills/support_skill.md`](support_skill.md) - 援護スキル（未作成）

---

**最終更新**: 2025年12月25日（v2.0）
