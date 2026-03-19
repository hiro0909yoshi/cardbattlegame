# push_error / push_warning → GameLogger 移行計画

**作成日**: 2026-03-19
**対象**: 67ファイル / 274件（battle_test, logger.gd 除外）
**方針**: ファイル単位で精査。デッドコード・不要コードは削除、必要なもののみ GameLogger 変換

---

## 調査結果サマリ

| 判定 | 件数 | 内容 |
|------|------|------|
| **変換** | 271 | GameLogger.error() / GameLogger.warn() へ変換 |
| **維持** | 3 | 抽象メソッドスタブ（push_error のまま） |
| **削除** | 0 | デッドコードなし — 全メソッドが使用されている |

**ステータス: ✅ 全件完了（2026-03-19）**

**維持対象の詳細**:
- `scripts/spells/strategies/spell_strategy.gd` L11, L17 — validate() / execute() 抽象メソッド
- `scripts/skills/skill_effect_base.gd` L239 — apply_effect() 抽象メソッド

---

## ステータス凡例

- ⬜ 未着手
- 🔄 作業中
- ✅ 完了

---

## 対象ファイル一覧（件数降順）

### 大規模（10件以上）— 全て変換

| # | ファイル | 件数 | ステータス | 調査結果 |
|---|---------|------|-----------|---------|
| 1 | `system_manager/game_system_manager.gd` | 32 | ⬜ | 全て変換。初期化チェック・null参照ガード中心 |
| 2 | `spells/spell_land_new.gd` | 18 | ⬜ | 全て変換。データ検証・パラメータバリデーション |
| 3 | `game_flow/spell_target_selection_handler.gd` | 15 | ⬜ | 全て変換。初期化チェック（SPH/spell_flow null） |
| 4 | `game_flow/spell_effect_executor.gd` | 11 | ⬜ | 全て変換。初期化+Strategy バリデーション |
| 5 | `spells/spell_mystic_arts.gd` | 10 | ⬜ | 全て変換。spell_phase_handler/UI参照チェック |
| 6 | `spells/spell_magic.gd` | 10 | ⬜ | 全て変換。PlayerSystem null + player_id 検証 |
| 7 | `spells/spell_draw/basic_draw_handler.gd` | 10 | ⬜ | 全て変換。CardSystem null チェック×9 + UI |
| 8 | `quest/stage_loader.gd` | 10 | ⬜ | 全て変換。ファイル読み込み・JSONパースエラー |
| 9 | `game_flow/spell_phase_handler.gd` | 10 | ⬜ | 全て変換。初期化・状態チェック |

### 中規模（4〜9件）

| # | ファイル | 件数 | ステータス | 調査結果 |
|---|---------|------|-----------|---------|
| 10 | `spells/spell_draw/destroy_handler.gd` | 7 | ⬜ | 全て変換。CardSystem/PlayerSystem null チェック |
| 11 | `game_flow/spell_ui_manager.gd` | 7 | ⬜ | 全て変換。初期化+シグナル接続チェック |
| 12 | `game_flow_manager.gd` | 7 | ⬜ | 全て変換。ハンドラー初期化・メソッド存在チェック |
| 13 | `game_flow/spell_flow_handler.gd` | 6 | ⬜ | 全て変換。ハンドラー初期化フォールバック |
| 14 | `game_flow/mystic_arts_handler.gd` | 6 | ⬜ | 全て変換。システム参照チェック |
| 15 | `board_system_3d.gd` | 6 | ⬜ | 全て変換。属性検証・タイル生成・データ整合性 |
| 16 | `network/network_manager.gd` | 5 | ⬜ | 全て変換。接続・サーバー起動・JSON受信エラー |
| 17 | `user_card_db.gd` | 4 | ⬜ | 全て変換。DB初期化・テーブル作成エラー |
| 18 | `tutorial/explanation_mode.gd` | 4 | ⬜ | 全て変換（warn）。UI参照 null チェック |
| 19 | `system/object_pool.gd` | 4 | ⬜ | 全て変換。プール管理エラー |
| 20 | `spells/spell_transform.gd` | 4 | ⬜ | 全て変換。未対応type・クリーチャー検索失敗 |
| 21 | `spells/spell_draw/steal_handler.gd` | 4 | ⬜ | 全て変換。CardSystem/BoardSystem null チェック |
| 22 | `skills/skill_effect_base.gd` | 4 | ⬜ | 3件変換 + 1件維持（L239 抽象メソッド） |
| 23 | `quest/quest_game.gd` | 4 | ⬜ | 全て変換。ステージ読み込み・CPU初期化チェック |
| 24 | `helpers/card_sacrifice_helper.gd` | 4 | ⬜ | 全て変換。CardSystem null + カード検索失敗 |
| 25 | `cpu_ai/cpu_spell_ai_container.gd` | 4 | ⬜ | 全て変換。4サブシステム null チェック |
| 26 | `card_system.gd` | 4 | ⬜ | 全て変換。player_id検証・デッキ空チェック |

