# base_up_hp と current_hp の関係性修正 (2025-11-17)

## 問題
- バトル中に永続バフ（base_up_hp +10）が適用されても、current_hp が増加していない
- ダメージを受けないシーンでは base_up_hp: 10 → 20 が正しく反映されるが、防御側タイルに反映されない
- ダメージ消費順序で base_up_hp が削られているため、MHPボーナスまで失われている

## ドキュメント仕様
`docs/design/hp_structure.md` セクション4「マスグロース」：
- `base_up_hp` が増加したら、同じ値分だけ `current_hp` も増加
- ダメージ消費時に `base_up_hp` を削ってはいけない（永続ボーナスのため）

## 修正内容（全3箇所）

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

## テスト方法

1. **テスト1: ダメージなしで永続バフが反映される**
   - プレイヤー2がダスクドウェラーで敵を倒す
   - `base_up_hp: 10 → 20`, `current_hp: 10 → 20` を確認

2. **テスト2: 通常ダメージで base_up_hp が削られない**
   - 防御側がダメージを受ける
   - `base_up_hp` は変わらず、`current_hp` だけ減ることを確認

3. **テスト3: 雪辱効果でも base_up_hp が削られない**
   - 雪辱効果でダメージを受ける
   - `base_up_hp` は変わらず、MHP だけ減ることを確認

## 実装状況
✅ 全修正完了（2025-11-17）
