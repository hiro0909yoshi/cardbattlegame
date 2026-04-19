CREATE TABLE user_unlocks (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    unlock_key  TEXT NOT NULL,
    unlock_type TEXT NOT NULL,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, unlock_key)
);

CREATE INDEX idx_user_unlocks_user ON user_unlocks(user_id);
CREATE INDEX idx_user_unlocks_key ON user_unlocks(unlock_key);
