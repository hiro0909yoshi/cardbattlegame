# Phase 3-A 詳細企画計画書 - SpellPhaseHandler Strategy パターン化

**作成日**: 2026-02-14
**プロジェクト**: カードセプト風カードバトルゲーム（Godot 4.5）
**目的**: SpellPhaseHandler (1,826行) を Strategy パターンで分割し、神オブジェクトを解消
**全体工数**: 4-5日（Day 1-2: 基盤 + Day 3-4: スペル移行 + Day 5: 統合）

---

## A. プロジェクト概要

### 1. 目的

**Primary Goal**: SpellPhaseHandler の 1,826行コードを戦略パターン（Strategy Pattern）で分割し、以下を実現
- スペル処理ロジックの独立性向上
- 新スペル追加時の開発効率化
- テスト容易性の向上
- ツリー構造の保守性強化

### 2. 背景（神オブジェクト化の問題）

**現状の課題**:
```
SpellPhaseHandler: 1,826行
├── スペル ID 判定 (30-50行)
├── スペル効果実行 (800-900行)
│   ├── Fireball（ファイアボール）
│   ├── Freeze（フリーズ）
│   ├── Heal（ヒール）
│   └── ... （その他11個）
├── ターゲット選択 (200-300行)
├── UI管理 (300-400行)
└── CPU AI判定 (200-250行)
```

**問題**:
1. 単一ファイルに11+個のスペル実装が集約
2. 新スペル追加時に SpellPhaseHandler を修正 (変更パターン: Open/Closed Principle 違反)
3. 各スペルのテストが困難（SpellPhaseHandler 全体のセットアップが必要）
4. UI処理とスペル処理が混在（関心の分離不足）
5. 層違反: SpellPhaseHandler が UI と効果実行の両方を担当

### 3. スコープ

**実装する内容**:
- ✅ SpellStrategy 基底クラス設計 + インターフェース定義
- ✅ SpellStrategyFactory による動的生成
- ✅ 11個の既存スペル → Strategy へ移行
- ✅ SpellPhaseHandler → 400行に削減（77%削減）
- ✅ effect_type Strategies (9-12個) 実装
- ✅ UI・ターゲット分離（SpellPhaseUIController, TargetSelectionManager）

**スコープ外**:
- ❌ 新スペルの機能実装（既存スペルの Strategy 化のみ）
- ❌ CPU AI の根本的な改造
- ❌ UIコンポーネントの再構築（既存インターフェース維持）
- ❌ ネットワークプレイ対応

### 4. 成功基準

**定量的基準**:
- [ ] SpellPhaseHandler: 1,826行 → 400行以下（削減率: 78%以上）
- [ ] Strategy クラス数: 11個（スペル数）+ 9-12個（effect_type）
- [ ] ユニットテスト: 各 Strategy ごとに最低1つ
- [ ] エラーログ: 0個（3ターン以上プレイテスト）
- [ ] 処理時間: 従来比 100-105%（2-5%の遅延許容）

**定性的基準**:
- [ ] 新スペル追加時に SpellPhaseHandler を修正不要（Strategy のみ追加）
- [ ] 各 Strategy が独立してテスト可能
- [ ] ツリー構造図で SpellPhaseHandler の責務が明確化
- [ ] ドキュメントで各 Strategy の実装パターンが説明可能

---

## B. 現状分析

### 1. SpellPhaseHandler の責務一覧

**Category 1: スペル選択・フェーズ制御 (300-400行)**
```gdscript
- start_spell_phase(player_id: int) - スペルフェーズ開始
- use_spell(spell_card: Dictionary) - スペル使用判定
- execute_spell_effect(spell_card, target_data) - 効果実行委譲
- complete_spell_phase() - フェーズ完了
- pass_spell(auto_roll: bool) - スペルパス
```

**Category 2: スペル効果実行 (700-800行)**
```gdscript
# 直接実装されている 11個のスペル処理
- _execute_fireball(target_data) [実装例]
- _execute_freeze(target_data)
- _execute_heal(target_data)
- ... （その他8個）
```

**Category 3: ターゲット選択・UI (400-500行)**
```gdscript
- show_target_selection_ui(target_type, target_info)
- _start_confirmation_phase(target_type, target_info, target_data)
- _update_target_selection()
- _confirm_target_selection()
- _cancel_target_selection()
```

**Category 4: UI管理・ボタン (200-300行)**
```gdscript
- _initialize_spell_phase_ui()
- _show_spell_phase_buttons()
- _show_spell_selection_ui(hand_data, available_magic)
- _update_spell_phase_ui()
- _setup_spell_selection_navigation()
```

