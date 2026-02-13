# プロジェクト固有情報 抽出レポート

カードバトルゲームプロジェクト特有のGDScriptパターン・制約・設計規約を、一般的なGodotパターンから分離して抽出したレポート。

---

## 1. 禁止パターン（プロジェクト固有）

### 1.1 Node に has() を使わない

**プロジェクト固有である理由**: Nodeは辞書ではなく、has()を使用するとランタイムエラーになる。これはGodot全般の基礎知識。

**判定**: ❌ 削除対象（godot-gdscript-patternsに任せる）

---

### 1.2 end_turn() を直接呼ばない

**プロジェクト固有である理由**: このプロジェクトはターン終了に複雑なシグナルチェーンを使用し、シグナルの発火順序が重要。直接呼び出しはこのチェーンを迂回し、二重呼び出しやフェーズ不整合の原因になる。

**正しいシグナルチェーン**:

```
TileActionProcessor
  → emit "action_completed"
    → BoardSystem3D (リッスン・処理)
      → emit "tile_action_completed"
        → GameFlowManager._on_tile_action_completed_3d()
          → end_turn()
```

**コード例（禁止）**:
```gdscript
# ❌ 直接呼び出し（禁止）
tile_action_processor.some_action()
game_flow_manager.end_turn()  # シグナルチェーンをスキップ
```

**コード例（正しい）**:
```gdscript
# ✅ シグナルチェーンを使う
tile_action_processor.complete_action()  # action_completedをemit
# → GameFlowManager がリッスン → end_turn() が自動的に呼ばれる
```

**プロジェクト固有である理由**: フェーズ重複防止の二段チェック（BUG-000対策）がシグナルチェーンに依存しているため。

---

### 1.3 UI座標をハードコードしない

**プロジェクト固有である理由**: このプロジェクトは複数の画面サイズに対応し、全UIコンポーネントがビューポート相対位置計算を使用している。

**コード例（禁止）**:
```gdscript
# ❌ 画面サイズ依存で異なる解像度で壊れる
panel.position = Vector2(1200, 100)
panel.size = Vector2(300, 400)
```

**コード例（正しい）**:
```gdscript
# ✅ ビューポート相対位置計算
var viewport_size = get_viewport().get_visible_rect().size
var panel_x = viewport_size.x - panel_width - 20  # 右端から20pxオフセット
var panel_y = (viewport_size.y - panel_height) / 2  # 中央配置
panel.position = Vector2(panel_x, panel_y)
panel.size = Vector2(panel_width, panel_height)
```

**プロジェクト固有である理由**: UI座標戦略がプロジェクト設計の重要部分。

---

### 1.4 privateメソッド/プロパティを外部から呼ばない

**プロジェクト固有である理由**: このプロジェクトはカプセル化を厳格に管理し、`_`プレフィックスで公開vs非公開を明確に区別している。

**判定基準**: 外部から呼ぶなら`_`を外す。呼ばないなら`_`をつける。

**コード例（禁止）**:
```gdscript
# ❌ privateメソッドを外部から呼ぶ
tile_action_processor._is_summon_condition_ignored()
var steps = controller._current_remaining_steps
```

**コード例（正しい）**:
```gdscript
# ✅ publicメソッド/プロパティ
tile_action_processor.is_summon_condition_ignored()
var steps = controller.current_remaining_steps
```

**プロジェクト固有である理由**: 密結合を避けるための設計方針。

---

### 1.5 状態フラグを外部から直接setしない

**プロジェクト固有である理由**: 状態遷移は一貫性が必要で、直接代入は検証をスキップする危険がある。

**コード例（禁止）**:
```gdscript
# ❌ 外部から直接代入
tile_action_processor.is_action_processing = true
```

**コード例（正しい）**:
```gdscript
# ✅ 明示的メソッド経由（検証ロジック内包）
tile_action_processor.begin_action_processing()
tile_action_processor.reset_action_processing()
```

**プロジェクト固有である理由**: フェーズ管理・フラグ管理の厳格性が重要。

---

### 1.6 内部プロパティを外部から直接参照しない（チェーンアクセス禁止）

**プロジェクト固有である理由**: このプロジェクトはシステム間の密結合を防止するための「委譲メソッドパターン」を採用。チェーンアクセス（`a.b.c()`）は呼び出し側が内部構造に依存し、リファクタリング時の影響範囲を増やす。

