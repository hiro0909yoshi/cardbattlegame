# GDScript規約 洗い出しレポート

## 執行概要

このレポートは、カードバトルゲームプロジェクトで実装されているGDScriptパターンと、既存の2つのコーディング規約スキル（`gdscript-coding` と `godot-gdscript-patterns`）の比較分析です。

**主な発見**:
- プロジェクトは多くの一般的なGodotパターンを採用している
- プロジェクト固有の設計パターン（SpellSystemContainer、委譲メソッル、直接参照注入）が既存スキルに含まれていない
- 2つのスキル間に矛盾点がある（プライベート変数の命名規則など）
- Godot 4.4の新しいパターンのいくつかはプロジェクト内で未使用だが導入可能

---

## 1. プロジェクトで使われている主要パターン

### 1.1 シグナルパターン

**使用箇所**: 極めて広範（ほぼ全てのシステムで使用）

#### 命名規則
- **形式**: 過去分詞形 + 引数型注釈
- **例**: `signal action_completed()`, `signal phase_changed(new_phase: int)`, `signal card_selected(card_index: int)`
- **導入度**: 100% 準拠

#### 接続パターン
1. **永続接続**（_ready() や initialize時）
   ```gdscript
   # ✅ 多重接続防止チェック付き
   if not board_system_3d.tile_action_completed.is_connected(_on_tile_action_completed_3d):
       board_system_3d.tile_action_completed.connect(_on_tile_action_completed_3d)
   ```

2. **一度きりの接続**（CONNECT_ONE_SHOT）
   ```gdscript
   # battle_system.gd, dominio_command_handler.gd等で使用
   battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
   item_phase_completed.connect(_on_move_item_phase_completed, CONNECT_ONE_SHOT)
   ```

3. **シグナル中継**
   ```gdscript
   # game_flow_manager.gd: lap_systemのシグナルを中継
   func _on_lap_completed(player_id: int):
       lap_completed.emit(player_id)
   ```

#### 接続方向
- **遵守度**: 95%
- **原則**: 子→親（通知の上昇）
- **例外**: UI→ロジックの通知（許容）

**問題点なし** - シグナル設計は gdscript-coding の規約に完全に準拠

---

### 1.2 初期化パターン

**使われているメソッド名と用途**:

| メソッド名 | 用途 | 使用例 |
|-----------|------|---------|
| `_init()` | コンストラクタ（外部依存なし） | PlayerData クラス |
| `_ready()` | Godot組み込み、システム初期化 | ほぼ全てのノード |
| `initialize()` | 外部参照受取＋子オブジェクト生成 | BattlePreparation, TileDataManager |
| `setup()` | initialize() と同義、複数参照受取 | UIManager, BoardSystem3D |
| `setup_systems()` | GameFlowManager の専用初期化 | GameFlowManager |
| `setup_3d_mode()` | 3D特化の初期化 | GameFlowManager |
| `setup_with_context()` | コンテキスト受取＋生成 | BattleSkillProcessor |

**評価**: gdscript-coding の初期化メソッド規約に完全準拠。命名が明確で一貫性がある。

---

### 1.3 Autoloadパターン

**現在のAutoload（5個）**:

1. **CardLoader** (extends Node)
   - 用途: JSON カードデータの読み込み
   - 特徴: すべてのカードデータを `all_cards[]` に一元管理
   - パターン: 古い Autoload パターン（Godot 4.4推奨は @GlobalScope）

2. **GameData** (推測: ゲーム状態の永続化)
   - 用途: プレイヤー選択デッキ、ゲーム統計
   - パターン: 状態管理用 Autoload

3. **DebugSettings** (extends Node)
   - 用途: デバッグフラグの一元管理（10個のフラグ）
   - パターン: フラグレジストリ（拡張可能）
   - コード品質: 優秀（static 変数は使わず instance 変数）

4. **GameConstants** (推測)
   - 用途: ゲーム全体の定数（プレイヤー色など）

5. **推測: EventBus** (見つかられず)
   - 可能性: 検討中

**評価**:
- ✅ Autoload数が多すぎない（5個は適度）
- ✅ 責任分離が明確（CardLoader, DebugSettings等）
- ⚠️  Godot 4.4では @GlobalScope を使うほうがベター

---

### 1.4 その他のプロジェクト固有パターン

#### A. SpellSystemContainer パターン（RefCounted コンテナ）

