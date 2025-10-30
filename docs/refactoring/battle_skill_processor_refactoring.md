# BattleSkillProcessor スキル別分割計画

## 概要
- **日付**: 2025年10月31日
- **対象**: `scripts/battle/battle_skill_processor.gd`
- **推定行数**: 約1,116行（44,643文字）
- **目的**: スキル別に分割し、拡張性と保守性を向上

## 現状の課題

### 問題点
1. **ファイルサイズ**: 1,116行で分割推奨レベル
2. **スキル追加の困難性**: 新スキル追加時に大きなファイルを編集する必要
3. **テストの複雑性**: 特定スキルのテストが困難
4. **将来の拡張**: さらにスキルが増える予定

### スキル数
- **実装済み**: 17種類以上
- **今後追加予定**: 多数

---

## 分割戦略

### 基本方針: **1スキル = 1ファイル**

```
scripts/battle/skills/
├── skill_support.gd           # 応援
├── skill_assist.gd            # 援護
├── skill_affinity.gd          # 感応
├── skill_power_strike.gd      # 強打
├── skill_first_strike.gd      # 先制
├── skill_double_attack.gd     # 2回攻撃
├── skill_instant_death.gd     # 即死
├── skill_nullify.gd           # 無効化
├── skill_penetration.gd       # 貫通
├── skill_reflect.gd           # 反射
├── skill_regeneration.gd      # 再生
├── skill_scroll_attack.gd     # 巻物攻撃
├── skill_item_destruction.gd  # アイテム破壊
├── skill_item_steal.gd        # アイテム盗み
├── skill_transform.gd         # 変身
├── skill_revive.gd            # 死者復活
├── skill_vacant_move.gd       # 空地移動
├── skill_enemy_land_move.gd   # 敵地移動
├── skill_indomitable.gd       # 不屈
├── skill_land_count.gd        # 土地数比例
├── skill_destroy_count.gd     # 破壊数カウント
├── skill_hand_count.gd        # 手札数効果
├── skill_constant_bonus.gd    # 常時補正
├── skill_battle_condition.gd  # 戦闘地条件
├── skill_turn_number.gd       # ターン数ボーナス
└── skill_random_stat.gd       # ランダムステータス
```

### メインファイル（統合管理）
```
scripts/battle/battle_skill_processor.gd (約200-300行)
```

---

## 分割後のファイル構成

### 1. メインファイル (battle_skill_processor.gd)
**役割**: 
- スキルモジュールの統合管理
- フェーズ順の実行制御
- システム参照の管理

**行数目安**: 200-300行

**主要メソッド**:
```gdscript
func apply_pre_battle_skills(participants, tile_info, attacker_index)
func apply_skills(participant, context)
func setup_systems(board_system, game_flow_manager, card_system)
```

### 2. 個別スキルファイル

各スキルは独立したファイルとして実装：

| ファイル名 | スキル | 行数目安 | 優先度 |
|-----------|--------|---------|--------|
| skill_transform.gd | 変身 | 100-150 | Phase 0 (高) |
| skill_support.gd | 応援 | 150-200 | Phase 1 (高) |
| skill_affinity.gd | 感応 | 100-150 | Phase 2 (高) |
| skill_land_count.gd | 土地数比例 | 100-150 | Phase 3 (高) |
| skill_destroy_count.gd | 破壊数カウント | 50-80 | Phase 3 (中) |
| skill_hand_count.gd | 手札数効果 | 50-80 | Phase 3 (中) |
| skill_constant_bonus.gd | 常時補正 | 50-80 | Phase 3 (中) |
| skill_battle_condition.gd | 戦闘地条件 | 100-150 | Phase 3 (中) |
| skill_turn_number.gd | ターン数ボーナス | 80-100 | Phase 3 (中) |
| skill_power_strike.gd | 強打 | 100-150 | Phase 4 (高) |
| skill_scroll_attack.gd | 巻物攻撃 | 100-150 | Phase 4 (高) |
| skill_double_attack.gd | 2回攻撃 | 30-50 | Phase 5 (中) |
| skill_reflect.gd | 反射 | 150-200 | 戦闘中 (中) |
| skill_item_destruction.gd | アイテム破壊 | 80-100 | 戦闘前 (中) |
| skill_item_steal.gd | アイテム盗み | 80-100 | 戦闘前 (中) |
| skill_random_stat.gd | ランダムステータス | 50-80 | 準備時 (低) |
| skill_instant_death.gd | 即死 | 80-100 | 戦闘後 (中) |
| skill_nullify.gd | 無効化 | 100-150 | 戦闘前 (中) |
| skill_penetration.gd | 貫通 | 30-50 | 戦闘前 (低) |
| skill_regeneration.gd | 再生 | 30-50 | 戦闘後 (中) |
| skill_first_strike.gd | 先制 | 30-50 | 準備時 (低) |
| skill_revive.gd | 死者復活 | 80-100 | 戦闘後 (低) |
| skill_vacant_move.gd | 空地移動 | 50-80 | 移動時 (低) |
| skill_enemy_land_move.gd | 敵地移動 | 50-80 | 移動時 (低) |
| skill_indomitable.gd | 不屈 | 30-50 | 移動時 (低) |
| skill_assist.gd | 援護 | 100-150 | アイテム (低) |

