package matchmaking

import (
	"log/slog"
	"sync"
	"time"
)

type QueueEntry struct {
	UserID      int64
	UserUUID    string
	DisplayRate float64
	DeckID      string
	JoinedAt    time.Time
}

type MatchFound struct {
	Players []QueueEntry
	RoomID  string
}

type CreateRoomFunc func(entries []QueueEntry) string

type Queue struct {
	mu          sync.Mutex
	entries     map[string][]QueueEntry // tier -> entries
	pending     map[int64]string        // userID -> tier (for cancel)
	matchSize   int
	createRoom  CreateRoomFunc
	stop        chan struct{}
}

const (
	scanInterval     = 1 * time.Second
	baseRateRange    = 5.0
	rateExpansion    = 5.0  // +5 per 10 seconds
	expansionInterval = 10.0
)

var tierOrder = []string{"bronze", "silver", "gold", "platinum", "diamond"}

func NewQueue(matchSize int, createRoom CreateRoomFunc) *Queue {
	q := &Queue{
		entries:    make(map[string][]QueueEntry),
		pending:    make(map[int64]string),
		matchSize:  matchSize,
		createRoom: createRoom,
		stop:       make(chan struct{}),
	}
	go q.scanLoop()
	return q
}

func (q *Queue) Enqueue(entry QueueEntry) bool {
	q.mu.Lock()
	defer q.mu.Unlock()

	if _, exists := q.pending[entry.UserID]; exists {
		return false
	}

	tier := rateTier(entry.DisplayRate)
	q.entries[tier] = append(q.entries[tier], entry)
	q.pending[entry.UserID] = tier
	slog.Info("matchmaking enqueue", "user", entry.UserID, "rate", entry.DisplayRate, "tier", tier)
	return true
}

func (q *Queue) Cancel(userID int64) bool {
	q.mu.Lock()
	defer q.mu.Unlock()

	tier, ok := q.pending[userID]
	if !ok {
		return false
	}

	entries := q.entries[tier]
	for i, e := range entries {
		if e.UserID == userID {
			q.entries[tier] = append(entries[:i], entries[i+1:]...)
			break
		}
	}
	delete(q.pending, userID)
	slog.Info("matchmaking cancel", "user", userID)
	return true
}

func (q *Queue) Stop() {
	close(q.stop)
}

func (q *Queue) scanLoop() {
	ticker := time.NewTicker(scanInterval)
	defer ticker.Stop()

	for {
		select {
		case <-q.stop:
			return
		case <-ticker.C:
			q.scan()
		}
	}
}

func (q *Queue) scan() {
	q.mu.Lock()
	defer q.mu.Unlock()

	now := time.Now()

	for _, tier := range tierOrder {
		entries := q.entries[tier]
		if len(entries) < q.matchSize {
			continue
		}

		// Try to form matches within the same tier
		matched := q.tryMatch(entries, now)
		if matched != nil {
			q.formMatch(tier, matched)
			continue
		}
	}

	// Cross-tier matching for long-waiting players
	q.tryCrossTierMatch(now)
}

func (q *Queue) tryMatch(entries []QueueEntry, now time.Time) []int {
	for i := 0; i < len(entries); i++ {
		group := []int{i}
		for j := i + 1; j < len(entries) && len(group) < q.matchSize; j++ {
			waitI := now.Sub(entries[i].JoinedAt).Seconds()
			threshold := baseRateRange + (waitI/expansionInterval)*rateExpansion
			diff := abs(entries[i].DisplayRate - entries[j].DisplayRate)
			if diff <= threshold {
				group = append(group, j)
			}
		}
		if len(group) >= q.matchSize {
			return group[:q.matchSize]
		}
	}
	return nil
}

func (q *Queue) tryCrossTierMatch(now time.Time) {
	// Combine all entries sorted by wait time, try matching across tiers
	var all []struct {
		tier  string
		index int
		entry QueueEntry
	}
	for tier, entries := range q.entries {
		for i, e := range entries {
			waitTime := now.Sub(e.JoinedAt).Seconds()
			if waitTime >= 30 { // Only cross-tier after 30s wait
				all = append(all, struct {
					tier  string
					index int
					entry QueueEntry
				}{tier, i, e})
			}
		}
	}

	if len(all) < q.matchSize {
		return
	}

	// Simple greedy: pick first matchSize players with closest rates
	// Sort by rate
	for i := 0; i < len(all); i++ {
		for j := i + 1; j < len(all); j++ {
			if all[j].entry.DisplayRate < all[i].entry.DisplayRate {
				all[i], all[j] = all[j], all[i]
			}
		}
	}

	// Sliding window
	for i := 0; i <= len(all)-q.matchSize; i++ {
		window := all[i : i+q.matchSize]
		maxDiff := window[q.matchSize-1].entry.DisplayRate - window[0].entry.DisplayRate
		maxWait := 0.0
		for _, w := range window {
			wt := now.Sub(w.entry.JoinedAt).Seconds()
			if wt > maxWait {
				maxWait = wt
			}
		}
		threshold := baseRateRange + (maxWait/expansionInterval)*rateExpansion
		if maxDiff <= threshold {
			// Match found
			var matched []QueueEntry
			for _, w := range window {
				matched = append(matched, w.entry)
			}
			// Remove from queues
			for _, w := range window {
				q.removeEntry(w.tier, w.entry.UserID)
				delete(q.pending, w.entry.UserID)
			}
			roomID := q.createRoom(matched)
			slog.Info("cross-tier match formed", "room", roomID, "players", len(matched))
			return
		}
	}
}

func (q *Queue) formMatch(tier string, indices []int) {
	entries := q.entries[tier]
	var matched []QueueEntry

	// Collect matched entries (reverse order to preserve indices during removal)
	for _, idx := range indices {
		matched = append(matched, entries[idx])
	}

	// Remove matched entries from queue (reverse order)
	for i := len(indices) - 1; i >= 0; i-- {
		idx := indices[i]
		q.entries[tier] = append(q.entries[tier][:idx], q.entries[tier][idx+1:]...)
	}

	for _, e := range matched {
		delete(q.pending, e.UserID)
	}

	roomID := q.createRoom(matched)
	slog.Info("match formed", "room", roomID, "tier", tier, "players", len(matched))
}

func (q *Queue) removeEntry(tier string, userID int64) {
	entries := q.entries[tier]
	for i, e := range entries {
		if e.UserID == userID {
			q.entries[tier] = append(entries[:i], entries[i+1:]...)
			return
		}
	}
}

func (q *Queue) QueueSize() int {
	q.mu.Lock()
	defer q.mu.Unlock()
	return len(q.pending)
}

func rateTier(rate float64) string {
	switch {
	case rate >= 40:
		return "diamond"
	case rate >= 30:
		return "platinum"
	case rate >= 20:
		return "gold"
	case rate >= 10:
		return "silver"
	default:
		return "bronze"
	}
}

func abs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}
