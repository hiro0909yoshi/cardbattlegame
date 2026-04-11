extends RefCounted
class_name GameStateSaver

## ゲーム中ステートセーブ/復帰システム
## ターン開始時に全状態を保存し、クラッシュ復帰時に再構築する
## 「完全再現」ではなく「安全な場所に戻して再構築」する設計

const SAVE_FILE_PATH = "user://game_state.json"
const SAVE_VERSION = 1


# ==========================================
# ファイル操作
# ==========================================

## セーブファイルが存在するか
static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)


## セーブファイルを削除
static func clear_save_file() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("[GameStateSaver] セーブファイル削除")


## セーブデータをファイルに書き出し（tmp→rename方式で破損防止）
static func save_to_file(data: Dictionary) -> bool:
	var tmp_path = SAVE_FILE_PATH + ".tmp"

	# 1. 一時ファイルに書き込み
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		GameLogger.error("Save", "一時ファイルを開けませんでした: %s" % tmp_path)
		return false

	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

	# 2. 既存ファイルを削除してからリネーム
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
	var err = DirAccess.rename_absolute(tmp_path, SAVE_FILE_PATH)
	if err != OK:
		GameLogger.error("Save", "リネーム失敗: %s → %s (err=%d)" % [tmp_path, SAVE_FILE_PATH, err])
		return false

	print("[GameStateSaver] セーブ完了: %s" % SAVE_FILE_PATH)
	return true


## セーブデータをファイルから読み込み
static func load_from_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return {}

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		GameLogger.error("Save", "セーブファイルを開けませんでした: %s" % SAVE_FILE_PATH)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		GameLogger.error("Save", "セーブファイルのパースに失敗: %s" % json.get_error_message())
		return {}

	var data = json.data
	if not data is Dictionary:
		GameLogger.error("Save", "セーブデータが不正な形式です")
		return {}

	# バージョンチェック
	if data.get("version", 0) != SAVE_VERSION:
		GameLogger.error("Save", "セーブデータのバージョンが不一致: %d (期待: %d)" % [data.get("version", 0), SAVE_VERSION])
		return {}

	return data


# ==========================================
# セーブデータ構築
# ==========================================

## 全システムから状態を収集してセーブデータを構築
## systems: {"player_system", "card_system", "board_system_3d", "game_flow_manager", "lap_system", "player_buff_system", "stage_id"}
static func build_save_data(systems: Dictionary) -> Dictionary:
	var gfm_ref: GameFlowManager = systems.get("game_flow_manager")
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"stage_id": systems.get("stage_id", GameData.selected_stage_id),
		"game_mode": gfm_ref.current_game_mode if gfm_ref else "solo",
	}

	var player_system: PlayerSystem = systems.get("player_system")
	var card_system: CardSystem = systems.get("card_system")
	var board_system: BoardSystem3D = systems.get("board_system_3d")
	var gfm: GameFlowManager = systems.get("game_flow_manager")
	var lap_system: LapSystem = systems.get("lap_system")
	var buff_system: PlayerBuffSystem = systems.get("player_buff_system")

	# プレイヤー数・CPU設定
	if player_system:
		data["player_count"] = player_system.players.size()
	if gfm:
		data["player_is_cpu"] = gfm.player_is_cpu.duplicate()

	# 進行状況
	data["progress"] = _build_progress(gfm)

	# プレイヤー状態（board_systemから実際の駒位置を取得）
	data["players"] = _build_players(player_system, board_system)

	# カード状態
	data["cards"] = _build_cards(card_system, player_system)

	# ボード状態
	data["board"] = _build_board(board_system)

	# 周回状態
	data["lap_state"] = _build_lap_state(lap_system)

	# バフ状態
	data["buffs"] = _build_buffs(buff_system)

	# ゲーム統計
	if gfm:
		data["game_stats"] = gfm.game_stats.duplicate()

	return data


## 進行状況を構築
static func _build_progress(gfm: GameFlowManager) -> Dictionary:
	if not gfm:
		return {}
	return {
		"current_turn_number": gfm.current_turn_number,
		"current_player_index": gfm.player_system.current_player_index if gfm.player_system else 0,
		"last_dice_result": gfm.last_dice_result,
		"save_phase": gfm._current_save_phase,
	}


