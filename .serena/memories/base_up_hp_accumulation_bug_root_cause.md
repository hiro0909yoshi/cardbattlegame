# ベースアップHP累積バグ - 根本原因判明 (2025-11-16)

## 問題の詳細
2回目以降のバトルで、HPの永続バフが前の値にリセットされる。

**例：**
- バトル1：base_up_hp 0 → 10
- バトル2直前：base_up_hp は10のまま（正しい）
- バトル2中に永続バフ発動：base_up_hp 10 → 20
- バトル2終了後のログで：base_up_hp 0 → 10（20が10にリセットされている）
- バトル3では base_up_hp が 0 から 10 にリセット

APは正しく累積：10 → 20 → 30...

## 根本原因

`battle_system.gd`の`_apply_after_battle_permanent_changes`内で、**HP と AP の処理が非対称**

### AP処理（正しい）- 730-742行目
```gdscript
participant.creature_data["base_up_ap"] = new_base_up_ap  # creature_dataに保存
```

### HP処理（間違い）- 745-758行目
```gdscript
participant.base_up_hp = new_base_up_hp  # participantプロパティにのみ保存
# creature_data には保存されていない！
```

### 問題の流れ

1. **バトル中**：`participant.base_up_hp`は正しく更新される
2. **バトル後`update_defender_hp`**：
   - `creature_data["base_up_hp"] = defender.base_up_hp`で正しく保存される
   - タイルのクリーチャーデータが更新される

3. **`_apply_after_battle_permanent_changes`**：
   - `participant.base_up_hp = new_base_up_hp` で participant のみ更新
   - `creature_data` には書き込まれない（ここが問題）

4. **次のバトル準備時**：
   - `defender_creature = tile_info.get("creature", {})`で読み込み
   - `tile_info.get("creature", {}).get("base_up_hp", 0)`で読む
   - `update_defender_hp` で保存した値をそのまま読み込むが...

5. **その次のバトル中**：
   - `_apply_after_battle_permanent_changes` が再び実行
   - `participant.base_up_hp`は BattleParticipant のプロパティなので、新しい値として追加
   - しかし `creature_data` には反映されないまま

つまり、APは毎回 `creature_data` に保存されるので累積するが、HPは `participant` プロパティのみに保存されるため、次のバトル準備時に古い値をリセットされている。

## 修正方法

744-758行目の HP処理を APと同じようにする：

```gdscript
# 修正前
participant.base_up_hp = new_base_up_hp

# 修正後
participant.creature_data["base_up_hp"] = new_base_up_hp  # creature_dataに保存
participant.base_up_hp = new_base_up_hp  # 念のため両方保存
```

または、AP処理もシンプルに APのみ`participant`プロパティにして、統一させる方法も考えられる。
