# Phase 2 Day 2-3 実装計画

**最終更新**: 2026-02-14
**策定者**: Opus Agent (a0b7965)

---

## 背景と現状

**Phase 2 Day 1 完了状況**:
- ✅ invasion_completed リレーチェーン完全実装・テスト完了
- ✅ 横断的シグナル接続: 12箇所 → 9箇所（3箇所削減）
- ✅ シグナルリレーパターン確立

**確立されたリレーパターン**:
```
BattleSystem.invasion_completed
  → TileActionProcessor._on_invasion_completed()
  → BoardSystem3D._on_invasion_completed()
  → GameFlowManager._on_invasion_completed_from_board()
    ├→ DominioCommandHandler._on_invasion_completed()
    └→ CPUTurnProcessor._on_invasion_completed()
```

---

## 残り9箇所の横断的シグナル接続

### 1. movement_completed（優先度: High）

- **現在のパターン**: MovementController3D → BoardSystem3D（リレー済み）が、GameFlowManager が受信していない
- **理想のリレーチェーン**:
  ```
  MovementController3D.movement_completed
    → BoardSystem3D._on_movement_completed()
    → BoardSystem3D.movement_completed.emit()
    → GameFlowManager._on_movement_completed_from_board()
      ├→ DominioCommandHandler へ通知（タイル到着処理）
      └→ LandActionHelper へ通知（アクション表示）
  ```
- **影響範囲**: 4ファイル（BoardSystem3D, GameFlowManager, DominioCommandHandler, LandActionHelper）
- **難易度**: Low（invasion_completed と完全同パターン）
- **推定工数**: 2時間
- **優先度**: Day 2（最優先）
- **リスク**: シグナル接続順序の問題（中）
- **緩和策**: GameSystemManager での段階的接続、is_connected() チェック
- **テスト項目**: 移動完了後のタイルアクション表示、CPU移動処理

---

### 2. level_up_completed（優先度: High）

- **現在のパターン**: BoardSystem3D が emit するが、GameFlowManager が受信していない
- **理想のリレーチェーン**:
  ```
  TileDataManager.level_up_completed（未定義）
    → BoardSystem3D._on_level_up_completed()
    → BoardSystem3D.level_up_completed.emit()
    → GameFlowManager._on_level_up_completed_from_board()
      ├→ DominioCommandHandler へ通知
      └→ UIManager へ通知
  ```
- **影響範囲**: 3ファイル（BoardSystem3D, GameFlowManager, DominioCommandHandler）
- **難易度**: Low
- **推定工数**: 1.5時間
- **優先度**: Day 2
- **リスク**: UI更新タイミングのズレ（中）
- **緩和策**: デバッグログで各ステップ確認
- **テスト項目**: レベルアップ後のUI更新、ドミニオコマンド表示

---

### 3. terrain_changed（優先度: Medium）

- **現在のパターン**: BoardSystem3D が emit するが、GameFlowManager 以上に伝播していない
- **理想のリレーチェーン**:
  ```
  BoardSystem3D.terrain_changed.emit()
    → GameFlowManager._on_terrain_changed_from_board()
      └→ SpellPhaseHandler or UIManager へ通知
  ```
- **影響範囲**: 2ファイル（BoardSystem3D, GameFlowManager）
- **難易度**: Low
- **推定工数**: 1時間
- **優先度**: Day 2（後半）
- **リスク**: スペルフェーズとの連携（低）
- **緩和策**: 既存の terrain_changed 受信者を確認
- **テスト項目**: 地形変更スペル実行、UI表示確認

---

### 4. start_passed（優先度: Medium）

- **現在のパターン**: MovementController3D が emit するが、直接受信者が不明確
- **理想のリレーチェーン**:
  ```
  MovementController3D.start_passed
    → BoardSystem3D._on_start_passed()
    → BoardSystem3D.start_passed.emit()（新規）
    → GameFlowManager._on_start_passed_from_board()
      └→ LapSystem.on_start_passed()
  ```
- **影響範囲**: 4ファイル（MovementController3D, BoardSystem3D, GameFlowManager, LapSystem）
- **難易度**: Low
- **推定工数**: 1.5時間
- **優先度**: Day 3（優先度中）
- **リスク**: 周回処理との二重実行（中）
- **緩和策**: LapSystem の is_connected() チェック確認
- **テスト項目**: スタート通過時のボーナス処理、周回カウント更新

---

### 5. warp_executed（優先度: Medium）

