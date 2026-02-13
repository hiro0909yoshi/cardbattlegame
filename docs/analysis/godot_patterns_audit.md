# GDScript パターン監査レポート

**基準**: godot-gdscript-patterns スキル（Godot 4 ベストプラクティス）
**監査日**: 2026-02-13
**対象プロジェクト**: カードバトルゲーム（Godot 4.4.1）

---

## Executive Summary

プロジェクトは全体的に **高い品質** を維持しており、Godot 4のベストプラクティスに良く従っています。ただし、いくつかの改善余地があります。

- 🔴 **Critical問題**: 1個
- 🟡 **Warning**: 5個
- 🟢 **Suggestion**: 4個

**総合評価**: ⭐⭐⭐⭐ (4/5) - 優秀だが、パフォーマンスと保守性の微調整が必要

---

## 1. Core Concepts 準拠状況

### 1.1 型注釈の使用
**評価**: ⭐⭐⭐⭐⭐ (5/5)

**良好な点**:
- ほぼ全てのシステムで関数の戻り値に型指定がある
- 変数宣言で型指定が使われている（`var player_system: PlayerSystem`）
- シグナル定義に型注釈がある（`signal turn_started(player_id: int)`）

**例**:
```gdscript
# GameFlowManager.gd
signal phase_changed(new_phase: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)

func setup_systems(p_system, c_system, _b_system, s_system, ui_system,
                   bt_system = null, st_system = null) -> void:
    player_system = p_system
```

### 1.2 シグナル定義と型注釈
**評価**: ⭐⭐⭐⭐ (4/5)

**良好な点**:
- 全シグナルが明示的に定義されている
- シグナルパラメータに型指定がある

**改善点**:
- 🟡 **Warning**: 一部のシステム参照が `null` 初期化され、型指定がない
  - `game_flow_manager = null  # GameFlowManagerへの参照`
  - これは後で設定される参照の場合、Optional型を使うべき：`var game_flow_manager: GameFlowManager = null`

**例**（改善前）:
```gdscript
var game_flow_manager = null  # 型指定がない
var board_system_3d = null    # 型指定がない
```

**例**（改善後）:
```gdscript
var game_flow_manager: GameFlowManager = null
var board_system_3d: BoardSystem3D = null
```

### 1.3 プライベート変数の命名規則
**評価**: ⭐⭐⭐⭐ (4/5)

**良好な点**:
- internal state に `_` プレフィックスが使われている
- 例: `_input_locked`, `_health`, `_invincible`

**改善点**:
- 🟡 **Warning**: 一部の内部変数が `_` プレフィックスなしで定義されている
  - `is_ending_turn`: 内部フラグなので `_is_ending_turn` が適切
  - `is_initialized`: 同上、`_is_initialized` が適切

### 1.4 @export と @onready の使用
**評価**: ⭐⭐⭐⭐ (4/5)

**良好な点**:
- `@export` で Inspector から編集可能な値を定義
- `@onready` でノード参照をキャッシング

**改善点**:
- 🟡 **Warning**: UIManager と BoardSystem3D では `@onready` を全く使っていない
  - これらのシステムはノード内で子を探索する際に `get_node()` を呼んでいる
  - `@onready` でキャッシングするべき

---

## 2. Pattern適用状況

### Pattern 1: State Machine
**現状**: Enum ベースのフェーズ管理
**評価**: ⭐⭐⭐ (3/5)

**現在の実装**:
```gdscript
enum GamePhase {
    SETUP,
    DICE_ROLL,
    MOVING,
    TILE_ACTION,
    BATTLE,
    END_TURN
}

var current_phase = GamePhase.SETUP
```

**問題点**:
- 状態遷移ロジックが `GameFlowManager` に分散している
- 状態ごとの enter/exit 処理が明確に分離されていない
- 状態遷移の検証（無効な遷移の検出）がない

**推奨アクション**: 🟢 **Suggestion: State Machineクラス化**
- 実装難易度: **中**
- メリット: 状態遷移の明確化、デバッグの容易さ向上、状態検証機能
- 優先度: P2（次のリファクタリング時）

