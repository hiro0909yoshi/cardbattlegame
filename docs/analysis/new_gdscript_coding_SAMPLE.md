---
name: gdscript-coding
description: カードバトルゲーム向けGDScript規約。Godot 4パターン + プロジェクト固有の設計ルール。
---

# GDScript Coding Standards

カードバトルゲームプロジェクト向けのGDScriptコーディング規約。
一般的なGodot 4パターンと、プロジェクト固有の設計ルールを統合。

## 📋 目次

### Part 1: Godot 4 一般パターン
1. Core Concepts (Godotアーキテクチャ、GDScript基礎)
2. Design Patterns (State Machine, Autoload, Resource, Object Pooling, Component, Scene Management, Save System)
3. Performance Tips
4. General Best Practices

### Part 2: プロジェクト固有ルール ⭐
5. **Project-Specific Prohibitions** (禁止パターン)
6. **Project-Specific Design Patterns** (固有設計)
7. **Project-Specific Data Structures** (データ構造)
8. **Project-Specific Flows** (フロー・ルール)
9. **Project-Specific Naming Conventions** (命名規則)

---

# Part 1: Godot 4 一般パターン

## 1. Core Concepts

### 1.1 Godot Architecture

```
Node: Base building block
├── Scene: Reusable node tree (saved as .tscn)
├── Resource: Data container (saved as .tres)
├── Signal: Event communication
└── Group: Node categorization
```

### 1.2 GDScript Basics

```gdscript
class_name Player
extends CharacterBody2D

# Signals
signal health_changed(new_health: int)
signal died

# Exports (Inspector-editable)
@export var speed: float = 200.0
@export var max_health: int = 100
@export_range(0, 1) var damage_reduction: float = 0.0

# Onready (initialized when ready)
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation: AnimationPlayer = $AnimationPlayer

# Private variables (convention: underscore prefix)
var _health: int
var _can_attack: bool = true

func _ready() -> void:
    _health = max_health

func take_damage(amount: int) -> void:
    var actual_damage := int(amount * (1.0 - damage_reduction))
    _health = max(_health - actual_damage, 0)
    health_changed.emit(_health)

    if _health <= 0:
        died.emit()
```

## 2. Design Patterns

### Pattern 2.1: Autoload Singletons

```gdscript
# game_manager.gd (Add to Project Settings > Autoload)
extends Node

signal game_started
signal game_paused(is_paused: bool)
signal game_over(won: bool)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var state: GameState = GameState.MENU
var score: int = 0:
    set(value):
        score = value
        score_changed.emit(score)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func start_game() -> void:
    score = 0
    state = GameState.PLAYING
    game_started.emit()
```

### Pattern 2.2: Resource-based Data

```gdscript
# weapon_data.gd
class_name WeaponData
extends Resource

@export var name: StringName
@export var damage: int
@export var attack_speed: float
@export var icon: Texture2D
```

```gdscript
# Using resources
class_name Character
extends CharacterBody2D

@export var base_stats: CharacterStats
@export var weapon: WeaponData

var stats: CharacterStats

func _ready() -> void:
    # Create runtime copy to avoid modifying the resource
    stats = base_stats.duplicate_for_runtime()
```

### Pattern 2.3: Object Pooling

```gdscript
# object_pool.gd
class_name ObjectPool
extends Node

@export var pooled_scene: PackedScene
@export var initial_size: int = 10
@export var can_grow: bool = true

var _available: Array[Node] = []
var _in_use: Array[Node] = []

func get_instance() -> Node:
    var instance: Node

    if _available.is_empty():
        if can_grow:
            instance = _create_instance()
        else:
            push_warning("Pool exhausted")
            return null
    else:
        instance = _available.pop_back()

    instance.process_mode = Node.PROCESS_MODE_INHERIT
    instance.visible = true
    _in_use.append(instance)

    return instance
```

**プロジェクトでの使用状況**: 現在未使用。エフェクト/パーティクルシステムが複雑化した際に導入を検討。

## 3. Performance Tips