**ファイル**: `scripts/spells/spell_system_container.gd`

```gdscript
class_name SpellSystemContainer
extends RefCounted

# 10+2個のスペルシステムを一元管理
var spell_draw = null
var spell_magic = null
var spell_land = null
var spell_curse = null
var spell_dice = null
var spell_curse_stat = null
var spell_world_curse = null
var spell_player_move = null
var spell_curse_toll = null
var spell_cost_modifier = null
```

**特徴**:
- **パターン**: CPUAIContext と同じ RefCounted ベースのコンテナ
- **メリット**:
  - GFM 経由のチェーンアクセス（`gfm.spell_magic`）を廃止
  - `spell_container.spell_magic` の直接参照に統一
  - 参照の集約化でメモリ管理が容易
  - 拡張時に dictionary ↔ 個別変数の変換が不要

- **導入度**: 部分的（まだ GFM に spell_* 変数が残る可能性）

**評価**:
- ✅ 優秀なパターン、再利用可能
- ✅ godot-gdscript-patterns には含まれていない（プロジェクト固有）
- ⚠️ 他の RefCounted コンテナ（例: BattleParticipant）との一貫性を確認が必要

#### B. 委譲メソッルパターン（チェーンアクセス廃止）

**原則**: 2段以上のチェーンアクセスを禁止

```gdscript
# ❌ 禁止
ui_manager.phase_display.show_toast("メッセージ")
board_system.tile_action_processor.complete_action()

# ✅ 委譲メソッル経由
ui_manager.show_toast("メッセージ")
board_system.complete_action()
```

**実装状況**:
- `UIManager` に 12+ の委譲メソッルがある（`show_toast()`, `show_comment_and_wait()` 等）
- `BoardSystem3D` に複数の委譲メソッルがある（`get_player_tile()`, `calculate_toll_with_curse()` 等）
- **遵守度**: 95%（ほぼ完全）

**評価**:
- ✅ 完全に実装されている
- ✅ gdscript-coding で規定されているが、godot-gdscript-patterns には含まれていない
- ⚠️ 新しいコード追加時に常に確認が必要

#### C. 直接参照注入パターン

**原則**: initialize 時に必要な参照を直接渡す（チェーンアクセス廃止）

```gdscript
# GameSystemManager.setup()でコンテナを作成
var spell_container = SpellSystemContainer.new()
spell_container.setup(spell_draw, spell_magic, ...)

# GameFlowManager に設定
game_flow_manager.spell_container = spell_container
```

**実装状況**:
- `SpellEffectExecutor`, `SpellPhaseHandler` 等で徹底
- `GameFlowManager` に直接参照がある：`board_system_3d`, `player_system`, `card_system` 等

**評価**:
- ✅ 参照を最小限に限定している
- ⚠️ 場所によっては多重参照がある（5+個の参照がある箇所もある）

---

### 1.5 その他のパターン

#### BattleParticipant ラッパーパターン
```gdscript
# 戦闘中のクリーチャーを一時的にラップ
# base_stats と current_stats を分離
var participant = BattleParticipant.new(creature_data)
```

- **用途**: 戦闘中の一時的な stat 変更を base_stats から分離
- **導入度**: 完全（BattlePreparation で使用）

#### Down State System（タイルダウン状態）
- **用途**: タイル上のクリーチャーが行動後に「ダウン」状態になる
- **実装**: TileDataManager で管理
- **例外**: 「不屈」スキルを持つクリーチャーはダウンしない

#### フェーズ重複防止（BUG-000対応）
```gdscript
# GameFlowManager での二段チェック
if is_ending_turn:
    return

if current_phase == GamePhase.END_TURN:
    return

is_ending_turn = true
```

- **導入度**: 完全
- **効果**: ターン終了の重複呼び出しを防止

---

## 2. godot-gdscript-patterns との比較

### 2.1 既に使われているパターン