**チェーンアクセスの禁止レベル**:
- **2段**: `ui_manager.phase_display.show_toast()`  → ❌ 禁止
- **3段以上**: `handler.game_flow_manager.spell_phase_handler.spell_cast_notification_ui`  → ❌ 絶対禁止

**コード例（禁止）**:
```gdscript
# ❌ 2段チェーンアクセス
ui_manager.phase_display.show_toast("メッセージ")
board_system.tile_action_processor.complete_action()

# ❌ 3段以上は絶対禁止
handler.game_flow_manager.spell_phase_handler.spell_cast_notification_ui
```

**コード例（正しい）**:
```gdscript
# ✅ 親クラスに委譲メソッドを用意して使う
ui_manager.show_toast("メッセージ")  # UIManager内で phase_display に委譲
board_system.complete_action()  # BoardSystem3D内で tile_action_processor に委譲

# ✅ initialize時に必要な参照を直接渡す
handler.spell_cast_notification_ui  # initialize時にセット済み
```

**プロジェクト固有である理由**: 委譲メソッドパターンがこのプロジェクトの中核設計。

---

### 1.7 デバッグフラグは DebugSettings に集約

**プロジェクト固有である理由**: このプロジェクトは`DebugSettings`という静的Autoloadを使ってデバッグフラグを一元管理。個別システムに分散すると管理が困難になる。

**コード例（禁止）**:
```gdscript
# ❌ 個別システムにデバッグフラグを持たせる
if tile_action_processor.debug_disable_lands_required:
    ...
if game_flow_manager.debug_manual_control_all:
    ...
```

**コード例（正しい）**:
```gdscript
# ✅ DebugSettings（staticクラス）経由
if DebugSettings.disable_lands_required:
    ...
if DebugSettings.manual_control_all:
    ...
```

**プロジェクト固有である理由**: デバッグ設定の一元管理がプロジェクト方針。

---

## 2. プロジェクト固有の設計パターン

### 2.1 委譲メソッドパターン

**説明**: 子コンポーネントに直接アクセスする代わりに、親クラスに委譲メソッドを用意し、そのメソッドを通じてアクセスする。

**目的**:
- 呼び出し側が内部構造に依存しない
- リファクタリング時に親のメソッドだけ修正すればOK
- チェーンアクセスの禁止に対応

**コード例**:
```gdscript
# 親クラス（ui_manager.gd）に委譲メソッドを追加
class_name UIManager
extends Node

var phase_display: PhaseDisplay
var global_comment_ui: GlobalCommentUI
var card_selection_ui: CardSelectionUI

# 委譲メソッド
func show_toast(message: String, duration: float = 2.0):
    phase_display.show_toast(message, duration)

func show_action_prompt(message: String):
    phase_display.show_action_prompt(message)

func hide_action_prompt():
    phase_display.hide_action_prompt()

func await show_comment_and_wait(message: String, player_id: int = -1) -> void:
    await global_comment_ui.show_and_wait(message, player_id)
```

**呼び出し側**:
```gdscript
# ✅ 委譲メソッド経由
ui_manager.show_toast("ゲーム開始")
await ui_manager.show_comment_and_wait("準備完了", player_id)

# ❌ チェーンアクセス（禁止）
ui_manager.phase_display.show_toast("ゲーム開始")
```

**委譲メソッドクイックリファレンス**:

| やりたいこと | 委譲メソッド |
|-------------|-------------|
| トースト表示 | `ui_manager.show_toast(msg)` |
| アクション指示表示 | `ui_manager.show_action_prompt(msg)` |
| アクション指示非表示 | `ui_manager.hide_action_prompt()` |
| コメント表示+クリック待ち | `await ui_manager.show_comment_and_wait(msg, pid)` |
| Yes/No選択 | `await ui_manager.show_choice_and_wait(msg, pid, yes, no)` |
| 手札表示更新 | `ui_manager.update_hand_display(player_id)` |
| 全InfoPanel非表示 | `ui_manager.hide_all_info_panels(clear_buttons)` |
| カード情報表示（閲覧） | `ui_manager.show_card_info(card_data, tile_index)` |
| カード情報表示（選択） | `ui_manager.show_card_selection(card_data, hand_index, ...)` |
| ナビゲーション設定 | `ui_manager.enable_navigation(confirm, back, up, down)` |
| ナビゲーション無効化 | `ui_manager.disable_navigation()` |