```gdscript
# 1. Cache node references
@onready var sprite := $Sprite2D  # Good
# $Sprite2D in _process()  # Bad - repeated lookup

# 2. Use static typing
func calculate(value: float) -> float:  # Good
    return value * 2.0

# 3. Disable processing when not needed
func _on_off_screen() -> void:
    set_process(false)
    set_physics_process(false)
```

## 4. General Best Practices

### Do's
- **Use signals for decoupling** - Avoid direct references
- **Type everything** - Static typing catches errors
- **Use resources for data** - Separate data from logic
- **Pool frequently spawned objects** - Avoid GC hitches

### Don'ts
- **Don't use `get_node()` in loops** - Cache references
- **Don't couple scenes tightly** - Use signals
- **Don't put logic in resources** - Keep them data-only

---

# Part 2: プロジェクト固有ルール ⭐

このセクションは、カードバトルゲームプロジェクト特有の設計パターン・制約・ルールです。

## 5. Project-Specific Prohibitions (禁止パターン)

このプロジェクトで絶対にやってはいけないパターン。

### 5.1 ❌ end_turn() を直接呼ばない

**理由**: ターン終了は複雑なシグナルチェーンで管理されており、直接呼び出しはフェーズ不整合を引き起こす（BUG-000の原因）。

**正しいシグナルチェーン**:
```
TileActionProcessor
  → emit "action_completed"
    → BoardSystem3D (リッスン)
      → emit "tile_action_completed"
        → GameFlowManager._on_tile_action_completed_3d()
          → end_turn()
```

**コード例**:
```gdscript
# ❌ 直接呼び出し（禁止）
game_flow_manager.end_turn()  # シグナルチェーンをスキップ

# ✅ シグナルチェーン経由
tile_action_processor.complete_action()  # action_completedをemit
# → 自動的に end_turn() が呼ばれる
```

### 5.2 ❌ 内部プロパティを外部から直接参照しない（チェーンアクセス禁止）

**理由**: 密結合を防ぎ、カプセル化を維持するため。

**ルール**: 2段以上のチェーンアクセスは禁止。

```gdscript
# ❌ 2段チェーン（禁止）
ui_manager.phase_display.show_toast("メッセージ")
board_system.tile_action_processor.complete_action()

# ✅ 親クラスに委譲メソッドを用意
ui_manager.show_toast("メッセージ")
board_system.complete_action()

# ❌ 3段チェーンは絶対禁止
handler.game_flow_manager.spell_phase_handler.spell_cast_notification_ui
```

**解決策**: 委譲メソッドパターン（6.2参照）

### 5.3 ❌ UI座標をハードコードしない

**理由**: 複数の画面サイズに対応するため、全UIはビューポート相対位置を使用。

```gdscript
# ❌ 画面サイズ依存
panel.position = Vector2(1200, 100)

# ✅ ビューポート相対
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20  # 右端から20px
var panel_y = (viewport_size.y - panel_height) / 2  # 中央
panel.position = Vector2(panel_x, panel_y)
```

### 5.4 ❌ デバッグフラグは DebugSettings に集約

**理由**: デバッグフラグが各システムに散在するとメンテナンス困難。

```gdscript
# ❌ 個別システムにフラグ
if tile_action_processor.debug_disable_lands_required: ...

# ✅ DebugSettings（Autoload）経由
if DebugSettings.disable_lands_required: ...
```

**参照**: `scripts/autoload/debug_settings.gd`

---

## 6. Project-Specific Design Patterns (固有設計)

このプロジェクトで使われている独自の設計パターン。

### 6.1 SpellSystemContainer パターン（RefCounted コンテナ）

**目的**: 10+2個のスペルシステムを一元管理し、辞書⇔個別変数の変換チェーンを解消。

**ファイル**: `scripts/spells/spell_system_container.gd`

**パターン**:
```gdscript
class_name SpellSystemContainer
extends RefCounted

# コアシステム（8個）
var spell_draw = null
var spell_magic = null
var spell_land = null
var spell_curse = null
var spell_dice = null
var spell_curse_stat = null
var spell_world_curse = null
var spell_player_move = null

# 派生システム（2個）
var spell_curse_toll = null
var spell_cost_modifier = null

func setup(
    p_spell_draw,
    p_spell_magic,
    # ... 他のシステム
) -> void:
    spell_draw = p_spell_draw
    spell_magic = p_spell_magic
    # ...
```

