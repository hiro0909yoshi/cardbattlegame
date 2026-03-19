# バックエンド設計書

## 概要

**方式**: 案B（Go リレーサーバー + 要所検証）に決定済み
**参照**: `docs/progress/roadmap.md`（決定事項メモ 2026-02-21）
**想定ユーザー規模**: 500-700人（VPS 2-3台で対応可能）

ゲームロジックはクライアント（Godot/GDScript）側で実行し、サーバーはメッセージ中継・データ保存・要所検証を担当する。

---

## アーキテクチャ

```
┌──────────────┐     WebSocket (WSS)     ┌──────────────────┐
│  Godot       │◄──────────────────────►│  Go リレーサーバー  │
│  クライアント  │     JSON メッセージ      │                  │
└──────────────┘                        │  - メッセージ中継   │
                                        │  - 要所検証        │
┌──────────────┐     WebSocket (WSS)     │  - REST API       │
│  Godot       │◄──────────────────────►│                  │
│  クライアント  │                        └────────┬─────────┘
└──────────────┘                                 │
                                                 │ SQL
┌──────────────┐     HTTPS (REST)                │
│  管理画面     │◄─────────────────┐      ┌───────▼─────────┐
│  (Web)       │                  │      │  PostgreSQL     │
└──────────────┘                  │      │  データベース     │
                                  │      └─────────────────┘
                           ┌──────┴─────────┐
                           │  Go サーバー     │
                           │  (REST API)     │
                           └────────────────┘
```

### 通信方式

| 用途 | プロトコル | 方式 |
|------|-----------|------|
| 対戦中リアルタイム通信 | WebSocket (WSS) | JSON メッセージ |
| データ取得・更新 | HTTPS (REST API) | JSON リクエスト/レスポンス |
| プッシュ通知 | FCM (Firebase Cloud Messaging) | サーバーから配信 |

### ターン制の利点
- リアルタイム性の要求が低い（1秒程度の遅延は問題なし）
- WebSocket のメッセージ頻度が低い（1ターンに数メッセージ）
- サーバー負荷が軽い

---

## サーバー構成

### VPS 選定候補

| サービス | 最安プラン | 特徴 |
|---------|-----------|------|
| さくらVPS | 月643円〜 | 国内、日本語サポート |
| ConoHa | 月296円〜 | 国内、時間課金あり |
| Vultr | 月$2.5〜 | 海外、安い |

### スケーリング目安

| ユーザー規模 | 構成 | 月額目安 |
|------------|------|---------|
| 〜300人 | VPS 1台（Go + DB） | 月500〜1,500円 |
| 〜700人 | VPS 2-3台（Go + DB分離） | 月1,500〜3,000円 |
| 1,000人超 | ロードバランサー + 複数Go | 月5,000円〜 |

---

## データベース設計

### DB 選定
- **PostgreSQL**（本番環境）
- 理由: JSON型サポート、フルテキスト検索、スケーラビリティ

### テーブル一覧

```sql
-- P6: ネット対戦
users              -- ユーザーアカウント（TrueSkillレーティング含む）
rooms              -- ルーム管理（一時データ、メモリ併用）
match_history      -- 対戦履歴（2～4人対応）
match_players      -- 対戦参加者（match_historyの子テーブル）
decks              -- 対戦用デッキ

-- P6: 解放管理
user_unlocked_maps       -- ユーザーが解放済みのマップ
user_unlocked_characters -- ユーザーが解放済みのキャラクター

-- P7: アカウント基盤
cloud_saves        -- セーブデータ（クラウド同期）

-- P8: ソーシャル
friends            -- フレンドリスト
rank_history       -- ランク変動履歴（シーズン管理）
tournaments        -- 大会データ
tournament_entries -- 大会参加者
tournament_matches -- 大会対戦結果

-- P9: マネタイズ・運営
purchases          -- 課金履歴
announcements      -- お知らせ
mail               -- ユーザーメール（運営/フレンド）
daily_quests       -- デイリークエスト定義
daily_quest_progress -- デイリークエスト達成状況
push_tokens        -- プッシュ通知トークン
items              -- ユーザー所持アイテム（倉庫）
gacha_events       -- ガチャイベント定義
gacha_history      -- ガチャ履歴
```