**合計推定**: 約2,000-2,500行（元: 1,116行、増加: +80-120%）

---

## 設計パターン

### Static関数パターン（推奨）

各スキルファイルはStatic関数のみで実装：

```gdscript
# skill_power_strike.gd
class_name SkillPowerStrike

## 強打スキルを適用
## @param participant: BattleParticipant
## @param context: 戦闘コンテキスト
## @return: 適用されたか
static func apply(participant: BattleParticipant, context: Dictionary) -> bool:
	var keywords = participant.creature_data.get("ability_parsed", {}).get("keywords", [])
	
	if not "強打" in keywords:
		return false
	
	# 条件チェック
	var keyword_conditions = participant.creature_data.get("ability_parsed", {}).get("keyword_conditions", {})
	var power_strike_condition = keyword_conditions.get("強打", {})
	
	var condition_checker = ConditionChecker.new()
	if not condition_checker._evaluate_single_condition(power_strike_condition, context):
		return false
	
	# 強打適用
	var multiplier = power_strike_condition.get("multiplier", 2.0)
	var old_ap = participant.current_ap
	participant.current_ap = int(participant.current_ap * multiplier)
	
	print("【強打】", participant.creature_data.get("name"), " AP:", old_ap, "→", participant.current_ap)
	return true

## 強打スキルを持つかチェック（オプション）
static func has_skill(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "強打" in keywords
```

### メインファイルからの呼び出し

```gdscript
# battle_skill_processor.gd

# スキルモジュールをpreload
const SkillTransform = preload("res://scripts/battle/skills/skill_transform.gd")
const SkillSupport = preload("res://scripts/battle/skills/skill_support.gd")
const SkillAffinity = preload("res://scripts/battle/skills/skill_affinity.gd")
const SkillPowerStrike = preload("res://scripts/battle/skills/skill_power_strike.gd")
const SkillLandCount = preload("res://scripts/battle/skills/skill_land_count.gd")
# ... 他のスキルも同様

func apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> void:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# Phase 0: 変身
	SkillTransform.apply(attacker)
	SkillTransform.apply(defender)
	
	# Phase 1: 応援
	SkillSupport.apply_to_all(participants, tile_info.get("index", -1), board_system_ref)
	
	# コンテキスト構築
	var attacker_context = _build_context(attacker, defender, tile_info, attacker_index)
	var defender_context = _build_context(defender, attacker, tile_info, defender.player_id)
	
	# Phase 2: 感応
	SkillAffinity.apply(attacker, attacker_context)
	SkillAffinity.apply(defender, defender_context)
	
	# Phase 3: 各種効果
	SkillLandCount.apply(attacker, attacker_context)
	SkillLandCount.apply(defender, defender_context)
	
	# Phase 4: 強打
	SkillPowerStrike.apply(attacker, attacker_context)
	SkillPowerStrike.apply(defender, defender_context)
	
	# ... 他のフェーズも同様
```

---

## 分割のメリット

### 1. 拡張性
- **新スキル追加 = 新ファイル作成**
- 既存コードに一切触らない
- Git競合ゼロ

### 2. 可読性
- 1ファイル50-200行で見通しが良い
- スキル名でファイルを特定できる
- コードの意図が明確

### 3. テスト容易性
```gdscript
# tests/test_skill_power_strike.gd
func test_power_strike_with_mhp_condition():
	var participant = create_test_participant()
	var context = create_test_context()
	var result = SkillPowerStrike.apply(participant, context)
	assert_true(result)
	assert_equal(participant.current_ap, 60)  # 30 × 2.0
```

### 4. 並行開発
- 複数人で異なるスキルを同時開発可能
- ファイル競合が発生しない

### 5. 保守性
- バグ修正が該当ファイルのみ
- スキル削除も該当ファイルの削除だけ

---

## 実装手順

### Step 1: ディレクトリ作成
```bash
mkdir -p scripts/battle/skills
```

### Step 2: 優先順位別に分離

#### フェーズ別の優先順位
1. **Phase 0 (変身)** - 最優先
2. **Phase 1 (応援)** - 高優先度
3. **Phase 2 (感応)** - 高優先度
4. **Phase 3 (効果)** - 中優先度
5. **Phase 4 (強打・巻物)** - 高優先度
6. **戦闘中・戦闘後** - 低優先度

### Step 3: 1スキルずつ分離とテスト（重要）

**⚠️ 必須ルール: 1スキル完了毎にドキュメント更新**

**手順**:
1. 新しいスキルファイルを作成
2. battle_skill_processor.gdから該当コードを移動
3. メインファイルでpreloadと呼び出しを追加
4. テスト実行・動作確認
5. **📝 ドキュメント更新（必須）**:
   - `docs/design/skills_design.md` - スキルの実装状況と新ファイルパスを更新
   - `docs/design/condition_patterns_catalog.md` - 使用された条件パターンを更新
