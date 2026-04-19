package model

import "time"

type UserUnlock struct {
	ID         int64     `json:"id"`
	UserID     int64     `json:"user_id"`
	UnlockKey  string    `json:"unlock_key"`
	UnlockType string    `json:"unlock_type"`
	UnlockedAt time.Time `json:"unlocked_at"`
}
