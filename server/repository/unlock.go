package repository

import (
	"context"
	"fmt"

	"arcana-conquest-server/model"

	"github.com/jackc/pgx/v5/pgxpool"
)

type UnlockRepo struct {
	pool *pgxpool.Pool
}

func NewUnlockRepo(pool *pgxpool.Pool) *UnlockRepo {
	return &UnlockRepo{pool: pool}
}

func (r *UnlockRepo) Add(ctx context.Context, userID int64, key, unlockType string) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO user_unlocks (user_id, unlock_key, unlock_type)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, unlock_key) DO NOTHING`, userID, key, unlockType); err != nil {
		return fmt.Errorf("add unlock %s for user %d: %w", key, userID, err)
	}
	return nil
}

func (r *UnlockRepo) GetAll(ctx context.Context, userID int64) ([]model.UserUnlock, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, unlock_key, unlock_type, unlocked_at
		FROM user_unlocks WHERE user_id=$1`, userID)
	if err != nil {
		return nil, fmt.Errorf("get unlocks %d: %w", userID, err)
	}
	defer rows.Close()

	var unlocks []model.UserUnlock
	for rows.Next() {
		var u model.UserUnlock
		if err := rows.Scan(&u.ID, &u.UserID, &u.UnlockKey, &u.UnlockType, &u.UnlockedAt); err != nil {
			return nil, err
		}
		unlocks = append(unlocks, u)
	}
	return unlocks, rows.Err()
}

func (r *UnlockRepo) HasKey(ctx context.Context, userID int64, key string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM user_unlocks WHERE user_id=$1 AND unlock_key=$2)`,
		userID, key).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("has unlock key %s for user %d: %w", key, userID, err)
	}
	return exists, nil
}

func (r *UnlockRepo) Remove(ctx context.Context, userID int64, key string) error {
	if _, err := r.pool.Exec(ctx, `DELETE FROM user_unlocks WHERE user_id=$1 AND unlock_key=$2`, userID, key); err != nil {
		return fmt.Errorf("remove unlock %s for user %d: %w", key, userID, err)
	}
	return nil
}
