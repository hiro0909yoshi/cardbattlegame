# Phase 2 実装前の質問セッション

**作成日**: 2026-02-14
**対象**: Phase 2: シグナルリレー整備（実装予定）
**主要な参考資料**:
- `docs/progress/refactoring_next_steps.md` の Phase 2 セクション
- `docs/design/dependency_map.md` の問題のある依存関係
- `scripts/game_flow/tile_battle_executor.gd` (invasion_completed emit)
- `scripts/tile_action_processor.gd` (リレー実装対象)
- `scripts/board_system_3d.gd` (シグナル定義)
- `scripts/battle_system.gd` (invasion_completed emit)

---

## 質問グループ1: 既存コードの確認

### Q1-1: TileBattleExecutor の invasion_completed emit 確認

**具体的な質問内容**:

コードを確認したところ、TileBattleExecutor（scripts/game_flow/tile_battle_executor.gd）では：

- **行 7**: `signal invasion_completed(success: bool, tile_index: int)` で定義
- **行 367-374**: `_on_battle_completed()` メソッド内で emit

```gdscript
func _on_battle_completed(success: bool, tile_index: int):
	# ...
	emit_signal("invasion_completed", success, tile_index)
	_complete_callback.call()
```

このシグナルは **BattleSystem の invasion_completed** ではなく、**TileBattleExecutor 独自のシグナル**ですか？

**確認したい事項**:
- [ ] TileBattleExecutor.invasion_completed と BattleSystem.invasion_completed は別物か？
- [ ] BattleSystem.invasion_completed はどこで emit されるか？（既にバトル結果として emit されている？）
- [ ] Phase 2 では、どちらのシグナルをリレー対象とすべきか？

**確認したい理由**: リレー実装時に正しいシグナルソースを特定するため

---

### Q1-2: TileActionProcessor の invasion_completed 受信確認

**具体的な質問内容**:

TileActionProcessor（scripts/tile_action_processor.gd）を確認したところ：

- **行 8**: `signal action_completed()` で定義
- **行 9**: `signal invasion_completed(success: bool, tile_index: int)` で定義（リレー用？）
- **行 92-93**: `battle_executor.invasion_completed` に接続

```gdscript
if not battle_executor.invasion_completed.is_connected(_on_invasion_completed):
	battle_executor.invasion_completed.connect(_on_invasion_completed)
```

**質問**:
- [ ] TileActionProcessor の `invasion_completed` シグナルは、battle_executor から受け取ったものをリレーするためのものか？
- [ ] `_on_invasion_completed()` メソッドの実装は何か？（コード行番号）

**確認したい理由**: 既に部分的なリレーが実装されているかどうかを確認するため

---

### Q1-3: BoardSystem3D の tile_action_completed と他シグナル関係

**具体的な質問内容**:

BoardSystem3D（scripts/board_system_3d.gd）の signal 定義：

```gdscript
# 行 7: tile_action_completed（既存）
signal tile_action_completed()

# 行 9-10: 他のシグナル（既存だが、現在の接続状況は？）
signal level_up_completed(tile_index: int, new_level: int)
signal movement_completed(player_id: int, final_tile: int)

# invasion_completed のシグナル定義がない
```

**質問**:
- [ ] BoardSystem3D に `invasion_completed` シグナルを定義追加すべきか？
- [ ] それとも既存の `tile_action_completed` を使用して invasion をリレーすべきか？
- [ ] `level_up_completed` と `movement_completed` も Phase 2 で統合リレーの対象か、それとも後の Phase か？

**確認したい理由**: Phase 2 で追加すべきシグナルの範囲を確定するため

---

### Q1-4: GameFlowManager での invasion_completed 受信パターン確認

**具体的な質問内容**:

現在、GameFlowManager には各種ハンドラー（DominioCommandHandler, LandActionHelper 等）が直接 BattleSystem.invasion_completed に接続しています。

Phase 2 実装後は：
```
BattleSystem.invasion_completed
  → TileActionProcessor._on_invasion_completed()
  → TileActionProcessor.invasion_completed.emit()
  → BoardSystem3D._on_invasion_completed()（新規実装）
  → BoardSystem3D.invasion_completed.emit()
  → GameFlowManager._on_invasion_completed()（新規実装）
  → 各ハンドラーへ通知
```

