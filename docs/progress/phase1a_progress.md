# Phase 1-A 進捗管理

**最終更新**: 2025年10月16日（Phase 1-A 完全完了・動作確認済み）

---

## 📊 全体進捗

### Phase 1-A: 基盤整備（5日間）

| Day | 項目 | ステータス | 完了日 |
|-----|------|-----------|--------|
| 1-2 | フェーズ管理構造 | 🔄 進行中 | - |
| 3-4 | 領地コマンドUI基盤 | ✅ 完了 | 2025-01 |
| 5   | 既存システム統合 | ✅ 完了 | 2025-10-16 |

**進捗率**: Phase 1-A 完全完了 (100%) - 全機能実装済み

---

## ✅ 完了タスク

### 2025年10月17日: アイテムフェーズ実装完了 ✅

#### 概要
バトル前のアイテム使用フェーズを完全実装。攻撃側・防御側の両方がアイテムを使用できるシステムを構築。

#### 実装内容
- [x] `ItemPhaseHandler`クラス作成
  - アイテムフェーズの状態管理（`State.INACTIVE`、`WAITING_FOR_SELECTION`、`ITEM_APPLIED`）
  - アイテム使用処理
  - 魔力消費処理
  - UI連携
- [x] 攻撃側アイテムフェーズ
  - バトルカード選択後、アイテムフェーズ開始
  - 手札からアイテムカード選択
  - アイテム効果を保存
- [x] 防御側アイテムフェーズ
  - 攻撃側のアイテムフェーズ完了後、自動的に開始
  - 防御側プレイヤーの手札を表示
  - 防御側のアイテム効果を保存
- [x] バトルシステムとの統合
  - `BattleSystem._apply_item_effects()` - アイテム効果適用
  - `buff_ap`、`buff_hp` - ステータス強化
  - `grant_skill` - スキル付与（強打、先制など）
  - アイテムで付与されたスキルは無条件で発動
- [x] UIフィルター修正
  - アイテムフェーズ中はアイテムカードのみ選択可能
  - 捨て札モードではすべてのカードタイプを選択可能
- [x] バトルカード消費タイミング修正
  - バトルカード選択時に即座に消費
  - アイテムフェーズ中に手札に表示されない
- [x] プレイヤーID参照の修正
  - アイテムフェーズ中は`ItemPhaseHandler.current_player_id`を使用
  - 防御側のアイテムフェーズで正しい手札を表示

**作成ファイル**:
- `scripts/game_flow/item_phase_handler.gd` (約210行)

**修正ファイル**:
- `scripts/tile_action_processor.gd` - アイテムフェーズ統合
- `scripts/battle_system.gd` - アイテム効果適用、スキル付与
- `scripts/battle_participant.gd` - `item_bonus_hp`使用
- `scripts/game_flow_manager.gd` - プレイヤーID参照修正
- `scripts/ui_components/card_selection_ui.gd` - フィルター修正
- `scripts/ui_components/hand_display.gd` - フィルタータイミング修正
- `scripts/card_system.gd` - テストアイテム追加（ロングソード、マグマハンマー）

**実装されたフロー**:
```
バトルカード選択
  ↓
バトルカード消費（手札から削除）
  ↓
攻撃側アイテムフェーズ開始
  - 攻撃側の手札を表示
  - アイテムカードのみ選択可能
  - アイテム選択 or パス
  ↓
防御側アイテムフェーズ開始
  - 防御側の手札を表示
  - アイテムカードのみ選択可能
  - アイテム選択 or パス
  ↓
バトル開始
  - 両者のアイテム効果を適用
  - AP/HP強化
  - スキル付与（強打など）
  ↓
バトル実行
```

**デバッグ用テストアイテム**:
- **ロングソード** (ID: 1072)
  - コスト: 10mp (100G)
  - 効果: AP+30
- **マグマハンマー** (ID: 1062)
  - コスト: 20mp (200G)
  - 効果: AP+20、火属性使用時に強打付与
  - 強打は無条件で発動

**成果**:
- 戦略性の向上（バトル前にアイテムで強化）
- 攻撃側・防御側の公平性（両者がアイテムを使用可能）
- スキル付与システムの実装
- UI/UXの改善（正しい手札表示、フィルター機能）

---

### 2025年10月16日（夕方）: BUG-002 CPU無限ループ修正完了 ✅

