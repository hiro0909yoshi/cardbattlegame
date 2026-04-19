# ミッションシステム設計書

**作成日**: 2026-04-18
**ステータス**: 実装中

---

## 概要

プレイヤーの行動に対して報酬を与えるミッションシステム。
デイリー / ウィークリー / 永続の3カテゴリで構成する。

**設計方針:**
- 条件は行動ベースのみ（カードコンプリート系は景品表示法に抵触するため不可）
- メインメニュー右上の既存アイコン列（DailyQuestButton）に接続
- 報酬はゴールド / ジェム / アイテム

---

## カテゴリ

| カテゴリ | リセット | 説明 |
|---------|---------|------|
| デイリー | 毎日 04:00 JST | 毎日リセットされる軽いミッション |
| ウィークリー | 毎週月曜 04:00 JST | 週単位のやや重いミッション |
| 永続 | なし | 累計達成で1回のみ受け取れるミッション |

---

## 条件タイプ

| 条件タイプ | 説明 | 記録元 |
|-----------|------|--------|
| `quest_play` | クエストプレイ回数 | `stats.quest.plays` |
| `quest_clear` | クエストクリア回数 | `stats.quest.clears` |
| `creature_battle` | クリーチャーバトル回数 | `stats.quest.battles` + `stats.net_battle.battles` |
| `creature_summon` | クリーチャー召喚回数 | `stats.quest.creature_summons` |
| `spell_use` | スペル使用回数 | `stats.quest.spell_uses` |
| `gacha_pull` | ガチャを引いた回数 | `stats.gacha_count` |
| `gold_earn` | ゴールド獲得累計 | `stats.total_gold_earned`（新規追加） |
| `login` | ログイン日数 | `stats.login_days`（新規追加） |

---

## 報酬タイプ

| タイプ | キー | 説明 |
|-------|------|------|
| ゴールド | `gold` | `GameData.add_gold(amount)` |
| ジェム | `stone` | `GameData.add_stone(amount)` |

---

## ミッション定義データ

**ファイル**: `data/missions.json`

```json
{
  "daily": [
    {
      "id": "d001",
      "title": "クエストに挑戦",
      "description": "クエストを1回プレイする",
      "condition": {
        "type": "quest_play",
        "target": 1
      },
      "reward": {
        "type": "gold",
        "amount": 500
      }
    }
  ],
  "weekly": [
    {
      "id": "w001",
      "title": "週間クエストマスター",
      "description": "クエストを10回クリアする",
      "condition": {
        "type": "quest_clear",
        "target": 10
      },
      "reward": {
        "type": "gold",
        "amount": 5000
      }
    }
  ],
  "permanent": [
    {
      "id": "p001",
      "title": "はじめてのクエスト",
      "description": "クエストを1回クリアする",
      "condition": {
        "type": "quest_clear",
        "target": 1
      },
      "reward": {
        "type": "gold",
        "amount": 1000
      }
    }
  ]
}
```

---

## ミッション一覧

### デイリーミッション

| ID | タイトル | 条件 | 報酬 |
|----|---------|------|------|
| d001 | クエストに挑戦 | クエスト3回クリア | 300G |
| d002 | クリーチャー召喚 | 召喚9回 | 300G |
| d003 | スペルを使おう | スペル使用5回 | 300G |
| d004 | ガチャを回そう | ガチャ1回 | 100G |

### ウィークリーミッション

| ID | タイトル | 条件 | 報酬 |
|----|---------|------|------|
| w001 | 週間クエストマスター | クエスト30回クリア | 5,000G |
| w002 | 召喚の達人 | 召喚50回 | 2,000G |
| w003 | スペルマスター | スペル使用20回 | 1,000G |
| w004 | 歴戦の勇者 | クリーチャーバトル30回 | 2,000G |

### 永続ミッション

| ID | タイトル | 条件 | 報酬 |
|----|---------|------|------|
| p001 | はじめてのクエスト | クエスト1回クリア | 1,000G |
| p002 | 駆け出し冒険者 | クエスト10回クリア | 3,000G |
| p003 | 熟練冒険者 | クエスト20回クリア | 5,000G |
| p004 | 英雄の道 | クエスト30回クリア | 8,000G |
| p005 | 伝説の冒険者 | クエスト50回クリア | 15,000G |
| p006 | 召喚師見習い | 召喚10回 | 2,000G |
| p007 | 召喚師 | 召喚50回 | 5,000G |
| p008 | 大召喚師 | 召喚100回 | 10,000G |
| p009 | 百戦錬磨 | クリーチャーバトル100回 | 10,000G |
| p010 | 千戦錬磨 | クリーチャーバトル500回 | 30,000G |

---

## セーブデータ

**ファイル**: `user://mission_save.json`

