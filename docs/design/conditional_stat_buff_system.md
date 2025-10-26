# 条件付きステータスバフシステム統合仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**作成日**: 2025年10月26日  
**ステータス**: Phase 3 実装準備中

---

## ⚠️ 実装前に必要な機能の追加

条件付きバフスキルの実装には、以下の機能の追加が必要です。

詳細な実装方法は [required_features_for_buffs.md](./required_features_for_buffs.md) を参照してください。

### 🔴 必須機能（未実装）

| 機能 | 実装場所 | 難易度 | 対象クリーチャー |
|------|---------|-------|----------------|
| ターン数カウンター | GameFlowManager | ★☆☆ | ラーバキン(47) |
| 周回完了シグナル | GameFlowManager | ★★☆ | キメラ(7), モスタイタン(240) |
| 土地イベント | BoardSystem3D | ★★☆ | アースズピリット(200), デュータイタン(328) |
| 破壊カウンター | GameData, BattleSystem | ★★☆ | ソウルコレクター(323), バルキリー(35)など |

### ✅ 実装可能（既存システム活用）

| 機能 | 実装場所 | 状況 | 対象クリーチャー |
|------|---------|------|----------------|
| 手札数取得 | BattleSkillProcessor | CardSystem活用 | リリス(146) |
| デッキ枚数比較 | BattleSkillProcessor | CardSystem改修必要 | コアトリクエ(214) |

### 実装優先順位

1. ~~**ターン数カウンター**（最優先、簡単）~~ ✅ **実装完了** (2025-10-27)
2. **手札数取得**（すぐ実装可能）
3. **クリーチャー破壊カウンター**（重要）
4. ~~**周回完了シグナル**（やや複雑）~~ ✅ **実装完了** (2025-10-27)
5. **土地レベルアップ/地形変化イベント**（やや複雑）

---

## 📋 実装済み機能詳細

### ✅ 周回完了シグナル (2025-10-27)
- **実装ファイル**: `GameFlowManager`, `CheckpointTile`, `MovementController`
- **対象クリーチャー**: キメラ(7), モスタイタン(240)
- **詳細仕様**: [lap_system.md](./lap_system.md) 参照

### ✅ ラウンド数カウンター (2025-10-27)
- **実装ファイル**: `GameFlowManager`, `BattleSkillProcessor`, `ConditionChecker`
- **対象クリーチャー**: ラーバキン(47)
- **詳細仕様**: [turn_number_system.md](./turn_number_system.md) 参照
- **重要**: ターン制ではなく**ラウンド制**（全プレイヤーが1回ずつ行動で+1）

---

---

## 📋 目次

