# ベースアップ全個体問題の調査結果 (2025-11-16)

## 🔴 発見された問題点

### **問題1: BattleParticipant.creature_dataが直接参照されている【最有力】**

**場所**: `scripts/battle/battle_participant.gd` 行1-54
```gdscript
func _init(
	p_creature_data: Dictionary,  # ← ここでタイルのcreature_dataをそのまま受け取る
	...
):
	creature_data = p_creature_data  # ← コピーではなく参照を保存！
```

**問題**:
- BattleParticipantが受け取る`p_creature_data`は、BaseTileの`creature_data`プロパティから取得
- BaseTileの`creature_data`は**CreatureManagerへリダイレクト**
- つまり: `participant.creature_data = CreatureManager.get_data_ref(tile_index)`
- **同じカードの複数個体が同じタイルにあるわけではない**が...

### **問題2: battle_system.gd内の永続バフ処理【直接原因】**

**場所**: `scripts/battle_system.gd` 行647-670 (`_apply_on_destroy_permanent_buffs`)
```gdscript
func _apply_on_destroy_permanent_buffs(participant: BattleParticipant):
	...
	if effect.get("effect_type") == "on_enemy_destroy_permanent":
		var stat_changes = effect.get("stat_changes", {})
		for stat in stat_changes:
			var value = stat_changes[stat]
			if stat == "ap":
				if not participant.creature_data.has("base_up_ap"):
					participant.creature_data["base_up_ap"] = 0
				participant.creature_data["base_up_ap"] += value  # ← ここで直接加算
			elif stat == "max_hp":
				if not participant.creature_data.has("base_up_hp"):
					participant.creature_data["base_up_hp"] = 0
				participant.creature_data["base_up_hp"] += value  # ← ここで直接加算
```

### **問題3: データの保存先と同期の問題【根本原因】**

**フロー分析**:

1. **バトル前**: 
   - タイル上のヴァルキリー①: `CreatureManager.creatures[tile_index_1] = {...}`
   - タイル上のヴァルキリー②: `CreatureManager.creatures[tile_index_2] = {...}`
   - タイル上のヴァルキリー③: `CreatureManager.creatures[tile_index_3] = {...}`

2. **バトル準備時**:
   - BattleParticipantが作成される際、`creature_data`に**参照**が保存される
   - `participant.creature_data` ← 実はCreatureManagerの辞書への参照

3. **敵倒時（ヴァルキリー②が敵を倒した）**:
   - `_apply_on_destroy_permanent_buffs(participant②)` が呼ばれる
   - `participant②.creature_data["base_up_hp"] += 10` が実行
   - これは `CreatureManager.creatures[tile_index_2]["base_up_hp"] += 10` になる

**ここまでは正常。問題はここから:**

4. **手札への復帰時**:
   - 倒されたクリーチャーは手札に戻る
   - デッキから新しく出し直される

**ただし、同じカード定義だと:**
- ヴァルキリーのカード定義は同じ
- 手札に戻すと、また同じcreature_data辞書を参照する可能性がある

## 🤔 本当の問題は？

**仮説**: 
- `card_system.return_card_to_hand()` で手札に戻す際、実データを直接編集している？
- または、CreatureManagerから削除されたはずのクリーチャーが、タイルの`creature_data`プロパティ経由で同じクリーチャーを参照し続けている？

## 🔍 コピー処理の確認

実装を追跡したところ：

**place_creature()の流れ**:
1. tile_action_processor.execute_summon()
   - card_data = card_system.get_card_data_for_player()
   - board_system.place_creature(tile_index, card_data)

2. board_system.place_creature()
   - tile_data_manager.place_creature(tile_index, creature_data)

3. tile_data_manager.place_creature()
   - tile_nodes[tile_index].place_creature(creature_data)

4. base_tiles.place_creature(data)
   - creature_data = data.duplicate() ← **ディープコピー1**
   - この時点でCreatureManagerの setter が呼ばれる
   - creature_manager.set_data(tile_index, value) が呼ばれる

5. creature_manager.set_data()
   - creatures[tile_index] = data.duplicate(true) ← **ディープコピー2**

**つまり2回ディープコピーされている！**

ただし、各タイル（tile_index_1, tile_index_2, tile_index_3）は別々のcreatures[tile_index]に保存される。

## 📋 本当の問題の仮説

**battle_system.gd の _apply_on_destroy_permanent_buffs() で:**

```gdscript
participant.creature_data["base_up_hp"] += value
```

`participant.creature_data` は battle_preparation.gd で設定された時点での **参照** 。

その参照が指す先は CreatureManager.creatures[tile_index] の辞書。

ここで加算された値が **タイルのデータに永続化** される。

**問題はここから：**
- バトル完了後、タイルのデータは更新される
- ヴァルキリー①が敵を倒した → base_up_hp が +10
- **その後、ヴァルキリー②が新たに別のタイルに配置される時**
- card_system.get_card_data_for_player() が返すデータが...

**card_system の内部実装を確認する必要がある！**
- 手札のカードデータが グローバルで共有されているのか?
- 各カードインスタンスが独立しているのか?

## 📋 次に確認すべき

1. BattleParticipantの`_init`でデータコピーがあるか?
2. battle_system.gd で base_up を加算している際、battle_after_saveやデータ保存処理があるか?
3. hand_display や card_system で creature_data の扱いがどうなっているか?
4. CreatureManager の creatures辞書が複数キーで同じオブジェクト参照を持つことがないか?
