# GameSystemManager 設計書

> **⚠️ 注意**: この文書は初期設計時（2025-11-22）のものです。
> 実装後に多数のシステム追加・リファクタリングが行われたため、
> **最新の初期化順序・実装詳細は以下を参照してください**:
> - 実装ドキュメント: `docs/design/game_system_manager_implementation.md`
> - コーディングスキル: `/mnt/skills/user/gdscript-coding/SKILL.md`
> - 実装コード: `scripts/system_manager/game_system_manager.gd`
>
> 本文書は設計意図・背景の参考資料として残しています。
> 具体的なコード例やシステム一覧は古い可能性があります。
>
> **主な差分**:
> - SkillSystem は廃止（スキル処理は BattleSystem 配下に統合）
> - Phase 4-2 のスペル初期化は setup() メソッド方式に変更
> - Phase 1A ハンドラー（TargetSelectionHelper, DominioCommandHandler, SpellPhaseHandler, ItemPhaseHandler）が追加
> - CPUMovementEvaluator, CPUAIContext が追加
> - BattleScreenManager の初期化が Phase 4-1 最初に必要（順序制約追加）
> - SpellCurseToll, SpellCostModifier, SpellWorldCurse, SpellPlayerMove が追加

**バージョン**: 1.0（設計時）/ 注記追加: 2026-02-11  
**作成日**: 2025-11-22  
**目的**: game_3d.gd の複雑度を軽減し、システム初期化を一元管理

---

## 概要

Google Gemini による設計レビューで指摘された「システムマネージャーの必要性」に対応。
game_3d.gd と GameFlowManager が管理している複雑なシステム初期化・連携を、
専用の GameSystemManager クラスに委譲する設計。

### 対応システム数

| カテゴリ | システム数 | 詳細 |
|---------|----------|------|
| **Tier 1（GameSystemManager が直接作成）** | 11個 | SignalRegistry, BoardSystem3D, PlayerSystem, CardSystem, BattleSystem, SkillSystem, PlayerBuffSystem, SpecialTileSystem, UIManager, DebugController, GameFlowManager |
| **GameFlowManager の子システム** | 10個 | SpellDraw, SpellMagic, SpellLand, SpellCurse, SpellDice, SpellCurseStat, DominioOrderHandler, SpellPhaseHandler, ItemPhaseHandler, CPUAIHandler |
| **BoardSystem3D の子システム** | 4個 | TileActionProcessor, CPUTurnProcessor, MovementController, CPUAIHandler |
| **内部管理システム** | 2個 | CreatureManager (in BoardSystem3D), TileDataManager (in BoardSystem3D) |
| **合計対応システム** | **27個** | 全120ファイル以上のプロジェクトをカバー |

---

## 現在の問題点

### 1. game_3d.gd の複雑度が高い

**現状**:
```
func _ready():
	initialize_systems()      # 9個のシステム作成
	setup_game()              # 複数のシステム間連携設定
	connect_signals()         # 多数のシグナル接続
	await ...
	game_flow_manager.start_game()
```

**問題**:
- 初期化ロジックが 100+ 行に及ぶ
- システム間の依存関係が明示的でない
- 初期化順序が複雑（SignalRegistry → システム → UI → ゲーム開始）
- 新しいシステム追加時に game_3d.gd を修正する必要

### 2. GameFlowManager の責務が複雑

**問題**:
- 9個のシステム参照を保持
- システム初期化ロジックが分散
- ゲームフェーズ管理とシステム管理が混在

### 3. 初期化順序が複雑で脆弱

**現在の順序**:
```
1. SignalRegistry 作成（重要：最初）
2. BoardSystem3D 作成
3. PlayerSystem 作成
4. CardSystem 作成
5. BattleSystem 作成
6. PlayerBuffSystem 作成
7. SpecialTileSystem 作成
8. UIManager 作成
9. DebugController 作成
10. GameFlowManager 作成

11. 3D ノード収集（camera, tiles, players）
12. システムへの設定（PlayerSystem.initialize_players など）
13. BoardSystem3D への参照設定
14. UIManager への参照設定
15. GameFlowManager への参照設定
... 計20+ステップ
```

**問題**:
- 順序を間違えるとバグ発生
- 順序の根拠が不明確
- 段階的理解が困難

---

## 解決方針：GameSystemManager の設計

