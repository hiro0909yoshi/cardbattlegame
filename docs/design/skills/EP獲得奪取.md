# EP獲得・奪取スキル

**バージョン**: 1.0  
**最終更新**: 2025年11月3日

---

## 概要

バトル中にEPを獲得・奪取するスキル群。様々なタイミングで発動し、プレイヤーのEPを増やす。

**実装ファイル**: 
- `scripts/battle/skills/skill_magic_gain.gd` - EP獲得
- `scripts/battle/skills/skill_magic_steal.gd` - EP奪取

---

## EP獲得スキル

### 1. 侵略時EP獲得

バトル開始時（侵略側のみ）にEPを獲得する。

**該当クリーチャー**:
- **ピュトン** (ID: 36): 侵略時、EP獲得[100EP]
- **トレジャーレイダー** (ID: 331): 侵略時、EP獲得[100EP]

**JSON定義**:
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "magic_gain_on_invasion",
		"amount": 100
	  }
	]
  }
}
```

**発動タイミング**: `BattleSkillProcessor.apply_pre_battle_skills()` の最後

**動作**:
```
バトル開始
  → 【侵略時EP獲得】ピュトン → 100EP獲得
  → spell_magic.add_magic(player_id, 100)
```

---

### 2. 無条件EP獲得

バトル開始時（攻防両側）にEPを獲得する。

**該当クリーチャー**:
- **クリーピングコイン** (ID: 410): EP獲得[100EP]

**JSON定義**:
```json
{
  "ability_parsed": {
	"keywords": ["EP獲得"],
	"effects": [
	  {
		"effect_type": "magic_gain_on_battle_start",
		"amount": 100
	  }
	]
  }
}
```

**発動タイミング**: `BattleSkillProcessor.apply_pre_battle_skills()` の最後

**動作**:
```
バトル開始
  → 【EP獲得】クリーピングコイン → 100EP獲得
  → spell_magic.add_magic(player_id, 100)
```

---

### 3. ダメージ時EP獲得

ダメージを受けた直後にEPを獲得する。

**該当クリーチャー**:
- **ゼラチンウォール** (ID: 127): EP獲得[受けたダメージ×5EP]

**JSON定義**:
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "magic_gain_on_damage",
		"multiplier": 5
	  }
	]
  }
}
```

**発動タイミング**: `BattleParticipant.take_damage()` の最後

**動作**:
```
ゼラチンウォールが30ダメージ受ける
  → 【ダメージ時EP獲得】ゼラチンウォール → 150EP獲得（ダメージ30×5）
  → spell_magic.add_magic(player_id, 150)
```

---

## EP奪取スキル

### 1. ダメージベースEP奪取

敵に与えたダメージに応じてEPを奪う。

**該当クリーチャー**:
- **バンディット** (ID: 433): EP奪取[敵に与えたダメージ×2EP]

**JSON定義**:
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "magic_steal_on_damage",
		"multiplier": 2
	  }
	]
  }
}
```

**発動タイミング**: 攻撃でダメージを与えた直後

**動作**:
```
バンディットが40ダメージを与える
  → 【EP奪取】バンディット → 80EP奪取（ダメージ40×2）
  → spell_magic.steal_magic(defender_id, attacker_id, 80)
```

---

### 2. アイテム不使用時EP奪取

アイテムを使用していない場合にEPを奪う。

**該当クリーチャー**:
- **アマゾン** (ID: 107): アイテム不使用時、EP奪取[周回数×30EP]

**JSON定義**:
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "magic_steal_no_item",
		"multiplier": 30
	  }
	]
  }
}
```

**発動タイミング**: バトル開始時（アイテム使用チェック後）

**動作**:
```
アマゾンがアイテム未使用（周回数3）
  → 【アイテム不使用時EP奪取】アマゾン → 90EP奪取（周回数3×30）
  → spell_magic.steal_magic(enemy_id, player_id, 90)
```

**注意**: 周回数の取得は`GameFlowManager`から必要

---

## 実装詳細

