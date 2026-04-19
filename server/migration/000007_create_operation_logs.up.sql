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

CREATE INDEX idx_operation_logs_match ON operation_logs(match_id);
CREATE INDEX idx_operation_logs_user ON operation_logs(user_id, created_at DESC);

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

CREATE INDEX idx_fraud_alerts_user ON fraud_alerts(user_id);
CREATE INDEX idx_fraud_alerts_detected ON fraud_alerts(detected_at DESC);

CREATE TABLE banned_users (
    user_id     BIGINT PRIMARY KEY REFERENCES users(id),
    ban_reason  TEXT NOT NULL,
    banned_by   TEXT,
    banned_at   TIMESTAMPTZ DEFAULT NOW(),
    banned_until TIMESTAMPTZ,
    is_permanent BOOLEAN DEFAULT FALSE
);
