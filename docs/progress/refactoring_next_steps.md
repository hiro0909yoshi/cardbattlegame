# リファクタリング次ステップ

**最終更新**: 2026-02-18
**現在のフェーズ**: Phase 8 — UIManager 依存方向の正規化

---

## ✅ 完了済み Phase（サマリー）

| Phase | 内容 | 実施日 |
|-------|------|--------|
| 7-A | CPU AI パススルー除去（SPH → GSM 直接注入） | 2026-02-17 |
| 7-B | SPH UI 依存逆転（Signal 駆動化、spell_ui_manager 直接呼び出しゼロ） | 2026-02-17 |
| 8-F | UIManager 内部4サービス分割（NavigationService, MessageService, CardSelectionService, InfoPanelService） | 2026-02-18 |
| 8-A | ItemPhaseHandler Signal化（4 Signals、ui_manager 完全削除） | 2026-02-18 |
| 8-B | DominioCommandHandler サービス注入（90→49参照、46%削減） | 2026-02-18 |
| 8-E | 兄弟システム サービス注入（TileActionProcessor 34→9, SpecialTileSystem 27→15, BattleSystem 4→0） | 2026-02-18 |
| 8-I | タイル系 ui_manager → サービス移行（6タイル、context 経由） | 2026-02-18 |
| 8-J | Spell系ファイル サービス注入（purify_effect_strategy, basic_draw_handler, condition_handler） | 2026-02-18 |
| 8-K | 移動系 ui_manager → サービス移行（3ファイル、movement_controller） | 2026-02-18 |
| 8-L | 小規模ファイル サービス注入（lap_system, cpu_turn_processor, target_ui_helper） | 2026-02-18 |

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

| 順番 | Phase | 内容 | 対象ファイル数 | 難易度 | 状態 |
|-----|-------|------|-------------|--------|------|
| 1 | **8-F** | UIManager 内部分割（4サービス、個別注入） | 1 + 4新規 | **高** | ✅ 完了 |
| ✅ | **8-G** | ヘルパー → サービス直接注入（5/6、CSH 63%減・LAH 67%減） | ~6 | 高 | ✅ 完了 |
| 3 | **8-H** | UIコンポーネント逆参照除去 | ~4 | 低〜中 | 待機 |
| ✅ | **8-A** | ItemPhaseHandler Signal化 | 1 | 低 | ✅ 完了 |
| ✅ | **8-B** | DominioCommandHandler サービス注入（90→49参照） | 1 | 高 | ✅ 完了 |
| 6 | **8-C** | BankruptcyHandler パネル分離 | 2 | 低 | 待機 |
| ✅ | **8-E** | 兄弟システム サービス注入（4ファイル、74-100%削減） | 4 | 中〜高 | ✅ 完了 |
| ✅ | **8-I** | タイル系 → context経由サービス | ~6 | 低 | ✅ 完了 |
| ✅ | **8-J** | スペル系 → サービス注入（3ファイル） | 3 | 中 | ✅ 完了 |
| ✅ | **8-K** | 移動系 + その他（3+1ファイル） | ~10 | 中 | ✅ 完了 |
| ✅ | **8-L** | 小規模ファイル サービス注入（3ファイル） | 3 | 低〜中 | ✅ 完了 |
| 12 | **8-D** | UIManager 最終評価 | — | — | 待機 |

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

### ✅ 8-G: ヘルパー → サービス直接注入（完了 2026-02-18）

**状態**: ✅ 5/6ファイル完了（card_sacrifice_helper は signal await パターンのため保留）

**実施結果**:

| ファイル | Before | After | 削減率 | セッション |
|---------|--------|-------|--------|----------|
| target_selection_helper.gd | 5 | 0 | 100% | 前セッション |
| tile_summon_executor.gd | 17 | 7 | 59% | 前セッション |
| tile_battle_executor.gd | 8 | 2 | 75% | 前セッション |
| **card_selection_handler.gd** | ~143 | 53 | **63%** | 本セッション |
| **land_action_helper.gd** | ~75 | 25 | **67%** | 本セッション |
| card_sacrifice_helper.gd | 12 | — | 保留 | — |

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

