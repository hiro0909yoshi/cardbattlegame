# GameSystemManager 実装レポート

**実装日**: 2025-11-22  
**版**: 1.0  
**ステータス**: ゲーム起動確認済み

---

## 概要

GameSystemManager を実装し、game_3d.gd の複雑な初期化処理を一元管理しました。
6フェーズ初期化により、初期化順序を明確化し、保守性を向上させました。

---

## 実装内容

### ファイル作成

| ファイル | 行数 | 概要 |
|---------|------|------|
| scripts/system_manager/game_system_manager.gd | 560 | 新規作成：6フェーズシステム統括管理 |
| scripts/game_3d.gd | 70 | 簡潔化：200行 → 70行、GameSystemManager へ委譲 |

### 6フェーズ初期化

| フェーズ | 処理内容 | 実装状況 |
|---------|---------|---------|
| **Phase 1** | 11個システム作成 | ✅ 完了 |
| **Phase 2** | 3Dノード収集 | ✅ 完了 |
| **Phase 3** | 基本設定（PlayerSystem, BoardSystem3D） | ✅ 完了 |
| **Phase 4** | システム間参照設定 | ✅ 完了（一部削除） |
| **Phase 5** | シグナル接続 | ✅ 完了 |
| **Phase 6** | ゲーム開始準備 | ✅ 完了 |

---

## 実装で判明した問題と解決策

### 問題1: Spell系システムの初期化重複

**発生内容**:
```
エラー: Invalid assignment of property 'card_system' with value of type 'Node (CardSystem)' 
		on a base object of type 'Node (SpellDraw)'
```

**根本原因**:
- SpellDraw, SpellMagic, SpellDice 等は GameFlowManager._setup_spell_systems() で既に作成・setup() 済み
- GameSystemManager の Phase 4-2 で直接プロパティ設定しようとしたため発生

**解決方法**:
```gdscript
# ❌ 削除した方法（エラー原因）
game_flow_manager.spell_draw.card_system = card_system  # プロパティ直接設定

# ✅ 採用した方法
# Phase 4-2 から Spell系の参照設定を完全削除
# GameFlowManager.setup_systems() → _setup_spell_systems() で既に初期化済みのため
```

**学習ポイント**:
- 子システムが既に別の親システムで setup() 済みの場合、GameSystemManager では参照設定しない
- Spell系は GameFlowManager の責務範囲内

---

### 問題2: プロセッサーの初期化重複

**発生内容**:
```
エラー: Invalid assignment of property 'board_system_3d' with value of type 'Node (BoardSystem3D)' 
		on a base object of type 'Node (TileActionProcessor)'
```

**根本原因**:
- TileActionProcessor, CPUTurnProcessor, MovementController は BoardSystem3D._ready() で既に setup() 済み
- GameSystemManager の Phase 4-3 で直接プロパティ設定しようとしたため発生

**解決方法**:
```gdscript
# ❌ 削除した方法（エラー原因）
board_system_3d.tile_action_processor.board_system = board_system_3d
board_system_3d.tile_action_processor.player_system = player_system
# ... その他プロセッサー設定

# ✅ 採用した方法
# Phase 4-3 を完全削除
# BoardSystem3D._ready() で既に全プロセッサーが setup() で初期化済みのため
```

**実装の流れ**:
1. BoardSystem3D._ready() が実行される
2. TileActionProcessor, CPUTurnProcessor 等が作成される
3. setup() メソッドで各プロセッサーが初期化される
4. GameSystemManager は何もしない（既に完了している）

**学習ポイント**:
- 大規模な子システムを持つシステムは、自身の _ready() で子システムを初期化する
- GameSystemManager はそのような複雑な初期化には関与しない

---

### 問題3: CPUAIHandler の参照エラー

**発生内容**:
```
エラー: Invalid assignment of property 'board_system_3d' with value of type 'Node (BoardSystem3D)' 
		on a base object of type 'Node (CPUAIHandler)'
```

**根本原因**:
- CPUAIHandler は board_system_3d プロパティを持たず、board_system プロパティを持つ
- GameFlowManager._ready() で既に作成・setup_systems() 済み
- GameSystemManager で参照設定しようとしたため発生

