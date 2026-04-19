package model

import (
	"encoding/json"
	"time"
)

type UserCard struct {
	UserID   int64 `json:"user_id"`
	CardID   int   `json:"card_id"`
	Count    int   `json:"count"`
	Level    int   `json:"card_level"`
	Obtained bool  `json:"obtained"`
}

type Deck struct {
	ID        int64           `json:"id"`
	UserID    int64           `json:"user_id"`
	SlotIndex int             `json:"slot_index"`
	DeckName  string          `json:"deck_name"`
	Cards     json.RawMessage `json:"cards"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt *time.Time      `json:"updated_at,omitempty"`
}
