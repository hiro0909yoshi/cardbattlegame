# Phase 3-B Implementation Plan - BoardSystem3D SSoT 化

**作成日**: 2026-02-14
**優先度**: P0（最優先）
**実装時間**: 2-3日
**目的**: クリーチャーデータの Single Source of Truth (SSoT) 化によるデータ整合性向上

---

## 📊 現状分析

### クリーチャーデータの現状

現在、クリーチャーデータは以下の場所に分散して管理されています:

1. **BaseTile.creature_data** (参照方式)
   - `creature_data` プロパティ: CreatureManager から参照を取得
   - setter で3D表示を自動同期
   - 165箇所で直接アクセス

2. **CreatureManager** (部分的にSSoT)
   - `creatures: Dictionary = {}` に tile_index → creature_data をマッピング
   - `get_data_ref()`: 参照を返す
   - `set_data()`: 重複コピーで安全性を確保

3. **TileDataManager** (参照層)
   - `get_tile_info()` で creature フィールドを返す
   - タイル情報統計処理（土地価値計算等）で creature データを参照

4. **TileBattleExecutor, TileSummonExecutor**
   - `tile.creature_data` を直接読み取り・書き込み
   - データの不整合リスク

### 問題点

- **データ変更時に通知メカニズムがない** → UI自動更新困難
- TileDataManager での creature アクセスがやや冗長
- BattleSystem と UI の同期が手動で行われている
- creature_data 変更が UI に自動反映されない

### 現在のデータフロー

```
CreatureManager.creatures[tile_index]
	↓ (参照)
BaseTile.creature_data getter/setter
	↓
TileBattleExecutor / TileSummonExecutor (読み取り・書き込み)
	↓
TileDataManager.get_tile_info() (参照のみ)
	↓
UIManager (手動更新)
```

---

## 🎯 理想形設計（SSoT パターン）

### 目標

- CreatureManager を唯一のデータソース（SSOT）に統一
- データ変更を自動的に他のシステムに通知
- UI の自動更新を実現

### 理想的なデータフロー

```
CreatureManager (SSOT)
├─ creatures[tile_index]: creature_data
└─ creature_changed シグナル
	↓
BoardSystem3D (リレー層)
└─ creature_updated シグナル
	↓
GameFlowManager (リレー層)
└─ creature_updated シグナル
	↓
UIManager (表示層)
└─ 自動更新
```

### 実装パターン

```gdscript
# CreatureManager (SSOT)
signal creature_changed(tile_index: int, old_data: Dictionary, new_data: Dictionary)

func set_creature(tile_index: int, data: Dictionary):
	var old_data = creatures.get(tile_index, {})
	if data.is_empty():
		creatures.erase(tile_index)
	else:
		creatures[tile_index] = data.duplicate(true)
	creature_changed.emit(tile_index, old_data, data)

# BaseTile (参照層)
var creature_data:
	get:
		return creature_manager.get_data_ref(tile_index)
	set(value):
		creature_manager.set_creature(tile_index, value)

# TileDataManager (参照層)
func get_creature(tile_index: int) -> Dictionary:
	return creature_manager.get_data_ref(tile_index)

# TileBattleExecutor (読み取り層)
var creature = creature_manager.get_data_ref(tile_index)
```

---

## 📅 タスク分解（3日間）

### Day 1: CreatureManager SSoT 化（8-10時間）

#### Task 3-B-1: CreatureManager に creature_changed シグナルを追加 (1-2時間)

**ファイル**: `scripts/creature_manager.gd`

**変更内容**:
```gdscript
# Line 1 の後に追加
signal creature_changed(tile_index: int, old_data: Dictionary, new_data: Dictionary)
```

---

#### Task 3-B-2: set_data() を set_creature() に改名して拡張 (2-3時間)

**ファイル**: `scripts/creature_manager.gd`

**変更内容**:
- 既存の `set_data()` を `set_creature()` に改名
- シグナル emit ロジック追加
- 古いデータと新しいデータを記録して emit
- `set_data()` は後方互換性のためラッパーとして実装

```gdscript
func set_creature(tile_index: int, data: Dictionary):
	var old_data = creatures.get(tile_index, {})
	if data.is_empty():
		creatures.erase(tile_index)
	else:
		creatures[tile_index] = data.duplicate(true)
	print("[CreatureManager] creature_changed: tile=%d" % tile_index)
	creature_changed.emit(tile_index, old_data, data)

# 後方互換性
func set_data(tile_index: int, data: Dictionary):
	set_creature(tile_index, data)
```

