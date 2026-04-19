package handler

import (
	"encoding/json"
	"net/http"

	"arcana-conquest-server/auth"
	"arcana-conquest-server/repository"
)

type PlayerHandler struct {
	users *repository.UserRepo
	stats *repository.PlayerStatsRepo
	cards *repository.CardRepo
	unlocks *repository.UnlockRepo
}

func NewPlayerHandler(users *repository.UserRepo, stats *repository.PlayerStatsRepo, cards *repository.CardRepo, unlocks *repository.UnlockRepo) *PlayerHandler {
	return &PlayerHandler{users: users, stats: stats, cards: cards, unlocks: unlocks}
}

func (h *PlayerHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	u, err := h.users.GetByID(r.Context(), claims.UserID)
	if err != nil || u == nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "user not found"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"user_id":       u.UserID,
		"display_name":  u.DisplayName,
		"player_level":  u.PlayerLevel,
		"experience":    u.Experience,
		"gold":          u.Gold,
		"stone":         u.Stone,
		"character_id":  u.CharacterID,
		"title_id":      u.TitleID,
		"display_rate":  u.DisplayRate,
		"rank_tier":     u.RankTier,
		"stamina":       u.Stamina,
		"stamina_max":   u.StaminaMax,
		"max_decks":     u.MaxDecks,
		"login_streak":  u.LoginStreak,
	})
}

func (h *PlayerHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	s, err := h.stats.GetByUserID(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	if s == nil {
		writeJSON(w, http.StatusOK, map[string]any{})
		return
	}
	writeJSON(w, http.StatusOK, s)
}

func (h *PlayerHandler) UpdateSettings(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var settings json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&settings); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	if err := h.users.UpdateSettings(r.Context(), claims.UserID, settings); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "update failed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

type updateProfileRequest struct {
	DisplayName string  `json:"display_name"`
	TitleID     *string `json:"title_id"`
	CharacterID string  `json:"character_id"`
}

func (h *PlayerHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var req updateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	if err := h.users.UpdateProfile(r.Context(), claims.UserID, req.DisplayName, req.TitleID, req.CharacterID, nil); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "update failed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *PlayerHandler) GetCards(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	cards, err := h.cards.GetCards(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	writeJSON(w, http.StatusOK, cards)
}

func (h *PlayerHandler) GetDecks(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	decks, err := h.cards.GetDecks(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	writeJSON(w, http.StatusOK, decks)
}

func (h *PlayerHandler) GetUnlocks(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	unlocks, err := h.unlocks.GetAll(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	writeJSON(w, http.StatusOK, unlocks)
}

func (h *PlayerHandler) SaveDeck(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r.Context())
	if claims == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var req struct {
		SlotIndex int    `json:"slot_index"`
		DeckName  string `json:"deck_name"`
		Cards     []int  `json:"cards"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	cardsJSON, err := json.Marshal(req.Cards)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "marshal failed"})
		return
	}

	if err := h.cards.UpsertDeck(r.Context(), claims.UserID, req.SlotIndex, req.DeckName, cardsJSON); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "save failed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
