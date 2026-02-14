# アーキテクチャ移行計画

**最終更新**: 2026-02-14（Phase 3-B Day 1 完了を反映）
**目的**: 理想的なツリー構造への段階的移行を計画し、リスクを最小化しながら実装する

**重要**: Phase 3 以降の詳細計画は `refactoring_next_steps.md` を参照してください。

---

## 📋 全体スケジュール

```
Phase 0: ツリー構造定義 ───────────── 1日 ✅ 完了 (2026-02-14)
Phase 1: SpellSystemManager 導入 ──── 2日 ✅ 完了 (2026-02-13)
Phase 2: シグナルリレー整備 ──────── 1日 ✅ 完了 (2026-02-14)
Phase 3-B: BoardSystem3D SSoT 化 ── 2-3日 🔵 進行中 (Day 1 完了)
  Day 1: CreatureManager SSoT 化 ──── ✅ 完了 (2026-02-14)
  Day 2: BaseTile/TileDataManager ──── ⚪ 未着手
  Day 3: シグナルチェーン＋テスト ── ⚪ 未着手
Phase 3-A: SpellPhaseHandler Strategy - 4-5日 ⚪ 未着手
Phase 4: UIManager 責務分離 ────── 3-4日 ⚪ 未着手
Phase 5: 統合テスト・ドキュメント ── 2-3日 ⚪ 未着手

完了: 4日 / 進行中: 1-2日 / 残り: 9-15日
```

---

## Phase 0: ツリー構造定義（1日）✅ 完了

**開始日**: 2026-02-14
**完了日**: 2026-02-14

### 目的

- 理想的なツリー構造を定義
- 現在のシステム依存関係をマップ化
- 段階的移行計画の基盤を確立

### 作業内容

#### タスク0-1: TREE_STRUCTURE.md 作成（2-3時間）✅ 完了

- [x] 理想的なツリー構造の図示
- [x] 各システムの責務定義
- [x] シグナルフローの設計原則

**成果物**: `docs/design/TREE_STRUCTURE.md`

---

#### タスク0-2: dependency_map.md 作成（2-3時間）✅ 完了

- [x] 現在の依存関係を可視化
- [x] 問題のある依存（循環、横断）を特定
- [x] 改善ポイントのリスト化

**成果物**: `docs/design/dependency_map.md`

---

#### タスク0-3: architecture_migration_plan.md 作成（1-2時間）🔵 進行中

- [x] Phase 1-4 の詳細タスク定義
- [ ] 各フェーズの成功指標
- [ ] リスク評価

**成果物**: `docs/progress/architecture_migration_plan.md`（本ドキュメント）

---

### 成功指標

- [ ] 3つのドキュメントが完成
- [ ] ツリー構造が視覚的に理解できる
- [ ] 問題のある依存が12箇所特定されている
- [ ] Phase 1-4 の作業内容が明確

### リスク

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| ドキュメントが実装と乖離 | 🟡 中 | 中 | 実装時に随時更新 |
| 問題の見落とし | 🟢 低 | 低 | Phase 1 開始前に再確認 |

---

## Phase 1: SpellSystemManager 導入（2日）✅ 完了

**開始日**: 2026-02-13
**完了日**: 2026-02-13

### 目的

- スペルシステムの階層化
- GameFlowManager の責務明確化
- 10+個のスペルシステムの統一的管理

### 背景

**現状の問題**:
```gdscript
GameFlowManager
└── spell_container: SpellSystemContainer (直接保持)
	├── spell_draw
	├── spell_magic
	├── spell_land
	... (10+個)
```

- SpellContainer が GameFlowManager に直接ぶら下がっている
- 階層が浅く、責務が不明確
- 新しいスペルシステム追加時に GameFlowManager を修正

**理想形**:
```gdscript
GameFlowManager
└── SpellSystemManager (新規)
	└── SpellSystemContainer
		├── spell_draw
		├── spell_magic
		... (10+個)
```

---

### 作業内容

#### タスク1-1: SpellSystemManager クラス作成（4-5時間）

**新規ファイル**: `scripts/game_flow/spell_system_manager.gd`