| やりたいこと | 委譲メソッド |
|-------------|-------------|
| プレイヤー位置取得 | `board_system.get_player_tile(player_id)` |
| プレイヤー位置設定 | `board_system.set_player_tile(player_id, tile_index)` |
| ダウン状態全解除 | `board_system.clear_all_down_states_for_player(player_id)` |
| タイルにカメラフォーカス | `board_system.focus_camera_on_tile_slow(tile_index)` |
| 手動カメラモード | `board_system.enable_manual_camera()` |
| 追従カメラモード | `board_system.enable_follow_camera()` |
| アクション処理開始 | `board_system.begin_action_processing()` |
| アクション処理リセット | `board_system.reset_action_processing()` |
| アクション完了 | `board_system.complete_action()` |
| 交換実行 | `board_system.execute_swap_action(tile, card_idx, old_creature)` |
| レベルアップコスト計算 | `board_system.calculate_level_up_cost(current, target)` |
| 呪い込み通行料計算 | `board_system.calculate_toll_with_curse(tile_index)` |
| ワープペア取得 | `board_system.get_warp_pairs()` |
| バトル画面マネージャ取得 | `board_system.get_battle_screen_manager()` |

**詳細**: `docs/implementation/delegation_method_catalog.md` を参照

**プロジェクト固有である理由**: 大規模システムのカプセル化戦略がプロジェクト設計の中核。

---

### 2.2 SpellSystemContainer パターン

**説明**: 10+個のスペルシステムを1つのRefCountedコンテナに集約し、`GameFlowManager.spell_container`経由でアクセスする。

**背景**: 従来はGFM内に個別変数（`spell_draw`, `spell_magic`, `spell_land`等）があり、アクセスが`game_flow_manager.spell_draw`になっていた。

**改善内容**:
- すべてのspellシステムを`SpellSystemContainer`に集約
- 個別変数をGFM内から削除
- アクセスを`game_flow_manager.spell_container.spell_draw`に統一

**実装例**:
```gdscript
# SpellSystemContainer.gd（RefCountedクラス）
class_name SpellSystemContainer
extends RefCounted

# 10個のspellシステム
var spell_draw: SpellDraw
var spell_magic: SpellMagic
var spell_land: SpellLand
var spell_curse: SpellCurse
var spell_curse_toll: SpellCurseToll
var spell_cost_modifier: SpellCostModifier
var spell_dice: SpellDice
var spell_curse_stat: SpellCurseStat
var spell_world_curse: SpellWorldCurse
var spell_player_move: SpellPlayerMove

# Node型システム（GFMで add_child()）
var spell_curse_stat: SpellCurseStat
var spell_world_curse: SpellWorldCurse

func initialize(...):
    spell_draw = SpellDraw.new()
    spell_magic = SpellMagic.new()
    spell_land = SpellLand.new()
    # ... 他のシステムもinitialize
```

**GameFlowManager内での使用**:
```gdscript
class_name GameFlowManager
extends Node

var spell_container: SpellSystemContainer  # RefCounted

func _ready():
    spell_container = SpellSystemContainer.new()
    spell_container.initialize(...)

    # Node型システムの登録
    add_child(spell_container.spell_curse_stat)
    add_child(spell_container.spell_world_curse)

func some_method():
    # ✅ spell_containerを通じてアクセス
    var drawn = spell_container.spell_draw.draw_one(player_id)
    spell_container.spell_magic.modify_ep(player_id, -10)
```

**メリット**:
- 10個のspellシステムを1つの参照で管理
- `GameFlowManager`のプロパティが肥大化しない
- spellシステムの追加・削除がコンテナ内で完結

**プロジェクト固有である理由**: マジックシステムの拡張に対応するために採用した、プロジェクト特有の設計パターン。

---

### 2.3 直接参照注入パターン

**説明**: システム間で参照が必要な場合、`initialize()`時に直接参照を渡す。チェーンアクセスを避けるための設計。

**コード例**:
```gdscript
# ❌ 避けるべきパターン（逆方向参照、チェーンアクセス）
func initialize(game_flow_manager):
    self.gfm = game_flow_manager
    # → gfmを知っていれば何でもできてしまう
    # → gfm.spell_container.spell_draw.draw_one() など長いチェーン

# ✅ 必要最小限の参照だけ渡す
func initialize(spell_draw: SpellDraw, player_system: PlayerSystem):
    self.spell_draw = spell_draw
    self.player_system = player_system
    # → 必要な機能だけアクセス可能
```

