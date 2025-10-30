# コード統一化リファクタリング計画

**作成日**: 2025年10月30日  
**目的**: 条件分岐パターンのコード不統一を解消し、保守性とテスト容易性を向上  
**対象**: 条件分岐処理全般

---

## 📋 目次

1. 問題の概要
2. 統一すべき箇所の詳細
3. 新クラス設計
4. 対象クリーチャー一覧
5. テスト計画
6. 実装手順

---

## 1. 問題の概要

### 1.1 現状の問題

同じ処理を行うコードが複数の場所で**異なる書き方**で実装されている：

- **MHP計算**: 3種類の異なる書き方
- **土地数取得**: 2種類の異なる書き方
- **領地レベル取得**: 2種類の異なるキー名
- **条件判定**: 関数経由と直接比較が混在

### 1.2 問題の影響

- ❌ **保守コストの増加**: 同じロジックを複数箇所で修正が必要
- ❌ **バグの温床**: 一部だけ修正漏れが発生しやすい
- ❌ **テストの困難**: テストケースが分散
- ❌ **可読性の低下**: 新規開発者が混乱

---

## 2. 統一すべき箇所の詳細

### 🔥 最優先（P0）: MHP計算の統一

#### 問題の詳細

**現在の3パターン**:

```gdscript
# パターンA: battle_skill_processor.gd (1箇所)
var creature_mhp = creature_hp + creature_base_up_hp

# パターンB: battle_preparation.gd (援護MHP取得)
var assist_mhp = assist_base_hp + assist_base_up_hp

# パターンC: context経由 (condition_checker.gd等)
var target_mhp = context.get("creature_mhp", 100)

# パターンD: battle_participant.gd (update_current_hp)
current_hp = base_hp + base_up_hp + temporary_bonus_hp + \
			 resonance_bonus_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp
```

#### 使用箇所

| ファイル | 行数 | 処理内容 |
|---------|-----|---------|
| battle_skill_processor.gd | 1087 | ジェネラルカンのMHP50以上カウント |
| battle_skill_processor.gd | 1318 | スペクターのランダムMHP計算 |
| battle_preparation.gd | 複数 | ブラッドプリンの援護MHP取得 |
| battle_special_effects.gd | 103, 109 | 無効化判定のMHPチェック |
| movement_controller.gd | 300, 413 | HP回復処理 |
| game_flow_manager.gd | 688 | HP管理 |
| battle_participant.gd | 82 | current_hp計算 |

#### 対象クリーチャー

**MHP計算を使用するクリーチャー（8体）:**

| ID | 名前 | 使用箇所 | 効果 |
|----|------|---------|------|
| 15 | ジェネラルカン | battle_skill_processor.gd | ST+MHP50以上配置数×5 |
| 137 | ブラッドプリン | battle_preparation.gd | 援護MHP吸収 |
| 321 | スペクター | battle_skill_processor.gd | ランダムMHP設定 |
| - | 強打条件持ち全般 | condition_checker.gd | MHP閾値判定 |
| 42 | フロギストン | condition_checker.gd | MHP40以下で強打 |
| - | ウォーリアー系 | condition_checker.gd | MHP50以上で強打 |
| - | 無効化持ち全般 | battle_special_effects.gd | MHP条件で無効化 |
| - | 全クリーチャー | battle_participant.gd | 基本HP計算 |

**影響範囲**: 38体全てのクリーチャー（MHPは全てに関係）

#### 解決策

新規ユーティリティクラス `StatCalculator` を作成：

```gdscript
class StatCalculator:
	# 基礎MHP計算（base_hp + base_up_hp）
	static func calculate_base_mhp(creature_data: Dictionary) -> int
	
	# 完全MHP計算（全ボーナス含む）
	static func calculate_full_mhp(participant: BattleParticipant) -> int
	
	# 基礎ST計算
	static func calculate_base_st(creature_data: Dictionary) -> int
```

---


### 🌟 高優先度（P1）: 土地数取得の統一

#### 問題の詳細

**現在の状況**:

```gdscript
# 推奨パターン: board_system_3d.gd のメソッド使用
var player_lands = board_system_ref.get_player_lands_by_element(player_id)
var fire_count = player_lands.get("fire", 0)

# 非推奨: 直接ループ（現状は見当たらないが潜在的リスク）
```

#### 使用箇所

| ファイル | 行数 | 処理内容 |
|---------|-----|---------|
| battle_skill_processor.gd | 26, 49 | apply_land_count_effects |
| board_system_3d.gd | 269 | get_player_lands_by_element（本体） |

#### 対象クリーチャー

