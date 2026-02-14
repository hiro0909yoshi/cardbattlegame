# 📋 次のリファクタリング作業

**最終更新**: 2026-02-14
**目的**: セッション間で作業計画が失われないよう、次にやることを明確に記録

**確立したワークフロー**:
```
1. Opus: Phase 計画立案 → refactoring_next_steps.md に記載
2. Haiku: 計画を読んで実装
3. Sonnet: ドキュメント更新・完了報告
4. 次の Phase へ（繰り返し）
```

---

## ✅ 完了済みフェーズ（簡潔版）

詳細は `daily_log.md` および `architecture_migration_plan.md` を参照してください。

### Phase 0: ツリー構造定義（2026-02-14）✅
- **成果**: `TREE_STRUCTURE.md`, `dependency_map.md`, `architecture_migration_plan.md` 作成
- **効果**: ツリー構造が明確化、問題箇所の特定完了

### Phase 1: SpellSystemManager 導入（2026-02-13）✅
- **成果**: SpellSystemContainer パターン導入（10+2個のスペルシステムを一元管理）
- **効果**: コード削減約42行、保守性向上

### Phase 2: シグナルリレー整備（2026-02-14）✅
- **成果**: 8種類のシグナルリレーチェーン実装（invasion, movement, level_up, terrain, start_passed, warp, spell_used, item_used）
- **効果**: 横断的シグナル接続 12箇所 → 2箇所（83%削減）

### Phase 3-B: BoardSystem3D SSoT 化（2026-02-14）✅
- **Day 1-3**: CreatureManager SSoT 化 + シグナルチェーン構築
- **成果**: creature_updated リレーチェーン完全動作、UI 自動更新の実現
- **効果**: データ不整合バグの防止、デバッグ容易性向上
- **コミット**: a6f9849, 6c4f902, f401950, c37d5b6
- **追加修正**: LapSystem 周回チェックポイント重複リセット問題修正（750b0f1）

### Phase 3-A: SpellPhaseHandler Strategy パターン化 - Day 1-2（2026-02-14）✅
- **実装内容**: Strategy パターン基盤実装（基底クラス + Factory + サンプル）
- **成果**: SpellStrategy, SpellStrategyFactory, EarthShiftStrategy 作成
- **効果**: 拡張性向上、テスト容易性向上、コード構造明確化
- **コミット**: 8b3f19f
- **次**: Day 3-4（既存11スペルの Strategy 移行）

---

## 🎯 現在のフェーズ: Phase 3-A - SpellPhaseHandler Strategy パターン化（進行中）

**優先度**: P1（最優先）
**実装時間**: 4-5日（Day 1-2 完了、残り 2-3日）
**担当**: Haiku（実装）、Opus（計画立案）
**進捗**: Day 1-2 完了 ✅

### なぜ P1 か？

1. **神オブジェクト解消**: 最大の神オブジェクト（1,764行）を分割
2. **新スペル追加が容易**: Strategy パターンで拡張性向上
3. **Phase 3-B 完了**: データ基盤が固まったため、上位層の整理に着手可能

---

### 実施内容

**現状の問題**:
```gdscript
SpellPhaseHandler: 1,764行
- 全スペルのロジックが1ファイルに集約
- 新スペル追加時に SpellPhaseHandler を修正
```

**理想形（Strategy パターン）**:
```gdscript
SpellPhaseHandler: 400行（77%削減）
├── SpellStrategyFactory
└── 各 Strategy（独立したファイル）
	├── FireballStrategy
	├── FreezeStrategy
	├── HealStrategy
	└── ...（11個のスペル）
```

---

### タスク一覧（4-5日）

#### Day 1-2: Strategy パターン基盤実装（2日）
1. **SpellStrategy 基底クラス作成**（4-5時間）
   - `scripts/spells/strategies/spell_strategy.gd` 新規作成
   - `validate(context: Dictionary) -> bool` インターフェース定義
   - `execute(context: Dictionary) -> void` インターフェース定義

2. **SpellStrategyFactory 実装**（3-4時間）
   - `scripts/spells/strategies/spell_strategy_factory.gd` 新規作成
   - スペルID → Strategy クラスのマッピング
   - `create_strategy(spell_id: String) -> SpellStrategy`

3. **サンプル Strategy 実装**（2-3時間）
   - FireballStrategy（ファイアボール）を最初に実装
   - 動作確認・テスト