6. 次のスキルへ

**重要**: スキル分離完了後、**必ず次のスキルに進む前に**上記2つのドキュメントを更新すること。これにより：
- ✅ 実装状況が常に最新
- ✅ 条件パターンの使用状況が追跡可能
- ✅ 分離作業の進捗が可視化
- ✅ 後続作業者が現状を把握しやすい

### Step 4: 全スキル分離完了後のドキュメント更新

全スキルの分離が完了した後に更新：
- `docs/README.md` - 新ディレクトリ構造を反映
- `docs/progress/daily_log.md` - リファクタリング完了を記録

---

## ドキュメント更新の具体例

### skills_design.md の更新例

**分離前**:
```markdown
### 強打
- **実装状況**: ✅ 完了
- **実装場所**: `scripts/battle/battle_skill_processor.gd`
- **関数**: `apply_power_strike_skills()`
```

**分離後**:
```markdown
### 強打
- **実装状況**: ✅ 完了（分離済み）
- **実装場所**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `SkillPowerStrike.apply()`
- **分離日**: 2025-10-31
```

### condition_patterns_catalog.md の更新例

**スキル分離時に追記**:
```markdown
## 使用箇所リスト

### 3-1. MHP（最大HP）閾値以下
- ✅ **skill_power_strike.gd** - 強打の条件判定
  - 条件: `{"condition_type": "mhp_below", "value": 40}`
  - 行数: 約25行目

### 7-3. 種族条件
- ✅ **skill_support.gd** - 応援の対象判定
  - 条件: `{"condition_type": "race", "race": "goblin"}`
  - 行数: 約45行目
```

---

## 成功の鍵

### ✅ DO（すべき）
1. **Static関数のみ使用**（インスタンス生成不要）
2. **1スキル = 1ファイル**（明確な責任分離）
3. **既存インターフェース維持**（外部コードの変更不要）
4. **段階的な分離**（一度に全部やらない）
5. **各段階でテスト**（動作確認を徹底）
6. **📝 1スキル毎にドキュメント更新**（skills_design.md + condition_patterns_catalog.md）

### ❌ DON'T（避けるべき）
1. **後方互換性メソッドの追加**（コード増加の原因）
2. **新しいシグナルの作成**（複雑性が増す）
3. **状態の重複管理**（バグの温床）
4. **一度に全スキル分離**（リスクが高い）
5. **テストのスキップ**（バグが埋め込まれる）
6. **ドキュメント更新の先送り**（実装状況の把握が困難になる）

---

## リスク管理

### 想定リスク

1. **行数の増加** 
   - 予想: +80-120%（1,116 → 2,000-2,500行）
   - 対策: Static関数のみで最小化

2. **パフォーマンス低下**
   - 予想: ほぼ影響なし（preloadで最適化）
   - 対策: 必要に応じてプロファイリング

3. **既存機能の破壊**
   - 予想: 段階的分離で最小化
   - 対策: 各段階で徹底テスト

4. **ファイル数の増加**
   - 予想: 25ファイル程度
   - 影響: 問題なし（むしろメリット）

---

## 期待される効果

### 定量的効果
- ファイル数: 1 → 25ファイル（+2,400%）
- 平均ファイルサイズ: 1,116行 → 80-100行（-90%）
- 新スキル追加時間: 大幅短縮

### 定性的効果
- コードの可読性: 大幅向上
- テスト容易性: 大幅向上
- 保守性: 大幅向上
- 拡張性: 大幅向上
- 並行開発: 可能に

---

## 参考: 過去の成功事例

### LandCommandHandler分割（2025年10月）
- **元**: 881行
- **分割後**: 4ファイル、合計988行
- **増加率**: +12%
- **パターン**: Static関数
- **結果**: 大成功

### TileActionProcessor分割
- **元**: 1,284行
- **分割後**: 5ファイル
- **増加率**: +0%
- **結果**: 大成功

---

## まとめ

**BattleSkillProcessor**を**スキル別に分割**することで：

1. ✅ 新スキル追加が容易
2. ✅ コードの可読性が向上
3. ✅ テストが簡単
4. ✅ 保守性が向上
5. ✅ 並行開発が可能

**ファイル数の増加は問題ではなく、むしろメリット**です。

---

**次のステップ**: 
1. この計画をレビュー
2. Phase 0（変身スキル）から分離開始
3. **各スキル完了毎に必ずドキュメント更新**（skills_design.md + condition_patterns_catalog.md）
4. 各段階でテストを実施

**重要な注意事項**:
- ⚠️ **絶対にドキュメント更新をスキップしない**
- ⚠️ 複数スキルをまとめて分離してから更新、は禁止
- ✅ 1スキル完了 → ドキュメント更新 → 次のスキル、の順守

**Last updated**: 2025-10-31
