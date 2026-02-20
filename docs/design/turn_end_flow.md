# ターン終了処理フロー図

## 概要
ターン終了処理（`end_turn()`）の呼び出し経路と実装状況

**バージョン**: 3.0
**最終更新**: 2026年2月13日
**ステータス**: 実装完了（BUG-000完全解決）

---

## 🎯 責任クラス
**GameFlowManager** (`scripts/game_flow_manager.gd`)
- **メソッド**: `end_turn()` (Line 525)
- **トリガー**: `_on_tile_action_completed_3d()` (Line 363)

---

## 📊 呼び出しフロー図

```
┌─────────────────────────────────────────────────────────┐
│                   ゲームアクション                          │
│  (カード使用 / 通行料 / バトル / レベルアップ)               │
└──────────────────┬──────────────────────────────────────┘
				   │
				   ▼
	  ┌────────────────────────────┐
	  │   BoardSystem3D            │
	  │  - on_action_pass()        │
	  │  - on_card_selected()      │
	  │  - execute_summon()        │
	  │  - _on_invasion_completed()│
	  └────────────┬───────────────┘
				   │
				   │ emit_signal("tile_action_completed")
				   ▼
	  ┌────────────────────────────┐
	  │  GameFlowManager           │
	  │  _on_tile_action_completed_3d()  (Line 141)
	  │                            │
	  │  【フェーズチェック】        │
	  │  if phase == END_TURN:     │
	  │    return (重複防止)        │
	  └────────────┬───────────────┘
				   │
				   │ 呼び出し
				   ▼
	  ┌────────────────────────────┐
	  │  end_turn()  (Line 525)    │
	  │                            │
	  │  【重複チェック】            │
	  │  if is_ending_turn: return │
	  │  if phase == END_TURN:     │
	  │    return                  │
	  │                            │
	  │  is_ending_turn = true     │
	  │  ドミニオオーダーを閉じる        │
	  │  手札調整チェック           │
	  │  敵地通行料支払い           │
	  │  change_phase(END_TURN)    │
	  │  player_buff_system.end_turn_cleanup()
	  │  spell_curse更新           │
	  │  プレイヤー切り替え          │
	  │  spell_world_curse更新（ラウンド開始時）
	  │  await camera移動           │
	  │  is_ending_turn = false    │
	  │  start_turn()              │
	  └────────────────────────────┘
```

---

## ✅ 実装済み：重複実行防止

### 現在の正常フロー（3D版のみ）
```
アクション完了
  ↓
TileActionProcessor._complete_action()
  ↓
emit_signal("tile_action_completed")
  ↓
GameFlowManager._on_tile_action_completed_3d()
  │
  ├─ フェーズチェック（END_TURN/SETUP なら return）
  ├─ is_ending_turn チェック（true なら return）
  │
  └→ end_turn()
	  ├─ is_ending_turn = true（最優先）
	  ├─ ドミニオオーダーを閉じる
	  ├─ 手札調整
	  ├─ 通行料支払い
	  ├─ ターン終了処理
	  ├─ プレイヤー切り替え
	  ├─ カメラ移動
	  ├─ is_ending_turn = false
	  └→ start_turn()
```

### 2D版コード
**削除済み** - 2D版の分岐コードは完全に削除され、3D版に一本化されました。

---

## 🔍 tile_action_completed発火箇所一覧

### TileActionProcessor内（主要）
| メソッド | タイミング |
|---------|-----------|
| `_complete_action()` | 全アクション完了時の統一出口 |

### 発火タイミング
| アクション | 発火元 |
|-----------|--------|
| 召喚完了 | `execute_summon()` → `_complete_action()` |
| パス選択 | `on_action_pass()` → `_complete_action()` |
| バトル完了 | `_on_battle_completed()` → `_complete_action()` |
| レベルアップ | `on_level_up_selected()` → `_complete_action()` |
| ドミニオオーダー | 各アクション → `_complete_action()` |

### CPU処理（GameFlowManager内）
| メソッド | 処理 |
|---------|------|
| `_on_cpu_summon_decided()` | TileActionProcessor.execute_summon()に委譲 |
| `_on_cpu_battle_decided()` | TileActionProcessor経由でバトル実行 |
| `_on_cpu_level_up_decided()` | TileActionProcessor経由でレベルアップ |

**注**: 全てのCPU処理はTileActionProcessorに委譲され、直接emit_signalしない設計に統一済み

---

## 🛡️ 実装済み防御機構

### 1. is_ending_turnフラグ（最優先）
```gdscript
# game_flow_manager.gd
var is_ending_turn = false

func end_turn():
	if is_ending_turn:
		print("Warning: Already ending turn (flag check)")
		return
	
	is_ending_turn = true  # ★最優先でフラグを立てる
	# ... ターン終了処理 ...
	is_ending_turn = false
	start_turn()
```

### 2. フェーズチェック（二次防御）
```gdscript
# _on_tile_action_completed_3d() 内
if current_phase == GamePhase.END_TURN or current_phase == GamePhase.SETUP:
	return

if is_ending_turn:
	return

end_turn()
```

### 3. end_turn()内のフェーズチェック（三次防御）
```gdscript
func end_turn():
	if current_phase == GamePhase.END_TURN:
		print("Warning: Already ending turn (phase check)")
		return
```