```gdscript
extends Node
class_name SpellSystemManager

## スペルシステム統括管理者
## GameFlowManager の子として配置され、全スペルシステムを管理

# コアスペルシステムコンテナ
var spell_container: SpellSystemContainer = null

# 個別スペルシステム（Node型）
var spell_curse_toll: SpellCurseToll = null
var spell_borrow: SpellBorrow = null
var spell_transform: SpellTransform = null
var spell_purify: SpellPurify = null
var spell_synthesis: SpellSynthesis = null

func _ready():
	print("[SpellSystemManager] 初期化完了")

## セットアップ
func setup(container: SpellSystemContainer) -> void:
	if not container:
		push_error("[SpellSystemManager] SpellSystemContainer が null です")
		return

	spell_container = container

	# Node型のスペルシステムを初期化
	_setup_node_spells()

	print("[SpellSystemManager] setup 完了")

## Node型スペルシステムの初期化
func _setup_node_spells() -> void:
	# spell_curse_toll の初期化例（既存コードから移行）
	# spell_curse_toll = SpellCurseToll.new()
	# add_child(spell_curse_toll)
	# spell_curse_toll.name = "SpellCurseToll"
	pass

## スペルシステムへのアクセサ（後方互換性）
func get_spell_draw():
	return spell_container.spell_draw if spell_container else null

func get_spell_magic():
	return spell_container.spell_magic if spell_container else null

# ... 他のスペルシステムも同様
```

**チェックポイント**:
- [ ] SpellSystemManager クラス定義
- [ ] spell_container 参照保持
- [ ] setup() メソッド実装
- [ ] アクセサメソッド実装（後方互換性）

---

#### タスク1-2: GameSystemManager の初期化を更新（2-3時間）

**対象ファイル**: `scripts/system_manager/game_system_manager.gd`

**変更箇所**: `_setup_spell_systems()` メソッド

```gdscript
# ===== 変更前 =====
func _setup_spell_systems() -> void:
	var spell_container = SpellSystemContainer.new()
	game_flow_manager.set_spell_container(spell_container)

	# 各スペルシステムの初期化...

# ===== 変更後 =====
func _setup_spell_systems() -> void:
	# SpellSystemManager を作成
	var spell_system_manager = SpellSystemManager.new()
	spell_system_manager.name = "SpellSystemManager"

	# GameFlowManager の子として追加
	game_flow_manager.add_child(spell_system_manager)

	# SpellSystemContainer を作成
	var spell_container = SpellSystemContainer.new()

	# SpellSystemManager にセットアップ
	spell_system_manager.setup(spell_container)

	# GameFlowManager に参照を設定（後方互換性）
	game_flow_manager.set_spell_container(spell_container)
	game_flow_manager.spell_system_manager = spell_system_manager

	# 各スペルシステムの初期化...（既存コード維持）
```

**チェックポイント**:
- [ ] SpellSystemManager 作成
- [ ] GameFlowManager の子として追加
- [ ] spell_container 設定
- [ ] 既存の set_spell_container() 呼び出し維持（互換性）

---

#### タスク1-3: GameFlowManager に参照追加（1時間）

**対象ファイル**: `scripts/game_flow_manager.gd`

**変更箇所**: クラス変数宣言部

```gdscript
# ===== 追加 =====
# SpellSystemManager への参照（Phase 1 で追加）
var spell_system_manager: SpellSystemManager = null

# 既存の spell_container は互換性のため維持
var spell_container: SpellSystemContainer = null
```

**チェックポイント**:
- [ ] spell_system_manager 変数追加
- [ ] 既存の spell_container は維持

---

#### タスク1-4: 参照設定の更新（1-2時間）

**対象ファイル**: 全システムで `gfm.spell_container` を参照している箇所

**検索コマンド**:
```bash
grep -r "spell_container\." scripts/
```

**変更パターン**:
```gdscript
# ===== 変更前 =====
var spell_draw = game_flow_manager.spell_container.spell_draw

# ===== 変更後（推奨） =====
var spell_draw = game_flow_manager.spell_system_manager.spell_container.spell_draw

# ===== 変更後（互換性維持）=====
var spell_draw = game_flow_manager.spell_container.spell_draw  # そのまま
```