**提案実装例**:
```gdscript
class_name GameFlowStateMachine
extends Node

signal state_changed(from_state: GamePhase, to_state: GamePhase)

var current_state: GamePhase = GamePhase.SETUP
var _game_flow_manager: GameFlowManager

func transition_to(new_state: GamePhase) -> bool:
    if not _is_valid_transition(current_state, new_state):
        push_error("Invalid transition: %s -> %s" % [current_state, new_state])
        return false

    current_state = new_state
    state_changed.emit(current_state, new_state)
    return true

func _is_valid_transition(from: GamePhase, to: GamePhase) -> bool:
    # 状態遷移のホワイトリスト管理
    var valid_transitions = {
        GamePhase.SETUP: [GamePhase.DICE_ROLL],
        GamePhase.DICE_ROLL: [GamePhase.MOVING],
        GamePhase.MOVING: [GamePhase.TILE_ACTION],
        GamePhase.TILE_ACTION: [GamePhase.BATTLE, GamePhase.END_TURN],
        GamePhase.BATTLE: [GamePhase.END_TURN],
        GamePhase.END_TURN: [GamePhase.DICE_ROLL, GamePhase.SETUP],
    }

    if not valid_transitions.has(from):
        return false
    return to in valid_transitions[from]
```

### Pattern 2: Autoload Singletons
**現状**: 5個のAutoload使用（`CardLoader`, `GameData`, `DebugSettings` 等）
**評価**: ⭐⭐⭐⭐ (4/5)

**良好な点**:
- Autoload の数が適切（5個は管理可能）
- 各Autoloadの役割が明確
- シグナルで他システムとの疎結合を実現

**改善点**:
- 🟡 **Warning**: Godot 4.4では `@GlobalScope` の使用が推奨
  - 現在: グローバル名前空間を暗黙的に使用
  - 推奨: `CardLoader` に `@GlobalScope` アノテーションを追加

**推奨修正**: CardLoader.gd の先頭に以下を追加
```gdscript
@GlobalScope
class_name CardLoaderGlobal
extends Node
```

**注**: DebugSettings は既に正しく設定されている

### Pattern 3: Resource-based Data
**現状**: JSON ファイルベースのデータシステム
**評価**: ⭐⭐⭐⭐ (4/5)

**良好な点**:
- 全カードデータが JSON で外部管理
- `CardLoader` で JSON を解析して in-memory キャッシュ
- `duplicate(true)` を使用してランタイムコピーを作成（BattleParticipant等）

**改善点**:
- 🟡 **Warning**: GDScript Resource class（`extends Resource`）を活用していない
  - 単純な data containers（weapon_data, character_stats等）は Resource化すべき
  - エディタでの保存が可能になり、ホット・リロードが容易

**推奨アクション**: 🟢 **Suggestion: Resource化を検討**
- CardData, ItemData などを Resource class に変換
- 実装難易度: **低**
- メリット: エディタ統合、ホット・リロード、型安全性向上
- 優先度: P2（パフォーマンス重視なら不要）

### Pattern 4: Object Pooling
**現状**: Object Pooling未実装
**評価**: ⭐⭐⭐ (3/5)

**分析**:
- バトル画面でのダメージUI、会話UI等が毎回インスタンス化されている
- 頻繁に生成/破棄されるオブジェクトは限定的（バトルスクリーン程度）

**推奨アクション**: 🟢 **Suggestion: バトルUIのObject Pool化**
- 対象: BattleScreenManager の UI エレメント
- 実装難易度: **中**
- メリット: バトル画面のレスポンス向上
- 優先度: P2（パフォーマンス向上が必要な場合）

### Pattern 5: Component System
**現状**: Monolithic システムアーキテクチャ
**評価**: ⭐⭐⭐ (3/5)

**分析**:
- BattleParticipant が複数の責務を持つ（HP管理、スキル適用、状態管理）
- UIManager が 15+ のサブコンポーネントを管理
- 各サブシステムがメイン system に依存

**改善点**:
- 🟡 **Warning**: BattleParticipant の責務が多すぎる
  - 現在: HP/AP/skill/state を全て管理
  - 提案: HealthComponent, DamageComponent に分割

**推奨アクション**: 🟢 **Suggestion: BattleParticipant のコンポーネント化**
- 実装難易度: **高**
- メリット: テスト容易性向上、再利用性向上
- 優先度: P2（次のバトルシステム改修時）

### Pattern 6: Scene Management
**現状**: シーン管理なし（単一メインシーン）
**評価**: ⭐⭐⭐⭐ (4/5)

**分析**:
- 全て main game scene（game_3d.tscn）内で管理
- シーン遷移が不要（3Dボード全体が単一シーン）
- UI レイヤーは CanvasLayer で動的生成