#### 概要
CPUが魔力不足時に無限ループする問題を修正。最大試行回数制限を導入。

#### 実装内容
- [x] `CPUAIHandler`に`MAX_DECISION_ATTEMPTS = 3`定数追加
- [x] `decision_attempts`カウンター変数追加
- [x] 各決定関数に試行回数チェック追加
  - `decide_summon()` - 召喚判断
  - `decide_invasion()` - 侵略判断
  - `decide_battle()` - バトル判断
  - `decide_level_up()` - レベルアップ判断
- [x] 最大試行回数超過時は強制スキップ
- [x] シグナル発行時にカウンターリセット

**修正ファイル**:
- `scripts/flow_handlers/cpu_ai_handler.gd`
  - 無限ループ防止ロジック追加（約20行追加）

**関連課題**: BUG-002完全解決

**確認済み**: BUG-003（属性連鎖）とUI-004（ターン終了ボタン）も完了確認

---

### 2025年10月16日（深夜）: Phase 1-D クリーチャー交換機能完了 ✅

#### 概要
Phase 1-Aの最後のピースであるクリーチャー交換機能を実装完了。

#### 実装内容
- [x] `LandCommandHandler.execute_swap_creature()` 実装
- [x] `TileActionProcessor.execute_swap()` 実装
- [x] 交換条件チェック（手札にクリーチャーカードがあるか）
- [x] 元のクリーチャーを手札に戻す処理
- [x] 新しいクリーチャー召喚処理
  - コスト支払い
  - 土地ボーナス適用
  - 土地レベル継承
  - ダウン状態設定
- [x] `GameFlowManager`での交換モード分岐処理
- [x] カード選択UIとの統合

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_swap_creature()` - 交換開始処理
  - `_check_swap_conditions()` - 条件チェック
  - `on_card_selected_for_swap()` - カード選択コールバック
  - 交換モード用変数追加
- `scripts/tile_action_processor.gd`
  - `execute_swap()` - 交換実行処理
- `scripts/game_flow_manager.gd`
  - `on_card_selected()` - 交換モード分岐追加

**実装されたフロー**:
```
領地コマンド → 交換を選択
  ↓
交換対象の土地を選択（ダウン状態除外済み）
  ↓
召喚条件チェック（手札にクリーチャーカードがあるか）
  ↓
交換する新しいカードを手札から選択
  ↓
元のクリーチャーを手札に戻す
  ↓
新しいクリーチャーを召喚（コスト支払い）
  - 土地ボーナス適用
  - 土地レベル継承
  - ダウン状態設定
  ↓
