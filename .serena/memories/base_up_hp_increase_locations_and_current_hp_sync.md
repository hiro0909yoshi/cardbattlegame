# base_up_hp が増える箇所と current_hp 更新対応 (2025-11-18)

## マップ上で base_up_hp が増える場所

### 1. **スペル（魔法）**

**ファイル**: `scripts/spells/spell_land_new.gd`

- 地形変化スペルで土地の属性とレベルを変更
- MHPボーナスが増える可能性あり

**ファイル**: `scripts/spells/スタータス増減.md`

- 永続的にステータスを変更するスペル

---

### 2. **周回ボーナス（LAP SYSTEM）**

**ファイル**: `scripts/battle_system.gd` (536行, 570行)

```gdscript
# マスグロース
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + bonus_hp

# ドミナントグロース
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + bonus_hp
```

タイル上に配置されている敵クリーチャーの `base_up_hp` が増える

---

### 3. **レベルアップ（地形コマンド）**

**ファイル**: `scripts/game_flow/land_action_helper.gd` (376, 381行)

```gdscript
# アースズピリット（レベルアップでMHP+10）
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + 10

# デュータイタン（レベルアップでMHP-10）
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) - 10
```

タイル上に配置されているクリーチャーのMHPが変化

---

### 4. **地形変化（スペルによる地形操作）**

**ファイル**: `scripts/board_system_3d.gd` (432, 437行)

```gdscript
# 地形を上昇させる
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + 10

# 地形を下降させる
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) - 10
```

土地に配置されているクリーチャーに副次効果でMHPボーナスが付く

---

### 5. **スキル効果（バトル中・バトル後）**

**ファイル**: `scripts/battle_system.gd`

- **690行**: アシストスキル（永続バフ）
  ```gdscript
  participant.base_up_hp += value
  ```

- **713行**: MHPダメージ
  ```gdscript
  participant.base_up_hp -= 30
  ```

- **726行**: ブルガサリ発動
  ```gdscript
  participant.base_up_hp += 10
  ```

- **756-766行**: 永続変化スキル
  ```gdscript
  participant.creature_data["base_up_hp"] = new_base_up_hp
  participant.base_up_hp = new_base_up_hp
  ```

---

## current_hp 更新が必要な場所

### パターン1: バトル中に base_up_hp が増える

**現状**: 正しく機能している

```gdscript
# battle_participant.gd
participant.base_up_hp += value
update_current_hp()  # ← 再計算される
```

---

### パターン2: マップ上に配置済みクリーチャーで base_up_hp が増える

**現状**: current_hp が更新されない ⚠️

**該当箇所**:

1. `scripts/game_flow/land_action_helper.gd` (376行)
   - レベルアップ時のMHP変更
   - `creature_data["base_up_hp"] += 10` のみ

2. `scripts/board_system_3d.gd` (432行)
   - 地形変化時のMHP変更
   - `creature_data["base_up_hp"] += 10` のみ

3. `scripts/battle_system.gd` (536, 570行)
   - 周回ボーナス（マスグロース、ドミナントグロース）
   - `creature_data["base_up_hp"] += bonus_hp` のみ

4. `scripts/spells/spell_land_new.gd`
   - スペルによる地形変化
   - current_hp 更新の有無を確認必要

---

## 修正が必要な処理フロー

### 【修正前】
```
base_up_hp が増える
  ↓
creature_data["base_up_hp"] += 10
  ↓
MHP = 30 + 10 = 40 に増加
current_hp は変わらず
  ↓
UI表示: current_hp=30, MHP=40（矛盾）
```

### 【修正後】
```
base_up_hp が増える
  ↓
old_mhp = 30 + 0 = 30
new_mhp = 30 + 10 = 40
  ↓
creature_data["base_up_hp"] += 10
creature_data["current_hp"] += (new_mhp - old_mhp)  # ← 追加
  ↓
MHP = 40, current_hp = 40
  ↓
UI表示: current_hp=40, MHP=40（一貫性あり）
```

---

## 実装推奨パターン

### ヘルパー関数の作成

**場所**: `scripts/effect_manager.gd` または新規ユーティリティ

```gdscript
## base_up_hp を増やし、current_hp も同時に増加させる
func increase_max_hp(creature_data: Dictionary, increase_amount: int) -> void:
	# 1. 古いMHPを保存
	var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
	
	# 2. base_up_hp を増加
	creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + increase_amount
	
	# 3. 新しいMHPを計算
	var new_mhp = creature_data.get("hp", 0) + creature_data["base_up_hp"]
	
	# 4. current_hp も増加
	if creature_data.has("current_hp"):
		creature_data["current_hp"] += (new_mhp - old_mhp)
		# MHP上限を超えないようにクランプ
		creature_data["current_hp"] = min(creature_data["current_hp"], new_mhp)
```

### 使用例

**land_action_helper.gd**:
```gdscript
# 修正前
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + 10

# 修正後
effect_manager.increase_max_hp(creature_data, 10)
```

---

## 対応すべき箇所リスト

| ファイル | 行番号 | 処理 | 優先度 |
|---------|--------|------|--------|
| land_action_helper.gd | 376 | レベルアップ (MHP+10) | 🔴 高 |
| land_action_helper.gd | 381 | レベルアップ (MHP-10) | 🔴 高 |
| board_system_3d.gd | 432 | 地形上昇 (MHP+10) | 🔴 高 |
| board_system_3d.gd | 437 | 地形下降 (MHP-10) | 🔴 高 |
| battle_system.gd | 536 | マスグロース | 🟡 中 |
| battle_system.gd | 570 | ドミナントグロース | 🟡 中 |
| spell_land_new.gd | ? | スペルによる変更 | 🟡 中 |
| effect_manager.gd | 62, 77, 88 | パーマネント効果 | 🟡 中 |

---

## バトル中との区別

**バトル中**: 既に `update_current_hp()` が呼ばれるため問題なし

**マップ上**: 
- CreatureManager経由でデータ参照
- place_creature() の初期化後は手動更新必要
- UI表示時に矛盾が生じる可能性

---

## リファクタリング実装時の対応

1. **place_creature() で current_hp 初期化** 
   ```gdscript
   if not creature_data.has("current_hp"):
       creature_data["current_hp"] = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
   ```

2. **マップ上の base_up_hp 変更時に current_hp も更新**
   ```gdscript
   # 各箇所で以下を実装
   effect_manager.increase_max_hp(creature_data, amount)
   ```

3. **ヘルパー関数整備**
   - UtilityやEffectManagerに関数追加
   - 統一された処理で current_hp 同期
