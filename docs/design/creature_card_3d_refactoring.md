# クリーチャー3Dカード表示 整合性リファクタリング設計書

## 概要

クリーチャーデータ（creature_data）と3Dカード表示（creature_card_3d）の整合性が取れない問題を修正する。

---

## 問題の原因

### 現状の構造

```
BaseTile
├── creature_data (プロパティ) → CreatureManager.creatures[tile_index] を参照
└── creature_card_3d (変数) → 3Dカードノード（BaseTile内で独立管理）

CreatureManager
├── creatures[tile_index] → データ
└── visual_nodes[tile_index] → 3Dカード（未使用）
```

### 問題点

`creature_data`への直接代入時に、3Dカード表示が同期されない。

| 操作 | creature_data | creature_card_3d | 結果 |
|------|---------------|------------------|------|
| `tile.place_creature(data)` | ✅ 設定 | ✅ 作成 | 正常 |
| `tile.remove_creature()` | ✅ クリア | ✅ 削除 | 正常 |
| `tile.creature_data = data` | ✅ 設定 | ❌ 作成されない | **データあり・画像なし** |
| `tile.creature_data = {}` | ✅ クリア | ❌ 削除されない | **データなし・画像あり** |

---

## 直接代入箇所一覧（14箇所）

### board_system_3d.gd（2箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 273 | `tile.creature_data = {}` | フォールバック（remove_creatureがない場合のみ） |
| 387 | `new_tile.creature_data = old_creature` | 地形変化時のタイル置換。401行目でplace_creature呼び出しあり |

### game_flow/movement_helper.gd（2箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 400 | `from_tile_node.creature_data = {}` | 移動元クリア。**3Dカード残る** |
| 411 | `to_tile_node.creature_data = creature_data` | 移動先設定。**3Dカード作成されない** |

### spells/spell_creature_return.gd（1箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 140 | `tile.creature_data = {}` | クリーチャーを手札に戻す際のクリア |

### spells/spell_creature_swap.gd（3箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 179 | `tile.creature_data = new_creature` | 単体変更 |
| 221 | `tile_1.creature_data = creature_2` | 2体交換 |
| 222 | `tile_2.creature_data = creature_1` | 2体交換 |

### spells/spell_damage.gd（2箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 352 | `tile.creature_data = {}` | クリーチャー破壊時のクリア |
| 408 | `tile.creature_data = new_creature` | 変身系ダメージ処理 |

### spells/spell_land_new.gd（1箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 711 | `tile.creature_data = {}` | 土地操作時のクリーチャー削除 |

### spells/spell_transform.gd（1箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 171 | `tile.creature_data = transformed_creature` | 変身処理 |

### battle/battle_special_effects.gd（2箇所）

| 行 | コード | 状況 |
|----|--------|------|
| 359 | `tile_nodes[tile_index].creature_data = creature_data` | 戦闘後のデータ更新 |
| 712 | `participant.creature_data = new_creature` | BattleParticipantへの代入（タイルではない） |

---

## 修正方法

### 採用方式: BaseTileのsetterで3Dカードを自動同期

`scripts/tiles/base_tiles.gd`のcreature_data setterを修正し、代入時に自動で3Dカードを作成/削除する。

```gdscript
var creature_data: Dictionary:
    get:
        if creature_manager:
            return creature_manager.get_data_ref(tile_index)
        else:
            push_error("[BaseTile] CreatureManager が初期化されていません！")
            return {}
    set(value):
        if creature_manager:
            creature_manager.set_data(tile_index, value)
        else:
            push_error("[BaseTile] CreatureManager が初期化されていません！")
        # 3Dカードの同期
        _sync_creature_card_3d(value)

func _sync_creature_card_3d(data: Dictionary):
    if data.is_empty():
        # データが空 → 3Dカード削除
        if creature_card_3d:
            creature_card_3d.queue_free()
            creature_card_3d = null
    else:
        # データあり
        if creature_card_3d:
            # 既存のカードがある → 更新のみ（再作成しない）
            if creature_card_3d.has_method("set_creature_data"):
                creature_card_3d.set_creature_data(data)
        else:
            # カードがない → 新規作成
            _create_creature_card_3d()
```

**setterの動作：**

| データ | 3Dカード | 動作 |
|--------|----------|------|
| 空 | あり | 削除 |
| 空 | なし | 何もしない |
| あり | あり | 更新（再作成しない） |
| あり | なし | 新規作成 |