### 基本コンセプト

**単一責任の原則**に基づき、以下のように責務を分割：

| クラス | 責務 |
|--------|------|
| **game_3d.gd** | ゲームシーンのセットアップと開始指示のみ |
| **GameSystemManager** | 全システムの作成・初期化・連携を一元管理 |
| **GameFlowManager** | ゲームのフェーズ管理とターン進行のみ |

---

## GameSystemManager の設計

### ファイル位置
```
scripts/
├── system_manager/
│   └── game_system_manager.gd  ← 新規作成
```

### クラス構造

```gdscript
class_name GameSystemManager
extends Node

# === システム参照 ===
var systems: Dictionary = {}

# 個別参照（アクセス便宜用）
var signal_registry: SignalRegistry
var board_system_3d: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var player_buff_system: PlayerBuffSystem
var special_tile_system: SpecialTileSystem
var ui_manager: UIManager
var debug_controller: DebugController
var game_flow_manager: GameFlowManager

# === 設定 ===
var player_count: int = 2
var player_is_cpu: Array = [false, true]
var debug_manual_control_all: bool = true

# === 3D シーンノード ===
var tiles_container: Node
var players_container: Node
var camera_3d: Camera3D
var ui_layer: CanvasLayer

# === 初期化フェーズ ===
# Phase 1: システム作成
# Phase 2: 3D ノード収集
# Phase 3: システム基本設定
# Phase 4: システム間連携設定
# Phase 5: シグナル接続
# Phase 6: ゲーム開始準備
```

---

## 実装方針：6フェーズ初期化

### Phase 1: システム作成

**何をする**: 9個のシステムを作成・登録

```gdscript
func phase_1_create_systems() -> void:
	print("[GameSystemManager] Phase 1: システム作成開始")
	
	# システム作成順序（重要：依存関係順）
	_create_signal_registry()      # 最初（他が使う可能性）
	_create_board_system()
	_create_player_system()
	_create_card_system()
	_create_battle_system()
	_create_player_buff_system()
	_create_special_tile_system()
	_create_ui_manager()
	_create_debug_controller()
	_create_game_flow_manager()
	
	print("[GameSystemManager] Phase 1: システム作成完了（9個）")
```

**理由**:
- SignalRegistry を最初に作成（他が参照する可能性）
- 他のシステムはほぼ独立（順序は相対的に自由）

---

### Phase 2: 3D ノード収集

**何をする**: game_3d シーン内の 3D ノードを取得

```gdscript
func phase_2_collect_3d_nodes(parent_node: Node) -> bool:
	print("[GameSystemManager] Phase 2: 3D ノード収集")
	
	tiles_container = parent_node.get_node_or_null("Tiles")
	players_container = parent_node.get_node_or_null("Players")
	camera_3d = parent_node.get_node_or_null("Camera3D")
	ui_layer = parent_node.get_node_or_null("UILayer")
	
	var all_found = tiles_container and players_container and camera_3d and ui_layer
	
	if all_found:
		print("[GameSystemManager] Phase 2: 3D ノード収集完了")
	else:
		print("[GameSystemManager] WARNING: 一部の3Dノードが見つかりません")
	
	return all_found
```

**理由**:
- ゲームシーン（game_3d.tscn）のノード構造を理解する必要
- 以降のフェーズで使用

---

### Phase 3: システム基本設定

**何をする**: 各システムの基本設定（単独で完結）

```gdscript
func phase_3_setup_basic_config() -> void:
	print("[GameSystemManager] Phase 3: システム基本設定")
	
	# PlayerSystem
	player_system.initialize_players(player_count)
	
	# BoardSystem3D - 初期化順序が重要
	board_system_3d.camera = camera_3d  # ← カメラ参照を最初に設定（重要）
	board_system_3d.player_count = player_count
	board_system_3d.player_is_cpu = player_is_cpu
	board_system_3d.current_player_index = 0
	
	# 3D ノード収集（カメラ設定後に実行）
	if tiles_container:
		board_system_3d.collect_tiles(tiles_container)
	if players_container:
		board_system_3d.collect_players(players_container)  # ← ここでcamera参照が必要
	
	# UIManager - create_ui()はPhase 4-1後に呼び出す（参照設定待ち）
	# UIManagerはadd_childされており、_readyで自動初期化済み
	
	print("[GameSystemManager] Phase 3: システム基本設定完了")
```

