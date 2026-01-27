# ステージクリアシステム設計書

## 概要

ステージクリア時の判定、報酬、記録を管理するシステム。

---

## クリアフロー

```
勝利条件達成（TEP達成 + チェックポイント通過）
    ↓
クリア演出（WIN表示 + クリック待ち）
    ↓
リザルト画面
  - クリアランク表示（SS/S/A/B/C）
  - ゴールド報酬表示
  - クリック待ち
    ↓
データ保存
  - ステージクリア記録
  - ランク記録（最高ランク保持）
  - ゴールド加算
    ↓
タイトルへ戻る
```

---

## ランク判定

### ターン数によるランク

| ランク | ターン数 | 備考 |
|--------|----------|------|
| SS | 14以下 | 最高ランク |
| S | 15〜19 | |
| A | 20〜24 | |
| B | 25〜29 | |
| C | 30以上 | 最低ランク |

### 拡張性

将来的に以下の判定基準も追加可能な設計とする：
- TEP達成率
- クリーチャー破壊数
- 被ダメージ量
- 残りHP合計
- etc.

---

## 報酬システム

### 報酬種別

| 条件 | 報酬内容 |
|------|----------|
| **初回クリア** | ステージ報酬 + ランクボーナス |
| **2回目以降** | ステージ報酬 × 20%（切り上げ） |

※ランクボーナスは初回クリア時のみ

### 報酬計算

```gdscript
# 初回クリア
total = stage_gold + rank_bonus[rank]

# 2回目以降
total = ceil(stage_gold * 0.2)
```

### ランクボーナス（ステージJSONで定義）

| ランク | ボーナス例 |
|--------|------------|
| SS | 500G |
| S | 300G |
| A | 200G |
| B | 100G |
| C | 0G |

---

## データ構造

### ステージJSON（rewards追加）

```json
{
  "id": "stage_1_1",
  "name": "はじまりの草原",
  "map_id": "standard",
  "rule_preset": "standard",
  "rewards": {
    "gold": 1000,
    "rank_bonus": {
      "SS": 500,
      "S": 300,
      "A": 200,
      "B": 100,
      "C": 0
    }
  },
  "quest": {
    "enemies": [...]
  }
}
```

### プレイヤーセーブデータ

```json
{
  "stage_records": {
    "stage_1_1": {
      "cleared": true,
      "best_rank": "S",
      "best_turn": 15,
      "clear_count": 3
    },
    "stage_1_2": {
      "cleared": true,
      "best_rank": "A",
      "best_turn": 22,
      "clear_count": 1
    }
  },
  "gold": 50000
}
```

---

## リザルト画面

### 初回クリア時

```
┌─────────────────────────────┐
│                             │
│      ステージクリア！        │
│                             │
│    クリアランク: S          │
│    クリアターン: 15         │
│                             │
│    ───────────────         │
│    報酬:                    │
│      初回クリア報酬  1000G  │
│      ランクボーナス   300G  │
│    ───────────────         │
│      合計          1300G   │
│                             │
│      [ タップで続ける ]      │
│                             │
└─────────────────────────────┘
```

### 2回目以降

```
┌─────────────────────────────┐
│                             │
│      ステージクリア！        │
│                             │
│    クリアランク: A          │
│    クリアターン: 22         │
│    ベストランク: S (15T)    │
│                             │
│    ───────────────         │
│    報酬:                    │
│      クリア報酬      200G   │
│    ───────────────         │
│      合計           200G   │
│                             │
│      [ タップで続ける ]      │
│                             │
└─────────────────────────────┘
```

---

## 実装ファイル

| ファイル | 役割 |
|----------|------|
| `scripts/game_result/rank_calculator.gd` | ランク計算（拡張可能） |
| `scripts/game_result/result_screen.gd` | リザルト画面UI |
| `scripts/game_result/reward_calculator.gd` | 報酬計算 |
| `scripts/save_data/stage_record_manager.gd` | ステージ記録管理 |

---

## 処理フロー詳細

### 1. 勝利判定時（LapSystem）

