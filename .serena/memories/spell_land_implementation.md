# SpellLand実装記録

**実装日**: 2025年11月9日

## 実装ファイル

### 1. スクリプトファイル
- `scripts/spells/spell_land.gd` ✅ 作成完了

### 2. ドキュメントファイル
- `docs/design/spells/領地変更.md` ✅ 作成完了

### 3. 設計書更新
- `docs/design/spells_design.md` ✅ 更新完了

## 実装メソッド一覧

### 基本メソッド
1. `change_element(tile_index, new_element)` - 土地属性変更
2. `change_level(tile_index, delta)` - レベル増減
3. `set_level(tile_index, level)` - レベル固定
4. `destroy_creature(tile_index)` - クリーチャー破壊
5. `abandon_land(tile_index, player_id)` - 土地放棄（価値計算含む）

### 高度なメソッド
6. `change_element_with_condition(tile_index, condition, new_element)` - 条件付き属性変更
7. `get_player_dominant_element(player_id)` - プレイヤーの最多属性取得
8. `change_level_multiple_with_condition(player_id, condition, delta)` - 条件付き一括レベル変更

## システム統合（未実装）

### GameFlowManagerへの追加が必要

```gdscript
# game_flow_manager.gd

# スペル効果システム
var spell_draw: SpellDraw
var spell_magic: SpellMagic
var spell_land: SpellLand  # 追加

func setup_systems(...):
    # ... 既存の初期化
    
    # SpellLandの初期化
    spell_land = SpellLand.new()
    spell_land.setup(board_system, creature_manager, player_system)
```

### SpellPhaseHandlerへの統合が必要

土地操作系スペルの`effect_type`を処理する必要がある：

```gdscript
# spell_phase_handler.gd

func _execute_spell_effect(spell_data: Dictionary, target_tile: int):
    var effect_type = spell_data.get("effect_type", "")
    
    match effect_type:
        "change_element":
            var new_element = spell_data.get("element", "earth")
            game_flow_manager.spell_land.change_element(target_tile, new_element)
        
        "change_level":
            var delta = spell_data.get("delta", -1)
            game_flow_manager.spell_land.change_level(target_tile, delta)
        
        "destroy_creature":
            game_flow_manager.spell_land.destroy_creature(target_tile)
        
        "abandon_land":
            var player_id = current_player_id
            var value = game_flow_manager.spell_land.abandon_land(target_tile, player_id)
            var magic_gain = int(value * 0.7)  # 70%
            game_flow_manager.spell_magic.add_magic(player_id, magic_gain)
```

## 対応スペルカード（20個）

### 実装済みの基盤メソッド
以下のスペルに対応可能：

**属性変換系**:
- 2001: アースシフト
- 2010: ウォーターシフト
- 2011: エアーシフト
- 2074: ファイアーシフト
- 2022: クインテッセンス
- 2008: インフルエンス

**レベル操作系**:
- 2003: アステロイド
- 2029: サドンインパクト
- 2030: サブサイド
- 2085: フラットランド

**土地放棄系**:
- 2118: ランドトランス

### まだ実装が必要なスペル
以下は特殊な処理が必要：

- 2040: ストームシフト（条件分岐が複雑）
- 2103: マグマシフト（条件分岐が複雑）
- 2096: ホームグラウンド（密命システム）

## 次のステップ

### 優先度：高
1. GameFlowManagerへのspell_land追加
2. SpellPhaseHandlerへの統合
3. 個別スペルカードのJSON作成とeffect定義

### 優先度：中
4. ターゲット選択UIの拡張（土地選択対応）
5. 土地💬システムの調査と実装

### 優先度：低
6. 密命システムの実装（ホームグラウンド等）
7. 合成システムの実装（アステロイド合成版等）

## 技術メモ

### BoardSystem3Dの依存関係
- `_update_tile_visual(tile_index)` - 属性・レベル変更後に必須
- `remove_creature(tile_index)` - クリーチャー破壊時に使用
- `tiles[tile_index]` - タイルデータへの直接アクセス

### CreatureManagerの活用
- `has_creature(tile_index)` - クリーチャー存在確認
- `get_data_ref(tile_index)` - クリーチャーデータ取得
- `set_data(tile_index, {})` - クリーチャー削除

### PlayerSystemの更新
- `player.lands_owned[element]` - 土地放棄時に減算が必要

## 既知の問題

なし（現時点では基盤実装のみ完了）

---

**最終更新**: 2025年11月9日