**土地数比例スキルを持つクリーチャー（11体）:**

| ID | 名前 | 効果 |
|----|------|------|
| 1 | アームドパラディン | ST+（火+地）配置数×10 |
| 37 | ファイアードレイク | ST+火配置数×5 |
| 109 | アンダイン | HP=水配置数×20 |
| 133 | ケンタウロス | ST+水配置数×5 |
| 135 | サラマンダー | HP+火配置数×5 |
| 205 | カクタスウォール | 水/風敵でHP+50、地配置数×5 |
| 236 | ブランチアーミー | ST+地配置数×5 |
| 238 | マッドマン | HP+地配置数×5 |
| 307 | ガルーダ | ST&HP=風配置数×10 |
| 308 | ハーピー | HP+風配置数×5 |
| 310 | サンダーバード | ST+風配置数×5 |

**影響範囲**: 11体

#### 解決策

現状は統一されているため、**ドキュメント化とレビュー強化**で対応

---

### 🌟 高優先度（P1）: 条件判定の統一

#### 問題の詳細

**現在の2パターン**:

```gdscript
# パターンA: condition_checker.gd経由（推奨）
if condition_checker.mhp_below(context):

# パターンB: 直接比較（非推奨）
if target_mhp <= 40:
```

#### 使用箇所

| ファイル | パターン | 処理内容 |
|---------|---------|---------|
| battle_skill_processor.gd | 直接比較 | ジェネラルカンのMHP閾値 |
| battle_special_effects.gd | 直接比較 | 無効化のMHP/ST判定 |
| condition_checker.gd | 関数経由 | 強打条件等 |

#### 対象クリーチャー

**MHP/ST条件を持つクリーチャー（多数）:**

- フロギストン（MHP40以下で強打）
- ウォーリアー系（MHP50以上で強打）
- ジェネラルカン（MHP50以上カウント）
- 無効化持ち全般（MHP/ST条件）

**影響範囲**: 15体以上

#### 解決策

`condition_checker.gd` を拡張し、全ての条件判定を統一：

```gdscript
# StatCalculatorから値を取得してConditionCheckerで判定
if condition_checker.check_mhp_threshold(creature_data, ">=", 50):
```

---

## 3. 新クラス設計

### 3.1 StatCalculator クラス

**ファイル名**: `scripts/utils/stat_calculator.gd`

```gdscript
class_name StatCalculator

## ステータス計算ユーティリティ
## 全てのステータス計算を統一的に行う

## 基礎MHP計算（base_hp + base_up_hp）
static func calculate_base_mhp(creature_data: Dictionary) -> int:
	var base_hp = creature_data.get("hp", 0)
	var base_up_hp = creature_data.get("base_up_hp", 0)
	return base_hp + base_up_hp

## 完全MHP計算（BattleParticipantから全ボーナスを含めて計算）
static func calculate_full_mhp(participant: BattleParticipant) -> int:
	return participant.base_hp + participant.base_up_hp + \
		   participant.temporary_bonus_hp + participant.resonance_bonus_hp + \
		   participant.land_bonus_hp + participant.item_bonus_hp + \
		   participant.spell_bonus_hp

## 基礎ST計算（ap + base_up_ap）
static func calculate_base_st(creature_data: Dictionary) -> int:
	var base_ap = creature_data.get("ap", 0)
	var base_up_ap = creature_data.get("base_up_ap", 0)
	return base_ap + base_up_ap

## creature_dataから基礎MHPを簡易取得（BattleParticipant不要版）
static func get_base_mhp_from_data(creature_data: Dictionary) -> int:
	return calculate_base_mhp(creature_data)

## creature_dataから基礎STを簡易取得
static func get_base_st_from_data(creature_data: Dictionary) -> int:
	return calculate_base_st(creature_data)
```

**使用例**:

```gdscript
# 修正前
var creature_mhp = creature_hp + creature_base_up_hp

# 修正後
var creature_mhp = StatCalculator.calculate_base_mhp(creature_data)
```

---

### 3.2 ConditionChecker 拡張

**既存**: `scripts/skills/condition_checker.gd`

**追加メソッド**:

