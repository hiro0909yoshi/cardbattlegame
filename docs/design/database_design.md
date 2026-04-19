# データベース設計書（サーバー側）

**最終更新**: 2026-04-19
**ステータス**: Phase 1 実装完了 — PostgreSQL サーバー管理

> **注意**: 本ドキュメントはサーバー側（Go + PostgreSQL）のDB設計を記述する。
> クライアント側（Godot）のローカルDB（UserCardDB等）は別途管理。

---

## 1. 基本構成

| 項目 | 選定 |
|------|------|
| DBMS | PostgreSQL 16+ |
| ドライバ | pgx/v5 (pgxpool) |
| ORM | 不使用（SQL直接実行） |
| マイグレーション | golang-migrate/migrate（7組 × up/down） |
| 接続方式 | コネクションプール（pgxpool） |

### コネクションプール設定

```go
cfg.MaxConns = 25
cfg.MinConns = 5
cfg.MaxConnLifetime = 30 * time.Minute
cfg.MaxConnIdleTime = 5 * time.Minute
cfg.HealthCheckPeriod = 1 * time.Minute
```

### 起動順序

```
Config読込 → DB接続（pgxpool） → defer pool.Close() → マスタデータ読込 → リポジトリ構築 → HTTP起動
```

DB接続はマスタデータ読込より先に行う（接続失敗時に早期終了するため）。

---

## 2. テーブル一覧

| # | テーブル | マイグレーション | 用途 |
|---|---------|----------------|------|
| 1 | `users` | 000001 | ユーザーアカウント・認証・レーティング・プロフィール・設定 |
| 2 | `player_stats` | 000002 | プレイ統計（クエスト・ネット対戦・収集） |
| 3 | `user_cards` | 000003 | カード所持情報（枚数・レベル・図鑑） |
| 4 | `user_deck_slots` | 000003 | デッキスロット上限管理 |
| 5 | `decks` | 000003 | デッキ構成（カードID配列をJSONB保存） |
| 6 | `user_unlocks` | 000004 | 解放管理（ステージ・キャラ・機能等） |
| 7 | `rooms` | 000005 | ルーム管理（将来の永続化用） |
| 8 | `room_players` | 000005 | ルーム参加者 |
| 9 | `match_history` | 000006 | 対戦履歴 |
| 10 | `match_players` | 000006 | 対戦参加者詳細（TrueSkill変動含む） |
| 11 | `operation_logs` | 000007 | 操作ログ（チート検知用） |
| 12 | `fraud_alerts` | 000007 | 不正検知アラート |
| 13 | `banned_users` | 000007 | BAN管理 |

---

## 3. テーブル詳細

### 3.1 users（000001）

ユーザーの全情報を集約する中心テーブル。

```sql
CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    user_id       TEXT UNIQUE NOT NULL,        -- クライアント生成UUID
    device_id     TEXT,
    display_name  TEXT NOT NULL DEFAULT 'ゲスト',
    password_hash TEXT,
    auth_provider TEXT DEFAULT 'guest',         -- 'guest' / 将来: 'google', 'apple'
    auth_token    TEXT,
    refresh_token_hash TEXT,                    -- bcryptハッシュ（平文非保存）
    token_expires_at TIMESTAMPTZ,               -- NULL = 無効（無期限ではない）
    status        TEXT DEFAULT 'active',        -- 'active' / 'suspended' / 'banned'
    transfer_code TEXT UNIQUE,                  -- 引き継ぎコード（16hex平文）

    -- TrueSkill レーティング
    ts_mu         REAL DEFAULT 25.0,
    ts_sigma      REAL DEFAULT 8.333,
    display_rate  REAL DEFAULT 0.0,             -- μ - 3σ（最小0）
    rank_tier     TEXT DEFAULT 'bronze_1',

    -- ランクマッチ戦績
    ranked_wins   INTEGER DEFAULT 0,
    ranked_losses INTEGER DEFAULT 0,
    ranked_draws  INTEGER DEFAULT 0,

    -- プロフィール
    player_level  INTEGER DEFAULT 1,
    experience    INTEGER DEFAULT 0,
    gold          INTEGER DEFAULT 100000,
    stone         INTEGER DEFAULT 0,            -- ジェム（課金通貨）
    stamina       INTEGER DEFAULT 50,
    stamina_max   INTEGER DEFAULT 50,
    stamina_updated_at TIMESTAMPTZ,
    title_id      TEXT,
    favorite_card_id INTEGER,
    character_id  TEXT DEFAULT 'hero',

    -- デッキ・インベントリ
    max_decks     INTEGER DEFAULT 6,
    inventory     JSONB DEFAULT '{}',

    -- 設定
    settings      JSONB DEFAULT '{...}',        -- master_volume, bgm_volume等

    -- ログインボーナス
    login_streak      INTEGER DEFAULT 0,
    total_login_days  INTEGER DEFAULT 0,
    last_login_date   TEXT,
    last_daily_date   TEXT,
    claimed_campaigns JSONB DEFAULT '[]',

    created_at    TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

-- インデックス
CREATE INDEX idx_users_display_rate ON users(display_rate DESC);
CREATE INDEX idx_users_device_id ON users(device_id);
CREATE INDEX idx_users_transfer_code ON users(transfer_code) WHERE transfer_code IS NOT NULL;
```