ターン終了
```

**成果**:
- Phase 1-Aの全機能が完成
- 領地コマンドシステムが完全に動作
- レベルアップ・移動・交換の3つのコマンドが利用可能
- **動作確認完了**: 全フローが正常に実行されることを確認

---

### 2025年10月16日（夜）: TECH-002 アクション処理フラグ統一完了 ✅

#### 概要
BUG-004の恒久対応として、二重管理されていたアクション処理フラグを一箇所に統一。

#### 修正内容
- [x] `BoardSystem3D.is_waiting_for_action` 削除
- [x] `TileActionProcessor.is_action_processing` に統一
- [x] `TileActionProcessor.complete_action()` 公開メソッド追加
- [x] `LandCommandHandler` の暫定対応コード整理（3箇所）
- [x] 設計ドキュメント更新
- [x] issues.md, tasks.md 更新

**修正ファイル**:
- `scripts/board_system_3d.gd` - フラグ削除、シグナル転送のみに簡素化
- `scripts/tile_action_processor.gd` - 公開メソッド追加
- `scripts/game_flow/land_command_handler.gd` - 3箇所修正
- `docs/design/design.md` - アーキテクチャ更新
- `docs/issues/issues.md` - BUG-004を解決済みに
- `docs/issues/tasks.md` - TECH-002を完了に

**成果**:
- 状態管理の責任を明確化
- バグの温床となる二重管理を根本解決
- 保守性・拡張性が大幅に向上

---

### 2025年10月16日（夕方）: UIManager分割プロジェクト完了 ✅

**詳細**: [UIManager リファクタリング完了記録](./phase1a_ui_refactoring.md)

#### 概要
UIManagerの肥大化を解消し、7つの独立したUIコンポーネントに分割完了。
- UIManager: 483行 → 398行（85行削減）
- 新規コンポーネント: LandCommandUI、HandDisplay、PhaseDisplay

#### 主な成果
- [x] LandCommandUI作成（535行）
- [x] HandDisplay作成（157行）- 手札表示管理
- [x] PhaseDisplay作成（150行）- フェーズ・サイコロUI管理
- [x] カメラ制御改善（領地コマンド終了時）
- [x] UI残存問題修正（移動後の「召喚しない」ボタン）
- [x] 警告修正4件（未使用パラメータ、変数シャドウイング）
- [x] ドキュメント作成
- [x] 動作確認完了

---

### 2025年10月16日（午前）: LandCommandUI分割 ✅

#### LandCommandUIクラス作成
- [x] 領地コマンド関連のUI処理を独立クラスに分離
- [x] ボタン作成メソッド実装
  - `create_land_command_button()`
  - `create_cancel_land_command_button()`
- [x] パネル作成メソッド実装
  - `create_action_menu_panel()` - アクションメニュー
  - `create_level_selection_panel()` - レベル選択パネル
- [x] 表示/非表示メソッド実装
  - `show_land_command_button()`、`hide_land_command_button()`
  - `show_action_menu()`、`hide_action_menu()`
  - `show_level_selection()`、`hide_level_selection()`
  - `show_cancel_button()`、`hide_cancel_button()`
- [x] イベントハンドラ実装
  - `_on_action_level_up_pressed()`
  - `_on_action_move_pressed()`
  - `_on_action_swap_pressed()`
  - `_on_action_cancel_pressed()`
  - `_on_level_selected()`
  - `_on_level_cancel_pressed()`
- [x] シグナル定義
  - `land_command_button_pressed`
  - `level_up_selected`

**作成ファイル**:
- `scripts/ui_components/land_command_ui.gd` (535行)

---

#### UIManagerリファクタリング
- [x] 重複コードの削除
  - `land_command_button`、`cancel_land_command_button`変数
  - パネル作成メソッド
  - イベントハンドラ
- [x] 委譲メソッドの実装
  - 全てのメソッドをLandCommandUIに委譲
- [x] LandCommandUIの統合
  - 初期化処理追加
  - シグナル接続
  - システム参照の設定

**修正ファイル**:
- `scripts/ui_manager.gd` (597行 - 以前より大幅削減)

**成果**:
- UIManagerの肥大化を解消
- 保守性向上
- 責任の明確化
- コード行数: 1132行 → より管理しやすい構造

---

### 2025年10月16日: クリーチャー移動機能完全実装 ✅

#### 選択マーカーシステム実装
- [x] 選択中の土地を視覚的に表示するマーカー
  - トーラス（ドーナツ型）メッシュ
  - 黄色の発光エフェクト
  - 回転アニメーション
- [x] 移動先選択時のマーカー移動
  - ↑↓キーで移動先を切り替え
  - マーカーが選択中の移動先に移動
  - カメラも追従

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `create_selection_marker()` - マーカー作成
  - `show_selection_marker()` - マーカー表示
  - `hide_selection_marker()` - マーカー非表示
  - `rotate_selection_marker()` - 回転アニメーション

---

#### 隣接タイル取得システム
- [x] `TileNeighborSystem`との統合
  - 物理的距離ベースの隣接判定
  - キャッシュ機能でパフォーマンス向上
- [x] `get_adjacent_tiles()`実装
  - `TileNeighborSystem.get_spatial_neighbors()`を使用

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `get_adjacent_tiles()` - TileNeighborSystem使用

---

#### 移動先選択UI（キーボード操作）
- [x] 上下キー（↑↓）で移動先を切り替え
- [x] 左右キー（←→）でも切り替え可能
- [x] Enterキーで移動を確定
- [x] Cキー/Escapeキーで前画面に戻る
- [x] UI表示更新
  - 現在の選択位置表示（1/3など）
  - 操作ガイド表示

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `handle_move_destination_input()` - キーボード操作
  - `update_move_destination_ui()` - UI更新

---

#### 移動処理の完全実装
- [x] 移動元の空き地化
  - クリーチャー削除
  - 所有権を-1（空き地）に設定
- [x] 空き地への移動
  - 土地獲得
  - クリーチャー配置
  - ダウン状態設定
  - ターン終了
- [x] 敵地への移動
  - 既存のバトルシステムと統合
  - クリーチャーを一時的に手札に追加
  - `battle_system.execute_3d_battle()`を使用
  - バトル完了後にダウン状態設定
- [x] フォールバック機能
  - 簡易バトルシステム（`_execute_simple_move_battle()`）

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `confirm_move()` - 移動確定処理
  - `_on_move_battle_completed()` - バトル完了コールバック
  - `_execute_simple_move_battle()` - 簡易バトル

**実装されたフロー**:
```
移動元選択（数字キー）
  ↓
