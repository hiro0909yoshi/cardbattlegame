package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strconv"

	"arcana-conquest-server/auth"
	"arcana-conquest-server/config"
	"arcana-conquest-server/db"
	"arcana-conquest-server/handler"
	"arcana-conquest-server/masterdata"
	"arcana-conquest-server/repository"
	"arcana-conquest-server/ws"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})))

	cfg := config.Load()

	pool, err := db.Connect(cfg.DBDSN())
	if err != nil {
		slog.Error("database connection failed", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	// カードマスタデータ読み込��
	dataDir := cfg.DataDir
	if dataDir == "" {
		dataDir = "../data"
	}
	if err := masterdata.LoadCards(dataDir); err != nil {
		slog.Warn("card data not loaded", "err", err)
	}

	userRepo := repository.NewUserRepo(pool)
	statsRepo := repository.NewPlayerStatsRepo(pool)
	cardRepo := repository.NewCardRepo(pool)
	unlockRepo := repository.NewUnlockRepo(pool)

	authH := handler.NewAuthHandler(userRepo)
	playerH := handler.NewPlayerHandler(userRepo, statsRepo, cardRepo, unlockRepo)

	// Wire deck loader callback for ws.Hub
	deckLoader := func(ctx context.Context, userID int64, deckID string) ([]int, error) {
		slotIndex := 0
		if idx, err := strconv.Atoi(deckID); err == nil {
			slotIndex = idx
		}
		decks, err := cardRepo.GetDecks(ctx, userID)
		if err != nil {
			return nil, err
		}
		for _, deck := range decks {
			if deck.SlotIndex == slotIndex {
				var cards []int
				if err := json.Unmarshal(deck.Cards, &cards); err != nil {
					return nil, err
				}
				return cards, nil
			}
		}
		return []int{}, nil
	}
	hub := ws.NewHub(deckLoader)

	mux := http.NewServeMux()

	// Public
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /api/auth/guest/register", authH.GuestRegister)
	mux.HandleFunc("POST /api/auth/guest/login", authH.GuestLogin)
	mux.HandleFunc("POST /api/auth/refresh", authH.RefreshToken)

	// WebSocket (token in query param)
	mux.HandleFunc("GET /ws", handler.WebSocket(hub))

	// Protected (JWT required)
	protected := http.NewServeMux()
	protected.HandleFunc("GET /api/player/profile", playerH.GetProfile)
	protected.HandleFunc("PUT /api/player/profile", playerH.UpdateProfile)
	protected.HandleFunc("GET /api/player/stats", playerH.GetStats)
	protected.HandleFunc("PUT /api/player/settings", playerH.UpdateSettings)
	protected.HandleFunc("GET /api/player/cards", playerH.GetCards)
	protected.HandleFunc("GET /api/player/decks", playerH.GetDecks)
	protected.HandleFunc("GET /api/player/unlocks", playerH.GetUnlocks)
	mux.Handle("/api/player/", auth.Middleware(protected))

	addr := fmt.Sprintf(":%s", cfg.Port)
	slog.Info("server starting", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		slog.Error("server failed", "err", err)
		os.Exit(1)
	}
}
