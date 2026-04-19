package repository

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type MatchHistoryRepo struct {
	pool *pgxpool.Pool
}

func NewMatchHistoryRepo(pool *pgxpool.Pool) *MatchHistoryRepo {
	return &MatchHistoryRepo{pool: pool}
}

type MatchRecord struct {
	MatchType    string
	PlayerCount  int
	MapID        string
	RulePreset   string
	InitialMagic int
	TargetMagic  int
	MaxTurns     int
	TotalTurns   int
	Duration     int // seconds
}

type MatchPlayerRecord struct {
	UserID    int64
	FinalRank int
	DeckID    string
	FinalTEP  int
}

// InsertMatch writes match history and player results in a single transaction
func (r *MatchHistoryRepo) InsertMatch(ctx context.Context, m MatchRecord, players []MatchPlayerRecord) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin match history tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var matchID int64
	err = tx.QueryRow(ctx, `
		INSERT INTO match_history (match_type, player_count, map_id, rule_preset, initial_magic, target_magic, max_turns, total_turns, duration, played_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
		RETURNING id`,
		m.MatchType, m.PlayerCount, m.MapID, m.RulePreset, m.InitialMagic, m.TargetMagic, m.MaxTurns, m.TotalTurns, m.Duration,
	).Scan(&matchID)
	if err != nil {
		return fmt.Errorf("insert match_history: %w", err)
	}

	for _, p := range players {
		if _, err := tx.Exec(ctx, `
			INSERT INTO match_players (match_id, user_id, final_rank, deck_id, final_tep)
			VALUES ($1, $2, $3, $4, $5)`,
			matchID, p.UserID, p.FinalRank, p.DeckID, p.FinalTEP,
		); err != nil {
			return fmt.Errorf("insert match_player user %d: %w", p.UserID, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit match history: %w", err)
	}

	slog.Info("match history saved", "match_id", matchID, "player_count", len(players))
	return nil
}

// GetMatchHistory retrieves match history with optional limit
func (r *MatchHistoryRepo) GetMatchHistory(ctx context.Context, limit int) ([]map[string]any, error) {
	if limit <= 0 {
		limit = 100
	}

	rows, err := r.pool.Query(ctx, `
		SELECT id, match_type, player_count, map_id, rule_preset, initial_magic, target_magic, max_turns, total_turns, duration, played_at
		FROM match_history
		ORDER BY played_at DESC
		LIMIT $1`,
		limit,
	)
	if err != nil {
		return nil, fmt.Errorf("query match history: %w", err)
	}
	defer rows.Close()

	var results []map[string]any
	for rows.Next() {
		var id int64
		var matchType, mapID, rulePreset string
		var playerCount, initialMagic, targetMagic, maxTurns, totalTurns, duration int
		var playedAt time.Time

		if err := rows.Scan(&id, &matchType, &playerCount, &mapID, &rulePreset, &initialMagic, &targetMagic, &maxTurns, &totalTurns, &duration, &playedAt); err != nil {
			return nil, fmt.Errorf("scan match history row: %w", err)
		}

		results = append(results, map[string]any{
			"id":             id,
			"match_type":     matchType,
			"player_count":   playerCount,
			"map_id":         mapID,
			"rule_preset":    rulePreset,
			"initial_magic":  initialMagic,
			"target_magic":   targetMagic,
			"max_turns":      maxTurns,
			"total_turns":    totalTurns,
			"duration":       duration,
			"played_at":      playedAt,
		})
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("match history rows error: %w", err)
	}

	return results, nil
}