**質問**:
- [ ] GameFlowManager に `_on_invasion_completed()` メソッドを新規追加して中央受信すべきか？
- [ ] それとも各ハンドラーが BoardSystem3D から直接受信すべきか？
- [ ] GameFlowManager が受信後、どのハンドラーに順番に通知すべきか？

**確認したい理由**: GameFlowManager の責務範囲と実装パターンを確定するため

---

## 質問グループ2: 実装方針の確認

### Q2-1: TileBattleExecutor → TileActionProcessor リレー実装の詳細

**具体的な質問内容**:

TileBattleExecutor は既に `invasion_completed` を emit していますが（行 374）、これを TileActionProcessor に通知するための実装について：

```gdscript
# TileBattleExecutor で新規追加すべき？
emit_signal("invasion_completed", success, tile_index)

# TileActionProcessor で受信（既に行92-93で一部実装）
if not battle_executor.invasion_completed.is_connected(_on_invasion_completed):
	battle_executor.invasion_completed.connect(_on_invasion_completed)
```

**質問**:
- [ ] `_on_invasion_completed()` メソッドを TileActionProcessor に実装する際、何をすべきか？
  - A) ログ出力のみ
  - B) 内部状態を更新
  - C) `self.invasion_completed.emit()` で上位にリレー
  - D) 複数の処理（B + C）
- [ ] `is_connected()` チェック後の接続先は `CONNECT_ONE_SHOT` を使うべきか、通常接続か？

**確認したい理由**: 各段階での処理パターンを明確にするため

---

### Q2-2: BoardSystem3D での invasion_completed リレー実装

**具体的な質問内容**:

BoardSystem3D は現在、tile_action_completed シグナルを使っていますが、Phase 2 で invasion_completed をリレーする際：

```gdscript
# BoardSystem3D に新規メソッドを追加すべき？
func _on_invasion_completed(success: bool, tile_index: int):
	print("[BoardSystem3D] invasion_completed 受信: success=%s, tile=%d" % [success, tile_index])
	# リレー emit？
```

**質問**:
- [ ] BoardSystem3D に invasion_completed シグナルを新規定義すべきか？
- [ ] メソッド名は `_on_invasion_completed()` か、別の名前か？
- [ ] emit 時に同じ引数（success, tile_index）をそのまま渡すべきか、加工すべきか？

**確認したい理由**: BoardSystem3D での実装パターンを確定するため

---

### Q2-3: GameFlowManager での invasion_completed リレー受信

**具体的な質問内容**:

GameFlowManager では現在、各ハンドラーが BattleSystem の invasion_completed に直接接続しています：

```gdscript
# scripts/game_flow/dominio_command_handler.gd: 行 789
if not battle_system.invasion_completed.is_connected(_on_invasion_completed):
	battle_system.invasion_completed.connect(_on_invasion_completed)
```

Phase 2 後は、これらすべての接続を削除して、GameFlowManager 経由に変更すべきか？

**質問**:
- [ ] 既存の `battle_system.invasion_completed` への直接接続は完全に削除すべきか？
- [ ] GameFlowManager に新しい `_on_invasion_completed_from_board()` など別メソッドを追加すべきか？
- [ ] 各ハンドラーへの通知は、GameFlowManager から `handler.invasion_completed_signal()` のようなメソッド呼び出しでいいか？

**確認したい理由**: 既存接続の削除タイミングと新規実装パターンを確定するため

---

### Q2-4: シグナル接続の順序（create → connect → emit）の再確認

**具体的な質問内容**:

Phase 1 で確立された規則：

```gdscript
# 順序: create → add_child → setup/connect
var obj = SomeClass.new()
add_child(obj)
if not obj.signal.is_connected(handler):
	obj.signal.connect(handler)
```

Phase 2 でも同じパターンか？

**質問**:
- [ ] TileActionProcessor.setup() で `battle_executor.invasion_completed` に接続すべきか？
- [ ] それとも `_ready()` メソッド内で接続すべきか？
- [ ] BoardSystem3D での `tile_action_processor.invasion_completed` 接続の場所は？

**確認したい理由**: シグナル接続タイミングのベストプラクティス確認

---

## 質問グループ3: 複数ハンドラーの通知順序

### Q3-1: 複数ハンドラーへの invasion_completed 通知順序

