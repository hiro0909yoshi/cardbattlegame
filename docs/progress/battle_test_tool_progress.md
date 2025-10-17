# バトルテストツール開発進捗

**開始日**: 2025年10月18日  
**ステータス**: 設計完了 → 実装待ち  
**目的**: スペル・アイテム・スキルの効果を網羅的にテストし、バランス調整・バグ検出を行う

---

## ⚠️ 重要：実装時の注意事項

**このツールを実装する際は、必ず以下の設計書を参照してください：**

1. **[design.md](../design/design.md)**
   - バトルシステムの仕様
   - BattleParticipantの構造
   - ダメージ計算ロジック
   - 土地連鎖・ボーナス計算
   - 先制攻撃判定

2. **[skills_design.md](../design/skills_design.md)**
   - スキルシステムの全体構造
   - ability_parsedの構造
   - 条件判定システム（ConditionChecker）
   - 効果適用システム（EffectCombat）
   - 実装済みスキル一覧
   - スキル適用順序

3. **[spell_and_item_implementation_details（メモリ）](../../.serena/memories/spell_and_item_implementation_details.md)**
   - スペル効果の適用方法
   - アイテム効果の実装状況
   - ability_parsedの解析方法

**特に重要なポイント：**
- バトル実行には既存の`BattleSystem.determine_battle_result_with_priority()`を使用
- スキル適用は`SkillSystem`のメソッドを活用
- 土地条件は`BoardSystem3D`または`TileDataManager`から取得
- ability_parsedの構造に従ってスキル効果を適用

---

## 📊 進捗サマリー

| フェーズ | ステータス | 完了率 | 備考 |
|---------|-----------|--------|------|
| Phase 1: 設計・仕様策定 | ✅ 完了 | 100% | 2025/10/18 |
| Phase 2: データ構造実装 | ⏳ 未着手 | 0% | |
| Phase 3: UI実装 | ⏳ 未着手 | 0% | |
| Phase 4: バトルロジック統合 | ⏳ 未着手 | 0% | |
| Phase 5: 結果表示実装 | ⏳ 未着手 | 0% | |
| Phase 6: テスト・デバッグ | ⏳ 未着手 | 0% | |

**総合進捗**: 17% (1/6フェーズ完了)

---

## 🎯 プロジェクト概要

### 目的
1. スペル・アイテム使用時の効果を網羅的にテスト
2. 数値異常やバグを早期発見
3. バランス調整のための統計データ収集
4. リファクタリング時の回帰テスト

### テスト規模
```
10クリーチャー × 10クリーチャー × 20アイテム × 20アイテム × 1スペル
= 40,000 バトル
実行時間: 約6-7分
メモリ使用量: 約10MB
```

### 主要機能
1. ✅ ID入力式のクリーチャー・アイテム・スペル選択
2. ✅ プリセット機能（火水風地・先制・強打・無効化）
3. ✅ 土地保有数・バトル土地属性の設定
4. ✅ 隣接条件のON/OFF
5. ✅ 攻撃⇔防御の入れ替え
6. ✅ テーブル形式での結果表示
7. ✅ 詳細バトルログの閲覧
8. ✅ 統計サマリー（折りたたみ式）
9. ✅ CSV出力
10. ✅ ID参照パネル（折りたたみ式）

---

## 📅 Phase 1: 設計・仕様策定 ✅ 完了

**期間**: 2025/10/18  
**ステータス**: ✅ 完了

### 完了項目
- [x] 要件定義
- [x] UI設計
- [x] データ構造設計
- [x] プリセット定義
- [x] 結果表示フォーマット決定
- [x] ファイル構成決定
- [x] 容量見積もり

### 主要な決定事項

#### プリセット構成
```gdscript
CREATURE_PRESETS = {
	"火属性": [2, 4, 7, 9, 15, 16, 19],
	"水属性": [101, 104, 108, 113, 116, 120],
	"風属性": [300, 303, 307, 309, 315, 320],
	"地属性": [201, 205, 210, 215, 220],
	"先制攻撃持ち": [7, 303, 405],
	"強打持ち": [4, 9, 19],
	"無効化持ち": [1, 6, 11, 16, 112, 325, 413],
}

SPELL_PRESETS = {
	"攻撃系": [],  # 手動追加予定
	"防御系": [],  # 手動追加予定
}
```