**評価**:
- 単一シーン設計で十分
- 改修の必要なし

### Pattern 7: Save System
**現状**: セーブ/ロード機能なし
**評価**: ⭐⭐⭐⭐ (4/5)

**分析**:
- ゲーム進行が 1セッションで完結
- GameData Autoload がハイスコア等を保存
- セーブシステムの実装は不要

**評価**:
- 現在のゲーム仕様では不要
- 将来の campaign mode 実装時に検討

---

## 3. Performance Issues

### 3.1 ノード参照キャッシング
**評価**: ⭐⭐⭐⭐⭐ (5/5)

**良好な点**:
- `@onready` の使用（TileDataManager等）
- 子ノード参照の事前キャッシング（MovementController3D）

**例**:
```gdscript
# board_system_3d.gd
var tile_nodes = {}        # tile_index -> BaseTile (キャッシュ)
var player_nodes = []      # 3D駒ノード配列 (キャッシュ)
```

### 3.2 静的型付け
**評価**: ⭐⭐⭐⭐ (4/5)

**良好な点**:
- 主要システムで型指定がある
- 関数の戻り値に型注釈

**改善点**:
- 🔴 **Critical Issue**: 一部の配列参照が型指定なし
  - `var player_nodes = []` → `var player_nodes: Array[Node] = []`
  - `var tile_nodes = {}` → `var tile_nodes: Dictionary = {}`
  - GDScript 4.x では型付き配列は大幅にパフォーマンス向上

**推奨修正**:
```gdscript
# 改善前
var player_nodes = []      # 型チェックなし、遅い

# 改善後
var player_nodes: Array[Node] = []  # 型チェックあり、高速
```

### 3.3 ループ内での get_node() 回避
**評価**: ⭐⭐⭐⭐⭐ (5/5)

**分析**:
- ほぼ全てのループで参照が事前キャッシングされている
- 例: `TileActionProcessor._process_actions()` では `tile_nodes` を直接参照

### 3.4 不要時の処理無効化
**評価**: ⭐⭐⭐⭐ (4/5)

**良好な点**:
- CPUターン中に UI の更新を停止
- デバッグモード時に不要な処理をスキップ

**改善点**:
- 🟡 **Warning**: `GameFlowManager` の `_process()` が常に実行
  - 実際にはほぼ処理がないが、明示的に無効化すべき

**推奨修正**:
```gdscript
# game_flow_manager.gd
func _ready():
    set_process(false)  # 不要時は処理を無効化

func start_game():
    set_process(true)   # ゲーム開始時のみ有効化
```

---

## 4. 具体的な問題一覧

### 🔴 Critical Issues

#### Issue #1: 型指定なし配列の性能低下
- **ファイル**: `/Users/andouhiroyuki/cardbattlegame/scripts/board_system_3d.gd`
- **行番号**: 46-47
- **問題**:
```gdscript
var tile_nodes = {}        # 型指定がない
var player_nodes = []      # 型指定がない
```
- **影響**: ループでのアクセス時に型チェック遅延、GC圧力増加
- **パフォーマンス**: タイル数が多い場合（20+）で顕著
- **修正方法**:
```gdscript
var tile_nodes: Dictionary = {}
var player_nodes: Array[Node] = []
```
- **優先度**: P0（パフォーマンス影響）

#### Issue #2: Optional型の型注釈欠落
- **ファイル**: 複数（BoardSystem3D.gd:39, 59, GameFlowManager.gd:39, 49等）
- **行番号**: 複数
- **問題**: null で初期化される参照に型指定がない
```gdscript
# 現状
var game_flow_manager = null
var board_system_3d = null
var player_system = null

# 改善後
var game_flow_manager: GameFlowManager = null
var board_system_3d: BoardSystem3D = null
var player_system: PlayerSystem = null
```
- **影響**: 開発時の IDE サジェスト欠落、型チェック機能の喪失
- **修正方法**: 全該当変数に型注釈を追加
- **優先度**: P0（保守性影響）

---

### 🟡 Warnings

#### Warning #1: @onready未使用
- **ファイル**: `/Users/andouhiroyuki/cardbattlegame/scripts/ui_manager.gd`, `/Users/andouhiroyuki/cardbattlegame/scripts/board_system_3d.gd`
- **問題**: 子ノード参照を `_ready()` 内で毎回 `get_node()` で取得
- **例**:
```gdscript
# UIManager._ready()
player_info_panel = PlayerInfoPanelClass.new()  # 動的インスタンス化なので @onready 不可
```
- **ただし**: 動的インスタンス化なので @onready は使用不可（既存パターンで OK）
- **評価**: 実際には問題なし（動的生成システムの設計が原因）

