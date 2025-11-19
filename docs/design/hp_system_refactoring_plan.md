# current_hp 直接削るシステムへの移行計画

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年11月17日  
**最終更新**: 2025年11月20日（v2.0 - バトル側実装計画を詳細化）  
**ステータス**: 設計・実装計画段階  
**目的**: HP管理構造を簡潔化し、current_hp を状態値として直接削るシステムへ移行

---

## 📋 目次

1. [現在のシステム](#現在のシステム)
2. [提案するシステム](#提案するシステム)
3. [データ構造の変更](#データ構造の変更)
4. [バトル側の実装計画](#バトル側の実装計画)
5. [マップ側の実装計画](#マップ側の実装計画)
6. [修正手順](#修正手順)
7. [テスト項目](#テスト項目)
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

## バトル側の実装計画

### 修正対象ファイル一覧

| ファイル | 行番号 | 修正内容 | 優先度 |
|---------|--------|--------|--------|
| scripts/battle/battle_participant.gd | 71 | コンストラクタの update_current_hp() 削除 | 🔴 高 |
| scripts/battle/battle_participant.gd | 150-152 | take_damage() の base_hp → current_hp 変更 | 🔴 高 |
| scripts/battle/battle_participant.gd | 155 | take_damage() の update_current_hp() 削除 | 🔴 高 |
| scripts/battle/battle_participant.gd | 240-241 | take_mhp_damage() の base_hp → current_hp 変更 | 🔴 高 |
| scripts/battle/battle_participant.gd | 244 | take_mhp_damage() の update_current_hp() 削除 | 🔴 高 |
| scripts/battle/battle_preparation.gd | 95-115 | prepare_participants() で current_hp を直接設定 | 🔴 高 |
| scripts/battle/battle_special_effects.gd | 355 | update_defender_hp() で current_hp 設定 | 🔴 高 |
| scripts/battle_system.gd | 296 | バトル成功時の current_hp 保存 | 🔴 高 |
| scripts/battle_system.gd | 363 | 移動侵略失敗時の current_hp 保存 | 🔴 高 |
| scripts/battle_system.gd | 440, 449, 458 | 永続変身・復活時の HP 処理 | 🟡 中 |
| scripts/battle/battle_execution.gd | 188, 304 | damage_breakdown の "base_hp_consumed" → "current_hp_consumed" | 🟡 中 |

### 1. BattleParticipant クラス

#### 1-1. コンストラクタ修正（71行目）

```gdscript
# 削除する行
update_current_hp()  # ← この行を削除

# 代わりに battle_preparation.gd で current_hp を直接設定
```

#### 1-2. take_damage() メソッド修正（150-155行目）

```gdscript
# 変更前
if remaining_damage > 0:
	base_hp -= remaining_damage
	damage_breakdown["base_hp_consumed"] = remaining_damage

# 現在HPを更新
update_current_hp()

# 変更後
if remaining_damage > 0:
	current_hp -= remaining_damage
	damage_breakdown["current_hp_consumed"] = remaining_damage

# update_current_hp() は呼ばない
```

#### 1-3. take_mhp_damage() メソッド修正（240-244行目）

```gdscript
# 変更前
if damage > 0:
	base_hp -= damage
	print("  base_hp: -", damage, " (残り:", base_hp, ")")

# 現在HPを再計算
update_current_hp()

# 変更後
if damage > 0:
	current_hp -= damage
	print("  current_hp: -", damage, " (残り:", current_hp, ")")

# update_current_hp() は呼ばない
```

**重要**: MHP計算は変わらない（`get_max_hp()` = `base_hp + base_up_hp`）

### 2. battle_preparation.gd

#### prepare_participants() メソッド修正（95-115行目）

```gdscript
# 変更前
# base_hpに現在HPから永続ボーナスを引いた値を設定
attacker.base_hp = attacker_current_hp - attacker.base_up_hp
attacker.update_current_hp()

# 変更後
# current_hp を直接設定
attacker.current_hp = attacker_current_hp
# base_hp と base_up_hp はコンストラクタで既に設定済み
```

同様に防御側も修正します。

### 3. battle_special_effects.gd

#### update_defender_hp() メソッド修正（355行目）

```gdscript
# 変更前
creature_data["current_hp"] = defender.base_hp + defender.base_up_hp

# 変更後
creature_data["current_hp"] = defender.current_hp
```

### 4. battle_system.gd

#### 侵略成功時（296行目）

```gdscript
# 変更前後は既に正しい
place_creature_data["current_hp"] = attacker.current_hp
```

#### 移動侵略失敗時（363行目）

```gdscript
# 変更前後は既に正しい
return_data["current_hp"] = attacker.current_hp
```

#### 永続変身・復活時（440, 449, 458行目）

**永続変身時（440行目）**
```gdscript
# 変更前
updated_creature["hp"] = defender.base_hp  # 現在のHPを保持

# 変更後
updated_creature["current_hp"] = defender.current_hp
# updated_creature["hp"] は新クリーチャーのベースHP（そのまま）
```

**復活時（449, 458行目）**
```gdscript
# 変更前
updated_creature["hp"] = defender.base_hp  # 復活後のHPを保持

# 変更後（HPを満タンに回復）
var mhp = updated_creature.get("hp", 0) + updated_creature.get("base_up_hp", 0)
updated_creature["current_hp"] = mhp
```

**重要**: 復活時は HP が満タンになる。creature_data には既に base_up_hp が含まれている（変身処理で保持）

### 5. battle_execution.gd

#### ダメージ集計部分（188, 304行目）

```gdscript
# 変更前
damage_breakdown.get("base_hp_consumed", 0)

# 変更後
damage_breakdown.get("current_hp_consumed", 0)
```

---

## マップ側の実装計画

### 修正対象ファイル一覧

| ファイル | 行番号 | 修正内容 | 優先度 |
|---------|--------|--------|--------|
| scripts/tiles/base_tiles.gd | 90-104 | place_creature() に current_hp 初期化を追加 | 🔴 高 |
| scripts/battle_system.gd | 536, 570 | マスグロース、ドミナントグロース時の current_hp 同期 | 🟡 中 |
| scripts/battle/land_action_helper.gd | 376, 381 | レベルアップ時の current_hp 同期 | 🟡 中 |
| scripts/battle/board_system_3d.gd | 432, 437 | 地形変化時の current_hp 同期 | 🟡 中 |
| scripts/battle/spell_land_new.gd | ? | スペル効果時の current_hp 同期 | 🟡 中 |

### 方針

**マップ側の base_up_hp 変更時は `effect_manager.gd` で一元管理する**

```gdscript
# effect_manager.gd に追加
func apply_max_hp_effect(creature_data: Dictionary, value: int) -> void:
	# 1. 古いMHPを計算
	var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
	
	# 2. base_up_hp を増加
	creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + value
	
	# 3. 新しいMHPを計算
	var new_mhp = creature_data.get("hp", 0) + creature_data["base_up_hp"]
	
	# 4. current_hp も増加（MHP増加分を反映、上限を超えない）
	if creature_data.has("current_hp"):
		creature_data["current_hp"] += (new_mhp - old_mhp)
		# MHP上限を超えないようにクランプ
		creature_data["current_hp"] = min(creature_data["current_hp"], new_mhp)
```

**各修正箇所で使用例**:
```gdscript
# 修正前
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + 10

# 修正後
effect_manager.apply_max_hp_effect(creature_data, 10)
```

---

## 修正手順

### ステップ1: BattleParticipant クラス（30分）

1. コンストラクタから update_current_hp() を削除
2. take_damage() を修正（base_hp → current_hp）
3. take_mhp_damage() を修正（base_hp → current_hp）

### ステップ2: battle_preparation.gd（20分）

1. prepare_participants() で current_hp を直接設定
2. 攻撃側・防御側両方修正

### ステップ3: バトル後処理（30分）

1. battle_special_effects.gd の update_defender_hp() 修正
2. battle_system.gd の永続変身・復活処理修正
3. battle_execution.gd の damage_breakdown 参照更新

### ステップ4: place_creature() に current_hp 初期化追加（15分）

base_tiles.gd に：
```gdscript
if not creature_data.has("current_hp"):
	var base_hp = creature_data.get("hp", 0)
	var base_up_hp = creature_data.get("base_up_hp", 0)
	creature_data["current_hp"] = base_hp + base_up_hp
```

### ステップ5: テスト実行（1時間）

バトルテストツール (battle_test_executor.gd) で動作確認

---

## テスト項目

### 基本動作

- [ ] バトル開始時に current_hp が正しく初期化される
- [ ] バトル中のダメージが current_hp から直接削られる
- [ ] 各種ボーナスが正しく消費される
- [ ] ボーナス消費後に current_hp から削られる

### HP管理

- [ ] get_max_hp() が正しい値を返す（base_hp + base_up_hp）
- [ ] is_alive() が current_hp > 0 で正しく判定される
- [ ] is_damaged() が正しく判定される
- [ ] get_hp_ratio() が正しく計算される

### ダメージ処理

- [ ] 通常ダメージが current_hp から削られる
- [ ] 反射ダメージが current_hp から削られる
- [ ] MHPダメージ(雪辱)が current_hp から削られる
- [ ] damage_breakdown が正しく記録される

### 戦闘終了処理

- [ ] バトル終了時の HP 保存が current_hp をそのまま保存する
- [ ] 保存された current_hp が次のバトル開始時に正しく復元される
- [ ] タイル配置後の HP が正しく更新される

### 特殊効果

- [ ] 再生スキルが base_hp + base_up_hp までしか回復しない
- [ ] 永続変身時に HP ダメージ状況が引き継がれる
- [ ] 復活時に HP が満タンになる
- [ ] マスグロース時に current_hp が正しく同期される

---

## 実装ステータス

| 項目 | ステータス | 担当 | 開始 | 完了 |
|------|-----------|------|------|------|
| 設計・計画 | ✅ 完了 | Hand | 2025-11-17 | 2025-11-20 |
| BattleParticipant 修正 | ⬜ 未開始 | - | - | - |
| battle_preparation.gd 修正 | ⬜ 未開始 | - | - | - |
| バトル後処理修正 | ⬜ 未開始 | - | - | - |
| place_creature() 初期化追加 | ⬜ 未開始 | - | - | - |
| テスト実行 | ⬜ 未開始 | - | - | - |
| ドキュメント更新 | ⬜ 未開始 | - | - | - |

---

## 注意事項・リスク

### 1. 大規模な変更

- HP 管理の根本的な変更
- 修正漏れがあるとバグの原因に
- 十分なテストが必須

### 2. 破壊的変更

- 既存ロジックが大きく変わる
- デバッグ時に混乱の可能性
- コメント記載と一貫性維持が重要

### 3. 関連システムの同期

バトル側とマップ側での HP 管理が異なるため：
- バトル側：current_hp が状態値
- マップ側：base_up_hp 変更時に current_hp も同期

この境界での一貫性を保つことが重要

---

## 参考資料

- 現在のHP構造：`docs/design/hp_structure.md`
- 効果システム：`docs/design/effect_system_design.md`
- バトルシステム：`docs/design/battle_system.md`

---

**最終更新**: 2025年11月20日（v2.0）
