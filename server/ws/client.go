package ws

import (
	"log/slog"
	"time"

	"github.com/gorilla/websocket"
)

const (
	pingInterval    = 10 * time.Second
	pongWait        = 30 * time.Second
	writeWait       = 10 * time.Second
	maxMessageSize  = 64 * 1024 // 64KB
	msgRateLimit    = 30        // messages per second
	msgRateWindow   = 1 * time.Second
)

type Client struct {
	UserID   int64
	UserUUID string
	hub      *Hub
	conn     *websocket.Conn
	send     chan []byte
	Room     *Room
}

func NewClient(hub *Hub, conn *websocket.Conn, userID int64, userUUID string) *Client {
	return &Client{
		UserID:   userID,
		UserUUID: userUUID,
		hub:      hub,
		conn:     conn,
		send:     make(chan []byte, 256),
	}
}

func (c *Client) Send(msg []byte) {
	select {
	case c.send <- msg:
	default:
		slog.Warn("send buffer full, closing connection", "user", c.UserID)
		c.conn.Close()
	}
}

func (c *Client) ReadPump() {
	defer func() {
		if c.Room != nil {
			c.Room.HandleDisconnect(c)
		}
		c.hub.Unregister(c)
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	msgCount := 0
	windowStart := time.Now()

	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				slog.Warn("read error", "user", c.UserID, "err", err)
			}
			return
		}

		now := time.Now()
		if now.Sub(windowStart) > msgRateWindow {
			msgCount = 0
			windowStart = now
		}
		msgCount++
		if msgCount > msgRateLimit {
			slog.Warn("rate limit exceeded", "user", c.UserID)
			c.Send(NewMessage("error", map[string]string{"message": "rate limit exceeded"}))
			continue
		}

		msg, err := ParseMessage(raw)
		if err != nil {
			slog.Warn("invalid message", "user", c.UserID, "err", err)
			continue
		}

		c.hub.HandleMessage(c, msg)
	}
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(pingInterval)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case msg, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				slog.Warn("write error", "user", c.UserID, "err", err)
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