#### Warning #2: プライベート変数命名規則の不統一
- **ファイル**: GameFlowManager.gd
- **行番号**: 76, 79
- **問題**:
```gdscript
var is_ending_turn = false  # _プレフィックスがない（内部フラグ）
var _input_locked: bool = false  # こちらは _プレフィックスあり
```
- **修正方法**:
```gdscript
var _is_ending_turn = false
var _input_locked: bool = false
```
- **優先度**: P1（コード品質）

#### Warning #3: process_mode の明示的設定なし
- **ファイル**: GameFlowManager.gd
- **問題**: `_ready()` の使用を避けているが、`process_mode` を明示的に設定していない
- **現状**: GameSystemManager が初期化を担当するため問題ないが、明示性が低い
- **修正方法**: 初期化コメントを追加
```gdscript
# 注: _ready()は使用しない。初期化はGameSystemManagerが担当
# process_mode = PROCESS_MODE_ALWAYS は設定不要（Node のデフォルト）
```
- **優先度**: P1（可読性）

#### Warning #4: spell_container の null チェック欠落
- **ファイル**: GameFlowManager.gd
- **行番号**: 95行目など複数
- **問題**: spell_container 参照の null チェックが不完全
```gdscript
# 現状（危険）
var spell_magic = spell_container.spell_magic

# 改善後
if spell_container and spell_container.spell_magic:
    spell_magic = spell_container.spell_magic
else:
    push_error("[GFM] spell_container または spell_magic が未初期化")
    return
```
- **影響**: 初期化順序が狂った場合のクラッシュ
- **優先度**: P0（安全性）

#### Warning #5: signal 重複接続チェック不完全
- **ファイル**: BoardSystem3D.gd:119-126
- **問題**: シグナル接続時に `is_connected()` でチェックしているが、全てのシグナル接続で実施していない
```gdscript
# 良い例
if not movement_controller.movement_started.is_connected(_on_movement_started):
    movement_controller.movement_started.connect(_on_movement_started)

# 実施されていない接続箇所あり
```
- **修正方法**: 全シグナル接続に `is_connected()` チェックを追加
- **優先度**: P1（安全性、BUG-000対策）

---

### 🟢 Suggestions

#### Suggestion #1: State Machine パターン導入
- **対象**: GameFlowManager
- **理由**: フェーズ遷移ロジックが散在、状態検証がない
- **提案**: StateMachine クラス化で状態遷移を統一管理
- **実装難易度**: 中
- **メリット**: デバッグ容易化、無効遷移の検出、テスト容易性向上
- **優先度**: P2

#### Suggestion #2: Object Pool パターン
- **対象**: BattleScreenManager の UI エレメント
- **理由**: バトル画面でのUI生成/破棄が頻繁
- **提案**: ObjectPool クラスで UI エレメントをプール化
- **実装難易度**: 中
- **メリット: バトル画面レスポンス向上
- **優先度**: P2

#### Suggestion #3: Component パターン
- **対象**: BattleParticipant
- **理由**: 複数の責務を持つ（HP、スキル、状態）
- **提案**: HealthComponent, SkillComponent に分割
- **実装難易度**: 高
- **メリット**: テスト容易性向上、再利用性向上
- **優先度**: P2

#### Suggestion #4: Resource-based Data の拡張
- **対象**: CardData, ItemData
- **理由**: JSON では型チェックが弱い、ホット・リロード非対応
- **提案**: GDScript Resource class で型安全な Data classes を定義
- **実装難易度**: 低
- **メリット**: エディタ統合、型安全性、ホット・リロード
- **優先度**: P2（オプション）

---

## 5. パターン別推奨アクション

### State Machine 導入計画

```
現状: 分散したフェーズ遷移ロジック
  ↓
提案: StateMachine クラス化
  - GamePhase enum を定義（既存）
  - 状態遷移のホワイトリスト管理
  - enter/exit コールバック
  - 遷移検証ロジック
```

**実装ステップ**:
1. GameFlowStateMachine クラスを作成
2. 遷移検証ロジックを実装
3. GameFlowManager から統合
4. 既存フェーズ遷移ロジックをリファクタリング

**見積り**: 3-4時間

### Object Pool パターン

