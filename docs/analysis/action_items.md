# GDScript パターン監査 - アクション項目リスト

**監査日**: 2026-02-13
**総合評価**: ⭐⭐⭐⭐ (4/5)

---

## 優先度別タスク

### P0: 即座に修正（セキュリティ・パフォーマンス影響）

#### Task 1: 型指定なし配列の修正
**カテゴリ**: パフォーマンス
**影響範囲**: 3ファイル
**見積時間**: 1-2時間
**難易度**: 低

**対象ファイル**:
1. `/Users/andouhiroyuki/cardbattlegame/scripts/board_system_3d.gd`
   - Line 46: `var tile_nodes = {}` → `var tile_nodes: Dictionary = {}`
   - Line 47: `var player_nodes = []` → `var player_nodes: Array[Node] = []`

2. `/Users/andouhiroyuki/cardbattlegame/scripts/card_system.gd`
   - Line 23-25: player_decks, player_discards, player_hands に型を付与
   ```gdscript
   var player_decks: Dictionary = {}  # player_id -> Array[int]
   var player_discards: Dictionary = {}  # player_id -> Array[int]
   var player_hands: Dictionary = {}  # player_id -> {"data": Array}
   ```

3. `/Users/andouhiroyuki/cardbattlegame/scripts/player_system.gd`
   - Line 36: `var players = []` → `var players: Array[PlayerData] = []`
   - Line 38: `var player_pieces = []` → `var player_pieces: Array[Node] = []`

**テスト方法**:
- ゲーム全体を1周プレイ
- パフォーマンスプロファイラーでGC時間を確認
- 改修前後で比較

---

#### Task 2: spell_container の null チェック完全化
**カテゴリ**: 安全性
**影響範囲**: 2ファイル
**見積時間**: 1時間
**難易度**: 低

**対象ファイル**:
1. `/Users/andouhiroyuki/cardbattlegame/scripts/game_flow_manager.gd`
   - spell_container へのアクセスは全て以下パターンで
   ```gdscript
   if spell_container and spell_container.spell_draw:
       var drawn = spell_container.spell_draw.draw_one(player_id)
   else:
       push_error("[GFM] spell_draw が初期化されていません")
       return
   ```

2. `/Users/andouhiroyuki/cardbattlegame/scripts/battle_system.gd`
   - Line 68-72: spell_magic/spell_draw の null チェックを完全化

**テスト方法**:
- ゲーム開始直後のスペル使用テスト
- デバッグコンソールでエラーが出ないことを確認

---

#### Task 3: Optional型注釈を追加（全参照）
**カテゴリ**: 型安全性
**影響範囲**: 8ファイル
**見積時間**: 2-3時間
**難易度**: 低

**対象箇所一覧**:

`game_flow_manager.gd`:
```gdscript
Line 39:  var board_system_3d = null → var board_system_3d: BoardSystem3D = null
Line 46:  var player_system = null → var player_system: PlayerSystem = null
Line 47:  var card_system = null → var card_system: CardSystem = null
Line 48:  var player_buff_system = null → var player_buff_system: PlayerBuffSystem = null
Line 49:  var ui_manager = null → var ui_manager: UIManager = null
Line 50:  var battle_system = null → var battle_system: BattleSystem = null
Line 82:  var lap_system = null → var lap_system: LapSystem = null
```

`board_system_3d.gd`:
```gdscript
Line 31:  var movement_controller = null → var movement_controller: MovementController3D = null
Line 32:  var tile_info_display = null → var tile_info_display: TileInfoDisplay = null
Line 33:  var tile_data_manager = null → var tile_data_manager: TileDataManager = null
Line 34:  var tile_neighbor_system = null → var tile_neighbor_system: TileNeighborSystem = null
Line 35:  var tile_action_processor = null → var tile_action_processor: TileActionProcessor = null
Line 59:  var game_flow_manager = null → var game_flow_manager: GameFlowManager = null
Line 62:  var spell_land = null → var spell_land: SpellLand = null
```

`battle_system.gd`:
```gdscript
Line 22:  var board_system_ref = null → var board_system_ref: BoardSystem3D = null
Line 41:  var lap_system = null → var lap_system: LapSystem = null
```

