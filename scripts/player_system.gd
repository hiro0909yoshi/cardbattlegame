extends Node
class_name PlayerSystem

# プレイヤー管理システム - 菱形マス移動対応版

signal dice_rolled(value: int)
signal movement_started()
signal movement_completed(final_tile: int)
signal magic_changed(player_id: int, new_value: int)
signal player_won(player_id: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# プレイヤーデータ
class PlayerData:
	var id: int = 0
	var name: String = ""
	var current_tile: int = 0
	var magic_power: int = 3000  # 直接値使用（内部クラスのため）
	var target_magic: int = 8000  # 直接値使用（内部クラスのため）
	var color: Color = Color.WHITE
	var piece_node: Node = null  # 駒のノード
	var movement_direction: String = ""  # ← この行を追加
	var last_choice_tile: int = -1      # ← この行を追加

# プレイヤー管理
var players = []
var current_player_index = 0
var player_pieces = []  # 駒のノード配列

# 移動関連
var is_moving = false

# デバッグコントローラー参照
var debug_controller: DebugController = null

func _ready():
	print("PlayerSystem: 初期化")

# デバッグコントローラーを設定
func set_debug_controller(controller: DebugController):
	debug_controller = controller

# プレイヤーを初期化
func initialize_players(player_count: int, parent_node: Node):
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
		
		# 駒を作成
		var piece = create_player_piece(player, parent_node)
		player.piece_node = piece
		player_pieces.append(piece)
		
		players.append(player)
	
	print("PlayerSystem: ", player_count, "人のプレイヤーを初期化")

# プレイヤー駒を作成（改善版）
func create_player_piece(player: PlayerData, parent: Node) -> Node:
	var piece = ColorRect.new()
	piece.size = Vector2(20, 20)
	piece.color = player.color
	piece.z_index = 10  # タイルより前面に表示（5→10に変更）
	
	# プレイヤーIDラベルを追加（識別しやすくする）
	var label = Label.new()
	label.text = "P" + str(player.id + 1)
	label.position = Vector2(-5, -20)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.z_index = 1
	piece.add_child(label)
	
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

# プレイヤーを移動（菱形マス対応版・方向選択準備）
func move_player_steps(player_id: int, steps: int, board_system: BoardSystem, clockwise: bool = true):
	if is_moving:
		return
	
	var player = players[player_id]
	is_moving = true
	emit_signal("movement_started")
	
	# SpecialTileSystemの参照を取得
	var special_system = get_tree().get_root().get_node_or_null("Game/SpecialTileSystem")
	
	# 残り移動数
	var remaining_steps = steps
	
	# 移動方向の表示（将来の拡張用）
	var direction_text = "時計回り" if clockwise else "反時計回り"
	print("移動開始: ", player.name, " (", steps, "マス・", direction_text, ")")
	
	# 1マスずつ移動をシミュレート
	while remaining_steps > 0:
		var prev_pos = player.current_tile
		
		# 次のタイルを計算
		var next_tile = board_system.get_next_tile(player.current_tile, player.movement_direction)
		if next_tile == player.current_tile:
			# デフォルトの移動（movement_directionが空の場合）
			next_tile = (player.current_tile + 1) % board_system.total_tiles
		
		player.current_tile = next_tile
		
		print("  マス", prev_pos, " → マス", player.current_tile)
		
		# スタート通過チェック
		if prev_pos > player.current_tile:
			print("スタート地点通過！")
			add_magic(player_id, GameConstants.PASS_BONUS)
		
		# 駒を滑らかに移動（Tweenを使用）
		var target_pos = board_system.get_tile_position(player.current_tile)
		if player.piece_node:
			# Tweenで滑らかな移動
			var tween = get_tree().create_tween()
			tween.tween_property(
				player.piece_node, 
				"position", 
				target_pos - player.piece_node.size / 2,
				GameConstants.MOVE_SPEED
			)
			
			# カメラも追従
			var camera_system = get_tree().get_root().get_node_or_null("Game/CameraSystem")
			if camera_system and camera_system.is_following_player:
				camera_system.focus_on_player(target_pos)
			
			# 移動アニメーションを待つ
			await tween.finished
		# 通過型ワープチェック
		if special_system and special_system.is_warp_gate(player.current_tile):
			var warp_result = special_system.process_warp_gate(player.current_tile, player_id, remaining_steps)
			if warp_result.get("warped", false):
				# ワープ発生
				await get_tree().create_timer(GameConstants.WARP_DELAY).timeout
				player.current_tile = warp_result.get("new_tile", player.current_tile)
				
				# ワープ先への視覚的移動
				target_pos = board_system.get_tile_position(player.current_tile)
				if player.piece_node:
					player.piece_node.position = target_pos - player.piece_node.size / 2
					
					# ワープ後もカメラを更新
					var camera_system = get_tree().get_root().get_node_or_null("Game/CameraSystem")
					if camera_system and camera_system.is_following_player:
						camera_system.focus_on_player(target_pos)
				
				# 残り移動数は変わらない（通過型は移動カウントを消費しない）
				print("通過型ワープ！残り移動数: ", remaining_steps - 1)
		
		remaining_steps -= 1
	
	print("移動完了: マス", player.current_tile, "に到着")
	
	is_moving = false
	emit_signal("movement_completed", player.current_tile)

# プレイヤーを特定のタイルに配置（菱形マス対応版）
func place_player_at_tile(player_id: int, tile_index: int, board_system: BoardSystem):
	var player = players[player_id]
	player.current_tile = tile_index
	
	# 実際のタイル位置を取得
	var target_pos = board_system.get_tile_position(tile_index)
	if player.piece_node:
		# 駒をタイルの中心に配置
		player.piece_node.position = target_pos - player.piece_node.size / 2
		
		print("プレイヤー", player_id + 1, "をマス", tile_index, "に配置: ", target_pos)
		
		# 配置時もカメラ更新（デバッグ移動用）
		if player_id == current_player_index:
			var camera_system = get_tree().get_root().get_node_or_null("Game/CameraSystem")
			if camera_system and camera_system.is_following_player:
				camera_system.focus_on_player(target_pos)

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
