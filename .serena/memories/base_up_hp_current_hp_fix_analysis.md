# base_up_hp と current_hp の関係性修正 (2025-11-16)

## 問題
- バトル中に永続バフ（base_up_hp +10）が適用されても、current_hp が増加していない
- ダメージを受けないシーンでは base_up_hp: 10 → 20 が正しく反映されるが、防御側タイルに反映されない
- ダメージ消費順序で base_up_hp が削られているため、MHPボーナスまで失われている

## ドキュメント仕様
`docs/design/hp_structure.md` セクション4「マスグロース」：
```
# 1. MHPを増やす（base_up_hpを増やす）
creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + value

# 2. 現在HPも回復（増えたMHP分だけ）
var new_hp = min(current_hp + value, max_hp)
creature_data["current_hp"] = new_hp
```

**要件：**
- `base_up_hp` が増加したら、同じ値分だけ `current_hp` も増加
- ダメージ消費時に `base_up_hp` を削ってはいけない（永続ボーナスのため）

## 根本原因

### 原因1: 永続バフ適用時に current_hp が更新されない
位置: `battle_system.gd` の `_apply_on_destroy_permanent_buffs()` 関数（685行目付近）

```gdscript
elif stat == "max_hp":
    participant.base_up_hp += value
    print("[永続バフ] ", ..., " MHP+", value)
    # current_hp の増加処理がない ← ここが問題
```

### 原因2: ダメージ処理で base_up_hp を削っている
位置: `battle_participant.gd` の `take_damage()` メソッド（150行目付近）

```gdscript
# 6. 永続的な基礎HP上昇から消費
if base_up_hp > 0 and remaining_damage > 0:
    var consumed = min(base_up_hp, remaining_damage)
    base_up_hp -= consumed  # ← 削ってはいけない
    remaining_damage -= consumed
```

ダメージ消費順序は base_up_hp を含んでいるため、ダメージでMHPボーナスが削られてしまう。

## 修正内容

### 修正1: 永続バフ適用時に current_hp を増加させる

**ファイル**: `scripts/battle_system.gd`  
**関数**: `_apply_on_destroy_permanent_buffs()`  
**行番号**: 685行目付近

変更前：
```gdscript
elif stat == "max_hp":
    participant.base_up_hp += value
    print("[永続バフ] ", participant.creature_data.get("name", ""), " MHP+", value)
    print("  base_up_hp: ", old_base_up_hp, " → ", participant.base_up_hp)
```

変更後：
```gdscript
elif stat == "max_hp":
    participant.base_up_hp += value
    participant.current_hp += value  # ← 追加
    print("[永続バフ] ", participant.creature_data.get("name", ""), " MHP+", value)
    print("  base_up_hp: ", old_base_up_hp, " → ", participant.base_up_hp)
```

**効果**: base_up_hp が 10 増えたら、current_hp も 10 増える

### 修正2: ダメージ消費順序から base_up_hp を削除

**ファイル**: `scripts/battle_participant.gd`  
**関数**: `take_damage()`  
**行番号**: 150行目付近

変更前（消費順序6）：
```gdscript
# 6. 永続的な基礎HP上昇から消費
if base_up_hp > 0 and remaining_damage > 0:
    var consumed = min(base_up_hp, remaining_damage)
    base_up_hp -= consumed
    remaining_damage -= consumed
    damage_breakdown["base_up_hp_consumed"] = consumed
```

変更後（このブロック全体を削除）：
- ブロックを削除
- 残ったダメージを base_hp に直接渡す（現在の「7. 基本HPから消費」がそのまま機能）

**効果**: ダメージが base_up_hp を削らず、現在HPのみ削減される

## テスト方法

1. **テスト1: ダメージなしで永続バフが反映される**
   - プレイヤー2がダスクドウェラーで敵を倒す
   - `base_up_hp: 10 → 20`, `current_hp: 10 → 20` を確認
   - ダメージが0の場合、防御側タイルに正しく反映されることを確認

2. **テスト2: ダメージを受けても base_up_hp は削られない**
   - 防御側がダメージを受ける
   - `base_up_hp` は変わらず、`current_hp` だけ減ることを確認

3. **テスト3: 防御側勝利時に永続バフが反映される**
   - プレイヤー2がダスクドウェラーで敵を倒す（base_up_hp +10）
   - プレイヤー1がダスクドウェラーを場に出す
   - ダスクドウェラーのMHPが正しく増加していることを確認

## 実装状況
✅ 修正完了（2025-11-17）

## ダメージ処理の全修正

`base_up_hp` は永続的なボーナスのため、**どのダメージ処理でも削ってはいけない**

### 修正1: battle_system.gd（687行目）
```gdscript
# 変更前
participant.base_up_hp += value
print("[永続バフ] ", participant.creature_data.get("name", ""), " MHP+", value)

# 変更後
participant.base_up_hp += value
participant.current_hp += value  # ← 追加
print("[永続バフ] ", participant.creature_data.get("name", ""), " MHP+", value)
```

**効果**: base_up_hp が増えたら、current_hp も同じ値だけ増える

### 修正2: battle_participant.gd（110行目と153行目）
- `damage_breakdown` から `"base_up_hp_consumed": 0` を削除
- ダメージ消費ブロック「6. 永続的な基礎HP上昇から消費」全体を削除

**効果**: ダメージが base_up_hp を削らず、base_hp だけ消費される（current_hp だけ減少）
