# SkillSystem → PlayerBuffSystem リネーム影響範囲

## リネーム対象
- **ファイル**: `scripts/skill_system.gd` → `scripts/player_buff_system.gd`
- **クラス名**: `SkillSystem` → `PlayerBuffSystem`
- **変数名**: `skill_system` → `player_buff_system`

## 影響を受けるファイル（全15ファイル）

### 【優先度 高】インスタンス参照・型宣言

#### 1. scripts/game_3d.gd (2箇所)
- 11行: `var skill_system: SkillSystem`
- 63行: `skill_system = SkillSystem.new()`
- 64行: `skill_system.name = "SkillSystem"`
- 65行: `add_child(skill_system)`
- 136行: 関数呼び出しで `skill_system` を参照
- 140行: 関数呼び出しで `skill_system` を参照

#### 2. scripts/board_system_3d.gd (2箇所)
- 55行: `var skill_system: SkillSystem`
- 119行: `s_system: SkillSystem` パラメータ
- 123行: `skill_system = s_system`
- 163行: `skill_system` を渡す

#### 3. scripts/flow_handlers/cpu_ai_handler.gd (2箇所)
- 25行: `var skill_system: SkillSystem`
- 31行: `s_system: SkillSystem` パラメータ
- 36行: `skill_system = s_system`
- 202-203行: `skill_system.modify_card_cost()` 呼び出し

#### 4. scripts/game_flow_manager.gd (2箇所)
- 41行: `var skill_system: SkillSystem`
- 102行: `skill_system = s_system`
- 250行: `skill_system.modify_dice_roll()` 呼び出し
- 490行: `skill_system.end_turn_cleanup()` 呼び出し

### 【優先度 中】静的メソッド呼び出し（SkillSystem.has_unyielding()）

#### 5. scripts/game_flow/land_action_helper.gd (3箇所)
- 41行: `SkillSystem.has_unyielding(creature)`
- 257行: `SkillSystem.has_unyielding(creature_data)`
- 315行: `SkillSystem.has_unyielding(attacker_data)`
- 437行: `SkillSystem.has_unyielding(creature)`

#### 6. scripts/game_flow/movement_helper.gd (1箇所)
- 255行: `SkillSystem.has_unyielding(creature_data)`

#### 7. scripts/battle_system.gd (1箇所)
- 373行: `SkillSystem.has_unyielding(return_data)`

#### 8. scripts/tile_action_processor.gd (2箇所)
- 340行: `SkillSystem.has_unyielding(card_data)`
- 503行: `SkillSystem.has_unyielding(card_data)`

#### 9. scripts/game_flow/land_command_handler.gd.backup.disabled (4箇所)
- バックアップファイル（無視可）

### 【優先度 低】ドキュメント更新（参考資料）

#### 10. docs/design/turn_end_flow.md
- 53行: `skill_system.end_turn_cleanup()`

#### 11. docs/design/land_system.md
- 155行: コメント「SkillSystem.gd」
- 165行: `SkillSystem.has_unyielding()`

#### 12. docs/design/skills/indomitable_skill.md
- 89行, 107行, 118行: `SkillSystem.has_unyielding()`

#### 13. docs/design/skills/vacant_move_skill.md
- 214行: `SkillSystem.has_unyielding()`

#### 14. docs/design/refactoring/system_architecture_refactoring_plan.md
- 複数箇所: SkillSystem の説明

#### 15. docs/design/refactoring/skillsystem_expansion_plan.md
- 複数箇所: SkillSystem のドキュメント

## リネーム作業サマリー

### コード修正（必須）
| ファイル | 修正数 | 内容 |
|---------|--------|------|
| scripts/skill_system.gd | 3 | クラス名、print文 |
| scripts/game_3d.gd | 6 | 型宣言、インスタンス化、参照 |
| scripts/board_system_3d.gd | 4 | 型宣言、パラメータ、参照 |
| scripts/flow_handlers/cpu_ai_handler.gd | 4 | 型宣言、パラメータ、参照 |
| scripts/game_flow_manager.gd | 4 | 型宣言、パラメータ、参照 |
| scripts/game_flow/land_action_helper.gd | 4 | 静的メソッド呼び出し |
| scripts/game_flow/movement_helper.gd | 1 | 静的メソッド呼び出し |
| scripts/battle_system.gd | 1 | 静的メソッド呼び出し |
| scripts/tile_action_processor.gd | 2 | 静的メソッド呼び出し |
| **合計** | **29** | **コード修正** |

### ドキュメント更新（推奨）
- 11ファイル（優先度低）
- 将来のメンテナンス性向上

## 実装順序

1. ✅ ファイルリネーム: `skill_system.gd` → `player_buff_system.gd`
2. ✅ クラス名変更: `class_name SkillSystem` → `class_name PlayerBuffSystem`
3. ✅ コード修正: 29箇所の参照更新
4. 🔵 ドキュメント更新: 11ファイル
5. 🔵 Godot 構文チェック
6. 🔵 ゲーム起動テスト

## 注意点
- 静的メソッド `has_unyielding()` も同じクラス内にあるため、全て置換対象
- ファイル名変更後、GDScriptは自動的に新しいクラス名を認識
- Godot エディタのキャッシュをクリアすると安全（Ctrl+Shift+P → Clear Script Cache）
