# バトルテストツール 技術仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月18日  
**完成日**: 2025年10月20日  
**ステータス**: 基本機能完成（スペル機能除く）

---

## 📋 目次

1. [概要](#概要)
2. [システムアーキテクチャ](#システムアーキテクチャ)
3. [データ構造](#データ構造)
4. [実装の要点](#実装の要点)
5. [制約事項](#制約事項)
6. [更新履歴](#更新履歴)

---

## 概要

### 目的
スペル・アイテム・スキルの効果を網羅的にテストし、バランス調整・バグ検出を行うツール。

### テスト規模
```
10クリーチャー × 10クリーチャー × 20アイテム × 20アイテム
= 最大 40,000 バトル
実行時間: 約6-7分
```

### 主要機能
1. ID入力式のクリーチャー・アイテム選択
2. プリセット機能（属性別・スキル別）
3. 土地条件・隣接条件の設定
4. 全組み合わせのバトル自動実行
5. 詳細な結果表示（テーブル・統計・詳細ウィンドウ）
6. 発動スキル・付与スキルの記録

---

## システムアーキテクチャ

### 全体構成
```
BattleTestUI (メインコントローラー)
  │
  ├─► BattleTestConfig (設定データ)
  │
  ├─► BattleTestExecutor (実行エンジン)
  │     │
  │     ├─► BattleSystem (既存) - バトル実行
  │     ├─► CardLoader (既存) - カードデータ取得
  │     └─► BattleTestResult[] (出力)
  │
  └─► ResultViews (結果表示)
		├─► StatisticsLabel - 統計サマリー
		├─► DetailTable - テーブル表示
		└─► DetailWindow - 詳細ウィンドウ
```

### データフロー
```
ユーザー入力
  ↓
BattleTestConfig (設定)
  ↓
BattleTestExecutor.execute_all_battles()
  ├─ ループ: クリーチャー × アイテム
  ├─ BattleParticipant作成
  │   ├─ アイテム効果適用
  │   ├─ スキル付与
  │   └─ 土地ボーナス計算
  ├─ BattleSystem.execute_battle()
  └─ BattleTestResult[] 生成
  ↓
BattleTestStatistics.calculate() (統計計算)
  ↓
結果表示 (テーブル・詳細・統計)
```

---

## データ構造

### BattleTestConfig
テスト設定を保持するクラス。

```gdscript
class_name BattleTestConfig
extends RefCounted

# 攻撃側設定
var attacker_creatures: Array = []      # クリーチャーID配列
var attacker_items: Array = []          # アイテムID配列
var attacker_owned_lands: Dictionary = {
	"fire": 0, "water": 0, "earth": 0, "wind": 0
}
var attacker_battle_land: String = "neutral"
var attacker_has_adjacent: bool = false

# 防御側も同様
var defender_creatures: Array = []
var defender_items: Array = []
var defender_owned_lands: Dictionary = {...}
var defender_battle_land: String = "neutral"
var defender_has_adjacent: bool = false
```

### BattleTestResult
個別バトルの結果を記録。

```gdscript
class_name BattleTestResult
extends RefCounted

var battle_id: int
var attacker_id: int
var attacker_name: String
var attacker_item_id: int
var attacker_final_ap: int
var attacker_final_hp: int
var attacker_skills_triggered: Array = []    # 発動したスキル
var attacker_granted_skills: Array = []      # 付与されたスキル

# 防御側も同様
var defender_id: int
var defender_name: String
...

# バトル結果
var winner: String  # "attacker" or "defender"
var battle_land: String
var attacker_owned_lands: Dictionary
var defender_owned_lands: Dictionary
```

### BattleTestStatistics
統計データを計算・保持。

```gdscript
class_name BattleTestStatistics
extends RefCounted

var total_battles: int = 0
var attacker_wins: int = 0
var defender_wins: int = 0
var total_duration_ms: int = 0

# クリーチャー別勝率
var creature_stats: Dictionary = {}

# スキル付与統計
var skill_grant_stats: Dictionary = {}
```

### TestPresets
プリセット定義。

```gdscript
class_name BattleTestPresets

static var CREATURE_PRESETS = {
	"火属性": [2, 4, 7, 9, 15, 16, 19],
	"水属性": [101, 104, 108, 113, 116, 120],
	"風属性": [300, 303, 307, 309, 315, 320],
	"地属性": [201, 205, 210, 215, 220],
	"先制攻撃持ち": [7, 303, 405],
	"強打持ち": [4, 9, 19],
	"無効化持ち": [1, 6, 11, 16, 112, 325, 413],
}
```

---

## 実装の要点

### 既存システムとの統合

**重要**: 既存の `BattleSystem` を活用し、車輪の再発明をしない。

```gdscript
# BattleSystemを使ってバトル実行
var battle_system = BattleSystem.new()
var attacker = _create_participant(...)
var defender = _create_participant(...)

# 既存メソッドを使用
battle_system._apply_pre_battle_skills(participants, tile_info, 0)
battle_system._execute_attack_sequence(attack_order)
var result = battle_system._resolve_battle_result(attacker, defender)
```

### スキル付与システム

アイテムによってスキルが付与される機能。

#### 実装済みスキル
- **先制攻撃** - `has_item_first_strike = true`
- **後手** - `has_last_strike = true`  
- **強打** - キーワードに追加

#### 付与の流れ
```gdscript
func _apply_item_effects_and_record(participant, item_id) -> Array:
	var granted_skills = []
	
	# 付与前のスキル状態を記録
	var had_first_strike_before = participant.has_item_first_strike
	
	# BattleSystemのメソッドを使用
	battle_system._apply_item_effects(participant, item_data)
	
	# 付与後の状態をチェック
	if participant.has_item_first_strike and not had_first_strike_before:
		granted_skills.append("先制攻撃")
	
	return granted_skills
```

### 発動スキルの記録

バトル後のParticipant状態から発動したスキルを推測。

```gdscript
func _get_triggered_skills(participant: BattleParticipant) -> Array:
	var skills = []
	
	if participant.has_first_strike or participant.has_item_first_strike:
		skills.append("先制攻撃")
	
	if participant.has_last_strike:
		skills.append("後手")
	
	var keywords = participant.creature_data.ability_parsed.get("keywords", [])
	if "強打" in keywords:
		skills.append("強打")
	
	# その他のキーワードも自動追加
	...
	
	return skills
```

### 結果表示

#### テーブル表示
```
[1] グラディエーター vs アモン → 攻撃側勝利 | HP: 40 vs -30 | AP: 60 vs 20
[2] グラディエーター vs イエティ → 攻撃側勝利 | HP: 40 vs -10 | AP: 60 vs 30
```

#### 詳細ウィンドウ（ダブルクリック）
```
🔍 バトル詳細 #2

■ 基本情報
  攻撃側: グラディエーター (ID:9)
  防御側: イエティ (ID:3)
  勝者: 攻撃側

■ 装備・使用
  攻撃側アイテム: なし
  防御側アイテム: なし

■ 発動したスキル
  攻撃側: 強打

■ 最終ステータス
  攻撃側 HP: 40 (基礎: 40)
  防御側 HP: -10 (基礎: 30)
  攻撃側 攻撃力: 60 (基礎: 40)
  防御側 攻撃力: 30 (基礎: 30)

■ バトル条件
  バトル発生土地: water
  攻撃側隣接: なし
  防御側隣接: なし
```

---

## 制約事項

### 未実装機能
- ❌ **スペル効果の適用** - UIはあるが機能未実装
- ❌ **CSV出力** - 設計済みだが未実装
- ❌ **フィルター機能** - 基本実装のみ

### 技術的制約
1. **シングルスレッド実行** - Godotの制限によりマルチスレッド不可
2. **メモリ制約** - 40,000件の結果を保持（約12MB）
3. **UI応答性** - 長時間実行中はUI更新なし

### 仕様上の制限
1. **1対1のバトルのみ** - 複数クリーチャーの同時戦闘は非対応
2. **アイテム1個まで** - 複数装備は非対応
3. **スペル1個まで** - 複数スペルの組み合わせは非対応

### 重要な注意点

#### 土地ボーナス計算
**正しい実装**（修正済み）:
```gdscript
# 防御側の属性で判定
if def_card_data.element == tile_element:
	def_land_bonus = 10
```

**間違った実装**（修正前）:
```gdscript
# 攻撃側の属性で判定していた（バグ）
if att_card_data.element == tile_element:
	def_land_bonus = 10
```

#### 無属性土地
- バトル発生土地を**未選択**の場合 → `"neutral"`（無属性）
- UIには「火・水・風・土」の4つのみ表示
- 初期状態は `selected = -1`（未選択）

---

## 更新履歴

| 日付 | 内容 | 更新者 |
|------|------|--------|
| 2025/10/18 | 初版作成・設計完了 | AI |
| 2025/10/19 | Phase 2-4実装完了 | AI |
| 2025/10/20 | Phase 5完了、バグ修正、ドキュメント整理 | AI |

---

**最終更新**: 2025年10月20日
