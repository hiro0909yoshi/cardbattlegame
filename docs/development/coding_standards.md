---
name: gdscript-coding
description: GDScript (Godot 4.4) のコード生成・編集時に適用するコーディング規約とベストプラクティス。GDScriptファイルの作成・修正、Godotプロジェクトのコード作業全般で使用する。
---

# GDScript Coding Skill (Godot 4.4)

カードバトルゲームプロジェクト向けのGDScriptコーディング規約。
コード生成・編集時は必ずこのルールに従うこと。

## 禁止パターン（最重要）

以下は絶対にやってはいけない。違反するとランタイムエラーになる。

### 1. Node に has() を使わない
```gdscript
# ❌ has()はDictionary専用。Nodeには存在しない
if tile.has("property"):  # Error!

# ✅ 直接プロパティアクセス
if tile.property:
var value = tile.property

# ✅ Dictionaryなら has() OK
if dict.has("key"):
```

### 2. TextureRect に color を使わない
```gdscript
# ❌ color プロパティは存在しない
texture_rect.color = Color.RED

# ✅ modulate を使う
texture_rect.modulate = Color.RED
```

### 3. Godot予約語を変数名にしない
```gdscript
# ❌ 予約語
var owner: int
func is_processing()

# ✅ 別名にする
var tile_owner_id: int
func is_battle_active() -> bool
```

### 4. 変数シャドウイングしない
```gdscript
# ❌ クラスメンバと同名のローカル変数
var player_system = ...  # クラスにも player_system がある場合

# ✅ 別名
var p_system = ...
```

### 5. end_turn() を直接呼ばない
```
正しいシグナルチェーン:
TileActionProcessor → emit "action_completed"
  → BoardSystem3D → emit "tile_action_completed"
	→ GameFlowManager._on_tile_action_completed_3d() → end_turn()
```

### 6. UI座標をハードコードしない
```gdscript
# ❌ 画面サイズ依存で壊れる
panel.position = Vector2(1200, 100)

# ✅ ビューポート相対
var viewport_size = get_viewport().get_visible_rect().size
panel.position = Vector2(
	viewport_size.x - panel_width - 20,
	(viewport_size.y - panel_height) / 2
)
```

### 7. privateメソッド/プロパティを外部から呼ばない
```gdscript
# ❌ _プレフィックスのメソッドを外部から呼ぶ
tile_action_processor._is_summon_condition_ignored()
var steps = controller._current_remaining_steps

# ✅ publicメソッド/プロパティにするか、getterを用意
tile_action_processor.is_summon_condition_ignored()
var steps = controller.current_remaining_steps
```

**判断基準**: 外部から呼ぶなら`_`を外す。呼ばないなら`_`をつける。厳格に区別する。

### 8. 状態フラグを外部から直接setしない
```gdscript
# ❌ 外部から直接代入
tile_action_processor.is_action_processing = true

# ✅ 明示的メソッド経由
tile_action_processor.begin_action_processing()
tile_action_processor.reset_action_processing()
```

### 9. チェーンアクセスは2段まで（3段以上禁止）
```gdscript
# ✅ 許容: 公開サービス経由の2段チェーン
ui_manager.message_service.show_toast("メッセージ")
board_system.tile_data_manager.get_tile_info(idx)

# ✅ より良い: 直接注入済みなら1段
_message_service.show_toast("メッセージ")

# ❌ 禁止: 内部コンポーネントへの侵入（2段目が private）
ui_manager.phase_display._internal_label.text = "..."

# ❌ 禁止: 3段以上のチェーン
handler.game_flow_manager.spell_container.spell_draw.draw_one()

# ✅ 3段が必要な場合は initialize 時に直接参照を渡す
handler.spell_draw.draw_one()  # initialize時にセット済み
```

**判断基準**: 2段目が `_` プレフィックスなしの公開プロパティ/サービスなら許容。内部実装への侵入は1段でも禁止。

### 10. デバッグフラグは DebugSettings に集約
```gdscript
# ❌ 個別システムにデバッグフラグを持たせる
if tile_action_processor.debug_disable_lands_required: ...

# ✅ DebugSettings（staticクラス）経由
if DebugSettings.disable_lands_required: ...
```

---

## 設計規約（依存方向とカプセル化）

新しいコードを書く前に必ず確認すること。
これらを守らないと密結合・循環参照が蓄積し、修正困難になる。