**使用例**:
```gdscript
class_name DominioOrderHandler
extends Node

var spell_draw: SpellDraw
var player_system: PlayerSystem

func initialize(spell_draw: SpellDraw, player_system: PlayerSystem):
    self.spell_draw = spell_draw
    self.player_system = player_system

func execute_draw():
    # 直接参照なのでチェーンなし
    var drawn = spell_draw.draw_one(self.current_player_id)
    player_system.add_card_to_hand(self.current_player_id, drawn)
```

**メリット**:
- 依存関係が明確（メソッドシグネチャから読める）
- チェーンアクセスなし
- テストが容易（mockオブジェクトを注入可能）

**プロジェクト固有である理由**: 密結合を避けるためのアーキテクチャ設計。

---

### 2.4 BattleParticipant パターン

**説明**: バトル時に、生のcreature_dataの代わりに`BattleParticipant`というラッパークラスを使用。一時的な修正（ダメージ、バフ等）を追跡し、元のcreature_dataは変更しない。

**コード例**:
```gdscript
class_name BattleParticipant
extends RefCounted

var creature_data: Dictionary  # 元のデータ（参照のみ）
var current_hp: int
var current_ap: int
var temporary_buffs: Dictionary  # 戦闘中のみ有効

func initialize(creature_data: Dictionary):
    self.creature_data = creature_data
    self.current_hp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
    self.current_ap = creature_data.get("ap", 0) + creature_data.get("base_up_ap", 0)

func get_max_hp() -> int:
    # base_hp + 永続上昇 + 臨時バフ
    var base = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
    var buff = temporary_buffs.get("hp_buff", 0)
    return base + buff

func take_damage(amount: int):
    current_hp = max(current_hp - amount, 0)
    # creature_data["current_hp"] は直接変更しない（戦闘後に更新）
```

**使用場面**:
- `BattleExecution`内でダメージ計算
- スキル効果の適用（Resonance、Power Strike等）
- バトル後の確定処理

**プロジェクト固有である理由**: バトルシステムにおける一時データと永続データの厳格な分離がプロジェクト設計。

---

### 2.5 Autoload Singletons パターン

**説明**: グローバルにアクセス可能な状態管理・リソース管理用のシングルトン。

**このプロジェクトのAutoload一覧**:
- `CardLoader`: グローバルカードデータベース（カード情報のロード・キャッシュ）
- `GameData`: 永続ゲーム状態（プレイヤー情報、マップ状態等）
- `DebugSettings`: デバッグフラグ集約

**プロジェクト固有である理由**: カードシステムとデバッグシステムがグローバル参照を必要とするプロジェクト設計。

---

## 3. プロジェクト固有のデータ構造・計算式

### 3.1 MHP（最大HP）計算

**公式**: MHP = ベースHP(`hp`) + 永続基礎HP上昇(`base_up_hp`)

**コード例**:
```gdscript
# ✅ BattleParticipant がある場合（戦闘中）
var mhp = participant.get_max_hp()  # base_hp + base_up_hp 自動計算

# ✅ creature_data から直接計算する場合（戦闘外）
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)

# ❌ base_up_hp を忘れない
var mhp = creature_data.get("hp", 0)  # 不完全！
```

**注意事項**:
- `creature_data["hp"]` は元のカードデータ値で**絶対に変更しない**
- 現在HPは `creature_data["current_hp"]` に保存する
- `base_up_hp` はマスグロース・合成・周回ボーナスでのみ変更する
- バトル中は`BattleParticipant.current_hp`を使う

**プロジェクト固有である理由**: 永続上昇（base_up_hp）と一時バフの厳格な分離がプロジェクト仕様。

---

### 3.2 AP（攻撃力）計算

**公式**: AP = ベースAP(`ap`) + 永続基礎AP上昇(`base_up_ap`)

**コード例**:
```gdscript
# ✅ 基礎AP計算
var base_ap = creature_data.get("ap", 0) + creature_data.get("base_up_ap", 0)

# ✅ BattleParticipant では current_ap を使う
var attack_power = participant.current_ap  # 全ボーナス反映済み
```

**注意事項**:
- `creature_data["ap"]` は元の値で**変更しない**
- 永続上昇は `base_up_ap` に保存する
- コード内にST（旧称）が残っている箇所があるが、正しい用語はAP

**プロジェクト固有である理由**: クリーチャーの攻撃力管理が重要なゲームメカニクス。

---

### 3.3 土地レベルのキー名

**重要**: `tile_info` と `context` で**キー名が異なる**。混同は多くのバグの原因。