**具体的な質問内容**:

dependency_map.md によると、BattleSystem の invasion_completed には現在 3つのハンドラーが接続しています：

1. DominioCommandHandler（dominio_command_handler.gd: 行 789）
2. LandActionHelper（land_action_helper.gd: 行 539）
3. CPUTurnProcessor（cpu_turn_processor.gd: 行 286）

**質問**:
- [ ] 通知順序に優先度があるか？（例：DominioCommand → LandAction → CPU）
- [ ] 各ハンドラーは独立して処理するか、前のハンドラーの結果に依存するか？
- [ ] GameFlowManager で通知順序を管理すべきか、各ハンドラーが優先度を決めるべきか？

**確認したい理由**: リレー実装時のハンドラー呼び出し順序を確定するため

---

### Q3-2: CPUTurnProcessor への通知は特別扱いが必要か？

**具体的な質問内容**:

CPUTurnProcessor は BoardSystem3D の子システムですが、invasion_completed 通知を受け取る必要があります。

```
BoardSystem3D
  ├─ CPUTurnProcessor（子）
  └─ TileActionProcessor（子）
	  └─ TileBattleExecutor

→ TileBattleExecutor.invasion_completed
   → TileActionProcessor.invasion_completed
   → BoardSystem3D.invasion_completed
   → GameFlowManager.invasion_completed
   → ???（CPUTurnProcessor へどう通知するか？）
```

**質問**:
- [ ] CPUTurnProcessor は BoardSystem3D から直接受信すべきか？
- [ ] それとも GameFlowManager 経由で受信すべきか？
- [ ] CPUTurnProcessor.cpu_action_completed シグナルと invasion_completed は別の流れか？

**確認したい理由**: CPU関連ハンドラーの通知パターンを確定するため

---

## 質問グループ4: 後方互換性とロールバック

### Q4-1: 既存の BattleSystem.invasion_completed 直接接続の削除タイミング

**具体的な質問内容**:

現在、複数のハンドラーが `battle_system.invasion_completed` に直接接続しています。

Phase 2 実装時：

```gdscript
# 既存接続（削除対象）
if not battle_system.invasion_completed.is_connected(_on_invasion_completed):
	battle_system.invasion_completed.connect(_on_invasion_completed)

# 新規接続（追加対象）
if not board_system.invasion_completed.is_connected(_on_invasion_completed):
	board_system.invasion_completed.connect(_on_invasion_completed)
```

**質問**:
- [ ] 既存接続を完全に削除すべきか、それとも並存させるべきか？
- [ ] 並存させる場合、BUG-000（重複実行）が再発する可能性があるか？
- [ ] 削除する場合、どのファイルから削除すべきか？（3つのハンドラー全て？）

**確認したい理由**: 実装前にロールバック計画を立てるため

---

### Q4-2: invasion_completed リレー失敗時の対策

**具体的な質問内容**:

リレー実装後、もし通知が届かない場合：

**質問**:
- [ ] デバッグログはどこに出力すべきか？（各段階で print すべき？）
- [ ] ハンドラーが通知を受け取らない場合、どこをチェックすべきか？
- [ ] シグナル接続の `is_connected()` チェック忘れの可能性があるか？

**確認したい理由**: テスト・デバッグ戦略を事前に設定するため

---

### Q4-3: ロールバック手順の明確化

**計画には**:
```
ロールバック計画（所要時間: 1時間）:
1. BoardSystem3D の invasion_completed リレー削除
2. GameFlowManager の invasion_completed 受信削除
3. 各ハンドラーの接続先を BattleSystem に戻す
```

と書かれていますが、具体的な実装について：

**質問**:
- [ ] `git revert` で一括ロールバックすべきか、手動で削除すべきか？
- [ ] 上記 3ステップで十分か、他に必要な操作があるか？
- [ ] ロールバック後にテストすべき項目は何か？

**確認したい理由**: 緊急時の対応手順を明確にするため

---

## 質問グループ5: テスト・検証方針

### Q5-1: デバッグログの出力戦略

**具体的な質問内容**:

各段階でのリレーを確認するため、デバッグログが必要ですが：

