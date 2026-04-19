package model

import (
	"encoding/json"
	"time"
)

type PlayerStats struct {
	UserID                   int64           `json:"user_id"`
	TotalBattles             int             `json:"total_battles"`
	TotalWins                int             `json:"total_wins"`
	TotalLosses              int             `json:"total_losses"`
	PlayTimeSeconds          int             `json:"play_time_seconds"`
	StoryCleared             int             `json:"story_cleared"`
	GachaCount               int             `json:"gacha_count"`
	CardsObtained            int             `json:"cards_obtained"`
	TotalGoldEarned          int             `json:"total_gold_earned"`
	QuestPlays               int             `json:"quest_plays"`
	QuestClears              int             `json:"quest_clears"`
	QuestBattles             int             `json:"quest_battles"`
	QuestCreatureSummons     int             `json:"quest_creature_summons"`
	QuestSpellUses           int             `json:"quest_spell_uses"`
	NetBattlePlays           int             `json:"net_battle_plays"`
	NetBattleWins            int             `json:"net_battle_wins"`
	NetBattleBattles         int             `json:"net_battle_battles"`
	NetBattleCreatureSummons int             `json:"net_battle_creature_summons"`
	NetBattleSpellUses       int             `json:"net_battle_spell_uses"`
	CollectionComplete       json.RawMessage `json:"collection_complete"`
	UpdatedAt                time.Time       `json:"updated_at"`
}
