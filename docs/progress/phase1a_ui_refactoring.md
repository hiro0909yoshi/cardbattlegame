# UIManager リファクタリング完了記録

**最終更新**: 2025年10月16日

---

## 📊 UIManager分割プロジェクト

### 目的
UIManagerの肥大化を解消し、保守性・可読性を向上させるため、機能ごとに独立したUIコンポーネントクラスに分割する。

### 実施期間
2025年10月16日 午前〜夕方

---

## ✅ 完了したUIコンポーネント

### 1. PlayerInfoPanel
**責務**: プレイヤー情報パネルの表示・更新

**主要メソッド**:
- `initialize()` - 初期化
- `update_all_panels()` - 全パネル更新
- `set_current_turn()` - 現在ターンプレイヤー設定

**ファイル**: `scripts/ui_components/player_info_panel.gd`

---

### 2. CardSelectionUI
**責務**: カード選択UIの表示・操作

**主要メソッド**:
- `show_selection()` - 選択画面表示
- `hide_selection()` - 選択画面非表示
- `on_card_selected()` - カード選択処理
- `enable_card_selection()` - カード有効化
- `disable_card_selection()` - カード無効化

**ファイル**: `scripts/ui_components/card_selection_ui.gd`

**シグナル**:
- `card_selected(card_index: int)`
- `selection_cancelled()`

---

### 3. LevelUpUI
**責務**: レベルアップUI表示

**主要メソッド**:
- `show_level_up_selection()` - レベル選択画面表示
- `hide_selection()` - 画面非表示

**ファイル**: `scripts/ui_components/level_up_ui.gd`

**シグナル**:
- `level_selected(target_level: int, cost: int)`
- `selection_cancelled()`

---

### 4. DebugPanel
**責務**: デバッグパネル表示・デバッグ情報管理

**主要メソッド**:
- `toggle_visibility()` - 表示切替
- `update_cpu_hand()` - CPU手札表示更新

**ファイル**: `scripts/ui_components/debug_panel.gd`

**シグナル**:
- `debug_mode_changed(enabled: bool)`

---

### 5. LandCommandUI ⭐ NEW
**責務**: 領地コマンド関連UI管理

**主要メソッド**:
- `create_land_command_button()` - 領地コマンドボタン作成
- `create_cancel_land_command_button()` - キャンセルボタン作成
- `create_action_menu_panel()` - アクションメニュー作成
- `create_level_selection_panel()` - レベル選択パネル作成
- `show_action_menu()` / `hide_action_menu()` - アクションメニュー表示制御
- `show_level_selection()` / `hide_level_selection()` - レベル選択表示制御
- `show_land_command_button()` / `hide_land_command_button()` - ボタン表示制御
- `show_cancel_button()` / `hide_cancel_button()` - キャンセルボタン表示制御

**ファイル**: `scripts/ui_components/land_command_ui.gd` (535行)

**シグナル**:
- `land_command_button_pressed()`
- `level_up_selected(target_level: int, cost: int)`

**作成日**: 2025年10月16日

---

### 6. HandDisplay ⭐ NEW
**責務**: 手札表示UI管理

**主要メソッド**:
- `initialize()` - 手札コンテナ初期化
- `connect_card_system_signals()` - CardSystemシグナル接続
- `update_hand_display()` - 手札表示更新
- `create_card_node()` - カードノード生成
- `rearrange_hand()` - 手札再配置
- `get_player_card_nodes()` - プレイヤーのカードノード取得

**ファイル**: `scripts/ui_components/hand_display.gd` (157行)

**シグナル**:
- `card_drawn(card_data: Dictionary)`
- `card_used(card_data: Dictionary)`
- `hand_updated()`

**作成日**: 2025年10月16日

**統合内容**:
- UIManagerから手札表示関連の約120行を移行
- CardSelectionUIからの参照を`get_player_card_nodes()`経由に変更
- CardSystemとの連携を完全にカプセル化

---

### 7. PhaseDisplay ⭐ NEW
**責務**: フェーズ表示とサイコロUI管理

**主要メソッド**:
- `initialize()` - UI要素初期化
- `create_phase_label()` - フェーズラベル作成
- `create_dice_button()` - サイコロボタン作成
- `update_phase_display()` - フェーズ表示更新
- `show_dice_result()` - サイコロ結果表示
- `set_dice_button_enabled()` - ボタン有効/無効切替
- `set_phase_text()` - テキスト直接設定

**ファイル**: `scripts/ui_components/phase_display.gd` (150行)

**シグナル**:
- `dice_button_pressed()`

**作成日**: 2025年10月16日

**統合内容**:
- UIManagerからフェーズ・サイコロ関連の約80行を移行
- `create_basic_ui()`をPhaseDisplay初期化に簡略化
- プロパティゲッターでUI要素へのアクセス提供

---

## 📊 コード削減効果

### UIManager
- **開始時**: 483行
- **最終**: 398行
- **削減**: 85行（約18%削減）

### 新規コンポーネント合計
- LandCommandUI: 535行
- HandDisplay: 157行
- PhaseDisplay: 150行
- **合計**: 842行

### 総行数
- **リファクタリング前**: UIManager 483行
- **リファクタリング後**: UIManager 398行 + コンポーネント 842行 = 1,240行

**備考**: 総行数は増加していますが、これは：
1. 各コンポーネントが独立して動作可能
2. 責務が明確に分離された
3. テストが容易になった
4. 保守性が大幅に向上した

---

## 🔧 追加機能・修正

### カメラ制御改善
**実装日**: 2025年10月16日