---

#### Task 3-B-3: creature_manager の初期化時に creature_changed を接続 (2-3時間)

**ファイル**: `scripts/system_manager/game_system_manager.gd`

**変更内容**:
- Phase 4 で BoardSystem3D に creature_changed を接続（is_connected チェック必須）
- BoardSystem3D._on_creature_changed() ハンドラー実装
- Board から GameFlowManager へのリレー設定

```gdscript
# GameSystemManager.setup_systems() Phase 4 に追加
if board_system_3d and board_system_3d.creature_manager:
	var creature_manager = board_system_3d.creature_manager
	if not creature_manager.creature_changed.is_connected(board_system_3d._on_creature_changed):
		creature_manager.creature_changed.connect(board_system_3d._on_creature_changed)
```

---

#### Day 1 チェックポイント

- [ ] creature_changed シグナル定義完了
- [ ] set_creature() メソッド実装完了
- [ ] シグナル接続設定完了（is_connected チェック）
- [ ] 後方互換性確保（set_data() ラッパー動作）

---

### Day 2: BaseTile/TileDataManager リファクタリング（8-10時間）

#### Task 3-B-4: BaseTile の creature_data プロパティを最適化 (2-3時間)

**ファイル**: `scripts/tiles/base_tiles.gd`

**変更内容**:
- 既存の creature_data プロパティは維持（後方互換性）
- setter で creature_manager.set_creature() を呼び出し
- 3D表示の同期は creature_changed シグナル経由に移行（後続タスク）

```gdscript
var creature_data:
	get:
		if creature_manager:
			return creature_manager.get_data_ref(tile_index)
		return {}
	set(value):
		if creature_manager:
			creature_manager.set_creature(tile_index, value)
```

---

#### Task 3-B-5: TileDataManager に get_creature() メソッドを追加 (2-3時間)

**ファイル**: `scripts/tile_data_manager.gd`

**変更内容**:
```gdscript
# Line 400 付近に追加
func get_creature(tile_index: int) -> Dictionary:
	# CreatureManager から直接参照を取得
	if board_system and board_system.creature_manager:
		return board_system.creature_manager.get_data_ref(tile_index)
	return {}
```

- get_tile_info() では tile.creature_data の代わりに get_creature(tile_index) を使用（オプション）

---

#### Task 3-B-6: 既存コード互換性確認と最小限の修正 (2-3時間)

**ファイル**: 複数（grep で特定）

**確認事項**:
- 165箇所の `tile.creature_data` アクセスを確認
  - **読み取り専用**: そのまま（参照のため動作継続）
  - **書き込み**: `creature_manager.set_creature()` に統一
- **優先度**: TileBattleExecutor, TileSummonExecutor のみ対応

**検索コマンド**:
```bash
grep -rn "creature_data" scripts/ | grep -E "\\.creature_data\s*="
```

---

#### Day 2 チェックポイント

- [ ] BaseTile プロパティ最適化完了
- [ ] TileDataManager.get_creature() 実装完了
- [ ] 読み取り箇所の確認完了
- [ ] 書き込み箇所の修正完了（優先順位順）

---

### Day 3: シグナルチェーン構築とテスト（10-12時間）

#### Task 3-B-7: BoardSystem3D に creature_updated リレーシグナルを追加 (2-3時間)

**ファイル**: `scripts/board_system_3d.gd`

**変更内容**:
```gdscript
# Line 15 付近に追加
signal creature_updated(tile_index: int, creature_data: Dictionary)

# Line 560 付近にハンドラー追加（Day 1 で実装済みのハンドラーを拡張）
func _on_creature_changed(tile_index: int, old_data: Dictionary, new_data: Dictionary):
	# tile_index 妥当性チェック（Day 1 で実装済み）
	if not tile_nodes.has(tile_index):
		push_error("[BoardSystem3D] Invalid tile_index: %d" % tile_index)
		return

	# 状態判定（Day 1 で実装済み）
	if old_data.is_empty() and not new_data.is_empty():
		print("[BoardSystem3D] creature_changed: 新規配置 tile=%d" % tile_index)
	elif not old_data.is_empty() and new_data.is_empty():
		print("[BoardSystem3D] creature_changed: クリーチャー削除 tile=%d" % tile_index)
	elif not old_data.is_empty() and not new_data.is_empty():
		print("[BoardSystem3D] creature_changed: クリーチャー更新 tile=%d" % tile_index)

	# Day 3 追加: creature_updated シグナルをリレー
	creature_updated.emit(tile_index, new_data)

# 委譲メソッド追加（チェーンアクセス禁止対応）
func get_tile_info(tile_index: int) -> Dictionary:
	if tile_data_manager:
		return tile_data_manager.get_tile_info(tile_index)
	return {}
```

