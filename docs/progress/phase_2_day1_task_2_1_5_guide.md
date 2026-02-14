# Phase 2 Day 1 - Task 2-1-5: 既存接続の削除 (実装ガイド)

**対象**: テスト完全成功後（Task 2-1-4 すべてパス後）に実施
**実装予定**: 2026-02-14 テスト完了後（当日中に実施）
**所要時間**: 約 3 時間

---

## 実装前提条件

Task 2-1-5 を実施する前に、以下を **必ず確認** してください:

- [ ] Task 2-1-4 のテスト1: ゲーム起動 + 戦闘実行 ✅ PASS
- [ ] Task 2-1-4 のテスト2: デバッグコンソール接続確認 ✅ PASS
- [ ] Task 2-1-4 のテスト3: CPU vs CPU 3ターン ✅ PASS
- [ ] 重複ログなし（各ログが1回のみ） ✅ 確認済み
- [ ] ハンドラーが正常に動作 ✅ 確認済み

**重要**: 1つでも失敗している場合は、Task 2-1-4 に戻ってデバッグしてください。Task 2-1-5 を実施しないでください。

---

## 削除対象箇所 (3つのハンドラー)

### 1. DominioCommandHandler (`scripts/game_flow/dominio_command_handler.gd`)

#### 削除箇所: 行 787-789

**削除前**:
```gdscript
# バトル完了シグナルに接続
var callable = Callable(self, "_on_move_battle_completed")
if not battle_system.invasion_completed.is_connected(callable):
    battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
```

**削除後**:
```gdscript
# Phase 2 で GameFlowManager経由の通知に統一（この接続は削除）
```

#### メソッド名の統一

**現在**: `func _on_move_battle_completed(success: bool, tile_index: int):`
**変更後**: `func _on_invasion_completed(success: bool, tile_index: int):`

**理由**: GameFlowManager から `_on_invasion_completed()` で呼び出されるため

**変更箇所**: 行 809

```gdscript
# 変更前
func _on_move_battle_completed(success: bool, tile_index: int):

# 変更後
func _on_invasion_completed(success: bool, tile_index: int):
```

---

### 2. LandActionHelper (`scripts/game_flow/land_action_helper.gd`)

#### 削除箇所: 行 537-539

**削除前**:
```gdscript
# バトル完了シグナルに接続
var callable = Callable(handler, "_on_move_battle_completed")
if handler.battle_system and not handler.battle_system.invasion_completed.is_connected(callable):
    handler.battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
```

**削除後**:
```gdscript
# Phase 2 で GameFlowManager経由の通知に統一（この接続は削除）
# handler の _on_invasion_completed() は GameFlowManager から呼び出される
```

**コンテキスト**: `_execute_move_battle()` 静的メソッド内

---

### 3. CPUTurnProcessor (`scripts/cpu_ai/cpu_turn_processor.gd`)

#### 削除箇所: 行 285-286

**削除前**:
```gdscript
if not battle_system.invasion_completed.is_connected(_on_invasion_completed):
    battle_system.invasion_completed.connect(_on_invasion_completed, CONNECT_ONE_SHOT)
```

**削除後**:
```gdscript
# Phase 2 で GameFlowManager経由の通知に統一（この接続は削除）
```

**注意**: メソッド名 `_on_invasion_completed()` はそのまま（既に正しい名前）

---

## 実装手順

### Step 1: DominioCommandHandler の修正

#### 1-1: シグナル接続の削除

ファイル: `scripts/game_flow/dominio_command_handler.gd`
行: 787-789

```gdscript
# ❌ 削除対象（3行全て削除）
var callable = Callable(self, "_on_move_battle_completed")
if not battle_system.invasion_completed.is_connected(callable):
    battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
```

#### 1-2: メソッド名の統一

行: 809

```gdscript
# 変更前
func _on_move_battle_completed(success: bool, tile_index: int):

# 変更後
func _on_invasion_completed(success: bool, tile_index: int):
```

**確認**: メソッドの実装内容は変わらない（battle_systemへの接続を削除した以外）

#### 1-3: 検証

デバッグメッセージを追加（テスト用）:
```gdscript
func _on_invasion_completed(success: bool, tile_index: int):
    print("[DominioCommandHandler] invasion_completed 受信: success=%s, tile=%d" % [success, tile_index])

    # 既存の実装...
```

---

### Step 2: LandActionHelper の修正

ファイル: `scripts/game_flow/land_action_helper.gd`
行: 537-539

```gdscript
# ❌ 削除対象（3行全て削除）
var callable = Callable(handler, "_on_move_battle_completed")
if handler.battle_system and not handler.battle_system.invasion_completed.is_connected(callable):
    handler.battle_system.invasion_covered.connect(callable, CONNECT_ONE_SHOT)
```

**削除後**:
```gdscript
# Phase 2 で GameFlowManager を経由した通知に統一
# DominioCommandHandler の _on_invasion_completed() は
# GameFlowManager から呼び出されるようになったため、ここでの接続は不要
```

**確認**: LandActionHelper のメソッド名変更は不要（handler 経由で呼ばれ方が変わるだけ）

---

### Step 3: CPUTurnProcessor の修正

ファイル: `scripts/cpu_ai/cpu_turn_processor.gd`
行: 285-286

