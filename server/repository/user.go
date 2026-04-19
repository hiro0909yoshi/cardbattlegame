package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"arcana-conquest-server/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserRepo struct {
	pool *pgxpool.Pool
}

func NewUserRepo(pool *pgxpool.Pool) *UserRepo {
	return &UserRepo{pool: pool}
}

func (r *UserRepo) Create(ctx context.Context, u *model.User) error {
	inv, _ := json.Marshal(map[string]any{})
	if u.Inventory != nil {
		inv = u.Inventory
	}
	settings, _ := json.Marshal(map[string]any{
		"master_volume":  1.0,
		"bgm_volume":     0.8,
		"se_volume":      1.0,
		"language":       "ja",
		"auto_save":      true,
		"lightweight_mode": false,
	})
	if u.Settings != nil {
		settings = u.Settings
	}
	campaigns, _ := json.Marshal([]string{})
	if u.ClaimedCampaigns != nil {
		campaigns = u.ClaimedCampaigns
	}

	if err := r.pool.QueryRow(ctx, `
		INSERT INTO users (user_id, device_id, display_name, password_hash, auth_provider, character_id, inventory, settings, claimed_campaigns)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, created_at`,
		u.UserID, u.DeviceID, u.DisplayName, u.PasswordHash, u.AuthProvider, u.CharacterID, inv, settings, campaigns,
	).Scan(&u.ID, &u.CreatedAt); err != nil {
		return fmt.Errorf("create user %s: %w", u.UserID, err)
	}
	return nil
}

func (r *UserRepo) GetByID(ctx context.Context, id int64) (*model.User, error) {
	u := &model.User{}
	err := r.pool.QueryRow(ctx, `
		SELECT id, user_id, device_id, display_name, auth_provider, status,
		       ts_mu, ts_sigma, display_rate, rank_tier,
		       ranked_wins, ranked_losses, ranked_draws,
		       player_level, experience, gold, stone,
		       stamina, stamina_max, stamina_updated_at,
		       title_id, favorite_card_id, character_id,
		       max_decks, inventory, settings,
		       login_streak, total_login_days, last_login_date, last_daily_date, claimed_campaigns,
		       created_at, last_login_at
		FROM users WHERE id = $1`, id,
	).Scan(
		&u.ID, &u.UserID, &u.DeviceID, &u.DisplayName, &u.AuthProvider, &u.Status,
		&u.TsMu, &u.TsSigma, &u.DisplayRate, &u.RankTier,
		&u.RankedWins, &u.RankedLosses, &u.RankedDraws,
		&u.PlayerLevel, &u.Experience, &u.Gold, &u.Stone,
		&u.Stamina, &u.StaminaMax, &u.StaminaUpdatedAt,
		&u.TitleID, &u.FavoriteCardID, &u.CharacterID,
		&u.MaxDecks, &u.Inventory, &u.Settings,
		&u.LoginStreak, &u.TotalLoginDays, &u.LastLoginDate, &u.LastDailyDate, &u.ClaimedCampaigns,
		&u.CreatedAt, &u.LastLoginAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get user by id %d: %w", id, err)
	}
	return u, nil
}

func (r *UserRepo) GetByUserID(ctx context.Context, userID string) (*model.User, error) {
	u := &model.User{}
	err := r.pool.QueryRow(ctx, `
		SELECT id, user_id, device_id, display_name, password_hash, auth_provider,
		       refresh_token_hash, token_expires_at, status,
		       ts_mu, ts_sigma, display_rate, rank_tier,
		       ranked_wins, ranked_losses, ranked_draws,
		       player_level, experience, gold, stone,
		       stamina, stamina_max, stamina_updated_at,
		       title_id, favorite_card_id, character_id,
		       max_decks, inventory, settings,
		       login_streak, total_login_days, last_login_date, last_daily_date, claimed_campaigns,
		       created_at, last_login_at
		FROM users WHERE user_id = $1`, userID,
	).Scan(
		&u.ID, &u.UserID, &u.DeviceID, &u.DisplayName, &u.PasswordHash, &u.AuthProvider,
		&u.RefreshTokenHash, &u.TokenExpiresAt, &u.Status,
		&u.TsMu, &u.TsSigma, &u.DisplayRate, &u.RankTier,
		&u.RankedWins, &u.RankedLosses, &u.RankedDraws,
		&u.PlayerLevel, &u.Experience, &u.Gold, &u.Stone,
		&u.Stamina, &u.StaminaMax, &u.StaminaUpdatedAt,
		&u.TitleID, &u.FavoriteCardID, &u.CharacterID,
		&u.MaxDecks, &u.Inventory, &u.Settings,
		&u.LoginStreak, &u.TotalLoginDays, &u.LastLoginDate, &u.LastDailyDate, &u.ClaimedCampaigns,
		&u.CreatedAt, &u.LastLoginAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get user by user_id %s: %w", userID, err)
	}
	return u, nil
}

