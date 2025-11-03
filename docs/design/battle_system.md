# 🎮 バトルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**最終更新**: 2025年10月25日

---

## 📋 目次

1. [バトルフロー全体](#バトルフロー全体)
2. [BattleParticipantとHP管理](#battleparticipantとhp管理)
3. [スキル適用順序](#スキル適用順序)
4. [土地ボーナスシステム](#土地ボーナスシステム)
5. [先制・後手判定](#先制後手判定)
6. [バトル結果判定](#バトル結果判定)
7. [関連ファイル](#関連ファイル)

---

## バトルフロー全体

### 概要フロー

```
1. カード選択＆コスト支払い
   ↓
2. 攻撃側アイテムフェーズ（任意）
   ↓
3. 防御側アイテムフェーズ（任意）
   ↓
4. アイテム効果適用
   ↓
5. 攻撃側土地ボーナス（属性一致時）
   ↓
6. スキル条件チェック（adjacent_ally_land等）
   ↓
7. 先制攻撃: 攻撃側AP vs 防御側HP
   ↓
8. 反撃: 防御側ST vs 攻撃側HP（生存時）
   ↓
9. 結果判定
```

### 詳細フロー（スキル適用含む）

```
0. 変身スキル適用 (apply_battle_start_transform) 【Phase 0】
   ├─ 戦闘開始時に発動する変身スキルをチェック
   ├─ 攻撃側・防御側の両方に適用
   └─ 詳細: skills/transform_skill.md 参照
   
1. 応援スキル適用 (apply_support_skills_to_all) 【Phase 1】
   ├─ 盤面の応援持ちクリーチャーを取得
   ├─ 条件を満たすバトル参加者にバフ付与
   └─ 動的ボーナス（隣接自領地数）を計算
   
2. 巻物攻撃判定 (check_scroll_attack)
   ├─ 巻物攻撃 or 巻物強打スキルをチェック
   ├─ 巻物強打の場合は感応を適用
   └─ 通常巻物攻撃の場合は感応をスキップ

3. 感応スキル (apply_resonance_skill)
   ├─ 特定属性土地所有でAP/HP上昇
   └─ 巻物強打の場合は適用、通常巻物攻撃の場合はスキップ

4. 土地数比例効果 (apply_land_count_effects)
   ├─ プレイヤーの土地所有状況を確認
   ├─ 条件を満たせばAPとHPを上昇
   └─ resonance_bonus_hpフィールドに加算
   
5. 強打スキル (apply_power_strike)
   ├─ 感応適用後のAPを基準に計算
   ├─ 条件を満たせばAPを増幅
   └─ 例: 基本20 → 感応+30=50 → 強打×1.5=75
   
6. 2回攻撃判定 (_check_double_attack)
   ├─ 2回攻撃スキル保持チェック
   └─ attack_count = 2 に設定
   
7. 攻撃シーケンス (_execute_attack_sequence)
   ├─ 攻撃順決定（先制・後手判定）
   ├─ 各攻撃ごとにダメージ適用
   └─ **攻撃後に即死判定** (_check_instant_death)
	  ├─ 即死スキル保持チェック
	  ├─ 条件判定（属性、ST、立場など）
	  ├─ 確率判定
	  └─ 成功時: instant_death_flag = true, HP = 0
   
8. バトル結果判定 (_resolve_battle_result)
   ├─ HPチェック
   └─ 勝敗決定
   
9. バトル後処理 (_apply_post_battle_effects)
   ├─ 再生スキル適用（生存者のみ）
   │  └─ HP > 0 の場合のみ発動
   ├─ 土地奪取 or カード破壊 or 手札復帰
   └─ クリーチャーHP更新
```

**注**: 不屈スキルはバトル処理とは独立して動作し、アクション後のダウン判定時に適用される。バトルフロー内では関与しない。

---

## BattleParticipantとHP管理

### BattleParticipantクラス

**役割**: バトル参加者のステータスとHP管理を担当

**実装場所**: `scripts/battle_participant.gd`

### HPの階層構造

```gdscript
{
  base_hp: int              # クリーチャーの基本HP（最後に消費）
  resonance_bonus_hp: int   # 感応ボーナス（優先消費）
  land_bonus_hp: int        # 土地ボーナス（2番目に消費）
  item_bonus_hp: int        # アイテムボーナス（将来実装）
  spell_bonus_hp: int       # スペルボーナス（将来実装）
  current_hp: int           # 表示HP（全ての合計）
}
```

### ダメージ消費順序

1. **感応ボーナス** (`resonance_bonus_hp`) - 最優先で消費
2. **土地ボーナス** (`land_bonus_hp`) - 戦闘ごとに復活
3. **アイテムボーナス** (`item_bonus_hp`) - 将来実装
4. **スペルボーナス** (`spell_bonus_hp`) - 将来実装
5. **基本HP** (`base_hp`) - 最後に消費

### 設計思想

- **一時的なボーナスを先に消費**し、クリーチャーの本来のHPを守る
- **感応ボーナス**: 最も一時的（バトル限定）なため、最優先消費
- **土地ボーナス**: 戦闘ごとに復活するため、次に消費
- **基本HP**: 減ると配置クリーチャーの永続的なダメージとなる

### ダメージ処理の実装

```gdscript
func take_damage(damage: int) -> Dictionary:
	var remaining_damage = damage
	var damage_breakdown = {
		"resonance_bonus_consumed": 0,
		"land_bonus_consumed": 0,
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
	
	# 3. アイテムボーナス（将来実装）
	# 4. スペルボーナス（将来実装）
	
	# 5. 基本HPから消費
	if remaining_damage > 0:
		base_hp -= remaining_damage
		damage_breakdown["base_hp_consumed"] = remaining_damage
	
	# 現在HPを更新
	update_current_hp()
	
	return damage_breakdown
```

### 主要メソッド

```gdscript
# 合計HPを再計算
func update_current_hp():
	current_hp = base_hp + resonance_bonus_hp + land_bonus_hp + 
				 item_bonus_hp + spell_bonus_hp

# ダメージ処理（消費順序に従う）
func take_damage(damage: int) -> Dictionary

# 生存判定
func is_alive() -> bool:
	return current_hp > 0

# デバッグ用ステータス表示
func get_status_string() -> String:
	return "%s (HP:%d/%d, AP:%d)" % [
		creature_data.get("name", "不明"),
		current_hp,
		base_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp,
		current_ap
	]
```

### 使用例

```gdscript
# 1. 参加者作成
var attacker = BattleParticipant.new(
	card_data,      # クリーチャーデータ
	base_hp,        # 基本HP
	land_bonus,     # 土地ボーナスHP
	ap,             # 攻撃力
	true,           # is_attacker
	player_id       # プレイヤーID
)

# 2. スキル適用
attacker.resonance_bonus_hp += 30  # 感応ボーナス追加
attacker.update_current_hp()       # 合計HP再計算

# 3. ダメージ処理
var breakdown = attacker.take_damage(50)
# → 感応(30) → 土地(20) → 基本HP(0) の順で消費

# 4. 結果表示
print("  - 感応ボーナス: ", breakdown["resonance_bonus_consumed"], " 消費")
print("  - 土地ボーナス: ", breakdown["land_bonus_consumed"], " 消費")
print("  - 基本HP: ", breakdown["base_hp_consumed"], " 消費")
print("  → 残HP: ", attacker.current_hp)
```

---

## スキル適用順序

### 相乗効果の設計思想

この順序により、複数スキルを持つクリーチャーは相乗効果を得られる。

**例: 感応+強打の組み合わせ**
```
モルモ（感応[火]+30、強打×1.5を仮定）

基本AP: 20
  ↓ 感応発動（火土地1個所有）
AP: 50 (+30)
  ↓ 強打発動（隣接自領地あり）
AP: 75 (×1.5)

→ 最終的にAP: 75で攻撃！
```

この設計により、感応で上昇したAPが強打の基準値となり、大きな戦力増強が可能。

詳細な個別スキル仕様は **[skills_design.md](skills_design.md)** を参照。

---

## 土地ボーナスシステム

### 計算式

```
土地ボーナスHP = land_level × 10
```

### 適用条件

- **クリーチャーの属性** = **タイルの属性** のときのみ適用
- 例: 火属性クリーチャーが火属性タイルにいる

### 保存場所

- `land_bonus_hp` フィールドに独立して保存
- 基本HPとは分離管理

### 特殊ルール

- **貫通スキル**: 相手の土地ボーナスを無効化可能
- **戦闘ごとに復活**: 次のバトルでは再度適用される

詳細は **[land_system.md](land_system.md)** を参照。

---

## 先制・後手判定

### 判定順序

1. **先制スキル保持者**が先攻
2. **後手スキル保持者**が後攻
3. 両方なし → **攻撃側が先攻**（デフォルト）
4. 両方あり → 打ち消し合い → **攻撃側が先攻**

### 実装

```gdscript
func _determine_attack_order(attacker: BattleParticipant, defender: BattleParticipant) -> String:
	var attacker_has_first = attacker.has_first_strike
	var attacker_has_last = attacker.has_last_strike
	var defender_has_first = defender.has_first_strike
	var defender_has_last = defender.has_last_strike
	
	# 攻撃側が先制 && 防御側が後手でない
	if attacker_has_first and not defender_has_first:
		return "attacker_first"
	
	# 防御側が先制 && 攻撃側が後手でない
	if defender_has_first and not attacker_has_last:
		return "defender_first"
	
	# デフォルト: 攻撃側先攻
	return "attacker_first"
```

---

## バトル結果判定

### 結果の種類

バトル結果は以下の4種類に分類される：

| 結果 | enum値 | 説明 |
|------|--------|------|
| **侵略成功** | `ATTACKER_WIN` | 防御側のみ死亡 → 攻撃側が土地を獲得 |
| **防御成功** | `DEFENDER_WIN` | 攻撃側のみ死亡 → 攻撃側カードは破壊 |
| **侵略失敗** | `ATTACKER_SURVIVED` | 両方生存 → 攻撃側カードは手札に戻る |
| **相打ち** | `BOTH_DEFEATED` | 両方死亡 → 土地は無所有になる |

### 判定ロジック

```gdscript
func resolve_battle_result(attacker: BattleParticipant, defender: BattleParticipant) -> int:
	# 1. 両方死亡 → 相打ち（土地は無所有）
	if not attacker.is_alive() and not defender.is_alive():
		return BOTH_DEFEATED
	
	# 2. 防御側のみ死亡 → 攻撃側勝利
	elif not defender.is_alive():
		return ATTACKER_WIN
	
	# 3. 攻撃側のみ死亡 → 防御側勝利
	elif not attacker.is_alive():
		return DEFENDER_WIN
	
	# 4. 両方生存 → 攻撃側生還
	else:
		return ATTACKER_SURVIVED
```

### 死亡時効果（道連れ・雪辱）

**重要**: バトル結果判定の前に、死亡時効果が発動する。

#### 発動タイミング

```
攻撃実行
  ↓
ダメージ処理
  ↓
即死判定
  ↓
【撃破判定】← ここで死亡時効果をチェック
  ├─ 道連れ（instant_death）
  └─ 雪辱（revenge_mhp_damage）
  ↓
死者復活チェック
  ↓
バトル結果判定 ← ここで最終的な生存状況を判定
```

#### 死亡時効果の種類

| 効果 | effect_type | 説明 |
|------|-------------|------|
| **道連れ** | `instant_death` | 使用者が死亡時、相手を即死させる（確率判定あり） |
| **雪辱** | `revenge_mhp_damage` | 使用者が死亡時、相手のMHPに直接ダメージ |

詳細は **[skills/on_death_effects.md](skills/on_death_effects.md)** を参照。

#### 相打ちの発生パターン

1. **道連れによる相打ち**
   - A攻撃 → B死亡 → 道連れ発動 → A死亡 → 相打ち

2. **雪辱による相打ち**
   - A攻撃 → B死亡 → 雪辱発動 → AのMHP-40 → A即死 → 相打ち

3. **反射による相打ち**
   - A攻撃 → B死亡 → 反射ダメージ → A死亡 → 相打ち

### バトル後処理

各結果に応じた処理：

#### ATTACKER_WIN（侵略成功）
1. 破壊カウンター更新
2. 攻撃側の永続バフ適用
3. 土地所有権を攻撃側に変更
4. 攻撃側クリーチャーを配置（残りHP反映）
5. 土地レベルアップ効果（シルバープロウ）

#### DEFENDER_WIN（防御成功）
1. 破壊カウンター更新
2. 防御側の永続バフ適用
3. 防御側クリーチャーのHP更新
4. 土地レベルアップ効果（シルバープロウ）
5. 攻撃側カードは破壊（手札に戻らない）

#### ATTACKER_SURVIVED（侵略失敗）
1. 攻撃側カードを手札に戻す（HP全回復）
2. 防御側クリーチャーのHP更新

#### BOTH_DEFEATED（相打ち）
1. 破壊カウンター更新×2
2. 両方の永続バフ適用
3. 土地を無所有にする（owner = -1）
4. クリーチャーを削除
5. 両方のカードは破壊（手札に戻らない）
3. **クリーチャーHP更新**

---

## 関連ファイル

### 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/battle_system.gd` | バトルシステムメインロジック |
| `scripts/battle_participant.gd` | BattleParticipantクラス |
| `scripts/skills/condition_checker.gd` | スキル条件判定 |
| `scripts/skills/effect_combat.gd` | スキル効果適用 |
| `scripts/battle/battle_preparation.gd` | バトル前準備（アイテム適用等） |

### 設計ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| **[skills_design.md](skills_design.md)** | スキルシステム全体設計 |
| **[land_system.md](land_system.md)** | 土地システム・土地ボーナス |
| **[item_system.md](item_system.md)** | アイテムシステム・アイテムフェーズ |

---

**最終更新**: 2025年10月25日（v1.0）
