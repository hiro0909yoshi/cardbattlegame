//go:build integration

package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

const (
	serverURL = "http://localhost:8080"
	wsURL     = "ws://localhost:8080/ws"
	timeout   = 10 * time.Second
)

// TestOneTurn tests a full turn of game flow
func TestOneTurn(t *testing.T) {
	// Register two guest players
	player1ID, token1 := registerGuestUser(t, "test_p1")
	player2ID, token2 := registerGuestUser(t, "test_p2")

	t.Logf("Player 1: %s (token: %.10s...)", player1ID, token1)
	t.Logf("Player 2: %s (token: %.10s...)", player2ID, token2)

	// Connect both players via WebSocket
	conn1 := connectWebSocket(t, token1)
	defer conn1.Close()

	conn2 := connectWebSocket(t, token2)
	defer conn2.Close()

	t.Log("✓ Both players connected via WebSocket")

	// Player 1 creates room
	roomID := createRoom(t, conn1)
	t.Logf("✓ Room created: %s", roomID)

	// Player 2 joins room
	joinRoom(t, conn2, roomID)
	t.Log("✓ Player 2 joined room")

	// Both set ready — wait for room_state after each to confirm server processed
	setReady(t, conn1, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	setReady(t, conn2, true)
	// Wait until conn1 sees the room_state showing both ready
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	// Also drain conn2's room_state
	waitForMessageType(t, conn2, "room_state", 3*time.Second)
	t.Log("✓ Both players ready")

	// Player 1 starts game
	startGame(t, conn1)
	t.Log("✓ Game started")

	// Wait for game_state message
	gameState := waitForMessageType(t, conn1, "game_state", 5*time.Second)
	_ = waitForMessageType(t, conn2, "game_state", 5*time.Second)
	t.Logf("✓ game_state received\n%s", prettyJSON(gameState))

	// Determine active player
	var state map[string]any
	if gs, ok := gameState.(map[string]any); ok {
		if s, ok := gs["state"].(map[string]any); ok {
			state = s
		}
	}
	if state == nil {
		t.Fatal("Could not parse game_state")
	}

	activePlayer := int(state["active_player"].(float64))
	t.Logf("✓ Active player: %d", activePlayer)

	// Select the WebSocket connection for the active player
	activeConn := conn1
	if activePlayer == 1 {
		activeConn = conn2
	}

	// === TURN START PHASE ===
	turnStart := waitForMessageType(t, activeConn, "turn_start", 5*time.Second)
	t.Logf("✓ turn_start received\n%s", prettyJSON(turnStart))

	// === SPELL PHASE ===
	t.Log("\n--- Spell Phase ---")
	// Player sends spell_pass (server auto-rolls dice)
	sendMessage(t, activeConn, "spell_pass", nil)
	t.Log("→ spell_pass sent")

	// Wait for dice_result
	diceResult := waitForMessageType(t, activeConn, "dice_result", 5*time.Second)
	t.Logf("✓ dice_result received\n%s", prettyJSON(diceResult))

	var diceValue int
	if dr, ok := diceResult.(map[string]any); ok {
		diceValue = int(dr["result"].(float64))
	}
	t.Logf("  Dice value: %d", diceValue)

	// === MOVE PHASE ===
	t.Log("\n--- Move Phase ---")
	// Player sends move_complete with direction -1 (let server calculate)
	moveReq := map[string]any{"direction": -1}
	sendMessage(t, activeConn, "move_complete", moveReq)
	t.Log("→ move_complete sent")

	// Wait for action_result (server wraps all actions as action_result)
	moveResult := waitForMessageType(t, activeConn, "action_result", 5*time.Second)
	t.Logf("✓ move action_result received\n%s", prettyJSON(moveResult))

	var nextPhase string
	if ar, ok := moveResult.(map[string]any); ok {
		if data, ok := ar["data"].(map[string]any); ok {
			if p, ok := data["phase"].(string); ok {
				nextPhase = p
			}
		}
	}
	t.Logf("  Next phase: %s", nextPhase)

	// === TILE ACTION PHASE ===
	t.Log("\n--- Tile Action Phase ---")

	if nextPhase == "" {
		nextPhase = "tile_action" // default: first turn always lands on empty tile
		t.Log("  (phase not extracted from action_result, assuming tile_action)")
	}

	if nextPhase == "battle" {
		t.Log("  Battle phase detected, waiting for battle_result...")
		waitForMessageType(t, activeConn, "battle_result", 5*time.Second)
		t.Log("  Battle resolved")
	} else if nextPhase == "tile_action" {
		// Get player's hand from initial game_state
		var playerHand []any
		if gs, ok := gameState.(map[string]any); ok {
			if s, ok := gs["state"].(map[string]any); ok {
				if players, ok := s["players"].([]any); ok && activePlayer < len(players) {
					if p, ok := players[activePlayer].(map[string]any); ok {
						if hand, ok := p["hand"].([]any); ok {
							playerHand = hand
						}
					}
				}
			}
		}

		if len(playerHand) > 0 {
			// Summon first creature in hand
			cardID := int(playerHand[0].(float64))
			summonReq := map[string]any{"card_id": cardID}
			sendMessage(t, activeConn, "summon", summonReq)
			t.Logf("→ summon sent (card_id: %d)", cardID)

			// Wait for summon action_result
			summonResponse := waitForMessageType(t, activeConn, "action_result", 3*time.Second)
			if summonResponse != nil {
				t.Logf("✓ summon response\n%s", prettyJSON(summonResponse))
			} else {
				t.Log("  summon may have failed, sending pass instead")
				sendMessage(t, activeConn, "pass", nil)
				waitForMessageType(t, activeConn, "action_result", 3*time.Second)
			}
		} else {
			sendMessage(t, activeConn, "pass", nil)
			t.Log("→ pass sent (no cards in hand)")
			waitForMessageType(t, activeConn, "action_result", 3*time.Second)
		}
	}

	// === END TURN PHASE ===
	t.Log("\n--- End Turn Phase ---")
	sendMessage(t, activeConn, "end_turn", nil)
	t.Log("→ end_turn sent")

	// Wait for next turn_start to confirm turn cycle
	nextTurnStart := waitForMessageType(t, activeConn, "turn_start", 5*time.Second)
	if nextTurnStart != nil {
		t.Logf("✓ Next turn_start received\n%s", prettyJSON(nextTurnStart))
		t.Log("\n✓ Full turn cycle completed successfully!")
	} else {
		t.Log("! No next turn_start within timeout")
	}
}

// registerGuestUser registers a guest user and returns (userID, token)
func registerGuestUser(t *testing.T, prefix string) (string, string) {
	suffix := rand.Intn(999999)
	userID := fmt.Sprintf("%s_%d", prefix, suffix)
	displayName := fmt.Sprintf("Player_%d", suffix)

	reqBody := map[string]string{
		"user_id":      userID,
		"display_name": displayName,
	}
	body, _ := json.Marshal(reqBody)

	resp, err := http.Post(
		serverURL+"/api/auth/guest/register",
		"application/json",
		strings.NewReader(string(body)),
	)
	if err != nil {
		t.Fatalf("Failed to register user: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 201 {
		t.Fatalf("Register failed with status %d", resp.StatusCode)
	}

	var result map[string]any
	json.NewDecoder(resp.Body).Decode(&result)

	return result["user_id"].(string), result["access_token"].(string)
}

// connectWebSocket connects to the WebSocket and returns the connection
func connectWebSocket(t *testing.T, token string) *websocket.Conn {
	wsAddr := wsURL + "?token=" + token
	conn, _, err := websocket.DefaultDialer.Dial(wsAddr, nil)
	if err != nil {
		t.Fatalf("Failed to connect WebSocket: %v", err)
	}
	return conn
}

// createRoom creates a room and returns room_id
func createRoom(t *testing.T, conn *websocket.Conn) string {
	cfg := map[string]any{
		"match_type":    "friend",
		"max_players":   2,
		"initial_magic": 1000,
		"target_magic":  8000,
	}
	sendMessage(t, conn, "create_room", cfg)

	msg := waitForMessageType(t, conn, "room_created", 5*time.Second)
	if msg == nil {
		t.Fatal("No room_created response")
	}

	if m, ok := msg.(map[string]any); ok {
		return m["room_id"].(string)
	}
	t.Fatal("Could not extract room_id")
	return ""
}

// joinRoom joins an existing room
func joinRoom(t *testing.T, conn *websocket.Conn, roomID string) {
	req := map[string]any{
		"room_id": roomID,
		"deck_id": "0",
	}
	sendMessage(t, conn, "join_room", req)

	msg := waitForMessageType(t, conn, "room_state", 5*time.Second)
	if msg == nil {
		t.Fatal("No room_state response")
	}
}

// setReady sets the ready state
func setReady(t *testing.T, conn *websocket.Conn, ready bool) {
	req := map[string]any{"ready": ready}
	sendMessage(t, conn, "set_ready", req)
}

// startGame sends start_game message
func startGame(t *testing.T, conn *websocket.Conn) {
	sendMessage(t, conn, "start_game", nil)
}

// sendMessage sends a JSON message through WebSocket
func sendMessage(t *testing.T, conn *websocket.Conn, msgType string, data any) {
	msg := map[string]any{
		"type": msgType,
		"data": data,
	}
	body, _ := json.Marshal(msg)

	conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	defer conn.SetWriteDeadline(time.Now().Add(time.Hour))

	if err := conn.WriteMessage(websocket.TextMessage, body); err != nil {
		t.Logf("Failed to send message: %v", err)
	}
}

// waitForMessageType waits for a message of a specific type with timeout
func waitForMessageType(t *testing.T, conn *websocket.Conn, expectedType string, timeout time.Duration) any {
	conn.SetReadDeadline(time.Now().Add(timeout))
	defer conn.SetReadDeadline(time.Now().Add(time.Hour))

	deadline := time.Now().Add(timeout)
	for {
		if time.Now().After(deadline) {
			t.Logf("Timeout waiting for message type: %s", expectedType)
			return nil
		}

		_, raw, err := conn.ReadMessage()
		if err != nil {
			t.Logf("Read error: %v", err)
			return nil
		}

		var msg map[string]any
		if err := json.Unmarshal(raw, &msg); err != nil {
			t.Logf("! Unparseable message: %s", string(raw))
			continue
		}

		msgType := msg["type"].(string)
		t.Logf("← %s", msgType)

		if msgType == expectedType {
			if data, ok := msg["data"]; ok {
				return data
			}
			return msg
		}
	}
}

// TestFullGame runs a complete game to game_over with max_turns=4
func TestFullGame(t *testing.T) {
	_, token1 := registerGuestUser(t, "full_p1")
	_, token2 := registerGuestUser(t, "full_p2")

	conn1 := connectWebSocket(t, token1)
	defer conn1.Close()
	conn2 := connectWebSocket(t, token2)
	defer conn2.Close()

	// Create room with max_turns=4
	cfg := map[string]any{
		"match_type":    "friend",
		"max_players":   2,
		"initial_magic": 1000,
		"target_magic":  8000,
		"max_turns":     4,
	}
	sendMessage(t, conn1, "create_room", cfg)
	roomMsg := waitForMessageType(t, conn1, "room_created", 5*time.Second)
	roomID := roomMsg.(map[string]any)["room_id"].(string)
	t.Logf("Room: %s (max_turns=4)", roomID)

	joinRoom(t, conn2, roomID)

	setReady(t, conn1, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	setReady(t, conn2, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	waitForMessageType(t, conn2, "room_state", 3*time.Second)

	startGame(t, conn1)

	// Both receive game_state
	waitForMessageType(t, conn1, "game_state", 5*time.Second)
	waitForMessageType(t, conn2, "game_state", 5*time.Second)

	conns := [2]*websocket.Conn{conn1, conn2}

	// First turn_start already received as part of game_state flow
	firstTS := waitForMessageType(t, conn1, "turn_start", 3*time.Second)
	waitForMessageType(t, conn2, "turn_start", 2*time.Second) // drain

	var pendingTurnStart any = firstTS

	for turn := 1; turn <= 10; turn++ {
		ts := pendingTurnStart
		pendingTurnStart = nil

		if ts == nil {
			t.Fatalf("No turn_start data for turn %d", turn)
		}

		var activePlayer int
		if tsMap, ok := ts.(map[string]any); ok {
			activePlayer = int(tsMap["active_player"].(float64))
		}
		activeConn := conns[activePlayer]
		t.Logf("--- Turn %d (player %d) ---", turn, activePlayer)

		// spell_pass
		sendMessage(t, activeConn, "spell_pass", nil)
		waitForMessageType(t, activeConn, "dice_result", 3*time.Second)

		// move_complete
		sendMessage(t, activeConn, "move_complete", map[string]any{"direction": -1})
		moveResult := waitForMessageType(t, activeConn, "action_result", 3*time.Second)

		nextPhase := "tile_action"
		if ar, ok := moveResult.(map[string]any); ok {
			if data, ok := ar["data"].(map[string]any); ok {
				if p, ok := data["phase"].(string); ok {
					nextPhase = p
				}
			}
		}

		if nextPhase == "battle" {
			waitForMessageType(t, activeConn, "battle_result", 3*time.Second)
			t.Log("  Battle resolved")
		} else {
			sendMessage(t, activeConn, "pass", nil)
			waitForMessageType(t, activeConn, "action_result", 3*time.Second)
		}

		// end_turn
		sendMessage(t, activeConn, "end_turn", nil)

		// Wait for game_over or turn_start
		msgType, msgData := waitForAnyType(t, activeConn, []string{"game_over", "turn_start"}, 3*time.Second)
		if msgType == "game_over" {
			t.Logf("✓ GAME OVER at turn %d", turn)
			if goMap, ok := msgData.(map[string]any); ok {
				t.Logf("  Winner: %v, Total turns: %v", goMap["winner"], goMap["total_turns"])
			}
			t.Log("\n✓ Full game completed successfully!")
			return
		}
		if msgType == "turn_start" {
			// Drain turn_start from the other conn
			otherConn := conns[1-activePlayer]
			waitForMessageType(t, otherConn, "turn_start", 1*time.Second)
			pendingTurnStart = msgData
			continue
		}
		t.Fatalf("Unexpected state after end_turn at turn %d: type=%s", turn, msgType)
	}

	t.Fatal("Game did not end within 10 iterations")
}

// waitForAnyType waits for any of the specified message types
func waitForAnyType(t *testing.T, conn *websocket.Conn, types []string, timeout time.Duration) (string, any) {
	conn.SetReadDeadline(time.Now().Add(timeout))
	defer conn.SetReadDeadline(time.Now().Add(time.Hour))

	deadline := time.Now().Add(timeout)
	for {
		if time.Now().After(deadline) {
			return "", nil
		}

		_, raw, err := conn.ReadMessage()
		if err != nil {
			return "", nil
		}

		var msg map[string]any
		if err := json.Unmarshal(raw, &msg); err != nil {
			continue
		}

		msgType, _ := msg["type"].(string)
		t.Logf("← %s", msgType)

		for _, expected := range types {
			if msgType == expected {
				data, _ := msg["data"]
				return msgType, data
			}
		}
	}
}

// prettyJSON returns a pretty-printed JSON string (max 2 lines for brevity)
func prettyJSON(v any) string {
	b, _ := json.MarshalIndent(v, "  ", "  ")
	lines := strings.Split(string(b), "\n")
	if len(lines) > 2 {
		lines = append(lines[:2], "  ...")
	}
	return strings.Join(lines, "\n")
}