func (r *UserRepo) UpdateProfile(ctx context.Context, id int64, name string, titleID *string, charID string, favCardID *int) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE users SET display_name=$2, title_id=$3, character_id=$4, favorite_card_id=$5
		WHERE id=$1`, id, name, titleID, charID, favCardID); err != nil {
		return fmt.Errorf("update profile %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateGold(ctx context.Context, id int64, gold int) error {
	if _, err := r.pool.Exec(ctx, `UPDATE users SET gold=$2 WHERE id=$1`, id, gold); err != nil {
		return fmt.Errorf("update gold %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateStone(ctx context.Context, id int64, stone int) error {
	if _, err := r.pool.Exec(ctx, `UPDATE users SET stone=$2 WHERE id=$1`, id, stone); err != nil {
		return fmt.Errorf("update stone %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateStamina(ctx context.Context, id int64, current, max int) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE users SET stamina=$2, stamina_max=$3, stamina_updated_at=$4
		WHERE id=$1`, id, current, max, time.Now()); err != nil {
		return fmt.Errorf("update stamina %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateLoginBonus(ctx context.Context, id int64, streak, totalDays int, lastLogin, lastDaily string, campaigns json.RawMessage) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE users SET login_streak=$2, total_login_days=$3, last_login_date=$4, last_daily_date=$5, claimed_campaigns=$6, last_login_at=$7
		WHERE id=$1`, id, streak, totalDays, lastLogin, lastDaily, campaigns, time.Now()); err != nil {
		return fmt.Errorf("update login bonus %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateSettings(ctx context.Context, id int64, settings json.RawMessage) error {
	if _, err := r.pool.Exec(ctx, `UPDATE users SET settings=$2 WHERE id=$1`, id, settings); err != nil {
		return fmt.Errorf("update settings %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateInventory(ctx context.Context, id int64, inventory json.RawMessage) error {
	if _, err := r.pool.Exec(ctx, `UPDATE users SET inventory=$2 WHERE id=$1`, id, inventory); err != nil {
		return fmt.Errorf("update inventory %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateTrueSkill(ctx context.Context, id int64, mu, sigma, rate float64, tier string) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE users SET ts_mu=$2, ts_sigma=$3, display_rate=$4, rank_tier=$5
		WHERE id=$1`, id, mu, sigma, rate, tier); err != nil {
		return fmt.Errorf("update trueskill %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateRefreshToken(ctx context.Context, id int64, hash string, expiresAt time.Time) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE users SET refresh_token_hash=$2, token_expires_at=$3
		WHERE id=$1`, id, hash, expiresAt); err != nil {
		return fmt.Errorf("update refresh token %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) UpdateTransferCode(ctx context.Context, id int64, code string) error {
	if _, err := r.pool.Exec(ctx, `UPDATE users SET transfer_code=$2 WHERE id=$1`, id, code); err != nil {
		return fmt.Errorf("update transfer code %d: %w", id, err)
	}
	return nil
}

func (r *UserRepo) GetByTransferCode(ctx context.Context, code string) (*model.User, error) {
	u := &model.User{}
	err := r.pool.QueryRow(ctx, `SELECT id, user_id, display_name FROM users WHERE transfer_code=$1`, code).
		Scan(&u.ID, &u.UserID, &u.DisplayName)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get user by transfer code: %w", err)
	}
	return u, nil
}