**重要な順序**:
1. カメラ参照を最初に設定
2. collect_tiles() を実行
3. collect_players() を実行（移動コントローラーがカメラを使用）

**UIManager.create_ui()は実行しない**:
- create_ui()は以下を必要とする：player_system_ref, board_system_ref, card_system_ref, game_flow_manager_ref
- これらはPhase 4-1で設定される
- Phase 3では参照がないため、create_ui()はPhase 4-1後に遅延実行

**理由**:
- 各システムが単独で実行可能
- 他システムの初期化に依存しない
- **カメラの依存関係を正しく満たす**
- UIManager参照の依存関係を正しく満たす（Phase 4-1後）
- デバッグやテストが容易

---

### Phase 4: システム間連携設定

**何をする**: システム同士が参照できるように設定（20+ ステップ）

#### 4-1: 基本システム参照設定

```gdscript
func phase_4_setup_system_interconnections() -> void:
	print("[GameSystemManager] Phase 4: システム間連携設定開始")
	
	# ===== 4-1: 基本システム参照設定 =====
	print("[GameSystemManager] Phase 4-1: 基本システム参照設定")
	
	# Step 1: GameFlowManager に全システムを設定
	game_flow_manager.setup_systems(
		player_system, card_system, board_system_3d, skill_system,
		ui_manager, battle_system, special_tile_system
	)
	
	# Step 2: BoardSystem3D に全システムを設定
	board_system_3d.setup_systems(
		player_system, card_system, battle_system, skill_system,
		special_tile_system, game_flow_manager
	)
	board_system_3d.ui_manager = ui_manager
	
	# Step 3: SpecialTileSystem に必要なシステムを設定
	special_tile_system.setup_systems(
		board_system_3d, card_system, player_system, ui_manager
	)
	
	# Step 4: DebugController に設定
	debug_controller.setup_systems(
		player_system, board_system_3d, card_system, ui_manager
	)
	player_system.set_debug_controller(debug_controller)
	
	# Step 5: UIManager に参照を設定
	ui_manager.board_system_ref = board_system_3d
	ui_manager.player_system_ref = player_system
	ui_manager.card_system_ref = card_system
	ui_manager.game_flow_manager_ref = game_flow_manager
	
	# Step 6: UIManager をUILayerに移動
	if ui_layer:
		# UIManagerはGameSystemManagerの子から外し、UILayerの子に追加
		# この処理でUIが画面に表示される
		pass  # 実装時に実際の移動処理を記述
	
	# Step 7: CardSelectionUI に設定
	if ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager
	
	# Step 8: BattleSystem に設定
	if battle_system:
		battle_system.game_flow_manager_ref = game_flow_manager
	
	# Step 9: GameFlowManager の 3D 設定
	game_flow_manager.debug_manual_control_all = debug_manual_control_all
	game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)
	
	# Step 10: UIManager.create_ui() 実行（全参照設定後）
	# ここで初めて create_ui() を呼び出し
	# 理由: create_ui() が player_system_ref, board_system_ref, card_system_ref, game_flow_manager_ref を必要とする
	if parent_node:
		ui_manager.create_ui(parent_node)
	
	print("[GameSystemManager] Phase 4-1: 基本システム参照設定完了")

#### 4-2: GameFlowManager 子システム初期化

	# ===== 4-2: GameFlowManager 子システム初期化 =====
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム初期化")
	
	# Step 10: SpellDraw の初期化
	# 依存: card_system, player_system, ui_manager
	if game_flow_manager.spell_draw:
		game_flow_manager.spell_draw.card_system = card_system
		game_flow_manager.spell_draw.player_system = player_system
		game_flow_manager.spell_draw.ui_manager = ui_manager
	
	# Step 10: SpellMagic の初期化
	# 依存: player_system, card_system
	if game_flow_manager.spell_magic:
		game_flow_manager.spell_magic.player_system = player_system
		game_flow_manager.spell_magic.card_system = card_system
	
	# Step 11: SpellDice の初期化
	# 依存: player_system, ui_manager
	if game_flow_manager.spell_dice:
		game_flow_manager.spell_dice.player_system = player_system
		game_flow_manager.spell_dice.ui_manager = ui_manager
	
	# Step 12: SpellCurse の初期化
	# 依存: player_system, board_system_3d, creature_manager
	if game_flow_manager.spell_curse:
		game_flow_manager.spell_curse.player_system = player_system
		game_flow_manager.spell_curse.board_system_3d = board_system_3d
		# CreatureManager は board_system_3d から取得
	
	# Step 13: SpellCurseStat の初期化
	# 依存: player_system
	if game_flow_manager.spell_curse_stat:
		game_flow_manager.spell_curse_stat.player_system = player_system
	
	# Step 14: SpellLand の初期化（複雑な依存関係）
	# 依存: board_system_3d, player_system, card_system, creature_manager
	if game_flow_manager.spell_land:
		game_flow_manager.spell_land.board_system_3d = board_system_3d
		game_flow_manager.spell_land.player_system = player_system
		game_flow_manager.spell_land.card_system = card_system
		# creature_manager, tile_data_manager は board_system_3d から取得
	
	# Step 15: DominioOrderHandler の初期化
	# 依存: board_system_3d, player_system, ui_manager
	if game_flow_manager.dominio_order_handler:
		game_flow_manager.dominio_order_handler.board_system_3d = board_system_3d
		game_flow_manager.dominio_order_handler.player_system = player_system
		game_flow_manager.dominio_order_handler.ui_manager = ui_manager
	
	# Step 16: SpellPhaseHandler の初期化
	# 依存: board_system_3d, game_flow_manager, ui_manager
	if game_flow_manager.spell_phase_handler:
		game_flow_manager.spell_phase_handler.board_system_3d = board_system_3d
		game_flow_manager.spell_phase_handler.game_flow_manager = game_flow_manager
		game_flow_manager.spell_phase_handler.ui_manager = ui_manager
	
	# Step 17: ItemPhaseHandler の初期化
	# 依存: board_system_3d, player_system, ui_manager
	if game_flow_manager.item_phase_handler:
		game_flow_manager.item_phase_handler.board_system_3d = board_system_3d
		game_flow_manager.item_phase_handler.player_system = player_system
		game_flow_manager.item_phase_handler.ui_manager = ui_manager
	
	# Step 18: CPUAIHandler の初期化
	# 依存: board_system_3d, player_system, player_buff_system
	if game_flow_manager.cpu_ai_handler:
		game_flow_manager.cpu_ai_handler.board_system_3d = board_system_3d
		game_flow_manager.cpu_ai_handler.player_system = player_system
		game_flow_manager.cpu_ai_handler.player_buff_system = player_buff_system
	
	print("[GameSystemManager] Phase 4-2: GameFlowManager 子システム初期化完了")

#### 4-3: BoardSystem3D 子システム初期化

	# ===== 4-3: BoardSystem3D 子システム初期化 =====
	print("[GameSystemManager] Phase 4-3: BoardSystem3D 子システム初期化")
	
	# Step 19: TileActionProcessor の初期化（複雑な依存関係）
	# 依存: board_system_3d, player_system, card_system, battle_system
	#       game_flow_manager, player_buff_system, special_tile_system
	if board_system_3d.tile_action_processor:
		board_system_3d.tile_action_processor.board_system_3d = board_system_3d
		board_system_3d.tile_action_processor.player_system = player_system
		board_system_3d.tile_action_processor.card_system = card_system
		board_system_3d.tile_action_processor.battle_system = battle_system
		board_system_3d.tile_action_processor.game_flow_manager = game_flow_manager
		board_system_3d.tile_action_processor.player_buff_system = player_buff_system
		board_system_3d.tile_action_processor.special_tile_system = special_tile_system
	
	# Step 20: CPUTurnProcessor の初期化
	# 依存: board_system_3d, player_system, game_flow_manager
	if board_system_3d.cpu_turn_processor:
		board_system_3d.cpu_turn_processor.board_system_3d = board_system_3d
		board_system_3d.cpu_turn_processor.player_system = player_system
		board_system_3d.cpu_turn_processor.game_flow_manager = game_flow_manager
	
	# Step 21: MovementController の初期化
	# 依存: board_system_3d, player_system, ui_manager
	if board_system_3d.movement_controller:
		board_system_3d.movement_controller.board_system_3d = board_system_3d
		board_system_3d.movement_controller.player_system = player_system
		board_system_3d.movement_controller.ui_manager = ui_manager
	
	# Step 22: CPUAIHandler in BoardSystem3D の初期化
	# 依存: board_system_3d, game_flow_manager, player_buff_system
	if board_system_3d.cpu_ai_handler:
		board_system_3d.cpu_ai_handler.board_system_3d = board_system_3d
		board_system_3d.cpu_ai_handler.game_flow_manager = game_flow_manager
		board_system_3d.cpu_ai_handler.player_buff_system = player_buff_system
	
	print("[GameSystemManager] Phase 4-3: BoardSystem3D 子システム初期化完了")

#### 4-4: 特別な初期化

	# ===== 4-4: 特別な初期化 =====
	print("[GameSystemManager] Phase 4-4: 特別な初期化")
	
	# Step 23: GameFlowManager の最終初期化
	game_flow_manager.initialize_phase1a_systems()
	
	print("[GameSystemManager] Phase 4: システム間連携設定完了")
```

