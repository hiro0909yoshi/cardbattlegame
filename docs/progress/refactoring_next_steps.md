# ドキュメント整備計画

**最終更新**: 2026-02-20
**前提**: コードリファクタリング Phase 0〜E 全完了。ドキュメントとの乖離を解消する。

---

## 監査サマリー

**監査対象**: docs/design/ 配下 115ファイル（全量監査実施）
**要更新**: 19ファイル（16%）
**最新**: 96ファイル（84%）

---

## Phase F: ドキュメント整備タスク

### F-1: コアアーキテクチャ文書（HIGH）

- [x] **design.md** — `.serena/memories/` 参照3箇所を削除、CLAUDE.md への誘導に差し替え ✅
- [x] **spells_design.md** — SpellSystemContainer 統合反映、全10システム記載、spell_effect_system.gd 修正 ✅
- [x] **game_system_manager_implementation.md** — Phase 5〜E 追記（UIEventHub/Callable注入/5サービス/UI Signal） ✅
- [x] **dependency_map.md** — 全面書き換え（参照方向図・Callable注入・改善メトリクス） ✅

### F-2: ツリー構造・参照マップ（MEDIUM）

- [x] **TREE_STRUCTURE.md** — 全面書き換え（詳細ツリー+参照方向図+5サービス+UIEventHub） ✅
- [x] **target_selection_system.md** — 確認済み、該当記述なし（修正不要） ✅

### F-3: ゲームシステム設計（MEDIUM）

- [x] **effect_system.md** — 確認済み、該当記述なし（修正不要） ✅
- [x] **hp_structure.md** — 確認済み、既に正確（修正不要） ✅
- [x] **toll_system.md** — Phase 1 SpellSystemContainer 統合注記追加 ✅
- [x] **turn_end_flow.md** — Phase 10-D Callable化注記追加 ✅

### F-4: CPU AI 設計（HIGH）

- [x] **cpu_ai/cpu_ai_design.md** — CPUSpellAIContainer をクラス構成図に追加 ✅
- [x] **cpu_ai/cpu_ai_overview.md** — コアファイル表に追加、コンテナ構造記載 ✅
- [x] **cpu_ai/cpu_spell_ai_spec.md** — アーキテクチャ図・主要ファイル表に追加 ✅
- [x] **cpu_ai/cpu_ai_understanding.md** — 実装ファイル構成・実装済み機能セクション更新 ✅

### F-5: スペル個別設計（LOW）

- [x] **spells/ドミニオ変更.md** — `spell_container.spell_land.*` に変更（5箇所） ✅
- [x] **spells/手札操作.md** — `spell_container.spell_draw` に変更（1箇所） ✅
- [x] **spells/ステータス増減.md** — `spell_container.spell_curse_stat` に変更（1箇所） ✅
- [x] **spells/制限解除.md** — `apply_single_effect()` に変更（1箇所） ✅
- [x] **spells/クリーチャー配置.md** — Signal駆動化注記追加（1箇所） ✅

---

## 更新不要（最新状態を確認済み）

### docs/design/ コア
| ファイル | 状態 |
|---------|------|
| battle_system.md | ✅ v1.3 正確 |
| skills_design.md | ✅ v3.0 正確 |
| effect_system_design.md | ✅ 設計仕様として正確 |
| bankruptcy_system.md | ✅ 正確 |
| lap_system.md | ✅ 正確 |
| tile_system.md | ✅ 正確 |
| special_tiles.md | ✅ 正確 |
| land_system.md | ✅ 正確 |
| mystic_arts.md | ✅ 正確 |
| mystic_arts_tasks.md | ✅ 正確 |
| global_navigation_buttons.md | ✅ NavigationService API記述として正確 |
| info_panel.md | ✅ 正確 |
| player_info_panel.md | ✅ 正確 |
| defensive_creature_design.md | ✅ 正確 |
| conditional_stat_buff_system.md | ✅ 正確 |
| condition_patterns_catalog.md | ✅ 正確 |

### docs/design/cpu_ai/
| ファイル | 状態 |
|---------|------|
| cpu_action_via_handler_spec.md | ✅ Phase 7-A 反映済み |
| cpu_battle_ai_spec.md | ✅ 正確 |
| cpu_battle_policy_system.md | ✅ 正確 |
| cpu_card_rate_system.md | ✅ 正確 |
| cpu_curse_evaluator.md | ✅ 正確 |
| cpu_deck_system.md | ✅ 構想ドキュメントとして適切 |
| cpu_movement_ai_spec.md | ✅ 正確 |
| cpu_spell_pattern_assignments.md | ✅ 正確 |
| cpu_territory_command_spec.md | ✅ 正確 |

### docs/design/skills/（29ファイル全て）
✅ 全ファイル最新 — ゲーム仕様記述のみ、アーキテクチャ参照なし

### docs/design/spells/（18ファイル）
✅ 上記5ファイル以外は全て最新

### docs/implementation/
| ファイル | 状態 |
|---------|------|
| signal_catalog.md | ✅ 234シグナル記録済み（2026-02-19） |
| delegation_method_catalog.md | ✅ Phase 10-C 反映済み |

### docs/development/
| ファイル | 状態 |
|---------|------|
| coding_standards.md | ✅ GDScript規約完全準拠 |

---

## docs/design/ 以外の要更新ファイル（参考）

| ファイル | 問題 | 優先度 |
|---------|------|--------|
| docs/README.md | `.serena/memories/`参照、壊れたリンク2件、シグナル数192→234 | MEDIUM |
| docs/implementation/implementation_patterns.md | `.serena/`参照、Phase 6〜E 新パターン6件未記載（最終更新 2025-10-23） | HIGH |
| docs/progress/architecture_migration_plan.md | Phase 3-A以降の進捗が古い（最終更新 2026-02-14） | MEDIUM |
| docs/analysis/IMPROVEMENT_ROADMAP.md | 提案が全て実装完了済みだが反映されていない | LOW |

---

## コードリファクタリング完了アーカイブ

Phase 0〜E の詳細は `docs/progress/daily_log.md` を参照。

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

### 残存コード改善事項（LOW 優先）

| 項目 | 現状 | 理由 |
|------|------|------|
| Board `var ui_manager` | init時にサブシステムへ渡す | TAP/CPUTurnProcessor のデカップリングが前提 |
| Board `var battle_system` | init時にサブシステムへ渡す | TAP/CPUAIHandler のデカップリングが前提 |
| Board `var game_flow_manager` | init時にサブシステムへ渡す | TAP/CPUAIHandler のデカップリングが前提 |
| GFM `var ui_manager` | 初期化時 + クロージャキャプチャのみ | ランタイム直接呼び出しゼロ |
| UIManager `game_flow_manager_ref` | 17ファイルが使用 | UI→Logic 逆参照（大規模作業） |
| B-3〜B-5 | Service化済み、実害なし | TBE/TSE/STSH/CSH の ui_manager 保持 |
| B-6 SpellUIManager | 設計上 UIManager 参照必要 | 現状維持 |
| tutorial_manager | UIManager 直接参照 | チュートリアル再設計が前提 |