### ✅ 8-A: ItemPhaseHandler Signal化（完了 2026-02-18）

**目的**: ItemPhaseHandler から `ui_manager` 直接参照を削除し、Signal 駆動に移行
**リスク**: 低（完了）
**前提**: 8-F 完了後、Signal リスナーは **CardSelectionService** と **MessageService** に接続

#### 実装内容

**追加 Signal（4個）**:

| Signal | 発行元 | 役割 |
|--------|--------|------|
| `item_filter_configured(config)` | ItemPhaseHandler._show_item_selection_ui() | フィルター設定をUIに通知 |
| `item_filter_cleared()` | ItemPhaseHandler.complete_item_phase() | フィルターをリセット |
| `item_hand_display_update_requested(player_id)` | ItemPhaseHandler._show_item_selection_ui() と complete_item_phase() | 手札表示更新リクエスト |
| `item_selection_ui_show_requested(player, mode)` | ItemPhaseHandler._show_item_selection_ui() | カード選択UI表示リクエスト |

**コード変更**:

1. ItemPhaseHandler:
   - `var ui_manager = null` 削除
   - `initialize()` の `ui_mgr` パラメータ削除
   - `_show_item_selection_ui()` を Signal駆動に変更
   - `complete_item_phase()` でフィルタークリアを Signal 経由に

2. GameSystemManager:
   - `item_phase_handler.initialize(game_flow_manager, ...)` に変更（ui_manager 削除）
   - `_connect_item_phase_signals()` メソッド追加（4シグナル接続）
   - phase_4 で `_connect_item_phase_signals()` 呼び出し追加
   - `game_flow_manager.item_phase_handler.ui_manager = ui_manager` 削除

**見込み Signal 数**: 4個（完了）
**Signal リスナー**: GameSystemManager._connect_item_phase_signals() で直接接続

---

### ✅ 8-B: DominioCommandHandler サービス注入（完了 2026-02-18）

**目的**: DominioCommandHandler から ui_manager 依存を部分削減（サービス注入パターン）
**リスク**: 高（完了）
**戦略**: Signal化ではなくサービス注入。DCH はインタラクティブ（UI ↔ ロジック往復が多い）ため Signal 化は非実用的

#### 実装内容

**initialize() でサービス解決**:
- `_message_service`, `_navigation_service`, `_card_selection_service`, `_info_panel_service` を ui_mgr から解決

**移行結果**:

| サービス | 移行内容 | 箇所数 |
|---------|---------|-------|
| MessageService | show_toast, show_action_prompt, hide_action_prompt, show_comment_and_wait | 9 |
| NavigationService | enable_navigation, disable_navigation, clear_navigation_saved_state, clear_back_action | 10 |
| CardSelectionService | hide_card_selection_ui | 2 |
| InfoPanelService | hide_all_info_panels | 1 |
| **合計** | | **22** |

**ui_manager 残存（49参照）**: dominio_order_ui（9）、show_action_menu/show_land_selection_mode（6）、tap_target_manager（4）、level_up_selected signal（3）、card_selection_ui.deactivate（1）、update_player_info_panels（1）、add_child（1）、null チェック・ガード（24+）

**将来**: dominio_order_ui 直接注入で追加削減可能（Phase 8-B2）

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

### ✅ 8-E: 兄弟システム サービス注入（完了 2026-02-18）

**目的**: UIManager と同レベルのシステムが UIManager を直接参照している問題を解消
**リスク**: 中〜高（✅ 完了）
**前提**: 8-F 完了後、Signal リスナーは各サービスに接続

#### 実装内容