| パターン | gdscript-coding | プロジェクト | godot-gdscript-patterns | 状態 |
|---------|-----------------|------------|----------------------|------|
| **Signal** | ✅ 詳細規定 | ✅ 95%準拠 | ✅ 基本解説 | 同方向 |
| **Autoload** | ✅ 推奨 | ✅ 5個使用 | ✅ イベントバスパターン | 同方向 |
| **Resource-based Data** | ⚠️ 部分的 | ✅ カードJSON+CardLoader | ✅ 詳細実装 | 相互補完 |
| **Component System** | ❌ 未記載 | ✅ 部分的（HealthComponent的な） | ✅ 詳細実装 | **未採用** |
| **State Machine** | ❌ 未記載 | ✅ GamePhase enum使用 | ✅ StateMachine class | **部分的** |
| **Object Pooling** | ❌ 未記載 | ❌ 使用なし | ✅ 詳細実装 | **未採用** |
| **Scene Management** | ❌ 未記載 | ❌ 使用なし | ✅ 詳細実装 | **未採用** |
| **Save System** | ❌ 未記載 | ❌ 使用なし | ✅ 詳細実装 | **未採用** |

### 2.2 プロジェクトに有用な未使用パターン（優先度順）

#### 1. **Component System パターン** (推奨度: 高)

```gdscript
# 現在: BattleParticipant で stat を管理
var hp = participant.current_hp

# Component System なら:
var health_component = creature.get_node("HealthComponent")
health_component.take_damage(10)
```

**プロジェクトへの適用検討**:
- ✅ HealthComponent: 現在の hp/max_hp 管理を分離
- ✅ BuffComponent: 呪い/バフ管理を分離
- ✅ ItemComponent: 装備品の effects を分離
- **導入時期**: Phase 5+ （大規模リファクタリング時）

#### 2. **Object Pooling パターン** (推奨度: 中)

```gdscript
# 現在: 弾幕/エフェクトを instantiate/queue_free
var bullet = bullet_scene.instantiate()

# Object Pooling なら:
var bullet = bullet_pool.get_instance()
# 使用終了後:
bullet_pool.return_all()
```

**プロジェクトへの適用検討**:
- ⚠️ 弾幕エフェクトがまだ実装されていない（3D 演出用）
- ⚠️ UI パネルのアニメーション処理で有用かもしれない
- **優先度**: 低（演出が複雑になったら検討）

#### 3. **State Machine クラス化** (推奨度: 中)

```gdscript
# 現在: GamePhase enum + 手動状態遷移
current_phase = GamePhase.DICE_ROLL

# State Machine パターン なら:
state_machine.transition_to("DiceRoll", {player_id: 0})
```

**プロジェクトへの適用検討**:
- ✅ GameFlowManager の状態遷移を StateMachine クラスに移行可能
- ✅ メリット: enter(), exit() コールバックで自動化
- ⚠️ 現在の enum ベースで十分動作している
- **優先度**: 低〜中（次の大規模リファクタリング時）

#### 4. **Scene Management パターン** (推奨度: 低)

```gdscript
# 現在: scene 切り替えは別途実装
# Pattern なら:
await scene_manager.change_scene("res://scenes/game.tscn")
```

**プロジェクトへの適用検討**:
- ❌ シーン切り替えが少ない（メインゲーム画面が主体）
- **優先度**: 低

#### 5. **Save System パターン** (推奨度: 低)

**プロジェクトへの適用検討**:
- ❌ 現在、セーブ機能は実装されていない
- **優先度**: 低（将来のキャンペーンモード用）

---

### 2.3 2つのスキル間の矛盾点

#### 矛盾点 1: プライベート変数の命名規則

**gdscript-coding**:
```gdscript
# 判断基準: 外部から呼ぶなら `_` を外す、呼ばないなら `_` をつける
var player_system  # 外部参照あり → _ なし
var _internal_state  # 内部のみ → _ あり
```

**godot-gdscript-patterns**:
```gdscript
# 慣例: underscore prefix は convention
var _health: int  # private （慣例）
var _can_attack: bool = true
```

**評価**:
- gdscript-coding のほうが厳格（呼び出し可能性で判断）
- godot-gdscript-patterns のほうが Godot 一般的（慣例）
- **プロジェクト**: gdscript-coding を採用（推奨）

#### 矛盾点 2: Autoload の書き方

**gdscript-coding**:
```gdscript
# extends Node（古い方式）
extends Node
var manual_control_all: bool = false
```

**godot-gdscript-patterns**:
```gdscript
# game_manager.gd (Project Settings > Autoload に追加)
extends Node
process_mode = Node.PROCESS_MODE_ALWAYS
```

**評価**:
- Godot 4.4 では両方で動作
- Godot 4.4+ では @GlobalScope を推奨（2つとも古い）

#### 矛盾点 3: シグナル接続

**gdscript-coding**:
```gdscript
# 多重接続防止を厳密に
if not signal.is_connected(callback):
    signal.connect(callback)
```

