# 📋 次のリファクタリング作業

**最終更新**: 2026-02-14
**目的**: セッション間で作業計画が失われないよう、次にやることを明確に記録

**確立したワークフロー**（Phase 1-4 で継続）:
```
1. Opus: Phase 計画立案 → refactoring_next_steps.md に記載
2. Haiku: 計画を読んで質問セッション
3. Sonnet: 質問に回答
4. Haiku: 実装
5. Sonnet: ドキュメント更新・完了報告
6. 次の Phase へ（繰り返し）
```

---

## ✅ 完了: Phase 0 - ツリー構造定義（2026-02-14）

**優先度**: P0（最重要）
**実装時間**: 1日

### 実施内容
- `docs/design/TREE_STRUCTURE.md` 作成: 理想的なツリー構造（3階層）
- `docs/design/dependency_map.md` 作成: 現在の依存関係マップ、問題12箇所特定
- `docs/progress/architecture_migration_plan.md` 作成: Phase 1-4 の詳細計画

### 効果
- ツリー構造が視覚的に理解できる
- 問題のある依存が12箇所特定されている
- Phase 1-4 の作業内容が明確

---

## 🔵 Phase 1: SpellSystemManager 導入（実装予定）

**優先度**: P0
**実装時間**: 2日（16時間）
**担当**: Haiku
**目的**: スペルシステムの階層化、GameFlowManager の責務明確化

### 背景

**現状の問題**:
```gdscript
GameFlowManager
└── spell_container: SpellSystemContainer (直接保持)
	├── spell_draw
	├── spell_magic
	... (10+個)
```

- SpellContainer が GameFlowManager に直接ぶら下がっている
- 階層が浅く、責務が不明確
- 新しいスペルシステム追加時に GameFlowManager を修正

**理想形**:
```gdscript
GameFlowManager
└── SpellSystemManager (新規、Node型)
	└── SpellSystemContainer
		├── spell_draw
		├── spell_magic
		... (10+個)
```

---

### タスク一覧

#### タスク1-1: SpellSystemManager クラス作成（4-5時間）

**新規ファイル**: `scripts/game_flow/spell_system_manager.gd`

**実装内容**:
```gdscript
extends Node
class_name SpellSystemManager

## スペルシステム統括管理者
## GameFlowManager の子として配置され、全スペルシステムを管理

# コアスペルシステムコンテナ
var spell_container: SpellSystemContainer = null

# Node型のスペルシステム（今後の拡張用）
var spell_curse_toll: SpellCurseToll = null
var spell_cost_modifier = null

func _ready():
	print("[SpellSystemManager] 初期化完了")

## セットアップ
func setup(container: SpellSystemContainer) -> void:
	if not container:
		push_error("[SpellSystemManager] SpellSystemContainer が null です")
		return

	spell_container = container
	print("[SpellSystemManager] setup 完了")

## スペルシステムへのアクセサ（後方互換性）
func get_spell_draw():
	return spell_container.spell_draw if spell_container else null

func get_spell_magic():
	return spell_container.spell_magic if spell_container else null

# ... 他のスペルシステムも同様
```

**チェックポイント**:
- [ ] SpellSystemManager クラス定義完成
- [ ] spell_container 参照保持確認
- [ ] setup() メソッド実装完了
- [ ] すべてのアクセサメソッド実装完了
- [ ] GDScript 構文エラーなし

---

#### タスク1-2: GameSystemManager の初期化を更新（2-3時間）

**対象ファイル**: `scripts/system_manager/game_system_manager.gd`

**変更箇所**: `_setup_spell_systems()` メソッド（行 501-618）

**変更内容**:
```gdscript
func _setup_spell_systems() -> void:
	if not card_system or not player_system:
		push_error("[GameSystemManager] CardSystem/PlayerSystemが初期化されていません")
		return

	# === Step 1: SpellSystemManager を作成 ===
	var spell_system_manager = SpellSystemManager.new()
	spell_system_manager.name = "SpellSystemManager"

	# GameFlowManager の子として追加
	game_flow_manager.add_child(spell_system_manager)

	# === Step 2: SpellSystemContainer を作成 ===
	var spell_container = SpellSystemContainer.new()

	# === Step 3: 各スペルシステムの初期化（既存コード維持）===
	var spell_draw = SpellDraw.new()
	spell_draw.setup(card_system, player_system)
	# ... 他のスペルシステム初期化 ...

	# === Step 4: SpellSystemManager にセットアップ ===
	spell_system_manager.setup(spell_container)

	# === Step 5: GameFlowManager に参照を設定（後方互換性） ===
	game_flow_manager.set_spell_container(spell_container)
	game_flow_manager.spell_system_manager = spell_system_manager

	# === Step 6: SpellCurseToll 等の派生システム初期化（既存コード維持）===
	# ... 既存の SpellCurseToll 初期化コード ...

	print("[SpellSystemManager] 全初期化完了")
```

**重要なポイント**:
1. 順序が重要: SpellSystemManager を先に作成・add_child
2. 後方互換性: `game_flow_manager.spell_container` は維持
3. 新規参照: `game_flow_manager.spell_system_manager` を追加

**チェックポイント**:
- [ ] SpellSystemManager 作成（new()）
- [ ] GameFlowManager.add_child() で子として追加
- [ ] spell_container 設定
- [ ] setup() メソッド呼び出し確認
- [ ] 既存の set_spell_container() 呼び出し維持
- [ ] spell_system_manager 変数設定確認

---

#### タスク1-3: GameFlowManager に参照追加（1時間）

**対象ファイル**: `scripts/game_flow_manager.gd`

**変更箇所**: クラス変数宣言部（行 39-50）

