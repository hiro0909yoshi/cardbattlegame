# 統合アーキテクチャ改善計画 - 実装ガイド

**最終更新**: 2026-02-14
**総工期**: 15-17日
**目的**: ツリー構造改善 + 神オブジェクト改善の統合実施

---

## 📋 Phase 一覧

| Phase | 内容 | 工数 | 状態 |
|-------|------|------|------|
| Phase 0 | ツリー構造定義 | 1日 | ✅ 完了 |
| Phase 1 | SpellSystemManager 導入 | 2日 | ⚪ 未着手 |
| Phase 2 | シグナルリレー整備 | 3日 | ⚪ 未着手 |
| Phase 3-A | SpellPhaseHandler Strategy化 | 4-5日 | ⚪ 未着手 |
| Phase 3-B | BoardSystem3D SSoT化 | 2-3日 | ⚪ 未着手 |
| Phase 4 | UIManager 責務分離 | 3-4日 | ⚪ 未着手 |
| Phase 5 | 統合テスト・ドキュメント | 2-3日 | ⚪ 未着手 |

---

## Phase 1: SpellSystemManager 導入（2日）

**目的**: スペルシステムの階層化によるツリー構造確立の第一歩

### 作業内容

- [ ] **タスク1-1**: SpellSystemManager クラス作成（4-5h）
  - ファイル: `scripts/game_flow/spell_system_manager.gd`
  - 内容: Node継承、SpellSystemContainer参照、アクセサメソッド

- [ ] **タスク1-2**: GameSystemManager 初期化更新（2-3h）
  - ファイル: `scripts/system_manager/game_system_manager.gd`
  - 変更: `_setup_spell_systems()` 内で SpellSystemManager 生成

- [ ] **タスク1-3**: GameFlowManager 参照追加（1h）
  - ファイル: `scripts/game_flow_manager.gd`
  - 追加: `var spell_system_manager: SpellSystemManager`

- [ ] **タスク1-4**: テスト・検証（2-3h）

### テストチェックポイント（壊れていないか確認）

#### 必須確認項目
- [ ] ゲーム起動エラーなし
- [ ] スペルフェーズが表示される
- [ ] スペル選択・実行が可能
- [ ] スペル実行で効果確認（カードドロー、EP変化等）
- [ ] 3ターン以上正常動作
- [ ] エラーログなし（push_error なし）

#### 詳細確認項目
- [ ] `[SpellSystemManager] 初期化完了` ログ出力
- [ ] `spell_system_manager` が null でない
- [ ] `spell_container` が null でない
- [ ] 既存の `spell_container` 参照が動作（後方互換性）
- [ ] CPU vs CPU でスペルが自動実行される

### 成功判定
- ✅ 全チェックポイント通過 → **Phase 2 へ進行**
- ❌ 1項目でも失敗 → **ロールバック（30分）**

### ロールバック手順（失敗時）
```bash
# 1. SpellSystemManager.gd 削除
rm scripts/game_flow/spell_system_manager.gd

# 2. GameSystemManager を元に戻す
git checkout scripts/system_manager/game_system_manager.gd

# 3. GameFlowManager を元に戻す
git checkout scripts/game_flow_manager.gd

# 4. 動作確認
# ゲーム起動 → スペルフェーズ動作確認
```

---

## Phase 2: シグナルリレー整備（3日）

**目的**: 横断的シグナル接続（12箇所）を除去し、親子チェーンを確立

### 作業内容

- [ ] **タスク2-1**: BoardSystem3D にリレーシグナル追加（4-5h）
  - 対象シグナル: `invasion_completed`, `movement_completed`, `level_up_completed`
  - BoardSystem3D にリレーシグナル定義
  - 子システムのシグナルを接続
  - ハンドラーで emit

