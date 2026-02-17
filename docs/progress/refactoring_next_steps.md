# リファクタリング次ステップ

**最終更新**: 2026-02-18
**現在のフェーズ**: Phase 8 — UIManager 依存方向の正規化

---

## ✅ 完了済み Phase（サマリー）

| Phase | 内容 | 実施日 |
|-------|------|--------|
| 7-A | CPU AI パススルー除去（SPH → GSM 直接注入） | 2026-02-17 |
| 7-B | SPH UI 依存逆転（Signal 駆動化、spell_ui_manager 直接呼び出しゼロ） | 2026-02-17 |

---

## Phase 8: UIManager 依存方向の正規化

### 設計原則

**目的**: 行数削減ではなく、**依存方向の固定**。

```
Business Logic Layer (GFM, Handlers, Systems)
    ↓ Signal ONLY
UI Service Layer (NavigationService, MessageService, CardSelectionService, InfoPanelService)
    ↓ Direct call（親→子）
UI Component Layer (GlobalActionButtons, GlobalCommentUI, CardSelectionUI, InfoPanels...)
```

**4つの絶対ルール**:

| # | ルール | 理由 |
|---|--------|------|
| 1 | ビジネスロジック → UIサービス: **Signal のみ** | ロジック層はUI層を知らない |
| 2 | UIサービス → UIコンポーネント: **直接メソッド呼び出し** | 親→子は正当 |
| 3 | UIコンポーネント → ビジネスロジック: **禁止** | 逆参照は依存の逆転 |
| 4 | UIサービス → UIサービス: **禁止**（調停は上位のみ） | 横断依存は分割の意味を消す |

### アンチパターン

**🔴 ServiceLocator化 / バンドルオブジェクト配布の禁止**:

```gdscript
# ❌ UIManager が全サービスのファサード = 神オブジェクトの第二形態
ui_manager.message_service.show_toast()

# ❌ UIContext バンドルを広く配る = 疑似ServiceLocator（内部構造が外に露出）
ui_context.message.show_toast()

# ✅ 必要なサービスだけ個別注入（依存が明示的）
message_service.show_toast()
```

**UIContext クラスは作らない**。各ファイルの `setup()` に必要なサービスだけ渡す。
引数が4つになっても「このクラスは4つのUI操作に依存している」という事実の見える化。

**🔴 サービス間横断の禁止**:

```gdscript
# ❌ CardSelectionService が NavigationService を呼ぶ
func show_selection():
    navigation_service.save_state()  # 横断依存！
    _show_ui()

# ✅ 呼び出し元（Handler/GFM）が両方を順番に操作
func _on_card_selection_requested():
    navigation_service.save_state()
    card_selection_service.show_ui(config)
```

---

### 現状分析

**UIManager**: 1,094行、87メソッド、15 UIコンポーネント管理、**54ファイル**が参照

#### UIManager を参照している54ファイルの分類

| カテゴリ | ファイル数 | 代表的ファイル | 参照回数 | 最適パターン |
|---------|----------|-------------|---------|------------|
| **ハンドラー** | ~8 | DominioCommandHandler(90), ItemPhaseHandler(19) | 多 | Signal駆動 |
| **兄弟システム** | ~5 | TileActionProcessor(34), SpecialTileSystem(23) | 多 | Signal駆動 |
| **UIヘルパー** | ~6 | card_selection_handler(70+), land_action_helper(30+) | **最多** | サービス直接注入 |
| **タイル** | ~6 | magic_tile, card_buy_tile 等 | 少〜中 | context経由サービス |
| **スペル系** | ~6 | spell_borrow, spell_creature_swap 等 | 中 | Signal or サービス注入 |
| **移動系** | ~3 | movement_direction_selector 等 | 少 | サービス直接注入 |
| **UIコンポーネント** | ~11 | card_selection_ui(158), creature_info_panel_ui(25) | 多 | 親参照（正当） |
| **GFM** | 1 | game_flow_manager(20+) | 多 | コーディネーター（正当） |
| **その他** | ~8 | card.gd(再帰探索!), debug_controller(31) | 中 | 個別対応 |

#### UIManager 内部の問題

| 問題 | 規模 | 深刻度 |
|------|------|--------|
| **ナビゲーション状態管理** | 8変数 + 12メソッド + 44行復元ロジック | 🔴 最高 |
| **逆参照**（GFM, BoardSystem等 6システムを参照） | 6つの外部参照 | 🔴 高 |
| **87メソッド × 10責務カテゴリ** | 全体 | 🟡 高 |
| **restore_current_phase()** が全フェーズを知っている | 44行、5分岐 | 🟡 中 |

