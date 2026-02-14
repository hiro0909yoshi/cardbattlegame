# アーキテクチャ移行計画 - 進捗チェックリスト

**最終更新**: 2026-02-14（Phase 3-B Day 1-3 完全完了 + 周回システムバグ修正完了）
**目的**: Phase 0-5 の全体進捗を一目で把握する

**重要**:
- 詳細な作業計画は `refactoring_next_steps.md` を参照
- 完了記録は `daily_log.md` を参照

---

## 📊 全体進捗

```
Phase 0: ツリー構造定義        [✅ 完了] 1日   (2026-02-14)
Phase 1: SpellSystemManager    [✅ 完了] 2日   (2026-02-13)
Phase 2: シグナルリレー整備    [✅ 完了] 1日   (2026-02-14)
Phase 3-B: BoardSystem3D SSoT  [✅ 完了] 3日   (2026-02-14)
Phase 3-A: SpellPhaseHandler   [🔵 進行中] 4-5日 (Day 1-2 完了)
Phase 4: UIManager 責務分離    [⚪ 未着手] 3-4日
Phase 5: 統合テスト            [⚪ 未着手] 2-3日

完了: 7日 / 残り: 9-12日
```

---

## Phase 0: ツリー構造定義（1日）✅ 完了

**完了日**: 2026-02-14

