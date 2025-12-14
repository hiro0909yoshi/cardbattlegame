extends Node
class_name PlayerSystem

# プレイヤー管理システム - 3D専用版

signal dice_rolled(value: int)
# TODO: 将来実装予定
# signal magic_changed(player_id: int, new_value: int)
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

# プレイヤー管理
var players = []
var current_player_index = 0
var player_pieces = []  # 3D駒ノード配列

# 移動関連
var is_moving = false

# デバッグコントローラー参照
var debug_controller: DebugController = null

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
		player.magic_power = GameConstants.INITIAL_MAGIC
		player.target_magic = GameConstants.TARGET_MAGIC
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

# サイコロを振る
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

# 魔力を増減
func add_magic(player_id: int, amount: int):
	if player_id < 0 or player_id >= players.size():
		return
		
	var player = players[player_id]
	player.magic_power += amount
	player.magic_power = max(0, player.magic_power)
	
	print(player.name, ": 魔力 ", player.magic_power, "G (", 
		"+" if amount >= 0 else "", amount, ")")
	
	# 勝利判定はチェックポイント通過時に行う（LapSystem）

# 魔力を設定（初期値設定用）
func set_magic(player_id: int, amount: int):
	if player_id < 0 or player_id >= players.size():
		return
	players[player_id].magic_power = max(0, amount)
	print(players[player_id].name, ": 魔力を", amount, "Gに設定")

# 魔力を取得
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
	
	if payer.magic_power >= amount:
		add_magic(payer_id, -amount)
		add_magic(receiver_id, amount)
		return true
	else:
		# 魔力不足の場合は全額支払い
		var paid = payer.magic_power
		add_magic(payer_id, -paid)
		add_magic(receiver_id, paid)
		return false

# プレイヤーの現在位置を取得
func get_player_position(player_id: int) -> int:
	if player_id >= 0 and player_id < players.size():
		return players[player_id].current_tile
	return -1

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
