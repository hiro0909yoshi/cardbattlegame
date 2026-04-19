package handler

import (
	"log/slog"
	"net/http"
	"os"
	"strings"

	"arcana-conquest-server/auth"
	"arcana-conquest-server/ws"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		allowed := os.Getenv("ALLOWED_ORIGINS")
		if allowed == "" {
			return true
		}
		origin := r.Header.Get("Origin")
		for _, o := range strings.Split(allowed, ",") {
			if strings.TrimSpace(o) == origin {
				return true
			}
		}
		slog.Warn("ws origin rejected", "origin", origin)
		return false
	},
}

func WebSocket(hub *ws.Hub) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := r.URL.Query().Get("token")
		if token == "" {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "missing token"})
			return
		}

		claims, err := auth.ValidateToken(token)
		if err != nil {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid token"})
			return
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			slog.Error("websocket upgrade failed", "err", err)
			return
		}

		client := ws.NewClient(hub, conn, claims.UserID, claims.Sub, claims.DisplayName)
		hub.Register(client)

		slog.Info("websocket connected", "user", claims.UserID, "uuid", claims.Sub, "name", claims.DisplayName)

		go client.WritePump()
		go client.ReadPump()
	}
}
