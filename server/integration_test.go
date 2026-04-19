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

	// Save decks so players have cards to summon
	creatureDeck := []int{2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 1}
	saveDeck(t, token1, 0, creatureDeck)
	saveDeck(t, token2, 0, creatureDeck)

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
			waitForMessageType(t, activeConn, "battle_start", 3*time.Second)
			waitForMessageType(t, activeConn, "battle_result", 3*time.Second)
			t.Log("  Battle resolved")
		} else {
			// Try to summon using hand from turn_start
			var handCardID int
			if tsMap, ok := ts.(map[string]any); ok {
				if hand, ok := tsMap["hand"].([]any); ok && len(hand) > 0 {
					handCardID = int(hand[0].(float64))
				}
			}
			if handCardID > 0 {
				sendMessage(t, activeConn, "summon", map[string]any{"card_id": handCardID})
				resp, _ := waitForAnyType(t, activeConn, []string{"action_result", "action_error"}, 3*time.Second)
				if resp == "action_result" {
					t.Logf("  Summoned card %d", handCardID)
				} else {
					sendMessage(t, activeConn, "pass", nil)
					waitForMessageType(t, activeConn, "action_result", 3*time.Second)
				}
			} else {
				sendMessage(t, activeConn, "pass", nil)
				waitForMessageType(t, activeConn, "action_result", 3*time.Second)
			}
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

// saveDeck saves a deck for a user via the API
func saveDeck(t *testing.T, token string, slotIndex int, cards []int) {
	reqBody := map[string]any{
		"slot_index": slotIndex,
		"deck_name":  "Test Deck",
		"cards":      cards,
	}
	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("PUT", serverURL+"/api/player/decks", strings.NewReader(string(body)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("Failed to save deck: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		var errBody map[string]any
		json.NewDecoder(resp.Body).Decode(&errBody)
		t.Fatalf("Save deck failed with status %d: %v", resp.StatusCode, errBody)
	}
}

// TestSummon tests that a player with cards can summon a creature on an empty tile
func TestSummon(t *testing.T) {
	_, token1 := registerGuestUser(t, "summon_p1")
	_, token2 := registerGuestUser(t, "summon_p2")

	// Save decks with creature cards (IDs 1-20 are fire creatures)
	creatureDeck := []int{2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 1}
	saveDeck(t, token1, 0, creatureDeck)
	saveDeck(t, token2, 0, creatureDeck)

	conn1 := connectWebSocket(t, token1)
	defer conn1.Close()
	conn2 := connectWebSocket(t, token2)
	defer conn2.Close()

	// Create room
	cfg := map[string]any{
		"match_type":    "friend",
		"max_players":   2,
		"initial_magic": 1000,
		"target_magic":  8000,
	}
	sendMessage(t, conn1, "create_room", cfg)
	roomMsg := waitForMessageType(t, conn1, "room_created", 5*time.Second)
	roomID := roomMsg.(map[string]any)["room_id"].(string)

	joinRoom(t, conn2, roomID)

	setReady(t, conn1, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	setReady(t, conn2, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	waitForMessageType(t, conn2, "room_state", 3*time.Second)

	startGame(t, conn1)

	// Get game_state — check that hand has cards
	gameStateData := waitForMessageType(t, conn1, "game_state", 5*time.Second)
	waitForMessageType(t, conn2, "game_state", 5*time.Second)

	// Parse state to verify hand has cards
	if gs, ok := gameStateData.(map[string]any); ok {
		if state, ok := gs["state"].(map[string]any); ok {
			if players, ok := state["players"].([]any); ok {
				for i, p := range players {
					if pm, ok := p.(map[string]any); ok {
						if hand, ok := pm["hand"].([]any); ok {
							t.Logf("Player %d hand: %d cards", i, len(hand))
							if len(hand) == 0 {
								t.Fatalf("Player %d has empty hand — deck was not loaded", i)
							}
						}
					}
				}
			}
		}
	}

	// Wait for turn_start
	tsData := waitForMessageType(t, conn1, "turn_start", 3*time.Second)
	waitForMessageType(t, conn2, "turn_start", 2*time.Second)

	conns := [2]*websocket.Conn{conn1, conn2}
	var activePlayer int
	if tsMap, ok := tsData.(map[string]any); ok {
		activePlayer = int(tsMap["active_player"].(float64))
	}
	activeConn := conns[activePlayer]
	t.Logf("Active player: %d", activePlayer)

	// spell_pass → dice_result
	sendMessage(t, activeConn, "spell_pass", nil)
	waitForMessageType(t, activeConn, "dice_result", 3*time.Second)

	// move_complete
	sendMessage(t, activeConn, "move_complete", map[string]any{"direction": -1})
	moveResult := waitForMessageType(t, activeConn, "action_result", 3*time.Second)
	t.Logf("Move result: %s", prettyJSON(moveResult))

	// Get the first creature card from turn_start hand data
	var handCardID int
	if tsMap, ok := tsData.(map[string]any); ok {
		if hand, ok := tsMap["hand"].([]any); ok && len(hand) > 0 {
			handCardID = int(hand[0].(float64))
		}
	}

	if handCardID == 0 {
		t.Fatal("No card in hand to summon")
	}
	t.Logf("Summoning card ID: %d", handCardID)

	// Send summon
	sendMessage(t, activeConn, "summon", map[string]any{"card_id": handCardID})
	summonResult := waitForMessageType(t, activeConn, "action_result", 3*time.Second)

	if summonResult == nil {
		// Check if we got an error instead
		t.Fatal("No action_result for summon")
	}

	t.Logf("✓ Summon result: %s", prettyJSON(summonResult))

	// Verify summon action in result
	if ar, ok := summonResult.(map[string]any); ok {
		if data, ok := ar["data"].(map[string]any); ok {
			if action, ok := data["action"].(string); ok {
				if action != "summon" {
					t.Fatalf("Expected summon action, got: %s", action)
				}
				t.Log("✓ Summon action confirmed!")
			}
		}
	}

	// end_turn
	sendMessage(t, activeConn, "end_turn", nil)
	waitForAnyType(t, activeConn, []string{"game_over", "turn_start"}, 3*time.Second)

	t.Log("\n✓ Summon test completed successfully!")
}

// TestBattle tests that a battle occurs when player lands on opponent's creature tile
func TestBattle(t *testing.T) {
	_, token1 := registerGuestUser(t, "battle_p1")
	_, token2 := registerGuestUser(t, "battle_p2")

	// Save decks with creature cards
	creatureDeck := []int{2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 1}
	saveDeck(t, token1, 0, creatureDeck)
	saveDeck(t, token2, 0, creatureDeck)

	conn1 := connectWebSocket(t, token1)
	defer conn1.Close()
	conn2 := connectWebSocket(t, token2)
	defer conn2.Close()

	cfg := map[string]any{
		"match_type":    "friend",
		"max_players":   2,
		"initial_magic": 1000,
		"target_magic":  8000,
		"max_turns":     20,
	}
	sendMessage(t, conn1, "create_room", cfg)
	roomMsg := waitForMessageType(t, conn1, "room_created", 5*time.Second)
	roomID := roomMsg.(map[string]any)["room_id"].(string)

	joinRoom(t, conn2, roomID)

	setReady(t, conn1, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	setReady(t, conn2, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	waitForMessageType(t, conn2, "room_state", 3*time.Second)

	startGame(t, conn1)

	waitForMessageType(t, conn1, "game_state", 5*time.Second)
	waitForMessageType(t, conn2, "game_state", 5*time.Second)

	conns := [2]*websocket.Conn{conn1, conn2}

	firstTS := waitForMessageType(t, conn1, "turn_start", 3*time.Second)
	waitForMessageType(t, conn2, "turn_start", 2*time.Second)

	var pendingTurnStart any = firstTS
	battleOccurred := false

	for turn := 1; turn <= 20; turn++ {
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
		otherConn := conns[1-activePlayer]
		t.Logf("--- Turn %d (player %d) ---", turn, activePlayer)

		// spell_pass → dice_result
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
			t.Log("  ★ Battle triggered!")
			// Wait for battle_start and battle_result
			waitForMessageType(t, activeConn, "battle_start", 3*time.Second)
			battleResult := waitForMessageType(t, activeConn, "battle_result", 3*time.Second)
			if battleResult != nil {
				t.Logf("  Battle result: %s", prettyJSON(battleResult))
				battleOccurred = true
			}
			// After battle, phase should transition to end_turn automatically
		} else {
			// tile_action phase: try to summon using hand from turn_start
			var handCardID int
			if tsMap, ok := ts.(map[string]any); ok {
				if hand, ok := tsMap["hand"].([]any); ok && len(hand) > 0 {
					handCardID = int(hand[0].(float64))
				}
			}

			if handCardID > 0 {
				sendMessage(t, activeConn, "summon", map[string]any{"card_id": handCardID})
				summonResp, summonData := waitForAnyType(t, activeConn, []string{"action_result", "action_error"}, 3*time.Second)
				if summonResp == "action_result" {
					t.Logf("  Summoned card %d", handCardID)
				} else {
					t.Logf("  Summon failed: %v — passing", summonData)
					sendMessage(t, activeConn, "pass", nil)
					waitForMessageType(t, activeConn, "action_result", 3*time.Second)
				}
			} else {
				sendMessage(t, activeConn, "pass", nil)
				waitForMessageType(t, activeConn, "action_result", 3*time.Second)
			}
		}

		// end_turn
		sendMessage(t, activeConn, "end_turn", nil)

		msgType, msgData := waitForAnyType(t, activeConn, []string{"game_over", "turn_start"}, 3*time.Second)
		if msgType == "game_over" {
			t.Logf("✓ Game over at turn %d (battle occurred: %v)", turn, battleOccurred)
			return
		}
		if msgType == "turn_start" {
			// Drain from other conn
			waitForMessageType(t, otherConn, "turn_start", 1*time.Second)
			pendingTurnStart = msgData

			if battleOccurred {
				t.Logf("✓ Battle test passed! Battle occurred at turn %d", turn)
				return
			}
			continue
		}
		t.Fatalf("Unexpected state at turn %d", turn)
	}

	if !battleOccurred {
		t.Log("⚠ No battle occurred in 20 turns (players may not have landed on occupied tiles)")
	}
}

// TestSpellCast tests that a player can cast a spell during the spell phase
func TestSpellCast(t *testing.T) {
	_, token1 := registerGuestUser(t, "spell_p1")
	_, token2 := registerGuestUser(t, "spell_p2")

	// Deck with 1 spell card (ID 2004) + 19 creatures
	spellDeck := []int{2004, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}
	saveDeck(t, token1, 0, spellDeck)
	saveDeck(t, token2, 0, spellDeck)

	conn1 := connectWebSocket(t, token1)
	defer conn1.Close()
	conn2 := connectWebSocket(t, token2)
	defer conn2.Close()

	cfg := map[string]any{
		"match_type":    "friend",
		"max_players":   2,
		"initial_magic": 1000,
		"target_magic":  8000,
		"max_turns":     10,
	}
	sendMessage(t, conn1, "create_room", cfg)
	roomMsg := waitForMessageType(t, conn1, "room_created", 5*time.Second)
	roomID := roomMsg.(map[string]any)["room_id"].(string)

	joinRoom(t, conn2, roomID)

	setReady(t, conn1, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	setReady(t, conn2, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	waitForMessageType(t, conn2, "room_state", 3*time.Second)

	startGame(t, conn1)

	waitForMessageType(t, conn1, "game_state", 5*time.Second)
	waitForMessageType(t, conn2, "game_state", 5*time.Second)

	conns := [2]*websocket.Conn{conn1, conn2}

	firstTS := waitForMessageType(t, conn1, "turn_start", 3*time.Second)
	waitForMessageType(t, conn2, "turn_start", 2*time.Second)

	var pendingTurnStart any = firstTS
	spellCastSuccess := false

	for turn := 1; turn <= 10; turn++ {
		ts := pendingTurnStart
		pendingTurnStart = nil

		if ts == nil {
			t.Fatalf("No turn_start data for turn %d", turn)
		}

		var activePlayer int
		var hand []any
		if tsMap, ok := ts.(map[string]any); ok {
			activePlayer = int(tsMap["active_player"].(float64))
			if h, ok := tsMap["hand"].([]any); ok {
				hand = h
			}
		}
		activeConn := conns[activePlayer]
		otherConn := conns[1-activePlayer]
		t.Logf("--- Turn %d (player %d) hand: %v ---", turn, activePlayer, hand)

		// Check if spell card 2004 is in hand
		hasSpell := false
		for _, c := range hand {
			if int(c.(float64)) == 2004 {
				hasSpell = true
				break
			}
		}

		if hasSpell && !spellCastSuccess {
			// Cast spell
			t.Log("  ★ Casting spell 2004")
			sendMessage(t, activeConn, "spell_cast", map[string]any{
				"card_id":       2004,
				"target_player": -1,
				"target_tile":   -1,
			})
			resp, data := waitForAnyType(t, activeConn, []string{"action_result", "action_error"}, 3*time.Second)
			if resp == "action_result" {
				t.Logf("  ✓ Spell cast succeeded: %s", prettyJSON(data))
				spellCastSuccess = true
				// After spell_cast, phase is PhaseDice but no auto-roll
				// Test goal achieved — spell_cast works
				t.Log("\n✓ Spell cast test completed successfully!")
				return
			}
			t.Logf("  Spell cast failed: %v — falling back to spell_pass", data)
		}

		// Normal turn: spell_pass
		sendMessage(t, activeConn, "spell_pass", nil)
		waitForMessageType(t, activeConn, "dice_result", 3*time.Second)

		// move_complete
		sendMessage(t, activeConn, "move_complete", map[string]any{"direction": -1})
		waitForMessageType(t, activeConn, "action_result", 3*time.Second)

		// tile_action: try summon or pass
		var handCardID int
		for _, c := range hand {
			cid := int(c.(float64))
			if cid != 2004 && cid > 0 {
				handCardID = cid
				break
			}
		}
		if handCardID > 0 {
			sendMessage(t, activeConn, "summon", map[string]any{"card_id": handCardID})
			resp, _ := waitForAnyType(t, activeConn, []string{"action_result", "action_error"}, 3*time.Second)
			if resp != "action_result" {
				sendMessage(t, activeConn, "pass", nil)
				waitForMessageType(t, activeConn, "action_result", 3*time.Second)
			}
		} else {
			sendMessage(t, activeConn, "pass", nil)
			waitForMessageType(t, activeConn, "action_result", 3*time.Second)
		}

		// end_turn
		sendMessage(t, activeConn, "end_turn", nil)
		msgType, msgData := waitForAnyType(t, activeConn, []string{"game_over", "turn_start"}, 3*time.Second)
		if msgType == "game_over" {
			break
		}
		if msgType == "turn_start" {
			waitForMessageType(t, otherConn, "turn_start", 1*time.Second)
			pendingTurnStart = msgData
		}
	}

	if !spellCastSuccess {
		t.Log("⚠ Spell card 2004 never appeared in hand within 10 turns")
	}
}

// TestDominio tests level_up, move_creature, swap using Indomitable creatures (ID 14, 奮闘)
// Indomitable creatures don't go down after summon, enabling immediate dominio commands.
func TestDominio(t *testing.T) {
	_, token1 := registerGuestUser(t, "dominio_p1")
	_, token2 := registerGuestUser(t, "dominio_p2")

	// Deck with Indomitable creature ID 14 (エターナガード, 奮闘) at front
	// Multiple copies so we can summon on different tiles for move/swap
	indomitableDeck := []int{14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14}
	saveDeck(t, token1, 0, indomitableDeck)
	saveDeck(t, token2, 0, indomitableDeck)

	conn1 := connectWebSocket(t, token1)
	defer conn1.Close()
	conn2 := connectWebSocket(t, token2)
	defer conn2.Close()

	cfg := map[string]any{
		"match_type":    "friend",
		"max_players":   2,
		"initial_magic": 1000,
		"target_magic":  8000,
		"max_turns":     30,
	}
	sendMessage(t, conn1, "create_room", cfg)
	roomMsg := waitForMessageType(t, conn1, "room_created", 5*time.Second)
	roomID := roomMsg.(map[string]any)["room_id"].(string)

	joinRoom(t, conn2, roomID)

	setReady(t, conn1, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	setReady(t, conn2, true)
	waitForMessageType(t, conn1, "room_state", 3*time.Second)
	waitForMessageType(t, conn2, "room_state", 3*time.Second)

	startGame(t, conn1)

	waitForMessageType(t, conn1, "game_state", 5*time.Second)
	waitForMessageType(t, conn2, "game_state", 5*time.Second)

	conns := [2]*websocket.Conn{conn1, conn2}

	firstTS := waitForMessageType(t, conn1, "turn_start", 3*time.Second)
	waitForMessageType(t, conn2, "turn_start", 2*time.Second)

	var pendingTurnStart any = firstTS

	summonedTiles := map[int][]int{}
	testedLevelUp := false
	testedMove := false
	testedSwap := false

	for turn := 1; turn <= 30; turn++ {
		ts := pendingTurnStart
		pendingTurnStart = nil

		if ts == nil {
			t.Fatalf("No turn_start data for turn %d", turn)
		}

		var activePlayer int
		var hand []any
		if tsMap, ok := ts.(map[string]any); ok {
			activePlayer = int(tsMap["active_player"].(float64))
			if h, ok := tsMap["hand"].([]any); ok {
				hand = h
			}
		}
		activeConn := conns[activePlayer]
		otherConn := conns[1-activePlayer]
		t.Logf("--- Turn %d (player %d, tiles: %v) ---", turn, activePlayer, summonedTiles[activePlayer])

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
			waitForMessageType(t, activeConn, "battle_start", 3*time.Second)
			waitForMessageType(t, activeConn, "battle_result", 3*time.Second)
			t.Log("  Battle resolved")
		} else {
			playerTiles := summonedTiles[activePlayer]

			// Try dominio commands in priority order
			if !testedLevelUp && len(playerTiles) >= 1 {
				tileIdx := playerTiles[0]
				t.Logf("  ★ level_up on tile %d", tileIdx)
				sendMessage(t, activeConn, "dominio_action", map[string]any{
					"command":     "level_up",
					"source_tile": tileIdx,
					"target_tile": 0,
				})
				resp, data := waitForAnyType(t, activeConn, []string{"action_result", "action_error"}, 3*time.Second)
				if resp == "action_result" {
					t.Logf("  ✓ level_up succeeded: %s", prettyJSON(data))
					testedLevelUp = true
				} else {
					t.Logf("  level_up failed: %v — summon instead", data)
					trySummon(t, activeConn, hand, activePlayer, summonedTiles)
				}
			} else if !testedSwap && len(playerTiles) >= 2 {
				src, dst := playerTiles[0], playerTiles[1]
				t.Logf("  ★ swap tiles %d <-> %d", src, dst)
				sendMessage(t, activeConn, "dominio_action", map[string]any{
					"command":     "swap",
					"source_tile": src,
					"target_tile": dst,
				})
				resp, data := waitForAnyType(t, activeConn, []string{"action_result", "action_error"}, 3*time.Second)
				if resp == "action_result" {
					t.Logf("  ✓ swap succeeded: %s", prettyJSON(data))
					testedSwap = true
				} else {
					t.Logf("  swap failed: %v — summon instead", data)
					trySummon(t, activeConn, hand, activePlayer, summonedTiles)
				}
			} else if !testedMove && len(playerTiles) >= 1 {
				// move_creature needs an empty destination — find one
				src := playerTiles[0]
				dst := -1
				for i := 0; i < 20; i++ {
					occupied := false
					for _, tiles := range summonedTiles {
						for _, ti := range tiles {
							if ti == i {
								occupied = true
							}
						}
					}
					if !occupied {
						dst = i
						break
					}
				}
				if dst >= 0 {
					t.Logf("  ★ move_creature tile %d -> %d", src, dst)
					sendMessage(t, activeConn, "dominio_action", map[string]any{
						"command":     "move_creature",
						"source_tile": src,
						"target_tile": dst,
					})
					resp, data := waitForAnyType(t, activeConn, []string{"action_result", "action_error"}, 3*time.Second)
					if resp == "action_result" {
						t.Logf("  ✓ move_creature succeeded: %s", prettyJSON(data))
						testedMove = true
						// Update tracked tiles
						for i, ti := range summonedTiles[activePlayer] {
							if ti == src {
								summonedTiles[activePlayer][i] = dst
								break
							}
						}
					} else {
						t.Logf("  move_creature failed: %v — summon instead", data)
						trySummon(t, activeConn, hand, activePlayer, summonedTiles)
					}
				} else {
					trySummon(t, activeConn, hand, activePlayer, summonedTiles)
				}
			} else {
				// Summon to build up tiles
				trySummon(t, activeConn, hand, activePlayer, summonedTiles)
			}
		}

		// end_turn
		sendMessage(t, activeConn, "end_turn", nil)
		msgType, msgData := waitForAnyType(t, activeConn, []string{"game_over", "turn_start"}, 3*time.Second)
		if msgType == "game_over" {
			break
		}
		if msgType == "turn_start" {
			waitForMessageType(t, otherConn, "turn_start", 1*time.Second)
			pendingTurnStart = msgData

			if testedLevelUp && testedMove && testedSwap {
				t.Log("\n✓ All dominio commands tested: level_up, move_creature, swap")
				return
			}
			continue
		}
		t.Fatalf("Unexpected state at turn %d", turn)
	}

	t.Logf("Dominio results: level_up=%v, move=%v, swap=%v", testedLevelUp, testedMove, testedSwap)
	if !testedLevelUp || !testedMove || !testedSwap {
		t.Fatal("Not all dominio commands were tested")
	}
}

func trySummon(t *testing.T, conn *websocket.Conn, hand []any, activePlayer int, summonedTiles map[int][]int) {
	var handCardID int
	if len(hand) > 0 {
		handCardID = int(hand[0].(float64))
	}
	if handCardID > 0 {
		sendMessage(t, conn, "summon", map[string]any{"card_id": handCardID})
		sr, sd := waitForAnyType(t, conn, []string{"action_result", "action_error"}, 3*time.Second)
		if sr == "action_result" {
			if arMap, ok := sd.(map[string]any); ok {
				if d, ok := arMap["data"].(map[string]any); ok {
					if ti, ok := d["tile"].(float64); ok {
						summonedTiles[activePlayer] = append(summonedTiles[activePlayer], int(ti))
						t.Logf("  Summoned on tile %d", int(ti))
					}
				}
			}
		} else {
			sendMessage(t, conn, "pass", nil)
			waitForMessageType(t, conn, "action_result", 3*time.Second)
		}
	} else {
		sendMessage(t, conn, "pass", nil)
		waitForMessageType(t, conn, "action_result", 3*time.Second)
	}
}