#### データ構造
- BattleTestConfig: テスト設定
- BattleTestResult: 個別バトル結果
- BattleTestStatistics: 統計計算

#### UI構成
1. 設定パネル（攻撃側・防御側）
2. ID参照パネル（折りたたみ）
3. 実行パネル（プログレスバー）
4. 結果パネル（テーブル・詳細・統計）

---

## 📅 Phase 2: データ構造実装 ⏳ 未着手

**見積もり時間**: 1時間  
**ステータス**: ⏳ 未着手

### 📖 参照すべき設計書
- **[design.md](../design/design.md)** - データ構造セクション
- **[skills_design.md](../design/skills_design.md)** - ability_parsedの構造

### タスク一覧
- [ ] `battle_test_config.gd` 作成
- [ ] `battle_test_result.gd` 作成
- [ ] `battle_test_statistics.gd` 作成
- [ ] `test_presets.gd` 作成
- [ ] 各クラスのユニットテスト

### 実装ファイル
```
scripts/battle_test/
├── battle_test_config.gd       # テスト設定データ
├── battle_test_result.gd       # 結果データ
├── battle_test_statistics.gd   # 統計計算
└── test_presets.gd             # プリセット定義
```

### 実装要件

#### BattleTestConfig
```gdscript
# 攻撃側・防御側それぞれに以下を定義
class_name BattleTestConfig
extends RefCounted

var attacker_creatures: Array[int] = []      # クリーチャーID
var attacker_items: Array[int] = []          # アイテムID
var attacker_spell: int = -1                 # スペルID (-1 = なし)
var attacker_owned_lands: Dictionary = {     # 保有土地数
	"fire": 0,
	"water": 0,
	"earth": 0,
	"wind": 0
}
var attacker_battle_land: String = "fire"    # バトル発生土地の属性
var attacker_has_adjacent: bool = false      # 隣接条件

# 防御側も同様の構造
```

#### BattleTestResult
```gdscript
class_name BattleTestResult
extends RefCounted

# 基本情報
var battle_id: int
var attacker_name: String
var defender_name: String

# アイテム・スペル
var attacker_item_name: String
var defender_item_name: String
var attacker_spell_name: String
var defender_spell_name: String

# 最終ステータス
var attacker_final_ap: int
var attacker_final_hp: int         # 残HP
var attacker_skills_triggered: Array[String]  # 発動したスキル

var defender_final_ap: int
var defender_final_hp: int         # 残HP
var defender_skills_triggered: Array[String]

# 結果
var winner: String  # "attacker" or "defender"

# バトル条件
var battle_land: String
var attacker_owned_lands: Dictionary
var defender_owned_lands: Dictionary
var attacker_has_adjacent: bool
var defender_has_adjacent: bool

# ダメージ詳細
var damage_dealt_by_attacker: int
var damage_dealt_by_defender: int
```

### 完了条件
- [ ] すべてのデータクラスが正しく動作
- [ ] プリセットが正しく定義されている
- [ ] to_dict()メソッドでJSON/CSV変換可能

---

## 📅 Phase 3: UI実装 ⏳ 未着手

**見積もり時間**: 2.5時間  
**ステータス**: ⏳ 未着手

### タスク一覧
- [ ] `battle_test_tool.tscn` シーン作成
- [ ] `id_input_field.gd` 実装（ID入力コンポーネント）
- [ ] `id_reference_panel.gd` 実装（ID参照パネル）
- [ ] 攻撃側設定パネルUI
- [ ] 防御側設定パネルUI
- [ ] 土地設定UI（スライダー）
- [ ] 入れ替えボタン実装
- [ ] プリセット選択ドロップダウン

### 実装ファイル
```
scripts/battle_test/
├── battle_test_ui.gd           # メインUIコントローラー
├── id_input_field.gd           # ID入力フィールド
└── id_reference_panel.gd       # ID参照パネル

scenes/
└── battle_test_tool.tscn       # メインシーン
```