| システム | Before | After | 削減率 | 備考 |
|---------|--------|-------|--------|------|
| **TileActionProcessor** | 34 refs | 9 refs | **74%削減** | _message_service, _card_selection_service |
| **SpecialTileSystem** | 27 refs | 15 refs | **44%削減** | _message_service, _navigation_service, _card_selection_service |
| **BoardSystem3D** | 12 refs | 10 refs | **17%削減** | _message_service |
| **BattleSystem** | 4 refs | 0 refs | **100%削減** | _message_service（ui_manager完全排除） |
| **GameSystemManager** | — | 追加 | — | board_system_3d/battle_systemへのサービス注入 |

#### 修正内容

**BattleSystem**: `var ui_manager = null` 完全削除、MessageService 4箇所移行完了
**BoardSystem3D**: フェーズテキスト設定をMessageService経由に変更
**TileActionProcessor**: アクション指示・カード選択をサービス経由に変更
**SpecialTileSystem**: context に Message/Navigation/CardSelection Service 追加
**GameSystemManager**: `set_services()` メソッドで各システムにサービス注入

---

### ✅ 8-I: タイル系 → context経由サービス（完了 2026-02-18）

**目的**: タイルが `context.get("ui_manager")` で UIManager 全体を取得する問題を解消
**リスク**: 低
**状態**: ✅ 完全完了

#### 実装内容

| ファイル | 修正内容 |
|---------|---------|
| special_base_tile.gd | `context.get("ui_manager")` → `context.get("message_service")` **完全移行** |
| magic_tile.gd | `context.get("ui_manager")` → `context.get("message_service")` + `context.get("ui_layer")` **完全移行** |
| magic_stone_tile.gd | `context.get("message_service")` + `context.get("ui_layer")` 追加（update_player_info_panels は _ui_manager 暫定残し） |
| card_buy_tile.gd | `context.get("message_service")` + `context.get("ui_layer")` + `context.get("card_selection_service")` 追加（update_player_info_panels は暫定残し） |
| card_give_tile.gd | `context.get("ui_manager")` → 3サービス **完全移行** |
| branch_tile.gd | `context.get("ui_manager")` → `context.get("message_service")` + `context.get("navigation_service")` **完全移行** |

#### context に追加されたサービス

`special_tile_system.gd` の `_create_tile_context()`:
```gdscript
var context = {
	"message_service": _message_service,
	"navigation_service": _navigation_service,
	"card_selection_service": _card_selection_service,
	"ui_layer": ui_manager.ui_layer,
	...
}
```

**見込み完全移行**: 4/6ファイル

---

### ✅ 8-J: スペル系 → サービス注入（完了 2026-02-18）

**目的**: スペル系ファイルの UIManager 依存を解消
**リスク**: 中（✅ 完了）

#### 実装内容

| ファイル | 修正内容 | サービス |
|---------|---------|---------|
| **purify_effect_strategy.gd** | handler.spell_ui_manager._message_service 経由 | MessageService |
| **basic_draw_handler.gd** | 17→10 refs（59%削減） | MessageService, CardSelectionService |
| **condition_handler.gd** | 5→5 refs（構造改善） | CardSelectionService |

**実装パターン**:
- `purify_effect_strategy`: handler.spell_ui_manager 経由でメッセージサービスアクセス
- `basic_draw_handler`: initialize() でMessageService, CardSelectionService を直接注入
- `condition_handler`: ui_manager.card_selection_ui → _card_selection_service 経由に変更

---

### ✅ 8-K: 移動系 + その他（完了 2026-02-18）

**目的**: 移動系の UIManager 依存を解消（その他は8-J, 8-Lで対応）
**リスク**: 低
**状態**: ✅ 移動系 3/3 完全完了、その他1ファイル完了

#### 移動系実装内容