### 依存方向の原則

**上位→下位の一方向参照が原則。逆方向は禁止。**

```
正しい依存方向（上から下へ）:

  GameSystemManager（最上位・初期化のみ）
	↓ initialize時に参照を注入
  GameFlowManager / BoardSystem / UIManager / PlayerSystem
	↓
  子ハンドラ / 子コンポーネント
```

#### ルール

1. **上位→下位**: メソッド呼び出しで直接操作。OK
2. **下位→上位**: シグナルで通知。直接参照は禁止
3. **同レベル横方向**: initialize時に参照を注入。OK（ただし最小限に）
4. **子→親の親**: 禁止。必要な情報はinitialize時に渡す

```gdscript
# ❌ 子が親の親を参照（逆方向）
var toll = game_system_manager.board_system_3d.spell_curse_toll.get_modifier()

# ❌ get_tree()で上位を辿る（最悪パターン）
var gsm = get_tree().root.get_node_or_null("GameSystemManager")

# ✅ initialize時に必要な参照を渡す
func initialize(spell_curse_toll: SpellCurseToll):
	self.spell_curse_toll = spell_curse_toll
```

### 兄弟参照の許容範囲

同レベルのシステム間（兄弟関係）での参照ルール。相互参照は禁止だが、片方向の参照は用途に応じて許容する。

```gdscript
# ✅ 許容: 表示系の片方向参照（表示依頼・読み取り）
# BoardSystem3D → MessageService
_message_service.show_toast("移動完了")

# ✅ 許容: 読み取り専用の参照
# BattleSystem → PlayerSystem
var data = player_system.get_player_data(player_id)

# ❌ 禁止: 相互参照（循環依存）
# A → B かつ B → A の経路が存在する

# ❌ 禁止: 兄弟のロジック状態を変更
# BoardSystem3D が PlayerSystem の状態を直接書き換える
player_system.set_magic(player_id, 100)  # → 上位（GFM）経由で行う
```

| パターン | 許容 | 例 |
|---------|:---:|-----|
| 表示系の片方向参照 | ✅ | System → MessageService, NavigationService |
| 読み取り専用の参照 | ✅ | System → PlayerSystem.get_*() |
| 相互参照（循環） | ❌ | A → B かつ B → A |
| 兄弟の状態変更 | ❌ | System → OtherSystem.set_*() |

### 新しい参照を追加する前のチェック

**参照を追加するたびに以下を確認する:**

1. **方向は正しいか？** 上位→下位、または同レベル横方向か
2. **最小限か？** システム全体でなく、必要なコンポーネントだけ渡しているか
3. **循環しないか？** A→B→A の経路ができないか
4. **チェーンにならないか？** `a.b.c()` のようなアクセスが発生しないか
5. **5つ以上のシステムに依存しないか？** 依存過多は設計を見直すサイン。ただし依存の**方向**も重要。同レイヤー依存5つは許容範囲だが、UI依存3 + ロジック依存2のようにレイヤーをまたぐ依存が混在する場合は危険信号

```gdscript
# ❌ 「動けばいい」で安易に参照を追加
func initialize(game_flow_manager):
	self.gfm = game_flow_manager
	# → gfmを知っていれば何でもできてしまう

# ✅ 必要最小限の参照だけ渡す
func initialize(spell_cost_modifier, lap_system):
	self.spell_cost_modifier = spell_cost_modifier
	self.lap_system = lap_system
```

### UI/ロジック境界

**UIコンポーネントはロジック上位を直接参照しない。**

```gdscript
# ❌ UIがGameFlowManagerを参照してデバッグフラグを見る
if game_flow_manager_ref.debug_manual_control_all: ...

# ✅ DebugSettingsで済む
if DebugSettings.manual_control_all: ...

# ❌ UIが直接ロジックを操作
card_selection_ui.game_flow_manager.start_battle()

# ✅ シグナルで上位に通知 → 上位がロジックを実行
card_selection_ui.emit_signal("battle_requested")
# → UIManager → GameFlowManager.start_battle()
```

### 委譲メソッドのパターン

外部から子コンポーネントにアクセスする必要がある場合、親に委譲メソッドを追加する。

