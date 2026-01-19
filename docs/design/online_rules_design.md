# オンラインルール設計書

**バージョン**: 1.1  
**最終更新**: 2025年1月20日  
**ステータス**: 実装中

---

## 📋 目次

1. [概要](#概要)
2. [プリセット一覧](#プリセット一覧)
3. [勝利条件タイプ](#勝利条件タイプ)
4. [カード制限](#カード制限)
5. [JSONスキーマ](#jsonスキーマ)
6. [game_constants.gd との対応](#game_constantsgd-との対応)
7. [実装状況](#実装状況)

---

## 概要

### 目的

オンライン対戦とソロクエストで共通のルール設計を定義する。
ルール設定は `game_constants.gd` でプリセットとして管理し、JSON（ステージ/対戦ルーム）からプリセット名で参照する。

### 設計方針

| 方針 | 説明 |
|------|------|
| プリセット参照 | JSONはプリセット名を指定、実際の値は `game_constants.gd` から取得 |
| 上書き可能 | 必要に応じて `rule_overrides` でカスタム値を指定可能 |
| 共通化 | ソロクエスト/オンライン対戦で同じルールシステムを使用 |

### 適用フロー

```
game_constants.gd（プリセット定義）
    ↓
マップJSON / ステージJSON（プリセット名で参照）
    ↓
rule_overrides（オプション：カスタム値で上書き）
    ↓
StageLoader（プリセット取得・適用）
    ↓
ゲーム実行
```

---

## プリセット一覧

### RULE_PRESETS（ルールプリセット）

ゲームの基本ルールを定義。

| プリセット名 | 初期魔力 | 勝利条件 | 用途 |
|-------------|---------|---------|------|
| `standard` | 1000 | 魔力8000以上（チェックポイント） | 通常対戦 |
| `quick` | 2000 | 魔力4000以上（チェックポイント） | 短時間対戦 |
| `elimination` | 1000 | 敵を破産させる | サバイバル戦 |
| `territory` | 1000 | 領地10個以上（チェックポイント） | 領地争奪戦 |

```gdscript
const RULE_PRESETS = {
    "standard": {
        "initial_magic": 1000,
        "win_conditions": {
            "mode": "all",
            "conditions": [
                {"type": "magic", "target": 8000, "timing": "checkpoint"}
            ]
        }
    },
    "quick": {
        "initial_magic": 2000,
        "win_conditions": {
            "mode": "all",
            "conditions": [
                {"type": "magic", "target": 4000, "timing": "checkpoint"}
            ]
        }
    },
    "elimination": {
        "initial_magic": 1000,
        "win_conditions": {
            "mode": "any",
            "conditions": [
                {"type": "bankrupt_enemy", "timing": "immediate"}
            ]
        }
    },
    "territory": {
        "initial_magic": 1000,
        "win_conditions": {
            "mode": "all",
            "conditions": [
                {"type": "territories", "target": 10, "timing": "checkpoint"}
            ]
        }
    }
}
```

---

### LAP_BONUS_PRESETS（周回ボーナスプリセット）

周回完了時とチェックポイント通過時のボーナスを定義。

| プリセット名 | 周回ボーナス | CP通過ボーナス | 用途 |
|-------------|-------------|---------------|------|
| `low` | 80 | 50 | 低インフレマップ |
| `standard` | 120 | 100 | 通常マップ |
| `high` | 200 | 150 | 高インフレマップ |
| `very_high` | 300 | 200 | 超高速マップ |

```gdscript
const LAP_BONUS_PRESETS = {
    "low": {
        "lap_bonus": 80,
        "checkpoint_bonus": 50
    },
    "standard": {
        "lap_bonus": 120,
        "checkpoint_bonus": 100
    },
    "high": {
        "lap_bonus": 200,
        "checkpoint_bonus": 150
    },
    "very_high": {
        "lap_bonus": 300,
        "checkpoint_bonus": 200
    }
}
```

---

### CHECKPOINT_PRESETS（チェックポイントプリセット）

周回完了に必要なチェックポイントを定義。

| プリセット名 | 必要CP | 用途 |
|-------------|--------|------|
| `standard` | N, S | 2箇所（対角線） |
| `three_way` | N, S, W | 3箇所 |
| `three_way_alt` | N, E, W | 3箇所（別配置） |
| `four_way` | N, S, W, E | 4箇所（全方位） |

```gdscript
const CHECKPOINT_PRESETS = {
    "standard": ["N", "S"],
    "three_way": ["N", "S", "W"],
    "three_way_alt": ["N", "E", "W"],
    "four_way": ["N", "S", "W", "E"]
}
```

---

## 勝利条件タイプ

### 一覧

| type | target | timing | 説明 |
|------|--------|--------|------|
| `magic` | 数値 | `checkpoint` | 総魔力がtarget以上 |
| `laps` | 数値 | `checkpoint` | 周回数がtarget以上 |
| `territories` | 数値 | `checkpoint` | 領地数がtarget以上 |
| `enemy_no_territory` | - | `checkpoint` | 敵が領地0 |
| `bankrupt_enemy` | - | `immediate` | 敵を破産させる |
| `destroy` | 数値 | `immediate` | 敵クリーチャー撃破数がtarget以上 |
| `toll_single` | 数値 | `immediate` | 1回の通行料でtarget以上獲得 |
| `toll_total` | 数値 | `immediate` | 累計通行料がtarget以上 |
| `toll_count` | 数値 | `immediate` | 通行料徴収回数がtarget以上 |
| `survive` | ターン数 | `turn_end` | 指定ターン生存 |
| `battle_win` | 数値 | `immediate` | バトル勝利数がtarget以上 |

---

### 判定タイミング

| timing | 説明 | 例 |
|--------|------|-----|
| `checkpoint` | チェックポイント通過時に判定 | magic, territories, enemy_no_territory |
| `immediate` | イベント発生時に即判定 | bankrupt_enemy, toll_single, destroy |
| `turn_end` | ターン終了時に判定 | survive |

---

### 複合条件

#### mode: "all"（AND条件）

すべての条件を満たした時に勝利。

```json
{
    "mode": "all",
    "conditions": [
        {"type": "magic", "target": 8000, "timing": "checkpoint"},
        {"type": "enemy_no_territory", "timing": "checkpoint"}
    ]
}
```

**例**: 魔力8000以上 **かつ** 敵が領地0

#### mode: "any"（OR条件）

いずれかの条件を満たした時に勝利。

```json
{
    "mode": "any",
    "conditions": [
        {"type": "magic", "target": 8000, "timing": "checkpoint"},
        {"type": "bankrupt_enemy", "timing": "immediate"}
    ]
}
```

**例**: 魔力8000以上 **または** 敵を破産

---

## カード制限

オンライン対戦で使用可能/禁止カードを指定。全プレイヤーに適用。

### 指定方法

| mode | 説明 |
|------|------|
| `whitelist` | 指定カードのみ使用可能 |
| `blacklist` | 指定カードは使用禁止 |

### JSON例

```json
"card_restrictions": {
    "mode": "blacklist",
    "card_ids": [999, 888, 777]
}
```

```json
"card_restrictions": {
    "mode": "whitelist",
    "card_ids": [1, 2, 3, 4, 5, 10, 11, 12]
}
```

### 制限なし

```json
"card_restrictions": null
```

---

## JSONスキーマ

### マップJSON

```json
{
    "id": "map_diamond_20",
    "name": "ダイヤモンド型",
    "description": "基本の20マスマップ",
    "tile_count": 20,
    "loop_size": 20,
    "tiles": [
        {"index": 0, "type": "Checkpoint", "x": 0, "z": 0, "checkpoint_type": "N"},
        {"index": 1, "type": "Neutral", "x": 4, "z": 0}
    ],
    "connections": {
        "0": [1, 19, 20]
    },
    "lap_bonus_preset": "standard",
    "checkpoint_preset": "standard"
}
```

---

### ステージJSON（ソロクエスト用）

```json
{
    "id": "stage_quest_4p",
    "name": "4人クエストテスト",
    "description": "プレイヤー1名 + CPU3名のクエストテスト",
    "map_id": "map_diamond_20",
    
    "rule_preset": "standard",
    "rule_overrides": {
        "initial_magic": {"player": 1000, "cpu": 1000}
    },
    
    "quest": {
        "enemies": [
            {
                "character_id": "bowser",
                "deck_id": "skills_test",
                "ai_level": 3,
                "start_tile": 0
            },
            {
                "character_id": "bowser",
                "deck_id": "balance_easy",
                "ai_level": 3,
                "start_tile": 0
            },
            {
                "character_id": "bowser",
                "deck_id": "random",
                "ai_level": 3,
                "start_tile": 0
            }
        ],
        "rewards": {
            "first_clear": {"type": "gold", "amount": 1000},
            "repeat": {"type": "gold", "amount": 200}
        }
    }
}
```

---

### オンライン対戦ルームJSON（将来実装）

```json
{
    "room_id": "abc123",
    "map_id": "map_diamond_20",
    "rule_preset": "standard",
    "rule_overrides": {
        "initial_magic": 2000
    },
    "card_restrictions": {
        "mode": "blacklist",
        "card_ids": [999]
    },
    "players": [
        {"player_id": 0, "type": "human", "user_id": "user_A"},
        {"player_id": 1, "type": "human", "user_id": "user_B"},
        {"player_id": 2, "type": "cpu", "ai_level": 5}
    ],
    "max_players": 4
}
```

---

## game_constants.gd との対応

### 配置方針

| 設定 | 配置場所 | 備考 |
|------|----------|------|
| `CHAIN_BONUS_*` | game_constants.gd のみ | 全マップ共通、固定値 |
| `TOLL_LEVEL_MULTIPLIER` | game_constants.gd のみ | 全マップ共通、固定値 |
| `RULE_PRESETS` | game_constants.gd | JSONからプリセット名で参照 |
| `LAP_BONUS_PRESETS` | game_constants.gd | JSONからプリセット名で参照 |
| `CHECKPOINT_PRESETS` | game_constants.gd | JSONからプリセット名で参照 |

### 取得関数

```gdscript
# game_constants.gd

static func get_initial_magic(preset_name: String) -> int:
    var preset = RULE_PRESETS.get(preset_name, RULE_PRESETS["standard"])
    return preset.get("initial_magic", 1000)

static func get_win_conditions(preset_name: String) -> Dictionary:
    var preset = RULE_PRESETS.get(preset_name, RULE_PRESETS["standard"])
    return preset.get("win_conditions", {})

static func get_lap_bonus(preset_name: String) -> int:
    var preset = LAP_BONUS_PRESETS.get(preset_name, LAP_BONUS_PRESETS["standard"])
    return preset.get("lap_bonus", 120)

static func get_checkpoint_bonus(preset_name: String) -> int:
    var preset = LAP_BONUS_PRESETS.get(preset_name, LAP_BONUS_PRESETS["standard"])
    return preset.get("checkpoint_bonus", 100)

static func get_required_checkpoints(preset_name: String) -> Array:
    return CHECKPOINT_PRESETS.get(preset_name, CHECKPOINT_PRESETS["standard"])
```

---

## 実装状況

### ✅ 実装済み

- [x] game_constants.gd にプリセット定義追加
  - [x] RULE_PRESETS
  - [x] LAP_BONUS_PRESETS
  - [x] CHECKPOINT_PRESETS
- [x] プリセット取得関数
- [x] StageLoader でプリセット読み込み対応
- [x] rule_overrides の適用処理
- [x] マップJSON 7種類（プリセット参照形式）
- [x] ステージJSON 10種類（プリセット参照形式）
- [x] 旧形式との後方互換性

### 🚧 未実装

- [ ] 勝利条件システム（WinConditionChecker）
- [ ] カード制限システム（CardRestrictionChecker）
- [ ] オンライン対戦ルーム

---

## 関連ドキュメント

- [マップシステム仕様](map_system.md) - 地形・タイル・移動の仕様
- [クエストシステム設計](quest_system_design.md) - ソロクエスト専用の仕様
- [CPU AI設計](cpu_ai/cpu_ai_design.md) - CPUの行動ロジック

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2025/01/19 | 初版作成 |
| 1.1 | 2025/01/20 | 実装状況更新、取得関数の例を追加 |