アクションメニュー → [M]キー
  ↓
移動先選択（↑↓キー）
  ↓ Enterキー
【空き地の場合】
  ✅ 移動元が空き地になる
  ✅ 移動先に土地獲得
  ✅ クリーチャー配置
  ✅ ダウン状態設定
  ✅ ターン終了
  
【敵地の場合】
  ✅ 移動元が空き地になる
  ✅ 既存バトルシステム実行
  ✅ 勝利時: 土地獲得 + ダウン設定
  ✅ 敗北時: クリーチャー消滅
  ✅ ターン終了
```

---

#### バグ修正: アクション処理フラグの整合性
- [x] `is_action_processing`フラグのリセット問題を修正
  - `TileActionProcessor._complete_action()`を経由
  - 両方のフラグ（`is_waiting_for_action`と`is_action_processing`）を正しくリセット
- [x] 次のプレイヤーが召喚できない問題を解決
- [x] ドキュメント化
  - BUG-004として登録
  - TECH-002として恒久対応をタスク化
  - design.mdに詳細を記載

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - すべての完了処理で`tile_action_processor._complete_action()`を使用
- `docs/issues/issues.md` - BUG-004追加
- `docs/issues/tasks.md` - TECH-002追加
- `docs/design/design.md` - フラグ管理セクション追加

---

### 2025年10月15日: ハイライト機能と移動先選択の改善

#### 土地ハイライトシステム実装
- [x] `BaseTile`にハイライト機能追加
  - `is_highlighted`変数追加
  - `set_highlight(enabled: bool)`メソッド実装
- [x] ハイライト時の視覚効果
  - 白色に60%近づけて明るく表示
  - 黄色の発光エフェクト追加（emission）
  - emission_energy_multiplier=2.0で強調
- [x] `LandCommandHandler.select_land()`でハイライト自動設定
- [x] `LandCommandHandler.clear_highlight()`で解除

**修正ファイル**:
- `scripts/tiles/base_tiles.gd`
  - `is_highlighted`変数追加
  - `update_visual()`にハイライト処理追加
  - `set_highlight()`メソッド追加
- `scripts/game_flow/land_command_handler.gd`
  - `select_land()`にハイライト設定処理追加

**実装内容**:
```gdscript
// ハイライト時の処理
if is_highlighted:
	mat.albedo_color = mat.albedo_color.lerp(Color.WHITE, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.5) * 0.8
	mat.emission_energy_multiplier = 2.0
```

---

#### 移動先選択の前画面戻り機能
- [x] `State.SELECTING_MOVE_DEST`状態追加
- [x] `execute_move_creature()`を移動先選択モードに変更
- [x] `handle_move_destination_input()`メソッド追加
- [x] `cancel()`メソッドを3段階対応に更新
  - 移動先選択 → アクション選択
  - アクション選択 → 土地選択
  - 土地選択 → 閉じる

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `State`列挙型に`SELECTING_MOVE_DEST`追加
  - `execute_move_creature()`実装
  - `cancel()`を3段階戻りに対応
  - `_input()`に移動先選択処理追加
  - `handle_move_destination_input()`追加

**実装されたフロー**:
```
土地選択（数字キー）
  ↓
アクションメニュー（L/M/S/C）
  ↓ [M]キー
移動先選択（1-9,0/C）← ✅ [C]で前画面に戻る
```

---

### 2025年10月15日: Phase 1-A Day 5 開始

#### UIパネル配置修正
- [x] アクションメニュー・レベル選択パネルを画面中央に移動
- [x] 全画面対応の配置計算（相対座標）
- [x] design.mdに全画面対応の指針を追記

**修正ファイル**:
- `scripts/ui_manager.gd`
  - `create_action_menu_panel()` - 中央配置に修正
  - `create_level_selection_panel()` - 中央配置に修正
- `docs/design/design.md`
  - UI配置の基本方針セクション追加

**修正内容**:
```gdscript
// 修正前（上部配置）
var panel_y = 20