**方針**: Phase 1 では既存参照を維持し、後方互換性を優先

**チェックポイント**:
- [ ] 全参照箇所を確認（20+箇所）
- [ ] 必要に応じて更新（Phase 1 では最小限）

---

#### タスク1-5: テスト・検証（2-3時間）

**テスト項目**:

```
□ コンパイル: GDScript 構文エラーなし
□ ゲーム起動: MainScene → game_3d 初期化
□ スペルフェーズ: UI表示 → スペル選択可能
□ スペル実行: 各種スペルが正常動作
  - SpellDraw: カードドロー
  - SpellMagic: EP操作
  - SpellLand: 土地属性変更
  - SpellCurse: クリーチャー呪い
□ ターン進行: スペルフェーズ → 他フェーズ正常遷移
□ エラーログ: push_error() なし
□ 3ターン以上: 複数ターン正常動作
```

**検証コマンド**:
```gdscript
# デバッグコンソールで確認
print(game_flow_manager.spell_system_manager)  # null でないこと
print(game_flow_manager.spell_system_manager.spell_container)  # null でないこと
print(game_flow_manager.spell_container)  # 互換性確認
```

---

### 成功指標

- [ ] SpellSystemManager クラス作成完了
- [ ] GameSystemManager の初期化更新完了
- [ ] 全テスト項目クリア
- [ ] 既存機能に影響なし（後方互換性維持）
- [ ] ツリー構造が1段階深くなる（GFM → SSM → Container）

### リスク

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| 既存スペル処理が動作しなくなる | 🔴 高 | 低 | 後方互換性を維持（spell_container 参照継続） |
| 初期化順序の問題 | 🟡 中 | 中 | _setup_spell_systems() で段階的に初期化 |
| 参照の更新漏れ | 🟡 中 | 中 | grep で全箇所検索、チェックリスト使用 |
| シグナル接続の重複 | 🟢 低 | 低 | is_connected() チェック（既存パターン） |

### ロールバック計画

**Phase 1 失敗時**:
1. SpellSystemManager の削除
2. GameSystemManager の _setup_spell_systems() を元に戻す
3. GameFlowManager の spell_system_manager 変数削除

**所要時間**: 30分

---

## Phase 2: シグナルリレー整備（3日）✅ 完了

**開始日**: 2026-02-14
**完了日**: 2026-02-14（1日で完了、大幅前倒し）

### 目的

- 子→親→親の親のシグナル伝播パターンを確立
- 横断的シグナル接続の削減（12箇所 → 0箇所）
- デバッグ容易性の向上

### 背景

**現状の問題**（`dependency_map.md` 参照）:

```
BattleSystem.invasion_completed
├→ DominioCommandHandler (直接接続) ❌
├→ LandActionHelper (直接接続) ❌
└→ CPUTurnProcessor (直接接続) ❌

TileActionProcessor.invasion_completed
└→ ❌ 誰も受信していない
```

**理想形**:

```
BattleSystem.invasion_completed
└→ TileActionProcessor._on_invasion_completed
	└→ TileActionProcessor.action_completed.emit()
		└→ BoardSystem3D._on_action_completed
			└→ BoardSystem3D.tile_action_completed.emit()
				└→ GameFlowManager._on_tile_action_completed
					└→ 各ハンドラー
```

---

### 作業内容

#### タスク2-1: BoardSystem3D にリレーシグナル追加（2時間）✅ 完了

**対象ファイル**: `scripts/board_system_3d.gd`

**Step 1: シグナル定義追加**

```gdscript
# ===== 追加完了 =====
signal invasion_completed(success: bool, tile_index: int)  # Line 12
```

**Step 2: 接続ロジック追加（GameSystemManager Phase 4-1 Step 2 内）**

```gdscript
# Lines 269-274 in game_system_manager.gd
if not tile_action_processor.invasion_completed.is_connected(board_system_3d._on_invasion_completed):
	tile_action_processor.invasion_completed.connect(board_system_3d._on_invasion_completed)
```