**Category 5: CPU AI判定 (150-200行)**
```gdscript
- _handle_cpu_spell_turn()
- _execute_cpu_spell(decision)
- _cpu_select_target(targets, target_type, target_info)
- is_cpu_player(player_id: int)
```

### 2. コード規模の内訳

| Category | 現在の行数 | 削減目標 | Strategy化後 |
|----------|----------|--------|----------|
| フェーズ制御 | 350行 | 維持 | 350行 |
| スペル効果 | 700行 | 0行 | 0行 → Strategy分割 |
| ターゲット選択 | 450行 | 150行 | 300行 → TargetSelectionManager |
| UI管理 | 250行 | 100行 | 150行 → SpellPhaseUIController |
| CPU AI | 180行 | 100行 | 80行 |
| **合計** | **1,826行** | **～400行** | **400行（目標）** |

### 3. 問題点

**P0: 層違反**
```
SpellPhaseHandler (Game Flow Control)
├── UI制御（Presentation層の責務） ❌
├── スペル効果実行（Core層に属すべき） ❌
└── ターゲット選択UI（Presentation層）❌
```

**P1: Open/Closed Principle 違反**
- 新スペル追加時 = SpellPhaseHandler 修正必須
- 理想: Strategy 追加のみで OK

**P2: テスト困難性**
- SpellPhaseHandler 全体をセットアップしないと1つのスペルをテスト不可
- 理想: Strategy のみでテスト可能

**P3: 関心の分離不足**
- スペル判定 + 効果実行 + UI + CPU AI が1ファイルに混在

---

## C. 分離設計

### 1. ツリー構造への適合

**理想的な配置**:
```
GameFlowManager (Game Flow Control Tier)
│
├── SpellPhaseHandler (フェーズ制御のみ)
│   ├── SpellPhaseUIController ← 新規 (UI責務)
│   ├── TargetSelectionManager ← 新規 (ターゲット選択)
│   ├── SpellStrategyFactory (Strategy 動的生成)
│   └── [各 Strategy] (スペル効果実行)
│
└── SpellSystemContainer (既存スペルシステム)
```

### 2. コンポーネント構成

#### 新規クラス 1: SpellStrategy (基底クラス)
```gdscript
class_name SpellStrategy
extends RefCounted

# インターフェース
func validate(context: Dictionary) -> bool:
	"""条件チェック。falseで従来ロジックにフォールバック"""
	return true

func execute(context: Dictionary) -> void:
	"""スペル効果実行"""
	push_error("未実装: execute() を override してください")
```

**context 構造**:
```gdscript
{
	"spell_card": Dictionary,          # スペルカード全体
	"spell_id": int,                   # スペルID
	"target_data": Dictionary,         # ターゲット情報
	"current_player_id": int,
	"board_system": BoardSystem3D,
	"player_system": PlayerSystem,
	"card_system": CardSystem,
	"ui_manager": UIManager,
	"spell_container": SpellSystemContainer,
	"spell_phase_handler": SpellPhaseHandler,
	"spell_effect_executor": SpellEffectExecutor
}
```

#### 新規クラス 2: SpellStrategyFactory
```gdscript
class_name SpellStrategyFactory
extends Node

# スペルID → Strategy クラスのマッピング
const STRATEGY_MAP = {
	1: "FireballStrategy",
	2: "FreezeStrategy",
	# ... 他のスペル
}

func create_strategy(spell_id: int) -> SpellStrategy:
	"""Strategy インスタンスを動的生成"""
	if spell_id not in STRATEGY_MAP:
		return null  # フォールバック用

	var strategy_name = STRATEGY_MAP[spell_id]
	var strategy_class = load("res://scripts/spells/strategies/%s.gd" % strategy_name.to_lower())

	if not strategy_class:
		return null

	return strategy_class.new()
```

#### 変更 3: SpellPhaseHandler (簡潔化)
```gdscript
# 現在の 1,826行 → 400行に削減

# 追加メソッド
func _try_execute_spell_with_strategy(spell_card: Dictionary, target_data: Dictionary) -> bool:
	"""Strategy で実行を試行、フォールバック対応"""
	var strategy = SpellStrategyFactory.create_strategy(spell_card.get("id", -1))
	if not strategy:
		return false  # フォールバック

	var context = _build_spell_context(spell_card, target_data)
	if not strategy.validate(context):
		return false

	await strategy.execute(context)
	return true

func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):
	# Strategy 試行
	var strategy_executed = await _try_execute_spell_with_strategy(spell_card, target_data)

	if strategy_executed:
		return

	# フォールバック: 従来ロジック（spell_effect_executor）
	if spell_effect_executor:
		await spell_effect_executor.execute_spell_effect(spell_card, target_data)
```