```gdscript
## MHP閾値チェック（汎用）
func check_mhp_threshold(creature_data: Dictionary, operator: String, threshold: int) -> bool:
	var mhp = StatCalculator.calculate_base_mhp(creature_data)
	match operator:
		">=":
			return mhp >= threshold
		"<=":
			return mhp <= threshold
		">":
			return mhp > threshold
		"<":
			return mhp < threshold
		"==":
			return mhp == threshold
		_:
			push_error("Invalid operator: " + operator)
			return false

## ST閾値チェック（汎用）
func check_st_threshold(creature_data: Dictionary, operator: String, threshold: int) -> bool:
	var st = StatCalculator.calculate_base_st(creature_data)
	match operator:
		">=":
			return st >= threshold
		"<=":
			return st <= threshold
		">":
			return st > threshold
		"<":
			return st < threshold
		"==":
			return st == threshold
		_:
			push_error("Invalid operator: " + operator)
			return false
```

---

## 4. 対象クリーチャー一覧

### 4.1 MHP計算の修正対象（38体全て）

全クリーチャーが影響を受けるため、特に注意が必要なクリーチャーを列挙：

| ID | 名前 | 優先度 | 理由 |
|----|------|-------|------|
| 15 | ジェネラルカン | 🔥 高 | MHP条件付きカウント |
| 137 | ブラッドプリン | 🔥 高 | 援護MHP吸収 |
| 321 | スペクター | 🔥 高 | ランダムMHP設定 |
| 42 | フロギストン | 🌟 中 | MHP40以下強打 |
| - | ウォーリアー系 | 🌟 中 | MHP50以上強打 |
| - | 無効化持ち | 🌟 中 | MHP条件無効化 |

### 4.2 領地レベルの修正対象（2体）

| ID | 名前 | 優先度 | 修正内容 |
|----|------|-------|---------|
| 131 | ネッシー | 🔥 高 | キー名統一のみ |
| - | 無効化持ち（条件付き） | 🌟 中 | キー名統一のみ |

### 4.3 土地数取得の確認対象（11体）

現状は統一されているが、レビュー必須：

| ID | 名前 | 確認内容 |
|----|------|---------|
| 1 | アームドパラディン | 複数属性合計 |
| 37 | ファイアードレイク | 単一属性 |
| 109 | アンダイン | 単一属性 |
| 133 | ケンタウロス | 単一属性 |
| 135 | サラマンダー | 単一属性 |
| 205 | カクタスウォール | 条件付き単一属性 |
| 236 | ブランチアーミー | 単一属性 |
| 238 | マッドマン | 単一属性 |
| 307 | ガルーダ | 単一属性 |
| 308 | ハーピー | 単一属性 |
| 310 | サンダーバード | 単一属性 |

---

## 5. テスト計画

### 5.1 ユニットテスト

#### StatCalculator のテスト

**ファイル名**: `tests/unit/test_stat_calculator.gd`

```gdscript
extends GutTest

func test_calculate_base_mhp_normal():
	var data = {"hp": 50, "base_up_hp": 10}
	assert_eq(StatCalculator.calculate_base_mhp(data), 60)

func test_calculate_base_mhp_zero():
	var data = {"hp": 0, "base_up_hp": 0}
	assert_eq(StatCalculator.calculate_base_mhp(data), 0)

func test_calculate_base_mhp_missing_fields():
	var data = {}
	assert_eq(StatCalculator.calculate_base_mhp(data), 0)

func test_calculate_base_st_normal():
	var data = {"ap": 30, "base_up_ap": 5}
	assert_eq(StatCalculator.calculate_base_st(data), 35)
```

**テストケース数**: 最低10ケース

---

#### ConditionChecker 拡張のテスト

**ファイル名**: `tests/unit/test_condition_checker_extended.gd`

```gdscript
extends GutTest

var checker: ConditionChecker

func before_each():
	checker = ConditionChecker.new()

func test_check_mhp_threshold_greater_equal():
	var data = {"hp": 50, "base_up_hp": 10}
	assert_true(checker.check_mhp_threshold(data, ">=", 60))
	assert_true(checker.check_mhp_threshold(data, ">=", 50))
	assert_false(checker.check_mhp_threshold(data, ">=", 61))

func test_check_mhp_threshold_less_equal():
	var data = {"hp": 40, "base_up_hp": 0}
	assert_true(checker.check_mhp_threshold(data, "<=", 40))
	assert_true(checker.check_mhp_threshold(data, "<=", 50))
	assert_false(checker.check_mhp_threshold(data, "<=", 39))
```

**テストケース数**: 最低15ケース

---

### 5.2 統合テスト

#### 対象クリーチャーごとのテスト

**ファイル名**: `tests/integration/test_creatures_after_refactor.gd`

**テスト対象**:

1. **ジェネラルカン (ID: 15)**
   - MHP50以上のクリーチャーカウントが正しいか
   - ST計算が正しいか

2. **ブラッドプリン (ID: 137)**
   - 援護MHP吸収が正しく動作するか

