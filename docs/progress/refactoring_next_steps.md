# 📋 次のリファクタリング作業

**最終更新**: 2026-02-13
**目的**: セッション間で作業計画が失われないよう、次にやることを明確に記録

---

## 🔴 最優先フェーズ（P2）

### フェーズ5-A: State Machine クラス化（Task 6）

**優先度**: P2
**見積時間**: 3-4時間
**難易度**: 中
**タスク**: Task #6

#### Context（背景・目的）

GameFlowManagerの現在のフェーズ管理は、enum + 直接代入モデルで実装されており、以下の課題がある：

1. **状態遷移ロジックの分散化**
   - フェーズ遷移が `current_phase = GamePhase.XXX` で複数箇所に散在
   - GameFlowManager内で少なくとも8箇所で直接代入（line 202, 224, 246, 256, 260, 287等）
   - 遷移の妥当性チェックが存在しない

2. **デバッグの困難さ**
   - 無効な遷移（例：BATTLE→SETUP）がコンパイル時に検出されない
   - 遷移経路が不明確で、フェーズスキップのバグ特定が困難

3. **テスト容易性の低さ**
   - フェーズ遷移の検証が困難
   - モック化できない

**推奨アクション**:
- GameFlowStateMachine クラスを新規作成
- フェーズ遷移を一元管理
- UIボタン処理への影響は最小化

#### ユーザーの懸念への回答

**Q: UIボタン処理に影響しないか？**
- A: **影響しません**。State Machineはフェーズ遷移の内部実装のみを変更し、GameFlowManagerの外部インターフェースは変わりません。UIボタン処理に調整は不要です。

**Q: 後方互換性は？**
- A: GamePhase enum は保持するため、外部からの参照は引き続き使用可能です。

#### 実装ステップ

##### ステップ1: GameFlowStateMachine クラス作成

**新規作成**: `scripts/game_flow/game_flow_state_machine.gd`

**実装内容**:
- GamePhase enum への参照
- 状態遷移のホワイトリスト管理
- transition_to() メソッド
- state_changed シグナル
- デバッグログ機能

**影響**: ゼロ（新規ファイル）

##### ステップ2: GameFlowManager に State Machine を統合

**修正ファイル**: `scripts/game_flow_manager.gd`

**修正内容**:
- `_state_machine: GameFlowStateMachine` 変数追加
- _init_state_machine() メソッド追加
- _on_state_changed() シグナルハンドラー追加
- change_phase() メソッドを State Machine 経由に変更

**影響**: GameFlowManager内の change_phase() 呼び出しは自動的に State Machine 経由になる

##### ステップ3: 既存フェーズ遷移を State Machine 経由に置換

**修正ファイル**: `scripts/game_flow_manager.gd`

**修正箇所一覧** (全8箇所):
- line 202: `current_phase = GamePhase.DICE_ROLL` → `change_phase(GamePhase.DICE_ROLL)`
- line 224: `current_phase = GamePhase.DICE_ROLL` → `change_phase(GamePhase.DICE_ROLL)`
- line 246: `change_phase(GamePhase.TILE_ACTION)` → そのまま（既に関数経由）
- line 256: `current_phase = GamePhase.DICE_ROLL` → `change_phase(GamePhase.DICE_ROLL)`
- line 260: `current_phase = GamePhase.DICE_ROLL` → `change_phase(GamePhase.DICE_ROLL)`

**影響**: 全フェーズ遷移が State Machine 経由になり、遷移検証が自動的に実施される

##### ステップ4: State Machine シグナルの UI 層への接続

**修正ファイル**: `scripts/game_flow_manager.gd`

**修正内容**:
- State Machine の state_changed シグナルを UI の phase_changed シグナルに橋渡し
- 既存の phase_changed シグナルは互換性のため保持

**影響**: UIManager 等の外部リスナーは既存の phase_changed シグナルで動作

#### 対象ファイル一覧

| ファイル | 操作 | 理由 |
|---------|------|------|
| scripts/game_flow/game_flow_state_machine.gd | 新規作成 | State Machine 本体 |
| scripts/game_flow_manager.gd | 修正 | State Machine の統合、フェーズ遷移の置換 |

#### リスク と 対策

| リスク | 深刻度 | 対策 |
|-------|--------|------|
| Phase遷移の見落とし | 中 | ステップ3で全8箇所を grep で抽出・確認 |
| 外部からの current_phase 直接代入 | 低 | current_phase は保持、State Machine経由が推奨 |
| State Machine 初期化忘れ | 中 | setup_systems() 内で明示的に初期化 |
| 既存UI（phase_changed シグナル）との互換性喪失 | 低 | _on_state_changed() で既存シグナルを emit |