**各セクションの理由**:

- **4-1**: 基本システム群の参照設定（独立して実行可能）
- **4-2**: GameFlowManager の子システム初期化（複数の子システムが各親システムを必要とする）
- **4-3**: BoardSystem3D の子システム初期化（複雑な参照関係を持つ）
- **4-4**: 最終的な初期化ステップ

---

### Phase 5: シグナル接続

**何をする**: システム間のシグナル接続を一元管理

```gdscript
func phase_5_connect_signals() -> void:
	print("[GameSystemManager] Phase 5: シグナル接続")
	
	# GameFlowManager のシグナル
	game_flow_manager.dice_rolled.connect(_on_dice_rolled)
	game_flow_manager.turn_started.connect(_on_turn_started)
	game_flow_manager.turn_ended.connect(_on_turn_ended)
	game_flow_manager.phase_changed.connect(_on_phase_changed)
	
	# PlayerSystem のシグナル
	player_system.player_won.connect(game_flow_manager.on_player_won)
	
	# UIManager のシグナル
	ui_manager.dice_button_pressed.connect(game_flow_manager.roll_dice)
	ui_manager.card_selected.connect(game_flow_manager.on_card_selected)
	ui_manager.pass_button_pressed.connect(game_flow_manager.on_pass_button_pressed)
	ui_manager.level_up_selected.connect(game_flow_manager.on_level_up_selected)
	ui_manager.dominio_order_button_pressed.connect(game_flow_manager.open_dominio_order)
	
	print("[GameSystemManager] Phase 5: シグナル接続完了")
```