### 主要テーブル定義

#### users（P6）
```sql
CREATE TABLE users (
    id            SERIAL PRIMARY KEY,
    user_id       TEXT UNIQUE NOT NULL,      -- 表示用ID (#12345)
    display_name  TEXT NOT NULL,
    password_hash TEXT,                       -- ゲスト時はNULL
    auth_provider TEXT DEFAULT 'guest',       -- guest / apple / google
    auth_token    TEXT,                       -- OAuth トークン

    -- TrueSkill レーティング
    ts_mu         REAL DEFAULT 25.0,         -- 実力推定値（平均）
    ts_sigma      REAL DEFAULT 8.333,        -- 不確実性（μ/3）
    display_rate  REAL DEFAULT 0.0,          -- 表示レート = μ - 3σ（計算済みキャッシュ）
    rank_tier     TEXT DEFAULT 'bronze_1',   -- ランク段位（bronze_1 ～ diamond_3）

    -- ランクマッチ戦績
    ranked_wins   INTEGER DEFAULT 0,
    ranked_losses INTEGER DEFAULT 0,
    ranked_draws  INTEGER DEFAULT 0,

    -- プロフィール
    player_level  INTEGER DEFAULT 1,
    experience    INTEGER DEFAULT 0,
    gold          INTEGER DEFAULT 0,
    premium_stone INTEGER DEFAULT 0,         -- 課金石
    stamina       INTEGER DEFAULT 50,
    stamina_max   INTEGER DEFAULT 50,
    stamina_updated_at TIMESTAMP,            -- スタミナ最終更新時刻
    title_id      INTEGER,                   -- 装備中の称号
    favorite_card_id INTEGER,                -- お気に入りカード
    character_id  INTEGER DEFAULT 1,         -- 使用キャラクター
    created_at    TIMESTAMP DEFAULT NOW(),
    last_login_at TIMESTAMP
);

-- 表示レートでのランキング検索用
CREATE INDEX idx_users_display_rate ON users(display_rate DESC);
```

**TrueSkill パラメータ定数**（サーバー側で保持）:

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| 初期μ | 25.0 | 実力推定値（平均） |
| 初期σ | 8.333 | 不確実性（μ/3） |
| β | 4.167 | 実力幅（μ/6） |
| τ | 0.083 | 動的係数（σ/100） |
| draw_probability | 0.0 | 引き分け確率（このゲームでは0） |

**表示レート計算**: `display_rate = μ - 3σ`（初期値: 25.0 - 3×8.333 = 0.0）

**ランク段位マッピング**:

| rank_tier | 表示レート範囲 | 表示名 |
|-----------|--------------|--------|
| `bronze_1` ～ `bronze_3` | 0 ～ 9 | ブロンズ I～III |
| `silver_1` ～ `silver_3` | 10 ～ 19 | シルバー I～III |
| `gold_1` ～ `gold_3` | 20 ～ 29 | ゴールド I～III |
| `platinum_1` ～ `platinum_3` | 30 ～ 39 | プラチナ I～III |
| `diamond_1` ～ `diamond_3` | 40～ | ダイヤモンド I～III |

**レート更新タイミング**: 対戦結果報告時にサーバー側で計算し、`ts_mu`・`ts_sigma`・`display_rate`・`rank_tier` を同時更新

#### rooms（P6 — メモリ管理 + DB永続化オプション）

ルームは基本的にサーバーメモリ上で管理し、サーバー再起動時に消失しても問題ない一時データ。
必要に応じてDBに永続化（アクティブルーム一覧の表示用など）。