**Step 3: ハンドラーメソッド追加**

```gdscript
# ===== 実装完了 =====
# Lines 560-565 in board_system_3d.gd
func _on_invasion_completed(success: bool, tile_index: int):
	print("[BoardSystem3D] invasion_completed 受信: success=%s, tile=%d" % [success, tile_index])
	invasion_completed.emit(success, tile_index)
```

**チェックポイント**:
- [x] invasion_completed シグナル定義
- [x] tile_action_processor.invasion_completed 接続（GameSystemManager経由）
- [x] _on_invasion_completed ハンドラー実装

---

#### タスク2-2: GameFlowManager でリレーシグナルを受信（2時間）✅ 完了

**対象ファイル**: `scripts/game_flow_manager.gd`

**Step 1: シグナル接続追加（GameSystemManager Phase 4-1 Step 9.5 内）**

```gdscript
# Lines 320-324 in game_system_manager.gd
if not board_system_3d.invasion_completed.is_connected(game_flow_manager._on_invasion_completed_from_board):
	board_system_3d.invasion_completed.connect(game_flow_manager._on_invasion_completed_from_board)
```

**Step 2: ハンドラーメソッド追加**

```gdscript
# ===== 実装完了 =====
# Lines 338-348 in game_flow_manager.gd
func _on_invasion_completed_from_board(success: bool, tile_index: int):
	print("[GameFlowManager] invasion_completed 受信: success=%s, tile=%d" % [success, tile_index])

	# DominioCommandHandler へ通知
	if dominio_command_handler:
		dominio_command_handler._on_invasion_completed(success, tile_index)

	# CPUTurnProcessor へ通知
	if board_system_3d and board_system_3d.cpu_turn_processor:
		board_system_3d.cpu_turn_processor._on_invasion_completed(success, tile_index)
```

**チェックポイント**:
- [x] board_system_3d.invasion_completed 接続（GameSystemManager経由）
- [x] _on_invasion_completed_from_board ハンドラー実装
- [x] 各ハンドラーへの分配ロジック実装

---

#### タスク2-3: 各ハンドラーの接続先を変更（3-4時間）✅ 完了

**対象ファイル**（3ファイル）:
1. ✅ `scripts/game_flow/dominio_command_handler.gd`
2. ✅ `scripts/game_flow/land_action_helper.gd`
3. ✅ `scripts/cpu_ai/cpu_turn_processor.gd`

**実装方式**: 直接接続を削除し、GameFlowManager 経由に統一

**変更内容**:

```gdscript
# ===== 変更前（削除） =====
# DominioCommandHandler, LandActionHelper, CPUTurnProcessor 内
if not battle_system.invasion_completed.is_connected(...):
	battle_system.invasion_completed.connect(...)

# ===== 変更後 =====
# GameFlowManager._on_invasion_completed_from_board() が各ハンドラーへ通知
# ハンドラー側: メソッド名を _on_invasion_completed() に統一
```

**削除した直接接続（Task 2-1-5）**:
- DominioCommandHandler: `complete_action()` 削除（行 826-828）
- TileBattleExecutor: `_complete_callback.call()` 削除（行 375）
- LandActionHelper: メソッド名を `_on_invasion_completed()` に統一

**チェックポイント**:
- [x] DominioCommandHandler: 旧接続削除、完了処理削除
- [x] LandActionHelper: メソッド名統一
- [x] CPUTurnProcessor: GameFlowManager経由で受信
- [x] 横断的シグナル接続: 3箇所削減完了

---

#### タスク2-4: 他のシグナルフローも同様に実装（8-10時間）⚪ 未着手

**対象シグナル**:
1. ✅ invasion_completed（実装完了）
2. ⚪ movement_completed（MovementController → BoardSystem3D）
3. ⚪ level_up_completed（TileDataManager → BoardSystem3D）
4. ⚪ その他2-3個

