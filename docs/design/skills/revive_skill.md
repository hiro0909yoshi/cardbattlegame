# 死者復活スキル

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [概要](#概要)
2. [発動タイミング](#発動タイミング)
3. [復活タイプ](#復活タイプ)
4. [条件システム](#条件システム)
5. [ステータス処理](#ステータス処理)
6. [戦闘結果への影響](#戦闘結果への影響)
7. [実装クリーチャー](#実装クリーチャー)
8. [データ構造](#データ構造)
9. [他スキルとの相互作用](#他スキルとの相互作用)
10. [実装コード](#実装コード)
11. [使用例](#使用例)
12. [設計思想](#設計思想)

---

## 概要

クリーチャーが撃破されたとき、別のクリーチャーに変身して戦闘を継続する防御的スキル。

**最大の特徴**: 
- タイルを守り抜く最終防衛手段
- 復活後は**永続変身**（交換してもそのクリーチャーのまま）
- 「ある意味無敵」のスキル

---

## 発動タイミング

### on_death（撃破時）

- **タイミング**: クリーチャーのHPが0以下になった瞬間
- **発動条件**: 条件を満たしている場合のみ
- **効果**: 別のクリーチャーとして復活し、戦闘継続

**重要**: 
- 即死スキルで撃破された場合も発動
- 復活後のクリーチャーで反撃できる

---

## 復活タイプ

### 1. 強制復活 (`forced`)

無条件で指定されたクリーチャーに復活

```json
{
  "revive_type": "forced",
  "creature_id": 420
}
```

**特徴**:
- 条件チェックなし、必ず発動
- 復活先が固定
- 確実性が高い

**用途**: 
- ヘルグラマイト → サーペントフライ
- グレートフォシル → ティラノサウルス

---

### 2. 条件付き復活 (`conditional`)

特定条件を満たしたときのみ復活

```json
{
  "revive_type": "conditional",
  "creature_id": 438,
  "condition": {
	"type": "enemy_item_not_used",
	"item_category": "武器"
  }
}
```

**特徴**:
- 条件を満たさないと不発
- 戦略性が高い
- カウンタープレイが可能

**用途**: 
- リビングアムル → リビングアーマー（敵が武器未使用時）

---

## 条件システム

### enemy_item_not_used（敵アイテム未使用）

相手が特定カテゴリのアイテムを使用していないときに発動

```json
{
  "type": "enemy_item_not_used",
  "item_category": "武器"
}
```

**判定対象**:
- `item_type`フィールドをチェック
- "武器"、"防具"、"巻物"を指定可能

**判定ロジック**:
```
敵のアイテムリストを走査
  → 指定カテゴリのアイテムがある？
	→ Yes: 条件不成立（復活しない）
	→ No: 条件成立（復活する）
```

**使用例**:
- `"item_category": "武器"` → 敵が武器を使っていなければ復活
  - 防具や巻物は使っていても復活可能
  - 武器を使っていれば復活不可

---

## ステータス処理

### 復活時のステータス更新

1. **基本ステータス**: 復活先クリーチャーの値を使用
   - `base_hp` → 復活先のHP（全回復）
   - `current_ap` → 復活先のAP

2. **アイテムボーナス**: **引き継ぐ**
   - `item_bonus_hp` → 保持
   - アイテム効果 → 継続適用

3. **土地ボーナス**: **再計算**
   - 復活先クリーチャーの属性で土地ボーナスを再計算
   - 感応効果も復活先の条件で再判定

4. **現在HP**: **全回復**
   - `update_current_hp()`で最大HPに設定
   - 土地ボーナス + アイテムボーナスを含む

### 処理フロー

```
撃破直前: リビングアムル AP:20, HP:-20 (撃破)
↓
条件チェック: 敵が武器使用？ → No
↓
復活実行（ID: 438 リビングアーマー）
↓
復活後: AP:0, HP:40 (全回復)
  + 土地ボーナス再計算
  + アイテムボーナス引き継ぎ
↓
戦闘継続（防御側の攻撃ターン）
```

---

## 戦闘結果への影響

### 復活成功時

**侵略側視点**:
- 防御側を撃破したが、別クリーチャーとして復活
- 復活後のクリーチャーから反撃を受ける
- 侵略失敗の可能性が高まる

**防御側視点**:
- 撃破されても復活して戦闘継続
- タイルを守り抜ける
- 復活後のクリーチャーで反撃可能

**重要**: 
- **タイルは取られない**
- 復活後も戦闘は継続（両者生存と同じ扱い）
- 復活したクリーチャーで反撃できる

---

### 復活失敗時（条件不成立）

通常の撃破として処理:
- 防御側撃破
- 侵略成功
- タイル奪取

---

## 実装クリーチャー

### 実装済み（4体+1アイテム）

| 種類 | ID | 名前 | 復活タイプ | 復活先 | 復活先ID | 条件 |
|-----|----|----|----------|-------|---------|-----|
| クリーチャー | 439 | リビングアムル | 条件付き | リビングアーマー | 438 | 敵が武器未使用 |
| クリーチャー | 139 | ヘルグラマイト | 強制 | サーペントフライ | 316 | なし |
| クリーチャー | 411 | グレートフォシル | 強制 | ティラノサウルス | 425 | なし |
| アイテム | 1045 | ネクロマンサーリング | 強制 | スケルトン | 420 | なし |

**注**: アイテムの死者復活は、アイテム使用者が撃破されたときに発動

---

## データ構造

### リビングアムル（条件付き復活）

```json
{
  "id": 439,
  "name": "リビングアムル",
  "ap": 20,
  "hp": 10,
  "ability": "アイテムクリーチャー・死者復活",
  "ability_detail": "アイテムクリーチャー；敵武器不使用時、死者復活[リビングアーマー]",
  "ability_parsed": {
	"keywords": ["アイテムクリーチャー", "死者復活"],
	"effects": [
	  {
		"effect_type": "item_creature",
		"trigger": "on_use_as_item",
		"stat_bonus": {
		  "ap": 20,
		  "hp": 10
		}
	  },
	  {
		"effect_type": "revive",
		"trigger": "on_death",
		"revive_type": "conditional",
		"creature_id": 438,
		"condition": {
		  "type": "enemy_item_not_used",
		  "item_category": "武器"
		}
	  }
	]
  }
}
```

---

### ヘルグラマイト（強制復活）

```json
{
  "id": 139,
  "name": "ヘルグラマイト",
  "ap": 30,
  "hp": 30,
  "ability": "死者復活[サーペントフライ]",
  "ability_detail": "死者復活[サーペントフライ]",
  "ability_parsed": {
	"keywords": ["死者復活"],
	"effects": [
	  {
		"effect_type": "revive",
		"trigger": "on_death",
		"revive_type": "forced",
		"creature_id": 316
	  }
	]
  }
}
```

---

### グレートフォシル（強制復活）

```json
{
  "id": 411,
  "name": "グレートフォシル",
  "ap": 0,
  "hp": 30,
  "ability": "防御型・通行料変化・死者復活",
  "ability_detail": "防御型；通行料変化[G0]；死者復活[ティラノサウルス]",
  "ability_parsed": {
	"keywords": ["防御型", "通行料変化", "死者復活"],
	"effects": [
	  {
		"effect_type": "defensive"
	  },
	  {
		"effect_type": "toll_change",
		"value": 0
	  },
	  {
		"effect_type": "revive",
		"trigger": "on_death",
		"revive_type": "forced",
		"creature_id": 425
	  }
	]
  }
}
```

---

### ネクロマンサーリング（アイテム・強制復活）

```json
{
  "id": 1045,
  "name": "ネクロマンサーリング",
  "type": "item",
  "item_type": "防具",
  "effect": "死者復活[スケルトン]",
  "effect_parsed": {
	"keywords": ["死者復活"],
	"effects": [
	  {
		"effect_type": "revive",
		"trigger": "on_death",
		"revive_type": "forced",
		"creature_id": 420
	  }
	]
  }
}
```

---

## 他スキルとの相互作用

| スキル | 関係 |
|--------|------|
| 即死 | 即死で撃破されても死者復活は発動する |
| 再生 | 死者復活が発動すると再生は無効（既に撃破されているため） |
| 変身 | 変身後のクリーチャーが撃破されても、変身前のクリーチャーの死者復活は発動しない |
| 先制 | 復活後のクリーチャーが先制を持つ場合、反撃時に先制発動 |
| 感応 | 復活後のクリーチャーの属性と土地属性で感応を再判定 |
| 土地ボーナス | 復活後のクリーチャーの属性で土地ボーナスを再計算 |
| アイテム効果 | 復活前のアイテム効果は引き継がれる |

---

## 実装コード

### 死者復活チェックと適用

```gdscript
static func check_and_apply_revive(
	participant: BattleParticipant, 
	opponent: BattleParticipant, 
	card_loader
) -> Dictionary:
	"""
	死者復活スキルをチェックして適用
	
	Returns:
		{
			"revived": bool,
			"new_creature_id": int,
			"new_creature_name": String
		}
	"""
	var result = {
		"revived": false,
		"new_creature_id": -1,
		"new_creature_name": ""
	}
	
	# 死者復活効果をチェック
	var revive_effect = _check_revive(participant)
	if not revive_effect:
		return result
	
	print("[死者復活チェック] ", participant.creature_data.get("name", "?"))
	
	# 条件チェック（条件付き復活の場合）
	if not _check_revive_condition(revive_effect, opponent):
		print("[死者復活] 条件未達成のため発動しません")
		return result
	
	# 復活先のクリーチャーIDを決定
	var new_creature_id = revive_effect.get("creature_id", -1)
	if new_creature_id <= 0:
		print("[死者復活] 無効なクリーチャーIDです: ", new_creature_id)
		return result
	
	# 復活実行
	var new_creature = card_loader.get_card_by_id(new_creature_id)
	if new_creature:
		_apply_revive(participant, new_creature, result)
	else:
		print("[死者復活] クリーチャーが見つかりません: ID ", new_creature_id)
	
	return result
```

### 条件チェック

```gdscript
static func _check_revive_condition(
	revive_effect: Dictionary, 
	opponent: BattleParticipant
) -> bool:
	"""
	復活条件をチェック
	"""
	var revive_type = revive_effect.get("revive_type", "forced")
	
	# 強制復活は無条件で発動
	if revive_type == "forced":
		return true
	
	# 条件付き復活
	if revive_type == "conditional":
		var condition = revive_effect.get("condition", {})
		var condition_type = condition.get("type", "")
		
		match condition_type:
			"enemy_item_not_used":
				# 相手がアイテムを使用していない
				var item_category = condition.get("item_category", "")
				var opponent_used_item = _opponent_used_item_category(opponent, item_category)
				print("[条件チェック] 敵が", item_category, "を使用: ", opponent_used_item)
				return not opponent_used_item
		
		print("[警告] 未知の条件タイプ: ", condition_type)
		return false
	
	return false

static func _opponent_used_item_category(
	opponent: BattleParticipant, 
	category: String
) -> bool:
	"""
	相手が特定カテゴリのアイテムを使用しているかチェック
	
	注: item_typeフィールドをチェック（categoryではない）
	"""
	var items = opponent.creature_data.get("items", [])
	for item in items:
		var item_category = item.get("item_type", "")
		if item_category == category:
			return true
	return false
```

### 復活の適用

```gdscript
static func _apply_revive(
	participant: BattleParticipant, 
	new_creature: Dictionary, 
	result: Dictionary
) -> void:
	"""
	死者復活を適用（変身処理を流用）
	"""
	var old_name = participant.creature_data.get("name", "?")
	var new_name = new_creature.get("name", "?")
	
	print("【死者復活】", old_name, " → ", new_name)
	
	# 現在のアイテムボーナスを記録
	var current_item_bonus_hp = participant.item_bonus_hp
	var current_items = participant.creature_data.get("items", [])
	
	# creature_dataを新しいクリーチャーに置き換え
	participant.creature_data = new_creature.duplicate(true)
	
	# アイテム情報を引き継ぐ
	if not current_items.is_empty():
		participant.creature_data["items"] = current_items
	
	# 基礎ステータスを新しいクリーチャーのものに更新
	participant.base_hp = new_creature.get("hp", 0)
	participant.current_ap = new_creature.get("ap", 0)
	
	# HPバフを再適用
	participant.item_bonus_hp = current_item_bonus_hp
	
	# HPを全回復（最大HPで復活）
	participant.update_current_hp()
	
	print("  復活後AP/HP: ", participant.current_ap, "/", participant.current_hp)
	
	# 結果を記録
	result["revived"] = true
	result["new_creature_id"] = new_creature.get("id", -1)
	result["new_creature_name"] = new_name
```

---

## 使用例

### シナリオ1: リビングアムル（条件付き復活・成功）

```
侵略側: キメラ (AP:30, HP:50) + スパイクシールド（防具）
防御側: リビングアムル (AP:20, HP:10)

【第1攻撃】侵略側の攻撃
  キメラ AP:30 → リビングアムル
  ダメージ: 30
  → リビングアムル撃破（HP:-20）

【死者復活チェック】
  条件: 敵が武器を使用していない？
  → キメラはスパイクシールド（防具）を使用
  → 武器は使っていない
  → 条件成立！

【死者復活実行】
  リビングアムル → リビングアーマー (AP:0, HP:40)

【第2攻撃】防御側の攻撃
  リビングアーマー AP:0 → キメラ
  ダメージ: 0（AP:0のため）

【結果】両者生存 → 侵略失敗
  防御側タイルにリビングアーマーが配置
```

---

### シナリオ2: リビングアムル（条件付き復活・失敗）

```
侵略側: ゴブリン (AP:20, HP:30) + ホーリーワード（武器）
防御側: リビングアムル (AP:20, HP:10)

【第1攻撃】侵略側の攻撃
  ゴブリン AP:20 + ホーリーワード → リビングアムル
  ダメージ: 20
  → リビングアムル撃破（HP:-10）

【死者復活チェック】
  条件: 敵が武器を使用していない？
  → ゴブリンはホーリーワード（武器）を使用
  → 条件不成立
  → 死者復活しない

【結果】侵略成功
  防御側撃破、タイル奪取
```

---

### シナリオ3: ヘルグラマイト（強制復活）

```
侵略側: バンパイア (AP:40, HP:40)
防御側: ヘルグラマイト (AP:30, HP:30) 土地:水Lv2

【第1攻撃】侵略側の攻撃
  バンパイア AP:40 → ヘルグラマイト
  ダメージ: 40
  → ヘルグラマイト撃破（HP:-10）

【死者復活チェック】
  条件: なし（強制復活）
  → 無条件で発動

【死者復活実行】
  ヘルグラマイト → サーペントフライ (AP:30, HP:40)
  土地ボーナス: 水Lv2（属性不一致） → +0
  最終HP: 40

【第2攻撃】防御側の攻撃
  サーペントフライ AP:30 → バンパイア
  ダメージ: 30
  → バンパイア HP:10

【結果】両者生存 → 侵略失敗
  防御側タイルにサーペントフライが配置
```

---

## 設計思想

### 1. 防御的スキルの最終手段

- **コンセプト**: タイルを守り抜く最後の砦
- **バランス**: 強力だが条件付きや弱いクリーチャーへの復活で調整
- **戦略性**: 相手のアイテム使用を読む心理戦

### 2. 変身システムとの統合

- **コード再利用**: 変身処理をベースに実装
- **一貫性**: ステータス処理が変身と同じロジック
- **拡張性**: 将来的な復活条件の追加が容易

### 3. 条件システムの柔軟性

- **現在**: `enemy_item_not_used`のみ
- **将来**: 追加可能な条件
  - `hp_threshold`: HP一定以下で発動
  - `turn_count`: 特定ターン数以降で発動
  - `land_count`: 土地数に応じて発動

### 4. タイル防衛の重要性

- **ゲームバランス**: 侵略側と防御側のバランス調整
- **戦略の幅**: 防御特化のデッキ構築が可能
- **心理戦**: 相手に復活を警戒させる効果

### 5. データ構造の明確化

- **バグ修正**: `creature_id`が自分自身を指していたバグ
  - リビングアムル ID:439 → ID:439（間違い）
  - リビングアムル ID:439 → ID:438（正しい）
- **フィールド名**: `item_type`を使用（`category`ではない）
- **条件の明確化**: 「武器」のみチェック、防具や巻物は対象外

---

## 注意事項

### 実装上の注意

1. **復活タイミングの順守**
   - 撃破判定直後、戦闘結果確定前
   - 復活後も戦闘は継続

2. **条件チェックの正確性**
   - `item_type`フィールドを使用
   - 指定カテゴリのみチェック（他カテゴリは無視）

3. **ステータス更新の順序**
   - アイテムボーナスを先に記録
   - creature_dataを置き換え
   - 土地ボーナスを再計算
   - HPを全回復

4. **タイル更新**
   - 復活後は必ずタイル更新（永続変身）
   - `update_tile_creature()`でスキルインデックスも更新

5. **エッジケース**
   - 復活先のcreature_idが無効な場合
   - 復活先が自分自身を指している場合（バグ）
   - 条件不成立の場合は通常の撃破処理

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.1 | 2025/10/24 | バグ修正：復活後のクリーチャーが手札/タイルに正しく反映されるように修正 |
| 1.0 | 2025/10/24 | 初版作成：死者復活スキル実装完了 |
|  |  | バグ修正：リビングアムルのcreature_id 439→438 |
|  |  | バグ修正：アイテムカテゴリチェックでitem_typeを使用 |

---

## バグ修正履歴

### 2025/10/24 - 復活後のクリーチャーが手札/タイルに反映されない問題

**問題**: 死者復活した後に両者生存で戦闘終了すると、復活**前**のクリーチャーが手札に戻る

**例**: ヘルグラマイト → サーペントフライに復活 → 両者生存 → **ヘルグラマイト**が手札に戻る ❌

**原因**: `BattleResult.ATTACKER_SURVIVED`の処理で、元の`card_data`を手札に戻していた

**修正内容**:
```gdscript
// 修正前
card_system_ref.return_card_to_hand(attacker_index, card_data)

// 修正後
var return_card_data = attacker.creature_data.duplicate(true)
// HPは元の最大値にリセット（手札に戻る時はダメージを回復）
// duplicate(true)で元のHPが既にコピーされているので上書きしない
card_system_ref.return_card_to_hand(attacker_index, return_card_data)
```

**影響**: 復活後のクリーチャー（`attacker.creature_data`）が正しく手札に戻るようになった

---

### 2025/10/24 - タイル情報に`has_creature`フィールドがない問題

**問題**: 死者復活後にクリーチャー交換しようとすると、`tile_info.has_creature`が`false`になり交換が失敗

**原因**: `tile_data_manager.get_tile_info()`が`has_creature`フィールドを返していなかった

**修正内容**:
```gdscript
// 修正前
return {
	"creature": tile.creature_data,
	// has_creatureフィールドがない
}

// 修正後
return {
	"creature": tile.creature_data,
	"has_creature": not tile.creature_data.is_empty(),
}
```

**影響**: クリーチャーの存在を正しく判定できるようになり、交換が正常に動作するようになった