1. [概要](#概要)
2. [全体設計](#全体設計)
3. [effect_type 定義](#effect_type-定義)
4. [カテゴリ別実装仕様](#カテゴリ別実装仕様)
5. [実装優先度とロードマップ](#実装優先度とロードマップ)
6. [データ構造とJSON例](#データ構造とjson例)
7. [既存システムとの統合](#既存システムとの統合)

---

## 概要

### 目的

38体のクリーチャーが持つ条件付きステータス上昇/減少スキルを体系的に実装するための統合仕様書。

### 対象クリーチャー

- **実装済み**: 2体（アームドパラディン、サンダースポーン）
- **未実装**: 36体

### バフの永続性分類

条件付きバフは2種類に大別されます：

#### 🔵 一時的バフ（戦闘時のみ上昇）
- **適用タイミング**: バトル準備時に計算
- **持続期間**: 1回のバトルのみ
- **削除タイミング**: バトル終了時に消失
- **実装**: `temporary_bonus_hp/ap` に加算
- **対象**: 29体（永続バフ以外の全て）

#### 🟢 永続バフ（base_up_hp/ap）
- **適用タイミング**: イベント発生時（戦闘勝利時、周回時など）
- **持続期間**: 移動しても維持、バトル後も維持
- **削除タイミング**: 手札に戻った時のみリセット
- **実装**: `creature_data["base_up_hp/ap"]` に直接加算
- **対象**: 9体
  - ID: 7（キメラ）
  - ID: 23（ドゥームデボラー）
  - ID: 34（バイロマンサー）
  - ID: 35（バルキリー）
  - ID: 137（ブラッドプリン）
  - ID: 200（アースズピリット）
  - ID: 227（ダスクドウェラー）
  - ID: 240（モスタイタン）
  - ID: 328（デュータイタン）

**重要**: 永続バフは手札に戻った（交換・破壊からの復活など）時点でリセットされ、元のカードデータの値に戻ります。

### 設計原則

1. **統一されたデータ構造**: `ability_parsed.effects[]` で統一管理
2. **動的計算vs永続保存**: 一時バフは毎回計算、永続バフはデータ保存
3. **段階的実装**: シンプルなものから順次実装
4. **既存システムの活用**: BattleSkillProcessor, ConditionChecker との統合

---

## 全体設計

### 効果の計算タイミング

```
バトル準備
  ↓
1. 基礎値設定 (base_hp/ap)
  ↓
2. 永続効果適用 (base_up_hp/ap, permanent_effects)
  ↓
3. 土地ボーナス (land_bonus_hp)
  ↓
4. 【条件付きバフ効果の計算】← 本システムの対象
  ├─ 配置数比例効果
  ├─ 周回・ラウンド効果
  ├─ 領地条件効果
  ├─ 戦闘イベント効果
  ├─ 手札・ブック条件
  └─ その他の条件
  ↓
5. アイテム効果 (item_bonus_hp/ap)
  ↓
6. 感応効果 (resonance_bonus_hp/ap)
  ↓
7. 強打効果（AP × 1.5）
  ↓
バトル開始
```

### 条件チェックの責任分担

| 条件タイプ | 計算タイミング | 責任クラス |
|-----------|--------------|-----------|
| 配置数比例 | バトル準備時 | BattleSkillProcessor |
| 周回・ラウンド | バトル準備時 | BattleSkillProcessor |
| 領地条件 | バトル準備時 | BattleSkillProcessor |
| 戦闘イベント | バトル後 | BattleSystem |
| 手札・ブック | バトル準備時 | BattleSkillProcessor |
| 防御時条件 | バトル準備時 | BattlePreparation |

---

## effect_type 定義

### カテゴリ1: 配置数比例

#### `land_count_multiplier` ✅実装済み

土地の配置数に比例してステータスが変動

```gdscript
{
  "effect_type": "land_count_multiplier",
  "stat": "ap" | "hp" | "both",           # 対象ステータス
  "elements": ["fire", "earth"],          # 対象属性（複数可）
  "multiplier": 10,                       # 1つあたりの増加量
  "operation": "add" | "set",             # 加算 or 代入
  "description": "説明文"
}
```

**動作例**: 火土地2 + 土土地3 = 5つ → ST +50

#### `other_elements_count_multiplier` 🚧未実装

自分以外の属性の配置数に比例

```gdscript
{
  "effect_type": "other_elements_count_multiplier",
  "stat": "both",
  "multiplier": 5,
  "operation": "add"
}
```

**実装**: 自クリーチャーの属性を除外して全配置数をカウント

#### `creature_count_multiplier` 🚧未実装

特定クリーチャー名の配置数に比例

```gdscript
{
  "effect_type": "creature_count_multiplier",
  "stat": "both",
  "target_creature_name": "ハイプワーカー",
  "multiplier": 10,
  "operation": "add"
}
```

**実装**: BoardSystem3D.get_player_tiles() で該当クリーチャーをカウント

#### `land_count_with_condition` 🚧未実装

条件付きクリーチャーの配置数に比例

```gdscript
{
  "effect_type": "land_count_with_condition",
  "stat": "ap",
  "creature_condition": {
    "mhp_check": {"operator": ">=", "value": 50}
  },
  "multiplier": 5,
  "operation": "add"
}
```

**実装**: カウント時に各クリーチャーの条件をチェック

---

### カテゴリ2: 周回・ラウンド数

#### `per_lap_permanent_bonus` 🚧未実装

周回ごとに永続的にステータス上昇

```gdscript
{
  "effect_type": "per_lap_permanent_bonus",
  "stat": "ap" | "max_hp",
  "value": 10,
  "reset_condition": {                    # オプション（モスタイタン用）
    "max_hp_check": {"operator": ">=", "value": 80, "reset_to": 30}
  }
}
```

**データ保存**: `creature_data["map_lap_count"]` にカウント保存

**実装メモ**:
- 周回完了時に `creature_data["base_up_hp/ap"]` に加算
- リセット条件はモスタイタン（ID: 240）のみ

#### `round_number_bonus` 🚧未実装

現在のラウンド数がステータスになる

```gdscript
{
  "effect_type": "round_number_bonus",
  "stat": "ap" | "hp",
  "operation": "set" | "add"
}
```

**実装**: GameFlowManager から current_round を取得して適用

---

### カテゴリ3: 領地条件

#### `owned_land_count_bonus` 🚧未実装

自領地数による条件付きボーナス

```gdscript
{
  "effect_type": "owned_land_count_bonus",
  "condition": {"operator": ">=", "value": 5},
  "stat_changes": {"ap": -30, "hp": -30}
}
```

**実装**: プレイヤーの総領地数をカウントして条件チェック

#### `adjacent_land_bonus` 🚧未実装

隣接領地の状態による条件

```gdscript
{
  "effect_type": "adjacent_land_bonus",
  "condition": "all_adjacent_owned" | "any_adjacent_owned",
  "stat_changes": {"ap": 20, "hp": 20}
}
```

**実装**: 既存の強打スキルと同様の隣接チェック処理

#### `battle_land_level_bonus` 🚧未実装

戦闘地のレベルに依存

```gdscript
{
  "effect_type": "battle_land_level_bonus",
  "element_condition": ["water"],         # この属性の土地でのみ有効
  "stat": "hp",
  "multiplier": 10
}
```

**実装**: 戦闘タイルの level と element を確認

#### `on_land_change` 🚧未実装

領地変化時にトリガー（イベント駆動）

```gdscript
{
  "effect_type": "on_land_change",
  "trigger": "level_up" | "terrain_change",
  "stat_change": {"max_hp": 10}
}
```

**実装**: レベルアップ/地形変化時のイベントハンドラーが必要

#### `marked_land_bonus` 🚧未実装

マーク付き領地での戦闘

```gdscript
{
  "effect_type": "marked_land_bonus",
  "mark_type": "heart",
  "stat_change": {"hp": -20}
}
```

**実装**: タイルのマーク情報を確認

---

### カテゴリ4: 戦闘イベント

#### `on_enemy_destroy_permanent` 🚧未実装

敵破壊時に永続的にステータス上昇

```gdscript
{
  "effect_type": "on_enemy_destroy_permanent",
  "stat_changes": {"ap": 10, "max_hp": 10}
}
```

**データ保存**: `creature_data["destroy_count"]` にカウント保存

**実装**: 
- バトル勝利時に `creature_data["base_up_hp/ap"]` に加算
- BattleSystem.on_battle_end() で処理

#### `destroy_count_multiplier` 🚧未実装

累計破壊数に比例

```gdscript
{
  "effect_type": "destroy_count_multiplier",
  "stat": "ap",
  "multiplier": 5
}
```

**データ保存**: プレイヤーごとの破壊数カウンター必要

#### `after_battle_change` 🚧未実装

戦闘後にステータス変動

```gdscript
{
  "effect_type": "after_battle_change",
  "trigger": "any" | "enemy_attack_success",
  "stat_changes": {"ap": -10, "max_hp": -10},
  "operation": "add" | "set"
}
```

**実装**: バトル終了時に条件チェックして適用

---

### カテゴリ5: 戦闘地・地形条件

#### `battle_land_element_check` 🚧未実装

戦闘地の属性による条件

```gdscript
{
  "effect_type": "stat_bonus",
  "stat": "ap",
  "value": 20,
  "condition": {
    "battle_land_element_check": {
      "elements": ["water", "wind"]
    }
  }
}
```

**実装**: 既存の ConditionChecker を拡張

#### `enemy_element_check` 🚧未実装

敵の属性による条件

```gdscript
{
  "effect_type": "stat_bonus",
  "stat": "hp",
  "value": 50,
  "condition": {
    "enemy_is_element": {
      "elements": ["water", "wind"]
    }
  }
}
```

**実装**: 既存の `enemy_is_element` 条件を活用

---

### カテゴリ6: 手札・ブック条件

#### `hand_count_multiplier` 🚧未実装

手札枚数に依存

```gdscript
{
  "effect_type": "hand_count_multiplier",
  "stat": "ap",
  "multiplier": 10,
  "operation": "set"
}
```

**実装**: CardSystem.hand[player_id].size() を取得

#### `deck_comparison_bonus` 🚧未実装

デッキ枚数の比較

```gdscript
{
  "effect_type": "deck_comparison_bonus",
  "comparison": "greater_than_opponent",
  "stat_changes": {"ap": 20, "hp": 20}
}
```

**実装**: 各プレイヤーのデッキ枚数を比較

---

### カテゴリ7: ダイス条件

#### `dice_condition_bonus` 🚧未実装

ダイス目による条件

```gdscript
{
  "effect_type": "dice_condition_bonus",
  "dice_check": {"operator": "<=", "value": 3},
  "stat_changes": {"ap": 10, "max_hp": 10}
}
```

**実装**: 移動前のダイス値を記録して参照

---

### カテゴリ8: 役割・状態条件

#### `defensive_stat_override` 🚧未実装

防御時のみ有効

```gdscript
{
  "effect_type": "defensive_stat_override",
  "stat": "ap",
  "value": 50,
  "operation": "set"
}
```

**実装**: BattlePreparation で is_defender をチェック

#### `constant_stat_bonus` 🚧未実装

常時有効な固定補正

```gdscript
{
  "effect_type": "constant_stat_bonus",
  "stat_changes": {"ap": 20, "hp": -10}
}
```

**実装**: シンプルな無条件ボーナス（最優先で実装）

---

### カテゴリ9: アイテム関連

#### `as_creature_bonus` 🚧未実装

アイテムクリーチャーがクリーチャーとして戦闘時

```gdscript
{
  "effect_type": "as_creature_bonus",
  "stat_changes": {"ap": 50}
}
```

**実装**: アイテムクリーチャーシステムと連動

#### `on_item_use_bonus` 🚧未実装

アイテム使用時

```gdscript
{
  "effect_type": "on_item_use_bonus",
  "trigger": "self_item_use" | "enemy_item_use",
  "timing": "during_battle" | "after_battle",
  "stat_changes": {"ap": 20}
}
```

**実装**: アイテム使用フラグを確認

---

### カテゴリ10: 特殊・複雑

#### `random_stat` 🚧未実装

ランダムにステータス決定

```gdscript
{
  "effect_type": "random_stat",
  "stat": "both",
  "min": 10,
  "max": 70
}
```

**実装**: バトル準備時にランダム値を生成

#### `support_creature_stat_copy` 🚧未実装

援護クリーチャーのステータスをコピー

```gdscript
{
  "effect_type": "support_creature_stat_copy",
  "source_stat": "hp",
  "target_stat": "max_hp"
}
```

**実装**: 援護システムとの統合が必要

#### `tribe_placement_bonus` 🚧未実装

特定種族配置時

```gdscript
{
  "effect_type": "tribe_placement_bonus",
  "tribe": "オーガ",
  "conditions": [
    {"elements": ["fire", "wind"], "stat_changes": {"ap": 20}},
    {"elements": ["water", "earth"], "stat_changes": {"hp": 20}}
  ]
}
```

**実装**: クリーチャーの種族データとの連携が必要

---

## 永続バフの詳細仕様

### 永続バフを持つクリーチャー（9体）

| ID | 名前 | 効果内容 | トリガー | 実装方法 |
|----|------|---------|---------|---------|
| 7 | キメラ | 周回ごとにST+10 | 周回完了 | base_up_ap += 10 |
| 23 | ドゥームデボラー | ダイス3以下でST&MHP+10 | 条件満たした移動時 | base_up_ap/hp += 10 |
| 34 | バイロマンサー | 敵攻撃成功後ST=20, MHP-30 | バトル終了時 | base_ap = 20, base_up_hp -= 30 |
| 35 | バルキリー | 敵破壊時ST+10 | バトル勝利時 | base_up_ap += 10 |
| 137 | ブラッドプリン | 戦闘前MHP+援護クリーチャーHP | 援護発動時 | base_up_hp += support_hp |
| 200 | アースズピリット | レベルアップ/地形変化時MHP+10 | 領地変化時 | base_up_hp += 10 |
| 227 | ダスクドウェラー | 敵破壊時ST&MHP+10 | バトル勝利時 | base_up_ap/hp += 10 |
| 240 | モスタイタン | 周回ごとにMHP+10（80で30にリセット） | 周回完了 | base_up_hp += 10 (check reset) |
| 328 | デュータイタン | レベルアップ/地形変化時MHP-10 | 領地変化時 | base_up_hp -= 10 |

### 実装の重要ポイント

#### 0. 永続バフのリセット条件（詳細）

**リセットされるタイミング**:
1. **交換コマンド**で手札に戻った時
2. **クリーチャーが破壊**されて墓地に行った時
3. **変身効果**で別のクリーチャーになった時

**リセットされないタイミング**:
- 移動した時
- バトルに勝利/敗北した時
- 領地レベルが変化した時

**復活時の挙動**:
- 墓地から復活した場合、元のカードデータで復活（永続バフなし）

```gdscript
func reset_permanent_buffs(creature_data: Dictionary):
	creature_data["base_up_hp"] = 0
	creature_data["base_up_ap"] = 0
	creature_data["map_lap_count"] = 0
	creature_data["destroy_count"] = 0  # クリーチャー固有カウンター
```

#### 1. データ保存場所
```gdscript
creature_data = {
    "hp": 30,           # 元の基礎HP（変更されない）
    "ap": 20,           # 元の基礎AP（変更されない）
    "base_up_hp": 0,    # 永続的なHP上昇（イベントで加算）
    "base_up_ap": 0,    # 永続的なAP上昇（イベントで加算）
    # ...
}
```

#### 2. 適用タイミング
- **周回完了時**: キメラ、モスタイタン
- **バトル勝利時**: バルキリー、ダスクドウェラー
- **バトル終了時**: バイロマンサー
- **領地変化時**: アースズピリット、デュータイタン
- **援護発動時**: ブラッドプリン
- **移動時（条件チェック）**: ドゥームデボラー

#### 3. 手札に戻った時の処理
クリーチャーが手札に戻った時（交換、破壊からの復活など）:
```gdscript
func return_to_hand(creature_data: Dictionary):
    # 永続バフをリセット
    creature_data["base_up_hp"] = 0
    creature_data["base_up_ap"] = 0
    # その他のカウンターもリセット
    creature_data["map_lap_count"] = 0
    creature_data["destroy_count"] = 0
```

#### 4. バトル時の計算
```gdscript
# BattleParticipant での HP/AP 計算
current_hp = base_hp + base_up_hp + temporary_bonus_hp + land_bonus_hp + ...
current_ap = base_ap + base_up_ap + temporary_bonus_ap + ...
```

---

## カテゴリ別実装仕様

### 🔥 カテゴリ1: 配置数比例（6体）

| ID | 名前 | effect_type | 実装難易度 | ステータス |
|----|------|------------|----------|----------|
| 1 | アームドパラディン | land_count_multiplier | ★☆☆ | ✅実装済み |
| 37 | ファイアードレイク | land_count_multiplier | ★☆☆ | 🚧未実装 |
| 236 | ブランチアーミー | land_count_multiplier | ★☆☆ | 🚧未実装 |
| 238 | マッドマン | land_count_multiplier | ★☆☆ | 🚧未実装 |
| 307 | ガルーダ | land_count_multiplier (set) | ★☆☆ | 🚧未実装 |
| 318 | サンダースポーン | land_count_multiplier | ★☆☆ | ✅実装済み |
| 109 | アンダイン | land_count_multiplier (set) | ★☆☆ | 🚧未実装 |
| 440 | リビングクローブ | other_elements_count_multiplier | ★★☆ | 🚧未実装 |
| 32 | ハイプワーカー | creature_count_multiplier | ★★☆ | 🚧未実装 |
| 15 | ジェネラルカン | land_count_with_condition | ★★★ | 🚧未実装 |

**実装ポイント**:
- 既存の `apply_land_count_effects()` を活用
- `operation: "set"` の場合、base_ap/hp を上書き

---

### 🟡 カテゴリ2: 周回・ラウンド数（3体）

| ID | 名前 | effect_type | データ保存 | 永続性 | ステータス |
|----|------|------------|----------|-------|----------|
| 7 | キメラ | per_lap_permanent_bonus | map_lap_count | 🟢永続 | 🚧未実装 |
| 240 | モスタイタン | per_lap_permanent_bonus | map_lap_count + reset | 🟢永続 | 🚧未実装 |
| 47 | ラーバキン | round_number_bonus | なし | 🔵一時 | 🚧未実装 |

**永続バフ**: ID 7（キメラ）、ID 240（モスタイタン）
- 周回完了時に `base_up_hp/ap` に加算
- 手札に戻るまで永続的に維持

**一時バフ**: ID 47（ラーバキン）
- バトルごとに現在ラウンド数を計算
- バトル終了後は消失

**実装ポイント**:
- 周回完了時に `GameFlowManager.on_lap_complete()` を実装
- キメラ・モスタイタン: `creature_data["map_lap_count"]++` して `base_up_hp/ap` に加算
- モスタイタンはリセット条件チェック
- ラーバキン: 毎バトル時に `temporary_bonus_hp/ap` に加算

---

### 🟢 カテゴリ3: 領地条件（7体）

| ID | 名前 | effect_type | 実装難易度 | 永続性 |
|----|------|------------|----------|-------|
| 30 | バーンタイタン | owned_land_count_bonus | ★★☆ | 🔵一時 |
| 226 | タイガーヴェタ | adjacent_land_bonus | ★★☆ | 🔵一時 |
| 49 | ローンビースト | adjacent_land_bonus + 強打 | ★★★ | 🔵一時 |
| 131 | ネッシー | battle_land_level_bonus | ★★☆ | 🔵一時 |
| 200 | アースズピリット | on_land_change | ★★★ | 🟢永続 |
| 328 | デュータイタン | on_land_change | ★★★ | 🟢永続 |
| 206 | ギガンテリウム | marked_land_bonus | ★★★ | 🔵一時 |

**永続バフ**: ID 200（アースズピリット）、ID 328（デュータイタン）
- レベルアップ/地形変化イベント時に `base_up_hp/ap` を変更
- 手札に戻るまで永続的に維持

**一時バフ**: その他5体
- バトルごとに条件チェック
- バトル終了後は消失

**実装ポイント**:
- `adjacent_land_bonus`: 既存の強打チェック処理を流用
- `on_land_change`: イベントシステムの構築が必要
- アースズピリット・デュータイタン: イベント発生時に `base_up_hp` を直接変更

---

### 🔴 カテゴリ4: 戦闘イベント（6体）

| ID | 名前 | effect_type | イベント | 永続性 |
|----|------|------------|---------|-------|
| 35 | バルキリー | on_enemy_destroy_permanent | on_battle_win | 🟢永続 |
| 227 | ダスクドウェラー | on_enemy_destroy_permanent | on_battle_win | 🟢永続 |
| 323 | ソウルコレクター | destroy_count_multiplier | 毎バトル | 🔵一時 |
| 446 | ロックタイタン | after_battle_change | on_battle_end | 🔵一時 |
| 34 | バイロマンサー | after_battle_change | on_battle_end | 🟢永続 |

**永続バフ**: ID 35（バルキリー）、ID 227（ダスクドウェラー）、ID 34（バイロマンサー）
- 戦闘勝利/終了時に `base_up_hp/ap` に加算（または代入）
- 手札に戻るまで永続的に維持

**一時バフ**: ID 323（ソウルコレクター）、ID 446（ロックタイタン）
- バトルごとに条件チェック（破壊数など）
- バトル終了後は消失

**実装ポイント**:
- BattleSystem に `on_battle_win()`, `on_battle_end()` signal を追加
- 永続バフ: 戦闘終了時に `base_up_hp/ap` を直接変更
- 一時バフ: 破壊カウンターは `creature_data["destroy_count"]` に保存し、バトル時に参照

---

### 🟣 カテゴリ5: 戦闘地・地形条件（2体）

| ID | 名前 | effect_type | 既存システム |
|----|------|------------|------------|
| 110 | アンフィビアン | battle_land_element_check | ConditionChecker |
| 205 | カクタスウォール | enemy_element_check | ConditionChecker |

**実装ポイント**:
- 既存の ConditionChecker を拡張するだけ

---

### 🟠 カテゴリ6: 手札・ブック条件（2体）

| ID | 名前 | effect_type | データソース |
|----|------|------------|------------|
| 146 | リリス | hand_count_multiplier | CardSystem.hand |
| 214 | コアトリクエ | deck_comparison_bonus | CardSystem.deck |

**実装ポイント**:
- CardSystem からデータ取得

---

### 🟤 カテゴリ7: ダイス条件（1体）

| ID | 名前 | effect_type | 永続性 |
|----|------|------------|-------|
| 23 | ドゥームデボラー | dice_condition_bonus | 🟢永続 |

**永続バフ**: ID 23（ドゥームデボラー）
- ダイス3以下の場合、ST&MHP+10（戦闘勝利後も維持）
- 秘術使用後は ST&MHP-10 を `base_up_hp/ap` から減算

**実装ポイント**:
- GameFlowManager でダイス値を記録
- 条件を満たした場合、`base_up_hp/ap` に加算

---

### ⚫ カテゴリ8: 役割・状態条件（3体）

| ID | 名前 | effect_type |
|----|------|------------|
| 204 | ガーゴイル | defensive_stat_override |
| 102 | アイスウォール | constant_stat_bonus |
| 330 | トルネード | constant_stat_bonus |

**実装ポイント**:
- `constant_stat_bonus`: 最もシンプル、すぐ実装可能

---

### ⚪ カテゴリ9: アイテム関連（2体）

| ID | 名前 | effect_type |
|----|------|------------|
| 438 | リビングアーマー | as_creature_bonus |
| 339 | ブルガサリ | on_item_use_bonus |

**実装ポイント**:
- アイテムクリーチャーシステムの整備が必要

---

### 🎲 カテゴリ10: 特殊・複雑（3体）

| ID | 名前 | effect_type | 永続性 |
|----|------|------------|-------|
| 321 | スペクター | random_stat | 🔵一時 |
| 137 | ブラッドプリン | support_creature_stat_copy | 🟢永続 |
| 407 | オーガロード | tribe_placement_bonus | 🔵一時 |

**永続バフ**: ID 137（ブラッドプリン）
- 戦闘前に援護クリーチャーのHPを `base_up_hp` に加算
- 手札に戻るまで永続的に維持

**一時バフ**: ID 321（スペクター）、ID 407（オーガロード）
- バトルごとに計算/条件チェック
- バトル終了後は消失

**実装ポイント**:
- 高度な機能、後回しでOK
- ブラッドプリン: 援護システムとの統合が必要

---

## 個別クリーチャーの詳細仕様

### 永続バフクリーチャーの特殊仕様

#### ID 7: キメラ
```gdscript
# 周回完了時
creature_data["map_lap_count"] += 1
creature_data["base_up_ap"] += 10
```
- **累積**: 何周でも累積（上限なし）

---

#### ID 23: ドゥームデボラー
```gdscript
# ダイスロール直後にチェック
if dice_result <= 3:
    creature_data["base_up_ap"] += 10
    creature_data["base_up_hp"] += 10
```
- **累積**: 条件を満たすたびに +10（上限なし）
- **秘術**: 実装は後回し（現時点では未対応）

---

#### ID 34: バイロマンサー
```gdscript
# バトル終了時、敵からの攻撃を受けて敗北した場合
if not creature_data.get("bairomancer_triggered", false):
    if is_defender and battle_lost and enemy_took_land:
        creature_data["base_ap"] = 20  # 代入（上書き）
        creature_data["base_up_hp"] -= 30
        creature_data["bairomancer_triggered"] = true  # フラグ設定
```
- **1回のみ**: フラグ管理で2回目以降は発動しない
- **敵攻撃成功**: 敵から攻撃を受けて、かつ土地を奪われた場合

---

#### ID 35: バルキリー
```gdscript
# バトル勝利時
creature_data["base_up_ap"] += 10
```
- **累積**: 敵を破壊するたびに +10（上限なし）

---

#### ID 137: ブラッドプリン
```gdscript
# 援護発動時
var support_creature_mhp = support_creature_data["hp"] + support_creature_data.get("base_up_hp", 0)
creature_data["base_up_hp"] = min(creature_data["base_up_hp"] + support_creature_mhp, 100 - creature_data["hp"])
```
- **累積**: 援護するたびに加算
- **MHP上限**: 100まで（`hp + base_up_hp <= 100`）
- **援護クリーチャーのMHP**: 元のHP + base_up_hp

---

#### ID 200: アースズピリット
```gdscript
# 配置領地のレベルアップまたは地形変化時
creature_data["base_up_hp"] += 10
```
- **累積**: イベントのたびに +10（上限なし）
- **配置領地**: このクリーチャーが配置されている領地のみ
- **レベルアップ**: 1→2, 2→3, 3→4, 4→5 すべて対象
- **地形変化**: スペル、クリーチャー配置による属性変化を含む

---

#### ID 227: ダスクドウェラー
```gdscript
# バトル勝利時
creature_data["base_up_ap"] += 10
creature_data["base_up_hp"] += 10
```
- **累積**: 敵を破壊するたびに +10（上限なし）

---

#### ID 240: モスタイタン
```gdscript
# 周回完了時
creature_data["map_lap_count"] += 1
creature_data["base_up_hp"] += 10

# MHPチェック（毎周回時）
var total_mhp = creature_data["hp"] + creature_data["base_up_hp"]
if total_mhp >= 80:
    creature_data["base_up_hp"] = 0  # リセット（元のHPのみ残る）
```
- **累積**: 周回ごとに +10
- **リセット**: MHP < 80 → MHP >= 80 になった時点でリセット
- **リセット後**: base_up_hp = 0（元のHP 30 のみ）

---

#### ID 328: デュータイタン
```gdscript
# 配置領地のレベルアップまたは地形変化時
creature_data["base_up_hp"] -= 10
```
- **累積**: イベントのたびに -10（下限なし）
- **配置領地**: このクリーチャーが配置されている領地のみ

---

### 一時バフクリーチャーの特殊仕様

#### ID 47: ラーバキン
```gdscript
# バトル準備時
participant.base_ap = current_turn  # 代入（現在ターン数で上書き）
participant.temporary_bonus_hp += current_turn
```
- **動的計算**: 毎バトル時に計算（ターン数依存）
- **ST=現R数**: base_ap を完全上書き（元の値は無視）

---

#### ID 49: ローンビースト
```gdscript
# バトル準備時
var base_st = creature_data["ap"] + creature_data.get("base_up_ap", 0)
participant.temporary_bonus_hp += base_st

# 隣接条件チェック
if has_adjacent_owned_land:
    apply_power_strike(participant)
```
- **基本ST**: base_ap + base_up_ap
- **毎バトル**: リセットされる一時バフ

---

#### ID 146: リリス
```gdscript
# バトル準備時
var hand_count = card_system.hand[player_id].size()
participant.base_ap = hand_count * 10  # 代入
```
- **手札数**: バトル開始時点の手札枚数（アイテム使用後）
- **ST=手札数×10**: base_ap を上書き

---

#### ID 307: ガルーダ & ID 109: アンダイン
```gdscript
# バトル準備時（operation: "set"）
var land_count = count_player_lands(player_id, ["wind"])
participant.base_ap = land_count * 10  # 代入
participant.base_hp = land_count * 10  # 代入
```
- **operation="set"**: base_ap/hp を計算値で上書き
- **その後**: 土地ボーナス、アイテムボーナス、スペルボーナスは通常通り加算

---

#### ID 321: スペクター
```gdscript
# バトル準備時（毎回ランダム）
participant.base_ap = randi() % 61 + 10  # 10~70
participant.base_hp = randi() % 61 + 10  # 10~70（別々）
```
- **毎バトル**: ランダム値を再生成
- **ST と HP**: 別々にランダム

---

#### ID 323: ソウルコレクター
```gdscript
# バトル準備時
var global_destroy_count = game_data["total_creatures_destroyed"]
participant.temporary_bonus_ap += global_destroy_count * 5
```
- **破壊数**: 全プレイヤーの累計破壊数
- **カウント対象**: バトル勝利、スペルによる破壊すべて
- **保存場所**: グローバルゲームデータ（`game_data["total_creatures_destroyed"]`）

---

## 実装優先度とロードマップ

### Phase 3-A: シンプルな条件効果（最優先）

**対象**: 8体（実装難易度: ★☆☆〜★★☆）

1. **常時補正** (2体)
   - [ ] アイスウォール (ID: 102) - `constant_stat_bonus`
   - [ ] トルネード (ID: 330) - `constant_stat_bonus`

2. **配置数比例** (5体)
   - [ ] ファイアードレイク (ID: 37)
   - [ ] ブランチアーミー (ID: 236)
   - [ ] マッドマン (ID: 238)
   - [ ] ガルーダ (ID: 307)
   - [ ] アンダイン (ID: 109)

3. **戦闘地条件** (2体)
   - [ ] アンフィビアン (ID: 110)
   - [ ] カクタスウォール (ID: 205)

**見積もり工数**: 2-3日

**実装手順**:
1. `constant_stat_bonus` を BattleSkillProcessor に追加
2. `land_count_multiplier` の `operation: "set"` 対応
3. ConditionChecker に `battle_land_element_check` 追加

---

### Phase 3-B: 中程度の条件効果

**対象**: 10体（実装難易度: ★★☆）

4. **隣接条件** (2体)
   - [ ] タイガーヴェタ (ID: 226)
   - [ ] ローンビースト (ID: 49)

5. **領地数条件** (1体)
   - [ ] バーンタイタン (ID: 30)

6. **配置数比例（特殊）** (2体)
   - [ ] リビングクローブ (ID: 440) - 他属性
   - [ ] ハイプワーカー (ID: 32) - 特定クリーチャー

7. **手札・ブック** (2体)
   - [ ] リリス (ID: 146)
   - [ ] コアトリクエ (ID: 214)

8. **ラウンド数** (1体)
   - [ ] ラーバキン (ID: 47)

9. **戦闘地レベル** (1体)
   - [ ] ネッシー (ID: 131)

10. **防御時条件** (1体)
    - [ ] ガーゴイル (ID: 204)

**見積もり工数**: 4-5日

---

### Phase 3-C: 永続蓄積システム

**対象**: 5体（実装難易度: ★★★、新システム必要）

11. **周回ごと永続上昇** (2体)
    - [ ] キメラ (ID: 7)
    - [ ] モスタイタン (ID: 240)

12. **敵破壊時永続上昇** (2体)
    - [ ] バルキリー (ID: 35)
    - [ ] ダスクドウェラー (ID: 227)

13. **破壊数カウント** (1体)
    - [ ] ソウルコレクター (ID: 323)

**必要な新システム**:
- GameFlowManager に `on_lap_complete()` signal
- BattleSystem に `on_battle_win()` signal
- プレイヤーごとの破壊数カウンター

**見積もり工数**: 3-4日

---

### Phase 3-D: イベント駆動システム

**対象**: 5体（実装難易度: ★★★、イベントシステム必要）

14. **戦闘後変動** (3体)
    - [ ] ロックタイタン (ID: 446)
    - [ ] バイロマンサー (ID: 34)
    - [ ] リーンタイタン (ID: 439)

15. **領地変化時** (2体)
    - [ ] アースズピリット (ID: 200)
    - [ ] デュータイタン (ID: 328)

**必要な新システム**:
- BattleSystem に `on_battle_end()` signal
- BoardSystem3D に `on_land_level_up()`, `on_terrain_change()` signal

**見積もり工数**: 3-4日

---

### Phase 4: 複雑・特殊ケース（後回し）

**対象**: 6体（実装難易度: ★★★）

16. **MHP条件付き配置数** (1体)
    - [ ] ジェネラルカン (ID: 15)

17. **ダイス条件** (1体)
    - [ ] ドゥームデボラー (ID: 23)

18. **マーク領地** (1体)
    - [ ] ギガンテリウム (ID: 206)

19. **アイテム関連** (2体)
    - [ ] リビングアーマー (ID: 438)
    - [ ] ブルガサリ (ID: 339)

20. **特殊効果** (3体)
    - [ ] スペクター (ID: 321) - ランダム
    - [ ] ブラッドプリン (ID: 137) - 援護依存
    - [ ] オーガロード (ID: 407) - 種族判定

**見積もり工数**: 5-7日

---

## データ構造とJSON例

### 基本構造

```json
{
  "id": 102,
  "name": "アイスウォール",
  "ap": 10,
  "hp": 50,
  "ability_detail": "HP+20",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "constant_stat_bonus",
        "stat_changes": {"hp": 20},
        "description": "常時HP+20"
      }
    ]
  }
}
```

### 配置数比例（複数属性）

```json
{
  "id": 1,
  "name": "アームドパラディン",
  "ap": 0,
  "hp": 50,
  "ability_detail": "ST=火地,配置数×10",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "land_count_multiplier",
        "stat": "ap",
        "elements": ["fire", "earth"],
        "multiplier": 10,
        "operation": "set",
        "description": "火と土の配置数×10をSTに代入"
      }
    ]
  }
}
```

### 周回ごと永続上昇

```json
{
  "id": 7,
  "name": "キメラ",
  "ap": 50,
  "hp": 50,
  "ability_detail": "周回ごとにST+10",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "per_lap_permanent_bonus",
        "stat": "ap",
        "value": 10,
        "description": "マップ1周ごとにST+10（永続）"
      }
    ]
  }
}
```

### 隣接条件

```json
{
  "id": 226,
  "name": "タイガーヴェタ",
  "ap": 30,
  "hp": 30,
  "ability_detail": "隣接領地が自領地の場合、ST&HP+20",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "adjacent_land_bonus",
        "condition": "any_adjacent_owned",
        "stat_changes": {"ap": 20, "hp": 20},
        "description": "隣接に自領地がある場合ST&HP+20"
      }
    ]
  }
}
```

### 敵破壊時永続上昇

```json
{
  "id": 35,
  "name": "バルキリー",
  "ap": 30,
  "hp": 40,
  "ability_detail": "敵破壊時、ST+10",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "on_enemy_destroy_permanent",
        "stat_changes": {"ap": 10},
        "description": "敵を破壊するたびにST+10（永続）"
      }
    ]
  }
}
```

### 手札数依存

```json
{
  "id": 146,
  "name": "リリス",
  "ap": 0,
  "hp": 30,
  "ability_detail": "ST=自手札数×10",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "hand_count_multiplier",
        "stat": "ap",
        "multiplier": 10,
        "operation": "set",
        "description": "手札枚数×10をSTに代入"
      }
    ]
  }
}
```

---

## 既存システムとの統合

### BattleSkillProcessor の拡張

**現在の役割**:
- `apply_land_count_effects()` ✅実装済み

**追加が必要なメソッド**:

```gdscript
# Phase 3-A
func apply_constant_stat_bonuses(participant: BattleParticipant):
	"""常時補正を適用"""
	
func apply_battle_land_element_conditions(participant: BattleParticipant, tile_data: Dictionary, context: Dictionary):
	"""戦闘地属性条件を適用"""

# Phase 3-B
func apply_adjacent_land_bonuses(participant: BattleParticipant, tile_index: int, context: Dictionary):
	"""隣接領地条件を適用"""
	
func apply_owned_land_count_bonuses(participant: BattleParticipant, player_id: int):
	"""自領地数条件を適用"""
	
func apply_hand_count_effects(participant: BattleParticipant, player_id: int):
	"""手札数依存効果を適用"""
	
func apply_deck_comparison_effects(participant: BattleParticipant, player_id: int, enemy_id: int):
	"""デッキ比較効果を適用"""
	
func apply_round_number_effects(participant: BattleParticipant, current_round: int):
	"""ラウンド数依存効果を適用"""

# Phase 3-C
func apply_per_lap_bonuses(participant: BattleParticipant):
	"""周回ボーナスを適用（permanent_effectsから計算）"""
	
func apply_destroy_count_effects(participant: BattleParticipant, player_id: int):
	"""破壊数カウント効果を適用"""
```

### BattlePreparation への統合

**変更箇所**: `prepare_participants()`

```gdscript
func prepare_participants():
	# ... 既存処理 ...
	
	# 条件付きバフ効果の適用（新規追加）
	skill_processor.apply_constant_stat_bonuses(attacker)
	skill_processor.apply_constant_stat_bonuses(defender)
	
	skill_processor.apply_land_count_effects(attacker, context)
	skill_processor.apply_land_count_effects(defender, context)
	
	skill_processor.apply_adjacent_land_bonuses(attacker, attacker_tile_index, context)
	skill_processor.apply_adjacent_land_bonuses(defender, defender_tile_index, context)
	
	# ... 感応、強打など既存処理 ...
```

### BattleSystem への統合

**新規 signal の追加**:

```gdscript
signal battle_won(winner_player_id: int, loser_tile_index: int)
signal battle_ended(attacker_tile: int, defender_tile: int, result: Dictionary)
signal lap_completed(player_id: int)
```

**バトル終了処理の拡張**:

```gdscript
func on_battle_complete(result: Dictionary):
	# ... 既存処理 ...
	
	# 永続効果の適用
	if result.winner == "attacker":
		_apply_on_destroy_permanent_effects(attacker_tile_index)
		battle_won.emit(attacker.player_id, defender_tile_index)
	
	# 戦闘後変動効果
	_apply_after_battle_changes(attacker_tile_index)
	_apply_after_battle_changes(defender_tile_index)
	
	battle_ended.emit(attacker_tile_index, defender_tile_index, result)
```

### GameFlowManager への統合

**周回カウントの追加**:

```gdscript
signal lap_completed(player_id: int)

func check_lap_completion(player_id: int, new_tile_index: int):
	# ゴール通過判定
	if new_tile_index == 0 and old_tile_index > 0:
		_on_player_lap_completed(player_id)

func _on_player_lap_completed(player_id: int):
	# 全クリーチャーに周回ボーナスを適用
	for tile in board_system.get_player_tiles(player_id):
		if tile.creature_data:
			_apply_lap_bonus_to_creature(tile.creature_data)
	
	lap_completed.emit(player_id)
```

---

## 実装時の重要な注意事項

### ⚠️ operation="set" の正しい実装

**間違った実装**:
```gdscript
# ❌ これは間違い
participant.current_ap = land_count * 10
```

**正しい実装**:
```gdscript
# ✅ base_ap を上書きして、その後に通常のボーナスを加算
participant.base_ap = land_count * 10  # 基礎値を上書き
# その後、土地ボーナス、アイテム、スペル、感応は通常通り加算される
participant.current_ap = participant.base_ap + land_bonus_hp + item_bonus_ap + ...
```

**重要**: `operation="set"` は基礎値の上書きであり、最終値の上書きではない。

---

### ⚠️ 破壊数カウンターの実装場所

**グローバルカウンター**（ソウルコレクター用）:
```gdscript
# GameFlowManager または GameData
var game_data = {
    "total_creatures_destroyed": 0  # 全プレイヤーの累計
}

# バトル勝利時、スペルでの破壊時
func on_creature_destroyed():
    game_data["total_creatures_destroyed"] += 1
```

**クリーチャー固有カウンター**（将来の拡張用）:
```gdscript
creature_data["destroy_count"] = 0  # このクリーチャーが破壊した数
```

---

### ⚠️ 永続バフのリセットを忘れずに

以下の処理で必ず `reset_permanent_buffs()` を呼ぶ:
1. 交換コマンド実行時
2. クリーチャー破壊時
3. 変身効果適用時
4. 墓地から手札に戻す時

```gdscript
func reset_permanent_buffs(creature_data: Dictionary):
    creature_data["base_up_hp"] = 0
    creature_data["base_up_ap"] = 0
    creature_data["map_lap_count"] = 0
    creature_data["destroy_count"] = 0
    # その他の永続フラグもリセット
    creature_data.erase("bairomancer_triggered")
```

---

### ⚠️ 一時バフと永続バフの適用場所

**一時バフ（バトル準備時に計算）**:
```gdscript
# BattleSkillProcessor.apply_conditional_buffs()
participant.temporary_bonus_hp += calculated_value
participant.temporary_bonus_ap += calculated_value
```

**永続バフ（イベント時に直接変更）**:
```gdscript
# BattleSystem.on_battle_win(), GameFlowManager.on_lap_complete() など
tile.creature_data["base_up_hp"] += 10
tile.creature_data["base_up_ap"] += 10
```

---

### ⚠️ 一時バフの計算順序（推奨）

```gdscript
func apply_conditional_buffs(participant: BattleParticipant, context: Dictionary):
    # 1. 常時補正（最優先）
    apply_constant_stat_bonuses(participant)
    
    # 2. 配置数比例
    apply_land_count_effects(participant, context)
    
    # 3. 領地条件
    apply_owned_land_count_bonuses(participant, context.player_id)
    apply_adjacent_land_bonuses(participant, context.tile_index, context)
    apply_battle_land_level_bonus(participant, context)
    
    # 4. 手札・ブック条件
    apply_hand_count_effects(participant, context.player_id)
    apply_deck_comparison_effects(participant, context.player_id, context.enemy_id)
    
    # 5. 戦闘地・敵属性条件
    apply_battle_land_element_conditions(participant, context)
    
    # 6. ラウンド・ダイス条件
    apply_round_number_effects(participant, context.current_round)
    apply_dice_condition_bonuses(participant, context.dice_value)
    
    # 7. 破壊数カウント
    apply_destroy_count_effects(participant, context)
    
    # 8. 防御時条件
    if participant.is_defender:
        apply_defensive_stat_overrides(participant)
```

---

### ⚠️ MHP上限チェック（ブラッドプリン）

```gdscript
# 援護発動時
var support_mhp = support_creature_data["hp"] + support_creature_data.get("base_up_hp", 0)
var current_mhp = creature_data["hp"] + creature_data.get("base_up_hp", 0)

# MHP 100 を超えないように制限
var max_increase = 100 - current_mhp
var actual_increase = min(support_mhp, max_increase)

if actual_increase > 0:
    creature_data["base_up_hp"] += actual_increase
```

---

### ⚠️ フラグ管理（バイロマンサー）

```gdscript
# バトル終了時、1回のみ発動
if not creature_data.get("bairomancer_triggered", false):
    if is_defender and battle_lost and enemy_took_land:
        creature_data["base_ap"] = 20
        creature_data["base_up_hp"] -= 30
        creature_data["bairomancer_triggered"] = true
```

**注意**: フラグも手札に戻った時にリセットが必要

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/26 | 1.0 | 初版作成 - conditional_stat_buffs.md と effect_system.md を統合 |
| 2025/10/26 | 1.1 | 永続バフと一時バフの分類を追加、9体の永続バフクリーチャーを明確化 |
| 2025/10/26 | 1.2 | 質問13件の回答を反映、個別クリーチャーの詳細仕様と実装時の注意事項を追加 |

---

**最終更新**: 2025年10月26日（v1.2）