#### UIManager が実際に提供しているサービス（分割候補）

| サービス | 主な操作 | 利用ファイル数 |
|---------|---------|-------------|
| **MessageService** | show_comment_and_wait(), show_toast(), show_action_prompt(), set_phase_text() | ~30 |
| **NavigationService** | enable/disable_navigation(), save/restore state, GlobalActionButtons管理 | ~15 |
| **CardSelectionService** | card_selection_filter, show_card_selection_ui(), excluded_card_*, card_selected signal | ~12 |
| **InfoPanelService** | show_card_info(), hide_all_info_panels(), 3つのInfoPanelUI | ~10 |
| **PlayerInfoService** | update_player_info_panels(), set_current_turn() | ~8 |

---

### ターゲットアーキテクチャ

#### 個別サービス注入パターン（UIContext 不使用）

**原則**: 各ファイルには必要なサービスだけを `setup()` で渡す。バンドルオブジェクトは作らない。

```
UIManager（~200行、コーディネーターのみ）
├─ _ready(): サービス生成
├─ create_ui(): UIコンポーネントのライフサイクル管理
├─ get_*_service(): 個別サービスのgetter（GSMが配布に使用）
└─ UIレイヤー管理

GameSystemManager（配布元）
└─ 各ファイルの setup() に必要なサービスだけ注入
```

#### 外部ファイルの参照パターン（最終形）

```gdscript
# ハンドラー → Signal のみ（UIを直接参照しない）
signal item_filter_configured(filter_config)

# ヘルパー → 必要なサービスだけ個別注入
func setup(card_selection: CardSelectionService, navigation: NavigationService):
    _card_selection = card_selection
    _navigation = navigation

# タイル → context に必要なサービスだけ入れる
func handle_special_action(context: Dictionary):
    var message: MessageService = context.get("message_service")
    await message.show_comment_and_wait("魔法石を獲得！")

# UIコンポーネント → 親サービスへの正当な参照
func set_navigation_service(nav: NavigationService):
    _navigation = nav

# GFM → コーディネーターとしてサービス個別保持（正当）
var _message_service: MessageService
var _navigation_service: NavigationService
```

---

## 実施フェーズ

### 実施順序（構造が先、配線が後）

| 順番 | Phase | 内容 | 対象ファイル数 | 難易度 |
|-----|-------|------|-------------|--------|
| 1 | **8-F** | UIManager 内部分割（4サービス、個別注入） | 1 + 4新規 | **高** |
| 2 | **8-G** | 最重量級ヘルパー → サービス直接注入 | ~6 | 高 |
| 3 | **8-H** | UIコンポーネント逆参照除去 | ~4 | 低〜中 |
| 4 | **8-A** | ItemPhaseHandler Signal化 | 1 | 低 |
| 5 | **8-B** | DominioCommandHandler Signal化 | 1 | 高 |
| 6 | **8-C** | BankruptcyHandler パネル分離 | 2 | 低 |
| 7 | **8-E** | 兄弟システム Signal化 | 5 | 中〜高 |
| 8 | **8-I** | タイル系 → context経由サービス | ~6 | 低 |
| 9 | **8-J** | スペル系 → Signal/サービス注入 | ~6 | 中 |
| 10 | **8-K** | 移動系 + その他（card.gd等） | ~10 | 中 |
| 11 | **8-D** | UIManager 最終評価 | — | — |

**順序の理由**: 構造（サービス分割）を先に確立し、Signal 配線は確定した構造に対して行う。逆にすると Signal のリスナー先がまだ UIManager のままで、分割時にやり直しになる。

---

### 8-F: UIManager 内部分割（4サービス、個別注入）

**目的**: UIManager を4つの独立サービスに分割し、GSM が各ファイルに必要なサービスだけ注入
**リスク**: 高（UIManager の全メソッドを再配置）
**成果物**: UIManager 1,094行 → UIManager ~200行 + 4サービス
**注意**: UIContext クラスは作らない。サービスは GSM が個別に注入する。

#### 抽出するサービス

**1. NavigationService（~150行）**

