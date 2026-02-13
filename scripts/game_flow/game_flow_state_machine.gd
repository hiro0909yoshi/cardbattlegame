extends RefCounted
class_name GameFlowStateMachine

# State Machine for GameFlowManager phase transitions
# Centralizes all phase transition logic and validation
# Created: 2026-02-13

signal state_changed(new_phase: int)

# Reference to GamePhase enum from GameFlowManager
var game_phase_enum = null
var current_state = null

# Valid state transition whitelist
# Maps from_state -> [valid_to_states]
var _transition_whitelist = {}

func _init():
	_setup_transition_whitelist()

## Initialize with GamePhase enum reference
func initialize(phase_enum) -> void:
	game_phase_enum = phase_enum
	current_state = phase_enum.SETUP
	print("[StateMachine] Initialized with SETUP state")

## Setup the valid transition whitelist
func _setup_transition_whitelist() -> void:
	# Define valid transitions
	# GamePhase enum: SETUP, DICE_ROLL, MOVING, TILE_ACTION, BATTLE, END_TURN
	# 注意: 実際のゲームフローでは同じフェーズへの再遷移が発生するため、それも許可

	_transition_whitelist = {
		# SETUP -> DICE_ROLL (start of turn)
		#       or SETUP (re-entry)
		"SETUP": ["DICE_ROLL", "SETUP"],

		# DICE_ROLL -> MOVING (dice rolled)
		#           or TILE_ACTION (warp spell used)
		#           or DICE_ROLL (CPU/player turn re-entry)
		"DICE_ROLL": ["MOVING", "TILE_ACTION", "DICE_ROLL"],

		# MOVING -> TILE_ACTION (reached destination)
		#        or END_TURN (various flows)
		#        or SETUP, DICE_ROLL, MOVING (複雑なフロー対応)
		"MOVING": ["TILE_ACTION", "END_TURN", "SETUP", "DICE_ROLL", "MOVING"],

		# TILE_ACTION -> BATTLE (landed on enemy)
		#           or TILE_ACTION (stay on same tile for multiple actions)
		#           or END_TURN (no battle)
		"TILE_ACTION": ["BATTLE", "TILE_ACTION", "END_TURN"],

		# BATTLE -> TILE_ACTION (battle complete, more actions possible)
		#        or BATTLE (chain attack)
		#        or END_TURN (no more actions)
		"BATTLE": ["TILE_ACTION", "BATTLE", "END_TURN"],

		# END_TURN -> SETUP (next player turn)
		#          or END_TURN (re-entry)
		"END_TURN": ["SETUP", "END_TURN"],
	}

## Attempt transition to new state
func transition_to(new_state) -> bool:
	if game_phase_enum == null:
		push_error("[StateMachine] game_phase_enum not initialized")
		return false

	var current_state_name = _phase_to_name(current_state)
	var new_state_name = _phase_to_name(new_state)

	# Check if transition is valid
	if not _is_valid_transition(current_state, new_state):
		push_error("[StateMachine] Invalid transition: %s -> %s" % [current_state_name, new_state_name])
		return false

	# Perform transition
	current_state = new_state
	print("[StateMachine] Transition: %s -> %s" % [current_state_name, new_state_name])
	emit_signal("state_changed", new_state)
	return true

## Check if a transition is valid
func _is_valid_transition(from_state, to_state) -> bool:
	var from_name = _phase_to_name(from_state)
	var to_name = _phase_to_name(to_state)

	if from_name not in _transition_whitelist:
		return false

	var valid_targets = _transition_whitelist[from_name]
	return to_name in valid_targets

## Convert phase int/enum to string name
func _phase_to_name(phase) -> String:
	match phase:
		game_phase_enum.SETUP:
			return "SETUP"
		game_phase_enum.DICE_ROLL:
			return "DICE_ROLL"
		game_phase_enum.MOVING:
			return "MOVING"
		game_phase_enum.TILE_ACTION:
			return "TILE_ACTION"
		game_phase_enum.BATTLE:
			return "BATTLE"
		game_phase_enum.END_TURN:
			return "END_TURN"
		_:
			return "UNKNOWN"

## Get current state name for debugging
func get_current_state_name() -> String:
	return _phase_to_name(current_state)

## Get all valid transitions from current state
func get_valid_transitions() -> Array:
	var current_name = _phase_to_name(current_state)
	if current_name not in _transition_whitelist:
		return []
	return _transition_whitelist[current_name]