- [ ] **タスク2-2**: ハンドラー接続先を変更（2-3h）
  - ファイル:
	- `scripts/game_flow/dominio_command_handler.gd`
	- `scripts/game_flow/land_action_helper.gd`
	- `scripts/cpu_ai/cpu_turn_processor.gd`
  - 変更: `BattleSystem.invasion_completed` → `BoardSystem3D.invasion_completed`

- [ ] **タスク2-3**: テスト・検証（4-6h）

### テストチェックポイント（壊れていないか確認）

#### 必須確認項目
- [ ] ゲーム起動エラーなし
- [ ] 戦闘が正常に実行される
- [ ] 侵略成功時にドミニオコマンドが表示される
- [ ] レベルアップ・移動・スワップが動作
- [ ] CPU vs CPU で戦闘が正常動作
- [ ] 3ターン以上正常動作

#### シグナルフロー確認（デバッグログ）
- [ ] `[BattleSystem] invasion_completed emit`
- [ ] `[TileActionProcessor] invasion_completed 受信`
- [ ] `[BoardSystem3D] invasion_completed リレー`
- [ ] `[GameFlowManager] invasion_completed 受信`
- [ ] `[DominioCommandHandler] invasion_completed 受信`
- [ ] シグナル重複接続なし（BUG-000 対策）

#### 詳細確認項目
- [ ] `movement_completed` がリレーされる
- [ ] `level_up_completed` がリレーされる
- [ ] 既存の直接接続が削除されている
- [ ] エラーログなし

### 成功判定
- ✅ 全チェックポイント通過 → **Phase 3-A, 3-B へ進行**
- ❌ 失敗 → **ロールバック（1時間）**

---

## Phase 3-A: SpellPhaseHandler Strategy パターン化（4-5日）

**目的**: 最大の神オブジェクト（1,764行）を 400行に削減

### 作業内容

- [ ] **タスク3A-1**: Strategy パターン基盤実装（2日）
  - `scripts/spells/spell_strategy.gd` - Interface
  - `scripts/spells/strategies/spell_effect_strategy.gd` - Base class
  - `scripts/spells/strategies/[spell_name]_strategy.gd` - Concrete classes
  - `scripts/spells/strategies/spell_strategy_factory.gd` - Factory

- [ ] **タスク3A-2**: 既存スペルの Strategy 移行（2-3日）
  - 移行対象: Resonance, Power Strike, Double Attack, First Strike, Instant Death, Penetration, Regeneration, Reflect, Nullify, Support, Assist（11個）
  - 1つずつ移行 → テスト

- [ ] **タスク3A-3**: SpellPhaseHandler 簡潔化（1-2日）
  - 80個メソッド → 10個に削減
  - Strategy 呼び出しに統一

- [ ] **タスク3A-4**: テスト・検証（1-2日）

### テストチェックポイント（壊れていないか確認）

#### 必須確認項目（スペルごと）
- [ ] Fireball Strategy: ダメージスペルが動作
- [ ] Freeze Strategy: 凍結スペルが動作
- [ ] Heal Strategy: 回復スペルが動作
- [ ] Draw Strategy: カードドロースペルが動作
- [ ] 全11個のスペルが動作

#### システム確認
- [ ] スペル選択UIが表示される
- [ ] `Strategy.validate()` が正しく判定
- [ ] `Strategy.execute()` が効果を適用
- [ ] SpellPhaseHandler が 400行以下
- [ ] 既存のスペルシステムとの互換性

#### 詳細確認項目
- [ ] SpellStrategyFactory が各 Strategy を生成
- [ ] 各 Strategy が独立してテスト可能
- [ ] 新スペル追加時に SpellPhaseHandler 変更不要
- [ ] 3ターン以上正常動作

### 成功判定
- ✅ 全チェックポイント通過 → **Phase 3-B と並行実施可能**
- ❌ 失敗 → **ロールバック（2時間）**

---

## Phase 3-B: BoardSystem3D SSoT 化（2-3日）

**目的**: クリーチャーデータを Single Source of Truth に統一