**理由**:
- シグナル接続ロジックを一箇所に集約
- 接続状態の可視化が容易
- デバッグ時に接続状況を確認しやすい

---

### Phase 6: ゲーム開始準備

**何をする**: ゲーム開始直前の最終準備

```gdscript
func phase_6_prepare_game_start() -> void:
	print("[GameSystemManager] Phase 6: ゲーム開始準備")
	
	# 初期手札配布
	await get_tree().create_timer(0.1).timeout
	card_system.deal_initial_hands_all_players(player_count)
	
	await get_tree().create_timer(0.1).timeout
	ui_manager.update_player_info_panels()
	
	# 操作説明を表示
	_print_controls_help()
	
	print("[GameSystemManager] Phase 6: ゲーム開始準備完了")
```

**理由**:
- UI の最終更新
- ゲーム開始前の確認事項を一箇所に集約

---

## 実装時に判明した問題と解決策

### ❌ 削除された設計要素

**1. UIManager.create_ui()メソッド**
- **問題**: ドキュメントで説明されているが、実装に存在しない
- **理由**: UIManagerは`_ready()`で自動初期化される設計のため不要
- **修正**: Phase 3でcreate_ui()呼び出しを削除。UILayerへの親ノード移動のみ実施

**2. UIManager.initialize_hand_container()の実行タイミング**
- **問題**: Phase 3で実行すると、PlayerSystem参照がまだ設定されていない
- **理由**: UIManagerが画面描画される前に参照が必要だが、Phase 4-1で設定される
- **修正**: UIManagerをUILayerに移動（Phase 4-1 Step 6）してから、システム参照を設定