**解決方法**:
```gdscript
# ❌ 削除した方法
game_flow_manager.cpu_ai_handler.board_system_3d = board_system_3d  # プロパティ名誤り + 重複設定

# ✅ 採用した方法
# Phase 4-2 から CPUAIHandler への参照設定を削除
# GameFlowManager._ready() → cpu_ai_handler.setup_systems() で既に初期化済みのため
```

**学習ポイント**:
- プロパティ名の統一性が重要（board_system vs board_system_3d）
- 同じシステムを複数の親から参照設定しない

---

## 最終的な実装構造

### Phase 4 の実装内容

```
Phase 4-1: 基本システム参照設定（実装）
  - GameFlowManager.setup_systems()
  - BoardSystem3D.setup_systems()
  - SpecialTileSystem.setup_systems()
  - DebugController.setup_systems()
  - UIManager への参照設定
  - UIManager.create_ui()
  - CardSelectionUI への参照設定
  - BattleSystem への参照設定
  - GameFlowManager.setup_3d_mode()
  ✅ 実装完了

Phase 4-2: GameFlowManager 子システム初期化（簡潔化）
  - DominioOrderHandler への参照設定のみ
  - SpellPhaseHandler への参照設定
  - ItemPhaseHandler への参照設定
  - （Spell系は削除 → GameFlowManager が管理）
  - （CPUAIHandler は削除 → GameFlowManager._ready()済み）
  ✅ 簡潔化完了

Phase 4-3: BoardSystem3D 子システム初期化（削除）
  - 何もしない（BoardSystem3D._ready()で既に初期化済み）
  ✅ 完了
```

---

## カメラ位置の問題

### 現在の状況

ゲーム起動時のカメラ位置が期待値（Vector3(19, 19, 19)）と異なる可能性があります。

### 原因の候補

1. **GameSystemManager Phase 3 での設定**:
   ```gdscript
   camera_3d.position = Vector3(19, 19, 19)
   ```
   この設定が他の処理で上書きされている可能性

2. **game_3d.gd でのカメラ初期化**:
   元のコードで camera.look_at() を呼ぶと位置が変わる可能性

3. **BoardSystem3D での camera 参照設定後の処理**:
   collect_players() 内で camera を使用する際に位置が変更される可能性

### 推奨対応

1. **デバッグ確認**:
   ```gdscript
   # game_3d.gd の _ready() 内で確認
   await system_manager.initialize_all(...)
   print("カメラ位置: ", get_node("Camera3D").position)
   ```

2. **カメラ位置の再設定**:
   ```gdscript
   # system_manager.initialize_all() 後に再設定
   var camera = get_node("Camera3D")
   if camera:
	   camera.position = Vector3(19, 19, 19)
	   camera.look_at(...)  # 必要に応じて
   ```

3. **GameSystemManager の修正**:
   Phase 3 でカメラ設定をより後段階に移動することを検討

---

## チェックリスト（今後の参考）

### 新しいシステム追加時

- [ ] システムの _ready() で何が実行されるかを確認
- [ ] 子システムが setup() メソッドを持つかどうかを確認
- [ ] プロパティ名が一貫しているかを確認（特に board_system 系）
- [ ] 複数の親から同じシステムへ参照設定していないかを確認
- [ ] エラーメッセージから「プロパティが見つからない」と出たら、別の初期化方法を検討

### 大規模リファクタリング時

- [ ] システム間の依存関係図を作成
- [ ] 各システムの初期化順序をドキュメント化
- [ ] _ready() と setup() の役割分担を明確化
- [ ] 子システムの初期化責務を決定（親か子か）

---

## まとめ

### 達成した目標

✅ game_3d.gd を 200行 → 70行に簡潔化  
✅ 11個システムの初期化を 6フェーズで明確化  
✅ システム間の依存関係を整理  
✅ ゲーム起動確認完了

### 残存する課題

⚠️ カメラ位置の設定（要確認・調整）

### 学習成果

- システム初期化の責務分離の重要性
- 子システムが既に初期化済みの場合の処理方法
- プロパティ名の統一の重要性
- 複雑な初期化ロジックはシステムの _ready() に任せるべき

---

**作成日**: 2025-11-22  
**バージョン**: 1.0
