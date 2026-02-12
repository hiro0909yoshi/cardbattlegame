# Data Structures & Reference

Coding conventions: see `/mnt/skills/user/gdscript-coding/SKILL.md`

## 追加コーディング規約（SKILLファイル補足）

### privateメソッドを外部から呼ばない
`_` プレフィックスのメソッドは定義ファイル内でのみ呼ぶ。
外部から必要な場合は public メソッドとして公開するか、適切なクラス（例: SummonConditionChecker）に移動する。

### 状態フラグの外部直接setを禁止
他クラスの状態フラグ（`is_xxx`）を外部から直接 `= true/false` しない。
代わりに `begin_xxx()` / `reset_xxx()` 等の明示的メソッドを用意する。
例: `tile_action_processor.begin_action_processing()` / `reset_action_processing()`

### デバッグフラグは DebugSettings に集約
召喚条件やアイテム制限のデバッグフラグは `DebugSettings` クラス（static変数）を使う。
各システムに個別のデバッグフラグを持たせない。
```gdscript
# ✅ DebugSettings経由
if DebugSettings.disable_lands_required: ...

# ❌ 個別システムのフラグ
if tile_action_processor.debug_disable_lands_required: ...
```

### UI表示はui_managerの委譲メソッド経由でアクセス
phase_display, global_comment_ui, hand_displayへのチェーンアクセスは委譲メソッドを使う。
- `ui_manager.show_toast(msg)` → `phase_display.show_toast()`
- `ui_manager.show_action_prompt(msg)` → `phase_display.show_action_prompt()`
- `ui_manager.hide_action_prompt()` → `phase_display.hide_action_prompt()`
- `ui_manager.show_comment_and_wait(msg, pid, force)` → `global_comment_ui.show_and_wait()`
- `ui_manager.show_choice_and_wait(msg, pid, yes, no)` → `global_comment_ui.show_choice_and_wait()`
- `ui_manager.show_comment_message(msg)` → `global_comment_ui.show_message()`
- `ui_manager.hide_comment_message()` → `global_comment_ui.hide_message()`
- `ui_manager.update_hand_display(pid)` → `hand_display.update_hand_display()`
- `ui_manager.show_card_info_only(data, tile)` → パネル直接表示（ナビゲーションに触らない）

### インフォパネルはui_managerの統合メソッド経由でアクセス
3つのinfo_panel（creature/spell/item）の一括操作はui_managerの統合メソッドを使う。
- `hide_all_info_panels(clear_buttons)`: 全パネル一括非表示
- `is_any_info_panel_visible()`: いずれかが表示中か
- `show_card_info(card_data, tile_index, setup_buttons)`: 種別自動判定で閲覧表示
- `show_card_selection(card_data, hand_index, ...)`: 種別自動判定で選択表示
creature固有の操作（タップ表示等）は直接アクセスOK。

### 内部プロパティを外部から直接参照しない
他クラスの内部プロパティ（`creature_synthesis`, `sacrifice_selector` 等）に直接アクセスしない。
initialize時に引数として渡すか、getter メソッドを用意する。
Initialization order: see `/mnt/skills/user/gdscript-initialization/SKILL.md`
UI flow rules: see `/mnt/skills/user/gdscript-ui-flow/SKILL.md`

## Card Data Structures (JSON)

### Creature
id, name, rarity, type, element, cost{ep, lands_required}, ap, hp, ability, ability_detail, ability_parsed

### Item
id, name, rarity, type, item_type, cost{ep}, effect, effect_parsed

### Spell
id, name, rarity, type, spell_type, cost{ep}, effect, effect_parsed, cpu_rule

## ability_parsed Structure
```json
{
  "keywords": ["強打", "先制", "感応"],
  "keyword_conditions": { "keyword_name": { ... } },
  "effects": [{
    "effect_type": "power_strike|instant_death|item_return|...",
    "trigger": "after_item_use|battle_start|...",
    "target": "self|enemy|all_enemies|all_items",
    "stat": "AP|HP",
    "operation": "add|multiply",
    "value": 20,
    "multiplier": { ... },
    "elements": [...],
    "conditions": [{
      "condition_type": "adjacent_ally_land|mhp_below|...",
      "value": 40
    }],
    "return_type": "return_to_deck|return_to_hand"
  }],
  "mystic_arts": [{ "id": int, "name": str, "description": str, "spell_id": int, "cost": int }]
}
```

## Runtime creature_data Fields
- `base_up_hp`, `base_up_ap`: permanent stat boosts (mass growth, synthesis, lap bonus)
- `current_hp`: HP after battle
- `curse`: curse Dictionary
- `items`: equipped items (battle only)
- `permanent_effects`, `temporary_effects`: effect arrays

## GamePhase Enum
```gdscript
enum GamePhase { SETUP, DICE_ROLL, MOVING, TILE_ACTION, BATTLE, END_TURN }
```
