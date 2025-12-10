# リファクタリング計画

作成日: 2025/12/11

## 対象ファイル

### 1. spell_phase_handler.gd (1284行) → 3ファイル

**現状の問題:**
- フェーズ管理、ターゲット選択、スペル実行が1ファイルに混在
- 責務が多すぎて保守が困難

**分割計画:**

| 新ファイル | 責務 | 主要関数 |
|-----------|------|---------|
| `spell_phase_handler.gd` | フェーズ管理・統括 | start_spell_phase, complete_spell_phase, pass_spell, is_spell_phase_active |
| `spell_target_selector.gd` | ターゲット選択UI・処理 | _show_target_selection_ui, _update_target_selection, _confirm_target_selection, select_tile_from_list |
| `spell_effect_executor.gd` | スペル効果の実行 | execute_spell_effect, _apply_single_effect, _execute_spell_on_all_creatures |

**依存関係:**
```
spell_phase_handler.gd
  ├── spell_target_selector.gd (ターゲット選択を委譲)
  └── spell_effect_executor.gd (効果実行を委譲)
```

---

### 2. game_flow_manager.gd (936行) → 分割検討

**現状の問題:**
- ターン管理、周回システム、敵地支払い、統計管理が混在
- Phase 1-A関連のハンドラー管理も含む

**分割計画:**

| 新ファイル | 責務 | 主要関数 |
|-----------|------|---------|
| `game_flow_manager.gd` | コア（ターン管理・フェーズ制御） | start_game, start_turn, end_turn, roll_dice, change_phase |
| `lap_system.gd` | 周回管理 | _initialize_lap_state, _on_checkpoint_passed, _complete_lap, get_lap_count |
| `game_stats_manager.gd` | ゲーム統計・破壊カウンター | on_creature_destroyed, get_destroy_count, reset_destroy_count |

**依存関係:**
```
game_flow_manager.gd
  ├── lap_system.gd (周回イベント処理を委譲)
  └── game_stats_manager.gd (統計処理を委譲)
```

---

## 作業順序

1. [x] spell_phase_handler.gd 分割 (2025/12/11完了)
   - [x] spell_effect_executor.gd 抽出 (338行)
   - [-] spell_target_selector.gd → 不要（TargetSelectionHelperが既に存在）
   - [x] 動作確認
   - 結果: 1284行 → 925行 (約360行削減)

2. [x] game_flow_manager.gd 分割 (2025/12/11完了)
   - [x] lap_system.gd 抽出 (202行) - 周回管理 + 破壊カウンター
   - [x] ファサード方式に統一（lap_system直接参照）
   - [x] 動作確認完了
   - 結果: 936行 → 772行 (164行削減)
   - 備考: game_statsはworld_curse用にGameFlowManagerに残留

---

## 注意事項

- 各分割後に必ず動作確認を行う
- シグナル接続が壊れないよう注意
- 循環参照を避ける（親→子の参照のみ）