### メリット

- 既存コードの変更が最小限（base_tiles.gdのみ）
- どこからcreature_dataに代入しても整合性が保たれる
- 今後の新規コードでも自動的に対応

### 注意点

1. **place_creature()との二重処理を防ぐ**
   - place_creature()内で_create_creature_card_3d()を呼んでいる
   - setterでも呼ぶと二重作成になる
   - → place_creature()から_create_creature_card_3d()呼び出しを削除

2. **remove_creature()との二重処理を防ぐ**
   - remove_creature()内でcreature_card_3dを削除している
   - setterでも削除すると二重削除（ただしnullチェックで問題なし）
   - → remove_creature()からの3Dカード削除はそのまま（冗長だが安全）

---

## 修正対象ファイル

### Phase 1: コア修正（base_tiles.gd）

セーフティネットとしてsetterで3Dカードを自動同期する。

**修正箇所：**

| 行 | 修正内容 |
|----|----------|
| 22-32 | setterに `_sync_creature_card_3d()` 呼び出し追加 |
| 新規 | `_sync_creature_card_3d()` メソッド追加 |

**削除箇所：**

| 行 | 現在のコード | 削除理由 |
|----|-------------|----------|
| 110 | `_create_creature_card_3d()` | setterで作成されるので二重処理 |
| 140-142 | `if creature_card_3d: creature_card_3d.queue_free()...` | setterで削除されるので二重処理 |

---

### Phase 2: 直接代入箇所の統一（14箇所）

全ての直接代入を `place_creature()` / `remove_creature()` に統一する。

#### board_system_3d.gd（2箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 273 | `tile.creature_data = {}` | `tile.remove_creature()` |
| 387 | `new_tile.creature_data = old_creature` | 削除（401行目でplace_creature済み） |

#### game_flow/movement_helper.gd（2箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 400 | `from_tile_node.creature_data = {}` | `from_tile_node.remove_creature()` |
| 411 | `to_tile_node.creature_data = creature_data` | `to_tile_node.place_creature(creature_data)` |

#### spells/spell_creature_return.gd（1箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 140 | `tile.creature_data = {}` | `tile.remove_creature()` |

#### spells/spell_creature_swap.gd（3箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 179 | `else: tile.creature_data = new_creature` | else節を削除（フォールバック不要） |
| 221-222 | `else: tile_1.creature_data = ...` | else節を削除（フォールバック不要） |

#### spells/spell_damage.gd（2箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 352 | `tile.creature_data = {}` | `tile.remove_creature()` |
| 408 | `tile.creature_data = new_creature` | `tile.place_creature(new_creature)` |

#### spells/spell_land_new.gd（1箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 711 | `tile.creature_data = {}` | `tile.remove_creature()` |

#### spells/spell_transform.gd（1箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 171 | `else: tile.creature_data = transformed_creature` | else節を削除（フォールバック不要） |

#### battle/battle_special_effects.gd（2箇所）

| 行 | 現在のコード | 修正後 |
|----|-------------|--------|
| 359 | `tile_nodes[tile_index].creature_data = creature_data` | そのまま（既存クリーチャーのデータ更新。setterで3Dカード更新対応） |
| 712 | `participant.creature_data = new_creature` | そのまま（BattleParticipant、タイルではない） |

---

### Phase 3: 動作確認

修正後、以下の動作を確認：

- [ ] クリーチャー配置（通常）
- [ ] クリーチャー削除（バトル敗北）
- [ ] クリーチャー移動（領地コマンド）
- [ ] クリーチャー交換（スペル）
- [ ] クリーチャー変身（スペル）
- [ ] 地形変化（クリーチャーいる状態）
- [ ] 手札に戻す（スペル）
- [ ] 死者復活

---

## 実装状況

- [x] 調査完了
- [x] ドキュメント作成
- [ ] Phase 1: コア修正（base_tiles.gd）
- [ ] Phase 2: 直接代入箇所の統一（8ファイル、12箇所）
- [ ] Phase 3: 動作確認

---

## 備考

- `battle_special_effects.gd:712`の`participant.creature_data`はBattleParticipantへの代入なのでBaseTileとは無関係
- CreatureManager.visual_nodesは現在未使用。将来的に統合を検討

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025/12/08 | 初版作成 |