---

#### Task 3-B-8: GameFlowManager で creature_updated を受信・リレー (2-3時間)

**ファイル**: `scripts/game_flow_manager.gd`

**変更内容**:
```gdscript
# シグナル定義追加
signal creature_updated_relay(tile_index: int, creature_data: Dictionary)

# ハンドラー追加（シグナルリレーのみ、直接呼び出しは禁止）
func _on_creature_updated_from_board(tile_index: int, creature_data: Dictionary):
	print("[GameFlowManager] creature_updated 受信: tile=%d" % tile_index)

	# シグナルリレー（UIManager はこのシグナルを受信）
	creature_updated_relay.emit(tile_index, creature_data)
```

**重要**: GameFlowManager から UIManager のメソッドを直接呼び出すのではなく、シグナル経由で通知します（Phase 2 パターンに準拠）

---

#### Task 3-B-8.5: GameSystemManager でシグナル接続設定 (30分-1時間)

**ファイル**: `scripts/system_manager/game_system_manager.gd`

**変更内容**:
```gdscript
# Phase 4-Creature セクションに追加（Day 1 で作成済み）
func _setup_phase_4_creature_signals() -> void:
	print("[GameSystemManager] creature シグナル接続開始")

	# Day 1: CreatureManager → BoardSystem3D
	if board_system_3d and board_system_3d.creature_manager:
		var creature_manager = board_system_3d.creature_manager
		if not creature_manager.creature_changed.is_connected(board_system_3d._on_creature_changed):
			creature_manager.creature_changed.connect(board_system_3d._on_creature_changed)
			print("[GameSystemManager] creature_changed 接続完了")

	# Day 3 追加: BoardSystem3D → GameFlowManager
	if not board_system_3d.creature_updated.is_connected(game_flow_manager._on_creature_updated_from_board):
		board_system_3d.creature_updated.connect(game_flow_manager._on_creature_updated_from_board)
		print("[GameSystemManager] creature_updated → GFM 接続完了")

	# Day 3 追加: GameFlowManager → UIManager
	if not game_flow_manager.creature_updated_relay.is_connected(ui_manager.on_creature_updated):
		game_flow_manager.creature_updated_relay.connect(ui_manager.on_creature_updated)
		print("[GameSystemManager] creature_updated_relay → UI 接続完了")
```

**重要**: is_connected() チェック必須（BUG-000 再発防止）

---

#### Task 3-B-9: UIManager に creature_updated 受信ハンドラーを追加 (2-3時間)

**ファイル**: `scripts/ui_manager.gd`

**変更内容**:
```gdscript
# public メソッド（シグナルハンドラーなので _ プレフィックスなし）
func on_creature_updated(tile_index: int, creature_data: Dictionary):
	print("[UIManager] creature_updated 受信: tile=%d" % tile_index)

	# null チェック
	if not board_system_3d:
		push_error("[UIManager] board_system_3d が null")
		return

	# UI の creature 関連要素を自動更新
	if creature_info_panel_ui and not creature_data.is_empty():
		creature_info_panel_ui.update_display(creature_data)

	# 3D表示更新（tile_info_display）
	if tile_info_display:
		# 委譲メソッド使用（2段チェーンアクセス禁止）
		var tile_info = board_system_3d.get_tile_info(tile_index)
		if not tile_info.is_empty():
			tile_info_display.update_display(tile_index, tile_info)
```

**重要**:
- メソッド名は `on_creature_updated`（`_` プレフィックスなし）
- `board_system_3d.get_tile_info()` 委譲メソッド使用（2段チェーン禁止）
- null チェック追加

---

#### Task 3-B-10: 統合テストと検証 (4-6時間)

**テスト項目**:

```
Day 3 テストチェックポイント:
□ コンパイル: GDScript 構文エラーなし
□ シグナル接続: 重複接続エラーなし（is_connected() チェック）
□ CreatureManager の動作
  - creature_changed シグナルが正しく emit される
  - get_data_ref() が参照を返す
□ CreatureManager SSoT 化
  - creatures Dictionary が唯一のデータソース
  - set_creature() で変更時にシグナル emit
□ シグナルリレーチェーン
  - CreatureManager → BoardSystem3D → GameFlowManager
  - 各層で正しくリレーされるか確認
□ UI 自動更新
  - creature 配置時に creature_info_panel_ui が自動更新
  - creature 削除時に UI が自動更新
□ 3ターン以上の正常動作
  - 全フェーズが正常に進行
  - creature データが整合
□ デバッグログ
  - [CreatureManager] creature_changed ログ出力
  - [BoardSystem3D] creature_updated ログ出力
  - [GameFlowManager] creature_updated リレーログ出力
□ 互換性確認
  - tile.creature_data アクセスが従来通り動作
  - get_data_ref() が参照を返す（値の変更が反映される）
```

---

#### Day 3 チェックポイント

- [ ] BoardSystem3D.creature_updated シグナル定義完了
- [ ] BoardSystem3D.get_tile_info() 委譲メソッド追加完了
- [ ] GameFlowManager.creature_updated_relay シグナル定義完了
- [ ] UIManager.on_creature_updated() ハンドラー実装完了
- [ ] GameSystemManager でシグナル接続完了（is_connected() チェック）
- [ ] コーディング規約準拠:
  - [x] is_connected() チェック実装
  - [x] 2段チェーンアクセス解消（委譲メソッド使用）
  - [x] シグナル接続パターン準拠（直接呼び出しなし）
  - [x] null チェック実装
- [ ] creature_changed シグナルチェーン全体が動作
- [ ] UI が自動更新（creature 配置・削除時）
- [ ] 3ターン以上の正常動作確認
- [ ] デバッグログ出力確認

---

## ⚠️ リスク分析

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| creature_data 参照の破損 | 🔴 高 | 中 | BaseTile プロパティは維持、CreatureManager 経由に統一 |
| シグナル重複接続 | 🟡 中 | 低 | is_connected() チェック必須（既存パターン） |
| UI 自動更新の遅延 | 🟡 中 | 中 | creature_changed → 即座に emit、接続順序確認 |
| 数値計算への影響 | 🟡 中 | 低 | TileDataManager の計算ロジックは参照のみ（変更なし） |
| 初期化順序の問題 | 🟡 中 | 中 | GameSystemManager の Phase 4 で接続（creature_manager 作成後） |

### ロールバック計画 (所要時間: 1時間)

1. creature_changed シグナル削除
2. set_creature() → set_data() に戻す
3. BoardSystem3D, GameFlowManager の creature_updated シグナル・ハンドラー削除
4. UIManager の自動更新ハンドラー削除

---

## ✅ テストチェックポイント

### Day 1 終了時
- [ ] CreatureManager.creature_changed シグナルが emit される
- [ ] set_creature() が正しく動作
- [ ] 既存の get_data_ref() が参照を返す

### Day 2 終了時
- [ ] BaseTile.creature_data プロパティが参照を返す
- [ ] TileDataManager.get_creature() が実装完了
- [ ] 既存コードとの互換性確認（読み取り）

### Day 3 終了時
- [ ] creature_changed シグナルチェーン全体が動作
- [ ] UI が自動更新（creature 配置・削除時）
- [ ] 3ターン以上の正常動作確認
- [ ] データ整合性テスト（creature_manager.validate_integrity()）

---

## 📈 期待効果

### 定量的効果

- **データ不整合リスク**: 100% 削減（CreatureManager が唯一のソース）
- **UI 更新遅延**: 手動 → 自動（creature_changed シグナル経由）
- **デバッグ時間**: 推定 30% 削減（データソース明確化）

### 定性的効果

- クリーチャーデータの信頼性向上
- 新機能追加時のデータ整合性リスク低下
- UI 自動更新で実装の複雑性低下

---

## 📁 Critical Files for Implementation

- `scripts/creature_manager.gd` - Core SSOT data structure and creature_changed signal
- `scripts/tiles/base_tiles.gd` - creature_data property reference mechanism
- `scripts/tile_data_manager.gd` - Data reference layer and tile info aggregation
- `scripts/board_system_3d.gd` - Signal relay layer and coordination hub
- `scripts/system_manager/game_system_manager.gd` - Signal connection orchestration

---

**作成者**: Opus (Plan agent)
**作成日**: 2026-02-14
**Opus Agent ID**: ab7c406