**使用箇所**:
```gdscript
# GameFlowManager
var spell_container: SpellSystemContainer = null

# アクセス
spell_container.spell_draw.draw_one(player_id)
spell_container.spell_magic.trigger_land_curse()
```

**メリット**:
- チェーンアクセス（`gfm.spell_magic`）を廃止
- 参照の集約化でメモリ管理が容易
- 辞書変換が不要

**類似パターン**: CPUAIContext（`scripts/cpu_ai/cpu_ai_context.gd`）

### 6.2 委譲メソッドパターン

**目的**: チェーンアクセスを禁止しつつ、子コンポーネントへのアクセスを提供。

**原則**: 外部から子コンポーネントにアクセスする場合、親に委譲メソッドを追加。

**例: UIManager**
```gdscript
# ui_manager.gd
func show_toast(message: String, duration: float = 2.0):
    phase_display.show_toast(message, duration)

func show_comment_and_wait(message: String, player_id: int = -1) -> void:
    await global_comment_ui.show_and_wait(message, player_id)

# 呼び出し側
ui_manager.show_toast("メッセージ")  # ✅
ui_manager.phase_display.show_toast("メッセージ")  # ❌
```

**委譲メソッド クイックリファレンス**:

#### UIManager 経由
| やりたいこと | 委譲メソッド |
|-------------|-------------|
| トースト表示 | `ui_manager.show_toast(msg)` |
| コメント表示＋待機 | `await ui_manager.show_comment_and_wait(msg, pid)` |
| Yes/No選択 | `await ui_manager.show_choice_and_wait(msg, pid, yes, no)` |
| 手札表示更新 | `ui_manager.update_hand_display(player_id)` |

#### BoardSystem3D 経由
| やりたいこと | 委譲メソッド |
|-------------|-------------|
| プレイヤー位置取得 | `board_system.get_player_tile(player_id)` |
| タイルにカメラフォーカス | `board_system.focus_camera_on_tile_slow(tile_index)` |
| アクション完了 | `board_system.complete_action()` |

**詳細**: `docs/implementation/delegation_method_catalog.md`

### 6.3 直接参照注入パターン

**目的**: 密結合を避け、必要最小限の参照のみを渡す。

**原則**: initialize時に必要な参照のみを直接渡す。システム全体（GameFlowManager等）は渡さない。

```gdscript
# ❌ 「動けばいい」で安易に全体を渡す
func initialize(game_flow_manager):
    self.gfm = game_flow_manager
    # → gfmを知っていれば何でもできてしまう

# ✅ 必要最小限の参照だけ
func initialize(spell_cost_modifier, lap_system):
    self.spell_cost_modifier = spell_cost_modifier
    self.lap_system = lap_system
```

**チェックリスト**（参照を追加する前に確認）:
- [ ] 方向は正しいか？（上位→下位、または同レベル横方向）
- [ ] 最小限か？（システム全体でなく必要なコンポーネントのみ）
- [ ] 循環しないか？（A→B→Aの経路ができないか）
- [ ] 5つ以上のシステムに依存しないか？

---

## 7. Project-Specific Data Structures (データ構造)

### 7.1 MHP（最大HP）計算

**重要**: `creature_data["hp"]` は元のカードデータ値で**絶対に変更しない**。

**計算式**:
```
MHP = 元のベースHP (hp) + 永続的基礎HP上昇 (base_up_hp)
```

**コード例**:
```gdscript
# ✅ BattleParticipant がある場合（戦闘中）
var mhp = participant.get_max_hp()  # base_hp + base_up_hp

# ✅ creature_data から直接計算（戦闘外）
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)

# ❌ base_up_hp を忘れない
var mhp = creature_data.get("hp", 0)  # 不完全！
```

**注意**: 現在HPは `creature_data["current_hp"]` に保存。`base_up_hp` はマスグロース・合成・周回ボーナスでのみ変更。