```gdscript
# 各段階での出力
print("[BattleSystem] invasion_completed emit")
print("[TileBattleExecutor] invasion_completed emit")
print("[TileActionProcessor] invasion_completed 受信")
print("[TileActionProcessor] invasion_completed emit")
print("[BoardSystem3D] invasion_completed 受信")
print("[BoardSystem3D] invasion_completed emit")
print("[GameFlowManager] invasion_completed 受信")
print("[DominioCommandHandler] invasion_completed 受信")
```

**質問**:
- [ ] 全段階で出力すべきか、それとも重要な段階のみか？
- [ ] ログレベル（print vs push_warning）の使い分けは？
- [ ] 実装後、ログを削除すべきか、残すべきか？

**確認したい理由**: テスト効率を最大化するため

---

### Q5-2: シグナルフロー検証方法

**具体的な質問内容**:

実装後、シグナルが正しくリレーされているか検証する方法について：

**質問**:
- [ ] ゲーム起動後、戦闘を実行して出力ログで確認すべきか？
- [ ] デバッグコンソールで手動実行できるテストコマンドを用意すべきか？
- [ ] 複数の戦闘（3回以上）実行して、毎回ログが出力されるか確認すべきか？

**確認したい理由**: テスト手順を標準化するため

---

### Q5-3: CPU vs CPU での検証

**具体的な質問内容**:

Phase 2 では複数プレイヤー間の通知が重要ですが：

**質問**:
- [ ] CPU vs CPU で戦闘を実行し、ハンドラーが正しく動作するか確認すべきか？
- [ ] 手動プレイ（Player vs CPU）と CPU vs CPU の両方をテストすべきか？
- [ ] テスト時間は最小 3ターン、各ターンで戦闘を実行すべきか？

**確認したい理由**: テストカバレッジの範囲を確定するため

---

## 質問グループ6: ドキュメント・メンテナンス

### Q6-1: signal_catalog.md の更新内容

**計画では実装後に以下を更新すると書かれています**:

```
- [ ] `docs/implementation/signal_catalog.md` - invasion_completed リレー チェーン追加
```

**質問**:
- [ ] `signal_catalog.md` に新しいセクション「invasion_completed リレーチェーン」を追加すべきか？
- [ ] 既存の「BattleSystem」セクションに追記すべきか？
- [ ] 図式表現（ASCII or Mermaid）で表示すべきか？

**確認したい理由**: ドキュメント更新範囲を事前に確定するため

---

### Q6-2: TREE_STRUCTURE.md の更新

**計画では**:
```
Phase 2 実装後に以下のドキュメントを更新：
- [ ] `docs/design/TREE_STRUCTURE.md` - シグナルリレー順序を追加
```

と書かれていますが：

**質問**:
- [ ] TREE_STRUCTURE.md の「Game Flow」セクションに invasion_completed リレーを追加すべきか？
- [ ] 既存の「Tile Landing → Dominio → Turn End」などの説明に組み込むべきか？

**確認したい理由**: ドキュメント構造を事前に計画するため

---

### Q6-3: daily_log.md の更新ペース

**計画には**:
```
実装途中に各日のログを更新（毎日 1-2行）
実装完了後に成功指標と実装内容を記録
```

と書かれていますが：

**質問**:
- [ ] 各日の作業結果（完了した Task 番号など）を記録すべきか？
- [ ] 発生した問題・解決方法も記録すべきか？
- [ ] テスト結果（OK/NG）も記録すべきか？

**確認したい理由**: ドキュメント記録の標準形式を確定するため

---

## 質問グループ7: リスク・依存関係の再確認

### Q7-1: invasion_completed 以外のシグナル（movement_completed, level_up_completed）の扱い

**具体的な質問内容**:

依存関係マップに記載されているシグナル：

```
P0（最優先）:
1. invasion_completed - 戦闘結果の通知 ← Phase 2 で実装
2. movement_completed - 移動完了の通知 ← ?
3. action_completed - タイルアクション完了の通知 ← ?

P1（推奨）:
4. level_up_completed - レベルアップ完了の通知 ← ?
```

**質問**:
- [ ] Phase 2 では invasion_completed だけに集中すべきか？
- [ ] movement_completed も同時に実装すべきか？
- [ ] action_completed, level_up_completed は Phase 3 に延期すべきか？

**確認したい理由**: Phase 2 の実装スコープを明確にするため

---