抽出元メソッド:
- `enable_navigation()`, `disable_navigation()`
- `save_navigation_state()`, `restore_navigation_state()`, `clear_navigation_saved_state()`
- `restore_current_phase()` — **注意**: フェーズ別復元ロジックは各ハンドラーに委譲
- `register_confirm_action()`, `register_back_action()`, `register_arrow_actions()`
- `set_special_button()`, `clear_special_button()`
- GlobalActionButtons 管理

抽出する状態:
- `_saved_nav_confirm`, `_saved_nav_back`, `_saved_nav_up`, `_saved_nav_down`
- `_saved_nav_special_cb`, `_saved_nav_special_text`, `_saved_nav_phase_comment`
- `_nav_state_saved`

**restore_current_phase() の分解**:
```
現在: UIManager が5フェーズの状態を判定して復元
改善: 各ハンドラーが自身の restore_navigation() を持つ
      NavigationService は save/restore の汎用機構のみ提供
      GFM が現在のフェーズに応じて適切なハンドラーの restore を呼ぶ
```

**2. MessageService（~80行）**

抽出元メソッド:
- `show_comment_and_wait()`, `show_choice_and_wait()`
- `show_comment_message()`, `hide_comment_message()`
- `show_toast()`, `is_notification_popup_active()`
- `show_action_prompt()`, `hide_action_prompt()`
- `set_phase_text()`, `get_phase_text()`
- `update_phase_display()`, `show_dice_result()` 系

管理コンポーネント:
- GlobalCommentUI
- PhaseDisplay

**3. CardSelectionService（~100行）**

抽出元メソッド:
- `show_card_selection_ui()`, `show_card_selection_ui_mode()`, `hide_card_selection_ui()`
- `on_card_button_pressed()`
- `show_card_selection()`
- `show_card_info_only()`

抽出する状態:
- `card_selection_filter`
- `excluded_card_index`, `excluded_card_id`
- `blocked_item_types`, `assist_target_elements`

管理コンポーネント:
- CardSelectionUI
- HandDisplay

発行Signal:
- `card_selected(card_index)`
- `pass_button_pressed()`

**4. InfoPanelService（~100行）**

抽出元メソッド:
- `show_card_info()` — **注意**: ナビゲーション保存は呼び出し元が行う（横断禁止）
- `hide_all_info_panels()`, `_hide_all_info_panels_raw()`
- `is_any_info_panel_visible()`, `close_all_info_panels()`

管理コンポーネント:
- CreatureInfoPanelUI
- SpellInfoPanelUI
- ItemInfoPanelUI

#### UIManager に残る責務（~200行）

- `_ready()`: サービス生成
- `create_ui()`: UIレイヤー作成、コンポーネント初期化
- `connect_ui_signals()`: コンポーネント間シグナル接続
- `get_navigation_service()`, `get_message_service()` 等: 個別サービスgetter（GSM用）
- PlayerInfoPanel 管理（`update_player_info_panels()`, `set_current_turn()`）
- UIレイヤー管理（`ui_layer`）
- DominioOrderUI 管理（8-B 完了後に Signal 化）
- LevelUpUI, DebugPanel 等の小規模管理

#### 対象ファイル

- `scripts/ui_manager.gd` — 分割（1,094行 → ~200行）
- `scripts/ui_services/navigation_service.gd` — **新規**
- `scripts/ui_services/message_service.gd` — **新規**
- `scripts/ui_services/card_selection_service.gd` — **新規**
- `scripts/ui_services/info_panel_service.gd` — **新規**
- `scripts/system_manager/game_system_manager.gd` — 個別サービス注入追加

---

### 8-G: 最重量級ヘルパー → サービス直接注入

**目的**: UIManager への最大の依存元を、必要なサービスだけの直接注入に切り替え
**リスク**: 高（参照箇所が非常に多い）

#### 対象ファイルと注入するサービス

| ファイル | 現参照数 | 注入するサービス |
|---------|---------|---------------|
| **card_selection_handler.gd** | 70+ | CardSelectionService, NavigationService, InfoPanelService, MessageService |
| **land_action_helper.gd** | 30+ | CardSelectionService, NavigationService, MessageService, InfoPanelService |
| **tile_summon_executor.gd** | 14 | CardSelectionService, MessageService |
| **tile_battle_executor.gd** | 7 | MessageService, PlayerInfoService |
| **target_selection_helper.gd** | 5 | NavigationService, MessageService |
| **card_sacrifice_helper.gd** | 5 | CardSelectionService, MessageService |

**修正パターン**:

