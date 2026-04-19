package ws

import (
	"encoding/json"
	"log/slog"
	"time"
)

type Message struct {
	Type      string          `json:"type"`
	Data      json.RawMessage `json:"data,omitempty"`
	Timestamp int64           `json:"ts"`
	RequestID string          `json:"rid,omitempty"`
}

// NewMessage creates a lobby/room-level message.
// Game messages use game.newMsg which includes StateVersion from GameState.
func NewMessage(msgType string, data any) []byte {
	d, err := json.Marshal(data)
	if err != nil {
		slog.Error("failed to marshal ws message data", "type", msgType, "err", err)
		d = []byte("{}")
	}
	msg := Message{
		Type:      msgType,
		Data:      d,
		Timestamp: time.Now().UnixMilli(),
	}
	b, err := json.Marshal(msg)
	if err != nil {
		slog.Error("failed to marshal ws message", "type", msgType, "err", err)
		return []byte(`{"type":"error","data":{},"ts":0}`)
	}
	return b
}

func ParseMessage(raw []byte) (*Message, error) {
	var m Message
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, err
	}
	return &m, nil
}