// 修正後（画面中央）
var panel_y = (viewport_size.y - panel_height) / 2
```

---

#### レベルアップ機能完全実装
- [x] アクションメニューパネルUI作成（右側中央配置）
  - レベルアップ、移動、交換、戻るボタン
- [x] レベル選択パネルUI作成
  - Lv2-5選択ボタン
  - 累計コスト表示
  - 魔力による有効/無効判定
- [x] `land_command_handler.gd`修正
  - `board_system.get_tile()`エラー修正 → `tile_nodes[]`使用
  - `execute_level_up_with_level()`実装
  - レベルアップ後のダウン状態設定
  - ターン終了処理統合
- [x] UIManagerとLandCommandHandlerの連携
  - `level_up_selected`シグナル接続

**修正ファイル**:
- `scripts/ui_manager.gd` (約150行追加)
- `scripts/game_flow/land_command_handler.gd` (約50行修正・追加)

**結果**: 完全なレベルアップフローが実装された

---

#### 領地コマンドボタンの表示タイミング修正
- [x] `GameFlowManager.start_turn()`からボタン表示処理を削除
- [x] `BoardSystem3D._on_movement_completed()`にボタン表示処理を追加
- [x] 人間プレイヤーのみ表示（CPU判定を含む）

**修正ファイル**:
- `scripts/game_flow_manager.gd` (100-105行目削除)
- `scripts/board_system_3d.gd` (211-217行目追加)

**結果**: 移動完了後に領地コマンドボタンが表示されるようになった

---

### 2025年10月15日: コード品質改善

#### 警告修正（4件）
- [x] `is_down`のシャドウイング修正（base_tiles.gd:148）
  - パラメータ名を`should_be_down`に変更
- [x] 未使用パラメータ修正（battle_system.gd:221）
  - `tile_info` → `_tile_info`
- [x] 到達不能コード削除（battle_system.gd:278）
  - 不要な`return false`を削除
- [x] 整数除算警告修正（player_info_panel.gd:56）
  - `margin / 2` → `int(margin / 2.0)`

**修正ファイル**:
- `scripts/tiles/base_tiles.gd`
- `scripts/battle_system.gd`
- `scripts/ui_components/player_info_panel.gd`

**結果**: Godotの警告が解消され、コード品質が向上

#### ドキュメント構造整理
- [x] `docs/`ディレクトリの構造化
  - `docs/design/` - 設計ドキュメント（読み取り専用）
  - `docs/progress/` - 進捗管理（適時更新）
  - `docs/issues/` - 課題管理（適時更新）
- [x] ルートファイルの移動
  - `design.md` → `docs/design/`
  - `skills_design.md` → `docs/design/`
  - `turn_end_flow.md` → `docs/design/`
  - `issues.md` → `docs/issues/`
  - `tasks.md` → `docs/issues/`
  - `TURN_END_QUICK_FIX.md` → `docs/issues/`
- [x] ドキュメント作成
  - `README.md` - プロジェクト概要
  - `docs/README.md` - ドキュメントインデックス
- [x] 更新ルール明記
  - design/は読み取り専用（ユーザー指示のみ更新可）
  - issues/は適時更新（バグ発見・修正時に即座に更新）
  - progress/は適時更新（タスク完了時に更新）

**実装ファイル**:
- プロジェクトルート: `README.md`
- `docs/README.md`
- メモリ: `project_structure_and_docs`

**目的**: 
- プロジェクトの情報を一元管理
- チャット開始時の必須確認事項を明確化
- ドキュメント更新の運用ルール確立

---

### Day 3-4: 領地コマンドUI基盤

#### 領地コマンドボタン
- [x] ボタン作成（左上配置、z_index=100）
- [x] キャンセルボタン作成（閉じるボタン）
- [x] 表示/非表示切り替え
- [x] hand_containerのmouse_filter設定（クリック可能に）

**実装ファイル**:
- `scripts/ui_manager.gd`
  - `create_land_command_button()`
  - `create_cancel_land_command_button()`
  - `show_land_command_button()`
  - `hide_land_command_button()`

#### 土地選択モード
- [x] キーボード入力処理（数字キー1-0）
- [x] 所有地リスト取得
- [x] ダウン状態の土地を除外
- [x] UIにコマンド説明表示

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `_input()` - キーボード処理
  - `handle_land_selection_input()` - 土地選択
  - `get_player_owned_lands()` - ダウン状態除外

#### アクション選択画面
- [x] アクション選択UI表示（L/M/S/C）
- [x] キーボード入力処理
- [x] キャンセル機能（土地選択に戻る）

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `handle_action_selection_input()` - アクション選択
  - `cancel()` - キャンセル処理

#### ダウン状態システム
- [x] 召喚後のダウン状態設定
- [x] スタート通過時のダウン解除
- [x] ダウン状態チェック（選択時）
- [x] Uキーでダウン解除（デバッグ）

**実装ファイル**:
- `scripts/tile_action_processor.gd`
  - 召喚後にダウン設定
- `scripts/movement_controller.gd`
  - `clear_all_down_states_for_player()`
- `scripts/debug_controller.gd`
  - `clear_current_player_down_states()`

---

## 🔲 未完了タスク

### 優先度1: UIManager分割の完成（🔄 30% → 70%完了）

#### 完了した項目
- [x] LandCommandUIクラス作成
- [x] UIManagerへの組み込み
- [x] 委譲メソッド実装
- [x] 既存参照の置き換え

#### 次回作業
1. **動作テスト** - 実機での動作確認が必要
   - ゲーム起動確認
   - 領地コマンドボタンの動作
   - アクションメニューの表示
   - レベルアップ機能の動作
2. **HandDisplay分割** - 手札表示関連のコード分割
3. **PhaseDisplay分割** - フェーズ表示関連のコード分割

---

## 🔲 未完了タスク（以前から）

### ~~優先度1: 表示タイミング修正~~（✅ 完了: 2025/10/15）

#### 領地コマンドボタンの表示タイミング
- [x] ターン開始時ではなく、移動完了後に表示
- [x] `GameFlowManager.start_turn()`から削除
- [x] 移動完了後のタイミングで表示（`BoardSystem3D._on_movement_completed()`）

**修正したファイル**:
- `scripts/game_flow_manager.gd`
  - `start_turn()` - ボタン表示処理を削除（100-105行目）
- `scripts/board_system_3d.gd`
  - `_on_movement_completed()` - ボタン表示処理を追加

**実装内容**:
```gdscript
// board_system_3d.gd: _on_movement_completed()
var is_cpu = current_player_index < player_is_cpu.size() and player_is_cpu[current_player_index] and not debug_manual_control_all
if not is_cpu and ui_manager:
	ui_manager.show_land_command_button()