**問題**: 領地コマンド終了時にカメラがスタート位置に戻ってしまう

**解決策**:
```gdscript
// MovementControllerから実際のプレイヤー位置を取得
var player_tile_index = board_system.movement_controller.get_player_tile(player_id)

// MovementControllerと同じカメラオフセットを使用
const CAMERA_OFFSET = Vector3(19, 19, 19)
board_system.camera.position = tile_pos + Vector3(0, 1.0, 0) + CAMERA_OFFSET
board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)
```

**修正ファイル**: `scripts/game_flow/land_command_handler.gd`

---

### 移動後のUI残存問題修正
**実装日**: 2025年10月16日

**問題**: 領地コマンドで移動後に「召喚しない」ボタンが残る

**解決策**:
```gdscript
func hide_land_command_ui():
	hide_action_menu()
	hide_level_selection()
	
	// CardSelectionUIも確実に非表示 ← 追加
	if card_selection_ui:
		card_selection_ui.hide_selection()
	
	hide_cancel_button()
```

**修正ファイル**: `scripts/ui_manager.gd`

---

### 警告修正
**実施日**: 2025年10月16日

#### 1. 未使用パラメータ（show_dice_result）
```gdscript
// 修正前
func show_dice_result(value: int, parent: Node):

// 修正後
func show_dice_result(value: int, _parent: Node = null):
```

#### 2. 未使用パラメータ（show_land_selection_mode）
```gdscript
// 修正前
func show_land_selection_mode(owned_lands: Array):

// 修正後
func show_land_selection_mode(_owned_lands: Array):
```

#### 3. 変数シャドウイング（LandCommandHandler）
```gdscript
// 修正前
var player_system = game_flow_manager.player_system
var current_player = player_system.get_current_player()

// 修正後（2箇所）
var p_system = game_flow_manager.player_system
var current_player = p_system.get_current_player()
```

#### 4. 未使用変数（defender_player）
```gdscript
// 削除
var defender_player = dest_tile.owner_id
```

**修正ファイル**:
- `scripts/ui_manager.gd`
- `scripts/game_flow/land_command_handler.gd`

---

## 📐 UIコンポーネントアーキテクチャ

### 階層構造
```
UIManager (398行)
├─ PlayerInfoPanel - プレイヤー情報
├─ CardSelectionUI - カード選択
├─ LevelUpUI - レベルアップ
├─ DebugPanel - デバッグ
├─ LandCommandUI - 領地コマンド ⭐
├─ HandDisplay - 手札表示 ⭐
└─ PhaseDisplay - フェーズ・サイコロ ⭐
```

### 依存関係
```
UIManager
  ↓ システム参照
  ├─ CardSystem
  ├─ PlayerSystem
  ├─ BoardSystem3D
  └─ GameFlowManager
  
HandDisplay
  ↓ システム参照
  ├─ CardSystem (手札データ)
  └─ PlayerSystem (現在プレイヤー)
  
PhaseDisplay
  ↓ 親参照のみ
  └─ UILayer (表示先)
  
LandCommandUI
  ↓ システム参照
  ├─ PlayerSystem
  ├─ BoardSystem3D
  └─ UIManager (相互参照)
```

### アクセスパターン

#### UIManager → コンポーネント（委譲）
```gdscript
// 直接呼び出し
func update_hand_display(player_id: int):
	if hand_display:
		hand_display.update_hand_display(player_id)
```

#### 他クラス → UIManager → コンポーネント（アクセサ経由）
```gdscript
// CardSelectionUIからHandDisplayへのアクセス
var hand_nodes = ui_manager_ref.get_player_card_nodes(player_id)
```

#### プロパティゲッター（透過アクセス）
```gdscript
// PhaseDisplayのUI要素に透過的にアクセス
var dice_button: Button:
	get: return phase_display.dice_button if phase_display else null

var phase_label: Label:
	get: return phase_display.phase_label if phase_display else null
```

---

## 🎯 設計指針

### 1. 単一責任の原則
各UIコンポーネントは1つの明確な責務を持つ。

### 2. カプセル化
UIコンポーネント内部の実装詳細は隠蔽し、公開インターフェースを通じてのみアクセス。

### 3. 疎結合
コンポーネント間の依存は最小限に抑え、UIManagerを通じて連携。

### 4. 拡張性
新しいUIコンポーネントの追加が容易な構造。

---

## 📝 今後の改善提案

### 1. UIイベントバスの導入
現在はUIManager経由でシグナルを伝播しているが、イベントバスパターンを導入することで、さらに疎結合化できる可能性がある。

### 2. UIテーマシステム
現在は各コンポーネントが個別にスタイルを設定している。共通のテーマシステムを導入することで、一貫性のあるデザインを実現できる。

### 3. UIアニメーションマネージャー
フェードイン・アウトなどのアニメーションを統一的に管理するマネージャーの導入。

### 4. LandCommandHandlerの分割検討
現在728行と大きいため、将来的に分割を検討する価値がある：
- SelectionMarkerController
- LandMovementHandler
など

---

## ✅ チェックリスト

- [x] PlayerInfoPanel統合
- [x] CardSelectionUI統合
- [x] LevelUpUI統合
- [x] DebugPanel統合
- [x] LandCommandUI作成・統合
- [x] HandDisplay作成・統合
- [x] PhaseDisplay作成・統合
- [x] カメラ制御修正
- [x] UI残存問題修正
- [x] 警告修正（4件）
- [x] ドキュメント更新
- [x] 動作確認

---

**プロジェクト完了日**: 2025年10月16日  
**担当**: AI Assistant  
**ステータス**: ✅ 完了