## プレイヤー状態を構築
## board_system から実際の駒位置を取得（player.current_tile は更新されていない場合がある）
static func _build_players(player_system: PlayerSystem, board_system: BoardSystem3D = null) -> Array[Dictionary]:
	if not player_system:
		return []

	var players_data: Array[Dictionary] = []
	for player in player_system.players:
		# 駒位置: board_system.get_player_tile() が正（movement_controller管理）
		var tile_pos: int = player.current_tile
		if board_system:
			var bs_tile: int = board_system.get_player_tile(player.id)
			if bs_tile >= 0:
				tile_pos = bs_tile
		players_data.append({
			"id": player.id,
			"current_tile": tile_pos,
			"magic_power": player.magic_power,
			"target_magic": player.target_magic,
			"current_direction": player.current_direction,
			"came_from": player.came_from,
			"last_choice_tile": player.last_choice_tile,
			"direction_choice_pending": player.direction_choice_pending,
			"curse": player.curse.duplicate(true),
			"magic_stones": player.magic_stones.duplicate(),
		})
	return players_data


## カード状態を構築
static func _build_cards(card_system: CardSystem, player_system: PlayerSystem) -> Dictionary:
	if not card_system or not player_system:
		return {}

	var cards_data: Dictionary = {}
	for player in player_system.players:
		var pid = player.id
		var pid_str = str(pid)

		# 手札: card_id の配列で保存（復元時に CardLoader.get_card_by_id で再構築）
		var hand_ids: Array[int] = []
		if card_system.player_hands.has(pid):
			for card in card_system.player_hands[pid].get("data", []):
				hand_ids.append(int(card.get("id", -1)))

		# デッキ: card_id の配列
		# クエストモード(player_deck_pools)優先、通常モード(player_decks)フォールバック
		var deck_ids: Array = []
		if card_system.player_deck_pools.has(pid) and not card_system.player_deck_pools[pid].is_empty():
			for card in card_system.player_deck_pools[pid]:
				deck_ids.append(int(card.get("id", -1)))
		elif card_system.player_decks.has(pid):
			deck_ids = card_system.player_decks[pid].duplicate()

		# 捨て札: card_id の配列
		var discard_ids: Array = []
		if card_system.player_discard_pools.has(pid) and not card_system.player_discard_pools[pid].is_empty():
			for card in card_system.player_discard_pools[pid]:
				discard_ids.append(int(card.get("id", -1)))
		elif card_system.player_discards.has(pid):
			discard_ids = card_system.player_discards[pid].duplicate()

		# クエストモードかどうかのフラグ（復元時の分岐用）
		var is_pool_mode: bool = card_system.player_deck_pools.has(pid)

		cards_data[pid_str] = {
			"deck": deck_ids,
			"hand": hand_ids,
			"discard": discard_ids,
			"pool_mode": is_pool_mode,
		}
	return cards_data


## ボード状態を構築
static func _build_board(board_system: BoardSystem3D) -> Array[Dictionary]:
	if not board_system:
		return []

	var board_data: Array[Dictionary] = []
	for tile_index in board_system.tile_nodes:
		var tile: BaseTile = board_system.tile_nodes[tile_index]
		var tile_data: Dictionary = {
			"index": tile_index,
			"owner_id": tile.owner_id,
			"level": tile.level,
			"down_state": tile.down_state,
			"creature_data": tile.creature_data.duplicate(true),
		}
		board_data.append(tile_data)
	return board_data


## 周回状態を構築
static func _build_lap_state(lap_system: LapSystem) -> Dictionary:
	if not lap_system:
		return {}

	var lap_data: Dictionary = {}
	for player_id in lap_system.player_lap_state:
		lap_data[str(player_id)] = lap_system.player_lap_state[player_id].duplicate()
	# 破壊カウンターも保存
	lap_data["destroy_count"] = lap_system.destroy_count
	return lap_data


## バフ状態を構築
static func _build_buffs(buff_system: PlayerBuffSystem) -> Dictionary:
	if not buff_system:
		return {}

	var buffs_data: Dictionary = {}
	for player_id in buff_system.player_buffs:
		var buff_list: Array[Dictionary] = []
		for buff in buff_system.player_buffs[player_id]:
			buff_list.append(buff.duplicate())
		buffs_data[str(player_id)] = buff_list
	return buffs_data


