package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"arcana-conquest-server/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PlayerStatsRepo struct {
	pool *pgxpool.Pool
}

func NewPlayerStatsRepo(pool *pgxpool.Pool) *PlayerStatsRepo {
	return &PlayerStatsRepo{pool: pool}
}

func (r *PlayerStatsRepo) Upsert(ctx context.Context, s *model.PlayerStats) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO player_stats (
			user_id, total_battles, total_wins, total_losses, play_time_seconds,
			story_cleared, gacha_count, cards_obtained, total_gold_earned,
			quest_plays, quest_clears, quest_battles, quest_creature_summons, quest_spell_uses,
			net_battle_plays, net_battle_wins, net_battle_battles, net_battle_creature_summons, net_battle_spell_uses,
			collection_complete, updated_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			total_battles=$2, total_wins=$3, total_losses=$4, play_time_seconds=$5,
			story_cleared=$6, gacha_count=$7, cards_obtained=$8, total_gold_earned=$9,
			quest_plays=$10, quest_clears=$11, quest_battles=$12, quest_creature_summons=$13, quest_spell_uses=$14,
			net_battle_plays=$15, net_battle_wins=$16, net_battle_battles=$17, net_battle_creature_summons=$18, net_battle_spell_uses=$19,
			collection_complete=$20, updated_at=NOW()`,
		s.UserID, s.TotalBattles, s.TotalWins, s.TotalLosses, s.PlayTimeSeconds,
		s.StoryCleared, s.GachaCount, s.CardsObtained, s.TotalGoldEarned,
		s.QuestPlays, s.QuestClears, s.QuestBattles, s.QuestCreatureSummons, s.QuestSpellUses,
		s.NetBattlePlays, s.NetBattleWins, s.NetBattleBattles, s.NetBattleCreatureSummons, s.NetBattleSpellUses,
		s.CollectionComplete,
	)
	if err != nil {
		return fmt.Errorf("upsert player stats %d: %w", s.UserID, err)
	}
	return nil
}

func (r *PlayerStatsRepo) GetByUserID(ctx context.Context, userID int64) (*model.PlayerStats, error) {
	s := &model.PlayerStats{}
	err := r.pool.QueryRow(ctx, `
		SELECT user_id, total_battles, total_wins, total_losses, play_time_seconds,
		       story_cleared, gacha_count, cards_obtained, total_gold_earned,
		       quest_plays, quest_clears, quest_battles, quest_creature_summons, quest_spell_uses,
		       net_battle_plays, net_battle_wins, net_battle_battles, net_battle_creature_summons, net_battle_spell_uses,
		       collection_complete, updated_at
		FROM player_stats WHERE user_id=$1`, userID,
	).Scan(
		&s.UserID, &s.TotalBattles, &s.TotalWins, &s.TotalLosses, &s.PlayTimeSeconds,
		&s.StoryCleared, &s.GachaCount, &s.CardsObtained, &s.TotalGoldEarned,
		&s.QuestPlays, &s.QuestClears, &s.QuestBattles, &s.QuestCreatureSummons, &s.QuestSpellUses,
		&s.NetBattlePlays, &s.NetBattleWins, &s.NetBattleBattles, &s.NetBattleCreatureSummons, &s.NetBattleSpellUses,
		&s.CollectionComplete, &s.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get player stats %d: %w", userID, err)
	}
	return s, nil
}

func (r *PlayerStatsRepo) IncrementBattle(ctx context.Context, userID int64, won bool) error {
	winInc, lossInc := 0, 0
	if won {
		winInc = 1
	} else {
		lossInc = 1
	}
	_, err := r.pool.Exec(ctx, `
		UPDATE player_stats SET
			total_battles = total_battles + 1,
			total_wins = total_wins + $2,
			total_losses = total_losses + $3,
			updated_at = NOW()
		WHERE user_id = $1`, userID, winInc, lossInc)
	if err != nil {
		return fmt.Errorf("increment battle %d: %w", userID, err)
	}
	return nil
}

func (r *PlayerStatsRepo) UpdateCollectionComplete(ctx context.Context, userID int64, cc json.RawMessage) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE player_stats SET collection_complete=$2, updated_at=NOW()
		WHERE user_id=$1`, userID, cc); err != nil {
		return fmt.Errorf("update collection complete %d: %w", userID, err)
	}
	return nil
}
