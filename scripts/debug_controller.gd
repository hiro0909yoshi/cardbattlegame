extends Node
class_name DebugController

# デバッグ機能管理システム
# リリース版では無効化可能

signal debug_action(action: String, value: Variant)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# デバッグモード
var enabled = true  # falseにすればデバッグ機能を完全無効化
var debug_dice_mode = false
var fixed_dice_value = 0

# システム参照
var player_system: PlayerSystem
var board_system: BoardSystem
var card_system: CardSystem
var ui_manager: UIManager

func _ready():
	if enabled:
		print("=== デバッグモード有効 ===")
		print("【デバッグコマンド】")
		print("  数字キー1-6: サイコロ固定")
		print("  0キー: サイコロ固定解除")
		print("  7キー: 敵の土地へ移動")
		print("  8キー: 空き地へ移動")
		print("  9キー: 魔力+1000G")
		print("  Dキー: CPU手札表示切替")
		print("  Tキー: 全タイル情報表示")

# システム参照を設定
func setup_systems(p_system: PlayerSystem, b_system: BoardSystem, c_system: CardSystem, ui_system: UIManager):
	player_system = p_system
	board_system = b_system
	card_system = c_system
	ui_manager = ui_system

# デバッグ入力を処理
func _input(event):
	if not enabled:
		return
	
	# リリースビルドでは無効
	if not OS.is_debug_build():
		return
	
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
				move_to_enemy_land()
			KEY_8:
				move_to_empty_land()
			KEY_9:
				add_debug_magic()
			KEY_D:
				toggle_cpu_hand_display()
			KEY_T:
				show_all_tiles_info()

# サイコロ固定
func set_debug_dice(value: int):
	debug_dice_mode = true
	fixed_dice_value = value
	print("【デバッグ】サイコロ固定: ", value)
	emit_signal("debug_action", "dice_fixed", value)

# サイコロ固定解除
func clear_debug_dice():
	debug_dice_mode = false
	fixed_dice_value = 0
	print("【デバッグ】サイコロ固定解除")
	emit_signal("debug_action", "dice_cleared", null)

# 固定ダイス値を取得
func get_fixed_dice() -> int:
	if debug_dice_mode and fixed_dice_value > 0:
		return fixed_dice_value
	return 0

# デバッグ: 敵の土地へ移動
func move_to_enemy_land():
	if not player_system or not board_system:
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return
	
	# 敵が所有している土地を探す
	for i in range(board_system.total_tiles):
		var tile_info = board_system.get_tile_info(i)
		if tile_info.owner != -1 and tile_info.owner != current_player.id:
			# クリーチャーがいる土地を優先
			if not tile_info.creature.is_empty():
				print("【デバッグ】敵クリーチャーがいるマス", i, "へ移動")
				player_system.place_player_at_tile(current_player.id, i, board_system)
				player_system.emit_signal("movement_completed", i)
				emit_signal("debug_action", "teleport", i)
				return
	
	# クリーチャーがいない敵の土地へ
	for i in range(board_system.total_tiles):
		var tile_info = board_system.get_tile_info(i)
		if tile_info.owner != -1 and tile_info.owner != current_player.id:
			print("【デバッグ】敵の土地マス", i, "へ移動")
			player_system.place_player_at_tile(current_player.id, i, board_system)
			player_system.emit_signal("movement_completed", i)
			emit_signal("debug_action", "teleport", i)
			return
	
	print("【デバッグ】敵の土地が見つかりません")

# デバッグ: 空き地へ移動
func move_to_empty_land():
	if not player_system or not board_system:
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return
	
	# 空き地を探す
	for i in range(1, board_system.total_tiles):  # スタート地点を除く
		var tile_info = board_system.get_tile_info(i)
		if tile_info.owner == -1 and tile_info.type == board_system.TileType.NORMAL:
			print("【デバッグ】空き地マス", i, "へ移動")
			player_system.place_player_at_tile(current_player.id, i, board_system)
			player_system.emit_signal("movement_completed", i)
			emit_signal("debug_action", "teleport", i)
			return
	
	print("【デバッグ】空き地が見つかりません")

# デバッグ: 魔力追加
func add_debug_magic():
	if not player_system:
		return
	
	var current_player = player_system.get_current_player()
	if current_player:
		player_system.add_magic(current_player.id, 1000)
		print("【デバッグ】魔力+1000G")
		emit_signal("debug_action", "add_magic", 1000)

# CPU手札表示切替
func toggle_cpu_hand_display():
	if not ui_manager:
		return
	
	ui_manager.toggle_debug_mode()
	emit_signal("debug_action", "toggle_cpu_hand", ui_manager.debug_mode)

# 全タイル情報表示
func show_all_tiles_info():
	if not board_system:
		return
	
	board_system.debug_print_all_tiles()
	emit_signal("debug_action", "show_tiles", null)

# 特定のタイルへ直接移動
func teleport_to_tile(tile_index: int):
	if not player_system or not board_system:
		return
	
	var current_player = player_system.get_current_player()
	if current_player and tile_index >= 0 and tile_index < board_system.total_tiles:
		print("【デバッグ】マス", tile_index, "へテレポート")
		player_system.place_player_at_tile(current_player.id, tile_index, board_system)
		player_system.emit_signal("movement_completed", tile_index)
		emit_signal("debug_action", "teleport", tile_index)

# 手札を最大まで補充
func fill_hand():
	if not card_system or not player_system:
		return
	
	var current_player = player_system.get_current_player()
	if current_player:
		var current_hand = card_system.get_hand_size_for_player(current_player.id)
		var to_draw = GameConstants.MAX_HAND_SIZE - current_hand
		if to_draw > 0:
			card_system.draw_cards_for_player(current_player.id, to_draw)
			print("【デバッグ】手札を", to_draw, "枚補充")
			emit_signal("debug_action", "fill_hand", to_draw)

# デバッグモードかチェック
func is_debug_mode() -> bool:
	return enabled and OS.is_debug_build()