### UI機能要件
1. **ID入力**
   - リアルタイム名前表示
   - 存在しないIDは赤色表示
   - "なし"入力対応
   
2. **プリセット選択**
   - ドロップダウンメニュー
   - 選択でID自動入力
   
3. **ID参照パネル**
   - 折りたたみ式
   - 検索機能
   - クリックでIDコピー

### 完了条件
- [ ] ID入力でクリーチャー名が正しく表示
- [ ] プリセット選択が動作
- [ ] 攻撃⇔防御入れ替えが動作
- [ ] 設定が正しくBattleTestConfigに反映

---

## 📅 Phase 4: バトルロジック統合 ⏳ 未着手

**見積もり時間**: 2時間  
**ステータス**: ⏳ 未着手

### 📖 参照すべき設計書（重要！）
- **[design.md](../design/design.md)** - バトルシステムセクション
  - `BattleSystem.determine_battle_result_with_priority()`の仕様
  - 先制攻撃判定ロジック
  - ダメージ計算方法
  - 属性相性・地形ボーナス
  
- **[skills_design.md](../design/skills_design.md)**
  - スキル適用順序
  - ConditionCheckerの使い方
  - EffectCombatの使い方
  - バトルコンテキストの構築方法

### タスク一覧
- [ ] `battle_test_executor.gd` 実装
- [ ] BattleParticipant生成ロジック
- [ ] 土地条件・スキル適用ロジック
- [ ] **アイテムによるスキル付与ロジック** ★追加
- [ ] **スペルによるスキル付与ロジック** ★追加
- [ ] 既存BattleSystemとの統合
- [ ] プログレスバー実装
- [ ] バックグラウンド実行対応

### 実装ファイル
```
scripts/battle_test/
└── battle_test_executor.gd     # バトル実行エンジン
```

### 技術的課題
- **パフォーマンス**: 40,000バトルを6-7分で実行
- **UI応答性**: バトル実行中もUIを応答可能に
- **メモリ管理**: 結果データ10MBの効率的管理（スキル付与情報含む） ★更新

### スキル付与機能の実装 ★追加
Phase 4では、アイテム・スペルによるスキル付与機能を実装します。

#### 既存システムの活用
- `BattleSystem._apply_item_effects()` - アイテム効果を適用
- `BattleSystem._grant_skill_to_participant()` - スキルを付与
- `BattleSystem._check_skill_grant_condition()` - 付与条件を判定

#### 実装するスキル付与
1. **先制攻撃** - `has_item_first_strike = true`
2. **後手** - `has_last_strike = true`
3. **強打** - `has_power_strike = true`
4. **今後追加されるスキル** - 拡張可能な設計

#### 条件付き付与の対応
- `user_element` による属性条件
- 例：「火属性のみ強打付与」

#### 結果への記録
- `granted_skills` 配列に付与されたスキル名を記録
- CSV出力・統計計算に活用

### 実装詳細

#### 1. バトル実行ループ
```gdscript
func execute_all_battles(config: BattleTestConfig) -> Array[BattleTestResult]:
	var results: Array[BattleTestResult] = []
	var battle_id = 0
	
	# 攻撃クリーチャーごと
	for att_creature_id in config.attacker_creatures:
		# 防御クリーチャーごと
		for def_creature_id in config.defender_creatures:
			# 攻撃アイテムごと（なしも含む）
			for att_item_id in config.attacker_items:
				# 防御アイテムごと（なしも含む）
				for def_item_id in config.defender_items:
					battle_id += 1
					
					var result = _execute_single_battle(
						battle_id,
						att_creature_id, att_item_id, config.attacker_spell,
						def_creature_id, def_item_id, config.defender_spell,
						config
					)
					
					results.append(result)
	
	return results
```