# ==========================================
# セーブデータ適用（復元）
# ==========================================

## セーブデータを各システムに適用
## 適用順序: players → cards → board → progress（順序固定）
## UI更新は呼び出し元で実行すること
static func apply_save_data(data: Dictionary, systems: Dictionary) -> bool:
	if data.is_empty():
		GameLogger.error("Save", "セーブデータが空です")
		return false

	var player_system: PlayerSystem = systems.get("player_system")
	var card_system: CardSystem = systems.get("card_system")
	var board_system: BoardSystem3D = systems.get("board_system_3d")
	var gfm: GameFlowManager = systems.get("game_flow_manager")
	var lap_system: LapSystem = systems.get("lap_system")
	var buff_system: PlayerBuffSystem = systems.get("player_buff_system")

	# 1. プレイヤー状態を復元
	if not _apply_players(data.get("players", []), player_system):
		GameLogger.error("Save", "プレイヤー状態の復元に失敗")
		return false

	# 2. カード状態を復元
	if not _apply_cards(data.get("cards", {}), card_system, player_system):
		GameLogger.error("Save", "カード状態の復元に失敗")
		return false

	# 3. ボード状態を復元
	if not _apply_board(data.get("board", []), board_system):
		GameLogger.error("Save", "ボード状態の復元に失敗")
		return false

	# 4. 進行状況を復元（ターン数、プレイヤーインデックス、周回、バフ）
	if not _apply_progress(data, gfm, lap_system, buff_system, board_system):
		GameLogger.error("Save", "進行状況の復元に失敗")
		return false

	print("[GameStateSaver] セーブデータ適用完了 (ラウンド%d, P%d)" % [
		data.get("progress", {}).get("current_turn_number", 0),
		data.get("progress", {}).get("current_player_index", 0) + 1,
	])
	return true


## プレイヤー状態を復元
static func _apply_players(players_data: Array, player_system: PlayerSystem) -> bool:
	if not player_system or players_data.is_empty():
		return false

	for p_data in players_data:
		var pid: int = int(p_data.get("id", 0))
		if pid < 0 or pid >= player_system.players.size():
			continue

		var player = player_system.players[pid]
		player.current_tile = int(p_data.get("current_tile", 0))
		player.magic_power = int(p_data.get("magic_power", 0))
		player.target_magic = int(p_data.get("target_magic", 0))
		player.current_direction = int(p_data.get("current_direction", 1))
		player.came_from = int(p_data.get("came_from", -1))
		player.last_choice_tile = int(p_data.get("last_choice_tile", -1))
		player.direction_choice_pending = bool(p_data.get("direction_choice_pending", false))

		# 刻印（深いコピー）
		var curse_data = p_data.get("curse", {})
		player.curse = curse_data.duplicate(true) if curse_data is Dictionary else {}

		# 魔法石
		var stones_data = p_data.get("magic_stones", {})
		if stones_data is Dictionary:
			for key in stones_data:
				if player.magic_stones.has(key):
					player.magic_stones[key] = int(stones_data[key])

	return true


## カード状態を復元
static func _apply_cards(cards_data: Dictionary, card_system: CardSystem, player_system: PlayerSystem) -> bool:
	if not card_system or not player_system or cards_data.is_empty():
		return false

	for player in player_system.players:
		var pid = player.id
		var pid_str = str(pid)
		if not cards_data.has(pid_str):
			continue

		var c_data = cards_data[pid_str]
		var pool_mode: bool = bool(c_data.get("pool_mode", false))

		if pool_mode:
			# クエストモード: player_deck_pools / player_discard_pools を復元
			# card_id から CardLoader で card_data を再構築
			if not card_system.player_deck_pools.has(pid):
				card_system.player_deck_pools[pid] = []
			card_system.player_deck_pools[pid].clear()
			for card_id in c_data.get("deck", []):
				var card_data = CardLoader.get_card_by_id(int(card_id))
				if not card_data.is_empty():
					card_system.player_deck_pools[pid].append(card_data.duplicate(true))

			if not card_system.player_discard_pools.has(pid):
				card_system.player_discard_pools[pid] = []
			card_system.player_discard_pools[pid].clear()
			for card_id in c_data.get("discard", []):
				var card_data = CardLoader.get_card_by_id(int(card_id))
				if not card_data.is_empty():
					card_system.player_discard_pools[pid].append(card_data.duplicate(true))

			# 通常モードのデッキ/捨て札はクリア（誤参照防止）
			if card_system.player_decks.has(pid):
				card_system.player_decks[pid].clear()
			if card_system.player_discards.has(pid):
				card_system.player_discards[pid].clear()
		else:
			# 通常モード: デッキ/捨て札を復元（card_id配列）
			if card_system.player_decks.has(pid):
				card_system.player_decks[pid].clear()
				for card_id in c_data.get("deck", []):
					card_system.player_decks[pid].append(int(card_id))

			if card_system.player_discards.has(pid):
				card_system.player_discards[pid].clear()
				for card_id in c_data.get("discard", []):
					card_system.player_discards[pid].append(int(card_id))

		# 手札を復元（card_idから CardLoader で再構築）
		if card_system.player_hands.has(pid):
			card_system.player_hands[pid]["data"].clear()
			for card_id in c_data.get("hand", []):
				var card_data = CardLoader.get_card_by_id(int(card_id))
				if not card_data.is_empty():
					card_system.player_hands[pid]["data"].append(card_data.duplicate(true))
				else:
					GameLogger.warn("Save", "カードID %d が見つかりません（スキップ）" % card_id)

	return true