3. **スペクター (ID: 321)**
   - ランダムMHP設定が範囲内か

4. **ネッシー (ID: 131)**
   - 水の土地でレベルボーナスが正しく適用されるか

5. **フロギストン (ID: 42)**
   - MHP40以下で強打が発動するか

**テストケース数**: 対象クリーチャー5体 × 3ケース = 15ケース

---

### 5.3 回帰テスト

#### 全クリーチャーの動作確認

**目的**: リファクタリング後も既存機能が動作することを保証

**方法**:
1. リファクタリング前の動作を記録
2. リファクタリング後に同じ条件でテスト
3. 結果を比較

**確認項目**:
- バトル準備時のステータス計算
- 条件分岐の発動有無
- ダメージ計算

**テストケース数**: 主要クリーチャー20体 × 2ケース = 40ケース

---

## 6. 実装手順

### フェーズ1: 新クラス作成とユニットテスト（1日目）

#### 1.1 StatCalculator 作成
- [ ] `scripts/utils/stat_calculator.gd` を作成
- [ ] メソッド実装
- [ ] ユニットテスト作成
- [ ] テスト実行・合格確認

#### 1.2 ConditionChecker 拡張
- [ ] 新メソッド追加
- [ ] ユニットテスト作成
- [ ] テスト実行・合格確認

---

### フェーズ2: 領地レベルキー名統一（1日目）

#### 2.1 キー名置換
- [ ] `condition_checker.gd` の `"current_land_level"` → `"tile_level"`
- [ ] `battle_special_effects.gd` の `"current_land_level"` → `"tile_level"`

#### 2.2 テスト
- [ ] ネッシーの動作確認
- [ ] 無効化条件の動作確認

**影響範囲**: 小（2ファイル、2体）

---

### フェーズ3: MHP計算の統一（2日目）

#### 3.1 battle_skill_processor.gd の修正
- [ ] 行1087: ジェネラルカンのMHP計算
- [ ] 行1318: スペクターのMHP計算
- [ ] テスト実行

#### 3.2 battle_preparation.gd の修正
- [ ] ブラッドプリンの援護MHP計算
- [ ] テスト実行

#### 3.3 battle_special_effects.gd の修正
- [ ] 行103, 109: 無効化判定のMHP計算
- [ ] テスト実行

#### 3.4 その他ファイルの修正
- [ ] movement_controller.gd
- [ ] game_flow_manager.gd
- [ ] テスト実行

**影響範囲**: 大（7ファイル、38体全て）

---

### フェーズ4: 条件判定の統一（3日目）

#### 4.1 battle_skill_processor.gd の修正
- [ ] ジェネラルカンの条件判定
- [ ] テスト実行

#### 4.2 battle_special_effects.gd の修正
- [ ] 無効化条件の判定
- [ ] テスト実行

**影響範囲**: 中（2ファイル、15体以上）

---

### フェーズ5: 統合テストと回帰テスト（4日目）

#### 5.1 統合テスト
- [ ] 対象クリーチャー5体のテスト実行
- [ ] 問題があれば修正

#### 5.2 回帰テスト
- [ ] 主要クリーチャー20体の動作確認
- [ ] 問題があれば修正

#### 5.3 最終確認
- [ ] 全テストが合格
- [ ] コードレビュー
- [ ] ドキュメント更新

---

### フェーズ6: ドキュメント更新（4日目）

#### 6.1 設計ドキュメント更新
- [ ] `condition_patterns_catalog.md` にStatCalculator追加
- [ ] 使用例の更新

#### 6.2 コーディング規約更新
- [ ] MHP計算は必ずStatCalculatorを使用
- [ ] 条件判定は必ずConditionCheckerを使用

---

## 7. リスク管理

### 7.1 高リスク項目

| リスク | 影響度 | 対策 |
|--------|--------|------|
| MHP計算ロジックの差異 | 高 | 詳細な単体テストで検証 |
| BattleParticipantとの統合 | 高 | 段階的実装、テスト |
| 回帰バグ | 中 | 全クリーチャーの回帰テスト |

### 7.2 ロールバック計画

- Git ブランチで作業
- フェーズごとにコミット
- 問題があれば前のコミットに戻す

---

## 8. 成果指標

### 8.1 コード品質

- [ ] 重複コード削減: **150-200行削減目標**
- [ ] 条件判定の統一率: **100%**
- [ ] テストカバレッジ: **80%以上**

### 8.2 保守性

- [ ] 修正箇所の削減: **10-15箇所 → 1箇所**
- [ ] 新規条件追加の工数: **60%削減**

---

**最終更新**: 2025年10月30日