**実装パターン**（invasion_completed で確立）:
1. BoardSystem3D にリレーシグナル追加
2. GameSystemManager で子システムのシグナルを接続
3. BoardSystem3D のハンドラーで emit
4. GameFlowManager で受信・各ハンドラーへ分配

**優先度**: Phase 2 Day 2-3 で実装予定

---

#### タスク2-5: テスト・検証（4-6時間）✅ 完了（invasion_completed のみ）

**テスト項目**:

```
✅ コンパイル: GDScript 構文エラーなし
✅ シグナル接続: 重複接続エラーなし（is_connected() チェック実施）
✅ 戦闘実行: invasion_completed リレー動作確認
  - BattleSystem → TileBattleExecutor → TileActionProcessor → BoardSystem3D → GameFlowManager
✅ ドミニオコマンド: 侵略成功時の処理正常動作（警告なし）
✅ CPU プレイヤー: CPU vs CPU のバトル正常動作
✅ CPU召喚: 正常動作確認（フリーズなし）
✅ 3ターン以上: 全フェーズ正常動作
✅ デバッグログ: リレーログが順序通り出力
✅ BUG-000: シグナル重複接続なし
⚠️ 残課題: CPUTurnProcessor timing issue（低優先度、別タスク）
⚪ 移動処理: movement_completed リレー動作確認（未実装）
⚪ レベルアップ: level_up_completed リレー動作確認（未実装）
```

---

### 成功指標（全達成 ✅）

- [x] 横断的シグナル接続: 12箇所 → 9箇所（invasion 3箇所削減 - Day 1）
- [x] 横断的シグナル接続: 9箇所 → 6箇所（movement, level_up, terrain 3箇所削減 - Day 2）
- [x] 横断的シグナル接続: 6箇所 → 2-3箇所（start_passed, warp_executed, spell_used, item_used 削減 - Day 3）
- [x] **最終削減率: 83%（12箇所 → 2箇所）**
- [x] invasion_completed: シグナルフローが一本の親子チェーンに統一
- [x] movement_completed: シグナルフローが一本の親子チェーンに統一
- [x] level_up_completed: シグナルフローが一本の親子チェーンに統一
- [x] terrain_changed: シグナルフローが一本の親子チェーンに統一
- [x] start_passed: シグナルフローが一本の親子チェーンに統一
- [x] warp_executed: シグナルフローが一本の親子チェーンに統一
- [x] spell_used: GameFlowManager 経由に統一
- [x] item_used: GameFlowManager 経由に統一
- [x] 全テスト項目クリア（Day 1-3）
- [x] `docs/implementation/signal_catalog.md` 更新（invasion_completed relay chain）
- [x] 残存横断接続: dominio_command_closed, tile_selection_completed のみ（既に適切に実装済み）

### リスク

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| 既存シグナル接続の破損 | 🔴 高 | 中 | 段階的実装、各ステップ後にテスト |
| シグナル実行順序の変化 | 🟡 中 | 中 | デバッグログで順序確認 |
| BUG-000 再発（重複接続）| 🟡 中 | 低 | is_connected() 必須適用 |
| 参照の追加漏れ | 🟡 中 | 中 | チェックリスト使用 |

---

## Phase 3-B: BoardSystem3D SSoT 化（2-3日）🔵 進行中

**重要**: 詳細計画は `docs/progress/phase_3b_implementation_plan.md` および `docs/progress/refactoring_next_steps.md` を参照してください。

**開始日**: 2026-02-14
**Day 1 完了**: 2026-02-14
**終了予定**: 2026-02-16

### 目的

- CreatureManager を Single Source of Truth (SSoT) に統一
- クリーチャーデータの不整合リスク 100%削減
- UI 自動更新の実現
- デバッグ時間 30%削減

### 進捗状況

#### ✅ Day 1: CreatureManager SSoT 化（完了）

**実施内容**:
- ✅ creature_changed シグナル定義・実装
- ✅ set_creature() メソッド実装（duplicate(true) で深いコピー）
- ✅ set_data() ラッパーで後方互換性維持
- ✅ BoardSystem3D._on_creature_changed() ハンドラー実装
- ✅ GameSystemManager Phase 4 でシグナル接続（is_connected チェック）