**3. カメラ初期化の順序問題（重要）**
- **問題**: BoardSystem3D.collect_players() が movement_controller.initialize(camera) を呼び出すが、その時点でカメラが設定されていない
- **流れ**:
  ```
  Phase 3で実行:
  1. board_system_3d.camera = camera_3d  ← カメラ参照設定
  2. board_system_3d.collect_tiles()     ← OK
  3. board_system_3d.collect_players()   ← movement_controller.initialize(camera)を呼ぶ
										  ← cameraが正しく設定されていることが前提
  ```
- **修正**: Phase 3で**カメラ参照設定を collect_players() より前に実行**すること
- **実装ルール**:
  ```gdscript
  board_system_3d.camera = camera_3d     # ← 最初に設定
  board_system_3d.collect_tiles(tiles_container)
  board_system_3d.collect_players(players_container)
  ```

**4. UIManager.create_ui()メソッド（正規実装）**
- **実装状況**: 実装されている ✓
- **機能**: UILayerを新規作成し、各UIコンポーネント（PlayerInfoPanel, CardSelectionUI等）を初期化
- **呼び出しタイミング**: Phase 4-1 Step 10（全参照設定後）
- **必要な参照**: player_system_ref, board_system_ref, card_system_ref, game_flow_manager_ref
  ```gdscript
  func create_ui(parent: Node):
	# これらの参照がsetされた後に呼び出す必要がある
	player_info_panel.initialize(ui_layer, player_system_ref, null)
	card_selection_ui.initialize(ui_layer, card_system_ref, phase_label, self)
	...
  ```

- **修正**:
  - Phase 3では create_ui() を呼ばない（参照がないため）
  - Phase 4-1 Step 5 で全参照を設定
  - Phase 4-1 Step 10 で create_ui() を呼ぶ

**5. SpellCurse の初期化依存関係**
- **問題**: SpellCurse が複数の子システム（SpellDice, SpellCurseStat）から依存されているため、初期化順序が重要
- **依存関係**:
  ```
  SpellCurse ← SpellDice (setup時にspell_curseを参照)
  SpellCurse ← SpellCurseStat (setup時にspell_curseを参照)
  SpellCurse ← SpellLand (直接参照はなし)
  ```
- **初期化順序**:
  1. SpellCurse を最初に初期化（Phase 4-2 Step 12）
  2. SpellDice を初期化（Phase 4-2 Step 11）→ setup時にSpellCurseを参照
  3. SpellCurseStat を初期化（Phase 4-2 Step 13）→ setup時にSpellCurseを参照
- **修正**: GameSystemManager の Phase 4-2 で SpellCurse を最初に初期化してから、依存するシステムを初期化

### ✅ 重要な実装ルール

**UIManagerの親ノード移動**
```
Phase 1: GameSystemManager作成時、UIManagerはGameSystemManagerの子として追加
Phase 4-1 Step 6: UIManagerをUILayerに移動（画面描画に必要）
結果: UIが正しく表示される
```

**UILayerが存在しない場合**
- Main.tscnに`[node name="UILayer" type="CanvasLayer" parent="."]`を追加すること
- UILayerなしではUIが正常に表示されない

---

## 潜在的な問題点と対策

### 1. 初期化順序の複雑性

**問題**:
- SpellLand が複数参照を必要とする（board_system, player_system, card_system, creature_manager）
- TileActionProcessor が 8+ の参照を必要とする
- 順序を間違えると参照エラーが発生

**対策**:
- ✅ Phase 4 を 4 つのセクション（4-1～4-4）に明示的に分割
- ✅ 各ステップで「依存: 〇〇, △△」を明記
- ✅ 4-1 で基本システムを先に設定してから 4-2, 4-3 で子システムを初期化
- ✅ 各初期化前に `if` でシステム存在確認

### 2. CreatureManager の扱い

**問題**:
- SpellLand, SpellCurse で CreatureManager が必要
- GameSystemManager では直接作成しない

**対策**:
- ✅ CreatureManager は BoardSystem3D の内部で管理される
- ✅ SpellLand, SpellCurse から board_system_3d を経由してアクセス
- ✅ Step 12（SpellCurse）, Step 14（SpellLand）で board_system_3d を設定

### 3. TileDataManager の扱い

**問題**:
- board_system_3d で使用される
- 初期化タイミングが不明確

**対策**:
- ✅ TileDataManager は BoardSystem3D の内部で管理される
- ✅ Phase 3 の collect_tiles() 内で自動初期化される
- ✅ GameSystemManager では直接操作しない

### 4. 参照循環の可能性

