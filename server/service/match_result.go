package service

import (
	"context"
	"fmt"
	"log/slog"

	"arcana-conquest-server/game"
	"arcana-conquest-server/rating"
	"arcana-conquest-server/repository"

	"github.com/jackc/pgx/v5/pgxpool"
)

type MatchResultProcessor struct {
	pool         *pgxpool.Pool
	users        *repository.UserRepo
	stats        *repository.PlayerStatsRepo
	matchHistory *repository.MatchHistoryRepo
}

func NewMatchResultProcessor(pool *pgxpool.Pool, users *repository.UserRepo, stats *repository.PlayerStatsRepo, matchHistory *repository.MatchHistoryRepo) *MatchResultProcessor {
	return &MatchResultProcessor{pool: pool, users: users, stats: stats, matchHistory: matchHistory}
}

func (p *MatchResultProcessor) ProcessRankedResult(ctx context.Context, gs *game.GameState, matchType string) ([]game.PlayerResult, error) {
	if matchType != "ranked" {
		return nil, nil
	}

	var players []rating.Player
	var ranks []int
	for _, ps := range gs.Players {
		u, err := p.users.GetByID(ctx, ps.InternalID)
		if err != nil || u == nil {
			slog.Warn("player not found for rating", "id", ps.InternalID)
			players = append(players, rating.Player{Mu: rating.InitialMu, Sigma: rating.InitialSigma})
		} else {
			players = append(players, rating.Player{Mu: u.TsMu, Sigma: u.TsSigma})
		}
		ranks = append(ranks, ps.FinalRank)
	}

	updated := rating.Update(rating.MatchResult{
		Players: players,
		Ranks:   ranks,
	})

	var results []game.PlayerResult
	for i, ps := range gs.Players {
		newRate := rating.DisplayRate(updated[i].Mu, updated[i].Sigma)
		newTier := rating.RankTier(newRate)
		oldRate := rating.DisplayRate(players[i].Mu, players[i].Sigma)

		results = append(results, game.PlayerResult{
			InternalID:  ps.InternalID,
			UserUUID:    ps.UserID,
			FinalRank:   ps.FinalRank,
			OldMu:       players[i].Mu,
			OldSigma:    players[i].Sigma,
			NewMu:       updated[i].Mu,
			NewSigma:    updated[i].Sigma,
			DisplayRate: newRate,
			RankTier:    newTier,
			RateChange:  newRate - oldRate,
		})
	}

	// All DB writes in a single transaction
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		slog.Error("failed to begin match result tx", "err", err)
		return results, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	for i, ps := range gs.Players {
		if _, err := tx.Exec(ctx, `
			UPDATE users SET ts_mu=$2, ts_sigma=$3, display_rate=$4, rank_tier=$5
			WHERE id=$1`,
			ps.InternalID, updated[i].Mu, updated[i].Sigma, results[i].DisplayRate, results[i].RankTier,
		); err != nil {
			slog.Error("failed to update trueskill in tx", "user", ps.InternalID, "err", err)
			return results, fmt.Errorf("update trueskill user %d: %w", ps.InternalID, err)
		}

		winInc, lossInc := 0, 0
		if ps.FinalRank == 1 {
			winInc = 1
		} else {
			lossInc = 1
		}
		if _, err := tx.Exec(ctx, `
			UPDATE player_stats SET
				total_battles = total_battles + 1,
				total_wins = total_wins + $2,
				total_losses = total_losses + $3,
				updated_at = NOW()
			WHERE user_id = $1`,
			ps.InternalID, winInc, lossInc,
		); err != nil {
			slog.Error("failed to update stats in tx", "user", ps.InternalID, "err", err)
			return results, fmt.Errorf("update stats user %d: %w", ps.InternalID, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		slog.Error("failed to commit match result tx", "err", err)
		return results, fmt.Errorf("commit tx: %w", err)
	}

	slog.Info("match results committed",
		"players", len(gs.Players),
		"match_type", matchType,
	)

	return results, nil
}

// SaveMatchHistory persists match history for all match types.
// Called from onGameOver callback in ws/room.go.
func (p *MatchResultProcessor) SaveMatchHistory(ctx context.Context, gs *game.GameState, matchType, mapID, rulePreset string, initialMagic, targetMagic, maxTurns, duration int) {
	if p.matchHistory == nil {
		slog.Warn("match history repo not initialized")
		return
	}

	players := make([]repository.MatchPlayerRecord, 0, len(gs.Players))
	for _, ps := range gs.Players {
		players = append(players, repository.MatchPlayerRecord{
			UserID:    ps.InternalID,
			FinalRank: ps.FinalRank,
			DeckID:    "", // Note: DeckID not currently tracked in PlayerState, can be added if needed
			FinalTEP:  ps.TEP,
		})
	}

	record := repository.MatchRecord{
		MatchType:    matchType,
		PlayerCount:  len(gs.Players),
		MapID:        mapID,
		RulePreset:   rulePreset,
		InitialMagic: initialMagic,
		TargetMagic:  targetMagic,
		MaxTurns:     maxTurns,
		TotalTurns:   gs.TotalTurns,
		Duration:     duration,
	}

	if err := p.matchHistory.InsertMatch(ctx, record, players); err != nil {
		slog.Error("failed to save match history", "err", err)
	}
}

// Pool returns the pool for external use (e.g., main.go wiring).
func (p *MatchResultProcessor) Pool() *pgxpool.Pool {
	return p.pool
}
