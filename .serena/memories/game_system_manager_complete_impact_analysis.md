# GameSystemManager 設計 - 完全な影響範囲分析（2025-11-22）

## プロジェクト全体構成

### ファイル数
- 実装コード: **60+ ファイル**（.gd ファイルのみ）
- UI コンポーネント: **10+ ファイル**
- バトルシステム: **25+ ファイル**（skills含む）
- スペルシステム: **7+ ファイル**
- ゲームフロー: **10+ ファイル**

**合計: 約120ファイル以上**（.uid ファイル除外）

---

## GameSystemManager が管理する必要があるシステム

### 【Tier 1】 必須システム（必ず初期化が必要）

1. **SignalRegistry** - シグナル通信の中核
2. **BoardSystem3D** - 3Dゲームボード管理
3. **PlayerSystem** - プレイヤー状態管理
4. **CardSystem** - カードとデッキ管理
5. **BattleSystem** - バトル制御
6. **PlayerBuffSystem** - プレイヤーバフ管理
7. **SpecialTileSystem** - 特殊タイル処理
8. **UIManager** - UI全般管理
9. **DebugController** - デバッグ機能
10. **GameFlowManager** - ゲームフロー制御

---

## GameFlowManager が管理する子システム群

GameFlowManager 内部で初期化される：

1. **spell_draw: SpellDraw** - ドロー処理
2. **spell_magic: SpellMagic** - 魔力操作
3. **spell_land: SpellLand** - 土地操作
4. **spell_curse: SpellCurse** - 呪いシステム
5. **spell_dice: SpellDice** - ダイス操作
6. **spell_curse_stat: SpellCurseStat** - ステータス呪い
7. **land_command_handler: LandCommandHandler** - 領地コマンド処理
8. **spell_phase_handler: SpellPhaseHandler** - スペルフェーズ
9. **item_phase_handler: ItemPhaseHandler** - アイテムフェーズ
10. **cpu_ai_handler: CPUAIHandler** - CPU AI処理

---

## BoardSystem3D が管理する子システム群

BoardSystem3D 内部で初期化される：

1. **tile_action_processor: TileActionProcessor** - タイル処理
2. **cpu_turn_processor: CPUTurnProcessor** - CPUターン処理
3. **movement_controller: MovementController** - プレイヤー移動

---

## システム間参照関係（複雑度が高い）

### 双方向参照（循環依存の可能性あり）
- game_3d.gd → GameFlowManager
- GameFlowManager → board_system_3d
- board_system_3d → game_flow_manager（参照がある）
- GameFlowManager → ui_manager
- ui_manager → game_flow_manager_ref

### 多段階参照
- board_system_3d → cpu_ai_handler → player_buff_system
- tile_action_processor → game_flow_manager → spell_*
- spell_phase_handler → game_flow_manager → spell_*

---

## GameSystemManager に追加すべき項目

### Phase 1: システム作成（現在のプラン）
✅ 既定の 9 つのシステム

### Phase 4: システム間連携設定に追加すべき内容

**GameFlowManager 内部の初期化**:
```
- spell_draw.setup()
- spell_magic.setup()
- spell_land.setup()  ← 複雑（board_system, creature_manager, player_system, card_system）
- spell_curse.setup()
- spell_dice.setup()
- spell_curse_stat.setup()
```

**BoardSystem3D 内部の初期化**:
```
- tile_action_processor.setup()  ← 複雑（複数参照）
- cpu_turn_processor.setup()
- movement_controller.setup()
- cpu_ai_handler.setup()
```

**GameFlowManager のハンドラー初期化**:
```
- land_command_handler.initialize()
- spell_phase_handler.initialize()
- item_phase_handler.initialize()
```

### Phase 5: シグナル接続に追加すべき内容
- 現在の計画: ✅ 十分
- 追加: CPU関連シグナルの確認

---

## 潜在的な問題点

### 1. 初期化順序の複雑性
現在のドキュメント案では不十分:
- spell_land.setup() が複数参照を必要とする
- tile_action_processor が 8+ の参照を必要とする
- 順序を間違えると参照エラーが発生する可能性

### 2. CreatureManager の扱い
- spell_land, spell_curse で CreatureManager が必要
- 現在のシステムに含まれていない
- 初期化タイミングが不明確

### 3. TileDataManager の扱い
- board_system_3d で使用される
- 初期化ロジックが不明確

---

## 修正が必要な箇所

### 1. ドキュメントの Phase 4 が不完全
現在のドキュメント案では、GameFlowManager の子システム初期化を十分に記載していない

### 2. システム間参照の複雑性が隠蔽されている
- spell_land.setup() → board_system, creature_manager, player_system, card_system
- tile_action_processor.setup() → 8個の参照
- これらの複雑な依存関係を明示する必要

### 3. 実装スケジュール（75分）は楽観的
実際の複雑度を考えると：
- ドキュメント確認: 15分
- GameSystemManager実装: 60-90分（複雑性が高い）
- game_3d.gd修正: 15分
- システム連携テスト: 30分以上

**推定: 2-3時間**

---

## 結論

ドキュメント案の構造は正しいが、**Phase 4 の詳細が不十分**。

特に：
1. GameFlowManager の 10個の子システム初期化
2. BoardSystem3D の 3個の子システム初期化
3. CreatureManager の初期化タイミング
4. TileDataManager の初期化タイミング

これらを **明示的に Phase に分割**する必要がある。

推奨：
- Phase 4 を細分化（Step を 20+ に増やす）
- 各 Step で参照関係を明示
- 実装スケジュールを 2-3 時間に修正