```json
{
  "daily": {
    "last_reset": "2026-04-18T04:00:00",
    "progress": {
      "d001": { "current": 0, "claimed": false },
      "d002": { "current": 2, "claimed": false }
    }
  },
  "weekly": {
    "last_reset": "2026-04-14T04:00:00",
    "progress": {
      "w001": { "current": 5, "claimed": false }
    }
  },
  "permanent": {
    "claimed": ["p001"]
  }
}
```

- デイリー/ウィークリー: `last_reset` 時刻を超えたら `progress` をクリア
- 永続: `claimed` に受け取り済みIDを記録

---

## アーキテクチャ

### MissionManager（Autoload）

**ファイル**: `scripts/autoload/mission_manager.gd`

```
MissionManager (Autoload)
├── ミッション定義読み込み（data/missions.json）
├── 進捗トラッキング（条件タイプごとにカウント更新）
├── リセット判定（デイリー/ウィークリー）
├── 報酬付与（GameData経由）
└── セーブ/ロード（user://mission_save.json）
```

**主要メソッド:**

| メソッド | 説明 |
|---------|------|
| `_ready()` | 定義読み込み + セーブロード + リセットチェック |
| `add_progress(type, amount)` | 条件タイプの進捗を加算 |
| `get_missions(category)` | カテゴリ別ミッション一覧を取得 |
| `get_progress(mission_id)` | ミッションの現在進捗を取得 |
| `is_completed(mission_id)` | 達成済みかチェック |
| `is_claimed(mission_id)` | 受け取り済みかチェック |
| `claim_reward(mission_id)` | 報酬受け取り |
| `get_unclaimed_count()` | 未受取の達成済みミッション数（バッジ表示用） |

**シグナル:**

| シグナル | 発火タイミング |
|---------|-------------|
| `mission_completed(mission_id)` | ミッション達成時 |
| `mission_claimed(mission_id)` | 報酬受け取り時 |
| `progress_updated(mission_id, current, target)` | 進捗更新時 |

### 進捗記録の呼び出し元

既存の `GameData.record_*()` 関数から `MissionManager.add_progress()` を呼ぶ。

| 既存関数 | → MissionManager |
|---------|----------------|
| `record_game_result(true)` | `add_progress("quest_clear", 1)` |
| `record_game_result(*)` | `add_progress("quest_play", 1)` |
| `record_creature_battle()` | `add_progress("creature_battle", 1)` |
| `record_creature_summon()` | `add_progress("creature_summon", 1)` |
| `record_spell_use()` | `add_progress("spell_use", 1)` |
| `record_gacha()` | `add_progress("gacha_pull", 1)` |

---

## UI

### ミッション画面

**シーン**: `scenes/ui/MissionScreen.tscn`
**スクリプト**: `scripts/ui_components/mission_screen.gd`

- メインメニューの `DailyQuestButton` から遷移
- 上部にタブ切り替え（デイリー / ウィークリー / 永続）
- 各ミッション行:
  - タイトル + 説明文
  - プログレスバー（current / target）
  - 報酬表示（アイコン + 金額）
  - 受け取りボタン（達成済み・未受取時のみ有効）
- 受け取り済みミッションはグレーアウト

### バッジ表示

メインメニューの `DailyQuestButton` に未受取数のバッジを表示。

---

## 実装ファイル一覧

| ファイル | 役割 |
|---------|------|
| `data/missions.json` | ミッション定義データ |
| `scripts/autoload/mission_manager.gd` | ミッション管理（Autoload） |
| `scenes/ui/MissionScreen.tscn` | ミッション画面シーン |
| `scripts/ui_components/mission_screen.gd` | ミッション画面ロジック |
| `scripts/main_menu.gd` | DailyQuestButton接続 + バッジ表示 |
| `scripts/game_data.gd` | record_*() から MissionManager 呼び出し |

---

## SNSデイリーボーナス

デイリータブの最上部に表示。サーバー連携後に有効化。

| SNS | 報酬 | リセット | 検証方法 |
|-----|------|---------|---------|
| X (Twitter) | 100 ジェム / 日 | 04:00 JST | OAuth 2.0 PKCE + フォロー確認API |
| Instagram | 100 ジェム / 日 | 04:00 JST | OAuth + Graph API（将来対応） |

**現在の状態**: クライアント側に雛形UI配置済み（「準備中」表示）
**サーバー実装時**: `backend_design.md` のSNS連携セクション参照

---

## 実装順序

1. `data/missions.json` - ミッション定義データ作成
2. `scripts/autoload/mission_manager.gd` - MissionManager 実装
3. Project Settings に Autoload 登録
4. `scripts/game_data.gd` - record_*() に MissionManager 連携追加
5. `scenes/ui/MissionScreen.tscn` + スクリプト - UI実装
6. `scripts/main_menu.gd` - DailyQuestButton 接続 + バッジ
7. テスト・エラー修正
8. ドキュメント最終化