**問題**:
- game_flow_manager ↔ board_system_3d の相互参照
- game_flow_manager ↔ ui_manager の相互参照

**対策**:
- ✅ 4-1 で基本参照を設定し、4-2, 4-3 で子システムを接続
- ✅ 各 Step で参照の上書きを避ける
- ✅ 循環参照は「異なるオブジェクト」なので無限ループにはならない

### 5. 子システムの存在確認

**問題**:
- GameFlowManager や BoardSystem3D が子システムを作成していない可能性
- 存在しないシステムへのアクセスでランタイムエラー

**対策**:
- ✅ Step 9～22 ですべて `if system:` で存在確認
- ✅ システムが存在しない場合はスキップ（エラーにはならない）

---

## 修正対象ファイル

### 1. 新規作成：scripts/system_manager/game_system_manager.gd

**内容**:
- GameSystemManager クラス実装（6フェーズ）
- SkillSystem を Phase 1 に追加
- SkillSystem を各 setup_systems() に含める
- Phase 4-1 Step 10 で `ui_manager.create_ui(parent_node)` を実行

### 2. 修正：scripts/game_3d.gd

**削除対象**:
- `ui_manager.create_ui(self)` - 呼び出しを削除
- `ui_manager.initialize_hand_container(ui_layer)` - 存在しないメソッドを削除

**変更内容**:
- GameSystemManager 呼び出しに置換
- initialize_systems()、setup_game()、connect_signals() を削除

### 3. 修正：scenes/Main.tscn

**確認事項**:
```
[node name="UILayer" type="CanvasLayer" parent="."]
```

UILayerが存在することを確認（既に存在する場合は追加不要）

### 4. 修正対象外：GameFlowManager

- GameSystemManager が正しく参照を設定していれば、変更不要

---

## 実装に必要な確認事項

### ✅ 実装前チェックリスト

**UIManager関連**:
- [ ] **UIManager.create_ui() は Phase 4-1 Step 10 で呼び出されること（全参照設定後）**
- [ ] **Phase 3 では UIManager.create_ui() を呼び出さないこと**
- [ ] **Phase 4-1 Step 5 で UIManager に全参照が設定されていることを確認**
- [ ] **game_3d.gd から `ui_manager.create_ui(self)` 呼び出しを削除**
- [ ] **game_3d.gd から `ui_manager.initialize_hand_container(ui_layer)` を削除**

**カメラ関連**:
- [ ] **Phase 3でカメラ参照を board_system_3d.camera = camera_3d で最初に設定**
- [ ] **Phase 3で collect_tiles() より前にカメラを設定していること**
- [ ] **Phase 3で collect_players() がカメラ参照を使用できる状態であること**
- [ ] **game_3d.gd でカメラ位置を `Vector3(19, 19, 19)` に設定**

**SkillSystem関連**:
- [ ] **SkillSystem を Phase 1 に追加**
- [ ] **GameFlowManager.setup_systems() に skill_system パラメータを含める**
- [ ] **BoardSystem3D.setup_systems() に skill_system パラメータを含める**

**Spell関連**:
- [ ] **SpellCurse が Phase 4-2 Step 12 で最初に初期化されていることを確認**
- [ ] **SpellDice と SpellCurseStat が SpellCurse の後に初期化されていることを確認**
- [ ] **各Spell系システムのsetupメソッドシグネチャが正確であることを確認**

**その他**:
- [ ] Main.tscn に UILayer ノードが存在することを確認（必須）
- [ ] 各ステップで正しいメソッドシグネチャを使用していることを確認

### ⚠️ よくあるエラーと解決策

**エラー**: UIが表示されない
→ Main.tscnにUILayerが存在しているか確認

**エラー**: プレイヤー情報が表示されない
→ UIManagerがUILayerに正しく移動されているか確認

**エラー**: ゲームが起動しない
→ Phase 3でUIManagerをUILayerに移動した時点でゲームシーンが破壊されていないか確認

**エラー**: カメラが初期位置と違う
→ game_3d.gd の `camera.position = Vector3(19, 19, 19)` が実行されていないか確認
→ Main.tscn の Camera3D の初期Transform が保持されていることを確認
→ GameSystemManager Phase 3 でカメラ位置を上書きしていないこと