`player_system.gd`:
```gdscript
Line 47:  var board_system_ref = null → var board_system_ref: BoardSystem3D = null
Line 48:  var magic_stone_system_ref = null → var magic_stone_system_ref: MagicStoneSystem = null
```

`ui_manager.gd`:
```gdscript
Line 38:  var card_system_ref = null → var card_system_ref: CardSystem = null
Line 39:  var player_system_ref = null → var player_system_ref: PlayerSystem = null
Line 40:  var board_system_ref = null → var board_system_ref: BoardSystem3D = null
Line 41:  var game_flow_manager_ref = null → var game_flow_manager_ref: GameFlowManager = null
Line 42:  var spell_phase_handler_ref = null → var spell_phase_handler_ref: SpellPhaseHandler = null
Line 43:  var dominio_command_handler_ref = null → var dominio_command_handler_ref: DominioCommandHandler = null
```

**テスト方法**:
- IDE で型サジェストが表示されることを確認
- GDScript ロケット型チェッカーで警告なしを確認

**チェックリスト**:
- [ ] 全ファイルの null 初期化変数に型を付与
- [ ] IDE サジェストが正常に動作することを確認
- [ ] コンパイル警告がないことを確認

---

### P1: 次のリファクタリング時に修正（保守性・品質向上）

#### Task 4: プライベート変数命名規則を統一
**カテゴリ**: コード品質
**影響範囲**: 1ファイル
**見積時間**: 30分
**難易度**: 低

**対象ファイル**:
`/Users/andouhiroyuki/cardbattlegame/scripts/game_flow_manager.gd`

**修正内容**:
```gdscript
Line 75:  var is_ending_turn = false
          → var _is_ending_turn = false
          （全ての参照箇所も更新）

Line 76:  var _input_locked: bool = false  ✓ 既に正しい
```

**テスト方法**:
- ターン遷移テスト
- フェーズ遷移時にエラーが出ないことを確認

---

#### Task 5: Signal 接続重複チェック完全化
**カテゴリ**: 安全性
**影響範囲**: 1ファイル
**見積時間**: 1時間
**難易度**: 低

**対象ファイル**:
`/Users/andouhiroyuki/cardbattlegame/scripts/board_system_3d.gd`

**現状分析**:
```gdscript
Line 119-126: 既に is_connected() でチェック済み ✓

# 他のシグナル接続箇所を確認が必要
```

**修正パターン**:
```gdscript
if not signal_name.is_connected(callback):
    signal_name.connect(callback)
```

**チェックリスト**:
- [ ] BoardSystem3D 内の全シグナル接続を確認
- [ ] 重複接続チェックが不足している箇所を特定
- [ ] テストプレイで「多重接続」エラーが出ないことを確認

---

### P2: 長期計画（パフォーマンス・拡張性向上）

#### Task 6: State Machine クラス化（オプション）
**カテゴリ**: アーキテクチャ
**影響範囲**: GameFlowManager
**見積時間**: 3-4時間
**難易度**: 中

**目的**: フェーズ遷移ロジックを統一・検証

**実装内容**:
1. `GameFlowStateMachine` クラスを新規作成
2. 状態遷移のホワイトリスト管理
3. GameFlowManager から統合

**メリット**:
- デバッグ効率向上
- 無効遷移の検出
- テスト容易性向上

**優先度が高い場合**:
- フェーズ周期のバグが多い場合
- 新しいフェーズの追加が予定されている場合

---

#### Task 7: Object Pool パターン導入
**カテゴリ**: パフォーマンス
**影響範囲**: BattleScreenManager
**見積時間**: 2-3時間
**難易度**: 中

**対象**: バトル画面の UI エレメント
- ダメージ表示
- ターン開始/終了 UI
- コマンド選択パネル

**メリット**:
- バトル画面のレスポンス向上
- GC 圧力削減

**優先度が高い場合**:
- バトル画面でのフレームドロップがある場合
- バトルが頻繁に発生するゲームモード追加時

---

#### Task 8: BattleParticipant のコンポーネント化
**カテゴリ**: 設計
**影響範囲**: バトルシステム全体
**見積時間**: 8-10時間
**難易度**: 高