```gdscript
# _check_win_condition() で勝利確定後
player_system.emit_signal("player_won", player_id)
```

### 2. 勝利処理（GameFlowManager）

```gdscript
func on_player_won(player_id: int):
    # 1. クリア演出
    await ui_manager.show_win_screen(player_id)
    
    # 2. リザルト処理
    var result_data = _calculate_result(player_id)
    await _show_result_screen(result_data)
    
    # 3. データ保存
    _save_stage_record(result_data)
    
    # 4. タイトルへ
    _return_to_title()
```

### 3. ランク計算（RankCalculator）

```gdscript
class_name RankCalculator

const RANK_THRESHOLDS = {
    "SS": 14,
    "S": 19,
    "A": 24,
    "B": 29,
    # C は 30以上
}

static func calculate_rank(turn_count: int) -> String:
    if turn_count <= RANK_THRESHOLDS["SS"]:
        return "SS"
    elif turn_count <= RANK_THRESHOLDS["S"]:
        return "S"
    elif turn_count <= RANK_THRESHOLDS["A"]:
        return "A"
    elif turn_count <= RANK_THRESHOLDS["B"]:
        return "B"
    else:
        return "C"

# 拡張用：複合判定
static func calculate_rank_extended(context: Dictionary) -> String:
    var turn_count = context.get("turn_count", 999)
    # 将来的に他の要素も加味
    # var tep_ratio = context.get("tep_ratio", 0.0)
    # var destroy_count = context.get("destroy_count", 0)
    return calculate_rank(turn_count)
```

### 4. 報酬計算（RewardCalculator）

```gdscript
class_name RewardCalculator

static func calculate_rewards(stage_data: Dictionary, rank: String, is_first_clear: bool) -> Dictionary:
    var rewards = stage_data.get("rewards", {})
    var base_gold = rewards.get("gold", 0)
    var rank_bonus_table = rewards.get("rank_bonus", {})
    
    var result = {
        "base_gold": 0,
        "rank_bonus": 0,
        "total": 0,
        "is_first_clear": is_first_clear
    }
    
    if is_first_clear:
        result.base_gold = base_gold
        result.rank_bonus = rank_bonus_table.get(rank, 0)
    else:
        result.base_gold = int(ceil(base_gold * 0.2))
        result.rank_bonus = 0
    
    result.total = result.base_gold + result.rank_bonus
    return result
```

---

## 称号システム（将来実装）

ステージ記録を参照して称号を付与する。

### 称号例

| 称号 | 条件 |
|------|------|
| 初心者セプター | ステージ1クリア |
| ベテランセプター | 全ステージクリア |
| スピードスター | 任意のステージをSSクリア |
| マスターセプター | 全ステージSSクリア |

### 判定用インターフェース

```gdscript
# StageRecordManager
func get_all_cleared_stages() -> Array
func get_best_rank(stage_id: String) -> String
func get_ss_count() -> int
func is_all_cleared() -> bool
func is_all_ss() -> bool
```

---

## 実装タスク

### Phase 1: 基盤クラス作成

- [ ] `scripts/game_result/rank_calculator.gd`
  - [ ] `calculate_rank(turn_count: int) -> String`
  - [ ] `calculate_rank_extended(context: Dictionary) -> String`（拡張用）
  - [ ] 定数 `RANK_THRESHOLDS`

- [ ] `scripts/game_result/reward_calculator.gd`
  - [ ] `calculate_rewards(stage_data, rank, is_first_clear) -> Dictionary`
  - [ ] 2回目以降の20%計算（切り上げ）

- [ ] `scripts/save_data/stage_record_manager.gd`
  - [ ] `load_records() -> Dictionary`
  - [ ] `save_records(records: Dictionary)`
  - [ ] `get_record(stage_id: String) -> Dictionary`
  - [ ] `update_record(stage_id, rank, turn_count)`
  - [ ] `is_first_clear(stage_id: String) -> bool`
  - [ ] `get_best_rank(stage_id: String) -> String`
  - [ ] セーブファイルパス: `user://stage_records.json`

### Phase 2: UI作成

