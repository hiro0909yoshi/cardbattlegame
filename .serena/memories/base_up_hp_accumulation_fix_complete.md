# ベースアップHP累積バグ修正完了 (2025-11-16)

## 問題
2回目以降のバトルで、HPの永続バフが前の値にリセットされる。
- バトル1: base_up_hp 0 → 10
- バトル2: base_up_hp が 10 → 20 になるべきが、0 → 10 にリセットされる
- バトル3: 同様にリセット

一方、APは正しく累積していた（10 → 20 → 30...）

## 根本原因
`_apply_after_battle_permanent_changes`内で、AP と HP の処理が非対称だった。

**AP処理（正しい）：**
```gdscript
participant.creature_data["base_up_ap"] = new_base_up_ap  # creature_dataに保存
```

**HP処理（間違い）：**
```gdscript
participant.base_up_hp = new_base_up_hp  # participantプロパティのみ
# creature_dataには保存されていなかった
```

このため、タイルのクリーチャーデータに永続バフが記録されず、次のバトル準備時に古い値が読み込まれていた。

## 修正内容
battle_system.gd の 755-756行目を修正

**修正前：**
```gdscript
participant.base_up_hp = new_base_up_hp
```

**修正後：**
```gdscript
participant.creature_data["base_up_hp"] = new_base_up_hp
participant.base_up_hp = new_base_up_hp
```

AP処理と統一し、`creature_data`にも保存するようにした。

## 効果
1. **永続バフの累積：** HPも APと同じように累積される
2. **マスターデータ保護：** CardLoaderのマスターデータは一切修正されない
3. **タイル独立性：** 各タイル上のクリーチャーデータが独立した値を持つ

## 修正状況
✅ 実装完了（2025-11-16）