#### 新規クラス 4: SpellPhaseUIController (UI責務分離)
```gdscript
class_name SpellPhaseUIController
extends Node

# 責務
# - スペル選択UI管理
# - アルカナアーツボタン管理
# - フェーズメッセージ表示

func update_spell_phase_ui():
	"""スペルカードのみ選択可能にフィルター"""

func show_spell_phase_buttons():
	"""アルカナアーツボタンを表示"""

func hide_spell_phase_buttons():
	"""フェーズ終了時にボタン非表示"""
```

#### 新規クラス 5: TargetSelectionManager (ターゲット選択)
```gdscript
class_name TargetSelectionManager
extends Node

# 責務
# - ターゲット選択ロジック（キーボード/タップ）
# - ターゲットビジュアル管理
# - 確認フェーズ管理

func show_target_selection_ui(target_type: String, target_info: Dictionary) -> bool:
	"""ターゲット選択UIを表示"""

func confirm_target_selection():
	"""ターゲット選択を確定"""

func cancel_target_selection():
	"""ターゲット選択をキャンセル"""
```

### 3. effect_type Strategies 一覧 (9-12個)

**effect_type** は `spell_card["effect_parsed"]["effects"][].effect_type` で定義されるスペルの詳細効果。
現在 SpellEffectExecutor.apply_single_effect() で一括処理されている。

| No. | effect_type | Strategy名 | 状態 | 優先度 |
|-----|------------|-----------|------|--------|
| 1 | damage | DamageEffectStrategy | 既実装 | P0 |
| 2 | heal | HealEffectStrategy | 既実装 | P0 |
| 3 | creature_move | CreatureMoveEffectStrategy | 既実装 | P0 |
| 4 | creature_swap | CreatureSwapEffectStrategy | 既実装 | P0 |
| 5 | creature_return | CreatureReturnEffectStrategy | 既実装 | P1 |
| 6 | curse_apply | CurseApplyEffectStrategy | 既実装 | P1 |
| 7 | land_change | LandChangeEffectStrategy | 既実装 | P1 |
| 8 | draw_card | DrawCardEffectStrategy | 既実装 | P1 |
| 9 | all_creatures_damage | AllCreaturesDamageEffectStrategy | 既実装 | P2 |
| 10 | synthesis_check | SynthesisCheckEffectStrategy | 新規 | P2 |
| 11 | warp | WarpEffectStrategy | 新規 | P2 |
| 12 | null_magic | NullMagicEffectStrategy | 新規 | P2 |

### 4. シグナルフロー設計

**従来フロー** (スペル効果実行):
```
use_spell(spell_card)
  ↓
execute_spell_effect(spell_card, target_data)
  ↓
[11個のif分岐で spellID判定] ← 保守困難
  ↓
spell_effect_executor.apply_single_effect()
  ↓
spell_phase_completed.emit()
```

**新しいフロー** (Strategy パターン):
```
use_spell(spell_card)
  ↓
execute_spell_effect(spell_card, target_data)
  ↓
_try_execute_spell_with_strategy(spell_card, target_data)
  ↓
SpellStrategyFactory.create_strategy(spell_id)
  ↓
[該当 Strategy].execute(context)
  ↓
(失敗時) spell_effect_executor.execute_spell_effect() ← フォールバック
  ↓
spell_phase_completed.emit()
```

---

## D. フェーズ分割実装計画

### Phase 3-A を 3つのサブフェーズに分割

各サブフェーズは**独立してコミット・テスト可能**に設計。

---

## D-1. Phase 3-A-1: effect_type Strategies 基盤 (Day 1-2)

### 目的

スペル効果の Strategy パターン化（effect_type レベル）を先に完成させ、基盤を確立する。
これにより以下が達成される:
1. 既存 11スペル も Strategy 化可能な体制整備
2. SpellEffectExecutor の再利用可能な分割

### 実装対象

**P0優先度（Day 1-2で必須）**:
1. SpellStrategy 基底クラス
2. SpellStrategyFactory（effect_type 対応版）
3. DamageEffectStrategy (ダメージ効果)
4. HealEffectStrategy (回復効果)
5. CreatureMoveEffectStrategy (クリーチャー移動)

**成果物**:
```
scripts/spells/strategies/
├── spell_strategy.gd                 # 基底クラス (50行)
├── spell_strategy_factory.gd         # Factory (40行)
├── effect_type/
│   ├── damage_effect_strategy.gd    # (60行)
│   ├── heal_effect_strategy.gd      # (50行)
│   └── creature_move_effect_strategy.gd # (70行)
```

### 実装チェックリスト

