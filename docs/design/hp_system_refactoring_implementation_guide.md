# current_hp 直接削るシステムへの移行 - 実装詳細ガイド

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年11月17日  
**目的**: リファクタリング実装時の詳細なコード例と確認項目

---

## 📋 目次

1. [実装の詳細コード](#実装の詳細コード)
2. [修正時の確認チェックリスト](#修正時の確認チェックリスト)
3. [トラブルシューティング](#トラブルシューティング)
4. [参考：修正前後の比較](#参考修正前後の比較)

---

## 実装の詳細コード

### 1. BattleParticipant - コンストラクタ修正

#### 確認項目

```gdscript
# 修正前：update_current_hp() の呼び出しがある
func _init(...):
    # ...初期化
    update_current_hp()  # ← この行を削除

# 修正後：update_current_hp() を呼ばない
func _init(...):
    # ...初期化
    # update_current_hp() は呼ばない
    # current_hp はコンストラクタ後に battle_preparation.gd で設定される
```

#### 実装チェック

- [ ] update_current_hp() 呼び出しが削除されている
- [ ] コンストラクタの他の初期化処理は残っている
- [ ] コメントが追加されている

---

### 2. BattleParticipant - take_damage() 修正

#### 完全な実装例

```gdscript
# ダメージを受ける（消費順序に従う）
func take_damage(damage: int) -> Dictionary:
	# 敵から攻撃を受けたフラグを設定（バイロマンサー用）
	was_attacked_by_enemy = true
	
	var remaining_damage = damage
	var damage_breakdown = {
		"resonance_bonus_consumed": 0,
		"land_bonus_consumed": 0,
		"temporary_bonus_consumed": 0,
		"item_bonus_consumed": 0,
		"spell_bonus_consumed": 0,
		"current_hp_consumed": 0  # 変更：base_hp_consumed → current_hp_consumed
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
		current_hp -= remaining_damage  # 変更：base_hp -= を current_hp -= に
		damage_breakdown["current_hp_consumed"] = remaining_damage
	
	# 変更：update_current_hp() を呼ばない
	# 理由：current_hp が状態値になったため、計算値ではなくなる
	
	# 💰 魔力獲得処理（ゼラチンアーマー: 受けたダメージから魔力獲得）
	_trigger_magic_from_damage(damage)
	
	return damage_breakdown
```

#### 実装チェック

- [ ] resonance_bonus_consumed から spell_bonus_consumed までのロジックは変わっていない
- [ ] base_hp -= remaining_damage が current_hp -= remaining_damage に変更されている
- [ ] damage_breakdown["base_hp_consumed"] が damage_breakdown["current_hp_consumed"] に変更されている
- [ ] update_current_hp() の呼び出しが削除されている
- [ ] _trigger_magic_from_damage() は残っている

---

### 3. BattleParticipant - take_mhp_damage() 修正

#### 完全な実装例

```gdscript
# MHP範囲に直接ダメージ（雪辱効果用）
# ボーナスを無視してMHP（base_hp + base_up_hp）を直接削る
# MHPが0以下になった場合は即死扱い
func take_mhp_damage(damage: int) -> void:
	print("【MHPダメージ】", creature_data.get("name", "?"), " MHPに-", damage)
	
	# MHPを計算（base_hp と base_up_hp は定数値）
	var current_mhp = base_hp + base_up_hp
	var new_mhp = current_mhp - damage
	
	# 削られたダメージ分を current_hp から消費
	if damage > 0:
		current_hp -= damage  # 変更：base_hp -= から current_hp -= に
		print("  current_hp: -", damage, " (残り:", current_hp, ")")  # ログも更新
	
	# MHPが0以下になった場合は即死
	if new_mhp <= 0:
		print("  → MHP=", new_mhp, " 即死発動")
		current_hp = 0  # 変更：base_hp = 0, base_up_hp = 0 から current_hp = 0 に
		print("  → 現在HP:", current_hp, " / MHP: 0")
	else:
		print("  → 現在HP:", current_hp, " / MHP:", new_mhp)
```

#### 実装チェック

- [ ] MHPの計算方法は変わっていない（base_hp + base_up_hp）
- [ ] base_hp -= damage が current_hp -= damage に変更されている
- [ ] update_current_hp() の呼び出しが削除されている
- [ ] 即死時の base_hp = 0, base_up_hp = 0 が current_hp = 0 に変更されている
- [ ] ログ出力が current_hp を参照するように更新されている

---

### 4. BattleParticipant - update_current_hp() 削除

#### 実装チェック

```gdscript
# 削除する関数
# 変更前
func update_current_hp():
	current_hp = base_hp + base_up_hp + temporary_bonus_hp + \
				 resonance_bonus_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp

# 変更後：この関数全体を削除
# （削除）

# ただし、参照している箇所をすべて削除することを確認する必要あり
```

#### 参照確認

```gdscript
# 以下の箇所で update_current_hp() が呼ばれていないか確認
grep -n "update_current_hp" scripts/battle/*.gd

# 削除すべき呼び出し例：
take_damage() の最後
take_mhp_damage() の最後
コンストラクタ
他のメソッド
```

---

### 5. battle_preparation.gd - prepare_participants() 修正

#### 完全な実装例

```gdscript
## 両者のBattleParticipantを準備
func prepare_participants(...) -> Dictionary:
	# 侵略側の準備（土地ボーナスなし）
	var attacker_base_hp = card_data.get("hp", 0)
	var attacker_land_bonus = 0
	var attacker_ap = card_data.get("ap", 0)
	
	var attacker = BattleParticipant.new(
		card_data,
		attacker_base_hp,
		attacker_land_bonus,
		attacker_ap,
		true,
		attacker_index
	)
	
	# SpellMagic参照を設定
	attacker.spell_magic_ref = spell_magic_ref
	
	# base_up_hpを設定
	attacker.base_up_hp = card_data.get("base_up_hp", 0)
	attacker.base_up_ap = card_data.get("base_up_ap", 0)
	
	# 変更：base_hp の計算を削除し、current_hp を直接設定
	var attacker_max_hp = attacker_base_hp + attacker.base_up_hp
	var attacker_current_hp = card_data.get("current_hp", attacker_max_hp)
	
	# current_hp を直接設定（新システム）
	attacker.current_hp = attacker_current_hp
	
	# 変更前の処理は削除
	# attacker.base_hp = attacker_current_hp - attacker.base_up_hp
	# attacker.update_current_hp()
	
	# 防御側の準備（土地ボーナスあり）
	var defender_creature = tile_info.get("creature", {})
	var defender_base_hp = defender_creature.get("hp", 0)
	var defender_land_bonus = calculate_land_bonus(defender_creature, tile_info)
	
	# 貫通スキルチェック
	if PenetrationSkill.check_penetration_condition(card_data, defender_creature):
		print("【貫通発動】防御側の土地ボーナス ", defender_land_bonus, " を無効化")
		defender_land_bonus = 0
	
	var defender_ap = defender_creature.get("ap", 0)
	var defender_owner = tile_info.get("owner", -1)
	
	var defender = BattleParticipant.new(
		defender_creature,
		defender_base_hp,
		defender_land_bonus,
		defender_ap,
		false,
		defender_owner
	)
	
	# SpellMagic参照を設定
	defender.spell_magic_ref = spell_magic_ref
	
	# base_up_hpとbase_up_apを設定
	defender.base_up_hp = defender_creature.get("base_up_hp", 0)
	defender.base_up_ap = defender_creature.get("base_up_ap", 0)
	
	# 変更：base_hp の計算を削除し、current_hp を直接設定
	var defender_max_hp = defender_base_hp + defender.base_up_hp
	var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)
	
	# current_hp を直接設定（新システム）
	defender.current_hp = defender_current_hp
	
	# 変更前の処理は削除
	# defender.base_hp = defender_current_hp - defender.base_up_hp
	# defender.update_current_hp()
	
	# 以下のコードは変わらない
	apply_effect_arrays(attacker, card_data)
	apply_effect_arrays(defender, defender_creature)
	# ...その他の処理
```

#### 実装チェック

- [ ] MHP計算は残っている（参照用）
- [ ] current_hp を直接設定する処理が追加されている
- [ ] base_hp の計算が削除されている
- [ ] update_current_hp() 呼び出しが削除されている
- [ ] 攻撃側・防御側両方が修正されている

---

### 6. バトル後処理 - HP保存修正

#### battle_special_effects.gd

```gdscript
## バトル終了後の防御側HP保存
func update_defender_hp(tile_info: Dictionary, defender: BattleParticipant) -> void:
	var tile_index = tile_info["index"]
	var creature_data = tile_info.get("creature", {}).duplicate()
	
	# 元のHPは触らない
	# creature_data["hp"] = そのまま（不変）
	
	# 永続ボーナスも触らない（既に入っている）
	# creature_data["base_up_hp"] = そのまま
	
	# 現在HPを保存（変更：シンプルに current_hp をそのまま保存）
	creature_data["current_hp"] = defender.current_hp  # 変更：base_hp + base_up_hp から削除
	
	# タイルのクリーチャーデータを更新
	board_system_ref.tile_data_manager.tile_nodes[tile_index].creature_data = creature_data
	
	print("[HP保存] ", creature_data.get("name", ""), 
		  " 現在HP:", creature_data["current_hp"], 
		  " / MHP:", creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0))
```

#### battle_system.gd

```gdscript
## 侵略成功時のHP保存
func _apply_post_battle_effects(...):
	# 侵略成功時
	var placement_data = attacker.creature_data.duplicate(true)
	
	# 元のHPは触らない
	# placement_data["hp"] = そのまま
	
	# 現在HPを保存（変更：シンプルに current_hp をそのまま保存）
	placement_data["current_hp"] = attacker.current_hp  # 変更：base_hp + base_up_hp から削除
	
	board_system_ref.place_creature(tile_index, placement_data)
	
	print("[HP保存] ", placement_data.get("name", ""), 
		  " 現在HP:", placement_data["current_hp"], 
		  " / MHP:", placement_data.get("hp", 0) + placement_data.get("base_up_hp", 0))
```

#### 実装チェック

- [ ] creature_data["current_hp"] = defender.current_hp に変更されている
- [ ] base_hp + base_up_hp の計算が削除されている
- [ ] ログ出力は MHP 計算のみ残っている

---

### 7. ダメージ集計修正 - battle_execution.gd

#### 実装例

```gdscript
# ダメージ集計時の修正箇所

# 変更前
var actual_damage_dealt = (
	damage_breakdown.get("resonance_bonus_consumed", 0) +
	damage_breakdown.get("land_bonus_consumed", 0) +
	damage_breakdown.get("temporary_bonus_consumed", 0) +
	damage_breakdown.get("item_bonus_consumed", 0) +
	damage_breakdown.get("spell_bonus_consumed", 0) +
	damage_breakdown.get("base_hp_consumed", 0)  # ← 変更
)

# 変更後
var actual_damage_dealt = (
	damage_breakdown.get("resonance_bonus_consumed", 0) +
	damage_breakdown.get("land_bonus_consumed", 0) +
	damage_breakdown.get("temporary_bonus_consumed", 0) +
	damage_breakdown.get("item_bonus_consumed", 0) +
	damage_breakdown.get("spell_bonus_consumed", 0) +
	damage_breakdown.get("current_hp_consumed", 0)  # 変更：base_hp_consumed → current_hp_consumed
)
```

#### 実装チェック

- [ ] base_hp_consumed が current_hp_consumed に変更されている
- [ ] 複数箇所ある場合（軽減処理など）、すべて修正されている
- [ ] ダメージ集計ロジックは変わっていない

---

## 修正時の確認チェックリスト

### Phase 1: BattleParticipant クラス修正

- [ ] コンストラクタの update_current_hp() 呼び出しを削除
- [ ] take_damage() で base_hp → current_hp に変更
- [ ] take_damage() で damage_breakdown キーを base_hp_consumed → current_hp_consumed に変更
- [ ] take_damage() の update_current_hp() 呼び出しを削除
- [ ] take_mhp_damage() で base_hp → current_hp に変更
- [ ] take_mhp_damage() の update_current_hp() 呼び出しを削除
- [ ] take_mhp_damage() で base_hp = 0, base_up_hp = 0 → current_hp = 0 に変更
- [ ] update_current_hp() メソッド全体を削除
- [ ] 削除時に他の場所で呼ばれていないか確認

### Phase 2: battle_preparation.gd 修正

- [ ] 攻撃側：base_hp 計算を削除
- [ ] 攻撃側：current_hp を直接設定
- [ ] 攻撃側：update_current_hp() 呼び出しを削除
- [ ] 防御側：base_hp 計算を削除
- [ ] 防御側：current_hp を直接設定
- [ ] 防御側：update_current_hp() 呼び出しを削除

### Phase 3: バトル後処理修正

- [ ] battle_special_effects.gd：creature_data["current_hp"] = defender.current_hp に変更
- [ ] battle_system.gd：placement_data["current_hp"] = attacker.current_hp に変更

### Phase 4: ダメージ集計修正

- [ ] battle_execution.gd：damage_breakdown.get("base_hp_consumed") → damage_breakdown.get("current_hp_consumed") に変更
- [ ] 複数箇所あれば、すべて修正

### Phase 5: 全体確認

- [ ] grep で "base_hp_consumed" が残っていないか確認
- [ ] grep で "update_current_hp" が残っていないか確認（不要な呼び出し）
- [ ] コンパイルエラーなし
- [ ] 基本的なバトルテスト実行

---

## トラブルシューティング

### 問題1: コンパイルエラー「undefined reference」

**症状**: `update_current_hp()` が存在しないというエラー

**原因**: 削除後に呼び出し箇所が残っている

**解決**:
```bash
grep -rn "update_current_hp" scripts/battle/
```
で全箇所を探して削除

---

### 問題2: HP が正しく減らない

**症状**: ダメージを受けても HP が変わらない

**原因**: 
- take_damage() が base_hp ではなく current_hp を削るようにできていない
- ボーナス消費後に update_current_hp() が呼ばれていない（呼んではいけない）

**確認項目**:
```gdscript
# take_damage() の最後に以下が左かあることを確認
if remaining_damage > 0:
    current_hp -= remaining_damage  # ← これがあるか
```

---

### 問題3: 再生スキル等でHP回復がおかしい

**症状**: バトル終了後、再生スキルで HP が正しく回復しない

**原因**: HP 保存時に base_hp + base_up_hp を計算していたロジックが残っている

**解決**:
```gdscript
# バトル後処理で以下の形になっているか確認
creature_data["current_hp"] = defender.current_hp  # ← シンプルに

# 以下の形になっていないか確認
# creature_data["current_hp"] = defender.base_hp + defender.base_up_hp  # ← 削除すべき
```

---

### 問題4: MHP が計算されていない

**症状**: MHP 表示が 0 または異常な値

**原因**: base_hp が正しく初期化されていない

**確認項目**:
```gdscript
# BattleParticipant コンストラクタで base_hp が正しく設定されているか
var battle_participant = BattleParticipant.new(
    creature_data,
    base_hp,  # ← creature_data["hp"] が渡されているか
    land_bonus,
    ap,
    is_attacker,
    player_id
)
```

---

### 問題5: バトル終了後に HP が勝手に変わる

**症状**: バトル終了時に current_hp が自動的に計算されてしまう

**原因**: 別のシステムで update_current_hp() が呼ばれている、または current_hp を計算している

**確認項目**:
- battle_skill_processor.gd で current_hp を計算していないか
- battle_special_effects.gd で current_hp を計算していないか
- その他のバトル関連ファイル

---

## 参考：修正前後の比較

### ダメージフロー比較

```
【修正前】
1. 各ボーナスから消費
2. base_hp -= remaining_damage
3. update_current_hp()
   current_hp = base_hp + base_up_hp + ボーナス
4. current_hp を保存

【修正後】
1. 各ボーナスから消費
2. current_hp -= remaining_damage
3. update_current_hp() なし
4. current_hp をそのまま保存
```

### HP 初期化比較

```
【修正前】
var current_hp_from_data = card_data.get("current_hp", max_hp)
participant.base_hp = current_hp_from_data - participant.base_up_hp
participant.update_current_hp()

【修正後】
var current_hp_from_data = card_data.get("current_hp", max_hp)
participant.current_hp = current_hp_from_data
```

### バトル後 HP 保存比較

```
【修正前】
creature_data["current_hp"] = participant.base_hp + participant.base_up_hp

【修正後】
creature_data["current_hp"] = participant.current_hp
```

---

**最終更新**: 2025年11月17日（v1.0）