**現状**: BattleParticipant が多数の責務を持つ
```
- HP管理
- スキル適用
- 状態管理
- ダメージ計算
```

**提案**: コンポーネント分割
```
- HealthComponent: HP/ダメージ
- SkillComponent: スキル適用
- StatusComponent: 状態管理
- StatsComponent: 攻撃力等
```

**優先度が高い場合**:
- バトルシステムの大規模改修予定
- 新しいステータス効果を頻繁に追加する場合
- ユニットテストの導入を予定している場合

---

## 実装チェックリスト

### P0 タスク完了チェック

- [ ] Task 1: 型指定なし配列の修正
  - [ ] board_system_3d.gd 修正
  - [ ] card_system.gd 修正
  - [ ] player_system.gd 修正
  - [ ] ゲーム1周プレイテスト実施
  - [ ] パフォーマンス比較（GC時間）

- [ ] Task 2: spell_container null チェック完全化
  - [ ] game_flow_manager.gd 修正
  - [ ] battle_system.gd 修正
  - [ ] スペル使用テスト実施
  - [ ] デバッグコンソール確認

- [ ] Task 3: Optional型注釈を追加
  - [ ] game_flow_manager.gd 完了
  - [ ] board_system_3d.gd 完了
  - [ ] battle_system.gd 完了
  - [ ] player_system.gd 完了
  - [ ] ui_manager.gd 完了
  - [ ] その他ファイル確認
  - [ ] IDE サジェスト確認
  - [ ] 型チェッカー実行

### P1 タスク完了チェック

- [ ] Task 4: プライベート変数命名規則統一
  - [ ] game_flow_manager.gd 修正
  - [ ] ターン遷移テスト実施

- [ ] Task 5: Signal 接続重複チェック完全化
  - [ ] BoardSystem3D 確認
  - [ ] その他ファイル確認
  - [ ] テストプレイ実施

---

## テスト計画

### P0 テスト（必須）

**テスト1: ゲーム全体プレイスルー**
- 実施時間: 10-15分
- 手順:
  1. ゲーム開始
  2. 複数ターン実行（3-5ターン）
  3. スペル、アイテム使用
  4. バトル実施（複数回）
  5. デバッグコンソールをチェック（エラー・警告なし）

**テスト2: パフォーマンスプロファイル**
- GDScript プロファイラー実行
- GC 時間を記録
- 改修前後で比較

---

## 見積り時間サマリー

| 優先度 | タスク | 時間 | 合計 |
|--------|--------|------|------|
| P0 | Task 1-3 | 1-2h + 1h + 2-3h | **4-6時間** |
| P1 | Task 4-5 | 0.5h + 1h | **1.5時間** |
| P2 | Task 6-8 | 3-4h + 2-3h + 8-10h | **13-17時間** |

**P0 実施推奨期間**: 今週中（1セッション）
**P1 実施推奨期間**: 1-2週間以内
**P2 実施推奨期間**: 1-3ヶ月以内

---

## 参考: 修正テンプレート

### テンプレート1: 型指定なし配列

```gdscript
# Before
var items = []

# After
var items: Array[String] = []
```

### テンプレート2: Optional型注釈

```gdscript
# Before
var system = null

# After
var system: SystemName = null
```

### テンプレート3: signal 接続チェック

```gdscript
# Before
signal_name.connect(callback)

# After
if not signal_name.is_connected(callback):
    signal_name.connect(callback)
```

### テンプレート4: null チェック（チェーン）

```gdscript
# Before
var value = obj.child.method()

# After
if obj and obj.child:
    var value = obj.child.method()
else:
    push_error("[System] obj or child is null")
    return
```

---

## ドキュメント更新

修正完了後、以下を更新してください:

1. **docs/progress/daily_log.md**
   - 修正内容をログに記録

2. **docs/issues/resolved_issues.md**
   - 解決した問題を記録

3. **docs/design/coding_standards.md** (必要に応じて)
   - Optional型注釈のガイドラインを追記

---

**作成日**: 2026-02-13
**次回レビュー**: 修正完了後 1週間以内