- **現在のパターン**: MovementController3D が emit するが、GameFlowManager へ伝播していない
- **理想のリレーチェーン**:
  ```
  MovementController3D.warp_executed
    → BoardSystem3D._on_warp_executed()
    → BoardSystem3D.warp_executed.emit()（新規）
    → GameFlowManager._on_warp_executed_from_board()
      └→ SpellPhaseHandler or 各ハンドラーへ通知
  ```
- **影響範囲**: 3ファイル（MovementController3D, BoardSystem3D, GameFlowManager）
- **難易度**: Low
- **推定工数**: 1.5時間
- **優先度**: Day 3
- **リスク**: ワープスペルとの連携（低）
- **緩和策**: スペルシステムとの統合テスト
- **テスト項目**: ワープスペル実行、移動処理確認

---

### 6. spell_used（優先度: Medium）

- **現在のパターン**: SpellPhaseHandler → UIManager（横断的接続）
- **理想のリレーチェーン**:
  ```
  SpellPhaseHandler.spell_used
    → GameFlowManager._on_spell_used()
    → UIManager._on_spell_used()（リレー）
  ```
- **影響範囲**: 3ファイル（SpellPhaseHandler, GameFlowManager, UIManager）
- **難易度**: Low
- **推定工数**: 1時間
- **優先度**: Day 3（低優先）
- **リスク**: UI更新タイミング（低）
- **緩和策**: 既存のスペル処理フローを維持
- **テスト項目**: スペル使用後のUI更新

---

### 7. item_used（優先度: Medium）

- **現在のパターン**: ItemPhaseHandler → UIManager（横断的接続）
- **理想のリレーチェーン**:
  ```
  ItemPhaseHandler.item_used
    → GameFlowManager._on_item_used()
    → UIManager._on_item_used()（リレー）
  ```
- **影響範囲**: 3ファイル（ItemPhaseHandler, GameFlowManager, UIManager）
- **難易度**: Low
- **推定工数**: 1時間
- **優先度**: Day 3（低優先）
- **リスク**: UI更新タイミング（低）
- **緩和策**: 既存のアイテム処理フローを維持
- **テスト項目**: アイテム使用後のUI更新

---

### 8. dominio_command_closed（優先度: Low）

- **現在のパターン**: DominioCommandHandler → GameFlowManager（既接続）
- **状態**: 既にリレーパターン実装済み
- **確認項目**: is_connected() チェック確認
- **推定工数**: 0.5時間（レビューのみ）
- **優先度**: Day 3（確認のみ）
- **テスト項目**: 接続確認のみ

---

### 9. tile_selection_completed（優先度: Low）

- **現在のパターン**: TargetSelectionHelper → GameFlowManager（既接続）
- **状態**: 既にリレーパターン実装済み
- **確認項目**: is_connected() チェック確認
- **推定工数**: 0.5時間（レビューのみ）
- **優先度**: Day 3（確認のみ）
- **テスト項目**: 接続確認のみ

---

## Day 2 実装タスク（1日、4-5時間）

### タスク2-4-1: movement_completed リレーチェーン実装（2時間）

**ステップ**:
1. GameFlowManager に `_on_movement_completed_from_board()` ハンドラー追加
2. GameSystemManager でシグナル接続設定（is_connected() チェック）
3. DominioCommandHandler, LandActionHelper へ通知分配
4. デバッグログ追加（各ステップ）
5. テスト: 移動完了後のタイルアクション表示確認

---

### タスク2-4-2: level_up_completed リレーチェーン実装（1.5時間）

**ステップ**:
1. BoardSystem3D の level_up_completed シグナル接続確認
2. GameFlowManager に `_on_level_up_completed_from_board()` ハンドラー追加
3. GameSystemManager でシグナル接続設定
4. DominioCommandHandler, UIManager へ通知分配
5. テスト: レベルアップ後のUI更新確認

---

### タスク2-4-3: terrain_changed リレーチェーン実装（1時間）

**ステップ**:
1. GameFlowManager に `_on_terrain_changed_from_board()` ハンドラー追加
2. GameSystemManager でシグナル接続設定
3. SpellPhaseHandler or UIManager へ通知
4. デバッグログ追加
5. テスト: 地形変更スペル実行確認

---

### タスク2-4-4: Day 2 テスト・検証（0.5時間）

**テスト項目**:
- [ ] コンパイル: GDScript 構文エラーなし
- [ ] シグナル接続: 重複接続エラーなし
- [ ] 移動完了: タイルアクション表示正常
- [ ] レベルアップ: UI更新正常
- [ ] 地形変更: スペル実行正常
- [ ] デバッグログ: 各リレーステップで出力確認

