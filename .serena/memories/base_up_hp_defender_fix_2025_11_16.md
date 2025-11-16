# ベースアップHP防御時反映バグ修正 (2025-11-16)

## 問題
防御側が敵をダスクドウェラーで倒した時に獲得した永続バフ（base_up_hp +10）が、次のバトルで反映されず、代わりにAPの永続バフは反映されていた。

## 根本原因
`_execute_battle_core`内で、バトル中は同じ`tile_info`参照がずっと使われていた。バトル中に`defender.base_up_hp`が増加しても、その後`update_defender_hp`呼び出し時に渡される`tile_info`は古いままだった。

ログから確認できた状況：
```
[battle_preparation] 防御側の初期永続バフ:
  base_up_hp: 10
  base_up_ap: 10

[永続バフ] ダスクドウェラー ST+10.0
[永続バフ] ダスクドウェラー MHP+10.0
  base_up_hp: 0 → 10  ← バトル中に増加

[update_defender_hp] 防御側の永続バフを反映:
  元のbase_up_hp: 10 → 10  ← 古いtile_infoから取得
  元のbase_up_ap: 10 → 20  ← こちらは正しく更新
```

`base_up_ap`は最初から20に達していたため反映されたが、`base_up_hp`はバトル前から初期値の10のままだったため、古いtile_infoからも10と読み込まれた。

## 解決方法
`DEFENDER_WIN`と`ATTACKER_SURVIVED`の両方の結果処理で、`update_defender_hp`呼び出し直前に`tile_info`を新規取得する。

### 修正内容（battle_system.gd）

```gdscript
# DEFENDER_WIN時（324行目付近）
# 修正前
battle_special_effects.update_defender_hp(tile_info, defender)

# 修正後
var updated_tile_info = board_system_ref.get_tile_info(tile_index)
battle_special_effects.update_defender_hp(updated_tile_info, defender)

# ATTACKER_SURVIVED時（387行目付近）も同様
```

## テスト方法
1. プレイヤー2がダスクドウェラーで敵を倒す（破壊カウント+1、base_up_hp +10）
2. プレイヤー1がダスクドウェラーを場に出す
3. ダスクドウェラーの最大HPが40 + 10 = 50で表示されることを確認

## 実装状況
✅ 修正完了（2025-11-16）
