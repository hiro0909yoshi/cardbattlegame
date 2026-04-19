package model

import (
	"encoding/json"
	"time"
)

type User struct {
	ID               int64      `json:"id"`
	UserID           string     `json:"user_id"`
	DeviceID         *string    `json:"device_id,omitempty"`
	DisplayName      string     `json:"display_name"`
	PasswordHash     *string    `json:"-"`
	AuthProvider     string     `json:"auth_provider"`
	RefreshTokenHash *string    `json:"-"`
	TokenExpiresAt   *time.Time `json:"-"`
	Status           string     `json:"status"`
	TransferCode     *string    `json:"-"`

	// TrueSkill
	TsMu        float64 `json:"ts_mu"`
	TsSigma     float64 `json:"ts_sigma"`
	DisplayRate float64 `json:"display_rate"`
	RankTier    string  `json:"rank_tier"`

	// ランクマッチ戦績
	RankedWins   int `json:"ranked_wins"`
	RankedLosses int `json:"ranked_losses"`
	RankedDraws  int `json:"ranked_draws"`

	// プロフィール
	PlayerLevel     int        `json:"player_level"`
	Experience      int        `json:"experience"`
	Gold            int        `json:"gold"`
	Stone           int        `json:"stone"`
	Stamina         int        `json:"stamina"`
	StaminaMax      int        `json:"stamina_max"`
	StaminaUpdatedAt *time.Time `json:"stamina_updated_at,omitempty"`
	TitleID         *string    `json:"title_id,omitempty"`
	FavoriteCardID  *int       `json:"favorite_card_id,omitempty"`
	CharacterID     string     `json:"character_id"`

	// デッキ・インベントリ
	MaxDecks  int             `json:"max_decks"`
	Inventory json.RawMessage `json:"inventory"`
	Settings  json.RawMessage `json:"settings"`

	// ログインボーナス
	LoginStreak      int     `json:"login_streak"`
	TotalLoginDays   int     `json:"total_login_days"`
	LastLoginDate    *string `json:"last_login_date,omitempty"`
	LastDailyDate    *string `json:"last_daily_date,omitempty"`
	ClaimedCampaigns json.RawMessage `json:"claimed_campaigns"`

	CreatedAt   time.Time  `json:"created_at"`
	LastLoginAt *time.Time `json:"last_login_at,omitempty"`
}
