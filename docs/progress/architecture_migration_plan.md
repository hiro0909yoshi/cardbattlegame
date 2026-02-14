# アーキテクチャ移行計画

**最終更新**: 2026-02-14
**目的**: 理想的なツリー構造への段階的移行を計画し、リスクを最小化しながら実装する

---

## 📋 全体スケジュール

```
Phase 0: ツリー構造定義 ─────────── 1日 [進行中]
Phase 1: SpellSystemManager 導入 ─── 2日 [未着手]
Phase 2: シグナルリレー整備 ────── 3日 [未着手]
Phase 3: UIManager 責務分離 ──── 4-5日 [未着手]
Phase 4: テスト・ドキュメント ──── 2日 [未着手]

合計: 12-13日
```

---

## Phase 0: ツリー構造定義（1日）🔵 進行中

**開始日**: 2026-02-14
**終了予定**: 2026-02-14

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

## Phase 1: SpellSystemManager 導入（2日）⚪ 未着手

**開始予定**: 2026-02-15
**終了予定**: 2026-02-17

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

## Phase 2: シグナルリレー整備（3日）⚪ 未着手

**開始予定**: 2026-02-18
**終了予定**: 2026-02-21

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

#### タスク2-1: BoardSystem3D にリレーシグナル追加（2時間）

**対象ファイル**: `scripts/board_system_3d.gd`

**Step 1: シグナル定義追加**

```gdscript
# ===== 追加 =====
signal invasion_completed(success: bool, tile_index: int)
```

**Step 2: 接続ロジック追加（create_subsystems 内）**

```gdscript
func create_subsystems():
	# ... 既存コード ...

	# 既存のシグナル接続
	if not tile_action_processor.action_completed.is_connected(_on_action_completed):
		tile_action_processor.action_completed.connect(_on_action_completed)

	# ===== 新規追加 =====
	if not tile_action_processor.invasion_completed.is_connected(_on_tile_invasion_completed):
		tile_action_processor.invasion_completed.connect(_on_tile_invasion_completed)
```

**Step 3: ハンドラーメソッド追加**

```gdscript
# ===== 新規追加 =====
func _on_tile_invasion_completed(success: bool, tile_index: int):
	# デバッグログ
	print("[BoardSystem3D] invasion_completed リレー: success=%s, tile=%d" % [success, tile_index])

	# 親へリレー
	invasion_completed.emit(success, tile_index)
```

**チェックポイント**:
- [ ] invasion_completed シグナル定義
- [ ] tile_action_processor.invasion_completed 接続
- [ ] _on_tile_invasion_completed ハンドラー実装

---

#### タスク2-2: GameFlowManager でリレーシグナルを受信（2時間）

**対象ファイル**: `scripts/game_flow_manager.gd`

**Step 1: シグナル接続追加（_ready または setup 内）**

```gdscript
func _ready():
	# ... 既存コード ...

	# ===== 新規追加 =====
	if board_system_3d:
		if not board_system_3d.invasion_completed.is_connected(_on_board_invasion_completed):
			board_system_3d.invasion_completed.connect(_on_board_invasion_completed)
```

**Step 2: ハンドラーメソッド追加**

```gdscript
# ===== 新規追加 =====
func _on_board_invasion_completed(success: bool, tile_index: int):
	print("[GameFlowManager] invasion_completed 受信: success=%s, tile=%d" % [success, tile_index])

	# 必要に応じて処理を実行
	# （現状では各ハンドラーが BattleSystem から直接受信しているため、ここでは何もしない）
```

**チェックポイント**:
- [ ] board_system_3d.invasion_completed 接続
- [ ] _on_board_invasion_completed ハンドラー実装

---

#### タスク2-3: 各ハンドラーの接続先を変更（3-4時間）

**対象ファイル**（3ファイル）:
1. `scripts/game_flow/dominio_command_handler.gd`
2. `scripts/game_flow/land_action_helper.gd`
3. `scripts/cpu_ai/cpu_turn_processor.gd`

**変更パターン**:

```gdscript
# ===== 変更前 =====
battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)

# ===== 変更後 =====
# board_system への参照が必要
var board_system = game_flow_manager.board_system_3d  # または注入
board_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
```