#### Day 3-4: effect_type Strategies 移行（2日）
4. **effect_type を Strategy に変換**（12-16時間）
   - 各 effect_type 1-1.5時間想定
   - 実装順序（優先度順）:
	 1. change_element（アースシフト等）✅ Day 1-2 実装済み
	 2. damage（エレメンタルラス、サンダークラップ等）
	 3. heal/full_heal（ライフストリーム、リストア等）
	 4. creature_move（アウトレイジ等の移動系）
	 5. land_change（アステロイド等の土地変更）
	 6. draw_card（ドロー系）
	 7. curse_apply（呪い系）
	 8. その他の effect_type（残り10-15個）

#### Day 5: SpellPhaseHandler 簡潔化 + テスト（1日）
5. **SpellPhaseHandler リファクタリング**（4-5時間）
   - 1,764行 → 400行に削減
   - 各スペル処理を Factory 経由の Strategy 呼び出しに統一
   - 既存のスペル処理ロジックを削除

6. **統合テスト・検証**（3-4時間）
   - 全11スペルが動作確認
   - 3ターン以上正常動作
   - エラーログなし確認

---

### 成功基準

- [ ] SpellStrategy 基底クラス作成完了
- [ ] SpellStrategyFactory 実装完了
- [ ] 11個のスペル Strategy 移行完了
- [ ] SpellPhaseHandler 400行以下に削減
- [ ] 全スペル動作確認（3ターン以上）
- [ ] エラーログなし
- [ ] コード削減率: 77%達成

---

### リスク分析

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| 既存スペル処理が動作しなくなる | 🔴 高 | 中 | 1スペルずつ移行、各ステップでテスト |
| Strategy パターンの設計ミス | 🟡 中 | 中 | Day 1 でサンプル実装、動作確認 |
| 工数超過（4-5日 → 6-7日） | 🟡 中 | 中 | 優先度の低いスペルは後回し |
| null 参照エラー | 🟢 低 | 低 | context チェックを各 Strategy に実装 |

---

## 📋 次のアクション: Phase 3-A-1 実装（進行中）

**現在のフェーズ**: Phase 3-A-1 - effect_type Strategies 基盤実装
**担当**: Haiku（実装）、Sonnet（計画・回答）
**参考**: `docs/progress/phase_3a_comprehensive_plan.md`（詳細企画計画書）

---

### Phase 3-A-1: effect_type Strategies 基盤実装

**目的**: SpellEffectExecutor (377行) を effect_type ベースの Strategy に分割

**背景**:
- 現在、SpellEffectExecutor.apply_single_effect() が 21個の effect_type を match で処理
- 132個のスペルは全て effect_type で汎用処理されている
- Strategy パターンで分割し、各 effect_type を独立クラス化

**実装対象**（P0優先度）:

#### 1. SpellStrategy 基底クラス（既存を確認）
**ファイル**: `scripts/spells/strategies/spell_strategy.gd`
**状態**: ✅ Day 1-2 で実装済み
**確認事項**:
- `validate(context: Dictionary) -> bool` メソッド存在確認
- `execute(context: Dictionary) -> void` メソッド存在確認

#### 2. SpellStrategyFactory 拡張（effect_type 対応）
**ファイル**: `scripts/spells/strategies/spell_strategy_factory.gd`
**状態**: Day 1-2 で spell_id 対応版を実装済み、effect_type 対応に拡張
**実装内容**:
```gdscript
# 追加メソッド
static func create_effect_strategy(effect_type: String) -> SpellStrategy:
	"""effect_type から Strategy を生成"""
	var strategy_map = {
		"damage": preload("res://scripts/spells/strategies/effect_strategies/damage_effect_strategy.gd"),
		"heal": preload("res://scripts/spells/strategies/effect_strategies/heal_effect_strategy.gd"),
		"creature_move": preload("res://scripts/spells/strategies/effect_strategies/creature_move_effect_strategy.gd"),
		# 他の effect_type は後で追加
	}

	if effect_type in strategy_map:
		return strategy_map[effect_type].new()
	return null
```

#### 3. DamageEffectStrategy 実装
**ファイル**: `scripts/spells/strategies/effect_strategies/damage_effect_strategy.gd`（新規）
**責務**: ダメージ効果の処理
**移行元**: `SpellEffectExecutor.apply_single_effect()` の "damage" 分岐
**実装パターン**:
```gdscript
class_name DamageEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# 必須キーチェック
	if not context.has("target_data"):
		return false
	if not context.has("effect"):
		return false
	return true

func execute(context: Dictionary) -> void:
	var effect = context["effect"]
	var target_data = context["target_data"]
	var value = effect.get("value", 0)

	# spell_damage への委譲（既存ロジック再利用）
	var spell_damage = context.get("spell_damage")
	if spell_damage:
		await spell_damage.apply_damage(target_data, value)
```

