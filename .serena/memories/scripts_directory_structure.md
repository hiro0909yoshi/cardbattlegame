# Scripts Directory Structure (Updated: 2026-01-16)

## Root Level (`scripts/`)
### Main Systems
- `game_flow_manager.gd` - ターン・フェーズ制御
- `board_system_3d.gd` - 3Dボード・タイル所有権
- `player_system.gd` - プレイヤー状態・魔力
- `card_system.gd` - デッキ・手札管理
- `battle_system.gd` - バトル処理
- `creature_manager.gd` - クリーチャーデータ一元管理
- `ui_manager.gd` - UI統合管理
- `tile_action_processor.gd` - タイルアクション処理
- `tile_data_manager.gd` - タイル情報・通行料計算
- `movement_controller.gd` - プレイヤー移動制御
- `effect_manager.gd` - エフェクト管理
- `special_tile_system.gd` - 特殊タイル処理

### Utilities
- `game_constants.gd` - 全ゲーム定数
- `card_loader.gd` - カードJSON読み込み
- `signal_registry.gd` - シグナル登録
- `tile_neighbor_system.gd` - 隣接タイル判定
- `tile_helper.gd` - タイルユーティリティ
- `player_buff_system.gd` - プレイヤーバフ管理
- `game_data.gd` - セーブ/ロード
- `game_settings.gd` - 設定管理

### Scene Scripts
- `game_3d.gd` - メインゲームシーン
- `main_menu.gd` - メインメニュー
- `album.gd` - アルバム画面
- `deck_select.gd` - デッキ選択
- `deck_editor.gd` - デッキ編集
- `camera_controller.gd` - カメラ制御
- `debug_controller.gd` - デバッグ機能

---

## `/system_manager/`
- `game_system_manager.gd` - 6フェーズ初期化、システム統合管理

---

## `/cpu_ai/` - CPU AI システム（22ファイル）
### Core
- `cpu_ai_handler.gd` - 統合ハンドラー（フェーズ振り分け）
- `cpu_ai_context.gd` - 共有コンテキスト（システム参照保持）
- `cpu_ai_constants.gd` - AI定数

### Turn Processing
- `cpu_turn_processor.gd` - ターン処理（召喚・レベルアップ等）
- `cpu_movement_evaluator.gd` - 移動先評価・方向選択
- `checkpoint_distance_calculator.gd` - チェックポイント距離計算

### Battle AI
- `cpu_battle_ai.gd` - バトル判断
- `cpu_defense_ai.gd` - 防御判断
- `cpu_merge_evaluator.gd` - 合体評価
- `battle_simulator.gd` - バトル結果シミュレーション

### Spell/Mystic AI
- `cpu_spell_ai.gd` - スペル使用判断
- `cpu_mystic_arts_ai.gd` - ミスティックアーツ判断
- `cpu_spell_condition_checker.gd` - スペル条件チェック
- `cpu_spell_target_selector.gd` - スペルターゲット選択
- `cpu_spell_utils.gd` - スペルユーティリティ
- `cpu_target_resolver.gd` - ターゲット解決

### Territory AI
- `cpu_territory_ai.gd` - 領地コマンド判断
- `cpu_sacrifice_selector.gd` - 犠牲カード選択
- `cpu_special_tile_ai.gd` - 特殊タイル判断

### Utilities
- `cpu_hand_utils.gd` - 手札管理ユーティリティ
- `cpu_board_analyzer.gd` - 盤面分析
- `cpu_curse_evaluator.gd` - 呪い評価
- `card_rate_evaluator.gd` - カードレート評価

---

## `/game_flow/` - ゲームフロー制御（12ファイル）
- `spell_phase_handler.gd` - スペルフェーズ管理
- `item_phase_handler.gd` - アイテムフェーズ管理
- `lap_system.gd` - 周回システム
- `bankruptcy_handler.gd` - 破産処理

### Land Command
- `land_command_handler.gd` - 領地コマンド管理
- `land_action_helper.gd` - 領地アクション実行
- `land_selection_helper.gd` - 領地選択
- `land_input_helper.gd` - 領地入力処理

### Utilities
- `target_selection_helper.gd` - ターゲット選択
- `spell_effect_executor.gd` - スペル効果実行
- `movement_helper.gd` - 移動処理
- `debug_command_handler.gd` - デバッグコマンド

---

## `/battle/` - バトルシステム（7ファイル + skills/）
- `battle_participant.gd` - バトル参加者クラス
- `battle_preparation.gd` - バトル準備（アイテム選択）
- `battle_execution.gd` - バトル実行
- `battle_skill_processor.gd` - スキル処理
- `battle_special_effects.gd` - 特殊効果
- `battle_item_applier.gd` - アイテム効果適用
- `battle_curse_applier.gd` - 呪い効果適用
- `battle_skill_granter.gd` - スキル付与

### `/battle/skills/` - バトルスキル実装（24ファイル）
- `skill_first_strike.gd` - 先制
- `skill_double_attack.gd` - 2回攻撃
- `skill_power_strike.gd` - 強打
- `skill_penetration.gd` - 貫通
- `skill_reflect.gd` - 反射
- `skill_resonance.gd` - 共鳴
- `skill_support.gd` / `skill_assist.gd` - 援護
- `skill_merge.gd` - 合体
- `skill_transform.gd` - 変身
- `skill_scroll_attack.gd` - 巻物攻撃
- `skill_land_effects.gd` - 土地効果
- `skill_stat_modifiers.gd` - ステータス修正
- `skill_item_return.gd` - アイテム返却
- `skill_item_creature.gd` - リビング系
- `skill_item_manipulation.gd` - アイテム操作
- `skill_creature_spawn.gd` - クリーチャー生成
- `skill_magic_steal.gd` / `skill_magic_gain.gd` - 魔力操作
- `skill_special_creature.gd` - 特殊クリーチャー
- `skill_battle_start_conditions.gd` - バトル開始条件
- `skill_battle_end_effects.gd` - バトル終了効果
- `skill_permanent_buff.gd` - 永続バフ
- `skill_legacy.gd` - レガシースキル