### 成果物
- ✅ `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造（3階層）
- ✅ `docs/design/dependency_map.md` - 現在の依存関係マップ、問題12箇所特定
- ✅ `docs/progress/architecture_migration_plan.md` - Phase 1-4 詳細計画

### 効果
- ツリー構造が明確化
- 問題のある依存12箇所を特定
- Phase 1-4 の作業内容が明確化

---

## Phase 1: SpellSystemManager 導入（2日）✅ 完了

**完了日**: 2026-02-13

### 成果物
- ✅ `SpellSystemContainer` パターン導入
- ✅ 10+2個のスペルシステムを一元管理
- ✅ 辞書⇔個別変数の変換チェーン解消

### 効果
- コード削減: 約42行
- 保守性向上（SpellSystemContainer による一元管理）
- 型安全性向上

---

## Phase 2: シグナルリレー整備（1日）✅ 完了

**完了日**: 2026-02-14（計画3日 → 1日で完了、大幅前倒し）

### 実施内容
- ✅ **Day 1**: invasion_completed リレーチェーン実装
- ✅ **Day 2**: movement_completed, level_up_completed, terrain_changed 実装
- ✅ **Day 3**: start_passed, warp_executed, spell_used, item_used 実装

### 成果物
- ✅ 8種類のシグナルリレーチェーン実装
  - invasion_completed, movement_completed, level_up_completed, terrain_changed
  - start_passed, warp_executed, spell_used, item_used
- ✅ GameSystemManager でシグナル接続設定（is_connected() チェック）
- ✅ BUG-000 再発防止策完全実装

### 効果
- **横断的シグナル接続削減**: 12箇所 → 2箇所（83%削減）
- デバッグ容易性向上（各層でログ出力）
- ツリー構造の確立（子→親方向のみ）

### コミット
- cf0feb2: Phase 2 Day 1 実装
- ebe11e1: Phase 2 Day 2 実装
- （Day 3 コミット記録追加予定）

---

## Phase 3-B: BoardSystem3D SSoT 化（3日）✅ 完了

**完了日**: 2026-02-14（計画3日 → 実質3日、予定通り）

### 実施内容

#### ✅ Day 1: CreatureManager SSoT 化（2026-02-14）
- creature_changed シグナル定義・実装
- set_creature() メソッド実装（duplicate(true) で深いコピー）
- set_data() ラッパーで後方互換性維持
- BoardSystem3D._on_creature_changed() ハンドラー実装

#### ✅ Day 2: BaseTile/TileDataManager リファクタリング（2026-02-14）
- TileDataManager.get_creature() メソッド追加
- 既存コード722箇所の互換性確認（100%互換性確保）

#### ✅ Day 3: シグナルチェーン構築とテスト（2026-02-14）
- BoardSystem3D.creature_updated リレーシグナル追加
- GameFlowManager.creature_updated_relay リレー実装
- UIManager.on_creature_updated() ハンドラー追加
- CreatureInfoPanelUI.update_display() メソッド追加
- 統合テスト完了（3ターン以上正常動作）

### 成果物
- ✅ クリーチャーデータが1箇所に統一（SSoT パターン確立）
- ✅ データ不整合バグの防止
- ✅ UI 自動更新の実現（creature_changed → UI 即座に反映）
- ✅ デバッグ容易性向上（シグナルチェーンログ出力）

### コミット
- a6f9849: Day 1 シグナル基盤実装
- 6c4f902: Day 1 tile_nodes 修正
- f401950: Day 3 シグナルチェーン構築
- c37d5b6: Day 3 CreatureInfoPanelUI 修正

### 追加修正
- ✅ **LapSystem バグ修正**（2026-02-14）
  - 周回チェックポイント重複リセット問題修正
  - on_start_passed() の二重リセットを解消
  - CPU 方向選択の正常化
  - コミット: 750b0f1

---

## Phase 3-A: SpellPhaseHandler Strategy パターン化（4-5日）🔵 進行中

**開始日**: 2026-02-14（Day 1-2 完了）
**優先度**: P1（最優先）
**進捗**: Day 1-2 完了 ✅、Day 3-5 未着手

### 目的
- SpellPhaseHandler (1,764行) を Strategy パターンで分割
- 神オブジェクトの解消
- 新スペル追加の容易性向上

### 実施内容

#### ✅ Day 1-2: Strategy パターン基盤実装（完了）
- SpellStrategy 基底クラス作成（50行）
- SpellStrategyFactory 実装（35行）
- EarthShiftStrategy サンプル実装（60行）
- SpellPhaseHandler 統合（Strategy パターン試行 + フォールバック）

#### ⚪ Day 3-4: 既存スペルの Strategy 移行（未着手）
- 11個のスペルを Strategy に移行
- 各スペル1-1.5時間想定

#### ⚪ Day 5: SpellPhaseHandler 簡潔化 + テスト（未着手）
- SpellPhaseHandler を 400行に削減
- 統合テスト

### 成果物（Day 1-2）
- ✅ `scripts/spells/strategies/spell_strategy.gd` - 基底クラス
- ✅ `scripts/spells/strategies/spell_strategy_factory.gd` - Factory
- ✅ `scripts/spells/strategies/spell_strategies/earth_shift_strategy.gd` - サンプル
- ✅ `scripts/game_flow/spell_phase_handler.gd` - 統合修正

### 期待効果（最終）
- コード削減率: 77%（1,764行 → 400行）
- 新スペル追加時間: 50%削減
- テスト容易性向上

### コミット
- 8b3f19f: Day 1-2 基盤実装

**詳細は `refactoring_next_steps.md` を参照**

---

## Phase 4: UIManager 責務分離（3-4日）⚪ 未着手

**開始予定**: Phase 3-A 完了後
**優先度**: P2（中優先）

### 目的
- UIManager (1,069行) を3つの Controller に分割
- UI 変更時の影響範囲限定
- UI システムの独立性向上

### 実施内容
- HandUIController (200行) 抽出
- BattleUIController (300行) 抽出
- DominioUIController (200行) 抽出
- UIManager を 300行に削減

### 期待効果
- コード削減率: 72%（1,069行 → 300行）
- UI 変更時の影響範囲 60%削減

**詳細は `refactoring_next_steps.md` を参照**

---

## Phase 5: 統合テスト・ドキュメント更新（2-3日）⚪ 未着手

**開始予定**: Phase 3-A, 4 完了後
**優先度**: P3（低優先）

### 目的
- 統合テストの実施
- ドキュメントの最終更新
- 成果の測定

### 実施内容
- 統合テスト（10+シーン）
- パフォーマンステスト（FPS、メモリ）
- メトリクス測定（削減率計測）
- ドキュメント更新（全体）

---

## 🎯 全体の成功指標

### 定量的指標

| メトリクス | Before | After（目標） | 現在の進捗 |
|-----------|--------|--------------|-----------|
| 横断的シグナル接続 | 12箇所 | 0箇所 | **2箇所（83%削減）** ✅ |
| 逆参照（子→親） | 5箇所 | 0箇所 | 調査中 |
| 最大ファイル行数 | 1,764行 | 400行 | 1,764行（未着手） |
| 神オブジェクト数 | 3個 | 0個 | 3個（未着手） |
| ツリー階層 | 2階層 | 3-4階層 | **3階層確立** ✅ |

### 定性的指標

- ✅ 新システム追加時に「どこに配置すべきか」が自明（TREE_STRUCTURE.md 確立）
- ✅ シグナルフローが一本の親子チェーンで表現可能（8種類実装完了）
- ⚪ 子システムが親のモックだけでテスト可能（未達成）
- ✅ ツリー図を見れば全体像が理解できる（TREE_STRUCTURE.md）
- ⚪ デバッグ時間が50%削減（測定中）

---

## 🔗 関連ドキュメント

### 設計ドキュメント
- `docs/design/TREE_STRUCTURE.md` - 理想的なツリー構造
- `docs/design/dependency_map.md` - システム依存関係マップ
- `docs/design/god_object_quick_reference.md` - 神オブジェクト分析

### 進捗管理
- `docs/progress/refactoring_next_steps.md` - **次のアクション詳細**（作業計画）
- `docs/progress/daily_log.md` - **完了記録**（セッション単位）
- `docs/progress/phase_3b_implementation_plan.md` - Phase 3-B 詳細計画
- `docs/progress/phase_2_day2_3_plan.md` - Phase 2 Day 2-3 計画

### その他
- `docs/progress/signal_cleanup_work.md` - シグナル改善計画（元計画、参考）

---

**最終更新**: 2026-02-14（Phase 3-B Day 1-3 完全完了 + 周回システムバグ修正完了）
**次のアクション**: Phase 3-A 開始準備（詳細は `refactoring_next_steps.md` 参照）