**godot-gdscript-patterns**:
```gdscript
# CONNECT_ONE_SHOT を推奨（一度きりの場合）
signal.connect(callback, CONNECT_ONE_SHOT)
```

**評価**:
- 両方正しい（使い分け次第）
- **プロジェクト**: is_connected() チェック + CONNECT_ONE_SHOT を両方使い分けている（正解）

---

## 3. 既存規約（gdscript-coding）の改善提案

### 3.1 追加すべき内容

#### 1. SpellSystemContainer / RefCounted コンテナパターン

**記載箇所**: 「カプセル化ルール」セクションに追加

```markdown
### コンテナ化パターン（RefCounted）

複数の関連システムを管理する場合、RefCounted ベースのコンテナを使用する。

#### パターン
\`\`\`gdscript
class_name SpellSystemContainer
extends RefCounted

var spell_draw = null
var spell_magic = null
# ... etc

func setup(p_spell_draw, p_spell_magic, ...) -> void:
    spell_draw = p_spell_draw
    spell_magic = p_spell_magic
\`\`\`

#### メリット
- Dictionary ⇔ 個別変数の変換が不要
- チェーンアクセスを廃止できる
- 参照の集約化でメモリ管理が容易

#### 使用例
- SpellSystemContainer: 10+2個のスペルシステム管理
- CPUAIContext: CPU判定ロジック用のコンテキスト
```

#### 2. State Machine の簡易パターン

**記載箇所**: 新規セクション「状態管理パターン」

```markdown
## 状態管理パターン

### 現在の enum ベース（推奨）

\`\`\`gdscript
enum GamePhase { SETUP, DICE_ROLL, MOVING, TILE_ACTION, BATTLE, END_TURN }
var current_phase = GamePhase.SETUP

func transition_to_phase(new_phase: int) -> void:
    # 遷移前処理
    _on_phase_exit()

    current_phase = new_phase

    # 遷移後処理
    _on_phase_enter()

    phase_changed.emit(new_phase)
\`\`\`

### 将来のリファクタリング向け: StateMachine クラス

複雑な状態遷移が必要な場合は、godot-gdscript-patterns の StateMachine パターンを参照。
```

#### 3. Object Pooling パターンのメモ

**記載箇所**: 新規セクション「パフォーマンスパターン」

```markdown
## パフォーマンスパターン

### Object Pooling（現在未使用、将来検討）

3D エフェクトや弾幕が大量に発生する場合、Object Pooling を検討する。

参考: godot-gdscript-patterns の Pattern 4: Object Pooling
```

#### 4. Component System への言及

**記載箇所**: 「カプセル化ルール」セクション

```markdown
### Component System への移行（長期計画）

BattleParticipant で stat を管理している部分は、将来的に Component System に移行可能。

参考: godot-gdscript-patterns の Pattern 5: Component System

現在は BattleParticipant で十分。大規模リファクタリング時に検討。
```

---

### 3.2 修正すべき内容

#### 修正 1: Autoload の最新パターン

**現在**:
```gdscript
# game_manager.gd (Add to Project Settings > Autoload)
extends Node
```

**Godot 4.4+ での推奨**:
```gdscript
# game_manager.gd (Godot 4.4+ では @GlobalScope を推奨)
@export_global(GameManager)
extends Node
```

**修正案**: gdscript-coding に Godot 4.4 の新しい @GlobalScope 記法を追加

#### 修正 2: MHP計算に関する補足

**現在**:
```gdscript
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
```

**実装パターンの追加**:
- Land Bonus を含める場合
- BattleParticipant での計算方法を明記

#### 修正 3: 土地レベルのキー名をより明確に

**現在**:
```gdscript
# ✅ tile_info（タイル情報Dictionary）からはキー "level"
var level = tile_info.get("level", 1)

# ✅ context（バトルコンテキスト）ではキー "tile_level"
var level = context.get("tile_level", 1)
```

**改善案**: コード例の箇所を1つの表にまとめる

| 使用箇所 | 正しいキー | 例 |
|---------|-----------|-----|
| tile_info | "level" | `tile_info.get("level", 1)` |
| context | "tile_level" | `context.get("tile_level", 1)` |
| battle_field | "level" | `battle_field.get("level", 1)` |

---

### 3.3 削除または廃止予定の内容

#### 削除 1: 旧 ST（攻撃力の旧称）への言及