### 小規模（2〜3件）

| # | ファイル | 件数 | ステータス | 調査結果 |
|---|---------|------|-----------|---------|
| 27 | `tiles/magic_stone_tile.gd` | 3 | ⬜ | 全て変換。UI/システム初期化チェック |
| 28 | `spells/strategies/spell_strategy.gd` | 3 | ⬜ | 1件変換（L78 _log_error）+ 2件維持（L11,17 抽象） |
| 29 | `battle/skills/skill_item_return.gd` | 3 | ⬜ | 全て変換。CardSystem参照+カードID検証 |
| 30 | `battle/battle_special_effects.gd` | 3 | ⬜ | 全て変換。SpellDraw/SpellMagic/CardSystem参照 |
| 31 | `battle_system.gd` | 3 | ⬜ | 全て変換。spell_draw/magic/board 初期化チェック |
| 32 | `ui_tap_handler.gd` | 2 | ⬜ | 全て変換（warn）。カメラコントローラ参照 |
| 33 | `tutorial/tutorial_manager.gd` | 2 | ⬜ | 全て変換。ファイル読み込み・JSONパース |
| 34 | `tiles/base_tiles.gd` | 2 | ⬜ | 全て変換。CreatureManager初期化チェック |
| 35 | `spells/spell_player_move.gd` | 2 | ⬜ | 全て変換。tile_neighbor_system未設定 |
| 36 | `spells/spell_draw/deck_handler.gd` | 2 | ⬜ | 全て変換。CardSystem null チェック |
| 37 | `spells/spell_draw/condition_handler.gd` | 2 | ⬜ | 全て変換。CardSystem null + カードID検証 |
| 38 | `spells/spell_creature_swap.gd` | 2 | ⬜ | 全て変換。未対応type・タイル無効 |
| 39 | `spells/spell_creature_move.gd` | 2 | ⬜ | 全て変換。未対応type・battle_system参照 |
| 40 | `skills/creature_synthesis.gd` | 2 | ⬜ | 全て変換。犠牲カード検証・変身先ID検証 |
| 41 | `quest/base_environment.gd` | 2 | ⬜ | 全て変換。タイル検索・リソース読み込み |
| 42 | `game_flow/game_flow_state_machine.gd` | 2 | ⬜ | 全て変換。enum初期化・遷移検証 |
| 43 | `battle_screen/battle_screen_manager.gd` | 2 | ⬜ | 全て変換（warn+error）。重複起動・インスタンス取得 |

### 最小（1件）