- [ ] `scripts/game_result/result_screen.gd`
  - [ ] リザルト画面UI構築
  - [ ] ランク表示（SS/S/A/B/C）
  - [ ] 報酬内訳表示
  - [ ] 初回/2回目以降の表示切り替え
  - [ ] ベストランク表示（2回目以降）
  - [ ] クリック待ち処理
  - [ ] シグナル: `result_confirmed`

### Phase 3: 統合

- [ ] `scripts/game_flow_manager.gd` 修正
  - [ ] `on_player_won()` を非同期化
  - [ ] クリア演出後にリザルト画面表示
  - [ ] データ保存処理追加
  - [ ] タイトルへ戻る処理

- [ ] `scripts/ui_manager.gd` 修正
  - [ ] `show_win_screen()` をクリック待ち対応に

- [ ] ステージJSON更新
  - [ ] `rewards` フィールド追加（既存ステージ全て）

### Phase 4: ゴールド連携

- [ ] `scripts/game_data.gd` または該当ファイル
  - [ ] 報酬ゴールドを所持金に加算
  - [ ] セーブ処理

---

## 実装メモ

### ターン数の取得

```gdscript
# GameFlowManager で管理されているターン数
var turn_count = game_flow_manager.turn_count
```

### ステージIDの取得

```gdscript
# QuestGame から取得
var stage_id = quest_game.current_stage_id

# または StageLoader から
var stage_id = stage_loader.current_stage_data.get("id", "")
```

### セーブデータ形式

```json
{
  "version": 1,
  "stage_records": {
    "stage_1_1": {
      "cleared": true,
      "best_rank": "S",
      "best_turn": 15,
      "clear_count": 3,
      "first_clear_date": "2026-01-27T12:00:00"
    }
  }
}
```

### リザルト画面の表示データ

```gdscript
var result_data = {
    "stage_id": "stage_1_1",
    "stage_name": "はじまりの草原",
    "turn_count": 15,
    "rank": "S",
    "is_first_clear": true,
    "best_rank": null,  # 初回はnull
    "best_turn": null,
    "rewards": {
        "base_gold": 1000,
        "rank_bonus": 300,
        "total": 1300,
        "is_first_clear": true
    }
}
```

### タイトルへ戻る処理

```gdscript
func _return_to_title():
    # シーン遷移
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
    # または
    get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")
```

---

## テスト項目

### ランク判定

- [ ] ターン14以下 → SS
- [ ] ターン15〜19 → S
- [ ] ターン20〜24 → A
- [ ] ターン25〜29 → B
- [ ] ターン30以上 → C

### 報酬計算

- [ ] 初回クリア: base_gold + rank_bonus
- [ ] 2回目以降: ceil(base_gold * 0.2)
- [ ] ランクボーナスは初回のみ

### セーブ/ロード

- [ ] 初回クリア時に記録作成
- [ ] 2回目以降で記録更新（ベスト更新時のみ）
- [ ] clear_count インクリメント
- [ ] アプリ再起動後も記録が残る

### UI

- [ ] 初回クリア時の表示
- [ ] 2回目以降の表示（ベストランク表示）
- [ ] ランク更新時の表示
- [ ] クリック待ち → タイトルへ遷移

---

## 進捗状況

| フェーズ | 項目 | ステータス |
|----------|------|-----------|
| 設計 | 設計書作成 | ✅ 完了 |
| Phase 1 | RankCalculator | ⬜ 未実装 |
| Phase 1 | RewardCalculator | ⬜ 未実装 |
| Phase 1 | StageRecordManager | ⬜ 未実装 |
| Phase 2 | ResultScreen | ⬜ 未実装 |
| Phase 3 | GameFlowManager統合 | ⬜ 未実装 |
| Phase 3 | UIManager修正 | ⬜ 未実装 |
| Phase 3 | ステージJSON更新 | ⬜ 未実装 |
| Phase 4 | ゴールド連携 | ⬜ 未実装 |
| テスト | 全項目確認 | ⬜ 未実施 |

---

## DB移行設計（将来計画）

### 現状のデータ管理