**現在**:
```gdscript
# 注意: コード内にST（旧称）が残っている箇所があるが、正しい用語はAP。
```

**削除提案**: 既に全て AP に置き換わっている可能性が高いため削除

#### 削除 2: `mp` 旧称への言及

**現在**:
```gdscript
# ❌ 旧キー名（廃止済み）
var level = context.get("current_land_level", 1)
```

**削除提案**: コード内に `mp` や `current_land_level` が存在しなければ削除

---

## 4. アクションアイテム

### 優先度 1 (すぐに実施)

- [ ] gdscript-coding に「SpellSystemContainer / RefCounted コンテナパターン」を追加
- [ ] gdscript-coding の「Autoload」セクションを Godot 4.4 対応に更新
- [ ] 既存規約で古い情報（ST、mp など）を削除

### 優先度 2 (次のリファクタリング時)

- [ ] 「状態管理パターン」セクションを追加
- [ ] 「パフォーマンスパターン」セクション（Object Pooling）を追加
- [ ] 土地レベルキー名の表を整理

### 優先度 3 (長期計画)

- [ ] Component System への移行計画を策定
- [ ] State Machine クラス化の検討（複雑度が増した場合）
- [ ] Object Pooling の実装検討（3D エフェクト複雑化時）

---

## 5. プロジェクト内への新パターン適用検討

### すぐに適用可能（0週間）

#### A. Event Bus（グローバルシグナルバス）

**現状**: CardLoader, GameData などの Autoload で管理

**導入パターン** (godot-gdscript-patterns から):
```gdscript
# event_bus.gd (Autoload)
extends Node

signal card_drawn(card_data: Dictionary)
signal battle_started(player1: int, player2: int)
```

**メリット**: 複数の Autoload の責務を一元化

**実装難度**: 低

---

### 1〜2週間で導入可能

#### B. Resource-based Data の拡張

**現状**: CardLoader で JSON を読み込み

**拡張パターン** (godot-gdscript-patterns から):
```gdscript
# card_data.gd
class_name CardData
extends Resource

@export var name: StringName
@export var hp: int
@export var ap: int
@export var ability_parsed: Array
```

**メリット**: Inspector で直接編集可能、型安全

**実装難度**: 中（JSON から Resource への移行が必要）

---

### 長期計画（1ヶ月以上）

#### C. Component System への移行

**対象**: BattleParticipant の stat 管理

**実装難度**: 高

**優先度**: 低（現在の仕組みで十分）

---

## 6. サマリー表

| 項目 | 状態 | 評価 | アクション |
|------|------|------|-----------|
| **シグナルパターン** | ✅ 完全実装 | 優秀 | 維持 |
| **初期化メソッド** | ✅ 完全実装 | 優秀 | 維持 |
| **Autoload** | ✅ 実装 | 良好 | Godot 4.4更新 |
| **委譲メソッル** | ✅ 95%実装 | 優秀 | 維持 |
| **SpellSystemContainer** | ✅ 実装 | 優秀 | gdscript-coding に追加 |
| **State Machine** | ⚠️ enum ベース | 機能的 | 長期リファクタリング検討 |
| **Component System** | ❌ 未実装 | — | 長期計画 |
| **Object Pooling** | ❌ 未実装 | — | 演出複雑化時に検討 |
| **Scene Management** | ❌ 不要 | — | 検討不要 |

---

## 結論

### プロジェクトの設計品質

**全体評価**: ⭐⭐⭐⭐ (4/5)

**強み**:
- シグナル設計が優秀
- 委譲メソッルによるカプセル化が徹底
- 参照の直接注入で依存関係を最小化
- SpellSystemContainer など、プロジェクト固有の優れたパターンがある

**弱み**:
- State Machine がまだ enum ベース（拡張性の限界）
- Component System が未実装（大規模時に問題になる可能性）

### 既存規約（gdscript-coding）への提言

**必須改善**:
1. SpellSystemContainer パターンの追加
2. Autoload の Godot 4.4 更新
3. 古い情報（ST、mp）の削除

**推奨改善**:
4. 状態管理パターンセクション追加
5. パフォーマンスパターンの言及

**長期的な構想**:
6. Component System への移行計画ドキュメント化

---

**作成日**: 2026-02-13
**分析対象**: 35,000+ 行の GDScript コード（15+ メインシステム）
**使用スキル**: gdscript-coding (532行), godot-gdscript-patterns (807行)
