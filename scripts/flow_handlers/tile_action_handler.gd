extends Node
class_name TileActionHandler

# タイルアクション処理クラス
# 各タイル種別に応じた処理を管理

signal action_completed()
signal summon_requested()
signal battle_requested()
signal level_up_requested()
signal toll_payment_required(amount: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# システム参照
var board_system: BoardSystem
var player_system: PlayerSystem
var card_system: CardSystem
var special_tile_system: SpecialTileSystem

# 現在の処理状態
var current_tile_info = {}
var current_player = null

func _ready():
	pass

# システム参照を設定
func setup_systems(b_system: BoardSystem, p_system: PlayerSystem, c_system: CardSystem, st_system: SpecialTileSystem = null):
	board_system = b_system
	player_system = p_system
	card_system = c_system
	special_tile_system = st_system

# タイルアクションを処理
func process_tile_action(tile_index: int, player) -> void:
	current_tile_info = board_system.get_tile_info(tile_index)
	current_player = player
	
	# 特殊マスの処理を優先
	if special_tile_system and handle_special_tiles(tile_index):
		return
	
	# 通常タイルの処理
	match current_tile_info.type:
		BoardSystem.TileType.START:
			handle_start_tile()
		BoardSystem.TileType.CHECKPOINT:
			handle_checkpoint_tile()
		BoardSystem.TileType.NORMAL, BoardSystem.TileType.SPECIAL:
			handle_normal_tile()

# 特殊マスの処理
# 特殊マスの処理
func handle_special_tiles(tile_index: int) -> bool:
	if not special_tile_system.is_special_tile(tile_index):
		return false
	
	var special_type = special_tile_system.get_special_type(tile_index)
	
	match special_type:
		# CHECKPOINTの行を削除
		special_tile_system.SpecialType.WARP_POINT:
			handle_warp_point(tile_index)
			return true
			
		special_tile_system.SpecialType.CARD:
			handle_card_tile(tile_index)
			return true
			
		special_tile_system.SpecialType.NEUTRAL:
			print("無属性マス - 属性連鎖が切れます")
			return false  # 通常土地として処理を続行
	
	return false

# スタートマスの処理
func handle_start_tile():
	print("スタート地点！ボーナス: ", GameConstants.START_BONUS, "G")
	player_system.add_magic(current_player.id, GameConstants.START_BONUS)
	emit_signal("action_completed")

# チェックポイントマスの処理
func handle_checkpoint_tile():
	print("チェックポイント到着！", GameConstants.CHECKPOINT_BONUS, "G獲得")
	player_system.add_magic(current_player.id, GameConstants.CHECKPOINT_BONUS)
	emit_signal("action_completed")

# ワープポイントの処理
func handle_warp_point(tile_index: int):
	var special_result = special_tile_system.activate_special_tile(tile_index, current_player.id)
	var new_tile = special_result.get("warp_to", tile_index)
	
	if new_tile != tile_index:
		# ワープ先のタイル情報を更新
		await get_tree().create_timer(GameConstants.WARP_DELAY).timeout
		current_tile_info = board_system.get_tile_info(new_tile)
		
		# ワープ先が特殊マスの場合、その効果も発動
		if special_tile_system.is_special_tile(new_tile):
			var warp_dest_type = special_tile_system.get_special_type(new_tile)
			if warp_dest_type == special_tile_system.SpecialType.CARD:
				handle_card_tile(new_tile)
				return
	
	emit_signal("action_completed")

# カードマスの処理
func handle_card_tile(tile_index: int):
	special_tile_system.activate_special_tile(tile_index, current_player.id)
	print("カードを引きました！")
	emit_signal("action_completed")

# 通常タイルの処理
func handle_normal_tile():
	if current_tile_info.owner == -1:
		# 空き地
		process_empty_land()
	elif current_tile_info.owner == current_player.id:
		# 自分の土地
		process_own_land()
	else:
		# 敵の土地
		process_enemy_land()

# 空き地の処理
func process_empty_land():
	# 土地を取得（無料）
	board_system.set_tile_owner(current_player.current_tile, current_player.id)
	print("空き地を取得しました！")
	
	# 手札がある場合のみ召喚選択
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size > 0:
		emit_signal("summon_requested")
	else:
		emit_signal("action_completed")

# 自分の土地の処理
func process_own_land():
	print("自分の土地です（レベル", current_tile_info.get("level", 1), "）")
	
	# レベルアップ可能かチェック
	var current_level = current_tile_info.get("level", 1)
	if current_level >= GameConstants.MAX_LEVEL:
		print("この土地は最大レベルです")
		emit_signal("action_completed")
		return
	
	# レベルアップ選択を要求
	emit_signal("level_up_requested")

# 敵の土地の処理
func process_enemy_land():
	if current_tile_info.creature.is_empty():
		# クリーチャーがいない場合
		print("敵の土地ですが、守るクリーチャーがいません")
		
		# 侵略可能かチェック（手札にクリーチャーがあるか）
		var hand_size = card_system.get_hand_size_for_player(current_player.id)
		if hand_size > 0:
			emit_signal("battle_requested")  # 侵略選択
		else:
			# 手札がなければ通行料
			print("侵略する手札がないため通行料を支払います")
			pay_toll()
	else:
		# クリーチャーがいる場合はバトル
		print("敵クリーチャーがいます！バトルするか選択してください")
		emit_signal("battle_requested")

# 通行料を支払う
func pay_toll():
	var toll = board_system.calculate_toll(current_tile_info.get("index", 0))
	print("通行料: ", toll, "G")
	emit_signal("toll_payment_required", toll)

# 土地取得を実行
func execute_land_acquisition():
	board_system.set_tile_owner(current_player.current_tile, current_player.id)

# クリーチャーを配置
func place_creature(creature_data: Dictionary):
	board_system.place_creature(current_player.current_tile, creature_data)

# レベルアップを実行
func execute_level_up(target_level: int):
	var tile_index = current_player.current_tile
	var current_level = board_system.tile_levels[tile_index]
	
	# 複数レベル分アップグレード
	for i in range(current_level, target_level):
		board_system.upgrade_tile_level(tile_index)

# 現在のタイル情報を取得
func get_current_tile_info() -> Dictionary:
	return current_tile_info

# 現在のプレイヤーを取得
func get_current_player():
	return current_player
