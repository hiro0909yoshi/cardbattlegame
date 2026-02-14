# 設計の曖昧性 - 詳細分析レポート

## 1. 循環依存の実態

### 検出された循環依存パス

#### Path A: GameFlowManager ↔ spell_phase_handler
```
game_flow_manager:
  → spell_phase_handler (set_phase1a_handlers で設定)
  → spell_phase_handler.start_spell_phase(player_id)
  → spell_phase_handler.spell_phase_completed を await
  
spell_phase_handler:
  → game_flow_manager_ref に参照を保有
  → game_flow_manager_ref.ui_manager にアクセス
  → game_flow_manager_ref.board_system_3d にアクセス
```
**問題：** GFM がハンドラー管理 + ハンドラーが GFM に依存 = 循環

#### Path B: GameFlowManager ↔ board_system_3d
```
game_flow_manager:
  → board_system_3d.tile_action_completed.connect(_on_tile_action_completed_3d)
  → board_system_3d.set_movement_controller_gfm(self)
  → board_system_3d.process_tile_landing()
  
board_system_3d:
  → movement_controller.game_flow_manager 参照を保有
  → spell_phase_handler（GFMを通じて）にアクセス
  → ui_manager（GFMを通じて）にアクセス
```
**問題：** GFM がボード管理 + ボードが GFM に依存 = 循環

#### Path C: spell_phase_handler ↔ board_system_3d
```
spell_phase_handler:
  → game_flow_manager_ref.board_system_3d.tile_action_processor にアクセス
  → board_system_3d.camera を直接操作
  
board_system_3d:
  → spell_phase_handler（GFMを通じて）に依存
```
**問題：** スペルハンドラーがボードを直接知っている

---

## 2. God Object の特定

### game_flow_manager（1000行超）
**責務：**
1. ターン進行管理（ターン開始・終了）
2. フェーズ管理（DICE_ROLL → MOVING → BATTLE等）
3. サイコロ処理
4. スペルフェーズ開始
5. アイテムフェーズ開始
6. ドミニオコマンド開始
7. 移動完了イベント処理
8. タイルアクション完了処理
9. バトル結果処理
10. 破産処理
11. 通行料処理
12. 世界呪い管理
13. 周回管理
14. カメラ制御
15. UI統合管理
16. ゲーム終了判定

**評価：** 🔴 責務が多すぎる（最低でも5つのシステムに分割可能）

### spell_phase_handler（1500行超）
**責務：**
1. スペルフェーズ進行管理
2. カード選択処理
3. コスト計算
4. ターゲット選択UI
5. スペル効果の実行判定
6. アルカナアーツ管理
7. CPU AI判定
8. UIメッセージ表示
9. カメラ移動
10. ボード状態参照

**評価：** 🔴 責務が多すぎる（スペル実行と UI は分割すべき）

### board_system_3d
**責務：**
1. 3Dボード管理
2. タイル管理
3. プレイヤー駒管理
4. 移動システム（movement_controller内蔵）
5. タイルアクション（tile_action_processor内蔵）
6. カメラ制御（camera_controller内蔵）
7. CPU AI（cpu_turn_processor内蔵）
8. シーン構築

**評価：** 🔴 複数のサブシステムをそのまま内蔵（ファサードになっていない）

---

## 3. 依存の方向性の逆転

### Entityが Logic層を知っている
```
card.gd:
  → gfm.spell_phase_handler.spell_mystic_arts
  → gfm.board_system_3d.xxx
  
↓ 本来はこう
card.gd:
  → カード情報のみ保有
  → ロジックはもっと上の層で判定
```

### Data層が Logic層に依存
```
creature_manager.gd:
  → game_flow_manager に参照あり？
  → board_system_3d に参照あり？
```
**要確認**

---

## 4. 初期化順序の暗黙契約

GameSystemManager の6フェーズ：
```
Phase 1: 基本システム作成（PlayerSystem, CardSystem等）
Phase 2: UIManager作成
Phase 3: BoardSystem3D作成
Phase 4: spell_container作成
Phase 5: ハンドラー作成（SpellPhaseHandler等）
Phase 6: 参照設定・シグナル接続
```

**問題：**
- この順番にしてる理由が明確でない
- 「フェーズ3の後にフェーズ4」という依存が暗黙的
- 新機能追加時に「どこに挿入すべき？」が判断困難

