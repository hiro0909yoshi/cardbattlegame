# 📌 ターン終了処理問題 - クイックリファレンス

## 🚨 最重要情報

### 責任ファイル
**`scripts/game_flow_manager.gd`**

### 問題のメソッド
- **`end_turn()`** (Line 236) - ターン終了処理本体
- **`_on_tile_action_completed_3d()`** (Line 141) - メイントリガー

---

## ⚡ 一時対策コード（コピペ用）

```gdscript
# game_flow_manager.gd の先頭（クラス変数として追加）
var is_ending_turn = false

# end_turn() の先頭に追加
func end_turn():
	# 🛡️ 排他制御：重複実行を完全ブロック
	if is_ending_turn:
		print("⚠️ BLOCKED: end_turn already in progress")
		return
	
	is_ending_turn = true
	print("🔄 Starting end_turn process...")
	
	# 既存のフェーズチェック
	if current_phase == GamePhase.END_TURN:
		print("Warning: Already ending turn")
		is_ending_turn = false  # フラグリセット
		return
	
	# ... 以下既存コード ...
	
	# 最後に必ずフラグリセット
	await get_tree().create_timer(GameConstants.TURN_END_DELAY).timeout
	current_phase = GamePhase.SETUP
	
	is_ending_turn = false  # ← これを追加
	print("✅ end_turn completed, starting next turn")
	start_turn()
```

---

## 📊 呼び出し元チェックリスト

| 呼び出し元 | 場所 | 3D/2D | 状態 | 対応 |
|-----------|------|-------|------|------|
| `_on_tile_action_completed_3d()` | Line 147 | 3D | ✅ 正常 | 維持 |
| `_on_cpu_summon_decided()` | Line 159 | 2D | ⚠️ 削除予定 | 削除 |
| `_on_cpu_battle_decided()` | Line 176 | 2D | ⚠️ 削除予定 | 削除 |
| `_on_cpu_level_up_decided()` | Line 198 | 2D | ⚠️ 削除予定 | 削除 |

---

## 🔍 デバッグ用ログ強化

```gdscript
func end_turn():
	# デバッグ情報追加
	var stack_trace = get_stack()
	print("━━━ end_turn called ━━━")
	print("  Current Phase: ", current_phase)
	print("  Is Ending Turn: ", is_ending_turn)
	print("  Called from: ", stack_trace[1].source if stack_trace.size() > 1 else "unknown")
	print("  Player: ", player_system.get_current_player().id + 1)
	
	if is_ending_turn:
		print("  ❌ DUPLICATE CALL BLOCKED")
		return
	
	is_ending_turn = true
	# ... 既存処理 ...
```

---

## 🎯 根本対策（今週実施）

### Step 1: 2D版削除
```bash
# 削除対象
- Line 159: else節のend_turn()
- Line 176: else節のend_turn()
- Line 198: else節のend_turn()
```

### Step 2: シグナル経路統一
```gdscript
# CPUハンドラーを全てシグナル発火に変更
func _on_cpu_summon_decided(card_index: int):
	if card_index >= 0:
		board_system_3d.execute_summon(card_index)
	else:
		board_system_3d.emit_signal("tile_action_completed")
	# end_turn()直接呼び出しは削除
```

### Step 3: テスト追加
```gdscript
# test_turn_management.gd
func test_no_duplicate_end_turn():
	# tile_action_completedを短時間に2回発火
	board_system_3d.emit_signal("tile_action_completed")
	await get_tree().create_timer(0.05).timeout
	board_system_3d.emit_signal("tile_action_completed")
	
	# end_turn()が1回だけ実行されることを確認
	assert(turn_count == 1, "Turn should only advance once")
```

---

## 📝 確認コマンド

### ログで確認
```
# 正常パターン
🔄 Starting end_turn process...
✅ end_turn completed, starting next turn

# 異常パターン（修正前）
🔄 Starting end_turn process...
⚠️ BLOCKED: end_turn already in progress  ← 2回目がブロックされている
```

### ゲーム内確認
1. CPUターンを観察
2. プレイヤー番号が順番に進むか確認
   - 正常: P1 → P2 → P3 → P4 → P1
   - 異常: P1 → P3 → P1 → P3（飛ばされる）

---

## 🔗 関連ドキュメント
- **詳細フロー**: `turn_end_flow.md`
- **バグ報告**: `issues.md` - BUG-000
- **設計書**: `design.md` - ターン終了処理の管理
- **タスク**: `tasks.md` - 緊急タスク0番

---

**最終更新**: 2025年1月10日