```sql
CREATE TABLE rooms (
    id            SERIAL PRIMARY KEY,
    room_id       TEXT UNIQUE NOT NULL,      -- 4桁数字（フレンド）or サーバー生成ID（ランク）
    host_user_id  INTEGER REFERENCES users(id),
    match_type    TEXT NOT NULL,              -- ranked / friendly
    status        TEXT DEFAULT 'waiting',     -- waiting / ready / in_game / finished
    max_players   INTEGER NOT NULL,           -- 2 / 3 / 4
    current_players INTEGER DEFAULT 1,
    map_id        TEXT,                       -- ホストが選択（フレンドマッチ）
    rule_preset   TEXT DEFAULT 'standard',
    initial_magic INTEGER DEFAULT 1000,
    target_magic  INTEGER DEFAULT 8000,
    max_turns     INTEGER DEFAULT 0,          -- 0=無制限
    created_at    TIMESTAMP DEFAULT NOW(),
    started_at    TIMESTAMP,                  -- ゲーム開始時刻
    finished_at   TIMESTAMP                   -- ゲーム終了時刻
);

-- アクティブルーム検索用
CREATE INDEX idx_rooms_status ON rooms(status) WHERE status IN ('waiting', 'ready');
-- ルームID重複チェック用（アクティブルームのみ）
CREATE UNIQUE INDEX idx_rooms_active_room_id ON rooms(room_id) WHERE status NOT IN ('finished');
```

#### room_players（P6 — rooms の子テーブル）
```sql
CREATE TABLE room_players (
    id          SERIAL PRIMARY KEY,
    room_id     INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
    user_id     INTEGER REFERENCES users(id),
    slot_index  INTEGER NOT NULL,             -- 0～3（プレイヤースロット番号）
    deck_id     TEXT,                         -- 選択デッキID
    is_ready    BOOLEAN DEFAULT FALSE,
    joined_at   TIMESTAMP DEFAULT NOW(),
    UNIQUE(room_id, user_id),
    UNIQUE(room_id, slot_index)
);
```

#### match_history（P6 — 2～4人対応）
```sql
CREATE TABLE match_history (
    id          SERIAL PRIMARY KEY,
    match_type  TEXT NOT NULL,                -- ranked / friendly / tournament
    player_count INTEGER NOT NULL,            -- 2 / 3 / 4
    map_id      TEXT NOT NULL,
    rule_preset TEXT NOT NULL,
    initial_magic INTEGER,
    target_magic INTEGER,
    max_turns   INTEGER,
    total_turns INTEGER,                      -- 実際にかかったターン数
    duration    INTEGER,                      -- 対戦時間（秒）
    played_at   TIMESTAMP DEFAULT NOW()
);
```

#### match_players（P6 — match_history の子テーブル）
```sql
CREATE TABLE match_players (
    id          SERIAL PRIMARY KEY,
    match_id    INTEGER REFERENCES match_history(id) ON DELETE CASCADE,
    user_id     INTEGER REFERENCES users(id),
    final_rank  INTEGER NOT NULL,             -- 順位（1=優勝, 2=2位...）
    deck_id     TEXT,
    final_tep   INTEGER,                      -- 最終TEP
    -- TrueSkill 変動記録
    ts_mu_before    REAL,
    ts_mu_after     REAL,
    ts_sigma_before REAL,
    ts_sigma_after  REAL,
    rate_change     REAL,                     -- 表示レート変動（+/-）
    UNIQUE(match_id, user_id)
);

-- ユーザーの対戦履歴検索用
CREATE INDEX idx_match_players_user ON match_players(user_id, match_id DESC);
```

#### rank_history（P8 — ランク変動履歴）
```sql
CREATE TABLE rank_history (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id),
    season_id   INTEGER,                      -- シーズン番号（将来対応）
    match_id    INTEGER REFERENCES match_history(id),
    ts_mu       REAL NOT NULL,
    ts_sigma    REAL NOT NULL,
    display_rate REAL NOT NULL,
    rank_tier   TEXT NOT NULL,
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_rank_history_user ON rank_history(user_id, recorded_at DESC);
```

#### user_unlocked_maps（P6 — マップ解放管理）

クエストクリアまたはショップ購入で解放されたマップを管理。
ソロバトル・ネット対戦（フレンドマッチ）で選択可能なマップを制限。
ランクマッチはサーバーがマップを自動選択するため、解放状態に依存しない。

```sql
CREATE TABLE user_unlocked_maps (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id),
    map_id      TEXT NOT NULL,                -- マップID（例: map_diamond_20）
    unlock_type TEXT NOT NULL,                -- quest_clear / purchase / default
    unlocked_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, map_id)
);
```

**初期解放マップ**（全ユーザーに付与、`unlock_type = 'default'`）:
- `map_diamond_20`（ダイヤモンド20）

#### user_unlocked_characters（P6 — キャラクター解放管理）