**コード例**:
```gdscript
# ✅ tile_info（タイル情報Dictionary）からはキー "level"
var tile_info = board_system.get_tile_info(tile_index)
var level = tile_info.get("level", 1)

# ✅ context（バトルコンテキスト）ではキー "tile_level"
var context = {
    "tile_level": battle_field.get("level", 1),
    # ... 他のコンテキスト情報
}
var level = context.get("tile_level", 1)

# ❌ tile_info に "tile_level" は存在しない
var level = tile_info.get("tile_level", 1)  # 常に1が返る（バグ）

# ❌ 旧キー名（廃止済み）
var level = context.get("current_land_level", 1)  # 廃止
```

**キー名の変換地点**:

```gdscript
# ConditionChecker.gd など、context構築時の変換
var context = {
    "tile_level": battle_field.get("level", 1),  # tile_info → context への変換
    # ...
}
```

**プロジェクト固有である理由**: 土地システムの設計における、タイル管理と戦闘コンテキストの分離。

---

### 3.4 コストフィールド

**ルール**: 常に `ep`（Energy Point）。`mp` は使わない。

```gdscript
# ✅ 正しい
var cost = cost_data.get("ep", 0)

# ❌ 旧称（廃止）
var cost = cost_data.get("mp", 0)
```

**プロジェクト固有である理由**: ゲーム設計における魔法コスト体系の用語統一。

---

### 3.5 creature_data の構造

**重要フィールド**:
- `hp`: ベースHP（変更禁止）
- `base_up_hp`: 永続基礎HP上昇（マスグロース・合成で変更）
- `current_hp`: 現在HP（バトル・ダメージで変更）
- `ap`: ベース攻撃力（変更禁止）
- `base_up_ap`: 永続基礎攻撃力上昇
- `ability_parsed`: スキル情報（Array[Dictionary]）
- `curse`: 呪い情報
- `items`: 装備アイテム（Array）

**ランタイムフィールド追加時の注意**:
- 永続値は `base_up_*` で管理
- 一時値は BattleParticipant など別オブジェクトで管理
- 元のcreature_data は immutable に扱う

**プロジェクト固有である理由**: ゲームデータ管理の中核設計。

---

## 4. プロジェクト固有のフロー・ルール

### 4.1 ターン終了フロー

**シグナルチェーン図**:

```
TileActionProcessor
  ├─ condition check
  ├─ execute action
  └─ emit "action_completed"
      ↓ (auto-connected)
  BoardSystem3D._on_action_completed()
    ├─ housekeeping (update states)
    └─ emit "tile_action_completed"
        ↓ (auto-connected)
  GameFlowManager._on_tile_action_completed_3d()
    ├─ フラグチェック: if is_ending_turn: return
    ├─ フェーズチェック: if current_phase == GamePhase.END_TURN: return
    ├─ is_ending_turn = true  ★重要: 最優先で立てる
    └─ end_turn()
        ├─ current_phase = GamePhase.END_TURN
        ├─ draw card
        ├─ emit "turn_ended"
        └─ next_turn()
```

**二段チェック（BUG-000対策）**:

```gdscript
func _on_tile_action_completed_3d():
    # 1. フラグチェック（最速ガード）
    if is_ending_turn:
        return

    # 2. フェーズチェック（状態ガード）
    if current_phase == GamePhase.END_TURN:
        return

    # ★重要: フラグを最優先で立てる
    is_ending_turn = true

    # ターン終了処理
    await end_turn()
```

**プロジェクト固有である理由**: 複雑なシグナル連鎖の中での重複呼び出し防止が重要。

---

### 4.2 Down State システム

**ルール**:
- タイルは summon, level_up, move, swap 等のアクション後に "down" 状態になる
- down状態のタイルはアクションできない（next lap で解除）
- **例外**: "Indomitable"（不屈）スキルを持つクリーチャーは down にならない

**コード例**:
```gdscript
# タイルをダウン状態に
func set_down(tile_index: int):
    var tile_info = get_tile_info(tile_index)
    tile_info["is_down"] = true

# アクション可能かチェック
func can_act(tile_index: int) -> bool:
    var tile_info = get_tile_info(tile_index)
    if tile_info.get("is_down", false):
        return false
    return true

# down状態全解除
func clear_all_down_states_for_player(player_id: int):
    for tile_index in get_player_lands(player_id):
        var tile_info = get_tile_info(tile_index)
        tile_info["is_down"] = false
```