- [ ] SpellStrategy 基底クラス作成（基本メソッド: validate(), execute()）
- [ ] SpellStrategyFactory 実装（effect_type マッピング）
- [ ] DamageEffectStrategy 実装・テスト
- [ ] HealEffectStrategy 実装・テスト
- [ ] CreatureMoveEffectStrategy 実装・テスト
- [ ] SpellPhaseHandler._try_execute_spell_with_strategy() 統合
- [ ] サンプルテスト: 1スペル（Fireball）で動作確認
- [ ] ロールバック手順書作成

### テストポイント

1. **SpellStrategy.validate() テスト**
   ```gdscript
   # Strategy が条件を正しく判定するか
   var context = {...}
   assert(strategy.validate(context) == true)
   ```

2. **SpellStrategyFactory テスト**
   ```gdscript
   # effect_type から正しい Strategy が生成されるか
   var strategy = factory.create("damage")
   assert(strategy is DamageEffectStrategy)
   ```

3. **effect 実行テスト**
   ```gdscript
   # 効果が正しく適用されるか（damage の場合）
   await strategy.execute(context)
   assert(target_creature.hp == expected_hp)
   ```

4. **フォールバック テスト**
   ```gdscript
   # Strategy が null の場合、従来ロジックで実行
   strategy = null
   await execute_spell_effect(spell_card, target_data)
   # エラーなし確認
   ```

### ロールバック手順

**実装中に問題発生時**:
1. `scripts/spells/strategies/` ディレクトリを削除
2. SpellPhaseHandler の `_try_execute_spell_with_strategy()` 削除
3. `execute_spell_effect()` を従来版に戻す
4. ゲーム再起動 → 従来ロジックで動作

**所要時間**: 5分

---

## D-2. Phase 3-A-2: UI・ターゲット分離 (Day 3-4)

### 目的

SpellPhaseHandler から UI責務と ターゲット選択責務を分離し、関心の分離を実現。
これにより:
1. SpellPhaseHandler が 400行に削減（現在1,826行）
2. 各コンポーネントがテスト容易に
3. ツリー構造が明確化

### 実装対象

**新規コンポーネント**:
1. SpellPhaseUIController (300行新規 ← SpellPhaseHandler から移行)
2. TargetSelectionManager (400行新規 ← SpellPhaseHandler から移行)

**追加 Strategies**:
- CreatureSwapEffectStrategy
- CreatureReturnEffectStrategy
- CurseApplyEffectStrategy
- LandChangeEffectStrategy
- DrawCardEffectStrategy

### 実装チェックリスト

- [ ] SpellPhaseUIController 作成・テスト
  - [ ] _update_spell_phase_ui() 移行
  - [ ] _show_spell_selection_ui() 移行
  - [ ] _show_spell_phase_buttons() 移行
  - [ ] ナビゲーション管理メソッド移行

- [ ] TargetSelectionManager 作成・テスト
  - [ ] show_target_selection_ui() 移行
  - [ ] _update_target_selection() 移行
  - [ ] _confirm_target_selection() 移行
  - [ ] _cancel_target_selection() 移行
  - [ ] キーボード/タップ入力処理移行

- [ ] 追加 Strategies 実装（5個）
  - [ ] CreatureSwapEffectStrategy
  - [ ] CreatureReturnEffectStrategy
  - [ ] CurseApplyEffectStrategy
  - [ ] LandChangeEffectStrategy
  - [ ] DrawCardEffectStrategy

- [ ] SpellPhaseHandler 統合
  - [ ] UIController 参照注入
  - [ ] TargetSelectionManager 参照注入
  - [ ] 委譲呼び出しへ変更

- [ ] 統合テスト: 3ターン以上プレイ確認
- [ ] エラーログ: 0個確認

### テストポイント

1. **UI機能テスト**
   ```gdscript
   # UI更新が正しく実行されるか
   ui_controller.update_spell_phase_ui()
   # カードのグレーアウトが適用されたか確認
   ```

2. **ターゲット選択テスト**
   ```gdscript
   # ターゲット選択が正常に動作するか
   var has_targets = await target_selector.show_selection_ui("creature")
   assert(has_targets == true)
   ```

3. **委譲呼び出しテスト**
   ```gdscript
   # SpellPhaseHandler → TargetSelectionManager への委譲が正常か
   use_spell(spell_card)
   # ターゲット選択UIが表示されたか
   ```

### ロールバック手順

**実装中に問題発生時**:
1. SpellPhaseUIController, TargetSelectionManager 削除
2. SpellPhaseHandler に UI・ターゲット関連メソッドを復旧（Git から restore）
3. 参照注入コードを削除
4. ゲーム再起動

