# ターン終了処理フロー図

## 概要
ターン終了処理（`end_turn()`）の呼び出し経路と問題点を可視化

---

## 🎯 責任クラス
**GameFlowManager** (`scripts/game_flow_manager.gd`)
- **メソッド**: `end_turn()` (Line 236)
- **トリガー**: `_on_tile_action_completed_3d()` (Line 141)

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
	  │  end_turn()  (Line 236)    │
	  │                            │
	  │  【重複チェック】            │
	  │  if phase == END_TURN:     │
	  │    return                  │
	  │                            │
	  │  change_phase(END_TURN)    │
	  │  skill_system.end_turn_cleanup()
	  │  プレイヤー切り替え          │
	  │  await camera移動           │
	  │  start_turn()              │
	  └────────────────────────────┘
```

---

## ⚠️ 問題：重複実行経路

### 3D版の正常フロー（推奨）
```
アクション完了
  ↓
BoardSystem3D.emit_signal("tile_action_completed")
  ↓
GameFlowManager._on_tile_action_completed_3d()
  ↓
end_turn()
```

### 2D版の残存フロー（削除予定・問題あり）
```
CPU判断完了
  ↓
_on_cpu_summon_decided() など
  ↓
end_turn()  ← 直接呼び出し（問題！）
```

### 混在時の問題ケース
```
シナリオ: CPUターンでカード召喚

1. _on_cpu_summon_decided()
   ├─ 3D版: board_system_3d.execute_summon()
   │         └→ 内部でtile_action_completed発火
   │             └→ _on_tile_action_completed_3d()
   │                 └→ end_turn() ①
   │
   └─ 2D版分岐（else節）
	   └→ end_turn() ② 【重複！】

結果: end_turn()が2回実行される可能性
```

---

## 🔍 tile_action_completed発火箇所一覧

### BoardSystem3D内
| メソッド | 場所 | タイミング |
|---------|------|-----------|
| `on_action_pass()` | Line 221 | 通行料支払い後 |
| `on_card_selected()` | - | カード使用決定後 |
| `_on_invasion_completed()` | - | バトル完了後 |
| `execute_summon()` | - | 召喚完了後 |

### GameFlowManager内（明示的emit）
| メソッド | 場所 | 条件 |
|---------|------|------|
| `_on_cpu_summon_decided()` | Line 156 | 3D版・召喚しない場合 |
| `_on_cpu_summon_decided()` | Line 159 | 2D版（削除予定） |
| `_on_cpu_battle_decided()` | Line 176 | 2D版（削除予定） |
| `_on_cpu_level_up_decided()` | Line 195 | 3D版・レベルアップ完了 |
| `_on_cpu_level_up_decided()` | Line 198 | 2D版（削除予定） |

---

## 🛡️ 現在の防御機構

### 1. フェーズチェック（一次防御）
```gdscript
# game_flow_manager.gd Line 142-145
func _on_tile_action_completed_3d():
	if current_phase == GamePhase.END_TURN or current_phase == GamePhase.SETUP:
		print("Warning: tile_action_completed ignored (phase:", current_phase, ")")
		return
	
	end_turn()
```

**問題点**: 非同期処理で`current_phase`が更新される前に2回目の呼び出しが入る

### 2. 実行中チェック（二次防御）
```gdscript
# game_flow_manager.gd Line 238-240
func end_turn():
	if current_phase == GamePhase.END_TURN:
		print("Warning: Already ending turn")
		return
	
	change_phase(GamePhase.END_TURN)  # ここでフェーズ変更
	# ...
```

**問題点**: `change_phase()`の前に2回目の呼び出しが入ると防げない

---

## 💡 修正案

### Option 1: シグナル一本化（推奨）
```gdscript
# 全ての経路をtile_action_completedシグナルに統一
func _on_cpu_summon_decided(card_index: int):
	if is_3d_mode and board_system_3d:
		if card_index >= 0:
			board_system_3d.execute_summon(card_index)
		else:
			board_system_3d.emit_signal("tile_action_completed")
	# else節削除（2D版削除）

# end_turn()はシグナル経由のみ
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

### Option 3: デバウンス処理
```gdscript
var end_turn_timer: Timer = null

func request_end_turn():
	if end_turn_timer and end_turn_timer.time_left > 0:
		return  # 既にリクエスト中
	
	end_turn_timer = get_tree().create_timer(0.1)
	await end_turn_timer.timeout
	end_turn()
```

---

## 📋 対応チェックリスト

### 即時対応
- [ ] BUG-000を最優先バグとして登録
- [ ] is_ending_turnフラグによる一時対策実装
- [ ] ログ出力強化（どの経路から呼ばれたか追跡）

### 今週対応
- [ ] 2D版コード完全削除（TECH-001）
- [ ] シグナル経路の一本化
- [ ] テストケース作成

### 来週以降
- [ ] ターン管理の専用クラス作成（TurnManager）
- [ ] フェーズ遷移の状態機械パターン適用
- [ ] リファクタリング完了

---

**作成日**: 2025年1月10日  
**関連Issue**: BUG-000, TECH-001
