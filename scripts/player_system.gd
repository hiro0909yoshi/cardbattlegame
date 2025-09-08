extends Node
class_name PlayerSystem

# プレイヤー管理システム - デバッグ機能付き

signal dice_rolled(value: int)
signal movement_started()
signal movement_completed(final_tile: int)
signal magic_changed(player_id: int, new_value: int)
signal player_won(player_id: int)

# プレイヤーデータ
class PlayerData:
	var id: int = 0
	var name: String = ""
	var current_tile: int = 0
	var magic_power: int = 3000
	var target_magic: int = 8000
	var color: Color = Color.WHITE
	var piece_node: Node = null  # 駒のノード

# プレイヤー管理
var players = []
var current_player_index = 0
var player_pieces = []  # 駒のノード配列

# 移動関連
var is_moving = false
var move_speed = 300.0  # 移動速度

# デバッグ用
var debug_dice_mode = false
var fixed_dice_value = 0

func _ready():
	print("PlayerSystem: 初期化")
	print("【デバッグ】数字キー1-6でサイコロ固定、0で解除")

# デバッグ入力を処理
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				set_debug_dice(1)
			KEY_2:
				set_debug_dice(2)
			KEY_3:
				set_debug_dice(3)
			KEY_4:
				set_debug_dice(4)
			KEY_5:
				set_debug_dice(5)
			KEY_6:
				set_debug_dice(6)
			KEY_0:
				clear_debug_dice()
			KEY_7:
				# 特殊: 敵の土地へ直接移動（バトルテスト用）
				move_to_enemy_land()
			KEY_8:
				# 特殊: 空き地へ直接移動
				move_to_empty_land()
			KEY_9:
				# 魔力を1000追加（デバッグ用）
				add_debug_magic()

# デバッグ用サイコロ値を設定
func set_debug_dice(value: int):
	debug_dice_mode = true
	fixed_dice_value = value
	print("【デバッグ】サイコロ固定: ", value)

# デバッグモードをクリア
func clear_debug_dice():
	debug_dice_mode = false
	fixed_dice_value = 0
	print("【デバッグ】サイコロ固定解除")

# デバッグ: 敵の土地へ移動
func move_to_enemy_land():
	if is_moving:
		return
	
	var current_player = get_current_player()
	if not current_player:
		return
	
	# BoardSystemへの参照を取得
	var board_system = get_tree().get_root().get_node_or_null("Game/BoardSystem")
	if not board_system:
		return
	
	# 敵が所有している土地を探す
	for i in range(board_system.total_tiles):
		var tile_info = board_system.get_tile_info(i)
		if tile_info.owner != -1 and tile_info.owner != current_player.id:
			# クリーチャーがいる土地を優先
			if not tile_info.creature.is_empty():
				print("【デバッグ】敵クリーチャーがいるマス", i, "へ移動")
				place_player_at_tile(current_player.id, i, board_system)
				emit_signal("movement_completed", i)
				return
	
	# クリーチャーがいない敵の土地へ
	for i in range(board_system.total_tiles):
		var tile_info = board_system.get_tile_info(i)
		if tile_info.owner != -1 and tile_info.owner != current_player.id:
			print("【デバッグ】敵の土地マス", i, "へ移動")
			place_player_at_tile(current_player.id, i, board_system)
			emit_signal("movement_completed", i)
			return
	
	print("【デバッグ】敵の土地が見つかりません")

# デバッグ: 空き地へ移動
func move_to_empty_land():
	if is_moving:
		return
	
	var current_player = get_current_player()
	if not current_player:
		return
	
	var board_system = get_tree().get_root().get_node_or_null("Game/BoardSystem")
	if not board_system:
		return
	
	# 空き地を探す
	for i in range(1, board_system.total_tiles):  # スタート地点を除く
		var tile_info = board_system.get_tile_info(i)
		if tile_info.owner == -1 and tile_info.type == board_system.TileType.NORMAL:
			print("【デバッグ】空き地マス", i, "へ移動")
			place_player_at_tile(current_player.id, i, board_system)
			emit_signal("movement_completed", i)
			return
	
	print("【デバッグ】空き地が見つかりません")