### Q7-2: 既存シグナル接続の二重実行リスク

**具体的な質問内容**:

BUG-000（重複シグナル実行）を再発させないため：

```gdscript
# リスク: 古い接続と新しい接続が両方実行される？
battle_system.invasion_completed.connect(handler)  # 古い
board_system.invasion_completed.connect(handler)   # 新しい
```

**質問**:
- [ ] 既存接続を削除する前に、新規接続をテストすべきか？
- [ ] or 既存接続を先に削除してから新規接続を追加すべきか？
- [ ] テスト時に `is_connected()` チェックで両方の接続状況を監視すべきか？

**確認したい理由**: 実装順序のリスク回避策を決めるため

---

### Q7-3: TileActionProcessor の位置づけの再確認

**具体的な質問内容**:

TileActionProcessor は現在：

```
BoardSystem3D（親）
  └─ TileActionProcessor（子）
	  ├─ TileBattleExecutor（RefCounted、子）
	  └─ TileSummonExecutor（RefCounted、子）
```

という構造ですが、Phase 2 でリレーの中継点になります：

```
BattleSystem.invasion_completed
  → TileBattleExecutor（RefCounted）
  → TileActionProcessor（Node）のリレー
  → BoardSystem3D（Node）のリレー
  → GameFlowManager（Node）のリレー
```

**質問**:
- [ ] TileActionProcessor が中継点として十分な機能を持っているか？
- [ ] RefCounted の TileBattleExecutor から emit されたシグナルは Node の TileActionProcessor で受信できるか？
- [ ] 何か追加の設定や注意点があるか？

**確認したい理由**: アーキテクチャ上の問題の事前検出

---

## 要約: 実装前に確認すべき重要ポイント

| # | 質問 | 優先度 | 回答形式 |
|---|------|--------|----------|
| Q1-1 | TileBattleExecutor vs BattleSystem の invasion_completed | P0 | 確認 + 選択 |
| Q1-2 | TileActionProcessor の invasion_completed 受信確認 | P0 | 確認 + コード箇所 |
| Q1-3 | BoardSystem3D で新規シグナル定義の必要性 | P0 | Yes/No |
| Q1-4 | GameFlowManager での受信パターン | P0 | パターン選択 |
| Q2-1 | TileActionProcessor リレー実装の詳細 | P0 | 処理内容 |
| Q2-2 | BoardSystem3D リレー実装の詳細 | P0 | 実装パターン |
| Q2-3 | 既存接続の削除タイミング | P0 | 削除範囲指定 |
| Q2-4 | シグナル接続順序の確認 | P1 | 確認 |
| Q3-1 | 複数ハンドラーの通知順序 | P1 | 優先度指定 |
| Q3-2 | CPUTurnProcessor への通知方法 | P1 | パターン選択 |
| Q4-1 | 後方互換性の方針 | P0 | 削除 or 並存 |
| Q4-2 | リレー失敗時のデバッグ戦略 | P1 | チェック手順 |
| Q4-3 | ロールバック手順の確認 | P1 | 手順確認 |
| Q5-1 | デバッグログ出力戦略 | P1 | 出力箇所指定 |
| Q5-2 | シグナルフロー検証方法 | P1 | テスト方法 |
| Q5-3 | CPU vs CPU テスト方法 | P2 | テスト項目 |
| Q6-1 | signal_catalog.md 更新内容 | P1 | 更新パターン |
| Q6-2 | TREE_STRUCTURE.md 更新 | P1 | 追記場所指定 |
| Q6-3 | daily_log.md 記録方法 | P2 | 記録形式 |
| Q7-1 | 他シグナルの Phase 2 実装範囲 | P0 | スコープ確定 |
| Q7-2 | BUG-000 再発リスク対策 | P0 | 実装順序 |
| Q7-3 | TileActionProcessor の位置づけ確認 | P1 | 確認 |

---

**優先度凡例**:
- P0: 実装開始前に必ず確認（ブロッカー）
- P1: 実装途中に確認可能
- P2: テスト時に確認でよい

**次のアクション**: Sonnet に上記質問を送信し、回答を受け取った後、Haiku に実装を依頼

---

**作成日**: 2026-02-14
**作成者**: Haiku (質問セッション)
**ステータス**: 完成（回答待ち）