### 7.2 土地レベルのキー名

**重要**: tile_info と context でキー名が異なる。

| ソース | キー名 | 使用例 |
|--------|--------|--------|
| tile_info（タイル情報） | `"level"` | `var level = tile_info.get("level", 1)` |
| context（バトル） | `"tile_level"` | `var level = context.get("tile_level", 1)` |

```gdscript
# ✅ tile_info から
var level = tile_info.get("level", 1)

# ✅ context から
var level = context.get("tile_level", 1)

# ❌ tile_info に "tile_level" は存在しない
var level = tile_info.get("tile_level", 1)  # 常に1が返る！
```

**context構築時の変換** (condition_checker.gd):
```gdscript
"tile_level": battle_field.get("level", 1),
```

---

## 8. Project-Specific Flows (フロー・ルール)

### 8.1 初期化順序（Critical）

**ファイル**: `scripts/scenes/game_3d.gd`

game_3d.gd の `_ready()` は以下の順序で実行する必要がある：

```gdscript
func _ready() -> void:
    # 1. GameSystemManager 作成
    game_system_manager = GameSystemManager.new()

    # 2. UIManager 参照設定
    game_system_manager.set_ui_manager_references(...)

    # 3. hand_container 初期化
    ui_manager.initialize_hand_container(hand_container)

    # 4. debug_manual_control_all フラグ設定（setup_systems()の前）
    DebugSettings.debug_manual_control_all = true

    # 5. setup_systems() 実行
    game_system_manager.setup_systems()

    # 6. setup_3d_mode() 実行
    game_flow_manager.setup_3d_mode(board_system_3d)

    # 7. CardSelectionUI 参照再設定（タイミング問題により必要）
    ui_manager.card_selection_ui.set_references(...)
```

**理由**: 各ステップが前のステップに依存しているため、順序を変更するとクラッシュする。

### 8.2 フェーズ重複防止（BUG-000対策）

**目的**: ターン終了の重複実行を防ぐ。

**二段チェック**:
```gdscript
# GameFlowManager.end_turn()
func end_turn():
    # 1. フラグチェック（最速ガード）
    if is_ending_turn:
        return

    # 2. フェーズチェック（状態ガード）
    if current_phase == GamePhase.END_TURN:
        return

    # ★重要: フラグを最優先で立てる
    is_ending_turn = true

    # ... ターン終了処理 ...
```

**ルール**: フェーズ遷移を伴う処理では、必ず冒頭でフェーズ/フラグチェックを入れる。

---

## 9. Project-Specific Naming Conventions (命名規則)

### 9.1 初期化メソッド名の使い分け

| メソッド名 | 用途 | 判定基準 |
|-----------|------|---------|
| `_init()` | コンストラクタ（外部依存なし） | - |
| `_ready()` | Godot組み込み、システム初期化 | Nodeクラス |
| `initialize()` | 外部参照受取＋子オブジェクト生成あり | `new()` で子生成あり |
| `setup()` | `initialize()`と同義、複数システム受取時 | 複数の外部参照 |
| `setup_with_context()` | context受取＋子オブジェクト生成あり | context + `new()` |
| `set_context()` | context保存のみ（生成なし） | 保存のみ |
| `set_xxx()` | 単一プロパティ設定 | 単一設定 |

**判定基準**: `new()` で子オブジェクト生成あり → `initialize()` / `setup_with_context()`

---

## 📚 関連ドキュメント

### 設計ドキュメント
- `docs/design/design.md` - マスターアーキテクチャ
- `docs/design/skills_design.md` - スキルシステム仕様
- `CLAUDE.md` - プロジェクト概要

### 実装リファレンス
- `docs/implementation/implementation_patterns.md` - 実装パターン集
- `docs/implementation/delegation_method_catalog.md` - 委譲メソッド一覧
- `docs/implementation/signal_catalog.md` - シグナル一覧

### 進捗管理
- `docs/progress/daily_log.md` - 作業履歴
- `docs/progress/refactoring_next_steps.md` - リファクタリング計画

---

**Last Updated**: 2026-02-13