---

## Day 3 実装タスク（1日、3-4時間）

### タスク2-5-1: start_passed, warp_executed リレーチェーン実装（2.5時間）

**ステップ（start_passed）**:
1. BoardSystem3D に `start_passed` シグナル定義
2. BoardSystem3D に `_on_start_passed()` ハンドラー追加
3. GameFlowManager に `_on_start_passed_from_board()` ハンドラー追加
4. LapSystem へ通知
5. テスト: スタート通過時のボーナス処理

**ステップ（warp_executed）**:
1. BoardSystem3D に `warp_executed` シグナル定義
2. BoardSystem3D に `_on_warp_executed()` ハンドラー追加
3. GameFlowManager に `_on_warp_executed_from_board()` ハンドラー追加
4. テスト: ワープスペル実行確認

---

### タスク2-5-2: spell_used, item_used リレーチェーン実装（1時間）

**ステップ（spell_used）**:
1. GameFlowManager に `_on_spell_used()` ハンドラー追加
2. SpellPhaseHandler → GameFlowManager 接続を GameSystemManager で設定
3. UIManager へリレー

**ステップ（item_used）**:
1. GameFlowManager に `_on_item_used()` ハンドラー追加
2. ItemPhaseHandler → GameFlowManager 接続を GameSystemManager で設定
3. UIManager へリレー

---

### タスク2-5-3: リレー済み項目の確認（0.5時間）

**確認項目**:
- [ ] dominio_command_closed: is_connected() チェック確認
- [ ] tile_selection_completed: is_connected() チェック確認

---

### タスク2-5-4: Day 3 統合テスト・検証（1時間）

**テスト項目**:
- [ ] スタート通過: 周回処理正常
- [ ] ワープスペル: 移動処理正常
- [ ] スペル使用: UI更新正常
- [ ] アイテム使用: UI更新正常
- [ ] CPU vs CPU: 5ターン以上正常動作
- [ ] 全シグナルリレー: デバッグログ確認

---

## 全体スケジュール

- **Day 2**（4-5時間）: movement_completed, level_up_completed, terrain_changed
- **Day 3**（3-4時間）: start_passed, warp_executed, spell_used, item_used + 統合テスト

---

## 成功指標

- [x] 横断的シグナル接続: 12箇所 → 9箇所（invasion_completed 完了）
- [ ] 横断的シグナル接続: 9箇所 → 3-4箇所（Day 2-3 完了）
  - 削減対象: movement_completed, level_up_completed, start_passed, warp_executed, spell_used, item_used
  - 確認済み: dominio_command_closed, tile_selection_completed
- [ ] すべてのリレーチェーンが「子→親→祖父」の3階層モデルに統一
- [ ] UIManager への横断的接続最小化
- [ ] 全テスト項目クリア

---

## リスク分析

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| invasion_completed との二重呼び出し | 🟡 中 | 低 | リレーパターン確立済み、CONNECT_ONE_SHOT の活用 |
| シグナル接続順序の問題 | 🟡 中 | 中 | GameSystemManager での段階的接続、is_connected() チェック |
| UI更新タイミングのズレ | 🟡 中 | 中 | デバッグログで各ステップ確認、スクリーンショット検証 |
| パフォーマンス低下 | 🟢 低 | 低 | リレー層の追加は軽量（呼び出し1回追加程度） |
| 既存機能の破損 | 🔴 高 | 低 | 段階的実装、各シグナル実装後にテスト |

---

## 優先度判断基準

1. **ゲームフロー上の重要度**: movement_completed, level_up_completed が最重要（ターン進行の核）
2. **実装難易度**: 全てLow（invasion_completed と同パターン）
3. **影響範囲**: 少ないもの優先
4. **依存関係**: 上流システム（移動→レベルアップ）優先
5. **テスト容易性**: MovementController よりも BoardSystem3D を先に実装

---

## 重要ファイル

- `scripts/board_system_3d.gd` - リレーポイント（movement, level_up, start_passed, warp_executed ハンドラー追加）
- `scripts/game_flow_manager.gd` - リレー受信者（全BoardSystem3Dシグナルを受信・分配）
- `scripts/system_manager/game_system_manager.gd` - 接続コーディネーター（is_connected() チェック）
- `scripts/game_flow/dominio_command_handler.gd` - 下流受信者（movement, level_up通知受信）
- `scripts/movement_controller.gd` - シグナルソース（movement, start_passed, warp_executed定義）

---

**策定日**: 2026-02-14
**Opus Agent ID**: a0b7965