---

## `/skills/` - スキルシステム共通（5ファイル）
- `condition_checker.gd` - 条件判定
- `skill_effect_base.gd` - 効果基底クラス
- `skill_log_system.gd` - スキルログ
- `skill_secret.gd` - 秘術
- `skill_toll_change.gd` - 通行料変更
- `creature_synthesis.gd` - クリーチャー合成

---

## `/spells/` - スペル実装（26ファイル）
### Core
- `spell_draw.gd` - ドロー系（16種）
- `spell_magic.gd` - 魔力操作
- `spell_curse.gd` - 呪い管理
- `spell_dice.gd` - サイコロ操作

### Curse Types
- `spell_curse_stat.gd` - ステータス呪い
- `spell_curse_toll.gd` - 通行料呪い
- `spell_curse_battle.gd` - バトル制限呪い
- `spell_world_curse.gd` - ワールド呪い

### Land/Creature
- `spell_land_new.gd` - 土地操作
- `spell_creature_place.gd` - クリーチャー配置
- `spell_creature_move.gd` - クリーチャー移動
- `spell_creature_swap.gd` - クリーチャー交換
- `spell_creature_return.gd` - クリーチャー返却
- `spell_transform.gd` - 変身

### Player
- `spell_player_move.gd` - プレイヤー移動
- `spell_movement.gd` - 移動制御
- `spell_borrow.gd` - 借用

### Utilities
- `spell_damage.gd` - ダメージ処理
- `spell_protection.gd` - 保護
- `spell_restriction.gd` - 制限
- `spell_purify.gd` - 浄化
- `spell_hp_immune.gd` - HP変更無効
- `spell_cost_modifier.gd` - コスト変更
- `spell_synthesis.gd` - スペル合成
- `spell_mystic_arts.gd` - ミスティックアーツ
- `card_selection_handler.gd` - カード選択処理

---

## `/tiles/` - タイル実装（17ファイル）
### Base
- `base_tiles.gd` - 基底クラス（creature_dataプロパティ）
- `special_base_tile.gd` - 特殊タイル基底

### Elements
- `fire_tile.gd`, `water_tile.gd`, `earth_tile.gd`, `wind_tile.gd`, `neutral_tile.gd`

### Special
- `checkpoint_tile.gd` - チェックポイント
- `warp_tile.gd` - ワープ
- `warp_stop_tile.gd` - ワープ停止
- `branch_tile.gd` - 分岐
- `magic_tile.gd` - 魔法陣
- `magic_stone_tile.gd` - 魔石
- `magic_stone_system.gd` - 魔石システム
- `card_buy_tile.gd` - カード購入
- `card_give_tile.gd` - カード配布

---

## `/ui_components/` - UI部品（26ファイル）
### Core
- `player_info_panel.gd` - プレイヤー情報
- `player_status_dialog.gd` - ステータスダイアログ
- `hand_display.gd` - 手札表示
- `card_selection_ui.gd` - カード選択
- `phase_display.gd` - フェーズ表示

### Land/Tile
- `land_command_ui.gd` - 領地コマンド
- `level_up_ui.gd` - レベルアップ
- `base_tile_ui.gd` - タイルUI基底
- `magic_tile_ui.gd` - 魔法陣UI
- `magic_stone_ui.gd` - 魔石UI
- `card_buy_ui.gd` - カード購入UI
- `card_give_ui.gd` - カード配布UI

### Spell
- `spell_phase_ui_manager.gd` - スペルフェーズUI管理
- `spell_and_mystic_ui.gd` - スペル/秘術選択
- `spell_info_panel_ui.gd` - スペル情報
- `spell_cast_notification_ui.gd` - 発動通知

### Info Panels
- `creature_info_panel_ui.gd` - クリーチャー情報
- `item_info_panel_ui.gd` - アイテム情報

### Utilities
- `global_action_buttons.gd` - グローバルボタン
- `global_comment_ui.gd` - コメント表示
- `action_menu_ui.gd` - アクションメニュー
- `card_ui_helper.gd` - カードUIヘルパー
- `debug_panel.gd` - デバッグパネル
- `battle_log_ui.gd` - バトルログ

---

## `/battle_screen/` - バトル画面（8ファイル）
- `battle_screen_manager.gd` - バトル画面管理
- `battle_screen.gd` - バトル画面
- `battle_creature_display.gd` - クリーチャー表示
- `hp_ap_bar.gd` - HP/APバー
- `damage_popup.gd` - ダメージポップアップ
- `skill_label.gd` - スキルラベル
- `skill_display_config.gd` - スキル表示設定
- `transition_layer.gd` - トランジション

---

## `/quest/` - クエストモード（3ファイル）
- `quest_game.gd` - クエストゲーム
- `quest_select.gd` - クエスト選択
- `stage_loader.gd` - ステージ読み込み

---

## `/helpers/` - ヘルパー（2ファイル）
- `card_sacrifice_helper.gd` - カード犠牲処理
- `item_use_restriction.gd` - アイテム使用制限

---

## Other Directories (Minor)
- `/network/` - ネットワーク関連
- `/creatures/` - クリーチャー関連
- `/flow_handlers/` - フローハンドラー
- `/battle_test/` - バトルテスト
- `/ui/` - UI関連