| データ | 現在の方式 | 場所 | 問題点 |
|--------|-----------|------|--------|
| カード所持 | SQLite | UserCardDB | ✅ OK |
| ゴールド | JSON | GameData.player_data.profile.gold | ファイル改ざん可能 |
| デッキ | JSON | GameData.player_data.decks | 同上 |
| ステージ記録 | JSON | GameData.player_data.story_progress | 同上 |
| 統計情報 | JSON | GameData.player_data.stats | 同上 |
| 設定 | JSON | GameData.player_data.settings | ローカルでOK |

### 目標のDB構造

```sql
-- ユーザー基本情報
CREATE TABLE users (
  user_id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT 'プレイヤー',
  gold INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  exp INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  last_played TEXT
);

-- ステージ記録
CREATE TABLE stage_records (
  user_id TEXT NOT NULL,
  stage_id TEXT NOT NULL,
  cleared INTEGER NOT NULL DEFAULT 0,
  best_rank TEXT,
  best_turn INTEGER,
  clear_count INTEGER NOT NULL DEFAULT 0,
  first_clear_date TEXT,
  PRIMARY KEY (user_id, stage_id),
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- デッキ
CREATE TABLE decks (
  user_id TEXT NOT NULL,
  deck_index INTEGER NOT NULL,
  name TEXT NOT NULL,
  PRIMARY KEY (user_id, deck_index),
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- デッキ内カード
CREATE TABLE deck_cards (
  user_id TEXT NOT NULL,
  deck_index INTEGER NOT NULL,
  card_id INTEGER NOT NULL,
  count INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, deck_index, card_id),
  FOREIGN KEY (user_id, deck_index) REFERENCES decks(user_id, deck_index)
);

-- 統計情報
CREATE TABLE user_stats (
  user_id TEXT PRIMARY KEY,
  total_battles INTEGER NOT NULL DEFAULT 0,
  wins INTEGER NOT NULL DEFAULT 0,
  losses INTEGER NOT NULL DEFAULT 0,
  play_time_seconds INTEGER NOT NULL DEFAULT 0,
  story_cleared INTEGER NOT NULL DEFAULT 0,
  gacha_count INTEGER NOT NULL DEFAULT 0,
  cards_obtained INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);
```

### マネージャークラス設計

DB移行後もインターフェースを変えずに使えるよう、抽象化レイヤーを設ける。

```
SaveDataManager（統括）
  ├── UserManager          # users テーブル
  │     ├── get_gold() -> int
  │     ├── add_gold(amount: int)
  │     ├── spend_gold(amount: int) -> bool
  │     ├── get_level() -> int
  │     └── add_exp(amount: int)
  │
  ├── StageRecordManager   # stage_records テーブル
  │     ├── get_record(stage_id) -> Dictionary
  │     ├── update_record(stage_id, rank, turn_count)
  │     ├── is_first_clear(stage_id) -> bool
  │     ├── is_cleared(stage_id) -> bool
  │     ├── get_best_rank(stage_id) -> String
  │     └── get_all_cleared_stages() -> Array
  │
  ├── DeckManager          # decks + deck_cards テーブル
  │     ├── get_deck(index) -> Dictionary
  │     ├── save_deck(index, cards)
  │     ├── get_deck_name(index) -> String
  │     └── set_deck_name(index, name)
  │
  ├── StatsManager         # user_stats テーブル
  │     ├── record_battle_result(won: bool)
  │     ├── get_win_rate() -> float
  │     └── add_play_time(seconds: int)
  │
  └── UserCardDB（既存）    # user_cards テーブル
        ├── get_card_count(card_id) -> int
        ├── add_card(card_id, count)
        └── remove_card(card_id, count)
```

### 移行の影響範囲

**GameData.player_data への直接アクセス箇所：**

| ファイル | 箇所 | 内容 |
|----------|------|------|
| `scripts/shop.gd` | 3箇所 | gold読み書き |
| `scripts/main_menu.gd` | 4箇所 | name, gold, decks |
| `scripts/gacha_system.gd` | 4箇所 | gold読み書き |
| `scripts/album.gd` | 2箇所 | decks |
| `scripts/deck_editor.gd` | 2箇所 | decks |
| `scripts/quest/quest_select.gd` | 1箇所 | decks |