**設計ポイント**:
- `refresh_token_hash`: bcryptハッシュのみ保存。平文のリフレッシュトークンはDBに残さない
- `token_expires_at`: NULLの場合は「無効」として扱う（無期限ではない）
- `settings`: JSONBで柔軟に拡張可能
- `inventory`: アイテム所持をJSONBで管理

### 3.2 player_stats（000002）

```sql
CREATE TABLE player_stats (
    user_id             BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_battles       INTEGER DEFAULT 0,
    total_wins          INTEGER DEFAULT 0,
    total_losses        INTEGER DEFAULT 0,
    play_time_seconds   INTEGER DEFAULT 0,
    story_cleared       INTEGER DEFAULT 0,
    gacha_count         INTEGER DEFAULT 0,
    cards_obtained      INTEGER DEFAULT 0,
    total_gold_earned   INTEGER DEFAULT 0,
    -- クエストモード統計
    quest_plays         INTEGER DEFAULT 0,
    quest_clears        INTEGER DEFAULT 0,
    quest_battles       INTEGER DEFAULT 0,
    quest_creature_summons INTEGER DEFAULT 0,
    quest_spell_uses    INTEGER DEFAULT 0,
    -- ネット対戦統計
    net_battle_plays    INTEGER DEFAULT 0,
    net_battle_wins     INTEGER DEFAULT 0,
    net_battle_battles  INTEGER DEFAULT 0,
    net_battle_creature_summons INTEGER DEFAULT 0,
    net_battle_spell_uses INTEGER DEFAULT 0,
    collection_complete JSONB DEFAULT '{}',
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);
```

**操作パターン**: `UPSERT`（`ON CONFLICT DO UPDATE`）で初回INSERT/以降UPDATEを1クエリで処理。

### 3.3 user_cards / decks（000003）

```sql
CREATE TABLE user_cards (
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_id     INTEGER NOT NULL,
    count       INTEGER DEFAULT 0,       -- 所持数（0でもレコード残す = 図鑑用）
    card_level  INTEGER DEFAULT 1,       -- カードレベル（将来実装）
    obtained    BOOLEAN DEFAULT FALSE,   -- 一度でも入手したか（図鑑フラグ）
    PRIMARY KEY(user_id, card_id)
);

CREATE TABLE decks (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    slot_index  INTEGER NOT NULL,
    deck_name   TEXT NOT NULL DEFAULT 'デッキ',
    cards       JSONB NOT NULL DEFAULT '{}',    -- カードID配列
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ,
    UNIQUE(user_id, slot_index)
);
```

**同期方式**: `SyncCards` / `SyncDecks` はトランザクション内で DELETE → INSERT のバルク処理。

### 3.4 user_unlocks（000004）

```sql
CREATE TABLE user_unlocks (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    unlock_key  TEXT NOT NULL,       -- 解放対象の識別子
    unlock_type TEXT NOT NULL,       -- 'stage', 'character', 'feature' 等
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, unlock_key)
);
```

**操作パターン**: `Add` は `ON CONFLICT DO NOTHING`（重複解放は無視）。

### 3.5 rooms / room_players（000005）

```sql
CREATE TABLE rooms (
    id              BIGSERIAL PRIMARY KEY,
    room_id         TEXT UNIQUE NOT NULL,
    host_user_id    BIGINT REFERENCES users(id),
    match_type      TEXT NOT NULL,          -- 'friend' / 'ranked'
    status          TEXT DEFAULT 'waiting', -- waiting → ready → playing → finished
    max_players     INTEGER NOT NULL,
    current_players INTEGER DEFAULT 1,
    map_id          TEXT,
    rule_preset     TEXT DEFAULT 'standard',
    initial_magic   INTEGER DEFAULT 1000,
    target_magic    INTEGER DEFAULT 8000,
    max_turns       INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    finished_at     TIMESTAMPTZ
);

CREATE TABLE room_players (
    id          BIGSERIAL PRIMARY KEY,
    room_id     BIGINT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    slot_index  INTEGER NOT NULL,
    deck_id     TEXT,
    is_ready    BOOLEAN DEFAULT FALSE,
    joined_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(room_id, user_id),
    UNIQUE(room_id, slot_index)
);
```

**注意**: 現在ルーム管理はインメモリ（Hub/Room構造体）。DBテーブルは将来の永続化・履歴用に用意。

### 3.6 match_history / match_players（000006）