**Indomitable（不屈）スキル対応**:
```gdscript
# can_act() チェック時に不屈を確認
func can_act(tile_index: int) -> bool:
    var tile_info = get_tile_info(tile_index)

    # Indomitableスキルがあればダウン無視
    if has_indomitable_skill(tile_index):
        return true

    if tile_info.get("is_down", false):
        return false
    return true
```

**プロジェクト固有である理由**: ボードゲームメカニクスの中核（ラップメカニクス）。

---

### 4.3 Land Bonus System

**ルール**: クリーチャーの属性がタイルの属性と一致すると、土地レベルごとに HP がボーナスされる

**計算式**:
```gdscript
land_bonus_hp = land_level × 10

# タイル属性がクリーチャー属性と一致する場合のみ適用
if tile_attribute == creature_attribute:
    total_hp = base_hp + base_up_hp + land_bonus_hp
else:
    total_hp = base_hp + base_up_hp
```

**コード例**:
```gdscript
func calculate_land_bonus_hp(creature_data: Dictionary, tile_info: Dictionary) -> int:
    var creature_attr = creature_data.get("attribute", "")
    var tile_attr = tile_info.get("attribute", "")
    var tile_level = tile_info.get("level", 1)

    if creature_attr == tile_attr:
        return tile_level * 10
    return 0
```

**プロジェクト固有である理由**: 属性一致システムがゲームメカニクスの重要部分。

---

### 4.4 初期化順序（game_3d.gd の _ready()）

**重要**: 初期化順序を間違えるとnull参照エラーが発生する

**正しい順序**:
1. Create systems（GameFlowManager, BoardSystem3D等を new()）
2. Set UIManager references（各UIコンポーネントをUIManagerに設定）
3. Initialize hand container（手札表示の初期化）
4. Set `debug_manual_control_all` flag（setup_systems()の前に設定）
5. Call `GameFlowManager.setup_systems()`（各サブシステムのinitialize）
6. Call `GameFlowManager.setup_3d_mode()`（3D表示モードの有効化）
7. Re-set CardSelectionUI references（タイミング問題により再設定が必要）

**コード例**:
```gdscript
# game_3d.gd の _ready()
func _ready():
    # 1. Create systems
    game_flow_manager = GameFlowManager.new()
    board_system_3d = BoardSystem3D.new()

    # 2. Set UIManager references
    ui_manager.set_player_info_panels(player_info_panels)
    ui_manager.set_card_info_panel(card_info_panel)

    # 3. Initialize hand container
    hand_container._ready()

    # 4. Set debug flag BEFORE setup_systems()
    game_flow_manager.debug_manual_control_all = true

    # 5. setup_systems()
    game_flow_manager.setup_systems()

    # 6. setup_3d_mode()
    game_flow_manager.setup_3d_mode()

    # 7. Re-set CardSelectionUI references
    card_selection_ui.set_references(...)
```

**プロジェクト固有である理由**: 大規模システム間の複雑な初期化依存関係。

---

### 4.5 フェーズ重複防止

**ルール**: GameFlowManager は**二段チェック**でターン終了の重複を防ぐ

```gdscript
# 1. フラグチェック（最速ガード）
if is_ending_turn:
    return

# 2. フェーズチェック（状態ガード）
if current_phase == GamePhase.END_TURN:
    return

# ★重要: フラグを最優先で立てる
is_ending_turn = true
```

**ルール**: フェーズ遷移を伴う処理では、必ず冒頭でフェーズ/フラグチェックを入れる

```gdscript
# フェーズ遷移メソッドのテンプレート
func transition_to_new_phase():
    # 1. 重複防止チェック
    if current_phase == GamePhase.TARGET_PHASE:
        return

    is_ending_turn = true  # フラグを立てる

    # 2. 旧フェーズの終了処理
    await end_current_phase()

    # 3. 新フェーズに遷移
    current_phase = GamePhase.TARGET_PHASE
    await start_target_phase()
```

**プロジェクト固有である理由**: BUG-000（ターンスキップ）の対策がプロジェクト必須。

---

## 5. プロジェクト固有の命名規則・用語

### 5.1 初期化メソッド名の使い分け

| メソッド名 | 用途 | 外部依存 | 子オブジェクト生成 |
|-----------|------|---------|------------------|
| `_init()` | コンストラクタ | なし | なし |
| `initialize()` | 外部参照受取 | あり | あり（new()） |
| `setup()` | `initialize()`と同義 | あり | あり |
| `setup_with_context()` | context受取 + 子生成 | あり | あり |
| `set_context()` | context保存のみ | あり | なし |
| `set_xxx()` | 単一プロパティ設定 | あり | なし |