elif ui_manager:
	ui_manager.hide_land_command_button()
```

**実現した動作**:
```
ターン開始
  ↓
カードドロー
  ↓
サイコロを振る
  ↓
移動完了 ← ✅ ここで領地コマンドボタン表示
  ↓
召喚フェーズ
```

---

### ~~優先度2: レベルアップ処理~~（✅ 完了: 2025/10/15）

#### エラー修正
- [x] `board_system.get_tile()`エラーの修正
  - 修正: `board_system.tile_nodes[selected_tile_index]`に変更

**修正ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_level_up()` 内の`get_tile()`呼び出し修正

#### レベルアップUI
- [x] レベル選択画面の実装
- [x] 累計コスト表示
- [x] 目標レベル選択（Lv2, 3, 4, 5）
- [x] アクションメニューパネル実装（右側配置）

**実装ファイル**:
- `scripts/ui_manager.gd`
  - `action_menu_panel` - アクションメニューパネル（L/M/S/C）
  - `level_selection_panel` - レベル選択パネル（Lv2-5 + コスト表示）
  - `create_action_menu_panel()` - アクションメニュー作成
  - `create_level_selection_panel()` - レベル選択パネル作成
  - `show_action_menu()` / `hide_action_menu()` - 表示制御
  - `show_level_selection()` / `hide_level_selection()` - 表示制御

#### レベルアップ実行
- [x] コスト計算（累計方式）
- [x] 魔力消費処理
- [x] タイルのレベル更新
- [x] レベルアップ後のダウン状態設定
- [x] UI更新
- [x] ターン終了処理

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_level_up_with_level()` - レベルアップ実行
  - `_on_level_up_selected()` - シグナルハンドラ

**実装されたフロー**:
```
土地選択（数字キー1-0）
  ↓
アクションメニュー表示（右側パネル）
  - [L] レベルアップ
  - [M] 移動
  - [S] 交換
  - [C] 戻る
  ↓
レベル選択画面（Lキー押下）
  - 現在レベル表示
  - Lv2-5ボタン（魔力で到達可能なレベルのみ有効）
  - 各レベルのコスト表示
  - [C] 前の画面に戻る
  ↓
