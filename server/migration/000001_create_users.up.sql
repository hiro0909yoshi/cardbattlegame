CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    user_id       TEXT UNIQUE NOT NULL,
    device_id     TEXT,
    display_name  TEXT NOT NULL DEFAULT 'ゲスト',
    password_hash TEXT,
    auth_provider TEXT DEFAULT 'guest',
    auth_token    TEXT,
    refresh_token_hash TEXT,
    token_expires_at TIMESTAMPTZ,
    status        TEXT DEFAULT 'active',
    transfer_code TEXT UNIQUE,

    -- TrueSkill
    ts_mu         REAL DEFAULT 25.0,
    ts_sigma      REAL DEFAULT 8.333,
    display_rate  REAL DEFAULT 0.0,
    rank_tier     TEXT DEFAULT 'bronze_1',

    -- ランクマッチ戦績
    ranked_wins   INTEGER DEFAULT 0,
    ranked_losses INTEGER DEFAULT 0,
    ranked_draws  INTEGER DEFAULT 0,

    -- プロフィール
    player_level  INTEGER DEFAULT 1,
    experience    INTEGER DEFAULT 0,
    gold          INTEGER DEFAULT 100000,
    stone         INTEGER DEFAULT 0,
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
    settings      JSONB DEFAULT '{"master_volume":1.0,"bgm_volume":0.8,"se_volume":1.0,"language":"ja","auto_save":true,"lightweight_mode":false}',

    -- ログインボーナス
    login_streak      INTEGER DEFAULT 0,
    total_login_days  INTEGER DEFAULT 0,
    last_login_date   TEXT,
    last_daily_date   TEXT,
    claimed_campaigns JSONB DEFAULT '[]',

    created_at    TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

CREATE INDEX idx_users_display_rate ON users(display_rate DESC);
CREATE INDEX idx_users_device_id ON users(device_id);
CREATE INDEX idx_users_transfer_code ON users(transfer_code) WHERE transfer_code IS NOT NULL;
