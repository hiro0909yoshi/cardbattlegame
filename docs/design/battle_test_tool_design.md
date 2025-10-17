# バトルテストツール設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月18日  
**ステータス**: 初版・レビュー待ち

---

## ⚠️ 重要な注意事項

**この設計書は新規作成されたものです。実装を進める中で誤りや不整合が見つかる可能性があります。**

実装時に以下の点に注意してください：
1. **既存設計書との整合性を確認**
   - [design.md](design.md) - バトルシステムの仕様
   - [skills_design.md](skills_design.md) - スキルシステムの仕様
2. **実装中に不整合を発見した場合**
   - このドキュメントを更新してください
   - 更新履歴に記録してください
3. **疑問点があれば**
   - 既存の実装コードを優先してください
   - design.md、skills_design.mdの仕様を優先してください

---

## 📋 目次

1. [概要](#概要)
2. [システムアーキテクチャ](#システムアーキテクチャ)
3. [データ構造設計](#データ構造設計)
4. [UI設計](#ui設計)
5. [バトルロジック設計](#バトルロジック設計)
6. [スキル付与システム](#スキル付与システム)
7. [結果表示設計](#結果表示設計)
8. [技術仕様](#技術仕様)
9. [制約事項](#制約事項)
10. [更新履歴](#更新履歴)

---

## 概要

### 目的
スペル・アイテム・スキルの効果を網羅的にテストし、バランス調整・バグ検出を行うツール。

### スコープ
```
10クリーチャー × 10クリーチャー × 20アイテム × 20アイテム × 1スペル
= 40,000 バトル
実行時間: 約6-7分
メモリ使用量: 約10MB
```

### 主要機能
1. ID入力式の選択UI
2. プリセット機能
3. 土地条件・隣接条件の設定
4. バトル実行・結果記録
5. 統計分析・CSV出力

---

## システムアーキテクチャ

### 全体構成図
```
┌─────────────────────────────────────────────────────┐
│          BattleTestTool (シーン)                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────┐  ┌──────────────────┐         │
│  │  ConfigPanel    │  │ IDReferencePanel │         │
│  │  (設定UI)       │  │  (折りたたみ)     │         │
│  └────────┬────────┘  └──────────────────┘         │
│           │                                         │
│           ▼                                         │
│  ┌─────────────────┐                               │
│  │ BattleTestUI    │                               │
│  │ (コントローラー)  │                               │
│  └────────┬────────┘                               │
│           │                                         │
│           ▼                                         │
│  ┌─────────────────┐                               │
│  │BattleTestExecutor│◄────┐                        │
│  │(実行エンジン)     │     │                        │
│  └────────┬────────┘     │                        │
│           │              │                        │
│           ▼              │                        │
│  ┌─────────────────┐    │                        │
│  │  BattleSystem   │    │ 既存システム           │
│  │  (既存)         │    │                        │
│  └─────────────────┘    │                        │
│                         │                        │
│  ┌─────────────────┐    │                        │
│  │  SkillSystem    │◄───┤                        │
│  │  (既存)         │    │                        │
│  └─────────────────┘    │                        │
│                         │                        │
│  ┌─────────────────┐    │                        │
│  │  CardLoader     │◄───┘                        │
│  │  (既存)         │                             │
│  └─────────────────┘                             │
│                                                     │
│  ┌─────────────────────────────────────┐           │
│  │         ResultPanel                  │           │
│  ├─────────────────────────────────────┤           │
│  │  ├─ StatisticsView (統計サマリー)    │           │
│  │  ├─ TableView (テーブル表示)         │           │
│  │  └─ DetailView (詳細表示)            │           │
│  └─────────────────────────────────────┘           │
└─────────────────────────────────────────────────────┘
```

### クラス依存関係図
```
BattleTestUI
  │
  ├─► BattleTestConfig (データ)
  │
  ├─► BattleTestExecutor
  │     │
  │     ├─► BattleTestConfig (入力)
  │     │
  │     ├─► BattleSystem (既存)
  │     │     ├─► BattleParticipant
  │     │     ├─► _apply_item_effects()
  │     │     ├─► _grant_skill_to_participant()
  │     │     └─► _check_skill_grant_condition()
  │     │
  │     ├─► SkillSystem (既存)
  │     │     ├─► ConditionChecker
  │     │     └─► EffectCombat
  │     │
  │     ├─► SpellPhaseHandler (既存)
  │     │     ├─► execute_spell_effect()
  │     │     └─► _apply_single_effect()
  │     │
  │     ├─► CardLoader (既存)
  │     │
  │     └─► BattleTestResult[] (出力)
  │
  └─► ResultViews
		├─► BattleTestResult[] (入力)
		└─► BattleTestStatistics
```

### データフロー
```
[1. 設定入力]
  ユーザー入力
	↓
  IDInputField → BattleTestConfig
	↓
[2. プリセット適用]
  TestPresets → BattleTestConfig
	↓
[3. バトル実行]
  BattleTestExecutor.execute_all_battles()
	├─ ループ: クリーチャー × アイテム × スペル
	│   ↓
	├─ _create_participant()
	│   ├─ CardLoader.get_card_by_id()
	│   ├─ _apply_item_effects() ★アイテム効果適用
	│   │   └─ _grant_skill_to_participant() ★スキル付与
	│   ├─ _apply_spell_effects() ★スペル効果適用
	│   ├─ _apply_land_count_skills()
	│   ├─ _apply_battle_land_skills()
	│   └─ _apply_adjacent_skills()
	│   ↓
	├─ BattleSystem.determine_battle_result_with_priority()
	│   ↓
	└─ BattleTestResult[] (結果配列)
	↓
[4. 統計計算]
  BattleTestStatistics.calculate()
	↓
[5. 結果表示]
  ResultViews.display()
	├─ StatisticsView
	├─ TableView
	└─ DetailView
	↓
[6. CSV出力（オプション）]
  CSVExporter.export()
```

---

## データ構造設計

### BattleTestConfig
```gdscript
# scripts/battle_test/battle_test_config.gd
class_name BattleTestConfig
extends RefCounted

# 攻撃側設定
var attacker_creatures: Array[int] = []      # クリーチャーID配列
var attacker_items: Array[int] = []          # アイテムID配列（1つずつテスト）
var attacker_spell: int = -1                 # スペルID (-1 = なし)
var attacker_owned_lands: Dictionary = {     # 保有土地数
	"fire": 0,
	"water": 0,
	"earth": 0,
	"wind": 0
}
var attacker_battle_land: String = "fire"    # バトル発生土地の属性
var attacker_has_adjacent: bool = false      # 隣接味方領地あり

# 防御側設定
var defender_creatures: Array[int] = []
var defender_items: Array[int] = []
var defender_spell: int = -1
var defender_owned_lands: Dictionary = {
	"fire": 0,
	"water": 0,
	"earth": 0,
	"wind": 0
}
var defender_battle_land: String = "fire"
var defender_has_adjacent: bool = false

# バリデーション
func validate() -> bool:
	if attacker_creatures.is_empty():
		push_error("攻撃側クリーチャーが未選択")
		return false
	if defender_creatures.is_empty():
		push_error("防御側クリーチャーが未選択")
		return false
	return true

# 設定の入れ替え
func swap_attacker_defender():
	var temp_creatures = attacker_creatures
	attacker_creatures = defender_creatures
	defender_creatures = temp_creatures
	
	var temp_items = attacker_items
	attacker_items = defender_items
	defender_items = temp_items
	
	# その他の設定も入れ替え
	var temp_spell = attacker_spell
	attacker_spell = defender_spell
	defender_spell = temp_spell
	
	var temp_lands = attacker_owned_lands.duplicate()
	attacker_owned_lands = defender_owned_lands.duplicate()
	defender_owned_lands = temp_lands
	
	var temp_battle_land = attacker_battle_land
	attacker_battle_land = defender_battle_land
	defender_battle_land = temp_battle_land
	
	var temp_adjacent = attacker_has_adjacent
	attacker_has_adjacent = defender_has_adjacent
	defender_has_adjacent = temp_adjacent
```

### BattleTestResult
```gdscript
# scripts/battle_test/battle_test_result.gd
class_name BattleTestResult
extends RefCounted

# 基本情報
var battle_id: int

# 攻撃側情報
var attacker_id: int
var attacker_name: String
var attacker_item_id: int
var attacker_item_name: String
var attacker_spell_id: int
var attacker_spell_name: String
var attacker_base_ap: int                    # 基礎AP
var attacker_base_hp: int                    # 基礎HP
var attacker_final_ap: int                   # 最終AP（スキル適用後）
var attacker_final_hp: int                   # 残HP
var attacker_skills_triggered: Array[String] # 発動したスキル
var attacker_granted_skills: Array[String]   # アイテム・スペルで付与されたスキル ★追加

# 防御側情報
var defender_id: int
var defender_name: String
var defender_item_id: int
var defender_item_name: String
var defender_spell_id: int
var defender_spell_name: String
var defender_base_ap: int
var defender_base_hp: int
var defender_final_ap: int
var defender_final_hp: int
var defender_skills_triggered: Array[String]
var defender_granted_skills: Array[String]   # アイテム・スペルで付与されたスキル ★追加

# バトル結果
var winner: String  # "attacker" or "defender"
var battle_duration_ms: int  # バトル実行時間（ミリ秒）

# バトル条件
var battle_land: String
var attacker_owned_lands: Dictionary
var defender_owned_lands: Dictionary
var attacker_has_adjacent: bool
var defender_has_adjacent: bool

# ダメージ詳細
var damage_dealt_by_attacker: int
var damage_dealt_by_defender: int
var first_strike_occurred: bool  # 先制攻撃が発生したか

# CSV/JSON出力用
func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"attacker_name": attacker_name,
		"attacker_item": attacker_item_name,
		"attacker_spell": attacker_spell_name,
		"attacker_base_ap": attacker_base_ap,
		"attacker_final_ap": attacker_final_ap,
		"attacker_final_hp": attacker_final_hp,
		"attacker_skills": ",".join(attacker_skills_triggered),
		"attacker_granted_skills": ",".join(attacker_granted_skills),  # ★追加
		"defender_name": defender_name,
		"defender_item": defender_item_name,
		"defender_spell": defender_spell_name,
		"defender_base_ap": defender_base_ap,
		"defender_final_ap": defender_final_ap,
		"defender_final_hp": defender_final_hp,
		"defender_skills": ",".join(defender_skills_triggered),
		"defender_granted_skills": ",".join(defender_granted_skills),  # ★追加
		"winner": winner,
		"damage_attacker": damage_dealt_by_attacker,
		"damage_defender": damage_dealt_by_defender,
		"battle_land": battle_land,
	}

# デバッグ用文字列
func to_string() -> String:
	return "[%d] %s vs %s → 勝者: %s" % [
		battle_id,
		attacker_name,
		defender_name,
		winner
	]
```

### BattleTestStatistics
```gdscript
# scripts/battle_test/battle_test_statistics.gd
class_name BattleTestStatistics
extends RefCounted

var total_battles: int = 0
var attacker_wins: int = 0
var defender_wins: int = 0
var total_duration_ms: int = 0

# クリーチャー別統計
# { "クリーチャー名": { "wins": int, "total": int, "win_rate": float } }
var creature_stats: Dictionary = {}

# アイテム別統計
# { "アイテム名": { "wins": int, "total": int, "win_rate": float } }
var item_stats: Dictionary = {}

# スキル発動統計
# { "スキル名": { "triggered": int, "total_possible": int, "rate": float } }
var skill_stats: Dictionary = {}

# スキル付与統計 ★追加
# { "スキル名": { "granted": int, "from_item": int, "from_spell": int } }
var skill_grant_stats: Dictionary = {}

# 統計計算
static func calculate(results: Array[BattleTestResult]) -> BattleTestStatistics:
	var stats = BattleTestStatistics.new()
	stats.total_battles = results.size()
	
	for result in results:
		# 勝敗集計
		if result.winner == "attacker":
			stats.attacker_wins += 1
		else:
			stats.defender_wins += 1
		
		# 実行時間集計
		stats.total_duration_ms += result.battle_duration_ms
		
		# クリーチャー統計更新
		_update_creature_stats(stats.creature_stats, result)
		
		# アイテム統計更新
		_update_item_stats(stats.item_stats, result)
		
		# スキル統計更新
		_update_skill_stats(stats.skill_stats, result)
		
		# スキル付与統計更新 ★追加
		_update_skill_grant_stats(stats.skill_grant_stats, result)
	
	# 勝率計算
	_calculate_win_rates(stats)
	
	return stats

static func _update_creature_stats(creature_stats: Dictionary, result: BattleTestResult):
	# 攻撃側
	if not creature_stats.has(result.attacker_name):
		creature_stats[result.attacker_name] = {"wins": 0, "total": 0}
	creature_stats[result.attacker_name].total += 1
	if result.winner == "attacker":
		creature_stats[result.attacker_name].wins += 1
	
	# 防御側
	if not creature_stats.has(result.defender_name):
		creature_stats[result.defender_name] = {"wins": 0, "total": 0}
	creature_stats[result.defender_name].total += 1
	if result.winner == "defender":
		creature_stats[result.defender_name].wins += 1

static func _update_item_stats(item_stats: Dictionary, result: BattleTestResult):
	# アイテム統計（実装予定）
	pass

static func _update_skill_stats(skill_stats: Dictionary, result: BattleTestResult):
	# スキル統計（実装予定）
	pass

# ★追加：スキル付与統計
static func _update_skill_grant_stats(skill_grant_stats: Dictionary, result: BattleTestResult):
	# 攻撃側の付与スキルを集計
	for skill in result.attacker_granted_skills:
		if not skill_grant_stats.has(skill):
			skill_grant_stats[skill] = {"granted": 0, "from_item": 0, "from_spell": 0}
		skill_grant_stats[skill].granted += 1
		# アイテムかスペルかを判定して加算
		if result.attacker_item_id > 0:
			skill_grant_stats[skill].from_item += 1
		if result.attacker_spell_id > 0:
			skill_grant_stats[skill].from_spell += 1
	
	# 防御側も同様に集計
	for skill in result.defender_granted_skills:
		if not skill_grant_stats.has(skill):
			skill_grant_stats[skill] = {"granted": 0, "from_item": 0, "from_spell": 0}
		skill_grant_stats[skill].granted += 1
		if result.defender_item_id > 0:
			skill_grant_stats[skill].from_item += 1
		if result.defender_spell_id > 0:
			skill_grant_stats[skill].from_spell += 1

static func _calculate_win_rates(stats: BattleTestStatistics):
	# 勝率計算
	for creature_name in stats.creature_stats:
		var data = stats.creature_stats[creature_name]
		data["win_rate"] = float(data.wins) / float(data.total) * 100.0
```

### TestPresets
```gdscript
# scripts/battle_test/test_presets.gd
class_name BattleTestPresets
extends RefCounted

# クリーチャープリセット
static var CREATURE_PRESETS = {
	"火属性": [2, 4, 7, 9, 15, 16, 19],
	"水属性": [101, 104, 108, 113, 116, 120],
	"風属性": [300, 303, 307, 309, 315, 320],
	"地属性": [201, 205, 210, 215, 220],
	"先制攻撃持ち": [7, 303, 405],
	"強打持ち": [4, 9, 19],
	"無効化持ち": [1, 6, 11, 16, 112, 325, 413],
}

# アイテムプリセット
static var ITEM_PRESETS = {
	"武器系": [],  # 手動追加予定
	"防具系": [],
	"アクセサリ系": [],
	"巻物系": [],
}

# スペルプリセット
static var SPELL_PRESETS = {
	"攻撃系": [],  # 手動追加予定
	"防御系": [],
}

static func get_creature_preset(name: String) -> Array[int]:
	return CREATURE_PRESETS.get(name, [])

static func get_item_preset(name: String) -> Array[int]:
	return ITEM_PRESETS.get(name, [])

static func get_spell_preset(name: String) -> Array[int]:
	return SPELL_PRESETS.get(name, [])

static func get_all_creature_preset_names() -> Array[String]:
	var names: Array[String] = []
	for key in CREATURE_PRESETS.keys():
		names.append(key)
	return names
```

---

## UI設計

### 画面構成
```
┌─────────────────────────────────────────────────────────────┐
│  バトルテストツール                                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─ 攻撃側設定 ────────────────────────────────────────────┐ │
│ │                                                          │ │
│ │ ▼ クリーチャー                                           │ │
│ │   ID入力: [___] [___] [___] [___] [___]                 │ │
│ │           [___] [___] [___] [___] [___]                 │ │
│ │   → (名前表示エリア)                                      │ │
│ │   プリセット: [火属性 ▼]                                  │ │
│ │                                                          │ │
│ │ ▼ アイテム                                               │ │
│ │   ID入力: [___] [___] [___] ...                          │ │
│ │   → (名前表示エリア)                                      │ │
│ │                                                          │ │
│ │ ▼ スペル                                                 │ │
│ │   ID入力: [___]  → (名前表示)                            │ │
│ │                                                          │ │
│ │ ▼ 保有土地数                                             │ │
│ │   🔥火: [スライダー 0-10]  💧水: [スライダー]            │ │
│ │   🌱地: [スライダー]       💨風: [スライダー]            │ │
│ │                                                          │ │
│ │ ▼ バトル発生土地                                         │ │
│ │   ◉ 🔥火  ○ 💧水  ○ 🌱地  ○ 💨風  ○ 中立             │ │
│ │                                                          │ │
│ │ ▼ 配置条件                                               │ │
│ │   ☑ 隣接味方領地あり                                      │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─ 防御側設定 ────────────────────────────────────────────┐ │
│ │ (同様のレイアウト)                                       │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                             │
│         [攻撃⇔防御入れ替え]  [テスト実行]                    │
│                                                             │
│ ┌─ ID参照表 [▼展開/▲折りたたみ] ─────────────────────┐   │
│ │ 検索: [___________]                                    │ │
│ │ [クリーチャー] [アイテム] [スペル]                      │ │
│ │ ┌────────────────────────────────────────┐            │ │
│ │ │ ID  | 名前        | AP | HP | 属性     │            │ │
│ │ │ 1   | アモン      | 30 | 30 | 火       │            │ │
│ │ │ 2   | ...                               │            │ │
│ │ └────────────────────────────────────────┘            │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─ 実行状況 ──────────────────────────────────────────┐   │
│ │ 進行状況: ■■■■■□□□□□ 45% (1,800/4,000)            │ │
│ │ 経過時間: 3分12秒                                      │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─ 結果表示 [統計][テーブル][詳細] ──────────────────────┐ │
│ │ (タブで切り替え)                                       │ │
│ │                                                        │ │
│ │ [CSV出力] [フィルター] [ソート]                        │ │
│ └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### UIコンポーネント一覧

| コンポーネント | ファイル | 責務 |
|--------------|---------|------|
| BattleTestUI | battle_test_ui.gd | メインコントローラー |
| IDInputField | id_input_field.gd | ID入力・名前表示 |
| IDReferencePanel | id_reference_panel.gd | ID参照表 |
| ResultTableView | result_table_view.gd | テーブル表示 |
| ResultDetailView | result_detail_view.gd | 詳細表示 |
| ResultStatisticsView | result_statistics_view.gd | 統計サマリー |

---

## バトルロジック設計

### 既存システムとの統合

**重要**: 既存の`BattleSystem`, `SkillSystem`, `SpellPhaseHandler`を活用し、車輪の再発明をしない。

#### 参照する既存システム
1. **BattleSystem** ([design.md](design.md)参照)
   - `determine_battle_result_with_priority()` を使用
   - `_apply_item_effects()` でアイテム効果適用 ★
   - `_grant_skill_to_participant()` でスキル付与 ★
   - `_check_skill_grant_condition()` で条件判定 ★
   - 先制攻撃判定
   - ダメージ計算

2. **SkillSystem** ([skills_design.md](skills_design.md)参照)
   - `ConditionChecker` で条件判定
   - `EffectCombat` で効果適用
   - ability_parsedの解析

3. **SpellPhaseHandler** (既存実装)
   - `execute_spell_effect()` でスペル効果実行 ★
   - `_apply_single_effect()` で個別効果適用 ★

4. **CardLoader** (既存Autoload)
   - カードデータ取得

### BattleParticipant作成フロー
```
_create_participant(creature_id, item_id, spell_id, config)
  │
  ├─ 1. CardLoader.get_card_by_id(creature_id)
  │    └─ カードデータ取得
  │
  ├─ 2. BattleParticipant.new()
  │    ├─ 基本ステータス設定
  │    │   ├─ base_ap = card_data.ap
  │    │   ├─ base_hp = card_data.hp
  │    │   ├─ current_hp = card_data.hp
  │    │   └─ ability_parsed = card_data.ability_parsed
  │    │
  │    └─ 先制攻撃判定
  │        └─ has_first_strike = "先制" in keywords
  │
  ├─ 3. _apply_item_effects(participant, item_id) ★重要
  │    ├─ アイテムによるAP/HP修正
  │    │   └─ stat_bonus effectを適用
  │    │
  │    └─ アイテムによるスキル付与 ★追加機能
  │        ├─ grant_skill effectを検出
  │        ├─ _check_skill_grant_condition()で条件確認
  │        │   └─ user_element等の条件判定
  │        │
  │        └─ _grant_skill_to_participant()でスキル付与
  │            ├─ "先制攻撃" → has_item_first_strike = true
  │            ├─ "後手" → has_last_strike = true
  │            ├─ "強打" → has_power_strike = true
  │            └─ 今後追加されるスキルにも対応
  │
  ├─ 4. _apply_spell_effects(participant, spell_id) ★重要
  │    ├─ SpellPhaseHandler.execute_spell_effect()を参考
  │    ├─ スペルによるステータス修正
  │    │   ├─ damage effect
  │    │   ├─ drain_magic effect
  │    │   └─ stat_bonus effect
  │    │
  │    └─ スペルによるスキル付与 ★追加機能（将来実装）
  │        └─ アイテムと同様のロジック
  │
  ├─ 5. _apply_land_count_skills(participant, owned_lands)
  │    └─ 「火地×10」等のスキル適用
  │        └─ ability_parsedを解析
  │
  ├─ 6. _apply_battle_land_skills(participant, battle_land)
  │    └─ 「感応[地]」等、土地属性で発動するスキル
  │        └─ skills_design.mdの仕様に従う
  │
  └─ 7. _apply_adjacent_skills(participant)
	   └─ 隣接条件で発動するスキル
		   └─ has_adjacent = true の場合のみ
```

---

## スキル付与システム

### 概要

アイテムやスペルによってクリーチャーに**スキルを付与**する機能。  
既存の `BattleSystem` のロジックを活用し、テストツールでも同じ挙動を再現する。

### 既存実装の確認

以下の既存メソッドを使用：

1. **`BattleSystem._apply_item_effects(participant, item_data)`**
   - 場所: `scripts/battle_system.gd` (L275-323)
   - 役割: アイテムの全効果を適用
   - 内部で `_grant_skill_to_participant()` を呼び出し

2. **`BattleSystem._grant_skill_to_participant(participant, skill_name)`**
   - 場所: `scripts/battle_system.gd` (L341-375)
   - 役割: 特定のスキルをParticipantに付与
   - 対応スキル：
	 - `"先制攻撃"` → `has_item_first_strike = true` + `has_last_strike = false`
	 - `"後手"` → `has_last_strike = true` + `has_item_first_strike = false`
	 - `"強打"` → `has_power_strike = true`
	 - **今後のスキル追加にも対応可能**

3. **`BattleSystem._check_skill_grant_condition(participant, conditions)`**
   - 場所: `scripts/battle_system.gd` (L326-338)
   - 役割: スキル付与条件の判定
   - 現在対応: `user_element` (クリーチャー属性による条件)

### スキル付与の実装例

```gdscript
# テストツール内での実装例
func _apply_item_effects(participant: BattleParticipant, item_id: int):
	if item_id <= 0:
		return  # アイテムなし
	
	var item_data = CardLoader.get_card_by_id(item_id)
	if not item_data:
		push_error("アイテムID %d が見つかりません" % item_id)
		return
	
	# 既存のBattleSystemのロジックを使用
	var battle_system = BattleSystem.new()
	battle_system._apply_item_effects(participant, item_data)
	
	# 付与されたスキルを記録
	_record_granted_skills(participant, item_data)

func _record_granted_skills(participant: BattleParticipant, item_data: Dictionary):
	"""付与されたスキルを記録する"""
	if not item_data.has("ability_parsed"):
		return
	
	var ability = item_data.ability_parsed
	if not ability.has("effects"):
		return
	
	for effect in ability.effects:
		if effect.get("effect_type") == "grant_skill":
			var skill_name = effect.get("skill_name", "")
			if skill_name != "":
				# BattleTestResultに記録するため配列に追加
				if not participant.has("granted_skills"):
					participant.granted_skills = []
				participant.granted_skills.append(skill_name)
```

### スキル付与のフロー図

```
アイテムデータ取得
	↓
ability_parsed.effects をループ
	↓
effect_type == "grant_skill" ?
	├─ Yes → 条件確認
	│         ├─ conditions があるか？
	│         │   ├─ Yes → _check_skill_grant_condition()
	│         │   │         ├─ 条件一致 → スキル付与
	│         │   │         └─ 条件不一致 → スキップ
	│         │   └─ No → 無条件でスキル付与
	│         │
	│         └─ _grant_skill_to_participant()
	│               ├─ "先制攻撃" → has_item_first_strike = true
	│               ├─ "後手" → has_last_strike = true
	│               ├─ "強打" → has_power_strike = true
	│               └─ 新スキル → 今後追加
	│
	└─ No → 他のeffect_typeを処理
```

### データ例

#### アイテムデータ（item.json）

```json
{
	"id": 3001,
	"name": "ロングソード",
	"type": "item",
	"cost": {"mp": 1},
	"ability_parsed": {
		"effects": [
			{
				"effect_type": "stat_bonus",
				"target_stat": "st",
				"value": 30
			}
		]
	}
}
```

```json
{
	"id": 3002,
	"name": "マグマハンマー",
	"type": "item",
	"cost": {"mp": 2},
	"ability_parsed": {
		"effects": [
			{
				"effect_type": "stat_bonus",
				"target_stat": "st",
				"value": 20
			},
			{
				"effect_type": "grant_skill",
				"skill_name": "強打",
				"conditions": {
					"user_element": "fire"
				}
			}
		]
	}
}
```

### テスト時の記録

BattleTestResultに以下を記録：

```gdscript
var attacker_granted_skills: Array[String] = ["強打", "先制攻撃"]
var defender_granted_skills: Array[String] = []
```

これにより、アイテム・スペルによってどのスキルが付与されたかを結果として確認できる。

### 今後の拡張性

新しいスキルが追加される場合：

1. **`BattleSystem._grant_skill_to_participant()` に追加**
   ```gdscript
   "貫通":
	   participant.has_penetration = true
   ```

2. **テストツールでは自動的に対応**
   - 既存メソッドを使用しているため、修正不要

3. **結果の記録も自動対応**
   - `granted_skills` 配列に自動追加

---

## 結果表示設計

### テーブル表示
```
┌────┬──────────┬──────────┬─────┬────┬─────┬────────┬──────────┐
│ ID │ 攻撃側    │ 防御側    │ 勝者 │残HP│ AP  │スキル   │付与スキル │
├────┼──────────┼──────────┼─────┼────┼─────┼────────┼──────────┤
│ 1  │ アモン    │フェニックス│ 攻  │ 25 │ 50  │先制,強打│強打(I)   │
│    │+ロングソード│+なし    │     │  0 │ 40  │        │          │
└────┴──────────┴──────────┴─────┴────┴─────┴────────┴──────────┘
```

**表記ルール**:
- 付与スキル列の `(I)` = アイテムによる付与
- 付与スキル列の `(S)` = スペルによる付与

**実装要件**:
- ItemList または TreeまたはTable を使用
- ページネーション: 20件/ページ
- ソート機能: 各カラムクリックでソート
- フィルター機能: 勝者・クリーチャー・APレンジ・付与スキル等 ★追加
- 色分け: 勝者に応じて行の背景色を変更

### 詳細表示

ポップアップウィンドウまたはサイドパネルで表示。
```
バトル詳細 #1234
───────────────────
攻撃側: アモン
  最終AP: 50 (+20)
  残HP: 25/30 (-5)
  アイテム: ロングソード
  スペル: パワーブースト
  発動スキル: ✓先制攻撃 ✓強打
  付与スキル: 強打 (アイテム: マグマハンマー) ★追加

防御側: フェニックス
  最終AP: 40
  残HP: 0/40 (-40)
  アイテム: なし
  スペル: なし
  発動スキル: なし
  付与スキル: なし ★追加

バトル条件:
  発生土地: 🔥火
  攻撃側保有: 火3 水2 地5 風1
  隣接: ☑

ダメージ詳細:
  攻撃側 → 防御側: 40ダメージ
  防御側 → 攻撃側: 5ダメージ
```

### 統計サマリー

折りたたみ式パネル。
```
📊 統計サマリー [▲非表示]
───────────────────
総バトル数: 4,000
実行時間: 6分42秒

勝率:
├─ 攻撃側勝利: 2,450 (61.3%)
└─ 防御側勝利: 1,550 (38.8%)

Top 5 勝率:
1. ティアマト: 95.0%
2. アモン: 87.5%
3. シグルド: 80.0%
...

スキル発動統計:
├─ 先制攻撃: 80.0% (800/1000)
├─ 強打: 75.0% (450/600)
└─ 無効化: 64.0% (320/500)

スキル付与統計: ★追加
├─ 強打: 450回付与 (アイテム: 400, スペル: 50)
├─ 先制攻撃: 200回付与 (アイテム: 200, スペル: 0)
└─ 後手: 150回付与 (アイテム: 150, スペル: 0)
```

---

## 技術仕様

### パフォーマンス要件

| 項目 | 目標値 | 許容値 |
|------|--------|--------|
| 総実行時間 | 6-7分 | 10分以内 |
| 1バトル実行時間 | 10ms | 15ms |
| メモリ使用量 | 10MB | 50MB |
| UI応答性 | プログレスバー更新 | フリーズなし |

### 使用するGodot機能

- **UI**: Control, VBoxContainer, HBoxContainer, LineEdit, Button, OptionButton
- **データ**: RefCounted, Dictionary, Array
- **非同期**: await, Timer (プログレスバー更新用)
- **ファイルI/O**: FileAccess (CSV出力)

### メモリ管理戦略

1. **結果データの保持**
   - BattleTestResult配列をメモリに保持
   - 40,000件 × 300バイト = 12MB（付与スキル情報追加により増加）

2. **ページネーション**
   - 表示は20件ずつ
   - 全データは保持するが、表示は部分的

3. **ガベージコレクション**
   - BattleParticipantは使い捨て
   - 各バトル終了後に解放

---

## 制約事項

### 技術的制約

1. **Godotの制限**
   - マルチスレッド非対応（メインスレッドで実行）
   - UI更新頻度の制限

2. **既存システムへの依存**
   - BattleSystem, SkillSystem, SpellPhaseHandlerに完全依存
   - これらのバグはテストツールにも影響

3. **データ制約**
   - クリーチャーIDは既存データに存在する必要
   - ability_parsedが正しく定義されている必要
   - item.jsonは事前作成が必要 ★重要

### 仕様上の制限

1. **テスト範囲**
   - 1対1のバトルのみ
   - 複数クリーチャーの同時戦闘は非対応

2. **スペル制限**
   - 1回のテストで1つのスペルのみ
   - 複数スペルの組み合わせは非対応

3. **アイテム制限**
   - クリーチャー1体につき1アイテム
   - 複数アイテムの同時装備は非対応

4. **スキル付与制限** ★追加
   - アイテム・スペルで付与できるスキルは `_grant_skill_to_participant()` で定義されたもののみ
   - 新スキル追加時は BattleSystem の更新が必要

---

## 更新履歴

| 日付 | 内容 | 更新者 |
|------|------|--------|
| 2025/10/18 | 初版作成 | AI |
| 2025/10/18 | アイテム・スペルによるスキル付与機能を追加 | AI |

---

**最終更新**: 2025年10月18日
