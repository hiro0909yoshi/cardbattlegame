# リファクタリング作業計画

**最終更新**: 2026-02-20
**前提**: Phase 0〜12 + Phase A〜E 完了済み

---

## 現状サマリー

Phase 0〜12 でアーキテクチャ移行・UI層分離を完了。
Phase A〜D で相互参照・逆参照・チェーンアクセスを解消。
Phase E で BoardSystem3D / GFM の依存方向を改善。

**残存する改善対象は LOW 優先のみ。**

---

## Phase E: BoardSystem3D + GFM 依存方向改善 ✅ 完了

### E-1: Board → UI 直接依存を外す ✅
- `_on_movement_completed()` の `ui_manager.show/hide_dominio_order_button()` → Callable 注入
- GSM `_setup_ui_callbacks()` で注入

### E-2: Board → Battle 直接依存を弱める ✅
- `get_battle_screen_manager()` を `battle_system` 経由 → `_battle_screen_manager_ref` 直接参照
- GSM `_setup_battle_screen_manager()` で注入

### E-3: Board → GFM 逆参照を Callable に ✅
- `trigger_land_curse_on_stop()` → `_trigger_land_curse_cb` Callable
- `is_game_ended` → `_is_game_ended_cb` Callable
- GSM `_setup_ui_callbacks()` で注入

### E-4: GFM → UI 呼び出しを Signal/Callable ハイブリッド化 ✅

**Signal 駆動（GSM シグナルハンドラー）:**
- `turn_started` → `set_current_turn()` + `hide_dominio_order_button()`
- `phase_changed` → `close_all_info_panels()` + `update_ui()`

**Callable 駆動（GFM `inject_ui_callbacks()` で7個注入）:**
- `set_phase_text`, `update_panels`, `show/hide_dominio_btn`
- `show/hide_card_selection`, `enable_navigation`

### E-5: GFM 清掃 ✅
- 死んだ preload 定数 11個削除
- `get_tutorial_manager()` チェーンアクセス → Callable 注入
- `ui_manager.game_flow_manager_ref = self` → GSM に移動

### E-6: CPU AI チェーンアクセス解消 ✅
- CPUSpellPhaseHandler: 13箇所のチェーンアクセス → ローカル変数化
- battle_policy: 4段チェーン → Callable getter（遅延評価）

### E-7: GDScript 警告修正 ✅
- STANDALONE_TERNARY 11件、UNUSED_PARAMETER 2件、UNUSED_VARIABLE 1件

---

## 残存事項（LOW 優先）

| 項目 | 現状 | 理由 |
|------|------|------|
| Board `var ui_manager` | init時にサブシステムへ渡す | TAP/CPUTurnProcessor のデカップリングが前提 |
| Board `var battle_system` | init時にサブシステムへ渡す | TAP/CPUAIHandler のデカップリングが前提 |
| Board `var game_flow_manager` | init時にサブシステムへ渡す | TAP/CPUAIHandler のデカップリングが前提 |
| GFM `var ui_manager` | setup_3d_mode でサービス渡し | GSM に移動可能 |
| UIManager `game_flow_manager_ref` | 17ファイルが使用 | UI→Logic 逆参照（大規模作業） |
| B-3〜B-5 | Service化済み、実害なし | TBE/TSE/STSH/CSH の ui_manager 保持 |
| B-6 SpellUIManager | 設計上 UIManager 参照必要 | 現状維持 |
| tutorial_manager | UIManager 直接参照 | チュートリアル再設計が前提 |

---

## 完了済みアーカイブ

Phase 0〜12 の詳細は `docs/progress/daily_log.md` を参照。

| Phase | 内容 | 完了日 |
|-------|------|--------|
| 0〜9 | アーキテクチャ移行・UI層分離・状態ルーター解体 | 〜2026-02-19 |
| 10 | PlayerInfoService・card.gd改善・双方向参照削減 | 2026-02-19 |
| 11 | UIManager適正化（ファサード化・Node整理） | 2026-02-20 |
| UIEventHub | UI→ロジック間イベント駆動化 | 2026-02-20 |
| 12 | BankruptcyHandler パネル分離 + TapTargetManager 直接注入 | 2026-02-20 |
| A-1〜A-3 | 相互参照の解消（CRITICAL 4組） | 2026-02-20 |
| B-0〜B-3 | UIManager残存参照の削減（DCH/LapSystem/GRH） | 2026-02-20 |
| C-1〜C-8 | Spell系の逆参照削減（8ファイル） | 2026-02-20 |
| D-1〜D-2 | GFMチェーンアクセス解消 | 2026-02-20 |
| E-1〜E-7 | Board/GFM依存方向改善 + CPU AI + 警告修正 | 2026-02-20 |
| バグ修正 | ナビ状態・ボタン消失・GDScript警告・TBE null参照等 | 2026-02-20 |
