package rating

import "math"

const (
	InitialMu    = 25.0
	InitialSigma = 8.333
	Beta         = 4.167
	Tau          = 0.083
	DrawProb     = 0.0
)

type Player struct {
	Mu    float64
	Sigma float64
}

type MatchResult struct {
	Players []Player
	Ranks   []int // 1-based rank for each player (1 = winner)
}

// Update computes new TrueSkill ratings for a multiplayer match.
// Simplified 2-team pairwise update for 2-4 player FFA.
func Update(result MatchResult) []Player {
	n := len(result.Players)
	updated := make([]Player, n)
	for i := range result.Players {
		updated[i] = Player{
			Mu:    result.Players[i].Mu,
			Sigma: result.Players[i].Sigma,
		}
	}

	// Pairwise update: each pair of players exchanges rating based on their relative rank
	for i := 0; i < n; i++ {
		for j := i + 1; j < n; j++ {
			rank1 := result.Ranks[i]
			rank2 := result.Ranks[j]

			// who won in this pair?
			var winner, loser int
			if rank1 < rank2 {
				winner, loser = i, j
			} else if rank2 < rank1 {
				winner, loser = j, i
			} else {
				continue // same rank = no update
			}

			muW := result.Players[winner].Mu
			sigmaW := result.Players[winner].Sigma
			muL := result.Players[loser].Mu
			sigmaL := result.Players[loser].Sigma

			c := math.Sqrt(2*Beta*Beta + sigmaW*sigmaW + sigmaL*sigmaL)
			t := (muW - muL) / c
			v := vFunc(t)
			w := wFunc(t)

			// Scale factor for multi-player (dampen updates)
			scale := 2.0 / float64(n)

			// Winner update
			updated[winner].Mu += scale * (sigmaW * sigmaW / c) * v
			newSigmaW2 := sigmaW*sigmaW*(1 - scale*(sigmaW*sigmaW/(c*c))*w)
			if newSigmaW2 > 0 {
				updated[winner].Sigma = math.Sqrt(newSigmaW2)
			}

			// Loser update
			updated[loser].Mu -= scale * (sigmaL * sigmaL / c) * v
			newSigmaL2 := sigmaL*sigmaL*(1 - scale*(sigmaL*sigmaL/(c*c))*w)
			if newSigmaL2 > 0 {
				updated[loser].Sigma = math.Sqrt(newSigmaL2)
			}
		}
	}

	// Apply dynamics factor τ
	for i := range updated {
		updated[i].Sigma = math.Sqrt(updated[i].Sigma*updated[i].Sigma + Tau*Tau)
	}

	return updated
}

func DisplayRate(mu, sigma float64) float64 {
	rate := mu - 3*sigma
	if rate < 0 {
		rate = 0
	}
	return math.Round(rate*100) / 100
}

func RankTier(displayRate float64) string {
	switch {
	case displayRate >= 40:
		return tierSub("diamond", displayRate, 40)
	case displayRate >= 30:
		return tierSub("platinum", displayRate, 30)
	case displayRate >= 20:
		return tierSub("gold", displayRate, 20)
	case displayRate >= 10:
		return tierSub("silver", displayRate, 10)
	default:
		return tierSub("bronze", displayRate, 0)
	}
}

func tierSub(name string, rate, base float64) string {
	sub := int((rate-base)/3.334) + 1
	if sub > 3 {
		sub = 3
	}
	if sub < 1 {
		sub = 1
	}
	return name + "_" + string(rune('0'+sub))
}

// Gaussian PDF and CDF helpers
func vFunc(t float64) float64 {
	return pdf(t) / cdf(t)
}

func wFunc(t float64) float64 {
	v := vFunc(t)
	return v * (v + t)
}

func pdf(x float64) float64 {
	return math.Exp(-x*x/2) / math.Sqrt(2*math.Pi)
}

func cdf(x float64) float64 {
	return 0.5 * math.Erfc(-x/math.Sqrt2)
}
