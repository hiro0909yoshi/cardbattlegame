# 変身スキル

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [概要](#概要)
2. [発動タイミング](#発動タイミング)
3. [変身タイプ](#変身タイプ)
4. [変身対象](#変身対象)
5. [ステータス処理](#ステータス処理)
6. [戦闘後の挙動](#戦闘後の挙動)
7. [実装クリーチャー](#実装クリーチャー)
8. [データ構造](#データ構造)
9. [他スキルとの相互作用](#他スキルとの相互作用)
10. [実装コード](#実装コード)
11. [使用例](#使用例)
12. [設計思想](#設計思想)

---

## 概要

特定のタイミングで自身または相手を別のクリーチャーに変身させるアクティブスキル。

---

## 発動タイミング

### 1. 戦闘開始時 (`on_battle_start`)

- **タイミング**: 戦闘準備完了後、攻撃開始前
- **用途**: 戦闘ごとに姿を変えるランダム変身（バルダンダース）

### 2. 攻撃成功時 (`on_attack_success`)

- **タイミング**: 攻撃がヒットし、ダメージ適用後、即死判定後
- **条件**: 相手が生存している場合のみ発動
- **用途**: 相手を弱体化させる強制変身（コカトリス）

---

## 変身タイプ

### 1. ランダム変身 (`random`)

全クリーチャーの中からランダムに1体を選んで変身

```json
{
  "transform_type": "random"
}
```

**特徴**:
- 変身先は完全ランダム
- 戦略性よりギャンブル性が高い
- 毎戦闘異なるクリーチャーになる

---

### 2. 強制変身 (`forced`)

指定されたクリーチャーに必ず変身させる

```json
{
  "transform_type": "forced",
  "creature_id": 222
}
```

**特徴**:
- 変身先が固定
- 相手を特定の弱いクリーチャーに変身させる戦術
- 確実性が高い

---

### 3. 特定変身 (`specific`)

条件に応じて特定のクリーチャーに変身（将来実装用）

```json
{
  "transform_type": "specific",
  "creature_id": 100
}
```

**用途**: 
- 秘術で特定クリーチャーに変身
- 条件付き変身効果

---

## 変身対象

### 1. 自分自身 (`self`)

スキル保持者自身が変身する

```json
{
  "target": "self"
}
```

**用途**: 
- ランダム変身（バルダンダース）
- 戦闘開始時の自己強化

**挙動**:
- 自分のcreature_dataが変身先に置き換わる
- 変身先のAP/HPを使用

---

### 2. 相手 (`opponent`)

攻撃相手を変身させる

```json
{
  "target": "opponent"
}
```

**用途**: 
- 強制変身（コカトリス → ストーンウォール）
- 相手の弱体化

**挙動**:
- 相手のcreature_dataが変身先に置き換わる
- 変身後も戦闘は継続
- 変身先のAP/HPで反撃する

---

## ステータス処理

### 変身時のステータス更新

1. **基本ステータス**: 変身先クリーチャーの値を使用
   - `base_hp` → 変身先のHP
   - `current_ap` → 変身先のAP

2. **アイテムボーナス**: **引き継ぐ**
   - `item_bonus_hp` → 保持
   - アイテム効果 → 継続適用

3. **土地ボーナス**: **再計算**
   - 変身先クリーチャーの属性で土地ボーナスを再計算
   - 感応効果も変身先の条件で再判定

4. **現在HP**: 土地ボーナス + アイテムボーナスで再計算

### 処理フロー

```
変身前: AP:30, HP:40 + 土地:10 = 合計HP:55
↓
変身実行（ID: 222 ストーンウォール）
↓
変身後: AP:0, HP:60 + 土地:0 = 合計HP:65
```

---

## 戦闘後の挙動

### 1. 永続変身 (`revert_after_battle: false`)

戦闘後も変身したまま

```json
{
  "revert_after_battle": false
}
```

**用途**: コカトリスの石化攻撃

**挙動**:
- 戦闘終了後もストーンウォールのまま
- タイルのcreature_dataも更新される
- 次回の戦闘でも変身後の姿で戦う

---

### 2. 一時変身 (`revert_after_battle: true`)

戦闘後に元の姿に戻る

```json
{
  "revert_after_battle": true
}
```

**用途**: バルダンダースのランダム変身

**挙動**:
- 戦闘中のみ変身
- 戦闘終了後、元のバルダンダースに戻る
- タイルのcreature_dataは元のまま

---

## 実装クリーチャー

### 実装済み（2体）

| ID | 名前 | 属性 | 効果 |
|----|------|------|------|
| 432 | バルダンダース（ハルゲンダース） | 無 | 戦闘開始時、ランダム変身（戦闘後復帰） |
| 215 | コカトリス | 地 | 攻撃成功時、相手をストーンウォール（ID:222）に変身 |

---

## データ構造

### バルダンダース（ランダム変身・戦闘後復帰）

```json
{
  "id": 432,
  "name": "ハルゲンダース",
  "ability_parsed": {
	"keywords": ["変身"],
	"effects": [
	  {
		"effect_type": "transform",
		"trigger": "on_battle_start",
		"target": "self",
		"transform_type": "random",
		"revert_after_battle": true
	  }
	]
  }
}
```

---

### コカトリス（強制変身・永続）

```json
{
  "id": 215,
  "name": "コカトリス",
  "ability_parsed": {
	"keywords": ["強制変化"],
	"effects": [
	  {
		"effect_type": "transform",
		"trigger": "on_attack_success",
		"target": "opponent",
		"transform_type": "forced",
		"creature_id": 222,
		"revert_after_battle": false
	  }
	]
  }
}
```

---

## 他スキルとの相互作用

| スキル | 関係 |
|--------|------|
| 即死 | 即死された場合、変身は発動しない |
| 無効化 | 変身は無効化されない（将来実装で変更可能） |
| 再生 | 変身後のクリーチャーが再生を持つ場合は発動 |
| 先制 | 変身前後どちらのスキルも発動する |
| アイテム効果 | 変身後もアイテム効果は継続 |
| 土地ボーナス | 変身後のクリーチャーの属性で再計算 |
| 感応 | 変身後のクリーチャーの感応条件で再判定 |

---

## 実装コード

### 変身処理の流れ

```gdscript
# 1. 変身効果のチェック
static func process_transform_effects(
	attacker: BattleParticipant, 
	defender: BattleParticipant, 
	card_loader, 
	trigger: String
) -> Dictionary:
	var result = {
		"attacker_transformed": false,
		"defender_transformed": false,
		"attacker_original": {},
		"defender_original": {}
	}
	
	# 攻撃側の変身効果チェック
	var attacker_transform = _check_transform(attacker, trigger)
	if attacker_transform:
		var target = attacker_transform.get("target", "self")
		if target == "self":
			# 自分自身が変身
			_apply_transform(attacker, attacker_transform, card_loader, result, true)
		elif target == "opponent":
			# 相手を変身させる
			_apply_transform(defender, attacker_transform, card_loader, result, false)
	
	# 防御側の変身効果チェック
	var defender_transform = _check_transform(defender, trigger)
	if defender_transform:
		var target = defender_transform.get("target", "self")
		if target == "self":
			# 自分自身が変身
			_apply_transform(defender, defender_transform, card_loader, result, false)
		elif target == "opponent":
			# 相手を変身させる
			_apply_transform(attacker, defender_transform, card_loader, result, true)
	
	return result
```

### 変身の適用

```gdscript
static func _apply_transform(
	participant: BattleParticipant, 
	transform_effect: Dictionary, 
	card_loader, 
	result: Dictionary, 
	is_attacker: bool
) -> void:
	var transform_type = transform_effect.get("transform_type", "")
	var revert_after_battle = transform_effect.get("revert_after_battle", false)
	
	# 元のデータを保存（戦闘後に戻す必要がある場合）
	var original_data = {}
	if revert_after_battle:
		original_data = participant.creature_data.duplicate(true)
	
	# 変身先の決定
	var new_creature_id = -1
	match transform_type:
		"random":
			new_creature_id = _get_random_creature_id(card_loader)
		"forced":
			new_creature_id = transform_effect.get("creature_id", -1)
		"specific":
			new_creature_id = transform_effect.get("creature_id", -1)
	
	# 変身実行
	if new_creature_id > 0:
		var new_creature = card_loader.get_card_by_id(new_creature_id)
		if new_creature:
			_transform_creature(participant, new_creature, is_attacker, result, original_data)
```

### ステータスの更新

```gdscript
static func _transform_creature(
	participant: BattleParticipant, 
	new_creature: Dictionary, 
	is_attacker: bool, 
	result: Dictionary, 
	original_data: Dictionary
) -> void:
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
	
	# HPを再計算（土地ボーナスとアイテムボーナスを含む）
	participant.update_current_hp()
	
	# 結果を記録
	if is_attacker:
		result["attacker_transformed"] = true
		if not original_data.is_empty():
			result["attacker_original"] = original_data
	else:
		result["defender_transformed"] = true
		if not original_data.is_empty():
			result["defender_original"] = original_data
```

### 戦闘後の復帰処理

```gdscript
static func revert_transform(
	participant: BattleParticipant, 
	original_data: Dictionary
) -> void:
	if original_data.is_empty():
		return
	
	print("[変身解除] ", participant.creature_data.get("name", "?"), 
		  " → ", original_data.get("name", "?"))
	
	# creature_dataを完全に元に戻す
	participant.creature_data = original_data.duplicate(true)
```

---

## 使用例

### シナリオ1: バルダンダース（ランダム変身）

```
侵略側: バルダンダース (AP:0, HP:30)
防御側: ゴブリン (AP:20, HP:30)

【戦闘開始】
【変身実行】バルダンダース → ドラゴン
  元のAP/HP: 0/30
  変身後AP/HP: 50/60

侵略側: ドラゴン
  基本HP:60 + 土地ボーナス:10 = MHP:70
  AP:50

【第1攻撃】侵略側の攻撃
  ドラゴン AP:50 → ゴブリン
  → ゴブリン撃破

【結果】侵略成功

【戦闘後処理】
[変身復帰] ドラゴン → バルダンダース
  バルダンダースに戻って配置
```

---

### シナリオ2: コカトリス（強制変身）

```
侵略側: コカトリス (AP:30, HP:40)
防御側: キングバラン (AP:60, HP:50)

【第1攻撃】侵略側の攻撃
  コカトリス AP:30 → キングバラン
  ダメージ処理:
	- 基本HP: 30 消費
  → 残HP: 20 (基本HP:20)

【変身発動】防御側が変身
  [強制変身] キングバラン → ID:222
  【変身実行】キングバラン → ストーンウォール
	元のAP/HP: 60/50
	変身後AP/HP: 0/60

【第2攻撃】防御側の攻撃
  ストーンウォール AP:0 → コカトリス
  ダメージ処理なし（AP:0のため）

【結果】両者生存 → 侵略失敗
  防御側タイルのクリーチャーはストーンウォールのまま
```

---

### シナリオ3: 変身後の土地ボーナス再計算

```
侵略側: バルダンダース (無属性, AP:0, HP:30)
防御側タイル: 火属性 Lv2 (土地ボーナス+20)

【戦闘開始】
【変身実行】バルダンダース → サラマンダー (火属性)
  元のAP/HP: 0/30
  変身後: AP:30, HP:40
  土地ボーナス: 火属性Lv2 → +20
  最終HP: 40 + 20 = 60
```

---

## 設計思想

### 1. ターゲット指定の重要性

- **`target`フィールドは必須**: "self"か"opponent"かを明確に指定
- **誤解を防ぐ**: スキル保持者が変身するのか、相手を変身させるのか明確化
- **コードの可読性**: 処理フローが追いやすくなる

### 2. ステータス処理の一貫性

- **アイテムボーナスは引き継ぐ**: 変身してもアイテムの効果は維持
- **土地ボーナスは再計算**: 変身先の属性に応じて再判定
- **HP管理の複雑さ**: 基本HP、土地ボーナス、アイテムボーナスを正しく処理

### 3. 戦闘後の状態管理

- **永続変身**: タイルのcreature_dataを更新、次回戦闘でも変身後の姿
- **一時変身**: original_dataを保持、戦闘後に復帰
- **スキルインデックスの更新**: タイル更新時にスキルインデックスも再構築

### 4. 拡張性

- **将来の変身タイプ**: 条件付き変身、属性指定変身などを追加可能
- **変身解除スキル**: 将来的に変身を解除するスキルの実装が可能
- **変身チェーン**: 変身先がさらに変身する処理も対応可能

### 5. バランス調整

- **ランダム変身のリスク**: 弱いクリーチャーになる可能性もある
- **強制変身の確実性**: コカトリスは相手を確実に弱体化できる
- **戦闘後復帰の安全性**: バルダンダースは元に戻るため安心して使える

---

## 注意事項

### 実装上の注意

1. **変身タイミングの順守**
   - `on_battle_start`: 戦闘準備完了後、攻撃開始前
   - `on_attack_success`: ダメージ適用後、即死判定後、撃破判定前

2. **ステータス更新の順序**
   - アイテムボーナスを先に記録
   - creature_dataを置き換え
   - 土地ボーナスを再計算
   - HPを再計算

3. **タイル更新のタイミング**
   - 永続変身の場合のみタイル更新
   - update_tile_creature()でスキルインデックスも更新

4. **エッジケース**
   - 変身先のcreature_idが無効な場合
   - 即死で倒された場合は変身しない
   - 完全無効化された場合は変身判定なし

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.1 | 2025/10/24 | バグ修正：攻撃成功時の変身条件、一時変身の復帰処理、戦闘結果情報のマージ |
| 1.0 | 2025/10/24 | 初版作成：バルダンダース、コカトリスの変身スキル実装 |

---

## バグ修正履歴

### 2025/10/24 - 攻撃成功時の変身条件修正
**問題**: AP:0の攻撃（ストーンウォール等）でも変身スキルが発動していた

**原因**: 攻撃成功時の条件が「相手が生存している」だけで、実際にダメージを与えたかチェックしていなかった

**修正内容**:
```gdscript
// 修正前
if defender_p.is_alive() and card_system_ref:

// 修正後  
if defender_p.is_alive() and card_system_ref and attacker_p.current_ap > 0:
```

**影響**: AP > 0 の条件を追加し、実際にダメージを与えた場合のみ変身が発動するように修正

---

### 2025/10/24 - 一時変身の復帰処理修正

**問題1**: バルダンダースが変身後のクリーチャーのまま手札に戻る

**原因**: 変身復帰処理が手札に戻す処理の**後**に実行されていた

**修正内容**: `BattleResult.ATTACKER_WIN`と`ATTACKER_SURVIVED`で、変身復帰を手札に戻す/タイル配置の前に実行

---

**問題2**: 戦闘結果情報が正しくマージされず、変身情報が失われる

**原因**: 
1. `battle_execution.execute_attack_sequence()`が変身情報を返していなかった
2. 攻撃シーケンスの結果で戦闘開始時の変身情報が上書きされていた

**修正内容**:
1. 戻り値を`revive_info`から`battle_result`に拡張し、変身情報も含めるように修正
2. マージ時に空でない値のみ上書きするロジックを追加

```gdscript
// マージロジック
for key in attack_result.keys():
	var value = attack_result[key]
	// 復活・変身フラグはtrueの場合のみ上書き
	if key in ["attacker_revived", "defender_revived"]:
		if value == true:
			battle_result[key] = value
	elif key in ["attacker_transformed", "defender_transformed"]:
		if value == true:
			battle_result[key] = value
	// original情報は空でない場合のみ上書き
	elif key in ["attacker_original", "defender_original"]:
		if not value.is_empty():
			battle_result[key] = value
```