```sql
CREATE TABLE match_history (
    id            BIGSERIAL PRIMARY KEY,
    match_type    TEXT NOT NULL,
    player_count  INTEGER NOT NULL,
    map_id        TEXT NOT NULL,
    rule_preset   TEXT NOT NULL,
    initial_magic INTEGER,
    target_magic  INTEGER,
    max_turns     INTEGER,
    total_turns   INTEGER,
    duration      INTEGER,         -- 秒
    played_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE match_players (
    id          BIGSERIAL PRIMARY KEY,
    match_id    BIGINT NOT NULL REFERENCES match_history(id) ON DELETE CASCADE,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    final_rank  INTEGER NOT NULL,
    deck_id     TEXT,
    final_tep   INTEGER,
    battle_count      INTEGER DEFAULT 0,
    spell_casts       INTEGER DEFAULT 0,
    creature_summons  INTEGER DEFAULT 0,
    territories_at_end INTEGER DEFAULT 0,
    damage_dealt      INTEGER DEFAULT 0,
    damage_taken      INTEGER DEFAULT 0,
    -- TrueSkill変動記録
    ts_mu_before    REAL,
    ts_mu_after     REAL,
    ts_sigma_before REAL,
    ts_sigma_after  REAL,
    rate_change     REAL,
    UNIQUE(match_id, user_id)
);
```

### 3.7 operation_logs / fraud_alerts / banned_users（000007）

```sql
CREATE TABLE operation_logs (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT REFERENCES users(id),
    match_id        BIGINT REFERENCES match_history(id),
    turn_number     INTEGER,
    operation_type  TEXT NOT NULL,
    operation_data  JSONB,
    before_state    JSONB,
    after_state     JSONB,
    server_verified BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE fraud_alerts (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT REFERENCES users(id),
    match_id    BIGINT,
    alert_type  TEXT NOT NULL,
    description TEXT,
    severity    TEXT NOT NULL,
    score       REAL DEFAULT 0.0,
    action_taken TEXT DEFAULT 'none',
    detected_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE banned_users (
    user_id     BIGINT PRIMARY KEY REFERENCES users(id),
    ban_reason  TEXT NOT NULL,
    banned_by   TEXT,
    banned_at   TIMESTAMPTZ DEFAULT NOW(),
    banned_until TIMESTAMPTZ,
    is_permanent BOOLEAN DEFAULT FALSE
);
```

---

## 4. Repository層

全Repositoryは`pgxpool.Pool`を受け取り、SQLを直接実行する薄いラッパー。ORMは不使用。
全DB操作で`fmt.Errorf("operation: %w", err)`によるコンテキスト付きエラーラップを実施。

| Repository | ファイル | 主要操作 |
|------------|---------|---------|
| `UserRepo` | repository/user.go | Create, GetByID, GetByUserID, UpdateProfile, UpdateGold, UpdateStone, UpdateStamina, UpdateLoginBonus, UpdateSettings, UpdateInventory, UpdateTrueSkill, UpdateRefreshToken, UpdateTransferCode, GetByTransferCode |
| `PlayerStatsRepo` | repository/player_stats.go | Upsert (ON CONFLICT), GetByUserID, IncrementBattle, UpdateCollectionComplete |
| `CardRepo` | repository/card.go | UpsertCard, GetCards, RemoveCard, UpsertDeck, GetDecks, DeleteDeck, SyncCards, SyncDecks（トランザクション内バルク同期） |
| `UnlockRepo` | repository/unlock.go | Add (ON CONFLICT DO NOTHING), GetAll, HasKey, Remove |

### トランザクション使用箇所

| 操作 | 理由 |
|------|------|
| SyncCards | 全カード DELETE → INSERT の原子性保証 |
| SyncDecks | 全デッキ DELETE → INSERT の原子性保証 |
| ランクマッチ結果処理 | TrueSkill更新 + stats更新を単一トランザクションで実行 |

---

## 5. マスタデータ（JSON、DB外）

サーバー起動時にメモリにロード。DBには保存しない。

| ファイル | 内容 |
|---------|------|
| `{fire,water,earth,wind,neutral}_{1,2}.json` | クリーチャー定義（5属性×2） |
| `spell_{1,2}.json` | スペルカード定義 |
| `item.json` | アイテムカード定義 |

アクセスは`sync.RWMutex`で保護。ゲームアクション時にマスタデータ参照でカード型チェック（creature/spell）を実行。

---

## 6. クライアント側DB（参考）

Godotクライアント側では別途ローカルDBを使用：
- **UserCardDB**: カード所持・図鑑のローカルキャッシュ（SQLite / godot-sqlite）
- **default_save.json**: デッキ・設定・進行データ

サーバー実装後はサーバーDBが正とし、クライアントはキャッシュとして利用する方針。

---

## 関連ドキュメント

- `docs/design/server_architecture.md` — サーバー全体設計
- `docs/design/network_design.md` — ネットワーク・通信設計
- `docs/design/backend_design.md` — バックエンド詳細設計