**所要時間**: 10分

---

## D-3. Phase 3-A-3: 簡潔化・統合 (Day 5)

### 目的

残りのスペルを Strategy 化し、SpellPhaseHandler を最終的に 400行に削減。
全スペルが新しいアーキテクチャで動作することを確認。

### 実装対象

**残り 6個のスペル Strategy 実装**:
1. AllCreaturesDamageEffectStrategy (全体ダメージ)
2. SynthesisCheckEffectStrategy (スペル合成判定)
3. WarpEffectStrategy (ワープ)
4. NullMagicEffectStrategy (スペル無効化)
5. + 既存スペル 11個の Strategy 化

**Phase 3-A-1/2 で未実装の effect_type**:
- AllCreaturesDamageEffectStrategy
- SynthesisCheckEffectStrategy
- WarpEffectStrategy
- NullMagicEffectStrategy

### 実装チェックリスト

- [ ] 残り effect_type Strategy 実装（4個）
- [ ] 既存スペル 11個の Strategy 化
  - [ ] FireballStrategy ← Day 1-2 で実装済み
  - [ ] FreezeStrategy
  - [ ] HealStrategy
  - [ ] LightningStrategy
  - [ ] ShieldStrategy
  - [ ] PoisonStrategy
  - [ ] TeleportStrategy
  - [ ] BuffStrategy
  - [ ] DebuffStrategy
  - [ ] SummonStrategy
  - [ ] OtherStrategy

- [ ] SpellPhaseHandler 最終削減
  - [ ] 既存スペル実装コード削除 (700-800行)
  - [ ] ターゲット選択コード削除 (400-500行) ← Phase 3-A-2 で移行済み
  - [ ] UI管理コード削除 (200-300行) ← Phase 3-A-2 で移行済み
  - [ ] 最終行数確認: 400行以下

- [ ] SpellStrategyFactory マッピング完成
  - [ ] 11個のスペルID → Strategy クラス マッピング

- [ ] 統合テスト完了
  - [ ] ゲーム起動: エラーなし
  - [ ] 3ターン以上プレイ: 各スペル 1回以上使用
  - [ ] スペル効果検証: 期待値通りの結果
  - [ ] CPU AI: 正常動作
  - [ ] エラーログ: 0個

- [ ] ドキュメント更新
  - [ ] docs/progress/daily_log.md に進捗記載
  - [ ] docs/design/TREE_STRUCTURE.md を Phase 3-A 完了版に更新
  - [ ] Strategy 実装パターン解説を docs/implementation/implementation_patterns.md に追加

### テストポイント

1. **全スペル動作テスト** (各 1回以上)
   ```gdscript
   # 各スペルが正常に実行されるか
   for spell_id in SPELL_IDS:
	   var strategy = factory.create_strategy(spell_id)
	   assert(strategy != null)
	   var result = await strategy.execute(context)
	   assert(result == true)
   ```

2. **パフォーマンステスト**
   ```gdscript
   # Strategy 化によって処理時間が大幅に悪化していないか
   var start_time = Time.get_ticks_msec()
   await execute_spell_effect(spell_card, target_data)
   var elapsed = Time.get_ticks_msec() - start_time
   assert(elapsed < 500)  # 500ms 以内
   ```

3. **スペル合成テスト**
   ```gdscript
   # Strategy 実装後も合成機能が正常か
   var synthesized = await use_spell(synthesis_spell)
   assert(synthesized == true)
   ```

### ロールバック手順

**実装中に問題発生時** (Day 5 中盤以降):
1. 直近の Strategy ファイルを削除
2. SpellStrategyFactory マッピングを修正
3. 該当 Strategy を従来ロジックにフォールバック
4. ゲーム再起動 → 一部 Strategy + フォールバック混在状態で動作

**完全ロールバック** (致命的な問題の場合):
1. Day 4 の最後のコミット時点に reset
2. Phase 3-A-2 の成果は保持（UIController, TargetSelectionManager）
3. Strategy は全削除
4. `git reset --hard <commit>`

**所要時間**: 15-30分

---

## E. リスク管理

### 各フェーズのリスク分析

