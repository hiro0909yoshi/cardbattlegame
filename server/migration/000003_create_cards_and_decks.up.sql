CREATE TABLE user_cards (
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_id     INTEGER NOT NULL,
    count       INTEGER DEFAULT 0,
    card_level  INTEGER DEFAULT 1,
    obtained    BOOLEAN DEFAULT FALSE,
    PRIMARY KEY(user_id, card_id)
);

CREATE INDEX idx_user_cards_user ON user_cards(user_id);

CREATE TABLE user_deck_slots (
    user_id     BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    max_slots   INTEGER DEFAULT 6
);

CREATE TABLE decks (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    slot_index  INTEGER NOT NULL,
    deck_name   TEXT NOT NULL DEFAULT 'デッキ',
    cards       JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ,
    UNIQUE(user_id, slot_index)
);
