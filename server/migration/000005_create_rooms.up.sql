CREATE TABLE rooms (
    id              BIGSERIAL PRIMARY KEY,
    room_id         TEXT UNIQUE NOT NULL,
    host_user_id    BIGINT REFERENCES users(id),
    match_type      TEXT NOT NULL,
    status          TEXT DEFAULT 'waiting',
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

CREATE INDEX idx_rooms_status ON rooms(status) WHERE status IN ('waiting', 'ready');
CREATE UNIQUE INDEX idx_rooms_active_room_id ON rooms(room_id) WHERE status NOT IN ('finished');

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