```gdscript
# 親クラス（ui_manager.gd）に委譲メソッドを追加
func show_toast(message: String, duration: float = 2.0):
	phase_display.show_toast(message, duration)

func show_comment_and_wait(message: String, player_id: int = -1) -> void:
	await global_comment_ui.show_and_wait(message, player_id)

# 呼び出し側は親のメソッドを使う
ui_manager.show_toast("メッセージ")  # ✅
ui_manager.phase_display.show_toast("メッセージ")  # ❌
```

### 委譲メソッドを作るべきか判断基準

| 条件 | 判断 |
|------|------|
| 3ファイル以上から呼ばれている | 委譲メソッドを作る |
| 1〜2ファイルからのみ | initialize時に直接参照を渡すか、委譲メソッドを作る |
| 親が肥大化しすぎる | 直接参照をinitialize時に渡す |
| 機能的に密結合（dominio系等） | 直接参照を許容。ただしチェーンは2段まで |

### ドメイン機能群の密結合許容

同じドメイン機能群に属するクラス間では、密結合を許容する。
ただし**UI操作の分離**と**他ドメインへの参照制限**は維持すること。

#### 判断基準

```
「同じドメイン機能群か？」
  ├── YES → 密結合を許容（ただしUI操作は分離）
  │         例: battle内部, dominio内部
  └── NO  → 疎結合を維持
			例: battle ↔ spell, dominio ↔ UI
```

#### 許容されるドメイン機能群

| ドメイン | 構成クラス | 許容される密結合 |
|---------|-----------|---------------|
| **battle系** | BattleSystem, BattlePreparation, BattleExecution, BattleSkillProcessor, ConditionChecker | 直接参照、共有データ（BattleParticipant, context）、`_ref`サフィックス命名 |
| **dominio系** | DominioCommandHandler, DominioOrderHandler（4分割）, LandActionHelper, LandSelectionHelper, CreatureSynthesis | 直接参照、インタラクティブフロー内の密な連携 |

#### 密結合でも切り離すべきもの

| 切り離す対象 | 理由 | 例 |
|-------------|------|-----|
| **UI操作** | 表示ロジックとビジネスロジックは変更理由が違う | battle → BattleScreenManager は Signal 経由 |
| **他ドメインへの参照** | ドメイン境界をまたぐ参照は上位（GFM）経由 | battle → spell は GFM が調停 |
| **兄弟の状態変更** | 循環依存の温床 | dominio → PlayerSystem.set_*() は GFM 経由 |

#### その他の例外

| 領域 | 許容内容 | 理由 |
|------|---------|------|
| 表示更新Signal | 上位→UI方向のシグナル接続 | 表示更新のみに限定。状態変更ロジックは絶対禁止 |

**原則**: 例外は「なぜ許容するか」の理由が明確な場合のみ。曖昧なら規約に従う。

### 委譲メソッドクイックリファレンス

チェーンアクセスの代わりに使う委譲メソッド一覧。

#### ui_manager 経由
| やりたいこと | 委譲メソッド |
|-------------|-------------|
| トースト表示 | `ui_manager.show_toast(msg)` |
| アクション指示表示 | `ui_manager.show_action_prompt(msg)` |
| アクション指示非表示 | `ui_manager.hide_action_prompt()` |
| コメント表示＋クリック待ち | `await ui_manager.show_comment_and_wait(msg, pid)` |
| Yes/No選択 | `await ui_manager.show_choice_and_wait(msg, pid, yes, no)` |
| 手札表示更新 | `ui_manager.update_hand_display(player_id)` |
| 全InfoPanel非表示 | `ui_manager.hide_all_info_panels(clear_buttons)` |
| カード情報表示（閲覧） | `ui_manager.show_card_info(card_data, tile_index)` |
| カード情報表示（選択） | `ui_manager.show_card_selection(card_data, hand_index, ...)` |
| ナビゲーション設定 | `ui_manager.enable_navigation(confirm, back, up, down)` |
| ナビゲーション無効化 | `ui_manager.disable_navigation()` |

#### board_system_3d 経由
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

---

## 必須パターン

### MHP（最大HP）計算
MHP = 元のベースHP(`hp`) + 永続的基礎HP上昇(`base_up_hp`)

```gdscript
# ✅ BattleParticipant がある場合（戦闘中）
var mhp = participant.get_max_hp()  # base_hp + base_up_hp

# ✅ creature_data から直接計算する場合（戦闘外）
var mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)

# ❌ base_up_hp を忘れない
var mhp = creature_data.get("hp", 0)  # 不完全！
```