**合計：** 約16箇所（修正は比較的容易）

### 移行手順案

```
Phase 1: 基盤整備
  ├── SaveDataManager 作成（空の統括クラス）
  ├── UserManager 作成（内部はJSON、インターフェース固定）
  └── StageRecordManager 作成（内部はJSON、インターフェース固定）

Phase 2: ステージクリア機能実装
  ├── StageRecordManager を使用
  └── リザルト画面等の実装

Phase 3: DB移行（別タスク）
  ├── SQLiteテーブル作成
  ├── UserManager の内部をDB化
  ├── StageRecordManager の内部をDB化
  ├── DeckManager 作成・DB化
  ├── StatsManager 作成・DB化
  └── GameData.player_data への直接アクセスを修正

Phase 4: サーバーDB対応（将来）
  ├── 認証システム追加
  ├── API経由でのデータ同期
  └── ローカルキャッシュ + サーバー同期
```

### 今回の実装方針

**Phase 1 + Phase 2 を実施：**

1. `StageRecordManager` を作成
   - インターフェースはDB対応設計
   - 内部実装は暫定的にJSON（GameData経由）
   
2. 将来のDB移行時は内部実装のみ差し替え
   - 呼び出し側の修正不要

**JSONでの暫定実装：**

```gdscript
# scripts/save_data/stage_record_manager.gd
class_name StageRecordManager

# GameData.player_data.story_progress.stage_records を使用
# {
#   "stage_1_1": {
#     "cleared": true,
#     "best_rank": "S",
#     "best_turn": 15,
#     "clear_count": 3,
#     "first_clear_date": "2026-01-27T12:00:00"
#   }
# }

static func _get_records() -> Dictionary:
    if not GameData.player_data.story_progress.has("stage_records"):
        GameData.player_data.story_progress["stage_records"] = {}
    return GameData.player_data.story_progress.stage_records

static func get_record(stage_id: String) -> Dictionary:
    var records = _get_records()
    return records.get(stage_id, {})

static func is_first_clear(stage_id: String) -> bool:
    return not get_record(stage_id).get("cleared", false)

static func is_cleared(stage_id: String) -> bool:
    return get_record(stage_id).get("cleared", false)

static func get_best_rank(stage_id: String) -> String:
    return get_record(stage_id).get("best_rank", "")

static func get_best_turn(stage_id: String) -> int:
    return get_record(stage_id).get("best_turn", 0)

static func get_clear_count(stage_id: String) -> int:
    return get_record(stage_id).get("clear_count", 0)

static func update_record(stage_id: String, rank: String, turn_count: int) -> void:
    var records = _get_records()
    var is_first = not records.has(stage_id) or not records[stage_id].get("cleared", false)
    
    if not records.has(stage_id):
        records[stage_id] = {}
    
    var record = records[stage_id]
    
    # 初回クリア
    if is_first:
        record["cleared"] = true
        record["first_clear_date"] = Time.get_datetime_string_from_system()
        record["clear_count"] = 1
        record["best_rank"] = rank
        record["best_turn"] = turn_count
    else:
        record["clear_count"] = record.get("clear_count", 0) + 1
        # ベスト更新判定（ターン数が少ない方が良い）
        var current_best_turn = record.get("best_turn", 999)
        if turn_count < current_best_turn:
            record["best_rank"] = rank
            record["best_turn"] = turn_count
    
    GameData.save_to_file()

static func get_all_cleared_stages() -> Array:
    var result = []
    var records = _get_records()
    for stage_id in records.keys():
        if records[stage_id].get("cleared", false):
            result.append(stage_id)
    return result
```

---

## 関連ドキュメント

- [クエストシステム設計](quest_system_design.md)
- [オンラインルール設計](online_rules_design.md)
- [用語統一](../refactoring/terminology_unification.md)
- [データベース設計](database_design.md)

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2026/01/27 | 1.0 | 初版作成 |
| 2026/01/27 | 1.1 | DB移行設計を追加 |