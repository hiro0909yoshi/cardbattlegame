# SpellLand - SpellPhaseHandler統合完了

**実施日**: 2025年11月9日

## 完了した作業

### 1. 属性リストの最終修正 ✅
**正しい属性（5種類）**:
- fire（火）
- water（水）
- earth（地）
- wind（風）
- neutral（無）

**誤り修正**:
- ❌ "air" → ✅ "wind"（風の正しい内部名）
- 属性は5種類（6種類ではない）

### 2. SpellPhaseHandlerへの統合 ✅
**ファイル**: `scripts/game_flow/spell_phase_handler.gd`

#### 追加した`effect_type`（4種類）
| effect_type | 説明 | 内部メソッド |
|-------------|------|--------------|
| `change_element` | 土地属性変更 | `_apply_land_effect_change_element()` |
| `change_level` | 土地レベル変更 | `_apply_land_effect_change_level()` |
| `abandon_land` | 土地放棄 | `_apply_land_effect_abandon()` |
| `destroy_creature` | クリーチャー破壊 | `_apply_land_effect_destroy_creature()` |

#### 土地ターゲット選択の拡張
`_get_valid_targets()`に以下を追加：
- `"land"`: 全ての所有地（owner_filter: "any"）
- `"own_land"`: 自分の土地のみ（owner_filter: "own"）
- `"enemy_land"`: 敵の土地のみ（owner_filter: "enemy"）

### 3. ドキュメント更新 ✅
- `docs/design/spells/領地変更.md`に統合情報を追加
- JSON定義例を追加
- 属性リストを修正

---

## 実装の詳細

### effect_typeごとの処理内容

#### 1. change_element（属性変更）
```gdscript
func _apply_land_effect_change_element(effect: Dictionary, target_data: Dictionary):
    var tile_index = target_data.get("tile_index", -1)
    var new_element = effect.get("element", "")
    
    if tile_index >= 0 and not new_element.is_empty():
        game_flow_manager.spell_land.change_element(tile_index, new_element)
```

**JSON例**:
```json
{
  "effect_type": "change_element",
  "element": "earth"
}
```

#### 2. change_level（レベル変更）
```gdscript
func _apply_land_effect_change_level(effect: Dictionary, target_data: Dictionary):
    var tile_index = target_data.get("tile_index", -1)
    var level_change = effect.get("value", 0)
    
    if tile_index >= 0:
        game_flow_manager.spell_land.change_level(tile_index, level_change)
```

**JSON例**:
```json
{
  "effect_type": "change_level",
  "value": -1  // レベルを1下げる
}
```

#### 3. abandon_land（土地放棄）
```gdscript
func _apply_land_effect_abandon(effect: Dictionary, target_data: Dictionary):
    var tile_index = target_data.get("tile_index", -1)
    var return_rate = effect.get("return_rate", 0.7)
    
    if tile_index >= 0:
        game_flow_manager.spell_land.abandon_land(tile_index, return_rate)
```

**JSON例**:
```json
{
  "effect_type": "abandon_land",
  "return_rate": 0.7  // 価値の70%を返却
}
```

#### 4. destroy_creature（クリーチャー破壊）
```gdscript
func _apply_land_effect_destroy_creature(effect: Dictionary, target_data: Dictionary):
    var tile_index = target_data.get("tile_index", -1)
    
    if tile_index >= 0:
        game_flow_manager.spell_land.destroy_creature(tile_index)
```

**JSON例**:
```json
{
  "effect_type": "destroy_creature"
}
```

---

## 土地スペルのJSON定義例

### アースシフト（ID: 2001）
```json
{
  "id": 2001,
  "name": "アースシフト",
  "type": "spell",
  "spell_type": "単体対象",
  "cost": {"mp": 100},
  "effect": "対象自領地を地に変える",
  "effect_parsed": {
    "target_type": "own_land",
    "target_info": {
      "owner_filter": "own"
    },
    "effects": [
      {
        "effect_type": "change_element",
        "element": "earth"
      }
    ]
  }
}
```

### アステロイド（ID: 2003）
```json
{
  "id": 2003,
  "name": "アステロイド",
  "type": "spell",
  "spell_type": "単体対象",
  "cost": {"mp": 100, "cards_sacrifice": 1},
  "effect": "対象領地のレベルを1下げる",
  "effect_parsed": {
    "target_type": "land",
    "target_info": {
      "owner_filter": "any"
    },
    "effects": [
      {
        "effect_type": "change_level",
        "value": -1
      }
    ]
  }
}
```

### ランドトランス（ID: 2118）
```json
{
  "id": 2118,
  "name": "ランドトランス",
  "type": "spell",
  "spell_type": "単体対象",
  "cost": {"mp": 100},
  "effect": "対象自領地を手放し、その価値の70%を得る",
  "effect_parsed": {
    "target_type": "own_land",
    "target_info": {
      "owner_filter": "own"
    },
    "effects": [
      {
        "effect_type": "abandon_land",
        "return_rate": 0.7
      }
    ]
  }
}
```

---

## 統合の流れ

```
1. ユーザーがスペルカード選択
   ↓
2. SpellPhaseHandler.on_spell_selected()
   ↓
3. target_typeに基づいて対象選択UI表示
   - "own_land" → 自分の土地のみ選択可能
   - "enemy_land" → 敵の土地のみ選択可能
   - "land" → 全ての所有地選択可能
   ↓
4. ユーザーが土地選択
   ↓
5. execute_spell_effect() → _apply_single_effect()
   ↓
6. effect_typeに応じた処理
   - "change_element" → _apply_land_effect_change_element()
   - "change_level" → _apply_land_effect_change_level()
   - "abandon_land" → _apply_land_effect_abandon()
   - "destroy_creature" → _apply_land_effect_destroy_creature()
   ↓
7. GameFlowManager.spell_landのメソッド呼び出し
   ↓
8. 効果発動完了
```

---

## 現在の実装状況（最終）

### ✅ 完全実装済み
1. **SpellLand（基盤クラス）**: 10メソッド実装
2. **GameFlowManager統合**: 初期化処理完備
3. **SpellPhaseHandler統合**: 4種類のeffect_type対応
4. **ターゲット選択**: 土地選択UI対応

### 🎯 次のステップ
1. 個別スペルカードのJSON定義（`effect_parsed`追加）
2. 密命スペルの実装（フラットランド、ホームグラウンド）
3. 特殊スペル（ストームシフト、マグマシフト）
4. テストプレイ

---

## 対応可能なスペル（現時点: 11個）

### 基本的な土地操作（7個）
1. アースシフト（地属性に変更）
2. ウォーターシフト（水属性に変更）
3. エアーシフト（風属性に変更）
4. ファイアーシフト（火属性に変更）
5. クインテッセンス（無属性に変更）
6. アステロイド（レベル-1）
7. ランドトランス（土地放棄、70%返却）

### 高度な土地操作（4個）
8. インフルエンス（最多属性に変更）
9. サブサイド（最高レベル領地-1）
10. サドンインパクト（密命、レベル4領地-1）
11. フラットランド（密命、レベル2領地×5を+1）

---

**最終更新**: 2025年11月9日