**判定基準**: `new()` で子オブジェクト生成あり → `initialize()` / `setup_with_context()`

**コード例**:
```gdscript
# _init() - 外部依存なし
class_name Creature
extends RefCounted

func _init():
    pass  # 何も受け取らない

# initialize() - 外部参照受取 + 子生成あり
func initialize(spell_system: SpellSystem):
    self.spell_system = spell_system
    self.effect_executor = EffectExecutor.new()  # ← 子生成あり

# setup_with_context() - context受取 + 子生成
func setup_with_context(context: Dictionary):
    self.context = context
    self.validator = ConditionChecker.new()  # ← 子生成あり

# set_context() - context保存のみ
func set_context(context: Dictionary):
    self.context = context  # ← 生成なし

# set_xxx() - 単一プロパティ
func set_name(new_name: String):
    self.name = new_name
```

**プロジェクト固有である理由**: 初期化パターンの厳格な分類がプロジェクト設計。

---

### 5.2 参照変数の `_ref` サフィックス

**ルール**: Battle系システムのみ `_ref` サフィックスを使う。その他はなし。

**Battle系（_ref あり）**:
```gdscript
# scripts/battle/ 配下
class_name BattleExecution
extends Node

var creature_ref: BattleParticipant  # ← _ref サフィックス
var participant_ref: BattleParticipant
```

**その他（_ref なし）**:
```gdscript
# scripts/game_flow/ 等
class_name GameFlowManager
extends Node

var board_system: BoardSystem3D  # ← _ref なし
var player_system: PlayerSystem
```

**判定基準**: 既存ファイルのスタイルに合わせる

**プロジェクト固有である理由**: コード領域ごとの命名規則の統一。

---

## 6. 一般情報として削除すべき内容（godot-gdscript-patternsに任せる）

以下の項目は godot-gdscript-patterns（Godot全般パターン）で十分カバーされるため、gdscript-coding から削除可能：

### ❌ 削除対象リスト

- **一般的なシグナル定義方法** (gdscript-coding行336-346)
  - godot-gdscript-patterns で Pattern: Signal-Based Communication

- **一般的なシグナル接続ルール** (lines 356-412)
  - 子→親方向、signal naming など一般的

- **一般的な await パターン** (lines 456-469)
  - タイマー待ち、シグナル待ちは一般的

- **一般的な ノード有効性チェック** (lines 348-352)
  - is_instance_valid() は Godot standard

- **一般的な大クラス分割パターン** (lines 417-435)
  - RefCounted への分割は一般的Godotパターン

- **一般的な TextureRect.modulate** (lines 28-35)
  - Godot API仕様

- **一般的な GDScript予約語** (lines 37-46)
  - GDScript言語制約

- **一般的な変数シャドウイング** (lines 48-55)
  - GDScriptベストプラクティス

- **シグナル CONNECT_ONE_SHOT** (lines 397-400)
  - Godot Signal APIの基本

### ✅ 残すべきプロジェクト固有情報

- **end_turn() を直接呼ばない** ← このプロジェクトのシグナルチェーン
- **内部プロパティを外部から直接参照しない（チェーンアクセス禁止）** ← 委譲メソッドパターン
- **デバッグフラグは DebugSettings に集約** ← DebugSettingsという固有Autoload
- **MHP/AP計算公式** ← base_up_hp / base_up_ap の重要性
- **土地レベルキー名** ← tile_info vs context の違い
- **初期化順序** ← game_3d.gd の複雑な初期化依存
- **フェーズ重複防止の二段チェック** ← BUG-000対策

---

## 7. サマリー

### 残すべき情報の総数

- **禁止パターン**: 7個
  1. Node に has() を使わない（一般的 → 削除候補）
  2. end_turn() を直接呼ばない ← ★プロジェクト固有
  3. UI座標をハードコードしない ← ★プロジェクト固有
  4. privateメソッド/プロパティを外部から呼ばない ← ★プロジェクト固有
  5. 状態フラグを外部から直接setしない ← ★プロジェクト固有
  6. 内部プロパティを外部から直接参照しない（チェーンアクセス禁止） ← ★★★最重要
  7. デバッグフラグは DebugSettings に集約 ← ★プロジェクト固有