| Phase | リスク内容 | 深刻度 | 発生確率 | 緩和策 |
|-------|--------|--------|---------|--------|
| 3-A-1 | Strategy 基盤の設計ミス | 🔴 高 | 中 | Day 1 でサンプル実装 → Day 2 で他 Strategy に適用 |
| 3-A-1 | フォールバック機構の不具合 | 🟡 中 | 低 | フォールバック時に従来ロジックが動作することを確認 |
| 3-A-2 | UI・ターゲット分離時の参照エラー | 🟡 中 | 中 | 段階的に移行（1メソッドずつ） |
| 3-A-2 | シグナル接続の重複 | 🟡 中 | 中 | is_connected() チェック必須 |
| 3-A-3 | 既存スペル動作の破損 | 🔴 高 | 中 | 1スペルずつ Strategy 化 → テスト → コミット |
| 全体 | 工数超過（4-5日 → 7-8日） | 🟡 中 | 中 | 優先度の低いスペルは後回し（Phase 4 で実装） |
| 全体 | パフォーマンス低下（>10%） | 🔴 高 | 低 | ベンチマーク測定 → ボトルネック分析 |

### 進捗判断基準（continue/stop）

#### Phase 3-A-1 完了時点（Day 2 夜）
**進める条件**:
- [ ] SpellStrategy 基底クラスが動作
- [ ] SpellStrategyFactory が 3つ以上の effect_type に対応
- [ ] サンプル Strategy (Damage, Heal) が正常動作
- [ ] フォールバックが正常に機能

**中止条件**:
- ❌ Strategy パターンの設計が根本的に不適切と判明
- ❌ フォールバック機構にバグがあり、従来ロジックで全スペルが失敗

#### Phase 3-A-2 完了時点（Day 4 夜）
**進める条件**:
- [ ] SpellPhaseUIController が正常に初期化
- [ ] TargetSelectionManager でターゲット選択が正常
- [ ] 3ターン以上プレイテスト: エラーなし
- [ ] SpellPhaseHandler が 800行以下に削減

**中止条件**:
- ❌ UI分離後にターゲット選択が失敗
- ❌ シグナル接続エラーが頻発
- ❌ SpellPhaseHandler の行数が 1,200行以上のまま

#### Phase 3-A-3 完了時点（Day 5 夜）
**success 条件**:
- [ ] SpellPhaseHandler が 400行以下
- [ ] 11個のスペル + 4個の effect_type が全て Strategy 化
- [ ] 3ターン以上プレイテスト: エラーなし
- [ ] CPU AI が正常に動作
- [ ] パフォーマンス: 従来比 100-105% (2-5%の遅延許容)

**failure 条件**:
- ❌ SpellPhaseHandler が 500行以上
- ❌ スペル動作に明らかなバグ
- ❌ パフォーマンス: 従来比 110% 以上（10%以上遅延）

---

## F. テスト戦略

### 1. 単体テスト（各 Strategy）

**テスト方式**: GdUnit4 (Godot テストフレームワーク)

```gdscript
class TestDamageEffectStrategy:
	var strategy: DamageEffectStrategy

	func before_each():
		strategy = DamageEffectStrategy.new()

	func test_validate_should_return_true_with_valid_context():
		var context = _create_sample_context()
		assert_true(strategy.validate(context))

	func test_execute_should_reduce_hp():
		var target_before = context["target_creature"].get("hp", 100)
		await strategy.execute(context)
		var target_after = context["target_creature"].get("hp", 100)
		assert_less(target_after, target_before)
```

**対象**: 各 effect_type Strategy (9-12個)
**目標**: 各 Strategy ごとに最低 3-5個のテストケース

### 2. 統合テスト（全スペル動作確認）

**テスト方法**: ゲーム内統合テスト

```
Test Scenario: スペルフェーズで全スペルを1回ずつ使用
1. ゲーム起動
2. Player 1: スペル1を使用 → 効果確認
3. Player 2: スペル2を使用 → 効果確認
4. ... (全11スペル)
5. 最低3ターン完了まで続ける
6. エラーログ: 0個確認
```

**テストケース**:
- [ ] Fireball: 敵クリーチャーに 30ダメージ
- [ ] Freeze: クリーチャーを 1ターン無視
- [ ] Heal: 自分のクリーチャー +20HP
- [ ] Lightning: ランダム敵クリーチャーに 40ダメージ
- [ ] Shield: 自分のクリーチャー +30防御
- [ ] Poison: クリーチャーに 毎ターン 10ダメージ
- [ ] Teleport: クリーチャー移動
- [ ] Buff: 全自分クリーチャー +10攻撃
- [ ] Debuff: 全敵クリーチャー -10防御
- [ ] Summon: ランダムクリーチャー配置
- [ ] Other: フェーズスキップ等

### 3. UI・ターゲット選択テスト

```gdscript
Test Scenario: SpellPhaseUIController and TargetSelectionManager
1. スペルフェーズ開始 → UI更新確認
   - スペルカードのみ選択可能
   - 他カードはグレーアウト
2. ターゲット選択スペル使用 → UI表示確認
   - ターゲット選択マーカー表示
   - キーボード/タップでターゲット選択可能
3. 確認フェーズ → 決定/キャンセル
   - 決定: 効果実行
   - キャンセル: スペル選択に戻る
```