```gdscript
# Before: ui_manager を丸ごと注入
func setup(ui_manager, player_system, card_system):
    self.ui_manager = ui_manager

# After: 必要なサービスだけ注入
func setup(card_selection: CardSelectionService, navigation: NavigationService, ...):
    _card_selection = card_selection
    _navigation = navigation
```

**注意**: card_selection_handler.gd は最重量（70+参照）。段階的に移行する:
1. まず `ui_manager` → `ui_context` に置換
2. その後 `ui_context.card_selection` 等に展開
3. 不要になった ui_context 参照を削除

---

### 8-H: UIコンポーネント逆参照除去

**目的**: UIコンポーネントからビジネスロジック層への逆参照を除去
**リスク**: 低〜中

#### 逆参照箇所

| ファイル | 逆参照 | 修正方針 |
|---------|--------|---------|
| **hand_display.gd** | `get_parent()` で UIManager を動的取得 | 正規の `set_ui_context()` 注入に変更 |
| **dominio_order_ui.gd** | `ui_manager_ref.game_flow_manager_ref` 逆参照 | GFMの入力ロック解除 → Signal化 |
| **global_comment_ui.gd** | `game_flow_manager_ref` 直接参照 | CPU判定 → Signal or コールバック注入 |
| **ui_tap_handler.gd** | `ui_manager.game_flow_manager_ref` 逆参照 | ドミニオ状態確認 → Signal化 |
| **ui_game_menu_handler.gd** | `game_flow_manager_ref.on_player_defeated()` | 降参処理 → Signal化 |

---

### 8-A: ItemPhaseHandler Signal化

**目的**: ItemPhaseHandler から `ui_manager` 直接参照を削除し、Signal 駆動に移行
**リスク**: 低
**前提**: 8-F 完了後、Signal リスナーは **CardSelectionService** と **MessageService** に接続

#### ui_manager 呼び出し一覧と変換方針

| 分類 | 現在の呼び出し | Signal |
|------|---------------|--------|
| フィルター設定 | `ui_manager.blocked_item_types = ...` 等 | `item_filter_configured(filter_config)` |
| 手札表示更新 | `ui_manager.update_hand_display(player_id)` | `item_hand_display_requested(player_id)` |
| カード選択UI | `ui_manager.card_selection_ui.show_selection(...)` | `item_selection_ui_shown(hand_data, config)` |
| フィルタークリア | `ui_manager.card_selection_filter = ""` 等 | `item_filter_cleared()` |

**追加修正**:
- `start_item_phase()` に `board_system.enable_manual_camera()` 追加

**見込み Signal 数**: ~4個
**Signal リスナー**: CardSelectionService（8-F で作成済み）

---

### 8-B: DominioCommandHandler Signal化

**目的**: DominioCommandHandler から `ui_manager` 直接参照を削除
**リスク**: 高（50箇所以上、状態遷移が複雑）
**前提**: 8-F 完了後、Signal リスナーは各サービスに接続

#### 段階的対応

**8-B1: ナビゲーション操作（~13箇所）→ NavigationService**

| 現在の呼び出し | Signal |
|---------------|--------|
| `ui_manager.clear_navigation_saved_state()` | `dominio_navigation_cleared()` |
| `ui_manager.enable_navigation(confirm, back)` ×6 | `dominio_navigation_configured(config)` |
| `ui_manager.disable_navigation()` | `dominio_navigation_disabled()` |

**8-B2: DominioOrderUI 操作（~15箇所）→ UIManager残存部（DominioOrderUI管理）**

| 現在の呼び出し | Signal |
|---------------|--------|
| `ui_manager.show_land_selection_mode(...)` | `dominio_land_selection_shown(lands)` |
| `ui_manager.dominio_order_ui.hide_level_selection()` 等 | `dominio_ui_state_changed(state)` |
| `ui_manager.hide_dominio_order_ui()` | `dominio_ui_closed()` |
| `ui_manager.show_action_menu()` 等 | `dominio_ui_state_changed(state)` |

**8-B3: その他 UI 操作（~10箇所）→ MessageService, InfoPanelService 等**

| 現在の呼び出し | Signal |
|---------------|--------|
| `ui_manager.phase_display.show_toast(...)` | `dominio_toast_shown(msg)` |
| `ui_manager.hide_all_info_panels()` | `dominio_info_panels_hidden()` |
| `ui_manager.update_player_info_panels()` | `dominio_player_info_updated()` |
| `ui_manager.show_comment_and_wait()` | request/completed Signal ペア |

