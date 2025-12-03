# SpellCostModifier - コスト操作スペルシステム

## 概要

コストや制限を操作する特殊スペルを一元管理するクラス。  
SpellPhaseHandlerやSpellCurseからは委譲のみで、処理ロジックはSpellCostModifierに集約する。

## 対象スペル

### ライフフォース（ID: 2117）✅ 実装完了
- **効果**: 対象セプターに呪い"生命力"を付与
  - クリーチャー/アイテムのコストが0になる
  - スペル使用時に無効化され（捨て札）、呪いが解除される
- **コスト**: 50G
- **対象**: 任意のプレイヤー（自分含む）

### リリース（ID: 2125）❌ 未実装
- **効果**: 使用者に呪い"制限解除"を付与（4R）
  - クリーチャーのアイテム制限を無視
  - クリーチャーの配置制限を無視
- **コスト**: 50G
- **対象**: 使用者

## クラス設計

### ファイル
`scripts/spells/spell_cost_modifier.gd`

### 依存関係
```
GameSystemManager
    └── SpellCostModifier（初期化）
            ├── SpellCurse（呪い付与/解除）
            └── PlayerSystem（プレイヤー情報）

SpellPhaseHandler
    └── SpellCostModifier（委譲）
            ├── apply_life_force() - 呪い付与
            └── check_spell_nullify() - スペル無効化

TileActionProcessor / ItemPhaseHandler / CPUハンドラー
    └── SpellCostModifier.get_modified_cost() - コスト0化判定
```

### 実装済みインターフェース

```gdscript
class_name SpellCostModifier
extends RefCounted

# 参照
var spell_curse = null
var player_system: PlayerSystem = null

# セットアップ
func setup(p_spell_curse, p_player_system: PlayerSystem)

# ライフフォース呪い付与
func apply_life_force(target_player_id: int) -> Dictionary
# 戻り値: { "success": bool, "message": String }

# ライフフォース呪いチェック
func has_life_force(player_id: int) -> bool

# スペル使用時の無効化チェック
func check_spell_nullify(player_id: int) -> Dictionary
# 戻り値: { "nullified": bool, "curse_removed": bool, "message": String }

# カードコスト修正（クリーチャー/アイテムのコスト0化）
func get_modified_cost(player_id: int, card: Dictionary) -> int
```

## 処理フロー

### 1. ライフフォース呪い付与
```
SpellPhaseHandler._apply_single_effect()
    └── "life_force_curse" 
        └── SpellCostModifier.apply_life_force(target_player_id)
            └── SpellCurse.curse_player(target_player_id, "life_force", -1, params)
```

### 2. カードコスト修正（クリーチャー/アイテム）
```
TileActionProcessor / ItemPhaseHandler / CPUハンドラー
    └── カードコスト計算時
        └── SpellCostModifier.get_modified_cost(player_id, card)
            └── life_force呪いあり && (creature || item) → 0
```

### 3. スペル使用時の無効化
```
SpellPhaseHandler.use_spell()
    └── コスト支払い後
        └── SpellCostModifier.check_spell_nullify(current_player_id)
            └── life_force呪いあり
                ├── SpellCurse.remove_curse_from_player(player_id)
                ├── カードを捨て札へ
                └── return { "nullified": true, "curse_removed": true }
```

## JSON定義（effect_parsed）

### ライフフォース（2117）
```json
{
  "id": 2117,
  "name": "ライフフォース",
  "effect_parsed": {
    "target_type": "player",
    "target_info": {
      "include_self": true
    },
    "effects": [
      {
        "effect_type": "life_force_curse",
        "curse_type": "life_force",
        "duration": -1
      }
    ]
  }
}
```

## 呪いデータ構造

### ライフフォース
```gdscript
# player.curse に格納（player.buffs["curse"]ではない）
player.curse = {
    "curse_type": "life_force",
    "name": "生命力",
    "duration": -1,  # 永続（スペル使用で解除）
    "params": {
        "name": "生命力",
        "cost_zero_types": ["creature", "item"],
        "nullify_spell": true
    },
    "caster_id": -1
}
```

## 変更ファイル一覧

### 新規作成
- `scripts/spells/spell_cost_modifier.gd`

### 変更
| ファイル | 変更内容 |
|----------|----------|
| `data/spell_2.json` | 2117にeffect_parsed追加 |
| `scripts/game_flow_manager.gd` | `spell_cost_modifier`変数追加 |
| `scripts/system_manager/game_system_manager.gd` | SpellCostModifier初期化処理追加 |
| `scripts/game_flow/spell_phase_handler.gd` | `life_force_curse`効果処理 + `check_spell_nullify()`呼び出し |
| `scripts/tile_action_processor.gd` | 召喚/バトル/交換のコスト0化（3箇所） |
| `scripts/game_flow/item_phase_handler.gd` | アイテムコスト0化（2箇所） |
| `scripts/flow_handlers/cpu_ai_handler.gd` | CPUコスト計算対応 |
| `scripts/flow_handlers/cpu_turn_processor.gd` | CPU召喚コスト対応 |

## 今後の拡張候補

### リリース（2125）実装時に必要な作業
- アイテム制限チェック箇所の特定
- 配置制限チェック箇所の特定
- `apply_release()`, `has_release()`, `can_ignore_*()` メソッド追加

### その他
- コスト増減スペル
- 使用回数制限スペル
- 条件付きコスト変更スペル
