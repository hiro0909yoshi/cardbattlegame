# base_up_hp と current_hp の関係性修正 完全版 (2025-11-17)

## 修正内容（全5箇所）

### 修正1: battle_system.gd (687行目)
永続バフ適用時に `current_hp` も増加させる

```gdscript
# 変更後
elif stat == "max_hp":
    participant.base_up_hp += value
    participant.current_hp += value  # ← 追加
```

### 修正2: battle_participant.gd take_damage メソッド
ダメージ消費順序から `base_up_hp` を削るブロックを削除

- `damage_breakdown` から `"base_up_hp_consumed": 0` を削除
- ダメージ消費ブロック「6. 永続的な基礎HP上昇から消費」全体を削除

### 修正3: battle_participant.gd take_mhp_damage メソッド
雪辱効果でも `base_up_hp` を削らないように修正

- `base_up_hp` を削るブロック全体を削除
- `base_hp` だけ消費するように変更

### 修正4: battle_execution.gd (188行目)
`base_up_hp_consumed` の参照を削除（軽減ダメージ計算）

```gdscript
# 変更前
var actual_damage_dealt_reduced = (
    ... + damage_breakdown_reduced.get("base_up_hp_consumed", 0) + ...
)

# 変更後
var actual_damage_dealt_reduced = (
    ... + damage_breakdown_reduced.get("base_hp_consumed", 0)
)
```

### 修正5: battle_execution.gd (305行目)
`base_up_hp_consumed` の参照を削除（通常ダメージ計算）

```gdscript
# 変更前
var actual_damage_dealt = (
    ... + damage_breakdown.get("base_up_hp_consumed", 0) + ...
)

# 変更後
var actual_damage_dealt = (
    ... + damage_breakdown.get("base_hp_consumed", 0)
)
```

## テスト方法

1. **テスト1: ダメージなしで永続バフが反映される**
   - プレイヤー2がバルキリーで敵を倒す
   - `base_up_hp: 10 → 20`, `current_hp: 10 → 20` を確認

2. **テスト2: 通常ダメージで base_up_hp が削られない**
   - 防御側がダメージを受ける
   - `base_up_hp` は変わらず、`current_hp` だけ減ることを確認

3. **テスト3: 防御側勝利時に永続バフが反映される**
   - プレイヤー2がバルキリーで敵を倒す
   - プレイヤー1がバルキリーを場に出す
   - バルキリーのMHPが正しく増加していることを確認

## 実装状況
✅ 全修正完了（2025-11-17）
- 5箇所の修正完了
- base_up_hp は永続的なMHPボーナスとして守られる
- ドキュメント仕様に完全に合致
