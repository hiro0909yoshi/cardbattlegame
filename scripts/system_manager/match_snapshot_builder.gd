class_name MatchSnapshotBuilder
extends RefCounted

## 試合状態のスナップショットを構築する
## 各システムから状態を「集めるだけ」。状態の変更は一切行わない。
##
## 用途:
## - セーブ/ロード
## - PvP同期（将来）
## - リプレイ（将来）
## - デバッグ（状態一発取得）


# === システム参照 ===

var _player_system: PlayerSystem = null
var _lap_system = null  # LapSystem
var _player_buff_system: PlayerBuffSystem = null
var _spell_state_handler = null  # SpellStateHandler
var _card_system = null  # CardSystem
var _board_system: BoardSystem3D = null
var _game_flow_manager = null  # GameFlowManager


## システム参照を一括注入
func setup(
	player_system: PlayerSystem,
	lap_system,
	player_buff_system: PlayerBuffSystem,
	spell_state_handler,
	card_system,
	board_system: BoardSystem3D,
	game_flow_manager,
) -> void:
	_player_system = player_system
	_lap_system = lap_system
	_player_buff_system = player_buff_system
	_spell_state_handler = spell_state_handler
	_card_system = card_system
	_board_system = board_system
	_game_flow_manager = game_flow_manager


# ============ プレイヤースナップショット ============

## プレイヤー1人分の完全状態を取得
func get_player_snapshot(player_id: int) -> Dictionary:
	var snapshot: Dictionary = {}

	# --- PlayerSystem ---
	if _player_system and player_id < _player_system.players.size():
		var p = _player_system.players[player_id]
		snapshot["id"] = p.id
		snapshot["name"] = p.name
		snapshot["magic_power"] = p.magic_power
		snapshot["target_magic"] = p.target_magic
		snapshot["current_tile"] = p.current_tile
		snapshot["current_direction"] = p.current_direction
		snapshot["came_from"] = p.came_from
		snapshot["last_choice_tile"] = p.last_choice_tile
		snapshot["movement_direction"] = p.movement_direction
		snapshot["direction_choice_pending"] = p.direction_choice_pending
		snapshot["curse"] = p.curse.duplicate(true)
		snapshot["magic_stones"] = p.magic_stones.duplicate(true)

	# --- LapSystem ---
	if _lap_system and _lap_system.player_lap_state.has(player_id):
		snapshot["lap_state"] = _lap_system.player_lap_state[player_id].duplicate(true)
	else:
		snapshot["lap_state"] = {}

	# --- PlayerBuffSystem ---
	if _player_buff_system and _player_buff_system.player_buffs.has(player_id):
		var buffs: Array[Dictionary] = []
		for buff in _player_buff_system.player_buffs[player_id]:
			buffs.append(buff.duplicate(true))
		snapshot["buffs"] = buffs
	else:
		snapshot["buffs"] = []

	# --- SpellStateHandler ---
	if _spell_state_handler:
		snapshot["spell_used_this_turn"] = _spell_state_handler.spell_used_this_turn
		snapshot["skip_dice_phase"] = _spell_state_handler.skip_dice_phase
	else:
		snapshot["spell_used_this_turn"] = false
		snapshot["skip_dice_phase"] = false

	# --- CardSystem ---
	if _card_system:
		var hand_data = _card_system.player_hands.get(player_id, {}).get("data", [])
		var hand_copy: Array[Dictionary] = []
		for card in hand_data:
			hand_copy.append(card.duplicate(true))
		snapshot["hand"] = hand_copy
		snapshot["deck_count"] = _card_system.player_decks.get(player_id, []).size()
		snapshot["discard_count"] = _card_system.player_discards.get(player_id, []).size()
	else:
		snapshot["hand"] = []
		snapshot["deck_count"] = 0
		snapshot["discard_count"] = 0

	return snapshot


# ============ 試合スナップショット ============

## 試合全体の完全状態を取得
func get_match_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}

	# --- プレイヤー全員 ---
	var players: Array[Dictionary] = []
	if _player_system:
		for i in range(_player_system.players.size()):
			players.append(get_player_snapshot(i))
	snapshot["players"] = players

	# --- GameFlowManager ---
	if _game_flow_manager:
		snapshot["current_turn"] = _game_flow_manager.current_turn_number
		snapshot["current_player_index"] = _game_flow_manager.current_player_index
		snapshot["current_phase"] = str(_game_flow_manager.current_phase)
		snapshot["game_stats"] = _game_flow_manager.game_stats.duplicate(true) if _game_flow_manager.game_stats else {}
	else:
		snapshot["current_turn"] = 0
		snapshot["current_player_index"] = 0
		snapshot["current_phase"] = ""
		snapshot["game_stats"] = {}

	# --- LapSystem（全体共有値） ---
	if _lap_system:
		snapshot["destroy_count"] = _lap_system.destroy_count
	else:
		snapshot["destroy_count"] = 0

	# --- BoardSystem3D ---
	var tiles: Array[Dictionary] = []
	if _board_system:
		for tile_index in _board_system.tile_nodes.keys():
			var info = _board_system.get_tile_info(tile_index)
			tiles.append({
				"index": tile_index,
				"owner_id": info.get("owner_id", -1),
				"creature_data": info.get("creature_data", {}).duplicate(true),
				"level": info.get("level", 1),
				"is_down": info.get("is_down", false),
				"element": info.get("element", ""),
			})
	snapshot["tiles"] = tiles

	return snapshot