**移行対象コード**（SpellEffectExecutor より）:
- 行89-110: "damage" 分岐のロジック

#### 4. HealEffectStrategy 実装
**ファイル**: `scripts/spells/strategies/effect_strategies/heal_effect_strategy.gd`（新規）
**責務**: 回復効果の処理
**移行元**: `SpellEffectExecutor.apply_single_effect()` の "heal", "full_heal" 分岐
**実装パターン**: DamageEffectStrategy と同様

#### 5. CreatureMoveEffectStrategy 実装
**ファイル**: `scripts/spells/strategies/effect_strategies/creature_move_effect_strategy.gd`（新規）
**責務**: クリーチャー移動効果の処理
**移行元**: `SpellEffectExecutor.apply_single_effect()` の "move_to_adjacent_enemy", "move_steps", "move_self" 等

---

### 実装手順（Haiku向け）

**Step 1: 既存コード確認**
1. `scripts/spells/strategies/spell_strategy.gd` を読んで基底クラス確認
2. `scripts/spells/strategies/spell_strategy_factory.gd` を読んで現状確認
3. `scripts/game_flow/spell_effect_executor.gd` を読んで移行対象コード確認

**Step 2: ディレクトリ作成**
```bash
mkdir -p scripts/spells/strategies/effect_strategies
```

**Step 3: DamageEffectStrategy 実装**
1. `damage_effect_strategy.gd` 新規作成
2. SpellEffectExecutor の "damage" 分岐ロジックを移行
3. validate() / execute() 実装

**Step 4: HealEffectStrategy 実装**
1. `heal_effect_strategy.gd` 新規作成
2. SpellEffectExecutor の "heal", "full_heal" 分岐ロジックを移行

**Step 5: CreatureMoveEffectStrategy 実装**
1. `creature_move_effect_strategy.gd` 新規作成
2. SpellEffectExecutor の移動系 effect_type を移行

**Step 6: SpellStrategyFactory 拡張**
1. `create_effect_strategy()` メソッド追加
2. 3つの Strategy をマッピング

**Step 7: SpellEffectExecutor 統合**
1. `apply_single_effect()` に Strategy 試行ロジック追加
2. フォールバック機構維持

---

### テスト用の実際のスペル

**重要**: 架空のスペル名を使用しない。以下の実際のスペルでテスト：

- **damage系**: エレメンタルラス(2016), サンダークラップ(2031)
- **heal系**: ライフストリーム(2116), リストア(2121)
- **move系**: アウトレイジ(2002)
- **change_element**: アースシフト(2001) ✅ 実装済み

---

### 質問への回答（Sonnet提供）

実装前の15質問に対する回答：

**A1. effect_type と spell_id の違い**
- ✅ 正しい。spell_id=スペルカード識別、effect_type=個別効果識別
- 1スペルに複数 effect_type 含む場合あり（例：リストア = clear_down + full_heal）

**A2-A5**: context 構造
- 必須: spell_card, current_player_id, board_system
- オプショナル: spell_container, spell_effect_executor
- spell_damage は SpellPhaseHandler の属性（SpellSystemContainer外）
- validate()=同期、execute()=非同期（await可）

**A6-A10**: 実装詳細
- 新規ディレクトリ: `effect_strategies/`
- 命名規則: damage_effect_strategy.gd / DamageEffectStrategy
- Factory: static + preload()
- Phase 3-A-1: 3個のみ移行（damage, heal, creature_move）

**A11-A15**: テスト・フォールバック
- テストスペル: エレメンタルラス(2016)
- エラーログ: push_error() のみ対象
- Strategy==null → push_warning() + フォールバック
- 二重実行防止: 保証あり（Strategy成功時はspell_effect_executor呼ばれない）

---

### 成功基準

- [ ] DamageEffectStrategy 実装・テスト完了
- [ ] HealEffectStrategy 実装・テスト完了
- [ ] CreatureMoveEffectStrategy 実装・テスト完了
- [ ] SpellStrategyFactory に effect_type マッピング追加
- [ ] SpellEffectExecutor で Strategy 試行→フォールバック動作
- [ ] 3ターン以上プレイテスト、エラーなし

---

### リスク

| リスク | 緩和策 |
|--------|--------|
| effect_type の移行漏れ | SpellEffectExecutor のコードを1行ずつ確認 |
| context キー不足 | validate() で厳格チェック |
| 既存サブシステムとの連携失敗 | spell_damage 等を context に含める |

---

**最終更新**: 2026-02-14
**次のアクション**: Haiku に Phase 3-A-1 実装を依頼