### 発動場所一覧

| スキル | 発動場所 | メソッド |
|--------|---------|---------|
| 侵略時EP獲得 | `BattleSkillProcessor` | `apply_magic_gain_on_battle_start()` |
| 無条件EP獲得 | `BattleSkillProcessor` | `apply_magic_gain_on_battle_start()` |
| ダメージ時EP獲得 | `BattleParticipant` | `_trigger_magic_from_damage()` |
| ダメージベース奪取 | `BattleParticipant` | `trigger_magic_steal_on_damage()` |
| アイテム不使用奪取 | `BattleSkillProcessor` | (未実装) |

### コード例

#### EP獲得（バトル開始時）

```gdscript
# BattleSkillProcessor.gd
func apply_magic_gain_on_battle_start(attacker, defender):
	if not game_flow_manager_ref:
		return
	
	var spell_magic = game_flow_manager_ref.spell_magic
	if not spell_magic:
		return
	
	SkillMagicGain.apply_on_battle_start(attacker, defender, spell_magic)
```

#### EP獲得（ダメージ時）

```gdscript
# BattleParticipant.gd
func _trigger_magic_from_damage(damage: int):
	# ... アイテムの処理 ...
	
	# クリーチャースキル
	SkillMagicGain.apply_damage_magic_gain(self, damage, spell_magic_ref)
```

#### EP奪取（ダメージベース）

```gdscript
# BattleParticipant.gd
func trigger_magic_steal_on_damage(defender, damage: int, spell_magic):
	if not spell_magic or damage <= 0:
		return
	
	SkillMagicSteal.apply_damage_based_steal(self, defender, damage, spell_magic)
```

---

## 正規表現パターン

### EP獲得量抽出
```gdscript
regex.compile("EP獲得\\[G(\\d+)\\]")
# "EP獲得[100EP]" → 100
```

### ダメージ倍率抽出
```gdscript
regex.compile("×EP(\\d+)")
# "受けたダメージ×5EP" → 5
# "敵に与えたダメージ×2EP" → 2
```

### 周回数倍率抽出
```gdscript
regex.compile("周回数×EP(\\d+)")
# "周回数×30EP" → 30
```

---

## 関連システム

- **SpellMagic** (`scripts/spells/spell_magic.gd`) - EP操作基盤
  - `add_magic()` - EP増加
  - `steal_magic()` - EP奪取
- **BattleSkillProcessor** - スキル適用処理
- **BattleParticipant** - ダメージ処理

---

## アイテムとの違い

### クリーチャースキル vs アイテム効果

| 項目 | クリーチャースキル | アイテム効果 |
|------|------------------|-------------|
| 実装場所 | `skill_magic_*.gd` | アイテムの`effect_parsed` |
| 判定方法 | `ability_detail`解析 | `effect_type`マッチ |
| 例 | ゼラチンウォール | ゼラチンアーマー |

### 共通点

- どちらも`SpellMagic`を使用
- 同じタイミングで発動可能（重複可能）
- ログ出力形式が類似

---

## 未実装機能

### アイテム不使用時EP奪取の完全実装

現在、アマゾンの「アイテム不使用時EP奪取」は以下が必要：
1. バトル開始時に両者のアイテム使用をチェック
2. `GameFlowManager`から周回数を取得
3. `SkillMagicSteal.apply_no_item_steal()`を呼び出し

**実装予定箇所**: `BattleSkillProcessor.apply_pre_battle_skills()`

---

## デバッグログ

EP獲得・奪取時には以下のログが出力される:

```
【侵略時EP獲得】ピュトン → 100EP獲得
【EP獲得】クリーピングコイン → 100EP獲得
【ダメージ時EP獲得】ゼラチンウォール → 150EP獲得（ダメージ30×5）
【EP奪取】バンディット → 80EP奪取（ダメージ40×2）
【アイテム不使用時EP奪取】アマゾン → 90EP奪取（周回数3×30）
```

---

**最終更新**: 2025年11月3日（v1.0）