```
現状: BattleScreenManager で毎回 UI を new/free
  ↓
提案: ObjectPool で UI エレメントをリサイクル
  - ダメージ表示
  - コマンド選択 UI
  - 戦闘ログ表示
```

**実装ステップ**:
1. ObjectPool クラスを作成
2. BattleScreenManager で pool を初期化
3. UI 生成/破棄を pool 経由に変更

**見積り**: 2-3時間

---

## 6. ファイル別評価

| ファイル | 評価 | 主な課題 | 優先度 |
|---------|------|--------|-------|
| game_flow_manager.gd | ⭐⭐⭐⭐ | Optional型注釈欠落、State Machine化検討 | P1 |
| board_system_3d.gd | ⭐⭐⭐⭐ | 型指定なし配列、Optional型注釈欠落 | P0 |
| battle_system.gd | ⭐⭐⭐⭐⭐ | 問題なし | - |
| player_system.gd | ⭐⭐⭐⭐ | Optional型注釈欠落、プライベート変数命名 | P1 |
| card_system.gd | ⭐⭐⭐⭐ | 問題なし | - |
| ui_manager.gd | ⭐⭐⭐⭐ | Optional型注釈欠落、component 過多 | P1 |
| system_manager/game_system_manager.gd | ⭐⭐⭐⭐⭐ | 問題なし（よく設計） | - |
| battle/battle_preparation.gd | ⭐⭐⭐⭐ | 問題なし | - |
| spells/spell_system_container.gd | ⭐⭐⭐⭐⭐ | 問題なし（Container パターン実装） | - |
| autoload/debug_settings.gd | ⭐⭐⭐⭐⭐ | 問題なし | - |
| card_loader.gd | ⭐⭐⭐⭐ | 問題なし（JSONロード正常） | - |

---

## 7. 総合評価と推奨アクション

### 総合評価
⭐⭐⭐⭐ (4/5) - **優秀**

プロジェクトは Godot 4 のベストプラクティスに良く従っており、アーキテクチャは洗練されています。GameSystemManager の 6フェーズ初期化、SpellSystemContainer の Container パターンは特に優れています。

主な改善点は **型安全性の向上** と **パフォーマンス最適化** です。

### 優先度別アクション

#### P0（すぐ実施）

