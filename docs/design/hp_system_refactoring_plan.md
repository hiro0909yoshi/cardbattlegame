# current_hp 直接削るシステムへの移行計画

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年11月17日  
**ステータス**: 設計・計画段階  
**目的**: HP管理構造を簡潔化し、current_hp を状態値として直接削るシステムへ移行

---

## 📋 目次

1. [現在のシステム](#現在のシステム)
2. [提案するシステム](#提案するシステム)
3. [データ構造の変更](#データ構造の変更)
4. [実装の変更箇所](#実装の変更箇所)
5. [修正手順](#修正手順)
6. [テスト項目](#テスト項目)
7. [ドキュメント更新項目](#ドキュメント更新項目)
8. [実装ステータス](#実装ステータス)

---

## 現在のシステム

### HP構造

```gdscript
# BattleParticipant（バトル中）
var base_hp: int              # 状態値：ダメージで削られる
var base_up_hp: int = 0       # 永続ボーナス
var current_hp: int           # 計算値：base_hp + base_up_hp + ボーナス群
```

### ダメージ処理フロー

```
1. ボーナスから順に消費
   resonance_bonus_hp → land_bonus_hp → temporary_bonus_hp → 
   item_bonus_hp → spell_bonus_hp
   
2. base_hp から消費

3. update_current_hp() で再計算
   current_hp = base_hp + base_up_hp + ボーナス群
```

### 問題点

- **複雑**: base_hp を計算する必要がある
- **ダメージ後の状態管理**: base_hp と current_hp の関係を常に追跡
- **保存時の計算**: バトル終了時に base_hp + base_up_hp を計算して保存

---

## 提案するシステム

### HP構造

```gdscript
# BattleParticipant（バトル中）
var base_hp: int              # 定数値：creature_data["hp"]
var base_up_hp: int = 0       # 定数値：creature_data["base_up_hp"]
var current_hp: int           # 状態値：ダメージで直接削られる
```

### ダメージ処理フロー

```
1. ボーナスから順に消費
   resonance_bonus_hp → land_bonus_hp → temporary_bonus_hp → 
   item_bonus_hp → spell_bonus_hp
   
2. current_hp から直接消費
   current_hp -= remaining_damage
   
3. update_current_hp() は呼ばない
   current_hp が状態値になるため、計算値ではなくなる
```

### 利点

- **シンプル**: current_hp が直接ダメージを受ける
- **直感的**: 状態値は current_hp のみ
- **保存簡単**: current_hp をそのまま保存

---

## データ構造の変更

### creature_data（ゲームデータ）

```gdscript
{
  "id": 1,
  "name": "アモン",
  "hp": 30,                    # 元のHP（不変）
  "base_up_hp": 0,             # 永続ボーナス（不変）
  "current_hp": 30             # 現在HP（ダメージで減少）
}
```

**変更なし** - 外部データ構造は変わらない

---

### BattleParticipant（バトル中）

#### 変更前

```gdscript
var base_hp: int              # 状態値
var base_up_hp: int = 0       # 状態値
var current_hp: int           # 計算値

func _init(p_creature_data, p_base_hp, p_land_bonus, p_ap, p_is_attacker, p_player_id):
    base_hp = p_base_hp
    land_bonus_hp = p_land_bonus
    # ... 他の初期化
    update_current_hp()  # 計算
```

#### 変更後

```gdscript
var base_hp: int              # 定数値
var base_up_hp: int = 0       # 定数値
var current_hp: int           # 状態値

func _init(p_creature_data, p_base_hp, p_land_bonus, p_ap, p_is_attacker, p_player_id):
    base_hp = p_base_hp           # 元のHP（固定）
    land_bonus_hp = p_land_bonus
    # base_hp と base_up_hp はコンストラクタで固定値化
    # current_hp は battle_preparation.gd で直接設定
```

---

## 実装の変更箇所

### 1. BattleParticipant クラス

#### 1-1. コンストラクタの修正

**ファイル**: `scripts/battle/battle_participant.gd`

**変更内容**:

```gdscript
# 変更前
func _init(
	p_creature_data: Dictionary,
	p_base_hp: int,
	p_land_bonus_hp: int,
	p_ap: int,
	p_is_attacker: bool,
	p_player_id: int
):
	creature_data = p_creature_data
	base_hp = p_base_hp
	land_bonus_hp = p_land_bonus_hp
	current_ap = p_ap
	is_attacker = p_is_attacker
	player_id = p_player_id
	
	has_first_strike = _check_first_strike()
	has_last_strike = _check_last_strike()
	
	# 現在HPを計算
	update_current_hp()

# 変更後
func _init(
	p_creature_data: Dictionary,
	p_base_hp: int,
	p_land_bonus_hp: int,
	p_ap: int,
	p_is_attacker: bool,
	p_player_id: int
):
	creature_data = p_creature_data
	base_hp = p_base_hp              # 元のHP（固定値）
	land_bonus_hp = p_land_bonus_hp
	current_ap = p_ap
	is_attacker = p_is_attacker
	player_id = p_player_id
	
	has_first_strike = _check_first_strike()
	has_last_strike = _check_last_strike()
	
	# current_hp は battle_preparation.gd で直接設定されるため、ここでは初期化しない
	# current_hp の初期値設定は呼び出し側の責任
```

---

#### 1-2. take_damage() メソッドの修正

**ファイル**: `scripts/battle/battle_participant.gd`

**変更内容**:

```gdscript
# 変更前
func take_damage(damage: int) -> Dictionary:
	was_attacked_by_enemy = true
	
	var remaining_damage = damage
	var damage_breakdown = {
		"resonance_bonus_consumed": 0,
		"land_bonus_consumed": 0,
		"temporary_bonus_consumed": 0,
		"item_bonus_consumed": 0,
		"spell_bonus_consumed": 0,
		"base_hp_consumed": 0
	}
	
	# 1. 感応ボーナスから消費
	if resonance_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(resonance_bonus_hp, remaining_damage)
		resonance_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["resonance_bonus_consumed"] = consumed
	
	# 2. 土地ボーナスから消費
	if land_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(land_bonus_hp, remaining_damage)
		land_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["land_bonus_consumed"] = consumed
	
	# 3. 一時的なボーナスから消費
	if temporary_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(temporary_bonus_hp, remaining_damage)
		temporary_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["temporary_bonus_consumed"] = consumed
	
	# 4. アイテムボーナスから消費
	if item_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(item_bonus_hp, remaining_damage)
		item_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["item_bonus_consumed"] = consumed
	
	# 5. スペルボーナスから消費
	if spell_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(spell_bonus_hp, remaining_damage)
		spell_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["spell_bonus_consumed"] = consumed
	
	# 6. 基本HPから消費（base_up_hp は削られない）
	if remaining_damage > 0:
		base_hp -= remaining_damage
		damage_breakdown["base_hp_consumed"] = remaining_damage
	
	# 現在HPを更新
	update_current_hp()
	
	# 💰 魔力獲得処理
	_trigger_magic_from_damage(damage)
	
	return damage_breakdown

# 変更後
func take_damage(damage: int) -> Dictionary:
	was_attacked_by_enemy = true
	
	var remaining_damage = damage
	var damage_breakdown = {
		"resonance_bonus_consumed": 0,
		"land_bonus_consumed": 0,
		"temporary_bonus_consumed": 0,
		"item_bonus_consumed": 0,
		"spell_bonus_consumed": 0,
		"current_hp_consumed": 0
	}
	
	# 1. 感応ボーナスから消費
	if resonance_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(resonance_bonus_hp, remaining_damage)
		resonance_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["resonance_bonus_consumed"] = consumed
	
	# 2. 土地ボーナスから消費
	if land_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(land_bonus_hp, remaining_damage)
		land_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["land_bonus_consumed"] = consumed
	
	# 3. 一時的なボーナスから消費
	if temporary_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(temporary_bonus_hp, remaining_damage)
		temporary_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["temporary_bonus_consumed"] = consumed
	
	# 4. アイテムボーナスから消費
	if item_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(item_bonus_hp, remaining_damage)
		item_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["item_bonus_consumed"] = consumed
	
	# 5. スペルボーナスから消費
	if spell_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(spell_bonus_hp, remaining_damage)
		spell_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["spell_bonus_consumed"] = consumed
	
	# 6. current_hp から直接消費（新システム）
	if remaining_damage > 0:
		current_hp -= remaining_damage
		damage_breakdown["current_hp_consumed"] = remaining_damage
	
	# update_current_hp() は呼ばない
	# current_hp が状態値になったため、計算値ではなくなる
	
	# 💰 魔力獲得処理
	_trigger_magic_from_damage(damage)
	
	return damage_breakdown
```

**重要な変更点**:
- ボーナス消費ロジックは変わらない
- base_hp への操作 → current_hp への操作に変更
- `update_current_hp()` 呼び出しを削除
- damage_breakdown の "base_hp_consumed" → "current_hp_consumed" に変更

---

#### 1-3. take_mhp_damage() メソッドの修正

**ファイル**: `scripts/battle/battle_participant.gd`

**変更内容**:

```gdscript
# 変更前
func take_mhp_damage(damage: int) -> void:
	print("【MHPダメージ】", creature_data.get("name", "?"), " MHPに-", damage)
	
	# base_hpから消費（base_up_hp は永続ボーナスのため削らない）
	if damage > 0:
		base_hp -= damage
		print("  base_hp: -", damage, " (残り:", base_hp, ")")
	
	# 現在HPを再計算
	update_current_hp()
	
	# MHPが0以下になった場合は即死フラグを立てる
	var current_mhp = base_hp + base_up_hp
	if current_mhp <= 0:
		print("  → MHP=", current_mhp, " 即死発動")
		base_hp = 0
		base_up_hp = 0
		update_current_hp()
	else:
		print("  → 現在HP:", current_hp, " / MHP:", current_mhp)

# 変更後
func take_mhp_damage(damage: int) -> void:
	print("【MHPダメージ】", creature_data.get("name", "?"), " MHPに-", damage)
	
	# MHPを計算
	var current_mhp = base_hp + base_up_hp
	var new_mhp = current_mhp - damage
	
	# 削られたダメージ分を current_hp から消費
	if damage > 0:
		current_hp -= damage
		print("  current_hp: -", damage, " (残り:", current_hp, ")")
	
	# MHPが0以下になった場合は即死
	if new_mhp <= 0:
		print("  → MHP=", new_mhp, " 即死発動")
		current_hp = 0
		print("  → 現在HP:", current_hp, " / MHP: 0")
	else:
		print("  → 現在HP:", current_hp, " / MHP:", new_mhp)
```

**重要な変更点**:
- MHPの計算は同じ（base_hp + base_up_hp）
- base_hp への操作 → current_hp への操作に変更
- `update_current_hp()` 呼び出しを削除

---

#### 1-4. update_current_hp() メソッドの廃止

**ファイル**: `scripts/battle/battle_participant.gd`

**変更内容**:

```gdscript
# 変更前
func update_current_hp():
	current_hp = base_hp + base_up_hp + temporary_bonus_hp + \
				 resonance_bonus_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp

# 変更後：削除
# 廃止理由：current_hp が状態値になったため、計算値ではなくなる
# current_hp は直接ダメージを受ける値になるため、再計算の必要がない
```

**代替案（必要に応じて）**:
- UI表示用の参考メソッドとして残す必要があれば、別途検討

---

#### 1-5. get_max_hp() メソッド

**ファイル**: `scripts/battle/battle_participant.gd`

**変更内容**:

```gdscript
# 変更なし（base_hp と base_up_hp は固定値のため）
func get_max_hp() -> int:
	return base_hp + base_up_hp
```

**理由**: base_hp と base_up_hp が定数値になったため、計算は変わらない

---

### 2. battle_preparation.gd

**ファイル**: `scripts/battle/battle_preparation.gd`

**変更内容**:

#### 変更前

```gdscript
# 攻撃側の準備
var attacker_base_only_hp = card_data.get("hp", 0)
var attacker_max_hp = attacker_base_only_hp + attacker.base_up_hp
var attacker_current_hp = card_data.get("current_hp", attacker_max_hp)

# base_hpに現在HPから永続ボーナスを引いた値を設定
attacker.base_hp = attacker_current_hp - attacker.base_up_hp

# current_hpを再計算
attacker.update_current_hp()

# 防御側の準備（同様）
var defender_base_only_hp = defender_creature.get("hp", 0)
var defender_max_hp = defender_base_only_hp + defender.base_up_hp
var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)

defender.base_hp = defender_current_hp - defender.base_up_hp

defender.update_current_hp()
```

#### 変更後

```gdscript
# 攻撃側の準備
var attacker_max_hp = card_data.get("hp", 0) + attacker.base_up_hp
var attacker_current_hp = card_data.get("current_hp", attacker_max_hp)

# current_hp を直接設定
attacker.current_hp = attacker_current_hp
# base_hp と base_up_hp はコンストラクタで既に固定値化されている

# 防御側の準備（同様）
var defender_max_hp = defender_creature.get("hp", 0) + defender.base_up_hp
var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)

# current_hp を直接設定
defender.current_hp = defender_current_hp
# base_hp と base_up_hp はコンストラクタで既に固定値化されている
```

**重要な変更点**:
- base_hp の計算を削除
- current_hp を直接設定
- update_current_hp() 呼び出しを削除
- コード行数が削減される

---

### 3. バトル後のHP保存

**ファイル**: 
- `scripts/battle/battle_special_effects.gd`
- `scripts/battle_system.gd`

**変更内容**:

#### 変更前

```gdscript
# battle_special_effects.gd
creature_data["current_hp"] = defender.base_hp + defender.base_up_hp

# battle_system.gd
placement_data["current_hp"] = attacker.base_hp + attacker.base_up_hp
```

#### 変更後

```gdscript
# battle_special_effects.gd
creature_data["current_hp"] = defender.current_hp

# battle_system.gd
placement_data["current_hp"] = attacker.current_hp
```

**重要な変更点**:
- 計算を削除
- current_hp をそのまま保存（シンプル化）

---

### 4. その他の参照確認

**ファイル**: `scripts/battle/battle_execution.gd`

**確認内容**:
- ダメージ集計時の `damage_breakdown` 参照を "current_hp_consumed" に変更
- その他のbattle_*.gd ファイルで `base_hp` を直接参照していないか確認

**変更箇所例**:

```gdscript
# 変更前
var actual_damage_dealt = (
	damage_breakdown.get("resonance_bonus_consumed", 0) +
	damage_breakdown.get("land_bonus_consumed", 0) +
	damage_breakdown.get("temporary_bonus_consumed", 0) +
	damage_breakdown.get("item_bonus_consumed", 0) +
	damage_breakdown.get("spell_bonus_consumed", 0) +
	damage_breakdown.get("base_hp_consumed", 0)
)

# 変更後
var actual_damage_dealt = (
	damage_breakdown.get("resonance_bonus_consumed", 0) +
	damage_breakdown.get("land_bonus_consumed", 0) +
	damage_breakdown.get("temporary_bonus_consumed", 0) +
	damage_breakdown.get("item_bonus_consumed", 0) +
	damage_breakdown.get("spell_bonus_consumed", 0) +
	damage_breakdown.get("current_hp_consumed", 0)
)
```

---

## 修正手順

### ステップ1: BattleParticipant クラスの修正

1. `scripts/battle/battle_participant.gd` を開く
2. 以下のメソッドを修正：
   - コンストラクタ：update_current_hp() 呼び出しを削除
   - take_damage()：base_hp → current_hp に変更
   - take_mhp_damage()：base_hp → current_hp に変更
   - update_current_hp()：廃止
3. get_max_hp()：変更なし（確認のみ）

**推定時間**: 30分

---

### ステップ2: battle_preparation.gd の修正

1. `scripts/battle/battle_preparation.gd` を開く
2. prepare_participants() メソッドを修正：
   - base_hp 計算を削除
   - current_hp を直接設定
   - update_current_hp() 呼び出しを削除
3. 攻撃側・防御側両方を修正

**推定時間**: 20分

---

### ステップ3: バトル後処理の修正

1. `scripts/battle/battle_special_effects.gd` を開く
2. update_defender_hp() メソッドを修正：
   - creature_data["current_hp"] = defender.current_hp に変更

1. `scripts/battle/battle_system.gd` を開く
2. _apply_post_battle_effects() メソッドを修正：
   - placement_data["current_hp"] = attacker.current_hp に変更

**推定時間**: 15分

---

### ステップ4: ダメージ集計の修正

1. `scripts/battle/battle_execution.gd` を開く
2. execute_attack_sequence() メソッド内のダメージ集計部分を修正：
   - damage_breakdown.get("base_hp_consumed", 0) → damage_breakdown.get("current_hp_consumed", 0) に変更

**推定時間**: 15分

---

### ステップ5: 全スクリプトの確認

1. 以下のファイルで `base_hp` の直接参照を確認：
   - `scripts/battle/battle_skill_processor.gd`
   - `scripts/battle/skills/*.gd`
   - その他バトル関連ファイル

2. 不正な参照や計算がないか確認

**推定時間**: 30分

---

### ステップ6: テスト実行

1. バトルテストツール（battle_test_executor.gd）で動作確認
2. 各ダメージシナリオでテスト実行

**推定時間**: 1時間

---

## テスト項目

### 基本動作

- [ ] バトル開始時に current_hp が正しく初期化される
- [ ] バトル中のダメージが current_hp から直接削られる
- [ ] 各種ボーナスが正しく消費される
- [ ] ボーナス消費後に current_hp から削られる

### HP管理

- [ ] get_max_hp() が正しい値を返す
- [ ] is_alive() が current_hp > 0 で正しく判定される
- [ ] is_damaged() が正しく判定される
- [ ] get_hp_ratio() が正しく計算される

### ダメージ処理

- [ ] 通常ダメージが current_hp から削られる
- [ ] 反射ダメージが current_hp から削られる
- [ ] 雪辱ダメージ(MHP直接)が current_hp から削られる
- [ ] damage_breakdown が正しく記録される

### 戦闘終了処理

- [ ] バトル終了時の HP 保存が current_hp をそのまま保存する
- [ ] 保存された current_hp が次のバトル開始時に正しく復元される
- [ ] スタート通過時の HP 回復が正しく機能する

### 特殊スキル

- [ ] 再生スキルが base_hp + base_up_hp までしか回復しない
- [ ] 永続バフが正しく機能する
- [ ] 先制・後手判定が正しく機能する

### UI表示

- [ ] HP表示が current_hp を表示する
- [ ] MHP表示が base_hp + base_up_hp を表示する
- [ ] ダメージログが正しく記録される

---

## ドキュメント更新項目

修正完了後、以下のドキュメントを更新する必要があります：

### 1. hp_structure.md

- [ ] HP計算式を更新
- [ ] BattleParticipant の構造を更新
- [ ] ダメージ消費順序の説明を更新
- [ ] バトル時のHP計算をシンプルに説明

### 2. effect_system_design.md

- [ ] HP/AP管理構造を更新
- [ ] ダメージ消費順序の説明を更新

### 3. battle_system.md

- [ ] BattleParticipant と HP管理の説明を更新
- [ ] ダメージ消費順序を更新

### 4. on_death_effects.md

- [ ] MHPダメージの説明を確認・更新

### 5. 新規ドキュメント

- [ ] このリファクタリング計画ドキュメントの完了報告書を作成

---

## 実装ステータス

| 項目 | ステータス | 担当 | 開始 | 完了 |
|------|-----------|------|------|------|
| BattleParticipant 修正 | ⬜ 未開始 | - | - | - |
| battle_preparation.gd 修正 | ⬜ 未開始 | - | - | - |
| バトル後処理修正 | ⬜ 未開始 | - | - | - |
| ダメージ集計修正 | ⬜ 未開始 | - | - | - |
| スクリプト全体確認 | ⬜ 未開始 | - | - | - |
| テスト実行 | ⬜ 未開始 | - | - | - |
| ドキュメント更新 | ⬜ 未開始 | - | - | - |

---

## 注意事項・リスク

### 1. 大規模な変更

- このリファクタリングは HP 管理の根本的な変更
- 修正漏れがあるとバグの原因になる
- 十分なテストが必要

### 2. 破壊的変更

- 既存のコードロジックが大きく変わる
- デバッグ時に混乱の可能性あり
- コメント記載と一貫性を保つ必要

### 3. パフォーマンス

- update_current_hp() の削除により、計算量が削減（向上）
- ただし、UI表示時に計算が必要な場合は検討要

### 4. 段階的な移行

- 一度にすべてを修正するのではなく、段階的に進めることを推奨
- 各ステップでテストを実行

---

## 参考資料

- 現在のHP構造：`docs/design/hp_structure.md`
- 効果システム：`docs/design/effect_system_design.md`
- バトルシステム：`docs/design/battle_system.md`

---

**最終更新**: 2025年11月17日（v1.0）