**注意**: `creature_data["hp"]` は元のカードデータ値で**絶対に変更しない**。
現在HPは `creature_data["current_hp"]` に保存する。
`base_up_hp` はマスグロース・合成・周回ボーナスでのみ変更する。

### AP（攻撃力）計算
AP = 元のAP(`ap`) + 永続的基礎AP上昇(`base_up_ap`)

```gdscript
# ✅ 基礎AP計算
var base_ap = creature_data.get("ap", 0) + creature_data.get("base_up_ap", 0)

# ✅ BattleParticipant では current_ap を使う
var attack_power = participant.current_ap  # 全ボーナス反映済み
```

**注意**: コード内にST（旧称）が残っている箇所があるが、正しい用語はAP。
`creature_data["ap"]` は元の値で**変更しない**。永続上昇は `base_up_ap` に保存する。

### 土地レベルのキー名
tile_info と context で**キー名が異なる**。混同しないこと。

```gdscript
# ✅ tile_info（タイル情報Dictionary）からはキー "level"
var level = tile_info.get("level", 1)

# ✅ context（バトルコンテキスト）ではキー "tile_level"
var level = context.get("tile_level", 1)

# ❌ tile_info に "tile_level" は存在しない
var level = tile_info.get("tile_level", 1)  # 常に1が返る！

# ❌ 旧キー名（廃止済み）
var level = context.get("current_land_level", 1)
```

context構築時の変換箇所（condition_checker.gd 等）:
```gdscript
"tile_level": battle_field.get("level", 1),
```

### コストフィールド
常に `ep`（Energy Point）。`mp` は使わない。
```gdscript
var cost = cost_data.get("ep", 0)  # ✅
var cost = cost_data.get("mp", 0)  # ❌ 旧称
```

### シグナル接続
```gdscript
# 1回限りの接続（バトル完了待ち等）
signal.connect(callback, CONNECT_ONE_SHOT)

# 多重接続防止
if not signal.is_connected(callback):
	signal.connect(callback)
```

### ノード有効性チェック
```gdscript
if card_node and is_instance_valid(card_node):
	card_node.queue_free()
```

---

## シグナル設計ルール

### 接続方向の原則
シグナルは**子→親**方向（通知の上昇）に使う。親→子は直接メソッド呼び出しで良い。

```
✅ 正しい方向（子が発行、親がリッスン）:
  TileActionProcessor → emit "action_completed"
	→ BoardSystem3D がリッスン → emit "tile_action_completed"
	  → GameFlowManager がリッスン → end_turn()

✅ UI→ロジック方向（ユーザー操作の伝達）:
  UIManager.card_selected → GameFlowManager.on_card_selected

⚠️ 許容: 表示更新用オブザーバー（上位→UIへの通知）:
  player_system.magic_changed → player_info_panel._on_magic_changed
  ※ 表示更新（UI反映）は許容。状態変更（ロジック処理）は絶対禁止。
  判断基準: シグナルハンドラ内で他システムのプロパティを変更していたらNG。

❌ 禁止: 子が親のシグナルに接続してロジックを実行
```

### シグナル定義のルール

**命名**: `動詞_過去分詞` 形式で、何が起きたかを表す
```gdscript
# ✅ 良い命名
signal action_completed()
signal card_selected(card_index: int)

# ❌ 悪い命名
signal do_action()        # 命令形はメソッド名
signal card()             # 何が起きたか不明
```

**引数**: 型注釈を必ずつける
```gdscript
signal magic_changed(player_id: int, new_value: int)
```

### 接続管理のルール

**CONNECT_ONE_SHOT**: 一度きりのイベント待ちに使う
**永続接続**: _ready() や初期化時に1回だけ接続
**動的接続と切断**: 接続したら必ず切断する。ペアで管理

### シグナル中継パターン
UIコンポーネントのシグナルはUIManager経由で中継する。
```
CardSelectionUI.card_selected → UIManager → GameFlowManager
```

### やってはいけないこと
- シグナル内でシグナルを emit しない（無限ループの危険）
- await でシグナルを待つ場合、そのシグナルが確実に発火されることを保証する
- 解放済みオブジェクトのシグナルに接続しない（is_instance_valid チェック）
- ラムダ接続を多用しない（切断が困難になる）

---

## カプセル化ルール

### 大きなクラスの分割パターン
1000行を超えるクラスは機能別に分割を検討する。
分割先は RefCounted クラスとして作成し、本体から委譲する。