#### 2. BattleParticipant作成（重要）
```gdscript
# design.md と skills_design.md の仕様に従う
func _create_participant(
	creature_id: int,
	item_id: int,
	spell_id: int,
	owned_lands: Dictionary,
	battle_land: String,
	has_adjacent: bool
) -> BattleParticipant:
	
	# 1. カードデータ取得
	var card_data = CardLoader.get_card_by_id(creature_id)
	
	# 2. BattleParticipant作成
	var participant = BattleParticipant.new()
	participant.creature_name = card_data.name
	participant.base_ap = card_data.ap
	participant.base_hp = card_data.hp
	participant.current_hp = card_data.hp
	participant.element = card_data.element
	participant.ability_parsed = card_data.ability_parsed
	
	# 3. アイテム効果適用
	if item_id != -1:
		_apply_item_effects(participant, item_id)
	
	# 4. スペル効果適用
	if spell_id != -1:
		_apply_spell_effects(participant, spell_id)
	
	# 5. 土地保有数に応じたスキル適用
	# skills_design.mdの「感応」「土地数×N」スキルを参照
	_apply_land_count_skills(participant, owned_lands)
	
	# 6. バトル土地属性に応じたスキル適用
	# 感応スキル等、battle_landで発動するスキル
	_apply_battle_land_skills(participant, battle_land)
	
	# 7. 隣接条件スキル適用
	# skills_design.mdの「隣接判定」を参照
	if has_adjacent:
		_apply_adjacent_skills(participant)
	
	return participant
```

#### 3. 土地条件の適用
```gdscript
# skills_design.mdの「感応」スキルを参照
func _apply_battle_land_skills(participant: BattleParticipant, land_element: String):
	if not participant.ability_parsed:
		return
	
	# 感応スキルの処理
	if participant.ability_parsed.has("keywords"):
		if "感応" in participant.ability_parsed.keywords:
			var affinity_element = participant.ability_parsed.keyword_conditions.感応.element
			if affinity_element == land_element:
				var bonus = participant.ability_parsed.keyword_conditions.感応.stat_bonus
				participant.ap += bonus.get("ap", 0)
				participant.current_hp += bonus.get("hp", 0)
				participant.base_hp += bonus.get("hp", 0)

# 土地保有数に応じたスキル
# 例: "火地配置数×10" のようなスキル
func _apply_land_count_skills(participant: BattleParticipant, lands: Dictionary):
	if not participant.ability_parsed or not participant.ability_parsed.has("effects"):
		return
	
	for effect in participant.ability_parsed.effects:
		if effect.has("land_count_multiplier"):
			var element1 = effect.get("element1", "")
			var element2 = effect.get("element2", "")
			var multiplier = effect.get("multiplier", 0)
			
			var count = lands.get(element1, 0) + lands.get(element2, 0)
			participant.ap += count * multiplier
```

#### 4. 既存BattleSystemとの統合
```gdscript
func _execute_single_battle(
	battle_id: int,
	att_creature_id: int, att_item_id: int, att_spell_id: int,
	def_creature_id: int, def_item_id: int, def_spell_id: int,
	config: BattleTestConfig
) -> BattleTestResult:
	
	# BattleParticipant作成
	var attacker = _create_participant(
		att_creature_id, att_item_id, att_spell_id,
		config.attacker_owned_lands,
		config.attacker_battle_land,
		config.attacker_has_adjacent
	)
	
	var defender = _create_participant(
		def_creature_id, def_item_id, def_spell_id,
		config.defender_owned_lands,
		config.defender_battle_land,
		config.defender_has_adjacent
	)
	
	# 既存のBattleSystemで判定
	# design.mdの「バトルシステム」セクションを参照
	var battle_system = BattleSystem.new()
	var battle_result = battle_system.determine_battle_result_with_priority(
		attacker, 
		defender
	)
	
	# 結果を記録
	var test_result = BattleTestResult.new()
	test_result.battle_id = battle_id
	test_result.attacker_name = attacker.creature_name
	test_result.defender_name = defender.creature_name
	test_result.winner = battle_result.winner
	test_result.attacker_final_ap = attacker.ap
	test_result.attacker_final_hp = attacker.current_hp
	test_result.defender_final_ap = defender.ap
	test_result.defender_final_hp = defender.current_hp
	
	# 発動したスキルを記録
	test_result.attacker_skills_triggered = _extract_triggered_skills(attacker)
	test_result.defender_skills_triggered = _extract_triggered_skills(defender)
	
	return test_result
```