#### テスト・検証手順

1. **State Machine 単体テスト**
   - 有効な遷移が成功することを確認
   - 無効な遷移がエラーログを出すことを確認

2. **GameFlowManager 統合テスト**
   - ゲーム開始
   - 複数ターン実行
   - 各フェーズで正常に遷移することを確認

3. **UI フェーズ表示テスト**
   - phase_display が正常に更新されることを確認

#### 破壊的変更の有無

- **UIボタン処理への影響**: **なし**
- **既存のゲームロジック**: **なし**
- **データ互換性**: **なし**

---

### フェーズ5-B: Object Pool パターン導入（Task 7）

**優先度**: P2
**見積時間**: 2-3時間
**難易度**: 中
**タスク**: Task #7

#### Context（背景・目的）

BattleScreenManager では、バトル画面の UI エレメントが毎回インスタンス化・破棄されている。頻繁にバトルが発生する場合、GC圧力が高まり、フレームドロップが発生しやすい。

**問題点**:
1. バトル画面生成の度に new/free が発生
2. GC圧力が高い（頻繁なメモリ割り当て/解放）
3. フレームドロップの可能性

**期待効果**:
- バトル画面レスポンス向上（～50msの高速化）
- GC 圧力削減（メモリ断片化防止）

#### 実装ステップ

##### ステップ1: ObjectPool クラス作成

**新規作成**: `scripts/system/object_pool.gd`

**実装内容**:
- 汎用 Object Pool クラス
- register_pool() メソッド
- get_instance() / return_instance() メソッド
- プール枯渇時の対応

**影響**: ゼロ（新規ファイル）

##### ステップ2: BattleScreen を Object Pool 対応にする

**修正ファイル**: `scripts/battle_screen/battle_screen.gd`

**修正内容**:
- reset() メソッド追加

**影響**: BattleScreen の軽微な変更

##### ステップ3: BattleScreenManager を Object Pool 対応にする

**修正ファイル**: `scripts/battle_screen/battle_screen_manager.gd`

**修正内容**:
- Object Pool 初期化（_ready()）
- start_battle() で get_instance() を使用
- close_battle_screen() で return_instance() を使用

**影響**: BattleScreenManager の内部実装のみ変更

#### 対象ファイル一覧

| ファイル | 操作 | 理由 |
|---------|------|------|
| scripts/system/object_pool.gd | 新規作成 | 汎用 Object Pool |
| scripts/battle_screen/battle_screen_manager.gd | 修正 | Pool の統合 |
| scripts/battle_screen/battle_screen.gd | 修正 | reset() メソッド追加 |

#### リスク と 対策

| リスク | 深刻度 | 対策 |
|-------|--------|------|
| BattleScreen インスタンスの不正な再利用 | 中 | reset() メソッドで確実にリセット |
| プール枯渇時の動的生成 | 低 | プール初期サイズを適切に設定（3-5） |

#### テスト・検証手順

1. **Object Pool 単体テスト**
   - get_instance() で取得可能
   - return_instance() で正常に返却可能

2. **BattleScreenManager 統合テスト**
   - 複数バトル実行（3回以上）
   - 各バトルで画面が正常に表示される
   - GC 時間を記録（改修前後で比較）

#### 破壊的変更の有無

- **UIボタン処理への影響**: **なし**
- **既存のゲームロジック**: **なし**
- **データ互換性**: **なし**

---

### フェーズ5-C: BattleParticipant のコンポーネント化（Task 8）

**優先度**: P2
**見積時間**: 8-10時間
**難易度**: 高
**タスク**: Task #8

#### Context（背景・目的）

BattleParticipant は現在、単一のクラスで複数の責務を持つ monolithic 設計になっており、以下の課題がある：

**責務の混在**:
1. HP/ダメージ管理（8種類のHP値）
2. AP/攻撃力管理
3. スキル管理
4. 状態・フラグ管理

**問題点**:
1. テスト困難性
2. 再利用性の低さ
3. 責務の変更難易度が高い
4. バグの温床

**期待効果**:
- テストの単純化
- スキルシステムへの拡張が容易
- HP計算の一元化

#### 実装ステップ

##### ステップ1: コンポーネントクラスの作成

**新規作成**:
1. `scripts/battle/components/health_component.gd`
2. `scripts/battle/components/attack_power_component.gd`
3. `scripts/battle/components/skill_component.gd`
4. `scripts/battle/components/status_effect_component.gd`

**影響**: ゼロ（新規ファイル）

##### ステップ2: BattleParticipant をリファクタリング