### 作業内容

- [ ] **タスク3B-1**: CreatureManager を SSoT に統一（1日）
  - `creatures: Dictionary` を唯一のデータソースに
  - `creature_changed` シグナル追加

- [ ] **タスク3B-2**: BaseTile と TileDataManager を参照に変更（1日）
  - BaseTile: getter/setter で CreatureManager 参照
  - TileDataManager: CreatureManager から取得

- [ ] **タスク3B-3**: シグナルチェーン構築（0.5-1日）
  - `CreatureManager.creature_changed` → `TileDataManager` → UI

- [ ] **タスク3B-4**: テスト・検証（0.5-1日）

### テストチェックポイント（壊れていないか確認）

#### 必須確認項目
- [ ] クリーチャー召喚が正常動作
- [ ] レベルアップ時にデータが正しく更新
- [ ] 移動時にクリーチャーが正しく移動
- [ ] スワップ時にクリーチャーが入れ替わる
- [ ] UI表示が正しく同期

#### データ整合性確認
- [ ] `CreatureManager.creatures` が唯一のデータソース
- [ ] `BaseTile.creature_data` が CreatureManager を参照
- [ ] TileDataManager が CreatureManager から取得
- [ ] `creature_changed` シグナルが正しく emit

#### 詳細確認項目
- [ ] 複数ターンでデータ一貫性が保たれる
- [ ] UI更新が自動的に行われる（シグナル経由）
- [ ] デバッグ時にデータソースが1つ
- [ ] 3ターン以上正常動作

### 成功判定
- ✅ 全チェックポイント通過 → **Phase 4 へ進行**
- ❌ 失敗 → **ロールバック（1.5時間）**

---

## Phase 4: UIManager 責務分離（3-4日）

**目的**: 1,069行の UIManager を 300行に削減、3個の独立 UIController に分割

### 作業内容

- [ ] **タスク4-1**: 3個の UIController 設計（4-6h）
  - HandUIController（200行）
  - BattleUIController（300行）
  - DominioUIController（200行）

- [ ] **タスク4-2**: 既存メソッドの各 Controller への分割（1.5日）
  - 93個メソッドを 3つの Controller に分散
  - 段階的分割: 1つのController ずつ実装・テスト

- [ ] **タスク4-3**: UIManager 簡潔化（0.5日）
  - 主要責務: 3つの Controller の登録・管理
  - Controller間の通信は UIManager 経由に限定

- [ ] **タスク4-4**: 統合テスト（1-2日）

### テストチェックポイント（壊れていないか確認）

#### 必須確認項目（UI領域ごと）
- [ ] HandUIController: 手札表示・カード選択が動作
- [ ] BattleUIController: バトル画面・HP表示が動作
- [ ] DominioUIController: レベルアップ・スワップUIが動作

#### システム確認
- [ ] UIManager が 300行以下
- [ ] UIManager メソッド数が 20個以下
- [ ] 各 UIController が独立して動作
- [ ] Controller間の通信が UIManager 経由

#### 詳細確認項目
- [ ] UI状態遷移が正常
- [ ] 新UI追加時に UIManager 変更不要
- [ ] 全UI機能が正常動作
- [ ] 3ターン以上正常動作

### 成功判定
- ✅ 全チェックポイント通過 → **Phase 5 へ進行**
- ❌ 失敗 → **ロールバック（1時間）**

---

## Phase 5: 統合テスト・ドキュメント更新（2-3日）

**目的**: 全体統合テスト、成果測定、ドキュメント更新

### 作業内容

- [ ] **タスク5-1**: 統合テスト（1日）
- [ ] **タスク5-2**: メトリクス測定（4-6h）
- [ ] **タスク5-3**: ドキュメント更新（6-8h）

### 統合テストチェックポイント