| # | ファイル | 件数 | ステータス | 調査結果 |
|---|---------|------|-----------|---------|
| 44 | `utils/tile_mesh_colorizer.gd` | 1 | ⬜ | 変換。メッシュ未設定 |
| 45 | `ui_manager.gd` | 1 | ⬜ | 変換。board_system_ref null |
| 46 | `ui_components/bankruptcy_info_panel_ui.gd` | 1 | ⬜ | 変換。ui_layer未設定 |
| 47 | `tiles/magic_tile.gd` | 1 | ⬜ | 変換。MessageService/ui_layer |
| 48 | `tiles/checkpoint_tile.gd` | 1 | ⬜ | 変換（warn）。SPタイルモデル |
| 49 | `tiles/card_give_tile.gd` | 1 | ⬜ | 変換。MessageService/ui_layer |
| 50 | `tiles/card_buy_tile.gd` | 1 | ⬜ | 変換。MessageService/ui_layer |
| 51 | `tiles/branch_tile.gd` | 1 | ⬜ | 変換。サービス参照 |
| 52 | `spells/spell_creature_return.gd` | 1 | ⬜ | 変換。未対応type |
| 53 | `skills/condition_checker.gd` | 1 | ⬜ | 変換（warn）。未実装条件タイプ |
| 54 | `signal_registry.gd` | 1 | ⬜ | 変換。未初期化 |
| 55 | `quest/castle_environment.gd` | 1 | ⬜ | 変換。シェーダー読み込み失敗 |
| 56 | `game_flow/game_result_handler.gd` | 1 | ⬜ | 変換。SceneTree取得失敗 |
| 57 | `game_flow/dice_phase_handler.gd` | 1 | ⬜ | 変換。spell_flow初期化チェック |
| 58 | `game_flow/bankruptcy_handler.gd` | 1 | ⬜ | 変換（warn）。重複処理ガード |
| 59 | `game_data.gd` | 1 | ⬜ | 変換（warn）。デッキ検証結果 |
| 60 | `game_3d.gd` | 1 | ⬜ | 変換。ステージ読み込み失敗 |
| 61 | `deck_editor.gd` | 1 | ⬜ | 変換（warn）。所持数超過 |
| 62 | `cpu_ai/cpu_target_resolver.gd` | 1 | ⬜ | 変換（warn）。未知のtarget_condition |
| 63 | `cpu_ai/cpu_spell_condition_checker.gd` | 1 | ⬜ | 変換（warn）。未知のcondition |
| 64 | `cpu_ai/cpu_spell_ai.gd` | 1 | ⬜ | 変換（warn）。未知のprofit_condition |
| 65 | `cpu_ai/cpu_movement_evaluator.gd` | 1 | ⬜ | 変換（warn）。movement_controller未設定 |
| 66 | `cpu_ai/checkpoint_distance_calculator.gd` | 1 | ⬜ | 変換（warn）。チェックポイント未検出 |
| 67 | `battle/battle_participant.gd` | 1 | ⬜ | 変換。未知の演算子 |
| 68 | `battle_screen/battle_creature_display.gd` | 1 | ⬜ | 変換。Card.tscn読み込み失敗 |

---

## 除外ファイル

| ファイル | 理由 |
|---------|------|
| `scripts/battle_test/*.gd` | テスト専用コード — 後日対応 |
| `scripts/autoload/logger.gd` | GameLogger 自身 — push_error 維持 |

---

## 変換ルール

| 元の呼び出し | 変換先 | カテゴリ選定 |
|-------------|--------|-------------|
| `push_error("...")` | `GameLogger.error("Category", "...")` | ファイルの機能に応じて |
| `push_warning("...")` | `GameLogger.warn("Category", "...")` | ファイルの機能に応じて |

### カテゴリマッピング

| カテゴリ | 対象ファイル群 |
|---------|--------------|
| `"Init"` | game_system_manager, 各handler初期化チェック |
| `"Spell"` | spell_*, spell_draw/*, spell_flow_handler |
| `"Battle"` | battle_system, battle_special_effects, battle_participant |
| `"Board"` | board_system_3d, base_tiles, tile_* |
| `"Card"` | card_system, card_sacrifice_helper |
| `"Move"` | spell_player_move, spell_creature_move/swap/return |
| `"CPU"` | cpu_ai/* |
| `"UI"` | ui_manager, spell_ui_manager, ui_tap_handler, ui_components/* |
| `"Quest"` | quest_game, stage_loader, base_environment, castle_environment |
| `"Data"` | game_data, user_card_db, deck_editor |
| `"SM"` | game_flow_state_machine |
| `"Network"` | network_manager |
| `"Skill"` | skill_effect_base, condition_checker, creature_synthesis |
| `"Tutorial"` | tutorial_manager, explanation_mode |
| `"System"` | object_pool, signal_registry |