**追加修正**:
- `open_dominio_order()` に `board_system.enable_manual_camera()` 追加

**見込み Signal 総数**: ~14個

---

### 8-C: BankruptcyHandler パネル直接生成の分離

**目的**: `Panel.new()`, `Label.new()` の直接生成をUIコンポーネント側に移動
**リスク**: 低

| 行番号 | 生成コード | 用途 |
|--------|-----------|------|
| L119 | `Panel.new()` | 破産情報パネル |
| L150 | `Label.new()` | 現在のEPラベル |
| L162 | `Label.new()` | 売却後のEPラベル |

**方針**:
1. `BankruptcyInfoPanel` UIコンポーネント（新規）を作成
2. パネル構築ロジックを移動
3. BankruptcyHandler は Signal で表示/更新を依頼

---

### 8-E: 兄弟システム Signal化

**目的**: UIManager と同レベルのシステムが UIManager を直接参照している問題を解消
**リスク**: 中〜高
**前提**: 8-F 完了後、Signal リスナーは各サービスに接続

#### 問題の構図

```
GameFlowManager（親）
  ├── BoardSystem3D ──❌直接参照──→ UIManager
  ├── BattleSystem ───❌直接参照──→ UIManager
  ├── SpecialTileSystem ─❌直接参照→ UIManager
  ├── TileActionProcessor ❌直接参照→ UIManager
  └── UIManager（本来ここだけがUIを管理）

SpellMysticArts ──❌チェーン参照──→ spell_ui_manager._ui_manager
```

#### 違反箇所と Signal 変換

| システム | 用途 | Signal リスナー先 |
|---------|------|-----------------|
| **BoardSystem3D** | フェーズテキスト、ドミニオボタン | MessageService |
| **BattleSystem** | バトル結果コメント | MessageService |
| **TileActionProcessor** | アクション指示、カード選択 | MessageService, CardSelectionService |
| **SpecialTileSystem** | カードフィルター、フェーズ表示 | CardSelectionService, MessageService |
| **SpellMysticArts** | チェーン参照でUI操作 | SpellUIManager のSignal経由 |

---

### 8-I: タイル系 → context経由サービス

**目的**: タイルが `context.get("ui_manager")` で UIManager 全体を取得する問題を解消
**リスク**: 低

#### 対象ファイル

| ファイル | 現在の参照 | 修正後 |
|---------|-----------|--------|
| special_base_tile.gd | `context.get("ui_manager")` | `context.get("message_service")` |
| magic_tile.gd | 同上 | `context.get("message_service")` + `context.get("ui_layer")` |
| magic_stone_tile.gd | 同上 | `context.get("message_service")` + `context.get("player_info_service")` |
| card_buy_tile.gd | 同上 | `context.get("message_service")` + `context.get("player_info_service")` |
| card_give_tile.gd | 同上 | `context.get("message_service")` + `context.get("card_selection_service")` |
| branch_tile.gd | 同上 | `context.get("message_service")` + `context.get("navigation_service")` |

**修正パターン**:

```gdscript
# Before
var _ui_manager = context.get("ui_manager")
await _ui_manager.global_comment_ui.show_comment_and_wait("魔法石を獲得！", player_id, true)

# After
var _message: MessageService = context.get("message_service")
await _message.show_comment_and_wait("魔法石を獲得！", player_id, true)
```

---

### 8-J: スペル系 → Signal/サービス注入

**目的**: スペル系ファイルの UIManager 依存を解消
**リスク**: 中

#### 対象ファイル

| ファイル | 参照数 | 方針 |
|---------|-------|------|
| **spell_borrow.gd** | 7 | CardSelectionService 直接注入 |
| **spell_creature_swap.gd** | 12 | CardSelectionService + NavigationService 注入 |
| **spell_world_curse.gd** | 1 | PlayerInfoService 注入（update_player_info_panels のみ） |
| **basic_draw_handler.gd** | 8 | CardSelectionService + MessageService 注入 |
| **condition_handler.gd** | 1 | CardSelectionService 注入（hand_display 更新のみ） |
| **purify_effect_strategy.gd** | 1 | MessageService 注入 |

**特殊ケース: spell_borrow, spell_creature_swap**

現在 `spell_ui_manager._ui_manager` 経由でアクセス。
改善: `spell_ui_manager` に CardSelectionService を注入 → スペル系はそこから取得。