### 4. リグレッション テスト

```
既存機能が破損していないか確認
- [ ] カード選択機能
- [ ] CPU AI 判定
- [ ] アルカナアーツ
- [ ] スペル合成
- [ ] 呪い・バフシステム
```

---

## G. ロールバック計画

### 各フェーズでのロールバック戦略

#### Phase 3-A-1 ロールバック

**最小限のロールバック** (Strategy 1個が失敗した場合):
```bash
# 該当 Strategy ファイルを削除
rm scripts/spells/strategies/effect_type/damage_effect_strategy.gd

# SpellStrategyFactory の該当マッピングをコメントアウト
# STRATEGY_MAP から該当行を削除

# ゲーム再起動 → 他の Strategy + フォールバックで動作
```

**完全ロールバック** (設計が根本的に不適切の場合):
```bash
# strategies ディレクトリ全削除
rm -rf scripts/spells/strategies/

# SpellPhaseHandler の Strategy 関連コード削除
# - _try_execute_spell_with_strategy() 削除
# - execute_spell_effect() を従来版に復旧

# コミット前に戻す
git checkout HEAD -- scripts/game_flow/spell_phase_handler.gd
```

#### Phase 3-A-2 ロールバック

**UI分離に問題がある場合**:
```bash
# SpellPhaseUIController, TargetSelectionManager を削除
rm scripts/game_flow/spell_phase_ui_controller.gd
rm scripts/game_flow/target_selection_manager.gd

# SpellPhaseHandler の委譲呼び出しを復旧
git checkout HEAD -- scripts/game_flow/spell_phase_handler.gd

# UI・ターゲット関連メソッドが復旧される
```

#### Phase 3-A-3 ロールバック

**スペル Strategy 1個が失敗した場合** (Day 5 中盤):
```bash
# 該当 Strategy を削除
rm scripts/spells/strategies/fireball_strategy.gd

# SpellStrategyFactory マッピングから削除
# 次回スペル使用時にフォールバック

# 該当スペルは従来ロジックで動作継続
```

**複数スペルが失敗した場合** (Day 5 後半):
```bash
# 直近コミット（Phase 3-A-2 完了時点）に戻す
git reset --hard <commit_hash_of_phase_3a2_complete>

# Strategy 実装は全削除
# UIController, TargetSelectionManager は保持
# Phase 3-A-3 をスキップして Phase 3-A 完了とする
```

### バックアップ方針

**コミット粒度**:
```
Phase 3-A-1 Day 2 完了時点
├── Commit: SpellStrategy基盤完成（バックアップ1）

Phase 3-A-2 Day 4 完了時点
├── Commit: UI・ターゲット分離完成（バックアップ2）

Phase 3-A-3 Day 5 完了時点
├── Commit: スペル Strategy 化完成（最終コミット）
```

**ロールバック所要時間**:
- 最小限: 5分
- 部分的: 10分
- 完全: 30分

---

## H. 実装チェックリスト

### Phase 3-A-1: effect_type Strategies 基盤完成基準

- [ ] SpellStrategy 基底クラス実装
  - [ ] validate(context: Dictionary) → bool
  - [ ] execute(context: Dictionary) → void
  - [ ] error handling

- [ ] SpellStrategyFactory 実装
  - [ ] effect_type → Strategy クラス マッピング
  - [ ] create_strategy(effect_type: String) → SpellStrategy
  - [ ] null チェック（未実装 Strategy 用）

- [ ] DamageEffectStrategy 実装・テスト
  - [ ] ダメージ計算ロジック移行
  - [ ] ターゲット HP 減少確認

- [ ] HealEffectStrategy 実装・テスト
  - [ ] 回復計算ロジック移行
  - [ ] ターゲット HP 増加確認

- [ ] CreatureMoveEffectStrategy 実装・テスト
  - [ ] クリーチャー移動ロジック移行
  - [ ] ボード更新確認

- [ ] SpellPhaseHandler._try_execute_spell_with_strategy() 実装
  - [ ] Strategy 生成・実行
  - [ ] フォールバック対応

- [ ] サンプルテスト実施
  - [ ] Fireball スペル使用 → 効果確認
  - [ ] 3ターンプレイ → エラーなし

- [ ] ドキュメント作成
  - [ ] Strategy 実装パターンガイド
  - [ ] context 構造ドキュメント

### Phase 3-A-2: UI・ターゲット分離完成基準

- [ ] SpellPhaseUIController 作成・テスト
  - [ ] 全UI関連メソッド移行
  - [ ] シグナル接続 is_connected() チェック