### 完了条件
- [ ] 全バトルが正しく実行される
- [ ] BattleSystemとの連携が正常
- [ ] 土地条件・スキルが正しく適用（design.md/skills_design.mdの仕様通り）
- [ ] プログレスバーが正しく更新
- [ ] 実行時間が10分以内

---

## 📅 Phase 5: 結果表示実装 ⏳ 未着手

**見積もり時間**: 1.5時間  
**ステータス**: ⏳ 未着手

### タスク一覧
- [ ] `result_table_view.gd` 実装（テーブル表示）
- [ ] `result_detail_view.gd` 実装（詳細表示）
- [ ] `result_statistics_view.gd` 実装（統計サマリー）
- [ ] フィルター機能実装
- [ ] ソート機能実装
- [ ] ページネーション実装
- [ ] CSV出力機能実装

### 実装ファイル
```
scripts/battle_test/
├── result_table_view.gd        # テーブル表示
├── result_detail_view.gd       # 詳細ウィンドウ
└── result_statistics_view.gd   # 統計サマリー
```

### 表示機能要件

#### テーブル表示
```
┌────┬──────────┬──────────┬─────┬────┬─────┬────────┐
│ ID │ 攻撃側    │ 防御側    │ 勝者 │残HP│ AP  │スキル   │
├────┼──────────┼──────────┼─────┼────┼─────┼────────┤
│ 1  │ アモン    │フェニックス│ 攻  │ 25 │ 50  │先制,強打│
│    │+ロングソード│+なし    │     │  0 │ 40  │        │
└────┴──────────┴──────────┴─────┴────┴─────┴────────┘
```
- 20件/ページ
- カラム: ID, 攻撃側, 防御側, 勝者, 残HP, AP, スキル
- 行クリックで詳細表示
- 色分け（勝者別）

#### 詳細表示
- ポップアップウィンドウ
- バトル条件詳細
- スキル発動詳細
- ダメージ計算詳細

#### 統計サマリー
```
総バトル数: 4,000
実行時間: 42秒

勝率:
├─ 攻撃側勝利: 2,450 (61.3%)
└─ 防御側勝利: 1,550 (38.8%)

Top 5 勝率 (攻撃側として):
1. ティアマト: 95.0% (380勝/400戦)
2. アモン: 87.5% (350勝/400戦)
...
```

#### CSV出力
```csv
battle_id,attacker_name,attacker_item,attacker_spell,defender_name,defender_item,defender_spell,winner,attacker_final_ap,attacker_final_hp,defender_final_ap,defender_final_hp,skills_triggered,battle_land,attacker_owned_lands,defender_owned_lands
```

### 完了条件
- [ ] テーブル表示が正しく動作
- [ ] フィルター・ソートが動作
- [ ] 詳細表示が正しく表示
- [ ] 統計が正しく計算・表示
- [ ] CSV出力が正しく動作

---

## 📅 Phase 6: テスト・デバッグ ⏳ 未着手

**見積もり時間**: 1時間  
**ステータス**: ⏳ 未着手

### タスク一覧
- [ ] 単体テスト（各クラス）
- [ ] 統合テスト（全体フロー）
- [ ] パフォーマンステスト
- [ ] UI操作テスト
- [ ] バグ修正
- [ ] 最終調整

### テストケース

#### 1. 基本動作
- [ ] ID入力で名前表示
- [ ] プリセット選択
- [ ] バトル実行
- [ ] 結果表示

#### 2. スキル動作確認（重要）
**skills_design.mdの仕様通りに動作するか確認：**
- [ ] 感応スキルが正しく発動（土地属性一致時）
- [ ] 先制攻撃が正しく動作
- [ ] 強打スキルが正しく発動（条件満たす時）
- [ ] 無効化スキルが正しく動作
- [ ] 貫通スキルが正しく動作
- [ ] 土地数×Nスキルが正しく計算

#### 2-1. スキル付与機能の確認 ★追加
**アイテム・スペルによるスキル付与が正しく動作するか確認：**
- [ ] アイテムで先制攻撃が付与される
- [ ] アイテムで後手が付与される
- [ ] アイテムで強打が付与される
- [ ] 条件付き付与が正しく動作（user_element等）
- [ ] 条件不一致時はスキルが付与されない
- [ ] 付与されたスキルが`granted_skills`に記録される
- [ ] CSV出力に付与スキル情報が含まれる
- [ ] 統計サマリーに付与スキル統計が表示される
- [ ] テーブル表示に付与スキル列が表示される

