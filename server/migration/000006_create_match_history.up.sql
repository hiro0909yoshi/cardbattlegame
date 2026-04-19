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
    duration      INTEGER,
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
    ts_mu_before    REAL,
    ts_mu_after     REAL,
    ts_sigma_before REAL,
    ts_sigma_after  REAL,
    rate_change     REAL,
    UNIQUE(match_id, user_id)
);

CREATE INDEX idx_match_players_user ON match_players(user_id, match_id DESC);