**注意**: 各ハンドラーが board_system への参照を持つ必要がある

**チェックポイント**:
- [ ] DominioCommandHandler: 接続先変更
- [ ] LandActionHelper: 接続先変更
- [ ] CPUTurnProcessor: 接続先変更
- [ ] 各ハンドラーに board_system 参照追加

---

#### タスク2-4: 他のシグナルフローも同様に実装（8-10時間）

**対象シグナル**:
1. ✅ invasion_completed（上記で実装）
2. movement_completed（MovementController → BoardSystem3D）
3. level_up_completed（TileDataManager → BoardSystem3D）
4. その他2-3個

**各シグナルで同じパターンを適用**:
1. BoardSystem3D にリレーシグナル追加
2. 子システムのシグナルを接続
3. ハンドラーで emit
4. GameFlowManager で受信（必要に応じて）

---

#### タスク2-5: テスト・検証（4-6時間）

**テスト項目**:

```
□ コンパイル: GDScript 構文エラーなし
□ シグナル接続: 重複接続エラーなし
□ 戦闘実行: invasion_completed リレー動作確認
  - BattleSystem → TileActionProcessor → BoardSystem3D → GameFlowManager
□ 移動処理: movement_completed リレー動作確認
□ レベルアップ: level_up_completed リレー動作確認
□ ドミニオコマンド: 侵略成功時の処理正常動作
□ CPU プレイヤー: CPU vs CPU のバトル正常動作
□ 3ターン以上: 全フェーズ正常動作
□ デバッグログ: リレーログが順序通り出力
□ BUG-000: シグナル重複接続なし
```

---

### 成功指標

- [ ] 横断的シグナル接続: 12箇所 → 0箇所
- [ ] シグナルフローが一本の親子チェーンに統一
- [ ] 全テスト項目クリア
- [ ] `docs/implementation/signal_catalog.md` 更新完了

### リスク

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| 既存シグナル接続の破損 | 🔴 高 | 中 | 段階的実装、各ステップ後にテスト |
| シグナル実行順序の変化 | 🟡 中 | 中 | デバッグログで順序確認 |
| BUG-000 再発（重複接続）| 🟡 中 | 低 | is_connected() 必須適用 |
| 参照の追加漏れ | 🟡 中 | 中 | チェックリスト使用 |

---

## Phase 3: UIManager 責務分離（4-5日）⚪ 未着手

**開始予定**: 2026-02-22
**終了予定**: 2026-02-27

### 目的

- UIManager を300-400行に削減
- 各UI領域が独立して動作
- UI変更時の影響範囲限定

### 背景

**現状の問題**:
- UIManager: 1,069行、93メソッド
- 全UI要素が1ファイルに集約
- 新UI追加時に UIManager を修正必須

**理想形**:
```
UIManager (300行)
├── HandUIController (200行)
├── BattleUIController (300行)
└── DominioUIController (200行)
```

---

### 作業内容（概要）

#### タスク3-1: HandUIController 抽出（1-1.5日）
#### タスク3-2: BattleUIController 抽出（1-1.5日）
#### タスク3-3: DominioUIController 抽出（1-1.5日）
#### タスク3-4: 統合テスト（1日）

**詳細は Phase 2 完了後に策定**

---

### 成功指標

- [ ] UIManager: 1,069行 → 300行（72%削減）
- [ ] UI Controller 3個作成完了
- [ ] 全UI機能正常動作
- [ ] 新UI追加時に UIManager 修正不要

### リスク

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| UI表示の破損 | 🔴 高 | 高 | 段階的実装、各UI領域ごとにテスト |
| 参照の更新漏れ | 🔴 高 | 中 | 全参照箇所を grep で検索 |
| UI状態管理の複雑化 | 🟡 中 | 中 | Controller間の通信を UIManager 経由に限定 |

---

## Phase 4: テスト・ドキュメント（2日）⚪ 未着手

**開始予定**: 2026-02-28
**終了予定**: 2026-03-02

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

#### Phase 2（3日）
- [ ] BoardSystem3D リレーシグナル追加
- [ ] GameFlowManager 受信実装
- [ ] 各ハンドラー接続先変更
- [ ] 他のシグナルフローも実装
- [ ] テスト・検証

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