---

## 5. シグナル接続の問題

### 接続漏れの危険性
```gdscript
// 毎回 is_connected チェック
if not board_system_3d.tile_action_completed.is_connected(_on_tile_action_completed_3d):
    board_system_3d.tile_action_completed.connect(_on_tile_action_completed_3d)

// ① 同じシグナルを複数箇所で接続？
// ② setup_systems と set_phase1a_handlers どっちで接続？
// ③ setup_3d_mode との順序関係は？
```

### 接続順序による動作変化の懸念
```
// A が B より先に接続されると？
A.connect(handler_a)
B.connect(handler_b)
// emit_signal → handler_a が先に実行
// もし handler_a が状態を変更すると、handler_b の動作が変わる
```

---

## 6. 型安全性の欠如

```gdscript
var spell_phase_handler = null                    // ❌ 型なし
var item_phase_handler = null                     // ❌ 型なし
var special_tile_system                           // ❌ 型なし
var battle_screen_manager                         // ❌ 型なし
var magic_stone_system                            // ❌ 型なし
var cpu_special_tile_ai: CPUSpecialTileAI = null  // ✅ 型あり
```

**問題：**
- null チェックが増える
- IDE 補完が効かない
- 実行時エラーのリスク
- デバッグが困難

---

## 7. 依存注入（DI）の不完全さ

### Setter が複数存在
```gdscript
func set_spell_container(container)
func set_phase1a_handlers(...)
func set_cpu_special_tile_ai(ai)
func set_battle_screen_manager(manager, overlay)
func set_magic_stone_system(system)
// etc...
```

**問題：**
- どの setter を何回呼ぶべき？
- 呼ぶ順序は？
- 呼び忘れた場合どうなる？
- 「全て設定された」状態を確認する手段がない

---

## 8. データフローの不透明性

**例：プレイヤーがサイコロを振る流れ**
```
start_turn()
  → change_phase(DICE_ROLL)
  → ui_manager.set_phase_text("サイコロを振ってください")
  → _setup_dice_phase_navigation()

_setup_dice_phase_navigation()
  → ui_manager.enable_navigation(
      func(): roll_dice()  ← どこで呼ばれる？
    )

roll_dice()
  → await dice_phase_handler.roll_dice(...)
  
dice_phase_handler.roll_dice()
  → movement_controller.move_player()
  
movement_controller.move_player()
  → await move_to_tile()  ← アニメーション実行

// 誰が最終的に状態を更新する？
```

**問題：** データフローが複雑に絡み合っている

---

## 9. 状態管理の混乱

```gdscript
// GFM のフェーズ
current_phase = GamePhase.SETUP

// State Machine のフェーズ
_state_machine.current_state

// board_system_3d のフェーズ？
// movement_controller の状態？
// tile_action_processor の状態？
// spell_phase_handler の状態？
```

**問題：** 複数の層で「状態」を持っている
- どれが「真実」？
- 同期はどうしてる？
- ズレたときの復帰方法は？

---

## 10. 初期化の暗黙的タイミング

```gdscript
func start_game():
    _init_state_machine()  ← ここで初めて State Machine 作成

// でも setup_systems() や setup_3d_mode() では？
// 「いつまでに initialized される？」が不明確
```

---

## まとめ：設計の根本問題

| 問題 | 重大度 | 改善効果 |
|------|--------|---------|
| 循環依存（3パス） | 🔴 致命的 | 高 |
| God Object（GFM, SPH, Board） | 🔴 高 | 高 |
| 初期化順序の暗黙契約 | 🔴 高 | 中 |
| 依存の方向性逆転 | 🟡 中 | 中 |
| シグナル接続の混乱 | 🟡 中 | 中 |
| 型安全性欠如 | 🟡 中 | 低 |
| DI の不完全性 | 🟡 中 | 中 |
| データフロー不透明 | 🟡 中 | 高 |
| 状態管理の混乱 | 🟡 中 | 高 |
| 初期化タイミング不明 | 🟡 中 | 中 |

**改善優先度（効果 × 重要度）：**
1. **循環依存を断つ**（最優先）
2. **God Object を分割**
3. **初期化順序を自動化・明示化**
4. **データフローを明確化**
5. 型安全性を上げる