# デバッグ: 魔力追加
func add_debug_magic():
	var current_player = get_current_player()
	if current_player:
		add_magic(current_player.id, 1000)
		print("【デバッグ】魔力+1000G")

# プレイヤーを初期化
func initialize_players(player_count: int, parent_node: Node):
	players.clear()
	player_pieces.clear()
	
	var colors = [
		Color(1, 0, 0),      # プレイヤー1: 赤
		Color(0, 0, 1),      # プレイヤー2: 青
		Color(0, 1, 0),      # プレイヤー3: 緑
		Color(1, 1, 0)       # プレイヤー4: 黄
	]
	
	for i in range(player_count):
		var player = PlayerData.new()
		player.id = i
		player.name = "プレイヤー" + str(i + 1)
		player.current_tile = 0
		player.magic_power = 3000
		player.color = colors[i % colors.size()]
		
		# 駒を作成
		var piece = create_player_piece(player, parent_node)
		player.piece_node = piece
		player_pieces.append(piece)
		
		players.append(player)
	
	print("PlayerSystem: ", player_count, "人のプレイヤーを初期化")

# プレイヤー駒を作成
func create_player_piece(player: PlayerData, parent: Node) -> Node:
	var piece = ColorRect.new()
	piece.size = Vector2(20, 20)
	piece.color = player.color
	piece.z_index = 10
	
	parent.add_child(piece)
	return piece

# 現在のプレイヤーを取得
func get_current_player() -> PlayerData:
	if current_player_index >= 0 and current_player_index < players.size():
		return players[current_player_index]
	return null

# 次のプレイヤーに交代
func next_player():
	current_player_index = (current_player_index + 1) % players.size()
	print("PlayerSystem: ", players[current_player_index].name, "のターン")

# サイコロを振る（デバッグモード対応）
func roll_dice() -> int:
	var value: int
	
	if debug_dice_mode and fixed_dice_value > 0:
		value = fixed_dice_value
		print("【デバッグ】固定ダイス: ", value)
	else:
		value = randi_range(1, 6)
	
	emit_signal("dice_rolled", value)
	return value

# プレイヤーを移動（ステップ移動）
func move_player_steps(player_id: int, steps: int, board_system: BoardSystem):
	if is_moving:
		return
	
	var player = players[player_id]
	is_moving = true
	emit_signal("movement_started")
	
	# 1マスずつ移動をシミュレート
	for i in range(steps):
		await player.piece_node.get_tree().create_timer(0.3).timeout
		
		var prev_pos = player.current_tile
		player.current_tile = (player.current_tile + 1) % board_system.total_tiles
		
		# スタート通過チェック
		if prev_pos > player.current_tile:
			print("スタート地点通過！")
			add_magic(player_id, 200)
		
		# 駒を移動
		var target_pos = board_system.get_tile_position(player.current_tile)
		if player.piece_node:
			player.piece_node.position = target_pos - player.piece_node.size / 2
	
	is_moving = false
	emit_signal("movement_completed", player.current_tile)

# プレイヤーを特定のタイルに配置
func place_player_at_tile(player_id: int, tile_index: int, board_system: BoardSystem):
	var player = players[player_id]
	player.current_tile = tile_index
	
	var target_pos = board_system.get_tile_position(tile_index)
	if player.piece_node:
		player.piece_node.position = target_pos - player.piece_node.size / 2

# 魔力を増減
func add_magic(player_id: int, amount: int):
	var player = players[player_id]
	player.magic_power += amount
	player.magic_power = max(0, player.magic_power)
	
	print(player.name, ": 魔力 ", player.magic_power, "G (", 
		"+" if amount >= 0 else "", amount, ")")
	
	emit_signal("magic_changed", player_id, player.magic_power)
	
	# 勝利判定
	if player.magic_power >= player.target_magic:
		emit_signal("player_won", player_id)

# 魔力を取得
func get_magic(player_id: int) -> int:
	if player_id >= 0 and player_id < players.size():
		return players[player_id].magic_power
	return 0

# 通行料を支払う
func pay_toll(payer_id: int, receiver_id: int, amount: int) -> bool:
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
			"magic": player.magic_power
		})
	return info