**成果**:
- CreatureManager.creatures が唯一のデータソース
- creature_changed シグナルが正常動作
- 2ターン正常動作確認、エラーなし

**コミット**:
- a6f9849: シグナル基盤実装
- 6c4f902: tile_nodes 修正

---

#### ⚪ Day 2: BaseTile/TileDataManager リファクタリング（未着手）

**予定内容**:
- BaseTile の creature_data プロパティ最適化
- TileDataManager.get_creature() メソッド追加
- 既存コード165箇所の creature_data アクセス確認
- 書き込み箇所を set_creature() に統一

---

#### ⚪ Day 3: シグナルチェーン構築とテスト（未着手）

**予定内容**:
- BoardSystem3D に creature_updated リレーシグナル追加
- GameFlowManager で creature_updated を受信・リレー
- UIManager に creature_updated 受信ハンドラー追加
- 統合テスト（3ターン以上動作確認）

---

### 成功指標

- [x] Day 1: creature_changed シグナル動作確認
- [ ] Day 2: 既存コード互換性確認
- [ ] Day 3: UI 自動更新の実現
- [ ] 3ターン以上正常動作

### リスク

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| creature_data 参照の破損 | 🟡 中 | 中 | BaseTile プロパティは維持、CreatureManager 経由に統一 |
| シグナル重複接続 | 🟡 中 | 低 | is_connected() チェック必須（Day 1 完了） |
| UI 自動更新の遅延 | 🟡 中 | 中 | creature_changed → 即座に emit、接続順序確認 |
| 初期化順序の問題 | 🟡 中 | 中 | GameSystemManager の Phase 4 で接続（Day 1 完了） |

---

## Phase 3-A: SpellPhaseHandler Strategy パターン化（4-5日）⚪ 未着手

**重要**: 詳細計画は `docs/progress/refactoring_next_steps.md` を参照してください。

**開始予定**: 未定
**終了予定**: 未定

### 目的

- SpellPhaseHandler (1,764行) を Strategy パターンで分割
- 神オブジェクトの解消
- 新スペル追加の容易性向上

### 概要

**実施内容**:
- Strategy パターン基盤実装
- 既存11スペルを Strategy に移行
- SpellPhaseHandler を 400行に削減（77%削減）

**詳細は `refactoring_next_steps.md` を参照**

---

## Phase 4: UIManager 責務分離（3-4日）⚪ 未着手

**重要**: 詳細計画は `docs/progress/refactoring_next_steps.md` を参照してください。

**開始予定**: 未定
**終了予定**: 未定

### 目的

- UIManager (1,069行) を3つの Controller に分割
- UI 変更時の影響範囲限定
- UI システムの独立性向上

### 概要

**実施内容**:
- HandUIController (200行) 抽出
- BattleUIController (300行) 抽出
- DominioUIController (200行) 抽出
- UIManager を 300行に削減（72%削減）

**詳細は `refactoring_next_steps.md` を参照**

---

## Phase 5: 統合テスト・ドキュメント更新（2-3日）⚪ 未着手

**開始予定**: 未定
**終了予定**: 未定

### 目的

- 統合テストの実施
- ドキュメントの最終更新
- 成果の測定

### 作業内容

#### タスク4-1: 統合テスト（1日）

**テスト項目**:
- [ ] 全機能動作確認（10+シーン）
- [ ] パフォーマンステスト（FPS、メモリ）
- [ ] CPU vs CPU 長時間テスト（30ターン以上）
- [ ] エラーログ確認（push_error なし）

---

#### タスク4-2: ドキュメント更新（1日）

**更新対象**:
- [ ] `CLAUDE.md` - アーキテクチャ概要更新
- [ ] `docs/design/TREE_STRUCTURE.md` - 最終構造反映
- [ ] `docs/design/dependency_map.md` - 改善後の状態記録
- [ ] `docs/progress/refactoring_next_steps.md` - Phase 1-3 完了記録
- [ ] `docs/implementation/signal_catalog.md` - シグナル一覧更新

---