**エラー**: プレイヤー情報UIが表示されない
→ **UIManager.create_ui() が Phase 4-1 Step 10 で呼ばれているか確認**（Phase 3ではなく）
→ **UIManager に全参照が設定されているか確認** (player_system_ref, board_system_ref, card_system_ref, game_flow_manager_ref)
→ **game_3d.gd から `ui_manager.create_ui(self)` が削除されているか確認**
→ **PlayerInfoPanel.initialize() が呼ばれているか確認**
→ **UILayer にPlayerInfoPanelが追加されているか確認**

**エラー**: SpellDice や SpellCurseStat が初期化されない
→ SpellCurse が最初に初期化されていることを確認（Phase 4-2 Step 12）
→ SpellDice と SpellCurseStat の setup() メソッドが正しい引数を受け取っているか確認
→ 初期化順序: SpellCurse → SpellDice → SpellCurseStat の順序を守っているか確認

**エラー**: "Invalid assignment of property or key 'spell_curse'" エラー
→ SpellDice.setup() の第2引数が SpellCurse オブジェクトであることを確認
→ SpellCurse が参照可能な状態（初期化済み）であることを確認

---

## 利点

### ✅ 即座の利点

1. **game_3d.gd の簡潔化**
   - 100+ 行 → 25 行
   - 責務が明確化

2. **初期化順序の明示化**
   - 6フェーズで順序が明確
   - 新規開発者の理解が容易

3. **スケーラビリティ**
   - 新システム追加時、GameSystemManager に追加するだけ
   - game_3d.gd は修正不要

4. **テスト容易性**
   - 各フェーズを独立してテスト可能
   - 初期化ロジックの単体テストが可能

### ✅ 長期的な利点

1. **保守性向上**
   - システム間の依存関係が明示的
   - バグの原因が特定しやすい

2. **拡張性向上**
   - 将来のシステム追加に対応容易
   - フェーズの追加や修正が容易

3. **チーム開発対応**
   - 複数開発者が各システムを並行実装可能
   - 初期化ロジックに対する競合が少ない

---

## リスク評価と対策

### リスク1：実装ミスによるシステム起動失敗

**リスク程度**: 中

**対策**:
- 各フェーズ実行後にログ出力
- フェーズ前後の状態確認機能
- ゲーム起動テストで全フェーズ検証

### リスク2：参照循環による無限ループ

**リスク程度**: 低（現在の実装では発生なし）

**対策**:
- Phase 4 で参照設定の順序を明示
- ドキュメント化

### リスク3：既存ロジックの破損

**リスク程度**: 低（ロジック変更なし）

**対策**:
- game_3d.gd のロジックは削除、GameSystemManager に移行のみ
- 機能追加ではなく純粋なリファクタリング

---

## 検証チェックリスト

実装後、以下を確認：

- [ ] GameSystemManager.gd ファイル作成
- [ ] 全6フェーズが正常に実行（ログ確認）
- [ ] Godot 構文エラーなし
- [ ] ゲーム起動テスト実施
- [ ] CPU AI の動作確認
- [ ] ダイスロール動作確認
- [ ] UIの更新確認
- [ ] デバッグ機能動作確認

---

## 将来への拡張性

### 新しいシステム追加時の手順

1. システムを Phase 1 の `_create_systems()` に追加
2. 必要に応じて Phase 3, 4, 5 に追加
3. game_3d.gd は修正不要

**例**:
```gdscript
# Phase 1 に追加
_create_achievement_system()

# Phase 4 に追加（if 他システムとの連携が必要）
achievement_system.setup_systems(player_system, board_system_3d)

# Phase 5 に追加（if シグナル接続が必要）
achievement_system.achievement_unlocked.connect(_on_achievement_unlocked)
```

---

## まとめ

**この設計により**:

1. ✅ game_3d.gd → 25 行（ゲーム開始指示のみ）
2. ✅ GameSystemManager → 明示的な6フェーズ
3. ✅ 初期化順序が明確で保守性向上
4. ✅ 将来のシステム追加が容易
5. ✅ 大規模プロジェクトに対応可能

---

**作成日**: 2025-11-22  
**作成者**: Game Development AI Assistant  
**バージョン**: 1.0（設計時）  
**注記追加日**: 2026-02-11  
**注記**: 実装後の変更が多数あり。最新情報は `docs/design/game_system_manager_implementation.md` を参照。