## ボード状態を復元
static func _apply_board(board_data: Array, board_system: BoardSystem3D) -> bool:
	if not board_system or board_data.is_empty():
		return false

	for tile_save in board_data:
		var tile_index: int = int(tile_save.get("index", -1))
		if not board_system.tile_nodes.has(tile_index):
			continue

		var tile: BaseTile = board_system.tile_nodes[tile_index]

		# オーナー
		tile.owner_id = int(tile_save.get("owner_id", -1))

		# レベル
		tile.level = int(tile_save.get("level", 1))

		# ダウン状態
		tile.down_state = bool(tile_save.get("down_state", false))

		# クリーチャーデータ（深いコピー必須）
		var c_data = tile_save.get("creature_data", {})
		if c_data is Dictionary and not c_data.is_empty():
			tile.creature_data = c_data.duplicate(true)
		else:
			tile.creature_data = {}

	return true


## 進行状況を復元
static func _apply_progress(
	data: Dictionary,
	gfm: GameFlowManager,
	lap_system: LapSystem,
	buff_system: PlayerBuffSystem,
	board_system: BoardSystem3D,
) -> bool:
	var progress = data.get("progress", {})

	# ターン数・ダイス結果・セーブフェーズ
	if gfm:
		gfm.current_turn_number = int(progress.get("current_turn_number", 1))
		gfm.last_dice_result = int(progress.get("last_dice_result", -1))
		gfm._current_save_phase = str(progress.get("save_phase", "turn_start"))

		# CPU設定を復元
		var cpu_flags = data.get("player_is_cpu", [])
		if not cpu_flags.is_empty():
			gfm.player_is_cpu = cpu_flags

	# プレイヤーインデックス
	var player_index: int = int(progress.get("current_player_index", 0))
	if gfm and gfm.player_system:
		gfm.player_system.current_player_index = player_index
	if board_system:
		board_system.current_player_index = player_index

	# 周回状態を復元
	if lap_system:
		var lap_data = data.get("lap_state", {})
		# 破壊カウンター
		lap_system.destroy_count = int(lap_data.get("destroy_count", 0))
		# プレイヤーごとの周回状態
		for key in lap_data:
			if key == "destroy_count":
				continue
			var pid = int(key)
			if lap_system.player_lap_state.has(pid):
				var saved_state = lap_data[key]
				if saved_state is Dictionary:
					lap_system.player_lap_state[pid] = saved_state.duplicate(true)

	# バフ状態を復元
	if buff_system:
		var buffs_data = data.get("buffs", {})
		for key in buffs_data:
			var pid = int(key)
			if buff_system.player_buffs.has(pid):
				buff_system.player_buffs[pid].clear()
				var buff_list = buffs_data[key]
				if buff_list is Array:
					for buff in buff_list:
						if buff is Dictionary:
							buff_system.player_buffs[pid].append(buff.duplicate())

	# ゲーム統計を復元
	if gfm:
		var saved_stats = data.get("game_stats", {})
		if saved_stats is Dictionary:
			gfm.game_stats = saved_stats.duplicate()

	return true