**変更内容**:
```gdscript
# === Phase 1 で追加: SpellSystemManager への参照 ===
var spell_system_manager: SpellSystemManager = null

# === 既存の spell_container は互換性のため維持 ===
var spell_container: SpellSystemContainer = null
```

**チェックポイント**:
- [ ] spell_system_manager 変数追加
- [ ] 既存の spell_container は維持
- [ ] 型アノテーション（: SpellSystemManager）付き

---

#### タスク1-4: 参照設定の確認（1-2時間）

**対象**: すべてのシステムで `gfm.spell_container` を参照している箇所

**検索方法**:
```bash
grep -rn "spell_container\." scripts/ --include="*.gd"
```

**方針**: Phase 1 では既存参照を維持し、後方互換性を優先

**チェックポイント**:
- [ ] spell_container 参照箇所が 20+箇所確認
- [ ] 全参照が動作することを確認
- [ ] spell_system_manager への移行は Phase 2 に延期

---

#### タスク1-5: テスト・検証（2-3時間）

**テスト項目**:

```
□ コンパイル: GDScript 構文エラーなし
□ ゲーム起動: MainScene → game_3d 初期化
  - [SpellSystemManager] 初期化完了
  - [GameSystemManager] 初期化完了
□ スペルフェーズ動作
  - UI表示: スペルカード選択可能
  - スペル実行: SpellDraw, SpellMagic が動作
□ スペル実行確認（各種）
  - SpellDraw: カードドロー正常
  - SpellMagic: EP操作正常
  - SpellLand: 土地属性変更正常
  - SpellCurse: クリーチャー呪い正常
□ ターン進行
  - Spell → Dice → Movement → Action → End
  - フェーズ遷移が正常
□ 複数ターン動作
  - 3ターン以上正常動作
  - CPU vs CPU で 3ターン以上動作
□ エラーログ確認
  - push_error() なし（正常時）
  - null 参照エラーなし
```

**検証コマンド（デバッグコンソール）**:
```gdscript
print("GFM spell_system_manager:", game_flow_manager.spell_system_manager)
print("GFM spell_container:", game_flow_manager.spell_container)
print("SpellDraw access:", game_flow_manager.spell_container.spell_draw)
```

---

### 成功指標

- [ ] SpellSystemManager クラス作成完了
- [ ] GameSystemManager の初期化更新完了
- [ ] GameFlowManager に spell_system_manager 変数追加完了
- [ ] すべてのテスト項目をクリア
- [ ] 既存機能に影響なし（後方互換性維持）
- [ ] ツリー構造が1段階深くなる

### リスク評価

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| 既存スペル処理が動作しなくなる | 🔴 高 | 低 | 後方互換性を維持 |
| 初期化順序の問題 | 🟡 中 | 中 | _setup_spell_systems() で段階的に初期化 |
| 参照の更新漏れ | 🟡 中 | 低 | grep で全箇所検索 |
| シグナル接続の重複 | 🟢 低 | 低 | is_connected() チェック |

### ロールバック計画

**Phase 1 失敗時**（所要時間: 30分）:
1. SpellSystemManager.gd ファイル削除
2. GameSystemManager の _setup_spell_systems() を元に戻す
3. GameFlowManager の spell_system_manager 変数削除

---

### 実装の流れ（推奨順序）

**Day 1（8時間）**:
1. タスク1-1: SpellSystemManager クラス作成（4-5時間）
2. タスク1-2: GameSystemManager 更新（2-3時間）
3. タスク1-3: GameFlowManager に参照追加（1時間）

**Day 2（8時間）**:
4. タスク1-4: 参照設定確認（1-2時間）
5. タスク1-5: テスト・検証（2-3時間）
6. ドキュメント更新（2時間）

---

### 実装後のドキュメント更新

完了後に以下のドキュメントを更新：

- [ ] `docs/design/TREE_STRUCTURE.md` - SpellSystemManager を追加
- [ ] `docs/progress/daily_log.md` - Phase 1 完了を記録
- [ ] `docs/progress/refactoring_next_steps.md` - Phase 2 開始予定を記録
- [ ] `CLAUDE.md` - Architecture Overview セクションを更新

---

### 重要なポイント

**後方互換性について**:

Phase 1 の最重要原則は**後方互換性の維持**です：

```gdscript
# ===== 既存コードが動作し続ける =====
game_flow_manager.spell_container.spell_draw  # OK（変更不要）
game_flow_manager.spell_container.spell_magic  # OK（変更不要）

# ===== Phase 1 後も両方のアクセス方法が利用可能 =====
# 既存パターン
game_flow_manager.spell_container.spell_draw

# 新規パターン（Phase 2以降で推奨）
game_flow_manager.spell_system_manager.spell_container.spell_draw
```

このため、20+ のファイルの参照を更新する必要がありません。

---

### 関連ドキュメント

- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造
- `docs/design/dependency_map.md` - システム依存関係マップ
- `docs/progress/architecture_migration_plan.md` - 移行計画詳細

---

## 📋 アーカイブ: 過去のリファクタリング

<details>
<summary>Phase 1-A, 1-B の詳細（クリックして展開）</summary>

### Phase 1-A: 逆参照解消（2日）
- TileDataManager: game_flow_manager 変数削除
- MovementController, LapSystem: Callable注入パターン

### Phase 1-B: nullチェック強化（3.25時間）
- game_flow_manager: 5箇所
- spell_phase_handler: 5箇所
- battle_system: 2箇所
- 統一パターン: push_error() + has_method()

</details>

---

**最終更新**: 2026-02-14
**次のアクション**: Haiku に Phase 1 の実装を依頼（質問セッション → 回答 → 実装）