#### ゲーム機能確認（10+シーン）
- [ ] タイトル画面 → game_3d 遷移
- [ ] スペルフェーズ → ダイス → 移動 → アクション
- [ ] 召喚 → レベルアップ → 移動 → スワップ
- [ ] 戦闘（攻撃側勝利・防御側勝利）
- [ ] 通行料支払い → 破産処理
- [ ] 周回ボーナス → ダウン状態解除
- [ ] 手札破棄（7枚超）
- [ ] CPU vs CPU 30ターン以上

#### パフォーマンステスト
- [ ] FPS: 60fps 維持
- [ ] メモリ: 増加なし（リーク確認）
- [ ] ロード時間: 変化なし

#### エラーログ確認
- [ ] push_error() なし
- [ ] push_warning() のみ（適切な警告）
- [ ] null 参照エラーなし

### メトリクス測定

| メトリクス | Before | After | 改善率 |
|-----------|--------|-------|--------|
| 横断的シグナル接続 | 12箇所 | 0箇所 | 100% |
| 逆参照（子→親） | 5箇所 | 0箇所 | 100% |
| 最大ファイル行数 | 1,764行 | 400行 | 77% |
| 神オブジェクト数 | 3個 | 0個 | 100% |
| UIManager メソッド数 | 93個 | 20個 | 78% |

### ドキュメント更新

- [ ] `docs/design/TREE_STRUCTURE.md` - 最終構造反映
- [ ] `docs/design/dependency_map.md` - 改善後の状態記録
- [ ] `docs/progress/refactoring_next_steps.md` - Phase 1-4 完了記録
- [ ] `docs/implementation/signal_catalog.md` - シグナル一覧更新
- [ ] `CLAUDE.md` - Architecture Overview 更新
- [ ] `docs/progress/daily_log.md` - 全体成果記録

### 成功判定
- ✅ 全チェックポイント通過 → **プロジェクト完了！**

---

## 🎯 全体スケジュール（ガントチャート）

```
Week 1 (2/17-2/21):
├─ Mon-Tue: Phase 1 実装＋テスト
├─ Wed-Fri: Phase 2 実装＋テスト

Week 2 (2/24-2/28):
├─ Mon-Wed: Phase 3-A 実装＋テスト
└─ Thu-Fri: Phase 3-B 実装＋テスト

Week 3 (3/3-3/7):
├─ Mon-Wed: Phase 4 実装＋テスト
└─ Thu-Fri: Phase 5 統合テスト＋ドキュメント

総工期: 15日 ✅
```

---

## 📊 成功指標

### ツリー構造改善の指標
- [ ] 横断的シグナル接続: 12箇所 → 0箇所（100%削減）
- [ ] 逆参照: 5箇所 → 0箇所（100%削減）
- [ ] 新システム追加時に「どこに配置すべきか」が自明

### 神オブジェクト改善の指標
- [ ] 最大ファイル行数: 1,764行 → 400行（77%削減）
- [ ] 神オブジェクト数: 3個 → 0個（100%削減）
- [ ] スペル追加時間: 3-5日 → 1-2日（50%削減）
- [ ] バグ特定時間: 1週間 → 1-2日（85%削減）

### 統合効果の指標
- [ ] テスト容易性: 各責務をモック化して単独テスト可能
- [ ] 変更影響範囲: 機能追加時の修正ファイル数が 50%削減
- [ ] デバッグ時間: 平均 50%削減

---

## 🔗 関連ドキュメント

- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造
- `docs/design/dependency_map.md` - 現在の依存関係マップ
- `docs/design/god_object_quick_reference.md` - 神オブジェクト分析
- `docs/progress/architecture_migration_plan.md` - 元の移行計画
- `docs/progress/phase_1_questions.md` - Phase 1 実装前の質問
- `docs/progress/phase_1_answers.md` - Phase 1 質問への回答

---

**最終更新**: 2026-02-14
**次のアクション**: Phase 1 開始 → Haiku エージェントに実装依頼