クエストクリアまたはショップ購入で解放されたキャラクターを管理。
解放済みキャラのみプレイヤーアバターとして使用可能。

```sql
CREATE TABLE user_unlocked_characters (
    id            SERIAL PRIMARY KEY,
    user_id       INTEGER REFERENCES users(id),
    character_id  TEXT NOT NULL,               -- キャラクターID（例: necromancer）
    unlock_type   TEXT NOT NULL,               -- quest_clear / purchase / default
    unlocked_at   TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, character_id)
);
```

**初期解放キャラクター**（全ユーザーに付与、`unlock_type = 'default'`）:
- `necromancer`（ネクロマンサー / マリオン）

#### 解放管理 API

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/users/me/unlocked_maps` | GET | 解放済みマップ一覧 |
| `/api/users/me/unlocked_characters` | GET | 解放済みキャラクター一覧 |
| `/api/unlocks/map` | POST | マップ解放（クエストクリア・購入時） |
| `/api/unlocks/character` | POST | キャラクター解放（クエストクリア・購入時） |

#### mail（P9）
```sql
CREATE TABLE mail (
    id          SERIAL PRIMARY KEY,
    recipient_id INTEGER REFERENCES users(id),
    sender_id   INTEGER REFERENCES users(id), -- NULL = 運営メール
    mail_type   TEXT NOT NULL,                 -- system / reward / friend
    subject     TEXT NOT NULL,
    body        TEXT NOT NULL,
    attachment  JSONB,                         -- 添付報酬 {"gold": 100, "items": [...]}
    is_read     BOOLEAN DEFAULT FALSE,
    is_claimed  BOOLEAN DEFAULT FALSE,         -- 添付受け取り済み
    is_protected BOOLEAN DEFAULT FALSE,        -- 削除保護
    expires_at  TIMESTAMP,                     -- 自動削除日（30日後）
    created_at  TIMESTAMP DEFAULT NOW()
);
```

#### announcements（P9）
```sql
CREATE TABLE announcements (
    id          SERIAL PRIMARY KEY,
    category    TEXT NOT NULL,                 -- important / event / update / campaign
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    image_url   TEXT,
    starts_at   TIMESTAMP DEFAULT NOW(),
    ends_at     TIMESTAMP,
    created_at  TIMESTAMP DEFAULT NOW()
);
```

#### daily_quests（P9）
```sql
CREATE TABLE daily_quests (
    id          SERIAL PRIMARY KEY,
    quest_type  TEXT NOT NULL,                 -- battle_count / quest_clear / summon_count 等
    description TEXT NOT NULL,
    target_value INTEGER NOT NULL,             -- 目標値（例: 3回）
    reward_type TEXT NOT NULL,                 -- gold / premium_stone / item
    reward_value INTEGER NOT NULL,
    is_active   BOOLEAN DEFAULT TRUE
);