| ファイル | 修正内容 |
|---------|---------|
| movement_direction_selector.gd | ui_manager → _message_service + _navigation_service **完全移行** |
| movement_branch_selector.gd | 同パターン **完全移行** |
| movement_controller.gd | `var ui_manager = null` 完全削除、`set_services()` メソッド追加 |
| board_system_3d.gd | `set_movement_controller_ui_manager()` → `set_movement_controller_services()` に変更 |
| game_flow_manager.gd | 呼び出し元を `ui_manager.message_service, ui_manager.navigation_service` に変更 |

---

### ✅ 8-L: 小規模ファイル サービス注入（完了 2026-02-18）

**目的**: 残存する小規模ファイルの UIManager 依存を解消
**リスク**: 低
**状態**: ✅ 完全完了

#### 実装内容

| ファイル | Before | After | サービス |
|---------|--------|-------|---------|
| **lap_system.gd** | 10 refs | 11 refs（構造改善） | MessageService |
| **cpu_turn_processor.gd** | 8 refs | 6 refs（25%削減） | MessageService, CardSelectionService |
| **target_ui_helper.gd** | 10 refs | 9 refs（10%削減） | _get_info_panel_service()静的ヘルパー追加 |

**修正内容**:
- lap_system: フェーズテキスト設定をMessageService経由に変更（参照増加は構造改善のため）
- cpu_turn_processor: initialize() でMessageService, CardSelectionService を注入
- target_ui_helper: 静的ヘルパー `_get_info_panel_service()` で InfoPanelService 取得パターンを確立

#### その他（8-C/8-H に移行）

| ファイル | 問題 | 修正方針 | Phase |
|---------|------|---------|-------|
| **card.gd** | `find_ui_manager_recursive()` 再帰探索 | 正規の参照注入に変更（CardSelectionService） | 8-H |
| **debug_controller.gd** | UIManager 直接参照 | 必要なサービスを個別注入（MessageService, CardSelectionService 等） | 8-H |
| **tutorial_manager.gd** | UIManager 子コンポーネント直接アクセス | NavigationService + CardSelectionService 個別注入 | 8-H |
| **explanation_mode.gd** | 同上 | NavigationService + CardSelectionService 個別注入 | 8-H |
| **game_result_handler.gd** | 5参照 | UIManager 残存部（勝敗演出管理） | 8-H |

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
| ItemPhaseHandler | 4 Signals | ✅ ゼロ | **✅ 完全分離** |
| DominioCommandHandler | — | ⚠️ 49参照残存（サービス注入） | ✅ **Phase 8-B 完了** |

### 兄弟システム → UIManager 直接参照

| システム | ui_manager 用途 | 状態 |
|---------|----------------|------|
| BoardSystem3D | フェーズテキスト、ドミニオボタン | ✅ **Phase 8-E（完了）** |
| BattleSystem | バトル結果コメント、global_comment_ui | ✅ **Phase 8-E（完了）** |
| TileActionProcessor | アクション指示、カード選択UI | ✅ **Phase 8-E（完了）** |
| SpecialTileSystem | カードフィルター、フェーズ表示 | ✅ **Phase 8-E（完了）** |

### UIManager 参照ファイル → サービス移行状況

| カテゴリ | 対象ファイル数 | 状態 |
|---------|-------------|------|
| UIヘルパー（最重量級） | ~6 | ✅ **Phase 8-G（5/6完了）** |
| UIコンポーネント逆参照 | ~4 | ❌ **Phase 8-H** |
| タイル系 | ~6 | ✅ **Phase 8-I（完了）** |
| スペル系 | 3 | ✅ **Phase 8-J（完了）** |
| 移動系 | 3 | ✅ **Phase 8-K（完了）** |
| 小規模ファイル | 3 | ✅ **Phase 8-L（完了）** |

---

## カメラモード設定漏れ（Phase 8 で同時修正）

| ファイル | 箇所 | 修正Phase |
|---------|------|----------|
| `item_phase_handler.gd` | `start_item_phase()` | 8-A |
| `dominio_command_handler.gd` | `open_dominio_order()` | 8-B |