#### 3. エッジケース
- [ ] 存在しないID入力
- [ ] "なし"入力
- [ ] 土地数0の場合
- [ ] 全スキルOFFの場合

#### 4. パフォーマンス
- [ ] 40,000バトルが10分以内
- [ ] メモリ使用量が50MB以内
- [ ] UI応答性維持

### 完了条件
- [ ] すべてのテストケースが通過
- [ ] 既知のバグがすべて修正
- [ ] パフォーマンス要件を満たす
- [ ] ドキュメント完成

---

## 🐛 既知の問題

現在なし（Phase 1完了時点）

---

## 📝 今後の拡張案

### 優先度: 低
- [ ] グラフ表示（勝率チャート等）
- [ ] バトルアニメーション再生
- [ ] JSON出力対応
- [ ] プリセットのカスタム保存
- [ ] フィルター条件の保存
- [ ] 比較モード（2つのテスト結果を比較）

---

## 📊 リソース管理

### ファイル数
- スクリプト: 10ファイル
- シーン: 1ファイル
- 合計: 11ファイル

### コード量見積もり
- データ構造: 約200行
- UI: 約500行
- バトルロジック: 約300行
- 結果表示: 約400行
- 合計: 約1,400行

### メモリ使用量
- バトル結果データ: 約10MB
- UI: 約2MB
- 合計: 約12MB

---

## 📚 関連ドキュメント

### 必読設計書
- **[design.md](../design/design.md)** - システム全体の設計
- **[skills_design.md](../design/skills_design.md)** - スキルシステムの詳細仕様
- **[battle_test_tool_design.md](../design/battle_test_tool_design.md)** - テストツールの設計書 ★追加
- **[battle_test_tool_spec.md](../specs/battle_test_tool_spec.md)** - テストツールの機能仕様書 ★追加
- [プロジェクト概要](../../README.md)

### 参考メモリ
- spell_and_item_implementation_details（スペル・アイテムの実装状況）
- project_overview（プロジェクト全体像）

---

## 📅 更新履歴

| 日付 | 内容 | 担当 |
|------|------|------|
| 2025/10/18 | 初版作成・Phase 1完了 | AI |

---

**最終更新**: 2025年10月18日  
**次回更新予定**: Phase 2完了時

---

## 🆕 スキル付与機能の追加 (2025/10/18)

### 追加内容
Phase 4のバトルロジック統合に、**アイテム・スペルによるスキル付与機能**を追加しました。

#### 主要な変更点
1. **設計書・仕様書の作成**
   - `battle_test_tool_design.md` に「スキル付与システム」セクション追加
   - `battle_test_tool_spec.md` に「スキル付与機能」セクション追加

2. **実装対象スキル（現在）**
   - 先制攻撃（アイテムで付与）
   - 後手（アイテムで付与）
   - 強打（アイテムで付与）

3. **既存システムの活用**
   - `BattleSystem._apply_item_effects()` - アイテム効果適用
   - `BattleSystem._grant_skill_to_participant()` - スキル付与
   - `BattleSystem._check_skill_grant_condition()` - 条件判定

4. **結果データへの追加**
   - `BattleTestResult.attacker_granted_skills` - 付与されたスキル記録
   - `BattleTestResult.defender_granted_skills` - 付与されたスキル記録

#### Phase 4への影響
- タスクに「アイテムによるスキル付与ロジック」を追加
- タスクに「スペルによるスキル付与ロジック（将来実装）」を追加
- 完了条件に「スキル付与が正しく動作」を追加

#### Phase 5への影響
- テーブル表示に「付与スキル」カラムを追加
- 詳細表示に「付与スキルの詳細」を追加
- 統計サマリーに「スキル付与統計」を追加
- CSV出力に「granted_skills」カラムを追加

#### Phase 6への影響
- テストケースに「スキル付与機能のテスト」を追加
- 条件付き付与のテスト（user_element等）を追加
