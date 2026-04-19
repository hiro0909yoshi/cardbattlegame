package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"arcana-conquest-server/auth"
	"arcana-conquest-server/model"
	"arcana-conquest-server/repository"
)

type AuthHandler struct {
	users *repository.UserRepo
}

func NewAuthHandler(users *repository.UserRepo) *AuthHandler {
	return &AuthHandler{users: users}
}

type guestRegisterRequest struct {
	DeviceID string `json:"device_id"`
	UserID   string `json:"user_id"`
	Name     string `json:"display_name"`
}

type authResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
	UserID       string `json:"user_id"`
}

func (h *AuthHandler) GuestRegister(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var req guestRegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request"})
		return
	}
	if req.UserID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "user_id required"})
		return
	}

	existing, _ := h.users.GetByUserID(r.Context(), req.UserID)
	if existing != nil {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "user already exists"})
		return
	}

	name := req.Name
	if name == "" {
		name = "ゲスト"
	}

	u := &model.User{
		UserID:       req.UserID,
		DeviceID:     strPtr(req.DeviceID),
		DisplayName:  name,
		AuthProvider: "guest",
		CharacterID:  "hero",
	}
	if err := h.users.Create(r.Context(), u); err != nil {
		slog.Error("create user failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "create failed"})
		return
	}

	accessToken, err := auth.GenerateAccessToken(u.ID, u.UserID, u.DisplayName)
	if err != nil {
		slog.Error("generate access token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
		return
	}

	plain, hash, err := auth.GenerateRefreshToken()
	if err != nil {
		slog.Error("generate refresh token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
		return
	}
	expiresAt := time.Now().Add(30 * 24 * time.Hour)
	if err := h.users.UpdateRefreshToken(r.Context(), u.ID, hash, expiresAt); err != nil {
		slog.Error("update refresh token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}

	writeJSON(w, http.StatusCreated, authResponse{
		AccessToken:  accessToken,
		RefreshToken: plain,
		ExpiresIn:    900,
		UserID:       u.UserID,
	})
}

type loginRequest struct {
	UserID   string `json:"user_id"`
	DeviceID string `json:"device_id"`
}

func (h *AuthHandler) GuestLogin(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request"})
		return
	}

	u, err := h.users.GetByUserID(r.Context(), req.UserID)
	if err != nil {
		slog.Error("get user failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	if u == nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "user not found"})
		return
	}
	if u.Status != "active" {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "account suspended"})
		return
	}

	accessToken, err := auth.GenerateAccessToken(u.ID, u.UserID, u.DisplayName)
	if err != nil {
		slog.Error("generate access token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
		return
	}
	plain, hash, err := auth.GenerateRefreshToken()
	if err != nil {
		slog.Error("generate refresh token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
		return
	}
	expiresAt := time.Now().Add(30 * 24 * time.Hour)
	if err := h.users.UpdateRefreshToken(r.Context(), u.ID, hash, expiresAt); err != nil {
		slog.Error("update refresh token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		AccessToken:  accessToken,
		RefreshToken: plain,
		ExpiresIn:    900,
		UserID:       u.UserID,
	})
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
	UserID       string `json:"user_id"`
}

func (h *AuthHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var req refreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request"})
		return
	}

	u, err := h.users.GetByUserID(r.Context(), req.UserID)
	if err != nil || u == nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}

	if u.RefreshTokenHash == nil || !auth.VerifyRefreshToken(req.RefreshToken, *u.RefreshTokenHash) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid refresh token"})
		return
	}

	if u.TokenExpiresAt == nil || u.TokenExpiresAt.Before(time.Now()) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "refresh token expired"})
		return
	}

	accessToken, err := auth.GenerateAccessToken(u.ID, u.UserID, u.DisplayName)
	if err != nil {
		slog.Error("generate access token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
		return
	}
	plain, hash, err := auth.GenerateRefreshToken()
	if err != nil {
		slog.Error("generate refresh token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
		return
	}
	expiresAt := time.Now().Add(30 * 24 * time.Hour)
	if err := h.users.UpdateRefreshToken(r.Context(), u.ID, hash, expiresAt); err != nil {
		slog.Error("update refresh token failed", "err", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		AccessToken:  accessToken,
		RefreshToken: plain,
		ExpiresIn:    900,
		UserID:       u.UserID,
	})
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