```gdscript
# ✅ 本体に薄い委譲メソッドを残す（後方互換）
func execute_summon(card_index: int):
	await summon_executor.execute_summon(card_index)

# ✅ 外部参照が多い場合はプロパティで後方互換を維持
var creature_synthesis: CreatureSynthesis:
	get: return summon_executor.creature_synthesis if summon_executor else null
```

### 分割時の外部参照ルール
- 分割前に外部結合を減らす（privateメソッド公開化、フラグメソッド化）
- 外部APIは委譲メソッドで維持し、呼び出し側の修正を最小化
- コルーチン（await含む関数）に変わった場合、呼び出し側にも `await` を追加

---

## フェーズ重複防止
GameFlowManagerは**二段チェック**でターン終了の重複を防ぐ。

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

**ルール**: フェーズ遷移を伴う処理では、必ず冒頭でフェーズ/フラグチェックを入れる。

## await パターン
```gdscript
# タイマー待ち
await get_tree().create_timer(1.0).timeout

# シグナル待ち
await battle_system.invasion_completed

# UI通知 + クリック待ち
await global_comment_ui.show_and_wait_for_click("メッセージ")

# バトル画面のクリック待ち
await battle_screen.wait_for_click()
```

**awaitの注意事項**:
- await先のシグナルが**確実に発火される**ことを保証する。発火されないとハングする
- await中にオブジェクトが解放されないよう注意
- CPU処理では `await get_tree().create_timer(CPU_THINKING_DELAY).timeout` でウェイト
- タイマー値の目安: 演出=0.3〜0.5秒、思考時間=0.5〜1.0秒、通知表示=1.0〜2.0秒

---

## 命名規約

### 初期化メソッド名の使い分け
| メソッド名 | 用途 |
|-----------|------|
| `_init()` | コンストラクタ（外部依存なし） |
| `initialize()` | 外部参照受取＋子オブジェクト `new()` 生成あり |
| `setup()` | `initialize()`と同義、複数システム受取時 |
| `setup_with_context()` | context受取＋子オブジェクト生成あり |
| `set_context()` | context保存のみ（生成なし） |
| `set_xxx()` | 単一プロパティ設定 |

**判定基準**: `new()` で子オブジェクト生成あり → `initialize()` / `setup_with_context()`

### 参照変数の `_ref` サフィックス
既存ファイルのスタイルに合わせる（battle系は `_ref` あり、その他はなし）。

---

## データ構造
データ構造は `docs/design/` および実データJSON（`data/` ディレクトリ）を参照。
主要な参照先:
- ability_parsed, effect_parsed: 各カードJSONの実データ
- ランタイムフィールド: `creature_data["base_up_hp"]`, `["base_up_ap"]`, `["current_hp"]`, `["curse"]` 等

---

## 実装前チェックリスト

### コーディング規約
- [ ] 禁止パターン(1-10)に該当していないか
- [ ] MHP計算で base_up_hp を含めているか
- [ ] AP計算で base_up_ap を含めているか
- [ ] 土地レベルは tile_info → `"level"`, context → `"tile_level"` と正しく使い分けているか
- [ ] コストは `ep` を使っているか（`mp` は旧称）
- [ ] UI座標はビューポート相対か
- [ ] シグナル多重接続を防止しているか
- [ ] シグナル方向は子→親か
- [ ] ノード有効性チェックをしているか
- [ ] end_turn() を直接呼んでいないか
- [ ] フェーズ遷移処理で重複防止チェック（フラグ＋フェーズ）を入れているか
- [ ] await 先のシグナルは確実に発火されるか
- [ ] 初期化メソッド名は処理内容と一致しているか
- [ ] creature_data["hp"] / ["ap"] を変更していないか（不変値）

### 設計規約（新しいコード/参照を追加するとき）
- [ ] 依存方向は上位→下位か（逆方向になっていないか）
- [ ] get_tree().root で上位を辿っていないか
- [ ] チェーンアクセスは2段以内か（3段以上は禁止）
- [ ] 新しい参照は最小限か（システム全体でなく必要なコンポーネントだけ）
- [ ] UIコンポーネントからロジック上位を直接参照していないか
- [ ] 循環参照が発生しないか（A→B→Aの経路）
- [ ] privateメソッド/プロパティの`_`プレフィックスは外部公開の意図と一致しているか