レベルアップ実行
  - 魔力消費
  - レベル更新
  - ダウン状態設定
  ↓
ターン終了
```

**コスト計算式（実装済み）**:
```gdscript
var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}
var cost = level_costs[target_level] - level_costs[current_level]
```

---

### ~~優先度3: クリーチャー移動~~（✅ 完了: 2025/10/16）

- [x] 移動元選択（全自領地、ダウン除外）
- [x] 移動先選択（↑↓キーで切り替え）
- [x] 移動処理実装
- [x] 移動元を空き地化
- [x] 移動先にクリーチャー配置 + ダウン
- [x] 空き地移動: 土地獲得 + ターン終了
- [x] 敵地移動: バトル発生（既存バトルシステム統合）
- [x] 選択マーカーシステム
- [x] TileNeighborSystemとの統合

**実装済みファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `confirm_move()` - 完全実装
  - `_on_move_battle_completed()` - バトル完了処理
  - `create_selection_marker()` - マーカー生成
  - `handle_move_destination_input()` - キーボード操作

---

### 優先度4: クリーチャー交換

- [ ] 交換対象土地選択（全自領地、ダウン除外）
- [ ] 既存クリーチャーを手札に戻す
- [ ] 新クリーチャー選択（カード選択画面）
- [ ] 召喚コスト支払い
- [ ] 新クリーチャー配置
- [ ] 土地ボーナス適用
- [ ] 土地レベル継承
- [ ] ダウン状態設定

**実装ファイル**:
- `scripts/game_flow/land_command_handler.gd`
  - `execute_swap_creature()` - 現在はプレースホルダー

---

## ⚠️ 既知の問題

### 修正が必要なエラー

#### 1. `board_system.get_tile()`が存在しない
**発生箇所**: `land_command_handler.gd:113`
```gdscript
var tile = board_system.get_tile(selected_tile_index)
```

**エラーメッセージ**:
```
Invalid call. Nonexistent function 'get_tile' in base 'Node (BoardSystem3D)'.
```

**修正方法**:
```gdscript
# 修正前
var tile = board_system.get_tile(selected_tile_index)

# 修正後
if board_system.tile_nodes.has(selected_tile_index):
	var tile = board_system.tile_nodes[selected_tile_index]
```

---

## 📝 設計メモ

### ダウン状態の仕様
- **ダウン状態の土地は選択できない**
- 選択できない = レベルアップ、移動、交換の全てができない
- `get_player_owned_lands()`でダウン状態を除外
- `select_land()`でも二重チェック

### デバッグコマンド
- **Uキー**: 現在プレイヤーの全土地のダウン解除
- あくまで現在プレイヤーのみ（全プレイヤーではない）

### 領地コマンドの制約
- **1ターンに1回のみ**
- 召喚と領地コマンドは排他的
- どちらか実行したらターン終了

---

## 🎯 次のステップ

### 今すぐ実装すべきこと
1. **領地コマンドボタンの表示タイミング修正**
   - GameFlowManagerの修正
   - 移動完了後に表示

2. **レベルアップのエラー修正**
   - `get_tile()`を`tile_nodes[]`に修正

### その後の実装順序
1. レベルアップUI・処理の完成
2. クリーチャー移動の実装
3. クリーチャー交換の実装

---

## 📂 関連ファイル一覧

### 実装済み
- `scripts/game_flow/land_command_handler.gd` - 領地コマンドのメインロジック
- `scripts/ui_manager.gd` - UI管理、ボタン作成
- `scripts/debug_controller.gd` - デバッグ機能（Uキー）
- `scripts/game_flow_manager.gd` - ゲームフロー管理
- `scripts/tile_action_processor.gd` - タイルアクション処理
- `scripts/movement_controller.gd` - 移動処理

### 今後修正が必要
- `scripts/game_flow_manager.gd` - 表示タイミング修正

---

## 📚 参考資料

- [Phase 1-A 完全仕様書](./phase1a_spec.md) - 元の仕様書（提供されたファイル）
- [ゲームデザイン](../design.md) - 全体設計
- [スキル設計](../skills_design.md) - スキルシステム

---

**作成日**: 2025年1月  
**管理者**: AI Assistant  
**ステータス**: Phase 1-A Day 5 進行中（表示タイミング修正完了）