- [ ] TargetSelectionManager 作成・テスト
  - [ ] ターゲット選択ロジック移行
  - [ ] キーボード/タップ入力処理
  - [ ] 確認フェーズ管理

- [ ] 追加 Strategies 実装（5個）
  - [ ] CreatureSwapEffectStrategy
  - [ ] CreatureReturnEffectStrategy
  - [ ] CurseApplyEffectStrategy
  - [ ] LandChangeEffectStrategy
  - [ ] DrawCardEffectStrategy

- [ ] SpellPhaseHandler 統合
  - [ ] UIController/TargetSelectionManager 参照注入
  - [ ] 委譲呼び出しへ変更
  - [ ] 行数削減確認: 800行以下

- [ ] 統合テスト
  - [ ] 3ターン以上プレイ
  - [ ] スペル効果確認（各1回以上）
  - [ ] エラーログ: 0個

### Phase 3-A-3: スペル Strategy 化完成基準

- [ ] 残り effect_type Strategies 実装（4個）
  - [ ] AllCreaturesDamageEffectStrategy
  - [ ] SynthesisCheckEffectStrategy
  - [ ] WarpEffectStrategy
  - [ ] NullMagicEffectStrategy

- [ ] 既存スペル 11個 Strategy 化
  - [ ] FireballStrategy (Day 1-2 で実装済み確認)
  - [ ] FreezeStrategy
  - [ ] HealStrategy
  - [ ] LightningStrategy
  - [ ] ShieldStrategy
  - [ ] PoisonStrategy
  - [ ] TeleportStrategy
  - [ ] BuffStrategy
  - [ ] DebuffStrategy
  - [ ] SummonStrategy
  - [ ] OtherStrategy

- [ ] SpellStrategyFactory 最終化
  - [ ] 15個スペル全て マッピング完成

- [ ] SpellPhaseHandler 最終削減
  - [ ] 行数確認: 400行以下
  - [ ] 既存スペル実装コード全削除
  - [ ] 責務: フェーズ制御のみに簡潔化

- [ ] 統合テスト完了
  - [ ] ゲーム起動: エラーなし
  - [ ] 3ターン以上プレイ
  - [ ] 各スペル 1回以上使用
  - [ ] CPU AI 正常動作
  - [ ] エラーログ: 0個

- [ ] パフォーマンステスト
  - [ ] スペル実行時間: 従来比 100-105%
  - [ ] フレームレート: 60 FPS 維持

- [ ] ドキュメント更新
  - [ ] daily_log.md に完了記載
  - [ ] TREE_STRUCTURE.md を Phase 3-A 完了版に更新
  - [ ] Strategy 実装ガイドを implementation_patterns.md に追加

---

## I. 関連ドキュメント

### 参考すべき設計ドキュメント

1. **TREE_STRUCTURE.md**
   - SpellPhaseHandler の位置づけ（Game Flow Control Tier）
   - 新コンポーネント（UIController, TargetSelectionManager）の配置確認

2. **architecture_migration_plan.md**
   - Phase 0-3 全体の進捗状況
   - 後続 Phase 4（UIManager 責務分離）との関連性

3. **dependency_map.md**
   - SpellPhaseHandler の現在の依存関係
   - 層違反の特定と改善計画

4. **implementation_patterns.md**
   - Strategy パターンの実装テンプレート（Day 1 で作成予定）
   - context 構造の詳細

5. **CLAUDE.md**
   - プロジェクト全体の指針
   - コーディング規約（GDScript）
   - シグナル接続の is_connected() チェック必須ルール

### 既存設計ドキュメント

- `docs/design/skills_design.md` - スキルシステム仕様（参考）
- `docs/design/effect_system_design.md` - 効果システム仕様
- `docs/design/spell_system_design.md` - スペルシステム設計

---

## 要約

| 項目 | 内容 |
|-----|------|
| **目的** | SpellPhaseHandler (1,826行) → 400行に削減、Strategy パターンで分割 |
| **工期** | 4-5日（Day 1-2: 基盤 + Day 3-4: UI分離 + Day 5: 統合） |
| **優先度** | P1（最優先）|
| **リスク** | 中（既存スペル動作保証が重要）|
| **進捗判断** | Day 2, Day 4, Day 5 夜に judgment 実施 |
| **ロールバック** | 5-30分で可能（段階的コミット） |
| **成功基準** | スペル 11個 + effect_type 9-12個 Strategy 化、エラーなし 3ターン以上テスト |

---

**最終更新**: 2026-02-14
**次のアクション**: Phase 3-A-1 実装開始（Day 1）
