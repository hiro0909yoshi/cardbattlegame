extends Node
class_name PlayerSystem

# プレイヤー管理システム - 3D専用版

signal dice_rolled(value: int)
signal dice_rolled_double(value1: int, value2: int, total: int)  # 2個ダイス用
# TODO: 将来実装予定
# signal magic_changed(player_id: int, new_value: int)
@warning_ignore("unused_signal")  # GameSystemManagerで接続、将来のLapSystemから発行予定
signal player_won(player_id: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# プレイヤーデータ
class PlayerData:
	var id: int = 0
	var name: String = ""
	var current_tile: int = 0
	var magic_power: int = 3000
	var target_magic: int = 8000
	var color: Color = Color.WHITE
	var piece_node: Node = null  # 3D駒ノード（MovementController3Dが管理）
	var movement_direction: String = ""
	var current_direction: int = 1  # 現在の移動方向（1=順方向, -1=逆方向）
	var came_from: int = -1  # 前にいたタイル（分岐判定用）
	var last_choice_tile: int = -1
	var curse: Dictionary = {}  # 呪い効果（SpellCurseで管理）
	var buffs: Dictionary = {}  # バフ効果（方向選択権等）
	var magic_stones: Dictionary = {"fire": 0, "water": 0, "earth": 0, "wind": 0}  # 魔法石所持数
	var destroyed_count: int = 0  # バトルで破壊されたクリーチャー数

# プレイヤー管理
var players = []
var current_player_index = 0
var player_pieces = []  # 3D駒ノード配列

# 移動関連
var is_moving = false

# デバッグコントローラー参照
var debug_controller: DebugController = null

# 外部システム参照（TEP計算用）
var board_system_ref = null
var magic_stone_system_ref = null  # MagicStoneSystem（tiles/magic_stone_system.gd）

func _ready():
	pass

# デバッグコントローラーを設定
func set_debug_controller(controller: DebugController):
	debug_controller = controller

# プレイヤーを初期化
func initialize_players(player_count: int):
	players.clear()
	player_pieces.clear()
	
	for i in range(player_count):
		var player = PlayerData.new()
		player.id = i
		player.name = "プレイヤー" + str(i + 1)
		player.current_tile = 0
		player.magic_power = GameConstants.DEFAULT_INITIAL_MAGIC
		player.target_magic = GameConstants.DEFAULT_TARGET_MAGIC
		player.color = GameConstants.PLAYER_COLORS[i % GameConstants.PLAYER_COLORS.size()]
		player.piece_node = null  # 3D駒は後で設定
		
		players.append(player)
		player_pieces.append(null)

# 現在のプレイヤーを取得
func get_current_player() -> PlayerData:
	if current_player_index >= 0 and current_player_index < players.size():
		return players[current_player_index]
	return null

# 次のプレイヤーに交代
func next_player():
	current_player_index = (current_player_index + 1) % players.size()
	print("PlayerSystem: ", players[current_player_index].name, "のターン")

# サイコロを振る（旧版 - 互換性のため残す）
func roll_dice() -> int:
	var value: int
	
	# デバッグコントローラーから固定値を取得
	if debug_controller and debug_controller.get_fixed_dice() > 0:
		value = debug_controller.get_fixed_dice()
		print("【デバッグ】固定ダイス: ", value)
	else:
		value = randi_range(1, 6)
	
	emit_signal("dice_rolled", value)
	return value

# サイコロ2個を振る（新版）
# ダイス1: 0, 1, 2, 3, 4, 5
# ダイス2: 0, 2, 3, 4, 5, 6
# 両方0の場合: 12（特殊ボーナス）
func roll_dice_double() -> Dictionary:
	var dice1: int
	var dice2: int
	var total: int
	
	# デバッグコントローラーから固定値を取得
	if debug_controller and debug_controller.get_fixed_dice() > 0:
		total = debug_controller.get_fixed_dice()
		# 固定値の場合は適当に分配
		dice1 = mini(total / 2, 5)
		dice2 = total - dice1
		print("【デバッグ】固定ダイス: ", total)
	else:
		# ダイス1: 0-5
		dice1 = randi_range(0, 5)
		# ダイス2: 0, 2, 3, 4, 5, 6（1がない）
		var dice2_faces = [0, 2, 3, 4, 5, 6]
		dice2 = dice2_faces[randi_range(0, 5)]
		
		# 両方0なら12
		if dice1 == 0 and dice2 == 0:
			total = 12
		else:
			total = dice1 + dice2
	
	emit_signal("dice_rolled_double", dice1, dice2, total)
	return {"dice1": dice1, "dice2": dice2, "total": total}

# サイコロ3個を振る（フライ効果用）
# ダイス1: 0, 1, 2, 3, 4, 5
# ダイス2: 0, 2, 3, 4, 5, 6
# ダイス3: 1, 2, 3, 4, 5, 6（通常ダイス）
# ダイス1とダイス2が両方0の場合: 12 + ダイス3
func roll_dice_triple() -> Dictionary:
	var dice1: int
	var dice2: int
	var dice3: int
	var total: int
	
	# デバッグコントローラーから固定値を取得
	if debug_controller and debug_controller.get_fixed_dice() > 0:
		total = debug_controller.get_fixed_dice()
		# 固定値の場合は適当に分配
		dice1 = mini(total / 3, 5)
		dice2 = mini((total - dice1) / 2, 6)
		dice3 = total - dice1 - dice2
		print("【デバッグ】固定ダイス: ", total)
	else:
		# ダイス1: 0-5
		dice1 = randi_range(0, 5)
		# ダイス2: 0, 2, 3, 4, 5, 6（1がない）
		var dice2_faces = [0, 2, 3, 4, 5, 6]
		dice2 = dice2_faces[randi_range(0, 5)]
		# ダイス3: 1-6（通常ダイス）
		dice3 = randi_range(1, 6)
		
		# ダイス1とダイス2が両方0なら12 + ダイス3
		if dice1 == 0 and dice2 == 0:
			total = 12 + dice3
		else:
			total = dice1 + dice2 + dice3
	
	return {"dice1": dice1, "dice2": dice2, "dice3": dice3, "total": total}

# EPを増減
func add_magic(player_id: int, amount: int):
	if player_id < 0 or player_id >= players.size():
		return
		
	var player = players[player_id]
	player.magic_power += amount
	# マイナス値を許容（破産処理で対応）
	
	print(player.name, ": EP ", player.magic_power, "EP (", 
		"+" if amount >= 0 else "", amount, ")")
	
	# 勝利判定はチェックポイント通過時に行う（LapSystem）

# EPを設定（初期値設定用）
func set_magic(player_id: int, amount: int):
	if player_id < 0 or player_id >= players.size():
		return
	players[player_id].magic_power = max(0, amount)
	print(players[player_id].name, ": EPを", amount, "EPに設定")

# EPを取得
func get_magic(player_id: int) -> int:
	if player_id >= 0 and player_id < players.size():
		return players[player_id].magic_power
	return 0

# 通行料を支払う
func pay_toll(payer_id: int, receiver_id: int, amount: int) -> bool:
	if payer_id < 0 or payer_id >= players.size():
		return false
	if receiver_id < 0 or receiver_id >= players.size():
		return false
		
	var payer = players[payer_id]
	
	# 全額支払い（マイナスになる可能性あり → 破産処理で対応）
	add_magic(payer_id, -amount)
	add_magic(receiver_id, amount)
	
	# EPが足りていたかどうかを返す
	return payer.magic_power >= 0

# プレイヤーの現在位置を取得
func get_player_position(player_id: int) -> int:
	if player_id >= 0 and player_id < players.size():
		return players[player_id].current_tile
	return -1

# プレイヤーの現在位置を設定
func set_player_position(player_id: int, tile_index: int):
	if player_id >= 0 and player_id < players.size():
		players[player_id].current_tile = tile_index

# すべてのプレイヤー情報を取得
func get_all_players_info() -> Array:
	var info = []
	for player in players:
		info.append({
			"id": player.id,
			"name": player.name,
			"tile": player.current_tile,
			"magic": player.magic_power,
			"target": player.target_magic
		})
	return info

# プレイヤー駒ノードを設定（MovementController3Dから呼ばれる）
func set_player_piece_node(player_id: int, node: Node):
	if player_id >= 0 and player_id < players.size():
		players[player_id].piece_node = node
		if player_id < player_pieces.size():
			player_pieces[player_id] = node

# ============================================
# TEP計算（一元化）
# ============================================

## TEPを計算（所持EP＋土地価値＋魔法石価値）
## 勝利判定、UI表示など全てここを参照する
func calculate_total_assets(player_id: int) -> int:
	if player_id < 0 or player_id >= players.size():
		return 0
	
	var total = players[player_id].magic_power
	
	# 土地価値を加算
	total += _calculate_land_value(player_id)
	
	# 魔法石価値を加算
	total += _calculate_stone_value(player_id)
	
	return total

## 土地価値を計算（通行料の合計）
func _calculate_land_value(player_id: int) -> int:
	if not board_system_ref or not "tile_nodes" in board_system_ref:
		return 0
	
	var value = 0
	for i in board_system_ref.tile_nodes:
		var tile = board_system_ref.tile_nodes[i]
		if tile.owner_id == player_id:
			var toll = board_system_ref.calculate_toll(i)
			value += toll
	
	return value

## 魔法石価値を計算
func _calculate_stone_value(player_id: int) -> int:
	if player_id < 0 or player_id >= players.size():
		return 0
	
	# MagicStoneSystemが設定されていれば委譲
	if magic_stone_system_ref and magic_stone_system_ref.has_method("calculate_player_stone_value"):
		return magic_stone_system_ref.calculate_player_stone_value(player_id)
	
	return 0

## 外部システム参照を設定
func set_board_system(board_system) -> void:
	board_system_ref = board_system

func set_magic_stone_system(stone_system) -> void:
	magic_stone_system_ref = stone_system

# ============================================
# 魔法石操作
# ============================================

## 魔法石を追加
func add_magic_stone(player_id: int, element: String, amount: int) -> void:
	if player_id < 0 or player_id >= players.size():
		return
	if not players[player_id].magic_stones.has(element):
		return
	
	players[player_id].magic_stones[element] += amount
	players[player_id].magic_stones[element] = max(0, players[player_id].magic_stones[element])

## 魔法石の所持数を取得
func get_magic_stone_count(player_id: int, element: String) -> int:
	if player_id < 0 or player_id >= players.size():
		return 0
	return players[player_id].magic_stones.get(element, 0)

## 全魔法石の所持数を取得
func get_all_magic_stones(player_id: int) -> Dictionary:
	if player_id < 0 or player_id >= players.size():
		return {"fire": 0, "water": 0, "earth": 0, "wind": 0}
	return players[player_id].magic_stones.duplicate()