CREATE TABLE daily_quest_progress (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id),
    quest_id    INTEGER REFERENCES daily_quests(id),
    progress    INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    is_claimed  BOOLEAN DEFAULT FALSE,         -- 報酬受け取り済み
    quest_date  DATE NOT NULL,                 -- どの日のクエストか
    UNIQUE(user_id, quest_id, quest_date)
);
```

#### friends（P8）
```sql
CREATE TABLE friends (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id),
    friend_id   INTEGER REFERENCES users(id),
    status      TEXT NOT NULL,                 -- pending / accepted / blocked
    created_at  TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, friend_id)
);
```

#### items（P9 - 倉庫）
```sql
CREATE TABLE user_items (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id),
    item_type   TEXT NOT NULL,                 -- stamina_small / stamina_large 等
    quantity    INTEGER DEFAULT 0,
    UNIQUE(user_id, item_type)
);
```

#### tournaments（P8）
```sql
CREATE TABLE tournaments (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    format      TEXT NOT NULL,                 -- league / tournament / league_to_tournament
    status      TEXT DEFAULT 'upcoming',       -- upcoming / active / finished
    map_id      TEXT NOT NULL,
    rule_preset TEXT NOT NULL,
    max_players INTEGER,
    starts_at   TIMESTAMP NOT NULL,
    ends_at     TIMESTAMP NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tournament_entries (
    id            SERIAL PRIMARY KEY,
    tournament_id INTEGER REFERENCES tournaments(id),
    user_id       INTEGER REFERENCES users(id),
    group_name    TEXT,                         -- リーグのグループ名
    wins          INTEGER DEFAULT 0,
    losses        INTEGER DEFAULT 0,
    rating_change INTEGER DEFAULT 0,
    final_rank    INTEGER,
    UNIQUE(tournament_id, user_id)
);
```

---

## API 設計

### 認証

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/auth/guest` | POST | ゲストログイン（UUID生成） |
| `/api/auth/login` | POST | Apple ID / Google ログイン |
| `/api/auth/transfer` | POST | 引き継ぎコード入力 |
| `/api/auth/transfer/code` | GET | 引き継ぎコード発行 |

### ユーザー

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/users/me` | GET | 自分のプロフィール |
| `/api/users/me` | PATCH | プロフィール更新（名前、称号、キャラ等） |
| `/api/users/{id}` | GET | 他ユーザーのプロフィール |
| `/api/users/me/stats` | GET | 戦績取得 |

### 対戦

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/match/history` | GET | 対戦履歴取得 |
| `/api/match/result` | POST | 対戦結果報告 |

### WebSocket（ロビー・準備画面）

#### ルーム管理

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `create_room` | C→S | ルーム作成（max_players指定） |
| `room_created` | S→C | ルーム作成成功（room_id返却） |
| `join_room` | C→S | ルーム参加（room_id指定） |
| `room_joined` | S→C | ルーム参加成功（プレイヤーリスト返却） |
| `player_joined` | S→C | 他プレイヤーが参加（全員に通知） |
| `player_left` | S→C | プレイヤーが退出（全員に通知） |
| `leave_room` | C→S | ルーム退出 |
| `error` | S→C | エラー通知（ルーム不存在、満員等） |

```json
// ルーム作成
→ {"type": "create_room", "max_players": 4}
← {"type": "room_created", "room_id": "1234"}

// ルーム参加
→ {"type": "join_room", "room_id": "1234"}
← {"type": "room_joined", "room_id": "1234", "players": [
    {"id": "user_1", "name": "ホスト", "slot": 0, "is_ready": false, "character_id": 1},
    {"id": "user_2", "name": "ゲスト", "slot": 1, "is_ready": false, "character_id": 1}
  ]}

// 他プレイヤー参加通知（既存メンバー全員に配信）
← {"type": "player_joined", "player": {"id": "user_3", "name": "新参加者", "slot": 2, "character_id": 1}}

// プレイヤー退出通知
← {"type": "player_left", "player_id": "user_3"}

// エラー
← {"type": "error", "code": "room_not_found", "message": "ルームが見つかりません"}
← {"type": "error", "code": "room_full", "message": "ルームが満員です"}
← {"type": "error", "code": "room_id_duplicate", "message": "ルームID重複、再生成してください"}
```

#### 準備画面（設定同期）

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `set_ready` | C→S | 準備完了/取消（ゲスト→サーバー→全員） |
| `ready_changed` | S→C | 準備状態変更通知（全員に配信） |
| `update_config` | C→S | ルール設定変更（ホスト→サーバー→ゲスト） |
| `config_updated` | S→C | ルール設定更新通知（ゲストに配信） |
| `set_deck` | C→S | デッキ選択通知 |

```json
// 準備完了
→ {"type": "set_ready", "is_ready": true}
← {"type": "ready_changed", "player_id": "user_2", "is_ready": true}

// ルール設定変更（ホストのみ送信可）
→ {"type": "update_config", "config": {
    "map_id": "map_diamond_20",
    "rule_preset": "standard",
    "initial_magic": 1000,
    "target_magic": 8000,
    "max_turns": 0
  }}
← {"type": "config_updated", "config": { ... }}  // ゲスト全員に配信

// デッキ選択
→ {"type": "set_deck", "deck_id": "deck_0"}
```

#### ランクマッチ（マッチメイキング）

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `start_matchmaking` | C→S | マッチング開始（レート・人数指定） |
| `cancel_matchmaking` | C→S | マッチングキャンセル |
| `matchmaking_cancelled` | S→C | キャンセル確認 |
| `match_found` | S→C | マッチング成立（ルーム情報返却） |

```json
// マッチング開始
→ {"type": "start_matchmaking", "player_count": 2, "deck_id": "deck_0"}
← {"type": "match_found", "room_id": "ranked_xyz", "players": [...]}

// マッチングキャンセル
→ {"type": "cancel_matchmaking"}
← {"type": "matchmaking_cancelled"}
```

**マッチメイキングロジック**（サーバー側）:
1. マッチング待機キューに追加（display_rate + 待機時間を保持）
2. 定期的にキューを走査（1秒間隔）
3. レート差が閾値以内のプレイヤーをグループ化
4. 待機時間が長いほど閾値を緩和（10秒ごとにレート差 +5）
5. 必要人数が揃ったら `match_found` を配信、自動でルーム作成

#### ゲーム開始・対戦中

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `game_start` | S→C | ゲーム開始（seed、プレイヤー順） |
| `game_action` | C→S | ゲーム操作（スペル選択、召喚等） |
| `game_action` | S→C | 操作の中継 |
| `dice_result` | S→C | ダイス結果（サーバー生成） |
| `game_over` | S→C | ゲーム終了（順位、レート変動） |

```json
// ゲーム開始
← {"type": "game_start", "seed": 12345, "player_order": [0, 1, 2, 3]}

// ゲーム終了（ランクマッチ時、レート変動を含む）
← {"type": "game_over", "results": [
    {"player_id": "user_1", "rank": 1, "rate_change": +3.2, "new_display_rate": 13.2},
    {"player_id": "user_2", "rank": 2, "rate_change": -1.5, "new_display_rate": 8.5}
  ]}
```

### フレンド

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/friends` | GET | フレンドリスト |
| `/api/friends/request` | POST | フレンド申請 |
| `/api/friends/{id}/accept` | POST | 申請承認 |
| `/api/friends/{id}/reject` | POST | 申請拒否 |
| `/api/friends/{id}` | DELETE | フレンド削除 |

### メール

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/mail` | GET | メール一覧 |
| `/api/mail/{id}/read` | POST | 既読にする |
| `/api/mail/{id}/claim` | POST | 添付報酬受け取り |
| `/api/mail/claim_all` | POST | 一括受け取り |
| `/api/mail/send` | POST | フレンドメール送信 |
| `/api/mail/unread_count` | GET | 未読件数 |

### 告知

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/announcements` | GET | お知らせ一覧 |
| `/api/announcements/{id}` | GET | お知らせ詳細 |

### デイリークエスト

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/daily_quests` | GET | 本日のクエスト一覧+進捗 |
| `/api/daily_quests/{id}/claim` | POST | 報酬受け取り |
| `/api/daily_quests/report` | POST | 進捗報告（対戦完了、召喚等） |

### 大会

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/tournaments` | GET | 大会一覧 |
| `/api/tournaments/{id}` | GET | 大会詳細（組み合わせ、結果） |
| `/api/tournaments/{id}/enter` | POST | エントリー |
| `/api/tournaments/{id}/ranking` | GET | 大会ランキング |

### ランキング

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/rankings` | GET | 全体ランキング（Top 100） |
| `/api/rankings/friends` | GET | フレンド内ランキング |

### 倉庫

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/items` | GET | 所持アイテム一覧 |
| `/api/items/{type}/use` | POST | アイテム使用 |

### ショップ・課金

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/shop/products` | GET | 商品一覧 |
| `/api/shop/purchase` | POST | 購入処理 |
| `/api/shop/verify_receipt` | POST | レシート検証（Apple/Google） |
| `/api/gacha/pull` | POST | ガチャ実行（サーバー側抽選） |
| `/api/gacha/events` | GET | 開催中ガチャイベント |

### クラウドセーブ

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/saves` | GET | セーブデータ取得 |
| `/api/saves` | PUT | セーブデータ保存 |
| `/api/saves/conflict` | POST | 競合解決 |

---

## 要所検証（チート対策）

サーバー側で検証する項目（段階的に強化）。

### 初期（P6リリース時）

| 検証項目 | 方法 |
|---------|------|
| ダイス結果 | サーバー側で生成・配信 |
| ターン順 | 正しいプレイヤーの操作か検証 |
| 手札所持 | 使用カードが手札にあるか |
| EP残高 | スペルコスト分のEPがあるか |

### 中期（不正報告が出たら）

| 検証項目 | 方法 |
|---------|------|
| バトル結果妥当性 | HP/ダメージが範囲内か |
| 召喚コスト | カードコスト分のEPがあるか |
| レベルアップコスト | 正しいEP消費か |

### 後期（必要に応じて）

| 検証項目 | 方法 |
|---------|------|
| バトルロジック再現 | サーバーでバトル計算を再現 |
| 完全サーバー権威 | 全操作をサーバーで処理 |

---

## セキュリティ

| 項目 | 対応 |
|------|------|
| 通信暗号化 | WSS (WebSocket Secure) / HTTPS |
| 認証 | JWT トークン（有効期限付き） |
| パスワード | bcrypt ハッシュ化 |
| ガチャ | サーバー側で抽選（クライアント改ざん防止） |
| 課金 | Apple/Google レシート検証（サーバー側） |
| 不正検知 | 操作ログ保存、異常値アラート |
| BAN | 管理画面から実行、即時切断 |

---

## Go サーバー技術スタック

| 用途 | ライブラリ/ツール |
|------|----------------|
| HTTP ルーター | `net/http` or `chi` |
| WebSocket | `gorilla/websocket` or `nhooyr/websocket` |
| DB ドライバ | `pgx` (PostgreSQL) |
| マイグレーション | `golang-migrate` |
| 認証 | `golang-jwt` |
| 設定管理 | `envconfig` or `viper` |
| ログ | `slog` (Go 標準) |
| テスト | `testing` (Go 標準) |

---

## クライアント側（Godot）の対応

### 既存実装（クライアント側）
- `scripts/network/network_manager.gd` — WebSocket P2P通信（スタンドアロン）
- `scripts/net_battle_lobby.gd` — ロビー画面（ランクマッチ/フレンドマッチ切替、ルーム作成・参加UI）
- `scripts/net_battle_setup.gd` — 準備画面（ホスト/ゲスト切替、マップ・ルール設定、プレイヤーリスト、3Dキャラプレビュー）
- ネットワーク公開メソッド: `on_player_joined()`, `on_player_left()`, `on_player_ready_changed()`, `on_config_received()`

### GameClock（時刻管理 - 実装済み）

**ファイル**: `scripts/autoload/game_clock.gd`（Autoload）

サーバー時刻とローカル時刻を抽象化するレイヤー。全スクリプトは `GameClock` 経由で時刻を取得しており、`Time.get_unix_time_from_system()` を直接呼ばない。

| メソッド | 説明 |
|---------|------|
| `get_now() -> int` | 現在のUnix時刻（サーバー同期済みならサーバー時刻） |
| `get_today() -> String` | 今日の日付（YYYY-MM-DD） |
| `sync_with_server(server_unix)` | サーバー時刻との差分を計算・保存 |
| `is_synced() -> bool` | サーバー同期済みか |

**サーバー移行時の対応**:
1. ログインAPIのレスポンスにサーバーUnix時刻を含める
2. クライアント側で `GameClock.sync_with_server(response.server_time)` を呼ぶ
3. 以降、スタミナ回復・ログインボーナス・日付判定等が全てサーバー時刻基準になる

**使用箇所**: `game_data.gd`（スタミナ・ログインボーナス・セーブ時刻）、`main_menu.gd`、`stage_record_manager.gd`

### 必要な追加実装

| 実装 | Phase | 説明 |
|------|-------|------|
| `NetworkService` (Autoload) | P6 | WebSocket接続管理 + シグナル駆動の抽象レイヤー |
| HTTPクライアント | P6 | REST API 呼び出し用（`HTTPRequest` ノード） |
| `player_is_remote` フラグ | P6 | GameFlowManager でリモートプレイヤー判定 |
| GFM ↔ NetworkService 統合 | P6 | 各フェーズの操作送受信 |
| ロビー ↔ NetworkService 接続 | P6 | TODO箇所の実装（ルーム作成/参加/マッチング） |
| 準備画面 ↔ NetworkService 接続 | P6 | TODO箇所の実装（設定同期/準備完了/ゲーム開始） |
| 解放状態のローカルキャッシュ | P6 | 解放済みマップ・キャラをローカルに保持、起動時同期 |
| トークン管理 | P7 | JWT の保存・自動付与・リフレッシュ |
| クラウドセーブ同期 | P7 | 起動時同期チェック、競合解決UI |

### GFM 統合の対象フェーズ

```
各フェーズで「ローカル操作 → サーバー送信」or「サーバー受信 → 画面反映」の分岐:

- SpellPhaseHandler      — スペル選択/パス
- DicePhaseHandler       — ダイス結果（サーバーから受信）
- MovementController     — 移動方向選択
- TileActionProcessor    — 召喚カード選択
- BattleSystem           — アイテム選択
- DominioCommandHandler  — ドミニオコマンド
```

---

## Phase 別実装計画

### P6: ネット対戦

#### サーバー基盤
1. Go サーバープロジェクト作成（WebSocket + REST）
2. DB セットアップ（PostgreSQL: users, rooms, room_players, match_history, match_players, decks）
3. DB マイグレーション（golang-migrate）
4. JWT 認証基盤（ゲストログイン最優先）

#### ルーム管理（フレンドマッチ）
5. ルーム作成（4桁ルームID生成、重複チェック）
6. ルーム参加（ID検索、満員チェック、存在チェック）
7. ルーム退出（ホスト退出時は全員退出 or ホスト移譲）
8. 準備完了状態の同期（set_ready → 全員に配信）
9. ルール設定の同期（ホスト → ゲスト全員に配信）
10. ゲーム開始判定（全員Ready → game_start 配信）

#### マッチメイキング（ランクマッチ）
11. マッチング待機キュー管理
12. レート近似マッチング（display_rate 基準、待機時間で閾値緩和）
13. マッチング成立 → 自動ルーム作成 → match_found 配信
14. マッチングキャンセル処理

#### TrueSkill レーティング
15. TrueSkill 計算ロジック実装（Go側）— μ/σ 更新、2～4人対応
16. 対戦結果報告 → レート更新 → DB保存（users + match_players + rank_history）
17. ランク段位の自動判定（display_rate → rank_tier）
18. ランキング API（全体 Top 100、フレンド内）

#### 解放管理
19. ユーザー登録時に初期解放データ挿入（デフォルトマップ・キャラクター）
20. クエストクリア時の解放処理 API
21. ショップ購入時の解放処理 API
22. マップ選択時のバリデーション（解放済みかチェック）— フレンドマッチのみ
23. キャラクター選択時のバリデーション

#### GFM ↔ NetworkManager 統合（ターン同期）
24. 各フェーズの操作送受信（スペル、ダイス、移動、召喚、バトル、ドミニオ）
25. ダイス結果のサーバー生成・配信
26. リモートプレイヤー操作の画面反映

#### 安定化
27. 切断検知（WebSocket ping/pong、60秒タイムアウト）
28. 切断時のAI引き継ぎ（ローカルCPUが代行）
29. ターンタイムアウト（60秒で自動パス）
30. ルーム自動クリーンアップ（全員退出 or 一定時間経過）

#### チート対策（初期）
31. ダイス結果サーバー生成
32. ターン順検証
33. 手札所持検証
34. EP残高検証

### P7: アカウント基盤
1. Apple ID / Google ログイン
2. JWT 認証
3. データ引き継ぎ
4. クラウドセーブ

### P8: ソーシャル
1. フレンドシステム
2. レーティング・ランキング
3. 大会システム
4. 観戦機能
5. SNS共有

### P9: マネタイズ・運営
1. 課金システム（ストア連携、レシート検証）
2. ガチャのサーバー側抽選
3. お知らせ機能
4. メールシステム
5. デイリークエスト
6. 倉庫
7. 管理画面
8. アクセス解析
9. プッシュ通知

---

## 関連ドキュメント

- `docs/progress/roadmap.md` - プロジェクトロードマップ（Phase定義）
- `docs/design/network_design.md` - ネット対戦通信設計（メッセージ仕様詳細）
- `docs/design/online_rules_design.md` - オンラインルール設計（プリセット定義）
- `docs/design/main_menu_design.md` - メイン画面設計（UI導線）
- `docs/design/database_design.md` - DB設計（SQLite移行計画）
- `docs/design/gacha_system.md` - ガチャシステム
- `docs/design/team_system_design.md` - チームシステム