**三重の防御機構により、重複実行は完全に防止されています。**

### 4. シグナル接続の重複防止（2026-02-13追加）
```gdscript
# 全てのシグナル接続時に is_connected() チェックを実施
if not signal.is_connected(callback):
    signal.connect(callback)
```

**対象箇所（7ファイル、16箇所）**:
- GameFlowManager: lap_completed, tile_action_completed, dominio_command_closed
- DominioCommandHandler: level_up_selected
- HandDisplay: card_drawn, card_used, hand_updated
- BattleLogUI: log_added, battle_started, battle_ended
- TileActionProcessor: invasion_completed, cpu_action_completed
- BoardSystem3D: movement_started, movement_completed, action_completed (×2)
- LapSystem: checkpoint_passed (既に実装済み)

**効果**:
- ゲーム再開時やシーン再読み込み時の多重接続を防止
- イベントハンドラーの2重・3重実行を防止
- メモリリーク（シグナル参照が解放されない）を防止

**CPUTurnProcessorのベストプラクティス**:
CPUTurnProcessorでは `CONNECT_ONE_SHOT` フラグを積極的に使用しており、接続が1回実行された後に自動切断される設計になっています。これは重複接続防止の優れた実装例です。

---

## ✅ 採用された修正

### Option 1: シグナル一本化 → 採用済み
- 全CPU処理はTileActionProcessorに委譲
- 直接emit_signalは行わない設計に統一

### Option 2: is_ending_turnフラグ → 採用済み
```gdscript
var is_ending_turn = false

func end_turn():
	if is_ending_turn:
		return
	is_ending_turn = true
	# ... 処理 ...
	is_ending_turn = false
	start_turn()はシグナル経由のみ
```

### Option 2: 排他制御フラグ
```gdscript
var is_ending_turn = false

func end_turn():
	if is_ending_turn:
		print("Warning: end_turn already in progress")
		return
	
	is_ending_turn = true
	
	# ... ターン終了処理 ...
	
	await get_tree().create_timer(1.0).timeout
	is_ending_turn = false
	start_turn()
```

### Option 3: デバウンス処理 → 不採用
is_ending_turnフラグで十分なため、デバウンス処理は不採用。

---

## 📋 対応完了チェックリスト

### 完了済み ✅
- [x] BUG-000対策: is_ending_turnフラグ実装
- [x] 2D版コード完全削除
- [x] シグナル経路の一本化
- [x] 三重防御機構の実装
- [x] **シグナル接続の重複防止** (2026-02-13追加)
  - [x] GameFlowManager (3箇所)
  - [x] DominioCommandHandler (1箇所)
  - [x] HandDisplay (3箇所)
  - [x] BattleLogUI (3箇所)
  - [x] TileActionProcessor (2箇所)
  - [x] BoardSystem3D (4箇所)
  - [x] LapSystem (既に実装済み)
  - 合計: **7ファイル、16箇所**に `is_connected()` チェック追加

### 今後の検討事項
- [ ] ターン管理の専用クラス作成（TurnManager）- 現状で問題ないため優先度低
- [ ] フェーズ遷移の状態機械パターン適用 - 現状で問題ないため優先度低

---

## 📊 end_turn()処理詳細

```
end_turn()
  │
  ├─ 重複チェック（is_ending_turn, phase）
  │
  ├─ is_ending_turn = true
  │
  ├─ ドミニオオーダーを閉じる
  │   └─ dominio_order_handler.close_dominio_order()
  │
  ├─ UIを隠す
  │   ├─ ui_manager.hide_dominio_order_button()
  │   │   ※ Phase 10-D で Callable 化済み（_ui_hide_dominio_btn_cb）
  │   └─ ui_manager.hide_card_selection_ui()
  │       ※ Phase 10-D で Callable 化済み（_ui_hide_card_selection_cb）
  │
  ├─ 手札調整チェック
  │   └─ await check_and_discard_excess_cards()
  │
  ├─ 敵地通行料支払い
  │   └─ await check_and_pay_toll_on_enemy_land()
  │
  ├─ ターン終了シグナル発火
  │   └─ emit_signal("turn_ended", player_id)
  │
  ├─ フェーズ変更
  │   └─ change_phase(GamePhase.END_TURN)
  │
  ├─ クリーンアップ
  │   ├─ player_buff_system.end_turn_cleanup()
  │   └─ spell_curse.update_player_curse()
  │
  ├─ プレイヤー切り替え
  │   ├─ current_player_index更新
  │   └─ ラウンド開始時: spell_world_curse.on_round_start()
  │
  ├─ カメラ移動
  │   └─ await move_camera_to_next_player()
  │
  ├─ 待機
  │   └─ await create_timer(TURN_END_DELAY)
  │
  ├─ フラグリセット
  │   ├─ current_phase = SETUP
  │   └─ is_ending_turn = false
  │
  └─ 次ターン開始
      └─ start_turn()
```

---

**作成日**: 2025年10月  
**最終更新**: 2025年12月16日（v2.0 - BUG-000対策完了、実装状況反映）  
**関連Issue**: BUG-000（解決済み）