---

### 8-K: 移動系 + その他

**目的**: 残りのファイルの UIManager 依存を解消
**リスク**: 中

#### 移動系

| ファイル | 参照数 | 注入するサービス |
|---------|-------|---------------|
| movement_direction_selector.gd | 3 | NavigationService, MessageService |
| movement_branch_selector.gd | 3 | NavigationService, MessageService |
| movement_controller.gd | — | 子への伝播のみ（サービス参照に変更） |

#### その他

| ファイル | 問題 | 修正方針 |
|---------|------|---------|
| **card.gd** | `find_ui_manager_recursive()` 再帰探索 | 正規の参照注入に変更（CardSelectionService） |
| **debug_controller.gd** | UIManager 直接参照 | 必要なサービスを個別注入（MessageService, CardSelectionService 等） |
| **tutorial_manager.gd** | UIManager 子コンポーネント直接アクセス | NavigationService + CardSelectionService 個別注入 |
| **explanation_mode.gd** | 同上 | NavigationService + CardSelectionService 個別注入 |
| **cpu_turn_processor.gd** | 3参照 | MessageService + PlayerInfoService 注入 |
| **lap_system.gd** | 4参照 | MessageService 注入 |
| **game_result_handler.gd** | 5参照 | UIManager 残存部（勝敗演出管理） |
| **game_flow_manager.gd** | 20+ | 各サービスを個別保持（コーディネーターとして正当） |
| **target_ui_helper.gd** | 2 | InfoPanelService 注入 |

---

### 8-D: UIManager 最終評価（全完了後）

**目的**: 全フェーズ完了後に UIManager の残存責務を評価

**評価基準**:
- UIManager のメソッド数が 20 以下か
- UIManager を直接参照するファイルが GFM + ui_components のみか
- 全サービス間に横断依存がないか
- 逆参照（UIコンポーネント → ビジネスロジック）がゼロか

---

## Signal 駆動化の全体状況

### ハンドラー

| ハンドラー | Signal数 | UI直接操作 | 状態 |
|-----------|---------|-----------|------|
| SpellPhaseHandler | 3 Signals | ✅ ゼロ | **完全分離** |
| SpellFlowHandler | 11 Signals | ✅ ゼロ | **完全分離** |
| MysticArtsHandler | 5 Signals | ✅ ゼロ | **完全分離** |
| DicePhaseHandler | 8 Signals | ✅ ゼロ | **完全分離** |
| TollPaymentHandler | 2 Signals | ✅ ゼロ | **完全分離** |
| DiscardHandler | 2 Signals | ✅ ゼロ | **完全分離** |
| BankruptcyHandler | 5 Signals | ⚠️ Panel直接生成 | **Phase 8-C** |
| ItemPhaseHandler | 0 Signals | ❌ 11箇所 | **Phase 8-A** |
| DominioCommandHandler | 0 Signals | ❌ 50箇所以上 | **Phase 8-B** |

### 兄弟システム → UIManager 直接参照

| システム | ui_manager 用途 | 状態 |
|---------|----------------|------|
| BoardSystem3D | フェーズテキスト、ドミニオボタン | ❌ **Phase 8-E** |
| BattleSystem | バトル結果コメント、global_comment_ui | ❌ **Phase 8-E** |
| TileActionProcessor | アクション指示、カード選択UI | ❌ **Phase 8-E** |
| SpecialTileSystem | カードフィルター、フェーズ表示 | ❌ **Phase 8-E** |
| SpellMysticArts | チェーン参照で ui_manager アクセス | ❌ **Phase 8-E** |

### UIManager 参照ファイル → サービス移行状況

| カテゴリ | 対象ファイル数 | 状態 |
|---------|-------------|------|
| UIヘルパー（最重量級） | ~6 | ❌ **Phase 8-G** |
| UIコンポーネント逆参照 | ~4 | ❌ **Phase 8-H** |
| タイル系 | ~6 | ❌ **Phase 8-I** |
| スペル系 | ~6 | ❌ **Phase 8-J** |
| 移動系 + その他 | ~10 | ❌ **Phase 8-K** |

---

## カメラモード設定漏れ（Phase 8 で同時修正）

| ファイル | 箇所 | 修正Phase |
|---------|------|----------|
| `item_phase_handler.gd` | `start_item_phase()` | 8-A |
| `dominio_command_handler.gd` | `open_dominio_order()` | 8-B |