```gdscript
# ❌ 削除対象（2行全て削除）
if not battle_system.invasion_completed.is_connected(_on_invasion_completed):
    battle_system.invasion_completed.connect(_on_invasion_completed, CONNECT_ONE_SHOT)
```

**削除後**:
```gdscript
# Phase 2 で GameFlowManager を経由した通知に統一
```

**注意**: CPUTurnProcessor の `_on_invasion_completed()` メソッド名は変更不要（既に正しい名前）

---

## 削除後のテスト手順 (再テスト)

### テスト方法1: ゲーム起動 + 戦闘1回実行

```
1. ゲーム起動
2. スペルフェーズ → ダイスフェーズ → 移動フェーズ
3. 敵タイルに到達 → 戦闘実行
4. デバッグログで新規フローのみが実行されることを確認
```

**確認項目**:
- [ ] `[TileActionProcessor] invasion_completed 受信` (1回)
- [ ] `[BoardSystem3D] invasion_completed 受信` (1回)
- [ ] `[GameFlowManager] invasion_completed 受信` (1回)
- [ ] `[DominioCommandHandler] invasion_completed 受信` (1回)
- [ ] `[CPUTurnProcessor] invasion_completed 受信` (1回)
- [ ] **重複なし**（各ログ正確に1回）

### テスト方法2: デバッグコンソール接続確認

```gdscript
# 接続状態確認
print("TileActionProcessor接続: ",
    board_system.tile_action_processor.invasion_completed.is_connected(board_system._on_invasion_completed))
print("BoardSystem3D接続: ",
    board_system.invasion_completed.is_connected(game_flow_manager._on_invasion_completed_from_board))

# 既存接続は削除されたことを確認
print("DominioCommandHandler_old接続: ",
    battle_system.invasion_completed.is_connected(Callable(game_flow_manager.dominio_command_handler, "_on_invasion_completed")))
print("CPUTurnProcessor_old接続: ",
    battle_system.invasion_completed.is_connected(Callable(board_system.cpu_turn_processor, "_on_invasion_completed")))
```

**期待される結果**:
- [ ] TileActionProcessor接続: true
- [ ] BoardSystem3D接続: true
- [ ] DominioCommandHandler_old接続: false ✅ (削除済み)
- [ ] CPUTurnProcessor_old接続: false ✅ (削除済み)

### テスト方法3: CPU vs CPU 3ターン以上

```
1. ゲーム起動
2. CPU vs CPU で 3ターン以上進行
3. 各戦闘のログをチェック（重複なし、順序正確）
4. ゲーム進行が正常
```

**確認項目**:
- [ ] 全戦闘のログが新規フローのみ
- [ ] 3回以上の戦闘で重複なし
- [ ] CPU AI が正常に判定している
- [ ] ゲーム進行に異常なし

---

## BUG-000 再発検出方法

### 重複実行カウンター

各ハンドラーに以下のカウンターを追加してテストできます:

```gdscript
# DominioCommandHandler に追加（テスト用）
var invasion_call_count = 0

func _on_invasion_completed(success: bool, tile_index: int):
    invasion_call_count += 1
    print("[DominioCommandHandler] invasion_completed call count: %d" % invasion_call_count)

    if invasion_call_count > 1:
        push_error("[BUG-000] invasion_completed が重複実行されています！")
        return

    # 処理...
```

**テスト後は削除してください** (本番コードに含めない)

---

## ロールバック計画

Task 2-1-5 で問題が発生した場合の即座ロールバック:

### 方法1: git revert (推奨)

```bash
git revert cf0feb2  # Phase 2 Day 1-1 の commit を revert
```

### 方法2: 手動復旧

1. 削除した接続コードを復旧
2. メソッド名を _on_move_battle_completed に戻す
3. ゲーム起動でテスト

---

## チェックリスト (Task 2-1-5 実施前)

実施前に以下をすべて確認:

- [ ] Task 2-1-4 全テスト ✅ PASS
- [ ] 新規ログが正しい順序で出力
- [ ] 重複ログなし
- [ ] 現在の commit が `cf0feb2` であることを確認

```bash
git log --oneline -1
# cf0feb2 Phase 2 Day 1-1: invasion_completed リレーチェーン基盤実装
```

---

## 実装の成功基準

Task 2-1-5 完了後:

- [ ] DominioCommandHandler 接続削除完了
- [ ] LandActionHelper 接続削除完了
- [ ] CPUTurnProcessor 接続削除完了
- [ ] メソッド名統一 (_on_invasion_completed に)
- [ ] 削除後の再テスト: ✅ PASS
- [ ] 重複実行なし（BUG-000 未再発）
- [ ] デバッグログで新規フローのみ実行確認

---

## 完了後の次ステップ

Task 2-1-5 完了後:

1. ドキュメント更新
   - [ ] `docs/progress/daily_log.md` に完了記録
   - [ ] `docs/implementation/signal_catalog.md` 更新

2. Phase 2-2 へ進行 (movement_completed)
   - [ ] movement_completed のリレー実装
   - [ ] level_up_completed のリレー実装

3. 統合テスト
   - [ ] 複数シグナルの並行動作確認
   - [ ] ゲーム全体の正常動作確認

---

**実装開始予定**: Task 2-1-4 テスト完全パス後（2026-02-14 見込み）
**ステータス**: 準備完了、テスト待ち