**修正ファイル**: `scripts/battle/battle_participant.gd`

**修正内容**:
- コンポーネント変数追加
- 既存の HP/AP 変数をプロパティに変換（互換性保持）
- 既存メソッドをコンポーネントに委譲

**影響**: BattleParticipant のインターフェースは変わらず（互換性保持）

##### ステップ3: BattleExecution / BattlePreparation のコンポーネント対応

**修正ファイル**:
- `scripts/battle/battle_preparation.gd`
- `scripts/battle/battle_execution.gd`
- `scripts/battle/battle_skill_processor.gd`

**修正内容**:
- コンポーネント経由でのHP/AP操作に変更

**影響**: バトルシステム全体への影響（高リスク）

#### 対象ファイル一覧

| ファイル | 操作 | 理由 |
|---------|------|------|
| scripts/battle/components/*.gd | 新規作成 | 4つのコンポーネント |
| scripts/battle/battle_participant.gd | 修正 | コンポーネント統合 |
| scripts/battle/battle_execution.gd | 修正 | コンポーネント経由 |
| scripts/battle/battle_preparation.gd | 修正 | コンポーネント経由 |
| scripts/battle/battle_skill_processor.gd | 修正 | コンポーネント経由 |

#### リスク と 対策

| リスク | 深刻度 | 対策 |
|-------|--------|------|
| HP計算の不整合 | **高** | 互換性レイヤー設定、手作業テスト実施 |
| コンポーネント初期化順序の問題 | 高 | BattlePreparation で初期化順を厳格に管理 |
| スキル適用時の副作用管理 | 高 | StatusEffectComponent で副作用を一元管理 |

#### テスト・検証手順

1. **コンポーネント単体テスト**
   - 各コンポーネントの動作確認

2. **互換性テスト**
   - 既存コードで BattleParticipant.current_hp にアクセス可能か確認

3. **バトルシステム統合テスト**
   - 複数バトル実行（5-10回）
   - HP計算が既存と一致しているか確認

4. **リグレッションテスト**
   - スキル適用が正常か確認
   - 状態効果が正常に適用されるか確認

#### 破壊的変更の有無

- **UIボタン処理への影響**: **なし**
- **既存のゲームロジック**: **なし**（互換性レイヤーで対応）
- **データ互換性**: **要確認**（HP計算結果が同じか手作業確認）

---

## 完了したフェーズ（参考）

### ✅ GDScript パターン監査 P0/P1 タスク（完了：2026-02-13）

- ✅ Task #1: 型指定なし配列の修正
- ✅ Task #2: spell_container の null チェック完全化
- ✅ Task #3: Optional型注釈を追加
- ✅ Task #4: プライベート変数命名規則を統一
- ✅ Task #5: Signal 接続重複チェック完全化

**コミット**: 5個作成（0d2a38d, 90963e9, 6d6cfb7, 63f85dc, c553a14）

---

### ✅ フェーズ4-A: BUG-000完全解決（完了：2026-02-13）

**作業内容**: シグナル接続の重複排除（`is_connected()` チェック追加）

**完了内容**:
- 7ファイル、16箇所のシグナル接続に `is_connected()` チェック追加
- GameFlowManager, DominioCommandHandler, HandDisplay, BattleLogUI, TileActionProcessor, BoardSystem3D

**成果**:
- BUG-000（ターンスキップ）の根本原因を解決
- イベントハンドラーの多重実行を防止

---

### ✅ フェーズ3-D: SpellSystemContainer導入（完了）

（既存の完了内容を維持）

---

## テスト・検証計画（全体）

### P2 タスク完了後の統合テスト

1. **ゲーム1周プレイスルー** （約20分）
   - 複数ターン実行（5-10ターン）
   - 各フェーズで正常に遷移することを確認

2. **バトル重視テスト** （10回以上）
   - 複数ユニット組み合わせでバトル実施
   - HP計算が正確か確認

3. **パフォーマンスプロファイル**
   - GC 時間測定（Task 7 で 50% 削減期待）
   - フェーズ遷移時間測定
   - メモリ使用量比較

---

## 見積り時間サマリー

| タスク | 見積時間 | 難易度 | 優先度 |
|--------|---------|--------|--------|
| Task 6: State Machine クラス化 | 3-4時間 | 中 | P2 |
| Task 7: Object Pool 導入 | 2-3時間 | 中 | P2 |
| Task 8: BattleParticipant コンポーネント化 | 8-10時間 | 高 | P2 |
| **合計** | **13-17時間** | - | P2 |

---

**注意**: このファイルは常に最新状態に保つこと。作業計画を詰めたら即座に更新する。