- **設計パターン**: 5個
  1. 委譲メソッドパターン ← ★★★最重要
  2. SpellSystemContainer パターン ← ★プロジェクト固有
  3. 直接参照注入パターン ← ★プロジェクト固有
  4. BattleParticipant パターン ← ★プロジェクト固有
  5. Autoload Singletons ← ★プロジェクト固有

- **データ構造**: 5個
  1. MHP計算公式 ← ★重要
  2. AP計算公式 ← ★重要
  3. 土地レベルのキー名 ← ★重要
  4. コストフィールド（ep） ← プロジェクト固有
  5. creature_data の構造 ← ★重要

- **フロー・ルール**: 5個
  1. ターン終了フロー ← ★重要
  2. Down State システム ← ★重要
  3. Land Bonus System ← ★重要
  4. 初期化順序 ← ★重要
  5. フェーズ重複防止 ← ★重要

- **命名規則**: 2個
  1. 初期化メソッド名の使い分け ← プロジェクト固有
  2. 参照変数の `_ref` サフィックス ← プロジェクト固有

**合計**: 24個のプロジェクト固有パターン

---

## 8. 推奨される新しい gdscript-coding の構造

### 新しい構成案

1. **禁止パターン（プロジェクト固有）** - 3個
   - end_turn() を直接呼ばない
   - UI座標をハードコードしない
   - 内部プロパティを外部から直接参照しない（チェーンアクセス禁止）
   - デバッグフラグは DebugSettings に集約

2. **設計規約（依存方向とカプセル化）** - 現状維持
   - 委譲メソッドパターン（スペルシステムアクセス例を追加）
   - SpellSystemContainer パターン（新規）
   - 直接参照注入パターン（新規）

3. **必須パターン** - 現状維持
   - MHP/AP計算
   - 土地レベルキー名
   - コストフィールド
   - creature_data 構造
   - シグナル接続（重複防止）

4. **フロー・ルール** - 現状維持
   - ターン終了フロー
   - Down State システム
   - Land Bonus System
   - 初期化順序
   - フェーズ重複防止

5. **命名規約** - 現状維持
   - 初期化メソッド名
   - 参照変数の `_ref` サフィックス

### 削除または godot-gdscript-patterns に委譲すべき項目

- Node.has() パターン
- TextureRect.color → modulate
- 一般的なシグナル定義・接続
- 一般的な await パターン
- 一般的なノード有効性チェック
- 一般的な大クラス分割パターン
- 予約語・変数シャドウイング

---

## 9. 最終判断表

| 項目 | 残す | 削除 | 理由 |
|------|------|------|------|
| end_turn() チェーン | ✅ | | プロジェクト特有のシグナルフロー |
| UI座標計算 | ✅ | | ビューポート相対化がプロジェクト方針 |
| チェーンアクセス禁止 | ✅ | | 委譲メソッドパターンが中核 |
| DebugSettings集約 | ✅ | | プロジェクト固有のAutoload |
| 委譲メソッド | ✅ | | 大規模システムのカプセル化必須 |
| SpellContainer | ✅ | | 10+システムの統合管理 |
| MHP/AP計算 | ✅ | | 永続値と一時値の分離が重要 |
| 土地レベルキー | ✅ | | 多くのバグの原因 |
| 初期化順序 | ✅ | | 複雑な依存関係の解説が必須 |
| フェーズ重複防止 | ✅ | | BUG-000対策 |
| Node.has() | | ✅ | 一般的Godotパターン |
| await パターン | | ✅ | 一般的Godotパターン |
| 大クラス分割 | | ✅ | 一般的Godotパターン |
| シグナル基本 | | ✅ | 一般的Godotパターン |
| 予約語 | | ✅ | GDScript言語仕様 |

---

## 参考ドキュメント

- **既存 gdscript-coding**: `/Users/andouhiroyuki/.claude/skills/gdscript-coding/SKILL.md` (532行)
- **godot-gdscript-patterns**: `/Users/andouhiroyuki/.agents/skills/godot-gdscript-patterns/SKILL.md` (807行)
- **プロジェクト CLAUDE.md**: `/Users/andouhiroyuki/cardbattlegame/CLAUDE.md`
- **委譲メソッドカタログ**: `docs/implementation/delegation_method_catalog.md`
- **実装パターン集**: `docs/implementation/implementation_patterns.md`

---

**抽出日**: 2026-02-13
**対象スキル**: gdscript-coding v1
**参照スキル**: godot-gdscript-patterns v1