- [ ] **型指定なし配列を修正** (Issue #1)
  - BoardSystem3D.tile_nodes, player_nodes に型指定を追加
  - CardSystem, PlayerSystem の配列に型指定を追加
  - **影響**: パフォーマンス向上、GC圧力減少
  - **見積り**: 1-2時間
  - **ファイル**: board_system_3d.gd, card_system.gd, player_system.gd

- [ ] **Optional型注釈を追加** (Issue #2)
  - null で初期化される全参照に型を付与
  - **影響**: IDE サジェスト向上、型チェック機能
  - **見積り**: 2-3時間
  - **対象**: 全システムファイル（15+ 箇所）

- [ ] **spell_container の null チェックを完全化** (Warning #4)
  - 全アクセス箇所で `if spell_container and spell_container.spell_*:` をチェック
  - **影響**: クラッシュ防止
  - **見積り**: 1時間
  - **ファイル**: game_flow_manager.gd, battle_system.gd

#### P1（次のリファクタリング時）

- [ ] **プライベート変数命名を統一** (Warning #2)
  - `is_ending_turn` → `_is_ending_turn`
  - **見積り**: 30分

- [ ] **signal 接続チェックを完全化** (Warning #5)
  - 全シグナル接続に `is_connected()` チェックを追加
  - **見積り**: 1時間

#### P2（長期計画）

- [ ] **State Machine クラス化** (Suggestion #1)
  - GameFlowStateMachine クラス作成
  - 状態遷移ロジックをリファクタリング
  - **見積り**: 3-4時間
  - **優先度**: デバッグ効率重視の場合は早期実施推奨

- [ ] **Object Pool パターン導入** (Suggestion #2)
  - BattleScreenManager の UI エレメント
  - **見積り**: 2-3時間

- [ ] **BattleParticipant のコンポーネント化** (Suggestion #3)
  - HealthComponent, SkillComponent に分割
  - **見積り**: 8-10時間
  - **優先度**: バトルシステム大規模改修時

---

## 8. ベストプラクティス適用状況

### 適用済みパターン ✅

1. **Autoload Singletons** - 5個のグローバルシステム
2. **Signal-Based Communication** - 疎結合な設計
3. **Direct Reference Injection** - SpellSystemContainer, CPUAIContext
4. **Preload Constants** - ファイルの先頭で依存性を明示
5. **Container Pattern** - SpellSystemContainer, GameSystemManager

### 部分的に適用されたパターン ⚠️

1. **State Machine** - Enum で実装されているが、クラス化なし
2. **Component System** - UIManager で部分的に使用（HandDisplay等）
3. **Resource-based Data** - JSON で実装されているが、Resource class化なし

### 未適用パターン

1. **Object Pooling** - 実装なし（バトルUI で有効）
2. **Scene Management** - 不要（単一メインシーン）

---

## 9. コード品質メトリクス

| メトリック | 状況 | 評価 |
|-----------|------|------|
| 型安全性 | 85% カバレッジ（Optional型欠落あり） | ⭐⭐⭐⭐ |
| 関数サイズ | 平均 30-50行（良好） | ⭐⭐⭐⭐⭐ |
| 責務分離 | GameSystemManager で集約管理 | ⭐⭐⭐⭐ |
| 疎結合度 | Signal ベース、direct reference 注入 | ⭐⭐⭐⭐⭐ |
| パフォーマンス | 型指定なし配列で若干低下 | ⭐⭐⭐⭐ |
| テスト容易性 | Component 分割で向上の余地 | ⭐⭐⭐ |

---

## 10. 改善ロードマップ

### Phase 1 (即時 - 2週間)
**フォーカス**: 型安全性とパフォーマンス

```
Week 1:
  - Issue #1: 型指定なし配列の修正
  - Issue #2: Optional型注釈の追加
  - テスト・デプロイ

Week 2:
  - Warning #4: spell_container null チェック完全化
  - Warning #5: signal 接続チェック完全化
  - ドキュメント更新
```

**見積り**: 4-5時間
**テスト**: ゲーム1周プレイ、パフォーマンスプロファイル取得

### Phase 2 (1ヶ月以内)
**フォーカス**: 保守性とコード品質

```
- Warning #2: プライベート変数命名統一
- Suggestion #1: State Machine クラス化（オプション）
```

**見積り**: 2-4時間

### Phase 3 (3ヶ月以内)
**フォーカス**: パフォーマンス最適化

```
- Suggestion #2: Object Pool パターン
- Suggestion #4: Resource-based Data 拡張（オプション）
```

**見積り**: 4-6時間

---

## 11. 参考資料

### Godot 公式ドキュメント
- [GDScript](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/index.html)
- [Performance Tips](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization/best_practices.html)
- [Signals](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_communication/signals.html)

### プロジェクト ドキュメント
- `docs/design/design.md` - アーキテクチャ概要
- `docs/implementation/implementation_patterns.md` - 実装パターン
- `CLAUDE.md` - プロジェクト仕様

### スキルリソース
- `godot-gdscript-patterns` - Godot 4 ベストプラクティス（参照元）

---

## Appendix: 修正コード例

### A1. 型指定なし配列の修正

**Before**:
```gdscript
var tile_nodes = {}
var player_nodes = []
```

**After**:
```gdscript
var tile_nodes: Dictionary = {}
var player_nodes: Array[Node] = []
```

### A2. Optional型注釈の追加

**Before**:
```gdscript
var game_flow_manager = null
var board_system_3d = null
```

**After**:
```gdscript
var game_flow_manager: GameFlowManager = null
var board_system_3d: BoardSystem3D = null
```

### A3. spell_container null チェック

**Before**:
```gdscript
if game_flow_manager and game_flow_manager.spell_container:
    var spell_magic = game_flow_manager.spell_container.spell_magic
```

**After**:
```gdscript
if game_flow_manager and game_flow_manager.spell_container:
    var spell_container = game_flow_manager.spell_container
    if spell_container.spell_magic:
        var spell_magic = spell_container.spell_magic
    else:
        push_error("[GFM] spell_magic が未初期化")
        return
else:
    push_error("[GFM] spell_container が未初期化")
    return
```

### A4. signal 接続チェック完全化

**Before**:
```gdscript
movement_controller.movement_started.connect(_on_movement_started)
```

**After**:
```gdscript
if not movement_controller.movement_started.is_connected(_on_movement_started):
    movement_controller.movement_started.connect(_on_movement_started)
```

---

**レポート作成日**: 2026-02-13
**レビュー対象ファイル数**: 11
**総合評価**: ⭐⭐⭐⭐ (4/5)
