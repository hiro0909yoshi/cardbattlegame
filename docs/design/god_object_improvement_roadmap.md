# 神オブジェクト改善ロードマップ

**優先度**: **P0 - 即座に対応** (開発速度に大きく影響)

---

## クイックスタート: 次のアクションは？

### 👁️ 現状
プロジェクトには以下の神オブジェクトが存在：

| クラス | 行数 | 状態 |
|--------|------|------|
| **UIManager** | 1,069行 | UI全体が一元化 |
| **BoardSystem3D** | 1,031行 | ボード管理が集約 |
| **SpellPhaseHandler** | 1,764行 | スペル処理が一極化 |

### 🎯 推奨対応順序

#### **フェーズ1: State Machine クラス化 (既実装)**
✅ `GameFlowStateMachine` が既に実装されている
- 他のシステムも同じパターンを適用すべき
- `SpellPhaseStateMachine`, `DominioCommandStateMachine` を追加

**作業時間**: 1-2日
**優先度**: 🔴 高

---

#### **フェーズ2: SpellPhaseHandler の Strategy パターン適用 (最重要)**
現在の問題:
- スペル追加時に SpellPhaseHandler を毎回修正（変更箇所が増加）
- 1,764行で テスト困難

改善案:
```gdscript
# 各スペルを独立したクラスに
class FireballStrategy:
  func execute(context: SpellContext) -> bool:
	# Fireball logic only

# Handler はディスパッチャーに簡略化
func execute_spell(spell_data):
  var strategy = strategy_factory.create(spell_data.type)
  return strategy.execute(spell_context)
```

**効果**:
- SpellPhaseHandler: 1,764行 → 400行（77%削減）
- スペル追加時: SpellPhaseHandler 不要（新 Strategy のみ）

**作業時間**: 4-5日
**優先度**: 🔴 最高

---

#### **フェーズ3: UIManager の責務分離 (高価値)**
現在の問題:
- 新UI要素追加時に UIManager も修正（結合度が高い）
- 93個のメソッドで処理が分散

改善案:
```gdscript
# UI系統ごとにコントローラー化
class HandUIController:
  func update_display(player): ...
  func show(): ...

class BattleUIController:
  func show_battle_screen(): ...

# UIManager は登録・管理のみ
class UIManager:
  var hand_ui: HandUIController
  var battle_ui: BattleUIController
  # 各 UI の初期化・表示・非表示は各コントローラー
```

**効果**:
- UIManager: 1,069行 → 300行（72%削減）
- UI追加時: 新コントローラー追加のみ（UIManager 変更不要）

**作業時間**: 3-4日
**優先度**: 🟡 高

---

#### **フェーズ4: BoardSystem3D の SSoT 確立 (品質向上)**
現在の問題:
- `creature_data` が3箇所に存在（同期バグの原因）
- データ更新時の依存関係が複雑

改善案:
```gdscript
# CreatureManager を唯一の source
class CreatureManager:
  var creatures = {}  # tile_index -> creature_data

# tile_nodes はキャッシュ（読み取り専用アクセス）
var tile_nodes = {}  # 表示用キャッシュ

# 更新は CreatureManager 経由
func update_creature(tile_index, data):
  creature_manager.set_data(tile_index, data)
  # 変更通知 → TileDataManager, BaseTile が自動同期
```

**効果**:
- データ整合性バグ根絶
- デバッグ時間短縮（source が1つ）
- 予測可能な更新フロー

**作業時間**: 2-3日
**優先度**: 🟡 中

---

## 改善スケジュール提案

### オプション A: 短期集中型（2週間）
```
Week 1:
  Mon-Tue: State Machine クラス化
  Wed-Fri: SpellPhaseHandler Strategy パターン

Week 2:
  Mon-Wed: UIManager 責務分離
  Thu-Fri: テスト・デバッグ
```

### オプション B: 段階的型（4週間）
```
Week 1: SpellPhaseHandler Strategy パターン
Week 2: UIManager 責務分離
Week 3: BoardSystem3D SSoT 確立
Week 4: 統合テスト・ドキュメント
```

---

## 実装チェックリスト

### SpellPhaseHandler Strategy パターン

- [ ] `SpellStrategy` インターフェース定義
- [ ] 既存スペルを戦略に移行
  - [ ] Fireball → FireballStrategy
  - [ ] Freeze → FreezeStrategy
  - [ ] ... 他のスペル
- [ ] `SpellStrategyFactory` 実装
- [ ] SpellPhaseHandler を ディスパッチャーに変更
- [ ] ユニットテスト実装（各 Strategy）
- [ ] 統合テスト確認

### UIManager 責務分離

- [ ] `HandUIController` 実装
- [ ] `BattleUIController` 実装
- [ ] `PhaseUIController` 実装
- [ ] 既存参照を新 Controller に置き換え
- [ ] UIManager メソッドを削減（43個 → 20個程度）
- [ ] UI追加テスト（新 Controller 動作確認）

### BoardSystem3D SSoT 確立

- [ ] `TileDataManager` → `CreatureManager` 連携確立
- [ ] `BaseTile` → `CreatureManager` 経由に変更
- [ ] 更新シグナル チェーン構築
- [ ] データ同期テスト

---

## 期待効果（数値化）

### コード品質
- **神オブジェクト数**: 3個 → 0個
- **最大ファイル行数**: 1,764行 → 400行
- **500行超ファイル**: 15個 → 5-6個
- **テスト カバレッジ**: 現在 20% → 目標 60%

### 開発効率
- **スペル追加**: 3-5日 → 1-2日（新 Strategy のみ）
- **UI修正**: 2-3日 → 1日（該当 Controller のみ）
- **バグ特定**: 1週間 → 1-2日（責務明確）

### 保守性
- **可読性**: ⭐⭐ → ⭐⭐⭐⭐⭐
- **変更容易性**: ⭐⭐ → ⭐⭐⭐⭐
- **テスト性**: ⭐ → ⭐⭐⭐⭐⭐

---

## リスク管理

### リスク 1: 既存機能の破損
**対策**:
- 段階的な実装（デュアルモード）
- 既存ハンドラーと新 Strategy の共存期間を設定
- 各 Step で統合テスト実施

### リスク 2: 実装時間超過
**対策**:
- 最小限の MVP（Minimal Viable Product）から開始
- スペイン方式の反復開発（1 Strategy / day）
- リソース追加の判断基準を明確化

### リスク 3: 他チーム構成員の混乱
**対策**:
- 実装前に設計ドキュメント共有
- パターン適用の解説セッション
- 実装例を示すサンプルコード提供

---

## 関連ファイル

- 詳細分析: `/docs/analysis/god_object_analysis.md`
- アーキテクチャ: `/docs/design/design.md`
- 実装パターン: `/docs/implementation/implementation_patterns.md`
