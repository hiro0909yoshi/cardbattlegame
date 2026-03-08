# バトルテストツール 技術仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム
**作成日**: 2025年10月18日
**最終更新**: 2026年3月8日
**ステータス**: バトルシステム完全統合版（刻印・アイテム・スキル対応）

---

## 📋 目次

1. [概要](#概要)
2. [システムアーキテクチャ](#システムアーキテクチャ)
3. [データ構造](#データ構造)
4. [実装の要点](#実装の要点)
5. [刻印スペル適用](#刻印スペル適用)
6. [制約事項](#制約事項)
7. [既知の問題と解決済みバグ](#既知の問題と解決済みバグ)
8. [更新履歴](#更新履歴)

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

### テストモード
1. **通常モード** - 高速で全組み合わせを実行、結果をテーブル・統計で表示
2. **ビジュアルモード** - BattleScreenManagerを使って実際のバトル画面で演出付き実行

### 主要機能
1. ID入力式のクリーチャー・アイテム選択
2. プリセット機能（属性別・スキル別）
3. 土地条件・隣接条件の設定
4. 刻印スペルの適用
5. 全組み合わせのバトル自動実行
6. 詳細な結果表示（テーブル・統計・詳細ウィンドウ）
7. 発動スキル・付与スキルの記録

---

## システムアーキテクチャ

### 全体構成
```
BattleTestUI (メインコントローラー)
  │
  ├─► BattleTestConfig (設定データ)
  │     └─ 刻印スペルID、バフ設定も含む
  │
  ├─► BattleTestExecutor (実行エンジン)
  │     │
  │     ├─► BattleSystem (既存) - バトル実行
  │     │     ├─► BattlePreparation
  │     │     ├─► BattleExecution
  │     │     ├─► BattleSkillProcessor
  │     │     ├─► BattleSpecialEffects
  │     │     └─► BattleCurseApplier
  │     │
  │     ├─► MockPlayerSystem (ダミープレイヤー2人)
  │     ├─► MockCardSystem
  │     ├─► CardLoader (既存) - カードデータ取得
  │     └─► BattleTestResult[] (出力)
  │
  ├─► BattleScreenManager (ビジュアルモード用)
  │
  └─► ResultViews (結果表示)
        ├─► StatisticsLabel - 統計サマリー
        ├─► DetailTable - テーブル表示
        └─► DetailWindow - 詳細ウィンドウ
```

### データフロー（通常モード）
```
ユーザー入力
  ↓
BattleTestConfig (設定)
  ↓
BattleTestExecutor.execute_all_battles()
  ├─ ループ: クリーチャー × アイテム
  ├─ BattleParticipant作成
  │   ├─ current_hp初期化（★重要: _init()では設定されない）
  │   ├─ apply_effect_arrays()（永続/一時効果）
  │   ├─ item_applier.apply_item_effects()（アイテム効果）
  │   └─ _apply_curse_spell()（刻印をcreature_data["curse"]にセット）
  ├─ apply_pre_battle_skills()
  │   └─ apply_creature_curses()（刻印のステータス変更を適用）
  ├─ execute_attack_sequence()
  ├─ resolve_battle_result()
  └─ BattleTestResult[] 生成
  ↓
BattleTestStatistics.calculate() (統計計算)
  ↓
結果表示 (テーブル・詳細・統計)
```

### データフロー（ビジュアルモード）
```
ユーザー入力
  ↓
BattleTestUI._execute_single_visual_battle()
  ├─ BattleScreenManager.start_battle() - バトル画面表示
  ├─ BattleParticipant作成（通常モードと同じ）
  ├─ BattleSystem作成・シーンツリー追加
  │   ├─ battle_execution.setup_systems(mock_card, _battle_screen_manager)
  │   ├─ battle_skill_processor.setup_systems(..., _battle_screen_manager, ...)
  │   └─ battle_special_effects.setup_systems(..., _battle_screen_manager)
  ├─ apply_pre_battle_skills() - スキル演出付き
  ├─ execute_attack_sequence() - 攻撃演出付き
  ├─ resolve_battle_result()
  ├─ BattleScreenManager.show_battle_result() - 結果演出
  └─ BattleScreenManager.close_battle_screen()
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
var attacker_spell: int = -1            # スペルID
var attacker_owned_lands: Dictionary = {
	"fire": 0, "water": 0, "earth": 0, "wind": 0
}
var attacker_battle_land: String = "neutral"
var attacker_has_adjacent: bool = false
var attacker_curse_spell_id: int = -1   # 刻印スペルID
var attacker_buff_config: Dictionary = {} # バフ設定

# 防御側も同様
var defender_creatures: Array = []
var defender_items: Array = []
var defender_spell: int = -1
var defender_owned_lands: Dictionary = {...}
var defender_battle_land: String = "neutral"
var defender_battle_land_level: int = 1  # 土地レベル
var defender_has_adjacent: bool = false
var defender_curse_spell_id: int = -1
var defender_buff_config: Dictionary = {}
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
var attacker_effect_info: Dictionary = {}    # 効果詳細

# 防御側も同様
...

# バトル結果
var winner: String  # "attacker", "defender", "attacker_survived", "both_defeated"
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

---

## 実装の要点

### ★最重要: current_hp の初期化

`BattleParticipant._init()` は `current_hp` を**初期化しない**（デフォルト0のまま）。
メインゲームでは `battle_preparation.prepare_participants()` が設定するが、
テストツールでは `prepare_participants()` を使わないため、**手動で設定が必須**。

```gdscript
# BattleParticipant作成後、必ずcurrent_hpを設定する
var attacker = BattleParticipant.new(att_card_data, att_card_data.hp, 0, att_card_data.ap, true, 0)
attacker.current_hp = att_card_data.hp  # ★これがないとHP:0で即死

var defender = BattleParticipant.new(def_card_data, def_card_data.hp, land_bonus, def_card_data.ap, false, 1)
defender.current_hp = def_card_data.hp + land_bonus  # ★土地ボーナス込み
```

### BattleSystemのシーンツリー追加

`BattleSystem` は `await` を使う処理が多いため、**必ずシーンツリーに追加する**。

```gdscript
var battle_system = BattleSystem.new()
battle_system.name = "BattleSystem_Test"
scene_tree_parent.add_child(battle_system)  # ★必須
```

### アイテム効果の適用

`battle_preparation` には直接 `apply_item_effects()` メソッドがない。
`item_applier` 経由で呼ぶ。

```gdscript
# ❌ 間違い（メソッドが存在しない）
battle_system.battle_preparation.apply_item_effects(participant, item_data, enemy)

# ✅ 正しい
battle_system.battle_preparation.item_applier.apply_item_effects(participant, item_data, enemy)
```

### HP管理の仕組み（ダメージ消費順序）

`current_hp` にはアイテムや刻印のボーナスHPを加算する必要はない。
ダメージは以下の順序で各ボーナスフィールドから個別に消費される：

```
1. land_bonus_hp    → 土地ボーナス（先に消費）
2. resonance_bonus_hp → 共鳴ボーナス
3. temporary_bonus_hp → 一時的ボーナス（効果配列・刻印等）
4. spell_bonus_hp   → スペルボーナス
5. item_bonus_hp    → アイテムボーナス
6. current_hp       → 基本HP（base_hp + base_up_hp の範囲）
```

`is_alive()` は `current_hp > 0` で判定。

### MockPlayerSystem

蓄魔系スキル（リキッドフォーム等）が `SpellMagic.steal_magic()` を呼ぶ際、
プレイヤーデータが必要。ダミープレイヤー2人を作成する。

```gdscript
class MockPlayerSystem extends PlayerSystem:
	func _init():
		var p0 = PlayerData.new()
		p0.id = 0
		p0.name = "テスト攻撃側"
		var p1 = PlayerData.new()
		p1.id = 1
		p1.name = "テスト防御側"
		players = [p0, p1]
```

### ビジュアルモードのBattleScreenManager連携

ビジュアルモードでは、各サブシステムに `_battle_screen_manager` を渡す必要がある。
`null` を渡すとアニメーションがスキップされ即終了する。

```gdscript
# ★全てに _battle_screen_manager を渡す
battle_system.battle_execution.setup_systems(mock_card, _battle_screen_manager)
battle_system.battle_skill_processor.setup_systems(mock_board, null, mock_card, _battle_screen_manager, ...)
battle_system.battle_special_effects.setup_systems(mock_board, spell_draw, spell_magic, mock_card, _battle_screen_manager)
```

---

## 刻印スペル適用

### 仕組み

テストツールでの刻印適用は2段階：

1. **`_apply_curse_spell()`** - スペルデータから `creature_data["curse"]` にDictionaryをセット
2. **`apply_pre_battle_skills()`** 内の `apply_creature_curses()` - 実際のステータス変更を適用

### curse データフォーマット

メインゲームの `spell_curse.curse_creature()` と同じ形式にする必要がある：

```gdscript
creature_data["curse"] = {
	"curse_type": "random_stat",     # ★battle_curse_applierが参照するキー
	"name": "狂星",
	"duration": -1,
	"params": {
		"name": "狂星",
		"stat": "both",
		"min": 10,
		"max": 70
	}
}
```

**注意**: `creature_data["curse"]` はDictionary型（Arrayではない）。

### effect_type → curse_type 変換マップ

スペルデータの `effect_type` と `battle_curse_applier` の `curse_type` は名前が異なる場合がある。
メインゲームでは `spell_curse.gd` が変換するが、テストツールでは独自に変換する：

```gdscript
var _curse_type_map = {
	"random_stat_curse": "random_stat",
	"command_growth_curse": "command_growth",
	"plague_curse": "plague",
	"bounty_curse": "bounty",
}
```

上記以外の `effect_type` はそのまま `curse_type` として使用可能
（例: `stat_boost`, `stat_reduce`, `ap_nullify`, `metal_form`, `magic_barrier`,
`battle_disable`, `skill_nullify`）。

### 対応済み刻印一覧

| スペル effect_type | curse_type | バトル効果 |
|---|---|---|
| `stat_boost` | `stat_boost` | HP/AP上昇（暁光） |
| `stat_reduce` | `stat_reduce` | HP/AP減少（衰月） |
| `ap_nullify` | `ap_nullify` | AP=0 |
| `metal_form` | `metal_form` | 無効化[通常攻撃]（硬化） |
| `magic_barrier` | `magic_barrier` | 無効化[通常攻撃]+EP移動（祭壇） |
| `battle_disable` | `battle_disable` | 攻撃・アイテム・加勢使用不可（消沈） |
| `skill_nullify` | `skill_nullify` | 全スキル無効化（錯乱） |
| `random_stat_curse` | `random_stat` | AP&HPランダム化（狂星/フラックス） |
| `command_growth_curse` | `command_growth` | 昇華 |
| `plague_curse` | `plague` | 衰弱 |
| `bounty_curse` | `bounty` | 賞金 |

### 非刻印effect_type（スキップ対象）

`draw`, `magic_gain` 等はスペルカードの付随効果であり、刻印ではないためスキップする。

---

## 制約事項

### 未実装機能
- ❌ **CSV出力** - 設計済みだが未実装
- ❌ **フィルター機能** - 基本実装のみ

### 技術的制約
1. **シングルスレッド実行** - Godotの制限によりマルチスレッド不可
2. **メモリ制約** - 40,000件の結果を保持（約12MB）
3. **UI応答性** - 長時間実行中はUI更新なし

### 仕様上の制限
1. **1対1のバトルのみ** - 複数クリーチャーの同時戦闘は非対応
2. **アイテム1個まで** - 複数装備は非対応
3. **刻印1個まで** - creature_data["curse"]は1つのDictionaryのみ

### UI仕様
- **グローバルテーマ**: `default_font_size = 24`
  - フォントサイズのオーバーライドは24以上でないと効果がない
  - テストツールでは36pt（1.5倍）を使用
- **DetailWindow**: Window型のため独立したテーマスコープを持つ
- **閉じるボタン**: DetailWindow、カード一覧ウィンドウ共に `close_requested` シグナルで対応

---

## 既知の問題と解決済みバグ

### 解決済み（2026/3/8）

| 問題 | 原因 | 修正 |
|------|------|------|
| HP:0 vs 0（全て相打ち） | `BattleParticipant._init()` が `current_hp` を初期化しない | `new()` 後に手動で `current_hp` を設定 |
| ビジュアルモード即終了 | `battle_execution.setup_systems()` に `null` を渡していた | `_battle_screen_manager` を渡す |
| アイテム効果未適用 | `battle_preparation.apply_item_effects()` は存在しない | `item_applier.apply_item_effects()` に修正 |
| 刻印でクラッシュ | `creature_data["curse"]` をArrayで設定していた | Dictionary形式に修正 |
| 刻印が効かない（リキッドフォーム等） | `effect_type` と `curse_type` の名前不一致 | 変換マップを追加 |
| SpellMagic:無効なプレイヤーID | MockPlayerSystemにプレイヤーデータがなかった | ダミープレイヤー2人を追加 |
| フォントサイズ変更が効かない | グローバルテーマの `default_font_size=24` 以下の値は無効 | 36pt（1.5倍）で設定 |

### 修正時の鉄則

**メインロジックは絶対に変更しない。テストクラス内での修正のみ。**

修正対象ファイル:
- `scripts/battle_test/battle_test_executor.gd`
- `scripts/battle_test/battle_test_ui.gd`
- `scripts/battle_test/battle_test_statistics.gd`
- `scenes/battle_test_tool.tscn`

---

## 更新履歴

| 日付 | 内容 | 更新者 |
|------|------|--------|
| 2025/10/18 | 初版作成・設計完了 | AI |
| 2025/10/19 | Phase 2-4実装完了 | AI |
| 2025/10/20 | Phase 5完了、バグ修正、ドキュメント整理 | AI |
| 2026/03/08 | 大規模修正: current_hp初期化、ビジュアルモード修正、刻印対応、変換マップ追加、UI拡大 | AI |

---

**最終更新**: 2026年3月8日
