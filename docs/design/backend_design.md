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
users              -- ユーザーアカウント
match_history      -- 対戦履歴
decks              -- 対戦用デッキ

-- P7: アカウント基盤
cloud_saves        -- セーブデータ（クラウド同期）

-- P8: ソーシャル
friends            -- フレンドリスト
rankings           -- レーティング
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
    rating        INTEGER DEFAULT 1500,
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
```

#### match_history（P6）
```sql
CREATE TABLE match_history (
    id          SERIAL PRIMARY KEY,
    player1_id  INTEGER REFERENCES users(id),
    player2_id  INTEGER REFERENCES users(id),
    winner_id   INTEGER REFERENCES users(id),
    match_type  TEXT NOT NULL,                -- ranked / friendly / tournament
    map_id      TEXT NOT NULL,
    rule_preset TEXT NOT NULL,
    duration    INTEGER,                      -- 対戦時間（秒）
    played_at   TIMESTAMP DEFAULT NOW()
);
```

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

### WebSocket（対戦中）

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `create_room` | C→S | 部屋作成 |
| `join_room` | C→S | 部屋参加 |
| `ready` | C→S | 準備完了 |
| `game_start` | S→C | ゲーム開始（seed、プレイヤー順） |
| `game_action` | C→S | ゲーム操作（スペル選択、召喚等） |
| `game_action` | S→C | 操作の中継 |
| `dice_result` | S→C | ダイス結果（サーバー生成） |
| `game_over` | S→C | ゲーム終了 |

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

### 既存実装
- `scripts/network/network_manager.gd` — WebSocket P2P通信（スタンドアロン）

### 必要な追加実装

| 実装 | Phase | 説明 |
|------|-------|------|
| HTTPクライアント | P6 | REST API 呼び出し用（`HTTPRequest` ノード） |
| `player_is_remote` フラグ | P6 | GameFlowManager でリモートプレイヤー判定 |
| GFM ↔ NetworkManager 統合 | P6 | 各フェーズの操作送受信 |
| ロビーUI | P6 | 部屋一覧、作成、待機画面 |
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
1. Go サーバー基盤（WebSocket + REST）
2. DB セットアップ（users, match_history, decks）
3. ロビー・マッチング
4. GFM ↔ NetworkManager 統合（ターン同期）
5. 安定化（切断対応、タイムアウト、認証）
6. チート対策（初期）

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