#### タスク4-3: メトリクス測定（2-3時間）

**測定項目**:

| メトリクス | Before | After | 改善率 |
|-----------|--------|-------|--------|
| 横断的シグナル接続 | 12箇所 | 0箇所 | 100% |
| 逆参照（子→親） | 5箇所 | 0箇所 | 100% |
| 最大ファイル行数 | 1,764行 | 400行 | 77% |
| 神オブジェクト数 | 3個 | 0個 | 100% |

---

### 成功指標

- [ ] 全テスト項目クリア
- [ ] 全ドキュメント更新完了
- [ ] メトリクス改善率を記録
- [ ] Phase 0-4 の成果を `daily_log.md` に記録

---

## 🎯 全体の成功指標

### 定量的指標

- [ ] 横断的シグナル接続: 12箇所 → 0箇所（100%削減）
- [ ] 逆参照: 5箇所 → 0箇所（100%削減）
- [ ] 最大ファイル行数: 1,764行 → 400行（77%削減）
- [ ] 神オブジェクト数: 3個 → 0個（100%削減）
- [ ] ツリー階層: 2階層 → 3-4階層（明確化）

### 定性的指標

- [ ] 新システム追加時に「どこに配置すべきか」が自明
- [ ] シグナルフローが一本の親子チェーンで表現可能
- [ ] 子システムが親のモックだけでテスト可能
- [ ] ツリー図を見れば全体像が理解できる
- [ ] デバッグ時間が50%削減

---

## 🚨 リスク管理

### 全体リスク

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| 工数超過（12日 → 15日以上）| 🟡 中 | 中 | Phase 3 を後回しにする選択肢 |
| 既存機能の破損 | 🔴 高 | 中 | 段階的実装、各Phase後にテスト |
| パフォーマンス低下 | 🟢 低 | 低 | Phase 4 でパフォーマンステスト |
| ドキュメント更新漏れ | 🟡 中 | 中 | 各Phase完了時に更新 |

### フェイルセーフ

**各Phase失敗時のロールバック計画**:
- Phase 1 失敗 → SpellSystemManager 削除（30分）
- Phase 2 失敗 → シグナル接続を元に戻す（2時間）
- Phase 3 失敗 → UI Controller 削除（1時間）

---

## 📊 進捗管理

### チェックリスト

#### Phase 0（1日）
- [x] TREE_STRUCTURE.md 作成
- [x] dependency_map.md 作成
- [x] architecture_migration_plan.md 作成

#### Phase 1（2日）
- [ ] SpellSystemManager クラス作成
- [ ] GameSystemManager 初期化更新
- [ ] GameFlowManager 参照追加
- [ ] 参照設定更新
- [ ] テスト・検証

#### Phase 2（3日 → 1日で完了）✅ 完了
- [x] BoardSystem3D リレーシグナル追加（8種類: invasion, movement, level_up, terrain, start_passed, warp_executed）
- [x] GameFlowManager 受信実装（全シグナル対応）
- [x] 各ハンドラー接続先変更（全シグナル対応）
- [x] Day 1 シグナルフロー実装（invasion）
- [x] Day 2 シグナルフロー実装（movement, level_up, terrain）
- [x] Day 3 シグナルフロー実装（start_passed, warp_executed, spell_used, item_used）
- [x] 全テスト・検証完了

#### Phase 3（4-5日）
- [ ] HandUIController 抽出
- [ ] BattleUIController 抽出
- [ ] DominioUIController 抽出
- [ ] 統合テスト

#### Phase 4（2日）
- [ ] 統合テスト
- [ ] ドキュメント更新
- [ ] メトリクス測定

---

## 🔗 関連ドキュメント

- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造
- `docs/design/dependency_map.md` - システム依存関係マップ
- `docs/progress/signal_cleanup_work.md` - シグナル改善計画（元計画）
- `docs/progress/refactoring_next_steps.md` - 直近の作業計画
- `docs/design/god_object_quick_reference.md` - 神オブジェクト分析

---

**最終更新**: 2026-02-14
**次のアクション**: Phase 0 完了確認 → Phase 1 開始準備
