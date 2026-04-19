package game

import "fmt"

type PlayerResult struct {
	InternalID   int64
	UserUUID     string
	FinalRank    int
	OldMu        float64
	OldSigma     float64
	NewMu        float64
	NewSigma     float64
	DisplayRate  float64
	RankTier     string
	RateChange   float64
}

// FormatRateChange returns a human-readable rate change string.
func FormatRateChange(change float64) string {
	if change >= 0 {
		return fmt.Sprintf("+%.2f", change)
	}
	return fmt.Sprintf("%.2f", change)
}
